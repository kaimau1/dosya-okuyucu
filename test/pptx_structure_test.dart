import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yapısal olarak geçerli (content-types + sunum + ilişkiler + 2 slayt) küçük
/// bir .pptx üretir. Slayt ekle/sil/taşı işlemleri bunun üzerinde denenir.
Uint8List _structuredPptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  const rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const pkgRel = 'http://schemas.openxmlformats.org/package/2006/relationships';

  add('[Content_Types].xml', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="xml" ContentType="application/xml"/>
 <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
 <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
 <Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
</Types>''');

  add('ppt/presentation.xml', '''
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="$rel">
 <p:sldIdLst>
  <p:sldId id="256" r:id="rId2"/>
  <p:sldId id="257" r:id="rId3"/>
 </p:sldIdLst>
 <p:sldSz cx="12192000" cy="6858000"/>
</p:presentation>''');

  add('ppt/_rels/presentation.xml.rels', '''
<Relationships xmlns="$pkgRel">
 <Relationship Id="rId1" Type="$rel/slideMaster" Target="slideMasters/slideMaster1.xml"/>
 <Relationship Id="rId2" Type="$rel/slide" Target="slides/slide1.xml"/>
 <Relationship Id="rId3" Type="$rel/slide" Target="slides/slide2.xml"/>
</Relationships>''');

  String slide(String text) => '''
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
 <p:cSld><p:spTree>
  <p:sp><p:spPr>
    <a:xfrm><a:off x="914400" y="457200"/><a:ext cx="4572000" cy="1143000"/></a:xfrm>
    <a:prstGeom prst="rect"/>
   </p:spPr>
   <p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="2400"/><a:t>$text</a:t></a:r></a:p></p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
</p:sld>''';

  add('ppt/slides/slide1.xml', slide('Bir'));
  add('ppt/slides/slide2.xml', slide('İki'));
  add('ppt/slides/_rels/slide1.xml.rels', '<Relationships xmlns="$pkgRel"/>');
  add('ppt/slides/_rels/slide2.xml.rels', '<Relationships xmlns="$pkgRel"/>');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _firstText(dynamic slide) => slide.paragraphs.first.text as String;

void main() {
  test('yapı okunur ve slaytlar sunum sırasına göre gelir', () {
    final e = PptxEditor.parse(_structuredPptx());
    expect(e.canEditStructure, isTrue);
    expect(e.slides.length, 2);
    expect(_firstText(e.slides[0]), 'Bir');
    expect(_firstText(e.slides[1]), 'İki');
  });

  test('slayt çoğaltma kaydedilen dosyada 3 slayt üretir, sıra korunur', () {
    final e = PptxEditor.parse(_structuredPptx());
    final dup = e.duplicateSlide(e.slides[0]);
    expect(dup, isNotNull);
    expect(e.slides.length, 3);
    // Kopya kaynağın hemen ardında ve yeni dosya adıyla.
    expect(e.slides[1].fileName, 'ppt/slides/slide3.xml');

    final again = PptxEditor.parse(e.save());
    expect(again.slides.length, 3);
    expect(again.slides.map(_firstText).toList(), ['Bir', 'Bir', 'İki']);
    expect(again.slides[1].fileName, 'ppt/slides/slide3.xml');
    // İçerik tipi ve ilişki de eklenmiş olmalı (yoksa yapı düzenlenemezdi).
    expect(again.canEditStructure, isTrue);
  });

  test('slayt silme kaydedilen dosyadan çıkarır', () {
    final e = PptxEditor.parse(_structuredPptx());
    expect(e.deleteSlide(e.slides[0]), isTrue);
    expect(e.slides.length, 1);

    final again = PptxEditor.parse(e.save());
    expect(again.slides.length, 1);
    expect(_firstText(again.slides[0]), 'İki');
  });

  test('son slayt silinemez (en az bir slayt kalır)', () {
    final e = PptxEditor.parse(_structuredPptx());
    e.deleteSlide(e.slides[0]);
    expect(e.deleteSlide(e.slides[0]), isFalse);
    expect(e.slides.length, 1);
  });

  test('slayt taşıma sırayı kaydedilen dosyaya yansıtır', () {
    final e = PptxEditor.parse(_structuredPptx());
    expect(e.moveSlide(e.slides[1], -1), isTrue); // İki'yi yukarı al
    expect(e.slides.map(_firstText).toList(), ['İki', 'Bir']);

    final again = PptxEditor.parse(e.save());
    expect(again.slides.map(_firstText).toList(), ['İki', 'Bir']);
  });

  test('yapı eksik dosyada yapısal düzenleme kapalı ama metin düzenleme açık', () {
    // Sadece bir slayt dosyası olan (content-types/presRels'siz) sentetik pptx.
    final archive = Archive();
    void add(String name, String xml) {
      final data = utf8.encode(xml);
      archive.addFile(ArchiveFile(name, data.length, data));
    }

    add('ppt/presentation.xml',
        '<p:presentation xmlns:p="ppt"><p:sldSz cx="9144000" cy="6858000"/></p:presentation>');
    add('ppt/slides/slide1.xml',
        '<p:sld xmlns:p="ppt" xmlns:a="draw"><p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>Tek</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>');
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    final e = PptxEditor.parse(bytes);
    expect(e.canEditStructure, isFalse);
    expect(e.duplicateSlide(e.slides[0]), isNull);
    expect(e.slides.length, 1);
  });
}
