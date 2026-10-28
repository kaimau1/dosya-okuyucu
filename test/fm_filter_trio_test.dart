import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_more_sheet.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_quick_filters.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_type_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Süzgeç şeridi: EN FAZLA üç kart (Tür · Kaynak ve zaman · Analiz ve diğer),
/// kaydırma yok, 360 dp'de taşma yok; "Analiz ve diğer" levhası sırala + tarih/
/// boyut kutularını yazar ve filtreyi gerçekten değiştirir.
void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  FsEntry f(String path, int size) => FsEntry(
      path: path, name: path.split('/').last, isDir: false, sizeBytes: size, modifiedMs: now);
  final files = [
    f('/storage/emulated/0/WhatsApp/a.pdf', 10),
    f('/storage/emulated/0/Download/b.docx', 20),
    f('/storage/emulated/0/DCIM/c.jpg', 30),
  ];

  Widget host(Widget child, Locale locale) =>
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: child),
        ),
      );

  for (final lang in ['tr', 'en', 'ar']) {
    testWidgets('üç kart 360 dp ve 2× yazıda taşmaz · $lang', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var filter = FmFilter.none;
      await t.pumpWidget(host(
        MediaQuery(
          data: const MediaQueryData(
              size: Size(360, 640), textScaler: TextScaler.linear(2)),
          child: StatefulBuilder(
            builder: (c, set) => FmQuickFilters(
              source: files,
              filter: filter,
              onChanged: (v) => set(() => filter = v),
              leading: FmTypeChips.forEntries(c,
                  source: files, filter: filter, onChanged: (v) => set(() => filter = v)),
              trailing: [
                FmMoreChip(sections: (c) => fmDateSizeSections(c,
                    filter: filter, onChanged: (v) => set(() => filter = v))),
              ],
            ),
          ),
        ),
        Locale(lang),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('type-pill')), findsOneWidget);
      expect(find.byKey(const ValueKey('source-pill')), findsOneWidget);
      expect(find.byKey(const ValueKey('more-pill')), findsOneWidget);
      expect(find.descendant(of: find.byType(FmFilterBar), matching: find.byType(Scrollable)),
          findsNothing);
    });
  }

  testWidgets('"Analiz ve diğer" levhası tarih kutusuyla süzgeci değiştirir',
      (t) async {
    var filter = FmFilter.none;
    await t.pumpWidget(host(
      StatefulBuilder(
        builder: (c, set) => FmMoreChip(
          active: filter.activeCount,
          sections: (c) => [
            fmSortSection(c,
                sort: FmSort.date, descending: true, onSort: (_, __) {}),
            ...fmDateSizeSections(c,
                filter: filter, onChanged: (v) => set(() => filter = v)),
          ],
        ),
      ),
      const Locale('tr'),
    ));
    await t.tap(find.byKey(const ValueKey('more-pill')));
    await t.pumpAndSettle();
    expect(find.text('Sırala'), findsOneWidget);
    await t.tap(find.text('Son 7 gün'));
    await t.pumpAndSettle();
    expect(filter.dateRange, FmDateRange.week);
  });
}
