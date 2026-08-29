import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../models/fs_entry.dart';
import '../fs_scan.dart';
import '../mime_types.dart';
import 'ftp_server.dart';
import 'ftp_tree.dart';

/// **Tarayıcıdan erişim** — ağ paylaşımının HTTP yüzü.
///
/// ## Niye eklendi (kullanıcı hatası 2026-08-29)
/// *"Herhangi bir belgeyi ağda paylaşıp bilgisayarımda açmaya çalıştığımda
/// Microsoft Edge açılıyor, dosya açılmıyor; ama dosyayı kopyalayıp
/// bilgisayarıma atınca açılıyor."*
///
/// **Kök neden:** paylaşım yalnız FTP konuşuyordu. Windows Gezgini FTP'yi
/// kendi biliyor (o yüzden listeleme ve KOPYALAMA çalışıyor) ama bir dosyaya
/// çift tıklandığında `ftp://…` adresini varsayılan tarayıcıya devrediyor —
/// ve **Chromium tabanlı tarayıcılar FTP desteğini 2021'de (sürüm 88)
/// tamamen kaldırdı.** Edge o adresle hiçbir şey yapamıyor: kullanıcının
/// gördüğü "tarayıcı açılıyor ama dosya açılmıyor" tam olarak bu.
///
/// **Çözüm protokolü değiştirmek:** aynı sanal ağaç ([FtpTree]) bir de HTTP
/// üzerinden sunuluyor. `http://192.168.1.x:8080` her tarayıcıda, her
/// telefonda, her işletim sisteminde çalışıyor; dosyaya tıklamak da doğru
/// sonucu veriyor çünkü:
/// - **Doğru MIME türü** gönderiliyor ([MimeTypes]) — PDF/görüntü/video
///   sekmede açılıyor,
/// - tarayıcının gösteremediği türler (Word, Excel, ZIP, APK)
///   `Content-Disposition: attachment` ile iniyor ve Windows dosyayı KENDİ
///   uygulamasıyla açıyor. Kullanıcının "kopyalayınca açılıyor" dediği
///   davranış, artık tek tıkla oluyor.
///
/// FTP kaldırılmadı: Gezgin'e sürükle-bırak ile yazma ve toplu kopyalama orada
/// daha iyi. İki kapı, tek ağaç.
///
/// ## Güvenlik
/// - Kök hapsi, kimlik doğrulama ve kilitli klasör kuralları **paylaşılan
///   [FtpServer] nesnesinden** geliyor ([FtpServer.realPathOf]); burada ikinci
///   bir kopya YOK.
/// - Parola varsa HTTP Basic sorulur (tarayıcı kendi penceresini açar).
///   Parolasız (anonim) paylaşımda sorulmaz — o kararı kullanıcı ekranda
///   bilerek veriyor.
/// - Yalnız `GET`/`HEAD`. Tarayıcıdan **yazma yok**: yazma FTP'de kalıyor,
///   çünkü bir tarayıcı sekmesinden yanlışlıkla dosya silinmesi istenmez.
class HttpShareServer {
  /// Sanal ağacın, kök hapsinin ve kimlik bilgilerinin sahibi.
  final FtpServer share;

  /// Varsayılan 8080: 1024 altındaki portlar Android'de root ister ve 80
  /// alınamaz. Tarayıcıya `:8080` yazmak alışılmış bir şey.
  final int port;

  HttpShareServer({required this.share, this.port = 8080});

  HttpServer? _server;

  bool get running => _server != null;

  /// Gerçekten bağlanılan port (0 verilmişse işletim sistemi seçer).
  int get boundPort => _server?.port ?? port;

