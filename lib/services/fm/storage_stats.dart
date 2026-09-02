import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_storage_service.dart';

/// Bir depolama biriminin TÜRÜ — simge, ad ve "harici belleğe kopyala"
/// kısayolu buna bakar.
enum StorageKind {
  /// Telefonun kendi belleği.
  internal,

  /// Takılabilir hafıza kartı (microSD).
  sdCard,

  /// USB OTG ile takılan bellek / disk.
  usb,
}

/// Bir depolama birimi (dahili bellek, SD kart, USB).
class StorageVolume {
  final String path;

  /// Birimin **ham** adı — dosya sistemindeki karşılığı (ör. `SAMSUNG`).
  /// Kullanıcının verisidir, çevrilmez. [labelKey] doluysa ekranda kullanılmaz.
  final String label;

  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`). Yalnız **tanınan**
  /// birimlerde dolu: ana bellek ve UUID adlı SD kart. Bu dosya saf Dart —
  /// `AppStrings`'i tanımaz, o yüzden metin değil anahtar taşınır.
  ///
  /// Metnin burada tutulmaması bir dil değişiminde de doğru olmasını sağlar:
  /// birim listesi açılışta bir kez kuruluyor, hazır çevrilmiş bir metin
  /// saklansaydı kullanıcı dili değiştirdiğinde eski dilde kalırdı.
  final String? labelKey;

  final bool isPrimary;
  final int totalBytes;
  final int freeBytes;

  /// Birimin türü. USB ile SD kartı ayırmak şart: ikisi de `/storage/<UUID>`
  /// altına bağlanıyor ama kullanıcı için apayrı şeyler — "harici belleğe
  /// kopyala" kısayolu USB'yi (ya da kartı) ADIYLA sunabilsin diye.
  final StorageKind kind;

  const StorageVolume({
    required this.path,
    required this.isPrimary,
    this.label = '',
    this.labelKey,
    this.totalBytes = 0,
    this.freeBytes = 0,
    this.kind = StorageKind.internal,
    this.nameSuffix = '',
  });

  /// Telefonun kendi belleği DIŞINDA bir birim mi? ("Harici belleğe kopyala"
  /// tam olarak bunları hedefler.)
  bool get isRemovable => kind != StorageKind.internal;

  /// Ekranda kullanılacak Material simge adı — arayüz katmanı bunu
  /// `IconData`ya çevirir (bu dosya saf Dart, `material` içe aktarmaz).
  String get iconName => switch (kind) {
        StorageKind.internal => 'smartphone',
        StorageKind.sdCard => 'sd_card',
        StorageKind.usb => 'usb',
      };

  /// Yazılabilir mi? Salt okunur bağlanmış bir birime kopyalamayı önermek
  /// kullanıcıyı boşuna uğraştırırdı.
  bool get isWritable {
    try {
      final probe = File(p.join(path, '.dosyaokuyucu_write_test'));
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Aynı ada düşen ikinci/üçüncü birimi ayırt eden ek (bağlama noktası adı,
  /// ör. `1A2B-3C4D`). Boşsa ek yok. Bkz. [StorageStats.disambiguate].
  final String nameSuffix;

  /// Ekranda gösterilecek ad. [t] genelde `context.t`.
  String displayLabel(String Function(String) t) {
    final base = labelKey == null ? label : t(labelKey!);
    return nameSuffix.isEmpty ? base : '$base ($nameSuffix)';
  }

  StorageVolume withSuffix(String suffix) => StorageVolume(
        path: path,
        label: label,
        labelKey: labelKey,
        isPrimary: isPrimary,
        kind: kind,
        totalBytes: totalBytes,
        freeBytes: freeBytes,
        nameSuffix: suffix,
      );

  /// **Cihazın üstünde yazan** kapasite (512 GB gibi) — `df`in verdiği dosya
  /// sistemi boyutu değil.
  ///
  /// `df` yalnız `/data` bölümünü ölçer; sistem, vendor ve ayrılmış bloklar
  /// dışarıda kalır, o yüzden 512 GB'lık bir telefonda 464 GiB görünür.
  /// Android'in kendisi de (Ayarlar → Depolama, `StorageStatsManager`)
  /// kullanıcıya bu ham sayıyı DEĞİL yuvarlanmış reklam kapasitesini gösterir
  /// — bkz. [advertisedSize]. Diğer dosya yöneticileri de öyle yapıyor;
  /// bizim "464 GB" demenizin nedeni buydu.
  int get capacityBytes => advertisedSize(totalBytes);

  /// Kullanılan = reklam kapasitesi − GERÇEK boş alan.
  ///
  /// Boş alan yuvarlanmaz: kullanıcıya olduğundan fazla yer varmış gibi
  /// göstermek, dolduramayacağı bir alana güvenmesine yol açardı. Aradaki
  /// fark (sistem bölümleri) "kullanılan" tarafında görünür — Android
  /// Ayarlar'ın davranışı da budur.
  int get usedBytes => (capacityBytes - freeBytes).clamp(0, capacityBytes);
  bool get hasStats => totalBytes > 0;
  double get usedFraction => capacityBytes <= 0
      ? 0
      : (usedBytes / capacityBytes).clamp(0, 1).toDouble();

  /// AOSP `android.os.FileUtils#roundStorageSize` birebir karşılığı: boyutu
  /// 1,2,4…512 × 1000ⁿ dizisindeki bir sonraki değere yuvarlar.
  ///
  /// `StorageStatsManager.getTotalBytes()` de tam olarak bunu yapıyor; saf
  /// Dart'a taşımak, yalnız bu sayı için bir platform kanalı eklemekten
  /// (CI `android/` iskelesini her derlemede yeniden üretiyor) çok daha ucuz.
  static int advertisedSize(int bytes) {
    if (bytes <= 0) return 0;
    var val = 1;
    var pow = 1;
    while (val * pow < bytes) {
      val <<= 1;
      if (val > 512) {
        val = 1;
        pow *= 1000;
      }
    }
    return val * pow;
  }

