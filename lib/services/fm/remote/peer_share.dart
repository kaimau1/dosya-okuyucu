import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'dart:typed_data';

import 'package:crypto/crypto.dart' show md5;
import 'package:path/path.dart' as p;

import '../archive_ops.dart';
import '../file_ops.dart';
import '../fs_events.dart';
import 'zip_stream.dart';

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

  /// Yarım kalan (devam ettirilebilir) alımların ön eki — alıcı klasöründe
  /// gizli dosya olarak durur, tamamlanınca gerçek adına taşınır.
  static const partPrefix = '.dosya-aktarim-';

  /// Bu kurulumun kimliği ([PeerReceiver.deviceId]). Yakındakiler ekranı
  /// kendi yayınına verdiği cevabı bununla ayıklar; Wi-Fi ve Bluetooth'tan
  /// gelen aynı cihaz bununla birleşir.
  static String newDeviceId() {
    final r = Random.secure();
    return List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
  }

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

  /// Karşı kurulumun kimliği (eski sürümlerde boş).
  final String id;

  const Peer({
    required this.name,
    required this.host,
    required this.port,
    this.needsCode = false,
    this.id = '',
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
///
/// ## Kaldığı yerden devam (2026-10-29)
/// Gönderen her dosyaya bir aktarım kimliği (`tid`) verir. Gelen baytlar
/// önce klasördeki gizli `.dosya-aktarim-<tid>` dosyasına yazılır; bağlantı
/// koparsa bu dosya SİLİNMEZ. Gönderen yeniden bağlanınca `/durum` ile kaç
/// baytın geldiğini sorar ve oradan sürdürür. Dosya tamamlanınca gerçek adına
/// taşınır (kullanıcı hiçbir zaman yarım dosyayı "geldi" sanmaz). Bir günden
/// eski yarım dosyalar alıcı açılırken temizlenir.
///
/// ## Paket (2026-10-29)
/// `paket=1` ile gelen gövde tek akış ZIP'tir ([ZipStream]): çok sayıda küçük
/// dosya ya da bir klasör. Tamamlanınca klasöre AÇILIR — klasör klasör
/// olarak, dosyalar tek tek görünür; kullanıcı ZIP ile uğraşmaz.
class PeerReceiver {
  /// Ekranda ve gönderenin listesinde görünecek ad.
  final String deviceName;

  /// Gelen dosyaların yazılacağı klasör.
  final String saveDir;

  /// Bu kurulumun kimliği (yayın cevabında gider).
  final String deviceId;

  /// **Eşleştirme kodu** — boşsa kod istenmez.
  ///
  /// Niye eklendi (2026-09-06 denetim turu): alıcı ekranı açıkken aynı ağdaki
  /// HERKES dosya gönderebiliyordu. Kod dört hane; yanlış kod gönderilen
  /// dosyayı ALMADAN reddediyor. (2026-10-29: Yakındakiler ekranı kodu
  /// kullanmıyor, onay penceresi yeterli görüldü — protokol eski sürümlerle
  /// uyum için duruyor.)
  final String pairingCode;

  /// Bir dosya (ya da açılan paketin her üst öğesi) tamamlandığında
  /// çağrılır (yol, gönderen adı).
  final void Function(String path, String from)? onReceived;

  /// Aktarım sürerken ilerleme (dosya adı, alınan bayt, toplam bayt).
  final void Function(String name, int received, int total)? onProgress;

  /// **Gelen dosya onayı** (2026-10-28 kullanıcı isteği: *"dosya almada onay
  /// olmalı"*). Verilirse gönderim, alıcı "Kabul et" demeden diske YAZILMAZ.
  /// Gönderen önce `/sor` ile ne geleceğini (adlar, boyutlar, küçük
  /// önizlemeler) bildirir; kabul edilince bir izin anahtarı alır ve o turun
  /// bütün dosyaları onunla gelir. `null` = onaysız.
  final Future<bool> Function(PeerOffer offer)? onAsk;

  PeerReceiver({
    required this.deviceName,
    required this.saveDir,
    this.deviceId = '',
    this.pairingCode = '',
    this.onReceived,
    this.onProgress,
    this.onAsk,
  });

  /// Verilmiş izinler: anahtar → son geçerlilik.
  final _grants = <String, DateTime>{};

  /// Sorular sırayla sorulur (iki gönderen aynı anda gelirse üst üste iki
  /// pencere açılmasın).
  Future<void> _askChain = Future.value();

  Future<bool> _ask(PeerOffer offer) {
    final ask = onAsk;
    if (ask == null) return Future.value(true);
    final result = _askChain.then((_) => ask(offer)).timeout(
        const Duration(seconds: 90),
        onTimeout: () => false);
    _askChain = result.then((_) {}, onError: (_) {});
    return result.catchError((_) => false);
  }

  String _grant() {
    final r = Random.secure();
    final token =
        List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
    final now = DateTime.now();
    _grants.removeWhere((_, until) => until.isBefore(now));
    _grants[token] = now.add(const Duration(minutes: 30));
    return token;
  }

  bool _granted(String? token) {
    if (token == null) return false;
    final until = _grants[token];
    return until != null && until.isAfter(DateTime.now());
  }

  /// Rastgele dört haneli kod. `Random.secure` DEĞİL: bu bir sır değil,
  /// ekranda yazan ve karşı tarafa okunan bir eşleştirme numarası.
  static String newCode() =>
      (1000 + Random().nextInt(9000)).toString();

  HttpServer? _http;
  RawDatagramSocket? _udp;

  /// Aynı `tid`'e aynı anda iki yazma olmasın (gönderen yeniden denerken
  /// eski bağlantı henüz düşmemiş olabilir).
  final _busy = <String>{};

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
    unawaited(_sweepParts());
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

  /// Bir günden eski yarım alımları siler.
  Future<void> _sweepParts() async {
    try {
      final limit = DateTime.now().subtract(const Duration(days: 1));
      await for (final e in Directory(saveDir).list(followLinks: false)) {
        if (!p.basename(e.path).startsWith(PeerShare.partPrefix)) continue;
        if ((await e.stat()).modified.isBefore(limit)) {
          await e.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  Map<String, Object> _identity() => {
        'magic': PeerShare._magic,
        'name': deviceName,
        'port': port,
        'id': deviceId,
        // Kod İSTENİYOR mu — kodun kendisi DEĞİL.
        'code': pairingCode.isNotEmpty,
        // Bu sürüm devam ettirme + paket biliyor.
        'v': 2,
      };

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
        // Cevap TEK ADRESE (soranın adresine) gider.
        final reply = utf8.encode(jsonEncode(_identity()));
        try {
          socket.send(reply, packet.address, packet.port);
        } catch (_) {}
      });
    } catch (_) {
      // Bulma çalışmasa da aktarım çalışır: gönderen IP'yi elle yazabilir,
      // Bluetooth ile de bulunabilir.
    }
  }

  static String? _cleanTid(String? raw) {
    if (raw == null) return null;
    final t = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (t.isEmpty || t.length > 40) return null;
    return t;
  }

  File _partFile(String tid) =>
      File(p.join(saveDir, '${PeerShare.partPrefix}$tid'));

  Future<void> _json(HttpResponse response, Object body,
      {int status = HttpStatus.ok}) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _deny(HttpResponse response, String body) async {
    response.statusCode = HttpStatus.forbidden;
    response.write(body);
    await response.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final q = request.uri.queryParameters;
      // Elle IP yazan gönderen için kimlik ucu.
      if (request.method == 'GET' && request.uri.path == '/kim') {
        await _json(response, _identity());
        return;
      }
      final codeOk = pairingCode.isEmpty || q['kod'] == pairingCode;
      // **Ön soru** (onay): ne geleceği — eski sürüm sorgu, yeni sürüm
      // gövdede liste + küçük önizlemeler gönderir.
      if (request.method == 'POST' && request.uri.path == '/sor') {
        if (!codeOk) return _deny(response, 'kod');
        final items = <PeerOfferItem>[];
        try {
          final bytes = BytesBuilder(copy: false);
          await for (final chunk in request) {
            bytes.add(chunk);
            // Önizleme gövdesi küçük olmalı; şişkin gövde kesilir.
            if (bytes.length > 4 * 1024 * 1024) break;
          }
          if (bytes.isNotEmpty) {
            final data = jsonDecode(utf8.decode(bytes.takeBytes()));
            if (data is Map && data['items'] is List) {
              for (final raw in (data['items'] as List).take(200)) {
                final item = PeerOfferItem.fromJson(raw);
                if (item != null) items.add(item);
              }
            }
          }
        } catch (_) {
          // Liste okunamadı: sorgudaki özet yine gösterilir.
        }
        final ok = await _ask(PeerOffer(
          from: q['kim'] ?? '?',
          firstName: FileOps.sanitizeName(q['ad'] ?? ''),
          count: int.tryParse(q['adet'] ?? '') ?? 1,
          totalBytes: int.tryParse(q['toplam'] ?? '') ?? 0,
          items: items,
        ));
        if (!ok) return _deny(response, 'red');
        await _json(response, {'ok': true, 'izin': _grant()});
        return;
      }
      // **Devam sorusu**: bu aktarımdan kaç bayt elimde?
      if (request.method == 'GET' && request.uri.path == '/durum') {
        if (!codeOk) return _deny(response, 'kod');
        final tid = _cleanTid(q['tid']);
        var have = 0;
        if (tid != null) {
          final part = _partFile(tid);
          if (await part.exists()) have = await part.length();
        }
        await _json(response, {'have': have});
        return;
      }
      if (request.method != 'POST' || request.uri.path != '/al') {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      // **Kod denetimi gövdeyi OKUMADAN**.
      if (!codeOk) return _deny(response, 'kod');
      // **Ad istekten gelir, YOL gelmez.** `sanitizeName` ayırıcıları
      // temizliyor: `../../etc/passwd` diye bir ad `.._.._etc_passwd` olur.
      final rawName = q['ad'] ?? 'dosya';
      final from = q['kim'] ?? '?';
      final safeName = FileOps.sanitizeName(rawName);
      final bundle = q['paket'] == '1';
      final tid = _cleanTid(q['tid']);
      final offset = int.tryParse(q['ofs'] ?? '') ?? 0;
      final body = request.contentLength;
      final total = int.tryParse(q['boyut'] ?? '') ??
          (body >= 0 ? offset + body : -1);
      // Onay: izin anahtarı yoksa (ör. eski sürüm gönderen) dosya başına
      // sorulur — reddedilen gövde OKUNMADAN geri çevrilir.
      if (onAsk != null && !_granted(q['izin'])) {
        final ok = await _ask(PeerOffer(
            from: from, firstName: safeName, count: 1, totalBytes: total));
        if (!ok) return _deny(response, 'red');
      }

      if (tid == null) {
        await _receiveLegacy(request, safeName, from, total);
        return;
      }
      if (!_busy.add(tid)) {
        await _json(response, {'have': -1}, status: HttpStatus.conflict);
        return;
      }
      try {
        final part = _partFile(tid);
        await part.parent.create(recursive: true);
        final have = await part.exists() ? await part.length() : 0;
        if (offset != have && offset != 0) {
          // Gönderen yanlış yerden başlıyor: doğru yeri söyle, gövdeyi alma.
          await _json(response, {'have': have}, status: HttpStatus.conflict);
          return;
        }
        final sink = part.openWrite(
            mode: offset == 0 ? FileMode.writeOnly : FileMode.append);
        var received = offset;
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
        if (total > 0 && received < total) {
          // Yarım: dosya KALIR, gönderen sürdürecek.
          await _json(response, {'have': received},
              status: HttpStatus.badRequest);
          return;
        }
        final landed = bundle
            ? await _unpack(part, safeName)
            : [await _finalize(part, safeName)];
        FsEvents.changed();
        for (final path in landed) {
          onReceived?.call(path, from);
        }
        await _json(response, {
          'ok': true,
          'name': landed.isEmpty ? safeName : p.basename(landed.first),
        });
      } finally {
        _busy.remove(tid);
      }
    } catch (_) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {}
    }
  }

  /// Eski sürüm gönderen (`tid` yok): dosya doğrudan hedefe yazılır, yarım
  /// kalırsa silinir.
  Future<void> _receiveLegacy(
      HttpRequest request, String safeName, String from, int total) async {
    final response = request.response;
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
    await _json(response, {'ok': true, 'name': p.basename(target)});
  }

  Future<String> _finalize(File part, String safeName) async {
    final target = FileOps.uniquePath(
        p.join(saveDir, safeName.isEmpty ? 'dosya' : safeName));
    await part.rename(target);
    return target;
  }

  /// Paketi klasöre açar: üst düzeydeki her öğe (dosya ya da klasör)
  /// alıcı klasörüne taşınır, ad çakışırsa `(1)` eklenir.
  Future<List<String>> _unpack(File part, String safeName) async {
    final zip = File('${part.path}.zip');
    await part.rename(zip.path);
    final tmp = Directory('${part.path}-x');
    try {
      final root = await ArchiveOps.extract(zip.path, destDir: tmp.path);
      final out = <String>[];
      await for (final e in Directory(root).list(followLinks: false)) {
        final target = FileOps.uniquePath(p.join(saveDir, p.basename(e.path)));
        await e.rename(target);
        out.add(target);
      }
      return out;
    } finally {
      try {
        await zip.delete();
      } catch (_) {}
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  }
}

/// Gönderilecek tek parça: düz dosya ya da paket (ZIP akışı).
class _Sendable {
  final String name;
  final int size;
  final String path;
  final ZipStream? zip;

  /// Pakete giren dosya sayısı (düz dosyada 1).
  final int files;

  _Sendable.file(this.path, this.name, this.size)
      : zip = null,
        files = 1;

  _Sendable.bundle(this.zip, this.name, {required this.path})
      : size = zip!.length,
        files = zip.entries.length;

  Stream<List<int>> open(int start) =>
      zip?.open(start: start) ?? File(path).openRead(start);
}

/// **Gönderen taraf**: ağdaki alıcıları bulur ve dosyaları gönderir.
abstract final class PeerSender {
  /// Ağa "kim var?" diye sorar; cevap verenleri akış olarak döner.
  ///
  /// Akış [timeout] sonunda kapanır. Sonuçlar **birikerek** gelir.
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
          id: '${data['id'] ?? ''}',
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

      // Soru tekrar tekrar sorulur: UDP güvenilir değil.
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
        id: '${data['id'] ?? ''}',
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Paket eşiği: bu kadar ya da daha çok KÜÇÜK dosya tek akışta gider.
  static const bundleMinFiles = 4;

  /// "Küçük" dosya üst sınırı — büyük video ayrı gider (paketlemenin
  /// kazancı küçük dosyaların el sıkışmasında, büyük dosyada değil).
  static const bundleFileLimit = 8 * 1024 * 1024;

  /// Gönderilecekleri parçalara ayırır: her klasör bir paket, çok sayıda
  /// küçük dosya bir paket, gerisi tek tek.
  static Future<List<_Sendable>> _plan(List<String> paths) async {
    final out = <_Sendable>[];
    final small = <String>[];
    final plain = <String>[];
    for (final path in paths) {
      if (await Directory(path).exists()) {
        final zip = await ZipStream.of([path]);
        if (zip != null && zip.entries.isNotEmpty) {
          out.add(_Sendable.bundle(zip, '${p.basename(path)}.zip', path: path));
        }
        continue;
      }
      final len = await File(path).length();
      (len <= bundleFileLimit ? small : plain).add(path);
    }
    if (small.length >= bundleMinFiles) {
      final zip = await ZipStream.of(small);
      if (zip != null) {
        out.insert(0, _Sendable.bundle(zip, 'dosyalar.zip', path: small.first));
        small.clear();
      }
    }
    for (final path in [...small, ...plain]) {
      out.add(_Sendable.file(path, p.basename(path), await File(path).length()));
    }
    return out;
  }

  /// Aktarım kimliği: aynı gönderen + aynı içerik → aynı kimlik (yeniden
  /// denemede ve ekran kapatılıp yeniden gönderildiğinde de devam eder).
  static Future<String> _tid(String senderId, _Sendable s) async {
    final parts = <String>[senderId, s.name, '${s.size}'];
    final zip = s.zip;
    if (zip != null) {
      for (final e in zip.entries.take(64)) {
        parts.add('${e.name}|${e.size}|${e.modified.millisecondsSinceEpoch}');
      }
    } else {
      try {
        parts.add('${(await File(s.path).lastModified()).millisecondsSinceEpoch}');
      } catch (_) {}
    }
    return md5.convert(utf8.encode(parts.join('/'))).toString().substring(0, 24);
  }

  /// Dosyaları (ve klasörleri) [peer]'a gönderir.
  ///
  /// * Klasörler ve çok sayıda küçük dosya **tek akış paket** olarak gider,
  ///   alıcıda açılır ([ZipStream]).
  /// * Bağlantı koparsa [retryFor] boyunca yeniden bağlanmayı dener ve
  ///   **kaldığı bayttan** sürdürür; beklerken [onWaiting] `true` alır.
  /// * [thumbnail] verilirse ilk birkaç görsel/videonun küçük önizlemesi
  ///   onay penceresinde görünsün diye `/sor` ile gider.
  ///
  /// İlerleme **bayt** üzerinden bildirilir.
  static Future<PeerSendResult> send(
    Peer peer,
    List<String> paths, {
    required String senderName,
    String senderId = '',
    String pairingCode = '',
    void Function(String name, int sentBytes, int totalBytes)? onProgress,
    void Function(bool waiting)? onWaiting,
    bool Function()? isCancelled,
    Future<List<int>?> Function(String path)? thumbnail,
    Duration retryFor = const Duration(minutes: 2),
    Duration retryEvery = const Duration(seconds: 2),
  }) async {
    var sent = 0;
    final errors = <String>[];
    final plan = await _plan(paths);
    final totalBytes = plan.fold<int>(0, (a, s) => a + s.size);
    final fileCount = plan.fold<int>(0, (a, s) => a + s.files);
    var doneBytes = 0;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 20);
    try {
      // **Ön soru**: alıcı onay istiyorsa "Kabul et" diyene kadar bekler.
      // Gövdede ne geleceği (ad, boyut, küçük önizleme) gider.
      var grant = '';
      try {
        final ask = await client.postUrl(
            peer.base.replace(path: '/sor', queryParameters: {
          'kim': senderName,
          'ad': paths.isEmpty ? '' : p.basename(paths.first),
          'adet': '$fileCount',
          'toplam': '$totalBytes',
          if (pairingCode.isNotEmpty) 'kod': pairingCode,
        }));
        final body = utf8.encode(jsonEncode(
            {'items': await _offerItems(paths, thumbnail)}));
        ask.headers.contentType = ContentType.json;
        ask.contentLength = body.length;
        ask.add(body);
        final res = await ask.close().timeout(const Duration(seconds: 95));
        final reply = await res.transform(utf8.decoder).join();
        if (res.statusCode == HttpStatus.forbidden) {
          return reply.trim() == 'red'
              ? const PeerSendResult(declined: true)
              : const PeerSendResult(wrongCode: true);
        }
        if (res.statusCode == HttpStatus.ok) {
          final data = jsonDecode(reply);
          if (data is Map && data['izin'] is String) {
            grant = data['izin'] as String;
          }
        }
      } on TimeoutException {
        return const PeerSendResult(declined: true);
      } catch (_) {
        // Ön soru başarısız (eski alıcı / ağ): gönderim aşağıda denenir.
      }

      for (final item in plan) {
        if (isCancelled?.call() ?? false) {
          return PeerSendResult(sent: sent, errors: errors, cancelled: true);
        }
        final tid = await _tid(senderId.isEmpty ? senderName : senderId, item);
        final deadline = DateTime.now().add(retryFor);
        var waiting = false;
        var ok = false;
        String? error;
        while (true) {
          if (isCancelled?.call() ?? false) break;
          final outcome = await _sendOne(client, peer, item,
              tid: tid,
              senderName: senderName,
              pairingCode: pairingCode,
              grant: grant,
              isCancelled: isCancelled,
              onBytes: (n) {
                if (waiting) {
                  waiting = false;
                  onWaiting?.call(false);
                }
                onProgress?.call(item.name, doneBytes + n, totalBytes);
              });
          if (outcome == _Outcome.ok) {
            ok = true;
            break;
          }
          if (outcome == _Outcome.declined) {
            return PeerSendResult(sent: sent, errors: errors, declined: true);
          }
          if (outcome == _Outcome.wrongCode) {
            return PeerSendResult(sent: sent, wrongCode: true);
          }
          if (outcome == _Outcome.fatal ||
              DateTime.now().isAfter(deadline)) {
            error = '${item.name}: ${outcome.name}';
            break;
          }
          // Bağlantı koptu: bekle, yeniden dene — baytlar alıcıda duruyor.
          if (!waiting) {
            waiting = true;
            onWaiting?.call(true);
          }
          await Future<void>.delayed(retryEvery);
        }
        if (waiting) onWaiting?.call(false);
        if (ok) {
          sent += item.files;
          doneBytes += item.size;
        } else if (error != null) {
          errors.add(error);
        } else {
          return PeerSendResult(sent: sent, errors: errors, cancelled: true);
        }
      }
    } finally {
      client.close(force: true);
    }
    return PeerSendResult(sent: sent, errors: errors, cancelled: false);
  }

  static Future<_Outcome> _sendOne(
    HttpClient client,
    Peer peer,
    _Sendable item, {
    required String tid,
    required String senderName,
    required String pairingCode,
    required String grant,
    required void Function(int bytesOfItem) onBytes,
    bool Function()? isCancelled,
  }) async {
    try {
      // Kaç bayt zaten orada? Eski alıcı `/durum` bilmez (404) → baştan.
      var have = 0;
      try {
        final st = await (await client.getUrl(peer.base.replace(
                path: '/durum',
                queryParameters: {
                  'tid': tid,
                  if (pairingCode.isNotEmpty) 'kod': pairingCode,
                })))
            .close()
            .timeout(const Duration(seconds: 10));
        final body = await st.transform(utf8.decoder).join();
        if (st.statusCode == HttpStatus.ok) {
          final data = jsonDecode(body);
          if (data is Map) have = (data['have'] as num?)?.toInt() ?? 0;
        }
      } on SocketException {
        return _Outcome.network;
      } on TimeoutException {
        return _Outcome.network;
      } on HttpException {
        return _Outcome.network;
      } catch (_) {}
      if (have > item.size) have = 0;
      onBytes(have);
      final request = await client.postUrl(
          peer.base.replace(path: '/al', queryParameters: {
        'ad': item.name,
        'kim': senderName,
        'tid': tid,
        'ofs': '$have',
        'boyut': '${item.size}',
        if (item.zip != null) 'paket': '1',
        if (pairingCode.isNotEmpty) 'kod': pairingCode,
        if (grant.isNotEmpty) 'izin': grant,
      }));
      request.contentLength = item.size - have;
      var n = have;
      // Akış hâlinde gönderilir: 2 GB'lık bir video belleğe alınmaz.
      await for (final chunk in item.open(have)) {
        if (isCancelled?.call() ?? false) {
          request.abort();
          return _Outcome.cancelled;
        }
        request.add(chunk);
        n += chunk.length;
        onBytes(n);
      }
      final response = await request.close();
      final reply = await response.transform(utf8.decoder).join();
      switch (response.statusCode) {
        case HttpStatus.ok:
          return _Outcome.ok;
        case HttpStatus.forbidden:
          return reply.trim() == 'red' ? _Outcome.declined : _Outcome.wrongCode;
        case HttpStatus.conflict:
        case HttpStatus.badRequest:
          return _Outcome.network; // yeniden sor, doğru yerden sürdür
        default:
          return _Outcome.fatal;
      }
    } on SocketException {
      return _Outcome.network;
    } on HttpException {
      return _Outcome.network;
    } on TimeoutException {
      return _Outcome.network;
    } catch (_) {
      return _Outcome.fatal;
    }
  }

  /// Onay penceresinin listesi: ad, boyut, (ilk 12 görsel/video için) küçük
  /// önizleme. Klasör tek satır görünür (içindeki dosya sayısıyla).
  static Future<List<Map<String, Object>>> _offerItems(List<String> paths,
      Future<List<int>?> Function(String path)? thumbnail) async {
    final out = <Map<String, Object>>[];
    var thumbs = 0;
    for (final path in paths.take(200)) {
      final isDir = await Directory(path).exists();
      var size = 0;
      var count = 0;
      if (isDir) {
        final zip = await ZipStream.of([path]);
        size = zip?.totalFileBytes ?? 0;
        count = zip?.entries.length ?? 0;
      } else {
        try {
          size = await File(path).length();
        } catch (_) {}
      }
      final item = <String, Object>{
        'n': p.basename(path),
        's': size,
        if (isDir) 'd': count,
      };
      if (!isDir && thumbnail != null && thumbs < 12) {
        try {
          final bytes = await thumbnail(path);
          if (bytes != null && bytes.length < 64 * 1024) {
            item['t'] = base64Encode(bytes);
            thumbs++;
          }
        } catch (_) {}
      }
      out.add(item);
    }
    return out;
  }
}

enum _Outcome { ok, declined, wrongCode, network, cancelled, fatal }

/// Gönderme sonucu — kaç dosya gitti, hangileri gitmedi.
class PeerSendResult {
  final int sent;
  final List<String> errors;
  final bool cancelled;

  /// Alıcı kodu reddetti.
  final bool wrongCode;

  /// Alıcı gelen dosyayı kabul etmedi (ya da yanıt vermedi).
  final bool declined;

  const PeerSendResult({
    this.sent = 0,
    this.errors = const [],
    this.cancelled = false,
    this.wrongCode = false,
    this.declined = false,
  });

  bool get hasError => errors.isNotEmpty;
}

/// Onay penceresindeki tek satır.
class PeerOfferItem {
  final String name;
  final int size;

  /// Klasörse içindeki dosya sayısı; düz dosyada null.
  final int? folderFiles;

  /// Küçük JPEG önizleme (görsel/video).
  final Uint8List? thumb;

  const PeerOfferItem({
    required this.name,
    required this.size,
    this.folderFiles,
    this.thumb,
  });

  bool get isFolder => folderFiles != null;

  static PeerOfferItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = FileOps.sanitizeName('${raw['n'] ?? ''}');
    if (name.isEmpty) return null;
    Uint8List? thumb;
    if (raw['t'] is String) {
      try {
        thumb = base64Decode(raw['t'] as String);
      } catch (_) {}
    }
    return PeerOfferItem(
      name: name,
      size: (raw['s'] as num?)?.toInt() ?? 0,
      folderFiles: (raw['d'] as num?)?.toInt(),
      thumb: thumb,
    );
  }
}

/// Alıcıya sorulan teklif: kim, kaç dosya, toplam ne kadar, neler.
class PeerOffer {
  final String from;
  final String firstName;
  final int count;
  final int totalBytes;

  /// Ayrıntılı liste (yeni sürüm gönderen); eski sürümde boş.
  final List<PeerOfferItem> items;

  const PeerOffer({
    required this.from,
    required this.firstName,
    required this.count,
    required this.totalBytes,
    this.items = const [],
  });
}
