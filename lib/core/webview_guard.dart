import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// **WebView sertleştirme** (Güvenlik G6.2–G6.4, 2026-11-12).
///
/// Uygulamadaki iki WebView (Word görüntüleyici, yerel sinirsel ses motoru)
/// güvenilmeyen içerik (belgedeki bağlantı, görsel adresi) işler. Kurallar:
/// * Gezinti yalnız kendi sayfasına; belgedeki `http/https/mailto`
///   bağlantısı WebView'ı DEĞİŞTİRMEZ — tam adres gösterilip sorulur, kabul
///   edilirse dış tarayıcıda açılır. `file:`, `content:`, `intent:`,
///   `javascript:` hiç açılmaz.
/// * Android: dosya/içerik erişimi kapalı (`file:///android_asset` bundan
///   etkilenmez — Android belgesi), konum kapalı, karışık içerik yok.
/// * JS kanal mesajı en çok [maxChannelMessage] karakter.
abstract final class WebViewGuard {
  /// Kanal mesajı üst sınırı (G6.4).
  static const maxChannelMessage = 256 * 1024;

  /// Dış uygulamaya verilebilecek şemalar.
  static const externalSchemes = {'http', 'https', 'mailto'};

  /// [url] gezinmesine izin verilir mi? [allowed] sayfanın kendi kökeni ya da
  /// yolu: `file:` için yol SONU (`/assets/word/viewer.html`), diğerlerinde
  /// önek (`http://127.0.0.1:1234/`).
  @visibleForTesting
  static bool allowNavigation(String url, String allowed) {
    final u = Uri.tryParse(url);
    if (u == null) return false;
    if (url == 'about:blank') return true;
    if (u.scheme == 'file') {
      // Yalnız APK içi varlık (file:///android_asset/…); depodaki aynı adlı
      // dosya sayılmaz.
      return u.host.isEmpty &&
          u.path.startsWith('/android_asset/') &&
          u.path.endsWith(allowed);
    }
    if (!allowed.contains('://')) return false;
    final a = Uri.parse(allowed);
    return u.scheme == a.scheme &&
        u.host == a.host &&
        u.port == a.port &&
        u.path.startsWith(a.path);
  }

  /// Engellenen gezinme dışarıda açılabilir bir bağlantı mı?
  @visibleForTesting
  static Uri? externalLink(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !externalSchemes.contains(u.scheme)) return null;
    if (u.scheme != 'mailto' && u.host.isEmpty) return null;
    return u;
  }

  /// Kanal mesajı kabul edilebilir mi (boyut)?
  static bool acceptMessage(String m) => m.length <= maxChannelMessage;

  /// Gezinti kilidi: yalnız [allowed]; dış bağlantıda [onExternal].
  static NavigationDecision Function(NavigationRequest) navigationLock(
          String allowed,
          {void Function(Uri link)? onExternal}) =>
      (req) {
        if (allowNavigation(req.url, allowed)) {
          return NavigationDecision.navigate;
        }
        final ext = req.isMainFrame ? externalLink(req.url) : null;
        if (ext != null) onExternal?.call(ext);
        return NavigationDecision.prevent;
      };

  /// Android ayarları (G6.3). Diğer platformlarda sessiz geçer.
  static Future<void> harden(WebViewController c) async {
    final p = c.platform;
    if (p is! AndroidWebViewController) return;
    await p.setAllowFileAccess(false);
    await p.setAllowContentAccess(false);
    await p.setGeolocationEnabled(false);
    await p.setMixedContentMode(MixedContentMode.neverAllow);
  }
}
