import 'dart:io';

import 'package:path/path.dart' as p;

import 'fs_events.dart';
import 'fs_scan.dart';
import 'path_side_index.dart';
import 'search_index.dart';

/// Hedefte aynı adlı dosya varsa ne yapılacağı.
enum FmConflict {
  /// Yeni ad ver: `rapor.pdf` → `rapor (1).pdf` (varsayılan, veri kaybı yok).
  rename,

  /// Hedefi üzerine yaz.
  overwrite,

  /// Bu dosyayı atla.
  skip,
}

/// Uzun süren bir işlemin anlık durumu (ilerleme çubuğu için).
class FmProgress {
  final int done;
  final int total;
  final String currentName;
  const FmProgress(this.done, this.total, this.currentName);

  double get fraction => total <= 0 ? 0 : (done / total).clamp(0, 1).toDouble();
}

/// Bir toplu işlemin sonucu. Hata TEK dosyada olsa bile işlem devam eder;
/// kullanıcıya sonda özet gösterilir (yarım kalan kopyalama en kötü sonuç).
class FmOpResult {
  final int succeeded;
  final int skipped;
  final List<String> errors;
  final bool cancelled;

  /// Gerçekleşen aktarımlar (kaynak → **son** hedef yolu).
  ///
  /// Hedef yol istenenden farklı olabilir (ad çakışınca `rapor (1).pdf`), bu
  /// yüzden tahmin edilemez; "Geri al" için gerçek yol gerekir.
  final List<FmTransfer> transfers;

  const FmOpResult({
    this.succeeded = 0,
    this.skipped = 0,
    this.errors = const [],
    this.cancelled = false,
    this.transfers = const [],
  });

  bool get hasError => errors.isNotEmpty;
}

/// Tek bir aktarımın kaynağı ve varış yolu.
class FmTransfer {
  final String source;
  final String dest;
  const FmTransfer(this.source, this.dest);
}

/// Dosya işlemleri: kopyala / taşı / sil / yeniden adlandır / oluştur.
///
/// Saf `dart:io` — Flutter bağımlılığı yok, geçici klasörle birim testi
/// yazılabilir (`test/fm_file_ops_test.dart`).
abstract final class FileOps {
  /// Hedef yol doluysa boşta olan ilk `" (n)"` ekli adı üretir.
  /// `rapor.pdf` → `rapor (1).pdf` → `rapor (2).pdf`; klasörde uzantı yok.
  static String uniquePath(String destPath) {
    if (!_exists(destPath)) return destPath;
    final dir = p.dirname(destPath);
    final base = p.basenameWithoutExtension(destPath);
    final ext = p.extension(destPath); // baştaki nokta dahil
    for (var i = 1; i < 10000; i++) {
      final candidate = p.join(dir, '$base ($i)$ext');
      if (!_exists(candidate)) return candidate;
    }
    // Pratikte ulaşılmaz; yine de veri ezmemek için zaman damgası ekle.
    return p.join(dir, '$base-${DateTime.now().millisecondsSinceEpoch}$ext');
  }

  static bool _exists(String path) =>
      File(path).existsSync() || Directory(path).existsSync();

  /// Dosyanın boyutu; okunamazsa -1 (kopya doğrulamasında "uyuşmadı" sayılır).
  static int _sizeOf(String path) {
    try {
      return File(path).statSync().size;
    } catch (_) {
      return -1;
    }
  }

