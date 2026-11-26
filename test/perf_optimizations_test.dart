import 'dart:io';

import 'package:dosya_okuyucu/core/excel_format.dart';
import 'package:dosya_okuyucu/core/text_search.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/duplicate_finder.dart';
import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('turkishFold ve asciiFold hızlı yol + 1:1 doğruluk', () {
    test('küçük ASCII hızlı yolu aynı nesneyi döndürür', () {
      const ascii = 'fatura_2026-11.pdf';
      expect(identical(turkishFold(ascii), ascii), isTrue);
      expect(identical(asciiFold(ascii), ascii), isTrue);
    });

    test('Türkçe büyük/küçük harf ve 1:1 uzunluk korunur', () {
      const sample = 'İSTANBUL IŞIK ÇAĞRI ÖĞÜT ŞİRİN ÜZÜM';
      final folded = turkishFold(sample);
      expect(folded, 'istanbul ışık çağrı öğüt şirin üzüm');
      expect(folded.length, sample.length);
      expect(asciiFold(sample), 'istanbul isik cagri ogut sirin uzum');
      expect(asciiFold('Kâğıt Îmâlât Rêsûm Élan'), 'kagit imalat resum elan');
    });

    test('findAll indeksleri kaynak metinle tam hizalı kalır', () {
      const text = 'Başlık: İSTANBUL ve IŞIK raporu';
      final hits = findAll(text, 'ışık');
      expect(hits, [20]);
      expect(text.substring(hits.single, hits.single + 4), 'IŞIK');
    });
  });

  group('DuplicateFinder hız ve en büyük kazanç önceliği', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('dup_opt_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('sameContent: 64-bit blok + son hizasız bayt farkını yakalar', () {
      // 300 KB + 5 bayt (256 KB parçayı ve 8 bayt hizalamayı aşar).
      final base = List<int>.generate(300 * 1024 + 5, (i) => i % 251);
      final f1 = File('${tmp.path}/a.bin')..writeAsBytesSync(base);
      final f2 = File('${tmp.path}/b.bin')..writeAsBytesSync(base);
      expect(DuplicateFinder.sameContent(f1.path, f2.path), isTrue);

      final tailDiff = [...base]..[base.length - 1] ^= 0xFF;
      final f3 = File('${tmp.path}/c.bin')..writeAsBytesSync(tailDiff);
      expect(DuplicateFinder.sameContent(f1.path, f3.path), isFalse);

      final midDiff = [...base]..[150 * 1024] ^= 0x01;
      final f4 = File('${tmp.path}/d.bin')..writeAsBytesSync(midDiff);
      expect(DuplicateFinder.sameContent(f1.path, f4.path), isFalse);
    });

    test('fingerprint: 64–128 KB arası dosyalarda son kısım farkını ayırır', () {
      final base = List<int>.generate(90 * 1024, (i) => i % 199);
      final diff = [...base]..[85 * 1024] ^= 0x7F;
      final f1 = File('${tmp.path}/p1.bin')..writeAsBytesSync(base);
      final f2 = File('${tmp.path}/p2.bin')..writeAsBytesSync(diff);
      expect(
        DuplicateFinder.fingerprint(f1.path, base.length),
        isNot(DuplicateFinder.fingerprint(f2.path, diff.length)),
      );
    });

    test('maxGroups sınırında en büyük yer kazandıracak kopyalar önce bulunur',
        () {
      final smallData = List<int>.filled(2048, 7);
      final bigData = List<int>.filled(40 * 1024, 9);
      final s1 = File('${tmp.path}/s1.bin')..writeAsBytesSync(smallData);
      final s2 = File('${tmp.path}/s2.bin')..writeAsBytesSync(smallData);
      final b1 = File('${tmp.path}/b1.bin')..writeAsBytesSync(bigData);
      final b2 = File('${tmp.path}/b2.bin')..writeAsBytesSync(bigData);
      FsEntry e(File f) => FsEntry(
            path: f.path,
            name: f.path.split('/').last,
            isDir: false,
            sizeBytes: f.lengthSync(),
            modifiedMs: 1,
          );
      // Küçükler önce verilse bile maxGroups: 1 ile büyük grup seçilmeli.
      final groups =
          DuplicateFinder.groupSync([e(s1), e(s2), e(b1), e(b2)], 1024, 1);
      expect(groups.single.sizeBytes, 40 * 1024);
    });
  });

  group('FmFilter.apply, FileOps ve Excel biçimleme tutarlılığı', () {
    test('FmFilter.apply çok kelimeli arama + tarih + kopya gizleme', () {
      final now = DateTime(2026, 11, 23, 12);
      final entries = [
        FsEntry(
          path: '/Download/Fatura_Ziraat_2026.pdf',
          name: 'Fatura_Ziraat_2026.pdf',
          isDir: false,
          sizeBytes: 2048,
          modifiedMs: now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
        ),
        FsEntry(
          path: '/Download/Eski_Ziraat_2024.pdf',
          name: 'Eski_Ziraat_2024.pdf',
          isDir: false,
          sizeBytes: 2048,
          modifiedMs: now.subtract(const Duration(days: 400)).millisecondsSinceEpoch,
        ),
      ];
      const filter = FmFilter(dateRange: FmDateRange.week, hideDuplicates: true);
      final res = filter.apply(entries, query: 'ziraat fatura', now: now);
      expect(res.map((e) => e.name), ['Fatura_Ziraat_2026.pdf']);
    });

    test('FileOps.sanitizeName ve generalNumber', () {
      expect(FileOps.sanitizeName(' rapor/test.. '), 'rapor_test');
      expect(generalNumber(12.500), '12,5');
      expect(generalNumber(42.0), '42');
    });
  });
}
