import 'dart:convert';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pdf_objects.dart';
import 'package:dosya_okuyucu/services/pdf_content_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Uçtan uca yerinde düzenleme + yeniden hizalama.**
///
/// Birim testler algoritmayı ölçüyor; burada asıl soru şu: uygulamanın gerçekte
/// çağırdığı yol (dosyayı ayrıştır → fontun genişlik tablosunu bul → içeriği
/// değiştir → dosyanın sonuna ekle → yeniden açıp doğrula) satırın kalanını
/// GERÇEKTEN hizalıyor mu?
///
/// Belge elle kuruluyor çünkü kontrollü genişlik gerekiyor: her glif 500/1000
/// em, yani 10 puntoda tam 5 birim. Beklenen kayma elle hesaplanabilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// İki ayrı konumlandırılmış parçadan oluşan tek satır — resmî yazışma
  /// PDF'lerinin tipik yapısı (her sözcük öbeği kendi `Tm`'iyle yerleşir).
  List<int> buildPdf(String first, String second, double secondX) {
    final content = 'BT /F1 10 Tf '
        '1 0 0 1 50 700 Tm ($first) Tj '
        '1 0 0 1 $secondX 700 Tm ($second) Tj ET';

    final out = BytesBuilder();
    final offsets = <int, int>{};
    void add(int number, String body) {
      offsets[number] = out.length;
      out.add(latin1.encode('$number 0 obj\n$body\nendobj\n'));
    }

    // 32..126 arası her glif 500 birim.
    final widths = List.filled(95, '500').join(' ');

    out.add(latin1.encode('%PDF-1.4\n'));
    add(1, '<< /Type /Catalog /Pages 2 0 R >>');
    add(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    add(
        3,
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 800] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>');
    add(4, '<< /Length ${content.length} >>\nstream\n$content\nendstream');
    add(
        5,
        '<< /Type /Font /Subtype /TrueType /BaseFont /Arial '
        '/Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 126 '
        '/Widths [$widths] >>');

    final xrefOffset = out.length;
    final xref = StringBuffer('xref\n0 6\n0000000000 65535 f \n');
    for (var i = 1; i <= 5; i++) {
      xref.write('${offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
    }
    xref
      ..write('trailer\n<< /Size 6 /Root 1 0 R >>\n')
      ..write('startxref\n$xrefOffset\n%%EOF\n');
    out.add(latin1.encode(xref.toString()));
    return out.takeBytes();
  }

  /// Yazılan belgenin GEÇERLİ (en son) sayfa içeriği.
  String contentOf(List<int> pdf) {
    final file = PdfFile.parse(pdf);
    final streams = file.pageContents(0);
    return latin1.decode(file.decodeStream(streams.first), allowInvalid: true);
  }

  test('kısalan metinde satırın kalanı gerçekten sola kayar', () async {
    // "Genel" 5 harf = 25 birim, ikinci parça 75'te. "Sube" 4 harf = 20 →
    // fark -5 → ikinci parça 70'e gelmeli.
    final pdf = buildPdf('Genel', 'Mudurlugu', 75);

    final result = await PdfContentEditor.replaceText(pdf,
        pageIndex: 0, oldText: 'Genel', newText: 'Sube');

    expect(result.reflowed, isTrue);
    final content = contentOf(result.bytes);
    expect(content, contains('(Sube)'));
    expect(content, contains('1 0 0 1 70 700 Tm'));
  });

  test('uzayan metinde satırın kalanı sağa kayar', () async {
    final pdf = buildPdf('Genel', 'Mudurlugu', 75);

    final result = await PdfContentEditor.replaceText(pdf,
        pageIndex: 0, oldText: 'Genel', newText: 'Genelge');

    // 7 harf = 35 → fark +10 → 85.
    expect(contentOf(result.bytes), contains('1 0 0 1 85 700 Tm'));
  });

  test('özgün baytlar korunur (değişiklik dosyanın SONUNA eklenir)', () async {
    final pdf = buildPdf('Genel', 'Mudurlugu', 75);

    final result = await PdfContentEditor.replaceText(pdf,
        pageIndex: 0, oldText: 'Genel', newText: 'Sube');

    expect(result.bytes.sublist(0, pdf.length), pdf);
    expect(result.bytes.length, greaterThan(pdf.length));
  });

  test('sayfaya sığan düzenleme taşma uyarısı vermez', () async {
    final pdf = buildPdf('Genel', 'Mudurlugu', 75);

    final result = await PdfContentEditor.replaceText(pdf,
        pageIndex: 0, oldText: 'Genel', newText: 'Sube');

    expect(result.overflows, isFalse);
  });

  test('sayfanın dışına taşan düzenleme UYARIR ama yine de yapılır', () async {
    // Sayfa 400 geniş, metin 50'den başlıyor → sağ sınır 350 kabul edilir.
    // 80 harf x 5 = 400 birim → 50 + 400 = 450 > 350.
    final pdf = buildPdf('Genel', 'Mudurlugu', 75);

    final result = await PdfContentEditor.replaceText(pdf,
        pageIndex: 0, oldText: 'Genel', newText: 'A' * 80);

    expect(result.overflows, isTrue);
    expect(contentOf(result.bytes), contains('A' * 80));
  });
}