  StorageVolume copyWith({int? totalBytes, int? freeBytes}) => StorageVolume(
        path: path,
        label: label,
        labelKey: labelKey,
        isPrimary: isPrimary,
        kind: kind,
        totalBytes: totalBytes ?? this.totalBytes,
        freeBytes: freeBytes ?? this.freeBytes,
        nameSuffix: nameSuffix,
      );
}

/// Depolama birimlerini bulur ve doluluk bilgisini okur.
///
/// **Karar — `df` çıktısını okuyoruz, yeni bir eklenti EKLENMEDİ:** Dart'ta
/// `statfs` yok; mevcut pub çözümleri (disk_space*) bakımsız ve tek amaç için
/// bir platform kanalı eklemek CI'daki Flutter 3.29.3 iskelesini (android/
/// klasörü CI'da üretiliyor) kırılganlaştırırdı. `df` Android'de
/// `/system/bin/df` (toybox) olarak her cihazda var ve uygulamadan
/// çalıştırılabilir. Okunamazsa doluluk çubuğu gizlenir, dosya yöneticisinin
/// geri kalanı çalışmaya devam eder (zarif düşüş).
abstract final class StorageStats {
  /// Android'de birincil depolamanın klasik yolu.
  static const primaryPath = '/storage/emulated/0';

  /// Takılabilir birimlerin bağlandığı KÖKLER.
  ///
  /// `/storage` her cihazda var; `/mnt/media_rw` (Android'in ham bağlama
  /// noktası) ve `/mnt/usb` (bazı üreticilerin USB OTG yolu) yedek. Birden
  /// çok kök aynı aygıtı gösterebilir; aynı **temel ad** iki kez eklenmez.
  static const removableRoots = ['/storage', '/mnt/media_rw', '/mnt/usb'];

