import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:dosya_okuyucu/services/conversion_service.dart';

/// Resim→PDF'te "veri kaçmaması" kontrolü: eskiden görsel metin yoluna girip
/// PDF'e "(Boş belge)" yazılıyor, resim tamamen kayboluyordu.
///
/// Geçerli 1x1 piksel PNG.
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File image;

  setUp(() async {
    image = File(
        '${Directory.systemTemp.path}/dosya_okuyucu_test_${DateTime.now().microsecondsSinceEpoch}.png');
    await image.writeAsBytes(base64Decode(_png1x1));
  });

  tearDown(() {
    if (image.existsSync()) image.deleteSync();
  });

  test('görsel gerçekten PDF\'e gömülür, "(Boş belge)" üretilmez', () async {
    final pdf = await ConversionService().imageToPdf(image.path);

    expect(pdf.length, greaterThan(0));
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

    // Resim akışı (XObject) yoksa görsel kaybolmuş demektir.
    final raw = latin1.decode(pdf, allowInvalid: true);
    expect(raw, contains('/Image'));
    expect(raw, isNot(contains('Boş belge')));
  });

  /// Belge tarayıcı: taranan sayfalar TEK PDF'te ve HER BİRİ kendi sayfasında
  /// olmalı — tek sayfaya üst üste binerse tarama işe yaramaz.
  test('çok görsel → her biri ayrı sayfa olan tek PDF', () async {
    final second = File('${image.path}_2.png');
    await second.writeAsBytes(base64Decode(_png1x1));
    try {
      final pdf = await ConversionService()
          .imagesToPdf([image.path, second.path, image.path]);

      final raw = latin1.decode(pdf, allowInvalid: true);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      // Sayfa nesnesi sayısı: /Page (ama /Pages değil) geçişleri.
      final pageObjects = RegExp(r'/Type\s*/Page[^s]').allMatches(raw).length;
      expect(pageObjects, 3);
    } finally {
      if (second.existsSync()) second.deleteSync();
    }
  });

  test('boş görsel listesi hata verir', () async {
    expect(() => ConversionService().imagesToPdf([]), throwsArgumentError);
  });

  /// Belge tarayıcı "tarayıcıdan çıkmış gibi" olmalı: her sayfa AYNI kâğıtta.
  /// Eskiden sayfa boyu görselin oranını alıyordu → arka arkaya çekilen
  /// sayfalar farklı boyda çıkıyor, PDF'te sayfa sayfa zıplıyordu.
  group('uniformPage (belge tarayıcı)', () {
    /// PDF'teki /MediaBox girdilerinin (genişlik, yükseklik) listesi.
    List<(double, double)> mediaBoxes(List<int> pdf) {
      final raw = latin1.decode(pdf, allowInvalid: true);
      return RegExp(r'/MediaBox\s*\[\s*([\d.\-]+)\s+([\d.\-]+)\s+'
              r'([\d.\-]+)\s+([\d.\-]+)\s*\]')
          .allMatches(raw)
          .map((m) => (
                double.parse(m.group(3)!) - double.parse(m.group(1)!),
                double.parse(m.group(4)!) - double.parse(m.group(2)!),
              ))
          .toList();
    }

    test('verilmezse sayfa oranı görselin oranını alır (kare görsel → kare sayfa)',
        () async {
      final pdf = await ConversionService().imagesToPdf([image.path]);
      final boxes = mediaBoxes(pdf);
      expect(boxes, hasLength(1));
      // 1x1 görsel → kare sayfa.
      expect(boxes.first.$1, closeTo(boxes.first.$2, 0.5));
    });

    test('verilirse her sayfa A4 olur', () async {
      final second = File('${image.path}_3.png');
      await second.writeAsBytes(base64Decode(_png1x1));
      try {
        final pdf = await ConversionService().imagesToPdf(
          [image.path, second.path],
          uniformPage: PdfPageFormat.a4,
        );
        final boxes = mediaBoxes(pdf);
        expect(boxes, hasLength(2));
        for (final box in boxes) {
          expect(box.$1, closeTo(PdfPageFormat.a4.width, 0.5));
          expect(box.$2, closeTo(PdfPageFormat.a4.height, 0.5));
        }
      } finally {
        if (second.existsSync()) second.deleteSync();
      }
    });
  });
}
