import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/editors/slides_editor_screen.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:dosya_okuyucu/widgets/slide_box_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/temp_dir.dart';

/// Faz 28 — slaytta seç/düzenle, kutuya yakınlaşma, zengin biçim, boş yer
/// tutucu, geri al, anahat, konuşmacı notu (widget düzeyi).
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// İki slayt; ikincisinin gövde yer tutucusunun metin gövdesi YOK (boş).
Uint8List _deck() {
  final raw = PptxWriter.build(const [
    SlideDraft('Proje Özeti', ['Birinci madde', 'İkinci madde']),
    SlideDraft('Boş slayt', ['silinecek']),
  ]);
  final arc = ZipDecoder().decodeBytes(raw);
  final out = Archive();
  for (final f in arc.files) {
    if (f.name == 'ppt/slides/slide2.xml') {
      final doc = XmlDocument.parse(utf8.decode(f.content as List<int>));
      for (final sp in doc.findAllElements('p:sp').toList()) {
        if (sp.findAllElements('p:ph').first.getAttribute('type') == 'body') {
          sp.children.remove(sp.findElements('p:txBody').first);
        }
      }
      final data = utf8.encode(doc.toXmlString());
      out.addFile(ArchiveFile(f.name, data.length, data));
    } else {
      out.addFile(f);
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    SlidesEditorScreen.parseInIsolate = false;
    dir = await Directory.systemTemp.createTemp('slides_edit');
    path = '${dir.path}/deste.pptx';
    await File(path).writeAsBytes(_deck());
  });

  tearDown(() {
    SlidesEditorScreen.parseInIsolate = true;
    removeTempDir(dir);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: _delegates,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      home: SlidesEditorScreen(
          path: path, name: 'deste.pptx', plainText: 'Proje Özeti'),
    ));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
  }

  /// Kanvastaki bir metne dokunur (yazının ortası).
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openEditor(WidgetTester tester, String text) async {
    await tapText(tester, text); // seç
    expect(find.text('Metni düzenle'), findsOneWidget);
    await tapText(tester, text); // düzenle
    await tester.pump(const Duration(milliseconds: 400)); // yakınlaşma
    await tester.pump();
    expect(find.byKey(const ValueKey('slide-focus-editor')), findsOneWidget);
    expect(find.byType(SlideBoxEditor), findsOneWidget);
  }

  testWidgets('dokun = seç (bağlam çubuğu), ikinci dokunuş = kutuya yakınlaşıp '
      'düzenle; yazı ≥ 16 dp', (tester) async {
    await pump(tester);
    await openEditor(tester, 'Birinci madde');
    final k = SlidesEditorScreen.lastFocusScale!;
    // Gövde puntosu 20: yakınlaşmada en az 16 dp.
    final field = tester.widget<EditableText>(find.byType(EditableText).last);
    final span = field.controller.buildTextSpan(
        context: tester.element(find.byType(EditableText).last),
        withComposing: false);
    final size = span.children!.first.style!.fontSize!;
    expect(size * k, greaterThanOrEqualTo(16));
  });

  testWidgets('yaz → Bitti → slayt güncellenir; geri al eski metni getirir',
      (tester) async {
    await pump(tester);
    await openEditor(tester, 'Proje Özeti');
    final field = find.byType(EditableText).last;
    await tester.enterText(field, 'Yeni Başlık');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sl-done')));
    await settle(tester);
    expect(find.text('Yeni Başlık'), findsWidgets);
    expect(find.text('Proje Özeti'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sl-undo')));
    await settle(tester);
    expect(find.text('Proje Özeti'), findsWidgets);
  });

  testWidgets('düzenlerken başka kutuya dokunmak onu açar (önceki yazılır)',
      (tester) async {
    await pump(tester);
    await openEditor(tester, 'Proje Özeti');
    await tester.enterText(find.byType(EditableText).last, 'Özet 2026');
    await tester.pump();
    // Odak görünümünde gövde kutusu da çizili: dokununca o düzenlenir.
    await tester.tap(find.text('Birinci madde').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(SlideBoxEditor), findsOneWidget);
    final ed = tester.widget<EditableText>(find.byType(EditableText).last);
    expect(ed.controller.text, startsWith('Birinci madde'));
    await tester.tap(find.byKey(const ValueKey('sl-done')));
    await settle(tester);
    expect(find.text('Özet 2026'), findsWidgets);
  });

  testWidgets('seçime göre kalın: yalnız seçili kelime kalın yazılır',
      (tester) async {
    await pump(tester);
    await openEditor(tester, 'Birinci madde');
    final editable = tester.widget<EditableText>(find.byType(EditableText).last);
    editable.controller.selection =
        const TextSelection(baseOffset: 0, extentOffset: 7); // "Birinci"
    await tester.pump();
    await tester.tap(find.byTooltip('Kalın').first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sl-done')));
    await settle(tester);
    // Slayt yeniden çizildi: "Birinci" kalın, " madde" normal ayrı run.
    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((w) => w.text.toPlainText() == 'Birinci madde');
    final spans = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && (span.text ?? '').isNotEmpty) spans.add(span);
      return true;
    });
    expect(spans.first.text, 'Birinci');
    expect(spans.first.style!.fontWeight, FontWeight.bold);
    expect(spans.last.style!.fontWeight, isNot(FontWeight.bold));
  });

  testWidgets('boş yer tutucu istemi görünür; dokununca yazılır', (tester) async {
    await pump(tester);
    final prompt = find.text('Metin eklemek için dokunun');
    await tester.scrollUntilVisible(prompt, 300,
        scrollable: find
            .byWidgetPredicate((w) =>
                w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    expect(prompt, findsOneWidget);
    await tester.tap(prompt, warnIfMissed: false); // seç
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(prompt, warnIfMissed: false); // düzenle
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400)); // yakınlaşma
    await tester.pump();
    await tester.enterText(find.byType(EditableText).last, 'Taze içerik');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sl-done')));
    await settle(tester);
    expect(find.text('Taze içerik'), findsWidgets);
    expect(find.text('Metin eklemek için dokunun'), findsNothing);
  });

  testWidgets('anahat: paragraf orada düzeltilir, slayta yansır', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('sl-outline')));
    await settle(tester);
    expect(find.byKey(const ValueKey('slides-outline')), findsOneWidget);
    final field = find.widgetWithText(TextField, 'İkinci madde');
    await tester.enterText(field, 'İkinci madde düzeltildi');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sl-outline')));
    await settle(tester);
    expect(find.text('İkinci madde düzeltildi'), findsWidgets);
  });

  testWidgets('konuşmacı notu slayt menüsünden yazılır, şerit belirir',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Slayt işlemleri').first);
    await settle(tester);
    await tester.tap(find.text('Konuşmacı notu'));
    await settle(tester);
    await tester.enterText(
        find.byKey(const ValueKey('notes-edit')), 'Burada süreyi söyle');
    await tester.tap(find.byKey(const ValueKey('notes-save')));
    await settle(tester);
    expect(find.text('Burada süreyi söyle'), findsOneWidget); // not şeridi
  });
}