  /// Kullanılabilir birimleri bulur (doluluk bilgisi doldurulmuş olarak).
  static Future<List<StorageVolume>> volumes() async {
    final out = <StorageVolume>[];

    final primary = await primaryRoot();
    if (primary != null) {
      out.add(StorageVolume(
          path: primary, labelKey: 'fm.vol_internal', isPrimary: true));
    }

    // Bağlama tablosu: USB'yi SD karttan ancak bu ayırt eder (ikisi de
    // `/storage/<UUID>` altına bağlanıyor). Okunamazsa tür tahmini yapılır.
    final mounts = readMounts();

    final seen = <String>{for (final v in out) p.basename(v.path)};

    // **ÖNCE ANDROID'E SOR** (kullanıcı hatası 2026-09-02: USB takılıyken
    // uygulama "Takılı harici bellek yok" diyordu).
    //
    // `/storage` altını listeleyerek tahmin etmek SD kartta çalışıyor ama USB
    // OTG'de üreticiye göre değişiyor: kimi ROM `/storage/<UUID>`e bağlıyor,
    // kimi uygulamaya kapalı `/mnt/media_rw/<UUID>`ye, kimi hiç bağlamıyor.
    // `StorageManager` işletim sisteminin GERÇEK listesidir; tahmin yerine
    // onu kullanıyoruz ve yol taraması yalnız yedek olarak kalıyor
    // (masaüstü, test, kanalın olmadığı eski APK).
    for (final pv in await AppStorageService.storageVolumes()) {
      final path = pv.path;
      if (path == null || path.isEmpty) continue;
      if (pv.isPrimary) continue; // birincil zaten yukarıda eklendi
      // **`state`e TEK BAŞINA güvenilmez** (kullanıcı hatası 2026-09-02):
      // `StorageVolume.getState()` birimi uygulamaya görünen listede yolla
      // arıyor, bulamazsa `unknown` diyor — bağlı bir USB'de bile. Elemeyi
      // duruma bakarak yapınca başka dosya yöneticilerinin listelediği belleğe
      // biz "Takılı değil" diyorduk. Artık son söz DOSYA SİSTEMİNİN:
      // durumu iyi DEĞİLSE bile yol listelenebiliyorsa birim vardır.
      if (!pv.isUsable && !canList(path)) continue;
      if (out.any((v) => v.path == path)) continue;
      if (!seen.add(p.basename(path))) continue;
      if (!canList(path)) continue; // gezilemeyen birim listeye girmez
      final kind = kindOf(path, mounts);
      // Android'in verdiği ad ("USB sürücü", "SAMSUNG") UUID'den iyidir;
      // yoksa türe göre çevrilen ada düşülür.
      final described = pv.description.trim();
      final anonymous = described.isEmpty || _isUuid(described);
      out.add(StorageVolume(
        path: path,
        label: anonymous ? '' : described,
        labelKey: anonymous
            ? (kind == StorageKind.usb ? 'fm.vol_usb' : 'fm.vol_sdcard')
            : null,
        isPrimary: false,
        kind: kind,
      ));
    }

    // **İZİN GEREKTİRMEYEN kanal:** uygulamanın kendi klasörü bağlı her
    // birimde vardır (`/storage/<UUID>/Android/data/<paket>/files`), o yüzden
    // `/storage` listelenemeyen ROM'larda bile birimi buradan yakalıyoruz.
    // Bağlama tablosu da (aynı `mount` çıktısı) ayrıca taranıyor: kimi ROM
    // belleği `/mnt/usb/...` gibi `/storage` dışına bağlıyor.
    final extra = <String>[
      ...await AppStorageService.externalFilesRoots(),
      ...removableMountPoints(mounts),
    ];
    for (final path in extra) {
      if (path == primary) continue;
      if (out.any((v) => v.path == path)) continue;
      final name = p.basename(path);
      if (name == 'emulated' || name == 'self' || name == 'container') continue;
      if (!canList(path)) continue;
      if (!seen.add(name)) continue;
      final kind = kindOf(path, mounts);
      final anonymous = _isUuid(name);
      out.add(StorageVolume(
        path: path,
        label: anonymous ? '' : name,
        labelKey: anonymous
            ? (kind == StorageKind.usb ? 'fm.vol_usb' : 'fm.vol_sdcard')
            : null,
        isPrimary: false,
        kind: kind,
      ));
    }

    for (final root in removableRoots) {
      for (final entity in entriesOf(root)) {
        final name = p.basename(entity.path);
        if (name == 'emulated' || name == 'self' || name == 'container') {
          continue;
        }
        if (entity is! Directory) continue;
        if (out.any((v) => v.path == entity.path)) continue;
        if (!seen.add(name)) continue; // aynı aygıt başka kökten eklendi
        try {
          entity.listSync().take(1).toList(); // okunabiliyor mu?
        } catch (_) {
          continue;
        }
        final kind = kindOf(entity.path, mounts);
        // UUID adlı birim takılabilir bir aygıttır ve "1A2B-3C4D" kullanıcıya
        // hiçbir şey anlatmaz → çevrilen ad. Adı olan birim kendi adıyla
        // gösterilir (o ad kullanıcının verisi, çevrilmez).
        final anonymous = _isUuid(name);
        out.add(StorageVolume(
          path: entity.path,
          label: anonymous ? '' : name,
          labelKey: anonymous
              ? (kind == StorageKind.usb ? 'fm.vol_usb' : 'fm.vol_sdcard')
              : null,
          isPrimary: false,
          kind: kind,
        ));
      }
    }

    // Doluluk bilgisini doldur.
    final filled = <StorageVolume>[];
    for (final v in out) {
      final usage = await usageOf(v.path);
      filled.add(usage == null
          ? v
          : v.copyWith(totalBytes: usage.$1, freeBytes: usage.$2));
    }
    return disambiguate(filled);
  }

