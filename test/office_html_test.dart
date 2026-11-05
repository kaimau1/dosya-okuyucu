import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/office_html.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 39 madde 11 — Office → HTML (PDF'e yazdırma motoru çevirir).
Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((name, xml) {
    final data = utf8.encode(xml);
    a.addFile(ArchiveFile(name, data.length, data));
  });
  return Uint8List.fromList(ZipEncoder().encode(a));
}

const _w = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

void main() {
  test('docx: başlık, kalın, hizalama, tablo, kaçış', () {
    final html = OfficeHtml.docx(_zip({
      'word/document.xml': '<w:document $_w><w:body>'
          '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Giriş</w:t></w:r></w:p>'
          '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Kalın &lt;x&gt;</w:t></w:r></w:p>'
          '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>A1</w:t></w:r></w:p></w:tc>'
          '<w:tc><w:p><w:r><w:t>B1</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
          '</w:body></w:document>',
    }));
    expect(html, contains('<h1>Giriş</h1>'));
    expect(html, contains('<p style="text-align:center"><b>Kalın &lt;x&gt;</b></p>'));
    expect(html, contains('<td><p>A1</p></td><td><p>B1</p></td>'));
  });

  test('xlsx: sayfa adı ve hücreler, sayı sağa', () {
    final xlsx = XlsxWriter.build([
      XlsxWriteSheet(name: 'Gider', cells: {
        0: {0: const XlsxWriteCell(text: 'Kalem'), 1: const XlsxWriteCell(number: 12)},
      }),
    ]);
    final html = OfficeHtml.xlsx(xlsx);
    expect(html, contains('<h2>Gider</h2>'));
    expect(html, contains('<td>Kalem</td>'));
    expect(html, contains('<td class="num">12</td>'));
  });

  test('pptx: slayt sırası sayısal, ilk paragraf başlık', () {
    const a = 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"';
    String slide(String t1, String t2) =>
        '<p:sld $a><p:cSld><p:spTree><p:sp><p:txBody>'
        '<a:p><a:r><a:t>$t1</a:t></a:r></a:p><a:p><a:r><a:t>$t2</a:t></a:r></a:p>'
        '</p:txBody></p:sp></p:spTree></p:cSld></p:sld>';
    final html = OfficeHtml.pptx(_zip({
      'ppt/slides/slide10.xml': slide('Onuncu', 'x'),
      'ppt/slides/slide2.xml': slide('Ikinci', 'madde'),
    }));
    expect(html.indexOf('Ikinci'), lessThan(html.indexOf('Onuncu')));
    expect(html, contains('<h2>Ikinci</h2><p>madde</p>'));
  });
}
