import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/remote/ftp_service.dart';
import 'package:dosya_okuyucu/services/key_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Güvenlik Faz G2.2 (B2): telefonun FTP sunucu parolası Keystore'la sarılı;
/// eski düz `ftpd_password` göç eder; rastgele kipte parola diske yazılmaz.
/// (Parolalar uydurma — gerçek sır yok.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void fakeKeystore() {
    KeyVault.wrap = (p) async => Uint8List.fromList([0x4B, ...p.reversed]);
    KeyVault.unwrap = (b) async => b.isEmpty || b.first != 0x4B
        ? null
        : Uint8List.fromList(b.sublist(1).reversed.toList());
  }

  tearDown(() {
    KeyVault.reset();
    FtpService.instance.resetForTest();
  });

  test('eski düz parola (elle kip) → sarılı kayıt, parola korunur', () async {
    fakeKeystore();
    SharedPreferences.setMockInitialValues({
      'ftpd_random_password': false,
      'ftpd_password': 'sahte-ftp-1',
    });
    FtpService.instance.resetForTest();
    await FtpService.instance.load();
    expect(FtpService.instance.password, 'sahte-ftp-1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ftpd_password'), isNull);
    final sealed = prefs.getString('ftpd_password_sealed');
    expect(sealed, isNotNull);
    expect(sealed, isNot(contains('sahte-ftp-1')));

    // Yeniden okuma sarılı kayıttan.
    FtpService.instance.resetForTest();
    await FtpService.instance.load();
    expect(FtpService.instance.password, 'sahte-ftp-1');
  });

  test('elle parola yazımı düz kayıt bırakmaz', () async {
    fakeKeystore();
    SharedPreferences.setMockInitialValues({'ftpd_random_password': false});
    FtpService.instance.resetForTest();
    await FtpService.instance.load();
    await FtpService.instance.setCredentials(password: 'sahte-ftp-2');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ftpd_password'), isNull);
    expect(await FtpService.readStoredPassword(prefs), 'sahte-ftp-2');
  });

  test('rastgele kipte eski düz kayıt da diskte düz kalmaz', () async {
    fakeKeystore();
    SharedPreferences.setMockInitialValues({'ftpd_password': 'eski-rastgele'});
    FtpService.instance.resetForTest();
    await FtpService.instance.load();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ftpd_password'), isNull);
    // Rastgele kipte kayıtlı parola gösterilmez (oturumluk üretilir).
    expect(FtpService.instance.password, isEmpty);
  });

  test('Keystore yoksa düz yol sürer, parola kaybolmaz', () async {
    KeyVault.wrap = (_) async => null;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await FtpService.writeStoredPassword(prefs, 'sahte-ftp-3');
    expect(prefs.getString('ftpd_password'), 'sahte-ftp-3');
    expect(await FtpService.readStoredPassword(prefs), 'sahte-ftp-3');
  });
}
