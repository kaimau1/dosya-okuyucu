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

/// İçerik türü ve ilişki dosyası OLAN tam bir .docx (numaralandırma yazma
/// yolu bu üç parçaya birden dokunuyor).
Uint8List _fullDocx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add('[Content_Types].xml', '''
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''');
  add('word/_rels/document.xml.rels', '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''');
  add('word/document.xml', '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:body>
  <w:p><w:r><w:t>Birinci</w:t></w:r></w:p>
  <w:p><w:r><w:t>İkinci</w:t></w:r></w:p>
 </w:body>
</w:document>''');
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _part(Uint8List bytes, String name) {
  final f = ZipDecoder()
      .decodeBytes(bytes)
      .files
      .where((f) => f.name == name)
      .toList();
  return f.isEmpty ? '' : utf8.decode(f.first.content as List<int>);
}

void main() {
  // --- Yazı rengi / vurgu ---------------------------------------------------
  test('setRuns yazı rengini ve ADLANDIRILMIŞ vurguyu yazar', () {
    final editor = DocxEditor.parse(_richSampleDocx());
    editor.setRuns(0, const [
      RunSeg('renkli', false, false, false, color: '0070C0', highlight: 'FFFF00'),
    ]);
    final xml = _part(editor.save(), 'word/document.xml');
    expect(xml, contains('<w:color w:val="0070C0"/>'));
    // Word'ün fosforlu kalemi ada göre yazılır; keyfi renk `w:shd`ye düşer.
    expect(xml, contains('<w:highlight w:val="yellow"/>'));
  });

  test('palette olmayan vurgu w:shd dolgusu olarak yazılır', () {
    final editor = DocxEditor.parse(_richSampleDocx());
    editor.setRuns(0, const [
      RunSeg('renkli', false, false, false, highlight: 'FCE4D6'),
    ]);
    final xml = _part(editor.save(), 'word/document.xml');
    expect(xml, isNot(contains('<w:highlight')));
    expect(xml, contains('w:fill="FCE4D6"'));
  });

  test('renk verilmezse şablonun kendi rengi KORUNUR', () {
    final editor = DocxEditor.parse(_richSampleDocx());
    editor.setRuns(0, const [RunSeg('düz', false, false, false)]);
    // Şablon run'ın rengi FF0000'dı; renk verilmediği için değişmemeli.
    expect(_part(editor.save(), 'word/document.xml'),
        contains('<w:color w:val="FF0000"/>'));
  });

  // --- Madde işareti / numaralandırma --------------------------------------
  test('setListStyle w:numPr yazar ve numbering parçasını ÜRETİR', () {
    final editor = DocxEditor.parse(_fullDocx());
    editor.setListStyle(0, 'bullet');
    editor.setListStyle(1, 'number');
    final bytes = editor.save();

    final doc = _part(bytes, 'word/document.xml');
    expect(doc, contains('<w:numPr>'));
    expect(doc, contains('<w:numId w:val="9101"/>'));
    expect(doc, contains('<w:numId w:val="9102"/>'));

    // Üç parça birden yazılmalı: tanım, içerik türü, ilişki. Biri eksikse
    // Word dosyayı "onarılamaz" sayar.
    final numbering = _part(bytes, 'word/numbering.xml');
    expect(numbering, contains('w:abstractNumId="9101"'));
    expect(numbering, contains('<w:numFmt w:val="bullet"/>'));
    expect(numbering, contains('<w:numFmt w:val="decimal"/>'));
    expect(_part(bytes, '[Content_Types].xml'),
        contains('/word/numbering.xml'));
    expect(_part(bytes, 'word/_rels/document.xml.rels'),
        contains('Target="numbering.xml"'));
  });

  test('liste verilmezse numbering parçası HİÇ eklenmez', () {
    final editor = DocxEditor.parse(_fullDocx());
    editor.paragraphs.first.text = 'değişti';
    final bytes = editor.save();
    expect(_part(bytes, 'word/numbering.xml'), isEmpty);
    expect(_part(bytes, '[Content_Types].xml'),
        isNot(contains('numbering.xml')));
  });

  test('liste kaldırma w:numPr\'yi siler', () {
    final editor = DocxEditor.parse(_fullDocx());
    editor.setListStyle(0, 'bullet');
    editor.setListStyle(0, 'none');
    expect(_part(editor.save(), 'word/document.xml'),
        isNot(contains('<w:numPr>')));
  });

  // --- Canlı düzenleme (setRuns) -------------------------------------------
  test('setRuns B/I/U çalıştırmalarını yazar, şablon biçimi ve pPr korunur', () {
    final editor = DocxEditor.parse(_richSampleDocx());
    expect(editor.paragraphs.length, 2);
    expect(editor.paragraphs.first.text, 'Eski metin');

    editor.setRuns(0, const [
      RunSeg('Merhaba ', false, false, false),
      RunSeg('dünya', true, false, true),
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
    editor.setRuns(0, const [RunSeg('üst\nalt', false, false, false)]);

    final saved = editor.save();
    expect(utf8.decode(_docXml(saved)), contains('<w:br/>'));
    expect(DocxEditor.parse(saved).paragraphs.first.text, 'üstalt');
  });

  test('yazı tipi ve punto seçimi w:rFonts / w:sz olarak yazılır', () {
    final editor = DocxEditor.parse(_richSampleDocx());
    editor.setRuns(0, const [
      RunSeg('Arial 14', false, false, false, font: 'Arial', sizePt: 14),
    ]);
    final xml = utf8.decode(_docXml(editor.save()));
    expect(xml, contains('w:ascii="Arial"'));
    expect(xml, contains('w:hAnsi="Arial"'));
    expect(xml, contains('w:cs="Arial"'), reason: 'Arapça/karmaşık yazı da dönmeli');
    // Word yarım punto tutar: 14 pt → 28.
    expect(xml, contains('<w:sz w:val="28"/>'));
    expect(xml, contains('<w:szCs w:val="28"/>'));
  });

  test('font/punto VERİLMEZSE şablonun biçimi ezilmez', () {
    // Kullanıcı yalnız yazı yazdıysa dosyadaki stilden gelen font satır içi
    // bir w:rFonts'a dönüşmemeli — belge stili sessizce donardı.
    final editor = DocxEditor.parse(_richSampleDocx());
    editor.setRuns(0, const [RunSeg('sade', false, false, false)]);
    final xml = utf8.decode(_docXml(editor.save()));
    expect(xml.contains('<w:sz '), isFalse);
    expect(xml, contains('FF0000'), reason: 'şablon rPr yerinde kalmalı');
  });

  test('rich olmayan paragraf save() ile eski yoldan güncellenir', () {
    final editor = DocxEditor.parse(_richSampleDocx());
    editor.setRuns(0, const [RunSeg('Zengin', true, false, false)]);
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


  test('silinen paragraf KENDİ yerine geri konur (geri alma)', () {
    // Geri almanın kritik noktası: paragraf sona değil, silindiği yere
    // dönmeli — başlığın altındaki madde belgenin sonuna düşerse metin bozulur.
    final e = DocxEditor.parse(_sampleDocx());
    final target = e.paragraphs[1];
    final textsBefore = e.paragraphs.map((p) => p.text).toList();

    final slot = e.slotOf(target);
    e.deleteParagraph(target);
    expect(e.paragraphs.length, textsBefore.length - 1);

    e.restoreParagraph(target, slot);
    expect(e.paragraphs.map((p) => p.text), textsBefore);

    // Dosyada da doğru sırada.
    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs.map((p) => p.text), textsBefore);
  });

  test('eklenen paragrafın geri alınması belgeyi eski hâline döndürür', () {
    final e = DocxEditor.parse(_sampleDocx());
    final textsBefore = e.paragraphs.map((p) => p.text).toList();

    final added = e.addParagraphAfter(e.paragraphs[0]);
    added.text = 'Fazlalık';
    expect(e.paragraphs.length, textsBefore.length + 1);

    e.deleteParagraph(added);
    expect(e.paragraphs.map((p) => p.text), textsBefore);
    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs.map((p) => p.text), textsBefore);
  });

  test('ilk paragrafın silinmesi de geri alınabilir', () {
    final e = DocxEditor.parse(_sampleDocx());
    final first = e.paragraphs.first;
    final slot = e.slotOf(first);
    e.deleteParagraph(first);
    expect(e.paragraphs.first.text, isNot('Başlık'));
    e.restoreParagraph(first, slot);
    expect(e.paragraphs.first.text, 'Başlık');
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
    e.setRuns(0, const [RunSeg('Merhaba', true, false, false)]);
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
