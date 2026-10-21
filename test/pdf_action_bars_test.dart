import 'package:dosya_okuyucu/widgets/pdf_action_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var:** çubuklar `ViewerScreen`in içindeki özel metotlardı ve
/// dar ekranda taşıyor mu ölçülemiyordu — kullanıcı 2026-08-29'da tam bunu
/// bildirdi (*"araç menüleri zarif değil, yetersiz ve kötü görünüyor"*).
/// Burada gerçek telefon genişliklerinde ve büyütülmüş yazı ölçeğinde çizilip
/// `RenderFlex overflowed` çıkmadığı doğrulanıyor.
void main() {
  const colors = [0xFFFFE066, 0xFF9BE09F, 0xFFF9A8CB, 0xFF96CDF7, 0xFFFFC07A];

  Widget harness(Widget bar, {double width = 360, double textScale = 1.0}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 720),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: bar,
              ),
            ),
          ),
        ),
      );

  PdfSelectionBar selectionBar({
    VoidCallback? onHighlight,
    void Function(int)? onPickColor,
    VoidCallback? onUndo,
    VoidCallback? onRemove,
    VoidCallback? onEdit,
    bool marking = false,
    String preview = '“NOTEBOOK”',
  }) =>
      PdfSelectionBar(
        preview: preview,
        colors: colors,
        selectedColor: colors.first,
        marking: marking,
        onHighlight: onHighlight ?? () {},
        onPickColor: onPickColor ?? (_) {},
        onUndoHighlight: onUndo ?? () {},
        onDone: () {},
        onCopy: () {},
        onEdit: onEdit ?? () {},
        onTranslate: () {},
        moreItems: [
          PdfBarMenuItem(
            icon: Icons.format_color_reset_rounded,
            label: 'Vurguyu kaldır',
            onTap: onRemove ?? () {},
          ),
        ],
        highlightLabel: 'Vurgula',
        copyLabel: 'Kopyala',
        editLabel: 'Düzenle',
        translateLabel: 'Çevir',
        markedLabel: 'Vurgulandı',
        undoLabel: 'Geri al',
        doneLabel: 'Bitti',
        colorTooltip: 'Vurgu rengi',
        moreTooltip: 'Daha fazla',
      );


  group('taşma', () {
    // 320 = küçük telefon, 360 = en yaygın, 412 = Pixel/Xiaomi.
    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets('seçim çubuğu ${width.toInt()} dp\'de taşmaz',
          (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(harness(selectionBar(), width: width));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('BÜYÜK yazı ölçeğinde de taşmaz', (tester) async {
      // Uygulama içi yazı ölçeği 1,4'e kadar çıkabiliyor (Ayarlar > Görünüm).
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          harness(selectionBar(), width: 320, textScale: 1.4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ÇOK UZUN seçim metni çubuğu şişirmez', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(
        selectionBar(preview: '“${'çok uzun bir seçim ' * 20}”'),
      ));
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('vurgu kipi ${width.toInt()} dp\'de taşmaz', (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
            harness(selectionBar(marking: true), width: width, textScale: 1.3));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('davranış', () {
    testWidgets('renkler ilk bakışta YOK — vurgu menüsü yer kaplamıyor',
        (tester) async {
      // Kullanıcı 2026-09-27: "vurgu menüsü çok kullanılan bir şey değil,
      // hemen karşımıza çıkıp yer kaplıyor".
      await tester.pumpWidget(harness(selectionBar()));
      expect(find.byTooltip('Vurgu rengi'), findsNothing);
      expect(find.text('Vurgula'), findsOneWidget);
    });

    testWidgets('Vurgula tek dokunuş; vurgu kipinde renk + Geri al + Bitti',
        (tester) async {
      var highlighted = 0;
      await tester.pumpWidget(
          harness(selectionBar(onHighlight: () => highlighted++)));
      await tester.tap(find.text('Vurgula'));
      expect(highlighted, 1);

      int? picked;
      var undone = 0;
      await tester.pumpWidget(harness(selectionBar(
        marking: true,
        onPickColor: (c) => picked = c,
        onUndo: () => undone++,
      )));
      expect(find.text('Bitti'), findsOneWidget);
      await tester.tap(find.byTooltip('Vurgu rengi').at(2));
      expect(picked, colors[2]);
      await tester.tap(find.byTooltip('Geri al'));
      expect(undone, 1);
      // Vurgu kipinde eylem karoları yok: yanlışlıkla Düzenle'ye basılmaz.
      expect(find.text('Düzenle'), findsNothing);
    });

    testWidgets('vurgu kaldırma ⋯ menüsünde', (tester) async {
      var removed = false;
      await tester
          .pumpWidget(harness(selectionBar(onRemove: () => removed = true)));
      await tester.tap(find.byTooltip('Daha fazla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vurguyu kaldır'));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
    });

    testWidgets('eylemler etiketleriyle görünüyor', (tester) async {
      await tester.pumpWidget(harness(selectionBar()));
      expect(find.text('Kopyala'), findsOneWidget);
      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Çevir'), findsOneWidget);
    });
  });
}
