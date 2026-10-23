import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:dosya_okuyucu/services/text_decode.dart';

import 'xlsx_fixture.dart';

/// **Office ve metin örnek seti** (Faz 9 — `docs/FAZ_PLANI.md` §Faz 9 madde 6).
///
/// PDF setiyle aynı ilke: ikili dosya değil KOD. `tool/write_fixtures_test.dart`
/// bu örnekleri ve düzenlenmiş hâllerini `test/fixtures/office/` altına
/// yazar; masaüstü Office'te açılma kontrolü (`docs/CIHAZ_TESTI.md`) o
/// dosyalarla yapılır.
abstract final class OfficeFixtures {
  /// Başlık + tablo (2×2) + son paragraf; Türkçe karakterli.
  static Uint8List docxWithTable() {
    final out = Archive();
    for (final f in ZipDecoder().decodeBytes(BlankDocs.blankDocx()).files) {
      var data = f.content as List<int>;
      if (f.name == 'word/document.xml') {
        String p(String t) =>
            '<w:p><w:r><w:t xml:space="preserve">$t</w:t></w:r></w:p>';
        String cell(String t) => '<w:tc><w:tcPr><w:tcW w:w="3000" '
            'w:type="dxa"/></w:tcPr>${p(t)}</w:tc>';
        final table = '<w:tbl><w:tblPr><w:tblW w:w="6000" w:type="dxa"/>'
            '<w:tblBorders><w:top w:val="single" w:sz="4"/>'
            '<w:left w:val="single" w:sz="4"/><w:bottom w:val="single" w:sz="4"/>'
            '<w:right w:val="single" w:sz="4"/><w:insideH w:val="single" w:sz="4"/>'
            '<w:insideV w:val="single" w:sz="4"/></w:tblBorders></w:tblPr>'
            '<w:tblGrid><w:gridCol w:w="3000"/><w:gridCol w:w="3000"/></w:tblGrid>'
            '<w:tr>${cell('Ad')}${cell('Şehir')}</w:tr>'
            '<w:tr>${cell('Ayşe')}${cell('İzmir')}</w:tr></w:tbl>';
        data = utf8.encode(utf8.decode(data).replaceFirst(
            RegExp(r'<w:p>.*?</w:p>'),
            p('Toplantı tutanağı — Şubat') + table + p('Son paragraf')));
      }
      out.addFile(ArchiveFile(f.name, data.length, data));
    }
    return Uint8List.fromList(ZipEncoder().encode(out)!);
  }

  /// **Word'de kaydedilmiş çok sayfalı belge** (Faz 21 / W1 kanıtı).
  ///
  /// Word her kayıtta sayfanın kırıldığı yere `w:lastRenderedPageBreak`
  /// yazar; docx-preview o işareti taşıyan paragrafı İKİ `<p>`ye böler.
  /// Burada 3. paragrafın ORTASINDA bir işaret var (ikinci sayfa orada
  /// başlıyor) + bir sert sayfa sonu + köprü, sekme ve dipnot başvurusu
  /// içeren bir paragraf (dokunulmaz adalar).
  static Uint8List docxWordSaved() {
    String p(String body) => '<w:p>$body</w:p>';
    String r(String t, {String rpr = ''}) =>
        '<w:r>${rpr.isEmpty ? '' : '<w:rPr>$rpr</w:rPr>'}'
        '<w:t xml:space="preserve">$t</w:t></w:r>';
    final filler = List.generate(
        24, (i) => p(r('Dolgu paragrafı ${i + 1}: sayfayı doldurmak için '
            'yeterince uzun bir cümle, Word gibi.'))).join();
    final body = [
      p('<w:pPr><w:pStyle w:val="Heading1"/></w:pPr>${r('Rapor başlığı')}'),
      p(r('Giriş paragrafı.')),
      filler,
      p('${r('Sayfa sonunda başlayan ')}'
          '<w:r><w:lastRenderedPageBreak/><w:t xml:space="preserve">'
          've sonraki sayfada biten paragraf.</w:t></w:r>'),
      p('${r('Bağlantı: ')}<w:hyperlink r:id="rIdLink">'
          '${r('örnek site', rpr: '<w:color w:val="0563C1"/><w:u w:val="single"/>')}'
          '</w:hyperlink>${r(' sonrası')}<w:r><w:tab/></w:r>${r('sekme')}'
          '<w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr>'
          '<w:footnoteReference w:id="1"/></w:r>${r(' son.')}'),
      p(r('Karışık ') + r('kalın', rpr: '<w:b/>') + r(' metin.')),
      p('<w:r><w:br w:type="page"/></w:r>'),
      p(r('Üçüncü sayfa.')),
    ].join();
    final out = Archive();
    for (final f in ZipDecoder().decodeBytes(BlankDocs.blankDocx()).files) {
      var data = f.content as List<int>;
      if (f.name == 'word/document.xml') {
        var xml = utf8.decode(data);
        if (!xml.contains('xmlns:r=')) {
          xml = xml.replaceFirst('<w:document ',
              '<w:document xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" ');
        }
        data = utf8.encode(xml.replaceFirst(RegExp(r'<w:p>.*?</w:p>'), body));
      } else if (f.name == 'word/_rels/document.xml.rels') {
        data = utf8.encode(utf8.decode(data).replaceFirst('</Relationships>',
            '<Relationship Id="rIdLink" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com" TargetMode="External"/>'
            '<Relationship Id="rIdFn" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes" Target="footnotes.xml"/></Relationships>'));
      } else if (f.name == '[Content_Types].xml') {
        data = utf8.encode(utf8.decode(data).replaceFirst('</Types>',
            '<Override PartName="/word/footnotes.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml"/></Types>'));
      }
      out.addFile(ArchiveFile(f.name, data.length, data));
    }
    final fn = utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:footnote>'
        '<w:footnote w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>'
        '<w:footnote w:id="1"><w:p><w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr><w:footnoteRef/></w:r>'
        '<w:r><w:t xml:space="preserve"> Dipnot metni.</w:t></w:r></w:p></w:footnote></w:footnotes>');
    out.addFile(ArchiveFile('word/footnotes.xml', fn.length, fn));
    return Uint8List.fromList(ZipEncoder().encode(out)!);
  }

  /// İki sayfalı satış tablosu (formül + Türkçe ad).
  static Uint8List xlsxSales() => xlsxFrom({
        'A1': 'Ay', 'B1': 'Satış', 'C1': 'Gider',
        'A2': 'Ocak', 'B2': 120, 'C2': 80,
        'A3': 'Şubat', 'B3': 150, 'C3': 95,
        'A4': 'Mart', 'B4': 90, 'C4': 70,
      }, sheet: 'Özet');

  static Uint8List pptx() => PptxWriter.build(const [
        SlideDraft('Çeyrek Raporu', ['Gelir arttı', 'Gider sabit']),
        SlideDraft('Sonraki adımlar', ['İzmir şubesi', 'Yeni ürün']),
      ]);

  static const text = 'Başlık: Işık\nİkinci satır — çiğ süt\nÜçüncü';

  static List<int> textUtf8() => utf8.encode(text);
  static List<int> textCp1254() => TextDecode.encodeCp1254(text.replaceAll('—', '-'));
  static List<int> textUtf16le() => [
        0xFF, 0xFE,
        for (final u in text.codeUnits) ...[u & 0xFF, u >> 8],
      ];

  /// Türkçe Excel'in "CSV (noktalı virgül)" çıktısı.
  static const csvSemicolon = 'Ürün;Fiyat;Adet\nElma;12,50;3\nArmut;7,25;10\n';
}
