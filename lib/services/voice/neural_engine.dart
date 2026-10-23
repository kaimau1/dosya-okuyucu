import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'neural_voices.dart';

/// **Yapay sinir ağı sesi motoru** — görünmez bir WebView'da ONNX Runtime Web.
///
/// Kullanım: ekran [NeuralVoiceHost]u ağaca koyar (platform görünümü ancak
/// ağaçtayken çalışır), sonra [synthesize] metni WAV baytına çevirir.
/// Motor ilk istekte modeli yükler (birkaç saniye), sonraki istekler hızlıdır.
class NeuralVoiceEngine {
  NeuralVoiceEngine._(this._server, this.controller);

  final VoiceServer _server;
  final WebViewController controller;
  final _pageReady = Completer<void>();
  final Map<NeuralVoice, Completer<void>> _voiceReady = {};
  final Map<String, void Function(int done, int total)> _progress = {};

  /// Model yüklenirken (bayt) — arayüz "hazırlanıyor %…" gösterir.
  void Function(NeuralVoice voice, int loaded, int total)? onLoading;

  int _seq = 0;

  // ── Paylaşılan motor (2026-10-23) ──────────────────────────────────────
  // Kullanıcı: *"yapay zeka sesleri iniyor ama seçemiyorum, sadece sesli
  // kitapta seçiliyor"* + *"sesli kitap oluştur arka planda çalışabilmeli"*.
  // Motor eskiden sesli kitap EKRANININ içindeydi: ekran kapanınca WebView
  // ağaçtan düşüp iş duruyordu, sesli okuma da ona erişemiyordu. Artık tek
  // motor uygulama kökünde ([NeuralVoiceHostLayer]) yaşar; sesli kitap işi ve
  // sesli okuma onu [acquire]/[release] ile paylaşır. Kimse kullanmayınca
  // birkaç dakika sonra kapanır (model belleği geri verilir).

  /// Kökteki görünmez yüzeyin izlediği motor (yoksa null).
  static final active = ValueNotifier<NeuralVoiceEngine?>(null);
  static Future<NeuralVoiceEngine>? _starting;
  static int _users = 0;
  static Timer? _idle;

  /// Kullanılmayan motorun kapanmadan önce beklediği süre.
  static const idleTimeout = Duration(minutes: 3);

  /// Paylaşılan motoru alır (yoksa kurar). Her [acquire]e bir [release].
  static Future<NeuralVoiceEngine> acquire() async {
    _users++;
    _idle?.cancel();
    _idle = null;
    final current = active.value;
    if (current != null) return current;
    try {
      final engine = await (_starting ??= start());
      active.value = engine;
      return engine;
    } catch (_) {
      _users--;
      rethrow;
    } finally {
      _starting = null;
    }
  }

  static void release() {
    if (_users > 0) _users--;
    if (_users > 0) return;
    _idle?.cancel();
    _idle = Timer(idleTimeout, () {
      if (_users > 0) return;
      final engine = active.value;
      active.value = null;
      unawaited(engine?.dispose());
    });
  }

  static Future<NeuralVoiceEngine> start() async {
    final server = await VoiceServer.start(NeuralVoiceStore.instance.root);
    final controller = WebViewController();
    final engine = NeuralVoiceEngine._(server, controller);
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.addJavaScriptChannel('Ses',
        onMessageReceived: (m) => engine._onMessage(m.message));
    await controller.loadRequest(Uri.parse('${server.origin}/engine.html'));
    return engine;
  }

  void _onMessage(String raw) {
    final m = EngineMessage.parse(raw);
    if (m == null) return;
    final voice = NeuralVoice.values
        .where((v) => v.name == m.data['voice'])
        .firstOrNull;
    switch (m.type) {
      case 'page':
        if (!_pageReady.isCompleted) _pageReady.complete();
      case 'ready':
        if (voice != null) _voiceReady[voice]?.complete();
      case 'loading':
        final loaded = (m.data['loaded'] as num?)?.toInt() ?? 0;
        final total = (m.data['total'] as num?)?.toInt() ?? 0;
        if (voice != null) onLoading?.call(voice, loaded, total);
      case 'progress':
        final job = '${m.data['job']}';
        _progress[job]?.call((m.data['done'] as num?)?.toInt() ?? 0,
            (m.data['total'] as num?)?.toInt() ?? 0);
      case 'error':
        final msg = '${m.data['message'] ?? 'hata'}';
        final job = m.data['job'];
        if (job != null) _server.fail('$job', StateError(msg));
        if (voice != null) {
          final c = _voiceReady[voice];
          if (c != null && !c.isCompleted) c.completeError(StateError(msg));
        }
    }
  }

