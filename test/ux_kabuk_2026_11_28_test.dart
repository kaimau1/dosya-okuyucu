import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/widgets/app_action_sheet.dart';
import 'package:dosya_okuyucu/widgets/doc_action_bar.dart';
import 'package:dosya_okuyucu/widgets/ink/pen_art.dart';
import 'package:dosya_okuyucu/widgets/menu_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı ekran görüntüleri turu (2026-11-28): alt çubuk %30 alçak, her
/// menüde Ayarlar düğmesi, Notlar tarzı kalem tepsisi.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _app(Widget Function(BuildContext) body, {Widget? bottom}) =>
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: _delegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: body(context),
          bottomNavigationBar: bottom,
        ),
      ),
    );

void main() {
  testWidgets('alt eylem çubuğu ≈55 dp (eski ≈80), etiket tek satır',
      (tester) async {
    await tester.pumpWidget(_app(
      (_) => const SizedBox.shrink(),
      bottom: DocActionBar([
        DocAction(AppIcons.editNote, 'Düzenle', () {}, primary: true),
        DocAction(AppIcons.toc, 'İçindekiler', () {}),
        DocAction(AppIcons.share, 'Paylaş', () {}),
      ]),
    ));
    final h = tester.getSize(find.byType(DocActionBar)).height;
    expect(h, lessThanOrEqualTo(58));
    expect(h, greaterThanOrEqualTo(48), reason: 'dokunma hedefi korunur');
    expect(tester.takeException(), isNull);
  });

  testWidgets('menü levhasında Ayarlar düğmesi levhayı kapatıp Ayarlar açar',
      (tester) async {
    var opened = 0;
    MenuSections.openSettings = (_) => opened++;
    addTearDown(() => MenuSections.openSettings = null);
    String? result = 'boş';
    await tester.pumpWidget(_app((context) => Center(
          child: TextButton(
            onPressed: () async {
              result = await showAppActionSheet<String>(
                context,
                title: 'Analiz ve düzenle',
                groups: const [
                  AppActionGroup(actions: [
                    AppAction(value: 'a', icon: AppIcons.share, label: 'Bir'),
                  ]),
                ],
              );
            },
            child: const Text('aç'),
          ),
        )));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.byKey(MenuSections.settingsKey), findsOneWidget);
    await tester.tap(find.byKey(MenuSections.settingsKey));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(result, isNull, reason: 'levha seçim yapılmadan kapandı');
    expect(find.byType(MenuSections), findsNothing);
  });

  testWidgets('kanca bağlı değilse Ayarlar düğmesi çıkmaz', (tester) async {
    MenuSections.openSettings = null;
    await tester.pumpWidget(_app((context) => Center(
          child: TextButton(
            onPressed: () => showAppActionSheet<String>(
              context,
              title: 'Başlık',
              groups: const [
                AppActionGroup(actions: [
                  AppAction(value: 'a', icon: AppIcons.share, label: 'Bir'),
                ]),
              ],
            ),
            child: const Text('aç'),
          ),
        )));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.byKey(MenuSections.settingsKey), findsNothing);
  });

  testWidgets('kalem tepsisi: çizilmiş kalemler çizilir, dokunuş iletilir',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app((_) => Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final art in PenArt.values)
              PenArtSlot(
                key: ValueKey('slot-${art.name}'),
                art: art,
                label: art.name,
                selected: art == PenArt.pen,
                ink: const Color(0xFF1E88E5),
                onTap: () => taps++,
              ),
          ]),
        )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('slot-highlighter')));
    expect(taps, 1);
    expect(tester.getSize(find.byKey(const ValueKey('slot-pen'))),
        const Size(44, 56));
  });
}
