import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/ocr_studio_screen.dart';
import 'package:dosya_okuyucu/services/ocr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orderOcrRows & formatOrderedLines: sütun sırası ve paragraf boşluğu',
      () {
    final raw = [
      const OcrLine('Sağ', Rect.fromLTRB(300, 10, 380, 30)),
      const OcrLine('İkinci paragraf', Rect.fromLTRB(10, 80, 200, 100)),
      const OcrLine('Sol', Rect.fromLTRB(10, 12, 90, 32)),
      const OcrLine('Yakın alt', Rect.fromLTRB(10, 36, 150, 56)),
    ];
    final ordered = OcrService.orderOcrRows(raw);
    expect([for (final l in ordered) l.text],
        ['Sol', 'Sağ', 'Yakın alt', 'İkinci paragraf']);

    final formatted = OcrService.formatOrderedLines(ordered);
    expect(formatted, 'Sol\tSağ\nYakın alt\n\nİkinci paragraf');
  });

  test('OcrStudioScreen.parsePageRange: tekil ve aralıkları çözümler', () {
    expect(OcrStudioScreen.parsePageRange('1-3, 5, 99, 7-6', 10),
        {1, 2, 3, 5, 6, 7});
    expect(OcrStudioScreen.parsePageRange('abc, 0, -2', 5), isEmpty);
  });

  testWidgets('OcrStudioScreen: sayfa sekmeleri, temizleme ve kopyalama',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('tr'),
      supportedLocales: [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: OcrStudioScreen(
        title: 'taranmis.pdf',
        initialPagesForTest: [
          OcrPage(1, 'Iki metre\nener-\njiye var .'),
          OcrPage(2, 'ikinci sayfa metni'),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sayfa 1'), findsOneWidget);
    expect(find.text('Sayfa 2'), findsOneWidget);

    await tester.tap(find.text('Sayfa 1'));
    await tester.pumpAndSettle();

    final editor = tester.widget<TextField>(
        find.byKey(const ValueKey('ocr-editor')));
    expect(editor.controller?.text, contains('Iki metre'));

    await tester.tap(find.byKey(const ValueKey('ocr-clean')));
    await tester.pumpAndSettle();
    expect(editor.controller?.text, contains('İki metre'));

    await tester.tap(find.byKey(const ValueKey('ocr-copy')));
    await tester.pumpAndSettle();
    expect(copied, contains('İki metre'));
  });
}
