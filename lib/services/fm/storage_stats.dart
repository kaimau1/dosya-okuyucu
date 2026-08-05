import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bir depolama birimi (dahili bellek, SD kart, USB).
class StorageVolume {
  final String path;
  final String label;
  final bool isPrimary;
  final int totalBytes;
  final int freeBytes;

  const StorageVolume({
    required this.path,
    required this.label,
    required this.isPrimary,
    this.totalBytes = 0,
    this.freeBytes = 0,
  });

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
        isPrimary: isPrimary,
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

  /// Kullanılabilir birimleri bulur (doluluk bilgisi doldurulmuş olarak).
  static Future<List<StorageVolume>> volumes() async {
    final out = <StorageVolume>[];

    final primary = await primaryRoot();
    if (primary != null) {
      out.add(StorageVolume(
          path: primary, label: 'Ana bellek', isPrimary: true));
    }

    // Takılabilir birimler: /storage altında UUID adlı (ör. 1A2B-3C4D) klasörler.
    try {
      for (final entity in Directory('/storage').listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name == 'emulated' || name == 'self' || name == 'container') {
          continue;
        }
        if (entity is! Directory) continue;
        if (out.any((v) => v.path == entity.path)) continue;
        try {
          entity.listSync().take(1).toList(); // okunabiliyor mu?
        } catch (_) {
          continue;
        }
        out.add(StorageVolume(
          path: entity.path,
          label: _isUuid(name) ? 'SD kart' : name,
          isPrimary: false,
        ));
      }
    } catch (_) {
      // /storage listelenemiyor (emülatör/masaüstü) — birincil yeter
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
