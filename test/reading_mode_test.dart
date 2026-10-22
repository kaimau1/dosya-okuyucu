import 'package:dosya_okuyucu/models/document.dart';
import 'package:dosya_okuyucu/widgets/office_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 18 / G20: okuma kipi — aşağı kaydırınca çubuklar çekilir, yukarı
/// kaydırma ya da tek dokunuşla geri gelir. Aynı kabuk PDF, metin, Word ve
/// slaytta kullanılıyor; PDF kaydırmayı [ReadingBars.scrolled] ile iletir.
void main() {
  test('eşik: küçük titreşim karar vermez, yön değişince birikim sıfırlanır',
      () {
    final bars = ReadingBars();
    bars.scrolled(10);
    expect(bars.value, isTrue);
    bars.scrolled(30);
    expect(bars.value, isFalse);
    bars.scrolled(-20);
    expect(bars.value, isFalse);
    bars.scrolled(-20);
    expect(bars.value, isTrue);
    bars.scrolled(100);
    bars.scrolled(0, atTop: true);
    expect(bars.value, isTrue);
  });

  for (final kind in [DocKind.pdf, DocKind.text, DocKind.word, DocKind.slides]) {
    testWidgets('${kind.name}: aşağı kaydırınca gizlenir, dokununca gelir',
        (tester) async {
      final bars = ReadingBars();
      await tester.pumpWidget(MaterialApp(
        home: OfficeShell(
          kind: kind,
          title: 'belge',
          readingBars: bars,
          bottomBar: const SizedBox(height: 56, child: Text('alt')),
          body: ListView.builder(
            itemCount: 200,
            itemBuilder: (_, i) => SizedBox(height: 40, child: Text('$i')),
          ),
        ),
      ));
      final topBefore = tester.getTopLeft(find.byType(ListView)).dy;
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(bars.value, isFalse);
      expect(tester.getTopLeft(find.byType(ListView)).dy, lessThan(topBefore));

      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(bars.value, isTrue);
      expect(tester.getTopLeft(find.byType(ListView)).dy, topBefore);
    });
  }
}
