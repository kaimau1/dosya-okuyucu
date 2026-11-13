import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/theme.dart';
import '../../services/pdf/pro/pdf_edit_bridge.dart';
import 'pdf_pro_edit_controller.dart';

/// Bağlamsal çubuğun tek yongası.
class PdfProChip {
  const PdfProChip(this.icon, this.label, this.onTap,
      {this.active = false, this.danger = false, this.tapKey});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active, danger;
  final Key? tapKey;
}

/// **Bağlamsal ikinci çubuk** (etkileşim §5): seçili araca / seçime göre
/// değişen, yatay kaydırılabilir yongalar. Alt araç çubuğunun üstünde yüzer —
/// gövdenin boyunu değiştirmez (yakınlaştırma/kaydırma yerinde kalır).
class PdfProContextBar extends StatelessWidget {
  const PdfProContextBar({super.key, required this.chips, this.label});
  final List<PdfProChip> chips;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (chips.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: label,
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 2,
        child: SizedBox(
          height: PdfEditTokens.contextBar,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: Gap.sm, vertical: Gap.sm),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, i) {
              final c = chips[i];
              final fg = c.danger
                  ? scheme.error
                  : c.active
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface;
              return ActionChip(
                key: c.tapKey,
                avatar: Icon(c.icon, size: AppIcons.small, color: fg),
                label: Text(c.label),
                labelStyle: context.type.small.copyWith(color: fg),
                backgroundColor:
                    c.active ? scheme.primaryContainer : scheme.surface,
                side: BorderSide(
                    color: c.active
                        ? scheme.primary
                        : scheme.outlineVariant),
                onPressed: c.onTap,
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
  });
  final String done, cancel, bold, italic, underline, strike, color, highlight;
  final String align, smaller, larger, selectAll, copy, cut, paste;
  final String docFont, fallbackFont, glyphError, error, size;
}

