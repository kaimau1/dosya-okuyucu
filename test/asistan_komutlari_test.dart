import 'package:dosya_okuyucu/services/asistan_komutlari.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asistandan sesli okuma / durdurma kancası (kişisel derleme köprüsü).
void main() {
  test('açık dosya hemen okunur, başkası bekletilip açılınca alınır', () {
    var okundu = 0;
    final a = AsistanKomutlari.kaydet('/sd/a.pdf', oku: () => okundu++, durdur: () {});
    expect(AsistanKomutlari.oku('/sd/a.pdf'), isTrue);
    expect(okundu, 1);
    expect(AsistanKomutlari.oku(''), isTrue, reason: 'boş yol: açık olan');
    expect(okundu, 2);

    expect(AsistanKomutlari.oku('/sd/b.pdf'), isFalse);
    expect(AsistanKomutlari.bekleyenOkuAl('/sd/a.pdf'), isFalse);
    expect(AsistanKomutlari.bekleyenOkuAl('/sd/b.pdf'), isTrue);
    expect(AsistanKomutlari.bekleyenOkuAl('/sd/b.pdf'), isFalse, reason: 'bir kez');
    AsistanKomutlari.birak(a);
    expect(AsistanKomutlari.ustteki, isNull);
  });

  test('durdur üstteki görüntüleyiciye gider ve bekleyeni düşürür', () {
    var alt = 0, ust = 0;
    final a = AsistanKomutlari.kaydet('/a', oku: () {}, durdur: () => alt++);
    final b = AsistanKomutlari.kaydet('/b', oku: () {}, durdur: () => ust++);
    AsistanKomutlari.oku('/c');
    expect(AsistanKomutlari.durdur(), isTrue);
    expect((alt, ust), (0, 1));
    expect(AsistanKomutlari.bekleyenOkuAl('/c'), isFalse);
    AsistanKomutlari.birak(b);
    AsistanKomutlari.birak(a);
    expect(AsistanKomutlari.durdur(), isFalse);
  });
}
