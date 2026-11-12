import 'dart:convert';
import 'dart:io';

/// **Yerel sunucuların ortak güvenlik kapısı** (G4, 2026-11-11).
///
/// Telefonda açılan HTTP/FTP sunucuları (bilgisayara paylaşım, QR aktarım,
/// eşler arası alım, slayt kumandası) `0.0.0.0`'a bağlı. Belirli bir
/// arayüze bağlamak IP değişince (Wi-Fi yeniden bağlandı, erişim noktası
/// açıldı) sunucuyu sağır bırakırdı; onun yerine HER İSTEKTE karşı adres
/// denetlenir ([isPrivate]): mobil veri arayüzünden (genel ya da CGNAT
/// adres) gelen bağlantı 403 ile kapatılır.
abstract final class LanGuard {
  /// Yerel ağ adresi mi? Kabul: 10/8, 172.16/12, 192.168/16, 169.254/16,
  /// geri döngü; IPv6'da fe80::/10 (bağlantı-yerel), fc00::/7 (ULA), ::1 ve
  /// IPv4'e eşlenmiş IPv6. RED: genel adresler ve CGNAT 100.64/10
  /// (operatör ağı — aynı operatördeki başka aboneler).
  static bool isPrivate(InternetAddress address) {
    var raw = address.rawAddress;
    if (address.type == InternetAddressType.IPv6) {
      // ::ffff:a.b.c.d
      var mapped = raw.length == 16;
      for (var i = 0; i < 10 && mapped; i++) {
        if (raw[i] != 0) mapped = false;
      }
      if (mapped && raw[10] == 0xff && raw[11] == 0xff) {
        raw = raw.sublist(12);
      } else {
        if (address.isLoopback) return true;
        if (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80) return true; // fe80::/10
        if ((raw[0] & 0xfe) == 0xfc) return true; // fc00::/7
        return false;
      }
    }
    if (raw.length != 4) return false;
    final a = raw[0], b = raw[1];
    if (a == 127) return true;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    if (a == 169 && b == 254) return true;
    return false;
  }

  /// İsteğin karşı adresi yerel ağda değilse 403 yazıp kapatır ve false döner.
  static Future<bool> admit(HttpRequest request) async {
    final remote = request.connectionInfo?.remoteAddress;
    if (remote != null && isPrivate(remote)) return true;
    final res = request.response;
    try {
      res.statusCode = HttpStatus.forbidden;
      res.write('403');
      await res.close();
    } catch (_) {
      // Bilinçli: kapatma — zaten kapalıysa ya da kapanırken hata verirse yapılacak bir şey yok.
    }
    return false;
  }

  /// G4.5: aynı anda en çok bu kadar istek / FTP oturumu (fazlası 503 / 421).
  /// Tarayıcı bir sunucuya ≤ 6 bağlantı açar; 16 birkaç istemciye yeter.
  static const maxConcurrent = 16;

  /// G4.5: boşta bekleyen kalıcı bağlantı bu sürede kapanır (Dart varsayılanı
  /// 120 sn). Süren aktarımı etkilemez — yalnız istekler ARASI boşluğu sayar.
  static const idleTimeout = Duration(seconds: 60);

  /// Sunucuya ortak ayarlar: boşta zaman aşımı, `Server:` başlığı yok
  /// (sürüm bilgisi sızdırmasın).
  static void harden(HttpServer server) {
    server.idleTimeout = idleTimeout;
    server.serverHeader = null;
  }

  /// Sabit zamanlı metin karşılaştırma (uzunluk farkı da sızdırmaz: kısa
  /// olan döngü boyunca tamamlanır).
  static bool safeEquals(String a, String b) {
    final x = utf8.encode(a), y = utf8.encode(b);
    var diff = x.length ^ y.length;
    final n = x.length > y.length ? x.length : y.length;
    for (var i = 0; i < n; i++) {
      final p = i < x.length ? x[i] : 0;
      final q = i < y.length ? y[i] : 0;
      diff |= p ^ q;
    }
    return diff == 0;
  }

