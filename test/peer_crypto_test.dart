import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show KeyPairType, SimplePublicKey;
import 'package:cryptography/dart.dart' show DartX25519;
import 'package:dosya_okuyucu/services/fm/remote/peer_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz G5 — Aktar şifrelemesinin yapı taşları. Sabit vektörler bağımsız
/// başvuru uygulamasından (`tool/aktar_sifre_vektor.py`, Python
/// `cryptography`); Windows "Dosya Aktar" (Secure.cs) aynı değerlerle sınanır.
Uint8List _hex(String h) => Uint8List.fromList([
      for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)
    ]);

String _toHex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

List<int> _seq(int from) => List.generate(32, (i) => from + i);

void main() {
  final aead = DartAead();

  test('X25519 RFC 7748 bilinen vektör', () async {
    final kp = await const DartX25519().newKeyPairFromSeed(
        _hex('a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4'));
    final s = await const DartX25519().sharedSecretKey(
      keyPair: kp,
      remotePublicKey: SimplePublicKey(
          _hex('e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c'),
          type: KeyPairType.x25519),
    );
    expect(_toHex(await s.extractBytes()),
        'c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552');
  });

  Future<(PeerKeys, PeerKeys)> pair({String codeI = '', String codeR = ''}) async {
    final sI = await PeerIdentity.fromSeed(_seq(1));
    final eI = await PeerEphemeral.generate(_seq(33));
    final sR = await PeerIdentity.fromSeed(_seq(65));
    final eR = await PeerEphemeral.generate(_seq(97));
    final i = await PeerHandshake.derive(
        me: sI, ephemeral: eI, theirStatic: sR.publicKey,
        theirEphemeral: eR.publicKey, initiator: true, code: codeI);
    final r = await PeerHandshake.derive(
        me: sR, ephemeral: eR, theirStatic: sI.publicKey,
        theirEphemeral: eI.publicKey, initiator: false, code: codeR);
    return (i, r);
  }

  test('el sıkışma başvuru vektörüyle aynı anahtarları ve sayıyı verir', () async {
    final (i, r) = await pair();
    expect(_toHex(i.send),
        '646ad943abfc5b99ed971f83a2d21b89b639406535d982242d552203657bacc9');
    expect(_toHex(i.recv),
        'e5b36c94b98595a24bcd0801ea08641c38183dadb8c74ccd62638d14de44982a');
    expect(i.verifyCode, '441943');
    expect(r.send, i.recv);
    expect(r.recv, i.send);
    expect(r.verifyCode, i.verifyCode, reason: 'iki ekranda aynı sayı');
    expect(i.peerFingerprint, 'bc841db8fea3efd84555a7f8eeb92503');
    expect(r.peerFingerprint, 'aaa8fff703b50b2297f4f6e13508f724');

    final (ci, _) = await pair(codeI: '123456', codeR: '123456');
    expect(_toHex(ci.send),
        '6841b2be2c10e8650535b6a6a8a745db627756c07b3f76d61e56342e835b3723');
    expect(ci.verifyCode, '081443');
  });

  test('kayıt biçimi başvuru vektörüyle aynı', () async {
    final key = _hex('646ad943abfc5b99ed971f83a2d21b89b639406535d982242d552203657bacc9');
    final rec = await ChunkSealer(key, 7, aad: utf8.encode('/al'), aead: aead)
        .seal(utf8.encode('merhaba'), last: true);
    expect(_toHex(rec),
        '000000184c3fe3fc888b15324ad31fc6c24cf85e1279ecd53ef9c355');
  });

  test('yanlış kod: anahtarlar tutmaz, ilk kayıt açılmaz', () async {
    final (i, r) = await pair(codeI: '111111', codeR: '222222');
    expect(i.send, isNot(r.recv));
    final rec = await ChunkSealer(i.send, 1, aead: aead).seal([1, 2, 3], last: true);
    expect(
        () => ChunkOpener(r.recv, 1, aead: aead)
            .openStream(Stream.value(rec))
            .toList(),
        throwsA(isA<AeadFailure>()));
  });

  final key = Uint8List.fromList(List.generate(32, (i) => i * 3));
  final data = Uint8List.fromList(List.generate(23, (i) => i));

  Future<List<Uint8List>> records(int chunk) async {
    final out = <Uint8List>[];
    await for (final r in ChunkSealer(key, 5, aead: aead)
        .sealStream(Stream.fromIterable([data.sublist(0, 9), data.sublist(9)]),
            chunk: chunk)) {
      out.add(Uint8List.fromList(r));
    }
    return out;
  }

  Future<List<int>> open(List<Uint8List> recs) async {
    final out = <int>[];
    await for (final c in ChunkOpener(key, 5, aead: aead).openStream(Stream.fromIterable(recs))) {
      out.addAll(c);
    }
    return out;
  }

  test('parçalı akış gidip gelir; boy hesabı tutar', () async {
    final recs = await records(5);
    expect(recs, hasLength(SealedChunks.recordsFor(23, 5)));
    expect(recs.fold<int>(0, (a, r) => a + r.length), SealedChunks.sealedLength(23, 5));
    expect(await open(recs), data);
    // Tam katı ve boş akış.
    final ten = await ChunkSealer(key, 2, aead: aead)
        .sealStream(Stream.value(List.filled(10, 7)), chunk: 5)
        .toList();
    expect(ten, hasLength(2));
    final empty = await ChunkSealer(key, 2, aead: aead)
        .sealStream(const Stream.empty())
        .toList();
    expect(empty, hasLength(1));
    expect(empty.single.length, SealedChunks.sealedLength(0));
  });

  test('sıra dışı, yinelenen, eksik ve fazla parça REDDEDİLİR', () async {
    final recs = await records(5);
    Future<void> bad(List<Uint8List> r, String reason) => expectLater(
        open(r), throwsA(isA<AeadFailure>().having((e) => e.reason, 'neden', reason)));
    await bad([recs[1], recs[0], ...recs.skip(2)], 'etiket'); // sıra dışı
    await bad([recs[0], recs[0], ...recs.skip(1)], 'etiket'); // yinelenen
    await bad(recs.sublist(0, recs.length - 1), 'kesik'); // son yok
    await bad([...recs, recs.last], 'fazla'); // sondan sonra
    final flipped = Uint8List.fromList(recs[2])..[10] ^= 1;
    await bad([recs[0], recs[1], flipped, ...recs.skip(3)], 'etiket'); // bozuk
  });

  test('başka akış numarasıyla açılmaz (yeniden oynatma)', () async {
    final recs = await records(64);
    expect(
        () => ChunkOpener(key, 6, aead: aead).openStream(Stream.fromIterable(recs)).toList(),
        throwsA(isA<AeadFailure>()));
  });
}
