import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
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
  });
}
