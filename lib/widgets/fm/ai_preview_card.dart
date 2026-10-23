import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/ai_buckets.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/entry_opener.dart';
import 'fm_entry_icon.dart';
import '../../core/app_colors.dart';

/// AI'nın bulduğu bir dosyanın **önizleme kartı** — küçük resim + ad.
///
/// AI sohbetinin kaynakları ve akıllı klasörler aynı kartı kullanır
/// (2026-10-18: *"direkt görüntüler önizleme şeklinde olmalı"*).
class AiPreviewCard extends StatelessWidget {
  final AiRecord record;

  /// Kartın genişliği (küçük resim kare).
  final double size;

  /// Köşede "yeni" rozeti (akıllı klasöre son bakıştan sonra gelen dosya).
  final bool isNew;

  const AiPreviewCard(
      {super.key, required this.record, this.size = 104, this.isNew = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = AiBuckets.entryOf(record);
    final isVideo = entry.category == FmCategory.video;
    return SizedBox(
      width: size,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => EntryOpener.open(context, record.path),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: Center(
                          child: FmEntryIcon(
                            entry: entry,
                            size: size,
                            radius: 0,
                          ),
                        ),
                      ),
                    ),
                    if (isNew)
                      PositionedDirectional(
                        top: 6,
                        start: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(context.t('smart.new_badge'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    if (isVideo)
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0x88000000),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(AppIcons.play,
                            color: AppColors.onMedia, size: 26),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                  child: Text(
                    record.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(height: 1.15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
