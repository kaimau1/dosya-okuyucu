/// **Parolalı Office dosyası (ECMA-376 Agile şifreleme)** — Faz 36 madde 6
/// "parola ile aç/koru". Excel 2010+ biçimi: AES-256-CBC, SHA-512, 100 000
/// tur anahtar türetme, HMAC-SHA512 bütünlük. Kap OLE2 CFB'dir:
/// `EncryptionInfo` + `EncryptedPackage` + `\u0006DataSpaces` deposu.
///
/// [MS-OFFCRYPTO] 2.3.4.10–2.3.4.15. Ağır (100 bin SHA-512) → izolatta.
/// Parola ve anahtarlar hiçbir yere yazılmaz/günlüğe düşmez (KVKK).
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'ole_cfb.dart';
import 'ole_cfb_writer.dart';

class OfficeCryptoException implements Exception {
  /// `wrong_password` | `unsupported` | `corrupt`.
  final String code;
  const OfficeCryptoException(this.code);
  @override
  String toString() => 'OfficeCrypto: $code';
}

abstract final class OfficeCrypto {
  static const _bkVerifierInput = [0xfe, 0xa7, 0xd2, 0x76, 0x3b, 0x4b, 0x9e, 0x79];
  static const _bkVerifierValue = [0xd7, 0xaa, 0x0f, 0x6d, 0x30, 0x61, 0x34, 0x4e];
  static const _bkKey = [0x14, 0x6e, 0x0b, 0xe7, 0xab, 0xac, 0xd0, 0xd6];
  static const _bkHmacKey = [0x5f, 0xb2, 0xad, 0x01, 0x0c, 0xb9, 0xe1, 0xf6];
  static const _bkHmacValue = [0xa0, 0x67, 0x7f, 0x02, 0xb2, 0x2c, 0x84, 0x33];
  static const _segment = 4096;

  /// OLE kabı ve içinde `EncryptionInfo` akışı varsa parolalı Office belgesi.
  static bool isEncrypted(Uint8List bytes) {
    if (!OleFile.looksLikeOle(bytes)) return false;
    final ole = OleFile.tryParse(bytes);
    return ole?.stream('EncryptionInfo') != null &&
        ole?.stream('EncryptedPackage') != null;
  }

  // ── çözme ──────────────────────────────────────────────────────────────

  static Uint8List decrypt(Uint8List bytes, String password) {
    final ole = OleFile.tryParse(bytes);
    final info = ole?.stream('EncryptionInfo');
    final package = ole?.stream('EncryptedPackage');
    if (info == null || package == null) {
      throw const OfficeCryptoException('corrupt');
    }
    final hdr = ByteData.sublistView(info);
    if (info.length < 8 || hdr.getUint16(0, Endian.little) != 4 ||
        hdr.getUint16(2, Endian.little) != 4) {
      // Standart (RC4/eski AES) şifreleme desteklenmiyor.
      throw const OfficeCryptoException('unsupported');
    }
    final xml = utf8.decode(info.sublist(8), allowMalformed: true);
    String attr(String tag, String name) {
      final el = RegExp('<(?:\\w+:)?$tag\\b[^>]*>').firstMatch(xml)?.group(0);
      final m = el == null ? null : RegExp('\\b$name="([^"]*)"').firstMatch(el);
      if (m == null) throw const OfficeCryptoException('corrupt');
      return m.group(1)!;
    }

    final keySalt = base64.decode(attr('keyData', 'saltValue'));
    final keyBits = int.parse(attr('encryptedKey', 'keyBits'));
    final spin = int.parse(attr('encryptedKey', 'spinCount'));
    final pwSalt = base64.decode(attr('encryptedKey', 'saltValue'));
    if (attr('encryptedKey', 'hashAlgorithm') != 'SHA512' ||
        attr('keyData', 'cipherAlgorithm') != 'AES') {
      throw const OfficeCryptoException('unsupported');
    }
    final h = _passwordHash(password, pwSalt, spin);
    final keyLen = keyBits ~/ 8;
    final vInput = _aes(false, _derive(h, _bkVerifierInput, keyLen), pwSalt,
        base64.decode(attr('encryptedKey', 'encryptedVerifierHashInput')));
    final vValue = _aes(false, _derive(h, _bkVerifierValue, keyLen), pwSalt,
        base64.decode(attr('encryptedKey', 'encryptedVerifierHashValue')));
    final expect = _sha512(vInput.sublist(0, 16));
    for (var i = 0; i < 64; i++) {
      if (expect[i] != vValue[i]) {
        throw const OfficeCryptoException('wrong_password');
      }
    }
    final secret = _aes(false, _derive(h, _bkKey, keyLen), pwSalt,
            base64.decode(attr('encryptedKey', 'encryptedKeyValue')))
        .sublist(0, keyLen);
    final size = ByteData.sublistView(package).getUint64(0, Endian.little);
    final out = BytesBuilder(copy: false);
    var i = 0;
    for (var off = 8; off < package.length; off += _segment, i++) {
      final end = math.min(off + _segment, package.length);
      out.add(_aes(false, secret, _iv(keySalt, i), package.sublist(off, end)));
    }
    final plain = out.toBytes();
    if (size > plain.length) throw const OfficeCryptoException('corrupt');
    return Uint8List.sublistView(plain, 0, size);
  }

