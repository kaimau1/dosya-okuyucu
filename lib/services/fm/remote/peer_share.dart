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
import '../../offline_mode.dart';
import 'lan_guard.dart';
import 'peer_crypto.dart';
import 'transfer_keeper.dart';
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
/// * Aktarım yerel ağla sınırlı. **2026-11-13 (G5):** iki uç da yeni sürümse
///   (yayında `v: 3`) X25519 el sıkışması + AES-256-GCM kayıtlarıyla şifreli
///   ([peer_crypto.dart]); eski sürüm eşle düz protokol sürer, ekranda
///   "şifresiz" rozeti çıkar.
abstract final class PeerShare {
  /// "Kim var?" yayınının gittiği port. Alıcı burayı dinler.
  static const discoveryPort = 8769;

  /// Aktarımın HTTP portu (alıcı burada dinler).
  static const transferPort = 8770;

  /// Ön soru (`/sor`) gövdesinin tavanı (G4.5): gönderen en çok 12 küçük
  /// resim (her biri < 64 KB, base64 ≈ 87 KB) + 200 satır yollar ≈ 1,1 MB.
  static const maxOfferBytes = 2 * 1024 * 1024;

  /// Yayın paketinin başlığı — ağdaki başka bir uygulamanın datagramını
  /// yanlışlıkla cevaplamayalım.
  static const _magic = 'DOSYA-OKUYUCU-1';

  /// Yarım kalan (devam ettirilebilir) alımların ön eki — alıcı klasöründe
  /// gizli dosya olarak durur, tamamlanınca gerçek adına taşınır.
  static const partPrefix = '.dosya-aktarim-';

  /// Şifreli protokol sürümü (G5). Yayın cevabında `v` bu ya da üstüyse
  /// gönderen `/el` ile el sıkışır.
  static const protocolVersion = 3;

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

  /// Protokol sürümü (yayın cevabındaki `v`; bilinmiyorsa 0).
  final int version;

  /// Duyurulan kalıcı anahtar parmak izi (`pk`; doğrulanmamış ipucu).
  final String fingerprint;

  const Peer({
    required this.name,
    required this.host,
    required this.port,
    this.needsCode = false,
    this.id = '',
    this.version = 0,
    this.fingerprint = '',
  });

  /// Şifreli protokolü (G5) biliyor mu?
  bool get secure => version >= PeerShare.protocolVersion;

  static Peer fromIdentity(Map data, String host, int port) => Peer(
        name: '${data['name'] ?? host}',
        host: host,
        port: (data['port'] as num?)?.toInt() ?? port,
        needsCode: data['code'] == true,
        id: '${data['id'] ?? ''}',
        version: (data['v'] as num?)?.toInt() ?? 0,
        fingerprint: '${data['pk'] ?? ''}',
      );

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
class PeerReceiver implements KeepableServer {
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

  /// Bir dosyanın alımı **bitti** (tamamlandı, yarım kaldı ya da koptu):
  /// ekran ilerleme satırını kaldırır. [onProgress] adıyla aynı ad gelir —
  /// `onReceived` yolu tutmaz (çakışmada `uniquePath` adı değiştirir, paket
  /// açılınca bir istekten çok yol çıkar).
  final void Function(String name)? onDone;

  /// **Gelen dosya onayı** (2026-10-28 kullanıcı isteği: *"dosya almada onay
  /// olmalı"*). Verilirse gönderim, alıcı "Kabul et" demeden diske YAZILMAZ.
  /// Gönderen önce `/sor` ile ne geleceğini (adlar, boyutlar, küçük
  /// önizlemeler) bildirir; kabul edilince bir izin anahtarı alır ve o turun
  /// bütün dosyaları onunla gelir. `null` = onaysız.
  final Future<bool> Function(PeerOffer offer)? onAsk;

  /// **Gelen yazı** (`/yazi`, 2026-11-03 kullanıcı isteği *"yazı gönderme"*).
  /// Diske yazılmaz, yalnız gösterilir (kopyalanabilir) — bu yüzden onay
  /// sorulmaz; gösterim kabulün kendisi. `null` = yazı alınmaz (404).
  final void Function(String text, String from)? onText;

  /// Kalıcı kimlik (G5). Verilirse alıcı şifreli protokolü (v3) duyurur ve
  /// `/el` el sıkışmasını kabul eder; yoksa yalnız eski düz protokol.
  final PeerIdentity? identity;

  PeerReceiver({
    this.identity,
    required this.deviceName,
    required this.saveDir,
    this.deviceId = '',
    this.pairingCode = '',
    this.onReceived,
    this.onProgress,
    this.onDone,
    this.onAsk,
    this.onText,
    this.onActivity,
  });

  /// Süren alım sayısı değişince ([TransferKeeper.onActivity]).
  final void Function(PeerReceiver receiver)? onActivity;

  @override
  int activeTransfers = 0;

  @override
  DateTime? lastActivity;

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

