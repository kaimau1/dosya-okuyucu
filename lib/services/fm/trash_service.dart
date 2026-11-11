import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;

import 'file_ops.dart';
import 'fs_events.dart';
import 'fs_scan.dart';
import 'path_side_index.dart';
import 'search_index.dart';

/// Çöp kutusundaki tek bir kayıt.
class TrashItem {
  /// Çöp klasöründeki gerçek yol (`…/.dosya-okuyucu-cop/files/<id>`).
  final String storedPath;

  /// Silinmeden önceki yol — geri yükleme buraya yapar.
  final String originalPath;
  final String name;
  final bool isDir;
  final int sizeBytes;
  final int deletedAtMs;

  /// Kaydın ait olduğu çöp klasörü (birim başına bir tane olabilir).
  final String trashDir;

  const TrashItem({
    required this.storedPath,
    required this.originalPath,
    required this.name,
    required this.isDir,
    required this.sizeBytes,
    required this.deletedAtMs,
    required this.trashDir,
  });

  Map<String, dynamic> toMap() => {
        // `files/`e göre göreli yol: alt klasörlü (bkz. [TrashService._shard])
        // ya da eski kayıtlarda yalnız ad — ikisini de [fromMap] okur.
        'stored': p.relative(storedPath, from: p.join(trashDir, 'files')),
        'original': originalPath,
        'name': name,
        'isDir': isDir,
        'size': sizeBytes,
        'deletedAt': deletedAtMs,
      };

