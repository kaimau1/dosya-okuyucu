import 'dart:convert';
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

  /// Bir kategorinin (ya da tüm dosyaların) **eksiksiz** listesi — arama
  /// dizininden, diske girilmeden.
  ///
  /// *Niye ayrı bir yol:* [index] kategori başına yalnız en yeni
  /// [_IndexArgs.perCategory] (800) dosyayı tutar; pano kutuları için yeterli
  /// ama kullanıcı "Videolar"a girince **hepsini** görmek ister (hata
  /// 2026-07-29: "videolarda tüm videolar görünmüyor ama dosyaların içinde
  /// bulabiliyorum"). Tam liste ancak istendiğinde kurulur — 100 bin dosyalık
  /// bir telefonda hepsini sürekli bellekte tutmak pahalı olurdu.
  ///
  /// [root] verilirse yalnız o klasörün altı döner.
  static Future<List<FsEntry>> collectFromIndex(
    String searchIndexPath, {
    FmCategory? category,
    String? root,
    int limit = 100000,
  }) =>
      _run(
        _collectFromIndexSync,
        _CollectArgs(
          const [],
          category?.name,
          limit,
          indexPath: searchIndexPath,
          root: root,
        ),
      );

  /// Aynı listeyi **diski gezerek** kurar (dizin yoksa / bozuksa).
  static Future<List<FsEntry>> collect(
    List<String> roots, {
    FmCategory? category,
    int limit = 100000,
  }) =>
      _run(_collectSync, _CollectArgs(roots, category?.name, limit));

  /// Listedeki artık diskte olmayan girdileri ayıklar (arka planda).
  ///
  /// *Niye isolate:* silme/taşıma sonrası tazelemede 20 bin girdi için ana
  /// izlekte `statSync` çağırmak listeyi saniyelerce kilitlerdi.
  static Future<List<FsEntry>> pruneMissing(List<FsEntry> entries) =>
      _run(_pruneMissingSync, entries);

  /// Yolları girdiye çevirir; **artık olmayanlar listeye girmez** (arka
  /// planda, sıra korunur).
  ///
  /// "Son açılanlar" ekranı bunu yolları elinde tutan bir kayıttan
  /// (`OpenHistory`) liste kurmak için kullanıyor. Eskiden her yol için ana
  /// izlekte `existsSync` + `statSync` çağrılıyordu: birkaç bin kayıtlık bir
  /// geçmişte ekran saniyelerce donuyordu (kullanıcı 2026-08-09: *"son
  /// açılanlar çok daha hızlı çalışmalı"*).
  static Future<List<FsEntry>> statPaths(List<String> paths) =>
      _run(_statPathsSync, paths);

  /// Aynı indeksi **diski hiç gezmeden**, daha önce yazılmış arama dizini
  /// dosyasından kurar (kullanıcı isteği 2026-07-25: "her açılışta baştan
  /// tarıyor").
  ///
  /// *Niye çalışıyor:* arama dizini ([SearchIndex]) zaten her dosya ve klasör
  /// için yol/boyut/tarih tutuyor — panonun ihtiyacı olan her şey orada.
  /// Ağacı yürümek 100 bin dosyada dakikalar sürerken düz dosyayı okumak
  /// saniyenin altında. Dizin yoksa/bozuksa `null` döner, çağıran tam
  /// taramaya düşer.
  static Future<StorageIndex?> indexFromRows(
    String searchIndexPath, {
    int perCategory = 800,
  }) =>
      _run(_indexFromRowsSync, _IndexArgs(const [], perCategory,
          searchIndexPath));

  /// **Sıcak klasörlerin hızlı taraması** — kameranın, indirmelerin, mesajlaşma
  /// medyasının bulunduğu birkaç klasörde son eklenen dosyaları toplar.
  ///
  /// Kullanıcı isteği (2026-08-17): *"son açılanlar ve yeni dosyalar sürekli
  /// güncel tutulmalı … her seferinde ben açtığımda 1 sn önce eklenen bir
  /// görsel belge ses her ne varsa görmeliyim, kaçmamalı hiçbir şey"*.
  ///
  /// *Niye tam tarama DEĞİL:* 100 bin dosyalı bir telefonda tüm ağacı yürümek
  /// dakikalar sürüyor ve pili yiyor — bu yüzden [index] yalnız 12 saatte bir
  /// koşuyordu, arada eklenen dosyalar panoya hiç yansımıyordu. Yeni dosyalar
  /// **rastgele yerlere düşmez**: kamera DCIM'e, indirmeler Download'a,
  /// WhatsApp kendi klasörüne yazar. O birkaç ağacı gezmek saniyenin altında
  /// sürüyor ve her açılışta koşabiliyor.
  ///
  /// [sinceMs] verilirse yalnız o andan sonra değişenler döner.
  static Future<List<FsEntry>> freshFiles(
    List<String> roots, {
    int sinceMs = 0,
    int limit = 400,
  }) =>
      _run(_freshFilesSync, _FreshArgs(roots, sinceMs, limit));

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

  /// En büyük dosyalar (depolama analizi) — **tüm kategoriler karışık**.
  final List<FsEntry> largest;

  /// Kategori başına en büyük dosyalar.
  ///
  /// **Niye ayrı liste (genel [largest]'ı süzmek YETMİYOR):** genel liste ilk
  /// 200 dosyayla sınırlı ve pratikte hepsi videodur (bir film 2 GB, bir PDF
  /// 2 MB). Bellek analizinde "Belgeler" çubuğuna dokunan kullanıcı o listeyi
  /// süzünce **boş** bir ekran görüyordu (kullanıcı hatası 2026-08-09: *"en
  /// büyük dosyalarda sadece videolar görülüyor, diğerleri boş çıkıyor"*).
  /// Her kategorinin kendi "en büyük"leri ayrı toplanıyor: artık her süzgeç
  /// kendi içinde çalışıyor.
  final Map<FmCategory, List<FsEntry>> largestByCategory;

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
    this.largestByCategory = const {},
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

  /// [c] null ise genel en büyükler, değilse o kategorinin en büyükleri.
  List<FsEntry> largestOf(FmCategory? c) =>
      c == null ? largest : (largestByCategory[c] ?? const []);

  /// [FsScan.freshFiles] ile bulunan **yeni** dosyaları indekse katar.
  ///
  /// Kullanıcı isteği (2026-08-17): pano bir saniye önce eklenen dosyayı da
  /// göstermeli. Tam tarama pahalı olduğu için sıcak klasörler ayrıca taranıyor
  /// ve sonucu buradan indekse işleniyor: hem "Yeni Dosyalar" listesine hem de
  /// kategori listelerine ve sayaçlara.
  ///
  /// Zaten bilinen yollar (yol karşılaştırmasıyla) **iki kez sayılmaz** — aynı
  /// dosya her açılışta yeniden bulunacağı için sayaçlar şişerdi.
  StorageIndex mergeFresh(List<FsEntry> fresh) {
    if (fresh.isEmpty) return this;
    final known = <String>{
      for (final e in recent) e.path,
      for (final list in byCategory.values)
        for (final e in list) e.path,
    };
    final added = [for (final e in fresh) if (!known.contains(e.path)) e];
    if (added.isEmpty) return this;

    List<FsEntry> prepend(List<FsEntry> base, List<FsEntry> extra, int cap) {
      final out = [...extra, ...base];
      out.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
      return out.length > cap ? out.sublist(0, cap) : out;
    }

    final nextByCategory = {
      for (final entry in byCategory.entries) entry.key: entry.value,
    };
    final nextStats = {for (final e in stats.entries) e.key: e.value};
    for (final category in FmCategory.values) {
      final mine = [for (final e in added) if (e.category == category) e];
      if (mine.isEmpty) continue;
      nextByCategory[category] =
          prepend(byCategory[category] ?? const [], mine, 800);
      final old = stats[category] ?? const CategoryStat(0, 0);
      nextStats[category] = CategoryStat(
        old.count + mine.length,
        old.bytes + mine.fold<int>(0, (s, e) => s + e.sizeBytes),
      );
    }

    return StorageIndex(
      stats: nextStats,
      byCategory: nextByCategory,
      largest: largest,
      largestByCategory: largestByCategory,
      recent: prepend(recent, added, 800),
      totalFiles: totalFiles + added.length,
      totalBytes:
          totalBytes + added.fold<int>(0, (s, e) => s + e.sizeBytes),
      skipped: skipped,
      searchIndexRows: searchIndexRows,
    );
  }
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

