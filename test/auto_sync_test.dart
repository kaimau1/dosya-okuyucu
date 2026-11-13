import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/auto_sync.dart';
import 'package:dosya_okuyucu/services/fm/remote/peer_crypto.dart';
import 'package:dosya_okuyucu/services/fm/remote/peer_share.dart';
import 'package:dosya_okuyucu/services/fm/remote/transfer_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Otomatik klasör eşitleme (2026-11-13): varsayılan kapalı, yalnız açıldıktan
/// sonraki dosyalar, yalnız anahtarı tutan şifreli eşe.
void main() {
  late Directory temp, camera, inbox;
  late PeerIdentity me, pc;

  setUpAll(() async {
    me = await PeerIdentity.generate();
    pc = await PeerIdentity.generate();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AutoSync.instance.debugReset();
    TransferHistory.instance.debugReset();
    temp = Directory.systemTemp.createTempSync('esitle');
    camera = Directory(p.join(temp.path, 'Camera'))..createSync();
    inbox = Directory(p.join(temp.path, 'pc'))..createSync();
  });
  tearDown(() => temp.deleteSync(recursive: true));

  File photo(String name, DateTime at) =>
      File(p.join(camera.path, name))
        ..writeAsBytesSync(List.filled(1000, name.length))
        ..setLastModifiedSync(at);

  test('yalnız açıldığı andan sonraki dosyalar; başarıdan sonra işaret ilerler', () async {
    final t0 = DateTime(2026, 11, 13, 10);
    photo('eski.jpg', t0.subtract(const Duration(hours: 1)));
    final sync = AutoSync.instance;
    await sync.set(pc.fingerprint, 'PC', folders: [camera.path]);
    expect(sync.rule(pc.fingerprint)!.on, isFalse, reason: 'varsayılan kapalı');
    await sync.set(pc.fingerprint, 'PC', on: true, now: t0);
    photo('yeni1.jpg', t0.add(const Duration(minutes: 1)));
    photo('yeni2.jpg', t0.add(const Duration(minutes: 2)));
    File(p.join(camera.path, '.gizli')).writeAsStringSync('x');

    final r = PeerReceiver(deviceName: 'PC', saveDir: inbox.path, identity: pc);
    await r.start();
    addTearDown(r.stop);
    final peer = Peer(name: 'PC', host: '127.0.0.1', port: r.port,
        version: PeerShare.protocolVersion, fingerprint: pc.fingerprint);

    expect(await sync.runFor(peer, me: me, name: 'Tel', id: 'tel'), 2);
    expect(inbox.listSync().map((e) => p.basename(e.path)).toSet(), {'yeni1.jpg', 'yeni2.jpg'});
    expect(await sync.runFor(peer, me: me, name: 'Tel', id: 'tel'), 0, reason: 'yeniden gönderilmez');
  });

  test('anahtarı tutmayan eş (taklit) ya da kapalı kural: hiçbir şey gitmez', () async {
    final t0 = DateTime(2026, 11, 13, 10);
    final sync = AutoSync.instance;
    await sync.set(pc.fingerprint, 'PC', folders: [camera.path], on: true, now: t0);
    photo('a.jpg', t0.add(const Duration(minutes: 1)));
    final impostor = await PeerIdentity.generate();
    final r = PeerReceiver(deviceName: 'PC', saveDir: inbox.path, identity: impostor);
    await r.start();
    addTearDown(r.stop);
    // Saldırgan PC'nin parmak izini DUYURUR ama anahtarı yoktur.
    final fake = Peer(name: 'PC', host: '127.0.0.1', port: r.port,
        version: PeerShare.protocolVersion, fingerprint: pc.fingerprint);
    expect(await sync.runFor(fake, me: me, name: 'Tel', id: 'tel', retryFor: Duration.zero), 0);
    expect(inbox.listSync(), isEmpty);
    expect(sync.rule(pc.fingerprint)!.mark, t0.millisecondsSinceEpoch, reason: 'işaret ilerlemez');

    await sync.set(pc.fingerprint, 'PC', on: false);
    final plain = Peer(name: 'PC', host: '127.0.0.1', port: r.port, fingerprint: pc.fingerprint);
    expect(await sync.runFor(plain, me: me, name: 'Tel', id: 'tel'), 0);
  });
}
