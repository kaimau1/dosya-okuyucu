import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:dosya_okuyucu/services/pptx_rich_text.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 28 — slayt zengin metni: karışık biçim korunur, seçime göre biçim,
/// Enter/geri silme paragraf böler/birleştirir, boş yer tutucuya yazı,
/// not yazma, şekil işlemleri, geri al anlık görüntüsü.
Uint8List _bytes({String Function(String xml)? slideXmlPatch}) {
  final raw = PptxWriter.build(const [
    SlideDraft('Başlık', ['bir', 'iki']),
    SlideDraft('İkinci', ['üç']),
  ]);
  if (slideXmlPatch == null) return raw;
  final arc = ZipDecoder().decodeBytes(raw);
  final out = Archive();
  for (final f in arc.files) {
    if (f.name == 'ppt/slides/slide1.xml') {
      final xml = slideXmlPatch(utf8.decode(f.content as List<int>));
      final data = utf8.encode(xml);
      out.addFile(ArchiveFile(f.name, data.length, data));
    } else {
      out.addFile(f);
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

/// "bir" paragrafını üç run'a böler: "Merhaba " · **dünya** · " sonu".
String _mixed(String xml) {
  final doc = XmlDocument.parse(xml);
  final p = doc.findAllElements('a:p').firstWhere(
      (p) => p.findAllElements('a:t').any((t) => t.innerText == 'bir'));
  final r = p.findElements('a:r').first;
  XmlElement run(String text, {bool bold = false}) {
    final c = r.copy();
    c.findAllElements('a:t').first.children
      ..clear()
      ..add(XmlText(text));
    final rPr = c.findElements('a:rPr').first;
    if (bold) rPr.setAttribute('b', '1');
    return c;
  }

  final at = p.children.indexOf(r);
  p.children
    ..removeAt(at)
    ..insertAll(at, [run('Merhaba '), run('dünya', bold: true), run(' sonu')]);
  return doc.toXmlString();
}

ShapeVM _shapeWith(PptxSlide slide, String text) => slide.view!.shapes
    .firstWhere((s) => s.paragraphs.any((p) => p.plainText.contains(text)));

void main() {
  test('el değmeyen run aynen kalır, düzenlenen aralık yeniden yazılır', () {
    final e = PptxEditor.parse(_bytes(slideXmlPatch: _mixed));
    final slide = e.slides.first;
    final shape = _shapeWith(slide, 'dünya');
    final boldBefore = shape.paragraphs.first.runs[1].source!.toXmlString();
    final rich = SlideRichText.fromParagraphs(shape.paragraphs);
    expect(rich.text, 'Merhaba dünya sonu\niki');
    rich.applyText(rich.text.replaceFirst('Merhaba', 'Selam'));
    expect(e.writeRichText(slide, shape, rich), isTrue);

    final back = PptxEditor.parse(e.save());
    final p = back.slides.first.paragraphs
        .firstWhere((p) => p.text.contains('dünya'));
    expect(p.text, 'Selam dünya sonu');
    final runs = p.element.findElements('a:r').toList();
    expect(runs.map((r) => r.findAllElements('a:t').first.innerText),
        ['Selam ', 'dünya', ' sonu']);
    // Kalın run birebir aynı XML.
    expect(runs[1].toXmlString(), boldBefore);
    // İkinci paragrafa hiç dokunulmadı.
    expect(back.slides.first.paragraphs.map((p) => p.text), contains('iki'));
  });

  test('seçime göre biçim run böler; yazma biçimi önceki karakterden', () {
    final e = PptxEditor.parse(_bytes());
    final slide = e.slides.first;
    final shape = _shapeWith(slide, 'Başlık');
    final rich = SlideRichText.fromParagraphs(shape.paragraphs);
    rich.formatRange(0, 3, italic: true, color: const Color(0xFFFF0000));
    rich.applyText('${rich.text}!'); // sona ekle → son karakterin biçimi
    e.writeRichText(slide, shape, rich);
    final back = PptxEditor.parse(e.save());
    final p = back.slides.first.paragraphs.first;
    expect(p.text, 'Başlık!');
    final runs = p.element.findElements('a:r').toList();
    expect(runs.map((r) => r.findAllElements('a:t').first.innerText),
        ['Baş', 'lık!']);
    final rPr = runs.first.findElements('a:rPr').first;
    expect(rPr.getAttribute('i'), '1');
    expect(rPr.findAllElements('a:srgbClr').first.getAttribute('val'), 'FF0000');
    expect(runs[1].findElements('a:rPr').first.getAttribute('i'), isNot('1'));
  });

  test('Enter paragraf böler, geri silme birleştirir (a:p sayısı)', () {
    final e = PptxEditor.parse(_bytes());
    final slide = e.slides.first;
    var shape = _shapeWith(slide, 'bir');
    var rich = SlideRichText.fromParagraphs(shape.paragraphs);
    expect(rich.text, 'bir\niki');
    rich.applyText('bi\nr\niki');
    expect(rich.paras, hasLength(3));
    e.writeRichText(slide, shape, rich);
    var body = _shapeWith(slide, 'iki');
    expect(body.paragraphs.map((p) => p.plainText), ['bi', 'r', 'iki']);
    // Yeni paragraf öncekinin pPr'ini (madde işareti) taşır.
    expect(body.paragraphs[1].bullet, body.paragraphs[0].bullet);

    shape = body;
    rich = SlideRichText.fromParagraphs(shape.paragraphs);
    rich.applyText('bir\niki'); // "bi" ile "r" birleşir
    e.writeRichText(slide, shape, rich);
    final back = PptxEditor.parse(e.save());
    final texts = back.slides.first.paragraphs.map((p) => p.text).toList();
    expect(texts, containsAllInOrder(['bir', 'iki']));
    expect(texts, isNot(contains('bi')));
  });

  test('hizalama, madde işareti, numara, düzey pPr\'e yazılır', () {
    final e = PptxEditor.parse(_bytes());
    final slide = e.slides.first;
    final shape = _shapeWith(slide, 'bir');
    final rich = SlideRichText.fromParagraphs(shape.paragraphs);
    rich.formatParagraphs(0, 0, align: TextAlign.center, bullet: 'num');
    rich.formatParagraphs(4, 4, levelDelta: 1, bullet: 'none');
    e.writeRichText(slide, shape, rich);
    final back = PptxEditor.parse(e.save());
    final ps = back.slides.first.paragraphs;
    final bir = ps.firstWhere((p) => p.text == 'bir').element;
    final pPr = bir.findElements('a:pPr').first;
    expect(pPr.getAttribute('algn'), 'ctr');
    expect(pPr.findElements('a:buAutoNum'), hasLength(1));
    final iki = ps.firstWhere((p) => p.text == 'iki').element;
    final pPr2 = iki.findElements('a:pPr').first;
    expect(pPr2.getAttribute('lvl'), '1');
    expect(pPr2.findElements('a:buNone'), hasLength(1));
  });

  test('metin gövdesiz boş yer tutucu: istem gösterilir, yazınca gövde açılır',
      () {
    final e = PptxEditor.parse(_bytes(
        slideXmlPatch: (xml) {
          final doc = XmlDocument.parse(xml);
          for (final sp in doc.findAllElements('p:sp')) {
            final ph = sp.findAllElements('p:ph').first;
            if (ph.getAttribute('type') == 'body') {
              sp.children.remove(sp.findElements('p:txBody').first);
            }
          }
          return doc.toXmlString();
        }));
    final slide = e.slides.first;
    final empty = slide.view!.shapes.firstWhere((s) => s.isEmptyPlaceholder);
    expect(empty.placeholderType, 'body');
    final rich = SlideRichText.fromParagraphs(empty.paragraphs);
    expect(rich.text, '');
    rich.applyText('Yeni madde');
    expect(e.writeRichText(slide, empty, rich), isTrue);
    final back = PptxEditor.parse(e.save());
    expect(back.slides.first.paragraphs.map((p) => p.text),
        contains('Yeni madde'));
    final sp = back.slides.first.doc.findAllElements('p:sp').firstWhere(
        (sp) => sp.findAllElements('a:t').any((t) => t.innerText == 'Yeni madde'));
    // Şema sırası: spPr'den sonra txBody; bodyPr + lstStyle başta.
    final kids = sp.childElements.map((c) => c.name.qualified).toList();
    expect(kids.indexOf('p:txBody'), greaterThan(kids.indexOf('p:spPr')));
    expect(sp.findElements('p:txBody').first.childElements.first.name.qualified,
        'a:bodyPr');
  });

  test('not yazma: not sayfası + not şablonu yoksa oluşturulur', () {
    final e = PptxEditor.parse(_bytes());
    final slide = e.slides.first;
    expect(e.notesOf(slide), '');
    expect(e.setNotes(slide, 'Birinci not\nikinci satır'), isTrue);
    expect(e.notesOf(slide), 'Birinci not\nikinci satır');
    final out = e.save();
    final back = PptxEditor.parse(out);
    expect(back.notesOf(back.slides.first), 'Birinci not\nikinci satır');
    expect(back.notesOf(back.slides[1]), '');
    final arc = ZipDecoder().decodeBytes(out);
    String part(String n) =>
        utf8.decode(arc.files.firstWhere((f) => f.name == n).content as List<int>);
    expect(part('[Content_Types].xml'), contains('notesMaster+xml'));
    expect(part('[Content_Types].xml'), contains('notesSlide+xml'));
    expect(part('ppt/presentation.xml'), contains('p:notesMasterIdLst'));
    // Not şablonu sldMasterIdLst'ten hemen sonra (şema sırası).
    final pres = XmlDocument.parse(part('ppt/presentation.xml'));
    final names =
        pres.rootElement.childElements.map((c) => c.name.qualified).toList();
    expect(names.indexOf('p:notesMasterIdLst'),
        names.indexOf('p:sldMasterIdLst') + 1);

    // Var olan notu güncelleme.
    expect(back.setNotes(back.slides.first, 'güncel'), isTrue);
    expect(PptxEditor.parse(back.save()).notesOf(back.slides.first), 'güncel');
  });

  test('slayt çoğaltılınca not kopyaya taşınmaz', () {
    final e = PptxEditor.parse(PptxWriter.build(
        const [SlideDraft('A', ['x'], notes: 'özel not')]));
    final copy = e.duplicateSlide(e.slides.first)!;
    expect(e.notesOf(copy), '');
    expect(e.notesOf(e.slides.first), 'özel not');
  });

  test('şekil çoğalt / sil / öne-arkaya; kimlikler benzersiz', () {
    final e = PptxEditor.parse(_bytes());
    final slide = e.slides.first;
    final title = _shapeWith(slide, 'Başlık');
    expect(PptxEditor.canArrange(title), isTrue);
    expect(e.duplicateShape(slide, title), isTrue);
    final ids = slide.doc
        .findAllElements('p:cNvPr')
        .map((c) => c.getAttribute('id'))
        .toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(slide.view!.shapes.where((s) => s.hasText &&
        s.paragraphs.first.plainText == 'Başlık'), hasLength(2));

    final body = _shapeWith(slide, 'bir');
    expect(e.reorderShape(slide, body, front: false), isTrue);
    final tree = slide.doc.findAllElements('p:spTree').first;
    final firstShape = tree.childElements
        .firstWhere((c) => c.name.qualified == 'p:sp');
    expect(firstShape.findAllElements('a:t').first.innerText, 'bir');

    final again = _shapeWith(slide, 'bir');
    expect(e.deleteShape(slide, again), isTrue);
    expect(slide.paragraphs.map((p) => p.text), isNot(contains('bir')));
  });

  test('geri al anlık görüntüsü: silinen slayt ve metin geri gelir', () {
    final e = PptxEditor.parse(_bytes());
    final snap = e.snapshot();
    e.updateParagraph(e.slides.first, e.slides.first.paragraphs.first, 'Değişti');
    e.deleteSlide(e.slides[1]);
    e.setNotes(e.slides.first, 'not');
    expect(e.slides, hasLength(1));
    e.restore(snap);
    expect(e.slides, hasLength(2));
    expect(e.slides.first.paragraphs.first.text, 'Başlık');
    expect(e.notesOf(e.slides.first), '');
    final back = PptxEditor.parse(e.save());
    expect(back.slides, hasLength(2));
    expect(back.slides[1].paragraphs.first.text, 'İkinci');
    expect(back.notesOf(back.slides.first), '');
  });
}
