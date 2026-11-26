import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_colors.dart';
import '../core/app_haptics.dart';
import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/motion.dart';
import '../core/safe_insets.dart';
import '../core/theme.dart';

/// **Sayfa gezinti kapsülü** — belgenin altında yüzen "‹  49 / 88  ›".
///
/// Okuma ilerleme halkası + sayfa numarası (+ yıldızlıysa kurdele);
/// [onPrev]/[onNext] verildiğinde tek dokunuşla sayfa çevirme sağlar; ortaya
/// dokununca [PdfPageNavigator], uzun basınca sayfayı yıldızlar.
class PdfPageChip extends StatelessWidget {
  final int page;
  final int count;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const PdfPageChip({
    super.key,
    required this.page,
    required this.count,
    required this.onTap,
    this.bookmarked = false,
    this.onLongPress,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final paper = scheme.surfaceContainerLowest;
    final ink = scheme.onSurface;
    final progress = count <= 1 ? 1.0 : (page - 1) / (count - 1);
    final showStep = (onPrev != null || onNext != null) && count > 1;
    final canPrev = onPrev != null && page > 1;
    final canNext = onNext != null && page < count;

    Widget stepBtn({
      required IconData icon,
      required String tip,
      required VoidCallback? onPressed,
    }) =>
        Semantics(
          button: true,
          enabled: onPressed != null,
          label: tip,
          excludeSemantics: true,
          child: Tooltip(
            message: tip,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  icon,
                  size: 18,
                  color: onPressed == null
                      ? scheme.onSurface.withValues(alpha: 0.28)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.studioShadow(dark),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: paper.withValues(alpha: 0.96),
        shape: StadiumBorder(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.78),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showStep) ...[
              const SizedBox(width: 2),
              stepBtn(
                icon: AppIcons.chevronLeft,
                tip: context.t('pn.prev_page'),
                onPressed: canPrev ? onPrev : null,
              ),
              Container(
                width: 1,
                height: 18,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ],
            Semantics(
              button: true,
              label: context.t('pn.chip_label', {'n': page, 'total': count}),
              child: InkWell(
                key: const ValueKey('pdf-page-chip'),
                onTap: onTap,
                onLongPress: onLongPress,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    showStep ? 10 : 10,
                    6,
                    showStep ? 10 : 12,
                    6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 2.3,
                          color: scheme.primary,
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '$page',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text: ' / $count',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ]),
                        style: context.type.compact.copyWith(
                          color: ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (bookmarked) ...[
                        const SizedBox(width: 6),
                        Icon(AppIcons.bookmark,
                            size: 15, color: scheme.primary),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (showStep) ...[
              Container(
                width: 1,
                height: 18,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              stepBtn(
                icon: AppIcons.chevron,
                tip: context.t('pn.next_page'),
                onPressed: canNext ? onNext : null,
              ),
              const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gezgin sayfasının sonucu: gidilecek sayfa.
typedef PdfBookmarkToggle = Future<bool> Function(int page);

/// **Belge Stüdyosu Sayfa Gezgini** — canlı sayfa önizleme sahnesi,
/// görsel sayfa şeridi (filmstrip), hızlanan adım düğmeleri, hızlı yüzde/uç
/// kısayolları ve yıldızlı sayfalar koleksiyonu.
class PdfPageNavigator extends StatefulWidget {
  final PdfDocument? document;
  final int current;
  final int count;

  /// Son atlayıştan önce bulunulan sayfa (yoksa null).
  final int? previous;

  final List<int> bookmarks;
  final PdfBookmarkToggle onToggleBookmark;

  const PdfPageNavigator({
    super.key,
    required this.document,
    required this.current,
    required this.count,
    required this.bookmarks,
    required this.onToggleBookmark,
    this.previous,
  });

  static Future<int?> show(
    BuildContext context, {
    required PdfDocument? document,
    required int current,
    required int count,
    required List<int> bookmarks,
    required PdfBookmarkToggle onToggleBookmark,
    int? previous,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      barrierColor: AppColors.shade.withValues(alpha: 0.25),
      builder: (_) => PdfPageNavigator(
        document: document,
        current: current,
        count: count,
        previous: previous,
        bookmarks: bookmarks,
        onToggleBookmark: onToggleBookmark,
      ),
    );
  }

  @override
  State<PdfPageNavigator> createState() => _PdfPageNavigatorState();
}

class _PdfPageNavigatorState extends State<PdfPageNavigator> {
  static const double _stripItemExtent = 66.0;

  late int _target = widget.current.clamp(1, widget.count);
  late final TextEditingController _field =
      TextEditingController(text: '$_target');
  late final ScrollController _stripCtrl = ScrollController();
  late List<int> _marks = List.of(widget.bookmarks)..sort();
  Timer? _repeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerStrip(_target));
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _stripCtrl.dispose();
    _field.dispose();
    super.dispose();
  }

  void _centerStrip(int page, {bool animate = false}) {
    if (!_stripCtrl.hasClients) return;
    final pos = _stripCtrl.position;
    final desired =
        ((page - 1) * _stripItemExtent - pos.viewportDimension / 2 + 29)
            .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (animate) {
      _stripCtrl.animateTo(
        desired,
        duration: Motion.of(context, Motion.short),
        curve: Motion.standard,
      );
    } else {
      _stripCtrl.jumpTo(desired);
    }
  }

  void _set(int page, {bool fromField = false, bool scrollStrip = true}) {
    final p = page.clamp(1, widget.count);
    setState(() => _target = p);
    if (!fromField) {
      _field.value = TextEditingValue(
        text: '$p',
        selection: TextSelection.collapsed(offset: '$p'.length),
      );
    }
    if (scrollStrip) _centerStrip(p, animate: true);
  }

  void _startRepeat(int delta) {
    _set(_target + delta);
    _repeat?.cancel();
    var step = delta;
    var ticks = 0;
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
      ticks++;
      if (ticks == 15) step = delta * 5;
      if (ticks == 35) step = delta * 20;
      _set(_target + step);
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _go(int page) {
    AppHaptics.step();
    Navigator.pop(context, page.clamp(1, widget.count));
  }

  Future<void> _toggle() async {
    final page = _target;
    final now = await widget.onToggleBookmark(page);
    if (!mounted) return;
    setState(() {
      _marks = List.of(_marks)..remove(page);
      if (now) _marks = (_marks..add(page))..sort();
    });
  }

  Widget _quickPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: accent
          ? scheme.primaryContainer
          : scheme.surfaceContainerLow,
      shape: StadiumBorder(
        side: BorderSide(
          color: accent
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: accent ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final dark = theme.brightness == Brightness.dark;
    final count = widget.count;
    final marked = _marks.contains(_target);
    final percent =
        count <= 1 ? 100 : ((_target - 1) * 100 / (count - 1)).round();
    final progress = count <= 1 ? 1.0 : (_target - 1) / (count - 1);
    final previous = widget.previous;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: withNavInset(
            context, const EdgeInsets.fromLTRB(18, 0, 18, 20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Başlık + canlı ilerleme rozeti + yıldız ──
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(AppIcons.pageJump,
                      size: 20, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('pn.title'),
                        style: text.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.t('pn.position',
                            {'n': _target, 'total': count, 'p': percent}),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: context.t(marked ? 'pn.unstar' : 'pn.star'),
                  isSelected: marked,
                  onPressed: _toggle,
                  icon: const Icon(AppIcons.important),
                  selectedIcon: const Icon(AppIcons.bookmark),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Canlı sayfa sahnesi ──
            Container(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 178,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _aspect(),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.page,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.45),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.studioShadow(dark),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: widget.document == null
                                  ? Center(
                                      child: Text(
                                        '$_target',
                                        style: text.headlineMedium?.copyWith(
                                          color: AppColors.mediaScrim,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  : PdfPageView(
                                      key: ValueKey(_target),
                                      document: widget.document,
                                      pageNumber: _target,
                                      maximumDpi: 72,
                                      decoration: const BoxDecoration(
                                          color: AppColors.page),
                                    ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: 6,
                          end: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: ShapeDecoration(
                              color: scheme.inverseSurface
                                  .withValues(alpha: 0.88),
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              context.t('pn.progress_pct', {'n': percent}),
                              style: text.labelSmall?.copyWith(
                                color: scheme.onInverseSurface,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // İnce okuma ilerleme çubuğu
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Adım + kaydırıcı
                  Row(
                    children: [
                      _StepButton(
                        icon: AppIcons.chevronLeft,
                        tooltip: context.t('pn.prev'),
                        onDown: () => _startRepeat(-1),
                        onUp: _stopRepeat,
                      ),
                      Expanded(
                        child: Slider(
                          value: _target.toDouble(),
                          min: 1,
                          max: count < 2 ? 2 : count.toDouble(),
                          label: '$_target',
                          divisions: count > 1 ? count - 1 : 1,
                          onChanged:
                              count < 2 ? null : (v) => _set(v.round()),
                        ),
                      ),
                      _StepButton(
                        icon: AppIcons.chevron,
                        tooltip: context.t('pn.next'),
                        onDown: () => _startRepeat(1),
                        onUp: _stopRepeat,
                      ),
                    ],
                  ),
                  // ── Görsel sayfa şeridi (filmstrip) ──
                  if (widget.document != null && count > 1) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        context.t('pn.filmstrip'),
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 84,
                      child: ListView.builder(
                        controller: _stripCtrl,
                        scrollDirection: Axis.horizontal,
                        itemExtent: _stripItemExtent,
                        itemCount: count,
                        itemBuilder: (_, i) {
                          final p = i + 1;
                          final active = p == _target;
                          final isStar = _marks.contains(p);
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => active ? _go(p) : _set(p),
                              child: AnimatedContainer(
                                duration: Motion.of(context, Motion.short),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: active
                                      ? scheme.primaryContainer
                                      : scheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: active
                                        ? scheme.primary
                                        : scheme.outlineVariant
                                            .withValues(alpha: 0.6),
                                    width: active ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: PdfPageView(
                                              document: widget.document,
                                              pageNumber: p,
                                              maximumDpi: 28,
                                              decoration: const BoxDecoration(
                                                  color: AppColors.page),
                                            ),
                                          ),
                                          if (isStar)
                                            PositionedDirectional(
                                              top: 2,
                                              end: 2,
                                              child: Icon(
                                                AppIcons.bookmark,
                                                size: 12,
                                                color: scheme.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$p',
                                      maxLines: 1,
                                      style: text.labelSmall?.copyWith(
                                        fontWeight: active
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: active
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Sayı kutusu + Git ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('pn-field'),
                    controller: _field,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.go,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      prefixIcon: const Icon(AppIcons.hashtag, size: 19),
                      hintText: context.t('pn.field_hint', {'total': count}),
                      suffixText: '/ $count',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) _set(n, fromField: true);
                    },
                    onSubmitted: (_) => _go(_target),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const ValueKey('pn-go'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _go(_target),
                  icon: const Icon(AppIcons.arrowForward, size: 19),
                  label: Text(context.t('common.go')),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Hızlı geçiş kısayolları ──
            Text(
              context.t('pn.quick_jump'),
              style: text.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickPill(
                  icon: AppIcons.firstPage,
                  label: context.t('pn.first'),
                  onTap: () => _go(1),
                ),
                if (count >= 12)
                  for (final q in const [25, 50, 75])
                    _quickPill(
                      icon: AppIcons.fastForward,
                      label: '%$q',
                      onTap: () => _set(
                          math.max(1, (count * q / 100).round())),
                    ),
                _quickPill(
                  icon: AppIcons.lastPage,
                  label: context.t('pn.last'),
                  onTap: () => _go(count),
                ),
                if (previous != null && previous != widget.current)
                  _quickPill(
                    icon: AppIcons.undo,
                    label: context.t('pn.back_to', {'n': previous}),
                    onTap: () => _go(previous),
                    accent: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Yıldızlı sayfalar kartı ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.bookmarks, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.t('pn.bookmarks', {'n': _marks.length}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_marks.isEmpty)
                    Text(
                      context.t('pn.bookmarks_empty'),
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  else
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _marks.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final page = _marks[i];
                          final isCurrent = page == widget.current;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _go(page),
                            child: SizedBox(
                              width: 68,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppColors.page,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isCurrent
                                              ? scheme.primary
                                              : scheme.outlineVariant,
                                          width: isCurrent ? 2 : 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: widget.document == null
                                            ? const SizedBox.expand()
                                            : PdfPageView(
                                                document: widget.document,
                                                pageNumber: page,
                                                maximumDpi: 36,
                                                decoration: const BoxDecoration(
                                                    color: AppColors.page),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 1),
                                    decoration: ShapeDecoration(
                                      color: isCurrent
                                          ? scheme.primaryContainer
                                          : scheme.surfaceContainerHigh,
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Text(
                                      '$page',
                                      style: text.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: isCurrent
                                            ? scheme.primary
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _aspect() {
    final doc = widget.document;
    if (doc == null || _target < 1 || _target > doc.pages.length) {
      return 0.707;
    }
    final page = doc.pages[_target - 1];
    if (page.height <= 0) return 0.707;
    return (page.width / page.height).clamp(0.3, 3.0);
  }
}

/// ‹ › — basılı tutunca hızlanan adım düğmesi.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Listener(
        onPointerDown: (_) => onDown(),
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
  }
}
