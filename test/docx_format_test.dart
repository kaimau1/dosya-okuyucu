import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 23 — Word biçimlendirme: her düğme gidiş-dönüş testli (uygula →
/// kaydet → aç → aynı), stil uygulanınca doğrudan biçim yazılmaz, listeler
/// `numbering.xml`'i (yoksa yaratarak) doğru kurar.
const _dir = 'test/fixtures/office';

Uint8List _read(String name) => File('$_dir/$name').readAsBytesSync();

String _part(Uint8List bytes, String name) => utf8.decode(ZipDecoder()
    .decodeBytes(bytes)
    .files
    .firstWhere((f) => f.name == name)
    .content as List<int>);

bool _hasPart(Uint8List bytes, String name) =>
    ZipDecoder().decodeBytes(bytes).files.any((f) => f.name == name);

/// [startsWith] ile başlayan paragrafın `w:p` XML'i.
String _paraXml(Uint8List bytes, String startsWith) {
  for (final p in XmlDocument.parse(_part(bytes, 'word/document.xml'))
      .findAllElements('w:p')) {
    final t = p.findAllElements('w:t').map((e) => e.innerText).join();
    if (t.startsWith(startsWith)) return p.toXmlString();
  }
  throw StateError('paragraf yok: $startsWith');
}

int _find(DocxDocument d, String startsWith) =>
    d.paras.indexWhere((p) => p.text.startsWith(startsWith));

/// Paragrafın [word] kelimesini seçili bir denetleyici.
DocxEditController _select(DocxDocument d, String para, String word) {
  final c = DocxEditController(d);
  final i = _find(d, para);
  final k = d.paras[i].text.indexOf(word);
  c.select(DocPos(i, k), DocPos(i, k + word.length));
  return c;
}

DocxDocument _roundTrip(DocxDocument d) => DocxDocument.parse(d.save());

void main() {
  test('yazı biçimi: üstü çizili, renk, vurgu, punto, yazı tipi, üst simge', () {
    final d = DocxDocument.parse(_read('word_kaydedilmis_cok_sayfa.docx'));
    final c = _select(d, 'Giriş', 'paragrafı');
    c.toggleStrike();
    c.setColor(0xFFC00000);
    c.setHighlight('yellow');
    c.setFontSize(16);
    c.setFont('Georgia');
    expect(c.isStrike, isTrue);
    expect(c.fontSize, 16);
    expect(c.fontName, 'Georgia');
    expect(c.recentColors.first, 0xFFC00000);

    final back = _roundTrip(d);
    final p = back.paras[_find(back, 'Giriş')];
    final k = p.text.indexOf('paragrafı');
    final look = p.styles[k].effective;
    expect(look.strike, isTrue);
    expect(look.color, 0xFFC00000);
    expect(look.highlight, 0xFFFFFF00);
    expect(look.sizePt, 16);
    expect(look.font, 'Georgia');
    // Seçim dışındaki harf dokunulmadı.
    expect(p.styles[0].effective.strike, isFalse);
    expect(p.styles[0].effective.sizePt, isNot(16));

    final x = _paraXml(back.save(), 'Giriş');
    expect(x, contains('<w:strike/>'));
    expect(x, contains('<w:color w:val="C00000"/>'));
    expect(x, contains('<w:highlight w:val="yellow"/>'));
    expect(x, contains('<w:sz w:val="32"/>'));
  });

  test('üst / alt simge birbirini kapatır; vurgu kaldırılınca yazılmaz', () {
    final d = DocxDocument.parse(_read('word_kaydedilmis_cok_sayfa.docx'));
    final c = _select(d, 'Giriş', 'Giriş');
    c.toggleSuperscript();
    expect(c.isSuperscript, isTrue);
    c.toggleSubscript();
    expect(c.isSuperscript, isFalse);
    expect(c.isSubscript, isTrue);
    c.setHighlight('green');
    c.setHighlight('');
    final x = _paraXml(d.save(), 'Giriş');
    expect(x, contains('<w:vertAlign w:val="subscript"/>'));
    expect(x, isNot(contains('w:highlight')));
  });

  test('karışık seçimde punto "—" (null)', () {
    final d = DocxDocument.parse(_read('word_kaydedilmis_cok_sayfa.docx'));
    final c = _select(d, 'Giriş', 'Giriş');
    c.setFontSize(20);
    final i = _find(d, 'Giriş');
    c.select(DocPos(i, 0), DocPos(i, d.paras[i].length));
    expect(c.fontSize, isNull);
  });

  test('stil uygula: yalnız w:pStyle; sanal yerleşik stil styles.xml\'e eklenir', () {
    final d = DocxDocument.parse(_read('word_kaydedilmis_cok_sayfa.docx'));
    final gallery = d.styles.gallery();
    final h1 = gallery.firstWhere((g) => g.builtin == 'heading 1');
    expect(h1.virtual, isTrue, reason: 'örnekte yalnız Normal tanımlı');
    expect(gallery.map((g) => g.builtin), contains('Quote'));

    final c = _select(d, 'Giriş', 'Giriş');
    c.applyStyle(h1.id);
    expect(c.paraLook.headingLevel, 1);
    expect(c.styleId, h1.id);
    // Stilin harf görünüşü yansıdı (Başlık 1 = 16 pt, tema rengi).
    final i = _find(d, 'Giriş');
    expect(d.paras[i].styles[0].effective.sizePt, 16);

    final bytes = d.save();
    final x = _paraXml(bytes, 'Giriş');
    expect(x, contains('<w:pStyle w:val="${h1.id}"/>'));
    expect(x, isNot(contains('<w:sz')), reason: 'stil biçimi gömülmez');
    expect(x, isNot(contains('<w:color')));
    expect(_part(bytes, 'word/styles.xml'), contains('w:styleId="${h1.id}"'));

    final back = DocxDocument.parse(bytes);
    expect(back.paras[_find(back, 'Giriş')].look.headingLevel, 1);
    expect(back.styles.gallery().firstWhere((g) => g.builtin == 'heading 1').virtual,
        isFalse);
    // Başlıkta Enter → w:next (Normal).
    final c2 = DocxEditController(back);
    final j = _find(back, 'Giriş');
    c2.select(DocPos(j, back.paras[j].length), DocPos(j, back.paras[j].length));
    c2.enter();
    expect(c2.paraLook.headingLevel, 0);
  });

  test('stilden gelen italiği kapatmak w:i w:val="0" yazar', () {
    final d = DocxDocument.parse(_read('word_kaydedilmis_cok_sayfa.docx'));
    final quote = d.styles.gallery().firstWhere((g) => g.builtin == 'Quote');
    final c = _select(d, 'Giriş', 'paragrafı');
    c.applyStyle(quote.id);
    expect(c.isItalic, isTrue, reason: 'Alıntı stili italik');
    c.toggleItalic();
    expect(c.isItalic, isFalse);
    expect(_paraXml(d.save(), 'Giriş'), contains('<w:i w:val="0"/>'));
  });

  test('biçimi temizle: doğrudan biçim kalkar, paragraf stili kalır', () {
    final d = DocxDocument.parse(_read('stiller_basliklar.docx'));
    final i = _find(d, 'Bu belge');
    final c = DocxEditController(d);
    c.select(DocPos(i, 0), DocPos(i, d.paras[i].length));
    expect(d.paras[i].text.contains('kalın'), isTrue);
    c.clearFormatting();
    final k = d.paras[i].text.indexOf('kalın');
    expect(d.paras[i].styles[k].effective.bold, isFalse);
    final x = _paraXml(d.save(), 'Bu belge');
    expect(x, isNot(contains('<w:b/>')));
    expect(x, isNot(contains('C00000')));
  });

  test('hizalama, satır aralığı, boşluk, girinti, sağdan sola', () {
    final d = DocxDocument.parse(_read('word_kaydedilmis_cok_sayfa.docx'));
    final c = _select(d, 'Giriş', 'Giriş');
    c.setAlign('center');
    c.cycleAlign();
    expect(c.paraLook.align, 'right');
    c.setLineSpacing(1.5);
    c.toggleSpaceBefore();
    c.indent(1);
    c.toggleRtl();
    final back = _roundTrip(d);
    final look = back.paras[_find(back, 'Giriş')].look;
    expect(look.align, 'right');
    expect(look.lineMultiple, 1.5);
    expect(look.spaceBeforePt, 12);
    expect(look.indentLeftPt, 36);
    expect(look.bidi, isTrue);
    // pPr şema sırası: bidi < spacing < ind < jc.
    final x = _paraXml(back.save(), 'Giriş');
    final order = ['w:bidi', 'w:spacing', 'w:ind', 'w:jc']
        .map((t) => x.indexOf('<$t'))
        .toList();
    expect(order, orderedEquals([...order]..sort()));
    expect(order.every((o) => o > 0), isTrue);
  });

  test('madde / numara listesi: numbering.xml yoksa yaratılır, numara sürer', () {
    final src = _read('tablo.docx');
    expect(_hasPart(src, 'word/numbering.xml'), isFalse);
    final d = DocxDocument.parse(src);
    final c = DocxEditController(d);
    final i = _find(d, 'Toplantı');
    // İki paragraf olsun: başlığın sonunda Enter.
    c.select(DocPos(i, d.paras[i].length), DocPos(i, d.paras[i].length));
    c.enter();
    c.insertText('İkinci');
    c.select(DocPos(i, 0), DocPos(i + 1, 3));
    c.toggleList('number');
    expect(c.listKind, 'number');
    expect(c.labels[i], '1.');
    expect(c.labels[i + 1], '2.');

    final bytes = d.save();
    expect(_hasPart(bytes, 'word/numbering.xml'), isTrue);
    expect(_part(bytes, '[Content_Types].xml'), contains('/word/numbering.xml'));
    expect(_part(bytes, 'word/_rels/document.xml.rels'), contains('numbering.xml'));
    final back = DocxDocument.parse(bytes);
    final labels = back.listLabels();
    expect(labels[_find(back, 'Toplantı')], '1.');
    expect(labels[_find(back, 'İkinci')], '2.');

    // Girinti listede düzey değiştirir; aynı türe yeniden basmak çıkarır.
    final c2 = DocxEditController(back);
    final j = _find(back, 'İkinci');
    c2.select(DocPos(j, 0), DocPos(j, 0));
    c2.indent(1);
    expect(c2.paraLook.ilvl, 1);
    expect(c2.labels[j], 'a.');
    c2.toggleList('number');
    expect(c2.paraLook.numId, isNull);
  });

  test('madde ve çok düzeyli liste etiketleri', () {
    final d = DocxDocument.parse(_read('word_kaydedilmis_cok_sayfa.docx'));
    final c = _select(d, 'Giriş', 'Giriş');
    c.toggleList('bullet');
    final i = _find(d, 'Giriş');
    expect(c.labels[i], '•');
    expect(c.listKind, 'bullet');
    c.toggleList('multi');
    c.indent(1);
    expect(c.labels[i], '1.1.');
    final back = _roundTrip(d);
    expect(back.listLabels()[_find(back, 'Giriş')], '1.1.');
  });

  test('biçim boyacısı: tek dokunuş bir kez, kilitli birden çok kez', () {
    final d = DocxDocument.parse(_read('stiller_basliklar.docx'));
    final i = _find(d, 'Bu belge');
    final k = d.paras[i].text.indexOf('kalın');
    final c = DocxEditController(d);
    c.select(DocPos(i, k), DocPos(i, k + 5));
    c.pickPainter();
    expect(c.painterActive, isTrue);
    c.select(DocPos(i, 0), DocPos(i, 2));
    c.selectionFinished();
    expect(d.paras[i].styles[0].effective.bold, isTrue);
    expect(c.painterActive, isFalse, reason: 'tek dokunuş bir kez');

    c.select(DocPos(i, k), DocPos(i, k + 5));
    c.pickPainter(lock: true);
    final j = _find(d, 'Ortalanmış');
    c.select(DocPos(j, 0), DocPos(j, 3));
    c.selectionFinished();
    expect(c.painterActive, isTrue, reason: 'kilitli');
    c.cancelPainter();
    expect(c.painterActive, isFalse);
    expect(d.paras[j].styles[0].effective.bold, isTrue);
    final back = _roundTrip(d);
    expect(back.paras[_find(back, 'Ortalanmış')].styles[0].effective.bold, isTrue);
  });

  test('geri al biçim ve paragraf işlemlerini geri çevirir', () {
    final d = DocxDocument.parse(_read('word_kaydedilmis_cok_sayfa.docx'));
    final before = utf8.decode(utf8.encode(_paraXml(d.save(), 'Giriş')));
    final c = _select(d, 'Giriş', 'Giriş');
    c.setColor(0xFF0070C0);
    c.setAlign('center');
    c.undo();
    c.undo();
    expect(_paraXml(d.save(), 'Giriş'), before);
  });

  test('gezinti ve sözcük sayısı', () {
    final d = DocxDocument.parse(_read('stiller_basliklar.docx'));
    final c = DocxEditController(d);
    final hs = c.headings();
    expect(hs.first.$3, 'Proje Raporu 2026');
    expect(hs.any((h) => h.$3.startsWith('Giriş')), isTrue);
    final n = c.counts();
    expect(n.words, greaterThan(10));
    expect(n.chars, greaterThan(n.charsNoSpace));
  });

  test('liste kalıbı galerisi: ✓ madde ve A. numara numbering.xml\'e yazılır',
      () {
    final d = DocxDocument.parse(_read('word_kaydedilmis_cok_sayfa.docx'));
    final c = _select(d, 'Giriş', 'paragrafı');
    c.applyListPattern('bullet-check');
    expect(c.listKind, 'bullet');
    expect(c.listPattern, 'bullet-check');
    final out = d.save();
    final numbering = _part(out, 'word/numbering.xml');
    expect(numbering, contains('w:lvlText w:val="✓"'));
    final i = _find(d, 'Giriş');
    c.select(DocPos(i, 0), DocPos(i, 0));
    c.applyListPattern('num-upper');
    final again = _part(d.save(), 'word/numbering.xml');
    expect(again, contains('w:numFmt w:val="upperLetter"'));
    final back = DocxDocument.parse(d.save());
    final j = back.paras.indexWhere((p) => p.text.startsWith('Giriş'));
    expect(back.listKind(back.paras[j]), 'number');
  });
}