  /// **Aynı ada düşen birimleri ayırt eder** — saf fonksiyon (birim testli).
  ///
  /// Kullanıcı sorusu 2026-09-02: *"2 tane SD kart, 2 tane USB takılırsa ne
  /// olacak?"* UUID adlı birimlerin adı çeviriden geliyor ("SD kart"); iki
  /// kart takılınca listede yan yana iki "SD kart" duruyordu ve hangisinin
  /// hangisi olduğu ANLAŞILMIYORDU — üstelik "harici belleğe kopyala"da
  /// yanlışını seçmek işten değildi.
  ///
  /// Çözüm: aynı ada düşen birimlerin ikincisinden itibaren bağlama noktası
  /// adı (UUID) eklenir → "SD kart (1A2B-3C4D)". Tek başına duran birim
  /// dokunulmadan kalır: çoğu kullanıcı tek kart takıyor ve ona UUID
  /// göstermek gereksiz gürültü olurdu.
  ///
  /// Adı olan birimler (etiketli USB: "SAMSUNG") zaten ayrık; onlara da aynı
  /// kural uygulanır, çünkü iki özdeş marka bellek aynı etiketi taşıyabilir.
  static List<StorageVolume> disambiguate(List<StorageVolume> volumes) {
    final counts = <String, int>{};
    for (final v in volumes) {
      final key = v.labelKey ?? 'label:${v.label}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return [
      for (final v in volumes)
        if ((counts[v.labelKey ?? 'label:${v.label}'] ?? 0) > 1)
          v.withSuffix(p.basename(v.path))
        else
          v,
    ];
  }

