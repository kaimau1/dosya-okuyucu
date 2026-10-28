import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fm_list_groups.dart';
import 'package:dosya_okuyucu/models/fm_type.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/category_screen.dart';
import 'package:dosya_okuyucu/screens/fm/open_history_screen.dart';
import 'package:dosya_okuyucu/services/fm/list_memory.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_tiles.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_quick_filters.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_type_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Faz 13 — ortak tür süzgeci.** Kullanıcı (2026-10-22): *"son dosyalarda
/// PDF vs ayrı filtreleyemiyorum"*. Kök neden: tür süzgeci üç yerde üç ayrı
/// biçimde yazılmıştı ve alt tür (PDF/Word) çipleri bir ekran bayrağına
/// bağlıydı. Bu testler tek modeli, tek bileşeni ve ekranları kilitler.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _app(Widget home) => ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: home,
      ),
    );

/// Geniş yüzey: tek satırlık çip şeridinin tamamı ekranda olsun.
void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _now = DateTime.now().millisecondsSinceEpoch;

FsEntry _file(String name, {int size = 1000, int? ms, bool dir = false}) =>
    FsEntry(
      path: '/depo/Belgeler/$name',
      name: name,
      isDir: dir,
      sizeBytes: size,
      modifiedMs: ms ?? _now,
    );

/// Karışık liste: 3 PDF, 2 Word, 1 Excel, 2 görsel, 1 video.
final _mixed = [
  _file('kira.pdf'),
  _file('fatura.pdf'),
  _file('rapor.PDF'),
  _file('dilekce.docx'),
  _file('eski.doc'),
  _file('butce.xlsx'),
  _file('tatil.jpg'),
  _file('ekran.png'),
  _file('dugun.mp4'),
];

