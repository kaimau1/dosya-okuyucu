import 'package:dosya_okuyucu/screens/fm/image_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Galeri rotası (2026-09-26): saydam, solarak gelir; fotoğraf ızgaradaki
/// hücresinden büyüyerek açılır (Hero) ve **aşağı kaydırınca** kapanır.
///
/// Dosyalar diskte yok: görseller çözülemez, hata yolu çizilir — rotanın,
/// kahraman geçişinin ve sürükleyerek kapatmanın kendisi sınanıyor.
void main() {
  const paths = ['/yok/a.jpg', '/yok/b.jpg', '/yok/c.jpg'];

  Widget harness() => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(imageGalleryRoute(paths: paths, initialIndex: 1)),
                child: Hero(
                  tag: fmMediaHeroTag(paths[1]),
                  child: const SizedBox(
                    key: Key('hucre'),
                    width: 80,
                    height: 80,
                    child: ColoredBox(color: Colors.teal),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('hücreden büyüyerek açılır, aşağı kaydırınca kapanır',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.byKey(const Key('hucre')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120)); // geçişin ortası
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(ImageGalleryScreen), findsOneWidget);
    expect(find.text('2/3 · 0 B · b.jpg'), findsOneWidget);

    // Kısa sürükleme kapatmaz: yerine yaylanır.
    await tester.drag(find.byType(PageView), const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(find.byType(ImageGalleryScreen), findsOneWidget);

    // Uzun sürükleme kapatır; kahraman hücresine döner.
    await tester.drag(find.byType(PageView), const Offset(0, 260));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(ImageGalleryScreen), findsNothing);
    expect(find.byKey(const Key('hucre')), findsOneWidget);
  });

  testWidgets('yana kaydırma sayfa değiştirir (dikey sürükleme onu çalmaz)',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.byKey(const Key('hucre')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3 · 0 B · c.jpg'), findsOneWidget);
    expect(find.byType(ImageGalleryScreen), findsOneWidget);
  });
}
