import 'package:flutter/services.dart';

/// **Ekran üstünde yüzen video penceresi** — native köprü.
///
/// Kullanıcı isteği 2026-09-03: *"ekran üstünde ekran video oynatıcı sistemi
/// yapalım, her türlü özelliği olsun."* Pencereyi çizen ve videoyu oynatan
/// `ci/FloatingPlayer.kt`; burası yalnız çağrı ve olay taşıyor.
///
/// **İş bölümü:** yüzen pencere açıkken video ORADA oynar, uygulamadaki
/// oynatıcı duraklatılır. Pencere kapanınca (ya da "uygulamaya dön"
/// denince) konum geri gelir ve uygulama kaldığı yerden sürer — iki
/// oynatıcının aynı anda ses vermesi kullanıcının duyduğu ilk şey olurdu.
///
/// Kanal yoksa (masaüstü, `flutter test`, eski APK) her çağrı zarifçe
/// false/boş döner.
abstract final class FloatingVideo {
  static const _channel = MethodChannel('dosya_okuyucu/floating');

  /// Olay dinleyicisi ayarlandı mı (iki kez kurulmasın).
  static bool _wired = false;

  /// Pencereden gelen olay: `('closed'|'expand', konum)`.
  static void Function(String event, Duration position)? _handler;

  /// "Diğer uygulamaların üzerinde göster" izni verilmiş mi?
  static Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('permission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// İzin ekranını açar (kullanıcı elle verir; sonuç dönmez).
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod<bool>('requestPermission');
    } catch (_) {}
  }

  /// Videoyu yüzen pencerede açar. İzin yoksa/kanal yoksa false.
  ///
  /// [subtitle] bildirimin alt satırı ve kanal adı: metni **Dart gönderiyor**
  /// çünkü arayüz dilini yalnız Dart biliyor (native tarafa gömülü Türkçe bir
  /// cümle İngilizce kullanana Türkçe görünürdü).
  static Future<bool> open({
    required String path,
    Duration position = Duration.zero,
    String title = '',
    String subtitle = '',
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('open', {
        'path': path,
        'position': position.inMilliseconds,
        'title': title,
        'subtitle': subtitle,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Pencereyi kapatır.
  static Future<void> close() async {
    try {
      await _channel.invokeMethod<bool>('close');
    } catch (_) {}
  }

  /// Pencere şu an ekranda mı?
  static Future<bool> running() async {
    try {
      return await _channel.invokeMethod<bool>('running') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Uygulama kapalıyken kapanan pencerenin son konumu (bir kez okunur).
  ///
  /// Niye gerekli: pencere uygulamadan bağımsız yaşıyor. Kullanıcı
  /// uygulamayı görevlerden atıp pencereyi kapattığında konum Dart'a
  /// ulaşamıyordu; native taraf onu saklıyor, uygulama açılınca soruyoruz.
  static Future<(String, Duration)?> takePending() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('takePending');
      if (raw == null) return null;
      final event = '${raw['event'] ?? ''}';
      final ms = (raw['position'] as num?)?.toInt() ?? 0;
      if (event.isEmpty) return null;
      return (event, Duration(milliseconds: ms));
    } catch (_) {
      return null;
    }
  }

  /// Pencere olaylarını dinler (kapandı / uygulamaya dön).
  static void setHandler(
      void Function(String event, Duration position)? handler) {
    _handler = handler;
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'event') return null;
      final args = call.arguments;
      if (args is! Map) return null;
      final event = '${args['event'] ?? ''}';
      final ms = (args['position'] as num?)?.toInt() ?? 0;
      _handler?.call(event, Duration(milliseconds: ms));
      return null;
    });
  }
}
