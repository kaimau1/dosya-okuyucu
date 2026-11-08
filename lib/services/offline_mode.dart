import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../core/l10n/app_strings.dart';

/// **Çevrimdışı kip** (Play yorum çalışması aşama 2, 2026-11-08).
///
/// Açıkken uygulama internete ÇIKMAZ: AI (Gemini), bulut (Drive), altyazı,
/// ses/model indirme. Yerel ağ (NAS, yakındaki cihaz, QR aktarım) serbest —
/// veri telefondan internete gitmez. Tanılama zaten ağ açmaz (paylaşımı
/// kullanıcı seçer).
///
/// Tek kesim noktası: `main` tüm uygulamayı `http.runWithClient` içinde
/// [OfflineAwareClient] ile koşturur; `package:http`'in üst düzey işlevleri ve
/// `http.Client()` bu istemciyi kullanır — çağrı yerlerine tek tek bekçi
/// koymak gerekmez. `AppState` ayarı yükleyince/değişince [enabled]ı yazar.
class OfflineMode {
  OfflineMode._();

  static bool enabled = false;

  /// Yerel ağ adresi mi? (Çevrimdışı kipte de izinli.)
  static bool isLocalHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h.endsWith('.local') || h.endsWith('.lan')) {
      return true;
    }
    final ip = InternetAddress.tryParse(h.replaceAll(RegExp(r'^\[|\]$'), ''));
    if (ip == null) return false;
    if (ip.isLoopback || ip.isLinkLocal) return true;
    final b = ip.rawAddress;
    if (ip.type == InternetAddressType.IPv4) {
      return b[0] == 10 ||
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 && b[1] == 168);
    }
    return (b[0] & 0xfe) == 0xfc; // IPv6 ULA fc00::/7
  }

  /// İnternete çıkılacaksa ve kip açıksa [OfflineException] atar.
  static void check(Uri url) {
    if (enabled && !isLocalHost(url.host)) throw const OfflineException();
  }
}

class OfflineException implements Exception {
  const OfflineException();

  String get message => AppStrings.current.t('offline.blocked');

  @override
  String toString() => message;
}

/// Uygulamanın varsayılan HTTP istemcisi: önce [OfflineMode.check].
class OfflineAwareClient extends http.BaseClient {
  // ponytail: IOClient doğrudan — http.Client() bu bölgede kendini döndürürdü.
  final http.Client _inner = IOClient();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    OfflineMode.check(request.url);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
