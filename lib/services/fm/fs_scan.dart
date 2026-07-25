import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;

import '../../core/text_search.dart';
import '../../models/fs_entry.dart';

/// Depolama tarama motoru: klasör listeleme, sıralama, özyinelemeli arama ve
/// tüm depolamanın kategori indeksi.
///
/// **Tasarım kararı:** ağır işler (özyinelemeli yürüyüş) `compute` ile arka
/// plan isolate'inde koşar — XLSX çözümlemesinde öğrenilen ders (ana izlekte
/// uzun iş = ANR, bkz. HAFIZA 2026-07-22). İsolate açılamazsa (test/kısıtlı
/// ortam) aynı fonksiyon ana izlekte çalışır, sonuç birebir aynıdır.
abstract final class FsScan {
  /// Özyinelemeli yürüyüşte hiç girilmeyen klasörler.
  ///
  /// **`.dosya-okuyucu-cop` kritik (2026-07-25 hatası):** çöpe atılan dosya
  /// diskte bu klasörde durur; taramadan çıkarılmazsa kategori sayıları
  /// düşmez, silinen dosya "Videolar/Görüntüler" listelerinde durmaya devam
  /// eder ve yinelenen bulucu onu asıl dosyanın kopyası sanar.
  /// `.thumbnails`/`.trashed`/`lost+found` gürültü; `Android/data` ve
  /// `Android/obb` zaten okunamaz (SAF gerekir), denemek yalnız yavaşlatır.
  static const skipDirNames = {
    '.dosya-okuyucu-cop',
    '.thumbnails',
    '.trashed',
    'lost+found',
  };

  /// Bir klasörün içeriğini listeler. Okunamayan girdi atlanır, klasörün
  /// kendisi okunamıyorsa hata yukarı taşınır (kullanıcıya "izin yok" denir).
  static Future<List<FsEntry>> list(
    String dirPath, {
    bool showHidden = false,
  }) async {
    final dir = Directory(dirPath);
    final out = <FsEntry>[];
    await for (final entity in dir.list(followLinks: false)) {
      final entry = FsEntry.fromEntity(entity);
      if (!showHidden && entry.isHidden) continue;
      out.add(entry);
    }
    return out;
  }

  /// Girdileri sıralar. Klasörler varsayılan olarak üstte kalır (dosya
  /// yöneticisi geleneği); sıralama yönü yalnız ikincil ölçüte uygulanır.
  static List<FsEntry> sort(
    List<FsEntry> entries,
    FmSort by, {
    bool descending = false,
    bool foldersFirst = true,
  }) {
    final list = [...entries];
    int cmp(FsEntry a, FsEntry b) {
      if (foldersFirst && a.isDir != b.isDir) return a.isDir ? -1 : 1;
      final r = switch (by) {
        FmSort.name => nameKey(a.name).compareTo(nameKey(b.name)),
        FmSort.date => a.modifiedMs.compareTo(b.modifiedMs),
        FmSort.size => a.sizeBytes.compareTo(b.sizeBytes),
        FmSort.type => a.extension.compareTo(b.extension),
      };
      // Eşitlikte ada göre kararlı sırala (aynı boyutlu/tarihli dosyalar
      // yenilemeler arasında yer değiştirmesin).
      if (r != 0) return descending ? -r : r;
      return nameKey(a.name).compareTo(nameKey(b.name));
    }

    list.sort(cmp);
    return list;
  }

