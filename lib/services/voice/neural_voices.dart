import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../fm/fm_env.dart';

/// Bir indirme parçası: kaynak adres → yerel göreli yol (+ isteğe bağlı
/// metin yaması: CDN adreslerini yerel kopyaya çevirmek için).
class VoiceFile {
  final String url;
  final String path;
  final int approxBytes;
  final String Function(String text)? patch;

  /// İndirilen (yamadan ÖNCEki) baytların SHA-256'sı (G9.9 artığı,
  /// 2026-11-14): kaynak sabit sürümde (`resolve/<commit>`); tutmazsa dosya
  /// yazılmaz, kurulum hata verir.
  final String? sha256;
  const VoiceFile(this.url, this.path, this.approxBytes,
      {this.patch, this.sha256});
}

/// İndirilen ses dosyasının özeti beklenenle tutmadı.
class VoiceHashMismatch implements Exception {
  final String path;
  const VoiceHashMismatch(this.path);
  @override
  String toString() => 'Ses dosyası doğrulanamadı: $path';
}

/// **Yapay sinir ağı sesleri** (2026-10-22, kullanıcı: *"bu sesleri de kur
/// ama APK boyutu artmasın"*).
///
/// İkisi de Apache-2.0 lisanslı, ~8 M parametreli Türkçe TTS modeli; ikisinin
/// de tarayıcıda ONNX Runtime Web ile çalışan resmî/topluluk sürümü var. Bu
/// yüzden APK'ya HİÇBİR yerel kütüphane eklenmiyor: model ve çalışma zamanı
/// ilk kullanımda indirilir (~38 MB + ~36 MB, paylaşılan çalışma zamanı bir
/// kez), uygulamanın zaten taşıdığı WebView'da, cihaz üstünde, internetsiz
/// çalışır. Metin cihazdan çıkmaz.
enum NeuralVoice {
  /// Antalia-2 Mini — cloud0day3/antalia-mini (HF Space: ONNX, "mixed").
  antalia,

  /// EMA Lightning — canberk7/ema-lightning (HF: mrfakename/ema-lightning-webgpu).
  ema;

  String get label => switch (this) {
        NeuralVoice.antalia => 'Antalia-2 Mini',
        NeuralVoice.ema => 'EMA Lightning',
      };

  String get descriptionKey => switch (this) {
        NeuralVoice.antalia => 'voice.antalia_sub',
        NeuralVoice.ema => 'voice.ema_sub',
      };

  String get sourceUrl => switch (this) {
        NeuralVoice.antalia => 'https://huggingface.co/cloud0day3/antalia-mini',
        NeuralVoice.ema => 'https://github.com/canberk7/ema-lightning',
      };

  // G9.9 artığı (2026-11-14): `resolve/main` yerine sabit commit — Space
  // güncellenince indirilen dosya sessizce değişmez; her dosyanın SHA-256'sı
  // aşağıda. Yeni sürüme geçerken: commit + özetler birlikte güncellenir
  // (HF `api/spaces/<repo>/tree/<commit>`: LFS dosyada `lfs.oid` = SHA-256).
  static const _antalia =
      'https://huggingface.co/spaces/cloud0day3/antalia-mini/resolve/e7e3b1e3e83db5ca4cad925cc6d2563766e763e9';
  static const _ema =
      'https://huggingface.co/spaces/mrfakename/ema-lightning-webgpu/resolve/a2c8a396bc92754c63110f1b44e973106c9e7d22';

  /// ONNX Runtime Web 1.30.0 — iki ses de aynı sürümü kullanıyor; tek kopya
  /// `antalia/vendor/ort/` altında durur, EMA oraya yönlendirilir.
  static const runtime = [
    VoiceFile('$_antalia/vendor/ort/ort.wasm.min.mjs',
        'antalia/vendor/ort/ort.wasm.min.mjs', 450000, sha256: '219e6a1fc8a9938268d18efca3c91d310bd2f4a59bbd13744df5b2b7fc6cee3b'),
    VoiceFile('$_antalia/vendor/ort/ort-wasm-simd-threaded.mjs',
        'antalia/vendor/ort/ort-wasm-simd-threaded.mjs', 25000, sha256: 'e13f7f94fc51b4ca72b12faeb1ee95f4ace6dfbc8939bc718aabdc0a27c4299b'),
    VoiceFile('$_antalia/vendor/ort/ort-wasm-simd-threaded.wasm',
        'antalia/vendor/ort/ort-wasm-simd-threaded.wasm', 14239897, sha256: '3398c10d07d229bd91b364548e130e0e51a8e5704b88c7c083ebbeb78842dee2'),
  ];

