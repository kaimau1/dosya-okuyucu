import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// B11 m.7 — **sadakat bekçisi** (slayt): bizim anlamadığımız ama PowerPoint'in
/// kullandığı parçalar (SmartArt veri parçaları, gömülü yazı tipi, medya,
/// özel XML) ve slayt/sunum içindeki bilinmeyen öğeler (SmartArt çerçevesi,
/// `p14` uzantısı, gömülü yazı tipi listesi) kaydetmede KAYBOLMAZ.
/// Üç yol sınanır: dokunmadan kaydet, metin düzenle, not ekle + slayt sil.

const _rNs =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _dgmNs = 'http://schemas.openxmlformats.org/drawingml/2006/diagram';

/// Hiçbir yazıcının dokunmadığı parçalar: ad → içerik.
final _opaque = <String, List<int>>{
  'ppt/diagrams/data1.xml': utf8.encode(
      '<dgm:dataModel xmlns:dgm="$_dgmNs"><dgm:ptLst><dgm:pt modelId="{1}"/>'
      '</dgm:ptLst></dgm:dataModel>'),
  'ppt/diagrams/layout1.xml':
      utf8.encode('<dgm:layoutDef xmlns:dgm="$_dgmNs" uniqueId="x"/>'),
  'ppt/diagrams/quickStyle1.xml':
      utf8.encode('<dgm:styleDef xmlns:dgm="$_dgmNs" uniqueId="y"/>'),
  'ppt/diagrams/colors1.xml':
      utf8.encode('<dgm:colorsDef xmlns:dgm="$_dgmNs" uniqueId="z"/>'),
  'ppt/diagrams/drawing1.xml': utf8.encode('<dsp:drawing '
      'xmlns:dsp="http://schemas.microsoft.com/office/drawing/2008/diagram"/>'),
  'ppt/fonts/font1.fntdata': [0, 1, 0, 0, 0, 9, 0x80, 0x03, 0xFF, 0x10],
  'ppt/media/image1.png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 7],
  'customXml/item1.xml': utf8.encode('<ozel xmlns="urn:deneme">veri</ozel>'),
  'customXml/itemProps1.xml': utf8.encode('<ds:datastoreItem '
      'xmlns:ds="http://schemas.openxmlformats.org/officeDocument/2006/customXml" '
      'ds:itemID="{AB}"/>'),
  'customXml/_rels/item1.xml.rels': utf8.encode('<Relationships '
      'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$_rNs/customXmlProps" '
      'Target="itemProps1.xml"/></Relationships>'),
};

String _rel(String id, String type, String target) =>
    '<Relationship Id="$id" Type="$_rNs/$type" Target="$target"/>';

Uint8List _deck() {
  final raw = PptxWriter.build(const [
    SlideDraft('Proje', ['Birinci madde']),
    SlideDraft('Silinecek', ['x']),
  ]);
  final out = Archive();
  void put(String name, List<int> data) =>
      out.addFile(ArchiveFile(name, data.length, data));
  for (final f in ZipDecoder().decodeBytes(raw).files) {
    var s = utf8.decode(f.content as List<int>);
    switch (f.name) {
      case '[Content_Types].xml':
        s = s.replaceFirst(
            '<Override',
            '<Default Extension="fntdata" ContentType="application/x-fontdata"/>'
                '<Default Extension="png" ContentType="image/png"/>'
                '<Override PartName="/ppt/diagrams/data1.xml" ContentType='
                '"application/vnd.openxmlformats-officedocument.drawingml.diagramData+xml"/>'
                '<Override');
      case 'ppt/presentation.xml':
        s = s.replaceFirst(
            '</p:presentation>',
            '<p:embeddedFontLst><p:embeddedFont><p:font typeface="Ozel"/>'
                '<p:regular r:id="rIdFont"/></p:embeddedFont></p:embeddedFontLst>'
                '</p:presentation>');
      case 'ppt/_rels/presentation.xml.rels':
        s = s.replaceFirst(
            '</Relationships>',
            '${_rel('rIdFont', 'font', 'fonts/font1.fntdata')}'
                '${_rel('rIdCx', 'customXml', '../customXml/item1.xml')}'
                '</Relationships>');
      case 'ppt/slides/slide1.xml':
        s = s
            .replaceFirst(
                '</p:spTree>',
                '<p:graphicFrame xmlns:r="$_rNs"><p:nvGraphicFramePr>'
                    '<p:cNvPr id="90" name="SmartArt"/><p:cNvGraphicFramePr/><p:nvPr/>'
                    '</p:nvGraphicFramePr><p:xfrm><a:off x="0" y="0"/>'
                    '<a:ext cx="100" cy="100"/></p:xfrm><a:graphic><a:graphicData '
                    'uri="$_dgmNs"><dgm:relIds xmlns:dgm="$_dgmNs" r:dm="rIdDm" '
                    'r:lo="rIdLo" r:qs="rIdQs" r:cs="rIdCs"/></a:graphicData>'
                    '</a:graphic></p:graphicFrame></p:spTree>')
            .replaceFirst(
                '</p:sld>',
                '<p:extLst><p:ext uri="{BB962C8B-B14F-4D97-AF65-F5344CB8AC3E}">'
                    '<p14:creationId xmlns:p14="http://schemas.microsoft.com/'
                    'office/powerpoint/2010/main" val="4242"/></p:ext></p:extLst>'
                    '</p:sld>');
      case 'ppt/slides/_rels/slide1.xml.rels':
        s = s.replaceFirst(
            '</Relationships>',
            '${_rel('rIdDm', 'diagramData', '../diagrams/data1.xml')}'
                '${_rel('rIdLo', 'diagramLayout', '../diagrams/layout1.xml')}'
                '${_rel('rIdQs', 'diagramQuickStyle', '../diagrams/quickStyle1.xml')}'
                '${_rel('rIdCs', 'diagramColors', '../diagrams/colors1.xml')}'
                '${_rel('rIdImg', 'image', '../media/image1.png')}'
                '</Relationships>');
    }
    put(f.name, utf8.encode(s));
  }
  _opaque.forEach(put);
  return Uint8List.fromList(ZipEncoder().encode(out));
}

