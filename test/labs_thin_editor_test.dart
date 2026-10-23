import 'package:dosya_okuyucu/labs/word_editor/thin_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 21b / K18 — ince çekirdeğin (b-ii) klavye benzetimi: Türkçe harf,
/// birleştirme bölgesi, otomatik düzeltme değiştirmesi, Enter, paragraf
/// başında geri silme, paragraflar arası seç-sil, yapıştır, K/T/A. Ayrıca
/// 1000 paragraflık belgede açılış ve yazma süresi (super_editor ile aynı
/// görev — sonuç HAFIZA'da).

/// IME'den gelmiş gibi delta yollar (istemci -1: testlerde doğrulama atlanır).
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

const g = '​';

Future<ThinEditorController> _open(WidgetTester t, List<String> texts) async {
  final c = ThinEditorController(texts);
  addTearDown(c.dispose);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: ThinEditor(controller: c))));
  c.select(const ThinPos(0, 0), const ThinPos(0, 0));
  c.attach();
  await t.pump();
  return c;
}

void main() {
  testWidgets('Türkçe harfler birleştirme bölgesiyle yazılır, düzeltme değiştirir',
      (t) async {
    final c = await _open(t, ['']);
    var ime = g;
    for (final ch in 'ğüşıöçİ'.split('')) {
      final at = ime.length;
      await _deltas(t, [_d(ime, ch, at, at, at + 1, cb: 1, ce: at + 1)]);
      ime += ch;
    }
    expect(c.paras[0].text, 'ğüşıöçİ');
    expect(c.composing, const TextRange(start: 0, end: 7));
    // Otomatik düzeltme: "teh" → "the"
    c.insertText(' teh');
    ime = '$g${c.paras[0].text}';
    final at = ime.length;
    await _deltas(t, [_d(ime, 'the', at - 3, at, at)]);
    expect(c.paras[0].text, 'ğüşıöçİ the');
  });

  testWidgets('Enter böler, paragraf başında geri silme birleştirir', (t) async {
    final c = await _open(t, ['Merhaba dünya']);
    c.select(const ThinPos(0, 7), const ThinPos(0, 7));
    await _deltas(t, [_d('${g}Merhaba dünya', '\n', 8, 8, 9)]);
    expect(c.paras.map((p) => p.text), ['Merhaba', ' dünya']);
    expect(c.extent, const ThinPos(1, 0));
    // IME'de imleç bekçiden hemen sonra: geri silme bekçiyi siler.
    await _deltas(t, [_d('$g dünya', '', 0, 1, 0)]);
    expect(c.paras.map((p) => p.text), ['Merhaba dünya']);
    expect(c.extent, const ThinPos(0, 7));
  });

  testWidgets('klavyenin "yeni satır" eylemi de böler', (t) async {
    final c = await _open(t, ['ab']);
    c.select(const ThinPos(0, 1), const ThinPos(0, 1));
    await t.testTextInput.receiveAction(TextInputAction.newline);
    expect(c.paras.map((p) => p.text), ['a', 'b']);
  });

  testWidgets('paragraflar arası seçim silinir; yapıştırma satırlara bölünür',
      (t) async {
    final c = await _open(t, ['bir iki', 'üç', 'dört beş']);
    c.select(const ThinPos(0, 4), const ThinPos(2, 5));
    expect(c.selectedText(), 'iki\nüç\ndört ');
    await _deltas(t, [_d('${g}bir iki', 'X', 5, 8, 6)]);
    expect(c.paras.map((p) => p.text), ['bir beş']);
    c.select(const ThinPos(0, 4), const ThinPos(0, 4));
    c.insertText('a\nb\nc ');
    expect(c.paras.map((p) => p.text), ['bir a', 'b', 'c beş']);
  });

  testWidgets('K/T/A seçime ve yazma biçimine uygulanır', (t) async {
    final c = await _open(t, ['kalın yap']);
    c.select(const ThinPos(0, 0), const ThinPos(0, 5));
    c.toggle(ThinStyle.bold);
    expect(c.paras[0].styles.take(6), [1, 1, 1, 1, 1, 0]);
    c.toggle(ThinStyle.bold);
    expect(c.paras[0].styles.every((s) => s == 0), isTrue);
    c.select(const ThinPos(0, 9), const ThinPos(0, 9));
    c.toggle(ThinStyle.italic);
    c.insertText('!');
    expect(c.paras[0].styles.last, ThinStyle.italic);
  });

  testWidgets('dokunmak imleci koyar, çift dokunmak kelimeyi seçer', (t) async {
    final c = await _open(t, ['merhaba güzel dünya']);
    final rich = find.byType(RichText).first;
    final r = t.getRect(rich);
    await t.tapAt(Offset(r.left + 2, r.center.dy));
    await t.pump(const Duration(milliseconds: 400));
    expect(c.extent.para, 0);
    expect(c.extent.offset, lessThan(3));
  });

  testWidgets('ölçüm: 1000 paragraf açılış + yazma', (t) async {
    final texts = [
      for (var i = 0; i < 1000; i++)
        'Paragraf $i: Türkçe ğüşıöçİ metin, uzun bir cümle.',
    ];
    final sw = Stopwatch()..start();
    final c = await _open(t, texts);
    sw.stop();
    var ime = '$g${texts[0]}';
    c.select(const ThinPos(0, 0), const ThinPos(0, 0));
    final sw2 = Stopwatch()..start();
    var at = 1;
    for (final ch in 'ğüşıöçİ '.split('')) {
      await _deltas(t, [_d(ime, ch, at, at, at + 1)]);
      ime = ime.substring(0, at) + ch + ime.substring(at);
      at++;
    }
    sw2.stop();
    expect(c.paras[0].text, startsWith('ğüşıöçİ Paragraf 0'));
    // ignore: avoid_print
    print('THIN ACILIS_MS ${sw.elapsedMilliseconds} YAZMA_MS ${sw2.elapsedMilliseconds}');
  });
}
