import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../services/pdf/pro/pdf_edit_bridge.dart';
import 'pdf_pro_edit_controller.dart';

/// Bağlamsal çubuğun tek yongası.
class PdfProChip {
  const PdfProChip(this.icon, this.label, this.onTap,
      {this.active = false,
      this.danger = false,
      this.primary = false,
      this.swatch,
      this.tapKey});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active, danger, primary;
  final Color? swatch;
  final Key? tapKey;
}

/// **Belge Stüdyosu Bağlamsal Çubuğu**: seçili araca / nesneye göre
/// canlanan, yumuşak gölgeli yüzen hap şeridi. Gövdenin boyunu değiştirmez.
class PdfProContextBar extends StatelessWidget {
  const PdfProContextBar({super.key, required this.chips, this.label});
  final List<PdfProChip> chips;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    if (chips.isEmpty) return const SizedBox.shrink();
    final dur = Motion.of(context, Motion.short);
    return Semantics(
      container: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(scheme.surface, scheme.surfaceContainerLow, 0.55),
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.studioShadow(dark),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          height: PdfEditTokens.contextBar,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12, vertical: 9),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = chips[i];
              final enabled = c.onTap != null;
              final fg = !enabled
                  ? scheme.onSurface.withValues(alpha: 0.36)
                  : c.primary
                      ? scheme.onPrimary
                      : c.danger
                          ? scheme.error
                          : c.active
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface;
              final bg = !enabled
                  ? scheme.surfaceContainerHigh.withValues(alpha: 0.45)
                  : c.primary
                      ? scheme.primary
                      : c.danger
                          ? scheme.errorContainer.withValues(alpha: 0.72)
                          : c.active
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerLowest;
              final borderColor = !enabled
                  ? scheme.outlineVariant.withValues(alpha: 0.35)
                  : c.primary
                      ? scheme.primary
                      : c.danger
                          ? scheme.error.withValues(alpha: 0.32)
                          : c.active
                              ? scheme.primary.withValues(alpha: 0.55)
                              : scheme.outlineVariant.withValues(alpha: 0.72);
              final leading = c.swatch != null
                  ? Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: c.swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 1.8,
                          color: c.primary
                              ? scheme.onPrimary.withValues(alpha: 0.85)
                              : scheme.surface,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.studioShadow(dark),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    )
                  : Icon(c.icon, size: 18, color: fg);
              return Semantics(
                button: true,
                enabled: enabled,
                selected: c.active,
                label: c.label,
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: c.tapKey,
                    onTap: c.onTap,
                    child: AnimatedContainer(
                      duration: dur,
                      curve: Motion.standard,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          11, 0, 13, 0),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: bg,
                        shape: StadiumBorder(
                          side: BorderSide(color: borderColor),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          leading,
                          const SizedBox(width: 7),
                          Text(
                            c.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: fg,
                              fontWeight: c.primary || c.active
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Biçim çubuğunun çevrilmiş metinleri (çubuk kendi başına çeviri bilmez).
class PdfProFormatLabels {
  const PdfProFormatLabels({
    required this.done,
    required this.cancel,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strike,
    required this.color,
    required this.highlight,
    required this.align,
    required this.smaller,
    required this.larger,
    required this.selectAll,
    required this.copy,
    required this.cut,
    required this.paste,
    required this.docFont,
    required this.fallbackFont,
    required this.glyphError,
    required this.error,
    required this.size,
    this.overflow = '',
    this.shrink = '',
    this.push = '',
    this.widen = '',
  });
  final String done, cancel, bold, italic, underline, strike, color, highlight;
  final String align, smaller, larger, selectAll, copy, cut, paste;
  final String docFont, fallbackFont, glyphError, error, size;

  /// Taşma uyarısı ve seçenekleri (Faz 57 / 3).
  final String overflow, shrink, push, widen;
}

/// **Klavye üstü biçim çubuğu** (etkileşim §5): ✓/✕, yazı tipi rozeti
/// ("belge" = gömülü font kullanılıyor), gruplu punto adımlayıcı, B · I · U · S,
/// renk, vurgu, hizalama, pano.
class PdfProFormatBar extends StatelessWidget {
  const PdfProFormatBar({
    super.key,
    required this.controller,
    required this.labels,
    required this.onDone,
    required this.onCancel,
    required this.onPickColor,
    required this.onPickHighlight,
    required this.input,
    this.onPickFont,
  });

  final PdfProEditController controller;
  final PdfProFormatLabels labels;
  final VoidCallback onDone, onCancel;
  final VoidCallback onPickColor, onPickHighlight;

  /// Yazı tipi rozetine dokunuş (Faz 56 / 7 font seçici).
  final VoidCallback? onPickFont;

  /// Gizli giriş alanının denetleyicisi (pano işlemleri için).
  final TextEditingController input;

  static const _aligns = [
    (PdfBlockAlign.left, AppIcons.formatAlignLeft),
    (PdfBlockAlign.center, AppIcons.formatAlignCenter),
    (PdfBlockAlign.right, AppIcons.formatAlignRight),
    (PdfBlockAlign.justify, AppIcons.formatAlignJustify),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final live = controller.live;
        if (live == null) return const SizedBox.shrink();
        final a = live.selStart < live.selEnd ? live.selStart : live.selEnd;
        final b = live.selStart < live.selEnd ? live.selEnd : live.selStart;
        final size = live.size ??
            (live.map.sizes.isEmpty ? 12.0 : live.map.sizes.first);
        Widget toggle(Key key, IconData icon, String tip, bool on,
                VoidCallback onTap) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 6),
              child: IconButton(
                key: key,
                tooltip: tip,
                isSelected: on,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor:
                      on ? scheme.primaryContainer : Colors.transparent,
                  foregroundColor: on ? scheme.primary : scheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: on
                        ? BorderSide(
                            color: scheme.primary.withValues(alpha: 0.4))
                        : BorderSide.none,
                  ),
                ),
                icon: Icon(icon, size: 20),
                onPressed: onTap,
              ),
            );
        Widget colorIcon(IconData icon, Color bar) => Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17),
                const SizedBox(height: 1.5),
                Container(
                  width: 17,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: bar,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            );
        final textColorArgb = live.colorAt(a);
        final hlColorArgb = live.highlightAt(a);
        final alignIcon = _aligns.firstWhere((e) => e.$1 == live.align).$2;
        void paste() async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final t = data?.text;
          if (t == null || t.isEmpty) return;
          final v = input.value;
          final s = v.selection.isValid
              ? v.selection
              : TextSelection.collapsed(offset: v.text.length);
          input.value = TextEditingValue(
            text: v.text.replaceRange(s.start, s.end, t),
            selection: TextSelection.collapsed(offset: s.start + t.length),
          );
        }

        void copy({bool cut = false}) {
          final v = input.value;
          final s = v.selection;
          if (!s.isValid || s.isCollapsed) return;
          Clipboard.setData(ClipboardData(text: s.textInside(v.text)));
          if (cut) {
            input.value = TextEditingValue(
              text: v.text.replaceRange(s.start, s.end, ''),
              selection: TextSelection.collapsed(offset: s.start),
            );
          }
        }

        final err = live.error;
        final pick = live.fontAt(a);
        String? pickName;
        if (pick != null) {
          for (final c in controller.fontChoices()) {
            if (c.id == pick) pickName = c.name;
          }
        }
        final badge = pickName ??
            (live.fallbackChars > 0 ? labels.fallbackFont : labels.docFont);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.72),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.studioShadow(dark),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (err != null)
                  Container(
                    key: const ValueKey('pse-format-error'),
                    color: PdfEditTokens.pending(dark).withValues(alpha: 0.16),
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: Gap.md, vertical: Gap.xs),
                    child: Row(
                      children: [
                        Icon(AppIcons.warning,
                            size: AppIcons.small,
                            color: PdfEditTokens.pending(dark)),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(
                            live.glyphError ? labels.glyphError : labels.error,
                            style: context.type.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (err == null && live.collision != null)
                  Container(
                    key: const ValueKey('pse-overflow'),
                    color: PdfEditTokens.pending(dark).withValues(alpha: 0.16),
                    padding: const EdgeInsetsDirectional.only(
                        start: Gap.md, end: Gap.xs),
                    child: Row(
                      children: [
                        Icon(AppIcons.warning,
                            size: AppIcons.small,
                            color: PdfEditTokens.pending(dark)),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(labels.overflow,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.type.caption),
                        ),
                        TextButton(
                          key: const ValueKey('pse-overflow-shrink'),
                          onPressed: () => controller.liveOverflow('shrink'),
                          child: Text(labels.shrink),
                        ),
                        TextButton.icon(
                          key: const ValueKey('pse-overflow-push'),
                          icon: live.pushBelow
                              ? const Icon(AppIcons.check, size: AppIcons.small)
                              : const SizedBox.shrink(),
                          onPressed: () => controller.liveOverflow('push'),
                          label: Text(labels.push),
                        ),
                        if (controller.widenTo(live) != null)
                          TextButton(
                            key: const ValueKey('pse-overflow-widen'),
                            onPressed: () => controller.liveOverflow('widen'),
                            child: Text(labels.widen),
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: PdfEditTokens.formatBar,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: IconButton(
                          key: const ValueKey('pse-format-cancel'),
                          tooltip: labels.cancel,
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.surfaceContainerHigh,
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(AppIcons.close, size: 19),
                          onPressed: controller.busy ? null : onCancel,
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          children: [
                            // Yazı tipi rozeti
                            Center(
                              child: Tooltip(
                                message: badge,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: onPickFont,
                                  child: Container(
                                    key: const ValueKey('pse-font-badge'),
                                    margin: const EdgeInsetsDirectional.only(
                                        end: 6),
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            11, 6, 8, 6),
                                    decoration: ShapeDecoration(
                                      color: live.fallbackChars > 0 &&
                                              pick == null
                                          ? PdfEditTokens.pending(dark)
                                              .withValues(alpha: 0.18)
                                          : scheme.primaryContainer,
                                      shape: StadiumBorder(
                                        side: BorderSide(
                                          color: scheme.primary
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          badge,
                                          style: context.type.small.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: scheme.onPrimaryContainer,
                                          ),
                                        ),
                                        if (onPickFont != null) ...[
                                          const SizedBox(width: 2),
                                          Icon(AppIcons.dropDown,
                                              size: 18,
                                              color: scheme.onPrimaryContainer),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Gruplu punto adımlayıcı
                            Center(
                              child: Container(
                                margin:
                                    const EdgeInsetsDirectional.only(end: 6),
                                decoration: ShapeDecoration(
                                  color: scheme.surfaceContainerLow,
                                  shape: StadiumBorder(
                                    side: BorderSide(
                                      color: scheme.outlineVariant
                                          .withValues(alpha: 0.65),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      key: const ValueKey('pse-size-down'),
                                      tooltip: labels.smaller,
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(AppIcons.textDecrease,
                                          size: 18),
                                      onPressed: () => controller.liveParagraph(
                                          size: (size - 1).roundToDouble()),
                                    ),
                                    Semantics(
                                      label: labels.size,
                                      child: Text(
                                        size.round().toString(),
                                        style: context.type.small.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      key: const ValueKey('pse-size-up'),
                                      tooltip: labels.larger,
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(AppIcons.textIncrease,
                                          size: 18),
                                      onPressed: () => controller.liveParagraph(
                                          size: (size + 1).roundToDouble()),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            toggle(
                                const ValueKey('pse-bold'),
                                AppIcons.formatBold,
                                labels.bold,
                                live.has((s) => s.bold, a, b),
                                () => controller.liveStyle((x, y) =>
                                    PdfStyleSpan(x, y,
                                        bold:
                                            !live.has((s) => s.bold, a, b)))),
                            toggle(
                                const ValueKey('pse-italic'),
                                AppIcons.formatItalic,
                                labels.italic,
                                live.has((s) => s.italic, a, b),
                                () => controller.liveStyle((x, y) =>
                                    PdfStyleSpan(x, y,
                                        italic:
                                            !live.has((s) => s.italic, a, b)))),
                            toggle(
                                const ValueKey('pse-underline'),
                                AppIcons.formatUnderlined,
                                labels.underline,
                                live.has((s) => s.underline, a, b),
                                () => controller.liveStyle((x, y) =>
                                    PdfStyleSpan(x, y,
                                        underline: !live.has(
                                            (s) => s.underline, a, b)))),
                            toggle(
                                const ValueKey('pse-strike'),
                                AppIcons.strikethroughS,
                                labels.strike,
                                live.has((s) => s.strike, a, b),
                                () => controller.liveStyle((x, y) =>
                                    PdfStyleSpan(x, y,
                                        strike:
                                            !live.has((s) => s.strike, a, b)))),
                            IconButton(
                              key: const ValueKey('pse-color'),
                              tooltip: labels.color,
                              visualDensity: VisualDensity.compact,
                              icon: colorIcon(
                                AppIcons.formatColorText,
                                textColorArgb != null
                                    ? Color(textColorArgb | 0xFF000000)
                                    : scheme.onSurface,
                              ),
                              onPressed: onPickColor,
                            ),
                            IconButton(
                              key: const ValueKey('pse-highlight'),
                              tooltip: labels.highlight,
                              visualDensity: VisualDensity.compact,
                              icon: colorIcon(
                                AppIcons.highlighter,
                                hlColorArgb != null
                                    ? Color(hlColorArgb | 0xFF000000)
                                    : scheme.primary,
                              ),
                              onPressed: onPickHighlight,
                            ),
                            IconButton(
                              key: const ValueKey('pse-align'),
                              tooltip: labels.align,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(alignIcon, size: 20),
                              onPressed: () {
                                final i = _aligns
                                    .indexWhere((e) => e.$1 == live.align);
                                controller.liveParagraph(
                                    align:
                                        _aligns[(i + 1) % _aligns.length].$1);
                              },
                            ),
                            IconButton(
                              tooltip: labels.selectAll,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(AppIcons.selectAll, size: 20),
                              onPressed: () => input.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: input.text.length),
                            ),
                            IconButton(
                              tooltip: labels.copy,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(AppIcons.copy, size: 20),
                              onPressed: a == b ? null : copy,
                            ),
                            IconButton(
                              tooltip: labels.cut,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(AppIcons.cut, size: 20),
                              onPressed: a == b ? null : () => copy(cut: true),
                            ),
                            IconButton(
                              tooltip: labels.paste,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(AppIcons.paste, size: 20),
                              onPressed: paste,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            start: 4, end: 10),
                        child: FilledButton(
                          key: const ValueKey('pse-format-done'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: controller.busy ? null : onDone,
                          child: Text(labels.done),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// **Gizli klavye girişi** (Faz 57 / 6): görünmeyen bir `EditableText` —
/// Android IME'si (önerili Türkçe klavye, otomatik düzeltme, sesle yazma,
/// Arapça bileşim), donanım klavyesi ve pano bununla çalışır.
class PdfProTextInput extends StatefulWidget {
  const PdfProTextInput({
    super.key,
    required this.controller,
    required this.input,
    required this.focusNode,
    required this.onEscape,
    required this.onUndo,
    required this.onRedo,
  });

  final PdfProEditController controller;
  final TextEditingController input;
  final FocusNode focusNode;
  final VoidCallback onEscape, onUndo, onRedo;

  @override
  State<PdfProTextInput> createState() => _PdfProTextInputState();
}

class _PdfProTextInputState extends State<PdfProTextInput> {
  bool _syncing = false;
  final GlobalKey<EditableTextState> _editable = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.input.addListener(_onInput);
    widget.controller.addListener(_onController);
    _onController();
  }

  @override
  void didUpdateWidget(covariant PdfProTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input != widget.input) {
      oldWidget.input.removeListener(_onInput);
      widget.input.addListener(_onInput);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _onController();
    }
  }

  @override
  void dispose() {
    widget.input.removeListener(_onInput);
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  void _onInput() {
    if (_syncing) return;
    final v = widget.input.value;
    final s = v.selection;
    widget.controller.liveInput(
      v.text,
      s.isValid ? s.start : v.text.length,
      s.isValid ? s.end : v.text.length,
      composeStart: v.composing.isValid ? v.composing.start : -1,
      composeEnd: v.composing.isValid ? v.composing.end : -1,
    );
  }

  void _onController() {
    final live = widget.controller.live;
    if (live == null) return;
    final v = widget.input.value;
    final a = pdfUtf16Index(live.text, live.selStart);
    final b = pdfUtf16Index(live.text, live.selEnd);
    final same = v.text == live.text &&
        v.selection.start == (a < b ? a : b) &&
        v.selection.end == (a < b ? b : a);
    if (!same || !widget.focusNode.hasFocus) {
      _editable.currentState?.requestKeyboard();
    }
    if (same) return;
    _syncing = true;
    widget.input.value = TextEditingValue(
      text: live.text,
      selection: TextSelection(baseOffset: a, extentOffset: b),
      composing: v.text == live.text ? v.composing : TextRange.empty,
    );
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void style(PdfStyleSpan Function(int, int) make) =>
        widget.controller.liveStyle(make);
    final live = widget.controller.live;
    bool on(bool? Function(PdfStyleSpan) get) {
      if (live == null) return false;
      final a = live.selStart < live.selEnd ? live.selStart : live.selEnd;
      final b = live.selStart < live.selEnd ? live.selEnd : live.selStart;
      return live.has(get, a, b);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onEscape,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          if (widget.controller.live != null) {
            widget.onEscape();
          } else {
            widget.onUndo();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          if (widget.controller.live == null) widget.onRedo();
        },
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            style((a, b) => PdfStyleSpan(a, b, bold: !on((s) => s.bold))),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            style((a, b) => PdfStyleSpan(a, b, italic: !on((s) => s.italic))),
        const SingleActivator(LogicalKeyboardKey.keyU, control: true): () =>
            style((a, b) =>
                PdfStyleSpan(a, b, underline: !on((s) => s.underline))),
      },
      child: SizedBox(
        key: const ValueKey('pse-input'),
        width: 1,
        height: 1,
        child: Opacity(
          opacity: 0,
          child: ExcludeSemantics(
            child: EditableText(
              key: _editable,
              controller: widget.input,
              focusNode: widget.focusNode,
              autofocus: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: context.type.body,
              cursorColor: scheme.primary,
              backgroundCursorColor: scheme.surface,
              showCursor: false,
              enableInteractiveSelection: false,
              rendererIgnoresPointer: true,
              autocorrect: true,
              enableSuggestions: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Renk seçici ızgarası (metin rengi / vurgu / işaretleme): ARGB değerleri.
class PdfProSwatches extends StatelessWidget {
  const PdfProSwatches(
      {super.key, required this.colors, required this.onPick, this.selected});
  final List<int> colors;
  final int? selected;
  final ValueChanged<int> onPick;

  static const text = [
    0xFF000000, 0xFF424242, 0xFFD32F2F, 0xFFE65100, 0xFF2E7D32, //
    0xFF00796B, 0xFF1565C0, 0xFF6A1B9A, 0xFFAD1457, 0xFFFFFFFF,
  ];
  static const marker = [
    0x66FFEB3B, 0x6681C784, 0x6664B5F6, 0x66F48FB1, 0x66FFB74D, 0x66CE93D8,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final c in colors)
            Builder(builder: (context) {
              final fill = Color(c | 0xFF000000);
              final on = c == selected;
              final checkColor = fill.computeLuminance() > 0.55
                  ? AppColors.pageInk
                  : AppColors.onBrand;
              return Semantics(
                button: true,
                selected: on,
                label: '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onPick(c),
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.short),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: fill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: on ? 3 : 1.2,
                        color: on ? scheme.primary : scheme.outlineVariant,
                      ),
                      boxShadow: on
                          ? [
                              BoxShadow(
                                color: AppColors.studioShadow(dark),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: on
                        ? Icon(AppIcons.check, size: 20, color: checkColor)
                        : null,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
