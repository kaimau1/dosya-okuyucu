import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../file_ops.dart';
import '../fs_events.dart';

/// **İki Dosya Okuyucu arasında doğrudan dosya gönderme.**
///
/// ## Niye (kullanıcı isteği 2026-09-06)
/// *"paylaş dendiğinde iki dosya okuyucusu arasında hızlı dosya paylaşımı
/// özelliği yapalım"*
///
/// Bugün "Paylaş" sistemin paylaşım sayfasını açıyor: kullanıcı WhatsApp
/// (boyut sınırı + yeniden sıkıştırma), Bluetooth (yavaş) ya da e-posta
/// (25 MB) arasında seçim yapıyor. İki telefon aynı Wi-Fi'deyse bunların
/// hiçbirine gerek yok — dosya doğrudan, ağ hızında, kaybolmadan gidebilir.
///
/// ## Neden yeni bir paket YOK
/// `nearby_connections`, `wifi_direct` gibi paketler eklenebilirdi; hepsi
/// yeni Android izinleri (konum!), yeni bir sürüm duvarı ve CI'da yeni bir
/// derleme riski demek — bu depoda ikisi de pahalıya patlıyor (bkz. HAFIZA
/// "sürüm cehennemi"). Buradaki her şey `dart:io` ile:
/// * **Bulma:** UDP yayını (broadcast). Gönderen ağa "kim var?" diye
///   bağırır, alıcılar adlarıyla cevap verir. Yayın hem `255.255.255.255`e
///   hem alt ağın kendi yayın adresine (`192.168.1.255`) gidiyor: bazı
///   Android sürümleri/yönlendiriciler ilkini yutuyor, bazıları ikincisini.
/// * **Aktarım:** düz HTTP `POST`. Yerel ağda bir dosyayı bir soketten
///   akıtmaktan daha hızlı bir yol yok; uygulamanın zaten bir HTTP sunucusu
///   var (bkz. `http_share_server.dart`), bu onun küçük ve YAZILABİLİR
///   kardeşi.
///
/// ## Güvenlik — bilinçli sınırlar
/// * Alıcı sunucusu **yalnız "Al" ekranı açıkken** yaşar. Ekran kapanınca
///   soket kapanır; arka planda dinleyen bir kapı bırakılmıyor.
/// * Gelen her dosya **alıcının seçtiği klasöre** yazılır; yol istekten
///   ALINMAZ, yalnız dosya ADI alınır ve o da temizlenir
///   ([FileOps.sanitizeName]) — `../../` ile klasör dışına çıkmak imkânsız.
/// * Aynı adlı dosya EZİLMEZ: `rapor (1).pdf` olur.
/// * Aktarım yerel ağla sınırlı; şifreleme yok. Ekranda bu yazıyor —
///   halka açık Wi-Fi'de kullanmamak kullanıcının bilinçli kararı.
abstract final class PeerShare {
  /// "Kim var?" yayınının gittiği port. Alıcı burayı dinler.
  static const discoveryPort = 8769;

  /// Aktarımın HTTP portu (alıcı burada dinler).
  static const transferPort = 8770;

  /// Yayın paketinin başlığı — ağdaki başka bir uygulamanın datagramını
  /// yanlışlıkla cevaplamayalım.
  static const _magic = 'DOSYA-OKUYUCU-1';

  /// Cihazın yerel IPv4 adresleri (geri döngü ve `169.254.` hariç).
  static Future<List<InternetAddress>> localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return [
        for (final i in interfaces)
          for (final a in i.addresses)
            if (!a.address.startsWith('169.254.')) a,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// `192.168.1.37` → `192.168.1.255` (alt ağın yayın adresi).
  static String? broadcastFor(String ipv4) {
    final parts = ipv4.split('.');
    if (parts.length != 4) return null;
    if (parts.any((s) => int.tryParse(s) == null)) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }
}

/// Ağda bulunan bir Dosya Okuyucu.
class Peer {
  /// Kullanıcının cihazına verdiği ad ("Fatih'in telefonu").
  final String name;

  final String host;
  final int port;

  /// Alıcı eşleştirme kodu istiyor mu? (Kodun KENDİSİ yayınlanmaz.)
  final bool needsCode;

