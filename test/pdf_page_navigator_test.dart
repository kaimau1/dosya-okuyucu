import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/pdf_bookmarks.dart';
import 'package:dosya_okuyucu/widgets/pdf_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Sayfaya git" baştan (2026-09-27): önizlemeli gezgin, İlk/Son/Önceki
/// konum kısayolları ve yıldızlı sayfalar.
void main() {
  Future<int?> open(WidgetTester tester,
      {int current = 5,
      int count = 1272,
      int? previous,
      List<int> bookmarks = const [],
      PdfBookmarkToggle? toggle}) async {
    int? result;
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await PdfPageNavigator.show(
                  context,
                  document: null,
                  current: current,
                  count: count,
                  previous: previous,
                  bookmarks: bookmarks,
                  onToggleBookmark: toggle ?? (_) async => true,
                );
                done = true;
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(done, isFalse);
    return result;
  }

  testWidgets('sayı yazıp Git → o sayfa', (tester) async {
    int? got;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              got = await PdfPageNavigator.show(context,
                  document: null,
                  current: 5,
                  count: 1272,
                  bookmarks: const [],
                  onToggleBookmark: (_) async => true);
            },
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pn-field')), '900');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pn-go')));
    await tester.pumpAndSettle();
    expect(got, 900);
  });

  testWidgets('sınır dışı sayı son sayfaya kırpılır', (tester) async {
    int? got;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              got = await PdfPageNavigator.show(context,
                  document: null,
                  current: 5,
                  count: 40,
                  bookmarks: const [],
                  onToggleBookmark: (_) async => true);
            },
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pn-field')), '999');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pn-go')));
    await tester.pumpAndSettle();
    expect(got, 40);
  });

  testWidgets('İlk / Son / Önceki konum kısayolları görünür', (tester) async {
    await open(tester, previous: 120);
    expect(find.text('İlk sayfa'), findsOneWidget);
    expect(find.text('Son sayfa'), findsOneWidget);
    expect(find.text('120. sayfaya dön'), findsOneWidget);
  });

  testWidgets('yıldızlı sayfalar listelenir, yıldız düğmesi çalışır',
      (tester) async {
    final toggled = <int>[];
    await open(tester, bookmarks: [30, 7], toggle: (p) async {
      toggled.add(p);
      return true;
    });
    expect(find.text('Yıldızlı sayfalar (2)'), findsOneWidget);
    await tester.tap(find.byTooltip('Bu sayfayı yıldızla'));
    await tester.pumpAndSettle();
    expect(toggled, [5]);
    expect(find.text('Yıldızlı sayfalar (3)'), findsOneWidget);
  });

  testWidgets('dar ekranda taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester, previous: 3, bookmarks: [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sayfa rozeti: numara + yıldız', (tester) async {
    var taps = 0, longs = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PdfPageChip(
            page: 5,
            count: 1272,
            bookmarked: true,
            onTap: () => taps++,
            onLongPress: () => longs++,
          ),
        ),
      ),
    ));
    expect(find.text('5 / 1272', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pdf-page-chip')));
    await tester.longPress(find.byKey(const ValueKey('pdf-page-chip')));
    expect([taps, longs], [1, 1]);
  });

  group('PdfBookmarks', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('bm');
      FmEnv.appSupportDir = dir.path;
      PdfBookmarks.debugReset();
    });
    tearDown(() {
      FmEnv.appSupportDir = '';
      dir.deleteSync(recursive: true);
    });

    test('yıldızla / kaldır / diske yaz / geri oku', () async {
      expect(await PdfBookmarks.toggle('/k.pdf', 12, size: 99), isTrue);
      expect(await PdfBookmarks.toggle('/k.pdf', 3, size: 99), isTrue);
      expect(PdfBookmarks.of('/k.pdf').map((b) => b.page), [3, 12]);
      expect(await PdfBookmarks.toggle('/k.pdf', 12), isFalse);
      PdfBookmarks.debugReset();
      await PdfBookmarks.ensureLoaded();
      expect(PdfBookmarks.of('/k.pdf').map((b) => b.page), [3]);
      // Taşınan dosya ad + boyutla bulunur.
      expect(PdfBookmarks.isMarked('/baska/k.pdf', 3, size: 99), isTrue);
    });
  });
}
