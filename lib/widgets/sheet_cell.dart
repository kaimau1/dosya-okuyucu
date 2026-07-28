import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/xlsx_editor.dart';

/// Yazı rengini zeminiyle okunur hâle getirir.
///
/// Excel'de sayfa DAİMA beyazdır; dosyalar da bunu varsayıp yazıyı siyah
/// bırakır. Koyu temada o siyah yazı koyu zeminde kayboluyordu (ve tersi:
/// dosyadan gelen beyaz dolgu üstünde açık tema yazı rengi). Kontrast
/// oranı okunamayacak kadar düşükse renk zemine göre çevrilir; makul ama
/// düşük kontrastlı (gri/beyaz gibi BİLİNÇLİ) seçimler korunur.
@visibleForTesting
Color readableOn(Color fg, Color bg) {
  final lf = fg.computeLuminance();
  final lb = bg.computeLuminance();
  final ratio = (math.max(lf, lb) + 0.05) / (math.min(lf, lb) + 0.05);
  if (ratio >= 2.5) return fg;
  return lb > 0.5 ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2);
}

/// Hit-test ile hücreyi bulmak için (aralık seçiminde parmağın altındaki
/// hücre — ölçüm/koordinat matematiği yok).
class SheetCellPos {
  final int row, col;
  const SheetCellPos(this.row, this.col);
}

/// Koşullu biçimlendirmenin bu hücrede ürettiği görünüm.
class SheetCondPaint {
  final Color? background;
  final Color? foreground;
  final bool bold;
  final bool italic;

  /// Veri çubuğu oranı (0-1) ve rengi.
  final double? barRatio;
  final Color? barColor;

  const SheetCondPaint({
    this.background,
    this.foreground,
    this.bold = false,
    this.italic = false,
    this.barRatio,
    this.barColor,
  });
}

/// Tek bir Excel hücresi — dolgu, kenarlıklar, yazı tipi, hizalama, metin
/// kaydırma, girinti, koşullu biçim ve seçim çerçevesi.
///
/// Kenarlıklar `Border` ile DEĞİL, [_CellBorderPainter] ile çizilir: Excel'de
/// her kenarın kendi stili/rengi/kalınlığı olabilir ve `double` (çift çizgi)
/// gibi stiller Flutter'ın `BorderSide`ında yok.
class SheetCell extends StatelessWidget {
  final int row, col;
  final double width, height;
  final double zoom;
  final XlsxCellStyle? style;
  final XlsxCellView view;
  final SheetCondPaint? cond;
  final bool selected;
  final bool cursor;
  final bool editing;
  final bool showGridLines;
  final TextEditingController controller;
  final VoidCallback onTap;
  final VoidCallback onSubmitted;
  final VoidCallback onEditingComplete;

  const SheetCell({
    super.key,
    required this.row,
    required this.col,
    required this.width,
    required this.height,
    required this.zoom,
    required this.style,
    required this.view,
    required this.selected,
    required this.cursor,
    required this.editing,
    required this.showGridLines,
    required this.controller,
    required this.onTap,
    required this.onSubmitted,
    required this.onEditingComplete,
    this.cond,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = style;
    final background = cond?.background ?? s?.background;

    final fontSize = ((s?.fontSize ?? 11) * zoom).clamp(4.0, 96.0);
    final color = readableOn(
      cond?.foreground ?? view.formatColor ?? s?.fontColor ?? scheme.onSurface,
      background ?? scheme.surface,
    );

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: (cond?.bold ?? false) || (s?.bold ?? false)
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: (cond?.italic ?? false) || (s?.italic ?? false)
          ? FontStyle.italic
          : FontStyle.normal,
      decoration: _decoration(s),
      color: color,
      fontFamily: _mapFont(s?.fontFamily),
      height: 1.15,
    );

    final align = s?.alignFor(view.numeric) ?? TextAlign.left;
    final vAlign = s?.vAlign ?? XlsxVAlign.bottom;

    Widget content;
    if (editing) {
      content = TextField(
        controller: controller,
        autofocus: true,
        maxLines: 1,
        onSubmitted: (_) => onSubmitted(),
        onTapOutside: (_) => onEditingComplete(),
        textInputAction: TextInputAction.done,
        textAlign: align,
        style: textStyle,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      );
    } else if (view.text.isEmpty) {
      content = const SizedBox.shrink();
    } else {
      content = Text(
        view.text,
        textAlign: align,
        softWrap: s?.wrap ?? false,
        maxLines: (s?.wrap ?? false) ? null : 1,
        overflow: (s?.wrap ?? false)
            ? TextOverflow.clip
            : TextOverflow.ellipsis,
        style: textStyle,
      );
    }

    final indent = (s?.indent ?? 0) * 8.0 * zoom;
    final padding = EdgeInsets.only(
      left: 3 * zoom + (align == TextAlign.right ? 0 : indent),
      right: 3 * zoom + (align == TextAlign.right ? indent : 0),
      top: 1 * zoom,
      bottom: 1 * zoom,
    );

    Widget body = Align(
      alignment: switch (vAlign) {
        XlsxVAlign.top => _alignFor(align, -1),
        XlsxVAlign.center => _alignFor(align, 0),
        XlsxVAlign.bottom => _alignFor(align, 1),
      },
      child: Padding(padding: padding, child: content),
    );

    // Metin döndürme (Excel'de başlık sütunlarında sık kullanılır).
    final rotation = s?.rotation ?? 0;
    if (rotation != 0 && rotation != 255 && !editing) {
      final degrees = rotation > 90 ? 90 - rotation : rotation;
      body = Center(
        child: RotatedBox(
          quarterTurns: degrees >= 45 ? 3 : (degrees <= -45 ? 1 : 0),
          child: body,
        ),
      );
    }

    return MetaData(
      metaData: SheetCellPos(row, col),
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _CellBorderPainter(
            border: s?.border,
            background: background,
            gridColor: showGridLines
                ? Theme.of(context).dividerColor.withValues(alpha: 0.55)
                : null,
            selection: cursor
                ? OfficeColors.excel
                : (selected
                    ? OfficeColors.excel.withValues(alpha: 0.55)
                    : null),
            selectionFill: selected && !cursor
                ? OfficeColors.excel.withValues(alpha: 0.10)
                : null,
            barRatio: cond?.barRatio,
            barColor: cond?.barColor,
          ),
          child: SizedBox(width: width, height: height, child: body),
        ),
      ),
    );
  }

  static TextDecoration? _decoration(XlsxCellStyle? s) {
    if (s == null) return null;
    if (s.underline && s.strike) {
      return TextDecoration.combine(
          [TextDecoration.underline, TextDecoration.lineThrough]);
    }
    if (s.underline) return TextDecoration.underline;
    if (s.strike) return TextDecoration.lineThrough;
    return null;
  }

  /// Excel yazı tipini pakete gömülü **metrik-uyumlu** karşılığına eşler
  /// (Calibri→Carlito, Arial→Arimo, Times→Tinos — slaytta da aynı eşleme).
  static String? _mapFont(String? name) {
    if (name == null || name.isEmpty) return null;
    final n = name.toLowerCase();
    if (n.contains('times') || n.contains('cambria') || n.contains('georgia')) {
      return 'Tinos';
    }
    if (n.contains('arial') || n.contains('helvetica') || n.contains('verdana')) {
      return 'Arimo';
    }
    if (n.contains('calibri') || n.contains('segoe') || n.contains('candara')) {
      return 'Carlito';
    }
    return null; // bilinmeyen aile → cihaz fontu
  }

  static Alignment _alignFor(TextAlign h, double y) {
    final x = switch (h) {
      TextAlign.center => 0.0,
      TextAlign.right => 1.0,
      _ => -1.0,
    };
    return Alignment(x, y);
  }
}