class _CollectArgs {
  final List<String> roots;
  final String? categoryName;
  final int limit;
  final String? indexPath;
  final String? root;
  const _CollectArgs(
    this.roots,
    this.categoryName,
    this.limit, {
    this.indexPath,
    this.root,
  });

  FmCategory? get category {
    for (final c in FmCategory.values) {
      if (c.name == categoryName) return c;
    }
    return null;
  }
}

/// Kategori süzgeci + yeniden eskiye sıralama (iki toplayıcıda ortak).
List<FsEntry> _finishCollect(List<FsEntry> hits) {
  hits.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
  return hits;
}

List<FsEntry> _collectFromIndexSync(_CollectArgs args) {
  final path = args.indexPath;
  if (path == null) return const [];
  final category = args.category;
  final rootPrefix = args.root == null ? null : p.normalize(args.root!);
  final hits = <FsEntry>[];
  _forEachIndexRow(path, (entry) {
    if (entry.isDir) return true;
    if (category != null && entry.category != category) return true;
    if (rootPrefix != null && !FsPaths.isInside(rootPrefix, entry.path)) {
      return true;
    }
    hits.add(entry);
    return hits.length < args.limit;
  });
  return _finishCollect(hits);
}

List<FsEntry> _collectSync(_CollectArgs args) {
  final category = args.category;
  final hits = <FsEntry>[];
  for (final root in args.roots) {
    walkFiles(
      Directory(root),
      (entry) {
        if (hits.length >= args.limit) return;
        if (category != null && entry.category != category) return;
        hits.add(entry);
      },
      () {},
      stop: () => hits.length >= args.limit,
    );
  }
  return _finishCollect(hits);
}

