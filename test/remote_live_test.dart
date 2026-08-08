@Tags(['live'])
library;

import 'dart:io';

import 'package:dosya_okuyucu/models/remote_connection.dart';
import 'package:dosya_okuyucu/services/fm/remote/ftp_fs.dart';
import 'package:dosya_okuyucu/services/fm/remote/remote_fs.dart';
import 'package:dosya_okuyucu/services/fm/remote/sftp_fs.dart';
import 'package:dosya_okuyucu/services/fm/remote/smb_fs.dart';
import 'package:dosya_okuyucu/services/fm/remote/webdav_fs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/temp_dir.dart';

/// **Gerçek sunuculara karşı** uzak dosya sistemi testleri.
///
/// Diğer testler sahte/`MockClient` üzerinden koşuyor; burada dört protokolün
/// istemcisi de gerçekten konuşan bir sunucuya bağlanıyor. Bu, "paket
/// çalışıyor mu" sorusunu tahminden ölçüme taşıyor — özellikle **SMB** için
/// (olgunlaşmamış `smb_connect 0.0.9`).
///
/// **Sunucu yoksa test ATLANIR, kırmızı olmaz.** CI'da bu sunucular yok;
/// zorunlu kılmak CI'yı sürekli kırardı. Geliştirme ortamında kurmak için:
///
/// ```sh
/// # SFTP
/// apt-get install -y openssh-server
/// # (ayrı sshd_config ile 2222'de, kullanıcı nastest/nasgizli)
/// # FTP
/// pip install pyftpdlib     # 2121, nastest/nasgizli, kök /tmp/nas/ftp
/// # WebDAV
/// pip install wsgidav cheroot
/// python3 -m wsgidav.server.server_cli --port=8081 --root=/tmp/nas/dav --auth=anonymous
/// # SMB
/// # SMB — GERCEK Samba gerekiyor. impacket'in oyuncak sunucusu YETMIYOR:
/// #   baglanti + paylasim listeleme calisiyor, paylasimin ICINE girmek dusuyor.
/// apt-get install -y samba
/// #   smb.conf: smb ports = 445 · interfaces = lo 127.0.0.1 ·
/// #             bind interfaces only = yes  (IPv6 yoksa SART)
/// #   paylasim "paylasim" -> /tmp/nas/smb, kullanici nastest/nasgizli
/// ```
///
/// Koşmak için: `flutter test test/remote_live_test.dart`
void main() {
  group('SFTP (gerçek sunucu)', () {
    const connection = RemoteConnection(
      id: 'live-sftp',
      name: 'live',
      protocol: RemoteProtocol.sftp,
      host: '127.0.0.1',
      port: 2222,
      user: 'nastest',
      password: 'nasgizli',
    );

    test('bağlan · listele · indir · yükle · sil', () async {
      if (!await _up(2222)) return _skip('sshd :2222');
      final fs = SftpFs(connection);
      await fs.connect();
      addTearDown(fs.close);

      final entries = await fs.list('/home/nastest');
      expect(entries.map((e) => e.name), containsAll(['a.txt', 'klasor']));
      // Klasörler ÖNCE gelmeli (sıralama sözleşmesi).
      expect(entries.first.isDir, isTrue);
      final file = entries.firstWhere((e) => e.name == 'a.txt');
      expect(file.isDir, isFalse);
      expect(file.sizeBytes, greaterThan(0));
      // SFTP saniye veriyor; ms'ye çevrilmezse tarih 1970 civarı çıkar.
      expect(file.modifiedMs, greaterThan(1600000000000));

      final tmp = await Directory.systemTemp.createTemp('sftp_live');
      addTearDown(() => removeTempDir(tmp));
      final local = await fs.download(file, '${tmp.path}/inen.txt');
      expect(local.readAsStringSync().trim(), 'merhaba sftp');

      final up = File('${tmp.path}/yuklenecek.bin')
        ..writeAsBytesSync(List<int>.generate(300, (i) => i % 256));
      await fs.upload(up, '/home/nastest', name: 'yuklenen.bin');
      final after = await fs.list('/home/nastest');
      final uploaded = after.firstWhere((e) => e.name == 'yuklenen.bin');
      expect(uploaded.sizeBytes, 300);

      // İKİLİ içerik bozulmadan gitti mi?
      final back = await fs.download(uploaded, '${tmp.path}/geri.bin');
      expect(back.readAsBytesSync(), up.readAsBytesSync());

      await fs.rename(uploaded, 'yeniadi.bin');
      expect((await fs.list('/home/nastest')).map((e) => e.name),
          contains('yeniadi.bin'));

      final renamed = (await fs.list('/home/nastest'))
          .firstWhere((e) => e.name == 'yeniadi.bin');
      await fs.delete(renamed);
      expect((await fs.list('/home/nastest')).map((e) => e.name),
          isNot(contains('yeniadi.bin')));
    });

    test('yanlış parola auth hatası verir', () async {
      if (!await _up(2222)) return _skip('sshd :2222');
      final fs = SftpFs(connection.copyWith(password: 'yanlis'));
      await expectLater(
        fs.connect(),
        throwsA(isA<RemoteException>()
            .having((e) => e.error, 'error', RemoteError.auth)),
      );
    });

    test('ulaşılamayan port unreachable verir', () async {
      final fs = SftpFs(connection.copyWith(port: 2299));
      await expectLater(
        fs.connect(),
        throwsA(isA<RemoteException>()
            .having((e) => e.error, 'error', RemoteError.unreachable)),
      );
    });
  });

  group('FTP (gerçek sunucu)', () {
    const connection = RemoteConnection(
      id: 'live-ftp',
      name: 'live',
      protocol: RemoteProtocol.ftp,
      host: '127.0.0.1',
      port: 2121,
      user: 'nastest',
      password: 'nasgizli',
    );

    test('bağlan · listele · indir · yükle · klasör · sil', () async {
      if (!await _up(2121)) return _skip('ftpd :2121');
      final fs = FtpFs(connection);
      await fs.connect();
      addTearDown(fs.close);

      final entries = await fs.list('/');
      expect(entries.map((e) => e.name), containsAll(['a.txt', 'klasor']));
      expect(entries.firstWhere((e) => e.name == 'klasor').isDir, isTrue);

      final tmp = await Directory.systemTemp.createTemp('ftp_live');
      addTearDown(() => removeTempDir(tmp));

      // İkili aktarım: ASCII kipi kalsaydı bu bayt dizisi BOZULURDU.
      final bytes = List<int>.generate(400, (i) => (i * 7) % 256);
      final up = File('${tmp.path}/ikili.bin')..writeAsBytesSync(bytes);
      await fs.upload(up, '/', name: 'ikili.bin');

      final uploaded =
          (await fs.list('/')).firstWhere((e) => e.name == 'ikili.bin');
      final back = await fs.download(uploaded, '${tmp.path}/geri.bin');
      expect(back.readAsBytesSync(), bytes);

      await fs.makeDirectory('/yeniklasor');
      expect((await fs.list('/')).map((e) => e.name), contains('yeniklasor'));

      final folder =
          (await fs.list('/')).firstWhere((e) => e.name == 'yeniklasor');
      await fs.delete(folder);
      await fs.delete(uploaded);
      final after = (await fs.list('/')).map((e) => e.name);
      expect(after, isNot(contains('yeniklasor')));
      expect(after, isNot(contains('ikili.bin')));
    });

    test('alt klasöre inip dosya okur', () async {
      if (!await _up(2121)) return _skip('ftpd :2121');
      final fs = FtpFs(connection);
      await fs.connect();
      addTearDown(fs.close);
      final inner = await fs.list('/klasor');
      expect(inner.single.name, 'b.txt');

      final tmp = await Directory.systemTemp.createTemp('ftp_inner');
      addTearDown(() => removeTempDir(tmp));
      final local = await fs.download(inner.single, '${tmp.path}/b.txt');
      expect(local.readAsStringSync().trim(), 'ic');
    });

    test('yanlış parola auth hatası verir', () async {
      if (!await _up(2121)) return _skip('ftpd :2121');
      final fs = FtpFs(connection.copyWith(password: 'yanlis'));
      await expectLater(
        fs.connect(),
        throwsA(isA<RemoteException>()
            .having((e) => e.error, 'error', RemoteError.auth)),
      );
    });
  });

  group('WebDAV (gerçek sunucu)', () {
    const connection = RemoteConnection(
      id: 'live-dav',
      name: 'live',
      protocol: RemoteProtocol.webdav,
      host: 'http://127.0.0.1:8081',
      port: 8081,
    );

    test('bağlan · listele · indir · yükle · klasör · sil', () async {
      if (!await _up(8081)) return _skip('wsgidav :8081');
      final fs = WebDavFs(connection);
      await fs.connect();
      addTearDown(fs.close);

      final entries = await fs.list('/');
      expect(entries.map((e) => e.name), containsAll(['a.txt', 'klasor']));
      expect(entries.firstWhere((e) => e.name == 'klasor').isDir, isTrue);

      final tmp = await Directory.systemTemp.createTemp('dav_live');
      addTearDown(() => removeTempDir(tmp));
      final file = entries.firstWhere((e) => e.name == 'a.txt');
      final local = await fs.download(file, '${tmp.path}/inen.txt');
      expect(local.readAsStringSync().trim(), 'merhaba sftp');

      final bytes = List<int>.generate(256, (i) => 255 - i);
      final up = File('${tmp.path}/ikili.bin')..writeAsBytesSync(bytes);
      await fs.upload(up, '/', name: 'ikili.bin');
      final uploaded =
          (await fs.list('/')).firstWhere((e) => e.name == 'ikili.bin');
      final back = await fs.download(uploaded, '${tmp.path}/geri.bin');
      expect(back.readAsBytesSync(), bytes);

      await fs.makeDirectory('/yeniklasor');
      final withFolder = await fs.list('/');
      expect(withFolder.map((e) => e.name), contains('yeniklasor'));

      // Klasör silmede yol `/` ile bitmeli — bitmezse bazı sunucular 404 verir.
      await fs.delete(withFolder.firstWhere((e) => e.name == 'yeniklasor'));
      await fs.delete(uploaded);
      final after = (await fs.list('/')).map((e) => e.name);
      expect(after, isNot(contains('yeniklasor')));
      expect(after, isNot(contains('ikili.bin')));
    });

    test('yanlış adres unreachable verir', () async {
      final fs = WebDavFs(connection.copyWith(host: 'http://127.0.0.1:8099'));
      await expectLater(fs.connect(), throwsA(isA<RemoteException>()));
    });
  });

  group('SMB (gerçek sunucu)', () {
    const connection = RemoteConnection(
      id: 'live-smb',
      name: 'live',
      protocol: RemoteProtocol.smb,
      host: '127.0.0.1',
      port: 445,
      user: 'nastest',
      password: 'nasgizli',
      domain: 'WORKGROUP',
    );

    test('bağlan ve paylaşımları listele', () async {
      if (!await _smbUp(445)) return _skip('smb :445');
      final fs = SmbFs(connection);
      await fs.connect();
      addTearDown(fs.close);

      // Kök = paylaşım listesi (dosya listesi DEĞİL).
      final shares = await fs.list('/');
      expect(shares.map((e) => e.name), contains('paylasim'));
      // Yönetimsel paylaşımlar ($ ile biten) gizlenmeli.
      expect(shares.every((e) => !e.name.endsWith(r'$')), isTrue);
      expect(shares.every((e) => e.isDir), isTrue);
    });

    test('paylaşım içindeki dosyaları listeler ve indirir', () async {
      if (!await _smbUp(445)) return _skip('smb :445');
      final fs = SmbFs(connection);
      await fs.connect();
      addTearDown(fs.close);

      final entries = await fs.list('/paylasim');
      expect(entries.map((e) => e.name), contains('a.txt'));

      final tmp = await Directory.systemTemp.createTemp('smb_live');
      addTearDown(() => removeTempDir(tmp));
      final file = entries.firstWhere((e) => e.name == 'a.txt');
      final local = await fs.download(file, '${tmp.path}/inen.txt');
      expect(local.readAsStringSync().trim(), 'merhaba sftp');
    });

    test('yukle - klasor olustur - yeniden adlandir - sil', () async {
      if (!await _smbUp(445)) return _skip('smb :445');
      final fs = SmbFs(connection);
      await fs.connect();
      addTearDown(fs.close);

      final tmp = await Directory.systemTemp.createTemp('smb_write');
      addTearDown(() => removeTempDir(tmp));

      // Ikili icerik bozulmadan gidip geliyor mu?
      final bytes = List<int>.generate(333, (i) => (i * 13) % 256);
      final up = File('${tmp.path}/ikili.bin')..writeAsBytesSync(bytes);
      await fs.upload(up, '/paylasim', name: 'ikili.bin');

      final uploaded = (await fs.list('/paylasim'))
          .firstWhere((e) => e.name == 'ikili.bin');
      expect(uploaded.sizeBytes, 333);
      final back = await fs.download(uploaded, '${tmp.path}/geri.bin');
      expect(back.readAsBytesSync(), bytes);

      await fs.makeDirectory('/paylasim/yeniklasor');
      expect((await fs.list('/paylasim')).map((e) => e.name),
          contains('yeniklasor'));

      await fs.rename(uploaded, 'yeniadi.bin');
      final renamed = (await fs.list('/paylasim'))
          .firstWhere((e) => e.name == 'yeniadi.bin');

      await fs.delete(renamed);
      await fs.delete((await fs.list('/paylasim'))
          .firstWhere((e) => e.name == 'yeniklasor'));
      final after = (await fs.list('/paylasim')).map((e) => e.name);
      expect(after, isNot(contains('yeniadi.bin')));
      expect(after, isNot(contains('yeniklasor')));
    });
  });
}

/// Sunucu ayakta mı?
Future<bool> _up(int port, {String host = '127.0.0.1'}) async {
  Socket? socket;
  try {
    socket = await Socket.connect(host, port,
        timeout: const Duration(milliseconds: 600));
    return true;
  } catch (_) {
    return false;
  } finally {
    socket?.destroy();
  }
}

/// SMB'ye özel yoklama. Windows kendi SMB servisiyle 445'i HER ZAMAN dinler,
/// bu yüzden düz port yoklaması "bizim test sunucumuz" ile işletim sisteminkini
/// ayıramaz ve testler atlanacakları yerde gerçek Windows SMB'ye bağlanıp
/// patlar. Windows'ta açık onay iste; diğer platformlarda davranış aynı kalır.
Future<bool> _smbUp(int port, {String host = '127.0.0.1'}) async {
  if (Platform.isWindows && Platform.environment['LIVE_SMB'] != '1') {
    return false;
  }
  return _up(port, host: host);
}

void _skip(String what) => markTestSkipped(
    '$what çalışmıyor — canlı sunucu testi atlandı (bkz. dosya başındaki kurulum notu)');
