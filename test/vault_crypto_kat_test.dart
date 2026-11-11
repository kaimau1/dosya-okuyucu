import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/vault_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _unhex(String h) => Uint8List.fromList([
      for (var i = 0; i < h.length; i += 2)
        int.parse(h.substring(i, i + 2), radix: 16),
    ]);

/// **G3.7 (2026-11-11) sabit vektörler** — kasa biçimi (`DVK1`) ve PIN
/// türetmesi kazara değişirse kullanıcının kasası açılmaz hâle gelir; bu
/// test bayt bayt kilitler. Beklenen değerler bağımsız bir uygulamayla
/// (Python `hashlib` + `cryptography`) hesaplandı.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('vault_kat'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('PBKDF2-HMAC-SHA256 RFC 7914 vektörü (yerel yolla aynı algoritma)', () {
    final key = VaultCrypto.deriveKey(
        'passwd', Uint8List.fromList(utf8.encode('salt')),
        iterations: 1);
    expect(_hex(key),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc');
  });

  test('üretim tur sayısı 600 bin (G3.1)', () {
    expect(VaultCrypto.pinIterations, 600000);
  });

  const plain = 'Dosya Okuyucu kasa sabit vektor';
  const expected = '44564b31404142434445464748494a4b4c4d4e4f'
      'e477f45baf3980cd8954fe55e39059fc3ebcf4d7b21e7c579e09ade046aa34'
      '665e32be102b06eb132b08cd9860dd04b4e9449c673c0543f3b14099c823da77';
  final master = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final iv = Uint8List.fromList(List<int>.generate(16, (i) => 0x40 + i));

  Future<File> encrypted() async {
    final src = File(p.join(tmp.path, 'a.txt'))..writeAsStringSync(plain);
    final dst = p.join(tmp.path, 'a.dvk');
    await VaultCrypto.encryptFile(src.path, dst, master, debugIv: iv);
    return File(dst);
  }

  test('DVK1: sabit anahtar + IV → bilinen çıktı', () async {
    final f = await encrypted();
    expect(_hex(f.readAsBytesSync()), expected);
  });

  test('bilinen şifreli dosya çözülür', () async {
    final enc = File(p.join(tmp.path, 'k.dvk'))
      ..writeAsBytesSync(_unhex(expected));
    final out = p.join(tmp.path, 'k.txt');
    await VaultCrypto.decryptFile(enc.path, out, master);
    expect(File(out).readAsStringSync(), plain);
  });

  Future<void> expectRejected(Uint8List bytes) async {
    final enc = File(p.join(tmp.path, 'bad.dvk'))..writeAsBytesSync(bytes);
    final out = p.join(tmp.path, 'bad.txt');
    await expectLater(VaultCrypto.decryptFile(enc.path, out, master),
        throwsA(isA<VaultCorrupt>()));
    expect(File(out).existsSync(), isFalse,
        reason: 'doğrulanmayan dosyanın düz kopyası diske yazılmaz');
  }

  test('bozuk MAC açılmaz', () async {
    final b = _unhex(expected);
    b[b.length - 1] ^= 0x01;
    await expectRejected(b);
  });

  test('içerikte tek bayt değişikliği açılmaz', () async {
    final b = _unhex(expected);
    b[24] ^= 0x80;
    await expectRejected(b);
  });

  test('IV değişikliği açılmaz', () async {
    final b = _unhex(expected);
    b[5] ^= 0x01;
    await expectRejected(b);
  });

  test('kesik dosya açılmaz', () async {
    final b = _unhex(expected);
    await expectRejected(Uint8List.sublistView(b, 0, b.length - 5));
    await expectRejected(Uint8List.sublistView(b, 0, 30));
  });

  test('yanlış ana anahtar açılmaz', () async {
    final enc = File(p.join(tmp.path, 'w.dvk'))
      ..writeAsBytesSync(_unhex(expected));
    final wrong = Uint8List.fromList(List<int>.generate(32, (i) => 31 - i));
    await expectLater(
        VaultCrypto.decryptFile(enc.path, p.join(tmp.path, 'w.txt'), wrong),
        throwsA(isA<VaultCorrupt>()));
  });
}
