import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/peer_share.dart';
import 'package:dosya_okuyucu/services/fm/remote/qr_transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Telefondan PC / eşe yazı gönderme', () {
    test('/yazi uç noktası destekleniyorsa yazı doğrudan gider', () async {
      String? gotText;
      String? gotFrom;
      final dir = await Directory.systemTemp.createTemp('pctxt_recv_');
      addTearDown(() => dir.delete(recursive: true));
      final receiver = PeerReceiver(
        identity: null,
        deviceName: 'TestPC',
        deviceId: 'pc123456',
        saveDir: dir.path,
        onText: (t, f) {
          gotText = t;
          gotFrom = f;
        },
        onReceived: (_, _) {},
      );
      await receiver.start();
      addTearDown(receiver.stop);

      final peer = Peer(
        id: 'pc123456',
        name: 'TestPC',
        host: '127.0.0.1',
        port: receiver.port,
        version: 1,
      );
      final ok = await PeerSender.sendText(peer, 'Merhaba PC 🌍',
          senderName: 'Telefon');
      expect(ok, isTrue);
      expect(gotText, 'Merhaba PC 🌍');
      expect(gotFrom, 'Telefon');
    });

    test('/yazi 404 dönerse eski alıcıya not.txt (/al) ile düşer', () async {
      final savedFiles = <String>[];
      final dir = await Directory.systemTemp.createTemp('pctxt_old_');
      addTearDown(() => dir.delete(recursive: true));
      final receiver = PeerReceiver(
        identity: null,
        deviceName: 'EskiPC',
        deviceId: 'old12345',
        saveDir: dir.path,
        // onText null → /yazi 404 döner → /al ile not.txt düşmeli
        onReceived: (path, _) => savedFiles.add(path),
      );
      await receiver.start();
      addTearDown(receiver.stop);

      final peer = Peer(
        id: 'old12345',
        name: 'EskiPC',
        host: '127.0.0.1',
        port: receiver.port,
        version: 1,
      );
      final ok = await PeerSender.sendText(peer, 'Eski sürüme metin',
          senderName: 'Telefon', allowFileFallback: true);
      expect(ok, isTrue);
      expect(savedFiles, hasLength(1));
      expect(p.basename(savedFiles.single), 'not.txt');
      expect(File(savedFiles.single).readAsStringSync(), 'Eski sürüme metin');
    });

    test('QrShareServer dosya seçimi olmadan yalnız yazıyı HTML + text.txt sunar',
        () async {
      final served = <String>[];
      final server = QrShareServer(
        const [],
        text: 'Paylaşılan <not> & panodan yazı',
        senderName: 'Sena',
        onServed: served.add,
      );
      await server.start();
      addTearDown(server.stop);

      final base = server.urlFor('127.0.0.1');
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final htmlReq = await client.getUrl(base);
      final htmlRes = await htmlReq.close();
      expect(htmlRes.statusCode, HttpStatus.ok);
      final html = await utf8.decodeStream(htmlRes);
      expect(html, contains('Paylaşılan &lt;not&gt; &amp; panodan yazı'));
      expect(html, contains('href="text.txt"'));

      final txtReq = await client.getUrl(base.resolve('text.txt'));
      final txtRes = await txtReq.close();
      expect(txtRes.statusCode, HttpStatus.ok);
      expect(await utf8.decodeStream(txtRes),
          'Paylaşılan <not> & panodan yazı');
      expect(served, ['metin.txt']);
    });
  });
}
