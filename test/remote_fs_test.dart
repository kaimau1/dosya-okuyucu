import 'package:dosya_okuyucu/models/remote_connection.dart';
import 'package:dosya_okuyucu/services/fm/remote/lan_discovery.dart';
import 'package:dosya_okuyucu/services/fm/remote/remote_fs.dart';
import 'package:dosya_okuyucu/services/fm/remote/remote_fs_factory.dart';
import 'package:dosya_okuyucu/services/fm/remote/smb_fs.dart';
import 'package:dosya_okuyucu/services/fm/remote/webdav_fs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('yol yardımcıları', () {
    test('join çift ayraç üretmez', () {
      expect(RemoteFs.join('/a/b', 'c'), '/a/b/c');
      expect(RemoteFs.join('/a/b/', 'c'), '/a/b/c');
      expect(RemoteFs.join('/a/b', '/c'), '/a/b/c');
      expect(RemoteFs.join('/', 'c'), '/c');
      expect(RemoteFs.join('', 'c'), '/c');
    });

    test('parentOf kökün üstüne ÇIKMAZ', () {
      // Kökün üstü yine kök: kullanıcı "yukarı" ile sunucunun dışına
      // çıkamamalı ve ekran boş listeye kilitlenmemeli.
      expect(RemoteFs.parentOf('/a/b/c'), '/a/b');
      expect(RemoteFs.parentOf('/a'), '/');
      expect(RemoteFs.parentOf('/'), '/');
      expect(RemoteFs.parentOf(''), '/');
      expect(RemoteFs.parentOf('/a/b/'), '/a');
    });

    test('nameOf son parçayı verir', () {
      expect(RemoteFs.nameOf('/a/b/c.txt'), 'c.txt');
      expect(RemoteFs.nameOf('/a/b/'), 'b');
      expect(RemoteFs.nameOf('tek'), 'tek');
    });

    test('sıralama: klasörler önce, sonra harf duyarsız ad', () {
      final sorted = RemoteFs.sorted(const [
        RemoteEntry(name: 'zeta.txt', path: '/zeta.txt', isDir: false),
        RemoteEntry(name: 'Beta', path: '/Beta', isDir: true),
        RemoteEntry(name: 'alfa.txt', path: '/alfa.txt', isDir: false),
        RemoteEntry(name: 'ceta', path: '/ceta', isDir: true),
      ]);
      expect(sorted.map((e) => e.name), ['Beta', 'ceta', 'alfa.txt', 'zeta.txt']);
    });

    test('. ve .. listede gösterilmez', () {
      expect(RemoteFs.isDotEntry('.'), isTrue);
      expect(RemoteFs.isDotEntry('..'), isTrue);
      expect(RemoteFs.isDotEntry('...gizli'), isFalse);
    });
  });

  group('hata eşlemesi', () {
    test('ulaşılamayan sunucu', () {
      expect(RemoteFs.mapError('Connection refused').error,
          RemoteError.unreachable);
      expect(RemoteFs.mapError('Failed host lookup: nas.local').error,
          RemoteError.unreachable);
    });

    test('kimlik doğrulama', () {
      expect(RemoteFs.mapError('530 Login incorrect').error, RemoteError.auth);
      expect(RemoteFs.mapError('STATUS_LOGON_FAILURE').error, RemoteError.auth);
    });

    test('bulunamadı / izin yok / desteklenmiyor', () {
      expect(RemoteFs.mapError('550 No such file').error, RemoteError.notFound);
      expect(RemoteFs.mapError('403 Forbidden').error, RemoteError.denied);
      expect(RemoteFs.mapError('Unsupported dialect').error,
          RemoteError.unsupported);
    });

    test('var olan RemoteException aynen geçer', () {
      const original = RemoteException(RemoteError.denied, detail: 'x');
      expect(identical(RemoteFs.mapError(original), original), isTrue);
    });
  });

  group('bağlantı modeli', () {
    RemoteConnection sample({bool savePassword = true}) => RemoteConnection(
          id: 'r1',
          name: 'Ev NAS',
          protocol: RemoteProtocol.sftp,
          host: '192.168.1.10',
          port: 22,
          user: 'ali',
          password: 'gizli',
          savePassword: savePassword,
        );

    test('gidiş-dönüş', () {
      final decoded = RemoteConnection.tryDecode(sample().encode())!;
      expect(decoded.id, 'r1');
      expect(decoded.protocol, RemoteProtocol.sftp);
      expect(decoded.password, 'gizli');
      expect(decoded.port, 22);
    });

    test('savePassword KAPALIYKEN parola diske YAZILMAZ', () {
      final saved = sample(savePassword: false);
      expect(saved.encode().contains('gizli'), isFalse);
      final decoded = RemoteConnection.tryDecode(saved.encode())!;
      expect(decoded.password, '');
      // Bellekteki nesne parolayı oturum boyunca taşımaya devam eder.
      expect(saved.password, 'gizli');
    });

    test('bozuk/eksik kayıt null döner, çökme YOK', () {
      expect(RemoteConnection.tryDecode('çöp'), isNull);
      expect(RemoteConnection.tryDecode('{"id":"a"}'), isNull); // host yok
      expect(RemoteConnection.tryDecode('{"host":"h"}'), isNull); // id yok
    });

    test('bilinmeyen protokol FTP\'ye düşer, port varsayılanı gelir', () {
      final decoded = RemoteConnection.tryDecode(
          '{"id":"a","host":"h","protocol":"gopher"}')!;
      expect(decoded.protocol, RemoteProtocol.ftp);
      expect(decoded.port, 21);
    });

    test('varsayılan portlar', () {
      expect(RemoteProtocol.ftp.defaultPort, 21);
      expect(RemoteProtocol.ftps.defaultPort, 990);
      expect(RemoteProtocol.sftp.defaultPort, 22);
      expect(RemoteProtocol.smb.defaultPort, 445);
    });

    test('rootPath boş başlangıç yolunda köke düşer', () {
      expect(sample().rootPath, '/');
      expect(sample().copyWith(initialPath: '/veri').rootPath, '/veri');
      expect(sample().copyWith(initialPath: '   ').rootPath, '/');
    });
  });

  group('fabrika', () {
    RemoteConnection of(RemoteProtocol protocol) => RemoteConnection(
        id: 'x',
        name: 'x',
        protocol: protocol,
        host: 'h',
        port: protocol.defaultPort);

    test('her protokol bir gerçeklemeye eşlenir', () {
      // Yeni protokol eklenip fabrika unutulursa switch derlenmez; bu test
      // eşlemenin DOĞRU sınıfa gittiğini kilitliyor.
      for (final protocol in RemoteProtocol.values) {
        expect(createRemoteFs(of(protocol)).connection.protocol, protocol);
      }
      expect(createRemoteFs(of(RemoteProtocol.smb)), isA<SmbFs>());
      expect(createRemoteFs(of(RemoteProtocol.webdav)), isA<WebDavFs>());
    });
  });

  group('SMB yol biçimi', () {
    test('yol ters eğik çizgiye ÇEVRİLMEZ (paylaşım adı bozulur)', () {
      // Paket `/paylasim/klasor` bekliyor. `\paylasim\klasor`e çevirmek
      // `getShare`in tüm dizgiyi paylaşım adı sanmasına ve tree connect'in
      // STATUS_NETWORK_NAME_DELETED ile düşmesine yol açıyor — gerçek Samba
      // sunucusuna karşı ölçüldü (test/remote_live_test.dart).
      expect(SmbFs.toSmbPath('/paylasim/klasor'), '/paylasim/klasor');
      expect(SmbFs.toSmbPath('paylasim/klasor'), '/paylasim/klasor');
      expect(SmbFs.toSmbPath('/'), '/');
    });

    test('gelen yol tek biçime indirgenir', () {
      expect(SmbFs.fromSmbPath(r'paylasim\klasor'), '/paylasim/klasor');
      expect(SmbFs.fromSmbPath('/paylasim'), '/paylasim');
      expect(SmbFs.fromSmbPath(r'\paylasim'), '/paylasim');
    });

    test('kök = paylaşım listesi', () {
      expect(SmbFs.isShareRoot('/'), isTrue);
      expect(SmbFs.isShareRoot(''), isTrue);
      expect(SmbFs.isShareRoot('/paylasim'), isFalse);
    });
  });

  group('WebDAV adresi', () {
    test('şema yazılmazsa HTTPS varsayılır', () {
      // http'ye sessizce düşmek parolayı şifresiz göndermek olurdu.
      expect(WebDavFs.baseUrl('sunucu/dav', 443), startsWith('https://'));
    });

    test('kullanıcının yazdığı şema ve port korunur', () {
      expect(WebDavFs.baseUrl('http://sunucu:8080/dav', 8080),
          'http://sunucu:8080/dav');
      expect(WebDavFs.baseUrl('https://sunucu/dav', 443),
          'https://sunucu/dav');
    });

    test('varsayılan olmayan port adrese eklenir', () {
      expect(WebDavFs.baseUrl('https://sunucu/dav', 5006),
          contains(':5006'));
    });
  });

  group('LAN keşfi', () {
    test('alt ağ öneki', () {
      expect(LanDiscovery.subnetPrefix('192.168.1.37'), '192.168.1.');
      expect(LanDiscovery.subnetPrefix('10.0.0.1'), '10.0.0.');
      expect(LanDiscovery.subnetPrefix('nas.local'), isNull);
      expect(LanDiscovery.subnetPrefix('192.168.1'), isNull);
    });

    test('taranan portlar protokollere eşleniyor', () {
      expect(LanDiscovery.probes[445], RemoteProtocol.smb);
      expect(LanDiscovery.probes[22], RemoteProtocol.sftp);
      expect(LanDiscovery.probes[21], RemoteProtocol.ftp);
    });

    test('kapalı port yanlış pozitif vermez', () async {
      // 9 numaralı port (discard) bu ortamda kapalı; kısa zaman aşımıyla
      // false dönmeli — tarama "her adres canlı" demiyor.
      final alive = await LanDiscovery.probe('127.0.0.1', 9,
          timeout: const Duration(milliseconds: 200));
      expect(alive, isFalse);
    });
  });
}