  /// HTML ve JSON yanıtlarına güvenlik başlıkları (G4.6). [script] true ise
  /// sayfanın KENDİ satır içi betiğine izin verilir (dış kaynak yine yok).
  static void secureHeaders(HttpResponse res, {bool script = false}) {
    final h = res.headers;
    h.set('X-Content-Type-Options', 'nosniff');
    h.set('X-Frame-Options', 'DENY');
    h.set('Referrer-Policy', 'no-referrer');
    h.set(HttpHeaders.cacheControlHeader, 'no-store');
    h.set(
        'Content-Security-Policy',
        "default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:; "
            "media-src 'self'; form-action 'self'; frame-ancestors 'none'"
            "${script ? "; script-src 'unsafe-inline'; connect-src 'self'" : ''}");
  }

  /// Durum değiştiren istek (yükleme, silme) başka bir siteden mi geliyor
  /// (G4.7, CSRF / DNS yeniden bağlama)? `Host` sunucunun yerel adresi
  /// olmalı; `Origin` varsa aynı ana bilgisayarı göstermeli. Tarayıcı
  /// dışı istemci (Origin yok) geçer — o zaten kimlik bilgisini kendi taşır.
  static bool sameOrigin(HttpRequest request) {
    final host = request.headers.host;
    if (host == null) return false;
    if (host != 'localhost') {
      final hostAddr = InternetAddress.tryParse(host);
      if (hostAddr == null || !isPrivate(hostAddr)) return false;
    }
    final origin = request.headers.value('origin');
    if (origin == null) return true;
    final o = Uri.tryParse(origin);
    return o != null && o.host == host;
  }
}

/// **Eşzamanlı istek sınırı** (G4.5): [limit] istek sürerken gelen yenisi
/// 503 ile hemen kapatılır — tek bir istemcinin yüzlerce bağlantıyla
/// telefonun belleğini/dosya tanıtıcılarını tüketmesini önler.
class RequestGate {
  RequestGate({this.limit = LanGuard.maxConcurrent});

  final int limit;
  int _active = 0;

  /// Şu an süren istek sayısı.
  int get active => _active;

  /// [body]yi sınır içindeyse koşturur; doluysa 503 yazar.
  Future<void> run(HttpRequest request, Future<void> Function() body) async {
    if (_active >= limit) {
      final res = request.response;
      try {
        res.statusCode = HttpStatus.serviceUnavailable;
        res.headers.set(HttpHeaders.retryAfterHeader, '2');
        await res.close();
      } catch (_) {
        // Bilinçli: kapatma — istemci zaten gitmiş olabilir.
      }
      return;
    }
    _active++;
    try {
      await body();
    } finally {
      _active--;
    }
  }
}

/// **Deneme sınırı** (G4.3/G4.4): karşı adres başına [limit] hatalı
/// denemeden sonra [block] süresince reddedilir. Doğru deneme o adresin
/// sayacını sıfırlar. Bellekte (sunucu ömrü kadar).
class AuthThrottle {
  AuthThrottle({
    this.limit = 10,
    this.block = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int limit;
  final Duration block;
  final DateTime Function() _clock;
  final _fails = <String, int>{};
  final _until = <String, DateTime>{};

  bool blocked(String ip) {
    final until = _until[ip];
    if (until == null) return false;
    if (_clock().isBefore(until)) return true;
    _until.remove(ip);
    _fails.remove(ip);
    return false;
  }

  /// Hatalı deneme; bu denemeyle sınır dolduysa true.
  bool fail(String ip) {
    final n = (_fails[ip] ?? 0) + 1;
    _fails[ip] = n;
    if (n >= limit) {
      _until[ip] = _clock().add(block);
      return true;
    }
    // Sözlük sınırsız büyümesin (adres taklidiyle bellek doldurma).
    if (_fails.length > 1024) _fails.remove(_fails.keys.first);
    return false;
  }

  void success(String ip) {
    _fails.remove(ip);
    _until.remove(ip);
  }
}
