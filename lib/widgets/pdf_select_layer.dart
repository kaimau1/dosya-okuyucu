import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:pdfrx/pdfrx.dart';

/// PDF sayfası üzerinde **kendi metin seçim katmanımız**.
///
/// Niye kendimiz çiziyoruz: pdfrx 1.3.x'in SelectionArea tabanlı seçimi
/// Android'de güvenilir değil (uzun basış tepki verir ama vurgu çıkmaz);
/// düzgün seçim 2.x'te yeniden yazıldı ama 2.x bu projede KULLANILAMAZ —
/// motoru (pdfrx_engine) Dart >=3.8.1 ve `archive ^4` istiyor, CI Dart 3.7 +
/// excel paketinin `archive ^3` kısıtıyla çözümlenemiyor (bkz. HAFIZA).
///
/// Yöntem: pdfium'un karakter kutuları (`charRects`) sayfa koordinatından
/// ekran koordinatına çevrilir; parmak sürüklemesi (veya uzun basışla kelime)
/// karakter aralığına eşlenir, vurgu boyanır, seçilen metin [onSelected] ile
/// üst katmana bildirilir (oradan panoya kopyalanır).
class PdfSelectLayer extends StatefulWidget {
  final PdfPage page;

  /// Sayfanın ekrandaki (ölçekli) boyutu — overlay tam sayfayı kaplar.
  final Size pageSize;

  /// Seçim her değiştiğinde çağrılır. [rects] seçili metnin PDF-koordinat
  /// dikdörtgenleri (satır başına bir; kalıcı vurgu annotation'ı için),
  /// [pageNumber] bu katmanın sayfası (1-tabanlı). Boş metin = seçim temizlendi.
  final void Function(String text, List<PdfRect> rects, int pageNumber)
      onSelected;

  /// Seçim üstündeki "Kopyala" balonuna basılınca çağrılır.
  final VoidCallback? onCopy;

  const PdfSelectLayer({
    super.key,
    required this.page,
    required this.pageSize,
    required this.onSelected,
    this.onCopy,
  });

  @override
  State<PdfSelectLayer> createState() => _PdfSelectLayerState();
}

class _PdfSelectLayerState extends State<PdfSelectLayer> {
  final _overlayKey = GlobalKey(); // global→local çevirisi (tutamaç sürükleme)
  PdfPageText? _text;
  int? _anchor; // seçim çapası (karakter indeksi, fullText üzerinde)
  int? _extent; // seçim ucu (dahil)

  @override
  void initState() {
    super.initState();
    widget.page.loadText().then((t) {
      if (mounted) setState(() => _text = t);
    }).catchError((_) {});
  }

  int get _selStart =>
      _anchor == null || _extent == null ? 0 : (_anchor! < _extent! ? _anchor! : _extent!);
  int get _selEnd =>
      _anchor == null || _extent == null ? -1 : (_anchor! > _extent! ? _anchor! : _extent!);

  String get _selectedText {
    final t = _text;
    if (t == null || _anchor == null || _extent == null) return '';
    final s = _selStart;
    final e = (_selEnd + 1).clamp(0, t.fullText.length);
    if (s >= e) return '';
    return t.fullText.substring(s, e);
  }

