import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pdf_edit_history.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 31 / PD4: geri al/yinele **işlem listesi** — disk kopyası yok, belge
/// bellekte, ara sonuç bütçe dışına çıkınca yeniden oynatılır.
void main() {
  /// Sona bir bayt ekleyen, deterministik "işlem".
  PdfByteOp append(int v) => (b) async => [...b, v];

  test('20 işlemlik oturumda geçici klasöre hiçbir dosya yazılmaz', () async {
    final tmp = Directory.systemTemp;
    final before = tmp.listSync().length;
    final h = PdfEditHistory<int>(Uint8List.fromList([0]), 0);
    for (var i = 1; i <= 20; i++) {
      await h.applyOp('op$i', append(i));
    }
    for (var i = 0; i < 20; i++) {
      await h.undo();
    }
    for (var i = 0; i < 20; i++) {
      await h.redo();
    }
    expect(h.bytes, [0, for (var i = 1; i <= 20; i++) i]);
    expect(tmp.listSync().length, before);
  });

  test('geri al + yinele doğru hâli verir; yeni işlem yineleyi siler', () async {
    final h = PdfEditHistory<String>(Uint8List.fromList([9]), '');
    await h.applyOp('a', append(1));
    await h.applyOp('b', append(2));
    expect(h.canRedo, isFalse);
    expect(await h.undo(), isTrue);
    expect(h.bytes, [9, 1]);
    expect(h.redoLabel, 'b');
    await h.redo();
    expect(h.bytes, [9, 1, 2]);
    await h.undo();
    await h.applyOp('c', append(3));
    expect(h.canRedo, isFalse);
    expect(h.bytes, [9, 1, 3]);
  });

  test('katman adımları baytlara dokunmaz, geri alınır/yinelenir', () async {
    final h = PdfEditHistory<String>(Uint8List.fromList([0]), 'boş');
    await h.applyOp('a', append(1));
    h.setLayer('yazı', 'yazı-1');
    h.setLayer('taşı', 'yazı-2');
    expect(h.layer, 'yazı-2');
    expect(await h.undo(), isFalse);
    expect(h.layer, 'yazı-1');
    await h.undo();
    expect(h.layer, 'boş');
    expect(h.bytes, [0, 1]);
    await h.undo();
    expect(h.bytes, [0]);
    await h.redo();
    await h.redo();
    expect(h.layer, 'yazı-1');
    expect(h.bytes, [0, 1]);
  });

  test('bütçe içinde geri alma yeniden oynatmaz; dar bütçede yine doğru',
      () async {
    var runs = 0;
    PdfByteOp big(int v) => (b) async {
          runs++;
          return [...b, ...List.filled(100, v)];
        };
    final roomy = PdfEditHistory<int>(Uint8List(0), 0);
    for (var i = 1; i <= 6; i++) {
      await roomy.applyOp('$i', big(i));
    }
    runs = 0;
    await roomy.undo();
    await roomy.undo();
    expect(runs, 0);
    expect(roomy.bytes.length, 400);

    final tight = PdfEditHistory<int>(Uint8List(0), 0, cacheBudgetBytes: 450);
    for (var i = 1; i <= 6; i++) {
      await tight.applyOp('$i', big(i));
    }
    expect(tight.cachedBytes, lessThanOrEqualTo(450 + 600));
    await tight.undo();
    await tight.undo();
    await tight.undo();
    expect(tight.bytes.length, 300);
    expect(tight.bytes.last, 3);
    await tight.redo();
    expect(tight.bytes.length, 400);
  });

  test('kirli durum kayıt adımına göre: geri alıp kayıtlı hâle dönmek temiz',
      () async {
    final h = PdfEditHistory<int>(Uint8List(0), 0);
    expect(h.dirty, isFalse);
    await h.applyOp('a', append(1));
    h.markSaved();
    expect(h.dirty, isFalse);
    await h.applyOp('b', append(2));
    expect(h.dirty, isTrue);
    await h.undo();
    expect(h.dirty, isFalse);
  });

  test('reddedilen işlem listeye girmez', () async {
    final h = PdfEditHistory<int>(Uint8List.fromList([1]), 0);
    await expectLater(
        h.applyOp('x', (b) async => throw StateError('ret')), throwsStateError);
    expect(h.canUndo, isFalse);
    expect(h.bytes, [1]);
  });
}
