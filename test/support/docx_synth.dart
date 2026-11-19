import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// **Sentetik Word belgesi** (B9 — örnek belge KVKK gereği depoya girmez):
/// [body] `w:body` içeriği (bölüm özellikleri kendiliğinden eklenir);
/// [parts] ek parçalar (ad → içerik), [rels] `document.xml.rels`e ek
/// ilişkiler, [types] `[Content_Types].xml`e ek satırlar.
Uint8List synthDocx(
  String body, {
  Map<String, String> parts = const {},
  Map<String, List<int>> binParts = const {},
  String rels = '',
  String types = '',
}) {
  const ns = 'xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas" '
      'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" '
      'xmlns:o="urn:schemas-microsoft-com:office:office" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" '
      'xmlns:v="urn:schemas-microsoft-com:vml" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:w10="urn:schemas-microsoft-com:office:word" '
      'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" '
      'xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml" '
      'xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" '
      'xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" '
      'xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" '
      'mc:Ignorable="w14 w15"';
  final files = <String, List<int>>{
    '[Content_Types].xml': utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Default Extension="png" ContentType="image/png"/>'
        '<Default Extension="bin" ContentType="application/vnd.openxmlformats-officedocument.oleObject"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '$types</Types>'),
    '_rels/.rels': utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>'),
    'word/_rels/document.xml.rels': utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rels</Relationships>'),
    'word/document.xml': utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:document $ns><w:body>$body'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" '
        'w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>'
        '</w:body></w:document>'),
    for (final MapEntry(:key, :value) in parts.entries) key: utf8.encode(value),
    ...binParts,
  };
  final out = Archive();
  for (final MapEntry(:key, :value) in files.entries) {
    out.addFile(ArchiveFile(key, value.length, value));
  }
  return Uint8List.fromList(ZipEncoder().encode(out));
}

/// Paketten bir parçanın metni.
String synthPart(List<int> bytes, String name) => utf8.decode(ZipDecoder()
    .decodeBytes(bytes)
    .files
    .firstWhere((f) => f.name == name)
    .content as List<int>);

/// `<w:p>` … `</w:p>` (tek paragraf, düz run'lar).
String synthP(String text, {String rPr = '', String pPr = ''}) =>
    '<w:p>${pPr.isEmpty ? '' : '<w:pPr>$pPr</w:pPr>'}<w:r>'
    '${rPr.isEmpty ? '' : '<w:rPr>$rPr</w:rPr>'}'
    '<w:t xml:space="preserve">$text</w:t></w:r></w:p>';
