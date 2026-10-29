import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../archive_ops.dart';
import '../file_ops.dart';
import 'zip_stream.dart';


/// **QR ile dosya paylaşma / geçici web sunucusu** (2026-10-22; 2026-10-29
/// yenilendi, kullanıcı: *"kişi QR'ı okuttuğunda direkt açılmıyor, linke
/// tıklanmıyor ve arayüz iyi değil — rahatlıkla, zahmetsiz alabilmeli"*).
///
/// Gönderen telefon ekran açıkken küçük bir HTTP sunucusu açar; QR bu
/// sunucunun adresini taşır. Dosya hiçbir dış sunucuya yüklenmez.
/// * **Karşıda uygulama yoksa:** kamera adresi tarayıcıda açar; sayfada
///   küçük resimli dosya kartları, tek dokunuşla "İndir", birden çok dosyada
///   **"Tümünü indir (ZIP)"**. Tek dosyada indirme kendiliğinden başlar.
/// * **Karşıda Dosya Okuyucu varsa:** "QR tara" ya da Yakındakiler'deki
///   Bluetooth daveti adresi okur, dosyaları önizlemeli onaydan sonra indirir.
/// * **Ortak Wi-Fi yoksa:** gönderen yerel hotspot kurar; önce `WIFI:` QR'ı,
///   sonra adres QR'ı.
///
/// ## 2026-10-29 düzeltmeleri — niye "açılmıyordu"
/// * Adres uzun ve elle yazılamazdı (`/q/<16 karakter>/`, rastgele port):
///   artık **8080** portu (meşgulse rastgele) ve **6 karakterlik** küçük harf
///   jeton — QR okunmazsa adres ekrandan okunup yazılabilir.
/// * Klasörler önce diske ZIP'leniyordu (büyük klasörde dakikalarca "hazırlanıyor"):
///   artık indirme anında akan paket ([ZipStream]).
/// * `Range` desteği: tarayıcının "devam et"i ve uygulamanın yeniden denemesi
///   kaldığı yerden sürer.
///
/// Jeton tutmayan her istek 404. Sunucu yalnız GET yanıtlar, yalnız verilen
/// dosyaları açar.
class QrShareServer {
  final List<String> paths;
  final String token;

  /// Sayfada "X sizinle paylaşıyor" diye görünen ad.
  final String senderName;

  /// Bir dosyanın indirilmesi bitince (ekran "indirildi" sayar).
  final void Function(String name)? onServed;

  /// Görsel/video için küçük JPEG üretici (sayfa ve alıcı uygulama gösterir).
  final Future<List<int>?> Function(String path)? thumbnail;

  /// Tercih edilen port (kullanıcının alışık olduğu `:8080`).
  final int preferredPort;

  QrShareServer(
    this.paths, {
    this.onServed,
    this.thumbnail,
    this.senderName = '',
    this.preferredPort = 8080,
  }) : token = _newToken();

  HttpServer? _server;
  int get port => _server?.port ?? 0;

  final List<_Served> _items = [];
  final Map<int, Future<List<int>?>> _thumbs = {};

