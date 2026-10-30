// Faz 31 tasarım görüntüleri — PDF düzenleme deneyimi:
//
//   flutter test tool/design_shots_faz31_test.dart
//
// → docs/design/faz31/*.png. pdfium flutter_test'te çalışmadığı için sayfa
// burada elle çizilmiş bir "kâğıt"tır; üstündeki katmanlar (yerinde paragraf,
// bekleyen yazı/imza + dört köşe tutamağı, sayfa üstünde form) ve alttaki
// şerit / klavye üstü çubuk GERÇEK bileşenlerdir. Normal takımda KOŞMAZ.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/edit/editor_chrome.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_form.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_pending_objects.dart';
import 'package:dosya_okuyucu/widgets/office_ribbon.dart';
import 'package:dosya_okuyucu/widgets/pdf_object_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const out = 'docs/design/faz31';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// A4 oranlı sahte sayfa (katman ölçeği 0.6: 595 pt → 357 px).
const double scale = 0.6;

Widget _paper(List<Widget> layers) {
  const ink = TextStyle(fontFamily: 'Carlito', color: Color(0xFF222222));
  Widget line(double top, String text, double size, {bool bold = false}) =>
      Positioned(
        left: 50 * scale,
        top: top * scale,
        child: Text(text,
            style: ink.copyWith(
                fontSize: size * scale,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      );
  return Center(
    child: Container(
      width: 595 * scale,
      height: 842 * scale,
      color: Colors.white,
      child: Stack(clipBehavior: Clip.none, children: [
        line(50, 'Genel Rapor 2026', 20, bold: true),
        line(90, 'Toplam tutar 1500 TL — ödeme 30 gün içinde yapılır.', 12),
        line(108, 'Ek belgeler ilgili birime iletilmiştir.', 12),
        line(400, 'Ad Soyad:', 12),
        line(430, 'Kabul ediyorum', 12),
        ...layers,
      ]),
    ),
  );
}

Future<void> _shot(WidgetTester tester, String name, Widget body,
    {Widget? bottom}) async {
  tester.view.physicalSize = const Size(400, 820) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('rapor.pdf'),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(AppIcons.undo)),
              IconButton(onPressed: () {}, icon: const Icon(AppIcons.redo)),
              IconButton(onPressed: () {}, icon: const Icon(AppIcons.save)),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          body: Column(children: [
            Expanded(child: body),
            if (bottom != null) bottom,
          ]),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('$out/$name.png').writeAsBytesSync(bytes!);
}

Widget _ribbon(BuildContext c, int tab, List<Widget> items) => OfficeRibbon(
      compact: true,
      selectedTab: tab,
      tabs: [
        for (final (i, k) in const [
          'pe.mode_text',
          'pe.mode_image',
          'pe.mode_sign',
          'pe.mode_form',
          'pe.mode_watermark',
          'pe.mode_page'
        ].indexed)
          RibbonTab(c.t(k), i == tab ? items : const []),
      ],
    );

void main() {
  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    Directory(out).createSync(recursive: true);
  });

  testWidgets('yerinde paragraf + ret + Üstüne yaz', (t) async {
    final ctrl = TextEditingController(text: 'Genel Rapor 2026 — Жж');
    await _shot(
      t,
      'yerinde_paragraf',
      _paper([
        PdfInlineParagraphEditor(
          rect: const Rect.fromLTWH(50 * scale, 50 * scale, 170 * scale, 24 * scale),
          controller: ctrl,
          pointSize: 20 * scale,
          refused: true,
        ),
      ]),
      bottom: Builder(
        builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
          Material(
            color: Theme.of(c).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
              child: Row(children: [
                const Icon(AppIcons.info, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text(
                        "Yazı tipinde 'Ж' harfi yok; yeniden dizmek glif bozardı.")),
                TextButton(onPressed: () {}, child: Text(c.t('pe.overwrite'))),
              ]),
            ),
          ),
          KeyboardAccessoryBar(onHideKeyboard: () {}, items: [
            AccessoryItem(icon: AppIcons.check, tooltip: 'ok', onPressed: () {}),
            AccessoryItem(icon: AppIcons.close, tooltip: 'x', onPressed: () {}),
            AccessoryItem(
                icon: AppIcons.textDecrease, tooltip: '-', onPressed: () {}),
            AccessoryItem(
                icon: AppIcons.textIncrease, tooltip: '+', onPressed: () {}),
            AccessoryItem(
                text: c.t('pe.overwrite'), tooltip: 'o', onPressed: () {}),
          ]),
        ]),
      ),
    );
  });

  testWidgets('bekleyen yazı + imza (dört köşe)', (t) async {
    const text = PdfPendingObject(
        id: 1,
        kind: PdfPendingKind.text,
        pageIndex: 0,
        box: Rect.fromLTWH(60, 160, 180, 18),
        text: 'Onaylandı — 30.10.2026',
        fontSize: 13,
        bold: true,
        colorArgb: 0xFF185ABD);
    const sig = PdfPendingObject(
        id: 2,
        kind: PdfPendingKind.signature,
        pageIndex: 0,
        box: Rect.fromLTWH(330, 520, 180, 60),
        strokes: [
          [Offset(0, .8), Offset(.15, .1), Offset(.3, .9), Offset(.45, .2), Offset(.6, .8), Offset(1, .3)],
        ]);
    await _shot(
      t,
      'nesneler_imza',
      _paper([
        PdfPendingObjectLayer(
          objects: const [text, sig],
          scale: scale,
          selectedId: 2,
          onSelect: (_) {},
          onChanged: (_) {},
          onEdit: (_) {},
        ),
      ]),
      bottom: Builder(
          builder: (c) => _ribbon(c, 2, [
                RibbonChip(
                    icon: AppIcons.gesture,
                    label: c.t('pe.add_signature'),
                    tooltip: '',
                    onTap: () {}),
                RibbonChip(
                    icon: AppIcons.shortText,
                    label: c.t('pe.add_initials'),
                    tooltip: '',
                    onTap: () {}),
                RibbonChip(
                    icon: AppIcons.draw,
                    label: c.t('pe.redraw_signature'),
                    tooltip: '',
                    onTap: () {}),
              ])),
    );
  });

  testWidgets('sayfa üstünde form', (t) async {
    final ctrl = TextEditingController(text: 'Ayşe Yılmaz');
    await _shot(
      t,
      'form_sayfada',
      _paper([
        PdfFormOverlay(
          fields: const [
            PdfFormFieldInfo(
                name: 'Ad',
                kind: PdfFormFieldKind.text,
                value: '',
                page: 1,
                bounds: Rect.fromLTWH(120, 396, 250, 20)),
            PdfFormFieldInfo(
                name: 'Onay',
                kind: PdfFormFieldKind.checkbox,
                value: 'false',
                page: 1,
                bounds: Rect.fromLTWH(150, 428, 16, 16)),
          ],
          scale: scale,
          values: const {'Onay': 'true'},
          activeName: 'Ad',
          activeController: ctrl,
          onTapField: (_) {},
        ),
      ]),
      bottom: Builder(
        builder: (c) => KeyboardAccessoryBar(onHideKeyboard: () {}, items: [
          AccessoryItem(
              icon: AppIcons.keyboardArrowLeft, tooltip: '', onPressed: () {}),
          AccessoryItem(
              icon: AppIcons.keyboardArrowRight, tooltip: '', onPressed: () {}),
          AccessoryItem(icon: AppIcons.check, tooltip: '', onPressed: () {}),
        ]),
      ),
    );
  });
}
