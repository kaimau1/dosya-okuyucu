import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/ftp_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;

/// FTP sunucusu bu ortamda **gerçekten koşturulabiliyor** (localhost soketi),
/// bu yüzden testler varsayımla değil ölçümle: sunucu başlatılıyor ve
/// `ftpconnect` istemcisiyle sürülüyor. Aynı test hem sunucuyu hem
/// istemci tarafındaki (`FtpFs`) paket kullanımını doğruluyor.
void main() {
  group('yol çözümü (kök hapsi)', () {
    late Directory root;
    late FtpServer server;

    setUp(() {
      root = Directory.systemTemp.createTempSync('ftp_root');
      server = FtpServer(rootDirectory: root.path);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('kök içindeki yollar çözülür', () {
      expect(server.resolve('/', 'a.txt'), '${root.path}/a.txt');
      expect(server.resolve('/alt', 'b.txt'), '${root.path}/alt/b.txt');
      expect(server.resolve('/alt', '/c.txt'), '${root.path}/c.txt');
    });

    test('KÖK DIŞINA çıkma denemeleri kökün İÇİNDE kalır', () {
      // Güvenlik sözü "reddet" değil **"sonuç her zaman kökün içinde"**:
      // FTP istemcileri kökte `CWD ..` göndermeyi normal sayıyor, hata
      // döndürmek gezinmeyi kilitliyor. Kaçış olmadığı ölçülüyor.
      for (final attempt in [
        '../../etc/passwd',
        '/../gizli',
        'a/../../../../b',
        '....//....//kaçak',
      ]) {
        final resolved = server.resolve('/alt', attempt);
        expect(resolved, isNotNull, reason: attempt);
        expect(
          resolved == root.path || p.isWithin(root.path, resolved!),
          isTrue,
          reason: '$attempt → $resolved kökün DIŞINA çıktı',
        );
      }
    });

    test('kökün kendisi geçerlidir', () {
      expect(server.resolve('/', '.'), root.path);
      expect(server.resolve('/', '/'), root.path);
    });

    test('sanal yol normalizasyonu kökte kalır', () {
      expect(FtpServer.normalizeVirtual('/', '..'), '/');
      expect(FtpServer.normalizeVirtual('/a/b', '..'), '/a');
      expect(FtpServer.normalizeVirtual('/a', 'b/c'), '/a/b/c');
      expect(FtpServer.normalizeVirtual('/a', '/x'), '/x');
    });
  });

  group('biçimlendirme', () {
    test('LIST satırı ls -l biçiminde', () {
      final line = FtpServer.listLine(
        'rapor.pdf',
        isDir: false,
        size: 1234,
        modified: DateTime(2026, 7, 30, 15, 4),
      );
      expect(line, startsWith('-rw-r--r--'));
      expect(line, contains('Jul 30 15:04'));
      expect(line, endsWith('rapor.pdf'));
      expect(line, contains('1234'));
    });

    test('klasör satırı d ile başlar', () {
      final line = FtpServer.listLine('klasor',
          isDir: true, size: 0, modified: DateTime(2026, 1, 5, 9, 7));
      expect(line, startsWith('drwxr-xr-x'));
      expect(line, contains('Jan  5 09:07'));
    });

    test('PASV adres alanı doğru kodlanır', () {
      // 2121 = 8*256 + 73
      expect(FtpServer.pasvTuple('192.168.1.37', 2121), '192,168,1,37,8,73');
      expect(FtpServer.pasvTuple('10.0.0.1', 21), '10,0,0,1,0,21');
    });
  });

  group('gerçek sunucu — ftpconnect istemcisiyle', () {
    late Directory root;
    late FtpServer server;

    setUp(() async {
      root = Directory.systemTemp.createTempSync('ftp_live');
      File('${root.path}/merhaba.txt').writeAsStringSync('merhaba dünya');
      Directory('${root.path}/klasor').createSync();
      File('${root.path}/klasor/ic.txt').writeAsStringSync('iç');
      // Port 0 → işletim sistemi boş port seçer (testler paralel koşabilsin).
      server = FtpServer(
        rootDirectory: root.path,
        username: 'kullanici',
        password: 'gizli',
        port: 0,
        allowWrite: true,
      );
      await server.start();
    });

    tearDown(() async {
      await server.stop();
      root.deleteSync(recursive: true);
    });

    FTPConnect client({String user = 'kullanici', String pass = 'gizli'}) =>
        FTPConnect('127.0.0.1',
            port: server.boundPort, user: user, pass: pass, timeout: 10);

    test('giriş + listeleme + indirme çalışıyor', () async {
      final ftp = client();
      expect(await ftp.connect(), isTrue);
      await ftp.setTransferType(TransferType.binary);

      final entries = await ftp.listDirectoryContent();
      final names = entries.map((e) => e.name).toSet();
      expect(names, containsAll(['merhaba.txt', 'klasor']));
      final folder = entries.firstWhere((e) => e.name == 'klasor');
      expect(folder.type, FTPEntryType.DIR);

      final target = File('${root.path}/inen.txt');
      expect(await ftp.downloadFile('merhaba.txt', target), isTrue);
      expect(target.readAsStringSync(), 'merhaba dünya');

      await ftp.disconnect();
    });

    test('YANLIŞ parola reddedilir', () async {
      final ftp = client(pass: 'yanlis');
      // connect() ya false döner ya da fırlatır; ikisi de "giriş yok".
      var ok = false;
      try {
        ok = await ftp.connect();
      } catch (_) {
        ok = false;
      }
      expect(ok, isFalse);
    });

    test('klasöre girip içindeki dosyayı indirir', () async {
      final ftp = client();
      expect(await ftp.connect(), isTrue);
      await ftp.setTransferType(TransferType.binary);
      expect(await ftp.changeDirectory('klasor'), isTrue);
      expect(await ftp.currentDirectory(), '/klasor');

      final target = File('${root.path}/ic_inen.txt');
      expect(await ftp.downloadFile('ic.txt', target), isTrue);
      expect(target.readAsStringSync(), 'iç');
      await ftp.disconnect();
    });

    test('yükleme ve silme (yazma AÇIKKEN)', () async {
      final ftp = client();
      expect(await ftp.connect(), isTrue);
      await ftp.setTransferType(TransferType.binary);

      final local = File('${root.path}/yuklenecek.txt')
        ..writeAsStringSync('yeni içerik');
      expect(
          await ftp.uploadFile(local, sRemoteName: 'uzak.txt'), isTrue);
      expect(File('${root.path}/uzak.txt').readAsStringSync(), 'yeni içerik');

      expect(await ftp.deleteFile('uzak.txt'), isTrue);
      expect(File('${root.path}/uzak.txt').existsSync(), isFalse);
      await ftp.disconnect();
    });

    test('İKİLİ içerik bozulmadan geçer', () async {
      // ASCII kipi satır sonlarını çevirip resim/zip/pdf'i bozardı; sunucu
      // her şeyi ikili gönderiyor.
      final bytes = List<int>.generate(512, (i) => i % 256);
      File('${root.path}/ikili.bin').writeAsBytesSync(bytes);

      final ftp = client();
      expect(await ftp.connect(), isTrue);
      await ftp.setTransferType(TransferType.binary);
      final target = File('${root.path}/ikili_inen.bin');
      expect(await ftp.downloadFile('ikili.bin', target), isTrue);
      expect(target.readAsBytesSync(), bytes);
      await ftp.disconnect();
    });
  });

  group('gerçek sunucu — ham komutlar', () {
    late Directory root;
    late FtpServer server;
    late Socket control;
    late Stream<String> lines;

    Future<String> readUntilCode() async {
      await for (final line in lines) {
        // Çok satırlı yanıtta (211-) son satır "kod boşluk" ile gelir.
        if (RegExp(r'^\d{3} ').hasMatch(line)) return line;
      }
      return '';
    }

    Future<String> send(String command) async {
      control.write('$command\r\n');
      await control.flush();
      return readUntilCode();
    }

    setUp(() async {
      root = Directory.systemTemp.createTempSync('ftp_raw');
      File('${root.path}/a.txt').writeAsStringSync('abc');
      server = FtpServer(
          rootDirectory: root.path,
          username: 'u',
          password: 'p',
          port: 0,
          allowWrite: false);
      await server.start();
      control = await Socket.connect('127.0.0.1', server.boundPort);
      lines = control
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      await readUntilCode(); // 220 karşılama
    });

    tearDown(() async {
      control.destroy();
      await server.stop();
      root.deleteSync(recursive: true);
    });

    test('giriş yapılmadan komut kabul edilmez', () async {
      expect(await send('PWD'), startsWith('530'));
    });

    test('kullanıcı adı/parola ayrımı sızdırılmaz', () async {
      // Yanlış kullanıcı ve yanlış parola AYNI yanıtı vermeli; fark kaba
      // kuvvet saldırısına ipucu olurdu.
      expect(await send('USER yanlis'), startsWith('331'));
      final wrongUser = await send('PASS p');
      control.destroy();

      control = await Socket.connect('127.0.0.1', server.boundPort);
      lines = control
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      await readUntilCode();
      expect(await send('USER u'), startsWith('331'));
      final wrongPass = await send('PASS yanlis');
      expect(wrongUser, wrongPass);
      expect(wrongPass, startsWith('530'));
    });

    test('yazma KAPALIYKEN STOR/DELE/MKD reddedilir', () async {
      await send('USER u');
      expect(await send('PASS p'), startsWith('230'));
      expect(await send('MKD yeni'), startsWith('550'));
      expect(await send('DELE a.txt'), startsWith('550'));
      // Reddedilen silme gerçekten dosyaya dokunmamalı.
      expect(File('${root.path}/a.txt').existsSync(), isTrue);
    });

    test('kök dışına CWD kullanıcıyı KÖKTE tutar', () async {
      await send('USER u');
      await send('PASS p');
      // Kabul edilir (istemciler bunu normal sayıyor) ama kökün üstüne
      // çıkılmaz: PWD hâlâ "/".
      await send('CWD ../..');
      expect(await send('PWD'), contains('"/"'));
      // Kökteki dosya hâlâ görünüyor → gerçekten kökteyiz.
      expect(await send('SIZE a.txt'), '213 3');
    });

    test('SIZE ve MDTM yanıtları', () async {
      await send('USER u');
      await send('PASS p');
      expect(await send('SIZE a.txt'), '213 3');
      expect(await send('MDTM a.txt'), matches(RegExp(r'^213 \d{14}$')));
    });

    test('EPSV genişletilmiş pasif mod yanıtı verir', () async {
      await send('USER u');
      await send('PASS p');
      expect(await send('EPSV'), matches(RegExp(r'^229 .*\(\|\|\|\d+\|\)$')));
    });

    test('FEAT çok satırlı yanıtı doğru kapanır', () async {
      expect(await send('FEAT'), startsWith('211 '));
    });

    test('MLST makine okunur tek satır verir', () async {
      await send('USER u');
      await send('PASS p');
      // 250- ile başlayan çok satırlı yanıt; son satır "250 End".
      control.write('MLST a.txt\r\n');
      await control.flush();
      final collected = <String>[];
      await for (final line in lines) {
        collected.add(line);
        if (line.startsWith('250 ')) break;
      }
      expect(collected.any((l) => l.contains('type=file')), isTrue);
      expect(collected.any((l) => l.contains('size=3')), isTrue);
    });
  });
}
