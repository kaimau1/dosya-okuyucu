import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Telefonu **FTP sunucusuna** çevirir: PC'den tarayıcı ya da herhangi bir FTP
/// istemcisiyle telefondaki dosyalara erişilir.
///
/// **Neden paket yok:** hazır bir Dart FTP *sunucusu* yok; olan paketler
/// istemci. `dart:io` `ServerSocket` ile yazmak ~1 dosya, yeni bağımlılık
/// getirmiyor ve davranışın tamamı bizde (kök hapsi, kimlik doğrulama,
/// pasif mod) — güvenlik açısından da doğrusu bu.
///
/// **Yalnız PASİF mod.** Aktif modda (PORT) sunucu istemciye geri bağlanır;
/// telefon ile PC arasında ev yönlendiricisi/NAT varken bu neredeyse hep
/// başarısız olur ve kullanıcı "listeleniyor ama dosya inmiyor" der. PASV/EPSV
/// yeterli: her modern istemci destekliyor.
///
/// **Varsayılan port 2121.** Android'de 1024'ün altındaki portlar root ister;
/// 21'e bağlanmaya çalışmak sessiz başarısızlık olurdu.
class FtpServer {
  /// Paylaşılacak kök klasör. Bunun DIŞINA çıkılamaz ([resolve]).
  final String rootDirectory;

  final String username;
  final String password;

  /// Boşsa kimlik doğrulama yok (anonim). Arayüz bunu açıkça uyarıyor.
  bool get anonymous => username.trim().isEmpty;

  /// Yazma (STOR/DELE/MKD/RMD/RNFR) açık mı. Varsayılan **kapalı**: PC'den
  /// telefona bakmak isteyen kullanıcı, yanlışlıkla silme riskini istemez.
  final bool allowWrite;

  /// Nokta ile başlayan dosya/klasörler listelensin mi. Varsayılan **kapalı**:
  /// `.thumbnails`, `.nomedia`, uygulama önbellek klasörleri PC'de klasörü
  /// çöplüğe çeviriyor ve kullanıcının aradığı şey değil (2026-08-29 —
  /// "Ağdan erişim" ekranındaki *Gizli dosyaları göster* kutusu bunu açar).
  final bool showHidden;

  final int port;

  /// İstemci sayısı değişince çağrılır (arayüzdeki "1 cihaz bağlı" satırı).
  void Function(int clients)? onClients;

  FtpServer({
    required this.rootDirectory,
    this.username = '',
    this.password = '',
    this.port = 2121,
    this.allowWrite = false,
    this.showHidden = false,
  });

  ServerSocket? _server;
  final _clients = <_FtpSession>[];

  bool get running => _server != null;

  /// O an bağlı istemci (kontrol bağlantısı) sayısı.
  int get clientCount => _clients.length;

  /// Gizli mi: nokta ile başlayan ad. Saf fonksiyon → birim testli.
  static bool isHidden(String name) => name.startsWith('.');

