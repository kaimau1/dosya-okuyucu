import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Küçük ama gerçek bir .docx: 2 paragraf, ilki stilli (Heading1) ve renkli run'lı.
Uint8List _sampleDocx() {
  final archive = Archive();
  const xml = '''
<w:document xmlns:w="word">
 <w:body>
  <w:p>
   <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
   <w:r><w:rPr><w:color w:val="FF0000"/></w:rPr><w:t>Eski</w:t></w:r>
   <w:r><w:t> metin</w:t></w:r>
  </w:p>
  <w:p><w:r><w:t>İkinci</w:t></w:r></w:p>
 </w:body>
</w:document>
''';
  final data = utf8.encode(xml);
  archive.addFile(ArchiveFile('word/document.xml', data.length, data));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('setRuns B/I/U çalıştırmalarını yazar, şablon biçimi ve pPr korunur', () {
    final editor = DocxEditor.parse(_sampleDocx());
    expect(editor.paragraphs.length, 2);
    expect(editor.paragraphs.first.text, 'Eski metin');

    editor.setRuns(0, [
      ('Merhaba ', false, false, false),
      ('dünya', true, false, true),
    ]);
    expect(editor.paragraphs.first.text, 'Merhaba dünya');

    final saved = editor.save();
    final again = DocxEditor.parse(saved);
    expect(again.paragraphs.first.text, 'Merhaba dünya');
    expect(again.paragraphs.first.heading, isTrue); // pPr/pStyle yerinde

    final xml = utf8.decode(
      (ZipDecoder()
              .decodeBytes(saved)
              .files
              .firstWhere((f) => f.name == 'word/document.xml')
              .content as List<int>),
    );
    expect(xml, contains('<w:b/>')); // kalın segment
    expect(xml, contains('w:val="single"')); // altçizgi
    expect(xml, contains('FF0000')); // şablon rPr (renk) kopyalandı
    expect(xml, contains('Heading1'));
  });

  test('rich olmayan paragraf save() ile eski yoldan güncellenir', () {
    final editor = DocxEditor.parse(_sampleDocx());
    editor.setRuns(0, [('Zengin', true, false, false)]);
    editor.paragraphs[1].text = 'Düz değişti';

    final again = DocxEditor.parse(editor.save());
    expect(again.paragraphs[0].text, 'Zengin'); // save() rich'i ezmedi
    expect(again.paragraphs[1].text, 'Düz değişti');
  });
}
