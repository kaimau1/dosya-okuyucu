import 'package:dosya_okuyucu/widgets/office_ribbon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Üç Office editörünün ortak şeridi (2026-08-07). Buradaki testler ortak
/// bileşenin sözleşmesini korur: sekme değişimi, etkin durum ve çipin bir
/// menü düğmesinin çocuğu olarak çalışması.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('sekmeye dokununca o sekmenin öğeleri çizilir', (tester) async {
    await pump(
      tester,
      const OfficeRibbon(tabs: [
        RibbonTab('Giriş', [RibbonButton(OfficeIcons.bold, 'Kalın')]),
        RibbonTab('Görünüm', [RibbonButton(OfficeIcons.zoomIn, 'Yakınlaştır')]),
      ]),
    );
    expect(find.byIcon(OfficeIcons.bold), findsOneWidget);
    expect(find.byIcon(OfficeIcons.zoomIn), findsNothing);

    await tester.tap(find.text('Görünüm'));
    await tester.pumpAndSettle();
    expect(find.byIcon(OfficeIcons.zoomIn), findsOneWidget);
    expect(find.byIcon(OfficeIcons.bold), findsNothing);
  });

  testWidgets('tek sekmede sekme şeridi çizilmez', (tester) async {
    await pump(
      tester,
      const OfficeRibbon(tabs: [
        RibbonTab('', [RibbonButton(OfficeIcons.bold, 'Kalın')]),
      ]),
    );
    expect(find.byIcon(OfficeIcons.bold), findsOneWidget);
    // Boş etiketli tek sekme için başlık satırı yok.
    expect(tester.getSize(find.byType(OfficeRibbon)).height, 48);
  });

  testWidgets('RibbonChip PopupMenuButton çocuğuyken menüyü açar',
      (tester) async {
    // Regresyon: çip kendi InkWell'ini kurunca dokunuş menüye ULAŞMIYORDU
    // (Word'ün yazı tipi ve punto menüleri açılmazdı).
    await pump(
      tester,
      PopupMenuButton<String>(
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'a', child: Text('Arial')),
        ],
        child: const RibbonChip(
          icon: OfficeIcons.fontFamily,
          label: 'Calibri',
          tooltip: 'Yazı tipi',
        ),
      ),
    );
    await tester.tap(find.text('Calibri'));
    await tester.pumpAndSettle();
    expect(find.text('Arial'), findsOneWidget);
  });

  testWidgets('kendi onTap\'i olan çip doğrudan çalışır', (tester) async {
    var tapped = 0;
    await pump(
      tester,
      RibbonChip(
        icon: OfficeIcons.fontSize,
        label: '11',
        tooltip: 'Punto',
        onTap: () => tapped++,
      ),
    );
    await tester.tap(find.text('11'));
    await tester.pump();
    expect(tapped, 1);
  });
}
