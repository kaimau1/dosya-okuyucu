import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 22 — Word belge modeli: gidiş-dönüş, stiller/listeler, dokunulmaz
/// adalar, yalnız değişen paragrafın yazılması, geri al tutarlılığı.
const _dir = 'test/fixtures/office';

Uint8List _read(String name) => File('$_dir/$name').readAsBytesSync();

String _documentXml(Uint8List bytes) => utf8.decode(ZipDecoder()
    .decodeBytes(bytes)
    .files
    .firstWhere((f) => f.name == 'word/document.xml')
    .content as List<int>);

List<String> _paraXml(String xml) => [
      for (final p in XmlDocument.parse(xml).findAllElements('w:p'))
        p.toXmlString(),
    ];

int _find(DocxDocument d, String startsWith) =>
    d.paras.indexWhere((p) => p.text.startsWith(startsWith));

void main() {
  test('el değmemiş belge kaydedilince document.xml baytı baytına aynı', () {
    for (final f in Directory(_dir).listSync()) {
      if (!f.path.endsWith('.docx')) continue;
      final bytes = (f as File).readAsBytesSync();
      final d = DocxDocument.parse(bytes);
      expect(_documentXml(d.save()), _documentXml(bytes), reason: f.path);
      expect(d.xmlDirty, isFalse, reason: f.path);
    }
  });

  test('stiller, başlıklar, listeler, tablo, resim, sekme, satır sonu okunur', () {
    final d = DocxDocument.parse(_read('stiller_basliklar.docx'));
    final title = d.paras.first;
    expect(title.text, 'Proje Raporu 2026');
    expect(title.look.headingLevel, 1);
    final h1 = d.paras[_find(d, 'Giriş')];
    expect(h1.look.headingLevel, 1);
    expect(h1.mark.look.sizePt, greaterThan(12));
    final mixed = d.paras[_find(d, 'Bu belge')];
    final k = mixed.text.indexOf('kalın');
    expect(mixed.styles[k].look.bold, isTrue);
    expect(mixed.styles[0].look.bold, isFalse);
    final red = mixed.text.indexOf('kırmızı');
    expect(mixed.styles[red].look.color, 0xFFC00000);
    expect(d.paras[_find(d, 'Ortalanmış')].look.align, 'center');

    final labels = d.listLabels();
    expect(labels[_find(d, 'Birinci madde')], '•');
    expect(labels[_find(d, 'Adım bir')], '1.');
    expect(labels[_find(d, 'Adım iki')], '2.');

    final cells = d.paras.where((p) => p.cell != null).map((p) => p.text);
    expect(cells, ['Ad', 'Şehir', 'Ayşe', 'İzmir']);

    final pic = d.paras.firstWhere(
        (p) => p.atoms.any((a) => a?.kind == DocxAtomKind.image));
    final img = pic.atoms.firstWhere((a) => a != null)!;
    expect(img.image, isNotNull);
    expect(img.widthPt, closeTo(108, 1)); // 1,5 inç

    final tab = d.paras[_find(d, 'Sekmeli')];
    expect(tab.text, 'Sekmeli\tsatır ve $kDocxLineBreak'
        'satır sonu.');
  });

  test('bir kelime değişince yalnız o w:p farklı; kalın run aynen', () {
    final bytes = _read('stiller_basliklar.docx');
    final d = DocxDocument.parse(bytes);
    final i = _find(d, 'Bu belge');
    final p = d.paras[i];
    final bold = p.styles[p.text.indexOf('kalın')].run!.toXmlString();
    d.paras[i] = p.replace(3, 8, 'rapor', p.typingStyleAt(3));
    final out = d.save();
    final before = _paraXml(_documentXml(bytes));
    final after = _paraXml(_documentXml(out));
    expect(after, hasLength(before.length));
    var diff = 0;
    for (var k = 0; k < before.length; k++) {
      if (before[k] != after[k]) diff++;
    }
    expect(diff, 1);
    final back = DocxDocument.parse(out);
    final q = back.paras[_find(back, 'Bu rapor')];
    expect(q.text, startsWith('Bu rapor kalın, italik'));
    expect(after.firstWhere((x) => x.contains('Bu rapor')), contains(bold));
  });

  test('Enter başlıkta sonraki stile geçer; böl + birleştir XML\'e yansır', () {
    final d = DocxDocument.parse(_read('stiller_basliklar.docx'));
    final i = _find(d, 'Giriş');
    final h = d.paras[i];
    final (pPr, look) = d.nextParagraphProps(h);
    final (left, right) =
        h.split(h.length, nextPPr: pPr, nextLook: look);
    d.paras
      ..[i] = left
      ..insert(i + 1, right.replace(0, 0, 'Yeni gövde', right.mark));
    expect(d.paras[i + 1].look.headingLevel, 0);
    final out = d.save();
    var back = DocxDocument.parse(out);
    final j = _find(back, 'Yeni gövde');
    expect(j, _find(back, 'Giriş') + 1);
    expect(back.paras[j].look.headingLevel, 0);

    // Birleştir: "Yeni gövde" başlığa katılır.
    back.paras[j - 1] = back.paras[j - 1].join(back.paras[j]);
    back.paras.removeAt(j);
    back = DocxDocument.parse(back.save());
    expect(back.paras.map((p) => p.text), contains('GirişYeni gövde'));
    expect(back.paras.map((p) => p.text), isNot(contains('Yeni gövde')));
  });

  test('köprü, dipnot, sekme, alan dokunulmaz ada olarak korunur', () {
    final bytes = _read('word_kaydedilmis_cok_sayfa.docx');
    final d = DocxDocument.parse(bytes);
    final i = _find(d, 'Bağlantı');
    final p = d.paras[i];
    expect(p.atoms.where((a) => a?.kind == DocxAtomKind.link), hasLength(1));
    expect(p.atoms.where((a) => a?.kind == DocxAtomKind.note), hasLength(1));
    d.paras[i] = p.replace(0, 8, 'Bağ', p.typingStyleAt(0));
    final xml = _documentXml(d.save());
    final para = _paraXml(xml).firstWhere((x) => x.contains('Bağ: '));
    expect(para, contains('w:hyperlink'));
    expect(para, contains('örnek site'));
    expect(para, contains('w:footnoteReference'));
    expect(para, contains('<w:tab/>'));
    // Sayfa sonu (atom) ayrı paragrafta yerinde.
    expect(xml, contains('w:type="page"'));
  });

  test('geri al: eski paragraf listesine dönünce XML de geri döner', () {
    final bytes = _read('stiller_basliklar.docx');
    final d = DocxDocument.parse(bytes);
    final snap = [...d.paras];
    final i = _find(d, 'Adım bir');
    final (a, b) = d.paras[i].split(3);
    d.paras
      ..[i] = a
      ..insert(i + 1, b);
    d.paras.removeAt(_find(d, 'Son paragraf'));
    d.commit();
    expect(d.plainText(), isNot(contains('Son paragraf')));
    d.paras = [...snap];
    final back = DocxDocument.parse(d.save());
    expect(back.plainText(), DocxDocument.parse(bytes).plainText());
  });

  test('boş liste öğesinde Enter listeden çıkarır', () {
    final d = DocxDocument.parse(_read('liste_duzeyli.docx'));
    final i = _find(d, 'Bir');
    expect(d.paras[i].look.numId, isNotNull);
    final out = d.withoutList(d.paras[i]);
    expect(out.look.numId, isNull);
  });

  test('Arapça paragraf sağdan sola', () {
    final d = DocxDocument.parse(_read('arapca_rtl.docx'));
    expect(d.paras.first.look.bidi, isTrue);
    expect(d.paras.last.look.bidi, isFalse);
  });
}