  /// Rastgele ALTI haneli kod. G4.4: `Random.secure` — kod ağdaki bir
  /// saldırganın tahmin etmemesi gereken tek engel; düz `Random`un tohumu
  /// tahmin edilebilir. 2026-11-13: 4 → 6 hane. Uyum sorunu yok: arayüz
  /// alıcıyı kodsuz (onay penceresi) kipte kurar, kod yalnız API'de; Windows
  /// "Dosya Aktar" kod göndermiyor (kod isteyen alıcıyı "desteklenmiyor" der).
  static String newCode() =>
      (100000 + Random.secure().nextInt(900000)).toString();

  /// G4.4: adres başına 5 yanlış kod → 60 sn red (900 bin olasılık / 5 deneme
  /// dakikada ≈ 2 ay).
  final _codeThrottle = AuthThrottle(limit: 5);

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
    LanGuard.harden(server);
    server.listen(
      (request) => unawaited(_gate.run(request, () => _tracked(request))),
      onError: (_) {},
      cancelOnError: false,
    );
    unawaited(_sweepParts());
    await _startDiscovery();
  }

  /// Ekran kapandı, süren alım bitiyor: yeni göndericiler artık bulamasın.
  void stopDiscovery() {
    _udp?.close();
    _udp = null;
  }

