import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/models/media_bucket.dart';
import 'package:dosya_okuyucu/services/fm/fm_colors_store.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_filter_sheet.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_filter_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _host(
  Widget child, {
  double width = 360,
  double textScale = 1.0,
  Locale locale = const Locale('tr'),
}) {
  return ChangeNotifierProvider<AppState>.value(
    value: AppState(),
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  setUp(() {
    FmColorsStore.resetForTest();
  });

  testWidgets('Filtrele ve sırala kartlı tasarımla çalışır ve sonucu döndürür',
      (tester) async {
    FmFilterResult? result;
    await tester.pumpWidget(_host(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await showFmFilterSheet(
            context,
            filter: FmFilter.none,
            sort: FmSort.date,
            descending: true,
            extensions: const {'pdf': 12, 'docx': 4},
            buckets: const {
              MediaBucket.whatsapp: 10,
              MediaBucket.download: 6,
            },
            tags: const {'Sağlık': 5, 'Fatura': 3},
            smartCats: const {'invoice': 4, 'health': 6},
          );
        },
        child: const Text('aç'),
      ),
    )));

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(find.byType(FmFilterSheetScaffold), findsOneWidget);
    expect(find.byType(FmFilterSectionCard), findsWidgets);
    expect(find.byType(FmSortDirectionToggle), findsOneWidget);

    // Sıralamayı Ada göre + Artan yap; Son 7 gün + 1 – 10 MB seç.
    await tester.tap(find.text('Ada göre'));
    await tester.tap(find.text('Artan'));
    await tester.ensureVisible(find.text('Son 7 gün'));
    await tester.tap(find.text('Son 7 gün'));
    await tester.ensureVisible(find.text('1 – 10 MB'));
    await tester.tap(find.text('1 – 10 MB'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Uygula (2)'), findsOneWidget);

    await tester.tap(find.textContaining('Uygula (2)'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.sort, FmSort.name);
    expect(result!.descending, isFalse);
    expect(result!.filter.dateRange, FmDateRange.week);
    expect(result!.filter.sizeRange, FmSizeRange.small);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 dp ve 2,0x yazıda taşma yok (LTR ve Arapça RTL)',
      (tester) async {
    for (final locale in const [Locale('tr'), Locale('ar')]) {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFmFilterSheet(
              context,
              filter: FmFilter.none.withDateRange(FmDateRange.week),
              sort: FmSort.date,
              descending: true,
              extensions: const {'pdf': 8, 'xlsx': 3},
              buckets: const {
                MediaBucket.whatsapp: 8,
                MediaBucket.download: 3,
              },
              tags: const {'Önemli': 4},
              smartCats: const {'invoice': 4, 'health': 2},
            ),
            child: const Text('open'),
          ),
        ),
        width: 360,
        textScale: 2.0,
        locale: locale,
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(FmFilterSheetScaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(FmFilterSheetScaffold))).pop();
      await tester.pumpAndSettle();
    }
  });
}
