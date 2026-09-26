import 'dart:io';

import 'package:dosya_okuyucu/services/fm/disk_housekeeping.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/pdf_edit_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// 2026-09-23 tasarım denetimi: disk önbellekleri, geçici dosyalar ve
/// yarıda kalan PDF düzenlemeleri.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('housekeeping');
    FmEnv.appSupportDir = root.path;
    PdfEditJournal.debugReset();
  });

  tearDown(() {
    FmEnv.appSupportDir = '';
    PdfEditJournal.debugReset();
    removeTempDir(root);
  });

  File make(String relative, {Duration age = Duration.zero}) {
    final file = File(p.join(root.path, relative))
      ..createSync(recursive: true)
      ..writeAsStringSync(relative);
    file.setLastModifiedSync(DateTime.now().subtract(age));
    return file;
  }

  group('DiskCache', () {
    test('sınırın üstündeki EN ESKİLER silinir', () {
      for (var i = 0; i < 5; i++) {
        make('c/$i.jpg', age: Duration(hours: 10 - i)); // 0 en eski
      }
      expect(DiskCache.pruneSync(p.join(root.path, 'c'), 3), 2);
      final left = Directory(p.join(root.path, 'c'))
          .listSync()
          .map((e) => p.basename(e.path))
          .toSet();
      expect(left, {'2.jpg', '3.jpg', '4.jpg'});
    });

    test('uzantı süzgeci başka dosyalara dokunmaz', () {
      make('c/a.png', age: const Duration(hours: 3));
      make('c/b.png', age: const Duration(hours: 2));
      make('c/not.txt', age: const Duration(hours: 9));
      expect(
          DiskCache.pruneSync(p.join(root.path, 'c'), 1, extension: '.png'), 1);
      expect(File(p.join(root.path, 'c/not.txt')).existsSync(), isTrue);
      expect(File(p.join(root.path, 'c/b.png')).existsSync(), isTrue);
    });

    test('olmayan klasör sessizce 0', () {
      expect(DiskCache.pruneSync(p.join(root.path, 'yok'), 1), 0);
    });
  });

  group('TempSweep', () {
    const old = Duration(days: 4);
    int now() => DateTime.now().millisecondsSinceEpoch;

    test('yalnız BİZİM ürettiğimiz ESKİ girdiler silinir', () {
      final scanOld = make('fatura_duzeltildi_1695000000000.png', age: old);
      final filterOld = make('fatura_gray_1695000000000.jpg', age: old);
      final ocrOld = make('ocr_page_ab12_3.png', age: old);
      final editDir = make('pdf_editor123/work.pdf', age: old).parent;
      // Süren oturum: içinde YENİ bir dosya var → klasör genç sayılır.
      final liveDir = make('pdf_editor456/work.pdf', age: old).parent;
      make('pdf_editor456/undo_0.pdf');
      final scanNew = make('fatura_duzeltildi_1695000009999.png');
      // Eklentinin (paylaşılan dosya kopyası) dosyası: önbellek kökü olarak
      // işaretlenmeyen bir kökte dokunulmaz (önbellek kökündeki 7 günlük
      // süpürme `app_footprint_test`te).
      final foreign = make('rapor.pdf', age: old);
      final foreignDir = make('file_picker/x.pdf', age: old).parent;

      TempSweep.sweepSync(root.path, now());

      expect(scanOld.existsSync(), isFalse);
      expect(filterOld.existsSync(), isFalse);
      expect(ocrOld.existsSync(), isFalse);
      expect(editDir.existsSync(), isFalse);
      expect(liveDir.existsSync(), isTrue);
      expect(scanNew.existsSync(), isTrue);
      expect(foreign.existsSync(), isTrue);
      expect(foreignDir.existsSync(), isTrue);
    });

    test('arşiv önizleme klasörünün kendisi değil ESKİ içeriği silinir', () {
      final oldPreview = make('arsiv_onizleme/eski.pdf', age: old);
      final newPreview = make('arsiv_onizleme/yeni.pdf');
      TempSweep.sweepSync(root.path, now());
      expect(oldPreview.existsSync(), isFalse);
      expect(newPreview.existsSync(), isTrue);
    });

    test('günlükteki yedeğin klasörü korunur', () {
      final backup = make('dosya_okuyucu_edit42/belge.pdf', age: old);
      TempSweep.sweepSync(root.path, now(), keep: {backup.path});
      expect(backup.existsSync(), isTrue);
    });
  });

  group('PdfEditJournal', () {
    test('yarıda kalan düzenleme açılışta GERİ ALINIR', () {
      final original = make('belgeler/rapor.pdf');
      final backup = make('dosya_okuyucu_edit1/rapor.pdf',
          age: const Duration(minutes: 5));
      backup.writeAsStringSync('ÖZGÜN');
      backup.setLastModifiedSync(
          DateTime.now().subtract(const Duration(minutes: 5)));
      PdfEditJournal.add(original.path, backup.path);
      original.writeAsStringSync('KAYDEDİLMEMİŞ DÜZENLEME');
      // Süreç öldü: yeni süreçte canlı oturum yok.
      PdfEditJournal.debugReset();

      expect(PdfEditJournal.recover(), 1);
      expect(original.readAsStringSync(), 'ÖZGÜN');
      expect(backup.existsSync(), isFalse);
      expect(PdfEditJournal.backups(), isEmpty);
    });

    test('düzgün kapanan oturum kayıt bırakmaz', () {
      final original = make('rapor.pdf');
      final backup = make('dosya_okuyucu_edit2/rapor.pdf');
      PdfEditJournal.add(original.path, backup.path);
      PdfEditJournal.remove(original.path);
      expect(PdfEditJournal.backups(), isEmpty);
    });

    test('bu süreçteki CANLI oturuma dokunulmaz', () {
      final original = make('rapor.pdf');
      final backup = make('dosya_okuyucu_edit3/rapor.pdf',
          age: const Duration(minutes: 1));
      PdfEditJournal.add(original.path, backup.path);
      original.writeAsStringSync('DÜZENLENİYOR');
      expect(PdfEditJournal.recover(), 0);
      expect(original.readAsStringSync(), 'DÜZENLENİYOR');
      expect(PdfEditJournal.backups(), {backup.path});
    });

    test('özgün yedekten ESKİYSE (üstüne biz yazmamışız) geri yazılmaz', () {
      final original =
          make('rapor.pdf', age: const Duration(hours: 1)); // bizden eski
      final backup = make('dosya_okuyucu_edit4/rapor.pdf');
      PdfEditJournal.add(original.path, backup.path);
      PdfEditJournal.debugReset();
      expect(PdfEditJournal.recover(), 0);
      expect(original.readAsStringSync(), 'rapor.pdf');
      expect(PdfEditJournal.backups(), isEmpty);
    });
  });
}