class _FreshArgs {
  final List<String> roots;
  final int sinceMs;
  final int limit;
  const _FreshArgs(this.roots, this.sinceMs, this.limit);
}

List<FsEntry> _freshFilesSync(_FreshArgs args) {
  // **`stop:` ile kesmek YANLIŞ olurdu.** Yürüyüş dizin sırasında ilerler,
  // tarih sırasında değil: DCIM'de 7000 fotoğraf varken ilk 100'de durmak
  // "rastgele 100 dosya"yı en yeniler sanmak demekti — kullanıcının az önce
  // çektiği kare listeye hiç girmeyebilirdi. Onun yerine ağaç sonuna kadar
  // gezilir ama bellekte yalnız **en yeni [_FreshArgs.limit]** tutulur
  // (sınırlı bellek, tam doğruluk).
  final top = _TopN(args.limit, (a, b) => b.modifiedMs.compareTo(a.modifiedMs));
  final seen = <String>{};
  for (final root in args.roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    walkFiles(
      dir,
      (entry) {
        if (entry.modifiedMs < args.sinceMs) return;
        if (!seen.add(entry.path)) return;
        top.add(entry);
      },
      () {},
    );
  }
  return _finishCollect(top.result().toList());
}

List<FsEntry> _pruneMissingSync(List<FsEntry> entries) =>
    [for (final e in entries) if (e.exists) e];

List<FsEntry> _statPathsSync(List<String> paths) {
  final out = <FsEntry>[];
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    out.add(FsEntry.fromEntity(file));
  }
  return out;
}

