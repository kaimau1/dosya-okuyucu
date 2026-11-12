import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/disk_guard.dart';
import 'package:dosya_okuyucu/services/fm/remote/ftp_server.dart';
import 'package:dosya_okuyucu/services/fm/remote/http_share_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// G4.5 — yüklemede boş disk denetimi.
void main() {
  const mb = 1024 * 1024;
  final original = DiskGuard.freeBytesOf;
  tearDown(() => DiskGuard.freeBytesOf = original);

  group('DiskGuard.hasRoom', () {
    test('200 MB altına düşecekse yer yok', () async {
      DiskGuard.freeBytesOf = (_) async => 250 * mb;
      expect(await DiskGuard.hasRoom('/x'), isTrue);
      expect(await DiskGuard.hasRoom('/x', incoming: 40 * mb), isTrue);
      expect(await DiskGuard.hasRoom('/x', incoming: 60 * mb), isFalse);
      DiskGuard.freeBytesOf = (_) async => 150 * mb;
      expect(await DiskGuard.hasRoom('/x'), isFalse);
    });

    test('bilinmeyen boyut (-1) 0 sayılır', () async {
      DiskGuard.freeBytesOf = (_) async => 250 * mb;
      expect(await DiskGuard.hasRoom('/x', incoming: -1), isTrue);
    });

    test('ölçülemeyen boş alan engel değil', () async {
      DiskGuard.freeBytesOf = (_) async => null;
      expect(await DiskGuard.hasRoom('/x', incoming: 1 << 40), isTrue);
      DiskGuard.freeBytesOf = (_) async => throw const FileSystemException();
      expect(await DiskGuard.hasRoom('/x'), isTrue);
    });
  });

  test('HTTP yükleme: yer yoksa 507, dosya yazılmaz', () async {
    DiskGuard.freeBytesOf = (_) async => 100 * mb;
    final root = Directory.systemTemp.createTempSync('http_507');
    final inbox = p.join(root.path, 'Gelen');
    Directory(inbox).createSync();
    final share = FtpServer(
      rootDirectory: root.path,
      username: 'pc',
      password: '1',
      collectCategory: (_) async => const [],
    );
    final uploaded = <String>[];
    final server = HttpShareServer(
        share: share, port: 0, uploadDir: inbox, onUploaded: uploaded.addAll);
    await server.start();
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(
          'http://127.0.0.1:${server.boundPort}${HttpShareServer.uploadPath}'));
      request.headers.set(HttpHeaders.authorizationHeader,
          'Basic ${base64.encode(utf8.encode('pc:1'))}');
      request.headers.contentType = ContentType('multipart', 'form-data',
          parameters: {'boundary': 'SINIR'});
      request.write('--SINIR\r\n'
          'Content-Disposition: form-data; name="f"; filename="dolu.txt"\r\n'
          'Content-Type: text/plain\r\n\r\n'
          'icerik\r\n'
          '--SINIR--\r\n');
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, 507);
      expect(File(p.join(inbox, 'dolu.txt')).existsSync(), isFalse);
      expect(uploaded, isEmpty);
    } finally {
      client.close(force: true);
      await server.stop();
      removeTempDir(root);
    }
  });
}
