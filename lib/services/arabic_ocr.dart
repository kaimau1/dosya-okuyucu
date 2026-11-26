import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../core/l10n/app_strings.dart';
import 'ocr_service.dart' show OcrLine;
import 'scan_page_ops.dart' show ScanPageOps;
import 'voice/neural_engine.dart';
import 'voice/neural_voices.dart';

/// Cihazda Arapça modeli indirilmedi (Ayarlar → Belgeler → Metin tanıma dili).
class ArabicOcrMissing implements Exception {
  const ArabicOcrMissing();
  @override
  String toString() => AppStrings.current.t('ocr.ar_need_model');
}

/// **İnternetsiz Arapça metin tanıma** (B16, kullanıcı 2026-11-26).
///
/// KÖK: ML Kit'te Arapça yazı modeli yok; Arapça bugüne dek yalnız Gemini ile
/// (internet + anahtar). Tesseract APK bütçesi yüzünden reddedilmişti. Bu yol
/// APK'ya bir bayt eklemez: PaddleOCR PP-OCRv5 mobil modelleri (Apache 2.0;
/// ONNX dönüşümü snowfluke/ppu-paddle-ocr-models, Apache 2.0) ilk kullanımda
/// iner ve sesli kitabın görünmez WebView'ındaki ONNX Runtime Web'de koşar
/// ([NeuralVoiceEngine.infer], çalışma zamanı seslerle ORTAK). İndirilen şey
/// kod değil model dosyası.
///
/// Akış: görsel → (izolat) algılama girdisi → DB algılama → (izolat) eşik +
/// bağlı bileşen → satır kutuları → her satır 48 px yükseklikte tanıma → CTC
/// çözümü → görsel sıradan okuma sırasına ([visualToLogical]).
abstract final class ArabicOcr {
  static const _hf =
      'https://huggingface.co/snowfluke/ppu-paddle-ocr-models/resolve/3cbb26882389013ed863b66a78e52376b5ff0f0a';
  static const detModel = 'ocr-ar/det.onnx';
  static const recModel = 'ocr-ar/rec.onnx';
  static const _dict = 'ocr-ar/dict.txt';

  static const files = [
    VoiceFile(
      '$_hf/detection/PP-OCRv5_mobile_det_infer.onnx',
      detModel,
      4748769,
      sha256:
          'd7fe3ea74652890722c0f4d02458b7261d9f5ae6c92904d05707c9eb155c7924',
    ),
    VoiceFile(
      '$_hf/recognition/multi/arabic/v5/arabic_PP-OCRv5_mobile_rec_infer.onnx',
      recModel,
      8023442,
      sha256:
          'b58f7d1cc7200566aae1d56ac26c17942881958ed100ac5a07d9a6e67150cbef',
    ),
    VoiceFile(
      '$_hf/recognition/multi/arabic/v5/ppocrv5_arabic_dict.txt',
      _dict,
      2370,
      sha256:
          'f6b5baf1335408e6e1fb5cc6e8268a26769f549c2bb37268e72a6804fe269b4c',
    ),
  ];

  /// İndirilecek toplam bayt (çalışma zamanı kurulu değilse o da).
  static int get downloadBytes => [
    ...files,
    if (!NeuralVoiceStore.instance.complete(NeuralVoice.runtime))
      ...NeuralVoice.runtime,
  ].fold(0, (a, f) => a + f.approxBytes);

  static bool get installed =>
      NeuralVoiceStore.instance.complete([...files, ...NeuralVoice.runtime]);

  /// İndirme sürerken 0..1, yoksa null.
  static final progress = ValueNotifier<double?>(null);

  static Future<void> install() async {
    if (progress.value != null) return;
    progress.value = 0;
    try {
      await NeuralVoiceStore.instance.fetchFiles([
        ...NeuralVoice.runtime,
        ...files,
      ], onProgress: (r) => progress.value = r);
    } finally {
      progress.value = null;
    }
  }

  /// Modelleri siler; çalışma zamanı kurulu bir sesin de olduğundan kalır.
  static Future<void> remove() async {
    final root = NeuralVoiceStore.instance.root;
    for (final f in files) {
      final file = File(p.join(root, f.path));
      if (file.existsSync()) await file.delete();
    }
    _chars = null;
  }

  /// Algılama girdisinin uzun kenarı. ponytail: sabit; taranmış tam sayfada
  /// küçük yazı kaçarsa cihazda ölçüp büyüt (C2 — hız/bellek dengesi).
  static const detMaxSide = 1280;

  static List<String>? _chars;

