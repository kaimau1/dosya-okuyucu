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

/// setRuns testleri için: renkli run'lı (şablon rPr) 2 paragraflık örnek.
Uint8List _richSampleDocx() {
  const doc = '''
<w:document xmlns:w="word">
 <w:body>
  <w:p>
   <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
   <w:r><w:rPr><w:color w:val="FF0000"/></w:rPr><w:t>Eski</w:t></w:r>
   <w:r><w:t> metin</w:t></w:r>
  </w:p>
  <w:p><w:r><w:t>İkinci</w:t></w:r></w:p>
 </w:body>
</w:document>''';
  final archive = Archive();
  final data = utf8.encode(doc);
  archive.addFile(ArchiveFile('word/document.xml', data.length, data));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  // --- Canlı düzenleme (setRuns) -------------------------------------------
  test('setRuns B/I/U çalıştırmalarını yazar, şablon biçimi ve pPr korunur', () {
    final editor = DocxEditor.parse(_richSampleDocx());
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

    final xml = utf8.decode(_docXml(saved));
    expect(xml, contains('<w:b/>')); // kalın segment
    expect(xml, contains('w:val="single"')); // altçizgi
    expect(xml, contains('FF0000')); // şablon rPr (renk) kopyalandı
    expect(xml, contains('Heading1'));
  });

  test('segment içindeki satır sonu w:br olarak yazılır', () {
    final editor = DocxEditor.parse(_richSampleDocx());
    editor.setRuns(0, [('üst\nalt', false, false, false)]);

    final saved = editor.save();
    expect(utf8.decode(_docXml(saved)), contains('<w:br/>'));
    expect(DocxEditor.parse(saved).paragraphs.first.text, 'üstalt');
  });

  test('rich olmayan paragraf save() ile eski yoldan güncellenir', () {
    final editor = DocxEditor.parse(_richSampleDocx());
    editor.setRuns(0, [('Zengin', true, false, false)]);
    editor.paragraphs[1].text = 'Düz değişti';

    final again = DocxEditor.parse(editor.save());
    expect(again.paragraphs[0].text, 'Zengin'); // save() rich'i ezmedi
    expect(again.paragraphs[1].text, 'Düz değişti');
  });

  // --- Paragraf bazlı biçim / yapı (yedek editör) --------------------------
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

  test('yalnız hizalama değişince run biçimleri (karma B/I/U) ezilmez', () {
    final e = DocxEditor.parse(_sampleDocx());
    e.paragraphs[2].align = 'center'; // 'Normal' paragrafı — sadece hizalama

    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs[2].align, 'center');
    expect(again.paragraphs[2].bold, isFalse); // b/i/u eklenmedi
    expect(again.paragraphs[1].bold, isTrue); // komşu paragraf el değmedi
  });

  test('rich (canlı yazılmış) paragrafta hizalama da kaydedilir', () {
    final e = DocxEditor.parse(_richSampleDocx());
    e.setRuns(0, [('Merhaba', true, false, false)]);
    e.paragraphs[0].align = 'right'; // canlı hizalama düğmesinin yolu

    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs[0].text, 'Merhaba');
    expect(again.paragraphs[0].align, 'right');
    expect(again.paragraphs[0].bold, isTrue); // setRuns'ın B'si korunur
  });

  test('el değmeyen paragrafın run yapısı save sonrası aynı kalır', () {
    final e = DocxEditor.parse(_richSampleDocx());
    e.paragraphs[1].text = 'Sadece bu değişti';

    final xml = utf8.decode(_docXml(e.save()));
    // 1. paragrafa dokunulmadı: iki ayrı run (renkli 'Eski' + ' metin') duruyor.
    expect(xml, contains('<w:t>Eski</w:t>'));
    expect(xml, contains('FF0000'));
  });
}

/// Kaydedilen .docx içinden word/document.xml byte'larını çıkarır.
List<int> _docXml(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return archive.files
      .firstWhere((f) => f.name == 'word/document.xml')
      .content as List<int>;
}
