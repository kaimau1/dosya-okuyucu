import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/pdf_edit_journal.dart';
import 'package:dosya_okuyucu/services/fm/safe_write.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// **0 bayt PDF bulgusu** (2026-09-27): 3239 sayfalık kitaba vurgu eklenip
/// çıkılıp girilince dosya 0 bayt oldu. Kök neden "önce sıfırla, sonra yaz"
/// kalıbı (writeAsBytes / copySync) + ekran kapanırken ana izlekte büyük
/// kopya. Bu testler yeni güvenceleri kilitliyor.
List<int> fakePdf(String body) =>
    '%PDF-1.4\n${'x' * 80}\n$body\n%%EOF\n'.codeUnits;

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('safe_write_test');
    FmEnv.appSupportDir = p.join(dir.path, 'support');
    Directory(FmEnv.appSupportDir).createSync();
    PdfEditJournal.debugReset();
  });

  tearDown(() {
    FmEnv.appSupportDir = '';
    PdfEditJournal.debugReset();
    dir.deleteSync(recursive: true);
  });

  group('SafeWrite', () {
    test('yazar ve geçici dosya bırakmaz', () async {
      final target = p.join(dir.path, 'kitap.pdf');
      File(target).writeAsBytesSync(fakePdf('eski'));
      await SafeWrite.bytes(target, fakePdf('yeni'));
      expect(String.fromCharCodes(File(target).readAsBytesSync()),
          contains('yeni'));
      final leftovers = dir
          .listSync()
          .where((e) => p.basename(e.path).contains(SafeWrite.marker));
      expect(leftovers, isEmpty);
    });

    test('copy özgünü bölünmeden geri yazar', () async {
      final target = p.join(dir.path, 'kitap.pdf');
      final backup = p.join(dir.path, 'yedek.pdf');
      File(target).writeAsBytesSync(fakePdf('düzenlenmiş'));
      File(backup).writeAsBytesSync(fakePdf('özgün'));
      await SafeWrite.copy(backup, target);
      expect(String.fromCharCodes(File(target).readAsBytesSync()),
          contains('özgün'));
    });

    test('yarım yazmadan kalan gizli dosyalar temizlenir', () async {
      final target = p.join(dir.path, 'kitap.pdf');
      File(target).writeAsBytesSync(fakePdf('x'));
      final leftover =
          File(p.join(dir.path, '.kitap.pdf${SafeWrite.marker}-123'));
      leftover.writeAsBytesSync([1, 2, 3]);
      final other = File(p.join(dir.path, '.baska.pdf${SafeWrite.marker}-1'));
      other.writeAsBytesSync([1]);
      await SafeWrite.cleanupLeftovers(target);
      expect(leftover.existsSync(), isFalse);
      // Başka dosyanın artığına dokunulmaz.
      expect(other.existsSync(), isTrue);
    });
  });

  group('PdfBytesCheck', () {
    test('boş ya da başlıksız çıktı GEÇERSİZ', () {
      expect(PdfBytesCheck.looksValid(const []), isFalse);
      expect(PdfBytesCheck.looksValid(List.filled(500, 0x20)), isFalse);
      expect(PdfBytesCheck.looksValid(fakePdf('tamam')), isTrue);
    });

    test('%%EOF ile bitmeyen (yarım) dosya GEÇERSİZ', () {
      final full = fakePdf('gövde ${'y' * 5000}');
      final half = full.sublist(0, full.length - 100);
      expect(PdfBytesCheck.looksValid(half), isFalse);
    });

    test('dosya denetimi baş ve sonu okur', () async {
      final f = File(p.join(dir.path, 'a.pdf'))
        ..writeAsBytesSync(fakePdf('b' * 10000));
      expect(await PdfBytesCheck.fileLooksValid(f.path), isTrue);
      f.writeAsBytesSync(const []);
      expect(await PdfBytesCheck.fileLooksValid(f.path), isFalse);
      expect(PdfBytesCheck.fileLooksValidSync(f.path), isFalse);
    });
  });

  group('PdfEditJournal.recover', () {
    test('0 bayta düşmüş özgün tarihe bakılmadan GERİ YÜKLENİR', () {
      final original = File(p.join(dir.path, 'kitap.pdf'))
        ..writeAsBytesSync(fakePdf('özgün'));
      final backupDir = Directory(PdfEditJournal.backupRoot()!)
        ..createSync(recursive: true);
      final backup = File(p.join(backupDir.path, 'kitap.pdf'))
        ..writeAsBytesSync(fakePdf('özgün'));
      PdfEditJournal.add(original.path, backup.path);
      PdfEditJournal.debugReset(); // süreç öldü: oturum artık canlı değil
      // Yarım kalmış yazma: dosya 0 bayt ve yedekten ESKİ görünüyor.
      original.writeAsBytesSync(const []);
      original.setLastModifiedSync(
          backup.lastModifiedSync().subtract(const Duration(hours: 1)));

      expect(PdfEditJournal.hasStale(original.path), isTrue);
      expect(PdfEditJournal.recover(only: original.path), 1);
      expect(
          String.fromCharCodes(original.readAsBytesSync()), contains('özgün'));
      expect(PdfEditJournal.hasStale(original.path), isFalse);
    });

    test('sağlam ve yedekten eski özgün EZİLMEZ (başkası yazmış)', () {
      final original = File(p.join(dir.path, 'rapor.pdf'))
        ..writeAsBytesSync(fakePdf('kullanici yeni hali'));
      final backup = File(p.join(dir.path, 'yedek.pdf'))
        ..writeAsBytesSync(fakePdf('eski'));
      PdfEditJournal.add(original.path, backup.path);
      PdfEditJournal.debugReset();
      original.setLastModifiedSync(
          backup.lastModifiedSync().subtract(const Duration(hours: 1)));
      expect(PdfEditJournal.recover(), 0);
      expect(String.fromCharCodes(original.readAsBytesSync()),
          contains('kullanici yeni hali'));
    });
  });

  group('PdfRestoreQueue', () {
    test('aynı dosyanın işleri sırayla koşar, bitince kayıt düşer', () async {
      final order = <int>[];
      final a = PdfRestoreQueue.run('/x.pdf', () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        order.add(1);
      });
      final b = PdfRestoreQueue.run('/x.pdf', () async => order.add(2));
      expect(PdfRestoreQueue.pendingFor('/x.pdf'), isNotNull);
      await Future.wait([a, b]);
      expect(order, [1, 2]);
      expect(PdfRestoreQueue.pendingFor('/x.pdf'), isNull);
    });
  });
}
