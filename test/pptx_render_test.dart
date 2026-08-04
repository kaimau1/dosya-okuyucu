import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:dosya_okuyucu/widgets/slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Küçük ama gerçek bir .pptx üretir: 1 slayt, kırmızı dikdörtgen + 32pt kalın
/// başlık, bir de grup içinde ölçeklenmiş şekil.
Uint8List _samplePptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );

  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw">
 <p:cSld><p:spTree>
  <p:sp>
   <p:nvSpPr><p:cNvPr id="2" name="Baslik"/><p:nvPr/></p:nvSpPr>
   <p:spPr>
    <a:xfrm><a:off x="914400" y="457200"/><a:ext cx="4572000" cy="1143000"/></a:xfrm>
    <a:prstGeom prst="rect"/>
    <a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>
   </p:spPr>
   <p:txBody><a:bodyPr anchor="ctr"/>
    <a:p><a:pPr algn="ctr"/><a:r><a:rPr sz="3200" b="1"/><a:t>Merhaba</a:t></a:r></a:p>
   </p:txBody>
  </p:sp>
  <p:grpSp>
   <p:grpSpPr>
    <a:xfrm>
     <a:off x="0" y="0"/><a:ext cx="1270000" cy="1270000"/>
     <a:chOff x="0" y="0"/><a:chExt cx="2540000" cy="2540000"/>
    </a:xfrm>
   </p:grpSpPr>
   <p:sp>
    <p:spPr>
     <a:xfrm><a:off x="2540000" y="0"/><a:ext cx="1270000" cy="1270000"/></a:xfrm>
    </p:spPr>
    <p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Grup</a:t></a:r></a:p></p:txBody>
   </p:sp>
  </p:grpSp>
 </p:spTree></p:cSld>
 <p:timing><p:tnLst><p:par><p:cTn id="1" nodeType="tmRoot"><p:childTnLst>
  <p:seq><p:cTn id="2" nodeType="mainSeq"><p:childTnLst>
   <p:par><p:cTn id="3" nodeType="clickEffect"><p:childTnLst>
    <p:set><p:cBhvr><p:tgtEl><p:spTgt spid="2"/></p:tgtEl></p:cBhvr></p:set>
   </p:childTnLst></p:cTn></p:par>
  </p:childTnLst></p:cTn></p:seq>
 </p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Autofit örneği: küçük kutuda (360x45pt) taşacak kadar uzun 32pt metin +
/// `a:normAutofit` — PowerPoint bu durumda yazıyı kutuya sığdırır.
/// [withAutofit] false ise normAutofit yazılmaz: düz şekil örneği (sığdırma
/// artık TÜM metin kutularına uygulanır — yazı-taşması kök nedeni #3).
Uint8List _autofitPptx({bool withAutofit = true}) {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );
  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw">
 <p:cSld><p:spTree>
  <p:sp>
   <p:nvSpPr><p:cNvPr id="2" name="Baslik"/><p:nvPr/></p:nvSpPr>
   <p:spPr>
    <a:xfrm><a:off x="914400" y="457200"/><a:ext cx="4572000" cy="571500"/></a:xfrm>
    <a:prstGeom prst="rect"/>
   </p:spPr>
   <p:txBody>${withAutofit ? '<a:bodyPr><a:normAutofit lnSpcReduction="10000"/></a:bodyPr>' : '<a:bodyPr/>'}
    <a:p><a:r><a:rPr sz="3200"/><a:t>Uzun bir başlık metni kutuya sığmayacak kadar uzun yazılırsa PowerPoint yazıyı otomatik küçültür</a:t></a:r></a:p>
   </p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// typeface eşlemesi için: 3 paragraf, her biri farklı yazı tipiyle.
