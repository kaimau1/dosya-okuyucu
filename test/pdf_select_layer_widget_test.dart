import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:dosya_okuyucu/services/pdf/ocr_page_text.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_ocr_text.dart';
import 'package:dosya_okuyucu/widgets/pdf_select_layer.dart';

/// Chrome benzeri seçim davranışının jest testleri — gerçek pdfium olmadan:
/// sahte `PdfPage.loadText` elle kurulmuş karakter kutuları döndürür.
///
/// Geometri (tüm testlerde aynı): sayfa 200x100 punto, ekranda 1:1.
/// Tek satır "Merhaba dünya" (13 karakter), her karakter 10 px genişlik,
/// x=10'dan başlar; ekran dikeyi 40-50 → PDF'te top=60, bottom=50.
/// Yani i. karakterin ekran kutusu: (10+10i, 40)-(20+10i, 50).
void main() {
  const pageSize = Size(200, 100);

  OcrPageText lineText(String line) {
    final rects = <PdfRect>[
      for (var i = 0; i < line.length; i++)
        PdfRect(10.0 + 10 * i, 60, 20.0 + 10 * i, 50),
    ];
    return OcrPageText(
      pageNumber: 1,
      fullText: line,
      fragments: [
        PdfPageTextFragment.fromParams(
            0, line.length, rects.boundingRect(), line, rects),
      ],
    );
  }

  late List<String> selections;
  late List<bool> fromOcrLog;
  late List<bool> selectingLog;
  late List<Offset?> dragLog;

  Future<void> pumpLayer(WidgetTester tester, _FakePage page,
      {int activeSelectionPage = 0, bool fresh = true}) async {
    if (fresh) {
      selections = [];
      fromOcrLog = [];
      selectingLog = [];
      dragLog = [];
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            PdfSelectLayer(
              page: page,
              pageSize: pageSize,
              activeSelectionPage: activeSelectionPage,
              onSelected: (t, rects, pageNo, preceding, fromOcr) {
                selections.add(t);
                fromOcrLog.add(fromOcr);
              },
              onSelectingChanged: selectingLog.add,
              onDragAt: dragLog.add,
            ),
          ],
        ),
      ),
    );
    await tester.pump(); // loadText çözülsün
  }

  /// Seçim tutamaçlarının (daire nokta) sayısı — seçim var/yok göstergesi.
  Finder handleDots() => find.byWidgetPredicate((w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).shape == BoxShape.circle);

  testWidgets('uzun basış kelime seçer, sürükleme kelime kelime büyütür',
      (tester) async {
    await pumpLayer(tester, _FakePage(text: lineText('Merhaba dünya')));

    final g = await tester.startGesture(const Offset(15, 45));
    await tester.pump(const Duration(milliseconds: 600));

    expect(selections, isNotEmpty);
    expect(selections.last, 'Merhaba', reason: 'uzun basış kelimeyi seçmeli');
    expect(selectingLog, [true],
        reason: 'sürükleme kipi açıldı → pan kilitlenmeli');

    // Parmak kalkmadan "dünya"nın üstüne sürükle: seçim kelime sınırına uzar.
    await g.moveTo(const Offset(95, 45)); // 8. karakter: 'd'
    await tester.pump();
    await g.up();
    await tester.pump();

    expect(selections.last, 'Merhaba dünya');
    expect(fromOcrLog.last, isFalse);
    expect(selectingLog, [true, false],
        reason: 'parmak kalkınca pan kilidi AÇILMALI (yapısal güvence)');
  });

  testWidgets('sürükleme sırasında büyüteç görünür ve parmak kalkınca kaybolur',
      (tester) async {
    await pumpLayer(tester, _FakePage(text: lineText('Merhaba dünya')));

    final g = await tester.startGesture(const Offset(15, 45));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(RawMagnifier), findsOneWidget);

    await g.up();
    await tester.pump();
    expect(find.byType(RawMagnifier), findsNothing);
  });

  testWidgets('kısa dokunuş seçimi temizler', (tester) async {
    await pumpLayer(tester, _FakePage(text: lineText('Merhaba dünya')));

    final g = await tester.startGesture(const Offset(15, 45));
    await tester.pump(const Duration(milliseconds: 600));
    await g.up();
    await tester.pump();
    expect(selections.last, 'Merhaba');

    await tester.tapAt(const Offset(180, 90));
    await tester.pump();
    expect(selections.last, '', reason: 'boş dokunuş seçimi temizlemeli');
  });

  testWidgets('fare: bas-sürükle karakter hassasiyetinde seçer (Chrome)',
      (tester) async {
    await pumpLayer(tester, _FakePage(text: lineText('Merhaba dünya')));

    final g = await tester.startGesture(
      const Offset(15, 45),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    expect(selectingLog, [true],
        reason: 'metne fareyle basıldığı AN pan kilitlenmeli');

    await g.moveTo(const Offset(75, 45)); // 6. karakter: son 'a'
    await tester.pump();
    await g.up();
    await tester.pump();

    expect(selections.last, 'Merhaba');
    expect(selectingLog, [true, false]);
  });

  testWidgets('fare: çift tık kelime seçer', (tester) async {
    await pumpLayer(tester, _FakePage(text: lineText('Merhaba dünya')));

    for (var i = 0; i < 2; i++) {
      final g = await tester.startGesture(
        const Offset(95, 45),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      await g.up();
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(selections.last, 'dünya');
  });

  testWidgets(
      'taranmış sayfa: uzun basış OCR tetikler, çip görünür, kelime seçilir',
      (tester) async {
    // Sayfanın pdfium metni BOŞ → katman OCR'a düşmeli.
    final page = _FakePage(
        text: OcrPageText(pageNumber: 1, fullText: '', fragments: const []));
    final completer = Completer<OcrPageText?>();
    PdfOcrText.debugReset();
    PdfOcrText.debugOcrOverride = (_) => completer.future;
    addTearDown(PdfOcrText.debugReset);

    await pumpLayer(tester, page);

    final g = await tester.startGesture(const Offset(15, 45));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Metin tanınıyor…'), findsOneWidget,
        reason: 'OCR sürerken kullanıcı bilgilendirilmeli');

    completer.complete(lineText('Merhaba dünya'));
    await tester.pump();
    await tester.pump();

    expect(selections.last, 'Merhaba',
        reason: 'OCR bitince basılan kelime seçilmeli');
    expect(fromOcrLog.last, isTrue,
        reason: 'OCR seçimi bayrakla bildirilmeli (Düzenle gizlenir)');

    await g.up();
    await tester.pump();
  });

  testWidgets('taranmış sayfada metin çıkmazsa kullanıcıya söylenir',
      (tester) async {
    final page = _FakePage(
        text: OcrPageText(pageNumber: 1, fullText: '', fragments: const []));
    PdfOcrText.debugReset();
    PdfOcrText.debugOcrOverride = (_) async => null;
    addTearDown(PdfOcrText.debugReset);

    await pumpLayer(tester, page);

    final g = await tester.startGesture(const Offset(15, 45));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await g.up();

    expect(find.text('Sayfada seçilebilir metin bulunamadı'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // çip zamanlayıcısı bitsin
    expect(find.text('Sayfada seçilebilir metin bulunamadı'), findsNothing);
  });

  testWidgets(
      'taranmış sayfa KENDİLİĞİNDEN tanınır: jest yok, çip yok, '
      'sonrasında uzun basış anında seçer', (tester) async {
    final page = _FakePage(
        text: OcrPageText(pageNumber: 1, fullText: '', fragments: const []));
    var ocrCalls = 0;
    PdfOcrText.debugReset();
    PdfOcrText.debugOcrOverride = (_) async {
      ocrCalls++;
      return lineText('Merhaba dünya');
    };
    addTearDown(PdfOcrText.debugReset);

    await pumpLayer(tester, page);
    expect(ocrCalls, 0, reason: 'gecikme dolmadan OCR başlamamalı');

    // Hiç dokunmadan bekle: sayfa arka planda sessizce tanınmalı.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(ocrCalls, 1, reason: 'OCR kullanıcı beklemeden kendiliğinden koşmalı');
    expect(find.text('Metin tanınıyor…'), findsNothing,
        reason: 'otomatik tur görünmez olmalı (çip yalnız beklerken)');

    // Artık uzun basış OCR beklemeden anında kelime seçer.
    final g = await tester.startGesture(const Offset(15, 45));
    await tester.pump(const Duration(milliseconds: 600));
    await g.up();
    await tester.pump();
    expect(selections.last, 'Merhaba');
    expect(fromOcrLog.last, isTrue);
    expect(ocrCalls, 1, reason: 'önbellek/tek-seferlik: ikinci OCR koşmamalı');
  });

  testWidgets('hızla geçilen sayfa OCR\'lanmaz (katman sökülünce iptal)',
      (tester) async {
    final page = _FakePage(
        text: OcrPageText(pageNumber: 1, fullText: '', fragments: const []));
    var ocrCalls = 0;
    PdfOcrText.debugReset();
    PdfOcrText.debugOcrOverride = (_) async {
      ocrCalls++;
      return null;
    };
    addTearDown(PdfOcrText.debugReset);

    await pumpLayer(tester, page);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(ocrCalls, 0, reason: '350 ms dolmadan sökülen sayfa pil yakmamalı');
  });

  testWidgets('çift dokunuş kelime seçer (mobil Chrome paritesi)',
      (tester) async {
    await pumpLayer(tester, _FakePage(text: lineText('Merhaba dünya')));

    await tester.tapAt(const Offset(95, 45));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(95, 45));
    await tester.pump();

    expect(selections.last, 'dünya');
    expect(selectingLog, isEmpty,
        reason: 'çift dokunuş pan kilidi açmamalı (parmak yerde değil)');
  });

  testWidgets('seçimi başka sayfa devralınca katman vurgusunu bırakır',
      (tester) async {
    final page = _FakePage(text: lineText('Merhaba dünya'));
    await pumpLayer(tester, page);

    final g = await tester.startGesture(const Offset(15, 45));
    await tester.pump(const Duration(milliseconds: 600));
    await g.up();
    await tester.pump();
    expect(handleDots(), findsNWidgets(2), reason: 'seçim tutamaçları görünür');

    final before = selections.length;
    await pumpLayer(tester, page, activeSelectionPage: 2, fresh: false);
    expect(handleDots(), findsNothing,
        reason: 'seçim 2. sayfaya geçti: bu katman vurgusunu bırakmalı');
    expect(selections.length, before,
        reason: 'sessiz bırakma: rapor YOK (devralanın seçimi ezilmesin)');
  });

  testWidgets('sürükleme sırasında kenar kaydırma konumları bildirilir',
      (tester) async {
    await pumpLayer(tester, _FakePage(text: lineText('Merhaba dünya')));

    final g = await tester.startGesture(const Offset(15, 45));
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveTo(const Offset(95, 45));
    await tester.pump();
    expect(dragLog, isNotEmpty);
    expect(dragLog.last, isNotNull);

    await g.up();
    await tester.pump();
    expect(dragLog.last, isNull,
        reason: 'sürükleme bitince null gelmeli (zamanlayıcı ölsün)');
  });

  testWidgets('iki parmak inince sürükleme seçimi biter, pan kilidi açılır',
      (tester) async {
    await pumpLayer(tester, _FakePage(text: lineText('Merhaba dünya')));

    final g1 = await tester.startGesture(const Offset(15, 45));
    await tester.pump(const Duration(milliseconds: 600));
    expect(selectingLog, [true]);

    final g2 = await tester.startGesture(const Offset(120, 80));
    await tester.pump();
    expect(selectingLog, [true, false],
        reason: 'ikinci parmak = yakınlaştırma niyeti; kilit hemen açılmalı');

    await g1.up();
    await g2.up();
    await tester.pump();
  });
}

/// Test için sahte belge/sayfa: yalnız katmanın gerçekten kullandığı üyeler
/// gerçek; kalanı çağrılırsa test bilerek patlar (yanlışlıkla pdfium'a inen
/// yol hemen görünsün).
class _FakeDoc implements PdfDocument {
  @override
  final String sourceName = 'test.pdf';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

class _FakePage implements PdfPage {
  final PdfPageText text;
  _FakePage({required this.text});

  @override
  final PdfDocument document = _FakeDoc();

  @override
  int get pageNumber => 1;

  @override
  double get width => 200;

  @override
  double get height => 100;

  @override
  Size get size => const Size(200, 100);

  @override
  PdfPageRotation get rotation => PdfPageRotation.none;

  @override
  bool get isLoaded => true;

  @override
  Future<PdfPageText> loadText() async => text;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}