  @override
  Future<void> stop() async {
    stopDiscovery();
    final server = _http;
    _http = null;
    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {
        // Bilinçli: kapatma — zaten kapalıysa ya da kapanırken hata verirse yapılacak bir şey yok.
      }
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
    } catch (_) {
      // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
    }
  }

  Map<String, Object> _identity() => {
        'magic': PeerShare._magic,
        'name': deviceName,
        'port': port,
        'id': deviceId,
        // Kod İSTENİYOR mu — kodun kendisi DEĞİL.
        'code': pairingCode.isNotEmpty,
        // 2: devam ettirme + paket; 3: şifreli (G5) — `pk` kalıcı anahtarın
        // parmak izi (yalnız ipucu; asıl doğrulama el sıkışmada).
        'v': identity == null ? 2 : PeerShare.protocolVersion,
        if (identity != null) 'pk': identity!.fingerprint,
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
        // G4.1: mobil veri arayüzünden gelen yayına kimlik verilmez.
        if (!LanGuard.isPrivate(packet.address)) return;
        // Cevap TEK ADRESE (soranın adresine) gider.
        final reply = utf8.encode(jsonEncode(_identity()));
        try {
          socket.send(reply, packet.address, packet.port);
        } catch (_) {
          // Bilinçli: karşı taraf bağlantıyı kopardıysa yanıt gönderilemez; yapılacak bir şey yok.
        }
        // Ağ/güvenlik duvarı UDP göndermeyi reddederse (EPERM) hata akışa
        // düşer; yakalanmazsa "[async] SocketException" olarak tekrar eder.
      }, onError: (Object _) {}, cancelOnError: false);
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

  /// Kod denetimi (G4.4): sabit zamanlı; adres başına deneme sınırlı.
  /// Kodsuz kipte (onay penceresi) her zaman geçer.
  bool _checkCode(String ip, String? given) {
    if (pairingCode.isEmpty) return true;
    if (_codeThrottle.blocked(ip)) return false;
    if (given != null && LanGuard.safeEquals(given, pairingCode)) {
      _codeThrottle.success(ip);
      return true;
    }
    _codeThrottle.fail(ip);
    return false;
  }

  Future<void> _deny(HttpResponse response, String body) async {
    response.statusCode = HttpStatus.forbidden;
    response.write(body);
    await response.close();
  }

  /// G4.5: eşzamanlı istek sınırı.
  final _gate = RequestGate();

  Future<void> _tracked(HttpRequest request) async {
    // Gönderen (ör. Windows "Dosya Aktar") bağlantıyı sıfırlarsa yanıtın
    // `done`'u hata ile biter; dinleyen yoksa "[async] SocketException:
    // Connection reset by peer" hata kaydına düşer (2026-11-09 kullanıcı kaydı).
    request.response.done.ignore();
    // Kimlik yoklaması (`/kim`) aktarım DEĞİLDİR: çevredeki her cihazın
    // yoklaması sayaçları oynatıp ön plan servisini açıp kapatıyor, ekrandan
    // çıkınca da sunucuyu "meşgul" gösterip 60 sn açık tutuyordu.
    if (request.method == 'GET' && request.uri.path == '/kim') {
      await _handle(request);
      return;
    }
    activeTransfers++;
    lastActivity = DateTime.now();
    onActivity?.call(this);
    try {
      await _handle(request);
    } finally {
      activeTransfers--;
      lastActivity = DateTime.now();
      onActivity?.call(this);
    }
  }

  /// Şifreli oturumlar (`/el` el sıkışmasıyla açılır), oturum kimliğine göre.
  final _sessions = <String, _Session>{};

  /// `/el`: X25519 el sıkışması (G5). Gövde `{e, s, kim, kimlik}`, cevap
  /// `{e, s, o}` — `o` sonraki isteklerin oturum kimliği.
  Future<void> _handshake(HttpRequest request) async {
    final response = request.response;
    final me = identity;
    if (me == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in request) {
      bytes.add(chunk);
      if (bytes.length > 4096) return await _deny(response, 'buyuk');
    }
    final data = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (data is! Map) return await _deny(response, 'bicim');
    final e = base64Decode('${data['e']}');
    final st = base64Decode('${data['s']}');
    final eph = await PeerEphemeral.generate();
    final keys = await PeerHandshake.derive(
      me: me,
      ephemeral: eph,
      theirStatic: st,
      theirEphemeral: e,
      initiator: false,
      code: pairingCode,
    );
    final now = DateTime.now();
    _sessions.removeWhere((_, v) => v.expires.isBefore(now));
    if (_sessions.length >= 32) {
      _sessions.remove(_sessions.keys.first);
    }
    final sid = PeerShare.newDeviceId() + PeerShare.newDeviceId();
    _sessions[sid] = _Session(keys, now.add(const Duration(minutes: 30)));
    await _json(response, {
      'e': base64Encode(eph.publicKey),
      's': base64Encode(me.publicKey),
      'o': sid,
    });
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    // G4.1: yalnız yerel ağdan.
    if (!await LanGuard.admit(request)) return;
    try {
      final path = request.uri.path;
      final raw = request.uri.queryParameters;
      // Elle IP yazan gönderen için kimlik ucu.
      if (request.method == 'GET' && path == '/kim') {
        await _json(response, _identity());
        return;
      }
      if (request.method == 'POST' && path == '/el') {
        await _handshake(request);
        return;
      }
      final ip = request.connectionInfo?.remoteAddress.address ?? '';
      final _Ctx ctx;
      if (raw['o'] != null) {
        // **Şifreli istek** (G5): sorgu yalnız oturum + akış; asıl
        // parametreler ilk (başlık) kayıtta, gövde kalan kayıtlarda.
        final session = _sessions[raw['o']];
        final stream = int.tryParse(raw['k'] ?? '');
        if (session == null ||
            session.expires.isBefore(DateTime.now()) ||
            stream == null) {
          response.statusCode = HttpStatus.unauthorized;
          response.write('oturum');
          await response.close();
          return;
        }
        if (_codeThrottle.blocked(ip)) return await _deny(response, 'kod');
        if (!session.streams.add(stream)) return await _deny(response, 'akis');
        session.expires = DateTime.now().add(const Duration(minutes: 30));
        final reader = RecordReader(request);
        final opener = ChunkOpener(session.keys.recv, stream, aad: utf8.encode(path));
        Map<String, String> params;
        try {
          final head = await opener.next(reader);
          final decoded = jsonDecode(utf8.decode(head.payload));
          params = {
            if (decoded is Map)
              for (final e in decoded.entries) '${e.key}': '${e.value}',
          };
        } on AeadFailure {
          // Kod uyuşmazsa anahtar tutmaz, ilk kayıt açılmaz → bağlantı kesilir.
          _codeThrottle.fail(ip);
          return await _deny(response, 'kod');
        }
        _codeThrottle.success(ip);
        ctx = _Ctx(
          response,
          path,
          params,
          opener.done ? const Stream.empty() : opener.rest(reader),
          -1,
          session,
          stream,
        );
      } else {
        ctx = _Ctx(response, path, raw, request, request.contentLength, null, 0);
      }
      await _route(request.method, ctx, ip);
    } catch (_) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {
        // Bilinçli: kapatma — zaten kapalıysa ya da kapanırken hata verirse yapılacak bir şey yok.
      }
    }
  }

  Future<void> _route(String method, _Ctx ctx, String ip) async {
    final q = ctx.q;
    final path = ctx.path;
    final secure = ctx.session != null;
    final response = ctx.response;
    // `late`: kod yalnız ucun gerçekten istediği yerde denetlenir (bilinmeyen
    // yola gelen istek deneme sayılmasın). Şifreli istekte kod anahtarın
    // içinde: başlık açıldıysa kod doğrudur.
    late final codeOk = secure || _checkCode(ip, q['kod']);
    // **Ön soru** (onay): ne geleceği — eski sürüm sorgu, yeni sürüm
    // gövdede liste + küçük önizlemeler gönderir.
    if (method == 'POST' && path == '/sor') {
      if (!codeOk) return await _deny(response, 'kod');
      final items = <PeerOfferItem>[];
      try {
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in ctx.body) {
          bytes.add(chunk);
          // Önizleme gövdesi küçük olmalı; şişkin gövde kesilir (G4.5).
          if (bytes.length > PeerShare.maxOfferBytes) break;
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
      } on AeadFailure {
        return await _deny(response, 'kod');
      } catch (_) {
        // Liste okunamadı: sorgudaki özet yine gösterilir.
      }
      final ok = await _ask(PeerOffer(
        from: q['kim'] ?? '?',
        fromId: q['kimlik'] ?? '',
        firstName: FileOps.sanitizeName(q['ad'] ?? ''),
        count: int.tryParse(q['adet'] ?? '') ?? 1,
        totalBytes: int.tryParse(q['toplam'] ?? '') ?? 0,
        items: items,
        fingerprint: ctx.session?.keys.peerFingerprint ?? '',
        verifyCode: ctx.session?.keys.verifyCode ?? '',
      ));
      if (!ok) return await _deny(response, 'red');
      await ctx.json({'ok': true, 'izin': _grant()});
      return;
    }
    if (method == 'POST' && path == '/yazi' && onText != null) {
      if (!codeOk) return await _deny(response, 'kod');
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in ctx.body) {
        bytes.add(chunk);
        if (bytes.length > PeerSender.maxTextBytes) {
          return await _deny(response, 'buyuk');
        }
      }
      final text = utf8.decode(bytes.takeBytes(), allowMalformed: true);
      if (text.trim().isEmpty) return await _deny(response, 'bos');
      onText!(text, q['kim'] ?? '?');
      await ctx.json({'ok': true});
      return;
    }
    // **Devam sorusu**: bu aktarımdan kaç bayt elimde? Yalnız AYNI eşin
    // (şifrelide aynı anahtar parmak izinin) yarım dosyası sayılır.
    if ((method == 'GET' || secure) && path == '/durum') {
      if (!codeOk) return await _deny(response, 'kod');
      final tid = _cleanTid(q['tid']);
      var have = 0;
      if (tid != null) {
        final part = _partFile(tid);
        if (await part.exists() && await _owner(tid) == ctx.peerFp) {
          have = await part.length();
        }
      }
      await ctx.json({'have': have});
      return;
    }
    if (method != 'POST' || path != '/al') {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    // **Kod denetimi gövdeyi OKUMADAN**.
    if (!codeOk) return await _deny(response, 'kod');
    // **Ad istekten gelir, YOL gelmez.** `sanitizeName` ayırıcıları
    // temizliyor: `../../etc/passwd` diye bir ad `.._.._etc_passwd` olur.
    final rawName = q['ad'] ?? 'dosya';
    final from = q['kim'] ?? '?';
    final safeName = FileOps.sanitizeName(rawName);
    final bundle = q['paket'] == '1';
    final tid = _cleanTid(q['tid']);
    final offset = int.tryParse(q['ofs'] ?? '') ?? 0;
    final body = ctx.contentLength;
    final total = int.tryParse(q['boyut'] ?? '') ??
        (body >= 0 ? offset + body : -1);
    // Onay: izin anahtarı yoksa (ör. eski sürüm gönderen) dosya başına
    // sorulur — reddedilen gövde OKUNMADAN geri çevrilir.
    if (onAsk != null && !_granted(q['izin'])) {
      final ok = await _ask(PeerOffer(
          from: from,
          fromId: q['kimlik'] ?? '',
          firstName: safeName,
          count: 1,
          totalBytes: total,
          fingerprint: ctx.peerFp,
          verifyCode: ctx.session?.keys.verifyCode ?? ''));
      if (!ok) return await _deny(response, 'red');
    }

    if (tid == null) {
      if (secure) return await _deny(response, 'bicim');
      await _receiveLegacy(ctx.body, response, safeName, from, total);
      return;
    }
    if (!_busy.add(tid)) {
      await _json(response, {'have': -1}, status: HttpStatus.conflict);
      return;
    }
    try {
      final part = _partFile(tid);
      await part.parent.create(recursive: true);
      final mine = await _owner(tid) == ctx.peerFp;
      final have = await part.exists() && mine ? await part.length() : 0;
      if (offset != 0 && (offset != have || !mine)) {
        // Gönderen yanlış yerden başlıyor (ya da yarım dosya başka eşin):
        // doğru yeri söyle, gövdeyi alma.
        await _json(response, {'have': have}, status: HttpStatus.conflict);
        return;
      }
      if (offset == 0) await _setOwner(tid, ctx.peerFp);
      final sink = part.openWrite(
          mode: offset == 0 ? FileMode.writeOnly : FileMode.append);
      var received = offset;
      try {
        // `addStream` GERİ BASINÇ uygular (2026-11-12): eski `await for` +
        // `sink.add` diske yazılmayı beklemeden ağdan okuyordu; hızlı
        // gönderende (bilgisayar, kablolu ağ) yazılamayan baytlar bellekte
        // birikip büyük dosyada süreci öldürebiliyordu. Şifrelide yalnız
        // etiketi doğrulanmış kayıtlar diske iner (yarım dosya temiz kalır).
        try {
          await sink.addStream(ctx.body.map((chunk) {
            received += chunk.length;
            onProgress?.call(safeName, received, total);
            return chunk;
          }));
        } on AeadFailure catch (e) {
          // Bağlantı kayıt ortasında koptu: doğrulanmış kısım kalır, gönderen
          // sürdürür. Başka her şifre hatası (bozuk/sahte kayıt) iletilir.
          if (e.reason != 'kesik') rethrow;
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
      await _setOwner(tid, '');
      final landed = bundle
          ? await _unpack(part, safeName)
          : [await _finalize(part, safeName)];
      FsEvents.changed();
      for (final path in landed) {
        onReceived?.call(path, from);
      }
      await ctx.json({
        'ok': true,
        'name': landed.isEmpty ? safeName : p.basename(landed.first),
      });
    } finally {
      _busy.remove(tid);
      onDone?.call(safeName);
    }
  }

  File _ownerFile(String tid) => File('${_partFile(tid).path}.k');

  /// Yarım dosyanın sahibi: şifreli alımda gönderenin parmak izi, düzde boş.
  Future<String> _owner(String tid) async {
    try {
      final f = _ownerFile(tid);
      if (await f.exists()) return (await f.readAsString()).trim();
    } catch (_) {
      // Bilinçli: okunamayan sahip kaydı "bilinmeyen" sayılır → yarım dosya baştan alınır.
      return '?';
    }
    return '';
  }

  Future<void> _setOwner(String tid, String fp) async {
    final f = _ownerFile(tid);
    try {
      if (fp.isEmpty) {
        if (await f.exists()) await f.delete();
      } else {
        await f.writeAsString(fp, flush: true);
      }
    } catch (_) {
      // Bilinçli: sahip kaydı yazılamazsa devam sorusu baştan başlatır — güvenli yön.
    }
  }

  /// Eski sürüm gönderen (`tid` yok): dosya doğrudan hedefe yazılır, yarım
  /// kalırsa silinir.
  Future<void> _receiveLegacy(Stream<List<int>> request, HttpResponse response,
      String safeName, String from, int total) async {
    final target = FileOps.uniquePath(
        p.join(saveDir, safeName.isEmpty ? 'dosya' : safeName));
    final file = File(target);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var received = 0;
    try {
      await sink.addStream(request.map((chunk) {
        received += chunk.length;
        onProgress?.call(safeName, received, total);
        return chunk;
      }));
      await sink.flush();
    } finally {
      await sink.close();
      onDone?.call(safeName);
    }
    if (total > 0 && received < total) {
      try {
        await file.delete();
      } catch (_) {
        // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
      }
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
      } catch (_) {
        // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
      }
      try {
        await tmp.delete(recursive: true);
      } catch (_) {
        // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
      }
    }
  }
}