Uint8List _fontPptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );
  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw">
 <p:cSld><p:spTree>
  <p:sp>
   <p:nvSpPr><p:cNvPr id="2" name="Metin"/><p:nvPr/></p:nvSpPr>
   <p:spPr><a:xfrm><a:off x="914400" y="457200"/><a:ext cx="4572000" cy="2286000"/></a:xfrm></p:spPr>
   <p:txBody><a:bodyPr/>
    <a:p><a:r><a:rPr sz="1800"><a:latin typeface="Arial"/></a:rPr><a:t>Arial</a:t></a:r></a:p>
    <a:p><a:r><a:rPr sz="1800"><a:latin typeface="Times New Roman"/></a:rPr><a:t>Times</a:t></a:r></a:p>
    <a:p><a:r><a:rPr sz="1800"/><a:t>Varsayilan</a:t></a:r></a:p>
   </p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Bağlayıcı (ok'lu çizgi) + dış gölgeli dikdörtgen.
Uint8List _linePptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );
  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw">
 <p:cSld><p:spTree>
  <p:cxnSp>
   <p:nvCxnSpPr><p:cNvPr id="5" name="Baglayici"/><p:nvPr/></p:nvCxnSpPr>
   <p:spPr>
    <a:xfrm flipV="1"><a:off x="1000000" y="1000000"/><a:ext cx="2000000" cy="0"/></a:xfrm>
    <a:prstGeom prst="straightConnector1"/>
    <a:ln w="19050"><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill><a:tailEnd type="triangle"/></a:ln>
   </p:spPr>
  </p:cxnSp>
  <p:sp>
   <p:nvSpPr><p:cNvPr id="6" name="Golgeli"/><p:nvPr/></p:nvSpPr>
   <p:spPr>
    <a:xfrm><a:off x="500000" y="3000000"/><a:ext cx="2000000" cy="1000000"/></a:xfrm>
    <a:prstGeom prst="rect"/>
    <a:solidFill><a:srgbClr val="00FF00"/></a:solidFill>
    <a:effectLst><a:outerShdw blurRad="50800" dist="38100" dir="2700000"><a:srgbClr val="000000"><a:alpha val="40000"/></a:srgbClr></a:outerShdw></a:effectLst>
   </p:spPr>
   <p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Golge</a:t></a:r></a:p></p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Ön tanımlı geometri örneği: ok (ayar değerli), elmas, elips, çentikli
/// köşeli dikdörtgen ve tanınmayan bir geometri.
Uint8List _geometryPptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );

  String sp(String name, String prst, String geomBody) => '''
  <p:sp>
   <p:nvSpPr><p:cNvPr id="0" name="$name"/><p:nvPr/></p:nvSpPr>
   <p:spPr>
    <a:xfrm><a:off x="0" y="0"/><a:ext cx="2540000" cy="1270000"/></a:xfrm>
    <a:prstGeom prst="$prst">$geomBody</a:prstGeom>
    <a:solidFill><a:srgbClr val="3366CC"/></a:solidFill>
   </p:spPr>
   <p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1400"/><a:t>$name</a:t></a:r></a:p></p:txBody>
  </p:sp>''';

  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw">
 <p:cSld><p:spTree>
${sp('Ok', 'rightArrow', '<a:avLst><a:gd name="adj1" fmla="val 30000"/><a:gd name="adj2" fmla="val 70000"/></a:avLst>')}
${sp('Elmas', 'diamond', '<a:avLst/>')}
${sp('Elips', 'ellipse', '')}
${sp('Yuvarlak', 'roundRect', '<a:avLst><a:gd name="adj" fmla="val 50000"/></a:avLst>')}
${sp('Bilinmeyen', 'funkyShapeXyz', '')}
 </p:spTree></p:cSld>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// `a:srcRect` ile kırpılmış görsel içeren slayt.