  /// 6 karakter, karışmayan harf/rakamlar (0/o, 1/l yok) — elle yazılabilir.
  static String _newToken() {
    const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(6, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }

  Future<void> start() async {
    if (_server != null) return;
    _items.clear();
    for (final path in paths) {
      if (await Directory(path).exists()) {
        final zip = await ZipStream.of([path]);
        if (zip != null) {
          _items.add(_Served.zip('${p.basename(path)}.zip', zip, path));
        }
      } else {
        _items.add(_Served.file(path, await File(path).length()));
      }
    }
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } catch (_) {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server = server;
    server.listen((r) => unawaited(_handle(r)), onError: (_) {});
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
  }

  /// `http://<ip>:<port>/q/<jeton>/`
  Uri urlFor(String host) => Uri(
      scheme: 'http', host: host, port: port, path: '/q/$token/');

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final seg = req.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if ((req.method != 'GET' && req.method != 'HEAD') ||
          seg.length < 2 ||
          seg[0] != 'q' ||
          seg[1] != token) {
        // Jetonsuz adres (`/q/<jeton>` sonu eğik çizgisiz) yönlendirilir:
        // elle yazan çizgiyi unutabilir.
        if (req.method == 'GET' &&
            seg.length == 2 &&
            seg[0] == 'q' &&
            seg[1] == token) {
          res.redirect(Uri(path: '/q/$token/'));
          return;
        }
        res.statusCode = HttpStatus.notFound;
        return;
      }
      if (seg.length == 2) {
        if (!req.uri.path.endsWith('/')) {
          res.statusCode = HttpStatus.movedPermanently;
          res.headers.set(HttpHeaders.locationHeader, '/q/$token/');
          return;
        }
        return _page(res);
      }
      switch (seg[2]) {
        case 'list':
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode([
            for (final it in _items)
              {
                'name': it.name,
                'size': it.size,
                if (it.isZip) 'files': it.zip!.entries.length,
                if (_canThumb(it)) 'thumb': true,
              },
          ]));
          return;
        case 'th':
          final i = seg.length > 3 ? int.tryParse(seg[3]) : null;
          final bytes = i == null || i < 0 || i >= _items.length
              ? null
              : await _thumbOf(i);
          if (bytes == null) {
            res.statusCode = HttpStatus.notFound;
            return;
          }
          res.headers
            ..contentType = ContentType('image', 'jpeg')
            ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
          res.add(bytes);
          return;
        case 'all.zip':
          final zip = await ZipStream.of(paths);
          if (zip == null) {
            res.statusCode = HttpStatus.requestEntityTooLarge;
            return;
          }
          final name = paths.length == 1
              ? '${p.basenameWithoutExtension(paths.single)}.zip'
              : 'dosyalar.zip';
          await _send(req, res, _Served.zip(name, zip, ''));
          return;
      }
      final i = int.tryParse(seg[2]);
      if (i == null || i < 0 || i >= _items.length) {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      await _send(req, res, _items[i]);
    } catch (_) {
      // Karşı taraf yarıda bıraktı / dosya silindi: yapılacak bir şey yok.
    } finally {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  /// Dosyayı (ya da paketi) `Range` desteğiyle akıtır.
  Future<void> _send(HttpRequest req, HttpResponse res, _Served item) async {
    var start = 0;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final m = range == null ? null : RegExp(r'^bytes=(\d+)-$').firstMatch(range);
    if (m != null) {
      start = int.parse(m[1]!);
      if (start >= item.size) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */${item.size}');
        return;
      }
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(HttpHeaders.contentRangeHeader,
          'bytes $start-${item.size - 1}/${item.size}');
    }
    res.headers
      ..contentType = item.isZip
          ? ContentType('application', 'zip')
          : ContentType.binary
      ..contentLength = item.size - start
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set('content-disposition',
          "attachment; filename*=UTF-8''${Uri.encodeComponent(item.name)}");
    if (req.method == 'HEAD') return;
    await res.addStream(item.open(start));
    onServed?.call(item.name);
  }

  static const _thumbExts = {
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif',
    '.mp4', '.mkv', '.mov', '.webm', '.3gp', '.avi',
  };

  bool _canThumb(_Served it) =>
      thumbnail != null &&
      !it.isZip &&
      _thumbExts.contains(p.extension(it.path).toLowerCase());

  Future<List<int>?> _thumbOf(int i) {
    final it = _items[i];
    if (!_canThumb(it)) return Future.value(null);
    return _thumbs[i] ??= thumbnail!(it.path).catchError((_) => null);
  }

  static String _kind(String name) {
    final e = p.extension(name).toLowerCase();
    if (const {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif'}
        .contains(e)) {
      return '🖼️';
    }
    if (const {'.mp4', '.mkv', '.mov', '.webm', '.3gp', '.avi'}.contains(e)) {
      return '🎬';
    }
    if (const {'.mp3', '.m4a', '.wav', '.ogg', '.flac', '.aac', '.opus'}
        .contains(e)) {
      return '🎵';
    }
    if (e == '.pdf') return '📕';
    if (const {'.doc', '.docx', '.odt', '.rtf', '.txt', '.md'}.contains(e)) {
      return '📄';
    }
    if (const {'.xls', '.xlsx', '.csv', '.ods'}.contains(e)) return '📊';
    if (const {'.ppt', '.pptx', '.odp'}.contains(e)) return '📽️';
    if (const {'.zip', '.rar', '.7z', '.tar', '.gz'}.contains(e)) return '🗜️';
    if (e == '.apk') return '📦';
    return '📁';
  }

  static String _human(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var v = bytes / 1024;
    var u = 0;
    while (v >= 1024 && u < units.length - 1) {
      v /= 1024;
      u++;
    }
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[u]}';
  }

