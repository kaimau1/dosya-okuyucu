import 'package:dosya_okuyucu/widgets/pdf_edit_modes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 8 — PDF'te tek düzenleme kapısı: "Düzenle" altı kipi etiketiyle
/// gösterir ve seçilen kip sayfa KAPANDIKTAN sonra döner.
void main() {
  Widget host(void Function(PdfEditMode) onPick) => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPdfEditModes(context, onPick),
                child: const Text('Düzenle'),
              ),
            ),
          ),
        ),
      );

  testWidgets('altı kip etiketiyle görünür', (tester) async {
    await tester.pumpWidget(host((_) {}));
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    for (final label in ['Metin', 'Kalem', 'İmza', 'Form', 'Sayfalar', 'AI ile']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('kip seçilince sayfa kapanır ve kip döner', (tester) async {
    PdfEditMode? picked;
    await tester.pumpWidget(host((m) => picked = m));
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İmza'));
    await tester.pumpAndSettle();
    expect(picked, PdfEditMode.sign);
    expect(find.text('Kalem'), findsNothing);
  });

  testWidgets('320 dp ekranda taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host((_) {}));
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
