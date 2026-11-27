import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/widgets/app_action_sheet.dart';
import 'package:dosya_okuyucu/widgets/doc_more_sheet.dart';
import 'package:dosya_okuyucu/widgets/menu_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Menü görünümü** (2026-11-15, kullanıcı: menüler baştan tasarlansın; iki
/// görünüm, Ayarlar'dan seçilir, varsayılan sekmeli). MenuKit kullanan her
/// levha (`showAppActionSheet`, `DocMoreSheet`, dosya levhası) aynı
/// `MenuSections`ı çizer — görünüm kitten gelir.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _app(Widget Function(BuildContext) body) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: _delegates,
      home: Builder(builder: (context) => Scaffold(body: body(context))),
    );

const _sections = [
  MenuKitSection(title: 'Pano', actions: [
    MenuKitAction(icon: Icons.copy, label: 'Kopyala', onTap: _noop),
    MenuKitAction(icon: Icons.paste, label: 'Yapıştır', onTap: _noop),
  ]),
  MenuKitSection(title: 'Biçim', actions: [
    MenuKitAction(
        icon: Icons.wrap_text, label: 'Kaydır', onTap: _noop, checked: true),
  ]),
  MenuKitSection(title: 'Boş', actions: []),
];

void _noop() {}

void main() {
  const tr = AppStrings(AppLanguage.tr);

  test('kayıt yoksa Bento (2026-11-21); tanınmayan ad da Bento', () {
    expect(MenuLook.byName(null), MenuLook.bento);
    expect(MenuLook.byName('yok'), MenuLook.bento);
    expect(MenuLook.byName('tabbed'), MenuLook.tabbed);
    expect(MenuLook.byName('bento'), MenuLook.bento);
  });

  // R3 (b) bekçisi (2026-11-27): Word ⋮ levhası (showEntryActions ile aynı
  // showModalBottomSheet kurgusu) kayarken gövde her karede yeniden
  // KURULMAZ — yalnız açılışın ilk karesinde bir kez. Kare başı build
  // gerilemesi şüphesinde bu sayaç kanıttır.
  testWidgets('levha açılıp kapanırken MenuSections tek kez kurulur',
      (tester) async {
    for (final look in MenuLook.values) {
      var builds = 0;
      final trace = <String>[];
      final old = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (e, _) {
        if (trace.length < 60) trace.add('${e.widget.runtimeType}');
        if (e.widget is MenuSections) builds++;
      };
      try {
        await tester.pumpWidget(_app((context) => Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.88),
                  builder: (ctx) => SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(ctx).bottom),
                      child: MenuSections(
                        look: look,
                        quick: const [
                          MenuKitAction(
                              icon: Icons.copy, label: 'Kopyala', onTap: _noop),
                          MenuKitAction(
                              icon: Icons.paste, label: 'Yapıştır', onTap: _noop),
                          MenuKitAction(
                              icon: Icons.delete,
                              label: 'Sil',
                              tone: MenuTone.danger,
                              onTap: _noop),
                        ],
                        sections: _sections,
                      ),
                    ),
                  ),
                ),
                child: const Text('aç'),
              ),
            )));
        await tester.tap(find.text('aç'));
        await tester.pump();
        expect(find.byType(MenuSections), findsOneWidget, reason: '$look');
        builds = 0;
        await tester.pump(const Duration(milliseconds: 16));
        trace.clear();
        await tester.pump(const Duration(milliseconds: 16));
        debugPrint('R3 kare izi ($look): ${trace.join(' > ')}');
        for (var i = 0; i < 28; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(builds, 0, reason: '$look açılış karelerinde yeniden kuruldu');
        Navigator.of(tester.element(find.byType(MenuSections))).pop();
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(MenuSections), findsNothing, reason: '$look');
        expect(builds, 0, reason: '$look kapanış karelerinde yeniden kuruldu');
      } finally {
        debugOnRebuildDirtyWidget = old;
      }
    }
  });

  testWidgets('sağlayıcısız ağaçta varsayılan sekmeli', (tester) async {
    late MenuLook look;
    await tester.pumpWidget(_app((context) {
      look = MenuKit.lookOf(context);
      return const MenuSections(sections: _sections);
    }));
    expect(look, MenuLook.tabbed);
    // Sekme çipleri: boş bölüm sekme üretmez.
    expect(find.byKey(MenuSections.tabKey(0)), findsOneWidget);
    expect(find.byKey(MenuSections.tabKey(1)), findsOneWidget);
    expect(find.byKey(MenuSections.tabKey(2)), findsNothing);
    expect(find.text('Boş'), findsNothing);
  });

  testWidgets('sekmeli: sekme değişince o grubun işleri görünür',
      (tester) async {
    await tester.pumpWidget(
        _app((_) => const MenuSections(sections: _sections)));
    expect(find.text('Kopyala'), findsOneWidget);
    expect(find.text('Kaydır'), findsNothing);
    await tester.tap(find.byKey(MenuSections.tabKey(1)));
    await tester.pump();
    expect(find.text('Kaydır'), findsOneWidget);
    expect(find.text('Kopyala'), findsNothing);
  });

  testWidgets('tek grup: sekme şeridi yok', (tester) async {
    await tester.pumpWidget(_app((_) => MenuSections(sections: [_sections[0]])));
    expect(find.byKey(MenuSections.tabKey(0)), findsNothing);
    expect(find.text('Yapıştır'), findsOneWidget);
  });

  testWidgets('Bento: bütün gruplar başlıklarıyla görünür', (tester) async {
    await tester.pumpWidget(_app((_) => const SingleChildScrollView(
        child: MenuSections(sections: _sections, look: MenuLook.bento))));
    expect(find.widgetWithText(MenuGroupTitle, 'Pano'), findsOneWidget);
    expect(find.widgetWithText(MenuGroupTitle, 'Biçim'), findsOneWidget);
    expect(find.text('Kopyala'), findsOneWidget);
    expect(find.text('Kaydır'), findsOneWidget);
    expect(find.byKey(MenuSections.tabKey(0)), findsNothing);
  });

  testWidgets('ortak eylem levhası ve "Daha fazla" aynı kiti kullanır',
      (tester) async {
    String? picked;
    await tester.pumpWidget(_app((context) => Column(children: [
          TextButton(
            onPressed: () async => picked = await showAppActionSheet<String>(
              context,
              title: 'Başlık',
              groups: const [
                AppActionGroup(actions: [
                  AppAction(value: 'a', icon: Icons.add, label: 'Ekle'),
                ]),
                AppActionGroup(title: 'Tehlike', actions: [
                  AppAction(
                      value: 'sil',
                      icon: Icons.delete,
                      label: 'Kaldır',
                      destructive: true),
                ]),
              ],
            ),
            child: const Text('levha'),
          ),
          TextButton(
            onPressed: () => DocMoreSheet.show(context, [
              const DocMoreGroup(
                  'Pano', [DocMoreItem(Icons.copy, 'Kopyala', _noop)]),
            ]),
            child: const Text('daha'),
          ),
        ])));
    await tester.tap(find.text('levha'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuSections), findsOneWidget);
    // Başlıksız ilk grup "Sık kullanılan" sekmesi olur.
    expect(find.text(tr.t('menu.tab_common')), findsOneWidget);
    await tester.tap(find.text('Tehlike'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();
    expect(picked, 'sil');

    await tester.tap(find.text('daha'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuSections), findsOneWidget);
    expect(find.text('Kopyala'), findsOneWidget);
  });

  test('ayar kalıcı: setMenuLook prefs\'e yazar, yeni açılışta okunur',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    expect(state.menuLook, MenuLook.bento);
    expect(state.appearance.menuLook, MenuLook.bento);

    await state.setMenuLook(MenuLook.tabbed);
    expect(state.appearance.menuLook, MenuLook.tabbed);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('menu_look'), 'tabbed');

    final again = AppState();
    await again.init();
    expect(again.menuLook, MenuLook.tabbed);
    expect(again.appearance.menuLook, MenuLook.tabbed);
  });
}
