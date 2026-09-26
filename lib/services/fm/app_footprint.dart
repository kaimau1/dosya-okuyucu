import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'disk_housekeeping.dart';

/// Uygulamanın kendi klasörlerinde yer tutan şeylerin türü.
enum FootprintBucket {
  /// "Birlikte aç" / paylaş ile gelen dosyaların KOPYASI (önbellek kökü).
  shared('foot.shared', 'foot.shared_sub', clearable: true),

  /// Dosya seçicinin kopyaları (`cache/file_picker`).
  picker('foot.picker', 'foot.picker_sub', clearable: true),

  /// Video/PDF küçük resimleri, APK simgeleri.
  thumbs('foot.thumbs', 'foot.thumbs_sub', clearable: true),

  /// Diğer geçici dosyalar (tarama ara kareleri, arşiv önizlemeleri…).
  temp('foot.temp', 'foot.temp_sub', clearable: true),

  /// Google Drive'dan açılan dosyaların yerel kopyaları.
  drive('foot.drive', 'foot.drive_sub', clearable: true),

  /// İndirilen çeviri dil modelleri (ML Kit, dil başına ~30 MB).
  models('foot.models', 'foot.models_sub', clearable: true),

  /// Uygulamanın İÇİNE kaydedilmiş belgeler (eski taramalar, yeni belgeler).
  /// Kullanıcının verisidir — "temizle" ONA dokunmaz.
  docs('foot.docs', 'foot.docs_sub', clearable: false),

  /// Ayarlar, dizinler, geçmiş, WebView verisi…
  other('foot.other', 'foot.other_sub', clearable: false);

  final String labelKey;
  final String subKey;
  final bool clearable;

  const FootprintBucket(this.labelKey, this.subKey, {required this.clearable});
}

/// Uygulamanın özel klasörlerinin yeri (Android: `/data/user/0/<paket>/…`).
class FootprintRoots {
  /// Veri klasörünün kökü — ötekilerin ortak üstü.
  final String dataDir;

  /// `getTemporaryDirectory()` → Android'de `cache/`.
  final String cacheDir;

  /// `getApplicationSupportDirectory()` → Android'de `files/`.
  final String supportDir;

  /// `getApplicationDocumentsDirectory()` → Android'de `app_flutter/`.
  final String docsDir;

  const FootprintRoots({
    required this.dataDir,
    required this.cacheDir,
    required this.supportDir,
    required this.docsDir,
  });