/// Dizin dosyasını satır satır gezer. [onRow] `false` döndürünce durur.
///
/// Parça parça okunur (64 KB): 100 bin satırlık dizini tek String'e almak
/// isolate'i onlarca MB şişirirdi. UTF-8'de satırsonu baytı (0x0A) çok baytlı
/// bir dizinin içinde ASLA geçmez → baytları satırsonundan bölmek güvenlidir.
void _forEachIndexRow(String path, bool Function(FsEntry) onRow) {
  final file = File(path);
  if (!file.existsSync()) return;
  final raf = file.openSync();
  try {
    final pending = <int>[];
    while (true) {
      final chunk = raf.readSync(64 * 1024);
      if (chunk.isEmpty) break;
      pending.addAll(chunk);
      var start = 0;
      for (var i = 0; i < pending.length; i++) {
        if (pending[i] != 0x0A) continue;
        final line =
            utf8.decode(pending.sublist(start, i), allowMalformed: true);
        start = i + 1;
        final entry = decodeIndexRow(line);
        if (entry == null) continue;
        if (!onRow(entry)) return;
      }
      pending.removeRange(0, start);
    }
    // Son satır `\n` ile bitmemiş olabilir.
    final tail = decodeIndexRow(utf8.decode(pending, allowMalformed: true));
    if (tail != null) onRow(tail);
  } catch (_) {
    // bozuk/okunamayan dizin: o ana kadar toplananlarla devam edilir
  } finally {
    try {
      raf.closeSync();
    } catch (_) {}
  }
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
  final acc = _IndexAccumulator(args.perCategory);

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
        acc.add(entry);
      },
      acc.denied,
      // Klasörleri yalnız arama dizini isteniyorsa gez (aksi hâlde gereksiz
      // geri çağrı maliyeti).
      includeDirs: writer != null,
    );
  }

  final wrote = writer?.finish() ?? false;
  return acc.build(searchIndexRows: wrote ? indexedRows : -1);
}

/// Diski gezmeden, yazılmış arama dizini satırlarından indeks kurar.
/// Dosya yoksa/okunamıyorsa `null` → çağıran tam taramaya düşer.
StorageIndex? _indexFromRowsSync(_IndexArgs args) {
  final path = args.searchIndexPath;
  if (path == null) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  final acc = _IndexAccumulator(args.perCategory);
  var rows = 0;
  _forEachIndexRow(path, (entry) {
    acc.add(entry);
    rows++;
    return true;
  });
  if (rows == 0) return null;
  return acc.build(searchIndexRows: rows);
}

/// [StorageIndex] toplayıcısı: girdiler ister canlı yürüyüşten
/// ([_indexSync]) ister dizin dosyasından ([_indexFromRowsSync]) gelsin
/// sayım/sıralama mantığı **tek yerde** dursun diye ayrıldı.
class _IndexAccumulator {
  final int perCategory;
  final Map<FmCategory, int> _counts = {};
  final Map<FmCategory, int> _bytes = {};
  final Map<FmCategory, _TopN> _tops = {};

  /// Kategori başına **en büyükler** (bkz. [StorageIndex.largestByCategory]).
  /// Sınır kategori başına 200: bellek analizinde 200'den sonrası yer açma
  /// kararına katkı vermiyor (ekran da o kadarını çiziyor).
  final Map<FmCategory, _TopN> _largestTops = {};
  final _TopN _largest = _TopN(200, (a, b) => b.sizeBytes.compareTo(a.sizeBytes));
  final _TopN _recent = _TopN(300, (a, b) => b.modifiedMs.compareTo(a.modifiedMs));
  int _totalFiles = 0;
  int _totalBytes = 0;
  int _skipped = 0;

  _IndexAccumulator(this.perCategory);

  /// Okunamayan klasör sayacı ([walkFiles]'ın `onDenied` geri çağrısı).
  void denied() => _skipped++;

  void add(FsEntry entry) {
    // Klasörler yalnız arama dizinine girer: kategori sayıları ve
    // "en büyük/en yeni" listeleri DOSYA listeleridir.
    if (entry.isDir) return;
    final c = entry.category;
    _counts[c] = (_counts[c] ?? 0) + 1;
    _bytes[c] = (_bytes[c] ?? 0) + entry.sizeBytes;
    _totalFiles++;
    _totalBytes += entry.sizeBytes;
    (_tops[c] ??= _TopN(
      perCategory,
      (a, b) => b.modifiedMs.compareTo(a.modifiedMs),
    ))
        .add(entry);
    (_largestTops[c] ??=
            _TopN(200, (a, b) => b.sizeBytes.compareTo(a.sizeBytes)))
        .add(entry);
    _largest.add(entry);
    _recent.add(entry);
  }

