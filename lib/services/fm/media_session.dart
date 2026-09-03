import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// **Android medya oturumu (MediaSession) köprüsü.**
///
/// Kullanıcı isteği 2026-09-03: *"MediaSession yapalım sesler için bildirim
/// çubuğunda düzgün çalışması için tam bir premium alan olsun Spotify YouTube
/// Music gibi."*
///
/// ## Niye gerekti
/// Bildirimdeki **sürüklenebilir ilerleme çubuğunu**, kilit ekranı
/// kontrollerini ve kulaklık düğmelerini çizen şey Android'in medya
/// denetleyicisidir ve o ancak bir `MediaSession` tokenı varsa devreye girer.
/// `flutter_local_notifications`ın `MediaStyleInformation`ı yalnız GÖRÜNÜMÜ
/// taklit ediyordu (kapak + düğmeler), çubuk yoktu — 2026-09-02'de bu sınır
/// dürüstçe yazılmıştı, şimdi kalkıyor.
///
/// ## Sınır
/// Yalnız Android. Kanal yoksa (masaüstü, test) [supported] `false` olur ve
/// çağıran eski bildirim yoluna düşer — çalma her koşulda sürer.
abstract final class MediaSession {
  static const MethodChannel _channel =
      MethodChannel('dosya_okuyucu/media_session');

  /// Test kancası: köprüyü tamamen kapatır.
  @visibleForTesting
  static bool enabled = true;

  /// Test kancası: masaüstünde (test koşucusunda) de kanal kullanılıyormuş
  /// gibi davran. Üretimde ASLA açılmaz; `Platform.isAndroid` yalnız gerçek
  /// cihazda doğru.
  @visibleForTesting
  static bool debugForceSupported = false;

  /// Kanal bir kez "yok" dediyse bir daha denenmez (her tazelemede
  /// `MissingPluginException` yakalamak boşa iş).
  static bool _unavailable = false;

  /// En son başarılı bir güncelleme gitti mi (bildirim ayakta mı).
  static bool _live = false;

  static bool get live => _live;

  /// Oturumu en son KİM sürdü (`audio` / `video`).
  ///
  /// Tek bir oturum var ve iki çalar onu paylaşıyor: bildirimden gelen
  /// "duraklat" hangi çalara gitmeli sorusunun cevabı bu. Son güncelleyen
  /// sahiptir — kullanıcının gördüğü bildirim de zaten onunki.
  static String owner = '';

  /// Köprü kullanılabilir mi?
  static bool get supported {
    if (!enabled || _unavailable) return false;
    if (debugForceSupported) return true;
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Bildirimden/kilit ekranından gelen eylem: `play` `pause` `next`
  /// `previous` `stop` `seek` (seek'te [value] hedef milisaniye).
  static void Function(String action, int value)? onAction;

  /// Bildirime DOKUNULDU — uygulama açılıp bu yükün ekranına gitmeli.
  static void Function(String payload)? onOpen;

  /// Kanalı dinlemeye başlar (uygulama açılışında bir kez).
  static void install() {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'action':
          final args = call.arguments;
          if (args is! Map) return null;
          final action = args['action'];
          if (action is! String) return null;
          final value = args['value'];
          onAction?.call(action, value is int ? value : 0);
        case 'open':
          final payload = call.arguments;
          if (payload is String && payload.isNotEmpty) onOpen?.call(payload);
      }
      return null;
    });
  }

  /// Oturumu ve bildirimi tazeler.
  ///
  /// Konum her çağrıda gider ama bildirim native tarafta **yalnız görünen bir
  /// şey değiştiyse** yeniden çizilir; çubuğun akmasını sistem
  /// `PlaybackState`in hızından kendisi hallediyor.
  static Future<bool> update({
    required String title,
    required String subtitle,
    String album = '',
    required Duration position,
    required Duration duration,
    required bool playing,
    double speed = 1.0,
    bool hasNext = false,
    bool hasPrevious = false,
    String? cover,
    String payload = '',
    bool video = false,
    Map<String, String> labels = const {},
    String owner = '',
  }) async {
    if (!supported) return false;
    if (owner.isNotEmpty) MediaSession.owner = owner;
    try {
      await _channel.invokeMethod<bool>('update', {
        'title': title,
        'subtitle': subtitle,
        'album': album,
        'position': position.inMilliseconds,
        'duration': duration.inMilliseconds,
        'playing': playing,
        'speed': speed,
        'hasNext': hasNext,
        'hasPrevious': hasPrevious,
        'cover': cover,
        'payload': payload,
        'video': video,
        'labels': labels,
      });
      _live = true;
      return true;
    } on MissingPluginException {
      _unavailable = true;
      return false;
    } catch (_) {
      // Bildirim izni yok / servis başlatılamadı: çalma sürer, çağıran eski
      // bildirim yoluna düşer.
      return false;
    }
  }

  /// Oturumu ve bildirimi kaldırır.
  /// [owner] verilirse yalnız oturumun sahibi o ise temizler: duran ses
  /// çalar, çalan videonun bildirimini kapatmasın.
  static Future<void> clear({String owner = ''}) async {
    if (!supported) return;
    if (owner.isNotEmpty && MediaSession.owner.isNotEmpty &&
        MediaSession.owner != owner) {
      return;
    }
    _live = false;
    MediaSession.owner = '';
    try {
      await _channel.invokeMethod<bool>('clear');
    } on MissingPluginException {
      _unavailable = true;
    } catch (_) {}
  }

  /// Uygulama medya bildirimine dokunularak açıldıysa o yükü verir.
  static Future<String?> takePayload() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>('takePayload');
    } on MissingPluginException {
      _unavailable = true;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Yalnız test: durumu sıfırlar.
  @visibleForTesting
  static void debugReset() {
    _unavailable = false;
    _live = false;
    debugForceSupported = false;
    owner = '';
    onAction = null;
    onOpen = null;
  }
}
