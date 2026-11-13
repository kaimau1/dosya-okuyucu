import '../core/app_navigator.dart';
import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import 'app_dialog.dart';

/// **AI'ya gönderim onayı** (Play yorum çalışması aşama 2, 2026-11-08).
///
/// Dosya metni Gemini'ye ilk gidişte sorulur: "Gönder" bu oturum boyunca
/// geçerli (500 dosyalık toplu analizde 500 pencere olmasın), "bir daha
/// sorma" kalıcı (`AppState.aiSendConsent`; Ayarlar › Gizlilik ve izinler'den
/// geri alınır). `AiPool.consent` kancası olarak `main` bağlar.
abstract final class AiSendConsent {
  static bool _session = false;
  static Future<bool>? _pending;

  /// Ayarda "göndermeden önce sor" yeniden açılınca oturum onayı da düşer.
  static void forget() => _session = false;

  /// G10.1: pencere açmadan rıza var mı (oturum ya da kalıcı).
  static bool granted(AppState state) => state.aiSendConsent || _session;

  static Future<bool> ask(AppState state) {
    if (state.aiSendConsent || _session) return Future.value(true);
    // Aynı anda gelen istekler tek pencereyi bekler.
    return _pending ??= _show(state).whenComplete(() => _pending = null);
  }

  static Future<bool> _show(AppState state) async {
    final context = navigatorKey.currentContext;
    // Ekran yok (arka plan): sorulmadan gönderilmez.
    if (context == null || !context.mounted) return false;
    final r = await showAppConfirmRemember(
      context,
      title: context.t('aisend.title'),
      message: context.t('aisend.body'),
      rememberLabel: context.t('aisend.remember'),
      confirmLabel: context.t('aisend.send'),
    );
    if (r == null) return false;
    _session = true;
    if (r.remember) await state.setAiSendConsent(true);
    return true;
  }
}
