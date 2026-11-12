import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'fm/fm_env.dart';

/// **Görsel iyileştirme** — bulanık/karanlık/kumlu fotoğrafı düzeltip yanına
/// kopya olarak kaydeder (özgün dosyaya dokunulmaz).
///
/// Kullanıcı isteği 2026-11-02: *"bulanık görselleri iyileştirme"*.
///
/// - [EnhanceKind.auto] / [EnhanceKind.sharpen] / [EnhanceKind.denoise]:
///   klasik süzgeçler, saf Dart, internetsiz.
/// - [EnhanceKind.upscale]: **ESRGAN** (yapay zekâ, 4× büyütme + ayrıntı
///   üretme), LiteRT ile cihazda. Model (~5 MB) APK'ya gömülü DEĞİL — ilk
///   kullanımda indirilip SHA-256 ile doğrulanıyor: büyütmeyi hiç kullanmayan
///   kullanıcının APK'sı şişmesin.
enum EnhanceKind { auto, sharpen, denoise, upscale }

/// Kullanıcı arka plandaki iyileştirmeyi durdurdu.
class EnhanceCancelled implements Exception {
  const EnhanceCancelled();
  @override
  String toString() => 'cancelled';
}

abstract final class ImageEnhance {
  /// ESRGAN (captain-pool/esrgan-tf2, Apache 2.0) — TF Hub / Kaggle.
  static const modelUrl =
      'https://tfhub.dev/captain-pool/lite-model/esrgan-tf2/1?lite-format=tflite';
  static const modelSha256 =
      '1a380d3744103e11ef343534aaff54815cae40769dcd00c023652a7e5bc47f4b';

  /// Büyütmeden önce uzun kenar bu sınıra indirilir: 4× sonrası ≤ 3200 px.
  /// Daha büyüğü hem dakikalar sürer hem belleği taşırır; bulanık bir
  /// fotoğrafta ayrıntı zaten bu ölçekte kaybolmuş durumda.
  static const upscaleMaxSide = 800;

  static String get _modelPath =>
      p.join(FmEnv.appSupportDir, 'models', 'esrgan.tflite');

  static bool get modelReady => File(_modelPath).existsSync();

  /// Modeli indirir (zaten varsa hemen döner).
  static Future<void> ensureModel() async {
    final file = File(_modelPath);
    if (file.existsSync()) return;
    // G8.6: model indirme asılı kalmasın.
    final resp = await http
        .get(Uri.parse(modelUrl))
        .timeout(const Duration(minutes: 10));
    if (resp.statusCode != 200) {
      throw HttpException('HTTP ${resp.statusCode}');
    }
    if (sha256.convert(resp.bodyBytes).toString() != modelSha256) {
      throw const FormatException('model checksum mismatch');
    }
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(resp.bodyBytes, flush: true);
    await tmp.rename(file.path);
  }

  /// [path]'i iyileştirir, `<ad>_iyi.jpg` olarak yanına (yazılamıyorsa
  /// uygulama klasörüne) kaydeder ve yeni yolu döndürür.
  ///
  /// **Ayrı, öldürülebilir izolatta** (2026-11-03, kullanıcı isteği: *"arka
  /// planda yapılabilmesi"*): yapay zekâ büyütmesi dakikalar sürebiliyor;
  /// [onProgress] parça parça ilerlemeyi (0–1) bildirir; [cancelSignal]
  /// tamamlanınca izolat öldürülür ve [EnhanceCancelled] atılır (yoklama
  /// yok: "Durdur" anında etki eder).
  static Future<String> enhanceFile(
    String path,
    EnhanceKind kind, {
    void Function(double ratio)? onProgress,
    Future<void>? cancelSignal,
  }) async {
    var cancelled = false;
    unawaited(cancelSignal?.then((_) => cancelled = true));
    if (kind == EnhanceKind.upscale) await ensureModel();
    await Future<void>.delayed(Duration.zero); // hazır sinyal işlensin
    if (cancelled) throw const EnhanceCancelled();
    final bytes = await _runIsolated(
        path, kind, _modelPath, onProgress, cancelSignal);
    return _save(path, bytes);
  }

