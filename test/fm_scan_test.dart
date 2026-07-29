import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/entry_opener.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

    tearDown(() => tmp.deleteSync(recursive: true));

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

    test('index: kategori sayıları ve toplam boyut', () async {
      final index = await FsScan.index([tmp.path]);
      expect(index.stat(FmCategory.document).count, 2); // pdf + txt
      expect(index.stat(FmCategory.video).count, 1);
      expect(index.totalFiles, greaterThanOrEqualTo(3));
      expect(index.files(FmCategory.video).first.name, 'video.mp4');
      expect(index.largest.first.sizeBytes, greaterThan(0));
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

    /// 1000 video + 50 görsel satırlık dizin: pano indeksinin kategori başına
    /// 800'lük sınırının ötesine geçildiğini kanıtlar (hata 2026-07-29:
    /// "videolarda tüm videolar görünmüyor").
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fm_collect_test');
      indexPath = p.join(tmp.path, 'search_index.tsv');
      final rows = StringBuffer();
      for (var i = 0; i < 1000; i++) {
        rows.writeln(encodeIndexRow(FsEntry(
          path: '/depo/DCIM/klip_$i.mp4',
          name: 'klip_$i.mp4',
          isDir: false,
          sizeBytes: 1000 + i,
          modifiedMs: 1000 + i,
        )));
      }
      for (var i = 0; i < 50; i++) {
        rows.writeln(encodeIndexRow(FsEntry(
          path: '/depo/Pictures/foto_$i.jpg',
          name: 'foto_$i.jpg',
          isDir: false,
          sizeBytes: 10,
          modifiedMs: 5000 + i,
        )));
      }
      rows.writeln(encodeIndexRow(const FsEntry(
        path: '/depo/DCIM',
        name: 'DCIM',
        isDir: true,
        sizeBytes: 0,
        modifiedMs: 1,
      )));
      File(indexPath).writeAsStringSync(rows.toString());
    });

    tearDown(() => tmp.deleteSync(recursive: true));

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

      final inDcim = await FsScan.collectFromIndex(indexPath,
          root: '/depo/DCIM');
      expect(inDcim.length, 1000);

      final limited = await FsScan.collectFromIndex(indexPath,
          category: FmCategory.video, limit: 10);
      expect(limited.length, 10);
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
}
