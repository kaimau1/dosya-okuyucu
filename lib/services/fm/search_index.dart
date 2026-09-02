import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, compute;
import 'package:path/path.dart' as p;

import '../../core/text_search.dart';
import '../../models/fs_entry.dart';
import 'fm_env.dart';
import 'fs_events.dart';
import 'fs_scan.dart';

// Satır biçimi (`encodeIndexRow`/`decodeIndexRow`) artık `fs_scan.dart`'ta:
// dizini panonun taraması da yazıyor, pano indeksi de aynı satırlardan
// kuruluyor (`FsScan.indexFromRows`). Tek tanım, tek biçim.
export 'fs_scan.dart' show encodeIndexRow, decodeIndexRow;

/// **Aranabilir dosya dizini** — "her seferinde baştan taranmasın" isteğinin
/// karşılığı (kullanıcı, 2026-07-25).
///
/// ## Neden ve nasıl
/// Eski arama her sorguda tüm depolamayı gerçek zamanlı geziyordu
/// (`FsScan.search`): 100 bin dosyalı bir telefonda her harf 3-10 saniye ve
/// ciddi pil demek. Artık depolama **bir kez derinlemesine** taranıp düz bir
/// dizin dosyasına yazılıyor; sonraki aramalar bu dosyada yapılıyor.
///
/// - Dizin biçimi: satır başına bir kayıt, sekmeyle ayrılmış
///   `yol \t boyut \t değişiklikMs \t klasörMü`. Metin olması bilinçli —
///   ayrıştırması ucuz, bozulursa tek satır kaybolur, sürüm geçişi kolay.
/// - Sorgu **isolate'te** koşar (`compute`): 10 MB'lık dizini okuyup süzmek
///   ana izlekte kare atlatırdı. Dizin ana izlekte BELLEKTE TUTULMAZ —
///   100 bin yolu RAM'de tutmak (~15 MB) ucuz telefonlarda pahalı; dosyayı
///   okumak işletim sistemi önbelleğiyle zaten hızlı.
/// - Sonuçlar dönerken diskte gerçekten var mı diye süzülür → dizin bayatsa
///   bile silinmiş dosya sonuçta görünmez.
/// - Dosya sistemi değişince ([FsEvents]) dizin "bayat" işaretlenir; bir
///   sonraki aramada sonuç yine anında döner, arka planda sessizce yenilenir.
abstract final class SearchIndex {
  static const _indexName = 'search_index.tsv';
  static const _metaName = 'search_index.json';

  /// Dizin hazır/bayat durumundaki değişiklikler (arama ekranı dinler).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static int _builtAtMs = 0;
  static int _entryCount = 0;
  static bool _loadedMeta = false;
  static bool _stale = false;
  static Future<int>? _building;
  static int _seenFsVersion = FsEvents.version.value;

  /// Dizin ne zaman kuruldu (0 = hiç kurulmadı).
  static int get builtAtMs => _builtAtMs;

  /// Dizindeki kayıt sayısı.
  static int get entryCount => _entryCount;

  /// Dizin var mı?
  static bool get isReady => _builtAtMs > 0;

  /// Kurulduktan sonra dosya sistemi değişti mi?
  static bool get isStale => _stale;

  /// Şu anda yeniden kuruluyor mu?
  static bool get isBuilding => _building != null;

  static String get _dir => FmEnv.appSupportDir;
  static String get indexPath => p.join(_dir, _indexName);
  static String get _metaPath => p.join(_dir, _metaName);

  /// Meta bilgisini diskten okur (uygulama açılışında bir kez).
  static Future<void> ensureLoaded() async {
    if (_loadedMeta) return;
    _loadedMeta = true;
    await FmEnv.ensureInit();
    FsEvents.version.addListener(_onFsChanged);
    if (_dir.isEmpty) return;
    try {
      final meta = File(_metaPath);
      if (!meta.existsSync() || !File(indexPath).existsSync()) return;
      final raw = jsonDecode(await meta.readAsString());
      if (raw is! Map) return;
      _builtAtMs = (raw['builtAt'] as num?)?.toInt() ?? 0;
      _entryCount = (raw['count'] as num?)?.toInt() ?? 0;
      // Bayatlık DİSKE yazılır: uygulama kapanınca unutulursa, bir sonraki
      // açılışta bayat dizin taze sanılır ve silinen dosyalar panoda
      // sayılmaya devam ederdi.
      _stale = raw['stale'] == true;
    } catch (_) {
      _builtAtMs = 0;
    }
    revision.value++;
  }