  /// Kullanıcıya gösterilecek adresler: `http://192.168.1.37:8080`.
  static Future<List<String>> addresses(int port) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return [
        for (final i in interfaces)
          for (final a in i.addresses) 'http://${a.address}:$port',
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    // `listen` bilinçli olarak beklenmiyor: sunucu arka planda yaşıyor.
    server.listen(
      (request) => unawaited(_handle(request)),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server == null) return;
    // `force`: yarım kalmış bir indirme kapanışı süresiz bekletmesin.
    try {
      await server.close(force: true);
    } catch (_) {}
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (!_authorized(request)) {
        response.statusCode = HttpStatus.unauthorized;
        response.headers.set(
            HttpHeaders.wwwAuthenticateHeader, 'Basic realm="Dosya Okuyucu"');
        response.write('401');
        await response.close();
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        await response.close();
        return;
      }

      // **`Uri.path` DEĞİL, `pathSegments`.** `Uri.path` yüzde kaçışlarını
      // ÇÖZMEZ: `/Telefon/Rapor%20%C5%9Eubat.docx` aynen öyle geliyor ve
      // diskte o adla bir dosya olmadığı için her boşluklu ya da Türkçe
      // harfli dosya 404 dönüyordu — yani pratikte dosyaların çoğu.
      // `pathSegments` her parçayı UTF-8 çözüyor (test bunu yakaladı).
      final virtual = FtpServer.normalizeVirtual(
          '/', '/${request.uri.pathSegments.join('/')}');
      final node = await share.tree.resolve(virtual);
      switch (node.kind) {
        case FtpNodeKind.root:
          await _sendHtml(response, _rootPage(virtual));
        case FtpNodeKind.category:
          final files = await share.tree.categoryEntries(node.category!);
          await _sendHtml(response, _categoryPage(virtual, files));
        default:
          final real = share.realPathOf(node);
          if (real == null) {
            await _sendNotFound(response);
            return;
          }
          if (Directory(real).existsSync()) {
            await _sendHtml(response, _directoryPage(virtual, real));
          } else if (File(real).existsSync()) {
            await _sendFile(request, File(real));
          } else {
            await _sendNotFound(response);
          }
      }
    } catch (_) {
      // Bağlantı yarıda kesildiyse (kullanıcı sekmeyi kapattı) yazmak da
      // patlar; sunucu bu yüzden çökmemeli.
      try {
        await response.close();
      } catch (_) {}
    }
  }

  /// Parola varsa HTTP Basic. Anonim paylaşımda herkes girebilir (kullanıcı
  /// bunu ekranda bilerek seçiyor).
  bool _authorized(HttpRequest request) {
    if (share.anonymous) return true;
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    return checkBasicAuth(header, share.username, share.password);
  }

  // ── Sayfalar ──────────────────────────────────────────────────────────────

  String _rootPage(String virtual) => listingHtml(
        title: FtpTree.storageFolder,
        virtualPath: virtual,
        rows: [
          for (final item in share.tree.rootItems())
            HttpShareRow(name: item.name, isDir: true),
        ],
      );

  String _categoryPage(String virtual, Map<String, FsEntry> files) =>
      listingHtml(
        title: p.posix.basename(virtual),
        virtualPath: virtual,
        rows: [
          for (final entry in files.entries)
            HttpShareRow(
              name: entry.key,
              isDir: false,
              size: entry.value.sizeBytes,
              modifiedMs: entry.value.modifiedMs,
            ),
        ],
      );

  String _directoryPage(String virtual, String real) {
    final rows = <HttpShareRow>[];
    for (final entry in Directory(real).listSync(followLinks: false)) {
      final name = p.basename(entry.path);
      if (!share.showHidden && FtpServer.isHidden(name)) continue;
      FileStat stat;
      try {
        stat = entry.statSync();
      } catch (_) {
        continue;
      }
      rows.add(HttpShareRow(
        name: name,
        isDir: entry is Directory,
        size: entry is File ? stat.size : 0,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
      ));
    }
    return listingHtml(
      title: p.posix.basename(virtual),
      virtualPath: virtual,
      rows: rows,
    );
  }

  Future<void> _sendHtml(HttpResponse response, String html) async {
    response.headers.contentType = ContentType.html;
    // Listeleme ÖNBELLEKLENMEZ: klasör içeriği telefonda her an değişiyor.
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(html);
    await response.close();
  }

  Future<void> _sendNotFound(HttpResponse response) async {
    response.statusCode = HttpStatus.notFound;
    response.headers.contentType = ContentType.html;
    response.write('<h1>404</h1>');
    await response.close();
  }

  /// Dosyayı gönderir: doğru tür, indirme başlığı ve **kısmi istek** desteği.
  ///
  /// `Range` şart: onsuz tarayıcı bir videoyu baştan sona indirmeden
  /// oynatamaz ve ileri sarmak imkânsız olur.
  Future<void> _sendFile(HttpRequest request, File file) async {
    final response = request.response;
    final name = p.basename(file.path);
    final length = file.lengthSync();
    final mime = MimeTypes.forName(name);
    // `?indir=1` kullanıcıyı zorlamıyor, SEÇTİRİYOR: listedeki indirme
    // düğmesi tarayıcının gösterebileceği bir dosyayı da diske indirir.
    final forced = request.uri.queryParameters.containsKey('indir');
    final inline = !forced && MimeTypes.opensInBrowser(mime);

    response.headers.contentType = ContentType.parse(mime);
    // `HttpHeaders`ta sabiti yok; başlık adı düz metin.
    response.headers.set('content-disposition', contentDisposition(name, inline));
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

    final range = parseRange(
        request.headers.value(HttpHeaders.rangeHeader), length);
    if (range == null) {
      response.headers.set(
          HttpHeaders.contentRangeHeader, 'bytes */$length');
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await response.close();
      return;
    }

    if (range.partial) {
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(HttpHeaders.contentRangeHeader,
          'bytes ${range.start}-${range.end}/$length');
    }
    response.headers.contentLength = range.length;
    if (request.method == 'HEAD') {
      await response.close();
      return;
    }
    await response.addStream(file.openRead(range.start, range.end + 1));
    await response.close();
  }

  /// Listeleme sayfasının HTML'i. **Saf fonksiyon** (statik): kaçış,
  /// bağlantı kodlaması ve sıralama sunucu ayağa kaldırılmadan ölçülebilsin.
  static String listingHtml({
    required String title,
    required String virtualPath,
    required List<HttpShareRow> rows,
  }) {
    final sorted = [...rows]..sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final parent = p.posix.dirname(virtualPath);
    final buffer = StringBuffer()
      ..write('<!doctype html><html lang="tr"><head>')
      ..write('<meta charset="utf-8">')
      ..write('<meta name="viewport" content="width=device-width,'
          'initial-scale=1">')
      ..write('<title>${escapeHtml(title)}</title>')
      ..write('<style>$_css</style>')
      ..write('</head><body><header><h1>${escapeHtml(title)}</h1>')
      ..write('<p class="path">${escapeHtml(virtualPath)}</p></header><ul>');
    if (virtualPath != '/') {
      buffer.write('<li><a class="up" href="${encodePath(parent)}">'
          '&#8593; ..</a></li>');
    }
    for (final row in sorted) {
      final href = encodePath(p.posix.join(virtualPath, row.name));
      buffer
        ..write('<li><a href="$href">')
        ..write('<span class="ico">${row.isDir ? '&#128193;' : '&#128196;'}'
            '</span>')
        ..write('<span class="name">${escapeHtml(row.name)}</span>')
        ..write('<span class="meta">${escapeHtml(row.meta)}</span></a>');
      // Klasörde indirme düğmesi yok; dosyada tarayıcı türü gösterse bile
      // "diske indir" tek tık uzakta olsun.
      if (!row.isDir) {
        buffer.write('<a class="dl" href="$href?indir=1" '
            'download>&#8681;</a>');
      }
      buffer.write('</li>');
    }
    if (sorted.isEmpty) buffer.write('<li class="empty">—</li>');
    buffer.write('</ul></body></html>');
    return buffer.toString();
  }

  static const _css = '''
:root{color-scheme:light dark}
*{box-sizing:border-box}
body{margin:0;font:16px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
header{padding:16px 20px;border-bottom:1px solid rgba(128,128,128,.35)}
h1{margin:0;font-size:20px}
.path{margin:4px 0 0;opacity:.6;font-size:13px;word-break:break-all}
ul{list-style:none;margin:0;padding:0}
li{display:flex;align-items:center;border-bottom:1px solid rgba(128,128,128,.2)}
li a{display:flex;align-items:center;gap:12px;flex:1;min-width:0;
padding:12px 20px;text-decoration:none;color:inherit}
li a:hover{background:rgba(128,128,128,.12)}
.ico{font-size:20px}
.name{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;
white-space:nowrap}
.meta{opacity:.6;font-size:13px;white-space:nowrap}
.dl{flex:0 0 auto;padding:12px 20px;font-size:18px}
.up{opacity:.7}
.empty{padding:20px;opacity:.6}
''';
}