Uint8List _croppedPicPptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  // 1x1 saydam PNG — çözümlemeye girmesi yeter, çizilmesi gerekmiyor.
  final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
      'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
  archive.addFile(ArchiveFile('ppt/media/image1.png', png.length, png));

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );
  add('ppt/slides/_rels/slide1.xml.rels', '''
<Relationships xmlns="rel">
 <Relationship Id="rId1" Type="image" Target="../media/image1.png"/>
</Relationships>''');
  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw" xmlns:r="rel">
 <p:cSld><p:spTree>
  <p:pic>
   <p:nvPicPr><p:cNvPr id="7" name="Foto"/><p:nvPr/></p:nvPicPr>
   <p:blipFill>
    <a:blip r:embed="rId1"/>
    <a:srcRect l="10000" t="25000" r="5000" b="0"/>
    <a:stretch><a:fillRect/></a:stretch>
   </p:blipFill>
   <p:spPr>
    <a:xfrm><a:off x="0" y="0"/><a:ext cx="2540000" cy="1270000"/></a:xfrm>
    <a:prstGeom prst="ellipse"/>
    <a:ln w="25400"><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:ln>
   </p:spPr>
  </p:pic>
  <p:pic>
   <p:nvPicPr><p:cNvPr id="8" name="Tam"/><p:nvPr/></p:nvPicPr>
   <p:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
   <p:spPr>
    <a:xfrm><a:off x="3000000" y="0"/><a:ext cx="1270000" cy="1270000"/></a:xfrm>
    <a:prstGeom prst="rect"/>
    <a:ln w="25400"><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:ln>
   </p:spPr>
  </p:pic>
 </p:spTree></p:cSld>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Grafikli slayt: graphicFrame → ayrı chart parçası (2 seri, 3 kategori sütun).
Uint8List _chartPptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );
  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw" xmlns:c="chart" xmlns:r="rel">
 <p:cSld><p:spTree>
  <p:graphicFrame>
   <p:nvGraphicFramePr><p:cNvPr id="4" name="Grafik"/></p:nvGraphicFramePr>
   <p:xfrm><a:off x="1000000" y="1000000"/><a:ext cx="6000000" cy="3500000"/></p:xfrm>
   <a:graphic><a:graphicData uri="chart"><c:chart r:id="rId1"/></a:graphicData></a:graphic>
  </p:graphicFrame>
 </p:spTree></p:cSld>
</p:sld>
''');
  add('ppt/slides/_rels/slide1.xml.rels', '''
<Relationships xmlns="rel">
 <Relationship Id="rId1" Type="http://x/chart" Target="../charts/chart1.xml"/>
</Relationships>
''');
  add('ppt/charts/chart1.xml', '''
<c:chartSpace xmlns:c="chart" xmlns:a="draw">
 <c:chart>
  <c:plotArea>
   <c:barChart>
    <c:barDir val="col"/>
    <c:ser>
     <c:tx><c:strRef><c:strCache><c:pt idx="0"><c:v>Seri A</c:v></c:pt></c:strCache></c:strRef></c:tx>
     <c:cat><c:strRef><c:strCache>
       <c:pt idx="0"><c:v>Oca</c:v></c:pt>
       <c:pt idx="1"><c:v>Sub</c:v></c:pt>
       <c:pt idx="2"><c:v>Mar</c:v></c:pt>
     </c:strCache></c:strRef></c:cat>
     <c:val><c:numRef><c:numCache>
       <c:pt idx="0"><c:v>3</c:v></c:pt>
       <c:pt idx="1"><c:v>5</c:v></c:pt>
       <c:pt idx="2"><c:v>2</c:v></c:pt>
     </c:numCache></c:numRef></c:val>
    </c:ser>
    <c:ser>
     <c:tx><c:v>Seri B</c:v></c:tx>
     <c:val><c:numRef><c:numCache>
       <c:pt idx="0"><c:v>4</c:v></c:pt>
       <c:pt idx="1"><c:v>1</c:v></c:pt>
       <c:pt idx="2"><c:v>6</c:v></c:pt>
     </c:numCache></c:numRef></c:val>
    </c:ser>
   </c:barChart>
  </c:plotArea>
  <c:legend/>
 </c:chart>
