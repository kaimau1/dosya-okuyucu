import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/csv_codec.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/legacy_convert.dart';
import 'package:dosya_okuyucu/services/office_reader.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/text_decode.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/office_fixtures.dart';

/// **Office ve metin duman testleri** (Faz 9): her örnek için
/// aç → düzenle → kaydet → yeniden aç → içerik doğrula.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Word (.docx)', () {
    test('paragraf + tablo hücresi + liste + resim → kaydet → yeniden aç', () {
      final e = DocxEditor.parse(OfficeFixtures.docxWithTable());
      final cell = e.paragraphs.indexWhere((p) => p.text == 'Ayşe');
      e
        ..setRuns(0, const [
          RunSeg('Toplantı tutanağı — ', false, false, false),
          RunSeg('Mart', true, false, false, sizePt: 16),
        ])
        ..setRuns(cell, const [RunSeg('Ayşe Kaya', false, false, false)])
        ..setListStyle(e.paragraphs.length - 1, 'bullet')
        ..insertImageAfter(e.paragraphs.first, base64Decode(_png1x1),
            ext: 'png', widthPx: 1, heightPx: 1);
      final out = e.save();

      final again = DocxEditor.parse(out);
      expect(again.paragraphs.first.text, 'Toplantı tutanağı — Mart');
      expect(again.paragraphs.map((p) => p.text), contains('Ayşe Kaya'));
      expect(again.imageCount(1), 1);
      expect(OfficeReader.extractDocxText(out), contains('İzmir'));
    });
  });

  group('Excel (.xlsx)', () {
    test('hücre + formül + sayfa taşı/adlandır + grafik → yeniden aç', () {
      final e = XlsxEditor.parse(OfficeFixtures.xlsxSales());
      final sheet = e.sheets.first;
      e
        ..setCell('Özet', 4, 0, 'Toplam')
        ..setCell('Özet', 4, 1, '=TOPLA(B2:B4)');
      e.addSheet('Notlar');
      e.setCell('Notlar', 0, 0, 'Not');
      expect(e.moveSheet('Notlar', 0), isTrue);
      expect(e.renameSheet('Özet', 'Rapor'), isTrue);
      e.addChart(XlsxChartSpec.fromRange(
        sheetName: 'Rapor',
        kind: XlsxChartKind.column,
        top: 0, left: 0, bottom: 3, right: 2,
        display: sheet.rawAt,
      )!);
      final out = e.save();

      final again = XlsxEditor.parse(out);
      expect(again.sheets.map((s) => s.name), ['Notlar', 'Rapor']);
      final rapor = again.sheets[1];
      expect(rapor.rawAt(2, 1), '150');
      expect(rapor.rawAt(4, 1), startsWith('='));
      final names = ZipDecoder().decodeBytes(out).files.map((f) => f.name);
      expect(names, contains('xl/charts/chart1.xml'));
    });

    test('CSV (Türkçe noktalı virgül) → tablo → CSV aynı', () {
      final rows = CsvCodec.parse(OfficeFixtures.csvSemicolon);
      expect(rows[1], ['Elma', '12,50', '3']);
      final back = CsvCodec.parse(CsvCodec.encode(rows, delimiter: ';'));
      expect(back, rows);
    });
  });

  group('Slayt (.pptx)', () {
    test('metin düzenle → kaydet → yeniden aç', () {
      final e = PptxEditor.parse(OfficeFixtures.pptx());
      final slide = e.slides.first;
      final para = slide.paragraphs.firstWhere((p) => p.text == 'Gelir arttı');
      e.updateParagraph(slide, para, 'Gelir %12 arttı');
      final out = e.save();
      final again = PptxEditor.parse(out);
      expect(again.slides, hasLength(2));
      expect(again.slides.first.paragraphs.map((p) => p.text),
          contains('Gelir %12 arttı'));
      expect(OfficeReader.extractPptxText(out), contains('İzmir şubesi'));
    });
  });

  group('Metin', () {
    test('UTF-8 / Windows-1254 / UTF-16 aynı metni verir', () {
      expect(TextDecode.decode(OfficeFixtures.textUtf8()), OfficeFixtures.text);
      expect(TextDecode.decode(OfficeFixtures.textUtf16le()),
          OfficeFixtures.text);
      expect(TextDecode.decode(OfficeFixtures.textCp1254()),
          OfficeFixtures.text.replaceAll('—', '-'));
    });

    test('eski .doc metni → .docx → düzenlenir → yeniden açılır', () {
      final docx = LegacyConvert.docxFromText(OfficeFixtures.text);
      final e = DocxEditor.parse(docx)
        ..setRuns(2, const [RunSeg('Üçüncü (güncel)', false, false, false)]);
      expect(OfficeReader.extractDocxText(e.save()), contains('Üçüncü (güncel)'));
    });
  });
}

/// 1×1 beyaz PNG.
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4//8/AwAI/AL+XJ/PqwAAAABJRU5ErkJggg==';
