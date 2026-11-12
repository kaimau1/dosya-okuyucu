import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/skin.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import 'bills.dart';
import 'open_history.dart';

/// **Yerel Android ekleri** (2026-10-18 turu) — `ci/Extras.kt`in Dart yüzü.
///
/// Tek kanal (`dosya/extras`), dört iş:
/// 1. **Günlük iş** (JobScheduler, uygulama kapalıyken de): fatura son
///    ödeme hatırlatması + haftalık temizlik önerisi bildirimi. Dart yalnız
///    VERİYİ verir (hatırlatmalar, son bulunan gereksiz boyut, çevrilmiş
///    metinler); hesap ve bildirim Kotlin'de.
/// 2. **Ana ekran widget'ları**: depolama + hızlı eylemler, son dosyalar.
/// 3. **Parmak izi** (çerçevenin `BiometricPrompt`ı) ve şifreli kasanın
///    anahtarını Android Keystore ile sarma/açma.
/// 4. **Konum adı** (`Geocoder`): fotoğraf yerlerinin şehir/semt adı.
///
/// Kanal yoksa (test, masaüstü) her çağrı sessizce null/false döner.
abstract final class NativeExtras {
  static const _ch = MethodChannel('dosya/extras');

  /// Widget'a ya da bildirime dokunarak gelinen bağlantı (`app:scan`,
  /// `app:bills`, `file:/yol` …). Kancayı `main` takar.
  static void Function(String link)? onLink;

  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) {
        onLink?.call(call.arguments as String);
      }
      return null;
    });
  }

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Uygulama bir widget/bildirim bağlantısıyla AÇILDIYSA o bağlantı (bir kez).
  static Future<String?> takeLaunchLink() => _call<String>('takeLink');

  /// `FLAG_SECURE` aç/kapat (G1.4) — ekran görüntüsü ve son uygulamalar önizlemesi.
  /// Sayaç `SecureScreenGate`te (lib/core/secure_screen.dart); doğrudan çağırma.
  static Future<void> setSecure(bool secure) async {
    await _call<bool>('setSecure', secure);
  }

  /// Hassas metni panoya kopyalar (G2.6): Android 13+ önizlemede gizli.
  /// Kanal yoksa false (çağıran düz kopyalar).
  static Future<bool> copySensitive(String text) async =>
      await _call<bool>('copySensitive', text) ?? false;

  // ── 1. günlük iş ───────────────────────────────────────────────────────

  static const kWeeklyCleanup = 'weekly_cleanup';
  static const _kRecoverable = 'cleanup_last_bytes';

  /// "Yer aç" çözümlemesinin bulduğu toplamı saklar (haftalık bildirim
  /// bu sayıyı söyler) ve işi tazeler.
  static Future<void> rememberRecoverable(int bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kRecoverable, bytes);
    } catch (_) {
      // Bilinçli: kalıcı kayıt yazılamadı (disk dolu/izin) — bellekteki durum geçerli kalır, sonraki kayıtta yeniden denenir.
    }
    await syncDailyJob();
  }

  /// Günlük işin ayarını (hatırlatmalar + temizlik + metinler) yazar ve işi
  /// kurar. Açılışta ve fatura/temizlik verisi değişince çağrılır.
  static Future<void> syncDailyJob() async {
    var cleanup = true;
    var recoverable = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      cleanup = prefs.getBool(kWeeklyCleanup) ?? true;
      recoverable = prefs.getInt(_kRecoverable) ?? 0;
    } catch (_) {
      // Bilinçli: kayıt okunamadı ya da bozuk — boş/varsayılan durumla sürülür.
    }
    await Bills.instance.ensureLoaded();
    final s = AppStrings.current;
    await _call<bool>('configureDaily', jsonEncode(dailyConfig(
      cleanup: cleanup,
      recoverableBytes: recoverable,
      reminders: Bills.instance.reminders(),
      strings: {
        'channel': s.t('nx.channel'),
        'bill_title': s.t('nx.bill_title'),
        'bill_body': s.t('nx.bill_body'),
        'bill_today': s.t('nx.bill_today'),
        'bill_overdue': s.t('nx.bill_overdue'),
        'clean_title': s.t('nx.clean_title'),
        'clean_body': s.t('nx.clean_body'),
        'clean_body_found': s.t('nx.clean_body_found'),
      },
    )));
  }

  @visibleForTesting
  static Map<String, Object> dailyConfig({
    required bool cleanup,
    required int recoverableBytes,
    required List<Map<String, Object>> reminders,
    required Map<String, String> strings,
  }) =>
      {
        'cleanup': cleanup,
        'recoverable': recoverableBytes,
        'reminders': reminders,
        'remindDays': Bills.remindDays,
        'strings': strings,
      };

  static Future<void> setWeeklyCleanup(bool on) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kWeeklyCleanup, on);
    } catch (_) {
      // Bilinçli: kalıcı kayıt yazılamadı (disk dolu/izin) — bellekteki durum geçerli kalır, sonraki kayıtta yeniden denenir.
    }
    await syncDailyJob();
  }

  // ── 2. widget'lar ──────────────────────────────────────────────────────

  /// Widget'ların verisini tazeler: son açılan 10 dosya + çevrilmiş etiketler.
  /// Widget ilk 4'ünü çizer; 10'u Gemini işlevi (`ci/Ajan.kt` › recentFiles) okur.
  static Future<void> updateWidgets() async {
    try {
      await OpenHistory.ensureLoaded();
    } catch (_) {
      // Bilinçli: ortam hazırlanamadı (testte yol sağlayıcı yok) — ardından gelen okuma boş sonuçla sürer.
    }
    final recent = <Map<String, String>>[];
    for (final path in OpenHistory.pathsByRecency()) {
      recent.add({'name': p.basename(path), 'path': path});
      if (recent.length >= 10) break;
    }
    final s = AppStrings.current;
    await _call<bool>('updateWidgets', jsonEncode({
      'recent': recent,
      'strings': {
        'storage': s.t('fm.internal_storage'),
        'free': s.t('nx.w_free'),
        'scan': s.t('nx.w_scan'),
        'search': s.t('common.search'),
        'clean': s.t('fm.free_space'),
        'recent': s.t('fm.recent_opened'),
        'empty': s.t('nx.w_empty'),
      },
    }));
  }

  // ── 3. parmak izi + anahtar sarma ──────────────────────────────────────

  /// Cihazda kayıtlı parmak izi/yüz var ve çerçeve destekliyor mu (Android 9+).
  static Future<bool> canAuthenticate() async =>
      await _call<bool>('canAuthenticate') ?? false;

  /// Biyometrik doğrulama penceresi. Başarılıysa true.
  static Future<bool> authenticate(
          {required String title, String subtitle = '', required String cancel}) async =>
      await _call<bool>('authenticate',
          {'title': title, 'subtitle': subtitle, 'cancel': cancel}) ??
      false;

  /// [key]i cihaza bağlı Keystore anahtarıyla sarar (yalnız bu telefonda
  /// açılabilen bayt dizisi).
  static Future<Uint8List?> wrapKey(Uint8List key) =>
      _call<Uint8List>('wrapKey', key);

  static Future<Uint8List?> unwrapKey(Uint8List wrapped) =>
      _call<Uint8List>('unwrapKey', wrapped);

  /// PBKDF2-HMAC-SHA256, 32 bayt (G3.1; Android 8+, arka izlekte). Kanal ya
  /// da algoritma yoksa null → çağıran saf Dart'a düşer (`PinKdf`).
  static Future<Uint8List?> pbkdf2(String pin, Uint8List salt, int iterations) =>
      _call<Uint8List>(
          'pbkdf2', {'pin': pin, 'salt': salt, 'iter': iterations});

  /// G3.4: kasa ana anahtarını **kimlik doğrulama zorunlu** Keystore
  /// anahtarıyla sarar/açar — parmak izi penceresi `CryptoObject` ile açılır,
  /// doğrulama olmadan anahtar hiç kullanılamaz (yalnız arayüz kapısı değil).
  /// Sonuç: `{'status': 'ok', 'data': bayt}` · `cancel` · `invalidated`
  /// (yeni parmak izi eklendi → anahtar geçersiz) · `error`; kanal yoksa null.
  static Future<Map<Object?, Object?>?> bioCrypt({
    required bool encrypt,
    required Uint8List data,
    required String title,
    String subtitle = '',
    required String cancel,
  }) =>
      _call<Map<Object?, Object?>>('bioCrypt', {
        'encrypt': encrypt,
        'data': data,
        'title': title,
        'subtitle': subtitle,
        'cancel': cancel,
      });

  /// Kasanın biyometrik Keystore anahtarını siler (parmak izi kapatılınca).
  static Future<void> bioDeleteKey() => _call<bool>('bioDeleteKey');

  // ── 5. pencere parlaklığı + "Farklı kullan" (Faz 18) ─────────────────

  /// Pencere parlaklığı 0..1; -1 = sistemin ayarına dön. Sistem ayarı
  /// DEĞİŞMEZ (izin gerekmez), ekrandan çıkınca -1 ile geri alınır.
  static Future<void> setBrightness(double value) =>
      _call<bool>('setBrightness', value);

  /// Pencerenin o anki parlaklığı; sistem ayarı izleniyorsa negatif.
  static Future<double?> brightness() => _call<double>('getBrightness');

  /// Dosyayı sistemin varsayılan uygulamasında açar (Faz 46, open_filex yerine).
  /// `done` · `no_app` · `missing` · `error:<ileti>`; kanal yoksa `null`.
  static Future<String?> openExternal(String path) =>
      _call<String>('openExternal', {'path': path});

  /// Parçalı paketi (`.apks` / `.xapk` / `.apkm`) kurar — PackageInstaller
  /// oturumu (2026-11-09, ".apks kurulmuyor"). Kullanıcı onayından SONRA döner:
  /// `done` · `aborted` · `need_permission` · `no_apk` · `missing` ·
  /// `error:<ileti>`; kanal yoksa `null`.
  /// "Diğer uygulamaların üzerinde göster" izni var mı (güncelleme sonrası
  /// kendiliğinden açılma için). Kanal yoksa false.
  static Future<bool> canDrawOverlays() async =>
      await _call<bool>('canDrawOverlays') ?? false;

  /// Bu uygulamanın "üzerinde göster" izin sayfasını açar.
  static Future<bool> openOverlaySettings() async =>
      await _call<bool>('openOverlaySettings') ?? false;

  static Future<String?> installPackageFile(String path,
          {bool selfUpdate = false}) =>
      _call<String>('installPackageFile',
          {'path': path, if (selfUpdate) 'self': true});

  /// Sistemin "Farklı kullan" seçicisi (duvar kâğıdı, kişi fotoğrafı…).
  static Future<bool> attachData(String path, String mime, String title) async =>
      await _call<bool>(
          'attachData', {'path': path, 'mime': mime, 'title': title}) ??
      false;

  /// Android 12+ sistem vurgu rengini [SystemAccent]a yükler (Faz 19 / K13).
  static Future<void> loadSystemAccent() async {
    final v = await _call<List<Object?>>('systemAccent');
    if (v == null || v.length < 2) return;
    final light = v[0], dark = v[1];
    if (light is int && dark is int) {
      SystemAccent.light = Color(light & 0xFFFFFFFF);
      SystemAccent.dark = Color(dark & 0xFFFFFFFF);
    }
  }

  /// Görseli Android'in kendi çözücüsüyle açıp (HEIC dahil, EXIF yönü
  /// uygulanmış) JPEG'e yazar (Faz 14b). Kanal yoksa false.
  static Future<bool> decodeImageToJpeg(String path, String target,
          {int maxEdge = 4096}) async =>
      await _call<bool>('decodeImage',
          {'path': path, 'target': target, 'maxEdge': maxEdge}) ??
      false;

  /// Izgara küçük resmi: KISA kenarı [size] px olan JPEG (saydamsa PNG), EXIF
  /// yönü uygulanmış (`MainActivity.writeImageThumb`, 2026-11-04 kalite turu).
  /// Çözülemezse ya da kanal yoksa false.
  static Future<bool> imageThumb(String path, String target, int size) async =>
      await _call<bool>('imageThumb',
          {'path': path, 'target': target, 'size': size}) ??
      false;

  /// PNG/JPEG → WebP (Android kodlayıcısı, Faz 14b). Kanal yoksa false.
  static Future<bool> encodeWebp(String source, String target,
          {int quality = 85}) async =>
      await _call<bool>('encodeWebp',
          {'source': source, 'target': target, 'quality': quality}) ??
      false;

  /// Başlatıcı simgesinin dinamik kısayolları: son açılan iki dosya (Faz 19).
  static Future<void> setRecentShortcuts(List<String> paths) =>
      _call<bool>('setRecentShortcuts', paths.take(2).toList());

  // ── 4. konum adı ───────────────────────────────────────────────────────

  /// Koordinatın semt/şehir adı ("Çankaya, Ankara"); bulunamazsa null.
  static Future<String?> placeName(double lat, double lon) => _call<String>(
      'geocode', {'lat': lat, 'lon': lon, 'lang': AppStrings.current.language.code});
}
