import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/theme.dart';
import '../motion.dart';
import 'fm_category_tile.dart';

/// **Araçlar — hap düğmeler** (2026-11-20, kullanıcı: *"araçlar alanı hiç
/// hoşuma gitmiyor, her şeyi değiştirdik ama hâlâ eski tipte"*).
///
/// Eski 4 sütunlu ızgara iki satırlık etiket yeri ayırıyordu ve son satır
/// yarım kalınca kocaman boş hücreler bırakıyordu. Haplar soldan akar, yer
/// kadar yer kaplar; etiket tek satırda tam okunur, canlı bilgi ("1 biten")
/// etiketin yanında küçük yazıyla durur. Ağır iş yok: sabit `Wrap`, ölçüm
/// yok, animasyon yok (kasma listesi m.1).
class FmToolPills extends StatelessWidget {
  final List<FmTileData> tools;

  /// Hepsi gösterilmiyorsa sondaki "Tümü" hapı.
  final String? allLabel;
  final VoidCallback? onAll;

  const FmToolPills({
    super.key,
    required this.tools,
    this.allLabel,
    this.onAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.sm,
        children: [
          for (final t in tools)
            _Pill(
              key: ValueKey('tool-pill-${t.id}'),
              tool: t,
              tint: dark
                  ? Color.lerp(t.color, AppColors.mixLight, 0.3)!
                  : t.color,
            ),
          if (onAll != null && allLabel != null)
            ActionChip(
              key: const ValueKey('tool-pill-all'),
              label: Text(allLabel!),
              onPressed: onAll,
              shape: const StadiumBorder(),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final FmTileData tool;
  final Color tint;
  const _Pill({super.key, required this.tool, required this.tint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressScale(
      child: Material(
        color: tint.withValues(alpha: 0.10),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tool.gatedTap(context),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                tool.badged(Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tool.icon, size: 18, color: tint),
                )),
                const SizedBox(width: Gap.sm),
                Flexible(
                  child: Text(tool.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (tool.subtitle.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(tool.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
