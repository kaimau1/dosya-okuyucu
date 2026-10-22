import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';

/// Eski ikili Office dosyasının (`.doc`, `.ppt`) üstündeki şerit:
/// **"Salt okunur"** rozeti + **"DOCX'e dönüştür ve düzenle"** düğmesi
/// (Faz 9, §3.10). Eskiden metnin başına gömülü Türkçe bir cümle yazılıyordu;
/// İngilizce/Arapça arayüzde de Türkçe kalıyor, düzenleme yolunu da
/// göstermiyordu.
class LegacyBanner extends StatelessWidget {
  /// Eski uzantı (`doc`, `ppt`…).
  final String ext;

  /// Hedef modern uzantı (`docx`, `pptx`).
  final String target;
  final VoidCallback? onConvert;
  final bool busy;

  const LegacyBanner({
    super.key,
    required this.ext,
    required this.target,
    required this.onConvert,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 6),
        // İki satır: dar ekranda (320 dp) uzun çeviri düğmeyi taşırmasın.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.t('legacy.read_only'),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('legacy.body', {'ext': ext.toUpperCase()}),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : FilledButton.tonal(
                      onPressed: onConvert,
                      child: Text(context
                          .t('legacy.convert', {'ext': target.toUpperCase()})),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
