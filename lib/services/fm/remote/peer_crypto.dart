import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart'
    show
        KeyPairType,
        Mac,
        SecretBox,
        SecretBoxAuthenticationError,
        SecretKey,
        SimpleKeyPairData,
        SimplePublicKey;
import 'package:cryptography/dart.dart' show DartAesGcm, DartX25519;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Aktar şifrelemesi (Faz G5) — taşımadan BAĞIMSIZ yapı taşları.**
///
/// Aynı Wi-Fi'deki eşler arası aktarım ([PeerSender]/[PeerReceiver]) ve
/// "Bağlantıyla gönder" (Drive'a yüklenen şifreli dosya, [LinkShare]) aynı
/// kayıt biçimini kullanır:
///
/// ```
/// kayıt  = u32be(uzunluk) || AES-256-GCM(anahtar, nonce, düz, aad)
/// nonce  = u32be(akış) || u64be(sayaç)        (sayaç kayıt sırası, 0'dan)
/// düz    = bayrak(1 bayt: 1 = SON kayıt) || yük (en çok 1 MiB)
/// ```
///
/// * Sayaç nonce'tadır: sıra dışı, yinelenen ya da atlanan kayıt etiket
///   denetiminden GEÇEMEZ. Son kayıt işareti şifrelidir: akışın sonu
///   kesilirse ([AeadFailure] `kesik`) ya da sondan sonra bayt gelirse
///   (`fazla`) fark edilir.
/// * Başvuru uygulaması `tool/aktar_sifre_vektor.py`; Windows'taki eşi
///   `tool/pc_aktar/Secure.cs`. Biçim değişirse üçü birlikte değişir.
///
/// ## Hız (HAFIZA 2026-11-13)
/// Saf Dart AES-GCM (pointycastle) SFTP'yi 14 → 1 MB/sn düşürmüştü. Android'de
/// kayıtlar Kotlin `javax.crypto` (Conscrypt/BoringSSL, ARMv8 AES komutları)
/// ile mühürlenir — [NativeAead], kanal `dosya/aead`, arka plan iş kuyruğunda.
/// 1 MiB'lık kayıt başına bir kanal çağrısı: kopyalama yükü Wi-Fi hızının
/// yanında küçük. Testte ve kanal yoksa [DartAead] (yavaş ama doğru).
class AeadFailure implements Exception {
  final String reason;
  const AeadFailure(this.reason);

  @override
  String toString() => 'AeadFailure($reason)';
}

/// Kimlik doğrulamalı şifre (AES-256-GCM, 16 bayt etiket şifrenin SONUNDA).
abstract interface class Aead {
  Future<Uint8List> seal(
      Uint8List key, Uint8List nonce, Uint8List plain, Uint8List aad);

  /// Etiket tutmazsa [AeadFailure].
  Future<Uint8List> open(
      Uint8List key, Uint8List nonce, Uint8List sealed, Uint8List aad);
}

/// Saf Dart yedek (`cryptography` paketinin `DartAesGcm`'i).
class DartAead implements Aead {
  static final _gcm = DartAesGcm.with256bits();

  @override
  Future<Uint8List> seal(
      Uint8List key, Uint8List nonce, Uint8List plain, Uint8List aad) async {
    final box = await _gcm.encrypt(plain,
        secretKey: SecretKey(key), nonce: nonce, aad: aad);
    final out = Uint8List(box.cipherText.length + 16);
    out.setRange(0, box.cipherText.length, box.cipherText);
    out.setRange(box.cipherText.length, out.length, box.mac.bytes);
    return out;
  }

  @override
  Future<Uint8List> open(
      Uint8List key, Uint8List nonce, Uint8List sealed, Uint8List aad) async {
    if (sealed.length < 16) throw const AeadFailure('kisa');
    final n = sealed.length - 16;
    try {
      final plain = await _gcm.decrypt(
        SecretBox(Uint8List.sublistView(sealed, 0, n),
            nonce: nonce, mac: Mac(Uint8List.sublistView(sealed, n))),
        secretKey: SecretKey(key),
        aad: aad,
      );
      return plain is Uint8List ? plain : Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const AeadFailure('etiket');
    }
  }
}

/// Android: Kotlin `javax.crypto` (donanım hızlandırmalı). Kanal yoksa
/// (eski motor, test) kalıcı olarak [DartAead]'e düşer.
class NativeAead implements Aead {
  static const _channel = MethodChannel('dosya/aead');
  final _fallback = DartAead();
  bool _missing = false;

  Future<Uint8List> _call(String method, Uint8List key, Uint8List nonce,
      Uint8List data, Uint8List aad) async {
    try {
      final r = await _channel.invokeMethod<Uint8List>(
          method, {'k': key, 'n': nonce, 'd': data, 'a': aad});
      if (r == null) throw const AeadFailure('yerel');
      return r;
    } on PlatformException catch (e) {
      throw AeadFailure(e.code);
    }
  }