  /// Bir kökün girdileri; kök yoksa ya da OKUNAMIYORSA boş liste.
  ///
  /// **TUZAK — `existsSync()` de fırlatır (kullanıcı çökmesi 2026-09-02):**
  /// `/mnt/media_rw` telefonda VAR ama `media_rw` grubuna ait; uygulama `/mnt`
  /// içinde gezinemediği için `Directory('/mnt/media_rw').existsSync()`
  /// `false` DÖNMÜYOR, `FileSystemException: Exists failed … Permission
  /// denied (errno = 13)` fırlatıyor. O çağrı `try`nin dışında kaldığı için
  /// `volumes()` çöküyor, `FmEnv.ensureInit` çöküyor ve dosya yöneticisi
  /// "Depolama taranıyor…" ekranında asılı kalıyordu.
  ///
  /// Bu yüzden varlık denetimi ve listeleme TEK yerde ve tek `try` içinde:
  /// çağıranın ayrıca korunmasına gerek yok, unutması da mümkün değil.
  static List<FileSystemEntity> entriesOf(String root) {
    try {
      final dir = Directory(root);
      if (!dir.existsSync()) return const [];
      return dir.listSync(followLinks: false);
    } catch (_) {
      // Yok, okunamıyor ya da varlığı bile sorulamıyor — bu kök yok sayılır.
      return const [];
    }
  }

  /// Yol GERÇEKTEN gezilebiliyor mu? (varlık denetimi de fırlatabilir —
  /// bkz. [entriesOf]; bu yüzden tek `try` içinde.)
  static bool canList(String path) {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) return false;
      dir.listSync(followLinks: false).take(1).toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// `Directory.existsSync` **fırlatabilir** (izin verilmeyen kökte EACCES) —
  /// hata kaydı 2026-09-02: dosya yöneticisi bu yüzden komple düşmüştü.
  /// Varlık denetimi her yerde bu kapıdan geçiyor.
  static bool dirExists(String path) {
    try {
      return Directory(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// **Bağlama tablosundaki takılabilir birimler** — saf fonksiyon (testli).
  ///
  /// `/proc/mounts` her Linux'ta okunabilir ve bir birim GERÇEKTEN bağlıysa
  /// orada görünür; `/storage` klasörünü listeleyememek ya da
  /// `StorageManager`ın `unknown` demesi bunu değiştirmez. Yalnız
  /// [removableRoots] altındaki TEK parçalı bağlama noktaları döner
  /// (`/storage/1A2B-3C4D` evet, `/storage/emulated/0` hayır).
  static List<String> removableMountPoints(List<String> mounts) {
    final out = <String>[];
    for (final line in mounts) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      // `/proc/mounts` boşlukları `\040` olarak kaçırır.
      final point = parts[1].replaceAll(r'\040', ' ');
      for (final root in removableRoots) {
        if (!point.startsWith('$root/')) continue;
        final rest = point.substring(root.length + 1);
        if (rest.isEmpty || rest.contains('/')) continue;
        if (rest == 'emulated' || rest == 'self' || rest == 'container') break;
        if (!out.contains(point)) out.add(point);
        break;
      }
    }
    return out;
  }

  /// `/proc/mounts` satırları (okunamazsa boş).
  ///
  /// Niye ham dosya: `mount` komutu her ROM'da çalıştırılamıyor ama
  /// `/proc/mounts` her Linux'ta okunabilir ve tek `readAsStringSync`.
  static List<String> readMounts() {
    for (final path in const ['/proc/mounts', '/proc/self/mounts']) {
      try {
        final text = File(path).readAsStringSync();
        if (text.trim().isNotEmpty) return text.split('\n');
      } catch (_) {
        // sıradaki yolu dene
      }
    }
    return const [];
  }

  /// Bir bağlama noktasının TÜRÜ — **saf fonksiyon** (birim testli).
  ///
  /// Karar zinciri, en güvenilirden en zayıfa:
  /// 1. Bağlama tablosunda bu noktayı besleyen AYGIT adı: `/dev/block/sd*`
  ///    ya da `vold/public:8,*` → USB (SCSI/USB yığın depolama);
  ///    `mmcblk*` / `vold/public:179,*` → SD kart (MMC).
  /// 2. Yol `/mnt/usb` altındaysa → USB.
  /// 3. Hiçbiri değilse SD kart varsayılır: bugüne kadarki davranış buydu ve
  ///    yanlış tahminin bedeli yalnız simge/ad.
  static StorageKind kindOf(String mountPoint, List<String> mounts) {
    final name = p.basename(mountPoint);
    for (final line in mounts) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final device = parts[0];
      // **Aynı aygıt iki noktada durur** (kullanıcı ölçümü 2026-09-02):
      // `/mnt/media_rw/8A07-470A` (gerçek aygıt: `/dev/block/vold/public:8,1`
      // → USB) ve `/storage/8A07-470A` (`/dev/fuse` — tür bilgisi YOK).
      // Yalnız tam eşleşme arayınca fuse satırı bulunuyor, aygıt adı hiçbir
      // şey söylemiyor ve USB bellek "SD kart" olarak etiketleniyordu.
      // Temel ad eşleşmesi ikisini de aynı aygıt sayar; tam eşleşme yine
      // önce denenir.
      final exact = parts[1] == mountPoint;
      if (!exact && (name.isEmpty || p.basename(parts[1]) != name)) continue;
      final vold = RegExp(r'/dev/block/vold/public:(\d+),').firstMatch(device);
      if (vold != null) {
        // 179 = MMC (SD kart), 8 = SCSI disk (USB yığın depolama).
        final major = int.tryParse(vold.group(1)!);
        if (major == 179) return StorageKind.sdCard;
        if (major == 8) return StorageKind.usb;
      }
      if (RegExp(r'/dev/block/(sd[a-z]|sr\d)').hasMatch(device)) {
        return StorageKind.usb;
      }
      if (device.contains('mmcblk')) return StorageKind.sdCard;
    }
    if (mountPoint.startsWith('/mnt/usb')) return StorageKind.usb;
    return StorageKind.sdCard;
  }

  /// Birincil depolamanın kökü. Önce klasik yol, olmazsa uygulamanın harici
  /// klasöründen (`…/Android/data/<paket>/files`) türetilir, o da yoksa
  /// uygulama belgeler klasörü (masaüstü/test).
  static Future<String?> primaryRoot() async {
    if (dirExists(primaryPath)) return primaryPath;
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final idx = ext.path.indexOf('/Android/');
        if (idx > 0) return ext.path.substring(0, idx);
        return ext.path;
      }
    } catch (_) {}
    try {
      return (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      return null;
    }
  }

