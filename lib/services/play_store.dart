import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Play İçi Değerlendirme + Uygulama İçi Güncelleme (KALANLAR A6.6, N5).
///
/// Yalnız Play AAB'sinde etkin: derleme `--dart-define=DOSYA_PLAY=1` alır ve
/// Kotlin köprüsü (`ci/play/PlayCore.kt`) yalnız o derlemeye kopyalanır. GitHub
/// APK'sında [build] false → hiçbir şey yapılmaz, kanal hiç çağrılmaz; GitHub
/// kendi güncelleyicisi (`AppUpdate`) yalnız orada çalışır (Play politikası
/// Play dışından kendini güncellemeyi yasaklar).
abstract final class PlayStore {
  static const _define = String.fromEnvironment('DOSYA_PLAY');

  /// Play derlemesi mi? (Testte [debugBuild] ile değişir.)
  static bool get build => debugBuild ?? _define == '1';

  @visibleForTesting
  static bool? debugBuild;

  static const _channel = MethodChannel('dosya/play');

  /// Esnek güncelleme indirildi → "Yeniden başlat" önerilsin.
  static final ValueNotifier<bool> downloaded = ValueNotifier(false);

  static bool _listening = false;

  // ── Değerlendirme ──────────────────────────────────────────────────────
  static const _kOpens = 'play.review.opens';
  static const _kFirst = 'play.review.first_ms';
  static const _kLast = 'play.review.last_ms';

  /// İlk istekten önce: en az bu kadar dosya açılmış ve bu kadar gün geçmiş
  /// olmalı; sonra en az [reviewEvery] arayla (Play kotası zaten sınırlar).
  static const reviewMinOpens = 15;
  static const reviewMinDays = 5;
  static const reviewEvery = Duration(days: 120);

  /// Kurala uyuyor mu? (Saf; test edilir.)
  @visibleForTesting
  static bool shouldAskReview({
    required int opens,
    required int firstMs,
    required int? lastAskMs,
    required int nowMs,
  }) {
    if (opens < reviewMinOpens) return false;
    if (nowMs - firstMs < reviewMinDays * Duration.millisecondsPerDay) {
      return false;
    }
    if (lastAskMs != null && nowMs - lastAskMs < reviewEvery.inMilliseconds) {
      return false;
    }
    return true;
  }

  /// Bir dosya başarıyla açıldı (görüntüleyici). Kural sağlanırsa Play
  /// değerlendirme penceresi istenir — gösterip göstermemek Play'in kararı.
  static Future<void> noteFileOpened({DateTime? now}) async {
    if (!build) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final opens = (prefs.getInt(_kOpens) ?? 0) + 1;
      final first = prefs.getInt(_kFirst) ?? nowMs;
      await prefs.setInt(_kOpens, opens);
      if (!prefs.containsKey(_kFirst)) await prefs.setInt(_kFirst, first);
      if (!shouldAskReview(
          opens: opens,
          firstMs: first,
          lastAskMs: prefs.getInt(_kLast),
          nowMs: nowMs)) {
        return;
      }
      await prefs.setInt(_kLast, nowMs);
      await _channel.invokeMethod<bool>('requestReview');
    } catch (_) {
      // Bilinçli: Play Store yok/eski ya da kanal yok — değerlendirme isteği isteğe bağlı.
    }
  }

  // ── Güncelleme ─────────────────────────────────────────────────────────

  /// Açılışta (StartupQueue): güncelleme varsa esnek indirme başlatılır;
  /// öncelik ≥ 4 ya da 14 günden eski sürümde hemen güncelleme istenir.
  /// İndirme bitince [downloaded] true olur (UI "Yeniden başlat" önerir).
  static Future<void> runOnStartup() async {
    if (!build) return;
    _listen();
    try {
      final info =
          await _channel.invokeMethod<Map<Object?, Object?>>('checkUpdate');
      final plan = updatePlanOf(info);
      switch (plan) {
        case PlayUpdatePlan.restart:
          downloaded.value = true;
        case PlayUpdatePlan.immediate:
          await _channel.invokeMethod<bool>('startUpdate', {'immediate': true});
        case PlayUpdatePlan.flexible:
          await _channel
              .invokeMethod<bool>('startUpdate', {'immediate': false});
        case PlayUpdatePlan.none:
          break;
      }
    } catch (_) {
      // Bilinçli: Play Store yok ya da yanıt vermedi — güncelleme bir sonraki açılışta denenir.
    }
  }

  /// Yanıtı karara çevirir (saf; test edilir).
  @visibleForTesting
  static PlayUpdatePlan updatePlanOf(Map<Object?, Object?>? info) {
    if (info == null) return PlayUpdatePlan.none;
    if (info['downloaded'] == true) return PlayUpdatePlan.restart;
    // Kullanıcı hemen güncellemeyi yarıda bıraktıysa sürdürülür.
    if (info['inProgress'] == true) return PlayUpdatePlan.immediate;
    if (info['available'] != true) return PlayUpdatePlan.none;
    final priority = info['priority'] is int ? info['priority'] as int : 0;
    final stale = info['staleDays'] is int ? info['staleDays'] as int : -1;
    final urgent = priority >= 4 || stale >= 14;
    if (urgent && info['immediate'] == true) return PlayUpdatePlan.immediate;
    if (info['flexible'] == true) return PlayUpdatePlan.flexible;
    if (info['immediate'] == true) return PlayUpdatePlan.immediate;
    return PlayUpdatePlan.none;
  }

  /// İndirilmiş esnek güncellemeyi kurar (uygulama yeniden başlar).
  static Future<void> completeUpdate() async {
    if (!build) return;
    try {
      await _channel.invokeMethod<bool>('completeUpdate');
    } catch (_) {
      // Bilinçli: kurulum başlatılamadı — bildirim bir sonraki açılışta yeniden çıkar.
    }
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'downloaded') downloaded.value = true;
      return null;
    });
  }
}

enum PlayUpdatePlan { none, flexible, immediate, restart }
