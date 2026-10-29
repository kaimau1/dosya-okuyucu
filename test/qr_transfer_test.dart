import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/qr_transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('adres QR: hotspot eki gidip geliyor, jeton yolu korunuyor', () {
    final url = Uri.parse('http://192.168.49.1:40123/q/AbC_d-9/');
    final raw = QrPayload.encode(url, ssid: 'DIRECT-x;y', pass: 'p:a"ss', sec: 'sae');
    final back = QrPayload.parse(raw)!;
    expect(back.url, url);
    expect(back.ssid, 'DIRECT-x;y');
    expect(back.pass, 'p:a"ss');
    expect(back.sec, 'sae');
    expect(QrPayload.parse(url.toString())!.ssid, isNull);
  });

  test('WIFI: QR kaçışları çözülüyor; yabancı kod reddediliyor', () {
    final wifi = QrPayload.wifi(r'Ağ;1', r'pa\ss:;', sec: 'wpa');
    expect(wifi, startsWith('WIFI:T:WPA;'));
    final back = QrPayload.parse(wifi)!;
    expect(back.url, isNull);
    expect(back.ssid, 'Ağ;1');
    expect(back.pass, r'pa\ss:;');
    expect(QrPayload.parse('https://example.com/q/x/'), isNull);
    expect(QrPayload.parse('merhaba'), isNull);
  });

  test('sunucu → alıcı: dosyalar iner, yanlış jeton 404', () async {
    final tmp = await Directory.systemTemp.createTemp('qrt');
    addTearDown(() => tmp.delete(recursive: true));
    final a = File(p.join(tmp.path, 'rapor.pdf'))
      ..writeAsBytesSync(List.generate(300000, (i) => i % 251));
    final b = File(p.join(tmp.path, 'not ğ.txt'))..writeAsStringSync('selam');
    final served = <String>[];
    final server = QrShareServer([a.path, b.path], onServed: served.add);
    await server.start();
    addTearDown(server.stop);

    final out = Directory(p.join(tmp.path, 'gelen'))..createSync();
    File(p.join(out.path, 'rapor.pdf')).writeAsStringSync('eski'); // ezilmemeli
    final got = await QrReceiver.download(server.urlFor('127.0.0.1'), out.path);
    expect(got.map(p.basename), ['rapor (1).pdf', 'not ğ.txt']);
    expect(File(got[0]).readAsBytesSync(), a.readAsBytesSync());
    expect(File(got[1]).readAsStringSync(), 'selam');
    expect(File(p.join(out.path, 'rapor.pdf')).readAsStringSync(), 'eski');
    expect(served, hasLength(2));

    final client = HttpClient();
    addTearDown(client.close);
    final bad = await (await client.getUrl(
            Uri.parse('http://127.0.0.1:${server.port}/q/yanlis/0')))
        .close();
    expect(bad.statusCode, 404);
    final page = await (await client.getUrl(server.urlFor('127.0.0.1'))).close();
    expect(page.statusCode, 200);
  });

  // 2026-10-28: onay için liste ÖNCE alınır; vazgeçilirse hiçbir şey inmez,
  // iptal edilen indirme yarım dosya bırakmaz.
  test('liste önce gelir; onaylı indirme listeyi yeniden istemez; iptal temiz',
      () async {
    final tmp = await Directory.systemTemp.createTemp('qrl');
    addTearDown(() => tmp.delete(recursive: true));
    final a = File(p.join(tmp.path, 'a.bin'))
      ..writeAsBytesSync(List.filled(200000, 7));
    final b = File(p.join(tmp.path, 'b.txt'))..writeAsStringSync('bb');
    final server = QrShareServer([a.path, b.path]);
    await server.start();
    addTearDown(server.stop);
    final url = server.urlFor('127.0.0.1');

    final items = await QrReceiver.list(url);
    expect(items.map((e) => e.name), ['a.bin', 'b.txt']);
    expect(items.map((e) => e.size), [200000, 2]);

    final out = Directory(p.join(tmp.path, 'gelen'))..createSync();
    final got = await QrReceiver.download(url, out.path, listed: items);
    expect(got.map(p.basename), ['a.bin', 'b.txt']);

    final out2 = Directory(p.join(tmp.path, 'iptal'))..createSync();
    final none = await QrReceiver.download(url, out2.path,
        listed: items, isCancelled: () => true);
    expect(none, isEmpty);
    expect(out2.listSync(), isEmpty);
  });

  // 2026-10-29: kısa adres, klasör paketi, Range ile devam, Tümünü indir.
  test('kısa jeton, klasör paket olarak gelir ve alıcıda AÇILIR', () async {
    final tmp = await Directory.systemTemp.createTemp('qrk');
    addTearDown(() => tmp.delete(recursive: true));
    final dir = Directory(p.join(tmp.path, 'Fotoğraflar'))..createSync();
    File(p.join(dir.path, 'a.txt')).writeAsStringSync('aaa');
    File(p.join(dir.path, 'b.txt')).writeAsStringSync('bbbb');
    final server = QrShareServer([dir.path], senderName: 'Ayşe');
    await server.start();
    addTearDown(server.stop);
    expect(server.token, matches(RegExp(r'^[a-z2-9]{6}$')));
    final url = server.urlFor('127.0.0.1');
    final items = await QrReceiver.list(url);
    expect(items.single.name, 'Fotoğraflar.zip');
    expect(items.single.files, 2);
    final out = Directory(p.join(tmp.path, 'gelen'))..createSync();
    final got = await QrReceiver.download(url, out.path, listed: items);
    expect(got.map(p.basename), ['Fotoğraflar']);
    expect(File(p.join(out.path, 'Fotoğraflar', 'b.txt')).readAsStringSync(),
        'bbbb');
    expect(out.listSync().map((e) => p.basename(e.path)), ['Fotoğraflar']);

    final client = HttpClient();
    addTearDown(client.close);
    final page = await (await client.getUrl(url)).close();
    final html = await page.transform(const SystemEncoding().decoder).join();
    expect(html, contains('Ayşe'));
    expect(html, isNot(contains('all.zip'))); // tek öğe: "Tümü" düğmesi yok
  });

  test('Range: kalan bayttan sürer; Tümünü indir ZIP veriyor', () async {
    final tmp = await Directory.systemTemp.createTemp('qrr');
    addTearDown(() => tmp.delete(recursive: true));
    final a = File(p.join(tmp.path, 'a.bin'))
      ..writeAsBytesSync(List.generate(1000, (i) => i % 256));
    final b = File(p.join(tmp.path, 'b.txt'))..writeAsStringSync('bb');
    final server = QrShareServer([a.path, b.path]);
    await server.start();
    addTearDown(server.stop);
    final url = server.urlFor('127.0.0.1');
    final client = HttpClient();
    addTearDown(client.close);
    final req = await client.getUrl(url.resolve('0'));
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=990-');
    final res = await req.close();
    expect(res.statusCode, HttpStatus.partialContent);
    final tail = [for (final c in await res.toList()) ...c];
    expect(tail, List.generate(10, (i) => (990 + i) % 256));
    final all = await (await client.getUrl(url.resolve('all.zip'))).close();
    expect(all.statusCode, 200);
    final zipBytes = [for (final c in await all.toList()) ...c];
    expect(zipBytes.sublist(0, 4), [0x50, 0x4b, 0x03, 0x04]);
    final page = await (await client.getUrl(url)).close();
    final html = await page.transform(const SystemEncoding().decoder).join();
    expect(html, contains('all.zip'));
  });
}