  /// [path] görselindeki satırlar, resim pikseli koordinatında (EXIF uygulanmış).
  static Future<List<OcrLine>> recognize(String path) async {
    if (!installed) throw const ArabicOcrMissing();
    final root = NeuralVoiceStore.instance.root;
    final chars = _chars ??= dictChars(
      await File(p.join(root, _dict)).readAsString(),
    );
    final engine = await NeuralVoiceEngine.acquire();
    try {
      final det = await _runDet(path);
      if (det == null) return const [];
      final (prob, pd) = await engine.infer(detModel, det.data, [
        1,
        3,
        det.h,
        det.w,
      ]);
      final lines = await _runRec(path, prob, pd[2], pd[3]);
      final out = <OcrLine>[];
      for (final l in lines) {
        final (logits, ld) = await engine.infer(recModel, l.data, [
          1,
          3,
          recHeight,
          l.width,
        ]);
        if (ld.last != chars.length) throw StateError('ocr dict mismatch');
        final text = visualToLogical(ctcDecode(logits, ld[1], ld[2], chars));
        if (text.trim().isNotEmpty) out.add(OcrLine(text.trim(), l.box));
      }
      return out;
    } finally {
      NeuralVoiceEngine.release();
    }
  }

  // Ayrı yöntemde: kapanış `recognize`un bağlamını (motor, WebView) yakalayıp
  // izolata göndermeye çalışmasın.
  static Future<({Float32List data, int w, int h})?> _runDet(String path) =>
      Isolate.run(() => _detInput(path, detMaxSide));

  static Future<List<({ui.Rect box, Float32List data, int width})>> _runRec(
    String path,
    Float32List prob,
    int ph,
    int pw,
  ) => Isolate.run(() => _recInputs(path, prob, ph, pw));

  // ── Saf parçalar (izolatta koşar, birim testli) ─────────────────────────

  static const recHeight = 48;

  /// Sözlük → sınıf listesi. Model 749 sınıf: 0 = CTC boşluğu, son = ' '.
  /// Bu sözlük dosyası boş bir satırla başlıyor (dosya 748 satır): sınıf
  /// i = satır i, satır 0 boşluğun yerinde (Python'da ölçüldü: bu eşlemeyle
  /// "بسم الله الرحمن الرحيم" birebir çıktı, öteki eşleme anlamsız harf).
  @visibleForTesting
  static List<String> dictChars(String dict) {
    final lines = dict.replaceAll('\r', '').split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return ['', ...lines.skip(1), ' '];
  }

  /// CTC açgözlü çözüm: her adımda en olası sınıf; boşluk (0) ve art arda
  /// yinelenen atılır. [logits] [t × c] satır düzeninde.
  @visibleForTesting
  static String ctcDecode(
    Float32List logits,
    int t,
    int c,
    List<String> chars,
  ) {
    final sb = StringBuffer();
    var prev = -1;
    for (var i = 0; i < t; i++) {
      var best = 0;
      var bestV = logits[i * c];
      for (var k = 1; k < c; k++) {
        final v = logits[i * c + k];
        if (v > bestV) {
          bestV = v;
          best = k;
        }
      }
      if (best != prev && best != 0 && best < chars.length)
        sb.write(chars[best]);
      prev = best;
    }
    return sb.toString();
  }

  static final _ltrRun = RegExp(r'[a-zA-Z0-9 :*./%+\-]');

  /// Model Arapça satırı soldan sağa (görsel sırada) verir; PaddleOCR'ın
  /// `pred_reverse`i: Latin/rakam öbekleri kendi içinde korunur, öbek ve
  /// Arapça harf sırası tersine çevrilir.
  @visibleForTesting
  static String visualToLogical(String visual) {
    final parts = <String>[];
    var run = StringBuffer();
    // Öbeğin baş/son boşlukları yer değiştirir: "123 " ters çevrilince
    // " 123" olmalı (Paddle'da "كتب123 " çıkıyordu).
    void flush() {
      final s = run.toString();
      if (s.isEmpty) return;
      final core = s.trim();
      final lead = s.length - s.trimLeft().length;
      final trail = s.length - s.trimRight().length;
      parts.add(core.isEmpty ? s : '${' ' * trail}$core${' ' * lead}');
      run = StringBuffer();
    }

    for (final ch in visual.runes.map(String.fromCharCode)) {
      if (_ltrRun.hasMatch(ch)) {
        run.write(ch);
      } else {
        flush();
        parts.add(ch);
      }
    }
    flush();
    return parts.reversed.join();
  }

