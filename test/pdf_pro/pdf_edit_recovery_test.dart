// PDF Pro Faz 54 / 4: çökme kurtarma — komut günlüğü + geçici artımlı kayıt.
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_recovery.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_save.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

class _Fake implements PdfPageSnapshots {
  var _next = 1;
  @override
  Future<int> take(int pageIndex) async => _next++;
  @override
  Future<bool> restore(int pageIndex, int handle) async => true;
  @override
  Future<void> release(int handle) async {}
}

PdfReplaceBlockOp _op(int page, String from, String to) => PdfReplaceBlockOp(
    pageIndex: page, objectIndexes: [page, page + 1], oldText: from, newText: to);

Future<void> _step(PdfEditSession s, PdfEditOp op, {String detail = ''}) =>
    s.run(
        pageIndex: op.pageIndex,
        label: 'pe.step_paragraph',
        detail: detail,
        op: op,
        apply: () async {});

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

void main() {
  late Directory tmp;
  late String path;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_recovery_test');
    PdfEditRecovery.rootOverride = p.join(tmp.path, 'kurtarma');
    PdfEditRecovery.debugForgetLive();
    path = p.join(tmp.path, 'belge.pdf');
    File(path).writeAsBytesSync(
        File('test/fixtures/pdf_corpus/rl_paragraflar.pdf').readAsBytesSync());
  });

  tearDown(() {
    PdfEditRecovery.rootOverride = null;
    PdfEditRecovery.debugForgetLive();
    tmp.deleteSync(recursive: true);
  });

  group('günlük', () {
    test('süreç ölünce kalan günlük adımları ve adlarıyla bulunur', () async {
      final s = PdfEditSession(_Fake());
      PdfEditRecovery.begin(path);
      await _step(s, _op(0, 'a', 'b'), detail: 'b');
      await _step(s, _op(2, 'c', 'd'), detail: 'd');
      await PdfEditRecovery.writeJournal(path, s.stepsSinceSaved);

      expect(await PdfEditRecovery.find(path), isNull,
          reason: 'oturum bu süreçte canlı');
      PdfEditRecovery.debugForgetLive(); // süreç öldü

      final e = (await PdfEditRecovery.find(path))!;
      expect(e.count, 2);
      expect(e.snapshot, isNull);
      expect(e.steps![1].detail, 'd');
      expect(e.steps![1].label, 'pe.step_paragraph');
      final op = e.steps![1].op as PdfReplaceBlockOp;
      expect(op.pageIndex, 2);
      expect(op.oldText, 'c');
      expect(op.newText, 'd');
    });

    test('düzgün kapanış kaydı siler', () async {
      final s = PdfEditSession(_Fake());
      PdfEditRecovery.begin(path);
      await _step(s, _op(0, 'a', 'b'));
      await PdfEditRecovery.writeJournal(path, s.stepsSinceSaved);
      await PdfEditRecovery.end(path);
      expect(await PdfEditRecovery.find(path), isNull);
      expect(Directory(PdfEditRecovery.rootOverride!).listSync(), isEmpty);
    });

    test('kayıttan sonra günlük yalnız sonraki adımları taşır; hepsi '
        'kaydedildiyse silinir', () async {
      final s = PdfEditSession(_Fake());
      PdfEditRecovery.begin(path);
      await _step(s, _op(0, 'a', 'b'));
      s.markSaved();
      await PdfEditRecovery.writeJournal(path, s.stepsSinceSaved);
      PdfEditRecovery.debugForgetLive();
      expect(await PdfEditRecovery.find(path), isNull);

      await _step(s, _op(1, 'x', 'y'));
      await PdfEditRecovery.writeJournal(path, s.stepsSinceSaved);
      final e = (await PdfEditRecovery.find(path))!;
      expect(e.count, 1);
      expect((e.steps!.single.op as PdfReplaceBlockOp).newText, 'y');
    });

    test('kaydın altına inilince günlük oynatılamaz; geçici kayıt yoksa '
        'kurtarma sunulmaz', () async {
      final s = PdfEditSession(_Fake());
      await _step(s, _op(0, 'a', 'b'));
      s.markSaved();
      await s.undo();
      expect(s.stepsSinceSaved, isNull);
      await PdfEditRecovery.writeJournal(path, s.stepsSinceSaved);
      expect(await PdfEditRecovery.find(path), isNull);
    });

    test('belge dışarıda değiştiyse adımlar oynatılmaz, geçici kayıt kalır',
        () async {
      final s = PdfEditSession(_Fake());
      PdfEditRecovery.begin(path);
      await _step(s, _op(0, 'a', 'b'));
      await PdfEditRecovery.writeJournal(path, s.stepsSinceSaved);
      final bytes = File(path).readAsBytesSync();
      await PdfEditRecovery.writeSnapshot(path, bytes);
      PdfEditRecovery.debugForgetLive();
      File(path).writeAsBytesSync([...bytes, 0x0A]);

      final e = (await PdfEditRecovery.find(path))!;
      expect(e.steps, isNull);
      expect(e.snapshot!.readAsBytesSync(), bytes);
    });

    test('geçersiz bayt geçici kayda yazılmaz; bozuk günlük yok sayılır',
        () async {
      PdfEditRecovery.begin(path);
      await PdfEditRecovery.writeSnapshot(path, Uint8List.fromList([1, 2, 3]));
      expect(Directory(PdfEditRecovery.rootOverride!).existsSync(), isFalse);

      final s = PdfEditSession(_Fake());
      await _step(s, _op(0, 'a', 'b'));
      await PdfEditRecovery.writeJournal(path, s.stepsSinceSaved);
      PdfEditRecovery.debugForgetLive();
      final dir = Directory(PdfEditRecovery.rootOverride!)
          .listSync()
          .whereType<Directory>()
          .single;
      File(p.join(dir.path, 'gunluk.json')).writeAsStringSync('{bozuk');
      expect(await PdfEditRecovery.find(path), isNull);
    });
  });

  group('gerçek PDFium', () {
    setUpAll(() async => pdfrxInitialize());

    test('günlük yeni açılan belgeye oynatılır; adımlar yine geri alınır',
        () async {
      // 1. oturum: düzenle, günlük + geçici kayıt yaz, "öl".
      final doc1 = await PdfDocument.openFile(path);
      final s1 = PdfEditSession.forDocument(doc1);
      final saver = PdfEditSaver(session: s1, path: path, tempDir: tmp.path);
      PdfEditRecovery.begin(path);
      final before = _squash((await doc1.pages[0].loadText())!.fullText);
      final blocks = await PdfEditBridge.blocks(doc1, 0);
      await s1.apply(
          PdfReplaceBlockOp.of(
              0,
              blocks.firstWhere((b) => b.text.startsWith('Müze')),
              'Rehberi Müze Rehberi'),
          label: 'pe.step_paragraph',
          detail: 'Rehberi');
      await PdfEditRecovery.writeJournal(path, s1.stepsSinceSaved);
      await PdfEditRecovery.writeSnapshot(path, await saver.encode());
      await s1.close();
      await doc1.dispose();
      PdfEditRecovery.debugForgetLive();

      // 2. açılış.
      final e = (await PdfEditRecovery.find(path))!;
      expect(e.count, 1);
      final snap = await PdfDocument.openData(e.snapshot!.readAsBytesSync());
      addTearDown(snap.dispose);
      expect(_squash((await snap.pages[0].loadText())!.fullText),
          contains('RehberiMüzeRehberi'));

      final doc2 = await PdfDocument.openFile(path);
      addTearDown(doc2.dispose);
      final s2 = PdfEditSession.forDocument(doc2);
      expect(await PdfEditRecovery.replay(s2, e), 1);
      expect(s2.dirty, isTrue);
      expect(s2.undoStep!.detail, 'Rehberi');
      expect(_squash((await doc2.pages[0].loadText())!.fullText),
          contains('RehberiMüzeRehberi'));
      expect(await s2.undo(), isTrue);
      expect(_squash((await doc2.pages[0].loadText())!.fullText), before);
      await s2.close();
    });

    test('tutmayan adımda oynatma durur, belge bozulmaz', () async {
      final doc = await PdfDocument.openFile(path);
      addTearDown(doc.dispose);
      final s = PdfEditSession.forDocument(doc);
      final before = _squash((await doc.pages[0].loadText())!.fullText);
      final entry = PdfEditRecoveryEntry(
        path: path,
        baseSize: 0,
        baseModifiedMs: 0,
        steps: [
          PdfRecoveredStep(_op(0, 'bu metin belgede yok', 'x'),
              'pe.step_paragraph', ''),
        ],
        snapshot: null,
        savedAt: DateTime(2026),
      );
      expect(await PdfEditRecovery.replay(s, entry), 0);
      expect(s.dirty, isFalse);
      expect(_squash((await doc.pages[0].loadText())!.fullText), before);
      await s.close();
    });
  });
}
