import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/office_reader.dart';
import 'package:dosya_okuyucu/services/udf_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// P23: sentetik UYAP belgesi (gerçek kişi/dava verisi YOK — KVKK).
/// Biçim, kullanıcı örneğinden çözülen yapıyla aynı (HAFIZA 2026-11-15).
const _text = 'ÖRNEK MAHKEMESİ\nDosya No: 0000/1\nAd\tSoyad\nAli\tVeli\n\n';

// 1×1 saydam PNG.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

String _contentXml({String body = ''}) => '''<?xml version="1.0" encoding="UTF-8"?>
<template format_id="1.8">
<content><![CDATA[$_text]]></content>
<properties><pageFormat mediaSizeName="1" leftMargin="42.5" rightMargin="42.5" topMargin="42.5" bottomMargin="42.5" paperOrientation="1"/></properties>
<elements resolver="hvl-default">
$body
</elements>
<styles><style name="hvl-default" family="Times New Roman" size="12"/></styles>
</template>''';

const _body = '''
<paragraph Alignment="1"><content startOffset="0" length="16" bold="true" size="14" family="Times New Roman"/></paragraph>
<paragraph Alignment="3" FirstLineIndent="35.4"><content startOffset="16" length="17" italic="true" foreground="-65536"/></paragraph>
<table tableName="Tablo" columnCount="2" columnSpans="100,200" border="borderCell">
<row rowName="r1"><cell><paragraph><content startOffset="33" length="2"/></paragraph></cell><cell><paragraph><content startOffset="36" length="6"/></paragraph></cell></row>
<row rowName="r2"><cell><paragraph><content startOffset="42" length="3"/></paragraph></cell><cell><paragraph><content startOffset="46" length="5"/></paragraph></cell></row>
</table>
<paragraph><image imageData="$_png" width="40" height="20"/><content startOffset="51" length="1"/></paragraph>
''';

Uint8List _udf(String contentXml) {
  final a = Archive();
  final data = utf8.encode(contentXml);
  a.addFile(ArchiveFile('content.xml', data.length, data));
  final props = utf8.encode('<properties/>');
  a.addFile(ArchiveFile('documentproperties.xml', props.length, props));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

String _docXml(Uint8List docx) {
  final zip = ZipDecoder().decodeBytes(docx);
  return utf8.decode(
      zip.files.firstWhere((f) => f.name == 'word/document.xml').content
          as List<int>);
}

void main() {
  test('biçim, tablo ve görsel Word paketine geçer', () {
    final docx = UdfReader.toDocx(_udf(_contentXml(body: _body)));
    final xml = _docXml(docx);
    expect(xml, contains('<w:jc w:val="center"/>'));
    expect(xml, contains('<w:jc w:val="both"/>'));
    expect(xml, contains('<w:b/>'));
    expect(xml, contains('<w:i/>'));
    expect(xml, contains('<w:color w:val="FF0000"/>'));
    expect(xml, contains('<w:sz w:val="28"/>')); // 14 pt
    expect(xml, contains('w:firstLine="708"'));
    expect(xml, contains('<w:tbl>'));
    expect('<w:tr>'.allMatches(xml).length, 2);
    expect(xml, contains('<wp:extent cx="508000" cy="254000"/>'));

    final zip = ZipDecoder().decodeBytes(docx);
    expect(zip.files.map((f) => f.name), contains('word/media/udf1.png'));

    // Word okuyucusunun ayrıştırıcıları belgeyi açar, metin tam.
    final text = OfficeReader.extractDocxText(docx);
    expect(text, contains('ÖRNEK MAHKEMESİ'));
    expect(text, contains('Dosya No: 0000/1'));
    expect(text, contains('Veli'));
    expect(DocxEditor.parse(docx).paragraphs, isNotEmpty);
  });

  test('biçim öğesi yoksa metin satır satır gelir', () {
    final docx = UdfReader.toDocx(_udf(_contentXml()));
    expect(OfficeReader.extractDocxText(docx), contains('Dosya No: 0000/1'));
    expect(_docXml(docx), contains('<w:tab/>')); // "Ad<sekme>Soyad"
    expect(UdfReader.plainText(_udf(_contentXml())), startsWith('ÖRNEK'));
  });

  test('bozuk / şifreli / içeriksiz dosya anlaşılır hata verir', () {
    UdfFailure? kind(Uint8List b) {
      try {
        UdfReader.toDocx(b);
        return null;
      } on UdfError catch (e) {
        return e.kind;
      }
    }

    expect(kind(Uint8List.fromList(utf8.encode('bu bir zip değil, düz yazı'))),
        UdfFailure.corrupt);

    final noContent = Archive();
    noContent.addFile(ArchiveFile('baska.xml', 4, utf8.encode('<a/>')));
    expect(kind(Uint8List.fromList(ZipEncoder().encode(noContent))),
        UdfFailure.corrupt);

    expect(kind(_udf('<html>yanlış kök</html>')), UdfFailure.corrupt);

    final enc = _udf(_contentXml())..[6] |= 1; // ZIP "şifreli" bayrağı
    expect(kind(enc), UdfFailure.encrypted);

    expect(UdfReader.plainText(Uint8List(10)), '');
  });
}
