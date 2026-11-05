import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/widgets/share_export_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 40 / 7: tek "Paylaş / Dışa aktar" sayfası.
void main() {
  Widget app(Widget home, {double scale = 1}) => MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      );

  testWidgets('biçim üstte, gönder altta; seçilen iş sayfa kapanınca koşar',
      (tester) async {
    final ran = <String>[];
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showShareExportSheet(context, entries: [
              ShareExportEntry(
                  id: 'share',
                  icon: AppIcons.share,
                  label: 'Paylaş',
                  group: ShareExportGroup.send,
                  run: () async => ran.add('share')),
              ShareExportEntry(
                  id: 'pdf',
                  icon: AppIcons.pdf,
                  label: 'PDF',
                  run: () async => ran.add('pdf')),
            ]),
            child: const Text('aç'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('Biçim'), findsOneWidget);
    expect(find.text('Gönder'), findsOneWidget);
    expect(tester.getTopLeft(find.text('PDF')).dy,
        lessThan(tester.getTopLeft(find.text('Paylaş')).dy));
    await tester.tap(find.byKey(const ValueKey('share-export-pdf')));
    await tester.pumpAndSettle();
    expect(ran, ['pdf']);
    expect(find.text('Biçim'), findsNothing);
  });

  testWidgets('2× yazıda taşma yok', (tester) async {
    await tester.pumpWidget(app(
      Scaffold(
        body: SingleChildScrollView(
          child: ShareExportList(entries: [
            for (final id in ['pdf', 'docx', 'odt', 'rtf'])
              ShareExportEntry(
                  id: id,
                  icon: AppIcons.pdf,
                  label: 'Uzun bir dışa aktarım biçimi adı $id',
                  hint: 'Açıklama satırı da uzun olabilir',
                  run: () async {}),
          ]),
        ),
      ),
      scale: 2,
    ));
    expect(tester.takeException(), isNull);
  });
}
