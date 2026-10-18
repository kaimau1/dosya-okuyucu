import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:dosya_okuyucu/services/fm/secure_vault.dart';
import 'package:dosya_okuyucu/services/fm/vault_crypto.dart';

/// **Şifreli kasa** (2026-10-18): dosya gidiş-dönüş, yanlış anahtar ve
/// oynanmış dosya yakalanır, PIN'le kasa açılır.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vault_test');
  });

  tearDown(() {
    SecureVault.debugRoot = null;
    SecureVault.instance.debugReset();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('GCM: doğru anahtar açar, yanlış anahtar null', () {
    final key = VaultCrypto.randomBytes(32);
    final sealed = VaultCrypto.seal(key, Uint8List.fromList([1, 2, 3]));
    expect(VaultCrypto.open(key, sealed), [1, 2, 3]);
    expect(VaultCrypto.open(VaultCrypto.randomBytes(32), sealed), isNull);
  });

  test('PBKDF2 aynı PIN + tuz → aynı anahtar', () {
    final salt = VaultCrypto.randomBytes(16);
    final a = VaultCrypto.deriveKey('1234', salt, iterations: 1000);
    final b = VaultCrypto.deriveKey('1234', salt, iterations: 1000);
    final c = VaultCrypto.deriveKey('1235', salt, iterations: 1000);
    expect(a, b);
    expect(a, isNot(c));
  });

  test('dosya: gidiş-dönüş (çok parçalı), içerik düz metin olarak görünmez',
      () async {
    final src = File(p.join(tmp.path, 'kimlik.txt'));
    final data = Uint8List.fromList(
        List<int>.generate((1 << 20) * 2 + 777, (i) => i % 251));
    src.writeAsBytesSync(data);
    final enc = p.join(tmp.path, 'x.dvk');
    final out = p.join(tmp.path, 'geri.txt');
    final key = VaultCrypto.randomBytes(32);
    await VaultCrypto.encryptFile(src.path, enc, key);
    final encBytes = File(enc).readAsBytesSync();
    expect(encBytes.length, data.length + 4 + 16 + 32);
    expect(encBytes.sublist(20, 60), isNot(data.sublist(0, 40)));
    await VaultCrypto.decryptFile(enc, out, key);
    expect(File(out).readAsBytesSync(), data);
  });

  test('oynanmış dosya ve yanlış anahtar açılmaz, çıktı yazılmaz', () async {
    final src = File(p.join(tmp.path, 'a.bin'))
      ..writeAsBytesSync(List<int>.filled(5000, 7));
    final enc = p.join(tmp.path, 'a.dvk');
    final key = VaultCrypto.randomBytes(32);
    await VaultCrypto.encryptFile(src.path, enc, key);
    final out = p.join(tmp.path, 'out.bin');
    await expectLater(
        VaultCrypto.decryptFile(enc, out, VaultCrypto.randomBytes(32)),
        throwsA(isA<VaultCorrupt>()));
    expect(File(out).existsSync(), isFalse);
    final bytes = File(enc).readAsBytesSync();
    bytes[100] ^= 1;
    File(enc).writeAsBytesSync(bytes);
    await expectLater(VaultCrypto.decryptFile(enc, out, key),
        throwsA(isA<VaultCorrupt>()));
  });

  test('kasa: kur, dosya ekle (aslı silinir), kilitle, PIN ile aç, geri çıkar',
      () async {
    SecureVault.debugRoot = p.join(tmp.path, 'kasa');
    final vault = SecureVault.instance;
    await vault.create('2468');
    final doc = File(p.join(tmp.path, 'tapu.pdf'))
      ..writeAsBytesSync(List<int>.generate(3000, (i) => i % 200));
    final result = await vault.add([doc.path]);
    expect(result.succeeded, 1);
    expect(doc.existsSync(), isFalse);
    expect(vault.items.single.name, 'tapu.pdf');

    vault.debugReset(); // kilitli (bellekten silindi)
    expect(await vault.unlockWithPin('0000'), isFalse);
    expect(await vault.unlockWithPin('2468'), isTrue);
    expect(vault.items.single.name, 'tapu.pdf');

    final back = await vault.restore(vault.items.single);
    expect(File(back).readAsBytesSync().length, 3000);
    expect(vault.items, isEmpty);
  });
}