  List<VoiceFile> get files => switch (this) {
        NeuralVoice.antalia => const [
            VoiceFile('$_antalia/js/worker.js', 'antalia/js/worker.js', 6000, sha256: '4efcbf1567ce9630a19d1d5645e9790f8203430aab75e5b5bebb4e0b8940c64f'),
            VoiceFile('$_antalia/js/tts.js', 'antalia/js/tts.js', 20000, sha256: '6e0ce96b41b550c7531ffff95fdfde615ccb668427ad068ebe634feb3ae034af'),
            VoiceFile(
                '$_antalia/js/frontend.js', 'antalia/js/frontend.js', 47000, sha256: '25fcc04fbb019394e8649aa8d3b5434b74755729ccb1e4bd8146163e7fa87428'),
            VoiceFile('$_antalia/assets/frontend-data.json.gz',
                'antalia/assets/frontend-data.json.gz', 560861, sha256: '9f25ae01718643d5572deb11b586fb5ee2d443176990f8a39e2c073617a01453'),
            VoiceFile('$_antalia/models/manifest.json',
                'antalia/models/manifest.json', 2200, sha256: '3e5a3829d64f020f55fda80535f944695640952d97389e5abf480e873954cc88'),
            // "mixed": akustik grafikler fp32, vocoder fp16 (Space varsayılanı).
            VoiceFile('$_antalia/models/text.onnx', 'antalia/models/text.onnx',
                4048328, sha256: '6b74570a31734f9aebb121dce04a44f09c2aa0fbe0d299147c4506b4546b2ce8'),
            VoiceFile('$_antalia/models/cond.onnx', 'antalia/models/cond.onnx',
                613058, sha256: '55aa32749a8a6f8180f06694e9b36a10b2c632d8ecd250e04be6823bfc2b15ec'),
            VoiceFile('$_antalia/models/flow.onnx', 'antalia/models/flow.onnx',
                10288080, sha256: '0ec1fca11bad905e8fba85c2855ae08042a0787e244d7cbc525059349ffc16a5'),
            VoiceFile('$_antalia/models/vocoder.fp16.onnx',
                'antalia/models/vocoder.fp16.onnx', 7898746, sha256: 'c82c830e4fc83446918af9f4f35711e4b3c361eab3a25288d117b7ff4cb24417'),
          ],
        NeuralVoice.ema => const [
            VoiceFile('$_ema/worker.js', 'ema/worker.js', 8000,
                patch: _patchEmaWorker, sha256: '87acd52aa627a387a4ffce83517e99efbcc6e96aca692e72dadfeeb6c35e0a7d'),
            VoiceFile('$_ema/normalizer.wasm', 'ema/normalizer.wasm', 1304287, sha256: 'a5b7d541e91fa211853959126a76510a1ead535f3683f37a7dad24382ab52355'),
            VoiceFile('$_ema/onnx/meta.json', 'ema/onnx/meta.json', 400, sha256: '337c8cb15ad4fbad4af02645a653985b7439a628d810c1cbd68d142356aa96e1'),
            VoiceFile('$_ema/onnx/text.onnx', 'ema/onnx/text.onnx', 4806399, sha256: '6bebd1b07c9ab89bf561f9b53a7ca56b558a3ab794ecd089062365d9913912a8'),
            VoiceFile('$_ema/onnx/sound.onnx', 'ema/onnx/sound.onnx', 18125453, sha256: '6a3e48c31423dcb1a781f5518186ac386f033e3b9860cfc3c5cce68a8de67cef'),
            VoiceFile(
                '$_ema/onnx/decoder.onnx', 'ema/onnx/decoder.onnx', 12032058, sha256: '97966bcf43ae44da7e92fc4f2d987d50bc2d1ceeb4579995270e091e406a7ca5'),
          ],
      };

