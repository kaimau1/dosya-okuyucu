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
/// ekran koordinatına çevrilir; uzun basış kelimeyi seçer, uçlardaki tutamaçlar
/// seçimi büyütür/küçültür, seçilen metin [onSelected] ile üst katmana bildirilir.
///
/// **Kullanım biçimi (2026-07-26 sadeleştirmesi).** Eskiden seçim yapabilmek
/// için üst çubuktan "Metin seç" modunu açmak ZORUNLUYDU; kullanıcı bunu
/// "kullanışsız" buldu — telefonda metin seçmek uzun basmaktır, mod açmak değil.
/// Artık:
/// * Katman DAİMA sayfanın üzerindedir ve **uzun basış** her zaman seçer.
/// * Seçim yokken katman parmağı yutmaz ([enableDragSelect] false) → sayfa
///   normal kaydırılır/yakınlaştırılır, köprüler çalışır.
/// * Seçim varken tek dokunuş seçimi temizler (telefonun yerel davranışı).
/// * [enableDragSelect] yalnız açık "sürükleyerek seç" modunda true olur; o
///   modda sayfa kaydırma zaten kapatılır (`panEnabled: false`).
class PdfSelectLayer extends StatefulWidget {
  final PdfPage page;

  /// Sayfanın ekrandaki (ölçekli) boyutu — overlay tam sayfayı kaplar.
  final Size pageSize;

  /// Seçim her değiştiğinde çağrılır. [rects] seçili metnin PDF-koordinat
  /// dikdörtgenleri (satır başına bir; kalıcı vurgu annotation'ı için),
  /// [pageNumber] bu katmanın sayfası (1-tabanlı). Boş metin = seçim temizlendi.
  final void Function(String text, List<PdfRect> rects, int pageNumber)
      onSelected;

  /// Tek parmak sürüklemesi seçim yapsın mı? Yalnız açık seçim modunda true;
  /// false iken sürükleme sayfayı kaydırır (katman parmağı yutmaz).
  final bool enableDragSelect;

  const PdfSelectLayer({
    super.key,
    required this.page,
    required this.pageSize,
    required this.onSelected,
    this.enableDragSelect = false,
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

  int get _selStart => _anchor == null || _extent == null
      ? 0
      : (_anchor! < _extent! ? _anchor! : _extent!);
  int get _selEnd => _anchor == null || _extent == null
      ? -1
      : (_anchor! > _extent! ? _anchor! : _extent!);

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
    // Uzun basış boşluğa denk gelirse tolerans büyük tutulur: kullanıcı
    // "yazının üstüne" bastığını sanır, birkaç piksel ıskalamak sinir bozucu.
    final i = _charIndexAt(local, maxDist: 44);
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

  /// [index] karakterinin ekran dikdörtgeni (tutamaç konumu için).
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
    // Parmak tutamacın ORTASINDA değil, ucundadır; hedefi biraz yukarı al ki
    // kullanıcı gördüğü karakteri seçsin, altındakini değil.
    final local = box.globalToLocal(global) - const Offset(0, 14);
    final i = _charIndexAt(local, maxDist: 90);
    if (i == null) return;
    final fixed = isStart ? _selEnd : _selStart;
    if (fixed < 0) return;
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
    final dragSelect = widget.enableDragSelect;
    return Positioned.fill(
      child: Stack(
        key: _overlayKey,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            // translucent: seçim yokken sayfa kaydırma/köprü dokunuşu üstteki
            // katmana takılmasın. Sürükleme tanıyıcısı yalnız açık seçim
            // modunda kuruluyor (aksi hâlde pdfrx'in pan'iyle çekişirdi).
            behavior: dragSelect
                ? HitTestBehavior.opaque
                : HitTestBehavior.translucent,
            // Seçim varken dokunuş temizler (telefonun yerel davranışı). Seçim
            // yokken dokunuş tanıyıcısı HİÇ kurulmaz → köprüler çalışmaya devam.
            onTapDown: _hasSelection ? (_) => _clear() : null,
            onPanStart: !dragSelect
                ? null
                : (d) {
                    final i = _charIndexAt(d.localPosition);
                    setState(() {
                      _anchor = i;
                      _extent = i;
                    });
                  },
            onPanUpdate: !dragSelect
                ? null
                : (d) {
                    if (_anchor == null) return;
                    final i = _charIndexAt(d.localPosition, maxDist: 64);
                    if (i != null && i != _extent) setState(() => _extent = i);
                  },
            onPanEnd: !dragSelect ? null : (_) => _report(),
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
          ],
        ],
      ),
    );
  }

  /// Seçim ucundaki sürüklenebilir tutamaç (telefonun yerel seçim hissi).
  ///
  /// Dokunma alanı 48 px: Material'ın en küçük dokunma hedefi. Eskiden 40'tı ve
  /// nokta 18 px'di — kullanıcı "tutamacı yakalayamıyorum" diyordu.
  Widget _handle({required bool isStart, required Color color}) {
    final r = _charRect(isStart ? _selStart : _selEnd);
    if (r == null) return const SizedBox.shrink();
    final point = isStart ? Offset(r.left, r.bottom) : Offset(r.right, r.bottom);
    const touch = 48.0, dot = 20.0;
    return Positioned(
      left: point.dx - touch / 2,
      top: point.dy - touch / 2 + 10,
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