  @override
  Future<Uint8List> seal(
      Uint8List key, Uint8List nonce, Uint8List plain, Uint8List aad) async {
    if (!_missing) {
      try {
        return await _call('seal', key, nonce, plain, aad);
      } on MissingPluginException {
        _missing = true;
      }
    }
    return _fallback.seal(key, nonce, plain, aad);
  }

  @override
  Future<Uint8List> open(
      Uint8List key, Uint8List nonce, Uint8List sealed, Uint8List aad) async {
    if (!_missing) {
      try {
        return await _call('open', key, nonce, sealed, aad);
      } on MissingPluginException {
        _missing = true;
      }
    }
    return _fallback.open(key, nonce, sealed, aad);
  }
}

abstract final class PeerAead {
  static Aead instance = Platform.isAndroid ? NativeAead() : DartAead();
}

/// Kayıt biçiminin sabitleri ve boy hesabı.
abstract final class SealedChunks {
  /// Kayıt başına en çok düz yük.
  static const chunkSize = 1 << 20;

  /// Kayıt başına ek: uzunluk(4) + bayrak(1) + etiket(16).
  static const overhead = 4 + 1 + 16;

  /// Kabul edilen en büyük mühürlü kayıt (uzunluk alanı hariç).
  static const maxSealed = chunkSize + 1 + 16;

  /// [length] düz bayt kaç kayıt eder (boş akış da tek, boş "son" kayıttır).
  static int recordsFor(int length, [int chunk = chunkSize]) =>
      length <= 0 ? 1 : (length + chunk - 1) ~/ chunk;

  /// [length] düz baytın mühürlü akış boyu — HTTP `Content-Length` için.
  static int sealedLength(int length, [int chunk = chunkSize]) =>
      max(0, length) + recordsFor(length, chunk) * overhead;

  static Uint8List nonce(int stream, int counter) {
    final b = ByteData(12)
      ..setUint32(0, stream)
      ..setUint64(4, counter);
    return b.buffer.asUint8List();
  }
}

/// Bir akışın mühürleyicisi (tek anahtar + akış numarası).
class ChunkSealer {
  final Aead aead;
  final Uint8List key;
  final int stream;
  final Uint8List aad;
  int _counter = 0;
  bool _closed = false;

  ChunkSealer(this.key, this.stream, {List<int> aad = const [], Aead? aead})
      : aad = Uint8List.fromList(aad),
        aead = aead ?? PeerAead.instance;

  /// Tek kayıt (uzunluk alanıyla birlikte).
  Future<Uint8List> seal(List<int> payload, {required bool last}) async {
    if (_closed) throw StateError('akış kapandı');
    final plain = Uint8List(payload.length + 1);
    plain[0] = last ? 1 : 0;
    plain.setRange(1, plain.length, payload);
    final sealed =
        await aead.seal(key, SealedChunks.nonce(stream, _counter++), plain, aad);
    if (last) _closed = true;
    final out = Uint8List(4 + sealed.length);
    ByteData.sublistView(out).setUint32(0, sealed.length);
    out.setRange(4, out.length, sealed);
    return out;
  }

  /// Düz akışı [chunk]'lık kayıtlara böler; sonuncusu "son" işaretli. Boş
  /// akış tek boş son kayıt verir ([SealedChunks.recordsFor] ile tutarlı).
  Stream<List<int>> sealStream(Stream<List<int>> plain,
      {int chunk = SealedChunks.chunkSize}) async* {
    final buf = BytesBuilder(copy: false);
    Uint8List? held;
    await for (final data in plain) {
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      var off = 0;
      while (off < bytes.length) {
        if (held != null) {
          yield await seal(held, last: false);
          held = null;
        }
        final take = min(chunk - buf.length, bytes.length - off);
        buf.add(Uint8List.sublistView(bytes, off, off + take));
        off += take;
        if (buf.length == chunk) held = buf.takeBytes();
      }
    }
    if (held != null) {
      if (buf.isEmpty) {
        yield await seal(held, last: true);
        return;
      }
      yield await seal(held, last: false);
    }
    yield await seal(buf.takeBytes(), last: true);
  }
}

/// Bayt akışından mühürlü kayıtları teker teker çeker (uzunluk alanı atılır).
class RecordReader {
  final StreamIterator<List<int>> _it;
  final int maxRecord;
  final _chunks = ListQueue<Uint8List>();
  int _have = 0;

  RecordReader(Stream<List<int>> raw, {this.maxRecord = SealedChunks.maxSealed})
      : _it = StreamIterator(raw);