void main() {
  group('FmType — tek tür modeli', () {
    test('uzantı → tür (belge alt türleri ayrı)', () {
      const table = {
        'pdf': FmType.pdf,
        'PDF': FmType.pdf,
        'docx': FmType.word,
        'doc': FmType.word, // eski Office kendi ailesinde
        'odt': FmType.word,
        'xlsx': FmType.excel,
        'xls': FmType.excel,
        'csv': FmType.excel,
        'pptx': FmType.slides,
        'ppt': FmType.slides,
        'txt': FmType.text,
        'md': FmType.text,
        'json': FmType.text,
        'epub': FmType.ebook,
        'djvu': FmType.ebook,
        'xps': FmType.docOther,
        'jpg': FmType.image,
        'heic': FmType.image,
        'mp4': FmType.video,
        'mp3': FmType.audio,
        'zip': FmType.archive,
        'apk': FmType.apk,
        'xyz': FmType.other,
        '': FmType.other,
      };
      table.forEach((ext, type) {
        expect(FmType.forExtension(ext), type, reason: ext);
      });
      expect(FmType.forExtension('pdf', isDir: true), FmType.folder);
    });

    test('ÜST tür FsEntry.category ile birebir aynı (tek kaynak)', () {
      for (final ext in [
        ...FmExtensions.document,
        ...FmExtensions.image,
        ...FmExtensions.video,
        ...FmExtensions.audio,
        ...FmExtensions.archive,
        ...FmExtensions.apk,
        'bilinmeyen',
      ]) {
        expect(FmType.forExtension(ext).category,
            FsEntry.categoryForExtension(ext),
            reason: ext);
      }
      for (final ext in FmExtensions.document) {
        expect(FmType.forExtension(ext).isDocument, isTrue, reason: ext);
      }
    });

    test('addan tür (Çöp/Kasa kayıtları)', () {
      expect(FmType.ofName('Kira Sözleşmesi.PDF'), FmType.pdf);
      expect(FmType.ofName('.gizli'), FmType.other);
      expect(FmType.ofName('noktasiz'), FmType.other);
      expect(FmType.ofName('klasor.pdf', isDir: true), FmType.folder);
    });
  });

  group('FmFilter.types', () {
    test('PDF süzgeci yalnız PDF bırakır', () {
      final f = FmFilter.none.toggleType(FmType.pdf);
      expect(f.apply(_mixed).map((e) => e.name),
          ['kira.pdf', 'fatura.pdf', 'rapor.PDF']);
      expect(f.activeCount, 1);
      expect(f.isActive, isTrue);
    });

    test('PDF + Word çoklu seçim → ikisinden biri', () {
      final f =
          FmFilter.none.toggleType(FmType.pdf).toggleType(FmType.word);
      expect(f.apply(_mixed).length, 5);
      // Aynı çipe yeniden dokunmak çıkarır.
      expect(f.toggleType(FmType.pdf).apply(_mixed).length, 2);
    });

    test('imza türü içerir (önbellek bayatlamasın)', () {
      expect(FmFilter.none.toggleType(FmType.pdf).signature,
          isNot(FmFilter.none.signature));
      expect(FmFilter.none.toggleType(FmType.pdf).signature,
          isNot(FmFilter.none.toggleType(FmType.word).signature));
    });

    test('tür sayıları seçili türden BAĞIMSIZ, öteki ölçütlere bağlı', () {
      final counts = FmTypeChips.countsFor(
          _mixed, FmFilter.none.toggleType(FmType.word));
      expect(counts[FmType.pdf], 3);
      expect(counts[FmType.word], 2);
      // Boyut ölçütü sayıları daraltır.
      final big = [..._mixed, _file('dev.pdf', size: 200 * 1024 * 1024)];
      final large = FmTypeChips.countsFor(
          big, FmFilter.none.withSizeRange(FmSizeRange.large));
      expect(large, {FmType.pdf: 1});
    });
  });

  /// Tür hapını açar, [types]'a dokunur, "N dosyayı göster" ile kapatır
  /// (2026-10-28: türler tek açılır hap + levha).
  Future<void> pickTypes(WidgetTester tester, List<FmType> types) async {
    // pumpAndSettle DEĞİL: bazı ekranlarda sürekli dönen gösterge var.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await tester.tap(find.byKey(const ValueKey('type-pill')).first);
    await settle();
    for (final t in types) {
      await tester.tap(find.byKey(ValueKey('type-${t.name}')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('type-done')));
    await settle();
  }

  group('FmTypeChips bileşeni', () {
    /// Çipleri ve süzülmüş listenin uzunluğunu birlikte çizen düzenek.
    Future<ValueNotifier<FmFilter>> pump(
        WidgetTester tester, List<FsEntry> source) async {
      _wide(tester);
      final filter = ValueNotifier(FmFilter.none);
      await tester.pumpWidget(_app(Scaffold(
        body: ValueListenableBuilder<FmFilter>(
          valueListenable: filter,
          builder: (context, f, _) => Column(children: [
            FmFilterBar(
              children: FmTypeChips.forEntries(context,
                  source: source,
                  filter: f,
                  onChanged: (v) => filter.value = v),
            ),
            Text('görünen: ${f.apply(source).length}'),
          ]),
        ),
      )));
      return filter;
    }

    testWidgets('levhadaki sayı = dokununca kalan dosya; hap seçimi yazar',
        (tester) async {
      await pump(tester, _mixed);
      expect(find.text('Tür'), findsOneWidget);
      for (final (type, label, n) in [
        (FmType.pdf, 'PDF', 3),
        (FmType.word, 'Word', 2),
        (FmType.excel, 'Excel', 1),
        (FmType.image, 'Fotoğraflar', 2),
        (FmType.video, 'Videolar', 1),
      ]) {
        await tester.tap(find.byKey(const ValueKey('type-pill')));
        await tester.pumpAndSettle();
        // Levhada tür kutusu sayısıyla.
        expect(
            find.descendant(
                of: find.byKey(ValueKey('type-${type.name}')),
                matching: find.text('$n')),
            findsOneWidget,
            reason: label);
        await tester.tap(find.byKey(ValueKey('type-${type.name}')));
        await tester.pump();
        // Liste ARKADA hemen süzülür; düğme sonucu söyler.
        expect(find.text('görünen: $n'), findsOneWidget, reason: label);
        expect(find.text('$n dosyayı göster'), findsOneWidget, reason: label);
        await tester.tap(find.byKey(const ValueKey('type-done')));
        await tester.pumpAndSettle();
        expect(find.text('$label · $n'), findsOneWidget, reason: label);
        // "Tüm türler" seçimi temizler.
        await tester.tap(find.byKey(const ValueKey('type-pill')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('type-all')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('type-done')));
        await tester.pumpAndSettle();
        expect(find.text('görünen: 9'), findsOneWidget);
      }
    });

    testWidgets('PDF + Word birlikte seçilir', (tester) async {
      final filter = await pump(tester, _mixed);
      await pickTypes(tester, [FmType.pdf, FmType.word]);
      expect(filter.value.types, {FmType.pdf, FmType.word});
      expect(find.text('görünen: 5'), findsOneWidget);
      expect(find.text('PDF +1 · 5'), findsOneWidget);
    });

    testWidgets('tek türlü listede tür seçici çizilmez', (tester) async {
      await pump(tester, [_file('a.pdf'), _file('b.pdf')]);
      expect(find.byType(FmTypePill), findsNothing);
    });
  });

  group('ekranlar', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ListMemory.resetForTest();
    });

    Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
      _wide(tester);
      await tester.pumpWidget(_app(screen));
      await tester.pump();
    }

    testWidgets(
        'Yeni gelenler (CategoryScreen, bayraksız): PDF çipi tek dokunuşla '
        'yalnız PDF gösterir', (tester) async {
      await pumpScreen(
          tester,
          CategoryScreen(
            title: 'Yeni gelenler',
            files: _mixed,
            memoryId: 'new_files',
          ));
      await pickTypes(tester, [FmType.pdf]);
      expect(find.byType(FmEntryRow), findsNWidgets(3));
      expect(find.text('dilekce.docx'), findsNothing);
      // Süzgeç oturum boyunca hatırlanır (K17).
      expect(ListMemory.filterOf('new_files').types, {FmType.pdf});
    });

    testWidgets('Belgeler kutusu: Word ve Excel çipleri', (tester) async {
      final docs = [
        for (final e in _mixed)
          if (e.category == FmCategory.document) e,
      ];
      await pumpScreen(tester, CategoryScreen(title: 'Belgeler', files: docs));
      await pickTypes(tester, [FmType.excel]);
      expect(find.byType(FmEntryRow), findsOneWidget);
      expect(find.text('butce.xlsx'), findsOneWidget);
    });

    List<({FsEntry entry, int openedAtMs})> history() {
      const day = 24 * 60 * 60 * 1000;
      return [
        (entry: _mixed[0], openedAtMs: _now), // kira.pdf bugün
        (entry: _mixed[3], openedAtMs: _now - 1000), // dilekce.docx bugün
        (entry: _mixed[6], openedAtMs: _now - 3 * day), // tatil.jpg bu hafta
        (entry: _mixed[1], openedAtMs: _now - 60 * day), // fatura.pdf eski
      ];
    }

    testWidgets('Son açılanlar: PDF süzgeci', (tester) async {
      await pumpScreen(tester, OpenHistoryScreen(entriesForTest: history()));
      expect(find.byType(FmEntryRow), findsNWidgets(4));
      await pickTypes(tester, [FmType.pdf]);
      expect(find.byType(FmEntryRow), findsNWidgets(2));
      expect(find.text('kira.pdf'), findsOneWidget);
      expect(find.text('fatura.pdf'), findsOneWidget);
    });

    testWidgets('Son açılanlar: açılma tarihine göre gruplar', (tester) async {
      await pumpScreen(tester, OpenHistoryScreen(entriesForTest: history()));
      expect(find.text('Bugün · 2'), findsOneWidget);
      expect(find.text('Bu hafta · 1'), findsOneWidget);
      expect(find.text('Daha eski · 1'), findsOneWidget);
    });

    testWidgets('Son açılanlar: ada göre sıralama kalıcı', (tester) async {
      await pumpScreen(tester, OpenHistoryScreen(entriesForTest: history()));
      await tester.tap(find.text('Analiz ve diğer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Ada göre'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('more-done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final names = tester
          .widgetList<FmEntryRow>(find.byType(FmEntryRow))
          .map((r) => r.entry.name)
          .toList();
      expect(names, ['dilekce.docx', 'fatura.pdf', 'kira.pdf', 'tatil.jpg']);
      final saved = await ListMemory.load(OpenHistoryScreen.memoryId);
      expect(saved.sort, FmSort.name);
    });

    testWidgets('Son açılanlar: çoklu seçim + geçmişten kaldır + geri al',
        (tester) async {
      await pumpScreen(tester, OpenHistoryScreen(entriesForTest: history()));
      await tester.longPress(find.text('kira.pdf'));
      await tester.pump();
      await tester.tap(find.text('tatil.jpg'));
      await tester.pump();
      expect(find.text('2 / 4 seçildi'), findsOneWidget);
      await tester.tap(find.byTooltip('Seçim'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Geçmişten kaldır'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FmEntryRow), findsNWidgets(2));
      expect(find.text('kira.pdf'), findsNothing);
      expect(find.text('2 dosya geçmişten kaldırıldı'), findsOneWidget);
    });

    for (final (name, screen) in [
      ('Son açılanlar', () => OpenHistoryScreen(entriesForTest: history())),
      ('Yeni gelenler', () => CategoryScreen(title: 'Yeni gelenler', files: _mixed)),
    ]) {
      testWidgets('$name: 360 dp ve 2,0× yazıda taşma yok', (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(_app(screen()));
        await tester.pump();
        // PDF süzgeci açıkken (hap kalın) ve seçimde de taşmasın; levha da
        // 2,0× yazıda taşmaz.
        await pickTypes(tester, [FmType.pdf]);
        await tester.longPress(find.byType(FmEntryRow).first);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('boş sonuç → "Filtreyi temizle"', (tester) async {
      ListMemory.rememberFilter(OpenHistoryScreen.memoryId,
          FmFilter.none.toggleType(FmType.pdf).withSizeRange(FmSizeRange.large));
      await pumpScreen(tester, OpenHistoryScreen(entriesForTest: history()));
      expect(find.byType(FmEntryRow), findsNothing);
      await tester.tap(find.byKey(const ValueKey('clear-filter')));
      await tester.pump();
      expect(find.byType(FmEntryRow), findsNWidgets(4));
    });
  });

  test('gruplama açılma zamanını kullanabilir', () {
    final items = groupEntries(
      [_file('a.pdf', ms: 0), _file('b.pdf', ms: 0)],
      FmSort.date,
      now: DateTime.now(),
      timeOf: (e) => e.name == 'a.pdf' ? _now : 0,
    );
    expect(items.whereType<FmHeaderItem>().map((h) => h.labelKey),
        ['grp.today', 'grp.older']);
  });
}

