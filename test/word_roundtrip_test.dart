import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/docx_synth.dart';

/// B9 m.6 — **Sadakat bekçisi.** Word'ün bizim çizmediğimiz parçaları
/// (SmartArt, grafik, VML şekil, alan kodu, gömülü nesne,
/// `mc:AlternateContent`, metin kutusu, içerik denetimi) taşıyan sentetik
/// belge (örnek belge KVKK gereği depoya girmez):
/// * dokunmadan kaydet = bütün parçalar baytı baytına aynı;
/// * tek paragraf düzenle = yalnız o `w:p` değişir, öteki parçalar aynı;
/// * egzotik öğenin yanındaki yazı düzenlenince öğe aynen kalır.

const _dgm = 'http://schemas.openxmlformats.org/drawingml/2006/diagram';
const _chartUri = 'http://schemas.openxmlformats.org/drawingml/2006/chart';
const _rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

String _inline(int id, String uri, String data) =>
    '<w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
    '<wp:extent cx="1828800" cy="914400"/><wp:docPr id="$id" name="Nesne $id"/>'
    '<a:graphic><a:graphicData uri="$uri">$data</a:graphicData></a:graphic>'
    '</wp:inline></w:drawing>';

final _body = [
  synthP('Sadakat belgesi', pPr: '<w:pStyle w:val="Heading1"/>'),
  synthP('Düz paragraf: buradaki yazı düzenlenecek.'),
  // SmartArt
  '<w:p><w:r>${_inline(1, _dgm, '<dgm:relIds r:dm="rId10" r:lo="rId11" r:qs="rId12" r:cs="rId13"/>')}</w:r></w:p>',
  // Grafik + yanında yazı
  '<w:p><w:r><w:t xml:space="preserve">Grafik: </w:t></w:r>'
      '<w:r>${_inline(2, _chartUri, '<c:chart r:id="rId20"/>')}</w:r>'
      '<w:r><w:t xml:space="preserve"> satış özeti</w:t></w:r></w:p>',
  // Resim
  '<w:p><w:r>${_inline(3, 'http://schemas.openxmlformats.org/drawingml/2006/picture', '<pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="resim.png"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rId30"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1828800" cy="914400"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>')}</w:r></w:p>',
  // VML şekil
  '<w:p><w:r><w:pict><v:rect id="Dikdortgen 1" style="width:100pt;height:40pt" '
      'fillcolor="#4472c4"><v:textbox><w:txbxContent>${synthP('VML içi yazı')}'
      '</w:txbxContent></v:textbox></v:rect></w:pict></w:r></w:p>',
  // mc:AlternateContent (metin kutusu: wps + VML yedeği)
  '<w:p><w:r><mc:AlternateContent><mc:Choice Requires="wps">'
      '<w:drawing><wp:anchor distT="0" distB="0" distL="114300" distR="114300" '
      'simplePos="0" relativeHeight="1" behindDoc="0" locked="0" layoutInCell="1" '
      'allowOverlap="1"><wp:simplePos x="0" y="0"/><wp:positionH relativeFrom="column">'
      '<wp:posOffset>0</wp:posOffset></wp:positionH><wp:positionV relativeFrom="paragraph">'
      '<wp:posOffset>0</wp:posOffset></wp:positionV><wp:extent cx="1828800" cy="457200"/>'
      '<wp:wrapSquare wrapText="bothSides"/><wp:docPr id="4" name="Metin Kutusu 4"/>'
      '<a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">'
      '<wps:wsp><wps:spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></wps:spPr>'
      '<wps:txbx><w:txbxContent>${synthP('Kutu içi yazı')}</w:txbxContent></wps:txbx>'
      '<wps:bodyPr/></wps:wsp></a:graphicData></a:graphic></wp:anchor></w:drawing>'
      '</mc:Choice><mc:Fallback><w:pict><v:shape id="Kutu 4" style="width:144pt;height:36pt">'
      '<v:textbox><w:txbxContent>${synthP('Kutu içi yazı')}</w:txbxContent></v:textbox>'
      '</v:shape></w:pict></mc:Fallback></mc:AlternateContent></w:r></w:p>',
  // Alan kodları: karmaşık (sayfa) + basit (tarih)
  '<w:p><w:r><w:t xml:space="preserve">Sayfa </w:t></w:r>'
      '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
      '<w:r><w:instrText xml:space="preserve"> PAGE \\* MERGEFORMAT </w:instrText></w:r>'
      '<w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>1</w:t></w:r>'
      '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
      '<w:r><w:t xml:space="preserve"> · </w:t></w:r>'
      '<w:fldSimple w:instr=" DATE \\@ &quot;dd.MM.yyyy&quot; "><w:r><w:t>19.11.2026</w:t></w:r></w:fldSimple></w:p>',
  // Gömülü nesne (OLE)
  '<w:p><w:r><w:object w:dxaOrig="1531" w:dyaOrig="991">'
      '<v:shape id="ole1" type="#_x0000_t75" style="width:76.5pt;height:49.5pt" o:ole="">'
      '<v:imagedata r:id="rId31" o:title=""/></v:shape>'
      '<o:OLEObject Type="Embed" ProgID="Excel.Sheet.12" ShapeID="ole1" '
      'DrawAspect="Icon" ObjectID="_1700000000" r:id="rId40"/></w:object></w:r></w:p>',
  // İçerik denetimi + satır içi onay kutusu
  '<w:sdt><w:sdtPr><w:alias w:val="Bölüm"/><w:id w:val="900"/></w:sdtPr><w:sdtContent>'
      '${synthP('Denetim içi birinci')}${synthP('Denetim içi ikinci')}'
      '</w:sdtContent></w:sdt>',
  '<w:p><w:sdt><w:sdtPr><w:id w:val="901"/><w14:checkbox><w14:checked w14:val="0"/>'
      '<w14:checkedState w14:val="2612" w14:font="MS Gothic"/>'
      '<w14:uncheckedState w14:val="2610" w14:font="MS Gothic"/></w14:checkbox>'
      '</w:sdtPr><w:sdtContent><w:r><w:t>☐</w:t></w:r></w:sdtContent></w:sdt>'
      '<w:r><w:t xml:space="preserve"> Kabul</w:t></w:r></w:p>',
  // Dipnot başvurusu + yer imi + yorum aralığı
  '<w:p><w:bookmarkStart w:id="0" w:name="_Ref1"/><w:commentRangeStart w:id="0"/>'
      '<w:r><w:t>İşaretli yazı</w:t></w:r><w:commentRangeEnd w:id="0"/>'
      '<w:r><w:commentReference w:id="0"/></w:r><w:bookmarkEnd w:id="0"/>'
      '<w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr><w:footnoteReference w:id="1"/></w:r></w:p>',
  synthP('Son paragraf.'),
].join();

