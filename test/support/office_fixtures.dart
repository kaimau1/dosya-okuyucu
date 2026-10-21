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