  /// (toplam, boş) bayt. Okunamazsa null.
  static Future<(int, int)?> usageOf(String path) async {
    for (final exe in const ['df', '/system/bin/df']) {
      try {
        final r = await Process.run(exe, ['-k', path]);
        if (r.exitCode != 0) continue;
        final parsed = parseDf(r.stdout.toString());
        if (parsed != null) return parsed;
      } catch (_) {
        // exec yok/izin yok → sıradaki yolu dene
      }
    }
    return null;
  }

  /// `df -k <yol>` çıktısını (toplam, boş) bayt çiftine çevirir.
  ///
  /// Saf fonksiyon (birim testli). Uzun aygıt adı satırı kaydırdığında da
  /// çalışsın diye başlık satırından SONRAKİ tüm sayısal alanlar toplanır:
  /// `[toplam, kullanılan, boş]` sırası df'te evrenseldir.
  static (int, int)? parseDf(String output) {
    final lines = output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return null;
    final numbers = <int>[];
    for (final line in lines.skip(1)) {
      for (final token in line.split(RegExp(r'\s+'))) {
        final n = int.tryParse(token);
        if (n != null) numbers.add(n);
      }
      if (numbers.length >= 3) break;
    }
    if (numbers.length < 3) return null;
    const kb = 1024;
    final total = numbers[0] * kb;
    final free = numbers[2] * kb;
    if (total <= 0) return null;
    return (total, free);
  }

  static bool _isUuid(String name) =>
      RegExp(r'^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$').hasMatch(name);

