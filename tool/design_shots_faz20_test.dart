// ignore_for_file: invalid_use_of_visible_for_testing_member
// Faz 20 tasarım görüntüleri — ortak düzenleme çekirdeği:
//
//   flutter test tool/design_shots_faz20_test.dart
//   SHOT_LOCALE=ar flutter test tool/design_shots_faz20_test.dart
//
// → docs/design/faz20/*.png (üst çubuğun üç durumu, klavye üstü çubuk, Aa
// paneli, taslak kurtarma şeridi, çıkış sorusu; açık/koyu). Normal test
// takımında KOŞMAZ. Yöntem `tool/design_shots_faz15_test.dart` ile aynı.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/edit/draft_journal.dart';
import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/edit/editor_chrome.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/document.dart';
import 'package:dosya_okuyucu/widgets/office_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

ThemeData _withArabic(ThemeData t) => t.copyWith(
    textTheme:
        t.textTheme.apply(fontFamilyFallback: const ['NotoNaskhArabic']));

const _keyboard = 290.0;

/// Sahte belge: başlık + iki paragraf, imleç ikinci paragrafın sonunda.
class _Doc extends StatelessWidget {
  const _Doc();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ar = context.language.name == 'ar';
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ar ? 'ملخص المشروع' : 'Proje Özeti',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
              ar
                  ? 'يعرض هذا التقرير الأعمال المنجزة في النصف الأول من عام 2026.'
                  : 'Bu raporda 2026 yılının ilk yarısında yapılan çalışmalar '
                      'özetlenmektedir.',
              style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 8),
          Row(children: [
            Text(ar ? '• قياسات ميدانية' : '• Saha ölçümleri',
                style: const TextStyle(fontSize: 16, height: 1.5)),
            Container(width: 2, height: 20, color: scheme.primary),
          ]),
        ],
      ),
    );
  }
}

/// Klavyenin yerini tutan gri kutu (görüntüde klavyenin nerede olduğu belli
/// olsun diye).
class _FakeKeyboard extends StatelessWidget {
  const _FakeKeyboard();
  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Container(
        height: _keyboard,
        alignment: Alignment.center,
        child: Text('[ Android klavyesi ]',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      ));
}

List<AccessoryItem> _items(BuildContext context) => const [
      AccessoryItem(icon: Icons.undo_rounded, tooltip: 'Geri al'),
      AccessoryItem(icon: Icons.format_bold, tooltip: 'Kalın', selected: true),
      AccessoryItem(icon: Icons.format_italic, tooltip: 'İtalik'),
      AccessoryItem(icon: Icons.format_underline, tooltip: 'Altı çizili'),
      AccessoryItem(icon: Icons.format_list_bulleted, tooltip: 'Madde'),
      AccessoryItem(icon: Icons.format_list_numbered, tooltip: 'Numara'),
      AccessoryItem(icon: Icons.format_indent_increase, tooltip: 'Girinti'),
      AccessoryItem(icon: Icons.format_align_left, tooltip: 'Hizala'),
      AccessoryItem(icon: Icons.format_color_text, tooltip: 'Renk'),
    ];

