import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../services/fm/fs_scan.dart' show FsPaths;
import '../../services/voice/neural_voices.dart';

/// **Yapay zekâ sesleri** — indir / sil (Ayarlar > Okuma ve sesli kitap
/// ekranından). Sesler APK'da değil: kullanıcı istediği zaman indirir.
class VoicesScreen extends StatelessWidget {
  const VoicesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.t('voice.title'))),
        body: ListenableBuilder(
          listenable: NeuralVoiceStore.instance,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(Gap.md),
            children: [
              Text(context.t('voice.intro'),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: Gap.md),
              for (final v in NeuralVoice.values) VoiceCard(voice: v),
            ],
          ),
        ),
      );
}

/// Bir sesin kartı: durum + indir/sil düğmesi (sesli kitap ekranında da).
class VoiceCard extends StatelessWidget {
  final NeuralVoice voice;
  final bool selected;
  final VoidCallback? onSelect;

  const VoiceCard(
      {super.key, required this.voice, this.selected = false, this.onSelect});

  Future<void> _install(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    try {
      await NeuralVoiceStore.instance.install(voice);
      showSnackOn(messenger, strings.t('voice.installed', {'name': voice.label}));
    } catch (e) {
      showSnackOn(messenger,
          strings.t('voice.install_failed', {'error': userErrorText(e)}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = NeuralVoiceStore.instance;
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
                  if (installed)
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
                      child: Text(context.t('voice.install', {
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
                    context.t('voice.installed_size', {
                      'size': FsPaths.humanSize(store.installedBytes(voice)),
                    }),
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
