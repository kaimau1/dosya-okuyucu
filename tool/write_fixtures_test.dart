// Örnek dosya setini diske yazar (Faz 8-9). CI'da koşmaz; elle:
//   flutter test tool/write_fixtures_test.dart
// Çıktılar: test/fixtures/pdf/ ve test/fixtures/office/ — her örneğin özgün
// ve DÜZENLENMİŞ hâli. Telefonda (uygulama) ve masaüstü Office'te açılma
// kontrolü bu dosyalarla yapılır (docs/CIHAZ_TESTI.md).
import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/legacy_convert.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_form.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_text_stamp.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/office_fixtures.dart';
import '../test/support/pdf_edit_helper.dart';
import '../test/support/pdf_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void write(String path, List<int> bytes) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  test('PDF örnekleri', () async {
    const d = 'test/fixtures/pdf';
    write('$d/metinli.pdf', PdfFixtures.textual());
    write('$d/metinli_duzenlendi.pdf',
        replaceInParagraph(PdfFixtures.textual(), oldText: '2026', newText: '2027'));
    write('$d/turkce.pdf', PdfFixtures.turkish());
    write('$d/taranmis.pdf', PdfFixtures.scanned());
    write('$d/taranmis_yazi_eklendi.pdf', await PdfTextStamp.add(
        bytes: PdfFixtures.scanned(), pageIndex: 0, x: 60, y: 80,
        text: 'Ek not: onaylandı'));
    write('$d/parolali_1234.pdf', await PdfFixtures.passwordProtected('1234'));
    final form = await PdfFixtures.form();
    write('$d/formlu.pdf', form);
    write('$d/formlu_dolduruldu.pdf', PdfFormFiller.fillSync(
        form, {'ad': 'Ayşe', 'sehir': 'İzmir', 'onay': 'true'},
        fontData: File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync()));
    write('$d/dondurulmus_90.pdf', PdfFixtures.rotated(90));
    write('$d/cropbox.pdf', PdfFixtures.cropped());
    write('$d/uzun_320_sayfa.pdf', PdfFixtures.long());
  });

  test('Office örnekleri', () {
    const d = 'test/fixtures/office';
    write('$d/tablo.docx', OfficeFixtures.docxWithTable());
    write('$d/word_kaydedilmis_cok_sayfa.docx', OfficeFixtures.docxWordSaved());
    // Canlı düzenleme köprüsünün Playwright denetimi (tool/check_word_bridge.js)
    // WebView'ın gördüğü İŞARETLİ kopyayla koşar (Faz 21a).
    for (final name in [
      'tablo.docx',
      'madde_imleri.docx',
      'word_kaydedilmis_cok_sayfa.docx',
    ]) {
      final src = name == 'tablo.docx'
          ? OfficeFixtures.docxWithTable()
          : name == 'word_kaydedilmis_cok_sayfa.docx'
              ? OfficeFixtures.docxWordSaved()
              : File('$d/$name').readAsBytesSync();
      Directory('$d/view').createSync(recursive: true);
      write('$d/view/$name', DocxEditor.parse(src).viewBytes());
    }
    final docx = DocxEditor.parse(OfficeFixtures.docxWithTable());
    final cell = docx.paragraphs.indexWhere((p) => p.text == 'Ayşe');
    docx
      ..setRuns(0, const [
        RunSeg('Toplantı tutanağı — ', false, false, false),
        RunSeg('Mart', true, false, false, sizePt: 16),
      ])
      ..setRuns(cell, const [RunSeg('Ayşe Kaya', false, false, false)])
      ..setListStyle(docx.paragraphs.length - 1, 'bullet')
      ..insertImageAfter(docx.paragraphs.first, base64Decode(_png), ext: 'png',
          widthPx: 120, heightPx: 60);
    write('$d/tablo_duzenlendi.docx', docx.save());

    write('$d/satis.xlsx', OfficeFixtures.xlsxSales());
    final xlsx = XlsxEditor.parse(OfficeFixtures.xlsxSales())
      ..setCell('Özet', 4, 0, 'Toplam')
      ..setCell('Özet', 4, 1, '=SUM(B2:B4)');
    xlsx.addSheet('Notlar');
    xlsx
      ..moveSheet('Notlar', 0)
      ..addChart(XlsxChartSpec.fromRange(
        sheetName: 'Özet', kind: XlsxChartKind.column,
        top: 0, left: 0, bottom: 3, right: 2,
        display: xlsx.sheets[1].rawAt, title: 'Aylık',
      )!);
    write('$d/satis_duzenlendi.xlsx', xlsx.save());

    write('$d/sunum.pptx', OfficeFixtures.pptx());
    final pptx = PptxEditor.parse(OfficeFixtures.pptx());
    final slide = pptx.slides.first;
    pptx.updateParagraph(slide,
        slide.paragraphs.firstWhere((p) => p.text == 'Gelir arttı'),
        'Gelir %12 arttı');
    write('$d/sunum_duzenlendi.pptx', pptx.save());

    write('$d/eski_doc_donusturuldu.docx',
        LegacyConvert.docxFromText(OfficeFixtures.text));
    write('$d/metin_utf8.txt', OfficeFixtures.textUtf8());
    write('$d/metin_cp1254.txt', OfficeFixtures.textCp1254());
    write('$d/metin_utf16le.txt', OfficeFixtures.textUtf16le());
    write('$d/noktali_virgul.csv', utf8.encode(OfficeFixtures.csvSemicolon));
  });
}

/// 120×60 tek renk PNG yerine 1×1 (görüntü önemli değil, bağlantı önemli).
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4//8/AwAI/AL+XJ/PqwAAAABJRU5ErkJggg==';