  /// İndirilecek toplam (çalışma zamanı dahil, kurulu değilse).
  int get approxBytes =>
      [...files, ...runtime].fold(0, (a, f) => a + f.approxBytes);

  /// EMA çalışanı ONNX Runtime'ı jsDelivr'den alıyor: yerel kopyaya çevrilir
  /// (internetsiz çalışsın) ve WebGPU denemesi kapatılır (WebView'da yok;
  /// yalnız WASM paketi indiriliyor).
  static String _patchEmaWorker(String js) => js
      .replaceAll(
          RegExp(r'https://cdn\.jsdelivr\.net/npm/onnxruntime-web@[0-9.]+/dist/ort\.webgpu\.min\.mjs'),
          '/antalia/vendor/ort/ort.wasm.min.mjs')
      .replaceAll(
          RegExp(r'https://cdn\.jsdelivr\.net/npm/onnxruntime-web@[0-9.]+/dist/'),
          '/antalia/vendor/ort/')
      .replaceAll('if (self.navigator?.gpu', 'if (false && self.navigator?.gpu');
}

/// Sesli okuma tercihinde (`TtsPrefs.voiceName`) yapay zekâ sesinin adı:
/// `neural:antalia`. Cihaz seslerinin adlarıyla (`tr-tr-x-…`) çakışmaz; eski
/// sürümün okuduğu tercih dizesi biçimi değişmedi.
abstract final class NeuralVoiceId {
  static const prefix = 'neural:';

  static String of(NeuralVoice v) => '$prefix${v.name}';

  static NeuralVoice? parse(String name) {
    if (!name.startsWith(prefix)) return null;
    final id = name.substring(prefix.length);
    return NeuralVoice.values.where((v) => v.name == id).firstOrNull;
  }
}

/// Seslerin indirme/kurulum durumu (uygulama destek klasörü `voices/`).
class NeuralVoiceStore extends ChangeNotifier {
  NeuralVoiceStore._();
  static final instance = NeuralVoiceStore._();

  /// Testler kökü değiştirir.
  @visibleForTesting
  static String? rootOverride;

  String get root => rootOverride ?? p.join(FmEnv.appSupportDir, 'voices');

  final Map<NeuralVoice, double> _progress = {};

  /// İndirme sürüyorsa 0..1; yoksa null.
  double? progressOf(NeuralVoice v) => _progress[v];

  bool _complete(List<VoiceFile> files) => files.every((f) {
        final file = File(p.join(root, f.path));
        return file.existsSync() && file.lengthSync() > 0;
      });

  bool isInstalled(NeuralVoice v) =>
      _complete(v.files) && _complete(NeuralVoice.runtime);

  /// Kurulu sesin diskteki boyutu (çalışma zamanı hariç).
  int installedBytes(NeuralVoice v) => v.files.fold(0, (a, f) {
        final file = File(p.join(root, f.path));
        return a + (file.existsSync() ? file.lengthSync() : 0);
      });