  /// Cihazdaki gerçek yollar — **yalnız Android'de**, başka yerde null.
  ///
  /// Masaüstünde bu klasörler uygulamaya AİT DEĞİL: `getTemporaryDirectory`
  /// Linux'ta `/tmp`, Windows'ta `%TEMP%`; belgeler klasörü kullanıcının
  /// kendi "Belgeler"i. Oraları "bizim önbelleğimiz" sayıp temizlemek başka
  /// programların dosyalarını silmek olurdu.
  static Future<FootprintRoots?> resolve() async {
    if (!Platform.isAndroid) return null;
    try {
      final support = (await getApplicationSupportDirectory()).path;
      final cache = (await getTemporaryDirectory()).path;
      final docs = (await getApplicationDocumentsDirectory()).path;
      return FootprintRoots(
        dataDir: p.dirname(support),
        cacheDir: cache,
        supportDir: support,
        docsDir: docs,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Ölçüm sonucu: kova → bayt.
class FootprintReport {
  final Map<FootprintBucket, int> bytes;

  const FootprintReport(this.bytes);

  int of(FootprintBucket b) => bytes[b] ?? 0;

  int get total => bytes.values.fold(0, (a, b) => a + b);

  int get clearable => [
        for (final e in bytes.entries)
          if (e.key.clearable) e.value,
      ].fold(0, (a, b) => a + b);
}

/// **Uygulamanın kapladığı alanın kırılımı ve temizliği.**
///
/// KÖK NEDEN (2026-09-26, kullanıcı: *"uygulamamız yüklenince 550 MB
/// okuyor"*): APK 93,5 MB (arm64); ayarlardaki toplamın geri kalanı VERİ ve
/// ÖNBELLEK. Ölçülmeden bilinen üç büyüme yolu vardı ve üçünün de sınırı
/// yoktu:
/// * `receive_sharing_intent` "Birlikte aç"/paylaş ile gelen HER dosyanın
///   tamamını `cache/` köküne kopyalıyor (WhatsApp'tan açılan 200 MB'lık bir
///   video = önbellekte 200 MB) ve hiç silmiyordu;
/// * `file_picker` seçilen her dosyayı `cache/file_picker/<zaman>/` altına
///   kopyalıyor, o da hiç silinmiyordu;
/// * Drive önbelleği 400 MB'a kadar `files/` altında (Android'in "önbelleği
///   temizle"si ona dokunmaz).
/// Ayrıca yeni taramalar/belgeler uygulamanın İÇİNE (`app_flutter/`)
/// kaydediliyordu — kullanıcı verisi "uygulama verisi" sayılıyordu.
///
/// Bu sınıf kullanıcıya NEREDE ne kadar yer tutulduğunu gösterir (tahmin
/// değil, klasör ölçümü) ve güvenli kovaları temizler. Saf `dart:io`: testte
/// geçici bir klasör ağacıyla sınanır.
abstract final class AppFootprint {
  /// Önbellek kökünde BİZİM küçük resim klasörlerimiz.
  static const thumbDirs = {'video_thumbs', 'pdf_thumbs', 'apk_icons'};

  /// Dosya seçicinin klasörü (eklentinin sabit adı).
  static const pickerDir = 'file_picker';

  /// Drive önbelleği (`DriveCache.rootOf`) — `files/` altında.
  static const driveDir = 'drive';

  /// Temizlik bu kadar yeni girdilere dokunmaz: o an açık bir belgenin ya da
  /// süren bir işin dosyası olabilir.
  static const minAge = Duration(minutes: 10);

  /// ML Kit'in model klasörü mü? (Yol adında `mlkit` geçer.)
  static bool isModelPath(String name) => name.toLowerCase().contains('mlkit');

  /// Önbellek kökündeki bir girdinin kovası.
  static FootprintBucket cacheBucketOf(String name, {required bool isDir}) {
    if (isDir) {
      if (name == pickerDir) return FootprintBucket.picker;
      if (thumbDirs.contains(name)) return FootprintBucket.thumbs;
      if (isModelPath(name)) return FootprintBucket.models;
      return FootprintBucket.temp;
    }
    // Kökteki DOSYA: bizim ürettiğimiz bir ara dosya değilse eklentinin
    // (paylaşım) kopyasıdır.
    return TempSweep.isOwn(name, isDirectory: false)
        ? FootprintBucket.temp
        : FootprintBucket.shared;
  }

  // ── ölçüm ────────────────────────────────────────────────────────────────

  static int sizeOf(FileSystemEntity e) {
    try {
      if (e is File) return e.lengthSync();
      if (e is! Directory) return 0;
      var total = 0;
      for (final child in e.listSync(recursive: true, followLinks: false)) {
        if (child is File) {
          try {
            total += child.lengthSync();
          } catch (_) {}
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static List<FileSystemEntity> _list(String dir) {
    try {
      final d = Directory(dir);
      if (!d.existsSync()) return const [];
      return d.listSync(followLinks: false);
    } catch (_) {
      return const [];
    }
  }

  static FootprintReport measureSync(FootprintRoots roots) {
    final out = <FootprintBucket, int>{};
    void add(FootprintBucket b, int n) => out[b] = (out[b] ?? 0) + n;
    final seen = <String>{};

    // 1) önbellek
    for (final e in _list(roots.cacheDir)) {
      add(cacheBucketOf(p.basename(e.path), isDir: e is Directory), sizeOf(e));
    }
    seen.add(p.normalize(roots.cacheDir));

    // 2) uygulama belgeleri (kullanıcı verisi)
    if (Directory(roots.docsDir).existsSync()) {
      add(FootprintBucket.docs, sizeOf(Directory(roots.docsDir)));
    }
    seen.add(p.normalize(roots.docsDir));

    // 3) files/: Drive önbelleği, modeller, gerisi
    for (final e in _list(roots.supportDir)) {
      final name = p.basename(e.path);
      final b = name == driveDir && e is Directory
          ? FootprintBucket.drive
          : isModelPath(name)
              ? FootprintBucket.models
              : FootprintBucket.other;
      add(b, sizeOf(e));
    }
    seen.add(p.normalize(roots.supportDir));

    // 4) veri kökünün geri kalanı (no_backup, app_webview, databases…).
    //    Veri kökü `files/`in kendisiyse (masaüstü) zaten sayıldı.
    final rest = p.equals(roots.dataDir, roots.supportDir)
        ? const <FileSystemEntity>[]
        : _list(roots.dataDir);
    for (final e in rest) {
      if (seen.contains(p.normalize(e.path))) continue;
      if (e is Directory) {
        // ML Kit modelleri `no_backup/` gibi bir klasörün içinde olabilir:
        // bir alt düzey aşağıya bakılır.
        for (final child in _list(e.path)) {
          add(
              isModelPath(p.basename(child.path)) ||
                      isModelPath(p.basename(e.path))
                  ? FootprintBucket.models
                  : FootprintBucket.other,
              sizeOf(child));
        }
      } else {
        add(FootprintBucket.other, sizeOf(e));
      }
    }
    return FootprintReport(out);
  }

  /// [measureSync]'in izolatta çalışanı (büyük önbellekte ana izlek donmaz).
  static Future<FootprintReport> measure(FootprintRoots roots) async {
    try {
      return await Isolate.run(() => measureSync(roots));
    } catch (_) {
      return const FootprintReport({});
    }
  }

  // ── temizlik ─────────────────────────────────────────────────────────────

  /// [buckets] kovalarındaki DOSYALARI siler; boşaltılan baytı döner.
  ///
  /// * [FootprintBucket.models] burada SİLİNMEZ — modeller ML Kit'in kendi
  ///   kaydında da duruyor, klasörü altından silmek ona "var" dedirtip
  ///   çeviriyi kırardı. Onları `TranslateService.deleteDownloadedModels`
  ///   siler.
  /// * [keep] içindeki yollara (ve onları içeren klasörlere) dokunulmaz —
  ///   yarıda kalmış PDF düzenlemesinin yedeği gibi.
  /// * [minAge]'den yeni girdiler atlanır.
  static int cleanSync(
    FootprintRoots roots,
    Set<FootprintBucket> buckets, {
    required int nowMs,
    Set<String> keep = const {},
  }) {
    final cutoff = nowMs - minAge.inMilliseconds;
    final keepNorm = {for (final k in keep) p.normalize(k)};
    var freed = 0;

    bool young(FileSystemEntity e) {
      try {
        return e.statSync().modified.millisecondsSinceEpoch > cutoff;
      } catch (_) {
        return true;
      }
    }

    // Klasörü değil İÇİNDEKİLERİ tek tek siler; klasör ancak boşalınca
    // gider. Böylece yeni ya da korunan bir dosya kendi klasörünü ayakta
    // tutar.
    void wipe(FileSystemEntity e) {
      if (keepNorm.contains(p.normalize(e.path))) return;
      if (e is Directory) {
        for (final child in _list(e.path)) {
          wipe(child);
        }
        try {
          if (_list(e.path).isEmpty) e.deleteSync();
        } catch (_) {}
        return;
      }
      if (young(e)) return;
      final n = sizeOf(e);
      try {
        e.deleteSync();
        freed += n;
      } catch (_) {}
    }

    if (buckets.contains(FootprintBucket.shared) ||
        buckets.contains(FootprintBucket.picker) ||
        buckets.contains(FootprintBucket.thumbs) ||
        buckets.contains(FootprintBucket.temp)) {
      for (final e in _list(roots.cacheDir)) {
        final b = cacheBucketOf(p.basename(e.path), isDir: e is Directory);
        if (b == FootprintBucket.models || !buckets.contains(b)) continue;
        if (e is Directory) {
          // Önbellek kökündeki klasörün KENDİSİ kalır, içi boşalır: küçük
          // resim servisleri klasörün yolunu oturum boyunca bellekte tutuyor
          // (`ThumbnailCache._dir`); klasör silinirse uygulama yeniden
          // başlayana dek hiçbir küçük resim yazılamazdı.
          for (final child in _list(e.path)) {
            wipe(child);
          }
        } else {
          wipe(e);
        }
      }
    }
    if (buckets.contains(FootprintBucket.drive)) {
      final drive = Directory(p.join(roots.supportDir, driveDir));
      if (drive.existsSync()) {
        for (final child in _list(drive.path)) {
          wipe(child);
        }
      }
    }
    return freed;
  }

  static Future<int> clean(
    FootprintRoots roots,
    Set<FootprintBucket> buckets, {
    Set<String> keep = const {},
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      return await Isolate.run(
          () => cleanSync(roots, buckets, nowMs: now, keep: keep));
    } catch (_) {
      return 0;
    }
  }
}
