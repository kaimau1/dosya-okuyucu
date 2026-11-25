import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../services/fm/fs_scan.dart' show FsPaths;
import '../../services/voice/azure_tts.dart';
import '../../services/voice/neural_voices.dart';
import '../../widgets/app_dialog.dart';

/// **Yapay zekâ sesleri** — indir / sil (Ayarlar > Okuma ve sesli kitap
/// ekranından). Sesler APK'da değil: kullanıcı istediği zaman indirir.
class VoicesScreen extends StatelessWidget {
  const VoicesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.t('voice.title'))),
        body: ListenableBuilder(
          listenable: NeuralVoiceStore.instance,
          builder: (context, _) {
            final prefs = context.watch<AppState>().ttsPrefs;
            return ListView(
              padding: const EdgeInsets.all(Gap.md),
              children: [
                Text(context.t('voice.intro'),
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: Gap.md),
                // Kurulu ses buradan da sesli okuma sesi yapılır (2026-10-23:
                // "iniyor ama seçemiyorum").
                for (final v in NeuralVoice.usable)
                  VoiceCard(
                    voice: v,
                    selected: NeuralVoiceId.parse(prefs.voiceName) == v,
                    selectHint: true,
                    onSelect: () {
                      final id = NeuralVoiceId.of(v);
                      final state = context.read<AppState>();
                      state.setTtsPrefs(prefs.voiceName == id
                          ? prefs.copyWith(voiceName: '', voiceLocale: '')
                          : prefs.copyWith(
                              voiceName: id, voiceLocale: v.locale));
                    },
                  ),
              ],
            );
          },
        ),
      );
}

/// Bir sesin kartı: durum + indir/sil düğmesi (sesli kitap ekranında da).
class VoiceCard extends StatelessWidget {
  final NeuralVoice voice;
  final bool selected;
  final VoidCallback? onSelect;

  /// Kurulu kartta "sesli okumada kullan" satırı gösterilsin mi (Ayarlar >
  /// Yapay zekâ sesleri ekranı).
  final bool selectHint;

  const VoiceCard(
      {super.key,
      required this.voice,
      this.selected = false,
      this.onSelect,
      this.selectHint = false});

  Future<void> _install(BuildContext context) async {
    if (voice.isOnline) {
      await showAzureKeyDialog(context);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    try {
      await NeuralVoiceStore.instance.install(voice);
      showSnackOn(
          messenger, strings.t('voice.installed', {'name': voice.label}));
    } catch (e) {
      showSnackOn(messenger,
          strings.t('voice.install_failed', {'error': userErrorText(e)}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = NeuralVoiceStore.instance;
    if (voice.isOnline && !AzureTts.loaded) {
      // Anahtar bir kez okunur; okununca kart yeniden çizilir.
      AzureTts.load().then((_) => store.refresh()).ignore();
    }
    final installed = store.isInstalled(voice);
    final progress = store.progressOf(voice);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: installed ? onSelect : null,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(selected ? AppIcons.checkCircle : AppIcons.voice,
                      color: scheme.primary),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(voice.label,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (installed && voice.isOnline)
                    IconButton(
                      key: ValueKey('voice-remove-${voice.name}'),
                      tooltip: context.t('voice.azure_remove'),
                      icon: const Icon(AppIcons.delete),
                      onPressed: () async {
                        await AzureTts.save(key: '', region: AzureTts.region);
                        store.refresh();
                      },
                    )
                  else if (installed)
                    IconButton(
                      key: ValueKey('voice-remove-${voice.name}'),
                      tooltip: context.t('common.delete'),
                      icon: const Icon(AppIcons.delete),
                      onPressed: () => store.remove(voice),
                    )
                  else if (progress == null)
                    FilledButton.tonal(
                      key: ValueKey('voice-install-${voice.name}'),
                      onPressed: () => _install(context),
                      child: Text(voice.isOnline
                          ? context.t('voice.azure_setup')
                          : context.t('voice.install', {
                              'size': FsPaths.humanSize(voice.approxBytes),
                            })),
                    ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(context.t(voice.descriptionKey),
                  style: Theme.of(context).textTheme.bodySmall),
              if (progress != null) ...[
                const SizedBox(height: Gap.sm),
                LinearProgressIndicator(value: progress),
              ],
              if (installed)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: Text(
                    [
                      if (voice.isOnline)
                        context.t('voice.online')
                      else
                        context.t('voice.installed_size', {
                          'size':
                              FsPaths.humanSize(store.installedBytes(voice)),
                        }),
                      if (selectHint)
                        context.t(selected
                            ? 'voice.reading_selected'
                            : 'voice.tap_to_use'),
                    ].join(' · '),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **Azure konuşma anahtarı** (Ahmet sesi): anahtar + bölge. Kaydedilince
/// ses "kurulu" olur. Anahtar yalnız bu telefonda şifreli saklanır. Ortak
/// levha ([showAppSheet]) — tasarım bekçisi elle `showDialog` istemez.
Future<void> showAzureKeyDialog(BuildContext context) async {
  final res = await showAppSheet<({String key, String region})>(
    context,
    title: context.t('voice.azure_title'),
    builder: (_) => const _AzureKeyForm(),
  );
  if (res == null) return;
  await AzureTts.save(key: res.key, region: res.region);
  NeuralVoiceStore.instance.refresh();
  if (context.mounted) {
    showSnack(context,
        context.t('voice.installed', {'name': NeuralVoice.ahmet.label}));
  }
}

class _AzureKeyForm extends StatefulWidget {
  const _AzureKeyForm();

  @override
  State<_AzureKeyForm> createState() => _AzureKeyFormState();
}

class _AzureKeyFormState extends State<_AzureKeyForm> {
  final _key = TextEditingController();
  late final _region = TextEditingController(text: AzureTts.region);
  String? _regionError;

  @override
  void dispose() {
    _key.dispose();
    _region.dispose();
    super.dispose();
  }

  void _save() {
    final r = _region.text.trim().toLowerCase();
    if (!AzureTts.validRegion(r)) {
      setState(() => _regionError = context.t('voice.azure_bad_region'));
      return;
    }
    final k = _key.text.trim();
    if (k.isEmpty) return;
    Navigator.of(context).pop((key: k, region: r));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('voice.azure_help'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Gap.md),
            TextField(
              key: const ValueKey('azure-key'),
              controller: _key,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.t('voice.azure_key'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Gap.sm),
            TextField(
              key: const ValueKey('azure-region'),
              controller: _region,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.t('voice.azure_region'),
                errorText: _regionError,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: Gap.md),
            FilledButton(
              key: const ValueKey('azure-save'),
              onPressed: _save,
              child: Text(context.t('common.save')),
            ),
          ],
        ),
      );
}