/// Listeleme satırı (klasör ya da dosya).
class HttpShareRow {
  final String name;
  final bool isDir;
  final int size;
  final int modifiedMs;

  const HttpShareRow({
    required this.name,
    required this.isDir,
    this.size = 0,
    this.modifiedMs = 0,
  });

  /// Sağdaki ikincil metin: boyut · tarih (klasörde boş).
  String get meta {
    if (isDir) return '';
    final date =
        modifiedMs > 0 ? ' · ${FsPaths.humanDate(modifiedMs)}' : '';
    return '${FsPaths.humanSize(size)}$date';
  }
}

/// Bir `Range` isteğinin çözümü.
class HttpByteRange {
  final int start;

  /// **Dahil** son bayt (HTTP'nin tanımı böyle).
  final int end;

  /// Kısmi mi (206 dönecek mi)?
  final bool partial;

  const HttpByteRange(this.start, this.end, {this.partial = true});

  int get length => end - start + 1;
}

/// `Range: bytes=…` başlığını çözer.
///
/// **Saf fonksiyon** — sınır durumları (açık uçlu aralık, sondan N bayt,
/// dosya boyunu aşan istek) telefon olmadan ölçülebilsin diye.
/// - Başlık yoksa ya da anlaşılmıyorsa: dosyanın TAMAMI (`partial: false`).
/// - Aralık dosyanın dışındaysa `null` → çağıran 416 döner. Sessizce tüm
///   dosyayı göndermek, oynatıcıyı bozuk veriyle besler.
HttpByteRange? parseRange(String? header, int length) {
  if (length <= 0) return const HttpByteRange(0, -1, partial: false);
  if (header == null || !header.startsWith('bytes=')) {
    return HttpByteRange(0, length - 1, partial: false);
  }
  // Çoklu aralık (`bytes=0-99,200-299`) desteklenmiyor: tarayıcılar medya
  // oynatırken tek aralık gönderiyor. Tanımadığımız biçimde tüm dosya.
  final spec = header.substring(6).trim();
  if (spec.contains(',')) return HttpByteRange(0, length - 1, partial: false);
  final dash = spec.indexOf('-');
  if (dash < 0) return HttpByteRange(0, length - 1, partial: false);
  final startText = spec.substring(0, dash).trim();
  final endText = spec.substring(dash + 1).trim();

  if (startText.isEmpty) {
    // `bytes=-500`: SONDAN 500 bayt.
    final last = int.tryParse(endText);
    if (last == null || last <= 0) return null;
    final start = last >= length ? 0 : length - last;
    return HttpByteRange(start, length - 1);
  }
  final start = int.tryParse(startText);
  if (start == null || start >= length) return null;
  final end = endText.isEmpty ? length - 1 : int.tryParse(endText);
  if (end == null || end < start) return null;
  return HttpByteRange(start, end >= length ? length - 1 : end);
}

