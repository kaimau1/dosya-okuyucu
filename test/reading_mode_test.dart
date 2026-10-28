import 'package:dosya_okuyucu/core/motion.dart';
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

  testWidgets('kaydırma durunca çubuklar kendiliğinden geri gelir',
      (tester) async {
    final bars = ReadingBars();
    addTearDown(bars.dispose);
    bars.scrolled(100);
    expect(bars.value, isFalse);
    await tester.pump(Motion.readingIdle - const Duration(milliseconds: 100));
    expect(bars.value, isFalse, reason: 'süre dolmadan gelmez');
    bars.scrolled(40); // kaydırma sürüyor → süre baştan
    await tester.pump(Motion.readingIdle - const Duration(milliseconds: 100));
    expect(bars.value, isFalse);
    await tester.pump(const Duration(milliseconds: 200));
    expect(bars.value, isTrue);
  });

  test('sabitlenmişken (arama açık) kaydırma çubukları gizlemez', () {
    final bars = ReadingBars()..pinned = true;
    bars.scrolled(500);
    expect(bars.value, isTrue);
    bars.hide();
    expect(bars.value, isTrue);
    bars.pinned = false;
    bars.scrolled(500);
    expect(bars.value, isFalse);
    bars.dispose();
  });

  // 2026-10-28: çubuklar gövdenin ÜSTÜNDE kayan katman — gövdenin boyu ve
  // yeri HİÇ değişmez (eskiden her karede değişiyor, metin titriyor, PDF
  // sayfa başına atlıyordu). İçerik [ReadingChrome] payıyla başlar.
  for (final kind in [DocKind.pdf, DocKind.text, DocKind.word, DocKind.slides]) {
    testWidgets('${kind.name}: aşağı kaydırınca gizlenir, dokununca gelir; '
        'gövde boyu sabit', (tester) async {
      final bars = ReadingBars();
      EdgeInsets? insets;
      await tester.pumpWidget(MaterialApp(
        home: OfficeShell(
          kind: kind,
          title: 'belge',
          readingBars: bars,
          bottomBar: const SizedBox(height: 56, child: Text('alt')),
          body: Builder(builder: (context) {
            insets = ReadingChrome.insetsOf(context);
            return ListView.builder(
              padding: insets,
              itemCount: 200,
              itemBuilder: (_, i) => SizedBox(height: 40, child: Text('$i')),
            );
          }),
        ),
      ));
      await tester.pump();
      expect(insets!.top, greaterThan(40), reason: 'üst çubuk payı');
      expect(insets!.bottom, greaterThanOrEqualTo(56), reason: 'alt çubuk payı');
      // İlk satır çubuğun ALTINDA başlar.
      expect(tester.getTopLeft(find.text('0')).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy));

      final bodyBefore = tester.getRect(find.byType(ListView));
      final titleBefore = tester.getTopLeft(find.text('belge')).dy;
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(bars.value, isFalse);
      expect(tester.getRect(find.byType(ListView)), bodyBefore,
          reason: 'gövde yeniden yerleşmez');
      expect(tester.getTopLeft(find.text('belge')).dy, lessThan(titleBefore),
          reason: 'üst çubuk yukarı kayar');

      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(bars.value, isTrue);
      expect(tester.getTopLeft(find.text('belge')).dy, titleBefore);
      expect(tester.getRect(find.byType(ListView)), bodyBefore);
    });
  }
}
