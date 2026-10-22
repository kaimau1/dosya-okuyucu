import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/audiobook/audiobook_screen.dart';
import 'package:dosya_okuyucu/services/audiobook/doc_chapters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bölümler listelenir; yapay ses kurulu değilse "Oluştur" kapalı',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('tr'),
      supportedLocales: [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AudiobookScreen(
        path: '/x/Rapor.pdf',
        chaptersForTest: [
          AudioChapter('Giriş', 'Metin.'),
          AudioChapter('Sonuç', 'Son.'),
        ],
      ),
    ));
    await tester.pump();
    expect(find.text('Bölümler (2)'), findsOneWidget);
    expect(find.text('Antalia-2 Mini'), findsOneWidget);
    expect(find.text('EMA Lightning'), findsOneWidget);
    final start = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('ab-start')));
    expect(start.onPressed, isNotNull, reason: 'cihaz sesi seçili');
    expect(canMakeAudiobook('/a/b.docx'), isTrue);
    expect(canMakeAudiobook('/a/b.xlsx'), isFalse);
  });
}
