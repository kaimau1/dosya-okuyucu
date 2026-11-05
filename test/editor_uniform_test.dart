import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/edit/draft_journal.dart';
import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 40 / 6: ortak geri al/yinele + taslak kurtarma + kapanış güvencesi
/// DÖRT editörde aynı yapıdan geçer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const editors = {
    'word_editor_screen': 'word',
    'word_mobile_editor_screen': 'word_mobile',
    'slides_editor_screen': 'slides',
    'spreadsheet_editor_screen': 'spreadsheet',
  };

  String source(String screen, String dir) {
    final b = StringBuffer(
        File('lib/screens/editors/$screen.dart').readAsStringSync());
    final d = Directory('lib/screens/editors/$dir');
    if (d.existsSync()) {
      for (final f in d.listSync().whereType<File>()) {
        if (f.path.endsWith('.dart')) b.write(f.readAsStringSync());
      }
    }
    return b.toString();
  }

  editors.forEach((screen, dir) {
    test('$screen ortak altyapıyı kullanır', () {
      final s = source(screen, dir);
      expect(s, contains('EditSession('), reason: 'taslak + otomatik kaydet');
      expect(s, contains('withDraftBanner('), reason: 'taslak kurtarma');
      expect(s, contains('EditExitGuard('), reason: 'çıkışta kaydet/sor');
      expect(s, contains('EditorTopBar.actions('),
          reason: 'üst çubukta aynı ↶ ↷ 💾 ⋮ sırası');
    });
  });

  group('kapanış güvencesi', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('bg');
      DraftJournal.instance = DraftJournal(Directory('${dir.path}/drafts'));
    });
    tearDown(() {
      DraftJournal.instance = null;
      dir.deleteSync(recursive: true);
    });

    test('arka plana geçince kirli belge kaydedilir', () async {
      final src = File('${dir.path}/a.txt')..writeAsStringSync('a');
      var saves = 0;
      final s = EditSession(
        sourcePath: src.path,
        editor: 'text',
        observeLifecycle: false,
        snapshot: () async => Uint8List.fromList([98]),
        save: () async {
          saves++;
          await src.writeAsString('b');
        },
      );
      addTearDown(s.dispose);
      await s.captureSource();
      s.changed();
      await s.onBackground();
      expect(saves, 1);
      expect(s.isDirty, isFalse);
    });

    test('temiz belgede hiçbir şey yazılmaz', () async {
      final src = File('${dir.path}/b.txt')..writeAsStringSync('a');
      var saves = 0;
      final s = EditSession(
        sourcePath: src.path,
        editor: 'text',
        observeLifecycle: false,
        save: () async => saves++,
      );
      addTearDown(s.dispose);
      await s.onBackground();
      expect(saves, 0);
    });
  });
}
