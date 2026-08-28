import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_search_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'support/temp_dir.dart';

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
      removeTempDir(tmp);
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

    test('erişim zamanı turda KORUNUR', () {
      // Korunmazsa `lastTouchedMs` sessizce mtime'a düşer ve "6 aydır
      // açılmamış" süzgeci dizinden gelen listelerde yanlış cevap verir.
      const entry = FsEntry(
        path: '/depo/Filmler/Film.mkv',
        name: 'Film.mkv',
        isDir: false,
        sizeBytes: 10,
        modifiedMs: 1000,
        accessedMs: 9000,
      );
      final decoded = decodeIndexRow(encodeIndexRow(entry))!;
      expect(decoded.accessedMs, 9000);
      expect(decoded.lastTouchedMs, 9000);
    });

    test('ESKİ dört alanlı satırlar hâlâ okunur', () {
      // Sürüm yükseltmeden önce yazılmış dizin, yeniden taranana kadar
      // okunabilir kalmalı — yoksa güncellemeden sonra arama boş dönerdi.
      final decoded = decodeIndexRow('/depo/a.pdf\t12\t34\t0')!;
      expect(decoded.sizeBytes, 12);
      expect(decoded.modifiedMs, 34);
      expect(decoded.accessedMs, 0);
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

  // Kullanıcı isteği 2026-07-25: "dosya yöneticisi her açılışta tüm dosyaları
  // baştan tarıyor". Pano artık diski gezmeden yazılmış dizinden kuruluyor —
  // sonucun tam taramayla BİREBİR aynı olması bu testin konusu.
  group('dizinden pano indeksi (diski gezmeden)', () {
    test('tam taramayla aynı sayıları ve listeleri verir', () async {
      final root = Directory(p.join(tmp.path, 'depo'))..createSync();
      File(p.join(root.path, 'not.txt')).writeAsStringSync('a');
      File(p.join(root.path, 'foto.jpg')).writeAsStringSync('bb');
      File(p.join(root.path, 'klip.mp4')).writeAsStringSync('dddd');
      Directory(p.join(root.path, 'Klasör')).createSync();
      File(p.join(root.path, 'Klasör', 'İç Belge.pdf'))
          .writeAsStringSync('ccc');

      final indexPath = p.join(tmp.path, 'arama.tsv');
      final walked =
          await FsScan.index([root.path], searchIndexPath: indexPath);
      final restored = await FsScan.indexFromRows(indexPath);

      expect(restored, isNotNull);
      expect(restored!.totalFiles, walked.totalFiles);
      expect(restored.totalBytes, walked.totalBytes);
      for (final c in FmCategory.values) {
        expect(restored.stat(c).count, walked.stat(c).count,
            reason: '${c.name} sayısı tutmalı');
        expect(restored.stat(c).bytes, walked.stat(c).bytes);
        expect(restored.files(c).map((e) => e.path).toSet(),
            walked.files(c).map((e) => e.path).toSet());
      }
      expect(restored.largest.map((e) => e.path).toList(),
          walked.largest.map((e) => e.path).toList());
      // Türkçe adlar UTF-8 çözümlemesinden sağ çıkmalı.
      expect(
        restored.recent.map((e) => e.name),
        contains('İç Belge.pdf'),
      );
    });

    test('dizin yoksa ya da boşsa null döner (çağıran tam taramaya düşer)',
        () async {
      expect(await FsScan.indexFromRows(p.join(tmp.path, 'yok.tsv')), isNull);
      final bos = p.join(tmp.path, 'bos.tsv');
      File(bos).writeAsStringSync('');
      expect(await FsScan.indexFromRows(bos), isNull);
    });

    test('bozuk satırlar atlanır, sağlamlar sayılır', () async {
      final path = p.join(tmp.path, 'kirik.tsv');
      const saglam = FsEntry(
        path: '/depo/rapor.pdf',
        name: 'rapor.pdf',
        isDir: false,
        sizeBytes: 120,
        modifiedMs: 5,
      );
      File(path).writeAsStringSync(
        '${encodeIndexRow(saglam)}\nyalnız-yol\n\n\t1\t2\t0\n',
      );
      final index = await FsScan.indexFromRows(path);
      expect(index!.totalFiles, 1);
      expect(index.stat(FmCategory.document).bytes, 120);
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