</c:chartSpace>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Tema stil referansı: dolgu/çizgi `spPr`'de DEĞİL, `p:style` içinde
/// (`a:fillRef`/`a:lnRef`). Modern PowerPoint şekillerinin yaygın hâli.
Uint8List _styleRefPptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );
  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw">
 <p:cSld><p:spTree>
  <p:sp>
   <p:nvSpPr><p:cNvPr id="2" name="Temali"/><p:nvPr/></p:nvSpPr>
   <p:spPr>
    <a:xfrm><a:off x="914400" y="457200"/><a:ext cx="2000000" cy="1000000"/></a:xfrm>
    <a:prstGeom prst="rect"/>
   </p:spPr>
   <p:style>
    <a:lnRef idx="2"><a:srgbClr val="112233"/></a:lnRef>
    <a:fillRef idx="3"><a:srgbClr val="00AAFF"/></a:fillRef>
    <a:effectRef idx="0"><a:srgbClr val="000000"/></a:effectRef>
    <a:fontRef idx="minor"><a:srgbClr val="FFFFFF"/></a:fontRef>
   </p:style>
   <p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Temali</a:t></a:r></a:p></p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Mutlak punto satır aralığı (`a:lnSpc>a:spcPts`) + paragraf sonrası boşluk
/// (`a:spcAft>a:spcPts`). 15pt yazıda 30pt satır → çarpan 2.0; 6pt son boşluk.
Uint8List _spacingPptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );
  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw">
 <p:cSld><p:spTree>
  <p:sp>
   <p:nvSpPr><p:cNvPr id="2" name="Metin"/><p:nvPr/></p:nvSpPr>
   <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="4000000" cy="2000000"/></a:xfrm></p:spPr>
   <p:txBody><a:bodyPr/>
    <a:p>
     <a:pPr><a:lnSpc><a:spcPts val="3000"/></a:lnSpc><a:spcAft><a:spcPts val="600"/></a:spcAft></a:pPr>
     <a:r><a:rPr sz="1500"/><a:t>Aralik</a:t></a:r>
    </a:p>
   </p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Tablo: 1 hücre, yalnız sol (kırmızı 1pt) ve alt (mavi 2pt) kenarlık tanımlı.