  /// **Sıcak klasörler** — "yeni dosya buraya düşer" denebilecek ağaçlar.
  /// `FsScan.freshFiles` bu listeyi gezer ("Yeni Dosyalar" ekranı ve panonun
  /// yakalama taraması).
  ///
  /// **Kök neden — 2026-08-27 kullanıcı hatası:** *"yeni dosyalarda örnek ekran
  /// görüntüsündeki 660 EVLER dosyası yeni olmasına rağmen yok"*. O dosyanın
  /// yolu `/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/
  /// WhatsApp Documents/…`. Sıcak klasör listesi [standardFolders] idi ve
  /// oradaki WhatsApp girdisi **kökteki eski** `/storage/emulated/0/WhatsApp`
  /// klasörünü arıyor. Android 11 kapsamlı depolamadan beri WhatsApp (ve
  /// Telegram, Signal, Viber…) medyasını `Android/media/<paket>/` altına
  /// yazıyor; o klasör hiçbir zaman taranmıyordu. Tam tarama ağacın tamamını
  /// gezdiği için dosya "Belgeler" kategorisinde GÖRÜNÜYOR, ama 12 saatte bir
  /// koşan o tarama arasında gelen her mesaj eki "Yeni Dosyalar"a hiç
  /// düşmüyordu — kullanıcının gördüğü çelişki tam olarak buydu.
  ///
  /// `Android/media` tek kök olarak veriliyor: altındaki her paket klasörü
  /// yürüyüşe kendiliğinden giriyor, yeni bir mesajlaşma uygulaması kurulunca
  /// listeyi güncellemek gerekmiyor. (`Android/data` ve `Android/obb` DEĞİL —
  /// onlar Android 11'den beri okunamıyor, denemek yalnız yavaşlatır.)
  /// **Bütün birimlerin** sıcak klasörleri (ana bellek + SD kart + USB).
  ///
  /// Kullanıcı 2026-09-02: *"SD kart desteği olan telefonlarda uyumumuz yok,
  /// SD kartı kullananlar ne yapacak."* "Yeni Dosyalar" ve panonun yakalama
  /// taraması yalnız `primaryRoot`un sıcak klasörlerini geziyordu; kamerası
  /// SD karta çeken bir telefonda yeni fotoğraflar oraya düşüyor ve listede
  /// HİÇ görünmüyordu.
  ///
  /// Takılabilir bir birimde standart klasör olmayabilir (USB'de DCIM yok);
  /// o zaman birimin KÖKÜ sıcak klasör sayılır — dosyalar oraya atılır.
  static List<String> hotFoldersForAll(List<String> roots) {
    final out = <String>[];
    for (final root in roots) {
      final folders = hotFolders(root);
      if (folders.isEmpty) {
        if (dirExists(root)) out.add(root);
        continue;
      }
      for (final f in folders) {
        if (!out.contains(f)) out.add(f);
      }
    }
    return out;
  }

  static List<String> hotFolders(String root) {
    final out = <String>[
      for (final f in standardFolders(root)) f.path,
    ];
    // Kapsamlı depolama sonrası mesajlaşma/medya uygulamalarının yazdığı yer.
    const extras = ['Android/media', 'Telegram', 'Bluetooth', 'Recordings'];
    for (final rel in extras) {
      final path = p.join(root, p.joinAll(rel.split('/')));
      if (out.contains(path)) continue;
      if (dirExists(path)) out.add(path);
    }
    return out;
  }

  /// Kullanıcıya gösterilecek standart klasörler (varsa).
  static List<({String label, String path, String icon})> standardFolders(
      String root) {
    const candidates = [
      ('İndirilenler', 'Download', 'download'),
      ('Belgeler', 'Documents', 'document'),
      ('Kamera', 'DCIM', 'camera'),
      ('Resimler', 'Pictures', 'image'),
      ('Müzik', 'Music', 'audio'),
      ('Filmler', 'Movies', 'video'),
      ('WhatsApp', 'WhatsApp', 'chat'),
    ];
    final out = <({String label, String path, String icon})>[];
    for (final (label, dir, icon) in candidates) {
      final path = p.join(root, dir);
      if (dirExists(path)) {
        out.add((label: label, path: path, icon: icon));
      }
    }
    return out;
  }
}