const _rels = '<Relationship Id="rId10" Type="$_rel/diagramData" Target="diagrams/data1.xml"/>'
    '<Relationship Id="rId11" Type="$_rel/diagramLayout" Target="diagrams/layout1.xml"/>'
    '<Relationship Id="rId12" Type="$_rel/diagramQuickStyle" Target="diagrams/quickStyle1.xml"/>'
    '<Relationship Id="rId13" Type="$_rel/diagramColors" Target="diagrams/colors1.xml"/>'
    '<Relationship Id="rId20" Type="$_rel/chart" Target="charts/chart1.xml"/>'
    '<Relationship Id="rId30" Type="$_rel/image" Target="media/image1.png"/>'
    '<Relationship Id="rId31" Type="$_rel/image" Target="media/image2.png"/>'
    '<Relationship Id="rId40" Type="$_rel/oleObject" Target="embeddings/oleObject1.bin"/>'
    '<Relationship Id="rId50" Type="$_rel/footnotes" Target="footnotes.xml"/>'
    '<Relationship Id="rId51" Type="$_rel/comments" Target="comments.xml"/>';

const _wNs = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

final _parts = <String, String>{
  'word/diagrams/data1.xml':
      '<dgm:dataModel xmlns:dgm="$_dgm"><dgm:ptLst><dgm:pt modelId="{0}" type="doc"/></dgm:ptLst></dgm:dataModel>',
  'word/diagrams/layout1.xml': '<dgm:layoutDef xmlns:dgm="$_dgm" uniqueId="urn:basic"/>',
  'word/diagrams/quickStyle1.xml': '<dgm:styleDef xmlns:dgm="$_dgm" uniqueId="urn:simple1"/>',
  'word/diagrams/colors1.xml': '<dgm:colorsDef xmlns:dgm="$_dgm" uniqueId="urn:accent1"/>',
  'word/charts/chart1.xml':
      '<c:chartSpace xmlns:c="$_chartUri"><c:chart><c:plotArea><c:layout/></c:plotArea></c:chart>'
          '<c:externalData r:id="rId1" xmlns:r="$_rel"/></c:chartSpace>',
  'word/charts/_rels/chart1.xml.rels':
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="$_rel/package" Target="../embeddings/Microsoft_Excel_Worksheet.xlsx"/></Relationships>',
  'word/footnotes.xml': '<w:footnotes $_wNs><w:footnote w:id="1">${synthP('Dipnot metni')}</w:footnote></w:footnotes>',
  'word/comments.xml': '<w:comments $_wNs><w:comment w:id="0" w:author="Yazar" w:date="2026-11-19T00:00:00Z">'
      '${synthP('Yorum metni')}</w:comment></w:comments>',
};

