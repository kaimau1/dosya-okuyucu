import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/mime_types.dart';
import 'package:dosya_okuyucu/services/fm/remote/ftp_server.dart';
import 'package:dosya_okuyucu/services/fm/remote/http_share_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// **Niye bu test var — kullanıcı hatası 2026-08-29:**
/// *"Herhangi bir belgeyi ağda paylaşıp bilgisayarımda açmaya çalıştığımda
/// Microsoft Edge açılıyor, dosya açılmıyor; ama kopyalayıp bilgisayarıma
/// atınca açılıyor."*
///
/// Kök neden: paylaşım yalnız FTP konuşuyordu, Chromium tabanlı tarayıcılar
/// ise FTP desteğini 2021'de kaldırdı. Çözüm aynı ağacı HTTP'den de sunmak.
/// Burada ölçülen şey "sunucu ayakta mı" değil, **tarayıcının dosyayı
/// açabilmesi için gereken başlıklar**: doğru MIME, `Content-Disposition` ve
/// `Range`.
void main() {
  group('saf yardımcılar', () {
    test('tarayıcının GÖSTEREBİLDİĞİ türler inline, ötekiler attachment', () {
      // Kullanıcının açamadığı dosya tam olarak bu sınıftaydı: Word/Excel.
      expect(MimeTypes.opensInBrowser(MimeTypes.forName('rapor.docx')),
          isFalse);
      expect(MimeTypes.opensInBrowser(MimeTypes.forName('liste.xlsx')),
          isFalse);
      expect(MimeTypes.opensInBrowser(MimeTypes.forName('arsiv.zip')), isFalse);
      // Bunlar sekmede açılmalı.
      expect(MimeTypes.opensInBrowser(MimeTypes.forName('fatura.pdf')), isTrue);
      expect(MimeTypes.opensInBrowser(MimeTypes.forName('a.JPG')), isTrue);
      expect(MimeTypes.opensInBrowser(MimeTypes.forName('film.mp4')), isTrue);
    });

    test('Türkçe dosya adı Content-Disposition\'da BOZULMADAN taşınır', () {
      final header = contentDisposition('Fatura Şubat.pdf', true);
      expect(header.startsWith('inline;'), isTrue);
      // ASCII biçim yedek; doğru adı RFC 5987 biçimi taşır.
      expect(header.contains("filename*=UTF-8''"), isTrue);
      expect(
        Uri.decodeComponent(header.split("filename*=UTF-8''").last),
        'Fatura Şubat.pdf',
      );
    });

    test('tırnak ve ASCII dışı karakter başlığı kırmaz', () {
      final header = contentDisposition('a"b\nç.txt', false);
      expect(header.startsWith('attachment;'), isTrue);
      expect(header.contains('a\'b'), isTrue);
      expect(header.contains('\n'), isFalse);
    });

    group('parseRange', () {
      test('başlık yoksa dosyanın tamamı', () {
        final r = parseRange(null, 100)!;
        expect((r.start, r.end, r.partial, r.length), (0, 99, false, 100));
      });

      test('açık uçlu aralık dosyanın sonuna kadar', () {
        final r = parseRange('bytes=10-', 100)!;
        expect((r.start, r.end, r.partial), (10, 99, true));
      });

      test('kapalı aralık', () {
        final r = parseRange('bytes=10-19', 100)!;
        expect((r.start, r.end, r.length), (10, 19, 10));
      });

      test('sondan N bayt', () {
        final r = parseRange('bytes=-20', 100)!;
        expect((r.start, r.end), (80, 99));
      });

      test('dosya boyunu aşan son sınırlanır', () {
        final r = parseRange('bytes=90-500', 100)!;
        expect(r.end, 99);
      });

      test('dosyanın DIŞINDA başlayan istek reddedilir (416)', () {
        // Sessizce tüm dosyayı göndermek oynatıcıyı bozuk veriyle besler.
        expect(parseRange('bytes=500-', 100), isNull);
        expect(parseRange('bytes=10-5', 100), isNull);
      });
    });

    test('yol kodlaması: ayraç korunur, ad kodlanır', () {
      expect(encodePath('/Belgeler/Fatura Şubat.pdf'),
          '/Belgeler/Fatura%20%C5%9Eubat.pdf');
    });

    test('dosya adındaki HTML kaçırılır', () {
      final html = HttpShareServer.listingHtml(
        title: 'Belgeler',
        virtualPath: '/Belgeler',
        rows: const [HttpShareRow(name: '<script>x</script>.txt', isDir: false)],
      );
      expect(html.contains('<script>'), isFalse);
      expect(html.contains('&lt;script&gt;'), isTrue);
    });

    test('klasörler önce, sonra ada göre sıralı', () {
      final html = HttpShareServer.listingHtml(
        title: 'Kök',
        virtualPath: '/',
        rows: const [
          HttpShareRow(name: 'b.txt', isDir: false),
          HttpShareRow(name: 'Zklasor', isDir: true),
          HttpShareRow(name: 'a.txt', isDir: false),
        ],
      );
      expect(html.indexOf('Zklasor'), lessThan(html.indexOf('a.txt')));
      expect(html.indexOf('a.txt'), lessThan(html.indexOf('b.txt')));
      // Kökte "yukarı" bağlantısı olmamalı.
      expect(html.contains('class="up"'), isFalse);
    });

    group('checkBasicAuth', () {
      String basic(String u, String pw) =>
          'Basic ${base64.encode(utf8.encode('$u:$pw'))}';

      test('doğru kullanıcı/parola geçer', () {
        expect(checkBasicAuth(basic('pc', '123456'), 'pc', '123456'), isTrue);
      });

      test('yanlış parola, eksik başlık ve bozuk base64 geçmez', () {
        expect(checkBasicAuth(basic('pc', 'yanlis'), 'pc', '123456'), isFalse);
        expect(checkBasicAuth(null, 'pc', '123456'), isFalse);
        expect(checkBasicAuth('Basic !!!', 'pc', '123456'), isFalse);
        expect(checkBasicAuth('Bearer abc', 'pc', '123456'), isFalse);
      });

      test('parolada iki nokta üst üste olabilir', () {
        expect(checkBasicAuth(basic('pc', 'a:b'), 'pc', 'a:b'), isTrue);
      });
    });
  });

  group('gerçek sunucu', () {
    late Directory root;
    late FtpServer share;
    late HttpShareServer server;
    late HttpClient client;

    setUp(() async {
      root = Directory.systemTemp.createTempSync('http_share');
      File(p.join(root.path, 'Rapor Şubat.docx'))
          .writeAsBytesSync(List<int>.filled(500, 3));
      File(p.join(root.path, 'fatura.pdf')).writeAsStringSync('%PDF-1.4 test');
      Directory(p.join(root.path, 'Alt')).createSync();
      File(p.join(root.path, '.gizli')).writeAsStringSync('x');

      share = FtpServer(
        rootDirectory: root.path,
        username: 'pc',
        password: '123456',
        // Kategori kutuları gerçek kitaplığı tarar; testte boş bırakılıyor.
        collectCategory: (_) async => const [],
      );
      // Port 0: işletim sistemi boş port seçsin (testler paralel koşuyor).
      server = HttpShareServer(share: share, port: 0);
      await server.start();
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.stop();
      removeTempDir(root);
    });

    Future<HttpClientResponse> get(String path, {bool auth = true}) async {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}$path'));
      if (auth) {
        request.headers.set(HttpHeaders.authorizationHeader,
            'Basic ${base64.encode(utf8.encode('pc:123456'))}');
      }
      return request.close();
    }

    test('parolasız istek 401 döner (tarayıcı kendi penceresini açar)',
        () async {
      final response = await get('/', auth: false);
      expect(response.statusCode, HttpStatus.unauthorized);
      expect(response.headers.value(HttpHeaders.wwwAuthenticateHeader),
          contains('Basic'));
      await response.drain<void>();
    });

    test('kök, telefondaki kutuların aynısını listeler', () async {
      final response = await get('/');
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, 200);
      // FTP'deki sanal ağacın aynısı — iki kapı, tek ağaç.
      expect(body, contains('Telefon'));
      expect(body, contains('Belgeler'));
    });

    test('gerçek klasör listelenir; gizli dosya GİZLİ kalır', () async {
      final response = await get('/Telefon');
      final body = await response.transform(utf8.decoder).join();
      expect(body, contains('Rapor Şubat.docx'));
      expect(body, contains('Alt'));
      expect(body.contains('.gizli'), isFalse);
    });

    test('WORD BELGESİ indirilir (kullanıcının açamadığı dosya)', () async {
      // Bağlantı, listeleme sayfasının ürettiğinin AYNISI: tarayıcı da tam
      // olarak bunu izliyor.
      final response = await get(encodePath('/Telefon/Rapor Şubat.docx'));
      expect(response.statusCode, 200);
      expect(
        response.headers.contentType.toString(),
        startsWith('application/vnd.openxmlformats-officedocument'),
      );
      // Kritik başlık: bu olmadan tarayıcı belgeyi "göstermeye" çalışıp boş
      // kalıyordu.
      expect(response.headers.value('content-disposition'),
          startsWith('attachment;'));
      final bytes = await response.fold<int>(0, (n, chunk) => n + chunk.length);
      expect(bytes, 500);
    });

    test('PDF sekmede açılır (inline)', () async {
      final response = await get('/Telefon/fatura.pdf');
      expect(response.headers.contentType?.mimeType, 'application/pdf');
      expect(response.headers.value('content-disposition'),
          startsWith('inline;'));
      await response.drain<void>();
    });

    test('?indir=1 gösterilebilen dosyayı da indirtir', () async {
      final response = await get('/Telefon/fatura.pdf?indir=1');
      expect(response.headers.value('content-disposition'),
          startsWith('attachment;'));
      await response.drain<void>();
    });

    test('Range isteği 206 ve doğru dilim döner (video ileri sarma)',
        () async {
      final request = await client.getUrl(Uri.parse(
          'http://127.0.0.1:${server.boundPort}/Telefon/fatura.pdf'));
      request.headers.set(HttpHeaders.authorizationHeader,
          'Basic ${base64.encode(utf8.encode('pc:123456'))}');
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=5-9');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.headers.value(HttpHeaders.contentRangeHeader),
          'bytes 5-9/13');
      // '%PDF-1.4 test' dizesinin 5..9 aralığı.
      expect(await response.transform(utf8.decoder).join(), '1.4 t');
    });

    test('KÖK DIŞINA çıkma denemesi dosya sızdırmaz', () async {
      final response = await get('/../../etc/passwd');
      // Normalize sonrası kökün içinde kalır → böyle bir dosya yok.
      expect(response.statusCode, HttpStatus.notFound);
      await response.drain<void>();
    });

    test('yazma denemeleri reddedilir (tarayıcıdan silme YOK)', () async {
      final request = await client.deleteUrl(Uri.parse(
          'http://127.0.0.1:${server.boundPort}/Telefon/fatura.pdf'));
      request.headers.set(HttpHeaders.authorizationHeader,
          'Basic ${base64.encode(utf8.encode('pc:123456'))}');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.methodNotAllowed);
      await response.drain<void>();
      expect(File(p.join(root.path, 'fatura.pdf')).existsSync(), isTrue);
    });
  });
}