/// `Content-Disposition` başlığı — **Türkçe dosya adları için iki biçim**.
///
/// `filename="…"` yalnız ASCII taşıyabiliyor; "Fatura Şubat.pdf" oradan
/// geçerse ad bozulur ya da başlık tamamen yok sayılır. RFC 5987'nin
/// `filename*=UTF-8''…` biçimi doğru adı taşır ve modern tarayıcılar onu
/// tercih eder; ASCII biçim çok eski istemciler için yedek kalır.
String contentDisposition(String name, bool inline) {
  final ascii = name.replaceAll(RegExp(r'[^\x20-\x7E]'), '_')
      .replaceAll('"', "'");
  final encoded = Uri.encodeComponent(name);
  return '${inline ? 'inline' : 'attachment'}; '
      'filename="$ascii"; filename*=UTF-8\'\'$encoded';
}

/// HTTP Basic başlığını doğrular. **Saf fonksiyon** — kimlik doğrulama
/// mantığı soket açmadan test edilebilsin diye.
bool checkBasicAuth(String? header, String username, String password) {
  if (header == null || !header.toLowerCase().startsWith('basic ')) {
    return false;
  }
  try {
    final decoded = utf8.decode(base64.decode(header.substring(6).trim()));
    final colon = decoded.indexOf(':');
    if (colon < 0) return false;
    return decoded.substring(0, colon) == username &&
        decoded.substring(colon + 1) == password;
  } catch (_) {
    return false;
  }
}

/// Sanal yolu bağlantıya çevirir: her parça ayrı ayrı kodlanır ki `/`
/// ayraç olarak kalsın ("Fatura Şubat.pdf" → "Fatura%20%C5%9Eubat.pdf").
String encodePath(String virtualPath) {
  final parts = virtualPath.split('/').where((s) => s.isNotEmpty);
  return '/${parts.map(Uri.encodeComponent).join('/')}';
}

/// HTML kaçışı — dosya adında `<script>` geçse bile sayfa bozulmasın.
String escapeHtml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