  /// Eksik dosyaları indirir (var olanlara dokunmaz — yarıda kalan indirme
  /// kaldığı dosyadan sürer). Her dosya önce `.part`a yazılır, bitince adı
  /// değişir: yarım dosya "kurulu" sayılmaz.
  Future<void> install(NeuralVoice v,
      {http.Client? client, @visibleForTesting bool verify = true}) async {
    if (_progress.containsKey(v)) return;
    final all = [...NeuralVoice.runtime, ...v.files];
    final total = all.fold<int>(0, (a, f) => a + f.approxBytes);
    var done = 0;
    _progress[v] = 0;
    notifyListeners();
    final c = client ?? http.Client();
    try {
      for (final f in all) {
        final target = File(p.join(root, f.path));
        if (target.existsSync() && target.lengthSync() > 0) {
          done += f.approxBytes;
          continue;
        }
        await target.parent.create(recursive: true);
        final part = File('${target.path}.part');
        final res = await c.send(http.Request('GET', Uri.parse(f.url)));
        if (res.statusCode != 200) {
          throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(f.url));
        }
        Digest? digest;
        final hasher = sha256.startChunkedConversion(
            ChunkedConversionSink<Digest>.withCallback((d) => digest = d.single));
        if (f.patch != null) {
          final raw = await res.stream.toBytes();
          hasher.add(raw);
          await part.writeAsString(f.patch!(utf8.decode(raw)), flush: true);
          done += f.approxBytes;
        } else {
          final sink = part.openWrite();
          await for (final chunk in res.stream) {
            sink.add(chunk);
            hasher.add(chunk);
            done += chunk.length;
            _progress[v] = (done / total).clamp(0, 0.99);
            notifyListeners();
          }
          await sink.close();
        }
        hasher.close();
        if (verify &&
            f.sha256 != null &&
            digest.toString() != f.sha256) {
          await part.delete();
          throw VoiceHashMismatch(f.path);
        }
        await part.rename(target.path);
        _progress[v] = (done / total).clamp(0, 0.99);
        notifyListeners();
      }
    } finally {
      if (client == null) c.close();
      _progress.remove(v);
      notifyListeners();
    }
  }

  /// Sesi siler; başka kurulu ses yoksa çalışma zamanını da.
  Future<void> remove(NeuralVoice v) async {
    for (final f in v.files) {
      final file = File(p.join(root, f.path));
      if (file.existsSync()) await file.delete();
    }
    final others = NeuralVoice.values.where((o) => o != v && isInstalled(o));
    if (others.isEmpty) {
      for (final f in NeuralVoice.runtime) {
        final file = File(p.join(root, f.path));
        if (file.existsSync()) await file.delete();
      }
    }
    notifyListeners();
  }
}

/// **Yerel sunucu**: ses dosyalarını WebView'a `http://127.0.0.1:<port>/`
/// üzerinden verir (ES modülleri ve Worker `file://`dan yüklenemiyor) ve
/// üretilen sesi `POST /out/<iş>` ile geri alır (Dart'a megabaytlarca
/// base64 taşımadan). COOP/COEP başlıkları sayfayı "cross-origin isolated"
/// yapar → ONNX Runtime çok iş parçacıklı çalışır.
class VoiceServer {
  VoiceServer._(this._server, this.root) : prefix = _randomPrefix();

  final HttpServer _server;
  final String root;
  final Map<String, Completer<Uint8List>> _outputs = {};

  /// G6.5 artığı (2026-11-14): her açılışta 128 bit rastgele yol öneki —
  /// aynı cihazdaki başka uygulama portu tarasa da öneki bilmeden hiçbir
  /// dosyaya/sonuca ulaşamaz (önekli olmayan her istek 404).
  final String prefix;

  int get port => _server.port;
  String get origin => 'http://127.0.0.1:$port';

  /// Motor sayfasının ve dosyaların kökü (`<origin>/<önek>/`).
  String get base => '$origin/$prefix/';

