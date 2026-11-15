import 'package:flutter/material.dart';

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
  static bool granted(AppState state) =>
      state.aiTermsAccepted && (state.aiSendConsent || _session);

  static Future<bool> ask(AppState state) {
    if (granted(state)) return Future.value(true);
    // Aynı anda gelen istekler tek pencereyi bekler.
    return _pending ??= _show(state).whenComplete(() => _pending = null);
  }

  static Future<bool> _show(AppState state) async {
    final context = navigatorKey.currentContext;
    // Ekran yok (arka plan): sorulmadan gönderilmez.
    if (context == null || !context.mounted) return false;
    // Önce bir kerelik kullanım koşulları / sorumluluk reddi (2026-11-15).
    if (!state.aiTermsAccepted) {
      if (!await AiTerms.show(context, state)) return false;
      if (!context.mounted) return false;
    }
    if (state.aiSendConsent || _session) return true;
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


/// **AI kullanım koşulları ve sorumluluk reddi** (kullanıcı kararı
/// 2026-11-15: "kullanılmadan önce sorumluluk reddi ve gerekli
/// bilgilendirmeler, izinler onaylatılmalı"). İlk AI kullanımında bir kez;
/// kutular işaretlenmeden "Kabul et" basılamaz.
abstract final class AiTerms {
  static const _boxes = [
    'aiterms.c_accuracy',
    'aiterms.c_data',
    'aiterms.c_key',
  ];

  static Future<bool> show(BuildContext context, AppState state) async {
    final ok = await showAppChecklistConfirm(
      context,
      title: context.t('aiterms.title'),
      message: context.t('aiterms.body'),
      checks: [for (final k in _boxes) context.t(k)],
      confirmLabel: context.t('aiterms.accept'),
    );
    if (!ok) return false;
    await state.setAiTermsAccepted(true);
    return true;
  }
}