  /// Tarayıcıda açılan sayfa. Türkçe/İngilizce tarayıcı diline göre seçilir.
  void _page(HttpResponse res) {
    const esc = HtmlEscape();
    final total = _items.fold<int>(0, (a, e) => a + e.size);
    final cards = StringBuffer();
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      final href = '$i/${Uri.encodeComponent(it.name)}';
      final media = _canThumb(it)
          ? '<img loading="lazy" src="th/$i" alt="" '
              'onerror="this.replaceWith(Object.assign(document.createElement(\'span\'),'
              '{textContent:\'${_kind(it.name)}\'}))">'
          : '<span>${it.isZip ? '🗂️' : _kind(it.name)}</span>';
      final meta = it.isZip
          ? '${_human(it.size)} · <i data-t="files">${it.zip!.entries.length}</i>'
          : _human(it.size);
      cards.write('<a class="card" href="$href" download>'
          '<div class="thumb">$media</div>'
          '<div class="info"><b>${esc.convert(it.name)}</b><small>$meta</small></div>'
          '<div class="dl" aria-hidden="true">⬇</div></a>');
    }
    final who = senderName.trim().isEmpty ? '' : esc.convert(senderName.trim());
    final single = _items.length == 1;
    res.headers
      ..contentType = ContentType.html
      ..set(HttpHeaders.cacheControlHeader, 'no-store');
    res.write('''<!doctype html><html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="color-scheme" content="light dark">
<title>Dosya Okuyucu · ${_items.length}</title>
<style>
:root{--bg:#f7f5f0;--card:#fffdf9;--ink:#24211c;--muted:#6f685d;--line:#e7e1d6;--accent:#2f6f5e;--accent-ink:#fff}
@media (prefers-color-scheme:dark){:root{--bg:#1c1b19;--card:#262421;--ink:#efebe4;--muted:#a9a194;--line:#36332e;--accent:#7cc4ad;--accent-ink:#10251f}}
*{box-sizing:border-box}html,body{margin:0}
body{font:16px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--bg);color:var(--ink);padding:max(20px,env(safe-area-inset-top)) 16px 40px}
main{max-width:560px;margin:0 auto}
.brand{display:flex;align-items:center;gap:10px;color:var(--muted);font-size:14px;font-weight:600;letter-spacing:.2px}
.brand i{display:inline-grid;place-items:center;width:30px;height:30px;border-radius:9px;background:var(--accent);color:var(--accent-ink);font-style:normal}
h1{font-size:24px;line-height:1.25;margin:18px 0 4px}
.sub{color:var(--muted);margin:0 0 18px}
.all{display:flex;justify-content:center;align-items:center;gap:8px;width:100%;padding:16px;border:0;border-radius:16px;background:var(--accent);color:var(--accent-ink);font-size:17px;font-weight:700;text-decoration:none;margin-bottom:16px}
.card{display:flex;align-items:center;gap:14px;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:10px 14px 10px 10px;margin:10px 0;text-decoration:none;color:inherit;-webkit-tap-highlight-color:transparent}
.card:active{transform:scale(.99)}
.thumb{flex:none;width:56px;height:56px;border-radius:12px;background:var(--bg);display:grid;place-items:center;overflow:hidden;font-size:28px}
.thumb img{width:100%;height:100%;object-fit:cover}
.info{flex:1;min-width:0}.info b{display:block;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.info small{color:var(--muted);font-size:13px}.info i{font-style:normal}
.dl{flex:none;width:40px;height:40px;border-radius:50%;display:grid;place-items:center;background:var(--accent);color:var(--accent-ink);font-weight:700}
.note{margin-top:22px;padding:14px 16px;border-radius:14px;background:var(--card);border:1px dashed var(--line);color:var(--muted);font-size:14px}
.note b{color:var(--ink)}
footer{margin-top:18px;color:var(--muted);font-size:13px;text-align:center}
footer a{color:var(--accent)}
#toast{position:fixed;left:50%;bottom:24px;transform:translateX(-50%);background:var(--ink);color:var(--bg);padding:10px 16px;border-radius:999px;font-size:14px;opacity:0;transition:opacity .25s}
</style></head><body><main>
<div class="brand"><i>⇣</i>Dosya Okuyucu</div>
<h1 data-t="title"></h1>
<p class="sub">${_items.length} · ${_human(total)}</p>
${single ? '' : '<a class="all" href="all.zip" download>⬇ <span data-t="all"></span></a>'}
$cards
<div class="note" data-t="note"></div>
<footer><span data-t="private"></span><br><a href="https://github.com/kaimau1/dosya-okuyucu/releases/latest" data-t="get"></a></footer>
</main><div id="toast" data-t="started"></div>
<script>
var tr=(navigator.language||'tr').toLowerCase().indexOf('tr')===0;
var who=${jsonEncode(who)};
var T=tr?{title:(who?who+' sizinle dosya paylaşıyor':'Sizinle dosya paylaşıldı'),all:'Tümünü indir (ZIP)',files:'dosya',
note:'<b>Dokunun, indirilsin.</b> İndirme başlamazsa bu sayfayı Chrome/Safari\\'de açın. Sayfa açılmıyorsa iki telefonun aynı Wi-Fi\\'de olduğundan emin olun ya da mobil veriyi kapatın.',
private:'Dosyalar doğrudan gönderen telefondan gelir; internete yüklenmez.',get:'Dosya Okuyucu\\'yu indir',started:'İndirme başladı'}
:{title:(who?who+' is sharing files with you':'Files shared with you'),all:'Download all (ZIP)',files:'files',
note:'<b>Tap to download.</b> If nothing happens, open this page in Chrome/Safari. If the page does not load, make sure both phones are on the same Wi-Fi or turn off mobile data.',
private:'Files come straight from the sender\\'s phone; nothing is uploaded.',get:'Get Dosya Okuyucu',started:'Download started'};
document.querySelectorAll('[data-t]').forEach(function(e){var k=e.getAttribute('data-t');if(k==='files'){e.textContent=e.textContent+' '+T.files}else{e.innerHTML=T[k]}});
document.documentElement.lang=tr?'tr':'en';
function toast(){var t=document.getElementById('toast');t.style.opacity=1;setTimeout(function(){t.style.opacity=0},2200)}
document.querySelectorAll('a[download]').forEach(function(a){a.addEventListener('click',toast)});
${single ? "setTimeout(function(){var a=document.querySelector('.card');if(a){toast();location.href=a.getAttribute('href')}},900);" : ''}
</script></body></html>''');
  }
}