final _bin = <String, List<int>>{
  'word/media/image1.png': [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3],
  'word/media/image2.png': [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 4, 5, 6],
  'word/embeddings/oleObject1.bin': List.generate(64, (i) => (i * 37) & 0xff),
  'word/embeddings/Microsoft_Excel_Worksheet.xlsx': List.generate(48, (i) => (i * 11) & 0xff),
};

Map<String, List<int>> _all(List<int> b) => {
      for (final f in ZipDecoder().decodeBytes(b).files)
        if (f.isFile) f.name: f.content as List<int>,
    };

List<String> _paraXml(List<int> b) => [
      for (final p in XmlDocument.parse(synthPart(b, 'word/document.xml'))
          .findAllElements('w:p'))
        p.toXmlString(),
    ];

/// Belgedeki egzotik öğelerin XML'i (tür → dizeler).
Map<String, List<String>> _exotic(List<int> b) {
  final x = XmlDocument.parse(synthPart(b, 'word/document.xml'));
  return {
    for (final name in const [
      'w:drawing', 'w:pict', 'w:object', 'mc:AlternateContent', 'w:fldSimple',
      'w:fldChar', 'w:instrText', 'w:sdt', 'w:bookmarkStart', 'w:commentReference',
      'w:footnoteReference',
    ])
      name: [for (final e in x.findAllElements(name)) e.toXmlString()],
  };
}