/// Alıcıda bir şifreli oturum.
class _Session {
  final PeerKeys keys;
  DateTime expires;

  /// Kullanılmış akış numaraları — aynı nonce ikinci kez kabul edilmez
  /// (yeniden oynatma).
  final streams = <int>{};

  _Session(this.keys, this.expires);
}

/// Bir isteğin taşımadan bağımsız görünümü: düzde sorgu + gövde, şifrelide
/// açılmış başlık + açılmış kayıtlar.
class _Ctx {
  final HttpResponse response;
  final String path;
  final Map<String, String> q;
  final Stream<List<int>> body;
  final int contentLength;
  final _Session? session;
  final int stream;

  _Ctx(this.response, this.path, this.q, this.body, this.contentLength,
      this.session, this.stream);

  String get peerFp => session?.keys.peerFingerprint ?? '';

  /// Başarılı (200) JSON cevap; şifrelide tek mühürlü kayıt.
  Future<void> json(Object value) async {
    final s = session;
    response.statusCode = HttpStatus.ok;
    final bytes = utf8.encode(jsonEncode(value));
    if (s == null) {
      response.headers.contentType = ContentType.json;
      response.add(bytes);
    } else {
      final rec = await ChunkSealer(s.keys.send, stream, aad: utf8.encode(path))
          .seal(bytes, last: true);
      response.headers.contentType = ContentType.binary;
      response.contentLength = rec.length;
      response.add(rec);
    }
    await response.close();
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
  /// Tek yazı gönderiminin üst sınırı (alıcı fazlasını reddeder).
  static const maxTextBytes = 1024 * 1024;

  /// [text]'i [peer]'a gönderir (alıcıda kopyalanabilir olarak görünür).
  /// Alıcı eski sürümse (uç yok) ya da ulaşılamazsa false. Alıcı şifreli
  /// protokolü biliyorsa ve [identity] verildiyse yazı şifreli gider.
  static Future<bool> sendText(Peer peer, String text,
      {required String senderName,
      String pairingCode = '',
      PeerIdentity? identity}) async {
    NetGuard.allow('peer', host: peer.host);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final link = _Link(client, peer, code: pairingCode, me: identity);
      if (peer.secure && identity != null) {
        await link.handshake(name: senderName, id: '');
      }
      final body = utf8.encode(text);
      final r = await link.call('/yazi', {'kim': senderName},
          body: Stream.value(body),
          length: body.length,
          type: ContentType.text,
          timeout: const Duration(seconds: 15));
      return r.status == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

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
        final peer = Peer.fromIdentity(
            data, packet.address.address, PeerShare.transferPort);
        if (seen.add(peer.key)) controller.add(peer);
      }, onError: (Object _) {}, cancelOnError: false);