  /// Sesi yükler (ilk kullanım birkaç saniye). Kurulu değilse hata.
  Future<void> prepare(NeuralVoice voice) async {
    if (!NeuralVoiceStore.instance.isInstalled(voice)) {
      throw StateError('${voice.label} kurulu değil');
    }
    await _pageReady.future.timeout(const Duration(seconds: 30));
    final existing = _voiceReady[voice];
    if (existing != null) return existing.future;
    final c = _voiceReady[voice] = Completer<void>();
    await controller.runJavaScript("engine.prepare('${voice.name}')");
    return c.future.timeout(const Duration(minutes: 3));
  }

  /// Sentez kuyruğu: motor paylaşıldığı için (sesli kitap işi + sesli okuma)
  /// istekler SIRAYLA gider — EMA çalışanı aynı anda tek iş bilir.
  Future<void> _queue = Future.value();

  /// [text]i 24 kHz 16 bit mono WAV baytına çevirir.
  Future<Uint8List> synthesize(
    NeuralVoice voice,
    String text, {
    double speed = 1.0,
    void Function(int done, int total)? onProgress,
  }) async {
    final previous = _queue;
    final turn = Completer<void>();
    _queue = turn.future;
    try {
      await previous;
      return await _synthesizeNow(voice, text,
          speed: speed, onProgress: onProgress);
    } finally {
      turn.complete();
    }
  }

  Future<Uint8List> _synthesizeNow(
    NeuralVoice voice,
    String text, {
    required double speed,
    void Function(int done, int total)? onProgress,
  }) async {
    await prepare(voice);
    final job = 'j${_seq++}';
    if (onProgress != null) _progress[job] = onProgress;
    final out = _server.expect(job);
    try {
      await controller.runJavaScript(
          'engine.synth(${jsonEncode(job)}, ${jsonEncode(voice.name)}, '
          '${jsonEncode(text)}, $speed)');
      // Uzun bölüm için cömert süre: düşük cihazda gerçek zamanın altına
      // inebilir, metin başına üst sınır ~ (uzunluk / 5) sn.
      final limit = Duration(seconds: 60 + text.length ~/ 5);
      return await out.timeout(limit);
    } finally {
      _progress.remove(job);
    }
  }

  Future<void> dispose() => _server.close();
}

/// Motoru ağaca koyan 1×1 görünmez yüzey (WebView ancak ağaçtayken çalışır).
class NeuralVoiceHost extends StatelessWidget {
  final NeuralVoiceEngine engine;
  const NeuralVoiceHost({super.key, required this.engine});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 1,
        height: 1,
        child: Opacity(
          // Tam 0 opaklıkta bazı WebView sürümleri çizimi (ve JS'i) kısıyor.
          opacity: 0.01,
          child: IgnorePointer(child: WebViewWidget(controller: engine.controller)),
        ),
      );
}

/// Paylaşılan motorun yüzeyini uygulama köküne koyan katman (`main.dart`
/// `builder`ı). Motor yokken hiçbir şey çizmez.
class NeuralVoiceHostLayer extends StatelessWidget {
  final Widget child;
  const NeuralVoiceHostLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        textDirection: TextDirection.ltr,
        children: [
          Positioned.fill(child: child),
          ValueListenableBuilder<NeuralVoiceEngine?>(
            valueListenable: NeuralVoiceEngine.active,
            builder: (_, engine, __) => engine == null
                ? const SizedBox.shrink()
                : Positioned(
                    left: 0,
                    top: 0,
                    child: NeuralVoiceHost(engine: engine),
                  ),
          ),
        ],
      );
}
