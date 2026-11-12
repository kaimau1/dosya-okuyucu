import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/http_share_server.dart';
import 'package:dosya_okuyucu/services/fm/remote/lan_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// **G4 (2026-11-11)**: yerel sunucuların ortak kapısı — yalnız yerel ağ,
/// sabit zamanlı karşılaştırma, deneme sınırı, yükleme adı kuralları.
void main() {
  group('isPrivate', () {
    bool priv(String a) => LanGuard.isPrivate(InternetAddress(a));

    test('yerel ağ aralıkları kabul', () {
      for (final a in [
        '10.0.0.5',
        '10.255.255.255',
        '172.16.0.1',
        '172.31.255.254',
        '192.168.1.37',
        '192.168.43.1', // Android erişim noktası
        '169.254.10.2',
        '127.0.0.1',
        'fe80::1',
        'fd12:3456::1',
        '::1',
        '::ffff:192.168.1.5',
      ]) {
        expect(priv(a), isTrue, reason: a);
      }
    });

    test('genel adres, CGNAT ve sınır dışı aralıklar RED', () {
      for (final a in [
        '8.8.8.8',
        '100.64.0.1', // CGNAT (mobil operatör)
        '100.127.255.254',
        '172.15.255.255',
        '172.32.0.1',
        '192.169.0.1',
        '11.0.0.1',
        '2001:4860:4860::8888',
        '::ffff:8.8.8.8',
      ]) {
        expect(priv(a), isFalse, reason: a);
      }
    });
  });

  test('safeEquals', () {
    expect(LanGuard.safeEquals('abc123', 'abc123'), isTrue);
    expect(LanGuard.safeEquals('abc123', 'abc124'), isFalse);
    expect(LanGuard.safeEquals('abc', 'abc123'), isFalse);
    expect(LanGuard.safeEquals('', ''), isTrue);
    expect(LanGuard.safeEquals('ş', 's'), isFalse);
  });

  test('checkBasicAuth sabit zamanlı yolla aynı sonucu verir', () {
    String h(String s) => 'Basic ${base64Encode(s)}';
    expect(checkBasicAuth(h('pc:123'), 'pc', '123'), isTrue);
    expect(checkBasicAuth(h('pc:124'), 'pc', '123'), isFalse);
    expect(checkBasicAuth(h('pd:123'), 'pc', '123'), isFalse);
    expect(checkBasicAuth(h('pc:12'), 'pc', '123'), isFalse);
  });

  test('AuthThrottle: sınırda bloklar, süre dolunca açar, başarı sıfırlar', () {
    var now = DateTime(2026, 11, 11);
    final t = AuthThrottle(limit: 3, clock: () => now);
    expect(t.fail('1.1.1.1'), isFalse);
    expect(t.fail('1.1.1.1'), isFalse);
    expect(t.blocked('1.1.1.1'), isFalse);
    expect(t.fail('1.1.1.1'), isTrue);
    expect(t.blocked('1.1.1.1'), isTrue);
    expect(t.blocked('2.2.2.2'), isFalse, reason: 'adres başına');
    now = now.add(const Duration(seconds: 61));
    expect(t.blocked('1.1.1.1'), isFalse);
    t.fail('3.3.3.3');
    t.fail('3.3.3.3');
    t.success('3.3.3.3');
    expect(t.fail('3.3.3.3'), isFalse, reason: 'başarı sayacı sıfırlar');
  });

  test('RequestGate sınır doluyken 503 döndürür, boşalınca kabul eder (G4.5)',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    LanGuard.harden(server);
    expect(server.idleTimeout, LanGuard.idleTimeout);
    final gate = RequestGate(limit: 1);
    final hold = Completer<void>();
    var first = true;
    server.listen((req) {
      final slow = first;
      first = false;
      unawaited(gate.run(req, () async {
        if (slow) await hold.future;
        req.response.write('ok');
        await req.response.close();
      }));
    });
    final client = HttpClient();
    final url = Uri.parse('http://127.0.0.1:${server.port}/');
    try {
      final pending = client.getUrl(url).then((r) => r.close());
      // İlk istek kapıya girsin.
      while (gate.active == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final busy = await (await client.getUrl(url)).close();
      expect(busy.statusCode, HttpStatus.serviceUnavailable);
      await busy.drain<void>();
      hold.complete();
      final ok = await pending;
      expect(ok.statusCode, HttpStatus.ok);
      await ok.drain<void>();
      final again = await (await client.getUrl(url)).close();
      expect(again.statusCode, HttpStatus.ok);
      await again.drain<void>();
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });

  group('yükleme dosya adı (G4.5)', () {
    String? name(String n) =>
        HttpShareServer.uploadFileName('form-data; name="f"; filename="$n"');

    test('denetim karakterleri, noktalar, ayrılmış adlar', () {
      expect(name('a\u0007b.txt'), 'ab.txt');
      expect(name('...'), isNull);
      expect(name('CON.txt'), '_CON.txt');
      expect(name('nul'), '_nul');
      expect(name('com1.log'), '_com1.log');
      expect(name('console.txt'), 'console.txt');
    });

    test('255 bayttan uzun ad uzantı korunarak kısalır', () {
      final long = '${'ş' * 200}.pdf';
      final out = name(long)!;
      expect(out.endsWith('.pdf'), isTrue);
      expect(utf8Length(out), lessThanOrEqualTo(255));
    });
  });
}

int utf8Length(String s) => convert.utf8.encode(s).length;

String base64Encode(String s) => convert.base64.encode(convert.utf8.encode(s));
