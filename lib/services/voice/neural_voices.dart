import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  const VoiceFile(this.url, this.path, this.approxBytes, {this.patch});
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

  static const _antalia =
      'https://huggingface.co/spaces/cloud0day3/antalia-mini/resolve/main';
  static const _ema =
      'https://huggingface.co/spaces/mrfakename/ema-lightning-webgpu/resolve/main';

  /// ONNX Runtime Web 1.30.0 — iki ses de aynı sürümü kullanıyor; tek kopya
  /// `antalia/vendor/ort/` altında durur, EMA oraya yönlendirilir.
  static const runtime = [
    VoiceFile('$_antalia/vendor/ort/ort.wasm.min.mjs',
        'antalia/vendor/ort/ort.wasm.min.mjs', 450000),
    VoiceFile('$_antalia/vendor/ort/ort-wasm-simd-threaded.mjs',
        'antalia/vendor/ort/ort-wasm-simd-threaded.mjs', 25000),
    VoiceFile('$_antalia/vendor/ort/ort-wasm-simd-threaded.wasm',
        'antalia/vendor/ort/ort-wasm-simd-threaded.wasm', 14239897),
  ];

  List<VoiceFile> get files => switch (this) {
        NeuralVoice.antalia => const [
            VoiceFile('$_antalia/js/worker.js', 'antalia/js/worker.js', 6000),
            VoiceFile('$_antalia/js/tts.js', 'antalia/js/tts.js', 20000),
            VoiceFile(
                '$_antalia/js/frontend.js', 'antalia/js/frontend.js', 47000),
            VoiceFile('$_antalia/assets/frontend-data.json.gz',
                'antalia/assets/frontend-data.json.gz', 560861),
            VoiceFile('$_antalia/models/manifest.json',
                'antalia/models/manifest.json', 2200),
            // "mixed": akustik grafikler fp32, vocoder fp16 (Space varsayılanı).
            VoiceFile('$_antalia/models/text.onnx', 'antalia/models/text.onnx',
                4048328),
            VoiceFile('$_antalia/models/cond.onnx', 'antalia/models/cond.onnx',
                613058),
            VoiceFile('$_antalia/models/flow.onnx', 'antalia/models/flow.onnx',
                10288080),
            VoiceFile('$_antalia/models/vocoder.fp16.onnx',
                'antalia/models/vocoder.fp16.onnx', 7898746),
          ],
        NeuralVoice.ema => const [
            VoiceFile('$_ema/worker.js', 'ema/worker.js', 8000,
                patch: _patchEmaWorker),
            VoiceFile('$_ema/normalizer.wasm', 'ema/normalizer.wasm', 1304287),
            VoiceFile('$_ema/onnx/meta.json', 'ema/onnx/meta.json', 400),
            VoiceFile('$_ema/onnx/text.onnx', 'ema/onnx/text.onnx', 4806399),
            VoiceFile('$_ema/onnx/sound.onnx', 'ema/onnx/sound.onnx', 18125453),
            VoiceFile(
                '$_ema/onnx/decoder.onnx', 'ema/onnx/decoder.onnx', 12032058),
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
  Future<void> install(NeuralVoice v, {http.Client? client}) async {
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
        if (f.patch != null) {
          final text = await res.stream.bytesToString();
          await part.writeAsString(f.patch!(text), flush: true);
          done += f.approxBytes;
        } else {
          final sink = part.openWrite();
          await for (final chunk in res.stream) {
            sink.add(chunk);
            done += chunk.length;
            _progress[v] = (done / total).clamp(0, 0.99);
            notifyListeners();
          }
          await sink.close();
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
  VoiceServer._(this._server, this.root);

  final HttpServer _server;
  final String root;
  final Map<String, Completer<Uint8List>> _outputs = {};

  int get port => _server.port;
  String get origin => 'http://127.0.0.1:$port';

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
      final path = Uri.decodeComponent(req.uri.path);
      if (req.method == 'POST' && path.startsWith('/out/')) {
        final job = path.substring(5);
        final bytes = await req.fold<BytesBuilder>(
            BytesBuilder(copy: false), (b, d) => b..add(d));
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
      res.headers.contentLength = file.lengthSync();
      await res.addStream(file.openRead());
      await res.close();
    } catch (_) {
      try {
        res.statusCode = 500;
        await res.close();
      } catch (_) {}
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
const post = (m) => { try { Ses.postMessage(JSON.stringify(m)); } catch (e) {} };
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
  await fetch('/out/' + encodeURIComponent(job), { method: 'POST', body: wav(all, rate) });
  post({ type: 'done', job });
}
function worker(voice) {
  if (workers[voice]) return workers[voice];
  const url = voice === 'antalia' ? '/antalia/js/worker.js' : '/ema/worker.js';
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
    } catch (_) {}
    return null;
  }
}
