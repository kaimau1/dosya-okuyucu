import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../services/tts_service.dart';

/// **Sesli okuma ayarları** — ses seçimi, hız, perde.
///
/// Kullanıcı isteği 2026-08-06: *"sesli okuma çok kalitesiz, ses seçimi olmalı
/// notlar uygulamadaki gibi."* Not uygulamalarının yaptığı da tam olarak bu:
/// cihazda kurulu sesleri listele, dinlet, seçileni hatırla. Kaliteyi belirleyen
/// motor değil hangi sesin kullanıldığıdır ve varsayılan çoğu zaman en robotik
/// olanıdır.
///
/// Liste boşsa (motor ses listesi vermiyorsa) ayar yine çalışır: hız/perde
/// uygulanır, ses "cihaz varsayılanı" kalır — boş bir sayfa göstermek yerine.
class TtsVoiceSheet extends StatefulWidget {
  const TtsVoiceSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const TtsVoiceSheet(),
      );

  @override
  State<TtsVoiceSheet> createState() => _TtsVoiceSheetState();
}

class _TtsVoiceSheetState extends State<TtsVoiceSheet> {
  /// Önizleme için ayrı bir servis: ekrandaki okuma sürüyorsa onu bozmasın
  /// diye kendi motor örneğiyle konuşur.
  final _preview = TtsService();

  List<TtsVoiceInfo>? _voices;
  late TtsPrefs _prefs = context.read<AppState>().ttsPrefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Önce arayüz dilinin sesleri; hiç yoksa tüm sesler (kullanıcı İngilizce
    // bir belgeyi İngilizce sesle dinlemek isteyebilir).
    var list = await TtsService.voices(languagePrefix: 'tr');
    if (list.isEmpty) list = await TtsService.voices();
    if (mounted) setState(() => _voices = list);
  }

  Future<void> _save(TtsPrefs value) async {
    setState(() => _prefs = value);
    await context.read<AppState>().setTtsPrefs(value);
  }

  Future<void> _tryVoice() async {
    _preview.prefs = _prefs;
    await _preview.preview(AppStrings.of(context).t('tts.sample'));
  }

  @override
  Widget build(BuildContext context) {
    final voices = _voices;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('tts.settings'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Gap.sm),
            if (voices == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Gap.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (voices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                child: Text(context.t('tts.no_voices'),
                    style: Theme.of(context).textTheme.bodySmall),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    RadioListTile<String>(
                      value: '',
                      groupValue: _prefs.voiceName,
                      dense: true,
                      title: Text(context.t('tts.default_voice')),
                      onChanged: (_) => _save(
                          _prefs.copyWith(voiceName: '', voiceLocale: '')),
                    ),
                    for (final voice in voices)
                      RadioListTile<String>(
                        value: voice.name,
                        groupValue: _prefs.voiceName,
                        dense: true,
                        title: Text(voice.label,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(voice.locale),
                        onChanged: (_) => _save(_prefs.copyWith(
                            voiceName: voice.name, voiceLocale: voice.locale)),
                      ),
                  ],
                ),
              ),
            const Divider(),
            _slider(
              label: context.t('tts.rate'),
              value: _prefs.rate,
              onChanged: (v) => setState(() => _prefs = _prefs.copyWith(rate: v)),
              onDone: () => _save(_prefs),
            ),
            _slider(
              label: context.t('tts.pitch'),
              value: _prefs.pitch,
              onChanged: (v) =>
                  setState(() => _prefs = _prefs.copyWith(pitch: v)),
              onDone: () => _save(_prefs),
            ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _tryVoice,
                    icon: const Icon(Icons.volume_up_outlined),
                    label: Text(context.t('tts.try')),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.t('common.ok')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required VoidCallback onDone,
  }) =>
      Row(
        children: [
          SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: Slider(
              value: value.clamp(0.5, 2.0),
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${value.toStringAsFixed(2)}×',
              onChanged: onChanged,
              // Kaydırma SÜRERKEN kaydetmiyoruz: her karede
              // SharedPreferences yazmak diski gereksiz yorar.
              onChangeEnd: (_) => onDone(),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('${value.toStringAsFixed(1)}×',
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      );
}
