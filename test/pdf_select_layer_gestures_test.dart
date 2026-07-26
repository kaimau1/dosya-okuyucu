import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Yapısal koruma: seçim katmanı jest arenasına girmemeli.**
///
/// Bu kural üç turda üç kez bozuldu ve her seferinde kullanıcı "sayfayı
/// kaydıramıyorum / zoom yapamıyorum" diye bildirdi (bkz. HAFIZA 6/8/10. tur).
/// Sebep hep aynı: `PdfSelectLayer` sayfanın ÜSTÜNDE durduğu için oraya konan
/// her `GestureDetector` tanıyıcısı, pdfrx'in kaydırma/ölçek tanıyıcısıyla
/// arenada yarışır. Uzun basış süresi dolunca kazanır ve ötekini eler:
/// parmağını bir an dinlendirip kaydıran ya da iki parmağını koyup duraklayan
/// kullanıcıda gezinme tamamen ölür.
///
/// Katman bu yüzden yalnız `Listener` kullanıyor (arenaya girmez) ve uzun
/// basışı elle ölçüyor. Kuralı davranış testiyle yakalamak mümkün değil —
/// `PdfSelectLayer` gerçek bir pdfium `PdfPage`'i istiyor, o da testte yok.
/// Bu yüzden koruma kaynak düzeyinde: sayfayı kaplayan alanda uzun basış
/// tanıyıcısı KURULMAMALI.
void main() {
  test('seçim katmanı uzun basış tanıyıcısı kurmuyor', () {
    final source = File('lib/widgets/pdf_select_layer.dart').readAsStringSync();
    // Yorumları ele: açıklama metninde "onLongPress" geçebilir.
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      code.contains('onLongPress'),
      isFalse,
      reason: 'PdfSelectLayer sayfanın üstünde durur. Uzun basış TANIYICISI '
          '(GestureDetector.onLongPress*) eklenirse jest arenasında pdfrx\'in '
          'kaydırma/ölçek tanıyıcısını eler ve kullanıcı sayfayı kaydıramaz / '
          'yakınlaştıramaz. Uzun basış Listener + zamanlayıcı ile elle '
          'ölçülmeli (bkz. dosyanın başındaki kök neden açıklaması).',
    );
  });
}
