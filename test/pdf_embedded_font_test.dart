import 'dart:io';
import 'dart:ui';

import 'package:dosya_okuyucu/services/pdf/pdf_page_context.dart';
import 'package:dosya_okuyucu/services/pdf/ttf_coverage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'support/pdf_fixtures.dart';

/// Faz 31 kalanı: "Üstüne yaz" paragrafın kendi gömülü yazı tipiyle — önce
/// program çıkarılabilmeli ve harf kapsamı doğru ölçülmeli (alt küme!).
void main() {
  final carlito = File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync();

  test('tam font: Türkçe harfler var, Çince yok', () {
    expect(TtfCoverage.covers(carlito, 'Merhaba ğüşıİÖç'), isTrue);
    expect(TtfCoverage.covers(carlito, '漢字'), isFalse);
    expect(TtfCoverage.covers(const [1, 2, 3], 'a'), isFalse,
        reason: 'bozuk program → güvenli yedek');
  });

  test('paragrafın gömülü programı: kapsıyorsa verilir, kapsamıyorsa null', () {
    final src = PdfFixtures.hand(
        [PdfFixtures.textContent(['Toplantı notları'])],
        embedFont: carlito);
    final program = PdfPageEdit.paragraphFontProgram(src,
        pageIndex: 0, paragraphIndex: 0, text: 'Yeni toplantı');
    expect(program, isNotNull);
    expect(program!.length, carlito.length);
    expect(
        PdfPageEdit.paragraphFontProgram(src,
            pageIndex: 0, paragraphIndex: 0, text: '漢字'),
        isNull,
        reason: 'harf yok → Carlito yedeği');
  });

  test('cmap\'siz alt küme (bazı üreticiler): güvenli yedek (false)',
      () async {
    final doc = PdfDocument();
    doc.pages.add().graphics.drawString(
        'Toplantı', PdfTrueTypeFont(carlito, 12),
        bounds: const Rect.fromLTWH(40, 40, 300, 20));
    final bytes = await doc.save();
    doc.dispose();
    final page = PdfPageContext.open(bytes, 0);
    final programs = [
      for (final name in page.file.fontRefs(page.page).keys)
        page.file.embeddedTrueType(page.page, name),
    ].whereType<List<int>>().toList();
    expect(programs, isNotEmpty, reason: 'FontFile2 çıkarıldı');
    final sub = programs.first;
    // Syncfusion alt kümesi `cmap` tablosu taşımıyor: harf → glif eşlenemez,
    // bu programla yazmak boş kutu çizerdi → kapsam yok sayılır.
    expect(TtfCoverage.covers(sub, 'Toplantı'), isFalse);
  });
}
