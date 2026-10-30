import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Satır numarası şeridi **sarmalı satırlarda hizalı** (Faz 30 / TX2).
///
/// Eski şerit her mantıksal satır için bir `Text` kurup hepsini bir `Column`a
/// diziyordu: (1) uzun bir satır sarılınca sonraki numaralar yukarıda
/// kalıyordu, (2) her tuşta N widget yeniden kuruluyordu. Bu şerit tek bir
/// `CustomPaint`: her mantıksal satırın üst konumu alanın GERÇEK yerleşiminden
/// ölçülür ([codeLineTops]) ve yalnız görünen aralık boyanır.
double codeGutterWidth(int lines, double fontSize) {
  final digits = math.max(2, '$lines'.length);
  final tp = TextPainter(
    text: TextSpan(
        text: '9' * digits,
        style: editorTextStyle(fontSize, family: 'monospace')),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width + 12 + 10 + 12 + 1;
}

/// Her mantıksal satırın üst konumu (px). [wrap] kapalıyken satır sarılmaz →
/// sabit adım; açıkken metin [width] genişliğinde yerleştirilir.
List<double> codeLineTops(String text, TextStyle style, double width,
    {required bool wrap, int maxWrapChars = 200000}) {
  final starts = <int>[0];
  for (var i = text.indexOf('\n'); i != -1; i = text.indexOf('\n', i + 1)) {
    starts.add(i + 1);
  }
  final lh = (style.fontSize ?? 14) * (style.height ?? 1.0);
  if (!wrap || text.length > maxWrapChars || width <= 0) {
    return [for (var i = 0; i < starts.length; i++) i * lh];
  }
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  final base = tp.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dy;
  final tops = <double>[
    for (final s in starts)
      tp.getOffsetForCaret(TextPosition(offset: s), Rect.zero).dy - base,
  ];
  tp.dispose();
  return tops;
}

class CodeGutter extends StatefulWidget {
  final TextEditingController controller;
  final ScrollController scroll;
  final double size;
  final String? fontFamily;

  /// Alanın metin genişliği (şerit hariç).
  final double textWidth;
  final bool wrap;
  final double topPad;

  /// Satır aralığı (metin alanıyla aynı olmalı, yoksa numaralar kayar).
  final double lineHeight;

  const CodeGutter({
    super.key,
    required this.controller,
    required this.scroll,
    required this.size,
    required this.textWidth,
    required this.wrap,
    this.fontFamily,
    this.topPad = 0,
    this.lineHeight = 1.5,
  });

  @override
  State<CodeGutter> createState() => _CodeGutterState();
}

class _CodeGutterState extends State<CodeGutter> {
  String? _text;
  double _w = -1;
  bool _wrap = false;
  double _size = -1;
  double _lh = -1;
  List<double> _tops = const [0];

  List<double> _computeTops(String text) {
    if (identical(text, _text) &&
        _w == widget.textWidth &&
        _wrap == widget.wrap &&
        _size == widget.size &&
        _lh == widget.lineHeight) {
      return _tops;
    }
    _lh = widget.lineHeight;
    _text = text;
    _w = widget.textWidth;
    _wrap = widget.wrap;
    _size = widget.size;
    _tops = codeLineTops(
      text,
      editorTextStyle(widget.size,
          family: widget.fontFamily, height: widget.lineHeight),
      widget.textWidth,
      wrap: widget.wrap,
    );
    return _tops;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (_, value, __) {
        final tops = _computeTops(value.text);
        final lh = widget.size * widget.lineHeight;
        final height = tops.last + lh;
        final caretLine = _lineOf(value);
        return Container(
          width: codeGutterWidth(tops.length, widget.size),
          margin: const EdgeInsetsDirectional.only(end: 12),
          decoration: BoxDecoration(
            border: Border(
                right: BorderSide(color: scheme.outlineVariant)),
          ),
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(double.infinity, height),
              painter: _GutterPainter(
                tops: tops,
                scroll: widget.scroll,
                fs: widget.size,
                color: scheme.outline,
                activeColor: scheme.primary,
                caretLine: caretLine,
                topPad: widget.topPad,
                lineHeight: widget.lineHeight,
              ),
            ),
          ),
        );
      },
    );
  }

  int _lineOf(TextEditingValue v) {
    final sel = v.selection;
    if (!sel.isValid) return -1;
    var n = 0;
    final end = math.min(sel.extentOffset, v.text.length);
    for (var i = v.text.indexOf('\n'); i != -1 && i < end;
        i = v.text.indexOf('\n', i + 1)) {
      n++;
    }
    return n;
  }
}

class _GutterPainter extends CustomPainter {
  final List<double> tops;
  final ScrollController scroll;
  final double fs;
  final Color color;
  final Color activeColor;
  final int caretLine;
  final double topPad;
  final double lineHeight;

  _GutterPainter({
    required this.tops,
    required this.scroll,
    required this.fs,
    required this.color,
    required this.activeColor,
    required this.caretLine,
    required this.topPad,
    this.lineHeight = 1.5,
  }) : super(repaint: scroll);

  @override
  void paint(Canvas canvas, Size size) {
    final lh = fs * lineHeight;
    final off = scroll.hasClients ? scroll.offset - topPad : 0.0;
    final view = scroll.hasClients ? scroll.position.viewportDimension : 2000.0;
    final lo = off - lh;
    final hi = off + view + lh;
    // İlk görünen satır (ikili arama).
    var a = 0, b = tops.length;
    while (a < b) {
      final m = (a + b) >> 1;
      if (tops[m] < lo) {
        a = m + 1;
      } else {
        b = m;
      }
    }
    for (var i = a; i < tops.length && tops[i] <= hi; i++) {
      final active = i == caretLine;
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: editorTextStyle(fs,
              height: lineHeight,
              family: 'monospace',
              color: active ? activeColor : color,
              weight: active ? FontWeight.w700 : FontWeight.w400),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 10, tops[i]));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(_GutterPainter old) =>
      old.tops != tops ||
      old.caretLine != caretLine ||
      old.color != color ||
      old.fs != fs ||
      old.lineHeight != lineHeight;
}