/// Hücre zemini + veri çubuğu + kenar başına Excel kenarlıkları + seçim.
class _CellBorderPainter extends CustomPainter {
  final XlsxBorder? border;
  final Color? background;
  final Color? gridColor;
  final Color? selection;
  final Color? selectionFill;
  final double? barRatio;
  final Color? barColor;

  _CellBorderPainter({
    required this.border,
    required this.background,
    required this.gridColor,
    required this.selection,
    required this.selectionFill,
    required this.barRatio,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (background != null) {
      canvas.drawRect(rect, Paint()..color = background!);
    }
    if (barRatio != null && barColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 1, size.width * barRatio!, size.height - 2),
        Paint()..color = barColor!.withValues(alpha: 0.45),
      );
    }
    if (selectionFill != null) {
      canvas.drawRect(rect, Paint()..color = selectionFill!);
    }

    // Izgara çizgileri (Excel'in soluk ızgarası) — kenarlık tanımlıysa onun
    // yerine gerçek kenarlık çizilir.
    final b = border;
    void side(XlsxBorderSide? s, Offset p1, Offset p2) {
      if (s != null && s.visible) {
        final paint = Paint()
          ..color = Color(s.colorArgb ?? 0xFF000000)
          ..strokeWidth = s.width
          ..style = PaintingStyle.stroke;
        if (s.style == 'double') {
          final d = (p1.dy == p2.dy) ? const Offset(0, 1.5) : const Offset(1.5, 0);
          canvas.drawLine(p1 - d, p2 - d, paint..strokeWidth = 1);
          canvas.drawLine(p1 + d, p2 + d, paint..strokeWidth = 1);
          return;
        }
        if (s.style.toLowerCase().contains('dash') ||
            s.style.toLowerCase().contains('dot')) {
          _dashed(canvas, p1, p2, paint);
          return;
        }
        canvas.drawLine(p1, p2, paint);
        return;
      }
      final grid = gridColor;
      if (grid == null) return;
      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = grid
            ..strokeWidth = 0.5);
    }

    side(b?.top, Offset.zero, Offset(size.width, 0));
    side(b?.left, Offset.zero, Offset(0, size.height));
    side(b?.right, Offset(size.width, 0), Offset(size.width, size.height));
    side(b?.bottom, Offset(0, size.height), Offset(size.width, size.height));

    if (selection != null) {
      canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..color = selection!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  static void _dashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dash = 3.0, gap = 2.0;
    final total = (p2 - p1).distance;
    if (total <= 0) return;
    final dir = (p2 - p1) / total;
    var t = 0.0;
    while (t < total) {
      final end = (t + dash).clamp(0.0, total);
      canvas.drawLine(p1 + dir * t, p1 + dir * end, paint);
      t = end + gap;
    }
  }

  @override
  bool shouldRepaint(_CellBorderPainter old) =>
      old.background != background ||
      old.selection != selection ||
      old.selectionFill != selectionFill ||
      old.barRatio != barRatio ||
      old.barColor != barColor ||
      old.gridColor != gridColor ||
      old.border != border;
}
