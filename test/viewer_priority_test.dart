import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/core/startup_queue.dart';
import 'package:dosya_okuyucu/core/viewer_priority.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/pdf_edit_journal.dart';

void main() {
  setUp(() {
    ViewerPriority.debugReset();
    StartupQueue.instance.debugReset();
    PdfEditJournal.debugReset();
  });

  tearDown(() {
    ViewerPriority.debugReset();
    StartupQueue.instance.debugReset();
    PdfEditJournal.debugReset();
  });

  group('ViewerPriority', () {
    test('hold aktifken kuyruk bekler, birakilinca devam eder', () async {
      final ran = <String>[];
      final release = ViewerPriority.hold(
        maxHold: const Duration(seconds: 5),
      );
      expect(ViewerPriority.active, isTrue);

      StartupQueue.instance
        ..add('ilk', () async {
          ran.add('ilk');
        })
        ..add('ikinci', () async {
          ran.add('ikinci');
        })
        ..start(delay: Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(ran, isEmpty);

      release();
      expect(ViewerPriority.active, isFalse);
      await StartupQueue.instance.whenIdle;
      expect(ran, ['ilk', 'ikinci']);
    });

    test('birakilmayan hold maxHold dolunca otomatik serbest kalir', () async {
      ViewerPriority.hold(maxHold: const Duration(milliseconds: 60));
      expect(ViewerPriority.active, isTrue);

      await ViewerPriority.waitUntilIdle();
      expect(ViewerPriority.active, isFalse);
    });
  });

  group('FmEnv', () {
    late Directory tmp;
    late String savedSupportDir;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      savedSupportDir = FmEnv.appSupportDir;
      tmp = await Directory.systemTemp.createTemp('fm_env_test_');
      FmEnv.appSupportDir = tmp.path;
    });

    tearDown(() async {
      FmEnv.appSupportDir = savedSupportDir;
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test('ensureAppSupportDir ayarli dizini aninda dondurur ve ensureInit tek islem paylasir',
        () async {
      final dir = await FmEnv.ensureAppSupportDir();
      expect(dir, tmp.path);

      final f1 = FmEnv.ensureInit();
      final f2 = FmEnv.ensureInit();
      expect(identical(f1, f2), isTrue);
      await Future.wait([f1, f2]);
    });
  });

  group('PdfEditJournal', () {
    late Directory tmp;
    late String savedSupportDir;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      savedSupportDir = FmEnv.appSupportDir;
      tmp = await Directory.systemTemp.createTemp('pdf_journal_test_');
      FmEnv.appSupportDir = tmp.path;
      PdfEditJournal.debugReset();
    });

    tearDown(() async {
      PdfEditJournal.debugReset();
      FmEnv.appSupportDir = savedSupportDir;
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test('hasStale disk gunlugunu okuyup onbellekten hizlica yanitlar', () {
      final src = '${tmp.path}/doc.pdf';
      final backup = '${tmp.path}/doc.bak.pdf';

      expect(PdfEditJournal.hasStale(src), isFalse);
      PdfEditJournal.add(src, backup);
      expect(PdfEditJournal.hasStale(src), isFalse);

      PdfEditJournal.debugReset();
      expect(PdfEditJournal.hasStale(src), isTrue);

      PdfEditJournal.remove(src);
      expect(PdfEditJournal.hasStale(src), isFalse);
    });
  });
}
