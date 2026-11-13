import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/drive_service.dart';
import 'package:dosya_okuyucu/services/fm/remote/link_share.dart';
import 'package:dosya_okuyucu/services/fm/remote/peer_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// "Bağlantıyla gönder" (2026-11-13): şifreli kap, bağlantı biçimi ve Drive
/// akışı (sahte Drive, ağsız).
void main() {
  late Directory temp;
  final aead = DartAead();
  final key = Uint8List.fromList(List.generate(32, (i) => 200 - i));

  setUp(() {
    temp = Directory.systemTemp.createTempSync('link-share');
    SharedPreferences.setMockInitialValues({});
    LinkShare.instance
      ..debugReset()
      ..aead = aead;
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('bağlantı: anahtar # sonrasında; iletiden geri okunur', () {
    final t = LinkTicket('1AbCdEfGhIjKlMnOp', key);
    final url = t.toUrl();
    expect(url, startsWith('https://drive.google.com/file/d/1AbCdEfGhIjKlMnOp/view#dosya-aktar='));
    expect(Uri.parse(url).path.contains('dosya-aktar'), isFalse, reason: 'sunucuya giden kısımda anahtar yok');
    final back = LinkTicket.parse('Şunu aç: $url teşekkürler');
    expect(back!.fileId, t.fileId);
    expect(back.key, key);
    expect(LinkTicket.parse('https://drive.google.com/file/d/1AbCdEfGhIjKlMnOp/view'), isNull);
    expect(LinkTicket.parse('rastgele metin'), isNull);
  });

  Future<List<int>> sealed(List<int> data, {String name = 'rapor.pdf'}) async {
    final out = <int>[];
    await for (final c in LinkCipher.seal(Stream.value(data), key, name, data.length, aead: aead)) {
      out.addAll(c);
    }
    return out;
  }

  test('kap gidip gelir; boy önceden bilinir; ad korunur', () async {
    final data = List.generate(2 * 1024 * 1024 + 5, (i) => i & 0xFF);
    final box = await sealed(data);
    expect(box.length, LinkCipher.sealedLength('rapor.pdf', data.length));
    final path = await LinkCipher.open(Stream.value(box), key, temp.path, aead: aead);
    expect(p.basename(path), 'rapor.pdf');
    expect(File(path).readAsBytesSync(), data);
  });

  test('yanlış anahtar, kesik kap, HTML sayfa: hata + yarım dosya kalmaz', () async {
    final box = await sealed(List.filled(5000, 1));
    final wrong = Uint8List.fromList(List.filled(32, 9));
    await expectLater(LinkCipher.open(Stream.value(box), wrong, temp.path, aead: aead),
        throwsA(isA<AeadFailure>()));
    await expectLater(
        LinkCipher.open(Stream.value(box.sublist(0, box.length - 10)), key, temp.path, aead: aead),
        throwsA(isA<AeadFailure>()));
    await expectLater(
        LinkCipher.open(Stream.value(utf8.encode('<!DOCTYPE html><html>...')), key, temp.path,
            aead: aead),
        throwsA(isA<LinkFormatError>()));
    expect(temp.listSync(), isEmpty);
  });

  test('gönder → Drive (akışlı yükleme + herkese okuma) → al → iptal', () async {
    final store = <String, List<int>>{};
    final calls = <String>[];
    var publicHtml = false;
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.host}${req.url.path}');
      final u = req.url;
      if (req.method == 'POST' && u.queryParameters['uploadType'] == 'resumable') {
        expect(req.headers['X-Upload-Content-Length'], isNotNull);
        return http.Response('', 200, headers: {'location': 'https://upload.test/oturum'});
      }
      if (req.method == 'PUT' && u.host == 'upload.test') {
        store['dosya12345678'] = req.bodyBytes;
        return http.Response(jsonEncode({'id': 'dosya12345678', 'name': 'x.dok', 'mimeType': 'application/octet-stream'}), 200);
      }
      if (req.method == 'POST' && u.path.endsWith('/permissions')) {
        expect(jsonDecode(req.body), {'role': 'reader', 'type': 'anyone'});
        return http.Response('{}', 200);
      }
      if (req.method == 'GET' && u.host == 'drive.usercontent.google.com') {
        if (publicHtml) return http.Response('<html>giriş</html>', 200);
        final b = store[u.queryParameters['id']];
        return b == null ? http.Response('', 404) : http.Response.bytes(b, 200);
      }
      if (req.method == 'DELETE') {
        store.remove(u.pathSegments.last);
        return http.Response('', 204);
      }
      return http.Response('?', 500);
    });
    final src = File(p.join(temp.path, 'gizli.txt'))..writeAsStringSync('çok gizli' * 1000);
    final inbox = p.join(temp.path, 'gelen');

    await http.runWithClient(() async {
      final share = LinkShare.instance
        ..drive = DriveService(authHeadersOverride: () async => {'Authorization': 'Bearer t'});
      final link = await share.send([src.path]);
      expect(share.items.single.fileId, 'dosya12345678');
      expect(utf8.decode(store['dosya12345678']!, allowMalformed: true).contains('çok gizli'), isFalse,
          reason: 'Drive yalnız şifreli kabı görür');

      // Alıcı oturumsuz: web indirmesi.
      final recv = LinkShare.instance
        ..drive = DriveService(authHeadersOverride: () async => null);
      final got = await recv.receive(LinkTicket.parse(link.url)!, inbox);
      expect(File(got).readAsStringSync(), src.readAsStringSync());

      publicHtml = true;
      await expectLater(recv.receive(LinkTicket.parse(link.url)!, inbox),
          throwsA(isA<LinkFormatError>()), reason: 'arayüz "Drive ile bağlan" der');
      publicHtml = false;

      share.drive = DriveService(authHeadersOverride: () async => {'Authorization': 'Bearer t'});
      await share.revoke(share.items.single);
      expect(store, isEmpty);
      expect(share.items, isEmpty);
    }, () => client);
    expect(calls.any((c) => c.startsWith('PUT upload.test')), isTrue);
  });
}