/// **Klavye üstü biçim çubuğu** (etkileşim §5): ✓/✕, yazı tipi rozeti
/// ("belge" = gömülü font kullanılıyor), punto, B · I · U · S, renk, vurgu,
/// hizalama, pano. Yazılamayan durum (PK7) çubuğun üstünde açıkça yazar.
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
  });

  final PdfProEditController controller;
  final PdfProFormatLabels labels;
  final VoidCallback onDone, onCancel;
  final VoidCallback onPickColor, onPickHighlight;

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
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
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
            IconButton(
              key: key,
              tooltip: tip,
              isSelected: on,
              icon: Icon(icon),
              onPressed: onTap,
            );
        final alignIcon =
            _aligns.firstWhere((e) => e.$1 == live.align).$2;
        void paste() async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final t = data?.text;
          if (t == null || t.isEmpty) return;
          final v = input.value;
          final s = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
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
        return Material(
          color: scheme.surfaceContainerHigh,
          elevation: 3,
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
              SizedBox(
                height: PdfEditTokens.formatBar,
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('pse-format-cancel'),
                      tooltip: labels.cancel,
                      icon: const Icon(AppIcons.close),
                      onPressed: controller.busy ? null : onCancel,
                    ),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Yazı tipi rozeti: belgenin fontu mu, yedek mi.
                          Center(
                            child: Tooltip(
                              message: live.fallbackChars > 0
                                  ? labels.fallbackFont
                                  : labels.docFont,
                              child: Container(
                                key: const ValueKey('pse-font-badge'),
                                margin: const EdgeInsetsDirectional.only(
                                    end: Gap.sm),
                                padding: const EdgeInsetsDirectional.symmetric(
                                    horizontal: Gap.sm, vertical: Gap.xs),
                                decoration: BoxDecoration(
                                  color: live.fallbackChars > 0
                                      ? PdfEditTokens.pending(dark)
                                          .withValues(alpha: 0.18)
                                      : scheme.primaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(Radii.control),
                                ),
                                child: Text(
                                  live.fallbackChars > 0
                                      ? labels.fallbackFont
                                      : labels.docFont,
                                  style: context.type.small,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('pse-size-down'),
                            tooltip: labels.smaller,
                            icon: const Icon(AppIcons.textDecrease),
                            onPressed: () => controller.liveParagraph(
                                size: (size - 1).roundToDouble()),
                          ),
                          Center(
                            child: Semantics(
                              label: labels.size,
                              child: Text(size.round().toString(),
                                  style: context.type.small),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('pse-size-up'),
                            tooltip: labels.larger,
                            icon: const Icon(AppIcons.textIncrease),
                            onPressed: () => controller.liveParagraph(
                                size: (size + 1).roundToDouble()),
                          ),
                          toggle(
                              const ValueKey('pse-bold'),
                              AppIcons.formatBold,
                              labels.bold,
                              live.has((s) => s.bold, a, b),
                              () => controller.liveStyle((x, y) => PdfStyleSpan(
                                  x, y,
                                  bold: !live.has((s) => s.bold, a, b)))),
                          toggle(
                              const ValueKey('pse-italic'),
                              AppIcons.formatItalic,
                              labels.italic,
                              live.has((s) => s.italic, a, b),
                              () => controller.liveStyle((x, y) => PdfStyleSpan(
                                  x, y,
                                  italic: !live.has((s) => s.italic, a, b)))),
                          toggle(
                              const ValueKey('pse-underline'),
                              AppIcons.formatUnderlined,
                              labels.underline,
                              live.has((s) => s.underline, a, b),
                              () => controller.liveStyle((x, y) => PdfStyleSpan(
                                  x, y,
                                  underline:
                                      !live.has((s) => s.underline, a, b)))),
                          toggle(
                              const ValueKey('pse-strike'),
                              AppIcons.strikethroughS,
                              labels.strike,
                              live.has((s) => s.strike, a, b),
                              () => controller.liveStyle((x, y) => PdfStyleSpan(
                                  x, y,
                                  strike: !live.has((s) => s.strike, a, b)))),
                          IconButton(
                            key: const ValueKey('pse-color'),
                            tooltip: labels.color,
                            icon: const Icon(AppIcons.formatColorText),
                            onPressed: onPickColor,
                          ),
                          IconButton(
                            key: const ValueKey('pse-highlight'),
                            tooltip: labels.highlight,
                            icon: const Icon(AppIcons.highlighter),
                            onPressed: onPickHighlight,
                          ),
                          IconButton(
                            key: const ValueKey('pse-align'),
                            tooltip: labels.align,
                            icon: Icon(alignIcon),
                            onPressed: () {
                              final i = _aligns
                                  .indexWhere((e) => e.$1 == live.align);
                              controller.liveParagraph(
                                  align: _aligns[(i + 1) % _aligns.length].$1);
                            },
                          ),
                          IconButton(
                            tooltip: labels.selectAll,
                            icon: const Icon(AppIcons.selectAll),
                            onPressed: () => input.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: input.text.length),
                          ),
                          IconButton(
                            tooltip: labels.copy,
                            icon: const Icon(AppIcons.copy),
                            onPressed: a == b ? null : copy,
                          ),
                          IconButton(
                            tooltip: labels.cut,
                            icon: const Icon(AppIcons.cut),
                            onPressed: a == b ? null : () => copy(cut: true),
                          ),
                          IconButton(
                            tooltip: labels.paste,
                            icon: const Icon(AppIcons.paste),
                            onPressed: paste,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          start: Gap.xs, end: Gap.sm),
                      child: FilledButton(
                        key: const ValueKey('pse-format-done'),
                        onPressed: controller.busy ? null : onDone,
                        child: Text(labels.done),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// **Gizli klavye girişi** (Faz 57 / 6): görünmeyen bir `EditableText` —
/// Android IME'si (önerili Türkçe klavye, otomatik düzeltme, sesle yazma,
/// Arapça bileşim), donanım klavyesi ve pano bununla çalışır. Metnin kendisi
/// sayfada, PDFium'un çizdiği gerçek gliflerle görünür (PK6); bu alan yalnız
/// girişi toplar ve [PdfProEditController.liveInput]'a aktarır.
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

  @override
  void initState() {
    super.initState();
    widget.input.addListener(_onInput);
    widget.controller.addListener(_onController);
    _onController();
  }

  @override
  void dispose() {
    widget.input.removeListener(_onInput);
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  /// Alan → belge.
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

  /// Belge → alan (dokunuşla imleç taşındı, yazma başladı).
  void _onController() {
    final live = widget.controller.live;
    if (live == null) return;
    final v = widget.input.value;
    final a = pdfUtf16Index(live.text, live.selStart);
    final b = pdfUtf16Index(live.text, live.selEnd);
    if (v.text == live.text &&
        v.selection.start == (a < b ? a : b) &&
        v.selection.end == (a < b ? b : a)) {
      return;
    }
    _syncing = true;
    widget.input.value = TextEditingValue(
      text: live.text,
      selection: TextSelection(baseOffset: a, extentOffset: b),
      // Metin aynıysa süren bileşim korunur (imleç dokunuşla taşınmadıysa).
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
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            widget.onUndo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            widget.onRedo,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            style((a, b) => PdfStyleSpan(a, b, bold: !on((s) => s.bold))),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            style((a, b) => PdfStyleSpan(a, b, italic: !on((s) => s.italic))),
        const SingleActivator(LogicalKeyboardKey.keyU, control: true): () =>
            style((a, b) =>
                PdfStyleSpan(a, b, underline: !on((s) => s.underline))),
      },
      child: SizedBox(
        width: 1,
        height: 1,
        child: Opacity(
          opacity: 0,
          child: ExcludeSemantics(
            child: EditableText(
              key: const ValueKey('pse-input'),
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
              // Öneri/otomatik düzeltme ve yazım denetimi (Faz 58 / 4) açık.
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
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Wrap(
        spacing: Gap.md,
        runSpacing: Gap.md,
        children: [
          for (final c in colors)
            Semantics(
              button: true,
              selected: c == selected,
              label: '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onPick(c),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(c | 0xFF000000),
                    shape: BoxShape.circle,
                    border: Border.all(
                        width: c == selected ? 3 : 1,
                        color: c == selected
                            ? scheme.primary
                            : scheme.outlineVariant),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