      Future<void> ask() async {
        final payload = utf8.encode(PeerShare._magic);
        final targets = <String>{'255.255.255.255'};
        try {
          for (final address in await PeerShare.localAddresses()) {
            final broadcast = PeerShare.broadcastFor(address.address);
            if (broadcast != null) targets.add(broadcast);
          }
        } catch (_) {
          // Bilinçli: arayüz listesi alınamadı → yalnız genel yayın adresine sorulur.
        }
        for (final target in targets) {
          try {
            sock.send(payload, InternetAddress(target), PeerShare.discoveryPort);
          } catch (_) {
            // Bilinçli: karşı taraf bağlantıyı kopardıysa yanıt gönderilemez; yapılacak bir şey yok.
          }
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
    NetGuard.allow('peer', host: host);
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
      return Peer.fromIdentity(data, host, port);
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
      } catch (_) {
        // Bilinçli: dosya okunamadı — bilgi eksik kalır, iş sürer.
      }
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
  /// * **Şifreleme (G5):** alıcı v3 duyurduysa ve [identity] verildiyse
  ///   önce `/el` ile el sıkışılır, her şey şifreli gider; [onSecurity]
  ///   doğrulama sayısını alır. [requireFingerprint] verilirse (otomatik
  ///   eşitleme) yalnız o anahtarlı alıcıya ve yalnız şifreli gönderilir.
  ///
  /// İlerleme **bayt** üzerinden bildirilir: [onProgress] toplam, [onFile] o
  /// gönderim kalemi (dosya ya da paket) için — başlarken 0, bitince boyunun tamamı.
  static Future<PeerSendResult> send(
    Peer peer,
    List<String> paths, {
    required String senderName,
    String senderId = '',
    String pairingCode = '',
    PeerIdentity? identity,
    String? requireFingerprint,
    void Function(PeerSecurity security)? onSecurity,
    void Function(String name, int sentBytes, int totalBytes)? onProgress,
    void Function(bool waiting)? onWaiting,
    void Function(String name, int sentBytes, int sizeBytes)? onFile,
    bool Function()? isCancelled,
    Future<List<int>?> Function(String path)? thumbnail,
    Duration retryFor = const Duration(minutes: 2),
    Duration retryEvery = const Duration(seconds: 2),
  }) async {
    var sent = 0;
    final errors = <String>[];
    if (requireFingerprint != null && (!peer.secure || identity == null)) {
      return const PeerSendResult(identityMismatch: true);
    }
    final plan = await _plan(paths);
    final totalBytes = plan.fold<int>(0, (a, s) => a + s.size);
    final fileCount = plan.fold<int>(0, (a, s) => a + s.files);
    var doneBytes = 0;

    NetGuard.allow('peer', host: peer.host);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 20);
    final link = _Link(client, peer, code: pairingCode, me: identity);
    final senderKey = senderId.isEmpty ? senderName : senderId;
    try {
      if (peer.secure && identity != null) {
        try {
          await link.handshake(name: senderName, id: senderId);
        } catch (_) {
          // Şifreli protokolü duyuran alıcıyla düz protokole SESSİZCE
          // düşülmez (araya giren biri sürüm düşürmesin).
          return const PeerSendResult(errors: ['handshake']);
        }
      }
      final keys = link.keys;
      if (requireFingerprint != null &&
          keys?.peerFingerprint != requireFingerprint) {
        return const PeerSendResult(identityMismatch: true);
      }
      onSecurity?.call(PeerSecurity(
        encrypted: keys != null,
        verifyCode: keys?.verifyCode ?? '',
        fingerprint: keys?.peerFingerprint ?? '',
      ));
      // **Ön soru**: alıcı onay istiyorsa "Kabul et" diyene kadar bekler.
      // Gövdede ne geleceği (ad, boyut, küçük önizleme) gider.
      var grant = '';
      try {
        final body = utf8.encode(jsonEncode(
            {'items': await _offerItems(paths, thumbnail)}));
        final res = await link.call('/sor', {
          'kim': senderName,
          if (senderId.isNotEmpty) 'kimlik': senderId,
          'ad': paths.isEmpty ? '' : p.basename(paths.first),
          'adet': '$fileCount',
          'toplam': '$totalBytes',
        },
            body: Stream.value(body),
            length: body.length,
            type: ContentType.json,
            timeout: const Duration(seconds: 95));
        if (res.status == HttpStatus.forbidden) {
          return res.body.trim() == 'red'
              ? const PeerSendResult(declined: true)
              : const PeerSendResult(wrongCode: true);
        }
        if (res.status == HttpStatus.ok) {
          final data = jsonDecode(res.body);
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
        final tid = await _tid(senderKey, item);
        final deadline = DateTime.now().add(retryFor);
        var waiting = false;
        var ok = false;
        String? error;
        onFile?.call(item.name, 0, item.size);
        while (true) {
          if (isCancelled?.call() ?? false) break;
          final outcome = await _sendOne(link, item,
              tid: tid,
              senderName: senderName,
              senderId: senderId,
              grant: grant,
              isCancelled: isCancelled,
              onBytes: (n) {
                if (waiting) {
                  waiting = false;
                  onWaiting?.call(false);
                }
                onProgress?.call(item.name, doneBytes + n, totalBytes);
                onFile?.call(item.name, n, item.size);
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
          if (outcome == _Outcome.rekey) {
            // Alıcı oturumu unuttu (yeniden başladı): yeniden el sıkış —
            // AYNI kalıcı anahtarla; değiştiyse gönderim durur.
            final before = link.keys?.peerFingerprint;
            try {
              await link.handshake(name: senderName, id: senderId);
              if (link.keys?.peerFingerprint != before) {
                return PeerSendResult(
                    sent: sent, errors: errors, identityMismatch: true);
              }
              continue;
            } catch (_) {
              // Bilinçli: el sıkışma da olmadı → aşağıda ağ hatası gibi beklenir.
            }
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
          onFile?.call(item.name, item.size, item.size);
        } else if (error != null) {
          errors.add(error);
        } else {
          return PeerSendResult(sent: sent, errors: errors, cancelled: true);
        }
      }
    } finally {
      client.close(force: true);
    }
    return PeerSendResult(
        sent: sent,
        errors: errors,
        cancelled: false,
        encrypted: link.secure,
        peerFingerprint: link.keys?.peerFingerprint ?? '');
  }

  static Future<_Outcome> _sendOne(
    _Link link,
    _Sendable item, {
    required String tid,
    required String senderName,
    required String senderId,
    required String grant,
    required void Function(int bytesOfItem) onBytes,
    bool Function()? isCancelled,
  }) async {
    try {
      // Kaç bayt zaten orada? Eski alıcı `/durum` bilmez (404) → baştan.
      var have = 0;
      try {
        final st = await link.call('/durum', {'tid': tid},
            method: link.secure ? 'POST' : 'GET',
            timeout: const Duration(seconds: 10));
        if (st.status == HttpStatus.unauthorized) return _Outcome.rekey;
        if (st.status == HttpStatus.ok) {
          final data = jsonDecode(st.body);
          if (data is Map) have = (data['have'] as num?)?.toInt() ?? 0;
        }
      } on SocketException {
        return _Outcome.network;
      } on TimeoutException {
        return _Outcome.network;
      } on HttpException {
        return _Outcome.network;
      } on AeadFailure {
        return _Outcome.network;
      } catch (_) {
        // Bilinçli: bozuk yanıt → kaldığı yer bilinmiyor, baştan gönderilir (have = 0).
      }
      if (have > item.size || have < 0) have = 0;
      onBytes(have);
      // Akış hâlinde gönderilir: 2 GB'lık bir video belleğe alınmaz.
      final res = await link.call('/al', {
        'ad': item.name,
        'kim': senderName,
        if (senderId.isNotEmpty) 'kimlik': senderId,
        'tid': tid,
        'ofs': '$have',
        'boyut': '${item.size}',
        if (item.zip != null) 'paket': '1',
        if (grant.isNotEmpty) 'izin': grant,
      },
          body: item.open(have),
          length: item.size - have,
          isCancelled: isCancelled,
          onBytes: (n) => onBytes(have + n));
      switch (res.status) {
        case HttpStatus.ok:
          return _Outcome.ok;
        case HttpStatus.unauthorized:
          return _Outcome.rekey;
        case HttpStatus.forbidden:
          return res.body.trim() == 'red' ? _Outcome.declined : _Outcome.wrongCode;
        case HttpStatus.conflict:
        case HttpStatus.badRequest:
          return _Outcome.network; // yeniden sor, doğru yerden sürdür
        default:
          return _Outcome.fatal;
      }
    } on _Cancelled {
      return _Outcome.cancelled;
    } on SocketException {
      return _Outcome.network;
    } on HttpException {
      return _Outcome.network;
    } on TimeoutException {
      return _Outcome.network;
    } on AeadFailure {
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
        } catch (_) {
          // Bilinçli: dosya okunamadı — bilgi eksik kalır, iş sürer.
        }
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
        } catch (_) {
          // Bilinçli: küçük resim süs — üretilemezse öğe resimsiz listelenir.
        }
      }
      out.add(item);
    }
    return out;
  }
}

enum _Outcome { ok, declined, wrongCode, network, rekey, cancelled, fatal }

class _Cancelled implements Exception {
  const _Cancelled();
}

Stream<List<int>> _concat(List<int> head, Stream<List<int>>? rest) async* {
  yield head;
  if (rest != null) yield* rest;
}

/// Gönderenin bir alıcıyla bağı: düz (eski sürüm) ya da şifreli oturum (G5).
/// Uçlar ve anlamları ikisinde aynı; şifrelide sorgu yalnız `o` (oturum) +
/// `k` (akış), asıl parametreler başlık kaydında, gövde mühürlü kayıtlarda.
class _Link {
  final HttpClient client;
  final Peer peer;
  final String code;
  final PeerIdentity? me;
  PeerKeys? keys;
  String? _sid;
  int _stream = Random.secure().nextInt(1 << 30);

