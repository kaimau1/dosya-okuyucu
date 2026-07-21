import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Küçük ama gerçek bir .docx üretir: bir başlık, bir kalın paragraf, bir normal
/// paragraf ve bölüm özellikleri (`<w:sectPr>` her zaman en sonda olmalı).
Uint8List _sampleDocx() {
  const doc = '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:body>
  <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Başlık</w:t></w:r></w:p>
  <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Kalın satır</w:t></w:r></w:p>
  <w:p><w:r><w:t>Normal</w:t></w:r></w:p>
  <w:sectPr/>
 </w:body>
</w:document>''';
  final archive = Archive();
  final data = utf8.encode(doc);
  archive.addFile(ArchiveFile('word/document.xml', data.length, data));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('başlık ve kalın bayrağı ayrıştırılır', () {
    final e = DocxEditor.parse(_sampleDocx());
    expect(e.paragraphs.length, 3);
    expect(e.paragraphs[0].heading, isTrue);
    expect(e.paragraphs[0].text, 'Başlık');
    expect(e.paragraphs[1].bold, isTrue);
    expect(e.paragraphs[2].bold, isFalse);
    expect(e.paragraphs[2].align, 'left');
  });

  test('italik açılınca kaydedilir ve geri okunur', () {
    final e = DocxEditor.parse(_sampleDocx());
    e.paragraphs[2].italic = true;

    final saved = e.save();
    expect(utf8.decode(_docXml(saved)), contains('<w:i'));

    final again = DocxEditor.parse(saved);
    expect(again.paragraphs[2].italic, isTrue);
  });

  test('kalın kapatılınca w:b düğümü kalkar', () {
    final e = DocxEditor.parse(_sampleDocx());
    expect(e.paragraphs[1].bold, isTrue);
    e.paragraphs[1].bold = false;

    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs[1].bold, isFalse);
  });

  test('hizalama değişikliği <w:jc> olarak yazılır', () {
    final e = DocxEditor.parse(_sampleDocx());
    e.paragraphs[2].align = 'center';

    final saved = e.save();
    expect(utf8.decode(_docXml(saved)), contains('w:jc'));

    final again = DocxEditor.parse(saved);
    expect(again.paragraphs[2].align, 'center');
  });

  test('paragraf eklenir ve sectPr en sonda kalır', () {
    final e = DocxEditor.parse(_sampleDocx());
    final added = e.addParagraphAfter(e.paragraphs[2]);
    added.text = 'Eklenen';

    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs.length, 4);
    expect(again.paragraphs[3].text, 'Eklenen');
    // sectPr paragraf sayılmaz ama belgede bulunmalı (bozulmadı).
    expect(utf8.decode(_docXml(e.save())), contains('w:sectPr'));
  });

  test('paragraf silinir', () {
    final e = DocxEditor.parse(_sampleDocx());
    e.deleteParagraph(e.paragraphs[1]);

    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs.length, 2);
    expect(again.paragraphs.map((p) => p.text), ['Başlık', 'Normal']);
  });

  test('metin düzenlemesi biçimi bozmadan yazılır', () {
    final e = DocxEditor.parse(_sampleDocx());
    e.paragraphs[1].text = 'Değişti';

    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs[1].text, 'Değişti');
    expect(again.paragraphs[1].bold, isTrue); // kalınlık korunur
  });
}

/// Kaydedilen .docx içinden word/document.xml byte'larını çıkarır.
List<int> _docXml(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return archive.files
      .firstWhere((f) => f.name == 'word/document.xml')
      .content as List<int>;
}
