import 'package:dosya_okuyucu/services/pdf/pdf_selection_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// PS1 (PDF Pro Faz 51): "Düzenle" seçimi düzenleyicinin bloğuna eşlenir.
void main() {
  // PdfRect(left, top, right, bottom) — PDF sayfa uzayı, y yukarı.
  const p0 = PdfRect(70, 760, 520, 740); // başlık
  const p1 = PdfRect(70, 720, 520, 640); // birinci paragraf
  const p2 = PdfRect(70, 620, 520, 540); // ikinci paragraf

  test('seçimle en çok örtüşen paragraf seçilir', () {
    // İki satırlık seçim: çoğu p1'de, bir parçası p2'nin üstüne taşıyor.
    expect(
        bestOverlap(const [
          PdfRect(200, 700, 520, 688),
          PdfRect(70, 686, 520, 674),
          PdfRect(70, 625, 120, 615),
        ], const [p0, p1, p2]),
        1);
  });

  test('örtüşme yoksa null (editör sayfa görünümüyle açılır)', () {
    expect(bestOverlap(const [PdfRect(10, 100, 40, 90)], const [p0, p1]),
        isNull);
    expect(bestOverlap(const [], const [p0]), isNull);
  });

  test('imleç seçimin başına — pdfium satır sonu/boşluk farkı yok sayılır', () {
    const block = 'Ağaçların gölgesinde çay içen öğrenciler sınav haftasının '
        'yaklaştığını konuşuyordu.';
    expect(selectionCaret(block, 'öğrenciler\r\nsınav'),
        block.indexOf('öğrenciler'));
    expect(selectionCaret(block, 'bulunmayan metin'), 0);
    expect(selectionCaret(block, ''), 0);
  });
}