  static Future<Uint8List> decryptInBackground(Uint8List bytes, String password) =>
      Isolate.run(() => decrypt(bytes, password));

  // ── şifreleme ──────────────────────────────────────────────────────────

  static Uint8List encrypt(Uint8List plain, String password,
      {int spinCount = 100000}) {
    final rnd = _random();
    Uint8List bytes(int n) => rnd.nextBytes(n);
    final keySalt = bytes(16), pwSalt = bytes(16);
    final secret = bytes(32);
    // Paket: 8 bayt boy + 4096'lık dilimler (her biri kendi IV'siyle).
    final pkg = BytesBuilder(copy: false)
      ..add((ByteData(8)..setUint64(0, plain.length, Endian.little))
          .buffer
          .asUint8List());
    var i = 0;
    for (var off = 0; off < plain.length; off += _segment, i++) {
      final end = math.min(off + _segment, plain.length);
      pkg.add(_aes(true, secret, _iv(keySalt, i), _pad16(plain.sublist(off, end))));
    }
    final package = pkg.toBytes();
    // Bütünlük: HMAC anahtarı + paket HMAC'i, gizli anahtarla şifreli.
    final hmacKey = bytes(64);
    final hmac = HMac(SHA512Digest(), 128)..init(KeyParameter(hmacKey));
    final hmacValue = hmac.process(package);
    final encHmacKey = _aes(true, secret, _ivFor(keySalt, _bkHmacKey), hmacKey);
    final encHmacValue = _aes(true, secret, _ivFor(keySalt, _bkHmacValue), hmacValue);
    // Parola doğrulayıcı + gizli anahtar, paroladan türetilen anahtarlarla.
    final h = _passwordHash(password, pwSalt, spinCount);
    final verifier = bytes(16);
    final encVInput = _aes(true, _derive(h, _bkVerifierInput, 32), pwSalt, verifier);
    final encVValue =
        _aes(true, _derive(h, _bkVerifierValue, 32), pwSalt, _sha512(verifier));
    final encKey = _aes(true, _derive(h, _bkKey, 32), pwSalt, secret);
    String b64(List<int> v) => base64.encode(v);
    const alg = 'saltSize="16" blockSize="16" keyBits="256" hashSize="64" '
        'cipherAlgorithm="AES" cipherChaining="ChainingModeCBC" hashAlgorithm="SHA512"';
    final xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r\n'
        '<encryption xmlns="http://schemas.microsoft.com/office/2006/encryption" '
        'xmlns:p="http://schemas.microsoft.com/office/2006/keyEncryptor/password" '
        'xmlns:c="http://schemas.microsoft.com/office/2006/keyEncryptor/certificate">'
        '<keyData $alg saltValue="${b64(keySalt)}"/>'
        '<dataIntegrity encryptedHmacKey="${b64(encHmacKey)}" '
        'encryptedHmacValue="${b64(encHmacValue)}"/>'
        '<keyEncryptors><keyEncryptor uri="http://schemas.microsoft.com/office/2006/keyEncryptor/password">'
        '<p:encryptedKey spinCount="$spinCount" $alg saltValue="${b64(pwSalt)}" '
        'encryptedVerifierHashInput="${b64(encVInput)}" '
        'encryptedVerifierHashValue="${b64(encVValue)}" '
        'encryptedKeyValue="${b64(encKey)}"/></keyEncryptor></keyEncryptors></encryption>';
    final info = BytesBuilder(copy: false)
      ..add(const [4, 0, 4, 0, 0x40, 0, 0, 0])
      ..add(utf8.encode(xml));
    return CfbWriter.write([
      CfbNode.stream('EncryptionInfo', info.toBytes()),
      CfbNode.stream('EncryptedPackage', package),
      CfbNode.storage('\u0006DataSpaces', [
        CfbNode.stream('Version', _dsVersion()),
        CfbNode.stream('DataSpaceMap', _dsMap()),
        CfbNode.storage('DataSpaceInfo', [
          CfbNode.stream('StrongEncryptionDataSpace', _dsDefinition()),
        ]),
        CfbNode.storage('TransformInfo', [
          CfbNode.storage('StrongEncryptionTransform', [
            CfbNode.stream('\u0006Primary', _dsTransform()),
          ]),
        ]),
      ]),
    ]);
  }

  static Future<Uint8List> encryptInBackground(Uint8List plain, String password) =>
      Isolate.run(() => encrypt(plain, password));

