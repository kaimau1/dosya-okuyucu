import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/widgets/doc_action_bar.dart';
import 'package:dosya_okuyucu/widgets/editor_top_bar.dart';
import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget Function(BuildContext) appBarActions,
        {Widget? bottom, double scale = 1}) =>
    MaterialApp(
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
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('belge.docx'),
            actions: [appBarActions(context)],
          ),
          body: const SizedBox.expand(),
          bottomNavigationBar: bottom,
        ),
      ),
    );

/// Faz 40 / 1: tüm editörlerde üst çubuk sırası aynı.
void main() {
  testWidgets('sıra sabit: kaydet · geri al · yinele · ek · ⋮', (tester) async {
    var saved = 0, exported = 0;
    final history = ValueNotifier(0);
    await tester.pumpWidget(_app((context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: EditorTopBar.actions(
            context,
            onSave: () => saved++,
            history: history,
            undo: () => history.value > 0 ? () {} : null,
            redo: () => null,
            extras: [
              IconButton(
                  tooltip: 'ara', icon: const Icon(AppIcons.search), onPressed: () {}),
            ],
            menu: [
              EditorMenuItem(
                  id: 'export',
                  icon: AppIcons.share,
                  label: 'Paylaş / Dışa aktar',
                  onTap: () => exported++),
            ],
          ),
        )));
    final xs = [
      for (final tip in ['Kaydet', 'Geri al', 'Yinele', 'ara', 'Daha fazla'])
        tester.getCenter(find.byTooltip(tip)).dx,
    ];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]));
    }
    // Geri al başta kapalı; geçmiş değişince yalnız o düğme açılır.
    IconButton undo() => tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(AppIcons.undo), matching: find.byType(IconButton)));
    expect(undo().onPressed, isNull);
    history.value = 1;
    await tester.pump();
    expect(undo().onPressed, isNotNull);

    await tester.tap(find.byTooltip('Kaydet'));
    expect(saved, 1);
    await tester.tap(find.byKey(EditorTopBar.moreKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paylaş / Dışa aktar'));
    await tester.pumpAndSettle();
    expect(exported, 1);
  });

  testWidgets('menü boşken ⋮ yeri korunur ama kapalı', (tester) async {
    await tester.pumpWidget(_app((context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: EditorTopBar.actions(context, onSave: () {}),
        )));
    final more = tester.widget<PopupMenuButton<String>>(
        find.byKey(EditorTopBar.moreKey));
    expect(more.enabled, isFalse);
  });

  testWidgets('bağlam grubu şeridin başında; 2× yazıda taşma yok',
      (tester) async {
    await tester.pumpWidget(_app(
      (context) => const SizedBox.shrink(),
      scale: 2,
      bottom: DocActionBar(
        [
          DocAction(AppIcons.share, 'Paylaş', () {}),
          DocAction(AppIcons.download, 'İndir', () {}),
          DocAction(AppIcons.translate, 'Çevir', () {}),
        ],
        contextual: [
          DocAction(AppIcons.copyPlain, 'Kopyala', () {}),
          DocAction(AppIcons.cut, 'Kes', () {}),
        ],
        contextLabel: 'Seçim',
      ),
    ));
    expect(find.byKey(const ValueKey('doc-bar-context')), findsOneWidget);
    expect(tester.getCenter(find.text('Kopyala')).dx,
        lessThan(tester.getCenter(find.text('Paylaş')).dx));
    expect(tester.takeException(), isNull);
  });
}
