part of '../scan_result_screen.dart';

/// Alt araç: büyük simge kapsülü + etiket. Beşi eşit genişlikte.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fg = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : (highlight ? scheme.onPrimaryContainer : scheme.onSurface);
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 34,
                  decoration: BoxDecoration(
                    color: highlight && enabled
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, size: 21, color: fg),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Çift yönlü döndürme aracı: kapsülün sol yarısı Sola Döndür (`rotateLeft`),
/// sağ yarısı ve etiketi Sağa Döndür (`rotate`).
class _RotateToolButton extends StatelessWidget {
  final String label;
  final String leftTooltip;
  final String rightTooltip;
  final VoidCallback? onRotateLeft;
  final VoidCallback? onRotateRight;

  const _RotateToolButton({
    required this.label,
    required this.leftTooltip,
    required this.rightTooltip,
    required this.onRotateLeft,
    required this.onRotateRight,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onRotateRight != null || onRotateLeft != null;
    final fg =
        !enabled ? scheme.onSurface.withValues(alpha: 0.38) : scheme.onSurface;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onRotateRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: leftTooltip,
                          child: InkWell(
                            borderRadius: const BorderRadiusDirectional.horizontal(
                              start: Radius.circular(17),
                            ).resolve(Directionality.of(context)),
                            onTap: onRotateLeft,
                            child: Center(
                              child: Icon(AppIcons.rotateLeft,
                                  size: 18, color: fg),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 16,
                        color: scheme.outlineVariant,
                      ),
                      Expanded(
                        child: Tooltip(
                          message: rightTooltip,
                          child: InkWell(
                            borderRadius: const BorderRadiusDirectional.horizontal(
                              end: Radius.circular(17),
                            ).resolve(Directionality.of(context)),
                            onTap: onRotateRight,
                            child: Center(
                              child:
                                  Icon(AppIcons.rotate, size: 18, color: fg),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  const _Thumb({
    required this.path,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        width: 54,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.2 : 1,
          ),
          color: AppColors.onMedia,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image(
                image: FmFileImage(path, cacheWidth: (54 * dpr).round()),
                key: ValueKey(path),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: scheme.surfaceContainerHigh),
              ),
            ),
            PositionedDirectional(
              end: 2,
              bottom: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : AppColors.mediaScrim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  child: Text(
                    '$number',
                    style: context.type.micro.copyWith(
                      color: selected ? scheme.onPrimary : AppColors.onMedia,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Izgaradaki tek sayfa: basılı tut-sürükle ile taşınır, başka sayfanın
/// üstüne bırakılınca o yere girer.
class _GridPageTile extends StatelessWidget {
  final String path;
  final int index;
  final bool selected;
  final bool enabled;
  final VoidCallback onOpen;
  final ValueChanged<int> onMove;
  final ValueChanged<String> onAction;

  const _GridPageTile({
    super.key,
    required this.path,
    required this.index,
    required this.selected,
    required this.enabled,
    required this.onOpen,
    required this.onMove,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget card({bool lifted = false}) => LayoutBuilder(
          builder: (context, box) => Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2.2 : 1,
              ),
              color: AppColors.onMedia,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image(
                    image: FmFileImage(path,
                        cacheWidth: (((box.maxWidth * dpr) / 64).ceil() * 64)
                            .clamp(64, 1024)),
                    key: ValueKey(path),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        ColoredBox(color: scheme.surfaceContainerHigh),
                  ),
                ),
                PositionedDirectional(
                  start: 4,
                  bottom: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      child: Text('${index + 1}',
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ),
                ),
                if (!lifted)
                  PositionedDirectional(
                    end: 4,
                    top: 4,
                    child: PopupMenuButton<String>(
                      enabled: enabled,
                      tooltip: context.t('common.more'),
                      padding: EdgeInsets.zero,
                      icon: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          child: Icon(AppIcons.moreHoriz,
                              color: scheme.onSurface, size: 18),
                        ),
                      ),
                      onSelected: onAction,
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                            value: 'rotate_left',
                            child: Text(ctx.t('ss.tool_rotate_left'))),
                        PopupMenuItem(
                            value: 'rotate',
                            child: Text(ctx.t('ss.tool_rotate'))),
                        PopupMenuItem(
                            value: 'filter',
                            child: Text(ctx.t('ss.tool_filter'))),
                        PopupMenuItem(
                            value: 'crop', child: Text(ctx.t('ss.tool_crop'))),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text(ctx.t('ss.tool_delete'))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => enabled && d.data != index,
      onAcceptWithDetails: (d) {
        AppHaptics.drop();
        onMove(d.data);
      },
      builder: (context, candidates, _) => LongPressDraggable<int>(
        data: index,
        hapticFeedbackOnStart: false,
        onDragStarted: AppHaptics.longPress,
        maxSimultaneousDrags: enabled ? 1 : 0,
        feedback: Material(
          color: Colors.transparent,
          elevation: 6,
          child: SizedBox(width: 96, height: 136, child: card(lifted: true)),
        ),
        childWhenDragging: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.primary, width: 1.4),
            color: scheme.surfaceContainerHigh,
          ),
        ),
        child: PressScale(
            child: GestureDetector(
          onTap: onOpen,
          child: AnimatedScale(
            duration: Motion.of(context, Motion.short),
            scale: candidates.isNotEmpty ? 0.94 : 1,
            child: card(),
          ),
        )),
      ),
    );
  }
}

/// Izgaranın sonundaki "Sayfa ekle" kutusu.
class _GridAddTile extends StatelessWidget {
  final VoidCallback? onTap;
  const _GridAddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.noteAdd, color: scheme.onPrimaryContainer, size: 28),
            const SizedBox(height: Gap.xs),
            Text(context.t('scr.add_pages'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Sayfa OCR metnini elle düzenleme levhası.
class _PageTextEditSheet extends StatefulWidget {
  final String initial;
  const _PageTextEditSheet({required this.initial});

  @override
  State<_PageTextEditSheet> createState() => _PageTextEditSheetState();
}

class _PageTextEditSheetState extends State<_PageTextEditSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.md,
        0,
        Gap.md,
        Gap.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 12,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('common.cancel')),
              ),
              const SizedBox(width: Gap.xs),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _controller.text),
                icon: const Icon(AppIcons.check, size: 18),
                label: Text(context.t('common.save')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dışa aktarma seçimi: biçim (`pdf`/`docx`/`xlsx`/`txt`/`jpg`/`png`) + PDF kalitesi.
class _ExportChoice {
  final String format;
  final ScanQuality quality;
  const _ExportChoice(this.format, [this.quality = ScanQuality.medium]);
}

/// Dışa aktarma levhası: PDF kalitesi (tahmini boyutla) + Word/Excel/TXT +
/// Görsel olarak kaydet (JPEG / PNG).
class _ExportSheet extends StatefulWidget {
  final List<String> pages;
  const _ExportSheet({required this.pages});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  ScanQuality _quality = ScanQuality.medium;
  Map<ScanQuality, int>? _sizes;

  @override
  void initState() {
    super.initState();
    ScanExport.estimateSizes(widget.pages).then((v) {
      if (mounted) setState(() => _sizes = v);
    }, onError: (_) {});
  }

  String _size(ScanQuality q) {
    final b = _sizes?[q];
    if (b == null) return '…';
    final mb = b / (1024 * 1024);
    return mb >= 1
        ? '~${mb.toStringAsFixed(1)} MB'
        : '~${(b / 1024).round()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('sx.pdf_quality'), style: theme.textTheme.labelLarge),
          const SizedBox(height: Gap.sm),
          SegmentedButton<ScanQuality>(
            showSelectedIcon: false,
            segments: [
              for (final q in ScanQuality.values)
                ButtonSegment(
                  value: q,
                  label: Text('${context.t(q.labelKey)}\n${_size(q)}',
                      textAlign: TextAlign.center, maxLines: 2),
                ),
            ],
            selected: {_quality},
            onSelectionChanged: (v) => setState(() => _quality = v.first),
          ),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, _ExportChoice('pdf', _quality)),
            icon: const Icon(AppIcons.pdf, size: 20),
            label: Text(context.t('sx.save_pdf')),
          ),
          const Divider(height: Gap.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.newWord),
            title: Text(context.t('sx.to_word')),
            subtitle: Text(context.t('sx.to_word_sub')),
            onTap: () => Navigator.pop(context, const _ExportChoice('docx')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.newSheet),
            title: Text(context.t('sx.to_excel')),
            subtitle: Text(context.t('sx.to_excel_sub')),
            onTap: () => Navigator.pop(context, const _ExportChoice('xlsx')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.newText),
            title: Text(context.t('sx.to_txt')),
            onTap: () => Navigator.pop(context, const _ExportChoice('txt')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.image),
            title: Text(context.t('sx.to_jpg')),
            subtitle: Text(context.t('sx.to_image_sub')),
            onTap: () => Navigator.pop(context, const _ExportChoice('jpg')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.photos),
            title: Text(context.t('sx.to_png')),
            subtitle: Text(context.t('sx.to_image_sub')),
            onTap: () => Navigator.pop(context, const _ExportChoice('png')),
          ),
        ],
      ),
    );
  }
}
