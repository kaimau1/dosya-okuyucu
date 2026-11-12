import 'dart:io';

import 'package:dio/dio.dart';

import 'lan_guard.dart';
import 'remote_fs.dart';
import '../../offline_mode.dart';

/// **WebDAV taşıma güvenliği (G8.3, 2026-11-12).**
///
/// Kök neden: `webdav_client` 1.2.2 302 yanıtında `Location`'daki adrese —
/// başka ana makine ya da `http` olsa bile — isteği TEKRARLIYOR ve her
/// tekrarda `authorization` başlığını yeniden ekliyor (`WdDio.req`); sınır da
/// yok (sonsuz yönlendirme = sonsuz özyineleme). Kötü niyetli ya da ele
/// geçirilmiş bir sunucu tek yönlendirmeyle parolayı üçüncü bir sunucuya
/// aldırabilirdi.
///
/// Karar: köken (şema + ana makine + port) dışına giden her istek REDDEDİLİR
/// (kimliği düşürüp devam etmek Digest `stale` yanıtında sonsuz döngü
/// açıyordu); aynı kökende de art arda en çok [maxRedirects] yönlendirme.
abstract final class WebDavGuard {
  static const maxRedirects = 5;

  /// [base] kökenli oturumda [target]'a istek atılabilir mi?
  static bool sameOrigin(Uri base, Uri target) {
    final s = target.scheme.toLowerCase();
    if (s != 'http' && s != 'https') return false;
    return s == base.scheme.toLowerCase() &&
        target.host.toLowerCase() == base.host.toLowerCase() &&
        target.port == base.port;
  }

  /// `http://` adrese parola gönderilebilir mi? Yalnız adres(ler) yerel
  /// ağdaysa: özel IPv4/IPv6, geri döngü, bağlantı-yerel ve 100.64/10
  /// (Tailscale gibi şifreli tüneller bu aralığı kullanır; hedef olarak
  /// operatör CGNAT'ı anlamlı değil). Ad önce çözülür: `nas.ornek.com` iç
  /// DNS'te 192.168.x'e gidiyorsa izinli.
  static bool plainHttpAllowed(List<InternetAddress> addresses) {
    if (addresses.isEmpty) return false;
    for (final a in addresses) {
      if (LanGuard.isPrivate(a)) continue;
      final r = a.rawAddress;
      if (a.type == InternetAddressType.IPv4 &&
          r[0] == 100 &&
          (r[1] & 0xc0) == 64) {
        continue;
      }
      return false;
    }
    return true;
  }

  /// [baseUrl] `http` ve kimlik varsa, ana makine yerel ağda değilse
  /// [RemoteError.insecure] fırlatır. Ad çözülemezse sessiz geçer — asıl
  /// bağlantı denemesi "ulaşılamadı" hatasını zaten verir.
  static Future<void> checkPlainHttp(String baseUrl,
      {required bool hasCredentials,
      Future<List<InternetAddress>> Function(String host)? lookup}) async {
    final uri = Uri.parse(baseUrl);
    if (uri.scheme != 'http' || !hasCredentials) return;
    final host = uri.host.replaceAll(RegExp(r'^\[|\]$'), '');
    final ip = InternetAddress.tryParse(host);
    List<InternetAddress> addrs;
    if (ip != null) {
      addrs = [ip];
    } else {
      if (OfflineMode.isLocalHost(host)) return; // .local / noktasız NAS adı
      try {
        addrs = await (lookup ?? InternetAddress.lookup)(host);
      } catch (_) {
        return;
      }
    }
    if (!plainHttpAllowed(addrs)) {
      throw RemoteException(RemoteError.insecure, detail: 'plain http: $host');
    }
  }
}

/// `webdav_client`'ın dio'suna takılan bekçi: köken dışı istek ve aşırı
/// yönlendirme ağdan ÖNCE kesilir.
class WebDavGuardInterceptor extends Interceptor {
  WebDavGuardInterceptor(this.base);

  final Uri base;
  int _hops = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!WebDavGuard.sameOrigin(base, options.uri)) {
      handler.reject(DioException(
        requestOptions: options,
        error: RemoteException(RemoteError.insecure,
            detail: 'cross-origin: ${options.uri.host}'),
      ));
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final code = response.statusCode ?? 0;
    if (code >= 300 && code < 400) {
      if (++_hops > WebDavGuard.maxRedirects) {
        _hops = 0;
        handler.reject(DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: const RemoteException(RemoteError.insecure,
              detail: 'too many redirects'),
        ));
        return;
      }
    } else {
      _hops = 0;
    }
    handler.next(response);
  }
}

/// dio sarmalını açar: bekçinin [RemoteException]'ı olduğu gibi döner.
RemoteException mapWebDavError(Object error) {
  if (error is DioException && error.error is RemoteException) {
    return error.error! as RemoteException;
  }
  return RemoteFs.mapError(error);
}
