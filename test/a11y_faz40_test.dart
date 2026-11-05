import 'dart:math' as math;

import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/widgets/doc_action_bar.dart';
import 'package:dosya_okuyucu/widgets/editor_top_bar.dart';
import 'package:dosya_okuyucu/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Widget _host(Widget body,
        {Locale locale = const Locale('tr'),
        double scale = 1,
        ThemeData? theme}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      locale: locale,
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
      home: body,
    );

Widget _editorLike() => Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Bütçe 2026.xlsx'),
          actions: EditorTopBar.actions(
            context,
            onSave: () {},
            undo: () => () {},
            redo: () => null,
            extras: [
              IconButton(
                tooltip: context.t('common.search'),
                icon: const Icon(AppIcons.search),
                onPressed: () {},
              ),
            ],
            menu: [
              EditorMenuItem(
                  id: 'export',
                  icon: AppIcons.share,
                  label: context.t('ux.share_export'),
                  onTap: () {}),
            ],
          ),
        ),
        body: FmEmptyState(
          icon: AppIcons.emptyFolder,
          title: context.t('common.more'),
          hint: context.t('ux.share_export'),
        ),
        bottomNavigationBar: DocActionBar(
          [
            DocAction(AppIcons.share, context.t('common.share'), () {}),
            DocAction(AppIcons.download, context.t('common.download'), () {}),
            DocAction(AppIcons.translate, context.t('common.translate'), () {}),
          ],
          contextual: [
            DocAction(AppIcons.copyPlain, context.t('common.copy'), () {}),
            DocAction(AppIcons.paste, context.t('common.paste'), () {}),
          ],
          contextLabel: context.t('ux.selection'),
        ),
      ),
    );

/// Faz 40 / 3: erişilebilirlik — 2× yazı, TalkBack etiketleri, kontrast.
void main() {
  group('kontrast bekçisi (yeni ortak bileşenlerin rolleri)', () {
    for (final skin in AppSkin.values) {
      for (final b in Brightness.values) {
        if (skin.forcesDark && b == Brightness.light) continue;
        test('${skin.name}/${b.name}', () {
          final t = b == Brightness.light
              ? AppTheme.light(skin: skin)
              : AppTheme.dark(skin: skin);
          final s = t.colorScheme;
          // Etkin dok düğmesi: onPrimaryContainer / primaryContainer.
          expect(_contrast(s.onPrimaryContainer, s.primaryContainer),
              greaterThanOrEqualTo(4.5));
          // Bağlam grubu hapı: yarı saydam primaryContainer zemin üstünde yazı.
          final tint = Color.alphaBlend(
              s.primaryContainer.withValues(alpha: 0.45), s.surface);
          expect(_contrast(s.onSurface, tint), greaterThanOrEqualTo(4.5));
          // Üst çubuk simgeleri ve ⋮ menüsü.
          expect(_contrast(s.onSurface, s.surface), greaterThanOrEqualTo(4.5));
          expect(_contrast(s.onSurfaceVariant, s.surface),
              greaterThanOrEqualTo(4.5));
        });
      }
    }
  });

  for (final locale in const [Locale('tr'), Locale('ar')]) {
    testWidgets('TalkBack etiketleri + dokunma hedefi (${locale.languageCode})',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(_editorLike(), locale: locale));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    for (final b in Brightness.values) {
      testWidgets('2× yazıda taşma yok (${locale.languageCode}, ${b.name})',
          (tester) async {
        tester.view.physicalSize = const Size(360, 780) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(_editorLike(),
            locale: locale,
            scale: 2,
            theme: b == Brightness.light ? AppTheme.light() : AppTheme.dark()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