  static TrashItem? fromMap(Map<String, dynamic> m, String trashDir) {
    try {
      return TrashItem(
        storedPath: p.join(trashDir, 'files', m['stored'] as String),
        originalPath: m['original'] as String,
        name: m['name'] as String,
        isDir: m['isDir'] as bool? ?? false,
        sizeBytes: (m['size'] as num?)?.toInt() ?? 0,
        deletedAtMs: (m['deletedAt'] as num?)?.toInt() ?? 0,
        trashDir: trashDir,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Geri dönüşüm kutusu: silinen dosyalar önce buraya taşınır, kullanıcı geri
/// yükleyebilir ya da kalıcı silebilir.
///
/// **Karar — çöp klasörü uygulama verisinde DEĞİL, dosyanın kendi biriminde
/// (`/storage/emulated/0/.dosya-okuyucu-cop`):** `/data` ile `/storage` ayrı
/// bağlama noktalarıdır, aradaki `rename` başarısız olur → 2 GB'lık bir videoyu
/// çöpe atmak dosyayı baştan KOPYALARDI. Aynı birimde çöp = silme anında,
/// geri yükleme de anında.
class TrashService {
  /// Birim kökleri (dahili depolama, SD kart…).
  final List<String> volumeRoots;

  /// Birim tespit edilemeyen yollar için yedek çöp kökü (uygulama verisi).
  final String fallbackRoot;

  static const dirName = '.dosya-okuyucu-cop';
  static const _indexFile = 'index.json';

  const TrashService({required this.volumeRoots, required this.fallbackRoot});

  /// [path] hangi birimdeyse o birimin çöp klasörü.
  String trashDirFor(String path) {
    final normalized = p.normalize(path);
    for (final root in volumeRoots) {
      final r = p.normalize(root);
      // `startsWith('$r/')` DEĞİL: p.normalize Windows'ta `\` üretir, literal
      // `/` karşılaştırması hiçbir birimi eşleştirmez ve her şey yedek köke
      // düşer (2026-07-31, Windows test koşusu). p.isWithin iki ayırıcıyı da
      // sınır sayar.
      if (p.equals(normalized, r) || p.isWithin(r, normalized)) {
        return p.join(r, dirName);
      }
    }
    return p.join(fallbackRoot, dirName);
  }

  List<String> get _allTrashDirs => {
        for (final r in volumeRoots) p.join(p.normalize(r), dirName),
        p.join(fallbackRoot, dirName),
      }.toList();

  /// Verilen yolları çöpe taşır.
  static var _counter = 0;
  static const _batch = 64;

  /// Çöpteki alt klasör başına en çok bu kadar öğe (2026-11-02, Mi Note 10
  /// Lite). `/sdcard` FUSE'tan geçiyor ve `rename` maliyeti HEDEF KLASÖRÜN
  /// büyüklüğüyle artıyor: kabukta bile 5.500 dosyalı düz `files/`e taşıma
  /// dosya başına ~150 ms, küçük klasöre ~22 ms. Her çöpe atma çağrısı kendi
  /// `files/<zaman>-<k>/` klasörlerine yazar.
  static const _shard = 256;
  Future<FmOpResult> moveToTrash(
    List<String> paths, {
    void Function(FmProgress)? onProgress,
  }) async {
    final errors = <String>[];
    final gone = <String>[];
    // İş sonucu sayfası için (2026-11-02, A5): özgün yol → çöpteki yol.
    final moves = <FmTransfer>[];
    var ok = 0;
    var done = 0;
    // **Kayıtlar toplu yazılır** (2026-11-02, Mi Note 10 Lite: 5.000 küçük
    // dosya 4 dakikada ancak ~1.800'e varıyordu, giderek yavaşlayarak). KÖK
    // NEDEN: her dosyada büyüyen `index.json` baştan kodlanıp `flush`la
    // yazılıyordu — toplam O(n²). Artık [_batch] dosyada bir yazma; yazma
    // başarısızsa o gruptaki dosyalar eski yerine döner (aşağıdaki güvence).
    // ponytail: süreç grup ortasında ölürse en çok [_batch] dosya kayıtsız
    // kalır (eskiden 1); gerekirse `files/` içindeki kayıtsızları toplayan
    // bir kurtarma eklenir.
    final pending = <(TrashItem, FmTransfer)>[];
    Future<void> flush() async {
      if (pending.isEmpty) return;
      final batch = [...pending];
      pending.clear();
      try {
        await _appendIndex([for (final b in batch) b.$1]);
        ok += batch.length;
        for (final b in batch) {
          gone.add(b.$1.originalPath);
          moves.add(b.$2);
        }
      } catch (e) {
        // KAYIT YAZILAMAZSA DOSYA GERİ GETİRİLİR — açıklama aşağıda.
        for (final (item, _) in batch) {
          var back = false;
          try {
            if (item.isDir) {
              await Directory(item.storedPath).rename(item.originalPath);
            } else {
              await File(item.storedPath).rename(item.originalPath);
            }
            back = true;
            await PathSideIndex.moved(item.storedPath, item.originalPath);
          } catch (_) {
            // Bilinçli: yan kayıt (etiket/geçmiş) taşınamadı — dosyanın kendisi yerinde, yalnız yan bilgi eski yolda kalır.
          }
          final why = back
              ? 'dosya yerinde bırakıldı'
              : 'dosya şurada: ${item.storedPath}';
          errors.add('${item.name}: çöp kaydı yazılamadı ($e); $why');
        }
      }
    }

    final bucket = DateTime.now().millisecondsSinceEpoch;
    final ready = <String>{}; // bu çağrıda kurulan alt klasörler
    for (final path in paths) {
      final name = p.basename(path);
      onProgress?.call(FmProgress(done, paths.length, name));
      try {
        final trashDir = trashDirFor(path);
        final filesDir =
            Directory(p.join(trashDir, 'files', '$bucket-${done ~/ _shard}'));
        if (ready.add(filesDir.path)) {
          await filesDir.create(recursive: true);
          // Çöp klasörünün kendisi medya taramasına girmesin.
          await _ensureNoMedia(trashDir);
        }

        final id = '${DateTime.now().millisecondsSinceEpoch}'
            '-${_counter++}-${FileOps.sanitizeName(name)}';
        final stored = p.join(filesDir.path, id);
        final isDir = Directory(path).existsSync();
        // Klasörün boyutu GERÇEKTEN ölçülür (eskiden 0 yazılıyordu): 4 GB'lık
        // bir klasörü çöpe atıp boşaltmak "0 B yer açıldı" diyordu ve çöp
        // kutusunun toplam boyutu da olduğundan küçük görünüyordu
        // (2026-07-29 sadakat denetimi, 4. tur). Ölçüm ayrı izlekte koşuyor
        // (`FsScan.folderSize`) ve okunamazsa 0'a düşer — yalnız bir gösterge.
        int size;
        if (isDir) {
          try {
            size = await FsScan.folderSize(path);
          } catch (_) {
            size = 0;
          }
        } else {
          size = File(path).statSync().size;
        }

        // Aynı birimde rename anında; olmazsa kopyala+sil'e düş.
        var moved = false;
        try {
          if (isDir) {
            await Directory(path).rename(stored);
          } else {
            await File(path).rename(stored);
          }
          moved = true;
          // Etiket/açılma geçmişi dosyayla birlikte çöpe gider; geri
          // yüklenince eski yoluna döner (bkz. [restore]). Aksi hâlde
          // "çöpe at → geri al" turunda etiketler sessizce kaybolurdu.
          await PathSideIndex.moved(path, stored);
        } on FileSystemException {
          moved = false;
        }
        // Gerçekte nereye indi? Kural olarak `stored`, ama uzun adlarda
        // (ENAMETOOLONG) id ekiyle uzayan ad sığmayabiliyor — o durumda dosya
        // indiği adda BIRAKILIR ve kayıt o adı gösterir. Eskiden bu ikinci
        // `rename` korumasızdı: hata `on FileSystemException` bloğunun DIŞINDA
        // olduğu için dışa fırlıyor, kullanıcının dosyası klasöründen silinmiş
        // ama çöpte de kayıtsız (yani görünmez) kalıyordu — kurtarılamaz bir
        // durum (2026-07-29 sadakat denetimi, 4. tur).
        var storedAt = stored;
        if (!moved) {
          final r = await FileOps.moveAll([path], filesDir.path);
          if (r.hasError) throw FileSystemException(r.errors.first);
          // moveAll adı korur; id'ye çevir ki kayıt tutarlı olsun.
          final landed = p.join(filesDir.path, name);
          try {
            if (File(landed).existsSync()) {
              await File(landed).rename(stored);
            } else if (Directory(landed).existsSync()) {
              await Directory(landed).rename(stored);
            }
          } on FileSystemException {
            // Ad çevrilemedi (ör. çok uzun): dosya `landed`de duruyor, kaydı
            // ona göre yazıyoruz. Kayıp yok, yalnız çöpteki dosya adı özgün ad.
            storedAt = landed;
          }
          // `moveAll` yan kayıtları `landed`e taşıdı; son adım ham `rename`
          // olduğu için oradan `stored`e biz taşıyoruz.
          if (storedAt != landed) await PathSideIndex.moved(landed, storedAt);
        }

        // GÜVENCE (2026-07-25 hatası): kaynak hâlâ yerindeyse çöp kaydı
        // OLUŞTURMA — yoksa dosya hem klasörde hem çöpte görünür. Böyle bir
        // durumda çöpe düşen kopyayı da temizleyip hatayı bildiriyoruz.
        if (File(path).existsSync() || Directory(path).existsSync()) {
          try {
            if (isDir) {
              Directory(storedAt).deleteSync(recursive: true);
            } else {
              File(storedAt).deleteSync();
            }
          } catch (_) {
            // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
          }
          throw const FileSystemException(
              'dosya taşınamadı (yerinde kaldı), çöp kaydı oluşturulmadı');
        }

        // KAYIT YAZILAMAZSA DOSYA GERİ GETİRİLİR. Dosya çöpte olup kaydı
        // olmayan bir durum kullanıcı için "dosyam yok oldu" demektir: çöp
        // ekranı yalnız kayıtlı öğeleri listeliyor, `FsScan` çöp klasörünü
        // atlıyor ve baytlar `1753…-3-rapor.pdf` gibi bir adla erişilemez
        // kalıyor. O yüzden kayıt başarısız olursa dosyayı eski yoluna geri
        // alıp hatayı bildiriyoruz: kullanıcı dosyasını YERİNDE bulur, "silme
        // başarısız" mesajını okur ve yeniden dener (2026-07-29 denetimi, 4.
        // tur — CRITICAL). Geri alma da başarısız olursa yol en azından hata
        // metninde geçer. (Yazma toplu: [flush].)
        pending.add((
          TrashItem(
            storedPath: storedAt,
            originalPath: path,
            name: name,
            isDir: isDir,
            sizeBytes: size,
            deletedAtMs: DateTime.now().millisecondsSinceEpoch,
            trashDir: trashDir,
          ),
          FmTransfer(path, storedAt),
        ));
        if (pending.length >= _batch) await flush();
      } catch (e) {
        errors.add('$name: $e');
      }
      done++;
    }
    await flush();
    onProgress?.call(FmProgress(done, paths.length, ''));
    // **Çöpe atılan dosya arama dizininden de düşer** (kullanıcı hatası
    // 2026-08-25: *"çöpe atılan şeyler bir süre sonra hem çöpte hem
    // görüntüler hem dosyalarda hem son açılanlar hem yeni dosyalarda
    // görülüyor"*). Dizini yalnız bayat işaretlemek yetmiyordu: bayat dizin
    // ancak arama ekranı açılınca yeniden kuruluyor, o zamana kadar aynı
    // dosya hem çöpte hem kategori listelerinde görünüyordu.
    //
    // Geri yüklemede (bkz. [restore]) satır dizine geri YAZILMAZ; dosya
    // eski yolunda gerçekten durduğu için bir sonraki kurulumda kendiliğinden
    // döner, arada da diskten tarayan yollar (gezgin) onu zaten gösterir.
    if (gone.isNotEmpty) await SearchIndex.forget(gone);
    if (ok > 0) FsEvents.changed(gone);
    return FmOpResult(
        succeeded: ok, errors: errors, transfers: moves, trashed: true);
  }

  /// Çöpteki tüm kayıtlar (en yeni önce). Diskte karşılığı kalmamış kayıtlar
  /// (kullanıcı klasörü elle silmişse) listeden düşer.
  ///
  /// **Var olma denetimi arka izlekte** (2026-10-23, kullanıcı: *"çöp kutusu
  /// çok dolu olduğunda açılırken donma kasma oluyor, bazen çökme"*). KÖK
  /// NEDEN: her kayıt için ana izlekte `File.existsSync` + `Directory.
  /// existsSync` — 5 bin kayıtta 10 bin eşzamanlı disk çağrısı, ekran ve
  /// panonun çöp sayacı (her dönüşte) saniyelerce kilitleniyordu.
  Future<List<TrashItem>> list() async {
    final all = <TrashItem>[];
    for (final dir in _allTrashDirs) {
      all.addAll(await _readIndex(dir));
    }
    if (all.isEmpty) return all;
    final paths = [for (final i in all) i.storedPath];
    final alive = paths.length < _isolateFrom
        ? _existing(paths)
        : await _inBackground(_existing, paths);
    final out = [
      for (var i = 0; i < all.length; i++)
        if (alive[i]) all[i],
    ];
    out.sort((a, b) => b.deletedAtMs.compareTo(a.deletedAtMs));
    return out;
  }

  /// Bu sayının altında arka izleğe geçmek (ileti kopyası + izlek açılışı)
  /// denetimin kendisinden pahalı.
  static const _isolateFrom = 200;

  static List<bool> _existing(List<String> paths) => [
        for (final path in paths)
          File(path).existsSync() || Directory(path).existsSync(),
      ];

  static Future<R> _inBackground<A, R>(R Function(A) fn, A arg) async {
    try {
      return await compute(fn, arg);
    } catch (_) {
      return fn(arg);
    }
  }

  /// Kaydı eski yerine geri yükler. Eski yol doluysa `" (1)"` ekiyle.
  Future<String> restore(TrashItem item) async {
    final parent = Directory(p.dirname(item.originalPath));
    if (!parent.existsSync()) await parent.create(recursive: true);
    final target = FileOps.uniquePath(item.originalPath);
    try {
      if (item.isDir) {
        await Directory(item.storedPath).rename(target);
      } else {
        await File(item.storedPath).rename(target);
      }
    } on FileSystemException {
      // Çapraz birim (SD kart ↔ dahili): rename olmaz, kopyala+sil'e düşülür.
      final r = await FileOps.moveAll([item.storedPath], p.dirname(target));
      if (r.hasError) throw FileSystemException(r.errors.first);
      // DÜZELTME (2026-07-29 sadakat denetimi): `moveAll` dosyayı çöpteki
      // **id'li adıyla** ("1753...-0-rapor.pdf") indiriyor, oysa bu metot
      // çağırana `target`ı (eski adı) döndürüyordu — kullanıcıya "eski yerine
      // döndü" denip dosya bambaşka bir adla duruyordu. Son adımı biz atıyoruz.
      final landed = p.join(p.dirname(target), p.basename(item.storedPath));
      if (File(landed).existsSync()) {
        await File(landed).rename(target);
        await PathSideIndex.moved(landed, target);
      } else if (Directory(landed).existsSync()) {
        await Directory(landed).rename(target);
        await PathSideIndex.moved(landed, target);
      }
    }
    // Etiket/açılma geçmişi dosyayla birlikte eski yoluna döner.
    await PathSideIndex.moved(item.storedPath, target);
    await _removeFromIndex(item);
    _dropEmptyShards([item]);
    FsEvents.changed([target]);
    return target;
  }

  /// Kaydı **kalıcı** siler.
  ///
  /// Silme gerçekten başarısız olursa (kart salt-okunur takılmış, dosya başka
  /// bir uygulamada açık) hata **atılır ve kayıt KORUNUR**. Eskiden her hata
  /// yutuluyor, kayıt yine de düşürülüyordu: dosya diskte kalıyor ama artık
  /// çöp ekranında görünmüyor, `FsScan` da çöp klasörünü atladığı için "Yer aç"
  /// onu bulamıyordu → kullanıcının 4 GB'ı uygulama içinden asla geri
  /// kazanılamaz hâle geliyor, üstelik ekran "4,2 GB yer açıldı" diyordu
  /// (2026-07-29 sadakat denetimi, 4. tur).
  ///
  /// Dosya ZATEN yoksa hata değildir: kayıt düşer (kullanıcı elle silmiş olabilir).
  Future<void> deleteForever(TrashItem item) async {
    await _deleteStored(item);
    await _removeFromIndex(item);
    _dropEmptyShards([item]);
    FsEvents.changed();
  }

  /// Boşalan alt klasörleri ([_shard]) siler; dolu olan ya da `files/`in
  /// kendisi kalır (boş olmayan klasörde `delete` hata verir, yutulur).
  void _dropEmptyShards(Iterable<TrashItem> items) {
    for (final dir in {for (final i in items) p.dirname(i.storedPath)}) {
      if (p.basename(dir) == 'files') continue;
      try {
        Directory(dir).deleteSync();
      } catch (_) {
        // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
      }
    }
  }

  /// Dosyanın kendisini siler (kayda dokunmaz). Hata YUKARI çıkar.
  Future<void> _deleteStored(TrashItem item) async {
    final entity = item.isDir
        ? Directory(item.storedPath) as FileSystemEntity
        : File(item.storedPath);
    if (entity.existsSync()) {
      // Hata bilinçli olarak YUKARI çıkar; `empty()` onu sayar ve yazar.
      if (item.isDir) {
        await Directory(item.storedPath).delete(recursive: true);
      } else {
        await File(item.storedPath).delete();
      }
      // Gerçekten gitti mi? Bazı kurulumlarda `delete` sessizce başarısız olur.
      if (entity.existsSync()) {
        throw FileSystemException('silinemedi', item.storedPath);
      }
    }
  }

  /// Birden çok kaydı **tek yazmayla** düşürür (dizin başına bir kez).
  Future<void> _removeManyFromIndex(Iterable<TrashItem> gone) =>
      _withIndexLock(() async {
        final byDir = <String, Set<String>>{};
        for (final i in gone) {
          (byDir[i.trashDir] ??= {}).add(i.storedPath);
        }
        for (final e in byDir.entries) {
          final items = [...await _readIndex(e.key)]
            ..removeWhere((i) => e.value.contains(i.storedPath));
          await _writeIndex(e.key, items);
        }
      });

  /// Toplu kalıcı silme: dosyalar tek tek, kayıtlar ve değişiklik sinyali
  /// **toplu**.
  ///
  /// KÖK NEDEN (2026-10-23, "çöp kutusu dolu → donma, bazen çökme"): boşaltma
  /// her öğe için [deleteForever] çağırıyordu — 5 bin öğede 5 bin kez tüm
  /// `index.json`ı yeniden yazmak VE 5 bin kez `FsEvents.changed()`: her sinyal
  /// açık kategori ekranlarını, panoyu ve sohbet temizliğini disk taramalı
  /// tazelemeye sokuyordu. Kayıtlar [_flushEvery] öğede bir düşer; arada
  /// kesilirse dosyası gitmiş kayıtları [list] zaten göstermez.
  Future<FmOpResult> _deleteMany(
    List<TrashItem> items, {
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final errors = <String>[];
    final pending = <TrashItem>[];
    var ok = 0;
    var done = 0;
    var cancelled = false;
    for (final item in items) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        break;
      }
      onProgress?.call(FmProgress(done, items.length, item.name));
      try {
        await _deleteStored(item);
        pending.add(item);
        ok++;
      } catch (e) {
        errors.add('${item.name}: $e');
      }
      done++;
      if (pending.length >= _flushEvery) {
        await _removeManyFromIndex(pending);
        pending.clear();
      }
    }
    if (pending.isNotEmpty) await _removeManyFromIndex(pending);
    _dropEmptyShards(items);
    if (ok > 0) FsEvents.changed();
    onProgress?.call(FmProgress(done, items.length, ''));
    return FmOpResult(succeeded: ok, errors: errors, cancelled: cancelled);
  }

  static const _flushEvery = 200;

  /// [days] günden eski kayıtları kalıcı siler (ayarlardaki otomatik
  /// temizleme). Silinen öğe sayısını döndürür.
  Future<int> purgeOlderThan(int days) async {
    if (days <= 0) return 0;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final old = [
      for (final item in await list())
        if (item.deletedAtMs > 0 && item.deletedAtMs < cutoff) item,
    ];
    if (old.isEmpty) return 0;
    return (await _deleteMany(old)).succeeded;
  }

  /// Çöp kutusunu boşaltır. [onProgress] verilirse her öğede ilerleme
  /// bildirilir — kullanıcı isteği (2026-07-25): "çöp kutusu boşaltılırken
  /// sessizlik oluyor, ne olduğu belli değil".
  ///
  /// Silinen öğe sayısı ve (varsa) hatalar döner; kısmi başarı sessizce
  /// yutulmaz.
  Future<FmOpResult> empty({
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final items = await list();
    return _deleteMany(items,
        onProgress: onProgress, isCancelled: isCancelled);
  }

  /// Çöpteki toplam boyut (kayıtlardan okunur; klasörler çöpe atılırken
  /// gerçekten ölçülür — bkz. [moveToTrash]).
  Future<int> totalBytes() async {
    var sum = 0;
    for (final item in await list()) {
      sum += item.sizeBytes;
    }
    return sum;
  }

  // ── index.json ─────────────────────────────────────────────────────────

  /// Çözülmüş `index.json` önbelleği: dizin → (dosya damgası, kayıtlar).
  ///
  /// Her geri yükleme/silme/çöpe atma "oku → değiştir → yaz" yapıyor; dolu bir
  /// çöpte (5 bin kayıt ≈ 1 MB JSON) her adımda dosyayı baştan okuyup çözmek
  /// 600 dosyalık bir sohbet temizliğini dakikalara uzatıyordu. Damga (boy +
  /// değişme zamanı) dışarıdan bir yazmayı da yakalar.
  static final Map<String, ({String stamp, List<TrashItem> items})>
      _indexCache = {};

  static String _stampOf(File file) {
    final st = file.statSync();
    return '${st.size}|${st.modified.millisecondsSinceEpoch}';
  }

  Future<List<TrashItem>> _readIndex(String trashDir) async {
    final file = File(p.join(trashDir, _indexFile));
    if (!file.existsSync()) {
      _indexCache.remove(trashDir);
      return const [];
    }
    try {
      final stamp = _stampOf(file);
      final cached = _indexCache[trashDir];
      if (cached != null && cached.stamp == stamp) return cached.items;
      final text = await file.readAsString();
      // Büyük dizin JSON'u arka izlekte çözülür (ana izlekte 1 MB çözmek
      // tek başına birkaç kare yutuyor).
      final rows = text.length < 64 * 1024
          ? _decodeRows(text)
          : await _inBackground(_decodeRows, text);
      final items = rows
          .map((m) => TrashItem.fromMap(m, trashDir))
          .whereType<TrashItem>()
          .toList();
      _indexCache[trashDir] = (stamp: stamp, items: List.unmodifiable(items));
      return items;
    } catch (_) {
      return const [];
    }
  }

  static List<Map<String, dynamic>> _decodeRows(String text) {
    final raw = jsonDecode(text);
    if (raw is! List) return const [];
    return [
      for (final m in raw)
        if (m is Map) m.cast<String, dynamic>(),
    ];
  }

  /// Kaydı **atomik** yazar: geçici dosyaya yaz, sonra `rename`.
  ///
  /// ## Niye (2026-07-29 sadakat denetimi, 4. tur — CRITICAL)
  /// Eskiden `index.json` doğrudan üzerine yazılıyordu: `writeAsString` önce
  /// dosyayı **kısaltır**, sonra doldurur. Yazma arada kesilirse (kart dolu —
  /// ki kullanıcı zaten bu yüzden siliyor; kart çıkarıldı; süreç öldü) dosyada
  /// yarım bir JSON kalıyor ve [_readIndex] bozuk JSON'u boş listeye çeviriyor.
  /// Sonuç: çöp kutusu "boş" görünüyor, o turdaki dosyalar VE tüm eski kayıtlar
  /// birden yok oluyor, baytlar diskte `1753…-12-rapor.pdf` gibi adlarla
  /// `FsScan`ın atladığı gizli klasörde kalıyor — kullanıcı ne görebiliyor, ne
  /// geri alabiliyor, ne de "Yer aç" ile bulabiliyor. `rename` ise atomiktir:
  /// ya eski dosya ya yeni dosya görünür, yarısı asla.
  Future<void> _writeIndex(String trashDir, List<TrashItem> items) async {
    final file = File(p.join(trashDir, _indexFile));
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(items.map((i) => i.toMap()).toList()),
        flush: true);
    await tmp.rename(file.path);
    try {
      _indexCache[trashDir] =
          (stamp: _stampOf(file), items: List.unmodifiable(items));
    } catch (_) {
      _indexCache.remove(trashDir);
    }
  }

  /// Kayıt değişikliklerinin **sırayla** koşmasını sağlayan zincir.
  ///
  /// `_appendIndex`/`_removeFromIndex` "oku → değiştir → yaz" yapıyor ve iki
  /// yanında da `await` var. `showFmProgress`ın "Arka plana al" düğmesi
  /// sayesinde kullanıcı uzun bir silmeyi arka plana atıp hemen başka bir silme
  /// (ya da geri yükleme) başlatabiliyor: A okur (42 kayıt), B okur (42), B 43
  /// yazar, A kendi 43'ünü B'nin kaydı OLMADAN yazar → B'nin dosyası çöpte ama
  /// kaydı yok, yani görünmez ve geri alınamaz (2026-07-29 denetimi, 4. tur).
  /// **static**: kilit dosya başına değil, süreç başına. `TrashService` değer
  /// nesnesi gibi (`const`) kullanılabiliyor ve birden çok örnek aynı
  /// `index.json`a yazabilir; kilidi örneğe bağlamak korumayı boşa çıkarırdı.
  static Future<void> _indexLock = Future<void>.value();

  static Future<T> _withIndexLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _indexLock = _indexLock.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  /// Kayıtları çöp dizinlerine (birim başına bir `index.json`) ekler.
  Future<void> _appendIndex(List<TrashItem> added) => _withIndexLock(() async {
        for (final dir in {for (final i in added) i.trashDir}) {
          final items = [
            ...await _readIndex(dir),
            ...added.where((i) => i.trashDir == dir),
          ];
          await _writeIndex(dir, items);
        }
      });

  Future<void> _removeFromIndex(TrashItem item) => _withIndexLock(() async {
        // _readIndex sabit (değiştirilemez) liste dönebilir → kopyala.
        final items = [...await _readIndex(item.trashDir)]
          ..removeWhere((i) => i.storedPath == item.storedPath);
        await _writeIndex(item.trashDir, items);
      });

  /// `.nomedia`: galeri/müzik uygulamaları çöpteki dosyaları göstermesin.
  Future<void> _ensureNoMedia(String trashDir) async {
    final marker = File(p.join(trashDir, '.nomedia'));
    if (!marker.existsSync()) await marker.create(recursive: true);
  }
}