  /// DB olasılık haritasından satır kutuları ([w]×[h] harita pikselinde):
  /// eşik 0,3 → 4-komşu bağlı bileşen → ortalama olasılık ≥ 0,6 → kutu
  /// alan×1,5/çevre kadar genişletilir (PaddleOCR `unclip_ratio` 1,5).
  /// ponytail: eksene paralel kutu (taranmış belge düz); eğik fotoğrafta
  /// döndürülmüş dikdörtgen gerekirse minAreaRect ekle.
  @visibleForTesting
  static List<ui.Rect> boxesFromProb(Float32List prob, int w, int h) {
    final seen = Uint8List(w * h);
    final queue = Int32List(w * h);
    final out = <ui.Rect>[];
    for (var start = 0; start < w * h; start++) {
      if (seen[start] != 0 || prob[start] <= 0.3) continue;
      seen[start] = 1;
      var head = 0, tail = 0;
      queue[tail++] = start;
      var x0 = w, y0 = h, x1 = 0, y1 = 0;
      var sum = 0.0;
      while (head < tail) {
        final i = queue[head++];
        final x = i % w, y = i ~/ w;
        sum += prob[i];
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
        void visit(int j) {
          if (seen[j] == 0 && prob[j] > 0.3) {
            seen[j] = 1;
            queue[tail++] = j;
          }
        }

        if (x > 0) visit(i - 1);
        if (x < w - 1) visit(i + 1);
        if (y > 0) visit(i - w);
        if (y < h - 1) visit(i + w);
      }
      final bw = x1 - x0 + 1, bh = y1 - y0 + 1;
      if (math.min(bw, bh) < 3 || sum / tail < 0.6) continue;
      final d = bw * bh * 1.5 / (2 * (bw + bh));
      out.add(
        ui.Rect.fromLTRB(
          math.max(0, x0 - d),
          math.max(0, y0 - d),
          math.min(w.toDouble(), x1 + 1 + d),
          math.min(h.toDouble(), y1 + 1 + d),
        ),
      );
    }
    return out;
  }

  static img.Image? _decode(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final image = ScanPageOps.decode(file.readAsBytesSync());
    if (image == null || image.width < 8 || image.height < 8) return null;
    return image.convert(format: img.Format.uint8, numChannels: 3);
  }

  /// Planar BGR float32 (PaddleOCR cv2 sırası) — `norm(kanal, bayt)`.
  static Float32List _planar(
    img.Image im,
    double Function(int channel, int v) norm,
  ) {
    final bytes = im.getBytes(order: img.ChannelOrder.bgr);
    final n = im.width * im.height;
    final out = Float32List(3 * n);
    for (var i = 0; i < n; i++) {
      for (var c = 0; c < 3; c++) {
        out[c * n + i] = norm(c, bytes[i * 3 + c]);
      }
    }
    return out;
  }

  static const _mean = [0.485, 0.456, 0.406];
  static const _std = [0.229, 0.224, 0.225];

  static ({Float32List data, int w, int h})? _detInput(
    String path,
    int maxSide,
  ) {
    final im = _decode(path);
    if (im == null) return null;
    final s = math.min(1.0, maxSide / math.max(im.width, im.height));
    final w = math.max(32, (im.width * s / 32).round() * 32);
    final h = math.max(32, (im.height * s / 32).round() * 32);
    final r = img.copyResize(
      im,
      width: w,
      height: h,
      interpolation: img.Interpolation.linear,
    );
    return (
      data: _planar(r, (c, v) => (v / 255 - _mean[c]) / _std[c]),
      w: w,
      h: h,
    );
  }

  static List<({ui.Rect box, Float32List data, int width})> _recInputs(
    String path,
    Float32List prob,
    int ph,
    int pw,
  ) {
    final im = _decode(path);
    if (im == null) return const [];
    final sx = im.width / pw, sy = im.height / ph;
    final boxes = boxesFromProb(prob, pw, ph)
      ..sort((a, b) => a.top.compareTo(b.top));
    final out = <({ui.Rect box, Float32List data, int width})>[];
    for (final b in boxes) {
      final box = ui.Rect.fromLTRB(
        b.left * sx,
        b.top * sy,
        b.right * sx,
        b.bottom * sy,
      );
      final cw = box.width.floor(), ch = box.height.floor();
      if (cw < 4 || ch < 4) continue;
      final crop = img.copyCrop(
        im,
        x: box.left.floor(),
        y: box.top.floor(),
        width: cw,
        height: ch,
      );
      final width = (cw * recHeight / ch).round().clamp(16, 4000);
      final r = img.copyResize(
        crop,
        width: width,
        height: recHeight,
        interpolation: img.Interpolation.linear,
      );
      out.add((
        box: box,
        data: _planar(r, (_, v) => v / 127.5 - 1),
        width: width,
      ));
    }
    return out;
  }
}