  const Peer({
    required this.name,
    required this.host,
    required this.port,
    this.needsCode = false,
  });

  /// Liste tekilleştirme anahtarı: aynı cihaz iki arayüzden (Wi-Fi + hotspot)
  /// cevap verebilir.
  String get key => '$host:$port';

  Uri get base => Uri.parse('http://$host:$port');

  @override
  bool operator ==(Object other) => other is Peer && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// **Alıcı taraf**: "kim var?" sorularına cevap verir ve gelen dosyaları
/// diske yazar.
///
/// Tek örnek değil — ekran kendi örneğini kurar ve `dispose`ta durdurur;
/// böylece "ekran kapandı ama sunucu ayakta kaldı" durumu yapısal olarak
/// imkânsız.
class PeerReceiver {
  /// Ekranda ve gönderenin listesinde görünecek ad.
  final String deviceName;

  /// Gelen dosyaların yazılacağı klasör.
  final String saveDir;

  /// **Eşleştirme kodu** — boşsa kod istenmez.
  ///
  /// Niye eklendi (2026-09-06 denetim turu): alıcı ekranı açıkken aynı ağdaki
  /// HERKES dosya gönderebiliyordu. Ev ağında sorun değil ama yurtta, ofiste
  /// ya da bir kafede bu, telefonun İndirilenler klasörünü herkese açmak
  /// demek. Kod dört hane: kısa çünkü karşı tarafa okunacak, ve ağdaki
  /// birinin denemesini pratik olmaktan çıkarmaya yetiyor (yanlış kod
  /// gönderilen dosyayı ALMADAN reddediyor).
  final String pairingCode;

  /// Bir dosya tamamlandığında çağrılır (yol, gönderen adı).
  final void Function(String path, String from)? onReceived;

  /// Aktarım sürerken ilerleme (dosya adı, alınan bayt, toplam bayt).
  final void Function(String name, int received, int total)? onProgress;

  PeerReceiver({
    required this.deviceName,
    required this.saveDir,
    this.pairingCode = '',
    this.onReceived,
    this.onProgress,
  });

  /// Rastgele dört haneli kod. `Random.secure` DEĞİL: bu bir sır değil,
  /// ekranda yazan ve karşı tarafa okunan bir eşleştirme numarası.
  static String newCode() =>
      (1000 + Random().nextInt(9000)).toString();

  HttpServer? _http;
  RawDatagramSocket? _udp;

  bool get running => _http != null;

  int get port => _http?.port ?? PeerShare.transferPort;

  Future<void> start() async {
    if (_http != null) return;
    // Port MEŞGUL olabilir (aynı telefonda ikinci bir örnek, ya da kapanmış
    // bir sunucunun soketi hâlâ TIME_WAIT'te): sabit port tutmazsa işletim
    // sisteminin verdiği porta düşülür. Gönderen portu yayın cevabından
    // öğrendiği için sabit olması şart değil.
    HttpServer server;
    try {
      server = await HttpServer.bind(
          InternetAddress.anyIPv4, PeerShare.transferPort,
          shared: false);
    } catch (_) {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _http = server;
    server.listen(
      (request) => unawaited(_handle(request)),
      onError: (_) {},
      cancelOnError: false,
    );
    await _startDiscovery();
  }

  Future<void> stop() async {
    _udp?.close();
    _udp = null;
    final server = _http;
    _http = null;
    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {}
    }
  }

