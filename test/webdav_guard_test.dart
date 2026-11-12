import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/remote_fs.dart';
import 'package:dosya_okuyucu/services/fm/remote/webdav_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// G8.3: WebDAV yönlendirmesinde kimlik başka sunucuya gitmez; internetteki
/// sunucuya http:// ile parola gönderilmez.
void main() {
  group('sameOrigin', () {
    final base = Uri.parse('https://nas.ornek.com/dav/');
    test('aynı köken izinli', () {
      expect(WebDavGuard.sameOrigin(base, Uri.parse('https://NAS.ornek.com/dav/a')), isTrue);
    });
    test('başka ana makine, port, şema ya da http düşüşü reddedilir', () {
      expect(WebDavGuard.sameOrigin(base, Uri.parse('https://kotu.com/dav/')), isFalse);
      expect(WebDavGuard.sameOrigin(base, Uri.parse('https://nas.ornek.com:8443/')), isFalse);
      expect(WebDavGuard.sameOrigin(base, Uri.parse('http://nas.ornek.com/dav/')), isFalse);
      expect(WebDavGuard.sameOrigin(base, Uri.parse('ftp://nas.ornek.com/')), isFalse);
    });
  });

  group('plainHttpAllowed', () {
    InternetAddress a(String s) => InternetAddress(s);
    test('yerel ağ ve Tailscale aralığı izinli', () {
      for (final s in ['192.168.1.5', '10.0.0.2', '172.20.1.1', '127.0.0.1',
          '100.101.102.103', 'fd00::1', 'fe80::1']) {
        expect(WebDavGuard.plainHttpAllowed([a(s)]), isTrue, reason: s);
      }
    });
    test('genel adres ya da karışık liste reddedilir', () {
      expect(WebDavGuard.plainHttpAllowed([a('8.8.8.8')]), isFalse);
      expect(WebDavGuard.plainHttpAllowed([a('192.168.1.5'), a('1.1.1.1')]), isFalse);
      expect(WebDavGuard.plainHttpAllowed(const []), isFalse);
    });
  });

  group('checkPlainHttp', () {
    Future<List<InternetAddress>> genel(String _) async => [InternetAddress('93.184.216.34')];
    Future<List<InternetAddress>> yerel(String _) async => [InternetAddress('192.168.1.9')];

    test('internetteki http + parola → insecure', () async {
      await expectLater(
        WebDavGuard.checkPlainHttp('http://dav.ornek.com/', hasCredentials: true, lookup: genel),
        throwsA(isA<RemoteException>().having((e) => e.error, 'error', RemoteError.insecure)),
      );
    });
    test('iç DNS yerel adrese çözülürse, https, kimliksiz ya da .local izinli', () async {
      await WebDavGuard.checkPlainHttp('http://dav.ornek.com/', hasCredentials: true, lookup: yerel);
      await WebDavGuard.checkPlainHttp('https://dav.ornek.com/', hasCredentials: true, lookup: genel);
      await WebDavGuard.checkPlainHttp('http://dav.ornek.com/', hasCredentials: false, lookup: genel);
      await WebDavGuard.checkPlainHttp('http://nas.local/', hasCredentials: true, lookup: genel);
      await WebDavGuard.checkPlainHttp('http://192.168.1.4:5005/', hasCredentials: true);
    });
  });

  test('başka sunucuya yönlendirmede parola oraya hiç gitmez', () async {
    final hedef = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final gelen = <String?>[];
    hedef.listen((r) {
      gelen.add(r.headers.value('authorization'));
      r.response.statusCode = 207;
      r.response.close();
    });
    final kaynak = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    kaynak.listen((r) {
      r.response.statusCode = 302;
      r.response.headers.set('location', 'http://127.0.0.1:${hedef.port}/calinti/');
      r.response.close();
    });
    addTearDown(() async {
      await hedef.close(force: true);
      await kaynak.close(force: true);
    });

    final url = 'http://127.0.0.1:${kaynak.port}/';
    final client = webdav.newClient(url, user: 'u', password: 'gizli');
    client.c.interceptors.add(WebDavGuardInterceptor(Uri.parse(url)));
    Object? hata;
    try {
      await client.ping();
    } catch (e) {
      hata = e;
    }
    expect(gelen, isEmpty);
    expect(mapWebDavError(hata!).error, RemoteError.insecure);
  });

  test('aynı kökende sonsuz yönlendirme sınırda kesilir', () async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var sayi = 0;
    s.listen((r) {
      sayi++;
      r.response.statusCode = 302;
      r.response.headers.set('location', 'http://127.0.0.1:${s.port}/d$sayi/');
      r.response.close();
    });
    addTearDown(() => s.close(force: true));
    final url = 'http://127.0.0.1:${s.port}/';
    final client = webdav.newClient(url);
    client.c.interceptors.add(WebDavGuardInterceptor(Uri.parse(url)));
    Object? hata;
    try {
      await client.ping();
    } catch (e) {
      hata = e;
    }
    expect(mapWebDavError(hata!).error, RemoteError.insecure);
    expect(sayi, WebDavGuard.maxRedirects + 1);
  });
}
