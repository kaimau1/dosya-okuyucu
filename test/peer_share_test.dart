import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/peer_share.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// **İki Dosya Okuyucu arasında dosya gönderme** (kullanıcı isteği
/// 2026-09-06). Testler gerçek soketle, geri döngü (127.0.0.1) üzerinden
/// koşuyor: protokolün kendisi doğrulanmazsa "gönderdim ama gitmedi" ancak
/// iki telefonla anlaşılırdı.
///
/// UDP yayınıyla **bulma** test edilmiyor: `flutter test` ortamında ağ
/// yayınının davranışı makineye göre değişir (CI konteynerinde yayın adresi
/// yok). Bulunamayan cihaz için ürün zaten elle adres yazma yolunu sunuyor ve
/// [PeerSender.probe] o yolu buradan doğrulanabilir kılıyor.
void main() {
  late Directory temp;
  late Directory inbox;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('peer-test');
    inbox = Directory(p.join(temp.path, 'gelen'))..createSync();
  });

  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<PeerReceiver> startReceiver({
    void Function(String path, String from)? onReceived,
  }) async {
    final receiver = PeerReceiver(
      deviceName: 'Alıcı',
      saveDir: inbox.path,
      onReceived: onReceived,
    );
    await receiver.start();
    return receiver;
  }

  test('dosya karşı tarafa BOZULMADAN gider', () async {
    final received = <String>[];
    final receiver = await startReceiver(onReceived: (path, _) {
      received.add(path);
    });
    addTearDown(receiver.stop);

    final source = File(p.join(temp.path, 'rapor.txt'))
      ..writeAsStringSync('merhaba dünya' * 500);
    final peer =
        Peer(name: 'Alıcı', host: '127.0.0.1', port: receiver.port);

    final result = await PeerSender.send(peer, [source.path],
        senderName: 'Gönderen');

    expect(result.sent, 1);
    expect(result.errors, isEmpty);
    final landed = File(p.join(inbox.path, 'rapor.txt'));
    expect(landed.existsSync(), isTrue);
    expect(landed.readAsStringSync(), source.readAsStringSync());
    expect(received, hasLength(1));
  });

  test('aynı adlı dosya EZİLMEZ', () async {
    final receiver = await startReceiver();
    addTearDown(receiver.stop);
    File(p.join(inbox.path, 'not.txt')).writeAsStringSync('eski');

    final source = File(p.join(temp.path, 'not.txt'))
      ..writeAsStringSync('yeni');
    final peer = Peer(name: 'A', host: '127.0.0.1', port: receiver.port);
    await PeerSender.send(peer, [source.path], senderName: 'G');

    expect(File(p.join(inbox.path, 'not.txt')).readAsStringSync(), 'eski');
    expect(File(p.join(inbox.path, 'not (1).txt')).readAsStringSync(), 'yeni');
  });

  test('gönderenin verdiği AD klasör dışına çıkamaz', () async {
    final receiver = await startReceiver();
    addTearDown(receiver.stop);

    // Kötü niyetli bir istemci `../../` ile üst klasöre yazmayı deneyebilir.
    // Ad temizlendiği için dosya yine `inbox` içinde kalmalı.
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse(
        'http://127.0.0.1:${receiver.port}/al'
        '?ad=${Uri.encodeQueryComponent('../../kacti.txt')}&kim=kotu'));
    request.add('içerik'.codeUnits);
    final response = await request.close();
    await response.drain<void>();
    client.close();

    expect(File(p.join(temp.path, 'kacti.txt')).existsSync(), isFalse);
    expect(
      inbox.listSync().whereType<File>().length,
      1,
      reason: 'dosya yalnız seçilen klasöre yazılmalı',
    );
  });

  test('birden çok dosya tek oturumda gider', () async {
    final receiver = await startReceiver();
    addTearDown(receiver.stop);
    final paths = [
      for (var i = 0; i < 5; i++)
        (File(p.join(temp.path, 'dosya$i.bin'))..writeAsBytesSync([i, i, i]))
            .path,
    ];
    final peer = Peer(name: 'A', host: '127.0.0.1', port: receiver.port);

    var lastTotal = 0;
    final result = await PeerSender.send(peer, paths,
        senderName: 'G',
        onProgress: (_, sent, total) => lastTotal = total);

    expect(result.sent, 5);
    expect(lastTotal, 15); // 5 dosya × 3 bayt: ilerleme BAYT sayıyor
    expect(inbox.listSync().whereType<File>(), hasLength(5));
  });

  test('/kim ucu cihazı tanıtır (elle adres yazma yolu)', () async {
    final receiver = await startReceiver();
    addTearDown(receiver.stop);

    final peer = await PeerSender.probe('127.0.0.1', port: receiver.port);
    expect(peer, isNotNull);
    expect(peer!.name, 'Alıcı');
    expect(peer.port, receiver.port);
  });

  test('sunucu YOKSA elle adres sessizce null döner', () async {
    // Kapalı bir port: kullanıcı yanlış adres yazdığında ekran "bulunamadı"
    // diyebilmeli, çökmemeli.
    final peer = await PeerSender.probe('127.0.0.1', port: 1);
    expect(peer, isNull);
  });

  test('durdurma isteği kalan dosyaları göndermez', () async {
    final receiver = await startReceiver();
    addTearDown(receiver.stop);
    final paths = [
      for (var i = 0; i < 3; i++)
        (File(p.join(temp.path, 'v$i.bin'))..writeAsBytesSync([1]))
            .path,
    ];
    final peer = Peer(name: 'A', host: '127.0.0.1', port: receiver.port);

    var calls = 0;
    final result = await PeerSender.send(peer, paths,
        senderName: 'G',
        // İlk dosyadan sonra "durdur".
        isCancelled: () => calls++ > 1);

    expect(result.cancelled, isTrue);
    expect(result.sent, lessThan(3));
  });

  group('Eşleştirme kodu', () {
    test('doğru kod kabul edilir', () async {
      final receiver = PeerReceiver(
        deviceName: 'A',
        saveDir: inbox.path,
        pairingCode: '4271',
      );
      await receiver.start();
      addTearDown(receiver.stop);
      final source = File(p.join(temp.path, 'k.txt'))
        ..writeAsStringSync('içerik');
      final peer = Peer(
          name: 'A', host: '127.0.0.1', port: receiver.port, needsCode: true);

      final ok = await PeerSender.send(peer, [source.path],
          senderName: 'G', pairingCode: '4271');
      expect(ok.sent, 1);
      expect(ok.wrongCode, isFalse);
    });

    test('yanlış kodda dosya YAZILMAZ', () async {
      final receiver = PeerReceiver(
        deviceName: 'A',
        saveDir: inbox.path,
        pairingCode: '4271',
      );
      await receiver.start();
      addTearDown(receiver.stop);
      final source = File(p.join(temp.path, 'k.txt'))
        ..writeAsStringSync('içerik');
      final peer = Peer(
          name: 'A', host: '127.0.0.1', port: receiver.port, needsCode: true);

      final bad = await PeerSender.send(peer, [source.path],
          senderName: 'G', pairingCode: '0000');
      expect(bad.wrongCode, isTrue);
      expect(bad.sent, 0);
      // Gövde hiç okunmadı: klasörde dosya YOK.
      expect(inbox.listSync(), isEmpty);
    });

    test('kodsuz alıcıya kod göndermek zarar vermez', () async {
      final receiver = await startReceiver();
      addTearDown(receiver.stop);
      final source = File(p.join(temp.path, 'k.txt'))..writeAsStringSync('x');
      final peer = Peer(name: 'A', host: '127.0.0.1', port: receiver.port);
      final r = await PeerSender.send(peer, [source.path],
          senderName: 'G', pairingCode: '1234');
      expect(r.sent, 1);
    });

    test('/kim ucu kod İSTENDİĞİNİ söyler ama kodu VERMEZ', () async {
      final receiver = PeerReceiver(
        deviceName: 'A',
        saveDir: inbox.path,
        pairingCode: '9876',
      );
      await receiver.start();
      addTearDown(receiver.stop);
      final peer = await PeerSender.probe('127.0.0.1', port: receiver.port);
      expect(peer!.needsCode, isTrue);

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:${receiver.port}/kim'));
      final response = await request.close();
      final body = await response.transform(const Utf8Decoder()).join();
      client.close();
      expect(body.contains('9876'), isFalse,
          reason: 'kod yayınlanırsa kodun anlamı kalmaz');
    });

    test('kod dört haneli üretilir', () {
      for (var i = 0; i < 50; i++) {
        final code = PeerReceiver.newCode();
        expect(code, matches(RegExp(r'^\d{4}$')));
      }
    });
  });

  test('alt ağ yayın adresi', () {
    expect(PeerShare.broadcastFor('192.168.1.37'), '192.168.1.255');
    expect(PeerShare.broadcastFor('10.0.0.4'), '10.0.0.255');
    expect(PeerShare.broadcastFor('saçma'), isNull);
  });
}
