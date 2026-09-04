import 'package:flutter/services.dart';

/// Bir uygulamanın kapladığı alan.
class AppStorageSize {
  /// APK + kütüphaneler (kaldırınca gider, temizlenemez).
  final int appBytes;

  /// Uygulama verisi — `cacheBytes` bunun İÇİNDEDİR (Android böyle raporluyor).
  final int dataBytes;

  /// Önbellek: silinmesi güvenli, uygulama yeniden üretir.
  final int cacheBytes;

  const AppStorageSize({
    required this.appBytes,
    required this.dataBytes,
    required this.cacheBytes,
  });

  int get totalBytes => appBytes + dataBytes;
}

/// Yüklü uygulamaların **kapladığı alanı** okur ve Android'in ayar sayfalarını
/// açar (`StorageStatsManager` köprüsü — bkz. `ci/MainActivity.kt`).
///
/// **Neden platform kanalı:** `installed_apps` eklentisi ad/sürüm/simge
/// veriyor ama boyut vermiyor; `df` de uygulama başına kırılım bilmiyor.
/// Android 11+ `Android/data` klasörünü başka uygulamalara kapattığı için
/// klasör ölçerek de bulunamıyor. Tek yol `StorageStatsManager`.
///
/// **İzin:** "Kullanım erişimi" (`PACKAGE_USAGE_STATS`) — son kullanım
/// tarihiyle AYNI izin, yani kullanıcı bir kez verince ikisi de açılıyor.
/// İzin yokken boyut sorgusu boş döner; arayüz sayı uydurmaz, "bilinmiyor"
/// gösterir.
///
/// Kanal yoksa (masaüstü, `flutter test`, eski APK) bütün çağrılar zarifçe
/// boş/false döner — çağıranın ayrıca platform kontrolü yapmasına gerek yok.
abstract final class AppStorageService {
  static const _channel = MethodChannel('dosya_okuyucu/app_storage');

  /// Kanal bu cihazda çalışıyor mu (bir kez ölçülür).
  static bool? _available;

  static Future<bool> hasUsageAccess() async {
    try {
      final ok = await _channel.invokeMethod<bool>('hasUsageAccess');
      _available = true;
      return ok ?? false;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  /// Android'in "Kullanım erişimi" ayar sayfasını açar.
  static Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod<bool>('openUsageAccessSettings');
    } catch (_) {}
  }

