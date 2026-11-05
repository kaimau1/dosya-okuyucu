import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/qr_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 41 / 4: kısa ömürlü / tek seferlik paylaşım bağlantısı.
void main() {
  test('süre kararı', () {
    final t = DateTime(2026, 11, 5, 12);
    expect(QrShareServer.isExpired(t, null), isFalse);
    expect(QrShareServer.isExpired(t, t.add(const Duration(minutes: 1))), isFalse);
    expect(QrShareServer.isExpired(t, t), isTrue);
  });

  test('süre dolunca sunucu kapanır ve haber verir', () async {
    final dir = Directory.systemTemp.createTempSync('lnk');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/a.txt')..writeAsStringSync('merhaba');
    var expired = false;
    final s = QrShareServer([f.path],
        preferredPort: 0,
        ttl: const Duration(milliseconds: 150),
        onExpired: () => expired = true);
    await s.start();
    expect(s.expiresAt, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(expired, isTrue);
    expect(s.port, 0); // kapandı
  });

  test('tek indirme: dosya bir kez inince bağlantı kapanır', () async {
    final dir = Directory.systemTemp.createTempSync('lnk');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/a.txt')..writeAsStringSync('merhaba');
    var expired = false;
    final served = <String>[];
    final s = QrShareServer([f.path],
        preferredPort: 0,
        maxDownloads: 1,
        onServed: served.add,
        onExpired: () => expired = true);
    await s.start();
    final client = HttpClient();
    addTearDown(client.close);
    final req = await client.get('127.0.0.1', s.port, '/q/${s.token}/0');
    final res = await req.close();
    final body = await res.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(String.fromCharCodes(body), 'merhaba');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(served, ['a.txt']);
    expect(expired, isTrue);
  });
}
