import 'dart:async';
import 'dart:math' as math;

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
/// **KÖK NEDEN — katman neden hiç `GestureDetector` kullanmıyor
/// (2026-07-26, 10. tur).** Kullanıcının bu turların EN BAŞINDA bildirdiği
/// *"sayfayı kaydıramıyorum, zoom yapamıyorum"* hatası, sanılanın aksine üst
/// çubuktaki seçim modundan değil, bu katmanın kendisinden geliyordu:
///
/// Katman sayfanın üstünde durduğu için `GestureDetector`'ın
/// `LongPressGestureRecognizer`'ı HER dokunuşta jest arenasına giriyordu.
/// Arena kuralı gereği uzun basış, süresi (500 ms) dolduğunda kazanır ve
/// öteki tanıyıcıları eler:
/// * Parmağını yarım saniye dinlendirip sonra kaydırmaya başlayan kullanıcıda
///   uzun basış kazanıyor → **sayfa kaymıyor.**
/// * İki parmağını koyup açmadan önce bir an duraklayan kullanıcıda yine uzun
///   basış kazanıyor, pdfrx'in ölçek tanıyıcısı eleniyor → **zoom ölü.**
/// Telefonda ikisi de son derece olağan hareketler; bu yüzden hata "bazen"
/// değil "sürekli" hissediliyordu.
///
/// Çözüm: katman artık **hiçbir jest tanıyıcısı kurmuyor.** Yalnız bir
/// [Listener] var — `Listener` işaretçi olaylarını dinler ama arenaya HİÇ
/// girmez, dolayısıyla pdfrx'in kaydırma/yakınlaştırmasıyla yarışması
/// olanaksız. Uzun basış elle ölçülüyor (zamanlayıcı + kayma toleransı +
/// ikinci parmak iptali).
///
/// Bunun bilinçli bedeli: uzun basıştan sonra parmağı sürükleyerek seçimi
/// büyütmek yok — o sürükleme sayfayı kaydırır. Seçim, uçlardaki
/// **tutamaçlardan** büyütülür (Android'in yerel davranışı da budur).
/// Kazancı: katmanın en kötü arıza biçimi artık "seçim çalışmıyor"; gezinmeyi
/// kilitlemesi yapısal olarak mümkün değil.
///
/// **REDDEDİLEN yol (denendi, geri alındı):** uzun basış tanıyıcısını bırakıp
/// "iki parmak inince kendini reddet" koruması eklemek. Parmak sayacı SAYFA
/// BAŞINA tutulduğu için iki parmak ayrı katmanlara düşünce çalışmıyor;
/// katman yeniden kurulunca da sayaç takılı kalıp her dokunuşta reddediyor,
/// bu da pdfrx'in kaydırmasını kayma toleransı olmadan kazandırıp "sayfa
/// kaynıyor" hatasını üretiyordu.
class PdfSelectLayer extends StatefulWidget {
  final PdfPage page;

  /// Sayfanın ekrandaki (ölçekli) boyutu — overlay tam sayfayı kaplar.
  final Size pageSize;

  /// Seçim her değiştiğinde çağrılır. [rects] seçili metnin PDF-koordinat
  /// dikdörtgenleri (satır başına bir; kalıcı vurgu annotation'ı için),
  /// [pageNumber] bu katmanın sayfası (1-tabanlı). Boş metin = seçim temizlendi.
  ///
  /// [precedingText] seçimden hemen ÖNCEKİ metindir: aynı kelime sayfada
  /// birkaç kez geçtiğinde yerinde düzenlemenin doğru geçişi bulmasını sağlar
  /// (bkz. `PdfContentEditor.replaceText`).
  final void Function(
    String text,
    List<PdfRect> rects,
    int pageNumber,
    String precedingText,
  ) onSelected;

  const PdfSelectLayer({
    super.key,
    required this.page,
    required this.pageSize,
    required this.onSelected,
  });

  @override
  State<PdfSelectLayer> createState() => _PdfSelectLayerState();
}

class _PdfSelectLayerState extends State<PdfSelectLayer> {
  final _overlayKey = GlobalKey(); // global→local çevirisi (tutamaç sürükleme)
  PdfPageText? _text;
  int? _anchor; // seçim çapası (karakter indeksi, fullText üzerinde)
  int? _extent; // seçim ucu (dahil)

  // ── Elle uzun basış ölçümü (jest arenasına girmeden) ─────────────────────
  //
  // Kurallar telefonun yerel davranışıyla aynı: tek parmak, kıpırdamadan
  // [_longPressDelay] kadar basılı kalırsa kelime seçilir.
  static const _longPressDelay = Duration(milliseconds: 500);

  /// Parmağın "kıpırdamadı" sayılacağı en büyük kayma (Flutter'ın kTouchSlop'u).
  static const _slop = 18.0;

  /// Ekranda olan işaretçiler. İkinci parmak inince uzun basış iptal edilir —
  /// iki parmak "yakınlaştırıyorum" demektir.
  final _pointers = <int>{};

  Timer? _pressTimer;
  int? _pressPointer;
  Offset _pressStart = Offset.zero;

  /// Bu dokunuşta uzun basış ateşlendi mi? (Parmak kalkınca "boş dokunuş"
  /// sayılıp seçimin temizlenmemesi için.)
  bool _pressFired = false;

