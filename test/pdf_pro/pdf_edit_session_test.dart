// PDF Pro Faz 54 / 1: düzenleme oturumu — komut yığını, sayfa bazlı kirli
// izleme (sahte arka uç) + gerçek PDFium'da geri al/yinele (CI: PDFIUM_PATH).
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_session.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// Sayfaları dize olarak tutan sahte belge: anlık görüntü = dizenin kopyası.
class _Fake implements PdfPageSnapshots {
  final pages = <int, String>{0: 'a', 1: 'b', 2: 'c'};
  final _snaps = <int, String>{};
  var _next = 1;
  var failTake = false, failRestore = false;

  int get alive => _snaps.length;

  @override
  Future<int> take(int pageIndex) async {
    if (failTake) return 0;
    _snaps[_next] = pages[pageIndex]!;
    return _next++;
  }

  @override
  Future<bool> restore(int pageIndex, int handle) async {
    if (failRestore || !_snaps.containsKey(handle)) return false;
    pages[pageIndex] = _snaps[handle]!;
    return true;
  }

  @override
  Future<void> release(int handle) async => _snaps.remove(handle);
}

Future<void> _edit(PdfEditSession s, _Fake f, int page, String text,
        {String label = 'pe.step_paragraph'}) =>
    s.run(
        pageIndex: page,
        label: label,
        detail: text,
        apply: () async => f.pages[page] = text);

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

Future<Uint8List> _pixels(PdfDocument doc) async {
  final img = (await doc.pages[0].render(fullWidth: 300, fullHeight: 420))!;
  final out = Uint8List.fromList(img.pixels);
  img.dispose();
  return out;
}

