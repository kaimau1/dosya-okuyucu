import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/core/edit/draft_journal.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/edit/save_coordinator.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/xlsx_fixture.dart';

/// Faz 20 — taslak günlüğü, oturum (kirli/kaydet/taslak) ve izolat kaydetme.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late String source;
  late DraftJournal journal;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('edit_session');
    source = '${dir.path}/belge.txt';
    await File(source).writeAsString('özgün');
    journal = DraftJournal(Directory('${dir.path}/drafts'));
    DraftJournal.instance = journal;
    EditPrefs.autoSave = false;
  });

  tearDown(() async {
    DraftJournal.instance = null;
    EditPrefs.autoSave = true;
    SaveIsolate.runner = <M, R>(cb, m) async => cb(m);
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('DraftJournal', () {
    test('yazılan taslak bulunur, okunur, silinir', () async {
      await journal.write(source, [1, 2, 3], editor: 'text');
      final d = await journal.find(source);
      expect(d, isNotNull);
      expect(d!.editor, 'text');
      expect(await d.read(), [1, 2, 3]);
      await journal.discard(source);
      expect(await journal.find(source), isNull);
    });

    test('kaynak sonradan değiştiyse eski taslak SUNULMAZ', () async {
      await journal.write(source, [9], editor: 'text');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await File(source).writeAsString('başka uygulama değiştirdi');
      expect(await journal.find(source), isNull);
    });

    test('anahtar yoldan türetilir, dosya adına yol sızmaz', () {
      final k = DraftJournal.keyFor('/storage/emulated/0/Gizli Rapor.docx');
      expect(k, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(k, isNot(DraftJournal.keyFor('/storage/emulated/0/b.docx')));
    });

    test('7 günden eski taslaklar budanır', () async {
      await journal.write(source, [1], editor: 'text');
      final n = await journal.prune(
          now: DateTime.now().add(const Duration(days: 8)));
      expect(n, greaterThan(0));
      expect(await journal.find(source), isNull);
    });
  });

  group('EditSession', () {
    EditSession make(List<int> Function() bytes, {List<String>? log}) =>
        EditSession(
          sourcePath: source,
          editor: 'text',
          observeLifecycle: false,
          snapshot: () async => Uint8List.fromList(bytes()),
          save: () async {
            log?.add('save');
            await File(source).writeAsBytes(bytes());
          },
        );

    test('değişiklik kirli yapar, taslak yazılır, kayıt temizler + siler',
        () async {
      var content = 'özgün';
      final s = make(() => content.codeUnits);
      await s.captureSource();
      content = 'yeni metin';
      s.changed();
      expect(s.isDirty, isTrue);
      await s.writeDraft();
      expect(await journal.find(source), isNotNull);
      expect(await s.saveNow(), isTrue);
      expect(s.isDirty, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await journal.find(source), isNull);
      expect(await File(source).readAsString(), 'yeni metin');
      s.dispose();
    });

    test('kayıt sürerken gelen değişiklik belgeyi kirli bırakır', () async {
      var content = 'a';
      late EditSession s;
      s = EditSession(
        sourcePath: source,
        editor: 'text',
        observeLifecycle: false,
        save: () async {
          s.changed(); // kayıt sırasında kullanıcı yazmaya devam etti
          await File(source).writeAsString(content);
        },
      );
      s.changed();
      content = 'b';
      await s.saveNow();
      expect(s.isDirty, isTrue);
      s.dispose();
    });

    test('dosya dışarıda değiştiyse otomatik kaydetme üstüne YAZMAZ',
        () async {
      final log = <String>[];
      final s = make(() => 'bizim'.codeUnits, log: log);
      await s.captureSource();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await File(source).writeAsString('başka uygulama');
      s.changed();
      expect(await s.saveNow(auto: true), isFalse);
      expect(log, isEmpty);
      expect(s.externalConflict, isTrue);
      expect(await File(source).readAsString(), 'başka uygulama');
      s.dispose();
    });

    test('durum satırı: kirli → kaydedildi saatli', () async {
      const tr = AppStrings(AppLanguage.tr);
      final s = make(() => 'x'.codeUnits);
      s.changed();
      expect(s.statusText(tr), 'Kaydedilmedi');
      await s.saveNow();
      expect(s.statusText(tr), startsWith('Kaydedildi '));
      s.dispose();
    });
  });

  group('SaveCoordinator', () {
    test('aynı anda tek kayıt; bekleyen istekler tek kayda katlanır',
        () async {
      final c = SaveCoordinator();
      var runs = 0;
      Future<void> job() async {
        runs++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final a = c.save(job);
      final b = c.save(job);
      final d = c.save(job);
      await Future.wait([a, b, d]);
      expect(runs, 2, reason: 'ilk kayıt + sıradaki TEK kayıt');
      expect(c.status.value, SaveStatus.saved);
    });
  });

  group('izolat kaydetme (ED3)', () {
    test('Excel ve Word saveAsync ağır işi izolat kapısından geçirir',
        () async {
      var dispatched = 0;
      SaveIsolate.runner = <M, R>(cb, m) async {
        dispatched++;
        return cb(m);
      };
      final x = XlsxEditor.parse(xlsxFrom({'A1': 1}));
      x.setCell(x.sheets.first.name, 0, 1, '=A1*2');
      final xb = await x.saveAsync();
      expect(XlsxEditor.parse(xb).sheets.first.rawAt(0, 1), '=A1*2');

      final w = DocxEditor.parse(_tinyDocx());
      w.paragraphs.first.text = 'izolat';
      final wb = await w.saveAsync();
      expect(DocxEditor.parse(wb).paragraphs.first.text, 'izolat');
      expect(dispatched, 2);
    });
  });
}

/// En küçük .docx: tek paragraf.
Uint8List _tinyDocx() {
  const doc = '<w:document xmlns:w="http://schemas.openxmlformats.org/'
      'wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>bir</w:t></w:r>'
      '</w:p></w:body></w:document>';
  final a = Archive();
  final d = utf8.encode(doc);
  a.addFile(ArchiveFile('word/document.xml', d.length, d));
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}
