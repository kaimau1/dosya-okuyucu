import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  /// Ekranda gösterilecek ad. [t] genelde `context.t`.
  String displayLabel(String Function(String) t) =>
      labelKey == null ? label : t(labelKey!);

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
    for (final root in removableRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } catch (_) {
        continue; // kök listelenemiyor (izin yok) — sıradaki köke geç
      }
      for (final entity in entries) {
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
    return filled;
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
    for (final line in mounts) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final device = parts[0];
      // Bağlama noktası TAM eşleşmeli: `/storage/1A2B` ile `/storage/1A2B-3C4D`
      // karışmasın.
      if (parts[1] != mountPoint) continue;
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
    if (Directory(primaryPath).existsSync()) return primaryPath;
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
  static List<String> hotFolders(String root) {
    final out = <String>[
      for (final f in standardFolders(root)) f.path,
    ];
    // Kapsamlı depolama sonrası mesajlaşma/medya uygulamalarının yazdığı yer.
    const extras = ['Android/media', 'Telegram', 'Bluetooth', 'Recordings'];
    for (final rel in extras) {
      final path = p.join(root, p.joinAll(rel.split('/')));
      if (out.contains(path)) continue;
      if (Directory(path).existsSync()) out.add(path);
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
      if (Directory(path).existsSync()) {
        out.add((label: label, path: path, icon: icon));
      }
    }
    return out;
  }
}