Uint8List _tablePptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );
  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw">
 <p:cSld><p:spTree>
  <p:graphicFrame>
   <p:nvGraphicFramePr><p:cNvPr id="7" name="Tablo"/></p:nvGraphicFramePr>
   <p:xfrm><a:off x="500000" y="500000"/><a:ext cx="2540000" cy="1270000"/></p:xfrm>
   <a:graphic><a:graphicData uri="tbl">
    <a:tbl>
     <a:tblGrid><a:gridCol w="2540000"/></a:tblGrid>
     <a:tr h="1270000">
      <a:tc>
       <a:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Hucre</a:t></a:r></a:p></a:txBody>
       <a:tcPr>
        <a:lnL w="12700"><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:lnL>
        <a:lnB w="25400"><a:solidFill><a:srgbClr val="0000FF"/></a:solidFill></a:lnB>
       </a:tcPr>
      </a:tc>
     </a:tr>
    </a:tbl>
   </a:graphicData></a:graphic>
  </p:graphicFrame>
 </p:spTree></p:cSld>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  _notesTests();

  test('slayt geometrisi, rengi ve metni EMU -> punto olarak çözümlenir', () {
    final editor = PptxEditor.parse(_samplePptx());
    final view = editor.slides.single.view!;

    expect(view.widthPt, 960); // 12192000 EMU / 12700
    expect(view.heightPt, 540);
    expect(view.shapes.length, 2);

    final box = view.shapes.first;
    expect(box.x, 72);
    expect(box.y, 36);
    expect(box.w, 360);
    expect(box.h, 90);
    expect(box.fill, const Color(0xFFFF0000));
    expect(box.vAnchor, 'ctr');

    final para = box.paragraphs.single;
    expect(para.plainText, 'Merhaba');
    expect(para.align, TextAlign.center);
    expect(para.runs.single.sizePt, 32);
    expect(para.runs.single.bold, isTrue);
  });

  test('grup şekli çocuk koordinatlarını ölçekleyip öteler', () {
    final view = PptxEditor.parse(_samplePptx()).slides.single.view!;
    final grouped = view.shapes.last;

    // Grup 2540000 EMU'luk çocuk uzayını 1270000'e sıkıştırıyor => 0.5 ölçek.
    expect(grouped.x, 100); // 2540000/12700 * 0.5
    expect(grouped.w, 50);
    expect(grouped.paragraphs.single.plainText, 'Grup');
  });

  test('metin düzenlemesi hem XML\'e hem çizime yansır', () {
    final editor = PptxEditor.parse(_samplePptx());
    final slide = editor.slides.single;
    final shape = slide.view!.shapes.first;
    final para = slide.paragraphOf(shape.paragraphs.single.source)!;

    editor.updateParagraph(slide, para, 'Selam');

    expect(slide.view!.shapes.first.paragraphs.single.plainText, 'Selam');
    expect(slide.doc.toXmlString(), contains('<a:t>Selam</a:t>'));

    // Kaydedilen dosya yeniden okunduğunda da yeni metni içerir.
    final again = PptxEditor.parse(editor.save());
    expect(again.slides.single.paragraphs.first.text, 'Selam');
  });

  test('formatParagraph B/I/U + puntoyu yazar; görünüme ve kayda yansır', () {
    final editor = PptxEditor.parse(_samplePptx());
    final slide = editor.slides.single;
    final shape = slide.view!.shapes.first; // "Merhaba": 32pt, kalın
    final para = slide.paragraphOf(shape.paragraphs.single.source)!;

    editor.formatParagraph(slide, para,
        bold: false, italic: true, underline: true, sizePt: 20);

    final run = slide.view!.shapes.first.paragraphs.single.runs.single;
    expect(run.bold, isFalse);
    expect(run.italic, isTrue);
    expect(run.underline, isTrue);
    expect(run.sizePt, 20);

    // Kaydedilen dosya yeniden okununca da biçim durur.
    final again = PptxEditor.parse(editor.save());
    final run2 =
        again.slides.single.view!.shapes.first.paragraphs.single.runs.single;
    expect(run2.sizePt, 20);
    expect(run2.italic, isTrue);
    expect(run2.bold, isFalse);
  });

  test('yazı tipi typeface\'ten çözülüp gömülü metrik-uyumlu aileye eşlenir', () {
    final view = PptxEditor.parse(_fontPptx()).slides.single.view!;
    final paras = view.shapes.single.paragraphs;
    expect(paras[0].runs.single.fontFamily, 'Arimo'); // Arial
    expect(paras[1].runs.single.fontFamily, 'Tinos'); // Times New Roman
    expect(paras[2].runs.single.fontFamily, 'Carlito'); // varsayılan (Calibri)
  });

  test('bağlayıcı çizgi+ok olarak, şekil dış gölgesiyle çözülür', () {
    final view = PptxEditor.parse(_linePptx()).slides.single.view!;

    final line = view.shapes.firstWhere((s) => s.isLine);
    expect(line.flipV, isTrue);
    expect(line.arrowEnd, isTrue);
    expect(line.arrowStart, isFalse);
    expect(line.stroke, const Color(0xFFFF0000));
    expect(line.strokeWidth, closeTo(1.5, 0.01)); // 19050 EMU / 12700

    final shadowed = view.shapes.firstWhere((s) => s.shadow != null);
    expect(shadowed.shadow!.blurRadius, closeTo(4, 0.01)); // 50800 / 12700
    expect(shadowed.shadow!.offset.distance, greaterThan(0));
  });

  testWidgets('bağlayıcı ve gölgeli şekil hatasız çizilir', (t) async {
    final view = PptxEditor.parse(_linePptx()).slides.single.view!;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
            width: 400, height: 225, child: SlideCanvas(slide: view)),
      ),
    ));
    // Pump hatasız geçtiyse çizim başarılı; şekil metni de görünür.
    expect(find.text('Golge'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets); // çizgi painter'ı var
  });

  test('ön tanımlı geometri ve avLst ayarları çözülür', () {
    final view = PptxEditor.parse(_geometryPptx()).slides.single.view!;
    ShapeVM byName(String preset) =>
        view.shapes.firstWhere((s) => s.preset == preset);

    // Yol olarak çizilecek şekiller preset adını taşır.
    final ok = byName('rightArrow');
    expect(ok.isBoxShaped, isFalse);
    expect(ok.adjust['adj1'], 30000);
    expect(ok.adjust['adj2'], 70000);
    expect(byName('diamond').isBoxShaped, isFalse);
    expect(byName('ellipse').isBoxShaped, isFalse);

    // roundRect dikdörtgen ailesindedir: yarıçapa çözülür (adj=50000 →
    // kısa kenarın yarısı = 100pt / 2 = 50pt).
    final yuvarlak =
        view.shapes.firstWhere((s) => s.cornerRadius > 0);
    expect(yuvarlak.isBoxShaped, isTrue);
    expect(yuvarlak.cornerRadius, closeTo(50, 0.01));

    // Tanınmayan geometri sessizce dikdörtgene düşer (yanlış çizmektense kutu).
    expect(view.shapes.where((s) => s.preset == 'funkyShapeXyz'), isEmpty);
    expect(view.shapes.where((s) => s.isBoxShaped).length, 2);
  });

  testWidgets('ön tanımlı şekiller yol olarak hatasız çizilir', (t) async {
    final view = PptxEditor.parse(_geometryPptx()).slides.single.view!;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 225, child: SlideCanvas(slide: view)),
      ),
    ));
    expect(t.takeException(), isNull);
    expect(find.text('Ok'), findsOneWidget);
    expect(find.text('Elmas'), findsOneWidget);
  });

  test('görsel kırpması (a:srcRect) oran olarak okunur', () {
    final view = PptxEditor.parse(_croppedPicPptx()).slides.single.view!;
    final pics = view.shapes.where((s) => s.image != null).toList();
    expect(pics.length, 2);

    final cropped = pics.firstWhere((s) => s.crop != null);
    expect(cropped.crop!.left, closeTo(0.10, 1e-6));
    expect(cropped.crop!.top, closeTo(0.25, 1e-6));
    expect(cropped.crop!.right, closeTo(0.05, 1e-6));
    expect(cropped.crop!.bottom, 0);
    // Elips çerçeveli fotoğraf yol olarak kırpılır.
    expect(cropped.isBoxShaped, isFalse);

    // srcRect yoksa kırpma da yok (gereksiz sarmalayıcı kurulmasın).
    expect(pics.firstWhere((s) => s.isBoxShaped).crop, isNull);
  });

  testWidgets('görselin çerçevesi görselin ÜSTÜNE çizilir', (t) async {
    // Kenarlık arka plan süslemesinde kalırsa görselin altında kaybolur;
    // PowerPoint'te çerçeveli fotoğrafın çerçevesi bizde görünmüyordu.
    final view = PptxEditor.parse(_croppedPicPptx()).slides.single.view!;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 225, child: SlideCanvas(slide: view)),
      ),
    ));
    expect(t.takeException(), isNull);

    // Kutu (dikdörtgen) görsel: çerçeve ARKA plan süslemesinde OLMAMALI,
    // ön plan süslemesinde olmalı.
    final frames = t
        .widgetList<Container>(find.byType(Container))
        .where((c) => (c.foregroundDecoration as BoxDecoration?)?.border != null)
        .toList();
    expect(frames, isNotEmpty, reason: 'kutu görselin çerçevesi ön planda değil');
    for (final c in frames) {
      expect((c.decoration as BoxDecoration?)?.border, isNull,
          reason: 'çerçeve hem arka hem ön planda');
    }

    // Yol tabanlı (elips) görsel: kenarlık ön plan painter'ıyla çizilir.
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null),
      findsWidgets,
    );
  });

  test('tema stil referansı (p:style) dolgu ve çizgi rengini çözer', () {
    // spPr boş; renk yalnız p:style>a:fillRef/a:lnRef içinde. Eskiden şekil
    // dolgusuz/şeffaf çiziliyordu (en büyük tekil sadakat kaybı).
    final view = PptxEditor.parse(_styleRefPptx()).slides.single.view!;
    final shape = view.shapes.single;
    expect(shape.fill, const Color(0xFF00AAFF)); // fillRef
    expect(shape.stroke, const Color(0xFF112233)); // lnRef
    expect(shape.strokeWidth, closeTo(0.75, 0.001)); // tema minör çizgi varsayılanı
  });

  test('mutlak satır aralığı (spcPts) çarpana, spcAft puntoya çözülür', () {
    final view = PptxEditor.parse(_spacingPptx()).slides.single.view!;
    final para = view.shapes.single.paragraphs.single;
    expect(para.lineHeight, closeTo(2.0, 0.001)); // 30pt / 15pt yazı
    expect(para.spaceAfterPt, closeTo(6.0, 0.001)); // 600 / 100
  });

  test('tablo hücresi kenar-başına kenarlık taşır (yalnız tanımlı kenarlar)', () {
    final view = PptxEditor.parse(_tablePptx()).slides.single.view!;
    final cell = view.shapes.firstWhere((s) => s.cellBorder != null);
    final b = cell.cellBorder!;
    expect(b.left.color, const Color(0xFFFF0000));
    expect(b.left.width, closeTo(1.0, 0.001)); // 12700 EMU
    expect(b.bottom.color, const Color(0xFF0000FF));
    expect(b.bottom.width, closeTo(2.0, 0.001)); // 25400 EMU
    expect(b.right, BorderSide.none); // tanımsız kenar çizilmez
    expect(b.top, BorderSide.none);
  });

  test('grafik parçası çözülür: tür, seri, kategori, değerler', () {
    final view = PptxEditor.parse(_chartPptx()).slides.single.view!;
    final ch = view.shapes.firstWhere((s) => s.chart != null).chart!;

    expect(ch.type, ChartType.column);
    expect(ch.series.length, 2);
    expect(ch.categories, ['Oca', 'Sub', 'Mar']);
    expect(ch.series[0].name, 'Seri A');
    expect(ch.series[0].values, [3, 5, 2]);
    expect(ch.series[1].name, 'Seri B');
    expect(ch.series[1].values, [4, 1, 6]);
    expect(ch.showLegend, isTrue);
  });

  testWidgets('grafik slaytı hatasız çizilir', (t) async {
    final view = PptxEditor.parse(_chartPptx()).slides.single.view!;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
            width: 500, height: 300, child: SlideCanvas(slide: view)),
      ),
    ));
    // Grafik CustomPaint olarak çizilir (pump hatasızsa geometri sağlam).
    expect(find.byType(CustomPaint), findsWidgets);
  });

  test('animasyon adımları p:timing içinden çıkarılır', () {
    final view = PptxEditor.parse(_samplePptx()).slides.single.view!;

    expect(view.steps.length, 1);
    expect(view.steps.single, contains(const AnimTarget(2)));
    expect(view.stepFor(2, -1), 1); // 2 numaralı şekil 1. tıklamada belirir
    expect(view.stepFor(99, 0), 0); // animasyonu olmayan şekil baştan görünür
  });

  testWidgets('sunumda adımı gelmemiş içerik saydamdır', (t) async {
    final view = PptxEditor.parse(_samplePptx()).slides.single.view!;

    Future<double> opacityOf(int step) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SlideCanvas(slide: view, step: step)),
      ));
      await t.pumpAndSettle();
      return t
          .widget<AnimatedOpacity>(find
              .ancestor(
                of: find.text('Merhaba'),
                matching: find.byType(AnimatedOpacity),
              )
              .first)
          .opacity;
    }

    expect(await opacityOf(0), 0); // henüz tıklanmadı -> görünmez
    expect(await opacityOf(1), 1); // tıklandı -> belirir
  });

  testWidgets('SlideCanvas slaytı hatasız çizer ve dokunuşu iletir', (t) async {
    final view = PptxEditor.parse(_samplePptx()).slides.single.view!;
    ShapeVMTapped? tapped;

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 225,
          child: SlideCanvas(
            slide: view,
            onEditShape: (s) => tapped = ShapeVMTapped(s.paragraphs.first.plainText),
          ),
        ),
      ),
    ));

    expect(find.text('Merhaba'), findsOneWidget);
    expect(find.text('Grup'), findsOneWidget);

    await t.tap(find.text('Merhaba'));
    expect(tapped?.text, 'Merhaba');
  });

  testWidgets('normAutofit taşan yazıyı kutuya sığacak şekilde küçültür',
      (t) async {
    final view = PptxEditor.parse(_autofitPptx()).slides.single.view!;
    final shape = view.shapes.single;
    expect(shape.autofit, isTrue);
    expect(shape.lnSpcReduction, closeTo(0.1, 0.001));

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 225,
          child: SlideCanvas(slide: view),
        ),
      ),
    ));

    // Çizilen span'in efektif punto boyutu, bildirilen 32pt'nin altına inmeli.
    final rich = t.widget<RichText>(find
        .byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains('Uzun'))
        .first);
    double? found;
    rich.text.visitChildren((span) {
      if (span is TextSpan &&
          (span.text ?? '').contains('Uzun') &&
          span.style?.fontSize != null) {
        found = span.style!.fontSize;
        return false;
      }
      return true;
    });
    expect(found, isNotNull);
    expect(found!, lessThan(32));
  });

  testWidgets('autofit OLMAYAN düz kutuda da taşan yazı sığdırılır (kök #3)',
      (t) async {
    final view =
        PptxEditor.parse(_autofitPptx(withAutofit: false)).slides.single.view!;
    final shape = view.shapes.single;
    expect(shape.autofit, isFalse);
    expect(shape.isPlaceholder, isFalse);

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 225,
          child: SlideCanvas(slide: view),
        ),
      ),
    ));

    final rich = t.widget<RichText>(find
        .byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains('Uzun'))
        .first);
    double? found;
    rich.text.visitChildren((span) {
      if (span is TextSpan &&
          (span.text ?? '').contains('Uzun') &&
          span.style?.fontSize != null) {
        found = span.style!.fontSize;
        return false;
      }
      return true;
    });
    expect(found, isNotNull);
    expect(found!, lessThan(32));
  });
}