void main() {
  final out = 'docs/design/faz20';
  final locale = Locale(Platform.environment['SHOT_LOCALE'] ?? 'tr');
  final suffixLocale = locale.languageCode == 'tr' ? '' : '_${locale.languageCode}';

  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flt/flutter';
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('NotoNaskhArabic', [
      '$sdk/engine/src/flutter/txt/third_party/fonts/NotoNaskhArabic-Regular.ttf'
    ]);
    Directory(out).createSync(recursive: true);
  });

  Future<void> shot(WidgetTester tester, String name,
      Widget Function(BuildContext) screen,
      {Brightness brightness = Brightness.light,
      double keyboard = 0,
      Future<void> Function(WidgetTester)? after}) async {
    const size = Size(400, 820);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _withArabic(brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark()),
        locale: locale,
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: Builder(builder: (context) {
          if (keyboard == 0) return screen(context);
          return Stack(children: [
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  viewInsets: const EdgeInsets.only(bottom: _keyboard)),
              child: screen(context),
            ),
            const Positioned(
                left: 0, right: 0, bottom: 0, child: _FakeKeyboard()),
          ]);
        }),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    if (after != null) await after(tester);
    await tester.pump(const Duration(seconds: 1));
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    final suffix = brightness == Brightness.light ? 'acik' : 'koyu';
    File('$out/$name${suffixLocale}_$suffix.png').writeAsBytesSync(bytes!);
  }

  Widget shell(BuildContext context, {required Widget body, String? status, bool dirty = false}) =>
      Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: DocTitle(
              kind: DocKind.word,
              title: 'Rapor.docx',
              dirty: dirty,
              status: status),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.undo_rounded)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.redo_rounded)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
          ],
        ),
        body: body,
      );

  for (final b in Brightness.values) {
    testWidgets('üst çubuk durumları $b', (t) => shot(t, 'ust_cubuk', (context) {
          final s = AppStrings.of(context);
          Widget bar(String? status, bool dirty) => Material(
                child: SizedBox(
                  height: 64,
                  child: Row(children: [
                    const SizedBox(width: 12),
                    Expanded(
                        child: DocTitle(
                            kind: DocKind.word,
                            title: 'Rapor.docx',
                            dirty: dirty,
                            status: status)),
                    const Icon(Icons.undo_rounded),
                    const SizedBox(width: 12),
                    const Icon(Icons.redo_rounded),
                    const SizedBox(width: 12),
                  ]),
                ),
              );
          return Scaffold(
            body: SafeArea(
              child: Column(children: [
                bar(null, false),
                const Divider(),
                bar(s.t('edit.saving'), false),
                const Divider(),
                bar(s.t('shell.unsaved'), true),
                const Divider(),
                bar(s.t('edit.saved_at', {'time': '14:32'}), false),
                const Divider(),
                bar(s.t('edit.changed_elsewhere'), true),
              ]),
            ),
          );
        }, brightness: b));

    testWidgets('klavye üstü çubuk $b', (t) => shot(t, 'klavye_cubugu', (context) {
          return shell(context,
              status: AppStrings.of(context).t('edit.saved_at', {'time': '14:32'}),
              body: EditorChrome(
                keyboardInsetOverride: _keyboard,
                body: const _Doc(),
                accessory: KeyboardAccessoryBar(
                    items: _items(context), onFormat: () {}, onHideKeyboard: () {}),
              ));
        }, brightness: b, keyboard: _keyboard));

    testWidgets('Aa paneli $b', (t) {
      final panel = FormatPanelController()..reportKeyboard(_keyboard);
      return shot(t, 'aa_paneli', (context) {
        final s = AppStrings.of(context);
        return shell(context,
            dirty: true,
            body: EditorChrome(
              keyboardInsetOverride: 0,
              panel: panel,
              body: const _Doc(),
              accessory: KeyboardAccessoryBar(
                  items: _items(context), onFormat: () {}, onHideKeyboard: () {}),
              panelTabs: [
                FormatPanelTab(
                    label: s.t('edit.tab_text'),
                    builder: (_) => Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final i in const [
                            Icons.format_bold,
                            Icons.format_italic,
                            Icons.format_underline,
                            Icons.format_strikethrough,
                            Icons.superscript,
                            Icons.subscript,
                          ])
                            IconButton.filledTonal(onPressed: () {}, icon: Icon(i)),
                          for (final c in const [
                            Colors.black,
                            Colors.red,
                            Colors.blue,
                            Colors.green,
                            Colors.purple,
                            Colors.orange,
                          ])
                            CircleAvatar(radius: 16, backgroundColor: c),
                        ])),
                FormatPanelTab(label: s.t('edit.tab_paragraph'), builder: (_) => const SizedBox()),
                FormatPanelTab(label: s.t('edit.tab_styles'), builder: (_) => const SizedBox()),
              ],
            ));
      }, brightness: b, after: (t) async => panel.open());
    });

    testWidgets('taslak şeridi $b', (t) => shot(t, 'taslak_seridi', (context) {
          return shell(context,
              dirty: true,
              body: Column(children: [
                DraftRecoveryBanner(
                  draft: DraftInfo('/x', 'word', DateTime(2026, 10, 23, 14, 5), '/x.bin'),
                  onRestore: () {},
                  onDiscard: () {},
                ),
                const Expanded(child: _Doc()),
              ]));
        }, brightness: b));

    testWidgets('çıkış sorusu $b', (t) => shot(t, 'cikis_sorusu', (context) {
          return shell(context, dirty: true, body: const _Doc());
        }, brightness: b, after: (t) async {
          final ctx = t.element(find.byType(_Doc));
          showUnsavedChanges(ctx);
          await t.pump(const Duration(milliseconds: 400));
        }));
  }
}
