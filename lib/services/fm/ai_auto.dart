import 'dart:async';

import 'package:flutter/widgets.dart';

import '../ai_pool.dart';
import 'ai_analyzer.dart';
import 'ai_scope.dart';

/// **Yeni dosyaların otomatik AI analizi** (2026-11-06, kullanıcı isteği:
/// *"yeni dosyaların otomatik ai analizi açılıp kapanır özellik"*).
///
/// Ayarlar → AI → "Yeni dosyaları otomatik analiz et" (varsayılan KAPALI).
/// Açıkken uygulama açılışta ve öne her gelişte (en sık [minGap]'te bir)
/// anahtarın açıldığı andan SONRA değişmiş, henüz analizi olmayan dosyaları
/// bulur; varsa olağan analiz işini (iş kuyruğu, bildirim, iptal edilebilir)
/// başlatır. Aday yoksa hiçbir iş/bildirim açılmaz.
///
/// Anahtar yoksa analiz yerel kipte koşar (ücretsiz, cihazda) — elle
/// başlatılan analizle aynı kural.
class AiAutoAnalyze with WidgetsBindingObserver {
  AiAutoAnalyze._(this._scope, this._credentials);

  final AiScope Function() _scope;
  final AiCredentials Function() _credentials;

  /// İki otomatik deneme arasındaki en kısa süre — öne gelişler sık olur
  /// (izin penceresi, paylaşım dönüşü); her birinde diski taramak israf.
  static const minGap = Duration(minutes: 20);

  static AiAutoAnalyze? _instance;
  DateTime? _lastTry;
  bool _checking = false;

  /// Açılışta bir kez (StartupQueue). Tekrar çağrı zararsız.
  static void install({
    required AiScope Function() scope,
    required AiCredentials Function() credentials,
  }) {
    if (_instance != null) return;
    final auto = AiAutoAnalyze._(scope, credentials);
    _instance = auto;
    WidgetsBinding.instance.addObserver(auto);
    unawaited(auto.check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  /// Ayar açılınca hemen bir tur (aralık beklenmez).
  static Future<void> kick() async {
    final auto = _instance;
    if (auto == null) return;
    auto._lastTry = null;
    await auto.check();
  }

  /// Saf karar: bu anda denensin mi?
  static bool shouldTry({
    required AiScopeSettings settings,
    required bool analyzerBusy,
    required DateTime now,
    DateTime? lastTry,
  }) {
    if (!settings.autoNewFiles || analyzerBusy) return false;
    if (lastTry != null && now.difference(lastTry) < minGap) return false;
    return true;
  }

  Future<void> check() async {
    if (_checking) return;
    final scope = _scope();
    final now = DateTime.now();
    if (!shouldTry(
      settings: scope.settings,
      analyzerBusy: AiAnalyzer.isRunning,
      now: now,
      lastTry: _lastTry,
    )) {
      return;
    }
    _checking = true;
    _lastTry = now;
    try {
      final candidates = await AiAnalyzer.collectCandidates(
        scope: scope,
        newerThanMs: scope.settings.autoSinceMs,
      );
      if (candidates.isEmpty || AiAnalyzer.isRunning) return;
      await AiAnalyzer.start(
        scope: scope,
        credentials: _credentials(),
        candidates: candidates,
      );
    } catch (_) {
      // Otomatik tur bir kolaylık; başarısızsa bir sonraki öne gelişte denenir.
    } finally {
      _checking = false;
    }
  }
}
