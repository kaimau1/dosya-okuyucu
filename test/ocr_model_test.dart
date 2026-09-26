import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/ocr_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-09-26: OCR modeli artık APK'da değil, Google Play Hizmetleri'nden
/// iniyor. İlk kullanımda model inmemişse ML Kit bir hata atıyor; bu hata
/// tanınmalı (kısa bekleyip yeniden denemek için) ve kullanıcıya ham ML Kit
/// iletisi yerine ne yapacağını söyleyen metin gösterilmeli.
void main() {
  test('"model iniyor" hatası tanınır, öteki hatalar tanınmaz', () {
    // Eklentinin gerçek biçimi: ML Kit istisnası PlatformException'ın
    // iletisinde taşınıyor.
    expect(
      OcrService.isModelDownloading(PlatformException(
        code: 'TextRecognizerError',
        message: 'com.google.mlkit.common.MlKitException: Waiting for the '
            'text optional module to be downloaded. Please wait.',
      )),
      isTrue,
    );
    expect(
      OcrService.isModelDownloading(
          PlatformException(code: 'x', message: 'Failed to decode image')),
      isFalse,
    );
    expect(OcrService.isModelDownloading(StateError('başka')), isFalse);
  });

  test('bekleme toplamı makul (kullanıcı dakikalarca beklemesin)', () {
    final total = OcrService.modelRetryDelays
        .fold(Duration.zero, (a, b) => a + b);
    expect(total.inSeconds, lessThanOrEqualTo(20));
  });

  test('hata metni kullanıcının dilinde, ham ML Kit iletisi değil', () {
    final text = const OcrModelNotReady().toString();
    expect(text, AppStrings.current.t('ocr.model_downloading'));
    expect(text, isNot(contains('MlKitException')));
  });
}