  static String _randomPrefix() {
    final r = Random.secure();
    return List.generate(
        16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<VoiceServer> start(String root) async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final v = VoiceServer._(s, root);
    s.listen(v._handle);
    return v;
  }

  /// [job] için gelecek sesi bekler.
  Future<Uint8List> expect(String job) =>
      (_outputs[job] = Completer<Uint8List>()).future;

  void fail(String job, Object error) {
    final c = _outputs.remove(job);
    if (c != null && !c.isCompleted) c.completeError(error);
  }

  /// Bir ses çıktısının en büyük boyu (24 kHz 16 bit mono ≈ 46 dk).
  static const maxOutputBytes = 64 * 1024 * 1024;

  /// Host başlığı yalnız `127.0.0.1:<port>` / `localhost:<port>`.
  static bool hostAllowed(String? host, int port) =>
      host == '127.0.0.1:$port' || host == 'localhost:$port';

  /// POST'ta Origin yoksa (Dart istemcisi) ya da motor sayfasının kökeniyse.
  static bool originAllowed(String? origin, int port) =>
      origin == null ||
      origin == 'http://127.0.0.1:$port' ||
      origin == 'http://localhost:$port';

  static const _types = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.json': 'application/json',
    '.wasm': 'application/wasm',
  };

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('Cross-Origin-Opener-Policy', 'same-origin')
      ..set('Cross-Origin-Embedder-Policy', 'require-corp')
      ..set('Cross-Origin-Resource-Policy', 'same-origin')
      ..set('Cache-Control', 'no-store');
    try {
      // G6.5 (2026-11-12): DNS yeniden bağlama (rebinding) — tarayıcıdaki bir
      // site `evil.com`u 127.0.0.1'e çözdürüp buraya istek atabilir; Host
      // başlığı yine `evil.com` olur → 403. Sonuç POST'u da yalnız motor
      // sayfasının kökeninden (Origin yoksa ya da aynıysa).
      if (!hostAllowed(req.headers.value(HttpHeaders.hostHeader), port) ||
          (req.method == 'POST' &&
              !originAllowed(req.headers.value('origin'), port))) {
        res.statusCode = 403;
        await res.close();
        return;
      }
      final raw = Uri.decodeComponent(req.uri.path);
      if (!raw.startsWith('/$prefix/')) {
        res.statusCode = 404;
        await res.close();
        return;
      }
      final path = raw.substring(prefix.length + 1);
      if (req.method == 'POST' && path.startsWith('/out/')) {
        final job = path.substring(5);
        // Yalnız beklenen iş için gövde okunur; tavan 64 MB (≈ 20 dk ses).
        if (!_outputs.containsKey(job) ||
            req.contentLength > maxOutputBytes) {
          res.statusCode = req.contentLength > maxOutputBytes ? 413 : 404;
          await res.close();
          return;
        }
        final bytes = BytesBuilder(copy: false);
        await for (final d in req) {
          bytes.add(d);
          if (bytes.length > maxOutputBytes) {
            res.statusCode = 413;
            await res.close();
            return;
          }
        }
        _outputs.remove(job)?.complete(bytes.toBytes());
        res.statusCode = 204;
        await res.close();
        return;
      }
      if (path == '/engine.html') {
        res.headers.contentType = ContentType.html;
        res.write(engineHtml);
        await res.close();
        return;
      }
      // Kök dışına çıkış YOK ('..' reddedilir).
      final rel = p.normalize(path.replaceFirst(RegExp(r'^/+'), ''));
      if (rel.startsWith('..') || p.isAbsolute(rel)) {
        res.statusCode = 403;
        await res.close();
        return;
      }
      final file = File(p.join(root, rel));
      if (!file.existsSync()) {
        res.statusCode = 404;
        await res.close();
        return;
      }
      final type = _types[p.extension(rel).toLowerCase()];
      res.headers.set('Content-Type', type ?? 'application/octet-stream');
      // Kurulumda yamalanan EMA çalışanı ORT'yi mutlak `/antalia/vendor/ort/`
      // yolundan alıyor (eski kurulumlarda da diskte böyle) → önek burada eklenir.
      if (rel == p.normalize('ema/worker.js')) {
        res.write((await file.readAsString())
            .replaceAll('/antalia/vendor/ort/', '/$prefix/antalia/vendor/ort/'));
        await res.close();
        return;
      }
      res.headers.contentLength = file.lengthSync();
      await res.addStream(file.openRead());
      await res.close();
    } catch (_) {
      try {
        res.statusCode = 500;
        await res.close();
      } catch (_) {
        // Bilinçli: kapatma — zaten kapalıysa ya da kapanırken hata verirse yapılacak bir şey yok.
      }
    }
  }

  Future<void> close() async {
    for (final c in _outputs.values) {
      if (!c.isCompleted) c.completeError(StateError('kapandı'));
    }
    _outputs.clear();
    await _server.close(force: true);
  }

  /// WebView'da çalışan **motor sayfası**: her ses için bir Web Worker kurar
  /// (sesin kendi çalışanı, değiştirilmeden), metni verir, gelen 48 kHz
  /// float sesi 24 kHz 16 bit WAV'a çevirip `/out/<iş>`e gönderir. İlerleme
  /// ve hatalar `Ses` JavaScript kanalıyla Dart'a gider.
  static const engineHtml = r'''<!doctype html>
<html><head><meta charset="utf-8"><title>ses</title></head><body><script>
const post = (m) => { try { Ses.postMessage(JSON.stringify(m)); } catch (e) { /* köprü yoksa sessiz */ } };
const workers = {};
function wav(f32, rate) {
  // 48 kHz -> 24 kHz (iki örnek ortalaması; konuşma için yeterli), 16 bit.
  const n = Math.floor(f32.length / 2), buf = new ArrayBuffer(44 + n * 2), d = new DataView(buf);
  const s = (o, t) => { for (let i = 0; i < 4; i++) d.setUint8(o + i, t.charCodeAt(i)); };
  const r = Math.floor(rate / 2);
  s(0, 'RIFF'); d.setUint32(4, 36 + n * 2, true); s(8, 'WAVE'); s(12, 'fmt ');
  d.setUint32(16, 16, true); d.setUint16(20, 1, true); d.setUint16(22, 1, true);
  d.setUint32(24, r, true); d.setUint32(28, r * 2, true); d.setUint16(32, 2, true);
  d.setUint16(34, 16, true); s(36, 'data'); d.setUint32(40, n * 2, true);
  for (let i = 0; i < n; i++) {
    let v = (f32[2 * i] + f32[2 * i + 1]) / 2;
    v = Math.max(-1, Math.min(1, v));
    d.setInt16(44 + i * 2, v < 0 ? v * 0x8000 : v * 0x7fff, true);
  }
  return buf;
}
async function deliver(job, parts, rate) {
  const n = parts.reduce((a, b) => a + b.length, 0), all = new Float32Array(n);
  let o = 0; for (const p of parts) { all.set(p, o); o += p.length; }
  await fetch('out/' + encodeURIComponent(job), { method: 'POST', body: wav(all, rate) });
  post({ type: 'done', job });
}
function worker(voice) {
  if (workers[voice]) return workers[voice];
  // Göreli: sayfa `/<önek>/engine.html` altında (G6.5 artığı).
  const url = voice === 'antalia' ? 'antalia/js/worker.js' : 'ema/worker.js';
  const w = new Worker(url, { type: 'module' });
  const st = { w, jobs: {} };
  st.ready = new Promise((resolve, reject) => {
    w.onmessage = async (ev) => {
      const m = ev.data;
      if (m.type === 'ready') { post({ type: 'ready', voice }); resolve(); return; }
      if (m.type === 'progress' && m.loaded !== undefined) { post({ type: 'loading', voice, loaded: m.loaded, total: m.total }); return; }
      if (m.type === 'error') {
        const job = m.id || st.current;
        post({ type: 'error', voice, job, message: m.message });
        if (!st.started) reject(new Error(m.message));
        return;
      }
      const job = m.id || st.current;
      const j = st.jobs[job];
      if (!j) return;
      if (m.type === 'chunk') { j.parts.push(m.audio); post({ type: 'progress', job, done: m.index + 1, total: m.count }); }
      else if (m.type === 'progress') { post({ type: 'progress', job, done: m.done, total: m.total }); }
      else if (m.type === 'done') { delete st.jobs[job]; await deliver(job, j.parts, 48000); }
      else if (m.type === 'audio') { delete st.jobs[job]; await deliver(job, [m.audio], m.rate || 48000); }
    };
  });
  if (voice === 'antalia') w.postMessage({ type: 'init', backend: 'wasm', precision: 'mixed' });
  else w.postMessage({ type: 'load' });
  workers[voice] = st;
  return st;
}
window.engine = {
  async prepare(voice) {
    try { await worker(voice).ready; } catch (e) { post({ type: 'error', voice, message: String(e && e.message || e) }); }
  },
  async synth(job, voice, text, speed) {
    const st = worker(voice);
    try { await st.ready; } catch (e) { post({ type: 'error', job, message: String(e && e.message || e) }); return; }
    st.started = true; st.current = job; st.jobs[job] = { parts: [] };
    if (voice === 'antalia') st.w.postMessage({ type: 'synth', id: job, text, speed, seed: 0 });
    else st.w.postMessage({ type: 'speak', text, speed, seed: 0 });
  },
};
post({ type: 'page' });
</script></body></html>''';
}

/// WebView ile motor arasındaki iletiler (JSON) — [NeuralVoiceEngine] çözer.
class EngineMessage {
  final String type;
  final Map<String, dynamic> data;
  EngineMessage(this.type, this.data);

  static EngineMessage? parse(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is Map<String, dynamic> && m['type'] is String) {
        return EngineMessage(m['type'] as String, m);
      }
    } catch (_) {
      // Bilinçli: bozuk/eksik veri — varsayılan değer kalır.
    }
    return null;
  }
}
