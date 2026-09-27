import 'package:dosya_okuyucu/services/lang_detect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Çeviride "otomatik algıla" (2026-09-27).
void main() {
  test('Latin yazılı diller', () {
    expect(
        LangDetect.detect(
            'Sadece müslüman olmayan ülkelerde değil, müslüman ülkelerde de '
            'fikrî ve ahlâkî bir düşüşün yaşandığı bu günümüzde'),
        TranslateLanguage.turkish);
    expect(
        LangDetect.detect('The quick brown fox jumps over the lazy dog and '
            'this is a test of the system.'),
        TranslateLanguage.english);
    expect(LangDetect.detect('Das ist nicht der Weg, und die Straße ist lang.'),
        TranslateLanguage.german);
    expect(
        LangDetect.detect('Le chat est sur la table et les enfants sont dans '
            'le jardin.'),
        TranslateLanguage.french);
    expect(LangDetect.detect('¿Dónde está el baño? Por favor, señor.'),
        TranslateLanguage.spanish);
    expect(
        LangDetect.detect('Não sei se você vai, mas os meninos são da casa.'),
        TranslateLanguage.portuguese);
  });

  test('yazı sistemiyle belirlenenler', () {
    expect(
        LangDetect.detect('قال موسى لقومه يا قوم'), TranslateLanguage.arabic);
    expect(LangDetect.detect('این کتاب برای شما چگونه است'),
        TranslateLanguage.persian);
    expect(LangDetect.detect('Привет, как дела?'), TranslateLanguage.russian);
    expect(LangDetect.detect('これは日本語の文章です'), TranslateLanguage.japanese);
    expect(LangDetect.detect('这是中文句子'), TranslateLanguage.chinese);
    expect(LangDetect.detect('안녕하세요 반갑습니다'), TranslateLanguage.korean);
  });

  test('emin olunamayan metin null (son dile düşülür)', () {
    expect(LangDetect.detect('123 456'), isNull);
    expect(LangDetect.detect(''), isNull);
    expect(LangDetect.detect('OK'), isNull);
  });
}
