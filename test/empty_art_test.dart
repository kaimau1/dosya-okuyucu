import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/motion.dart';
import 'package:dosya_okuyucu/core/page_transitions.dart';
import 'package:dosya_okuyucu/widgets/empty_art.dart';
import 'package:dosya_okuyucu/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 40 / 2: boş durum çizimleri ve sayfa geçişi hareket tokenları.
void main() {
  test('simgeden sahne seçimi', () {
    expect(EmptyArtKind.forIcon(AppIcons.emptyFolder), EmptyArtKind.folder);
    expect(EmptyArtKind.forIcon(AppIcons.noMatch), EmptyArtKind.search);
    expect(EmptyArtKind.forIcon(AppIcons.searchOff), EmptyArtKind.search);
    expect(EmptyArtKind.forIcon(AppIcons.cleanEmpty), EmptyArtKind.clean);
    expect(EmptyArtKind.forIcon(AppIcons.audiobook), EmptyArtKind.document);
  });

  for (final brightness in Brightness.values) {
    testWidgets('her sahne çizilir ($brightness, 2× yazı)', (tester) async {
      for (final kind in EmptyArtKind.values) {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: FmEmptyState(
                icon: AppIcons.emptyFolder,
                art: kind,
                title: 'Klasör boş',
                hint: 'Buraya dosya taşıyın ya da yeni bir belge oluşturun',
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(EmptyArt), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  test('sahne yeniden çizimi yalnız değişince', () {
    const a = EmptyArtPainter(
        kind: EmptyArtKind.folder,
        paper: Color(0xFFEEEEEE),
        edge: Color(0xFFCCCCCC),
        accent: Color(0xFF336699));
    const b = EmptyArtPainter(
        kind: EmptyArtKind.folder,
        paper: Color(0xFFEEEEEE),
        edge: Color(0xFFCCCCCC),
        accent: Color(0xFF336699));
    expect(a.shouldRepaint(b), isFalse);
  });

  test('sayfa geçişi süreleri Motion tokenlarından', () {
    const b = FastPageTransitionsBuilder();
    expect(b.transitionDuration, Motion.medium);
    expect(b.reverseTransitionDuration, Motion.pageReverse);
  });

  testWidgets('sağdan sola dilde yeni sayfa soldan girer', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      theme: ThemeData(platform: TargetPlatform.android).copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FastPageTransitionsBuilder(),
        }),
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const Scaffold(body: Text('a')),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('b')))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final slide = tester
        .widgetList<SlideTransition>(find.ancestor(
            of: find.text('b'), matching: find.byType(SlideTransition)))
        .first;
    expect(slide.position.value.dx, lessThan(0));
    await tester.pumpAndSettle();
  });
}