  /// UDP dinleyicisi: "kim var?" yayınına adımızla ve portumuzla cevap verir.
  Future<void> _startDiscovery() async {
    try {
      final socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, PeerShare.discoveryPort,
          reuseAddress: true, reusePort: false);
      _udp = socket;
      socket.broadcastEnabled = true;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final packet = socket.receive();
        if (packet == null) return;
        String text;
        try {
          text = utf8.decode(packet.data);
        } catch (_) {
          return;
        }
        if (text != PeerShare._magic) return;
        // Cevap TEK ADRESE (soranın adresine) gider: ağa ikinci bir yayın
        // yapmanın anlamı yok.
        final reply = utf8.encode(jsonEncode({
          'magic': PeerShare._magic,
          'name': deviceName,
          'port': port,
          // Kod İSTENİYOR mu — kodun kendisi DEĞİL. Kodu yayınlamak onu
          // anlamsız kılardı; gönderen yalnız "kod sorulacak" bilgisini alıp
          // kullanıcıya kutuyu gösteriyor.
          'code': pairingCode.isNotEmpty,
        }));
        try {
          socket.send(reply, packet.address, packet.port);
        } catch (_) {}
      });
    } catch (_) {
      // Bulma çalışmasa da aktarım çalışır: gönderen IP'yi elle yazabilir.
      // (Bazı ROM'lar UDP yayınını kısıtlıyor — özelliğin tamamını buna
      // bağlamak yanlış olurdu.)
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      // Elle IP yazan gönderen için kimlik ucu.
      if (request.method == 'GET' && request.uri.path == '/kim') {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({
          'magic': PeerShare._magic,
          'name': deviceName,
          'port': port,
          'code': pairingCode.isNotEmpty,
        }));
        await response.close();
        return;
      }
      if (request.method != 'POST' || request.uri.path != '/al') {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      // **Kod denetimi gövdeyi OKUMADAN**: yanlış kodla gelen 2 GB'lık bir
      // dosyayı diske yazıp sonra silmek hem yer hem zaman kaybı olurdu.
      if (pairingCode.isNotEmpty &&
          request.uri.queryParameters['kod'] != pairingCode) {
        response.statusCode = HttpStatus.forbidden;
        response.write('kod');
        await response.close();
        return;
      }
      // **Ad istekten gelir, YOL gelmez.** `sanitizeName` ayırıcıları
      // temizliyor: `../../etc/passwd` diye bir ad `.._.._etc_passwd` olur ve
      // dosya yine seçilen klasöre yazılır.
      final rawName = request.uri.queryParameters['ad'] ?? 'dosya';
      final from = request.uri.queryParameters['kim'] ?? '?';
      final safeName = FileOps.sanitizeName(rawName);
      final total = request.contentLength;
      final target = FileOps.uniquePath(
          p.join(saveDir, safeName.isEmpty ? 'dosya' : safeName));

      final file = File(target);
      await file.parent.create(recursive: true);
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in request) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(safeName, received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      // Yarım kalan dosya BIRAKILMAZ: gönderen ortadan kaybolduysa
      // (Wi-Fi düştü) diskte bozuk bir dosya kalırdı ve kullanıcı bunu
      // gerçek sanardı.
      if (total > 0 && received < total) {
        try {
          await file.delete();
        } catch (_) {}
        response.statusCode = HttpStatus.badRequest;
        await response.close();
        return;
      }
      FsEvents.changed();
      onReceived?.call(target, from);
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({'ok': true, 'name': p.basename(target)}));
      await response.close();
    } catch (_) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {}
    }
  }
}

/// **Gönderen taraf**: ağdaki alıcıları bulur ve dosyaları gönderir.
abstract final class PeerSender {
  /// Ağa "kim var?" diye sorar; cevap verenleri akış olarak döner.
  ///
  /// Akış [timeout] sonunda kapanır. Sonuçlar **birikerek** gelir: kullanıcı
  /// ilk bulunan cihazı beklemeden görür (tarama bitene kadar boş ekrana
  /// bakmak "hiçbir şey yok" demek olurdu).
  static Stream<Peer> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async* {
    final controller = StreamController<Peer>();
    final seen = <String>{};
    RawDatagramSocket? socket;
    Timer? repeat;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final sock = socket;
      sock.listen((event) {
        if (event != RawSocketEvent.read) return;
        final packet = sock.receive();
        if (packet == null) return;
        Map<String, dynamic> data;
        try {
          data = jsonDecode(utf8.decode(packet.data)) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        if (data['magic'] != PeerShare._magic) return;
        final peer = Peer(
          name: '${data['name'] ?? '?'}',
          host: packet.address.address,
          port: (data['port'] as num?)?.toInt() ?? PeerShare.transferPort,
          needsCode: data['code'] == true,
        );
        if (seen.add(peer.key)) controller.add(peer);
      });

      Future<void> ask() async {
        final payload = utf8.encode(PeerShare._magic);
        final targets = <String>{'255.255.255.255'};
        for (final address in await PeerShare.localAddresses()) {
          final broadcast = PeerShare.broadcastFor(address.address);
          if (broadcast != null) targets.add(broadcast);
        }
        for (final target in targets) {
          try {
            sock.send(payload, InternetAddress(target), PeerShare.discoveryPort);
          } catch (_) {}
        }
      }

      // Soru üç kez sorulur: UDP güvenilir değil, tek paket yolda kaybolursa
      // cihaz "yok" görünürdü.
      unawaited(ask());
      repeat = Timer.periodic(
          const Duration(milliseconds: 900), (_) => unawaited(ask()));
      Timer(timeout, () => unawaited(controller.close()));
      yield* controller.stream;
    } finally {
      repeat?.cancel();
      socket?.close();
      unawaited(controller.close());
    }
  }