  /// [local] noktasına en yakın karakterin fullText indeksi (yoksa null).
  /// [maxDist]: kutu dışına bu kadar piksele kadar tolerans (parmak kalın).
  int? _charIndexAt(Offset local, {double maxDist = 28}) {
    final t = _text;
    if (t == null) return null;
    int? best;
    var bestD = maxDist * maxDist;
    for (final f in t.fragments) {
      final fr = f.bounds
          .toRect(page: widget.page, scaledPageSize: widget.pageSize)
          .inflate(maxDist);
      if (!fr.contains(local)) continue;
      final n = f.charRects.length;
      for (var i = 0; i < n; i++) {
        final r = f.charRects[i]
            .toRect(page: widget.page, scaledPageSize: widget.pageSize);
        final dx = local.dx < r.left
            ? r.left - local.dx
            : (local.dx > r.right ? local.dx - r.right : 0.0);
        final dy = local.dy < r.top
            ? r.top - local.dy
            : (local.dy > r.bottom ? local.dy - r.bottom : 0.0);
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = f.index + i;
        }
      }
    }
    return best;
  }

  static bool _isWordChar(String ch) => ch.trim().isNotEmpty;

  void _selectWordAt(Offset local) {
    final t = _text;
    final i = _charIndexAt(local);
    if (t == null || i == null) return;
    final s = t.fullText;
    var a = i, b = i;
    while (a > 0 && _isWordChar(s[a - 1])) {
      a--;
    }
    while (b + 1 < s.length && _isWordChar(s[b + 1])) {
      b++;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _anchor = a;
      _extent = b;
    });
    _report();
  }

  /// [index] karakterinin ekran dikdörtgeni (tutamaç/balon konumu için).
  Rect? _charRect(int index) {
    final t = _text;
    if (t == null) return null;
    for (final f in t.fragments) {
      final local = index - f.index;
      if (local < 0 || local >= f.charRects.length) continue;
      return f.charRects[local]
          .toRect(page: widget.page, scaledPageSize: widget.pageSize);
    }
    return null;
  }

  /// Tutamaç sürüklendi: [global] parmak noktasını en yakın karaktere eşle,
  /// seçimin ilgili ucunu (başı ya da sonu) oraya taşı, diğer ucu sabit tut.
  void _dragHandle(bool isStart, Offset global) {
    final box = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final i = _charIndexAt(box.globalToLocal(global), maxDist: 80);
    if (i == null) return;
    final fixed = isStart ? _selEnd : _selStart;
    setState(() {
      _anchor = fixed;
      _extent = i;
    });
  }

  void _clear() {
    if (_anchor == null && _extent == null) return;
    setState(() {
      _anchor = null;
      _extent = null;
    });
    widget.onSelected('', const [], widget.page.pageNumber);
  }

  void _report() {
    final t = _text;
    final rects =
        t == null ? const <PdfRect>[] : selectionPdfRects(t, _selStart, _selEnd);
    widget.onSelected(_selectedText, rects, widget.page.pageNumber);
  }

  bool get _hasSelection =>
      _anchor != null && _extent != null && _selEnd >= _selStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Stack(
        key: _overlayKey,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _clear(),
            onPanStart: (d) {
              final i = _charIndexAt(d.localPosition);
              setState(() {
                _anchor = i;
                _extent = i;
              });
            },
            onPanUpdate: (d) {
              if (_anchor == null) return;
              final i = _charIndexAt(d.localPosition, maxDist: 64);
              if (i != null && i != _extent) setState(() => _extent = i);
            },
            onPanEnd: (_) => _report(),
            onLongPressStart: (d) => _selectWordAt(d.localPosition),
            onLongPressMoveUpdate: (d) {
              if (_anchor == null) return;
              final i = _charIndexAt(d.localPosition, maxDist: 64);
              if (i != null && i != _extent) setState(() => _extent = i);
            },
            onLongPressEnd: (_) => _report(),
            child: CustomPaint(
              size: widget.pageSize,
              painter: _SelectionPainter(
                text: _text,
                page: widget.page,
                pageSize: widget.pageSize,
                start: _selStart,
                end: _selEnd,
                color: scheme.primary.withOpacity(0.35),
              ),
            ),
          ),
          if (_hasSelection) ...[
            _handle(isStart: true, color: scheme.primary),
            _handle(isStart: false, color: scheme.primary),
            if (widget.onCopy != null) _copyBubble(scheme),
          ],
        ],
      ),
    );
  }

  /// Seçim ucundaki sürüklenebilir tutamaç (telefonun yerel seçim hissi).
  Widget _handle({required bool isStart, required Color color}) {
    final r = _charRect(isStart ? _selStart : _selEnd);
    if (r == null) return const SizedBox.shrink();
    final point = isStart ? Offset(r.left, r.bottom) : Offset(r.right, r.bottom);
    const touch = 40.0, dot = 18.0;
    return Positioned(
      left: point.dx - touch / 2,
      top: point.dy - touch / 2 + 6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _dragHandle(isStart, d.globalPosition),
        onPanEnd: (_) => _report(),
        child: SizedBox(
          width: touch,
          height: touch,
          child: Center(
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Seçimin üstünde beliren küçük "Kopyala" balonu.
  Widget _copyBubble(ColorScheme scheme) {
    final r = _charRect(_selStart);
    if (r == null) return const SizedBox.shrink();
    const w = 108.0, h = 40.0;
    final above = r.top - h - 6 >= 0;
    final left =
        (r.left - 20).clamp(0.0, (widget.pageSize.width - w).clamp(0.0, double.infinity));
    final top = above ? r.top - h - 6 : r.bottom + 6;
    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.black.withOpacity(0.82),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _report();
            widget.onCopy?.call();
          },
          child: const SizedBox(
            width: w,
            height: h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('Kopyala', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [text]'in [start]..[end] (dahil) aralığını kaplayan, satır/parça başına bir
/// `PdfRect` (PDF koordinatı) listesi. Ekran seçim boyaması (`_SelectionPainter`)
/// ile kalıcı vurgu annotation'ı (`PdfAnnotator`) AYNI geometriyi kullansın diye
/// ortak. Parça çoğunlukla tek satırdır → aralık kutusu tek dikdörtgen yeter.
List<PdfRect> selectionPdfRects(PdfPageText text, int start, int end) {
  final out = <PdfRect>[];
  if (end < start) return out;
  for (final f in text.fragments) {
    final a = start - f.index;
    final b = end + 1 - f.index; // hariç
    final s = a < 0 ? 0 : a;
    final e = b > f.length ? f.length : b;
    if (s >= e) continue;
    PdfRect? bounds;
    try {
      bounds = f.getBoundsForRange(start: s, end: e);
    } catch (_) {
      bounds = f.bounds;
    }
    if (bounds != null) out.add(bounds);
  }
  return out;
}

class _SelectionPainter extends CustomPainter {
  final PdfPageText? text;
  final PdfPage page;
  final Size pageSize;
  final int start;
  final int end; // dahil; start > end ise seçim yok
  final Color color;

  _SelectionPainter({
    required this.text,
    required this.page,
    required this.pageSize,
    required this.start,
    required this.end,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = text;
    if (t == null || end < start) return;
    final paint = Paint()..color = color;
    for (final bounds in selectionPdfRects(t, start, end)) {
      final r = bounds.toRect(page: page, scaledPageSize: pageSize);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.inflate(1.5), const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.text != text ||
      old.start != start ||
      old.end != end ||
      old.pageSize != pageSize ||
      old.color != color;
}