  // ── DataSpaces yapıları ([MS-OFFCRYPTO] 2.1, 2.2) ──────────────────────

  /// UNICODE-LP-P4: bayt uzunluğu + UTF-16LE + 4'e dolgu.
  static List<int> _lp(String s) {
    final b = BytesBuilder();
    final units = s.codeUnits;
    b.add(_u32(units.length * 2));
    for (final u in units) {
      b.add([u & 0xff, u >> 8]);
    }
    final pad = (4 - (units.length * 2) % 4) % 4;
    b.add(List.filled(pad, 0));
    return b.toBytes();
  }

  static List<int> _u32(int v) =>
      (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();

  static List<int> _ver() => [1, 0, 0, 0]; // major 1, minor 0 (uint16 × 2)

  static Uint8List _dsVersion() => Uint8List.fromList([
        ..._lp('Microsoft.Container.DataSpaces'),
        ..._ver(), ..._ver(), ..._ver(),
      ]);

  static Uint8List _dsMap() {
    final entry = [
      ..._u32(1), // ReferenceComponentCount
      ..._u32(0), // tür: akış
      ..._lp('EncryptedPackage'),
      ..._lp('StrongEncryptionDataSpace'),
    ];
    return Uint8List.fromList([
      ..._u32(8), // HeaderLength
      ..._u32(1), // EntryCount
      ..._u32(entry.length + 4),
      ...entry,
    ]);
  }

  static Uint8List _dsDefinition() => Uint8List.fromList([
        ..._u32(8),
        ..._u32(1),
        ..._lp('StrongEncryptionTransform'),
      ]);

  static Uint8List _dsTransform() {
    final id = _lp('{FF9A3F03-56EF-4613-BDD5-5A41C1D07246}');
    return Uint8List.fromList([
      ..._u32(8 + id.length), // TransformLength (TransformName'e kadar)
      ..._u32(1), // TransformType
      ...id,
      ..._lp('Microsoft.Container.EncryptionTransform'),
      ..._ver(), ..._ver(), ..._ver(),
      // EncryptionTransformInfo: ad (boş UTF-8-LP-P4), blok, kip, ayrılmış=4.
      ..._u32(0), ..._u32(0), ..._u32(0), ..._u32(4),
    ]);
  }

  // ── kripto yardımcıları ────────────────────────────────────────────────

  static Uint8List _sha512(List<int> data) =>
      SHA512Digest().process(Uint8List.fromList(data));

  /// H0 = SHA512(tuz + UTF-16LE parola); Hn = SHA512(LE32(n) + Hn-1).
  static Uint8List _passwordHash(String password, List<int> salt, int spin) {
    final pw = <int>[];
    for (final u in password.codeUnits) {
      pw..add(u & 0xff)..add(u >> 8);
    }
    var h = _sha512([...salt, ...pw]);
    final d = SHA512Digest();
    final buf = Uint8List(4 + 64);
    final bd = ByteData.sublistView(buf);
    for (var i = 0; i < spin; i++) {
      bd.setUint32(0, i, Endian.little);
      buf.setRange(4, 68, h);
      d.reset();
      h = d.process(buf);
    }
    return h;
  }

  /// SHA512(H + blok anahtarı), anahtar boyuna kırp ya da 0x36 ile doldur.
  static Uint8List _derive(Uint8List h, List<int> blockKey, int len) {
    final full = _sha512([...h, ...blockKey]);
    if (full.length >= len) return Uint8List.sublistView(full, 0, len);
    return Uint8List(len)
      ..fillRange(0, len, 0x36)
      ..setAll(0, full);
  }

  static Uint8List _iv(List<int> salt, int segment) =>
      Uint8List.sublistView(_sha512([...salt, ..._u32(segment)]), 0, 16);

  static Uint8List _ivFor(List<int> salt, List<int> blockKey) =>
      Uint8List.sublistView(_sha512([...salt, ...blockKey]), 0, 16);

  static Uint8List _pad16(List<int> data) {
    final n = ((data.length + 15) ~/ 16) * 16;
    return Uint8List(n == 0 ? 16 : n)..setAll(0, data);
  }

  /// AES-CBC (dolgusuz — veri 16'nın katı olmalı; değilse sıfırla doldurulur).
  static Uint8List _aes(bool encrypt, List<int> key, List<int> iv, List<int> data) {
    final input = data.length % 16 == 0 ? Uint8List.fromList(data) : _pad16(data);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(encrypt,
          ParametersWithIV(KeyParameter(Uint8List.fromList(key)), Uint8List.fromList(iv)));
    final out = Uint8List(input.length);
    for (var off = 0; off < input.length; off += 16) {
      cipher.processBlock(input, off, out, off);
    }
    return out;
  }

  static SecureRandom _random() {
    final r = math.Random.secure();
    return FortunaRandom()
      ..seed(KeyParameter(
          Uint8List.fromList(List<int>.generate(32, (_) => r.nextInt(256)))));
  }
}
