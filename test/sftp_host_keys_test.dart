import 'package:dosya_okuyucu/services/fm/remote/sftp_host_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Güvenlik G8.1 (B16): SFTP sunucu anahtarı TOFU.
void main() {
  const fpA = 'SHA256:QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUE';
  const fpB = 'SHA256:QkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkI';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SftpHostKeys.prompt = null;
  });

  test('karar tablosu', () {
    expect(SftpHostKeys.decide(null, 'ssh-ed25519', fpA), 'ask');
    expect(SftpHostKeys.decide('ssh-ed25519 $fpA', 'ssh-ed25519', fpA), 'accept');
    expect(SftpHostKeys.decide('ssh-ed25519 $fpA', 'ssh-ed25519', fpB), 'changed');
    expect(SftpHostKeys.decide('ssh-rsa $fpA', 'ssh-ed25519', fpA), 'changed');
  });

  test('ilk anahtar sorulur ve kaydedilir; aynı anahtar bir daha sorulmaz', () async {
    var asked = 0;
    SftpHostKeys.prompt = (k) async {
      asked++;
      expect(k.changed, isFalse);
      return true;
    };
    expect(await SftpHostKeys.verify('NAS.local', 22, 'ssh-ed25519', fpA), isTrue);
    expect(await SftpHostKeys.verify('nas.local', 22, 'ssh-ed25519', fpA), isTrue);
    expect(asked, 1);
  });

  test('değişen anahtar: kanca yoksa RED, kanca reddederse kayıt değişmez', () async {
    expect(await SftpHostKeys.verify('h', 22, 'ssh-ed25519', fpA), isTrue);
    expect(await SftpHostKeys.verify('h', 22, 'ssh-ed25519', fpB), isFalse);
    HostKeyPrompt? seen;
    SftpHostKeys.prompt = (k) async {
      seen = k;
      return false;
    };
    expect(await SftpHostKeys.verify('h', 22, 'ssh-ed25519', fpB), isFalse);
    expect(seen?.changed, isTrue);
    expect(seen?.previous, fpA);
    // Eski anahtar hâlâ geçerli.
    SftpHostKeys.prompt = null;
    expect(await SftpHostKeys.verify('h', 22, 'ssh-ed25519', fpA), isTrue);
  });

  test('ilk anahtar reddedilirse kaydedilmez; port ayrı kayıt', () async {
    SftpHostKeys.prompt = (_) async => false;
    expect(await SftpHostKeys.verify('h', 22, 'ssh-ed25519', fpA), isFalse);
    SftpHostKeys.prompt = (k) async => !k.changed;
    expect(await SftpHostKeys.verify('h', 2222, 'ssh-ed25519', fpB), isTrue);
    expect(await SftpHostKeys.verify('h', 22, 'ssh-ed25519', fpA), isTrue);
  });
}
