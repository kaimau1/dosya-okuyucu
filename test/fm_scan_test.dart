import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/entry_opener.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'support/temp_dir.dart';

void main() {
  group('kategori eşlemesi', () {
    test('uzantılar doğru kategoriye düşer', () {
      expect(FsEntry.categoryForExtension('mp4'), FmCategory.video);
      expect(FsEntry.categoryForExtension('MP3'), FmCategory.audio);
      expect(FsEntry.categoryForExtension('jpeg'), FmCategory.image);
      expect(FsEntry.categoryForExtension('docx'), FmCategory.document);
      expect(FsEntry.categoryForExtension('pdf'), FmCategory.document);
      expect(FsEntry.categoryForExtension('zip'), FmCategory.archive);
      expect(FsEntry.categoryForExtension('apk'), FmCategory.apk);
      expect(FsEntry.categoryForExtension('bilinmeyen'), FmCategory.other);
      expect(FsEntry.categoryForExtension('', isDir: true), FmCategory.folder);
    });

    test('uzantı adın son noktasından okunur, gizli dosya ayrılır', () {
      const entry = FsEntry(
        path: '/a/.gizli.tar.gz',
        name: '.gizli.tar.gz',
        isDir: false,
        sizeBytes: 1,
        modifiedMs: 0,
      );
      expect(entry.extension, 'gz');
      expect(entry.isHidden, isTrue);
      expect(entry.category, FmCategory.archive);
    });
  });

  group('sıralama', () {
    FsEntry e(String name, {bool dir = false, int size = 0, int ms = 0}) =>
        FsEntry(
          path: '/x/$name',
          name: name,
          isDir: dir,
          sizeBytes: size,
          modifiedMs: ms,
        );

    test('klasörler üstte, ad Türkçe-duyarlı sıralanır', () {
      final sorted = FsScan.sort(
        [e('zebra.txt'), e('Işık.txt'), e('alt', dir: true), e('elma.txt')],
        FmSort.name,
      );
      expect(sorted.map((x) => x.name).toList(),
          ['alt', 'elma.txt', 'Işık.txt', 'zebra.txt']);
    });

    test('boyuta göre azalan', () {
      final sorted = FsScan.sort(
        [e('a', size: 10), e('b', size: 300), e('c', size: 50)],
        FmSort.size,
        descending: true,
      );
      expect(sorted.map((x) => x.name).toList(), ['b', 'c', 'a']);
    });

    test('tarihe göre azalan (en yeni önce)', () {
      final sorted = FsScan.sort(
        [e('eski', ms: 100), e('yeni', ms: 900), e('orta', ms: 500)],
        FmSort.date,
        descending: true,
      );
      expect(sorted.map((x) => x.name).toList(), ['yeni', 'orta', 'eski']);
    });
  });

  group('yol yardımcıları', () {
    test('isInside: klasörün kendi içine taşınması yakalanır', () {
      expect(FsPaths.isInside('/a/b', '/a/b/c'), isTrue);
      expect(FsPaths.isInside('/a/b', '/a/b'), isTrue);
      expect(FsPaths.isInside('/a/b', '/a/bc'), isFalse);
      expect(FsPaths.isInside('/a/b', '/a'), isFalse);
    });

    test('humanSize: Türkçe ondalık ayracı', () {
      expect(FsPaths.humanSize(0), '0 B');
      expect(FsPaths.humanSize(512), '512 B');
      expect(FsPaths.humanSize(1536), '1,5 KB');
      expect(FsPaths.humanSize(5 * 1024 * 1024 * 1024), '5,0 GB');
    });
  });

  group('disk üzerinde tarama', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fm_scan_test');
      File(p.join(tmp.path, 'Rapor.pdf')).writeAsStringSync('123');
      File(p.join(tmp.path, '.gizli')).writeAsStringSync('x');
      Directory(p.join(tmp.path, 'alt')).createSync();
      File(p.join(tmp.path, 'alt', 'İSTANBUL notlari.txt'))
          .writeAsStringSync('abc');
      File(p.join(tmp.path, 'alt', 'video.mp4')).writeAsStringSync('12345');
    });

    tearDown(() => removeTempDir(tmp));

    test('list: gizli dosyalar varsayılan olarak gizlenir', () async {
      final visible = await FsScan.list(tmp.path);
      expect(visible.map((e) => e.name), isNot(contains('.gizli')));

      final all = await FsScan.list(tmp.path, showHidden: true);
      expect(all.map((e) => e.name), contains('.gizli'));
    });

    test('search: Türkçe büyük/küçük harf farkına takılmaz', () async {
      final hits = await FsScan.search(tmp.path, 'istanbul');
      expect(hits.map((e) => e.name), contains('İSTANBUL notlari.txt'));
    });

    test('statFolders: klasörün EKSİKSİZ sayısı ve boyutu', () async {
      // Pano "Önemli Dosyalar" kutusu bu sayıyı "en yeni 300 + en büyük 200"
      // listelerini süzerek çıkarıyordu; o listeler tüm depolamanın en
      // yenisi/en büyüğü olduğu için 99 öğelik bir klasör "15" görünüyordu
      // (kullanıcı ekran görüntüsü 2026-08-17).
      final klasor = Directory(p.join(tmp.path, 'Önemli Dosyalar'))
        ..createSync();
      File(p.join(klasor.path, 'a.txt')).writeAsStringSync('12345');
      File(p.join(klasor.path, 'b.txt')).writeAsStringSync('123');
      Directory(p.join(klasor.path, 'alt')).createSync();
      File(p.join(klasor.path, 'alt', 'c.txt')).writeAsStringSync('1');

      final index = await FsScan.index([tmp.path], statFolders: [klasor.path]);
      final stat = index.folderStat(klasor.path);
      expect(stat, isNotNull);
      expect(stat!.count, 3); // alt klasördeki de sayılır
      expect(stat.bytes, 9);

      // İstenmeyen klasör için null döner — "0 dosya" ile "sayılmadı" ayrı
      // şeyler; çağıran tahmin ETMEMELİ.
      expect(index.folderStat(p.join(tmp.path, 'alt')), isNull);
    });

    test('index: kategori sayıları ve toplam boyut', () async {
      final index = await FsScan.index([tmp.path]);
      expect(index.stat(FmCategory.document).count, 2); // pdf + txt
      expect(index.stat(FmCategory.video).count, 1);
      expect(index.totalFiles, greaterThanOrEqualTo(3));
      expect(index.files(FmCategory.video).first.name, 'video.mp4');
      expect(index.largest.first.sizeBytes, greaterThan(0));
    });

    test('her kategorinin KENDİ en büyükleri ayrı tutulur', () async {
      // Bellek analizinde "Belgeler"e süzen kullanıcı boş ekran görüyordu:
      // genel en büyükler listesi (200 dosya) pratikte hep videodur, onu
      // süzmek hiçbir belge bırakmıyordu.
      final index = await FsScan.index([tmp.path]);

      final docs = index.largestOf(FmCategory.document);
      expect(docs, isNotEmpty);
      expect(docs.every((e) => e.category == FmCategory.document), isTrue);
      // Kendi içinde büyükten küçüğe.
      for (var i = 1; i < docs.length; i++) {
        expect(docs[i - 1].sizeBytes, greaterThanOrEqualTo(docs[i].sizeBytes));
      }

      final videos = index.largestOf(FmCategory.video);
      expect(videos.map((e) => e.name), ['video.mp4']);

      // null → genel liste (kategori süzgeci kapalıyken gösterilen).
      expect(index.largestOf(null), index.largest);
      // Hiç dosyası olmayan kategori boş liste döner (null değil).
      expect(index.largestOf(FmCategory.archive), isEmpty);
    });

    test('folderSize: alt klasörler dahil toplanır', () async {
      final size = await FsScan.folderSize(tmp.path);
      expect(size, 3 + 1 + 3 + 5); // Rapor.pdf + .gizli + txt + mp4
    });

    test('collect: kategori süzgeciyle diskten eksiksiz liste', () async {
      final videos = await FsScan.collect([tmp.path], category: FmCategory.video);
      expect(videos.map((e) => e.name), ['video.mp4']);

      final all = await FsScan.collect([tmp.path]);
      expect(all.length, 4); // gizli dosya da dosyadır, klasör sayılmaz
      expect(all.any((e) => e.isDir), isFalse);
    });

    test('pruneMissing: silinen girdiler listeden düşer', () async {
      final all = await FsScan.collect([tmp.path]);
      File(p.join(tmp.path, 'Rapor.pdf')).deleteSync();
      final alive = await FsScan.pruneMissing(all);
      expect(alive.length, all.length - 1);
      expect(alive.map((e) => e.name), isNot(contains('Rapor.pdf')));
    });
  });

  group('dizinden eksiksiz kategori listesi', () {
    late Directory tmp;
    late String indexPath;

    late String dcim;
    late String pictures;

    /// 1000 video + 50 görsel satırlık dizin: pano indeksinin kategori başına
    /// 800'lük sınırının ötesine geçildiğini kanıtlar (hata 2026-07-29:
    /// "videolarda tüm videolar görünmüyor").
    ///
    /// **Dosyalar diskte GERÇEKTEN oluşturulur** (2026-08-25): `collectFromIndex`
    /// artık dizindeki satırın karşılığı diskte duruyor mu diye bakıyor —
    /// çöpe atılan dosya kategori listelerinde hayalet olarak kalmasın diye
    /// (bkz. `_collectFromIndexSync`). Uydurma yollarla kurulan bir kurgu bu
    /// süzgeçten geçemezdi ve test gerçeği ölçmez olurdu.
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fm_collect_test');
      indexPath = p.join(tmp.path, 'search_index.tsv');
      dcim = p.join(tmp.path, 'DCIM');
      pictures = p.join(tmp.path, 'Pictures');
      Directory(dcim).createSync(recursive: true);
      Directory(pictures).createSync(recursive: true);
      final rows = StringBuffer();
      for (var i = 0; i < 1000; i++) {
        final path = p.join(dcim, 'klip_$i.mp4');
        File(path).writeAsStringSync('v');
        rows.writeln(encodeIndexRow(FsEntry(
          path: path,
          name: 'klip_$i.mp4',
          isDir: false,
          sizeBytes: 1000 + i,
          modifiedMs: 1000 + i,
        )));
      }
      for (var i = 0; i < 50; i++) {
        final path = p.join(pictures, 'foto_$i.jpg');
        File(path).writeAsStringSync('i');
        rows.writeln(encodeIndexRow(FsEntry(
          path: path,
          name: 'foto_$i.jpg',
          isDir: false,
          sizeBytes: 10,
          modifiedMs: 5000 + i,
        )));
      }
      rows.writeln(encodeIndexRow(FsEntry(
        path: dcim,
        name: 'DCIM',
        isDir: true,
        sizeBytes: 0,
        modifiedMs: 1,
      )));
      File(indexPath).writeAsStringSync(rows.toString());
    });

    tearDown(() => removeTempDir(tmp));

    test('800 sınırı yok: 1000 videonun hepsi döner, yeniden eskiye sıralı',
        () async {
      final videos = await FsScan.collectFromIndex(indexPath,
          category: FmCategory.video);
      expect(videos.length, 1000);
      expect(videos.first.name, 'klip_999.mp4'); // en yeni başta
      expect(videos.last.name, 'klip_0.mp4');
      expect(videos.any((e) => e.isDir), isFalse);
    });

    test('kategori ve kök süzgeci', () async {
      final images = await FsScan.collectFromIndex(indexPath,
          category: FmCategory.image);
      expect(images.length, 50);

      final inDcim = await FsScan.collectFromIndex(indexPath, root: dcim);
      expect(inDcim.length, 1000);

      final limited = await FsScan.collectFromIndex(indexPath,
          category: FmCategory.video, limit: 10);
      expect(limited.length, 10);
    });

    /// **Çöpe atılan dosya kategori listesinde kalmaz** (kullanıcı hatası
    /// 2026-08-25: *"çöpe atılan şeyler bir süre sonra hem çöpte hem
    /// görüntüler hem dosyalarda … görülüyor"*). Dizin satırı duruyor ama
    /// dosya diskte yok → liste onu göstermemeli.
    test('diskte olmayan satır (silinmiş/çöpe atılmış) listeye girmez',
        () async {
      File(p.join(pictures, 'foto_0.jpg')).deleteSync();
      File(p.join(pictures, 'foto_1.jpg')).deleteSync();
      final images = await FsScan.collectFromIndex(indexPath,
          category: FmCategory.image);
      expect(images.length, 48);
      expect(images.map((e) => e.name), isNot(contains('foto_0.jpg')));
    });

    test('dizin yoksa boş liste döner (çağıran diske düşer)', () async {
      final out =
          await FsScan.collectFromIndex(p.join(tmp.path, 'yok.tsv'));
      expect(out, isEmpty);
    });
  });

  group('açma yönlendirmesi', () {
    test('dosya türü doğru ekrana gider', () {
      expect(EntryOpener.routeFor('/a/foto.jpg'), OpenRoute.gallery);
      expect(EntryOpener.routeFor('/a/klip.MP4'), OpenRoute.player);
      expect(EntryOpener.routeFor('/a/sarki.mp3'), OpenRoute.audio);
      expect(EntryOpener.routeFor('/a/rapor.pdf'), OpenRoute.document);
      expect(EntryOpener.routeFor('/a/notlar'), OpenRoute.document); // uzantısız
      expect(EntryOpener.routeFor('/a/uygulama.apk'), OpenRoute.external);
      // Arşiv artık uygulama içinde açılır — eskiden sistemin uygulamasına
      // gidiyordu, yani kendi arşiv ekranımız yalnız dosya gezgininden
      // erişilebiliyordu (2026-07-27).
      expect(EntryOpener.routeFor('/a/arsiv.rar'), OpenRoute.archive);
      expect(EntryOpener.routeFor('/a/yedek.zip'), OpenRoute.archive);
      // Okuyamadığımız arşiv biçimi yine sisteme gider.
      expect(EntryOpener.routeFor('/a/imaj.iso'), OpenRoute.external);
    });

    test('kardeş listesi yalnız aynı türü toplar (galeri/çalma listesi)', () {
      const all = [
        '/a/1.jpg',
        '/a/2.png',
        '/a/rapor.pdf',
        '/a/klip.mp4',
        '/a/ses.mp3',
      ];
      expect(EntryOpener.siblingsFor('/a/1.jpg', all), ['/a/1.jpg', '/a/2.png']);
      // Video ve ses AYRI çalma listeleri (farklı oynatıcı/motor).
      expect(EntryOpener.siblingsFor('/a/klip.mp4', all), ['/a/klip.mp4']);
      expect(EntryOpener.siblingsFor('/a/ses.mp3', all), ['/a/ses.mp3']);
      // Listede olmayan dosya başa eklenir (yine de açılabilsin).
      expect(EntryOpener.siblingsFor('/a/9.jpg', const ['/a/1.jpg']),
          ['/a/9.jpg', '/a/1.jpg']);
    });
  });

  group('yeni dosyaların indekse katılması (mergeFresh)', () {
    FsEntry file(String path, {int ms = 0, int size = 10}) => FsEntry(
          path: path,
          name: p.basename(path),
          isDir: false,
          sizeBytes: size,
          modifiedMs: ms,
        );

    /// Kullanıcı isteği 2026-08-17: pano bir saniye önce eklenen dosyayı da
    /// göstermeli. Sıcak klasör taraması bulur, bu birleştirme indekse işler.
    test('yeni dosya "Yeni Dosyalar"a, kategorisine ve sayaca girer', () {
      const base = StorageIndex(
        stats: {FmCategory.image: CategoryStat(1, 10)},
        byCategory: {},
        largest: [],
        recent: [],
        totalFiles: 1,
        totalBytes: 10,
        skipped: 0,
      );
      final merged = base.mergeFresh([file('/a/yeni.jpg', ms: 5000, size: 40)]);

      expect(merged.recent.single.path, '/a/yeni.jpg');
      expect(merged.files(FmCategory.image).single.path, '/a/yeni.jpg');
      expect(merged.stat(FmCategory.image).count, 2);
      expect(merged.stat(FmCategory.image).bytes, 50);
      expect(merged.totalFiles, 2);
    });

    test('zaten bilinen dosya İKİ KEZ sayılmaz', () {
      final known = file('/a/eski.jpg', ms: 1000);
      final base = StorageIndex(
        stats: const {FmCategory.image: CategoryStat(1, 10)},
        byCategory: {FmCategory.image: [known]},
        largest: const [],
        recent: [known],
        totalFiles: 1,
        totalBytes: 10,
        skipped: 0,
      );
      // Sıcak klasör taraması aynı dosyayı her açılışta yeniden bulur.
      final merged = base.mergeFresh([known]);
      expect(identical(merged, base), isTrue);
      expect(merged.stat(FmCategory.image).count, 1);
    });

    test('birleştirilen liste yeniden eskiye sıralı kalır', () {
      final old = file('/a/eski.pdf', ms: 1000);
      final base = StorageIndex(
        stats: const {},
        byCategory: {FmCategory.document: [old]},
        largest: const [],
        recent: [old],
        totalFiles: 1,
        totalBytes: 10,
        skipped: 0,
      );
      final merged = base.mergeFresh([file('/a/yeni.pdf', ms: 9000)]);
      expect(merged.recent.map((e) => e.name), ['yeni.pdf', 'eski.pdf']);
    });
  });

  group('sıcak klasör taraması (freshFiles)', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('fresh_files');
    });

    tearDown(() => removeTempDir(dir));

    /// Sınır, yürüyüş sırasına göre KESMEZ: ağaç sonuna kadar gezilir ve
    /// bellekte en yeniler tutulur. Eskiden `stop:` ile kesiliyordu — 7000
    /// fotoğraflı bir DCIM'de kullanıcının az önce çektiği kare listeye hiç
    /// girmeyebilirdi.
    test('sınır varken bile EN YENİLER döner', () async {
      // 20 dosya; en yeni olanlar dizin sırasında SONA yazılıyor.
      for (var i = 0; i < 20; i++) {
        final f = File(p.join(dir.path, 'dosya_$i.txt'))..writeAsStringSync('x');
        f.setLastModifiedSync(
            DateTime.fromMillisecondsSinceEpoch(1700000000000 + i * 60000));
      }
      final hits = await FsScan.freshFiles([dir.path], limit: 5);
      expect(hits.length, 5);
      // En yeni beş: dosya_19 … dosya_15, yeniden eskiye sıralı.
      expect(hits.map((e) => e.name),
          ['dosya_19.txt', 'dosya_18.txt', 'dosya_17.txt', 'dosya_16.txt',
           'dosya_15.txt']);
    });

    test('sinceMs eski dosyaları eler', () async {
      final eski = File(p.join(dir.path, 'eski.txt'))..writeAsStringSync('x');
      eski.setLastModifiedSync(DateTime.fromMillisecondsSinceEpoch(1000));
      final yeni = File(p.join(dir.path, 'yeni.txt'))..writeAsStringSync('x');
      yeni.setLastModifiedSync(
          DateTime.fromMillisecondsSinceEpoch(1700000000000));

      final hits = await FsScan.freshFiles([dir.path], sinceMs: 1600000000000);
      expect(hits.map((e) => e.name), ['yeni.txt']);
    });

    test('olmayan kök çökmez', () async {
      final hits = await FsScan.freshFiles([p.join(dir.path, 'yok')]);
      expect(hits, isEmpty);
    });
  });
}