  Future<bool> _fill(int n) async {
    while (_have < n) {
      if (!await _it.moveNext()) return false;
      final cur = _it.current;
      if (cur.isEmpty) continue;
      final u = cur is Uint8List ? cur : Uint8List.fromList(cur);
      _chunks.add(u);
      _have += u.length;
    }
    return true;
  }

  Uint8List _take(int n) {
    final out = Uint8List(n);
    var o = 0;
    while (o < n) {
      final f = _chunks.removeFirst();
      final k = min(n - o, f.length);
      out.setRange(o, o + k, f);
      o += k;
      if (k < f.length) _chunks.addFirst(Uint8List.sublistView(f, k));
    }
    _have -= n;
    return out;
  }

  /// Sıradaki mühürlü kayıt; akış temiz bittiyse null.
  Future<Uint8List?> next() async {
    if (!await _fill(4)) {
      if (_have == 0) return null;
      throw const AeadFailure('kesik');
    }
    final len = ByteData.sublistView(_take(4)).getUint32(0);
    if (len < 17 || len > maxRecord) throw const AeadFailure('boy');
    if (!await _fill(len)) throw const AeadFailure('kesik');
    return _take(len);
  }

  Future<void> cancel() => _it.cancel();
}

/// Bir akışın açıcısı: kayıtlar YALNIZ sırayla açılır.
class ChunkOpener {
  final Aead aead;
  final Uint8List key;
  final int stream;
  final Uint8List aad;
  int _counter = 0;
  bool _done = false;

  ChunkOpener(this.key, this.stream, {List<int> aad = const [], Aead? aead})
      : aad = Uint8List.fromList(aad),
        aead = aead ?? PeerAead.instance;

  /// Son kayıt açıldı mı?
  bool get done => _done;

  Future<({Uint8List payload, bool last})> openRecord(Uint8List sealed) async {
    if (_done) throw const AeadFailure('fazla');
    final plain = await aead.open(
        key, SealedChunks.nonce(stream, _counter++), sealed, aad);
    if (plain.isEmpty || plain[0] > 1) throw const AeadFailure('bicim');
    final last = plain[0] == 1;
    if (last) _done = true;
    return (payload: Uint8List.sublistView(plain, 1), last: last);
  }

  Future<({Uint8List payload, bool last})> next(RecordReader reader) async {
    final sealed = await reader.next();
    if (sealed == null) throw const AeadFailure('kesik');
    return openRecord(sealed);
  }

  /// Kalan kayıtları açıp düz baytları verir; sondan sonra bayt varsa hata.
  Stream<Uint8List> rest(RecordReader reader) async* {
    while (!_done) {
      final r = await next(reader);
      if (r.payload.isNotEmpty) yield r.payload;
    }
    if (await reader.next() != null) throw const AeadFailure('fazla');
  }

  Stream<Uint8List> openStream(Stream<List<int>> raw) => rest(RecordReader(raw));
}

/// Bu kurulumun **kalıcı** X25519 anahtarı. Güvenilen cihaz = karşı tarafın
/// kalıcı açık anahtarının parmak izi (ad/IP değil — G5).
class PeerIdentity {
  final SimpleKeyPairData keyPair;
  final Uint8List publicKey;

  PeerIdentity._(this.keyPair, this.publicKey);

  String get fingerprint => fingerprintOf(publicKey);

  /// SHA-256(açık anahtar) ilk 16 bayt, onaltılık.
  static String fingerprintOf(List<int> publicKey) =>
      c.sha256.convert(publicKey).toString().substring(0, 32);

  static Future<PeerIdentity> fromSeed(List<int> seed) async {
    final kp =
        await const DartX25519().newKeyPairFromSeed(seed) as SimpleKeyPairData;
    final pub = await kp.extractPublicKey();
    return PeerIdentity._(kp, Uint8List.fromList(pub.bytes));
  }

  static Uint8List randomSeed() {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)));
  }

  static Future<PeerIdentity> generate() => fromSeed(randomSeed());

  static const _key = 'aktar_kimlik_v1';
  static Future<PeerIdentity>? _loaded;

  /// Kalıcı kimlik (ilk çağrıda üretilip saklanır).
  /// ponytail: tohum SharedPreferences'ta (uygulama özel alanı) — Keystore
  /// sarması yok; kökü açık telefonda okunabilir. Gerekirse wrapKey ile sarılır.
  static Future<PeerIdentity> load() => _loaded ??= () async {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_key);
        if (raw != null) {
          try {
            final seed = base64Decode(raw);
            if (seed.length == 32) return await fromSeed(seed);
          } catch (_) {
            // Bozuk kayıt: yeni kimlik üretilir (güvenilenler yeniden onaylanır).
          }
        }
        final seed = randomSeed();
        await prefs.setString(_key, base64Encode(seed));
        return fromSeed(seed);
      }();

  @visibleForTesting
  static void debugReset() => _loaded = null;
}