/// Sunulan tek parça: düz dosya ya da klasörden akan paket.
class _Served {
  final String name;
  final int size;
  final String path;
  final ZipStream? zip;

  _Served.file(this.path, this.size)
      : name = p.basename(path),
        zip = null;

  _Served.zip(this.name, ZipStream this.zip, this.path) : size = zip.length;

  bool get isZip => zip != null;

  Stream<List<int>> open(int start) =>
      zip?.open(start: start) ?? File(path).openRead(start);
}

/// QR'dan okunan içerik.
class QrPayload {
  /// Dosya listesinin adresi (`…/q/<jeton>/`); `WIFI:` QR'ında null.
  final Uri? url;
  final String? ssid;
  final String? pass;

  /// `sae` = WPA3-yalnız ağ; aksi WPA2.
  final String? sec;

  const QrPayload({this.url, this.ssid, this.pass, this.sec});

  /// Adres QR'ı: hotspot varsa `#w=<base64url(json)>` eki ağ bilgisini taşır
  /// (tarayıcı eki sunucuya göndermez, sayfayı etkilemez).
  static String encode(Uri url, {String? ssid, String? pass, String? sec}) {
    if (ssid == null) return url.toString();
    final w = base64Url
        .encode(utf8.encode(
            jsonEncode({'s': ssid, 'p': pass ?? '', 'k': sec ?? 'wpa'})))
        .replaceAll('=', '');
    return '$url#w=$w';
  }

  /// Kameranın tanıdığı Wi-Fi QR biçimi.
  static String wifi(String ssid, String pass, {String? sec}) {
    String e(String s) => s.replaceAllMapped(
        RegExp(r'([\\;,:"])'), (m) => '\\${m[1]}');
    return 'WIFI:T:${sec == 'sae' ? 'SAE' : 'WPA'};S:${e(ssid)};P:${e(pass)};;';
  }