void main() {
  group('komut yığını (sahte arka uç)', () {
    test('geri al / yinele sayfayı adım adım döndürür, adlar taşınır',
        () async {
      final f = _Fake();
      final s = PdfEditSession(f);
      await _edit(s, f, 0, 'a1');
      await _edit(s, f, 1, 'b1');
      await _edit(s, f, 0, 'a2');
      expect(s.undoStep!.detail, 'a2');
      expect(s.pendingCount, 3);
      expect(s.dirtyPages, [0, 1]);

      expect(await s.undo(), isTrue);
      expect(f.pages[0], 'a1');
      expect(s.redoStep!.detail, 'a2');
      expect(await s.undo(), isTrue);
      expect(f.pages[1], 'b');
      expect(s.dirtyPages, [0]);
      expect(await s.redo(), isTrue);
      expect(await s.redo(), isTrue);
      expect(f.pages, {0: 'a2', 1: 'b1', 2: 'c'});
      expect(await s.redo(), isFalse);
      expect(s.needsReplay, isTrue);
    });

    test('sınırsız: 200 adım geri alınır, sonunda temiz', () async {
      final f = _Fake();
      final s = PdfEditSession(f);
      for (var i = 0; i < 200; i++) {
        await _edit(s, f, i % 3, 'v$i');
      }
      while (s.canUndo) {
        expect(await s.undo(), isTrue);
      }
      expect(f.pages, {0: 'a', 1: 'b', 2: 'c'});
      expect(s.dirty, isFalse);
      expect(s.dirtyPages, isEmpty);
    });

    test('kirli izleme duruma bakar: kayıtlı hâle geri alınan sayfa temiz',
        () async {
      final f = _Fake();
      final s = PdfEditSession(f);
      await _edit(s, f, 0, 'a1');
      s.markSaved();
      expect(s.dirty, isFalse);
      await _edit(s, f, 2, 'c1');
      expect(s.dirtyPages, [2]);
      await s.undo();
      expect(s.dirty, isFalse);
      // Kaydın altına inmek de kirli.
      await s.undo();
      expect(s.dirtyPages, [0]);
      expect(s.pendingCount, 1);
      await s.redo();
      expect(s.dirty, isFalse);
    });

    test('yeni komut yinele yığınını ve anlık görüntülerini bırakır',
        () async {
      final f = _Fake();
      final s = PdfEditSession(f);
      await _edit(s, f, 0, 'a1');
      await _edit(s, f, 0, 'a2');
      await s.undo();
      expect(f.alive, 3); // 2 önce + 1 sonra
      await _edit(s, f, 0, 'a3');
      expect(s.canRedo, isFalse);
      expect(f.alive, 2);
      await s.close();
      expect(f.alive, 0);
    });

    test('reddedilen komut yığına girmez, sayfa ve yedekler olduğu gibi',
        () async {
      final f = _Fake();
      final s = PdfEditSession(f);
      await expectLater(
        s.run(
            pageIndex: 0,
            label: 'x',
            apply: () async => throw const PdfEditBridgeRefused('ret')),
        throwsA(isA<PdfEditBridgeRefused>()),
      );
      expect(s.canUndo, isFalse);
      expect(s.dirty, isFalse);
      expect(f.alive, 0);
      f.failTake = true;
      await expectLater(_edit(s, f, 0, 'z'),
          throwsA(isA<PdfEditBridgeRefused>()));
      expect(f.pages[0], 'a');
    });

    test('geri konamayan adım yığında kalır', () async {
      final f = _Fake();
      final s = PdfEditSession(f);
      await _edit(s, f, 0, 'a1');
      f.failRestore = true;
      expect(await s.undo(), isFalse);
      expect(s.canUndo, isTrue);
      expect(f.pages[0], 'a1');
    });

    test('kayda dön: ileri de geri de gider; erişilemezse false', () async {
      final f = _Fake();
      final s = PdfEditSession(f);
      await _edit(s, f, 0, 'a1');
      s.markSaved();
      await _edit(s, f, 1, 'b1');
      expect(await s.revertToSaved(), isTrue);
      expect(f.pages, {0: 'a1', 1: 'b', 2: 'c'});
      await s.undo(); // kaydın altı
      expect(await s.revertToSaved(), isTrue);
      expect(f.pages[0], 'a1');
      await s.undo();
      await _edit(s, f, 0, 'a9'); // kayıtlı adım artık yok
      expect(await s.revertToSaved(), isFalse);
    });

    test('dinleyiciler her değişimde uyarılır, kapandıktan sonra değil',
        () async {
      final f = _Fake();
      final s = PdfEditSession(f);
      var n = 0;
      s.addListener(() => n++);
      await _edit(s, f, 0, 'a1');
      await s.undo();
      await s.redo();
      s.markSaved();
      expect(n, 4);
    });

    test('işlem günlüğe yazılıp geri okunur', () {
      const op = PdfReplaceBlockOp(
          pageIndex: 3, objectIndexes: [4, 5], oldText: 'eski', newText: 'yeni');
      final back = PdfEditOp.fromJson(op.toJson()) as PdfReplaceBlockOp;
      expect(back.pageIndex, 3);
      expect(back.objectIndexes, [4, 5]);
      expect(back.oldText, 'eski');
      expect(back.newText, 'yeni');
      expect(PdfEditOp.fromJson({'op': 'bilinmeyen'}), isNull);
      expect(PdfEditOp.fromJson({'op': 'replaceBlock', 'page': 'x'}), isNull);
    });
  });

  group('gerçek PDFium', () {
    setUpAll(() async => pdfrxInitialize());

    test('geri al sayfayı piksel piksel eski hâline getirir, yinele yeniyi',
        () async {
      final bytes = File('test/fixtures/pdf_corpus/rl_paragraflar.pdf')
          .readAsBytesSync();
      final doc = await PdfDocument.openData(bytes);
      addTearDown(doc.dispose);
      final s = PdfEditSession.forDocument(doc);
      final pageCount = doc.pages.length;
      final before = (await doc.pages[0].loadText())!.fullText;
      final pxBefore = await _pixels(doc);
      final blocks = await PdfEditBridge.blocks(doc, 0);
      final target = blocks.firstWhere((b) => b.text.startsWith('Müze'));

      await s.apply(PdfReplaceBlockOp.of(0, target, 'Rehberi Müze Rehberi'),
          label: 'pe.step_paragraph', detail: 'Rehberi');
      expect(s.dirtyPages, [0]);
      expect(_squash((await doc.pages[0].loadText())!.fullText),
          contains('RehberiMüzeRehberi'));
      final pxEdited = await _pixels(doc);
      expect(pxEdited, isNot(pxBefore));

      expect(await s.undo(), isTrue);
      expect(doc.pages.length, pageCount);
      expect(_squash((await doc.pages[0].loadText())!.fullText),
          _squash(before));
      expect(await _pixels(doc), pxBefore,
          reason: 'geri alınan sayfa özgünle piksel piksel aynı');
      expect(s.dirty, isFalse);

      expect(await s.redo(), isTrue);
      expect(await _pixels(doc), pxEdited);
      await s.close();
    });

    test('art arda iki düzenleme tek tek geri alınır', () async {
      final doc = await PdfDocument.openData(
          File('test/fixtures/pdf_corpus/rl_paragraflar.pdf')
              .readAsBytesSync());
      addTearDown(doc.dispose);
      final s = PdfEditSession.forDocument(doc);
      Future<String> text() async =>
          _squash((await doc.pages[0].loadText())!.fullText);
      final t0 = await text();
      var blocks = await PdfEditBridge.blocks(doc, 0);
      await s.apply(
          PdfReplaceBlockOp.of(0,
              blocks.firstWhere((b) => b.text.startsWith('Müze')), 'Rehberi Müze'),
          label: 'pe.step_paragraph');
      final t1 = await text();
      blocks = await PdfEditBridge.blocks(doc, 0);
      await s.apply(
          PdfReplaceBlockOp.of(
              0,
              blocks.firstWhere((b) => b.text.startsWith('Rehberi')),
              'Müze Müze'),
          label: 'pe.step_paragraph');
      expect(await text(), isNot(t1));
      await s.undo();
      expect(await text(), t1);
      await s.undo();
      expect(await text(), t0);
      await s.close();
    });

    test('eski metni tutmayan işlem reddedilir (yanlış bloğa yazma yok)',
        () async {
      final doc = await PdfDocument.openData(
          File('test/fixtures/pdf_corpus/rl_paragraflar.pdf')
              .readAsBytesSync());
      addTearDown(doc.dispose);
      final s = PdfEditSession.forDocument(doc);
      final b = (await PdfEditBridge.blocks(doc, 0)).first;
      await expectLater(
        s.apply(
            PdfReplaceBlockOp(
                pageIndex: 0,
                objectIndexes: b.objectIndexes,
                oldText: '${b.text} başka',
                newText: 'x'),
            label: 'pe.step_paragraph'),
        throwsA(isA<PdfEditBridgeRefused>()),
      );
      expect(s.canUndo, isFalse);
      await s.close();
    });
  });
}