/// El sıkışmadan çıkan oturum anahtarları.
class PeerKeys {
  /// Bu tarafın GÖNDERDİĞİ kayıtların anahtarı.
  final Uint8List send;

  /// Karşıdan GELEN kayıtların anahtarı.
  final Uint8List recv;

  /// İki ekranda gösterilen 6 haneli doğrulama sayısı (ortak sırrın özeti).
  final String verifyCode;

  /// Karşı tarafın kalıcı anahtarının parmak izi.
  final String peerFingerprint;

  const PeerKeys(this.send, this.recv, this.verifyCode, this.peerFingerprint);
}

/// Geçici anahtar çifti (her oturumda yenisi).
class PeerEphemeral {
  final SimpleKeyPairData keyPair;
  final Uint8List publicKey;
  PeerEphemeral._(this.keyPair, this.publicKey);

  static Future<PeerEphemeral> generate([List<int>? seed]) async {
    final kp = await const DartX25519()
            .newKeyPairFromSeed(seed ?? PeerIdentity.randomSeed())
        as SimpleKeyPairData;
    final pub = await kp.extractPublicKey();
    return PeerEphemeral._(kp, Uint8List.fromList(pub.bytes));
  }
}

abstract final class PeerHandshake {
  static const info = 'dosya-aktar v2';

  static Future<Uint8List> _dh(SimpleKeyPairData mine, List<int> theirs) async {
    if (theirs.length != 32) throw const AeadFailure('anahtar');
    final secret = const DartX25519().sharedSecretSync(
      keyPairData: mine,
      remotePublicKey: SimplePublicKey(theirs, type: KeyPairType.x25519),
    );
    final bytes = Uint8List.fromList(await secret.extractBytes());
    // Düşük mertebeli nokta: ortak sır sıfır çıkar → reddet.
    if (bytes.every((b) => b == 0)) throw const AeadFailure('anahtar');
    return bytes;
  }

  /// RFC 5869 HKDF-SHA256 (boş tuz = 32 sıfır bayt).
  static Uint8List hkdf(List<int> ikm, List<int> salt, List<int> info, int length) {
    final prk =
        c.Hmac(c.sha256, salt.isEmpty ? Uint8List(32) : salt).convert(ikm).bytes;
    final out = BytesBuilder();
    var t = <int>[];
    var i = 1;
    while (out.length < length) {
      t = c.Hmac(c.sha256, prk).convert([...t, ...info, i++]).bytes;
      out.add(t);
    }
    return Uint8List.sublistView(out.takeBytes(), 0, length);
  }

  /// Anahtarları türetir. [initiator] gönderen taraftır. [code] eşleştirme
  /// kodu (kodsuz kipte boş): yanlış kodda anahtarlar tutmaz, ilk kayıt açılmaz.
  static Future<PeerKeys> derive({
    required PeerIdentity me,
    required PeerEphemeral ephemeral,
    required List<int> theirStatic,
    required List<int> theirEphemeral,
    required bool initiator,
    String code = '',
  }) async {
    final dh1 = await _dh(ephemeral.keyPair, theirEphemeral);
    final dh2 = initiator
        ? await _dh(me.keyPair, theirEphemeral)
        : await _dh(ephemeral.keyPair, theirStatic);
    final dh3 = initiator
        ? await _dh(ephemeral.keyPair, theirStatic)
        : await _dh(me.keyPair, theirEphemeral);
    final List<int> eI = initiator ? ephemeral.publicKey : theirEphemeral;
    final List<int> sI = initiator ? me.publicKey : theirStatic;
    final List<int> eR = initiator ? theirEphemeral : ephemeral.publicKey;
    final List<int> sR = initiator ? theirStatic : me.publicKey;
    final infoBytes = utf8.encode(info);
    final th = c.sha256.convert([...infoBytes, ...eI, ...sI, ...eR, ...sR]).bytes;
    final okm = hkdf(
        [...dh1, ...dh2, ...dh3], utf8.encode(code), [...infoBytes, ...th], 68);
    final i2r = Uint8List.fromList(okm.sublist(0, 32));
    final r2i = Uint8List.fromList(okm.sublist(32, 64));
    final v = ByteData.sublistView(okm, 64, 68).getUint32(0) % 1000000;
    return PeerKeys(
      initiator ? i2r : r2i,
      initiator ? r2i : i2r,
      v.toString().padLeft(6, '0'),
      PeerIdentity.fingerprintOf(theirStatic),
    );
  }
}