  /// Bizim adres QR'ımız ya da `WIFI:` değilse null.
  static QrPayload? parse(String raw) {
    final text = raw.trim();
    if (text.startsWith('WIFI:')) {
      String? field(String k) {
        final m = RegExp('[:;]$k:((?:\\\\.|[^;])*)').firstMatch(text);
        return m?.group(1)?.replaceAllMapped(
            RegExp(r'\\(.)'), (x) => x[1]!);
      }

      final ssid = field('S');
      return ssid == null ? null : QrPayload(ssid: ssid, pass: field('P'));
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.pathSegments.length < 2 ||
        uri.pathSegments[0] != 'q') {
      return null;
    }
    String? ssid, pass, sec;
    if (uri.fragment.startsWith('w=')) {
      try {
        final j = jsonDecode(utf8.decode(
            base64Url.decode(base64Url.normalize(uri.fragment.substring(2)))));
        ssid = j['s'] as String?;
        pass = j['p'] as String?;
        sec = j['k'] as String?;
      } catch (_) {}
    }
    return QrPayload(
        url: Uri(
            scheme: 'http',
            host: uri.host,
            port: uri.port,
            path: '/q/${uri.pathSegments[1]}/'),
        ssid: ssid,
        pass: pass,
        sec: sec);
  }
}

/// QR/Bluetooth ile sunulan tek dosya (alıcı tarafındaki görünüşü).
typedef QrItem = ({String name, int size, bool thumb, int? files});

/// **Alıcı (uygulama)**: adres QR'ındaki dosyaların hepsini klasöre indirir.
abstract final class QrReceiver {
  /// Gönderenin sunduğu dosyaların listesi — indirmeden ÖNCE alıcıya
  /// "şunlar gelecek, alınsın mı?" diye sorabilmek için.
  static Future<List<QrItem>> list(Uri base) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final listReq = await client.getUrl(base.resolve('list'));
      final listRes = await listReq.close();
      if (listRes.statusCode != 200) throw const HttpException('list');
      final raw = jsonDecode(await listRes.transform(utf8.decoder).join())
          as List<dynamic>;
      return [
        for (final item in raw)
          (
            name: FileOps.sanitizeName(item['name'] as String? ?? ''),
            size: (item['size'] as num?)?.toInt() ?? 0,
            thumb: item['thumb'] == true,
            files: (item['files'] as num?)?.toInt(),
          ),
      ];
    } finally {
      client.close(force: true);
    }
  }

  /// [index]. öğenin küçük resmi (yoksa null).
  static Future<Uint8List?> thumb(Uri base, int index) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final res = await (await client.getUrl(base.resolve('th/$index'))).close();
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final b = BytesBuilder(copy: false);
      await for (final c in res) {
        b.add(c);
      }
      return b.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// İndirilen dosyaların yollarını döndürür.
  ///
  /// * [listed] verilirse liste yeniden istenmez (onaydan sonra indirme).
  /// * [isCancelled] true dönünce kalan dosyalar alınmaz, yarım dosya silinir.
  /// * **Kaldığı yerden devam** (2026-10-29): bağlantı koparsa [retryFor]
  ///   boyunca yeniden denenir ve `Range` ile kalan bayttan sürer; beklerken
  ///   [onWaiting] `true` alır.
  /// * Klasör paketleri (`files` alanı olan `.zip`) indirildikten sonra
  ///   klasöre AÇILIR.
  static Future<List<String>> download(
    Uri base,
    String saveDir, {
    void Function(String name, int received, int total)? onProgress,
    void Function(bool waiting)? onWaiting,
    List<QrItem>? listed,
    bool Function()? isCancelled,
    Duration retryFor = const Duration(minutes: 2),
    Duration retryEvery = const Duration(seconds: 2),
  }) async {
    final items = listed ?? await list(base);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15);
    final out = <String>[];
    try {
      for (var i = 0; i < items.length; i++) {
        if (isCancelled?.call() ?? false) break;
        final name = items[i].name.isEmpty ? 'dosya' : items[i].name;
        final total = items[i].size;
        final part = File(p.join(saveDir,
            '${_partPrefix}q${base.pathSegments.length > 1 ? base.pathSegments[1] : ''}-$i'));
        await part.parent.create(recursive: true);
        final deadline = DateTime.now().add(retryFor);
        var waiting = false;
        var done = false;
        var stopped = false;
        while (!done) {
          if (isCancelled?.call() ?? false) {
            stopped = true;
            break;
          }
          final have = await part.exists() ? await part.length() : 0;
          try {
            final req = await client.getUrl(base.resolve('$i'));
            if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
            final res = await req.close();
            final resumed = res.statusCode == HttpStatus.partialContent;
            if (res.statusCode != 200 && !resumed) {
              await res.drain<void>();
              throw HttpException('$i:${res.statusCode}');
            }
            final sink = part.openWrite(
                mode: resumed ? FileMode.append : FileMode.writeOnly);
            var received = resumed ? have : 0;
            try {
              await for (final chunk in res) {
                if (isCancelled?.call() ?? false) {
                  stopped = true;
                  break;
                }
                if (waiting) {
                  waiting = false;
                  onWaiting?.call(false);
                }
                sink.add(chunk);
                received += chunk.length;
                onProgress?.call(name, received, total);
              }
              await sink.flush();
            } finally {
              await sink.close();
            }
            if (stopped) break;
            if (total > 0 && received < total) {
              throw HttpException('short $name');
            }
            done = true;
          } on HttpException catch (e) {
            if (e.message.contains(':4')) rethrow; // 404 vb.: tekrar boşuna
            if (DateTime.now().isAfter(deadline)) rethrow;
          } on SocketException {
            if (DateTime.now().isAfter(deadline)) rethrow;
          } on TimeoutException {
            if (DateTime.now().isAfter(deadline)) rethrow;
          } catch (_) {
            if (isCancelled?.call() ?? false) {
              stopped = true;
              break;
            }
            if (DateTime.now().isAfter(deadline)) rethrow;
          }
          if (!done) {
            if (!waiting) {
              waiting = true;
              onWaiting?.call(true);
            }
            await Future<void>.delayed(retryEvery);
          }
        }
        if (waiting) onWaiting?.call(false);
        if (stopped) {
          await part.delete().catchError((_) => part);
          break;
        }
        if (items[i].files != null && name.toLowerCase().endsWith('.zip')) {
          out.addAll(await _unpack(part, saveDir));
        } else {
          final target = FileOps.uniquePath(p.join(saveDir, name));
          await part.rename(target);
          out.add(target);
        }
      }
      return out;
    } catch (_) {
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static const _partPrefix = '.dosya-aktarim-';

  static Future<List<String>> _unpack(File part, String saveDir) async {
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
      await zip.delete().catchError((_) => zip);
      await tmp.delete(recursive: true).catchError((_) => tmp);
    }
  }
}

