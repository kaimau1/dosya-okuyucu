import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/edition.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/fs_entry.dart';
import '../../models/media_resize.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/video_shrink_estimate.dart';
import '../pro_gate.dart';

/// Video satırında **tek dokunuşla boyut düşür** hapı: "⇲ ≈ 320 MB"
/// (2026-11-25, kullanıcı: *"büyük dosyalarda videolara boyut düşür seçeneği
/// koyalım ve tahmini boyutu yazalım"*).
///
/// Tahmin hazır olana dek yalnız "Küçült" yazar (satır beklemez); ölçülemezse
/// de öyle kalır. Dokununca [onTap] (ayar sayfası açılır, iş kuyruğa gider).
/// Lite sürümde tahmin çalıştırılmaz, hapın yanında PRO rozeti gösterilir.
class VideoShrinkPill extends StatefulWidget {
  final FsEntry entry;
  final VoidCallback onTap;

  const VideoShrinkPill({super.key, required this.entry, required this.onTap});

  @override
  State<VideoShrinkPill> createState() => _VideoShrinkPillState();
}

class _VideoShrinkPillState extends State<VideoShrinkPill> {
  Future<int?>? _estimate;

  @override
  void initState() {
    super.initState();
    if (!ProGate.locked(Feature.videoCompress)) {
      _estimate = VideoShrinkEstimate.of(widget.entry);
    }
  }

  @override
  void didUpdateWidget(VideoShrinkPill old) {
    super.didUpdateWidget(old);
    if (ProGate.locked(Feature.videoCompress)) {
      _estimate = null;
      return;
    }
    if (_estimate == null ||
        old.entry.path != widget.entry.path ||
        old.entry.sizeBytes != widget.entry.sizeBytes) {
      _estimate = VideoShrinkEstimate.of(widget.entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ProGate.locked(Feature.videoCompress);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FutureBuilder<int?>(
      future: locked ? null : _estimate,
      builder: (context, snap) {
        // Kazanç anlamlıysa (≥ %25) tahmini boyut, yoksa düz "Küçült".
        final est = !locked &&
                MediaResizeOptions.worthShrinking(
                    widget.entry.sizeBytes, snap.data)
            ? snap.data
            : null;
        final label = est != null
            ? '≈ ${FsPaths.humanSize(est)}'
            : context.t('vsp.shrink');
        return Tooltip(
          message: est != null
              ? context.t('vsp.tooltip', {
                  'from': FsPaths.humanSize(widget.entry.sizeBytes),
                  'to': FsPaths.humanSize(est),
                })
              : context.t('ea.resize'),
          child: Material(
            key: ValueKey('vsp-${widget.entry.path}'),
            color: cs.secondaryContainer.withValues(alpha: 0.7),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.shrink,
                          size: 16, color: cs.onSecondaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        maxLines: 1,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        const ProBadge(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
