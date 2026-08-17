import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/folder_usage.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// Klasör haritası (bellek analizi → "hangi klasör ne kadar yer kaplıyor").
void main() {
  group('childSegment', () {
    test('kökün HEMEN altındaki parçayı verir, daha derinini değil', () {
      final root = p.join('depo', 'ana');
      expect(childSegment(root, p.join(root, 'DCIM', 'Camera', 'a.jpg')),
          'DCIM');
      expect(childSegment(root, p.join(root, 'not.txt')), 'not.txt');
    });

    test('kökün dışındaki ve kökün kendisi olan yol sayılmaz', () {
      final root = p.join('depo', 'ana');
      expect(childSegment(root, p.join('depo', 'baska', 'a.jpg')), isNull);
      expect(childSegment(root, root), isNull);
      // Ad benzerliği yeterli DEĞİL: "ana2" "ana"nın altında değildir.
      expect(childSegment(root, p.join('depo', 'ana2', 'a.jpg')), isNull);
    });
  });

  group('FolderUsageScan', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('klasor-haritasi');
      Directory(p.join(tmp.path, 'DCIM', 'Camera')).createSync(recursive: true);
      Directory(p.join(tmp.path, 'Belgeler')).createSync(recursive: true);
      // DCIM: 300 bayt (iki dosya, biri iki seviye derinde)
      File(p.join(tmp.path, 'DCIM', 'kapak.jpg')).writeAsStringSync('a' * 100);
      File(p.join(tmp.path, 'DCIM', 'Camera', 'foto.jpg'))
          .writeAsStringSync('b' * 200);
      // Belgeler: 50 bayt
      File(p.join(tmp.path, 'Belgeler', 'not.txt')).writeAsStringSync('c' * 50);
      // Kökteki tek dosya da bir "çocuk"tur.
      File(p.join(tmp.path, 'kok.txt')).writeAsStringSync('d' * 10);
    });

    tearDown(() => removeTempDir(tmp));

    test('diskten: çocuklar büyükten küçüğe, alt klasörler DAHİL', () async {
      final data = await FolderUsageScan.of(tmp.path);

      expect(data.children.map((c) => c.name), ['DCIM', 'Belgeler', 'kok.txt']);
      final dcim = data.children.first;
      expect(dcim.isDir, isTrue);
      expect(dcim.bytes, 300); // alt klasördeki dosya da sayıldı
      expect(dcim.files, 2);

      // Kökteki düz dosya klasör DEĞİL — haritada içine girilemez.
      expect(data.children.last.isDir, isFalse);
      expect(data.totalBytes, 360);
      expect(data.totalFiles, 4);
    });

    test('arama dizininden: diske hiç girmeden aynı sonuç', () async {
      final indexPath = p.join(tmp.path, 'dizin.tsv');
      final rows = [
        FsEntry(
            path: p.join(tmp.path, 'DCIM', 'kapak.jpg'),
            name: 'kapak.jpg',
            isDir: false,
            sizeBytes: 100,
            modifiedMs: 0),
        FsEntry(
            path: p.join(tmp.path, 'DCIM', 'Camera', 'foto.jpg'),
            name: 'foto.jpg',
            isDir: false,
            sizeBytes: 200,
            modifiedMs: 0),
        FsEntry(
            path: p.join(tmp.path, 'Belgeler', 'not.txt'),
            name: 'not.txt',
            isDir: false,
            sizeBytes: 50,
            modifiedMs: 0),
      ];
      File(indexPath)
          .writeAsStringSync(rows.map(encodeIndexRow).join('\n'));

      final data = await FolderUsageScan.of(tmp.path, indexPath: indexPath);
      expect(data.children.map((c) => c.name), ['DCIM', 'Belgeler']);
      expect(data.children.first.bytes, 300);
      expect(data.totalBytes, 350);
    });

    test('dizin yoksa sessizce diske düşülür (boş sonuç DÖNMEZ)', () async {
      final data = await FolderUsageScan.of(
        tmp.path,
        indexPath: p.join(tmp.path, 'olmayan-dizin.tsv'),
      );
      expect(data.children, isNotEmpty);
      expect(data.totalBytes, 360);
    });

    test('boş klasörde çöker değil, boş döner', () async {
      final bos = Directory(p.join(tmp.path, 'bos'))..createSync();
      final data = await FolderUsageScan.of(bos.path);
      expect(data.children, isEmpty);
      expect(data.totalBytes, 0);
    });
  });
}
