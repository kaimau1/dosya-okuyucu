// Slayt tasarım levhası önizlemeleri (2026-11-24): düzen çizimi ve geçiş
// canlandırması; canlandırma birkaç turda durur (sonsuz döngü yok).
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/widgets/slide_previews.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('düzen ve geçiş kutuları çizilir, canlandırma durur, dokunulur',
      (tester) async {
    var tapped = '';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Wrap(children: [
            SlidePreviewTile(
              key: const ValueKey('layout'),
              label: 'Başlık ve İçerik',
              selected: true,
              onTap: () => tapped = 'layout',
              preview: const SlideLayoutThumb(boxes: [
                PptxLayoutBox('title', .07, .05, .86, .17),
                PptxLayoutBox('body', .07, .27, .86, .62),
                PptxLayoutBox('pic', .5, .3, .4, .5),
                PptxLayoutBox('tbl', .1, .3, .3, .3),
                PptxLayoutBox('chart', .1, .6, .3, .3),
              ]),
            ),
            for (final k in PptxTransition.values)
              SlidePreviewTile(
                key: ValueKey('tr-${k.name}'),
                label: k.name,
                onTap: () => tapped = k.name,
                preview: SlideTransitionThumb(kind: k),
              ),
          ]),
        ),
      ),
    ));
    // Sonsuz döngü olsaydı pumpAndSettle zaman aşımına düşerdi.
    await tester.pumpAndSettle();
    expect(find.text('Başlık ve İçerik'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tr-push')));
    expect(tapped, 'push');
    await tester.tap(find.byKey(const ValueKey('layout')));
    expect(tapped, 'layout');
  });
}