  /// Elle yazılan bir adresteki cihazı doğrular (yayın engelliyse tek yol).
  static Future<Peer?> probe(String host,
      {int port = PeerShare.transferPort}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final request =
          await client.getUrl(Uri.parse('http://$host:$port/kim'));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;
      final data = jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;
      if (data['magic'] != PeerShare._magic) return null;
      return Peer(
        name: '${data['name'] ?? host}',
        host: host,
        port: (data['port'] as num?)?.toInt() ?? port,
        needsCode: data['code'] == true,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Dosyaları [peer]'a gönderir.
  ///
  /// Klasör gönderilmez (tek dosya = tek istek); çağıran klasörleri önceden
  /// ayıklar ya da sıkıştırır. İlerleme **bayt** üzerinden bildirilir: dosya
  /// sayısı büyük bir videoda hiçbir şey anlatmıyor.
  static Future<PeerSendResult> send(
    Peer peer,
    List<String> paths, {
    required String senderName,
    String pairingCode = '',
    void Function(String name, int sentBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    var sent = 0;
    final errors = <String>[];
    var totalBytes = 0;
    for (final path in paths) {
      try {
        totalBytes += await File(path).length();
      } catch (_) {}
    }
    var sentBytes = 0;

    // Tek istemci: bağlantı havuzu sayesinde ikinci dosya el sıkışmayı
    // tekrar etmiyor (çok sayıda küçük dosyada fark büyük).
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 20);
    try {
      for (final path in paths) {
        if (isCancelled?.call() ?? false) {
          return PeerSendResult(
              sent: sent, errors: errors, cancelled: true);
        }
        final file = File(path);
        final name = p.basename(path);
        try {
          final length = await file.length();
          final uri = peer.base.replace(path: '/al', queryParameters: {
            'ad': name,
            'kim': senderName,
            if (pairingCode.isNotEmpty) 'kod': pairingCode,
          });
          final request = await client.postUrl(uri);
          request.contentLength = length;
          // Akış hâlinde gönderilir: 2 GB'lık bir video belleğe alınmaz.
          await for (final chunk in file.openRead()) {
            if (isCancelled?.call() ?? false) break;
            request.add(chunk);
            sentBytes += chunk.length;
            onProgress?.call(name, sentBytes, totalBytes);
          }
          final response = await request.close();
          await response.drain<void>();
          if (response.statusCode == HttpStatus.forbidden) {
            // Yanlış kod: kalan dosyaları denemenin anlamı yok, hepsi aynı
            // cevabı alacak. Hata metni de "HTTP 403" değil, kullanıcının
            // düzeltebileceği bir şey söylüyor.
            return PeerSendResult(
                sent: sent, errors: const [], wrongCode: true);
          }
          if (response.statusCode != HttpStatus.ok) {
            errors.add('$name: HTTP ${response.statusCode}');
          } else {
            sent++;
          }
        } catch (e) {
          errors.add('$name: $e');
        }
      }
    } finally {
      client.close(force: true);
    }
    return PeerSendResult(sent: sent, errors: errors, cancelled: false);
  }
}

/// Gönderme sonucu — kaç dosya gitti, hangileri gitmedi.
class PeerSendResult {
  final int sent;
  final List<String> errors;
  final bool cancelled;

  /// Alıcı kodu reddetti — kullanıcıya "HTTP 403" değil, kodu yeniden
  /// sormak gerekiyor.
  final bool wrongCode;

  const PeerSendResult({
    this.sent = 0,
    this.errors = const [],
    this.cancelled = false,
    this.wrongCode = false,
  });

  bool get hasError => errors.isNotEmpty;
}