  /// Kaynakları [destDir] içine kopyalar.
  static Future<FmOpResult> copyAll(
    List<String> sources,
    String destDir, {
    FmConflict conflict = FmConflict.rename,
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) =>
      _transfer(sources, destDir,
          move: false,
          conflict: conflict,
          onProgress: onProgress,
          isCancelled: isCancelled);

  /// Kaynakları [destDir] içine taşır. Aynı bölümde `rename` ile anında;
  /// farklı bölümde (SD kart ↔ dahili) kopyala+sil ile.
  static Future<FmOpResult> moveAll(
    List<String> sources,
    String destDir, {
    FmConflict conflict = FmConflict.rename,
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) =>
      _transfer(sources, destDir,
          move: true,
          conflict: conflict,
          onProgress: onProgress,
          isCancelled: isCancelled);

  static Future<FmOpResult> _transfer(
    List<String> sources,
    String destDir, {
    required bool move,
    required FmConflict conflict,
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final errors = <String>[];
    final transfers = <FmTransfer>[];
    var done = 0;
    var skipped = 0;
    var succeeded = 0;
    final total = _countFiles(sources);

    for (final src in sources) {
      if (isCancelled?.call() ?? false) {
        // `transfers` MUTLAKA döner. Eskiden iptal dalı onu boş bırakıyordu:
        // 200 fotoğrafın 90'ı taşındıktan sonra "İptal"e basan kullanıcıya
        // "90 öğe taşındı" yazılıyor ama "Geri al" düğmesi (koşulu
        // `transfers.isNotEmpty`) HİÇ çıkmıyordu — 90 dosya taşınmış, geri
        // alma yok. Otomatik düzenlemede daha kötüsü oluyordu: `OpHistory`
        // kaydına o taşımalar hiç yazılmadığı için "Son işlemler"den de
        // geri alınamıyorlardı (2026-07-29 sadakat denetimi, 4. tur).
        //
        // `FsEvents.changed()` de burada çağrılır: yoksa açık ekranlar
        // taşınmış dosyaları eski yollarında göstermeye devam ediyordu.
        if (succeeded > 0) FsEvents.changed();
        return FmOpResult(
            succeeded: succeeded,
            skipped: skipped,
            errors: errors,
            transfers: transfers,
            cancelled: true);
      }
      final name = p.basename(src);
      // Klasörü kendi içine taşıma/kopyalama sonsuz özyinelemedir.
      if (FsPaths.isInside(src, destDir)) {
        errors.add('$name: klasör kendi içine taşınamaz');
        continue;
      }
      var dest = joinKeepingSeparator(destDir, name);
      if (p.normalize(src) == p.normalize(dest)) {
        // Aynı klasöre kopyalama → kopya üret ("rapor (1).pdf").
        if (move) {
          skipped++;
          continue;
        }
        dest = uniquePath(dest);
      }
      try {
        final finalPath = await _transferOne(
          src,
          dest,
          move: move,
          conflict: conflict,
          onFile: (fileName) {
            done++;
            onProgress?.call(FmProgress(done, total, fileName));
          },
          isCancelled: isCancelled,
          onSkip: () => skipped++,
        );
        // `succeeded` yalnız GERÇEKTEN aktarılanı sayar. Eskiden koşulsuz
        // artıyordu: atlanan dosya hem `skipped` hem `succeeded` sayılıyor,
        // iptal edilen yarım klasör de "aktarıldı" görünüyordu.
        if (finalPath != null) {
          succeeded++;
          transfers.add(FmTransfer(src, finalPath));
          // TAŞIMADA yan kayıtlar (etiket, açılma geçmişi) yeni yola geçer.
          // Kopyalamada geçmez: özgün dosya yerinde duruyor, etiketi onda
          // kalmalı — kopyaya da yapıştırmak "iki dosyada aynı etiket" gibi
          // kullanıcının vermediği bir karar olurdu.
          if (move) await PathSideIndex.moved(src, finalPath);
        }
      } catch (e) {
        errors.add('$name: ${_msg(e)}');
      }
    }
    // Taşımada ESKİ yol dizinde kalmasın (kopyalamada kaynak yerinde duruyor,
    // dokunulmaz). Yeni yol bir sonraki tam kurulumda dizine girer.
    if (move && transfers.isNotEmpty) {
      await SearchIndex.forget([for (final t in transfers) t.source]);
    }
    if (succeeded > 0) FsEvents.changed();
    return FmOpResult(
      succeeded: succeeded,
      skipped: skipped,
      errors: errors,
      transfers: transfers,
      // İptal isteği döngü İÇİNDE geldiyse (tek dosyalık bir işte ya da son
      // öğede) yukarıdaki erken dönüşe hiç uğranmaz ve sonuç "iptal edilmedi"
      // diyordu: kullanıcı "İptal"e bastığı hâlde "1 öğe taşındı" görüyordu.
      // Kopyalama/taşıma çekirdekte kesilemez (`File.copy` bölünemez), ama
      // OLANI DOĞRU söylemek zorundayız — arayüz bu bayrakla "iptal istendi,
      // şu kadarı çoktan aktarılmıştı" diyebiliyor.
      cancelled: isCancelled?.call() ?? false,
    );
  }

  /// Bir taşımayı **geri alır**: her öğeyi eski yoluna (eski ADIYLA) geri taşır.
  ///
  /// Eski yol doluysa yeni ad verilir (veri ezilmez), yani dosya eski adıyla
  /// dönmeyebilir — ama asla kaybolmaz. Kopyalama geri alınmaz: orada geri
  /// almak "sil" demektir, yanlış dokunuşta veri kaybı riski taşır.
  ///
  /// **Ad geri getirilir:** `moveAll` hedef adı `basename(dest)`ten üretiyor;
  /// taşıma sırasında çakışma yüzünden ad değişmişse (`rapor.pdf` →
  /// `rapor (1).pdf`) "Geri al" dosyayı `rapor (1).pdf` olarak geri getiriyor,
  /// arayüz ise sadece "Geri alındı." diyordu — kullanıcının dosya adı sessizce
  /// değişiyordu (2026-07-29 sadakat denetimi, 4. tur). Artık eski ad boşsa
  /// dosya o ada döndürülür.
  static Future<FmOpResult> undoMove(List<FmTransfer> transfers) async {
    final errors = <String>[];
    var ok = 0;
    for (final t in transfers) {
      try {
        final back = await moveAll([t.dest], p.dirname(t.source));
        if (back.hasError) {
          errors.addAll(back.errors);
          continue;
        }
        ok += back.succeeded;
        final landed = back.transfers.isNotEmpty
            ? back.transfers.first.dest
            : p.join(p.dirname(t.source), p.basename(t.dest));
        if (p.normalize(landed) != p.normalize(t.source) &&
            _exists(landed) &&
            !_exists(t.source)) {
          try {
            await rename(landed, p.basename(t.source));
          } catch (_) {
            // Ad geri verilemedi: dosya yerinde ve sağlam, yalnız adı farklı.
          }
        }
      } catch (e) {
        errors.add('${p.basename(t.dest)}: ${_msg(e)}');
      }
    }
    return FmOpResult(succeeded: ok, errors: errors);
  }

  /// Aktarımı yapar ve **gerçek** varış yolunu döndürür (atlandıysa null).
  static Future<String?> _transferOne(
    String src,
    String dest, {
    required bool move,
    required FmConflict conflict,
    required void Function(String) onFile,
    required void Function() onSkip,
    bool Function()? isCancelled,
  }) async {
    final srcDir = Directory(src);
    final isDir = srcDir.existsSync();

    if (isDir) {
      // Hızlı yol: aynı bölümde, hedef boşken klasörün tamamı tek `rename` ile
      // taşınır (binlerce dosyayı tek tek kopyalamaya gerek yok).
      if (move && !_exists(dest)) {
        try {
          await srcDir.rename(dest);
          onFile(p.basename(src));
          return dest;
        } on FileSystemException {
          // farklı bölüm → aşağıdaki normal yol
        }
      }
      // Klasör: hedef varsa BİRLEŞTİR (içerik tek tek kopyalanır) — hedefi
      // silip yeniden yazmak, hedefteki başka dosyaları kaybettirirdi.
      final target = Directory(_exists(dest) && conflict == FmConflict.rename
          ? uniquePath(dest)
          : dest);
      await target.create(recursive: true);
      // Çocuklardan biri ATLANDI mı? (Ad çakışması + `FmConflict.skip`.)
      // Bunu bilmek zorunludur: atlanan çocuk kopyalanmadığı hâlde aşağıdaki
      // `delete(recursive: true)` kaynağı komple siliyordu → atlanan dosyanın
      // TEK kopyası yok oluyordu, hedefte de zaten farklı içerikli bir dosya
      // vardı (2026-07-29 sadakat denetimi, 4. tur — CRITICAL). Atlama olduysa
      // kaynak klasör KORUNUR; kullanıcı elinde kalanı görür.
      var anySkipped = false;
      var cancelledHere = false;
      for (final child in srcDir.listSync(followLinks: false)) {
        if (isCancelled?.call() ?? false) {
          cancelledHere = true;
          break;
        }
        final childResult = await _transferOne(
          child.path,
          p.join(target.path, p.basename(child.path)),
          move: move,
          conflict: conflict,
          onFile: onFile,
          onSkip: () {
            anySkipped = true;
            onSkip();
          },
          isCancelled: isCancelled,
        );
        if (childResult == null) anySkipped = true;
      }
      // İptalde klasör YARIM kopyalanmış olur; kaynağı silmek de "başarılı"
      // demek de yanlış. `null` dönmek çağırana "bu öğe tamamlanmadı" der:
      // `succeeded` artmaz ve geri alma kaydına yarım bir ağaç yazılmaz.
      // (Eskiden `target.path` dönüyordu: 5000 fotoğraflık albümün 900'ü
      // kopyalanmışken kullanıcıya "kopyalandı" deniyordu.)
      if (cancelledHere) return null;
      if (move && !anySkipped) {
        try {
          await srcDir.delete(recursive: true);
        } catch (_) {
          // içeride kopyalanamayan dosya kaldıysa kaynak durur — veri kaybı yok
        }
      }
      return target.path;
    }

    final file = File(src);
    if (!file.existsSync()) throw const FileSystemException('kaynak bulunamadı');

    var target = dest;
    if (_exists(dest)) {
      switch (conflict) {
        case FmConflict.skip:
          onSkip();
          return null;
        case FmConflict.rename:
          target = uniquePath(dest);
        case FmConflict.overwrite:
          // Hedef ÖNCEDEN SİLİNMEZ. `rename`/`copy` POSIX'te var olan yolun
          // üstüne zaten yazar; önce silmek, kopyalama sonra başarısız olursa
          // (kart doldu, kaynak okunamadı, kart çıkarıldı) hedefteki veriyi
          // hiçbir şey koymadan yok etmek demekti — kullanıcı "üzerine yaz"
          // dedi, "sil" demedi (2026-07-29 sadakat denetimi, 4. tur).
          break;
      }
    }

    onFile(p.basename(src));
    if (move) {
      try {
        await file.rename(target); // aynı bölümde anında
        return target;
      } on FileSystemException {
        // farklı bölüm (SD kart / OTG): kopyala + sil
      }
      final sourceSize = file.statSync().size;
      await file.copy(target);
      // KAYNAK, KOPYA DOĞRULANMADAN SİLİNMEZ. Sıra zaten doğruydu (kopya önce),
      // ama boyut karşılaştırması yoktu: kısa yazmayı hata olarak bildirmeyen
      // bir bağlama noktasında (sdcardfs/FUSE/MTP) tek sağlam kopyayı silmek
      // demekti. Uyuşmazlıkta yarım hedef temizlenir, kaynak YERİNDE kalır.
      final copiedSize = _sizeOf(target);
      if (copiedSize != sourceSize) {
        try {
          if (_exists(target)) File(target).deleteSync();
        } catch (_) {}
        throw FileSystemException(
            'kopya eksik yazıldı ($copiedSize/$sourceSize bayt), '
            'kaynak silinmedi',
            target);
      }
      await file.delete();
    } else {
      await file.copy(target);
    }
    return target;
  }

  /// Kalıcı silme (çöp kutusuna göndermeden). Klasörler özyinelemeli silinir.
  static Future<FmOpResult> deleteAll(
    List<String> paths, {
    void Function(FmProgress)? onProgress,
  }) async {
    final errors = <String>[];
    final gone = <String>[];
    var done = 0;
    var ok = 0;
    for (final path in paths) {
      final name = p.basename(path);
      onProgress?.call(FmProgress(done, paths.length, name));
      try {
        final dir = Directory(path);
        if (dir.existsSync()) {
          await dir.delete(recursive: true);
        } else {
          await File(path).delete();
        }
        ok++;
        gone.add(path);
      } catch (e) {
        errors.add('$name: ${_msg(e)}');
      }
      done++;
    }
    onProgress?.call(FmProgress(done, paths.length, ''));
    // Silinen dosya arama dizininde KALMASIN: dizin yalnız "bayat"
    // işaretlenirse hayalet satır kategori listelerinde ve pano sayılarında
    // günlerce yaşıyordu (bkz. `SearchIndex.forget`).
    if (gone.isNotEmpty) await SearchIndex.forget(gone);
    if (ok > 0) FsEvents.changed();
    return FmOpResult(succeeded: ok, errors: errors);
  }

  /// [dir] + [name]; ayırıcı olarak [dir]'deki SON ayırıcı kullanılır.
  /// p.join platform ayırıcısı basar: Android'de fark yok ama Windows'ta
  /// '/'lu gelen yol '\'ya döner, yan kayıt (etiket/geçmiş) anahtarları ve
  /// test sözleşmeleri girdinin stilini bekler (2026-07-31 Windows koşusu).
  static String joinKeepingSeparator(String dir, String name) {
    final trimmed = (dir.endsWith('/') || dir.endsWith(r'\'))
        ? dir.substring(0, dir.length - 1)
        : dir;
    final i = trimmed.lastIndexOf(RegExp(r'[/\\]'));
    final sep = i < 0 ? p.separator : trimmed[i];
    return '$trimmed$sep$name';
  }

  /// Yeniden adlandırır ve yeni yolu döndürür.
  static Future<String> rename(String path, String newName) async {
    final clean = sanitizeName(newName);
    if (clean.isEmpty) throw const FileSystemException('ad boş olamaz');
    // p.dirname+p.join değil: girdinin ayırıcı stili korunur (üstteki not).
    final cut = path.lastIndexOf(RegExp(r'[/\\]')) + 1;
    final target = '${path.substring(0, cut)}$clean';
    if (p.normalize(target) == p.normalize(path)) return path;
    // YALNIZ BÜYÜK/KÜÇÜK HARF değişiyorsa "zaten var" hatası verilmez.
    // SD kart ve USB bellek FAT32/exFAT'tir: orada `_exists('IMG.jpg')` ile
    // `_exists('img.jpg')` aynı dosyayı bulur, yani `IMG_0042.JPG` →
    // `IMG_0042.jpg` denemesi "bu adda bir öğe zaten var" diye reddediliyordu
    // (dahili depolamada aynı işlem çalışıyor — kullanıcı için tutarsız).
    // Çözüm: geçici bir ada uğrayıp hedefe inmek (2026-07-29 denetimi, 4. tur).
    final caseOnly =
        p.normalize(target).toLowerCase() == p.normalize(path).toLowerCase();
    if (!caseOnly && _exists(target)) {
      throw const FileSystemException('bu adda bir öğe zaten var');
    }
    if (caseOnly) {
      final via = uniquePath('$path.tmp-rename');
      final isDirectory = Directory(path).existsSync();
      if (isDirectory) {
        await Directory(path).rename(via);
        await Directory(via).rename(target);
      } else {
        await File(path).rename(via);
        await File(via).rename(target);
      }
      await PathSideIndex.moved(path, target);
      FsEvents.changed();
      return target;
    }
    final dir = Directory(path);
    if (dir.existsSync()) {
      final renamed = await dir.rename(target);
      // Etiket/açılma geçmişi yolu izler; yoksa yeniden adlandırınca kaybolur.
      await PathSideIndex.moved(path, renamed.path);
      FsEvents.changed();
      return renamed.path;
    }
    final renamed = await File(path).rename(target);
    await PathSideIndex.moved(path, renamed.path);
    FsEvents.changed();
    return renamed.path;
  }

  static Future<String> createFolder(String parent, String name) async {
    final clean = sanitizeName(name);
    if (clean.isEmpty) throw const FileSystemException('ad boş olamaz');
    final target = p.join(parent, clean);
    if (_exists(target)) {
      throw const FileSystemException('bu adda bir öğe zaten var');
    }
    await Directory(target).create(recursive: true);
    FsEvents.changed();
    return target;
  }

  static Future<String> createFile(String parent, String name,
      {String content = ''}) async {
    final clean = sanitizeName(name);
    if (clean.isEmpty) throw const FileSystemException('ad boş olamaz');
    final target = p.join(parent, clean);
    if (_exists(target)) {
      throw const FileSystemException('bu adda bir öğe zaten var');
    }
    await File(target).writeAsString(content);
    FsEvents.changed();
    return target;
  }

  /// Dosya adından yol ayracı ve kontrol karakterlerini temizler. Kullanıcı
  /// "a/b" yazarsa yanlışlıkla başka klasöre yazmayı engeller.
  static String sanitizeName(String name) => name
      .trim()
      .replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'^\.+$'), '');

  /// İlerleme yüzdesi için dosya sayısı (klasörler özyinelemeli sayılır).
  /// Çok büyük ağaçlarda sayım da pahalıdır → 20 bin dosyada durur, ilerleme
  /// çubuğu yaklaşık olur (işlemin kendisi tam yapılır).
  static int _countFiles(List<String> sources) {
    var n = 0;
    void walk(String path, int depth) {
      if (n >= 20000 || depth > 24) return;
      final dir = Directory(path);
      if (dir.existsSync()) {
        List<FileSystemEntity> children;
        try {
          children = dir.listSync(followLinks: false);
        } catch (_) {
          return;
        }
        for (final c in children) {
          walk(c.path, depth + 1);
        }
      } else {
        n++;
      }
    }

    for (final s in sources) {
      walk(s, 0);
    }
    return n == 0 ? sources.length : n;
  }

  static String _msg(Object e) {
    if (e is FileSystemException) {
      return e.osError?.message ?? e.message;
    }
    return e.toString();
  }
}