Map<String, List<int>> _parts(Uint8List bytes) => {
      for (final f in ZipDecoder().decodeBytes(bytes).files)
        if (f.isFile) f.name: f.content as List<int>,
    };

void _expectPreserved(Uint8List out) {
  final after = _parts(out);
  String text(String name) => utf8.decode(after[name]!);

  // 1) Opak parçalar bayt bayt aynı.
  _opaque.forEach((name, bytes) {
    expect(after[name], bytes, reason: '$name kayboldu ya da değişti');
  });

  // 2) Bilinmeyen öğeler ve bağlar yerinde.
  final slide = text('ppt/slides/slide1.xml');
  expect(slide, contains('r:dm="rIdDm"'), reason: 'SmartArt çerçevesi');
  expect(slide, contains('p14:creationId'), reason: 'p14 uzantısı');
  final rels = text('ppt/slides/_rels/slide1.xml.rels');
  for (final id in ['rIdDm', 'rIdLo', 'rIdQs', 'rIdCs', 'rIdImg']) {
    expect(rels, contains('Id="$id"'), reason: 'slayt bağı $id');
  }
  expect(text('ppt/presentation.xml'), contains('r:id="rIdFont"'),
      reason: 'gömülü yazı tipi listesi');
  final presRels = text('ppt/_rels/presentation.xml.rels');
  expect(presRels, contains('Target="fonts/font1.fntdata"'));
  expect(presRels, contains('Target="../customXml/item1.xml"'));
  final types = text('[Content_Types].xml');
  expect(types, contains('Extension="fntdata"'));
  expect(types, contains('Extension="png"'));
  expect(types, contains('/ppt/diagrams/data1.xml'));
}

void main() {
  test('dokunmadan kaydet: bütün parçalar korunur', () {
    final src = _deck();
    final out = PptxEditor.parse(src).save();
    _expectPreserved(out);
    // Hiçbir yazıcının dokunmadığı slayt bağları da bayt bayt aynı.
    expect(_parts(out)['ppt/slides/_rels/slide1.xml.rels'],
        _parts(src)['ppt/slides/_rels/slide1.xml.rels']);
  });

  test('metin düzenle → kaydet: parçalar korunur, metin yazılır', () {
    final ed = PptxEditor.parse(_deck());
    final slide = ed.slides.first;
    ed.updateParagraph(slide, slide.paragraphs.first, 'Yeni başlık');
    final out = ed.save();
    _expectPreserved(out);
    expect(utf8.decode(_parts(out)['ppt/slides/slide1.xml']!),
        contains('Yeni başlık'));
  });

  test('not ekle + slayt sil → kaydet: parçalar korunur', () {
    final ed = PptxEditor.parse(_deck());
    expect(ed.setNotes(ed.slides.first, 'Konuşmacı notu'), isTrue);
    expect(ed.deleteSlide(ed.slides.last), isTrue);
    final out = ed.save();
    _expectPreserved(out);
    final after = _parts(out);
    expect(after.containsKey('ppt/slides/slide2.xml'), isFalse);
    expect(utf8.decode(after['ppt/slides/_rels/slide1.xml.rels']!),
        contains('notesSlide'));
  });
}
