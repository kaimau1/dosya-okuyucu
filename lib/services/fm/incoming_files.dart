import 'app_storage_service.dart';
import 'fm_env.dart';
import 'save_to_downloads.dart';

/// Başka uygulamadan "Birlikte aç" ile gelen dosyanın kalıcı hâle getirilmesi.
///
/// Kullanıcı 2026-09-22: *"tarayıcıda PDF açtığımda onu bulamıyorum, yeni
/// dosyalara düşmeli"*. Tarayıcı PDF'i kendi önbelleğinden `content://`
/// adresiyle veriyor; `receive_sharing_intent` onu BİZİM özel önbelleğimize
/// kopyalıyor. Kullanıcının elinde telefonda görünen hiçbir kopya kalmıyor —
/// ne dosya yöneticisinde ne "Yeni Dosyalar"da.
///
/// **Yalnız tarayıcılar:** WhatsApp/Gmail/Telegram dosyası zaten o uygulamanın
/// klasöründe duruyor (ya da kullanıcı "İndir" düğmesiyle alabilir);
/// her "Birlikte aç"ta İndirilenler'e kopya bırakmak depolamayı kopyalarla
/// doldururdu. Tarayıcıda ise dosyanın başka yerde kalıcı kopyası YOK.
class IncomingFiles {
  IncomingFiles._();

  /// Bilinen tarayıcı paketleri (paket adında "browser" geçenler ayrıca
  /// yakalanıyor — bkz. [isBrowserPackage]).
  static const browserPackages = {
    'com.android.chrome',
    'com.chrome.beta',
    'com.chrome.dev',
    'com.chrome.canary',
    'org.chromium.chrome',
    'com.google.android.googlequicksearchbox', // Google uygulaması
    'org.mozilla.firefox',
    'org.mozilla.firefox_beta',
    'org.mozilla.fenix',
    'org.mozilla.focus',
    'org.mozilla.klar',
    'com.duckduckgo.mobile.android',
    'com.sec.android.app.sbrowser',
    'com.sec.android.app.sbrowser.beta',
    'com.opera.browser',
    'com.opera.mini.native',
    'com.opera.gx',
    'com.microsoft.emmx',
    'com.brave.browser',
    'com.vivaldi.browser',
    'com.kiwibrowser.browser',
    'com.yandex.browser',
    'com.UCMobile.intl',
    'com.mi.globalbrowser',
    'com.huawei.browser',
    'com.ecosia.android',
    'org.torproject.torbrowser',
  };

  /// [package] bir web tarayıcısı mı? Saf fonksiyon — birim testli.
  static bool isBrowserPackage(String? package) {
    if (package == null || package.isEmpty) return false;
    if (browserPackages.contains(package)) return true;
    return package.toLowerCase().contains('browser');
  }

  /// Gelen [path] tarayıcıdan geldiyse ve yalnız özel önbelleğimizde
  /// duruyorsa İndirilenler'e kopyalar ve **kopyanın** yolunu döndürür
  /// (belge oradan açılsın: işaretler, kaldığı sayfa, son açılanlar kalıcı
  /// dosyaya bağlansın). Aksi hâlde null — çağıran özgün yolu açar.
  ///
  /// Kopyalama başarısız olursa da null: dosyayı açmak her şeyden önemli.
  static Future<SavedDownload?> keepIfFromBrowser(String path) async {
    await FmEnv.ensureInit();
    if (!SaveToDownloads.isPrivateCopy(path, FmEnv.volumeRoots)) return null;
    if (!isBrowserPackage(await AppStorageService.launchReferrer())) {
      return null;
    }
    try {
      return await SaveToDownloads.saveFile(path);
    } catch (_) {
      return null;
    }
  }
}