  /// Ada göre sıralama anahtarı.
  ///
  /// Dart'ın `compareTo`'su kod birimlerine bakar: `ı` (U+0131) `z`'den
  /// BÜYÜKTÜR → "Işık" listenin en sonuna düşerdi. Türkçe harfler temel
  /// karşılıklarına indirgenerek beklenen yere (i, s, g, u, o, c) oturur;
  /// büyük/küçük harf farkı `turkishFold` ile zaten kalkar.
  static String nameKey(String name) {
    const map = {
      'ı': 'i',
      'ş': 's',
      'ğ': 'g',
      'ü': 'u',
      'ö': 'o',
      'ç': 'c',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    final folded = turkishFold(name);
    final sb = StringBuffer();
    for (final ch in folded.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  /// Bir klasörün toplam boyutu (özyinelemeli). Arka plan isolate'inde.
  static Future<int> folderSize(String path) => _run(_folderSizeSync, path);

  /// Ada göre özyinelemeli arama (Türkçe-duyarlı, büyük/küçük harf duyarsız).
  static Future<List<FsEntry>> search(
    String root,
    String query, {
    int limit = 500,
  }) =>
      _run(_searchSync, _SearchArgs(root, query, limit));

  /// Tüm depolamanın tek geçişli indeksi: kategori istatistikleri, kategori
  /// başına en yeni dosyalar, en büyük dosyalar ve son değişenler.
  ///
  /// *Niye tek geçiş:* panodaki her kutu ayrı ayrı tararsa aynı 100 bin dosya
  /// defalarca gezilir. Tek yürüyüş hepsini besler.
  ///
  /// [searchIndexPath] verilirse **aynı yürüyüşte** arama dizini de yazılır
  /// (bkz. `SearchIndex`): panonun taraması zaten tüm ağacı geziyor, aramanın
  /// ikinci kez gezmesi saf israftı.
  static Future<StorageIndex> index(
    List<String> roots, {
    int perCategory = 800,
    String? searchIndexPath,
  }) =>
      _run(_indexSync, _IndexArgs(roots, perCategory, searchIndexPath));

  /// [fn]'i mümkünse arka plan isolate'inde çalıştırır; olmazsa ana izlekte.
  static Future<R> _run<A, R>(R Function(A) fn, A arg) async {
    try {
      return await compute(fn, arg);
    } catch (_) {
      return fn(arg);
    }
  }
}

/// Tek bir kategorinin toplamı.
class CategoryStat {
  final int count;
  final int bytes;
  const CategoryStat(this.count, this.bytes);
}

/// [FsScan.index] sonucu.
class StorageIndex {
  final Map<FmCategory, CategoryStat> stats;

  /// Kategori başına en yeni dosyalar (kategori ekranı bunu gösterir).
  final Map<FmCategory, List<FsEntry>> byCategory;

  /// En büyük dosyalar (depolama analizi).
  final List<FsEntry> largest;

  /// Son değiştirilen dosyalar (tüm kategoriler karışık).
  final List<FsEntry> recent;

  /// Taranan toplam dosya sayısı ve bayt (analiz özeti).
  final int totalFiles;
  final int totalBytes;

  /// İzin verilmediği için atlanan klasör sayısı (kullanıcıya ipucu).
  final int skipped;

  /// Aynı yürüyüşte yazılan arama dizinindeki satır sayısı;
  /// -1 = dizin istenmedi ya da yazılamadı.
  final int searchIndexRows;

  const StorageIndex({
    required this.stats,
    required this.byCategory,
    required this.largest,
    required this.recent,
    required this.totalFiles,
    required this.totalBytes,
    required this.skipped,
    this.searchIndexRows = -1,
  });

  static const empty = StorageIndex(
    stats: {},
    byCategory: {},
    largest: [],
    recent: [],
    totalFiles: 0,
    totalBytes: 0,
    skipped: 0,
  );

  CategoryStat stat(FmCategory c) => stats[c] ?? const CategoryStat(0, 0);
  List<FsEntry> files(FmCategory c) => byCategory[c] ?? const [];
}

// ── isolate'te koşan saf fonksiyonlar ───────────────────────────────────────

class _SearchArgs {
  final String root;
  final String query;
  final int limit;
  const _SearchArgs(this.root, this.query, this.limit);
}

class _IndexArgs {
  final List<String> roots;
  final int perCategory;

  /// Boş değilse arama dizini de bu yola yazılır.
  final String? searchIndexPath;
  const _IndexArgs(this.roots, this.perCategory, [this.searchIndexPath]);
}

int _folderSizeSync(String path) {
  var total = 0;
  walkFiles(Directory(path), (entry) => total += entry.sizeBytes, () {});
  return total;
}

List<FsEntry> _searchSync(_SearchArgs args) {
  final needle = turkishFold(args.query.trim());
  if (needle.isEmpty) return const [];
  final hits = <FsEntry>[];
  walkFiles(
    Directory(args.root),
    (entry) {
      if (hits.length >= args.limit) return;
      if (turkishFold(entry.name).contains(needle)) hits.add(entry);
    },
    () {},
    includeDirs: true,
    stop: () => hits.length >= args.limit,
  );
  return hits;
}

StorageIndex _indexSync(_IndexArgs args) {
  final counts = <FmCategory, int>{};
  final bytes = <FmCategory, int>{};
  final tops = <FmCategory, _TopN>{};
  final largest = _TopN(200, (a, b) => b.sizeBytes.compareTo(a.sizeBytes));
  final recent = _TopN(300, (a, b) => b.modifiedMs.compareTo(a.modifiedMs));
  var totalFiles = 0;
  var totalBytes = 0;
  var skipped = 0;

  // Arama dizini: aynı yürüyüşten beslenir. Yazma başarısız olursa (izin/yer)
  // tarama devam eder, yalnız dizin oluşmaz — pano çalışmaya devam etmeli.
  final writer = args.searchIndexPath == null
      ? null
      : _SearchIndexWriter.tryOpen(args.searchIndexPath!);
  var indexedRows = 0;

  for (final root in args.roots) {
    walkFiles(
      Directory(root),
      (entry) {
        writer?.add(entry);
        if (writer != null) indexedRows++;
        // Klasörler yalnız arama dizinine girer: kategori sayıları ve
        // "en büyük/en yeni" listeleri DOSYA listeleridir.
        if (entry.isDir) return;
        final c = entry.category;
        counts[c] = (counts[c] ?? 0) + 1;
        bytes[c] = (bytes[c] ?? 0) + entry.sizeBytes;
        totalFiles++;
        totalBytes += entry.sizeBytes;
        (tops[c] ??= _TopN(
          args.perCategory,
          (a, b) => b.modifiedMs.compareTo(a.modifiedMs),
        ))
            .add(entry);
        largest.add(entry);
        recent.add(entry);
      },
      () => skipped++,
      // Klasörleri yalnız arama dizini isteniyorsa gez (aksi hâlde gereksiz
      // geri çağrı maliyeti).
      includeDirs: writer != null,
    );
  }

  final wrote = writer?.finish() ?? false;

  return StorageIndex(
    stats: {
      for (final c in counts.keys)
        c: CategoryStat(counts[c] ?? 0, bytes[c] ?? 0),
    },
    byCategory: {for (final e in tops.entries) e.key: e.value.result()},
    largest: largest.result(),
    recent: recent.result(),
    totalFiles: totalFiles,
    totalBytes: totalBytes,
    skipped: skipped,
    searchIndexRows: wrote ? indexedRows : -1,
  );
}

/// Arama dizinini satır satır yazar (isolate içinde). Önce `.tmp`'ye yazar,
/// sonunda yerine taşır → yarım kalmış dizin okunmaz.
class _SearchIndexWriter {
  final File _tmp;
  final String _target;
  final RandomAccessFile _raf;
  final StringBuffer _buffer = StringBuffer();

  _SearchIndexWriter._(this._tmp, this._target, this._raf);

  static _SearchIndexWriter? tryOpen(String target) {
    try {
      final tmp = File('$target.tmp');
      tmp.parent.createSync(recursive: true);
      return _SearchIndexWriter._(
          tmp, target, tmp.openSync(mode: FileMode.write));
    } catch (_) {
      return null;
    }
  }

  void add(FsEntry entry) {
    final path = entry.path.replaceAll('\t', ' ').replaceAll('\n', ' ');
    _buffer.writeln('$path\t${entry.sizeBytes}\t${entry.modifiedMs}\t'
        '${entry.isDir ? 1 : 0}');
    if (_buffer.length >= 64 * 1024) _flush();
  }

  void _flush() {
    if (_buffer.isEmpty) return;
    _raf.writeStringSync(_buffer.toString());
    _buffer.clear();
  }

  /// Dosyayı kapatıp yerine taşır; başarılıysa true.
  bool finish() {
    try {
      _flush();
      _raf.closeSync();
      _tmp.renameSync(_target);
      return true;
    } catch (_) {
      try {
        if (_tmp.existsSync()) _tmp.deleteSync();
      } catch (_) {}
      return false;
    }
  }
}

/// Bellek-sınırlı "en iyi N" toplayıcı: liste 2N'e ulaşınca sıralayıp N'e
/// düşürür. *Niye:* 200 bin dosyalık bir telefonda hepsini listede tutup
/// sonda sıralamak isolate'i onlarca MB şişirirdi.
class _TopN {
  final int cap;
  final int Function(FsEntry, FsEntry) compare;
  final List<FsEntry> _items = [];
  _TopN(this.cap, this.compare);

  void add(FsEntry e) {
    _items.add(e);
    if (_items.length >= cap * 2) _trim();
  }

  void _trim() {
    _items.sort(compare);
    if (_items.length > cap) _items.removeRange(cap, _items.length);
  }

  List<FsEntry> result() {
    _trim();
    return List.unmodifiable(_items);
  }
}

/// Klasör ağacını gezer. [onFile] her DOSYA için çağrılır; [onDenied] okuma
/// izni olmayan klasörlerde. Sembolik bağlantılar izlenmez (döngü riski).
///
/// Herkese açık: yinelenen dosya bulucu gibi başka tarayıcılar da aynı
/// yürüyüşü (aynı atlama kuralları, aynı derinlik sigortası) kullansın.
void walkFiles(
  Directory dir,
  void Function(FsEntry) onFile,
  void Function() onDenied, {
  bool includeDirs = false,
  bool Function()? stop,
  int depth = 0,
}) {
  if (depth > 24) return; // patolojik derinlik/döngü sigortası
  List<FileSystemEntity> children;
  try {
    children = dir.listSync(followLinks: false);
  } catch (_) {
    onDenied();
    return;
  }
  for (final child in children) {
    if (stop != null && stop()) return;
    final entry = FsEntry.fromEntity(child);
    if (entry.isLink) continue;
    if (entry.isDir) {
      if (FsScan.skipDirNames.contains(entry.name)) continue;
      if (includeDirs) onFile(entry);
      walkFiles(
        Directory(child.path),
        onFile,
        onDenied,
        includeDirs: includeDirs,
        stop: stop,
        depth: depth + 1,
      );
    } else {
      onFile(entry);
    }
  }
}

/// Yol yardımcıları (saf, test edilebilir).
abstract final class FsPaths {
  /// [child], [parent]'ın altında mı? Klasörü kendi içine kopyalama/taşıma
  /// tuzağını (sonsuz özyineleme) engellemek için kullanılır.
  static bool isInside(String parent, String child) {
    final a = p.normalize(parent);
    final b = p.normalize(child);
    if (a == b) return true;
    return b.startsWith(a.endsWith('/') ? a : '$a/');
  }

  /// Okunabilir boyut: 1536 → "1,5 KB" (Türkçe ondalık ayracı).
  static String humanSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final text = unit == 0
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(size < 10 ? 1 : 0);
    return '${text.replaceAll('.', ',')} ${units[unit]}';
  }

  /// Kısa tarih: "12 Tem 2026 14:30".
  static String humanDate(int ms) {
    if (ms <= 0) return '—';
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
