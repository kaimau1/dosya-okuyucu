import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/ftp_server.dart';
import 'package:dosya_okuyucu/services/fm/remote/http_share_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// **G4.10 (2026-11-11) yol kaçışı**: paylaşım kökünün DIŞINDAKİ bir dosya
/// hiçbir kodlama hilesiyle okunamaz; güvenlik başlıkları ve CSRF kapısı.
void main() {
  late Directory outer;
  late Directory root;
  late FtpServer share;
  late HttpShareServer server;
  late HttpClient client;

  setUp(() async {
    outer = Directory.systemTemp.createTempSync('trav');
    root = Directory(p.join(outer.path, 'kok'))..createSync();
    File(p.join(outer.path, 'gizli.txt')).writeAsStringSync('SIR-ICERIK');
    File(p.join(root.path, 'acik.txt')).writeAsStringSync('acik');
    File(p.join(root.path, 'resim.svg'))
        .writeAsStringSync('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>');
    try {
      Link(p.join(root.path, 'bag')).createSync(outer.path);
    } catch (_) {}
    share = FtpServer(
      rootDirectory: root.path,
      username: 'pc',
      password: '123456',
      collectCategory: (_) async => const [],
    );
    server = HttpShareServer(
        share: share, port: 0, uploadDir: p.join(root.path, 'Gelen'));
    await server.start();
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
    removeTempDir(outer);
  });

  final auth = 'Basic ${base64.encode(utf8.encode('pc:123456'))}';

  Future<(int, String)> raw(String path) async {
    // Yol olduğu gibi gitsin diye ham soket (HttpClient `..`yu çözer).
    final s = await Socket.connect('127.0.0.1', server.boundPort);
    s.write('GET $path HTTP/1.1\r\nHost: 127.0.0.1\r\n'
        'Authorization: $auth\r\nConnection: close\r\n\r\n');
    final body = await utf8.decoder.bind(s).join();
    await s.close();
    final status = int.tryParse(body.split(' ').elementAtOrNull(1) ?? '') ?? 0;
    return (status, body);
  }

  test('kaçış denemeleri kök dışını okuyamaz', () async {
    // Kökün "Telefon" düğümü altında da denenir.
    for (final path in [
      '/../gizli.txt',
      '/%2e%2e/gizli.txt',
      '/%2E%2E/gizli.txt',
      '/..%2fgizli.txt',
      '/..%5cgizli.txt',
      '/%252e%252e/gizli.txt',
      '/Telefon/../../gizli.txt',
      '/Telefon/%2e%2e/%2e%2e/gizli.txt',
      '/Telefon/..%2f..%2fgizli.txt',
      '/Telefon/acik.txt%00/../../gizli.txt',
      '/Telefon/${Uri.encodeComponent(p.join(outer.path, 'gizli.txt'))}',
      '//${outer.path}/gizli.txt',
    ]) {
      final (status, body) = await raw(path);
      expect(body.contains('SIR-ICERIK'), isFalse, reason: '$path → $status');
    }
  });

  test('sembolik bağ kök dışına çıkarmaz', () async {
    final (_, body) = await raw('/Telefon/bag/gizli.txt');
    // Bağ kök dışını gösteriyor: izlenmez (FtpServer.withinRealRoot).
    expect(body.contains('SIR-ICERIK'), isFalse);
  }, skip: !Platform.isLinux);

  Future<HttpClientResponse> get(String path) async {
    final r = await client
        .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}$path'));
    r.headers.set(HttpHeaders.authorizationHeader, auth);
    return r.close();
  }

  test('listeleme sayfasında güvenlik başlıkları (G4.6)', () async {
    final res = await get('/');
    await res.drain<void>();
    expect(res.headers.value('x-content-type-options'), 'nosniff');
    expect(res.headers.value('x-frame-options'), 'DENY');
    expect(res.headers.value('content-security-policy'),
        contains("default-src 'none'"));
    expect(res.headers.value('referrer-policy'), 'no-referrer');
  });

  test('SVG tarayıcıda AÇILMAZ, indirilir (betik çalışmasın)', () async {
    final res = await get('/Telefon/resim.svg');
    await res.drain<void>();
    expect(res.statusCode, 200);
    expect(res.headers.value('content-disposition'), startsWith('attachment'));
    expect(res.headers.value('x-content-type-options'), 'nosniff');
  });

  test('başka siteden gönderilen yükleme formu reddedilir (G4.7)', () async {
    final r = await client.postUrl(Uri.parse(
        'http://127.0.0.1:${server.boundPort}${HttpShareServer.uploadPath}'));
    r.headers.set(HttpHeaders.authorizationHeader, auth);
    r.headers.set('origin', 'http://kotu.example');
    r.headers.contentType =
        ContentType('multipart', 'form-data', parameters: {'boundary': 'B'});
    r.write('--B\r\nContent-Disposition: form-data; name="f"; '
        'filename="x.txt"\r\n\r\nx\r\n--B--\r\n');
    final res = await r.close();
    await res.drain<void>();
    expect(res.statusCode, HttpStatus.forbidden);
    expect(Directory(p.join(root.path, 'Gelen')).existsSync() &&
        Directory(p.join(root.path, 'Gelen')).listSync().isNotEmpty, isFalse);
  });

  test('10 hatalı paroladan sonra 429 (G4.3)', () async {
    for (var i = 0; i < 10; i++) {
      final r = await client
          .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/'));
      r.headers.set(HttpHeaders.authorizationHeader,
          'Basic ${base64.encode(utf8.encode('pc:yanlis$i'))}');
      final res = await r.close();
      await res.drain<void>();
      expect(res.statusCode, HttpStatus.unauthorized);
    }
    final res = await get('/');
    await res.drain<void>();
    expect(res.statusCode, HttpStatus.tooManyRequests,
        reason: 'doğru parola da sınır süresince reddedilir');
  });
}
