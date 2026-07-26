import 'dart:convert';

import 'package:dosya_okuyucu/services/conversion_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Metin → PDF yolunda **Türkçe karakter** kontrolü.
///
/// Sorun sessizdi: `pdf` paketinin varsayılan fontu Helvetica (base-14,
/// WinAnsi) ve `ğ ş ı İ` bu kodlamada YOK. Paket hata atmıyor — PDF üretiliyor
/// ama o karakterler yanlış/boş çiziliyor, yani "PDF'e dönüştür" Türkçe bir
/// belgeyi bozuyordu. Çözüm gömülü Carlito teması.
///
/// Test bu yüzden "çökmedi mi"ye değil, **fontun gerçekten gömüldüğüne** bakar:
/// `/FontFile2` gömülü TrueType demektir, Helvetica'ya düşülmemiş demektir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const turkish = "Iğdır'ın şişli çöğürcüğü — ĞÜŞİÖÇ ığşiöç";

  test('textToPdf Türkçe fontu gömer, Helvetica\'ya düşmez', () async {
    final pdf = await ConversionService().textToPdf(turkish, turkish);
    final raw = latin1.decode(pdf, allowInvalid: true);

    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(raw, contains('/FontFile2'), reason: 'gömülü TrueType yok');
    expect(raw, isNot(contains('Helvetica')),
        reason: 'Türkçe çizemeyen base-14 fonta düşülmüş');
  });

  test('textToSlidesPdf de gömülü fontu kullanır', () async {
    final pdf = await ConversionService()
        .textToSlidesPdf(turkish, '$turkish\n---\nİkinci slayt: ğüşiöç');
    final raw = latin1.decode(pdf, allowInvalid: true);

    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(raw, contains('/FontFile2'));
    expect(raw, isNot(contains('Helvetica')));
  });
}