/// `ci/QrTransfer.kt`in Dart yüzü: Google kod tarayıcısı (kamera izni
/// istemez, Play Hizmetleri'nden gelir) ve yerel hotspot.
abstract final class QrNative {
  static const _ch = MethodChannel('dosya/qr');

  /// Okunan metin; vazgeçilirse null. Tarayıcı yoksa (Play Hizmetleri
  /// yok/eski) `unavailable` kodlu PlatformException.
  static Future<String?> scan() async {
    try {
      return await _ch.invokeMethod<String>('scan');
    } on MissingPluginException {
      throw PlatformException(code: 'unavailable');
    }
  }

  /// `{ssid, pass, sec}`. İzin eksikse bir kez ister ve yeniden dener;
  /// olmazsa hata kodu (`perm`, `location_off`, `unsupported`, `failed`)
  /// ile PlatformException.
  static Future<({String ssid, String pass, String sec})> startHotspot() async {
    Map<String, String>? m;
    try {
      m = await _ch.invokeMapMethod<String, String>('startHotspot');
    } on PlatformException catch (e) {
      if (e.code != 'perm') rethrow;
      final perm = e.details == 'nearby'
          ? Permission.nearbyWifiDevices
          : Permission.locationWhenInUse;
      if (!(await perm.request()).isGranted) rethrow;
      m = await _ch.invokeMapMethod<String, String>('startHotspot');
    } on MissingPluginException {
      throw PlatformException(code: 'unsupported');
    }
    return (ssid: m!['ssid']!, pass: m['pass'] ?? '', sec: m['sec'] ?? 'wpa');
  }

  static Future<void> stopHotspot() async {
    try {
      await _ch.invokeMethod('stopHotspot');
    } catch (_) {}
  }

  /// Alıcı: verilen ağa bağlanıp süreci o ağa bağlar (Android 10+; sistem
  /// onay penceresi çıkar). Bağlanamazsa false.
  static Future<bool> joinWifi(String ssid, String pass, String? sec) async {
    try {
      return await _ch.invokeMethod<bool>(
              'joinWifi', {'ssid': ssid, 'pass': pass, 'sec': sec ?? 'wpa'}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> leaveWifi() async {
    try {
      await _ch.invokeMethod('leaveWifi');
    } catch (_) {}
  }
}
