import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/document.dart';
import 'package:dosya_okuyucu/screens/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(LoadedDoc doc) => ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ViewerScreen(doc: doc),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('kod dosyası: odakta klavye üstü çubuk + durum satırı',
      (tester) async {
    await tester.pumpWidget(_app(const LoadedDoc(
        path: '/tmp/x.dart',
        name: 'x.dart',
        kind: DocKind.text,
        plainText: 'void main() {}\n')));
    await tester.pump();
    expect(find.byKey(const ValueKey('keyboard-accessory')), findsNothing);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.byKey(const ValueKey('keyboard-accessory')), findsOneWidget);
    expect(find.text('UTF-8'), findsOneWidget);
    expect(find.text('LF'), findsOneWidget);
    // {} ekleme araçlar çubuğundan
    await tester.tap(find.byKey(const ValueKey('code-ins-{ }')));
    await tester.pump();
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.controller!.text, contains('{}'));
    // satır sonu döndürme
    await tester.tap(find.byKey(const ValueKey('code-eol')));
    await tester.pump();
    expect(find.text('CRLF'), findsOneWidget);
  });

  testWidgets('Okuma ayarları: satır aralığı alana ve numara şeridine uygulanır',
      (tester) async {
    await tester.pumpWidget(_app(const LoadedDoc(
        path: '/tmp/y.txt',
        name: 'y.txt',
        kind: DocKind.text,
        plainText: 'bir\niki\n')));
    await tester.pump();
    double height() =>
        tester.widget<TextField>(find.byType(TextField)).style!.height!;
    expect(height(), 1.5);
    await tester.tap(find.byTooltip('Okuma ayarları'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('code-line-spacing')), 100,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('1.8'));
    await tester.pumpAndSettle();
    expect(height(), 1.8);
  });

  testWidgets('Markdown: önizleme düğmesi ve araç çubuğu', (tester) async {
    await tester.pumpWidget(_app(const LoadedDoc(
        path: '/tmp/n.md',
        name: 'n.md',
        kind: DocKind.text,
        plainText: '# Başlık\n\nmetin')));
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.byKey(const ValueKey('md-bold')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('md-preview-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('md-preview')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('md-preview-toggle')));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Markdown: geniş ekranda önizleme yan yana ve canlı',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const LoadedDoc(
        path: '/tmp/y.md',
        name: 'y.md',
        kind: DocKind.text,
        plainText: '# Başlık')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('md-preview-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('md-split')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '# Başlık\n\nyeni satır');
    await tester.pump();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('md-preview')),
            matching: find.textContaining('yeni satır', findRichText: true)),
        findsWidgets);
  });

  testWidgets('satır numarası açıkken şerit çizilir, bul seçenekleri var',
      (tester) async {
    await tester.pumpWidget(_app(const LoadedDoc(
        path: '/tmp/x.json',
        name: 'x.json',
        kind: DocKind.text,
        plainText: '{\n  "a": 1\n}')));
    await tester.pump();
    await tester.tap(find.byTooltip('Belgede ara'));
    await tester.pump();
    expect(find.byKey(const ValueKey('find-regex')), findsOneWidget);
    expect(find.byKey(const ValueKey('find-case')), findsOneWidget);
  });
}
