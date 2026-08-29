import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/tts_service.dart';
import '../../widgets/tts_voice_sheet.dart';
import 'settings_widgets.dart';

/// **Sesli okuma ayarları — Ayarlar'da (2026-08-29).**
///
/// Kök neden: `TtsPrefs` (ses, hız, perde) ve "AI yanıtlarını sesli oku"
/// tercihleri uygulamada VARDI ve çalışıyordu, ama tek giriş kapısı okuyucu
/// ekranının içindeki alt sayfaydı. Yani kullanıcı bir belge açıp sesli okumayı
/// başlatmadan sesini seçemiyordu; Ayarlar'da arayan hiçbir şey bulamıyordu.
/// Aynı alt sayfa (`TtsVoiceSheet`) buradan da açılıyor — ikinci bir arayüz
/// yazılmadı, iki yol aynı tercihi yazıyor.
class TtsVoiceTile extends StatelessWidget {
  const TtsVoiceTile({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppState>().ttsPrefs;
    return SettingTile(
      icon: Icons.record_voice_over_outlined,
      title: context.t('set.tts_voice'),
      subtitle: context.t('set.tts_voice_sub'),
      wrapSubtitle: true,
      // Değer satırı: seçili ses yoksa "cihaz varsayılanı" YAZILIR — boş
      // bırakmak "ayarlanmamış mı, bozuk mu" sorusunu doğururdu.
      value: _summary(context, prefs),
      onTap: () => TtsVoiceSheet.show(context),
    );
  }

  String _summary(BuildContext context, TtsPrefs prefs) {
    final voice = prefs.voiceName.isEmpty
        ? context.t('set.tts_default_voice')
        : prefs.voiceName;
    return '$voice · ${prefs.rate.toStringAsFixed(1)}x';
  }
}

/// AI yanıtları geldiğinde kendiliğinden sesli okunsun mu?
///
/// Okuyucu ekranındaki menüde bir onay kutusu olarak duruyordu; oradan
/// KALDIRILMADI (alışkanlık bozulmasın), burada da açılıp kapanabiliyor —
/// ikisi de aynı `AppState.ttsAiRead` alanını yazıyor.
class TtsAiReadTile extends StatelessWidget {
  const TtsAiReadTile({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SettingSwitch(
      icon: Icons.campaign_outlined,
      title: context.t('set.tts_ai_read'),
      subtitle: context.t('set.tts_ai_read_sub'),
      value: state.ttsAiRead,
      onChanged: state.setTtsAiRead,
    );
  }
}