  static void _onFsChanged() {
    if (_seenFsVersion == FsEvents.version.value) return;
    _seenFsVersion = FsEvents.version.value;
    if (!isReady || _stale) return;
    _stale = true;
    unawaited(_writeMeta());
    revision.value++;
  }

  /// Meta dosyası tek yerden yazılır (kurulum, benimseme ve bayatlama).
  static Future<void> _writeMeta({List<String>? roots}) async {
    if (_dir.isEmpty) return;
    try {
      await File(_metaPath).writeAsString(
        jsonEncode({
          'builtAt': _builtAtMs,
          'count': _entryCount,
          'stale': _stale,
          if (roots != null) 'roots': roots,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  /// Dizini (yeniden) kurar. Aynı anda ikinci çağrı yeni tarama BAŞLATMAZ,
  /// süren taramaya bağlanır. Kayıt sayısını döndürür.
  static Future<int> rebuild({List<String>? roots}) {
    final existing = _building;
    if (existing != null) return existing;
    final future = _rebuild(roots ?? FmEnv.volumeRoots);
    _building = future;
    revision.value++;
    // Bellek sızmasın / bayrak takılı kalmasın.
    future.whenComplete(() {
      _building = null;
      revision.value++;
    });
    return future;
  }

  static Future<int> _rebuild(List<String> roots) async {
    await ensureLoaded();
    if (_dir.isEmpty) return 0;
    try {
      final count = await compute(
        _buildSync,
        _BuildArgs(roots, indexPath),
      );
      _builtAtMs = DateTime.now().millisecondsSinceEpoch;
      _entryCount = count;
      _stale = false;
      _seenFsVersion = FsEvents.version.value;
      await _writeMeta(roots: roots);
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Panonun taraması dizini **kendisi yazdıysa** ([FsScan.index]'in
  /// `searchIndexPath` seçeneği) yalnız meta bilgisi güncellenir — aynı ağacı
  /// ikinci kez gezmek saf israf olurdu.
  static Future<void> adoptBuilt(int rows) async {
    await ensureLoaded();
    if (_dir.isEmpty || rows < 0) return;
    _builtAtMs = DateTime.now().millisecondsSinceEpoch;
    _entryCount = rows;
    _stale = false;
    _seenFsVersion = FsEvents.version.value;
    await _writeMeta();
    revision.value++;
  }

  /// Dizin yoksa kurar; varsa (bayat olsa bile) hemen döner ve gerekiyorsa
  /// arka planda tazeler. Arama ekranı açılışında çağrılır.
  static Future<void> ensureBuilt() async {
    await ensureLoaded();
    if (!isReady) {
      await rebuild();
      return;
    }
    if (_stale && !isBuilding) unawaited(rebuild());
  }

  /// **Verilen yolları dizinden düşürür** (dosya çöpe taşındı / kalıcı silindi
  /// / taşındı).
  ///
  /// KÖK NEDEN (kullanıcı hatası 2026-08-25: *"çöpe atılan şeyler bir süre
  /// sonra hem çöpte hem görüntüler hem dosyalarda hem son açılanlar hem yeni
  /// dosyalarda görülüyor"*): dizin diskin bir fotoğrafıydı ve silme onu
  /// yalnız **bayat** işaretliyordu. Bayat dizin ise ancak kullanıcı ARAMA
  /// ekranını açınca yeniden kuruluyor; hiç aramayan kullanıcıda hayalet satır
  /// günlerce yaşıyor ("bir süre sonra" dediği tam bu) ve panodaki kategori
  /// sayıları da o satırları sayıyordu.
  ///
  /// Tüm dizini yeniden taramak (dakikalar) yerine düz dosyadan o satırları
  /// çıkarmak yeterli: 10 MB'lık bir dosyayı bir kez okuyup yazmak isolate'te
  /// göz açıp kapayıncaya kadar sürüyor. Klasör silindiyse **altındaki tüm
  /// satırlar** da düşer.
  ///
  /// Dizin bayatlığı DEĞİŞMEZ: burada yalnız silinenler düşürülüyor, yeni
  /// eklenenler hâlâ tam yeniden kurulumu bekliyor.
  static Future<void> forget(Iterable<String> paths) async {
    final targets = paths.map(p.normalize).toSet();
    if (targets.isEmpty) return;
    await ensureLoaded();
    if (!isReady || _dir.isEmpty) return;
    try {
      final left = await compute(
        _forgetSync,
        _ForgetArgs(indexPath: indexPath, paths: targets.toList()),
      );
      if (left < 0) return; // dosya okunamadı: dizin olduğu gibi kalsın
      _entryCount = left;
      await _writeMeta();
      revision.value++;
    } catch (_) {}
  }

  /// Dizini siler (ayarlardan "dizini temizle").
  static Future<void> clear() async {
    await ensureLoaded();
    if (_dir.isEmpty) return;
    for (final f in [File(indexPath), File(_metaPath)]) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    _builtAtMs = 0;
    _entryCount = 0;
    _stale = false;
    revision.value++;
  }

  /// Dizinde arama. Dizin yoksa canlı taramaya ([FsScan.search]) düşer —
  /// kullanıcı ilk taramayı beklemek zorunda kalmaz.
  ///
  /// [root] verilirse yalnız o klasörün altı, [category] verilirse yalnız o
  /// kategori döner (süzme isolate'te yapılır, sonuç listesi kısa gelir).
  /// [matchAll] true ise **boş sorgu** tüm girdileri döndürür — akıllı arama
  /// cümleyi tamamen ölçüte çevirdiğinde ("bu hafta videolar") ad araması
  /// kalmaz, süzülecek bir listeye yine de ihtiyaç vardır.
  static Future<List<FsEntry>> query(
    String query, {
    String? root,
    FmCategory? category,
    bool includeDirs = true,
    bool matchAll = false,
    int limit = 500,
  }) async {
    final q = query.trim();
    if (q.isEmpty && !matchAll) return const [];
    await ensureLoaded();
    if (!isReady) {
      final hits = q.isEmpty
          ? await FsScan.collect(_rootsOf(root), limit: limit)
          : await _searchRoots(_rootsOf(root), q, limit);
      return _postFilter(hits, category, includeDirs);
    }
    try {
      final rows = await compute(
        _querySync,
        _QueryArgs(
          indexPath: indexPath,
          query: matchAll && q.isEmpty ? '' : q,
          root: root,
          categoryName: category?.name,
          includeDirs: includeDirs,
          limit: limit,
        ),
      );
      // Dizin bayat olabilir: diskte kalmayanları düşür (en çok `limit`
      // kadar stat çağrısı — göz açıp kapayıncaya kadar).
      return rows.where((e) => e.exists).toList();
    } catch (_) {
      final hits = await _searchRoots(_rootsOf(root), q, limit);
      return _postFilter(hits, category, includeDirs);
    }
  }

  /// Dizin hazır değilken hangi kökler gezilecek?
  ///
  /// [root] null = "tüm depolama" → **bütün birimler** (SD kart ve USB dahil).
  /// Eskiden burada `FmEnv.primaryRoot` vardı: dizin bayat/eksikken yapılan
  /// arama yalnız ana belleği geziyordu ve SD karttaki dosyalar hiç
  /// bulunmuyordu (kullanıcı 2026-09-02: *"SD kart desteği olan telefonlarda
  /// uyumumuz yok"*). Dizinin kendisi zaten `FmEnv.volumeRoots` yürüyüşünden
  /// besleniyor; yedek yolun ondan dar olması tutarsızlıktı.
  static List<String> _rootsOf(String? root) =>
      root == null ? FmEnv.volumeRoots : [root];

  /// Birden çok kökte arar ve sonuçları birleştirir ([limit]'e kadar).
  static Future<List<FsEntry>> _searchRoots(
      List<String> roots, String query, int limit) async {
    final out = <FsEntry>[];
    for (final root in roots) {
      if (out.length >= limit) break;
      out.addAll(await FsScan.search(root, query, limit: limit - out.length));
    }
    return out;
  }

  static List<FsEntry> _postFilter(
    List<FsEntry> hits,
    FmCategory? category,
    bool includeDirs,
  ) =>
      hits
          .where((e) => includeDirs || !e.isDir)
          .where((e) => category == null || e.category == category)
          .toList();
}

// ── isolate'te koşan saf işler ──────────────────────────────────────────────

class _BuildArgs {
  final List<String> roots;
  final String indexPath;
  const _BuildArgs(this.roots, this.indexPath);
}

class _QueryArgs {
  final String indexPath;

  /// Boş ise **tüm** satırlar eşleşir (bkz. `SearchIndex.query` matchAll).
  final String query;
  final String? root;
  final String? categoryName;
  final bool includeDirs;
  final int limit;
  const _QueryArgs({
    required this.indexPath,
    required this.query,
    required this.root,
    required this.categoryName,
    required this.includeDirs,
    required this.limit,
  });
}

/// Tüm kökleri gezip dizin dosyasını yazar; kayıt sayısını döndürür.
///
/// Dosya **akış hâlinde** yazılır (satır satır tampon) — 100 bin satırı tek
/// String'de biriktirmek isolate'i onlarca MB şişirirdi.
int _buildSync(_BuildArgs args) {
  final tmp = File('${args.indexPath}.tmp');
  tmp.parent.createSync(recursive: true);
  final raf = tmp.openSync(mode: FileMode.write);
  final buffer = StringBuffer();
  var count = 0;
  try {
    for (final root in args.roots) {
      walkFiles(
        Directory(root),
        (entry) {
          buffer.writeln(encodeIndexRow(entry));
          count++;
          if (buffer.length >= 64 * 1024) {
            raf.writeStringSync(buffer.toString());
            buffer.clear();
          }
        },
        () {},
        includeDirs: true,
      );
    }
    if (buffer.isNotEmpty) raf.writeStringSync(buffer.toString());
  } finally {
    raf.closeSync();
  }
  // Atomik değiştirme: yarım kalmış dizin dosyası okunmasın.
  tmp.renameSync(args.indexPath);
  return count;
}

List<FsEntry> _querySync(_QueryArgs args) {
  final file = File(args.indexPath);
  if (!file.existsSync()) return const [];
  final needle = turkishFold(args.query);
  FmCategory? category;
  for (final c in FmCategory.values) {
    if (c.name == args.categoryName) category = c;
  }
  final rootPrefix = args.root == null ? null : p.normalize(args.root!);
  final hits = <FsEntry>[];

  // **Parça parça okunur** (64 KB): 100 bin satırlık dizini tek String'e
  // almak isolate'i 10-20 MB şişirirdi. UTF-8'de satırsonu baytı (0x0A) çok
  // baytlı bir dizinin içinde ASLA geçmez → baytları satırsonundan bölmek
  // güvenlidir.
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
        if (!args.includeDirs && entry.isDir) continue;
        if (rootPrefix != null && !FsPaths.isInside(rootPrefix, entry.path)) {
          continue;
        }
        if (category != null && entry.category != category) continue;
        if (needle.isNotEmpty && !turkishFold(entry.name).contains(needle)) {
          continue;
        }
        hits.add(entry);
        if (hits.length >= args.limit) return hits;
      }
      pending.removeRange(0, start);
    }
  } finally {
    raf.closeSync();
  }
  return hits;
}


class _ForgetArgs {
  final String indexPath;
  final List<String> paths;
  const _ForgetArgs({required this.indexPath, required this.paths});
}

/// Dizin dosyasını satır satır kopyalar, [_ForgetArgs.paths] altında kalan
/// satırları atar. Kalan satır sayısını döndürür; dosya yoksa/okunamazsa −1.
///
/// **Geçici dosyaya yazıp `rename`:** yerinde yazmak, iş yarıda kesilirse
/// (uygulama öldürüldü, disk doldu) dizini yarım bırakırdı. `rename` aynı
/// klasörde atomik.
int _forgetSync(_ForgetArgs args) {
  final file = File(args.indexPath);
  if (!file.existsSync()) return -1;
  final tmp = File('${args.indexPath}.tmp');
  var kept = 0;
  try {
    final out = tmp.openSync(mode: FileMode.write);
    try {
      // Tampon: satır başına `writeStringSync` 100 bin sistem çağrısı demekti.
      final buffer = StringBuffer();
      for (final line in file.readAsLinesSync()) {
        final entry = decodeIndexRow(line);
        if (entry == null) continue;
        final path = p.normalize(entry.path);
        final dropped = args.paths.any(
          (t) => p.equals(t, path) || p.isWithin(t, path),
        );
        if (dropped) continue;
        buffer.writeln(line);
        kept++;
        if (buffer.length > 256 * 1024) {
          out.writeStringSync(buffer.toString());
          buffer.clear();
        }
      }
      if (buffer.isNotEmpty) out.writeStringSync(buffer.toString());
    } finally {
      out.closeSync();
    }
    tmp.renameSync(args.indexPath);
    return kept;
  } catch (_) {
    try {
      if (tmp.existsSync()) tmp.deleteSync();
    } catch (_) {}
    return -1;
  }
}
