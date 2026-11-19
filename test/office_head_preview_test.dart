import 'package:dosya_okuyucu/core/motion.dart';
import 'package:dosya_okuyucu/screens/editors/slides_editor_screen.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:dosya_okuyucu/services/xlsx/xlsx_stream.dart';
import 'package:dosya_okuyucu/widgets/slide_canvas.dart';
import 'package:dosya_okuyucu/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// B13 m.4 — Excel/Slayt aşamalı açılış (Word B9 m.8 yolu): tam model
/// hazırlanırken belgenin başı salt okunur görünür; açıklama yazısı yalnız
/// bekleme 1 sn'yi aşarsa belirir.
void main() {
  double labelAlpha(WidgetTester t) => t
      .widget<Text>(find
          .descendant(
              of: find.byType(OfficeLoadingPreview),
              matching: find.byType(Text))
          .first)
      .style!
      .color!
      .a;

  group('PptxEditor.headViews', () {
    test('uzun destede yalnız ilk slaytlar, tam modelle aynı çizim', () {
      final bytes = PptxWriter.build([
        for (var i = 0; i < 10; i++) SlideDraft('Slayt $i', ['madde $i']),
      ]);
      final head = PptxEditor.headViews(bytes)!;
      expect(head, hasLength(kPptxHeadSlides));
      final full = PptxEditor.parse(bytes);
      for (var i = 0; i < kPptxHeadSlides; i++) {
        expect(head[i].shapes.length, full.slides[i].view!.shapes.length);
      }
    });

    test('kısa destede önizleme yok (null)', () {
      final bytes = PptxWriter.build(const [SlideDraft('Tek', ['a'])]);
      expect(PptxEditor.headViews(bytes), isNull);
    });
  });

  testWidgets('slayt önizlemesi çizer; yazı 1 sn sonra belirir', (t) async {
    final head = PptxEditor.headViews(PptxWriter.build([
      for (var i = 0; i < 5; i++) SlideDraft('Slayt $i', const []),
    ]))!;
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: SlidesLoadingPreview(slides: head))));
    expect(find.byType(SlideCanvas), findsWidgets);
    expect(labelAlpha(t), 0);
    await t.pump(Motion.progressLabelDelay ~/ 2);
    expect(labelAlpha(t), 0, reason: 'kısa beklemede yazı yok');
    await t.pump(Motion.progressLabelDelay + Motion.medium);
    expect(labelAlpha(t), closeTo(1, 0.01));
  });

  testWidgets('Excel önizlemesi: sütun harfi, satır no, ham değer', (t) async {
    final sheet = XlsxStreamSheet('Özet')
      ..cells[0] = {0: 'Ay', 1: 'Satış'}
      ..cells[1] = {0: 'Ocak', 1: '120'}
      ..maxRow = 1
      ..maxCol = 1;
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: SheetHeadPreview(sheet: sheet))));
    for (final s in ['A', 'B', '1', '2', 'Ay', 'Satış', 'Ocak', '120']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('C'), findsNothing);
  });
}
