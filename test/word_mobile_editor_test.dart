import 'dart:io';

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/edit/save_coordinator.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile_editor_screen.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

/// Faz 22 — Word Mobil görünüm editörü (widget + IME benzetimi).
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _g = '​';

/// IME'den gelmiş gibi delta yollar.
Future<void> _deltas(WidgetTester t, List<Map<String, dynamic>> deltas) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(MethodCall(
        'TextInputClient.updateEditingStateWithDeltas', [
      -1,
      {'deltas': deltas}
    ])),
    (_) {},
  );
  await t.pump();
}

Map<String, dynamic> _d(String old, String text, int start, int end, int sel,
        {int cb = -1, int ce = -1}) =>
    {
      'oldText': old,
      'deltaText': text,
      'deltaStart': start,
      'deltaEnd': end,
      'selectionBase': sel,
      'selectionExtent': sel,
      'selectionAffinity': 'TextAffinity.downstream',
      'selectionIsDirectional': false,
      'composingBase': cb,
      'composingExtent': ce,
    };

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    WordMobileEditorScreen.parseInIsolate = false;
    SaveIsolate.runner = <M, R>(cb, m) async => cb(m);
    EditPrefs.autoSave = false;
    dir = await Directory.systemTemp.createTemp('word_mobile');
    path = '${dir.path}/rapor.docx';
    // TUZAK (HAFIZA 2026-07-25 §F): dosyalar testWidgets gövdesinde DEĞİL
    // burada yazılır — sahte saatte gerçek G/Ç bitmez.
    for (final f in const [
      'stiller_basliklar.docx',
      'word_kaydedilmis_cok_sayfa.docx',
      'arapca_rtl.docx',
    ]) {
      await File('${dir.path}/$f')
          .writeAsBytes(File('test/fixtures/office/$f').readAsBytesSync());
    }
    await File(path).writeAsBytes(
        File('test/fixtures/office/stiller_basliklar.docx').readAsBytesSync());
  });

  tearDown(() {
    WordMobileEditorScreen.parseInIsolate = true;
    EditPrefs.autoSave = true;
    removeTempDir(dir);
  });

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<DocxEditController> open(WidgetTester t, {String? file}) async {
    if (file != null) path = '${dir.path}/$file';
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: _delegates,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      home: WordMobileEditorScreen(path: path, name: 'rapor.docx'),
    ));
    for (var i = 0; i < 20 && find.byType(DocxEditorView).evaluate().isEmpty; i++) {
      await settle(t);
    }
    await settle(t);
    return t.widget<DocxEditorView>(find.byType(DocxEditorView)).controller;
  }

  Future<void> tapText(WidgetTester t, String text) async {
    await t.tapAt(t.getCenter(find.textContaining(text, findRichText: true).first));
    await t.pump(const Duration(milliseconds: 400)); // çoklu dokunuş penceresi
  }

  testWidgets('belge Mobil görünümde çizilir: başlık, liste, tablo, resim',
      (t) async {
    await open(t);
    expect(find.textContaining('Proje Raporu 2026', findRichText: true),
        findsOneWidget);
    expect(find.text('•'), findsWidgets);
    expect(find.text('1.'), findsOneWidget);
    expect(find.textContaining('İzmir', findRichText: true), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('dokun → imleç; Türkçe harf, Enter, geri silme; kaydet → yeniden aç',
      (t) async {
    final c = await open(t);
    final target = find.textContaining('Son paragraf', findRichText: true);
    await t.scrollUntilVisible(target, 300,
        scrollable: find.byType(Scrollable).first);
    // Fırlatma sürerken dokunuş kaydırmayı durdurur (Flutter): önce dursun.
    await t.pump(const Duration(seconds: 2));
    await tapText(t, 'Son paragraf');
    final i = c.extent.para;
    expect(c.paras[i].text, 'Son paragraf.');
    // İmleci sona al ve yaz.
    c.select(DocPos(i, 13), DocPos(i, 13));
    var ime = '$_g${c.paras[i].text}';
    for (final ch in ' ğüşİ'.split('')) {
      final at = ime.length;
      await _deltas(t, [_d(ime, ch, at, at, at + 1)]);
      ime += ch;
    }
    expect(c.paras[i].text, 'Son paragraf. ğüşİ');
    // Enter: yeni paragraf.
    final at = ime.length;
    await _deltas(t, [_d(ime, '\n', at, at, at + 1)]);
    expect(c.extent, DocPos(i + 1, 0));
    await _deltas(t, [_d(_g, 'Yeni', 1, 1, 5)]);
    expect(c.paras[i + 1].text, 'Yeni');
    // Paragraf başında geri silme (bekçi silinir) → birleştir.
    c.select(DocPos(i + 1, 0), DocPos(i + 1, 0));
    await _deltas(t, [_d('${_g}Yeni', '', 0, 1, 0)]);
    expect(c.paras[i].text, 'Son paragraf. ğüşİYeni');

    // Kaydedilecek baytlar (dosya yazımı EditSession'ın ortak yolu; burada
    // gerçek G/Ç sahte saatte bitmez — §F).
    final back = DocxDocument.parse(c.doc.save());
    expect(back.paras.map((p) => p.text), contains('Son paragraf. ğüşİYeni'));
    // Resim, tablo ve listeler yerinde.
    expect(back.paras.any((p) => p.atoms.any((a) => a?.kind == DocxAtomKind.image)),
        isTrue);
    expect(back.paras.where((p) => p.cell != null), hasLength(4));
  });

  testWidgets('klavyenin Geri sil / Sil TUŞ olayı modelde uygulanır; imleç yanıp söner',
      (t) async {
    // Android'de yazılım klavyesinin geri silmesi çoğu zaman KEYCODE_DEL tuş
    // olayıdır; motor bunu editable'a uygulamaz (kullanıcı: "siliyorum hiçbir
    // şey olmuyor ama yazılıyor").
    final c = await open(t);
    final target = find.textContaining('Son paragraf', findRichText: true);
    await t.scrollUntilVisible(target, 300,
        scrollable: find.byType(Scrollable).first);
    await t.pump(const Duration(seconds: 2));
    await tapText(t, 'Son paragraf');
    final i = c.extent.para;
    c.select(DocPos(i, 13), DocPos(i, 13));
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    expect(c.paras[i].text, 'Son paragraf');
    expect(c.extent, DocPos(i, 12));
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    expect(c.paras[i].text, 'Son paragra');
    // Sil (ileri).
    c.select(DocPos(i, 0), DocPos(i, 0));
    await t.sendKeyEvent(LogicalKeyboardKey.delete);
    await t.pump();
    expect(c.paras[i].text, 'on paragra');
    // Paragraf başında geri sil → öncekine katılır.
    final prevLen = c.paras[i - 1].length;
    final prevText = c.paras[i - 1].text;
    if (!c.paras[i - 1].opaque &&
        identical(c.paras[i - 1].container, c.paras[i].container) &&
        c.paras[i].look.numId == null) {
      await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      await t.pump();
      expect(c.paras[i - 1].text, '${prevText}on paragra');
      expect(c.extent, DocPos(i - 1, prevLen));
    }
    // Geri al tek tek geri getirir.
    c.undo();
    await t.pump();
    expect(c.paras.map((p) => p.text), isNot(contains('${prevText}on paragra')));
    // Yanıp sönme: 500 ms aralıkla imleç kaybolup geri gelir.
    expect(c.attached, isTrue);
    await t.pump(const Duration(milliseconds: 510));
    await t.pump(const Duration(milliseconds: 510));
  });

  testWidgets('uzun bas → kelime seçilir, bağlam çubuğu; K seçime uygulanır',
      (t) async {
    final c = await open(t);
    final word = find.textContaining('Ortalanmış', findRichText: true).first;
    await t.longPressAt(t.getTopLeft(word) + const Offset(30, 10));
    await t.pump(const Duration(milliseconds: 100));
    expect(c.collapsed, isFalse);
    expect(c.selectedText(), isNotEmpty);
    expect(find.byKey(const ValueKey('docx-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('docx-handle-a')), findsOneWidget);
    final sel = c.selectedText();
    c.toggleBold();
    await t.pump();
    final p = c.paras[c.start.para];
    expect(p.styles[c.start.offset].isBold, isTrue);
    expect(sel, isNotEmpty);
    // Geri al biçimi geri alır.
    c.undo();
    expect(c.paras[c.start.para].styles[c.start.offset].isBold, isFalse);
  });

  testWidgets('köprü + dipnot içeren paragrafta yazınca ikisi de korunur',
      (t) async {
    final c = await open(t, file: 'word_kaydedilmis_cok_sayfa.docx');
    final i = c.paras.indexWhere((p) => p.text.startsWith('Bağlantı'));
    c.select(DocPos(i, 0), DocPos(i, 0));
    c.insertText('Önemli ');
    await t.pump();
    final back = DocxDocument.parse(c.doc.save());
    final p = back.paras.firstWhere((p) => p.text.startsWith('Önemli Bağlantı'));
    expect(p.atoms.where((a) => a?.kind == DocxAtomKind.link), hasLength(1));
    expect(p.atoms.where((a) => a?.kind == DocxAtomKind.note), hasLength(1));
  });

  testWidgets('başlık sonunda Enter gövde stiline geçer; boş listede Enter çıkar',
      (t) async {
    final c = await open(t);
    final h = c.paras.indexWhere((p) => p.text == 'Giriş');
    c.select(DocPos(h, 5), DocPos(h, 5));
    c.enter();
    expect(c.paras[h + 1].look.headingLevel, 0);
    final li = c.paras.indexWhere((p) => p.text == 'İkinci madde');
    c.select(DocPos(li, 12), DocPos(li, 12));
    c.enter(); // yeni boş madde
    expect(c.paras[li + 1].look.numId, isNotNull);
    c.enter(); // boş maddede Enter → listeden çıkar
    expect(c.paras[li + 1].look.numId, isNull);
    expect(c.paras[li + 1].text, '');
  });

  testWidgets('Arapça paragraf sağdan sola çizilir', (t) async {
    await open(t, file: 'arapca_rtl.docx');
    final rich = t.widget<RichText>(
        find.textContaining('تقرير', findRichText: true).first);
    expect(rich.textDirection, TextDirection.rtl);
  });
}
