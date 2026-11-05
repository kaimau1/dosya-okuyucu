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
              child: Image.file(
                File(path),
                key: ValueKey(path),
                fit: BoxFit.cover,
                cacheWidth: (54 * dpr).round(),
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
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

class _SheetIcon extends StatelessWidget {
  final IconData icon;
  const _SheetIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
    );
  }
}

/// Filtre levhasının sonucu.
class _FilterChoice {
  final ScanFilter filter;
  final bool all;
  final bool straighten;
  const _FilterChoice(this.filter, {this.all = false, this.straighten = false});
}

/// **Filtre levhası** — dört görünümün CANLI önizlemesi, "tüm sayfalara"
/// anahtarı ve "Düzleştir". Önizlemeler küçük kopyada tek izolatta üretilir.
class _FilterSheet extends StatefulWidget {
  final String source;
  final ScanFilter current;
  final int pageCount;

  const _FilterSheet({
    required this.source,
    required this.current,
    required this.pageCount,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  Map<ScanFilter, Uint8List>? _previews;
  bool _all = false;

  @override
  void initState() {
    super.initState();
    compute(ScanEnhance.previews, ScanPreviewRequest(widget.source))
        .then((v) {
      if (mounted) setState(() => _previews = v);
    }).catchError((_) {
      if (mounted) setState(() => _previews = const {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('ss.filter_title'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Gap.xs),
            Text(context.t('ss.filter_note'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Paper.faint(context))),
            const SizedBox(height: Gap.md),
            // 6 filtre: 3'lü iki sıra (tek sırada önizlemeler okunmayacak
            // kadar küçülüyordu — Faz 35).
            for (var r = 0; r < ScanFilter.values.length; r += 3)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Row(
                  children: [
                    for (final filter in ScanFilter.values.skip(r).take(3))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _preview(context, filter),
                        ),
                      ),
                  ],
                ),
              ),
            if (widget.pageCount > 1) ...[
              const SizedBox(height: Gap.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _all,
                onChanged: (v) => setState(() => _all = v),
                title: Text(context.t('scan.apply_to_all')),
              ),
            ],
            const Divider(height: Gap.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(AppIcons.straighten, color: scheme.primary),
              title: Text(context.t('sr.straighten')),
              subtitle: Text(context.t('ss.straighten_sub')),
              onTap: () => Navigator.pop(context,
                  _FilterChoice(widget.current, straighten: true)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, ScanFilter filter) {
    final scheme = Theme.of(context).colorScheme;
    final selected = filter == widget.current;
    final bytes = _previews?[filter];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(context, _FilterChoice(filter, all: _all)),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.72,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2.4 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: bytes == null
                    ? ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: _previews == null
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : null,
                      )
                    : Image.memory(bytes,
                        fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(filter.shortLabelKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.primary : null,
                ),
          ),
        ],
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
                  child: Image.file(
                    File(path),
                    key: ValueKey(path),
                    fit: BoxFit.cover,
                    // Kademeli kova: hücre genişliği × dpr, 64'e yuvarlanır.
                    cacheWidth: (((box.maxWidth * dpr) / 64).ceil() * 64)
                        .clamp(64, 1024),
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
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
                    end: 0,
                    top: 0,
                    child: PopupMenuButton<String>(
                      enabled: enabled,
                      tooltip: context.t('common.more'),
                      icon: Icon(AppIcons.moreHoriz,
                          color: scheme.onSurface, size: 20),
                      onSelected: onAction,
                      itemBuilder: (ctx) => [
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
      onAcceptWithDetails: (d) => onMove(d.data),
      builder: (context, candidates, _) => LongPressDraggable<int>(
        data: index,
        maxSimultaneousDrags: enabled ? 1 : 0,
        feedback: Material(
          color: Colors.transparent,
          elevation: 6,
          child: SizedBox(width: 96, height: 136, child: card(lifted: true)),
        ),
        // Boş yuva (Opacity/saveLayer liste hücresinde yasak — anayasa k.5).
        childWhenDragging: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.primary, width: 1.4),
            color: scheme.surfaceContainerHigh,
          ),
        ),
        child: GestureDetector(
          onTap: onOpen,
          child: AnimatedScale(
            duration: Motion.of(context, Motion.short),
            scale: candidates.isNotEmpty ? 0.94 : 1,
            child: card(),
          ),
        ),
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
