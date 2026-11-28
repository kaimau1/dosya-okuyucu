import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/edition.dart';
import 'crash_log.dart';
import 'offline_mode.dart';

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
  static bool get build =>
      debugBuild ?? (_define == '1' || _define == 'true');

  @visibleForTesting
  static bool? debugBuild;

  static const _channel = MethodChannel('dosya/play');

  /// Esnek güncelleme indirildi → "Yeniden başlat" önerilsin.
  static final ValueNotifier<bool> downloaded = ValueNotifier(false);

  static bool _listening = false;
  static bool _reviewEligible = false;

  // ── Değerlendirme ──────────────────────────────────────────────────────
  static const _kOpens = 'play.review.opens';
  static const _kFirst = 'play.review.first_ms';
  static const _kLast = 'play.review.last_ms';
  static const _kDays = 'play.review.days';
  static const _kLastDay = 'play.review.last_day';
  static const _kCrashMs = 'play.review.last_crash_ms';
  static const _kFriction = 'play.review.friction_ms';

  /// İlk istekten önce: en az bu kadar dosya açılmış, en az [reviewMinDaysActive]
  /// farklı günde kullanılmış ve ilk kullanımdan [reviewMinDays] gün geçmiş
  /// olmalı. Son çökmeden [crashCooldown], son sürtünmeden [frictionCooldown]
  /// geçmeden ve görülmemiş hata varken sorulmaz (Play kotası ayrıca sınırlar).
  static const reviewMinOpens = 15;
  static const reviewMinDays = 5;
  static const reviewMinDaysActive = 3;
  static const crashCooldown = Duration(days: 7);
  static const frictionCooldown = Duration(days: 3);
  static const reviewEvery = Duration(days: 120);

  @visibleForTesting
  static void debugResetSession() {
    _reviewEligible = false;
  }

  /// Kurala uyuyor mu? (Saf; test edilir.)
  @visibleForTesting
  static bool shouldAskReview({
    required int opens,
    required int firstMs,
    required int? lastAskMs,
    required int nowMs,
    int activeDays = reviewMinDaysActive,
    int? lastCrashMs,
    int? lastFrictionMs,
    int unseenCrashes = 0,
  }) {
    if (opens < reviewMinOpens) return false;
    if (activeDays < reviewMinDaysActive) return false;
    if (nowMs - firstMs < reviewMinDays * Duration.millisecondsPerDay) {
      return false;
    }
    if (unseenCrashes > 0) return false;
    if (lastCrashMs != null &&
        nowMs - lastCrashMs < crashCooldown.inMilliseconds) {
      return false;
    }
    if (lastFrictionMs != null &&
        nowMs - lastFrictionMs < frictionCooldown.inMilliseconds) {
      return false;
    }
    if (lastAskMs != null && nowMs - lastAskMs < reviewEvery.inMilliseconds) {
      return false;
    }
    return true;
  }

  /// Bir dosya başarıyla açıldı (görüntüleyici). Koşullar sağlanırsa bir
  /// sonraki sakin dönüş anında ([maybeAskReviewAtCalmMoment]) Play
  /// değerlendirme penceresi istenir — dosya açılırken kullanıcı bölünmez.
  static Future<void> noteFileOpened({DateTime? now}) async {
    if (!build) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final opens = (prefs.getInt(_kOpens) ?? 0) + 1;
      final first = prefs.getInt(_kFirst) ?? nowMs;
      final dayBucket = nowMs ~/ Duration.millisecondsPerDay;
      final lastDay = prefs.getInt(_kLastDay);
      var days = prefs.getInt(_kDays) ?? 0;
      if (lastDay != dayBucket) {
        days += 1;
        await prefs.setInt(_kLastDay, dayBucket);
        await prefs.setInt(_kDays, days);
      }
      await prefs.setInt(_kOpens, opens);
      if (!prefs.containsKey(_kFirst)) await prefs.setInt(_kFirst, first);
      _reviewEligible = shouldAskReview(
        opens: opens,
        firstMs: first,
        lastAskMs: prefs.getInt(_kLast),
        nowMs: nowMs,
        activeDays: days,
        lastCrashMs: prefs.getInt(_kCrashMs),
        lastFrictionMs: prefs.getInt(_kFriction),
        unseenCrashes: CrashLog.unseen.value,
      );
    } catch (_) {
      // Bilinçli: Play Store yok/eski ya da kanal yok — değerlendirme isteği isteğe bağlı.
    }
  }

  /// Uygulama çökmesi/hata kaydedildiğinde değerlendirme penceresini erteler.
  static Future<void> noteCrash({DateTime? now}) async {
    _reviewEligible = false;
    if (!build) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      await prefs.setInt(_kCrashMs, nowMs);
    } catch (_) {
      // Bilinçli: tercih yazılamasa da bellek içi bayrak kapatıldı.
    }
  }

  /// Dosya açılış hatası veya Pro kapısı gibi sürtünme anında soğutma yazar.
  static Future<void> noteFriction({DateTime? now}) async {
    _reviewEligible = false;
    if (!build) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      await prefs.setInt(_kFriction, nowMs);
    } catch (_) {
      // Bilinçli: tercih yazılamasa da bellek içi bayrak kapatıldı.
    }
  }

  /// Kullanıcı belgeyi kapatıp sakin bir ana döndüğünde uygunluğu yeniden
  /// denetler ve Play'den değerlendirme penceresini ister.
  static Future<void> maybeAskReviewAtCalmMoment({DateTime? now}) async {
    if (!build || !_reviewEligible) return;
    _reviewEligible = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final ok = shouldAskReview(
        opens: prefs.getInt(_kOpens) ?? 0,
        firstMs: prefs.getInt(_kFirst) ?? nowMs,
        lastAskMs: prefs.getInt(_kLast),
        nowMs: nowMs,
        activeDays: prefs.getInt(_kDays) ?? 0,
        lastCrashMs: prefs.getInt(_kCrashMs),
        lastFrictionMs: prefs.getInt(_kFriction),
        unseenCrashes: CrashLog.unseen.value,
      );
      if (!ok) return;
      await prefs.setInt(_kLast, nowMs);
      await _channel.invokeMethod<bool>('requestReview');
    } catch (_) {
      // Bilinçli: Play Store yok/eski ya da kanal yok — isteğe bağlı.
    }
  }

  /// Play mağaza sayfasını açar ("Uygulamayı değerlendir").
  static Future<bool> openStoreListing([Edition edition = Edition.current]) async {
    final pkg = edition.packageId;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        if (await launchUrl(
          Uri.parse('market://details?id=$pkg'),
          mode: LaunchMode.externalApplication,
        )) {
          return true;
        }
      } catch (_) {
        // Play yüklü değilse web bağlantısına düş.
      }
    }
    try {
      return await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$pkg'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  // ── Güncelleme ─────────────────────────────────────────────────────────

  /// Açılışta (StartupQueue): güncelleme varsa esnek indirme başlatılır;
  /// yalnızca Play Console'da yüksek öncelik (`priority >= 4`) verildiyse hemen
  /// güncelleme istenir. Eski sürümü keyfi tam ekranla kilitlemeyiz.
  /// İndirme bitince [downloaded] true olur (UI "Yeniden başlat" önerir).
  static Future<void> runOnStartup() async {
    if (!build || OfflineMode.enabled) return;
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
    final urgent = priority >= 4;
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