class ShapeVMTapped {
  final String text;
  ShapeVMTapped(this.text);
}

/// Konuşmacı notu olan bir slayt: not sayfasında hem `body` (asıl not) hem de
/// `sldNum` (sayfa numarası) yer tutucusu var — PowerPoint her not sayfasına
/// ikisini de koyar.
Uint8List _notesPptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add('ppt/presentation.xml',
      '<p:presentation xmlns:p="ppt"><p:sldSz cx="9144000" cy="6858000"/>'
      '</p:presentation>');
  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw"><p:cSld><p:spTree>
 <p:sp><p:spPr/><p:txBody><a:bodyPr/><a:p><a:r><a:t>Slayt</a:t></a:r></a:p>
 </p:txBody></p:sp>
</p:spTree></p:cSld></p:sld>
''');
  add('ppt/slides/_rels/slide1.xml.rels', '''
<Relationships xmlns="rel">
 <Relationship Id="rId1"
   Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide"
   Target="../notesSlides/notesSlide1.xml"/>
</Relationships>
''');
  add('ppt/notesSlides/notesSlide1.xml', '''
<p:notes xmlns:p="ppt" xmlns:a="draw"><p:cSld><p:spTree>
 <p:sp>
  <p:nvSpPr><p:cNvPr id="2"/><p:nvPr><p:ph type="sldNum"/></p:nvPr></p:nvSpPr>
  <p:txBody><a:bodyPr/><a:p><a:r><a:t>7</a:t></a:r></a:p></p:txBody>
 </p:sp>
 <p:sp>
  <p:nvSpPr><p:cNvPr id="3"/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>
  <p:txBody><a:bodyPr/>
   <a:p><a:r><a:t>Bütçeyi </a:t></a:r><a:r><a:t>anlat</a:t></a:r></a:p>
   <a:p><a:r><a:t>Soruları sona bırak</a:t></a:r></a:p>
  </p:txBody>
 </p:sp>
</p:spTree></p:cSld></p:notes>
''');
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void _notesTests() {
  test('konuşmacı notu okunur; sayfa numarası yer tutucusu notun içine karışmaz',
      () {
    final editor = PptxEditor.parse(_notesPptx());
    final notes = editor.notesOf(editor.slides.single);
    expect(notes, 'Bütçeyi anlat\nSoruları sona bırak');
    expect(notes, isNot(contains('7')));
  });

  test('notu olmayan slaytta boş metin döner', () {
    final editor = PptxEditor.parse(_samplePptx());
    expect(editor.notesOf(editor.slides.single), isEmpty);
  });
}