  _Link(this.client, this.peer, {this.code = '', this.me});

  bool get secure => keys != null;

  Future<void> handshake({required String name, required String id}) async {
    final mine = me!;
    final eph = await PeerEphemeral.generate();
    final req = await client.postUrl(peer.base.replace(path: '/el'));
    req.done.ignore();
    final body = utf8.encode(jsonEncode({
      'e': base64Encode(eph.publicKey),
      's': base64Encode(mine.publicKey),
      'kim': name,
      'kimlik': id,
    }));
    req.headers.contentType = ContentType.json;
    req.contentLength = body.length;
    req.add(body);
    final res = await req.close().timeout(const Duration(seconds: 15));
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode != HttpStatus.ok) {
      throw HttpException('el ${res.statusCode}');
    }
    final data = jsonDecode(text) as Map;
    keys = await PeerHandshake.derive(
      me: mine,
      ephemeral: eph,
      theirStatic: base64Decode('${data['s']}'),
      theirEphemeral: base64Decode('${data['e']}'),
      initiator: true,
      code: code,
    );
    _sid = '${data['o']}';
  }

  Future<({int status, String body})> call(
    String path,
    Map<String, String> params, {
    String method = 'POST',
    Stream<List<int>>? body,
    int length = 0,
    ContentType? type,
    Duration? timeout,
    bool Function()? isCancelled,
    void Function(int sent)? onBytes,
  }) async {
    final k = keys;
    final stream = _stream++ & 0xFFFFFFFF;
    final HttpClientRequest req;
    if (k == null) {
      final uri = peer.base.replace(path: path, queryParameters: {
        ...params,
        if (code.isNotEmpty) 'kod': code,
      });
      req = method == 'GET'
          ? await client.getUrl(uri)
          : await client.postUrl(uri);
    } else {
      req = await client.postUrl(peer.base
          .replace(path: path, queryParameters: {'o': _sid!, 'k': '$stream'}));
    }
    // İptalde `abort()` sonrası ya da alıcı bağlantıyı kesince `done` hata
    // ile biter; sonuç `close()`tan okunur.
    req.done.ignore();
    var sent = 0;
    Stream<List<int>> counted(Stream<List<int>> s) => s.map((c) {
          sent += c.length;
          onBytes?.call(sent);
          return c;
        });
    Stream<List<int>>? out;
    var outLength = 0;
    if (k == null) {
      if (body != null) {
        out = counted(body);
        outLength = length;
        if (type != null) req.headers.contentType = type;
      }
    } else {
      final sealer = ChunkSealer(k.send, stream, aad: utf8.encode(path));
      final hasBody = body != null && length > 0;
      final head =
          await sealer.seal(utf8.encode(jsonEncode(params)), last: !hasBody);
      outLength = head.length + (hasBody ? SealedChunks.sealedLength(length) : 0);
      out = _concat(head, hasBody ? sealer.sealStream(counted(body)) : null);
      req.headers.contentType = ContentType.binary;
    }
    if (out != null) {
      req.contentLength = outLength;
      await for (final chunk in out) {
        if (isCancelled?.call() ?? false) {
          req.abort();
          throw const _Cancelled();
        }
        req.add(chunk);
        // Geri basınç (2026-11-12): `flush` bayt sokete yazılana dek bekler
        // → bellek sabit, yüzde gerçek.
        await req.flush();
      }
    } else if (method != 'GET') {
      req.contentLength = 0;
    }
    final pending = req.close();
    final res = await (timeout == null ? pending : pending.timeout(timeout));
    if (k != null && res.statusCode == HttpStatus.ok) {
      final opener = ChunkOpener(k.recv, stream, aad: utf8.encode(path));
      final bytes = BytesBuilder(copy: false);
      await for (final c in opener.openStream(res)) {
        bytes.add(c);
      }
      return (status: HttpStatus.ok, body: utf8.decode(bytes.takeBytes()));
    }
    return (
      status: res.statusCode,
      body: await res.transform(utf8.decoder).join()
    );
  }
}

