import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
