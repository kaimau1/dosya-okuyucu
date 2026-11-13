import 'package:dosya_okuyucu/services/fm/native_extras.dart';
import 'package:flutter_test/flutter_test.dart';

// G7.8 (GUVENLIK_PLANI): kurulum öncesi paket bilgisi ve kırmızı uyarı kararı.
void main() {
  test('kanaldan gelen harita okunur', () {
    final c = PackageCheck.fromMap({
      'label': 'Örnek',
      'package': 'com.ornek',
      'version': '1.2.3',
      'installedVersion': '1.2.0',
      'sha256': ['AA:BB', 7],
      'sameSigner': true,
      'self': false,
      'unsafe': false,
    });
    expect(c.package, 'com.ornek');
    expect(c.sha256, ['AA:BB']);
    expect(c.sameSigner, isTrue);
    expect(c.warning, isNull);
  });

  test('bu uygulamanın adıyla yabancı imza → self_foreign', () {
    const c = PackageCheck(
        package: 'x', sha256: ['AA'], self: true, sameSigner: false);
    expect(c.warning, 'self_foreign');
    // İmza karşılaştırılamadıysa da (null) güvenli taraf: uyar.
    const d = PackageCheck(package: 'x', sha256: ['AA'], self: true);
    expect(d.warning, 'self_foreign');
  });

  test('yüklü uygulamadan farklı imza → foreign', () {
    const c = PackageCheck(package: 'x', sha256: ['AA'], sameSigner: false);
    expect(c.warning, 'foreign');
  });

  test('kötü ZIP girdi adı her şeyden önce gelir', () {
    const c = PackageCheck(
        package: 'x', sha256: ['AA'], sameSigner: true, unsafe: true);
    expect(c.warning, 'unsafe');
  });

  test('imza okunamadı → unsigned; yüklü değilse uyarı yok', () {
    expect(const PackageCheck(package: 'x').warning, 'unsigned');
    expect(const PackageCheck(package: 'x', sha256: ['AA']).warning, isNull);
  });
}