  /// Uygulamanın **depolama / önbellek temizleme** sayfasını açar.
  static Future<bool> openAppStorageSettings(String packageName) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
          'openAppStorageSettings', {'package': packageName});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Verilen paketlerin boyutları. Okunamayan paket sonuçta YER ALMAZ
  /// (sıfır yazmak "hiç yer kaplamıyor" demek olurdu, bu yanlış olurdu).
  static Future<Map<String, AppStorageSize>> sizesOf(
      List<String> packages) async {
    if (packages.isEmpty || _available == false) return const {};
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
          'appSizes', {'packages': packages});
      _available = true;
      if (raw == null) return const {};
      final out = <String, AppStorageSize>{};
      raw.forEach((pkg, value) {
        if (value is! List || value.length < 3) return;
        out[pkg] = AppStorageSize(
          appBytes: (value[0] as num).toInt(),
          dataBytes: (value[1] as num).toInt(),
          cacheBytes: (value[2] as num).toInt(),
        );
      });
      return out;
    } catch (_) {
      _available = false;
      return const {};
    }
  }

  /// Paket → **son açılma zamanı** (epoch ms). Hiç açılmamış paket sonuçta
  /// YER ALMAZ; kanal yoksa/izin yoksa boş harita döner.
  ///
  /// Kaynak `UsageStats.getLastTimeUsed()` (bkz. `ci/MainActivity.kt`).
  /// `app_usage` eklentisinin `lastForeground` alanı bu DEĞİLDİ — o, son
  /// **ön plan servisi** zamanıdır ve servis çalıştırmayan uygulamalarda 0
  /// döner (kullanıcı hatası 2026-08-28: "açtığım birçok şey 'hiç açılmadı'
  /// görünüyor").
  static Future<Map<String, int>> lastUsed({int days = 730}) async {
    if (_available == false) return const {};
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('lastUsed', {'days': days});
      _available = true;
      if (raw == null) return const {};
      final out = <String, int>{};
      raw.forEach((pkg, value) {
        if (value is num && value > 0) out[pkg] = value.toInt();
      });
      return out;
    } catch (_) {
      // Eski APK'da bu yöntem yok (`notImplemented`) — kanalı ölü saymıyoruz,
      // boyut sorgusu hâlâ çalışabilir.
      return const {};
    }
  }

  /// Kurulu bir uygulamanın **APK dosyalarının yolu** (temel + parçalar).
  ///
  /// Kanal yoksa, paket bulunamazsa ya da yol okunamıyorsa `null` — arayüz
  /// "APK bulunamadı" der. Yolu uydurmak (`/data/app/<paket>/base.apk`)
  /// İMKÂNSIZ: gerçek yol iki rastgele parça içeriyor (bkz. ci/MainActivity.kt).
  static Future<ApkSource?> apkPathsOf(String packageName) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
          'apkPaths', {'package': packageName});
      if (raw == null) return null;
      final source = raw['source'];
      if (source is! String || source.isEmpty) return null;
      return ApkSource(
        sourcePath: source,
        splitPaths: [
          for (final s in (raw['splits'] as List? ?? const []))
            if (s is String && s.isNotEmpty) s,
        ],
        label: raw['label'] is String ? raw['label'] as String : '',
        versionName:
            raw['versionName'] is String ? raw['versionName'] as String : '',
      );
    } catch (_) {
      // Eski APK'da bu yöntem yok (`notImplemented`) — kanalı ölü saymıyoruz,
      // boyut sorgusu hâlâ çalışabilir.
      return null;
    }
  }

  /// Uygulamayı **başlatan** intent'in eylemi; okununca temizlenir.
  ///
  /// Tek kullanıcısı USB akışı: Android, bellek takılınca "hangi uygulamayla
  /// açayım?" diye soruyor ve bizi seçince uygulama
  /// `android.hardware.usb.action.USB_DEVICE_ATTACHED` ile açılıyor. O eylemin
  /// verisi (URI) olmadığı için `receive_sharing_intent` hiçbir şey getirmiyor;
  /// bu köprü olmasa uygulama sıradan bir açılış gibi panoya düşerdi.
  ///
  /// Kanal yoksa (masaüstü, test, eski APK) null döner.
  static Future<String?> launchAction() async {
    try {
      return await _channel.invokeMethod<String>('launchAction');
    } catch (_) {
      return null;
    }
  }

  /// Uygulama bir **USB bellek takılması** yüzünden mi açıldı?
  static Future<bool> launchedByUsb() async =>
      await launchAction() == usbAttachedAction;

  /// Android'in USB takılma eylemi (manifest'teki intent filtresiyle aynı).
  static const usbAttachedAction =
      'android.hardware.usb.action.USB_DEVICE_ATTACHED';

  /// **Android'in kendi depolama birimi listesi** (`StorageManager`).
  ///
  /// Kanal yoksa (masaüstü, test, eski APK) boş döner ve çağıran kendi
  /// `/storage` taramasını kullanır — bkz. `StorageStats.volumes`.
  static Future<List<PlatformVolume>> storageVolumes() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('storageVolumes');
      if (raw == null) return const [];
      return [
        for (final item in raw)
          if (item is Map) PlatformVolume.fromMap(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// **Bağlı birimlerin kökleri** — uygulamaya ait klasörden türetilir.
  ///
  /// `getExternalFilesDirs()` bağlı HER birimde uygulamaya ait bir klasör
  /// döndürür ve o klasör hiçbir izin gerektirmez; `/storage` listelenemeyen
  /// ROM'larda takılı SD/USB'yi yakalamanın en güvenilir yolu budur
  /// (bkz. `ci/MainActivity.kt` → `externalFilesRoots`).
  ///
  /// Kanal yoksa boş liste.
  static Future<List<String>> externalFilesRoots() async {
    try {
      final raw =
          await _channel.invokeMethod<List<dynamic>>('externalFilesRoots');
      return [
        for (final item in raw ?? const [])
          if (item is String && item.isNotEmpty) item,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// **USB takıldı** olayını dinler (native → Dart itmesi).
  ///
  /// Niye gerekli: uygulama zaten ön plandayken Android'in "USB cihazı için
  /// bir uygulama seçin" penceresinden bizi seçmek yeni bir `resumed` yaşam
  /// döngüsü olayı üretmiyor; eylemi yalnız `resumed`da soran kod hiçbir şey
  /// yapmıyordu (kullanıcı 2026-09-02: *"basıyorum tepki vermiyor"*).
  ///
  /// [onChanged] **canlı yayın** (2026-09-03): uygulama önde dururken bir
  /// bellek takılınca/çıkarılınca native taraf (`registerVolumeWatch`) olayı
  /// itiyor. Kullanıcı ölçümü: *"usb takıldığında ana menüde hızlı biçimde
  /// sayfa güncellenip eklenmeli, çok geç düşüyor."* Eskiden tek haber kaynağı
  /// `/storage` klasörünü 5 saniyede bir yoklayan zamanlayıcıydı ve Android
  /// belleği BAĞLAMAMIŞSA o yoklama hiçbir zaman görmüyordu.
  ///
  /// [attached] true = takıldı/bağlandı, false = çıkarıldı.
  static void setUsbAttachedHandler(
    void Function()? onAttached, {
    void Function(bool attached)? onChanged,
  }) {
    if (onAttached == null && onChanged == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'usbAttached':
          onAttached?.call();
        case 'usbChanged':
          final args = call.arguments;
          final attached =
              args is Map ? args['attached'] == true : true;
          onChanged?.call(attached);
      }
      return null;
    });
  }

  // ── SAF (Storage Access Framework) ────────────────────────────────────
  //
  // Android 11+ üzerinde takılabilir belleğe (USB/SD) erişmenin herkese açık
  // yolu: kullanıcı bir kez klasörü seçer, uygulama KALICI izin alır.
  // Ayrıntı ve sınırlar: `ci/MainActivity.kt` içindeki SAF bölümü.

  /// Klasör seçiciyi açar; seçilen ağacın URI'sini döner (vazgeçilirse null).
  ///
  /// [volume] verilirse (birimin UUID'si ya da yolu) seçici **doğrudan o
  /// birimin köküne** konumlanır — kullanıcı hatası 2026-09-02: seçicide
  /// takılı USB'yi bulamıyordu (bkz. `ci/MainActivity.kt` → `pickTreeIntent`).
  static Future<String?> safPickTree({String? volume}) async {
    try {
      return await _channel
          .invokeMethod<String>('safPickTree', {'volume': volume});
    } catch (_) {
      return null;
    }
  }

  /// Daha önce izin verilmiş ağaçlar.
  static Future<List<SafRoot>> safRoots() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('safRoots');
      return [
        for (final item in raw ?? const [])
          if (item is Map) SafRoot.fromMap(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Bir ağacın iznini geri verir (listeden kaldırır).
  static Future<bool> safForget(String uri) async {
    try {
      return await _channel.invokeMethod<bool>('safForget', {'uri': uri}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<SafEntry>> safList(String uri) async {
    try {
      final raw =
          await _channel.invokeMethod<List<dynamic>>('safList', {'uri': uri});
      return [
        for (final item in raw ?? const [])
          if (item is Map) SafEntry.fromMap(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> safCopyToFile(String uri, String dest) async {
    try {
      return await _channel.invokeMethod<bool>(
              'safCopyToFile', {'uri': uri, 'dest': dest}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> safCopyFromFile(
    String parentUri,
    String sourcePath,
    String name, {
    String mime = '',
  }) async {
    try {
      return await _channel.invokeMethod<String>('safCopyFromFile', {
        'parent': parentUri,
        'src': sourcePath,
        'name': name,
        'mime': mime,
      });
    } catch (_) {
      return null;
    }
  }

  static Future<bool> safDelete(String uri) async {
    try {
      return await _channel.invokeMethod<bool>('safDelete', {'uri': uri}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> safMkdir(String parentUri, String name) async {
    try {
      return await _channel.invokeMethod<String>(
          'safMkdir', {'parent': parentUri, 'name': name});
    } catch (_) {
      return null;
    }
  }

  static Future<String?> safRename(String uri, String name) async {
    try {
      return await _channel
          .invokeMethod<String>('safRename', {'uri': uri, 'name': name});
    } catch (_) {
      return null;
    }
  }

  /// Testlerde sahte kanal kurulduktan sonra "yok" damgasını temizler.
  static void resetForTest() => _available = null;
}

/// İzin verilmiş bir SAF ağacı (kullanıcının seçtiği klasör).
class SafRoot {
  final String uri;
  final String name;
  final bool writable;
  const SafRoot({required this.uri, required this.name, this.writable = true});

  factory SafRoot.fromMap(Map<dynamic, dynamic> m) => SafRoot(
        uri: '${m['uri'] ?? ''}',
        name: '${m['name'] ?? '?'}',
        writable: m['writable'] != false,
      );

  /// Ağacın ait olduğu **birimin kimliği** (`1A2B-3C4D`, `primary`) — saf,
  /// testli.
  ///
  /// Ağaç URI'si `…/tree/1A2B-3C4D%3AKlasor` biçimindedir; ilk `:` öncesi
  /// birimin kimliğidir ve bağlama noktasının adıyla aynıdır. Aynı belleği
  /// hem yol hem klasör izniyle görüyorsak panoda İKİ KEZ göstermemek için
  /// gerekiyor.
  ///
  /// Çözümlenemezse boş dize (o zaman eşleştirme yapılmaz, kart çizilir).
  String get volumeId {
    const marker = '/tree/';
    final at = uri.indexOf(marker);
    if (at < 0) return '';
    final id = Uri.decodeComponent(uri.substring(at + marker.length));
    final colon = id.indexOf(':');
    return colon < 0 ? id : id.substring(0, colon);
  }
}

/// SAF ağacındaki bir girdi.
class SafEntry {
  final String uri;
  final String name;
  final bool isDir;
  final int sizeBytes;
  final int modifiedMs;
  final String mime;

  const SafEntry({
    required this.uri,
    required this.name,
    required this.isDir,
    this.sizeBytes = 0,
    this.modifiedMs = 0,
    this.mime = '',
  });

  factory SafEntry.fromMap(Map<dynamic, dynamic> m) => SafEntry(
        uri: '${m['uri'] ?? ''}',
        name: '${m['name'] ?? ''}',
        isDir: m['isDir'] == true,
        sizeBytes: (m['size'] as num?)?.toInt() ?? 0,
        modifiedMs: (m['modified'] as num?)?.toInt() ?? 0,
        mime: '${m['mime'] ?? ''}',
      );
}

/// Android'in bildirdiği bir depolama birimi (`StorageManager.StorageVolume`).
class PlatformVolume {
  /// Birimin dosya yolu; Android vermiyorsa null (bağlanmamış olabilir).
  final String? path;

  /// Kullanıcıya gösterilen ad ("SD kart", "USB sürücü", üretici adı…).
  final String description;

  final bool isPrimary;
  final bool isRemovable;

  /// `mounted`, `unmounted`, `mounted_ro`, `ejecting`… Bağlı değilse birim
  /// FİZİKSEL olarak takılıdır ama kullanılamaz — kullanıcıya "yok" demek
  /// yerine bunu söyleyebiliriz.
  final String state;

  /// Birimin UUID'si (bağlama noktası adıyla aynı olur).
  final String? uuid;

  /// Native taraf yolu GERÇEKTEN listeleyebildi mi?
  ///
  /// [state]e güvenilmez: `StorageVolume.getState()` birimi uygulamaya görünen
  /// listede yolla arar, bulamazsa `unknown` der — bağlı bir USB'de bile.
  /// Dosya sistemi ise yalan söyleyemez (bkz. `ci/MainActivity.kt` →
  /// `readableDir`).
  final bool readable;

  const PlatformVolume({
    this.path,
    this.description = '',
    this.isPrimary = false,
    this.isRemovable = false,
    this.state = '',
    this.uuid,
    this.readable = false,
  });

  factory PlatformVolume.fromMap(Map<dynamic, dynamic> m) => PlatformVolume(
        path: m['path'] as String?,
        description: (m['description'] as String?) ?? '',
        isPrimary: m['isPrimary'] == true,
        isRemovable: m['isRemovable'] == true,
        state: (m['state'] as String?) ?? '',
        uuid: m['uuid'] as String?,
        readable: m['readable'] == true,
      );

  /// Okunabilir durumda mı? (`mounted` ya da salt okunur `mounted_ro`.)
  bool get isMounted => state == 'mounted' || state == 'mounted_ro';

  /// **Kullanılabilir mi?** Android "bağlı" diyorsa ya da yol fiilen
  /// listelenebiliyorsa evet. İkinci koşul şart: durumu `unknown` çıkan bağlı
  /// USB'ler yüzünden kullanıcıya "Takılı değil" diyorduk.
  bool get isUsable => (isMounted || readable) && (path?.isNotEmpty ?? false);

  /// Yalnız okunabiliyor mu?
  bool get isReadOnly => state == 'mounted_ro';
}

/// Kurulu bir uygulamanın diskteki APK dosyaları.
class ApkSource {
  /// `base.apk` — uygulamanın kodu ve manifest'i.
  final String sourcePath;

  /// Bölünmüş parçalar (`split_config.arm64_v8a.apk`, `split_config.tr.apk`…).
  /// Play'den App Bundle olarak kurulan uygulamalarda dolu olur.
  final List<String> splitPaths;

  final String label;
  final String versionName;

  const ApkSource({
    required this.sourcePath,
    this.splitPaths = const [],
    this.label = '',
    this.versionName = '',
  });

  /// Uygulama parçalı mı kurulmuş? (Paylaşma akışının verdiği kararın girdisi:
  /// tek `base.apk` karşı tarafta kurulmayabilir.)
  bool get isSplit => splitPaths.isNotEmpty;

  /// Paylaşılacak bütün dosyalar (temel + parçalar).
  List<String> get allPaths => [sourcePath, ...splitPaths];
}
