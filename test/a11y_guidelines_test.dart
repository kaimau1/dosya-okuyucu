import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/screens/fm/category_screen.dart';
import 'package:dosya_okuyucu/screens/fm/important_screen.dart';
import 'package:dosya_okuyucu/screens/fm/jobs_screen.dart';
import 'package:dosya_okuyucu/screens/fm/open_history_screen.dart';
import 'package:dosya_okuyucu/screens/fm/search_screen.dart';
import 'package:dosya_okuyucu/screens/fm/trash_screen.dart';
import 'package:dosya_okuyucu/screens/settings/help_screen.dart';
import 'package:dosya_okuyucu/screens/settings/settings_catalog.dart';
import 'package:dosya_okuyucu/screens/settings/settings_category_screen.dart';
import 'package:dosya_okuyucu/screens/settings_screen.dart';
import 'package:dosya_okuyucu/services/fm/list_memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Erişilebilirlik kılavuzları** (Faz 16 / madde 1, G9).
///
/// Flutter'ın hazır denetimleri ana ekranlarda koşar:
/// * `androidTapTargetGuideline` — dokunma hedefi ≥ 48×48 dp;
/// * `labeledTapTargetGuideline` — her dokunulabilir öğenin TalkBack'te
///   okunan bir adı var;
/// * `textContrastGuideline` — metin/zemin ≥ 4,5:1 (büyük yazıda 3:1).
///
/// Her ekran açık + koyu temada, Türkçe ve Arapça (RTL) ölçülür. Bugüne
/// kadar 0 ekranda koşuyordu.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  late Directory root;
  late List<FsEntry> files;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('a11y');
    Directory('${root.path}/Faturalar').createSync();
    files = [
      for (final (name, size) in [
        ('Kira sözleşmesi.pdf', 120000),
        ('Toplantı notları.docx', 34000),
        ('Bütçe 2026.xlsx', 56000),
        ('Tatil.jpg', 240000),
      ])
        () {
          final f = File('${root.path}/$name')
            ..writeAsBytesSync(List.filled(size, 32));
          return FsEntry(
              path: f.path,
              name: name,
              isDir: false,
              sizeBytes: size,
              modifiedMs: f.lastModifiedSync().millisecondsSinceEpoch);
        }(),
    ];
  });

  Future<void> pump(WidgetTester tester, Widget screen,
      {Brightness brightness = Brightness.light,
      Locale locale = const Locale('tr'),
      double textScale = 1}) async {
    SharedPreferences.setMockInitialValues({});
    ListMemory.resetForTest();
    final state = AppState();
    await tester.runAsync(state.init);
    tester.view.physicalSize = const Size(360, 780) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark(),
        locale: locale,
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        // Uygulamanın kendi ölçeği gibi: sistem ölçeğinin YERİNE geçer.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(const Duration(seconds: 1));
  }

  final screens = <String, Widget Function()>{
    'gezgin': () => BrowserScreen(path: root.path),
    'kategori': () =>
        CategoryScreen(title: 'Belgeler', files: files, memoryId: 'a11y'),
    'son açılanlar': () => OpenHistoryScreen(entriesForTest: [
          for (final e in files) (entry: e, openedAtMs: e.modifiedMs),
        ]),
    'arama': () => const SearchScreen(),
    'ayarlar': () => const SettingsScreen(),
    'ayar kategorisi': () =>
        SettingsCategoryScreen(category: settingsCategories().first),
    'yardım': () => const HelpScreen(),
    'çöp kutusu': () => const TrashScreen(),
    'önemli': () => const ImportantScreen(),
    'işlemler': () => const JobsScreen(),
  };

  for (final entry in screens.entries) {
    for (final b in Brightness.values) {
      for (final locale in const [Locale('tr'), Locale('ar')]) {
        final label = '${entry.key} · ${b.name} · ${locale.languageCode}';
        testWidgets('kılavuzlar: $label', (tester) async {
          final handle = tester.ensureSemantics();
          await pump(tester, entry.value(), brightness: b, locale: locale);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          // Kontrast renge bağlı, dile değil: Arapçada test motorunun yedek
          // glif kutuları kenar yumuşatmasıyla ara renk üretip ölçümü
          // bozuyor → yalnız Türkçede ölçülür (renk çiftlerinin kesin
          // denetimi `contrast_test`te).
          if (locale.languageCode == 'tr') {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          handle.dispose();
        });
      }
    }
  }

  // Faz 16 / madde 3: uygulama içi yazı ölçeğinin üst ucu (2,0×) 360 dp
  // genişlikte taşma (RenderFlex overflow) üretmez — satırlar iki satıra
  // iner ya da kısalır, kesilip sarı-siyah şerit çizmez.
  for (final entry in screens.entries) {
    for (final locale in const [Locale('tr'), Locale('ar')]) {
      testWidgets('2,0× yazı taşmıyor: ${entry.key} · ${locale.languageCode}',
          (tester) async {
        await pump(tester, entry.value(), locale: locale, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