  StorageIndex build({required int searchIndexRows}) => StorageIndex(
        stats: {
          for (final c in _counts.keys)
            c: CategoryStat(_counts[c] ?? 0, _bytes[c] ?? 0),
        },
        byCategory: {for (final e in _tops.entries) e.key: e.value.result()},
        largest: _largest.result(),
        largestByCategory: {
          for (final e in _largestTops.entries) e.key: e.value.result(),
        },
        recent: _recent.result(),
        totalFiles: _totalFiles,
        totalBytes: _totalBytes,
        skipped: _skipped,
        searchIndexRows: searchIndexRows,
      );
}

/// Dizin satırını üretir. Yol içinde sekme/satırsonu olamayacağı için ayraç
/// güvenli; yine de olası kaçık karakterler boşluğa çevrilir.
///
/// **5. alan erişim zamanı (2026-08-09).** Eskiden yazılmıyordu ve dizinden
/// kurulan her girdinin `accessedMs`'i 0 oluyordu → [FsEntry.lastTouchedMs]
/// sessizce değiştirilme zamanına düşüyordu. Sonuç: "6 aydır açılmamış"
/// süzgeci dizin yolundan gelen listelerde (kategori ekranları, hızlı süzgeç
/// çipleri) aslında "6 aydır DEĞİŞTİRİLMEMİŞ" demekti — kullanıcının indirip
/// dün izlediği film de "açılmamış" sayılıyordu.
String encodeIndexRow(FsEntry entry) {
  final path = entry.path.replaceAll('\t', ' ').replaceAll('\n', ' ');
  return '$path\t${entry.sizeBytes}\t${entry.modifiedMs}\t'
      '${entry.isDir ? 1 : 0}\t${entry.accessedMs}';
}

/// Dizin satırını çözer; bozuk satırda null.
///
/// Beşinci alan (erişim zamanı) **isteğe bağlı**: sürüm yükseltmeden önce
/// yazılmış dizinler dört alanlıdır ve okunmaya devam etmelidir — dizin
/// yeniden tarandığında kendiliğinden tamamlanır.
FsEntry? decodeIndexRow(String line) {
  if (line.isEmpty) return null;
  final parts = line.split('\t');
  if (parts.length < 4) return null;
  final path = parts[0];
  if (path.isEmpty) return null;
  return FsEntry(
    path: path,
    name: p.basename(path),
    isDir: parts[3] == '1',
    sizeBytes: int.tryParse(parts[1]) ?? 0,
    modifiedMs: int.tryParse(parts[2]) ?? 0,
    accessedMs: parts.length > 4 ? (int.tryParse(parts[4]) ?? 0) : 0,
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
    _buffer.writeln(encodeIndexRow(entry));
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
  /// tuzağını (sonsuz özyineleme) ve arşiv çıkarmada zip-slip'i engeller.
  ///
  /// **Elle `startsWith('$parent/')` YAPILMAZ:** ayracı `/` varsaymak Windows'ta
  /// (`p.normalize` `\` üretir) her karşılaştırmayı false yapıyordu →
  /// `_safeJoin` null dönüyor, arşiv çıkarma sessizce HİÇBİR dosya yazmıyordu
  /// (2026-07-27). `path` paketinin kendi karşılaştırması platform-doğrudur.
  static bool isInside(String parent, String child) =>
      p.equals(parent, child) || p.isWithin(parent, child);

  /// Okunabilir boyut: 1536 → "1,5 KB" (Türkçe ondalık ayracı).
  /// **Depolama kapasitesi** için okunur boyut — 1000 tabanlı.
  ///
  /// Dosya boyutları ([humanSize]) 1024 tabanında gösteriliyor, ama disk
  /// kapasitesi dünyanın her yerinde ondalık olarak anılıyor: 512 GB'lık bir
  /// telefonun `/data` bölümü 1024 tabanında 464 "GB" çıkıyor ve kullanıcı
  /// kutunun üstündeki sayıyı göremiyordu. Ayarlar → Depolama da, karşılaştığımız
  /// diğer dosya yöneticileri de ondalık gösteriyor.
  static String humanCapacity(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1000 && unit < units.length - 1) {
      size /= 1000;
      unit++;
    }
    final text = unit == 0
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(size < 10 ? 1 : 0);
    return '${text.replaceAll('.', ',')} ${units[unit]}';
  }

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