  /// **Rastgele parola.** "Ağdan erişim" ekranının varsayılanı: kullanıcı
  /// hiçbir şey yazmadan başlatabilsin, ama paylaşım da parolasız kalmasın
  /// (aynı Wi-Fi'daki herkes telefonun tüm dosyalarını görebilirdi).
  /// Altı hane yeter: parola tek oturum yaşıyor ve ağ yerel.
  static String randomPassword([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  /// Sunucunun gerçekten bağlandığı port (0 verilmişse işletim sistemi seçer).
  int get boundPort => _server?.port ?? port;

  /// Kullanıcıya gösterilecek adres(ler): `ftp://192.168.1.37:2121`.
  static Future<List<String>> addresses(int port) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return [
        for (final i in interfaces)
          for (final a in i.addresses) 'ftp://${a.address}:$port',
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> start() async {
    if (_server != null) return;
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(
      (socket) {
        final session = _FtpSession(this, socket);
        _clients.add(session);
        onClients?.call(_clients.length);
        session.done.whenComplete(() {
          _clients.remove(session);
          onClients?.call(_clients.length);
        });
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    for (final client in [..._clients]) {
      client.close();
    }
    _clients.clear();
    await server?.close();
  }

  /// İstemcinin verdiği yolu **kök içinde** gerçek bir yola çevirir.
  ///
  /// **Kök hapsi burada.** Bu kontrol olmasaydı FTP sunucusu telefonun TÜM
  /// dosya sistemini ağa açardı — sessiz ve çok ciddi bir açık.
  ///
  /// Kökün üstüne çıkmaya çalışan yol (`../../etc/passwd`) REDDEDİLMEZ,
  /// **köke sıkıştırılır** (`<kök>/etc/passwd`): FTP sunucularının standart
  /// davranışı bu ve istemciler kökte `CWD ..` göndermeyi normal sayıyor;
  /// hata döndürmek bazı istemcilerde gezinmeyi kilitliyor. Güvenlik sözü
  /// "reddet" değil, **"sonuç her zaman kökün içindedir"** — `test/
  /// ftp_server_test.dart` bunu ölçüyor.
  ///
  /// [cwd] istemcinin o anki sanal klasörü (kök `/`).
  String? resolve(String cwd, String requested) {
    final virtual = requested.startsWith('/')
        ? requested
        : p.posix.join(cwd.isEmpty ? '/' : cwd, requested);
    final normalized = p.posix.normalize(virtual);
    // normalize sonrası hâlâ `..` ile başlıyorsa kökün dışına çıkılmış demek.
    if (normalized.startsWith('..')) return null;
    final relative =
        normalized.startsWith('/') ? normalized.substring(1) : normalized;
    final real = p.normalize(p.join(rootDirectory, relative));
    // Son kontrol GERÇEK yol üzerinde: sembolik bağ/normalize kaçaklarına karşı.
    if (!p.equals(real, rootDirectory) && !p.isWithin(rootDirectory, real)) {
      return null;
    }
    // Güvenlik kontrolü normalize edilmiş yol üzerinde yapıldı; DÖNÜŞ ise
    // kök + '/' + sanal parça. p.normalize Windows'ta '\' basar — sözleşme
    // (test: yol çözümü) '/' bekler, File() iki ayırıcıyı da açar.
    return relative.isEmpty ? rootDirectory : '$rootDirectory/$relative';
  }

  /// Sanal yolu (`/` kökten) [resolve] için normalize eder.
  static String normalizeVirtual(String cwd, String requested) {
    final virtual = requested.startsWith('/')
        ? requested
        : p.posix.join(cwd.isEmpty ? '/' : cwd, requested);
    final normalized = p.posix.normalize(virtual);
    if (normalized == '.' || normalized.isEmpty) return '/';
    return normalized.startsWith('/') ? normalized : '/$normalized';
  }

  /// `LIST` çıktısının bir satırı — Unix `ls -l` biçimi. İstemcilerin
  /// neredeyse tamamı bunu ayrıştırıyor (MLSD'yi eski istemciler bilmiyor).
  static String listLine(String name, {
    required bool isDir,
    required int size,
    required DateTime modified,
  }) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final perms = isDir ? 'drwxr-xr-x' : '-rw-r--r--';
    final month = months[modified.month - 1];
    final day = modified.day.toString().padLeft(2);
    final time = '${modified.hour.toString().padLeft(2, '0')}:'
        '${modified.minute.toString().padLeft(2, '0')}';
    final sizeText = size.toString().padLeft(12);
    return '$perms 1 ftp ftp $sizeText $month $day $time $name';
  }

  /// `MLSD`/`MLST` satırı — makine okunur biçim (RFC 3659). Modern
  /// istemcilerin varsayılanı; `ls -l` ayrıştırmasındaki dil/tarih
  /// belirsizliklerini ortadan kaldırıyor.
  static String machineLine(String name, {
    required bool isDir,
    required int size,
    required DateTime modified,
  }) {
    final t = modified.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return 'type=${isDir ? 'dir' : 'file'};size=$size;modify=$stamp; $name';
  }

  /// `PASV` yanıtındaki adres alanı: `h1,h2,h3,h4,p1,p2`.
  static String pasvTuple(String ipv4, int port) =>
      '${ipv4.replaceAll('.', ',')},${port >> 8},${port & 0xFF}';
}

/// Tek bir istemci oturumu (kontrol bağlantısı).
class _FtpSession {
  final FtpServer server;
  final Socket socket;
  final _doneCompleter = Completer<void>();

  Future<void> get done => _doneCompleter.future;

  String _cwd = '/';
  bool _authed = false;
  String _pendingUser = '';
  String _renameFrom = '';

  /// `REST` ile bildirilen kaldığı yer (bir sonraki aktarımda kullanılır ve
  /// sıfırlanır). Kesilen bir indirmeyi baştan başlatmamak için: 4 GB'lık bir
  /// videoyu Wi-Fi koptu diye yeniden indirmek kabul edilemez.
  int _restart = 0;

  /// Pasif mod dinleyicisi — bir sonraki veri aktarımı burayı kullanır.
  ServerSocket? _pasv;

  _FtpSession(this.server, this.socket) {
    _authed = server.anonymous;
    _send('220 Dosya Okuyucu FTP');
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _onLine,
          onError: (_) => close(),
          onDone: close,
          cancelOnError: false,
        );
  }

  void _send(String line) {
    try {
      socket.write('$line\r\n');
    } catch (_) {}
  }

  void close() {
    if (_doneCompleter.isCompleted) return;
    _doneCompleter.complete();
    try {
      _pasv?.close();
    } catch (_) {}
    try {
      socket.destroy();
    } catch (_) {}
  }

  Future<void> _onLine(String line) async {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    final space = trimmed.indexOf(' ');
    final command =
        (space < 0 ? trimmed : trimmed.substring(0, space)).toUpperCase();
    final argument = space < 0 ? '' : trimmed.substring(space + 1).trim();

    // Kimlik doğrulanmadan YALNIZ bu komutlar kabul edilir.
    const preAuth = {'USER', 'PASS', 'QUIT', 'FEAT', 'SYST', 'NOOP', 'AUTH'};
    if (!_authed && !preAuth.contains(command)) {
      _send('530 Önce giriş yapın');
      return;
    }

    try {
      await _dispatch(command, argument);
    } catch (e) {
      _send('550 Hata: $e');
    }
  }

  Future<void> _dispatch(String command, String argument) async {
    switch (command) {
      case 'USER':
        _pendingUser = argument;
        if (server.anonymous) {
          _authed = true;
          _send('230 Giriş yapıldı');
        } else {
          _send('331 Parola gerekli');
        }
      case 'PASS':
        if (server.anonymous ||
            (_pendingUser == server.username && argument == server.password)) {
          _authed = true;
          _send('230 Giriş yapıldı');
        } else {
          // Kullanıcı adı mı parola mı yanlış SÖYLENMEZ (kaba kuvvet için ipucu).
          _send('530 Giriş başarısız');
        }
      case 'SYST':
        _send('215 UNIX Type: L8');
      case 'FEAT':
        _send('211-Features:');
        _send(' UTF8');
        _send(' SIZE');
        _send(' MDTM');
        _send(' EPSV');
        // Kaldığı yerden devam (RETR için): duyurulmazsa istemci kesilen
        // aktarımı baştan başlatır.
        _send(' REST STREAM');
        // MLSD duyurulmazsa modern istemciler LIST'e düşer; duyurulup
        // uygulanmazsa (ilk yazımdaki hata) istemci 502 alıp listelemeyi
        // tamamen bırakır — `ftpconnect` varsayılan olarak MLSD kullanıyor.
        _send(' MLST type*;size*;modify*;');
        _send('211 End');
      case 'OPTS':
        _send(argument.toUpperCase().startsWith('UTF8') ? '200 OK' : '200 OK');
      case 'NOOP':
        _send('200 OK');
      case 'TYPE':
        // İkili/ASCII ayrımı yapılmıyor: her şey ikili gönderiliyor. ASCII
        // kipi satır sonlarını çevirip resim/zip/pdf'i BOZAR.
        _send('200 Binary');
      case 'PWD' || 'XPWD':
        _send('257 "$_cwd"');
      case 'CWD':
        await _changeDirectory(argument);
      case 'CDUP':
        await _changeDirectory('..');
      case 'PASV':
        await _openPassive(extended: false);
      case 'EPSV':
        await _openPassive(extended: true);
      case 'LIST' || 'NLST' || 'MLSD':
        await _list(argument,
            format: switch (command) {
              'NLST' => _ListFormat.names,
              'MLSD' => _ListFormat.machine,
              _ => _ListFormat.unix,
            });
      case 'MLST':
        await _machineSingle(argument);
      case 'RETR':
        await _retrieve(argument);
      case 'SIZE':
        await _size(argument);
      case 'MDTM':
        await _modifiedTime(argument);
      case 'REST':
        final offset = int.tryParse(argument.trim());
        if (offset == null || offset < 0) {
          _send('501 Geçersiz konum');
        } else {
          _restart = offset;
          _send('350 $offset konumundan devam');
        }
      case 'STOR':
        await _store(argument);
      case 'APPE':
        await _store(argument, append: true);
      case 'ABOR':
        // Veri bağlantısını istemci zaten kapatıyor; bizim işimiz bekleyen
        // pasif dinleyiciyi bırakmak, yoksa 20 sn boyunca askıda kalırdı.
        try {
          await _pasv?.close();
        } catch (_) {}
        _pasv = null;
        _send('226 Durduruldu');
      case 'DELE':
        await _delete(argument, directory: false);
      case 'RMD' || 'XRMD':
        await _delete(argument, directory: true);
      case 'MKD' || 'XMKD':
        await _makeDirectory(argument);
      case 'RNFR':
        _renameFrom = argument;
        _send(server.resolve(_cwd, argument) == null
            ? '550 Yol yok'
            : '350 Yeni ad bekleniyor');
      case 'RNTO':
        await _renameTo(argument);
      case 'QUIT':
        _send('221 Hoşça kalın');
        close();
      default:
        _send('502 Desteklenmeyen komut');
    }
  }

  bool _requireWrite() {
    if (server.allowWrite) return true;
    _send('550 Yazma kapalı');
    return false;
  }

  Future<void> _changeDirectory(String argument) async {
    final virtual = FtpServer.normalizeVirtual(_cwd, argument);
    final real = server.resolve(_cwd, argument);
    if (real == null || !Directory(real).existsSync()) {
      _send('550 Klasör yok');
      return;
    }
    _cwd = virtual;
    _send('250 Klasör değişti');
  }

  /// Pasif dinleyici açar. Port 0 → işletim sistemi boş bir port seçer;
  /// sabit port seçmek ikinci eşzamanlı aktarımı kırardı.
  Future<void> _openPassive({required bool extended}) async {
    try {
      await _pasv?.close();
    } catch (_) {}
    _pasv = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = _pasv!.port;
    if (extended) {
      _send('229 Entering Extended Passive Mode (|||$port|)');
    } else {
      // Adres olarak KONTROL bağlantısının yerel adresi verilir: telefonun
      // birden çok arayüzü olabilir (Wi-Fi + hotspot) ve istemcinin ulaştığı
      // adres hangisiyse veri kanalı da o olmalı.
      final ip = socket.address.address;
      _send('227 Entering Passive Mode (${FtpServer.pasvTuple(ip, port)})');
    }
  }

  /// Pasif bağlantıyı bekler. İstemci bağlanmazsa askıda kalmamak için
  /// zaman aşımı var.
  Future<Socket?> _acceptData() async {
    final pasv = _pasv;
    if (pasv == null) {
      _send('425 Önce PASV kullanın');
      return null;
    }
    _pasv = null;
    try {
      final data = await pasv.first.timeout(const Duration(seconds: 20));
      return data;
    } catch (_) {
      _send('425 Veri bağlantısı kurulamadı');
      return null;
    } finally {
      try {
        await pasv.close();
      } catch (_) {}
    }
  }

  Future<void> _machineSingle(String argument) async {
    final real = server.resolve(_cwd, argument.isEmpty ? '.' : argument);
    if (real == null) {
      _send('550 Yol yok');
      return;
    }
    final isDir = Directory(real).existsSync();
    if (!isDir && !File(real).existsSync()) {
      _send('550 Yol yok');
      return;
    }
    final stat = FileStat.statSync(real);
    _send('250-Listing');
    _send(' ${FtpServer.machineLine(
      p.basename(real),
      isDir: isDir,
      size: isDir ? 0 : stat.size,
      modified: stat.modified,
    )}');
    _send('250 End');
  }

  Future<void> _list(String argument, {required _ListFormat format}) async {
    // Bazı istemciler `LIST -la` gönderir; seçenekler yol değildir.
    final cleaned = argument.startsWith('-') ? '' : argument;
    final real = server.resolve(_cwd, cleaned.isEmpty ? '.' : cleaned);
    if (real == null || !Directory(real).existsSync()) {
      _send('550 Klasör yok');
      return;
    }
    _send('150 Liste geliyor');
    final data = await _acceptData();
    if (data == null) return;
    try {
      final entries = Directory(real).listSync(followLinks: false);
      final buffer = StringBuffer();
      for (final entry in entries) {
        final name = p.basename(entry.path);
        if (!server.showHidden && FtpServer.isHidden(name)) continue;
        if (format == _ListFormat.names) {
          buffer.write('$name\r\n');
          continue;
        }
        FileStat stat;
        try {
          stat = entry.statSync();
        } catch (_) {
          continue;
        }
        final isDir = entry is Directory;
        final size = entry is File ? stat.size : 0;
        buffer.write(format == _ListFormat.machine
            ? FtpServer.machineLine(name,
                isDir: isDir, size: size, modified: stat.modified)
            : FtpServer.listLine(name,
                isDir: isDir, size: size, modified: stat.modified));
        buffer.write('\r\n');
      }
      data.add(utf8.encode(buffer.toString()));
      await data.flush();
      _send('226 Liste bitti');
    } catch (e) {
      _send('550 Liste alınamadı: $e');
    } finally {
      await data.close();
    }
  }

  Future<void> _retrieve(String argument) async {
    final real = server.resolve(_cwd, argument);
    // `REST` işaretçisi HER aktarımda tüketilir: bir sonraki indirmeye
    // sızarsa dosyanın başı eksik iner (sessiz bozulma).
    final from = _restart;
    _restart = 0;
    if (real == null || !File(real).existsSync()) {
      _send('550 Dosya yok');
      return;
    }
    if (from > File(real).lengthSync()) {
      _send('554 Konum dosyanın dışında');
      return;
    }
    _send('150 Dosya gönderiliyor');
    final data = await _acceptData();
    if (data == null) return;
    try {
      await data.addStream(File(real).openRead(from));
      await data.flush();
      _send('226 Aktarım bitti');
    } catch (e) {
      _send('426 Aktarım kesildi: $e');
    } finally {
      await data.close();
    }
  }

  Future<void> _store(String argument, {bool append = false}) async {
    final from = _restart;
    _restart = 0;
    if (!_requireWrite()) return;
    final real = server.resolve(_cwd, argument);
    if (real == null) {
      _send('550 Geçersiz yol');
      return;
    }
    final file = File(real);
    // **Yüklemede `REST` yalnız "dosyanın sonundan devam" için kabul edilir.**
    // Ortadan yazmak `RandomAccessFile` ister; yarım desteklemek, istemcinin
    // 350 alıp yanlış yere yazmasına ve dosyayı sessizce bozmasına yol açardı.
    var mode = append ? FileMode.writeOnlyAppend : FileMode.writeOnly;
    if (from > 0) {
      final size = file.existsSync() ? file.lengthSync() : 0;
      if (from != size) {
        _send('554 Yüklemede yalnız dosyanın sonundan devam edilebilir');
        return;
      }
      mode = FileMode.writeOnlyAppend;
    }
    _send('150 Dosya alınıyor');
    final data = await _acceptData();
    if (data == null) return;
    try {
      await file.parent.create(recursive: true);
      final sink = file.openWrite(mode: mode);
      await sink.addStream(data);
      await sink.close();
      _send('226 Aktarım bitti');
    } catch (e) {
      _send('426 Yazılamadı: $e');
    } finally {
      await data.close();
    }
  }

  Future<void> _size(String argument) async {
    final real = server.resolve(_cwd, argument);
    if (real == null || !File(real).existsSync()) {
      _send('550 Dosya yok');
      return;
    }
    _send('213 ${File(real).lengthSync()}');
  }

  Future<void> _modifiedTime(String argument) async {
    final real = server.resolve(_cwd, argument);
    if (real == null || !File(real).existsSync()) {
      _send('550 Dosya yok');
      return;
    }
    final t = File(real).lastModifiedSync().toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    _send('213 ${t.year}${two(t.month)}${two(t.day)}'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}');
  }

  Future<void> _delete(String argument, {required bool directory}) async {
    if (!_requireWrite()) return;
    final real = server.resolve(_cwd, argument);
    if (real == null) {
      _send('550 Geçersiz yol');
      return;
    }
    try {
      if (directory) {
        Directory(real).deleteSync();
      } else {
        File(real).deleteSync();
      }
      _send('250 Silindi');
    } catch (e) {
      _send('550 Silinemedi: $e');
    }
  }

  Future<void> _makeDirectory(String argument) async {
    if (!_requireWrite()) return;
    final real = server.resolve(_cwd, argument);
    if (real == null) {
      _send('550 Geçersiz yol');
      return;
    }
    try {
      Directory(real).createSync(recursive: true);
      _send('257 Klasör oluşturuldu');
    } catch (e) {
      _send('550 Oluşturulamadı: $e');
    }
  }

  Future<void> _renameTo(String argument) async {
    if (!_requireWrite()) return;
    final from = server.resolve(_cwd, _renameFrom);
    final to = server.resolve(_cwd, argument);
    if (from == null || to == null) {
      _send('550 Geçersiz yol');
      return;
    }
    try {
      if (Directory(from).existsSync()) {
        Directory(from).renameSync(to);
      } else {
        File(from).renameSync(to);
      }
      _send('250 Adı değişti');
    } catch (e) {
      _send('550 Değiştirilemedi: $e');
    }
  }
}

/// Liste komutlarının çıktı biçimi.
enum _ListFormat {
  /// `LIST` — Unix `ls -l` (eski istemciler).
  unix,

  /// `NLST` — yalnız adlar.
  names,

  /// `MLSD` — makine okunur (RFC 3659), modern istemcilerin varsayılanı.
  machine,
}
