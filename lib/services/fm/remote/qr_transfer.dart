import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../file_ops.dart';

/// **QR ile dosya paylaşma** (2026-10-22, kullanıcı: *"paylaşta 3. seçenek
/// QR'la paylaş olacak; diğer kişide Dosya Okuyucu varsa direkt onun
/// üzerinden hızlıca, yoksa da başka bir yolla kolay paylaşım"*).
///
/// Gönderen telefon ekran açıkken küçük bir HTTP sunucusu açar; QR bu
/// sunucunun adresini taşır. Dosya hiçbir dış sunucuya yüklenmez (gizlilik:
/// üçüncü taraf yükleme 2026-10-22'de reddedildi).
/// * **Karşıda uygulama yoksa:** telefon kamerası adresi tarayıcıda açar,
///   sayfada "İndir" bağlantıları var.
/// * **Karşıda Dosya Okuyucu varsa:** "Al → QR tara" adresi okur, dosyaları
///   seçilen klasöre doğrudan indirir ([QrReceiver]).
/// * **Ortak Wi-Fi yoksa:** gönderen yerel hotspot kurar ([QrNative.startHotspot]);
///   önce `WIFI:` QR'ı (kamera ağa bağlanır), sonra adres QR'ı. Uygulama
///   adres QR'ının `#w=` ekinden ağı kendisi bağlar.
///
/// Adres tahmin edilemez bir jeton taşır (`/q/<jeton>/`); jeton tutmayan her
/// istek 404. Sunucu yalnız GET yanıtlar, yalnız verilen dosyaları açar.
class QrShareServer {
  final List<String> paths;
  final String token;

  /// Bir dosyanın indirilmesi bitince (ekran "indirildi" sayar).
  final void Function(String name)? onServed;

  QrShareServer(this.paths, {this.onServed}) : token = _newToken();

  HttpServer? _server;
  int get port => _server?.port ?? 0;

  static String _newToken() {
    final r = Random.secure();
    return base64Url
        .encode(List.generate(12, (_) => r.nextInt(256)))
        .replaceAll('=', '');
  }

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
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
      if (req.method != 'GET' ||
          seg.length < 2 ||
          seg[0] != 'q' ||
          seg[1] != token) {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      if (seg.length == 2) return _page(res);
      if (seg[2] == 'list') {
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode([
          for (final f in paths)
            {'name': p.basename(f), 'size': File(f).lengthSync()},
        ]));
        return;
      }
      final i = int.tryParse(seg[2]);
      if (i == null || i < 0 || i >= paths.length) {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      final file = File(paths[i]);
      final name = p.basename(file.path);
      res.headers
        ..contentType = ContentType.binary
        ..contentLength = await file.length()
        ..set('content-disposition',
            "attachment; filename*=UTF-8''${Uri.encodeComponent(name)}");
      await res.addStream(file.openRead());
      onServed?.call(name);
    } catch (_) {
      // Karşı taraf yarıda bıraktı / dosya silindi: yapılacak bir şey yok.
    } finally {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  /// Tarayıcıda açılan sayfa: dosya adları + İndir bağlantıları. Dil
  /// ayrımı yok — üç kelimelik sayfa için çeviri katmanı açmaya değmez.
  void _page(HttpResponse res) {
    const esc = HtmlEscape();
    final rows = StringBuffer();
    for (var i = 0; i < paths.length; i++) {
      final f = File(paths[i]);
      final name = p.basename(f.path);
      final mb = (f.lengthSync() / 1048576).toStringAsFixed(1);
      rows.write('<a class="f" href="$i/${Uri.encodeComponent(name)}" download>'
          '<b>${esc.convert(name)}</b><span>$mb MB · İndir / Download</span></a>');
    }
    res.headers.contentType = ContentType.html;
    res.write('<!doctype html><html lang="tr"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>Dosya Okuyucu</title><style>'
        'body{font-family:system-ui,sans-serif;margin:0;padding:20px;'
        'background:#f6f7f9;color:#1b1d21}h1{font-size:20px}'
        '.f{display:block;background:#fff;border-radius:14px;padding:16px;'
        'margin:10px 0;text-decoration:none;color:inherit;'
        'box-shadow:0 1px 3px #0002}.f b{display:block;word-break:break-all}'
        '.f span{color:#0b6bcb;font-size:14px}p{color:#5b6070;font-size:14px}'
        '</style></head><body><h1>📄 Dosya Okuyucu</h1>$rows'
        '<p>Dosyalar doğrudan gönderen telefondan gelir; internete yüklenmez.'
        '<br>Files come straight from the sender\'s phone.</p>'
        '<p><a href="https://github.com/kaimau1/dosya-okuyucu/releases/latest">'
        'Dosya Okuyucu\'yu indir</a></p></body></html>');
  }
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

/// **Alıcı (uygulama)**: adres QR'ındaki dosyaların hepsini klasöre indirir.
abstract final class QrReceiver {
  /// İndirilen dosyaların yollarını döndürür. Yarım kalan dosya silinir.
  static Future<List<String>> download(
    Uri base,
    String saveDir, {
    void Function(String name, int received, int total)? onProgress,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final out = <String>[];
    try {
      final listReq = await client.getUrl(base.resolve('list'));
      final listRes = await listReq.close();
      if (listRes.statusCode != 200) throw const HttpException('list');
      final list = jsonDecode(await listRes.transform(utf8.decoder).join())
          as List<dynamic>;
      for (var i = 0; i < list.length; i++) {
        final name = FileOps.sanitizeName(list[i]['name'] as String? ?? '');
        final total = (list[i]['size'] as num?)?.toInt() ?? 0;
        final target = FileOps.uniquePath(
            p.join(saveDir, name.isEmpty ? 'dosya' : name));
        final res = await (await client.getUrl(base.resolve('$i'))).close();
        if (res.statusCode != 200) throw HttpException('$i');
        final file = File(target);
        await file.parent.create(recursive: true);
        final sink = file.openWrite();
        var received = 0;
        try {
          await for (final chunk in res) {
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(name, received, total);
          }
          await sink.flush();
        } catch (_) {
          await sink.close();
          await file.delete().catchError((_) => file);
          rethrow;
        }
        await sink.close();
        if (total > 0 && received < total) {
          await file.delete().catchError((_) => file);
          throw HttpException('short $name');
        }
        out.add(target);
      }
      return out;
    } finally {
      client.close(force: true);
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
