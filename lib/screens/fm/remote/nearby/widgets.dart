part of '../nearby_screen.dart';

/// Durum kartındaki küçük "yayında" halkası.
class _Radar extends StatefulWidget {
  final bool active;

  const _Radar({required this.active});

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Radar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = WidgetsBinding.instance.platformDispatcher
        .accessibilityFeatures.disableAnimations;
    if (widget.active && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.active ? scheme.primary : scheme.outline;
    return SizedBox.square(
      dimension: 56,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _RadarPainter(color, widget.active ? _c.value : 0),
          child: Center(child: Icon(AppIcons.device, color: color)),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Color color;
  final double t;

  _RadarPainter(this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r * 0.62, Paint()..color = color.withValues(alpha: 0.12));
    if (t > 0) {
      for (final k in [0.0, 0.5]) {
        final v = (t + k) % 1.0;
        canvas.drawCircle(
          c,
          r * (0.62 + 0.38 * v),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: (1 - v) * 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;
  final VoidCallback? onTap;

  const _Pill({required this.icon, required this.label, required this.ok, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = ok ? Paper.success(context) : scheme.onSurfaceVariant;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  final String name;
  final bool wifi;
  final bool ble;

  /// Süren gönderim var: soluk görünür (dokunmak nedenini söyler).
  final bool busy;
  final VoidCallback onTap;

  /// Güvenilen cihaz: adın yanında rozet (teklifi sorulmadan alınır).
  final bool trusted;

  const _PeerAvatar({
    required this.name,
    required this.wifi,
    required this.ble,
    required this.onTap,
    this.busy = false,
    this.trusted = false,
  });

  static const _hues = [
    AppHues.jade, AppHues.tangerine, AppHues.purple, AppHues.green,
    AppHues.red, AppHues.olive, AppHues.cyan, AppHues.plum,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hue = _hues[name.hashCode.abs() % _hues.length];
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return SizedBox(
      width: 84,
      child: Opacity(
        opacity: busy ? 0.45 : 1,
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: hue.withValues(alpha: 0.16),
                    foregroundColor: hue,
                    child: Text(initial,
                        style: theme.textTheme.headlineSmall?.copyWith(color: hue)),
                  ),
                  PositionedDirectional(
                    end: -4,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (wifi) Icon(AppIcons.wifi, size: 12, color: scheme.primary),
                          if (ble) Icon(AppIcons.bluetooth, size: 12, color: scheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
              if (trusted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.verified, size: 12, color: Paper.success(context)),
                    const SizedBox(width: 2),
                    Text(context.t('near.trusted_badge'),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Paper.success(context))),
                  ],
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// "Ne gönderilecek?" adımının büyük eylem kutusu (Dosya / Klasör / Yazı):
/// simge üstte, ad altta, en az 64 dp yüksek — tek elle rahat dokunulur.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(Radii.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: Gap.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: scheme.onSecondaryContainer),
                const SizedBox(height: Gap.xs),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.onSecondaryContainer)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölüm başlığı yerine adım başlığı ("1 · Ne gönderilecek?") + alt satır.
class _StepHeader extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;

  const _StepHeader({required this.title, this.sub, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SelectedTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _SelectedTile({super.key, required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDir = FileSystemEntity.isDirectorySync(path);
    final name = p.basename(path);
    final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
    final c = isDir ? FmCategory.folder : FsEntry.categoryForExtension(ext);
    final (glyph, color) = isDir
        ? (AppIcons.folder, FmColors.folder)
        : FmColors.forExtension(ext) ?? (FmColors.iconFor(c), FmColors.forCategory(c));
    final isImage = c == FmCategory.image;
    return SizedBox(
      width: 76,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.control),
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: isImage
                        ? Image.file(File(path),
                            fit: BoxFit.cover,
                            cacheWidth: 160,
                            errorBuilder: (_, __, ___) =>
                                Center(child: Icon(glyph, color: color)))
                        : Center(child: Icon(glyph, color: color, size: 30)),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall),
            ],
          ),
          PositionedDirectional(
            top: 2,
            end: 2,
            child: Material(
              color: scheme.surface.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(AppIcons.close, size: 14, color: scheme.onSurface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Süren aktarım kartı (gönderim ya da alım): başlık + toplam, isteğe bağlı
/// eylem (Durdur), altında dosya satırları.
class _TransferCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? detail;
  final Color tint;
  final Widget? action;
  final List<Widget> rows;

  const _TransferCard({
    super.key,
    required this.icon,
    required this.title,
    required this.tint,
    required this.rows,
    this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: Card(
        margin: EdgeInsets.zero,
        color: tint.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall),
                        if (detail != null)
                          Text(detail!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              for (final r in rows) ...[const SizedBox(height: Gap.md), r],
            ],
          ),
        ),
      ),
    );
  }
}

/// Süren aktarımın tek dosya satırı (iki yönde de): simge + tek satır ad +
/// "aktarılan / toplam · %" + kendi çubuğu; biten dosyada onay işareti.
class _TransferFileRow extends StatelessWidget {
  final String name;
  final int done;
  final int total;

  const _TransferFileRow({
    super.key,
    required this.name,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fraction = total > 0 ? (done / total).clamp(0.0, 1.0) : null;
    final finished = total > 0 && done >= total;
    final category = FsEntry.categoryForExtension(
        p.extension(name).replaceFirst('.', '').toLowerCase());
    final color = FmColors.forCategory(category);
    final detail = finished
        ? '${FsPaths.humanSize(total)} · ${context.t('near.file_done')}'
        : total > 0
            ? '${FsPaths.humanSize(done)} / ${FsPaths.humanSize(total)}'
                ' · %${(fraction! * 100).floor()}'
            : FsPaths.humanSize(done);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(finished ? AppIcons.check : FmColors.iconFor(category),
                size: 20, color: finished ? Paper.success(context) : color),
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(detail,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              if (!finished) ...[
                const SizedBox(height: Gap.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: fraction, minHeight: 6),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