/// Gönderimin güvenlik durumu (ekranda rozet + doğrulama sayısı).
class PeerSecurity {
  final bool encrypted;
  final String verifyCode;
  final String fingerprint;
  const PeerSecurity(
      {required this.encrypted, this.verifyCode = '', this.fingerprint = ''});
}

/// Gönderme sonucu — kaç dosya gitti, hangileri gitmedi.
class PeerSendResult {
  final int sent;
  final List<String> errors;
  final bool cancelled;

  /// Alıcı kodu reddetti.
  final bool wrongCode;

  /// Alıcı gelen dosyayı kabul etmedi (ya da yanıt vermedi).
  final bool declined;

  /// Beklenen anahtar parmak izi tutmadı ya da alıcı şifresiz (eşitleme).
  final bool identityMismatch;

  /// Aktarım şifreli gitti mi; gittiyse alıcının parmak izi.
  final bool encrypted;
  final String peerFingerprint;

  const PeerSendResult({
    this.sent = 0,
    this.errors = const [],
    this.cancelled = false,
    this.wrongCode = false,
    this.declined = false,
    this.identityMismatch = false,
    this.encrypted = false,
    this.peerFingerprint = '',
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
      } catch (_) {
        // Bilinçli: bozuk/eksik veri — varsayılan değer kalır.
      }
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

  /// Gönderenin kurulum kimliği (`kimlik`; eski sürüm / bilgisayar: boş) —
  /// güvenilen cihaz eşleşmesi için.
  final String fromId;
  final String firstName;
  final int count;
  final int totalBytes;

  /// Ayrıntılı liste (yeni sürüm gönderen); eski sürümde boş.
  final List<PeerOfferItem> items;

  /// Şifreli oturumda gönderenin kalıcı anahtar parmak izi; düzde boş.
  final String fingerprint;

  /// Şifreli oturumda iki ekranda aynı görünmesi gereken 6 haneli sayı.
  final String verifyCode;

  const PeerOffer({
    required this.from,
    this.fromId = '',
    required this.firstName,
    required this.count,
    required this.totalBytes,
    this.items = const [],
    this.fingerprint = '',
    this.verifyCode = '',
  });

  /// Aktarım şifreli mi (G5)?
  bool get encrypted => fingerprint.isNotEmpty;
}
