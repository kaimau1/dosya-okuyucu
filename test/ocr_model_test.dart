import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/user_error.dart';
import 'package:dosya_okuyucu/services/arabic_ocr.dart';
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

  // 2026-11-27 tablet (Huawei, Play Hizmetleri yok): "Metni Tanı" sessizce
  // asılı kalıyordu. Bekçi: modül yokluğu tanınır, çağrı sınırlı, ileti
  // kullanıcıya ULAŞIR (genel "bir şeyler ters gitti"ye ezilmez).
  test('Play Hizmetleri/modül yokluğu tanınır', () {
    expect(
      OcrService.isPlayServicesMissing(PlatformException(
        code: 'TextRecognizerError',
        message: 'No acceptable module com.google.android.gms.vision.dynamite '
            'found. Local version is 0 and remote version is 0.',
      )),
      isTrue,
    );
    expect(
      OcrService.isPlayServicesMissing(
          PlatformException(code: 'x', message: 'Failed to decode image')),
      isFalse,
    );
    expect(OcrService.processTimeout.inSeconds, inInclusiveRange(5, 30));
  });

  test('OCR iletileri stüdyo/şeride olduğu gibi ulaşır', () {
    const unavailable = OcrUnavailable();
    expect(unavailable, isA<OcrModelNotReady>(),
        reason: 'tarama döngüleri kalan sayfalarda beklemeden dursun');
    final text = AppStrings.current.t('ocr.no_play_services');
    expect(unavailable.toString(), text);
    expect(userErrorText(unavailable), text);
    expect(userErrorText(const OcrModelNotReady()),
        AppStrings.current.t('ocr.model_downloading'));
    expect(userErrorText(const ArabicOcrMissing()),
        AppStrings.current.t('ocr.ar_need_model'));
  });
}
