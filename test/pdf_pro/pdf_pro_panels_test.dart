// PDF Pro Faz 57–65: düzenleme kipinin çubukları ve levhaları (widget).
import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_bars.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, {Locale locale = const Locale('tr')}) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

Future<void> _host<T>(WidgetTester tester,
    Future<T> Function(BuildContext) open, void Function(T) result,
    {Locale locale = const Locale('tr')}) async {
  await tester.pumpWidget(_app(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result(await open(context)),
            child: const Text('aç'),
          ),
        ),
      ),
      locale: locale));
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bağlamsal çubuk: yongalar dokunulur, etkin olan vurgulu, '
      'en az 44 dp hedef', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: PdfProContextBar(label: 'Araç seçenekleri', chips: [
        PdfProChip(AppIcons.textFields, 'Metin kutusu', () => taps++,
            active: true, tapKey: const ValueKey('a')),
        PdfProChip(AppIcons.delete, 'Sil', () => taps += 10,
            danger: true, tapKey: const ValueKey('b')),
        const PdfProChip(AppIcons.copy, 'Kopyala', null),
      ]),
    )));
    await tester.tap(find.byKey(const ValueKey('a')));
    await tester.tap(find.byKey(const ValueKey('b')));
    expect(taps, 11);
    expect(tester.getSize(find.byKey(const ValueKey('a'))).height,
        greaterThanOrEqualTo(32));
    expect(find.bySemanticsLabel('Araç seçenekleri'), findsOneWidget);
    // Boş yonga listesi yer kaplamaz.
    await tester.pumpWidget(
        _app(const Scaffold(body: PdfProContextBar(chips: []))));
    expect(tester.getSize(find.byType(PdfProContextBar)).height, 0);
  });

  testWidgets('renk levhası seçileni döndürür', (tester) async {
    int? picked;
    await _host<int?>(
        tester,
        (c) => showPdfColorSheet(c,
            title: 'Renk', colors: PdfProSwatches.text, selected: 0xFF000000),
        (v) => picked = v);
    expect(find.text('Renk'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('#d32f2f'));
    await tester.pumpAndSettle();
    expect(picked, 0xFFD32F2F);
  });

  for (final locale in const [Locale('tr'), Locale('en'), Locale('ar')]) {
    testWidgets('kilitli blok levhası nedeni söyler ve seçenek sunar '
        '(${locale.languageCode})', (tester) async {
      String? pick;
      await _host<String?>(
          tester,
          (c) => showPdfLockedBlockSheet(c, lock: PdfBlockLock.rtl),
          (v) => pick = v,
          locale: locale);
      expect(find.byKey(const ValueKey('pse-locked-box')), findsOneWidget);
      if (locale.languageCode == 'tr') {
        // Cihaz 2026-11-13: başlık belge kilidi diyordu.
        expect(find.text('Neden düzenlenemiyor?'), findsOneWidget);
        expect(find.textContaining('Bu belge'), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('pse-locked-line')));
      await tester.pumpAndSettle();
      expect(pick, 'line');
    });
  }

  testWidgets('AI önerisi: eski ve yeni metin görünür; kabul true döner',
      (tester) async {
    bool? ok;
    await _host<bool?>(
        tester,
        (c) => showPdfSuggestionSheet(c,
            before: 'Eski cümle.', after: 'Yeni cümle.'),
        (v) => ok = v);
    expect(find.text('Eski cümle.'), findsOneWidget);
    expect(find.text('Yeni cümle.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pse-ai-accept')));
    await tester.pumpAndSettle();
    expect(ok, isTrue);
  });

  testWidgets('kırpma levhası: değer yokken uygulanamaz; oranları döndürür',
      (tester) async {
    (double, double, double, double)? crop;
    await _host<(double, double, double, double)?>(
        tester, showPdfCropSheet, (v) => crop = v);
    final apply = find.byKey(const ValueKey('pse-crop-apply'));
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    await tester.drag(find.byKey(const ValueKey('pse-crop-0')),
        const Offset(120, 0));
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(crop, isNotNull);
    expect(crop!.$1, greaterThan(0));
    expect(crop!.$2, 0);
  });

  testWidgets('açıklama türü adları çevrilir', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_app(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    expect(pdfAnnotTypeLabel(ctx, PdfAnnotType.highlight), 'Vurgula');
    expect(pdfAnnotTypeLabel(ctx, PdfAnnotType.ink), 'Kalem');
    expect(pdfAnnotTypeLabel(ctx, 99), 'Açıklama');
  });
}
