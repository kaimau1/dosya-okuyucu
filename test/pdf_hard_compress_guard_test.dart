import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';

/// C3 2026-11-27: agresif sıkıştırma metin-only belgeyi 108 KB → 12,5 MB
/// yapıyordu ve sonuç uygulanıyordu. Büyüyen/değmeyen sonuç uygulanmaz.
void main() {
  test('büyüyen sonuç uygulanmaz', () {
    expect(PdfTools.hardCompressWorthIt(108 * 1024, 12800 * 1024), isFalse);
    expect(PdfTools.hardCompressWorthIt(1000, 1000), isFalse);
    expect(PdfTools.hardCompressWorthIt(1000, 960), isFalse); // < %5 kazanç
  });

  test('en az %5 küçülen sonuç uygulanır', () {
    expect(PdfTools.hardCompressWorthIt(1000, 950), isTrue);
    expect(PdfTools.hardCompressWorthIt(5000000, 1200000), isTrue);
  });

  test('metin ağırlıklı belge için önceden uyarı', () {
    expect(PdfTools.hardCompressLikelyBigger(108 * 1024, 320), isTrue);
    expect(PdfTools.hardCompressLikelyBigger(20 * 1024 * 1024, 40), isFalse);
    expect(PdfTools.hardCompressLikelyBigger(1000, 0), isFalse);
  });
}
