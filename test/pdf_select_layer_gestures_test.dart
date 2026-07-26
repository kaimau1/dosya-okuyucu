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
  String codeOf(String path) => File(path)
      .readAsStringSync()
      .split('\n')
      // Yorumları ele: açıklama metinlerinde aranan adlar geçiyor.
      .where((line) =>
          !line.trimLeft().startsWith('//') && !line.trimLeft().startsWith('///'))
      .join('\n');

  test('seçim boyayıcısı dokunuşu yutmuyor (hitTest => false)', () {
    expect(
      codeOf('lib/widgets/pdf_select_layer.dart')
          .contains('bool hitTest(Offset position) => false'),
      isTrue,
      reason: 'Flutter\'da arka plan boyayıcısı için '
          'RenderCustomPaint.hitTestSelf, painter.hitTest(p) ?? TRUE yazar; '
          'CustomPainter.hitTest varsayılanı null olduğu için `painter:` '
          'verilmiş her CustomPaint kapladığı alandaki dokunuşları YUTAR. '
          'Bu katmanın boyayıcısı sayfanın tamamını kaplıyor: geçersiz kılma '
          'kalkarsa pdfrx\'in InteractiveViewer\'ı (Stack\'te en altta) '
          'işaretçiyi hiç görmez ve kullanıcı sayfayı kaydıramaz / '
          'yakınlaştıramaz. Sarmalayıcıya translucent vermek YETMEZ.',
    );
  });

  test('seçim katmanı uzun basış tanıyıcısı kurmuyor', () {
    final code = codeOf('lib/widgets/pdf_select_layer.dart');

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
