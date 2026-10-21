import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 9 / Y1 — Word: tablo HÜCRE metni düzenleme ve karakter düzeyinde
/// punto/yazı tipi. Canlı görünümün gönderdiği mesajların (Chromium'da
/// ölçüldü: `{"i":3,"segs":[["Ayşe X",…]]}`) Dart tarafındaki karşılığı.
void main() {
  Uint8List tableDoc() {
    final out = Archive();
    for (final f in ZipDecoder().decodeBytes(BlankDocs.blankDocx()).files) {
      var data = f.content as List<int>;
      if (f.name == 'word/document.xml') {
        String p(String t) =>
            '<w:p><w:r><w:t xml:space="preserve">$t</w:t></w:r></w:p>';
        String cell(String t) => '<w:tc><w:tcPr><w:tcW w:w="3000" '
            'w:type="dxa"/></w:tcPr>${p(t)}</w:tc>';
        final table = '<w:tbl><w:tblPr><w:tblW w:w="6000" w:type="dxa"/>'
            '</w:tblPr><w:tblGrid><w:gridCol w:w="3000"/><w:gridCol '
            'w:w="3000"/></w:tblGrid><w:tr>${cell('Ad')}${cell('Şehir')}</w:tr>'
            '<w:tr>${cell('Ayşe')}${cell('İzmir')}</w:tr></w:tbl>';
        data = utf8.encode(utf8.decode(data).replaceFirst(
            RegExp(r'<w:p>.*?</w:p>'),
            p('Başlık paragrafı burada') + table + p('Son paragraf')));
      }
      out.addFile(ArchiveFile(f.name, data.length, data));
    }
    return Uint8List.fromList(ZipEncoder().encode(out)!);
  }

  String documentXml(Uint8List docx) => utf8.decode(ZipDecoder()
      .decodeBytes(docx)
      .files
      .firstWhere((f) => f.name == 'word/document.xml')
      .content as List<int>);

  test('tablo hücreleri paragraf listesinde, belge sırasıyla', () {
    final e = DocxEditor.parse(tableDoc());
    expect(e.paragraphs.map((p) => p.text), [
      'Başlık paragrafı burada', 'Ad', 'Şehir', 'Ayşe', 'İzmir', 'Son paragraf',
    ]);
  });

  test('hücre metni değişir, tablo yapısı korunur', () {
    final e = DocxEditor.parse(tableDoc())
      ..setRuns(3, [const RunSeg('Ayşe Kaya', false, false, false)]);
    final saved = e.save();
    final again = DocxEditor.parse(saved);
    expect(again.paragraphs[3].text, 'Ayşe Kaya');
    expect(again.paragraphs[4].text, 'İzmir');
    final xml = documentXml(saved);
    expect(RegExp('<w:tr>').allMatches(xml), hasLength(2));
    expect(RegExp('<w:tc>').allMatches(xml), hasLength(4));
  });

  test('punto yalnız seçilen parçaya yazılır (karakter düzeyi)', () {
    final e = DocxEditor.parse(tableDoc())
      ..setRuns(0, const [
        RunSeg('Başlık ', false, false, false),
        RunSeg('paragrafı', false, false, false, sizePt: 20),
        RunSeg(' burada', false, false, false),
      ]);
    final xml = documentXml(e.save());
    // 20 pt = 40 yarım punto, yalnız bir koşuda.
    expect(RegExp(r'<w:sz w:val="40"/>').allMatches(xml), hasLength(1));
    final run = RegExp(r'<w:r>(?:(?!</w:r>).)*paragrafı(?:(?!</w:r>).)*</w:r>')
        .firstMatch(xml)![0]!;
    expect(run, contains('w:val="40"'));
  });

  test('yazı tipi yalnız seçilen parçaya yazılır', () {
    final e = DocxEditor.parse(tableDoc())
      ..setRuns(5, const [
        RunSeg('Son', false, false, false, font: 'Times New Roman'),
        RunSeg(' paragraf', false, false, false),
      ]);
    final xml = documentXml(e.save());
    expect(RegExp('Times New Roman').allMatches(xml).length, greaterThan(0));
    final rest =
        RegExp(r'<w:r>(?:(?!</w:r>).)* paragraf</w:t>').firstMatch(xml)![0]!;
    expect(rest, isNot(contains('Times')));
  });
}