  static Future<Uint8List> _runIsolated(
    String path,
    EnhanceKind kind,
    String model,
    void Function(double ratio)? onProgress,
    Future<void>? cancelSignal,
  ) async {
    final port = ReceivePort();
    final done = Completer<Uint8List>();
    Isolate? iso;
    void finish([Object? error]) {
      port.close();
      if (done.isCompleted) return;
      if (error != null) {
        done.completeError(error);
      }
    }

    port.listen((msg) {
      if (msg is double) {
        onProgress?.call(msg);
      } else if (msg is TransferableTypedData) {
        if (!done.isCompleted) {
          done.complete(msg.materialize().asUint8List());
        }
        finish();
      } else if (msg is String) {
        finish(msg == 'decode'
            ? const FormatException('decode')
            : Exception(msg));
      } else if (msg == null) {
        // onExit: sonuç gelmeden çıktıysa (bellek yetmedi vb.) hata say.
        finish(Exception('enhance isolate exited'));
      }
    });
    iso = await Isolate.spawn(
      _isolateEntry,
      (port.sendPort, path, kind.index, model),
      onExit: port.sendPort,
      errorsAreFatal: true,
    );
    unawaited(cancelSignal?.then((_) {
      if (done.isCompleted) return;
      iso?.kill(priority: Isolate.immediate);
      finish(const EnhanceCancelled());
    }));
    return done.future;
  }

  static void _isolateEntry((SendPort, String, int, String) args) {
    final (send, path, kindIndex, model) = args;
    try {
      img.Image? src;
      try {
        src = img.decodeImage(File(path).readAsBytesSync());
      } on FileSystemException {
        rethrow;
      } catch (_) {
        src = null; // bozuk/tanınmayan biçim (çözücü RangeError vb. atıyor)
      }
      if (src == null) {
        send.send('decode');
        return;
      }
      final kind = EnhanceKind.values[kindIndex];
      var last = -1.0;
      void progress(double r) {
        // Kanal taşmasın: yüzde birlik adımlarla.
        if (r - last < 0.01 && r < 1) return;
        last = r;
        send.send(r);
      }

      final out = switch (kind) {
        EnhanceKind.auto => sharpen(autoLevels(denoise(src)), amount: 0.6),
        EnhanceKind.sharpen => sharpen(src),
        EnhanceKind.denoise => denoise(src, threshold: 28),
        EnhanceKind.upscale => _upscale(src, model, onTile: progress),
      };
      progress(1);
      send.send(TransferableTypedData.fromList(
          [img.encodeJpg(out, quality: 92)]));
    } catch (e) {
      send.send('$e');
    }
  }

  static Future<String> _save(String path, Uint8List bytes) async {
    final base = p.basenameWithoutExtension(path);
    for (final dir in [p.dirname(path), FmEnv.appSupportDir]) {
      try {
        var out = p.join(dir, '${base}_iyi.jpg');
        for (var n = 2; File(out).existsSync(); n++) {
          out = p.join(dir, '${base}_iyi$n.jpg');
        }
        await File(out).writeAsBytes(bytes, flush: true);
        return out;
      } on FileSystemException {
        // klasör yazılamıyor → uygulama klasörü
      }
    }
    throw const FileSystemException('write failed');
  }

  /// **Otomatik düzey**: parlaklığın en karanlık/en aydınlık %0,5'ini
  /// kırpıp aralığı 0–255'e yayar (soluk, sisli, karanlık fotoğraf).
  static img.Image autoLevels(img.Image src) {
    final hist = List<int>.filled(256, 0);
    for (final px in src) {
      hist[px.luminance.toInt().clamp(0, 255)]++;
    }
    final total = src.width * src.height;
    final cut = total * 0.005;
    var lo = 0, hi = 255, acc = 0;
    while (lo < 255 && (acc += hist[lo]) < cut) {
      lo++;
    }
    acc = 0;
    while (hi > 0 && (acc += hist[hi]) < cut) {
      hi--;
    }
    if (hi - lo < 16) return src; // tek renkli görsel: yayılacak aralık yok
    final scale = 255 / (hi - lo);
    final out = src.clone();
    for (final px in out) {
      px
        ..r = ((px.r - lo) * scale).clamp(0, 255)
        ..g = ((px.g - lo) * scale).clamp(0, 255)
        ..b = ((px.b - lo) * scale).clamp(0, 255);
    }
    return out;
  }