void main() {
  final bytes = synthDocx(_body,
      parts: _parts,
      binParts: _bin,
      rels: _rels,
      types: '<Override PartName="/word/charts/chart1.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>');
  final before = _all(bytes);

  test('korpus okunur: her egzotik öğe yerinde ve sayıları tam', () {
    final d = DocxDocument.parse(bytes);
    expect(d.paras.map((p) => p.text).first, 'Sadakat belgesi');
    expect(d.paras.any((p) => p.text == 'Denetim içi ikinci'), isTrue);
    final ex = _exotic(bytes);
    expect(ex['w:drawing'], hasLength(4));
    expect(ex['mc:AlternateContent'], hasLength(1));
    expect(ex['w:fldChar'], hasLength(3));
  });

  test('dokunmadan kaydet: bütün parçalar baytı baytına aynı', () {
    final d = DocxDocument.parse(bytes);
    final viaModel = _all(d.save());
    expect(viaModel.keys.toSet(), before.keys.toSet());
    for (final k in before.keys) {
      expect(viaModel[k], before[k], reason: k);
    }
    expect(d.xmlDirty, isFalse);
    final viaPkg = _all(DocxPackage.open(bytes).save());
    for (final k in before.keys) {
      expect(viaPkg[k], before[k], reason: 'paket: $k');
    }
  });

  test('tek paragraf düzenle: yalnız o w:p değişir, öteki parçalar aynı', () {
    final d = DocxDocument.parse(bytes);
    final i = d.paras.indexWhere((p) => p.text.startsWith('Düz paragraf'));
    final p = d.paras[i];
    d.paras[i] = p.replace(0, 3, 'Sade', p.typingStyleAt(0));
    final out = d.save();
    final after = _all(out);
    expect(after.keys.toSet(), before.keys.toSet());
    for (final k in before.keys) {
      if (k == 'word/document.xml') continue;
      expect(after[k], before[k], reason: k);
    }
    final a = _paraXml(bytes), b = _paraXml(out);
    expect(b, hasLength(a.length));
    final changed = [
      for (var k = 0; k < a.length; k++)
        if (a[k] != b[k]) k,
    ];
    expect(changed, hasLength(1));
    expect(b[changed.single], contains('Sade paragraf'));
    expect(_exotic(out), _exotic(bytes));
    expect(utf8.decode(after['word/document.xml']!),
        isNot(utf8.decode(before['word/document.xml']!)));
  });

  test('egzotik öğenin yanındaki yazı düzenlenince öğe aynen kalır', () {
    final d = DocxDocument.parse(bytes);
    for (final start in ['Grafik', 'Sayfa', 'İşaretli']) {
      final i = d.paras.indexWhere((p) => p.text.startsWith(start));
      final p = d.paras[i];
      d.paras[i] = p.replace(0, 0, 'Yeni ', p.typingStyleAt(0));
    }
    final out = d.save();
    expect(_exotic(out), _exotic(bytes));
    final back = DocxDocument.parse(out);
    expect(back.paras.where((p) => p.text.startsWith('Yeni ')), hasLength(3));
    // İkinci tur: yeniden açıp el değmeden kaydetmek bir şey değiştirmez.
    expect(synthPart(back.save(), 'word/document.xml'),
        synthPart(out, 'word/document.xml'));
  });

  test('denetimi doldur + paragraf ekle: egzotik öğeler yine aynı', () {
    final d = DocxDocument.parse(bytes);
    final i = d.paras.indexWhere((p) => p.text.endsWith(' Kabul'));
    final k = d.paras[i].atoms.indexWhere((a) => a?.kind == DocxAtomKind.control);
    d.paras[i] = d.fillControl(d.paras[i], k, checked: true);
    final j = d.paras.indexWhere((p) => p.text == 'Denetim içi ikinci');
    final (l, r) = d.paras[j].split(d.paras[j].length);
    d.paras
      ..[j] = l
      ..insert(j + 1, r.replace(0, 0, 'Denetim içi üçüncü', r.mark));
    final out = d.save();
    final ex = _exotic(out), was = _exotic(bytes);
    for (final name in was.keys) {
      if (name == 'w:sdt') continue;
      expect(ex[name], was[name], reason: name);
    }
    final x = XmlDocument.parse(synthPart(out, 'word/document.xml'));
    final sdt = x.findAllElements('w:sdt').first;
    expect(sdt.findAllElements('w:p').map((p) => p.innerText),
        ['Denetim içi birinci', 'Denetim içi ikinci', 'Denetim içi üçüncü']);
    expect(x.findAllElements('w14:checked').single.getAttribute('w14:val'), '1');
  });
}
