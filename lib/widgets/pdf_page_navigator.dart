import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/l10n/app_strings.dart';

/// **Sayfa rozeti** — belgenin altında yüzen "5 / 1272".
///
/// 2026-09-27 kullanıcı: *"sayfaya git bölümü de çok kötü görünüyor; tamamen
/// baştan tasarlanmalı — hem görünümü hem işlevi hem iç yapısı."* Eski rozet
/// "5 / 1272 · sayfaya git ↕" yazan uzun siyah bir haptı; sağ üstteki büyük
/// mavi kaydırma sekmesi aynı numarayı ikinci kez gösteriyordu. Şimdi:
/// okuma ilerlemesini gösteren ince halka + sayı (+ yıldızlıysa yıldız);
/// dokununca [PdfPageNavigator], uzun basınca sayfayı yıldızlar.
class PdfPageChip extends StatelessWidget {
  final int page;
  final int count;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PdfPageChip({
    super.key,
    required this.page,
    required this.count,
    required this.onTap,
    this.bookmarked = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onInverseSurface;
    final progress = count <= 1 ? 1.0 : (page - 1) / (count - 1);
    return Semantics(
      button: true,
      label: context.t('pn.chip_label', {'n': page, 'total': count}),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(40)),
          boxShadow: [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
        child: Material(
          color: scheme.inverseSurface.withValues(alpha: 0.92),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('pdf-page-chip'),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 2.4,
                      color: scheme.inversePrimary,
                      backgroundColor: fg.withValues(alpha: 0.18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '$page',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: ' / $count',
                        style: TextStyle(color: fg.withValues(alpha: 0.7)),
                      ),
                    ]),
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (bookmarked) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.bookmark_rounded,
                        size: 15, color: scheme.inversePrimary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gezgin sayfasının sonucu: gidilecek sayfa.
typedef PdfBookmarkToggle = Future<bool> Function(int page);

/// **Sayfa gezgini** — "sayfaya git"in yerine gelen alt sayfa.
///
/// Eskisi bir `AlertDialog`: sayı kutusu + çizgi kaydırıcı. Sayfanın ne
/// olduğunu görmeden 1272 sayfalık bir kitapta kaydırıcıyla yer aramak
/// körlemeydi. Şimdi:
/// - kaydırdıkça **hedef sayfanın önizlemesi** (pdfium'dan küçük resim);
/// - ince ayar için ‹ › (basılı tutunca hızlanır) ve sayı kutusu;
/// - **İlk / Son / Önceki konum** kısayolları (arama ya da içindekilerle
///   atlayan kullanıcı tek dokunuşla geri döner);
/// - **yıldızlı sayfalar** şeridi ve bu sayfayı yıldızla / kaldır.
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
      barrierColor: Colors.black.withValues(alpha: 0.2),
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
  late int _target = widget.current.clamp(1, widget.count);
  late final TextEditingController _field =
      TextEditingController(text: '$_target');
  late List<int> _marks = List.of(widget.bookmarks)..sort();
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _set(int page, {bool fromField = false}) {
    final p = page.clamp(1, widget.count);
    setState(() => _target = p);
    if (!fromField) {
      _field.value = TextEditingValue(
        text: '$p',
        selection: TextSelection.collapsed(offset: '$p'.length),
      );
    }
  }

  void _startRepeat(int delta) {
    _set(_target + delta);
    _repeat?.cancel();
    var step = delta;
    var ticks = 0;
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
      ticks++;
      // Basılı tuttukça hızlanır: 1 → 5 → 20 sayfa.
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
    HapticFeedback.selectionClick();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = widget.count;
    final marked = _marks.contains(_target);
    final percent =
        count <= 1 ? 100 : ((_target - 1) * 100 / (count - 1)).round();
    final previous = widget.previous;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('pn.title'), style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        context.t('pn.position',
                            {'n': _target, 'total': count, 'p': percent}),
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: context.t(marked ? 'pn.unstar' : 'pn.star'),
                  isSelected: marked,
                  onPressed: _toggle,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  selectedIcon: const Icon(Icons.bookmark_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Önizleme: hedef sayfa.
            SizedBox(
              height: 190,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _aspect(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scheme.outlineVariant),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 10,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: widget.document == null
                          ? Center(
                              child: Text('$_target',
                                  style: text.headlineMedium
                                      ?.copyWith(color: Colors.black54)))
                          : PdfPageView(
                              key: ValueKey(_target),
                              document: widget.document,
                              pageNumber: _target,
                              maximumDpi: 72,
                              decoration:
                                  const BoxDecoration(color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StepButton(
                  icon: Icons.chevron_left_rounded,
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
                    onChanged: count < 2 ? null : (v) => _set(v.round()),
                  ),
                ),
                _StepButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: context.t('pn.next'),
                  onDown: () => _startRepeat(1),
                  onUp: _stopRepeat,
                ),
              ],
            ),
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
                      prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                      hintText: context.t('pn.field_hint', {'total': count}),
                      suffixText: '/ $count',
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
                  onPressed: () => _go(_target),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(context.t('common.go')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.first_page_rounded, size: 18),
                  label: Text(context.t('pn.first')),
                  onPressed: () => _go(1),
                ),
                ActionChip(
                  avatar: const Icon(Icons.last_page_rounded, size: 18),
                  label: Text(context.t('pn.last')),
                  onPressed: () => _go(count),
                ),
                if (previous != null && previous != widget.current)
                  ActionChip(
                    avatar: const Icon(Icons.undo_rounded, size: 18),
                    label: Text(context.t('pn.back_to', {'n': previous})),
                    onPressed: () => _go(previous),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.bookmarks_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(context.t('pn.bookmarks', {'n': _marks.length}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_marks.isEmpty)
              Text(context.t('pn.bookmarks_empty'),
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
            else
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _marks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final page = _marks[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _go(page),
                      child: SizedBox(
                        width: 66,
                        child: Column(
                          children: [
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: page == widget.current
                                          ? scheme.primary
                                          : scheme.outlineVariant,
                                      width: page == widget.current ? 2 : 1),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: widget.document == null
                                      ? const SizedBox.expand()
                                      : PdfPageView(
                                          document: widget.document,
                                          pageNumber: page,
                                          maximumDpi: 36,
                                          decoration: const BoxDecoration(
                                              color: Colors.white),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('$page',
                                style: text.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
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
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(icon),
        ),
      ),
    );
  }
}