  /// **Keskinleştirme maskesi** (unsharp mask): görüntü + miktar × (görüntü −
  /// bulanık hâli). Kenarlar belirginleşir, düz alanlar değişmez.
  static img.Image sharpen(img.Image src, {double amount = 1.0}) {
    final blur = img.gaussianBlur(src.clone(), radius: 2);
    final out = src.clone();
    for (final px in out) {
      final b = blur.getPixel(px.x, px.y);
      px
        ..r = (px.r + amount * (px.r - b.r)).clamp(0, 255)
        ..g = (px.g + amount * (px.g - b.g)).clamp(0, 255)
        ..b = (px.b + amount * (px.b - b.b)).clamp(0, 255);
    }
    return out;
  }

  /// **Kenar koruyan gürültü azaltma** (sigma süzgeci): her piksel, 3×3
  /// komşularından yalnız kendisine [threshold]'dan yakın olanlarla
  /// ortalanır — kumlanma gider, kenarlar bulanıklaşmaz.
  static img.Image denoise(img.Image src, {int threshold = 18}) {
    final out = src.clone();
    final w = src.width, h = src.height;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final c = src.getPixel(x, y);
        num r = 0, g = 0, b = 0;
        var n = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= h) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= w) continue;
            final q = src.getPixel(xx, yy);
            if ((q.r - c.r).abs() + (q.g - c.g).abs() + (q.b - c.b).abs() >
                threshold * 3) {
              continue;
            }
            r += q.r;
            g += q.g;
            b += q.b;
            n++;
          }
        }
        out.setPixelRgb(x, y, r / n, g / n, b / n);
      }
    }
    return out;
  }

  /// ESRGAN ile 4× büyütme — görsel model girişi boyunda (50×50) parçalara
  /// bölünür; parçalar [_pad] piksel örtüşür ve ortaları alınır (ek yeri
  /// görünmesin).
  static img.Image _upscale(img.Image source, String modelPath,
      {void Function(double ratio)? onTile}) {
    var src = source;
    final side = src.width > src.height ? src.width : src.height;
    if (side > upscaleMaxSide) {
      src = src.width >= src.height
          ? img.copyResize(src, width: upscaleMaxSide)
          : img.copyResize(src, height: upscaleMaxSide);
    }
    final interpreter = Interpreter.fromFile(File(modelPath));
    try {
      final input = interpreter.getInputTensor(0);
      final output = interpreter.getOutputTensor(0);
      final tin = input.shape[1]; // 50
      final scale = output.shape[1] ~/ tin; // 4
      return tileUpscale(src, tin, scale, (tile) {
        input.data = tile.buffer.asUint8List();
        interpreter.invoke();
        return Float32List.fromList(
            Uint8List.fromList(output.data).buffer.asFloat32List());
      }, onTile: onTile);
    } finally {
      interpreter.close();
    }
  }

  static const _pad = 4;

  /// Parçalama/birleştirme (model bağımsız — testte sahte [run] verilir).
  /// [run]: `tile×tile×3` (0–255) → `(tile·scale)²×3`.
  static img.Image tileUpscale(
    img.Image src,
    int tile,
    int scale,
    Float32List Function(Float32List tile) run, {
    void Function(double ratio)? onTile,
  }) {
    final out = img.Image(width: src.width * scale, height: src.height * scale);
    final step = tile - 2 * _pad;
    final tiles = ((src.height + step - 1) ~/ step) * ((src.width + step - 1) ~/ step);
    var tilesDone = 0;
    final buf = Float32List(tile * tile * 3);
    for (var oy = 0; oy < src.height; oy += step) {
      for (var ox = 0; ox < src.width; ox += step) {
        var i = 0;
        for (var y = 0; y < tile; y++) {
          final sy = (oy - _pad + y).clamp(0, src.height - 1);
          for (var x = 0; x < tile; x++) {
            final px = src.getPixel((ox - _pad + x).clamp(0, src.width - 1), sy);
            buf[i++] = px.r.toDouble();
            buf[i++] = px.g.toDouble();
            buf[i++] = px.b.toDouble();
          }
        }
        final res = run(buf);
        onTile?.call(++tilesDone / tiles);
        final rs = tile * scale;
        for (var y = _pad * scale; y < (tile - _pad) * scale; y++) {
          final dy = (oy - _pad) * scale + y;
          if (dy >= out.height) break;
          for (var x = _pad * scale; x < (tile - _pad) * scale; x++) {
            final dx = (ox - _pad) * scale + x;
            if (dx >= out.width) break;
            final k = (y * rs + x) * 3;
            out.setPixelRgb(dx, dy, res[k].clamp(0, 255), res[k + 1].clamp(0, 255),
                res[k + 2].clamp(0, 255));
          }
        }
      }
    }
    return out;
  }
}
