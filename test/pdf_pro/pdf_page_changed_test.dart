// PDF Pro Faz 52.3 (PK2): düzenleme belgeyi yeniden YÜKLEMEZ — köprü sayfayı
// değiştirir, `reloadPages` "sayfa değişti" olayını yayar, görüntüleyici yalnız
// o sayfanın önbelleğini düşürür; yakınlaştırma/konum (matris) DEĞİŞMEZ.
import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  testWidgets('düzenleme sonrası görüntüleyici matrisi aynı, belge aynı nesne',
      (tester) async {
    await tester.runAsync(() => pdfrxInitialize());
    final doc = (await tester.runAsync(() => PdfDocument.openData(
        File('test/fixtures/pdf_corpus/ch_cok_sayfa.pdf').readAsBytesSync())))!;
    final controller = PdfViewerController();
    final events = <PdfDocumentEvent>[];
    final sub = doc.events.listen(events.add);

    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 400,
        height: 700,
        child: PdfViewer(PdfDocumentRefDirect(doc), controller: controller),
      ),
    ));
    for (var i = 0; i < 50 && !controller.isReady; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.isReady, isTrue);

    // Kullanıcı yakınlaştırıp kaydırmış olsun.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 30));
    }
    final zoomed = controller.value.clone()
      ..leftTranslateByDouble(-60, -150, 0, 1)
      ..scaleByDouble(1.8, 1.8, 1, 1);
    controller.value = zoomed; // sahte zamanda goTo'nun Future'ı beklenmez
    await tester.pump();
    final before = controller.value.clone();

    final blocks = (await tester.runAsync(() => PdfEditBridge.blocks(doc, 0)))!;
    final target = blocks.firstWhere((b) => b.lines.length > 1);
    final words = target.text.split(' ');
    // İşlem sürerken kareler de ilerlemeli: görüntüleyicinin çizim işleri
    // bitmeden köprünün "boşta" bekçisi açılmaz (gerçekte de böyle).
    var done = false;
    Object? error;
    PdfEditBridge.replaceBlock(doc, 0, target,
            [words.last, ...words.sublist(1, words.length - 1), words.first].join(' '))
        .then((_) => done = true, onError: (Object e) {
      error = e;
      return false;
    });
    for (var i = 0; i < 200 && !done && error == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(error, isNull);
    expect(done, isTrue, reason: 'köprü işlemi bitmedi');
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 30));
    }

    expect(events.whereType<PdfDocumentPageStatusChangedEvent>().single.changes.keys,
        [1], reason: 'yalnız düzenlenen sayfa değişti');
    expect(controller.value, before, reason: 'yakınlaştırma/konum korunur');
    expect(controller.document, same(doc), reason: 'belge yeniden yüklenmedi');

    // Söküm: görüntüleyici gider, bekleyen çizim işleri gerçek zamanda
    // iptal olur (sahte zamanda test sonunda asılıyordu).
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await doc.dispose().timeout(const Duration(seconds: 5), onTimeout: () {});
    });
    // Rx aboneliğinin iptali sahte zamanda beklenirse test sonunda asılır.
    unawaited(sub.cancel());
  }, timeout: const Timeout(Duration(minutes: 2)));
}
