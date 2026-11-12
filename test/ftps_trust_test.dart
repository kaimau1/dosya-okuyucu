import 'package:dosya_okuyucu/services/fm/remote/ftps_trust.dart';
import 'package:dosya_okuyucu/services/fm/remote/sftp_host_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// G8.2: FTPS kendinden imzalı sertifika — ilk kullanımda güven.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FtpsTrust.resetForTest();
    SftpHostKeys.prompt = null;
  });

  const certA = [1, 2, 3], certB = [4, 5, 6];

  test('bilinmeyen sertifika el sıkışmada reddedilir, bekleyene yazılır', () async {
    await FtpsTrust.preload();
    expect(FtpsTrust.checkDer(certA, 'nas', 990), isFalse);
    expect(FtpsTrust.takePending('nas', 990), FtpsTrust.fingerprintOf(certA));
    expect(FtpsTrust.takePending('nas', 990), isNull);
  });

  test('onaylanan sertifika kaydedilir; sonraki bağlantı sormadan geçer', () async {
    var asked = 0;
    SftpHostKeys.prompt = (k) async {
      asked++;
      expect(k.type, 'TLS');
      return true;
    };
    await FtpsTrust.preload();
    FtpsTrust.checkDer(certA, 'nas', 990);
    final fp = FtpsTrust.takePending('nas', 990)!;
    expect(await FtpsTrust.confirm('nas', 990, fp), isTrue);
    FtpsTrust.resetForTest();
    await FtpsTrust.preload(); // diskten
    expect(FtpsTrust.checkDer(certA, 'NAS', 990), isTrue);
    expect(asked, 1);
  });

  test('değişen sertifika: kanca yokken RET, kancada önceki iz gösterilir', () async {
    await FtpsTrust.preload();
    expect(await FtpsTrust.confirm('nas', 21, FtpsTrust.fingerprintOf(certA)),
        isTrue); // kanca yok + kayıt yok → TOFU
    expect(FtpsTrust.checkDer(certB, 'nas', 21), isFalse);
    final fpB = FtpsTrust.takePending('nas', 21)!;
    expect(await FtpsTrust.confirm('nas', 21, fpB), isFalse);
    String? previous;
    SftpHostKeys.prompt = (k) async {
      previous = k.previous;
      return false;
    };
    expect(await FtpsTrust.confirm('nas', 21, fpB), isFalse);
    expect(previous, FtpsTrust.fingerprintOf(certA));
  });
}
