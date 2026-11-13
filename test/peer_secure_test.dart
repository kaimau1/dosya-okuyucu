import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show md5;
import 'package:dosya_okuyucu/services/fm/remote/peer_crypto.dart';
import 'package:dosya_okuyucu/services/fm/remote/peer_share.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Faz G5 — şifreli Wi-Fi aktarımı (gerçek soket, 127.0.0.1) + kaldığı yerden
/// devamın şifreli protokolle uyumu (yarım dosya YALNIZ aynı anahtarlı eşten
/// sürer).
void main() {
  late Directory temp;
  late Directory inbox;
  late PeerIdentity alice; // gönderen
  late PeerIdentity bob; // alıcı

  setUpAll(() async {
    alice = await PeerIdentity.generate();
    bob = await PeerIdentity.generate();
  });

  setUp(() {
    temp = Directory.systemTemp.createTempSync('peer-g5');
    inbox = Directory(p.join(temp.path, 'gelen'))..createSync();
  });

  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<PeerReceiver> start({
    String code = '',
    Future<bool> Function(PeerOffer)? onAsk,
    void Function(String, int, int)? onProgress,
  }) async {
    final r = PeerReceiver(
      deviceName: 'Bob',
      saveDir: inbox.path,
      identity: bob,
      pairingCode: code,
      onAsk: onAsk,
      onProgress: onProgress,
    );
    await r.start();
    addTearDown(r.stop);
    return r;
  }

  Peer peerOf(PeerReceiver r, {int version = PeerShare.protocolVersion}) =>
      Peer(name: 'Bob', host: '127.0.0.1', port: r.port, version: version);

  File source(String name, int size) {
    final f = File(p.join(temp.path, name));
    f.writeAsBytesSync(List.generate(size, (i) => (i * 31 + 7) & 0xFF));
    return f;
  }

  test('şifreli gönderim: dosya bozulmadan gelir, iki taraf aynı sayıyı görür',
      () async {
    PeerOffer? asked;
    final r = await start(onAsk: (o) async {
      asked = o;
      return true;
    });
    PeerSecurity? sec;
    final src = source('video.bin', 3 * 1024 * 1024 + 17);
    final result = await PeerSender.send(peerOf(r), [src.path],
        senderName: 'Alice', senderId: 'alice-id', identity: alice,
        onSecurity: (s) => sec = s);
    expect(result.sent, 1);
    expect(result.errors, isEmpty);
    expect(result.encrypted, isTrue);
    expect(result.peerFingerprint, bob.fingerprint);
    expect(File(p.join(inbox.path, 'video.bin')).readAsBytesSync(),
        src.readAsBytesSync());
    expect(sec!.encrypted, isTrue);
    expect(asked!.encrypted, isTrue);
    expect(asked!.fingerprint, alice.fingerprint, reason: 'güvenilen = anahtar');
    expect(asked!.verifyCode, sec!.verifyCode);
    expect(sec!.verifyCode, hasLength(6));
  });

  test('şifreli yazı ve küçük dosya paketi', () async {
    String? got;
    final r = PeerReceiver(
        deviceName: 'Bob', saveDir: inbox.path, identity: bob,
        onText: (t, _) => got = t);
    await r.start();
    addTearDown(r.stop);
    expect(
        await PeerSender.sendText(peerOf(r), 'gizli not',
            senderName: 'Alice', identity: alice),
        isTrue);
    expect(got, 'gizli not');
    final files = [for (var i = 0; i < 5; i++) source('k$i.txt', 100 + i).path];
    final res = await PeerSender.send(peerOf(r), files,
        senderName: 'Alice', identity: alice);
    expect(res.sent, 5);
    expect(res.encrypted, isTrue);
    for (var i = 0; i < 5; i++) {
      expect(File(p.join(inbox.path, 'k$i.txt')).lengthSync(), 100 + i);
    }
  });

  test('yanlış eşleştirme kodu: ilk kayıt açılmaz → wrongCode, dosya yazılmaz',
      () async {
    final r = await start(code: '123456');
    final res = await PeerSender.send(peerOf(r), [source('a.txt', 10).path],
        senderName: 'Alice', identity: alice, pairingCode: '654321');
    expect(res.wrongCode, isTrue);
    expect(inbox.listSync().where((e) => !p.basename(e.path).startsWith('.')),
        isEmpty);
    final ok = await PeerSender.send(peerOf(r), [source('b.txt', 10).path],
        senderName: 'Alice', identity: alice, pairingCode: '123456');
    expect(ok.sent, 1);
  });

  test('eşitleme kipi: beklenen anahtar değilse ya da alıcı eskiyse gönderilmez',
      () async {
    final r = await start();
    final f = source('c.txt', 10).path;
    final wrong = await PeerSender.send(peerOf(r), [f],
        senderName: 'Alice', identity: alice, requireFingerprint: alice.fingerprint);
    expect(wrong.identityMismatch, isTrue);
    expect(wrong.sent, 0);
    final old = await PeerSender.send(peerOf(r, version: 2), [f],
        senderName: 'Alice', identity: alice, requireFingerprint: bob.fingerprint);
    expect(old.identityMismatch, isTrue, reason: 'şifresiz protokolle eşitleme yok');
    final good = await PeerSender.send(peerOf(r), [f],
        senderName: 'Alice', identity: alice, requireFingerprint: bob.fingerprint);
    expect(good.sent, 1);
  });

  test('eski sürüm gönderen (düz) yeni alıcıya yine gönderir — şifresiz', () async {
    PeerOffer? asked;
    final r = await start(onAsk: (o) async {
      asked = o;
      return true;
    });
    final res = await PeerSender.send(peerOf(r, version: 2), [source('d.txt', 50).path],
        senderName: 'Eski');
    expect(res.sent, 1);
    expect(res.encrypted, isFalse);
    expect(asked!.encrypted, isFalse);
  });

  // Gönderenin aktarım kimliği (PeerSender._tid ile aynı kural).
  String tidOf(String senderKey, File f) => md5
      .convert(utf8.encode([
        senderKey,
        p.basename(f.path),
        '${f.lengthSync()}',
        '${f.lastModifiedSync().millisecondsSinceEpoch}',
      ].join('/')))
      .toString()
      .substring(0, 24);

  test('kaldığı yerden devam: aynı anahtarlı eşin yarım dosyası sürer', () async {
    final r = await start();
    final src = source('yarim.bin', 200000);
    final tid = tidOf('alice-id', src);
    final bytes = src.readAsBytesSync();
    File(p.join(inbox.path, '${PeerShare.partPrefix}$tid'))
        .writeAsBytesSync(bytes.sublist(0, 120000));
    File(p.join(inbox.path, '${PeerShare.partPrefix}$tid.k'))
        .writeAsStringSync(alice.fingerprint);
    final starts = <int>[];
    final res = await PeerSender.send(peerOf(r), [src.path],
        senderName: 'Alice', senderId: 'alice-id', identity: alice,
        onFile: (_, sent, _) => starts.add(sent));
    expect(res.sent, 1);
    expect(starts.where((n) => n == 120000), isNotEmpty, reason: 'baştan değil');
    expect(File(p.join(inbox.path, 'yarim.bin')).readAsBytesSync(), bytes);
    expect(File(p.join(inbox.path, '${PeerShare.partPrefix}$tid.k')).existsSync(),
        isFalse);
  });

  test('başka eşin (ya da düz protokolün) yarım dosyası SÜRDÜRÜLMEZ', () async {
    final r = await start();
    final src = source('yabanci.bin', 50000);
    final tid = tidOf('alice-id', src);
    // Saldırganın bıraktığı sahte önek: başka anahtarın yarım dosyası.
    File(p.join(inbox.path, '${PeerShare.partPrefix}$tid'))
        .writeAsBytesSync(List.filled(30000, 0xEE));
    File(p.join(inbox.path, '${PeerShare.partPrefix}$tid.k'))
        .writeAsStringSync('baska-bir-anahtar');
    final res = await PeerSender.send(peerOf(r), [src.path],
        senderName: 'Alice', senderId: 'alice-id', identity: alice);
    expect(res.sent, 1);
    expect(File(p.join(inbox.path, 'yabanci.bin')).readAsBytesSync(),
        src.readAsBytesSync());
  });

  test('aynı eşin ama BOZUK yarım dosyası: uç özeti tutmaz → baştan gönderilir',
      () async {
    final r = await start();
    final src = source('bozuk.bin', 150000);
    final tid = tidOf('alice-id', src);
    final bad = src.readAsBytesSync().sublist(0, 90000)..[89000] ^= 0xFF;
    File(p.join(inbox.path, '${PeerShare.partPrefix}$tid')).writeAsBytesSync(bad);
    File(p.join(inbox.path, '${PeerShare.partPrefix}$tid.k'))
        .writeAsStringSync(alice.fingerprint);
    final res = await PeerSender.send(peerOf(r), [src.path],
        senderName: 'Alice', senderId: 'alice-id', identity: alice);
    expect(res.sent, 1);
    expect(File(p.join(inbox.path, 'bozuk.bin')).readAsBytesSync(),
        src.readAsBytesSync());
  });

  test('alıcı v3 duyurur, parmak izini yayar; kimliksiz alıcı v2 kalır', () async {
    final r = await start();
    final probed = await PeerSender.probe('127.0.0.1', port: r.port);
    expect(probed!.secure, isTrue);
    expect(probed.fingerprint, bob.fingerprint);
    final old = PeerReceiver(deviceName: 'Eski', saveDir: inbox.path);
    await old.start();
    addTearDown(old.stop);
    final o = await PeerSender.probe('127.0.0.1', port: old.port);
    expect(o!.secure, isFalse);
  });
}
