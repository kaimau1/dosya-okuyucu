import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

/// **Şifreli kasanın kriptografisi** (2026-10-18) — saf Dart, test edilir.
///
/// - PIN → anahtar: PBKDF2-HMAC-SHA256 ([pinIterations] tur, 16 bayt tuz).
/// - Küçük veri (ana anahtar, dizin): AES-256-GCM (doğrulamalı — yanlış PIN
///   ya da bozuk veri sessizce çöp üretmez, hata verir).
/// - Dosyalar: **AES-256-CTR + HMAC-SHA256** (şifrele-sonra-doğrula).
///   GCM'nin tek seferde bütün veriyi istemesi büyük videoda belleği
///   doldururdu; CTR akış olarak 1 MB'lık parçalarla işler, HMAC de akışla
///   hesaplanır. Açarken ÖNCE doğrulama, SONRA çözme: bozuk/oynanmış bir
///   dosyanın yarısı diske yazılmaz.
///
/// Dosya biçimi: `DVK1` (4) · iv (16) · şifreli içerik · mac (32).
/// Şifreleme ve doğrulama anahtarları ana anahtardan ayrı türetilir.
abstract final class VaultCrypto {
  static const magic = [0x44, 0x56, 0x4B, 0x31]; // "DVK1"
  static const pinIterations = 120000;
  static const _chunk = 1 << 20;

  static final _rng = Random.secure();

  static Uint8List randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

  /// PIN'den 32 baytlık anahtar şifreleme anahtarı.
  static Uint8List deriveKey(String pin, Uint8List salt,
      {int iterations = pinIterations}) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(pin.trim())));
  }

  /// AES-256-GCM: `iv(12) + şifreli + etiket(16)`.
  static Uint8List seal(Uint8List key, Uint8List plain) {
    final iv = randomBytes(12);
    final gcm = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final out = gcm.process(plain);
    return Uint8List.fromList([...iv, ...out]);
  }

  /// [seal]in tersi; anahtar yanlışsa ya da veri bozuksa null.
  static Uint8List? open(Uint8List key, Uint8List sealed) {
    if (sealed.length < 12 + 16) return null;
    try {
      final gcm = GCMBlockCipher(AESEngine())
        ..init(false,
            AEADParameters(KeyParameter(key), 128, sealed.sublist(0, 12), Uint8List(0)));
      return gcm.process(sealed.sublist(12));
    } catch (_) {
      return null;
    }
  }

  static Uint8List _sub(Uint8List master, String label) => Uint8List.fromList(
      crypto.Hmac(crypto.sha256, master).convert(utf8.encode(label)).bytes);

  /// [src]i şifreleyip [dst]ye yazar. [onBytes] işlenen bayt sayısını bildirir.
  static Future<void> encryptFile(String src, String dst, Uint8List master,
      {void Function(int bytes)? onBytes, bool Function()? isCancelled}) async {
    final iv = randomBytes(16);
    final ctr = CTRStreamCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(_sub(master, 'enc')), iv));
    final macSink = _DigestSink();
    final mac = crypto.Hmac(crypto.sha256, _sub(master, 'mac'))
        .startChunkedConversion(macSink);
    final out = File(dst).openWrite();
    try {
      final header = Uint8List.fromList([...magic, ...iv]);
      out.add(header);
      mac.add(header);
      var done = 0;
      await for (final chunk in _chunks(File(src))) {
        if (isCancelled?.call() ?? false) throw const VaultCancelled();
        final enc = ctr.process(chunk);
        out.add(enc);
        mac.add(enc);
        done += chunk.length;
        onBytes?.call(done);
      }
      mac.close();
      out.add(macSink.value!.bytes);
      await out.flush();
    } finally {
      await out.close();
    }
  }

  /// Doğrular, sonra çözer. Doğrulama tutmazsa [VaultCorrupt] fırlatır ve
  /// [dst] hiç oluşturulmaz.
  static Future<void> decryptFile(String src, String dst, Uint8List master,
      {void Function(int bytes)? onBytes}) async {
    final file = File(src);
    final length = await file.length();
    if (length < 4 + 16 + 32) throw const VaultCorrupt();
    final raf = await file.open();
    Uint8List header, tag;
    try {
      header = await raf.read(20);
      await raf.setPosition(length - 32);
      tag = await raf.read(32);
    } finally {
      await raf.close();
    }
    for (var i = 0; i < 4; i++) {
      if (header[i] != magic[i]) throw const VaultCorrupt();
    }
    // 1. geçiş: doğrula.
    final macSink = _DigestSink();
    final mac = crypto.Hmac(crypto.sha256, _sub(master, 'mac'))
        .startChunkedConversion(macSink);
    await for (final chunk in _chunks(file, end: length - 32)) {
      mac.add(chunk);
    }
    mac.close();
    if (!_equal(macSink.value!.bytes, tag)) throw const VaultCorrupt();
    // 2. geçiş: çöz.
    final ctr = CTRStreamCipher(AESEngine())
      ..init(false,
          ParametersWithIV(KeyParameter(_sub(master, 'enc')), header.sublist(4)));
    final out = File(dst).openWrite();
    try {
      var done = 0;
      await for (final chunk in _chunks(file, start: 20, end: length - 32)) {
        out.add(ctr.process(chunk));
        done += chunk.length;
        onBytes?.call(done);
      }
      await out.flush();
    } finally {
      await out.close();
    }
  }

  static Stream<Uint8List> _chunks(File file, {int start = 0, int? end}) async* {
    final raf = await file.open();
    try {
      final stop = end ?? await raf.length();
      var pos = start;
      await raf.setPosition(pos);
      while (pos < stop) {
        final n = min(_chunk, stop - pos);
        final data = await raf.read(n);
        if (data.isEmpty) break;
        pos += data.length;
        yield data;
      }
    } finally {
      await raf.close();
    }
  }

  /// Sabit zamanlı karşılaştırma.
  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class _DigestSink implements Sink<crypto.Digest> {
  crypto.Digest? value;
  @override
  void add(crypto.Digest data) => value = data;
  @override
  void close() {}
}

class VaultCorrupt implements Exception {
  const VaultCorrupt();
  @override
  String toString() => 'VaultCorrupt';
}

class VaultCancelled implements Exception {
  const VaultCancelled();
}