  @override
  void initState() {
    super.initState();
    widget.page.loadText().then((t) {
      if (mounted) setState(() => _text = t);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  void _cancelPress() {
    _pressTimer?.cancel();
    _pressTimer = null;
    _pressPointer = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1) {
      // Yakınlaştırma başlıyor: uzun basış ölçümünü bırak.
      _cancelPress();
      return;
    }
    _pressFired = false;
    _pressPointer = event.pointer;
    _pressStart = event.localPosition;
    _pressTimer?.cancel();
    _pressTimer = Timer(_longPressDelay, () {
      _pressTimer = null;
      if (!mounted || _pressPointer == null) return;
      _pressFired = true;
      _selectWordAt(_pressStart);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pressPointer || _pressTimer == null) return;
    if ((event.localPosition - _pressStart).distance > _slop) {
      // Kaydırma: uzun basış değil. (Sayfa zaten pdfrx tarafından kaydırılıyor;
      // bizim iptal etmemiz yalnız yanlışlıkla seçim yapılmasını önler.)
      _cancelPress();
    }
  }

  void _onPointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    final wasMeasuring = _pressPointer == event.pointer;
    if (wasMeasuring) _cancelPress();
    // Boş dokunuş (kısa, kıpırdamadan, seçim yapmadan) → seçimi temizle.
    // Telefonun yerel davranışı. Uzun basış ateşlendiyse ya da parmak
    // kaydıysa dokunulmaz.
    if (wasMeasuring && !_pressFired && _hasSelection) {
      final moved = (event.localPosition - _pressStart).distance;
      if (moved <= _slop) _clear();
    }
    if (_pointers.isEmpty) _pressFired = false;
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
    widget.onSelected('', const [], widget.page.pageNumber, '');
  }

  /// Seçimden önceki en çok 40 karakter — yerinde düzenlemenin doğru geçişi
  /// bulması için bağlam.
  String get _precedingText {
    final t = _text;
    if (t == null || !_hasSelection) return '';
    final start = _selStart;
    final from = start - 40 < 0 ? 0 : start - 40;
    if (from >= start) return '';
    return t.fullText.substring(from, start);
  }

  void _report() {
    final t = _text;
    final rects =
        t == null ? const <PdfRect>[] : selectionPdfRects(t, _selStart, _selEnd);
    widget.onSelected(
        _selectedText, rects, widget.page.pageNumber, _precedingText);
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
          // Listener — GestureDetector DEĞİL. Arenaya girmediği için pdfrx'in
          // kaydırma/yakınlaştırmasıyla yarışamaz (sınıf açıklamasındaki kök
          // nedene bakın). translucent: parmak alttaki sayfaya da geçer.
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerUp,
            child: CustomPaint(
              size: widget.pageSize,
              painter: _SelectionPainter(
                text: _text,
                page: widget.page,
                pageSize: widget.pageSize,
                start: _selStart,
                end: _selEnd,
                color: scheme.primary.withValues(alpha: 0.28),
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [text]'in [start]..[end] (dahil) aralığını kaplayan, **satır başına bir**
/// `PdfRect` (PDF koordinatı) listesi. Ekran seçim boyaması
/// (`_SelectionPainter`) ile kalıcı vurgu annotation'ı (`PdfAnnotator`) AYNI
/// geometriyi kullansın diye ortak.
///
/// Aynı satırdaki parçalar BİRLEŞTİRİLİR. Niye (2026-07-26 kullanıcı bulgusu:
/// "kelime aralarında çıkan koyuluklar göz yoruyor"): PDF üreticileri bir
/// satırı kelime kelime (hatta harf harf) ayrı parçalara böler; her parça ayrı
/// yarı saydam dikdörtgen olarak boyanınca kelime aralarındaki örtüşmeler üst
/// üste binip koyu şeritler yapıyordu. Satır tek dikdörtgen olunca seçim
/// telefonun yerel seçimi gibi düz ve tek tonlu görünür.
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
  return mergeSameLineRects(out);
}

/// Dikey olarak örtüşen (aynı satırdaki) dikdörtgenleri tek dikdörtgende
/// birleştirir. Sıra korunur: ilk satır listenin başında kalır.
List<PdfRect> mergeSameLineRects(List<PdfRect> rects) {
  final out = <PdfRect>[];
  for (final r in rects) {
    if (r.top <= r.bottom) continue; // bozuk/boş kutu
    var merged = false;
    for (var i = 0; i < out.length; i++) {
      final o = out[i];
      final overlap = math.min(o.top, r.top) - math.max(o.bottom, r.bottom);
      final minHeight = math.min(o.top - o.bottom, r.top - r.bottom);
      // Satır yüksekliğinin yarısından fazlası örtüşüyorsa aynı satırdır.
      if (minHeight > 0 && overlap > minHeight * 0.5) {
        out[i] = PdfRect(
          math.min(o.left, r.left),
          math.max(o.top, r.top),
          math.max(o.right, r.right),
          math.min(o.bottom, r.bottom),
        );
        merged = true;
        break;
      }
    }
    if (!merged) out.add(r);
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
    // TEK yol olarak çiziyoruz: iki satır kutusu birbirine değse bile yarı
    // saydam renk üst üste binmez, seçim her yerde aynı tonda kalır.
    final path = Path();
    for (final bounds in selectionPdfRects(t, start, end)) {
      final r = bounds.toRect(page: page, scaledPageSize: pageSize);
      path.addRRect(
        RRect.fromRectAndRadius(r.inflate(0.5), const Radius.circular(2)),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.text != text ||
      old.start != start ||
      old.end != end ||
      old.pageSize != pageSize ||
      old.color != color;
}
