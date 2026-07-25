import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/services/fm/search_index.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_search_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Arama dizininin **saf** parçaları: satır kodlama/çözme ve panonun
/// taramasıyla üretilen dizin dosyası. (Dizinin kendisi `path_provider`
/// gerektirdiği için ekran katmanı burada kurulmaz.)
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fm_index_test');
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('dizin satırı', () {
    test('kodla → çöz turu bilgiyi korur', () {
      const entry = FsEntry(
        path: '/depo/Belgeler/Rapor.pdf',
        name: 'Rapor.pdf',
        isDir: false,
        sizeBytes: 1234,
        modifiedMs: 1700000000000,
      );
      final decoded = decodeIndexRow(encodeIndexRow(entry))!;
      expect(decoded.path, entry.path);
      expect(decoded.name, 'Rapor.pdf');
      expect(decoded.sizeBytes, 1234);
      expect(decoded.modifiedMs, 1700000000000);
      expect(decoded.isDir, isFalse);
      expect(decoded.category, FmCategory.document);
    });

    test('klasör bayrağı korunur', () {
      const dir = FsEntry(
        path: '/depo/DCIM',
        name: 'DCIM',
        isDir: true,
        sizeBytes: 0,
        modifiedMs: 5,
      );
      expect(decodeIndexRow(encodeIndexRow(dir))!.isDir, isTrue);
    });

    test('bozuk satır sessizce atlanır (dizin bozulsa da arama çalışır)', () {
      expect(decodeIndexRow(''), isNull);
      expect(decodeIndexRow('yalnız-yol'), isNull);
      expect(decodeIndexRow('\t1\t2\t0'), isNull);
    });
  });

  group('tarama dizini yazar', () {
    test('tek yürüyüş hem istatistik hem arama dizini üretir', () async {
      // Dizin dosyası taranan ağacın DIŞINDA (üründe uygulama verisinde
      // durur); içinde olsaydı kendini de sayardı.
      final root = Directory(p.join(tmp.path, 'depo'))..createSync();
      File(p.join(root.path, 'not.txt')).writeAsStringSync('a');
      File(p.join(root.path, 'foto.jpg')).writeAsStringSync('bb');
      Directory(p.join(root.path, 'Klasör')).createSync();
      File(p.join(root.path, 'Klasör', 'İç Belge.pdf'))
          .writeAsStringSync('ccc');

      final indexPath = p.join(tmp.path, 'arama.tsv');
      final result =
          await FsScan.index([root.path], searchIndexPath: indexPath);

      // İstatistikler yalnız DOSYAları sayar (klasör satırı dizine yazılsa da).
      expect(result.totalFiles, 3);
      expect(result.stat(FmCategory.image).count, 1);
      expect(result.stat(FmCategory.document).count, 2);

      // Dizin dosyası: 3 dosya + 1 klasör.
      expect(File(indexPath).existsSync(), isTrue);
      final rows = File(indexPath)
          .readAsLinesSync()
          .map(decodeIndexRow)
          .whereType<FsEntry>()
          .toList();
      expect(rows.length, 4);
      expect(result.searchIndexRows, 4);
      expect(rows.where((r) => r.isDir).length, 1);
      expect(rows.map((r) => r.name), contains('İç Belge.pdf'));
    });

    test('dizin istenmezse yazılmaz ve satır sayısı -1 kalır', () async {
      File(p.join(tmp.path, 'a.txt')).writeAsStringSync('x');
      final result = await FsScan.index([tmp.path]);
      expect(result.searchIndexRows, -1);
      expect(result.totalFiles, 1);
    });
  });

  group('yerinde arama eşleşmesi', () {
    test('Türkçe-duyarlı ve büyük/küçük harf duyarsız', () {
      expect(fmMatches('Işık Raporu.pdf', 'ışık'), isTrue);
      expect(fmMatches('ışık raporu.pdf', 'IŞIK'), isTrue);
      expect(fmMatches('İstanbul.jpg', 'istanbul'), isTrue);
      expect(fmMatches('Rapor.pdf', 'xyz'), isFalse);
    });

    test('boş sorgu her şeyi geçirir (süzgeç kapalı demektir)', () {
      expect(fmMatches('herhangi.txt', ''), isTrue);
      expect(fmMatches('herhangi.txt', '   '), isTrue);
    });
  });
}
