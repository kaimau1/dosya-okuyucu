import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, PointerHoverEvent, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:pdfrx/pdfrx.dart';

import '../core/l10n/app_strings.dart';
import '../services/pdf/ocr_page_text.dart' show OcrPageText;
import '../services/pdf/pdf_ocr_text.dart';

/// PDF sayfası üzerinde **kendi metin seçim katmanımız** — hedef davranış
/// Chrome'un PDF görüntüleyicisi: yazılmış ya da TARANMIŞ fark etmeden,
/// sayfadaki metin normal metin gibi seçilir.
///
/// Yetenekler (2026-08-05 "premium seçim" turu):
/// * Uzun basış kelimeyi seçer; parmak KALKMADAN sürüklenirse seçim kelime
///   kelime büyür (Chrome/Android yerlisi gibi). Sürükleme sırasında sayfa
///   kaymasın diye üst katman [onSelectingChanged] ile pan'ı kilitler —
///   kilit YALNIZ parmak yere basılıyken sürer, kalınca hemen açılır.
/// * Sürüklerken parmağın üstünde **büyüteç** (RawMagnifier) gezer.
/// * Uçlardaki tutamaçlar karakter hassasiyetinde büyütür/küçültür.
/// * Fare (masaüstü): metnin üstünde imleç I-kirişine döner, bas-sürükle
///   karakter karakter seçer, çift tık kelime seçer, boşluğa tık temizler.
///   Metin DIŞINDA bas-sürükle sayfayı kaydırmaya devam eder.
/// * Metin katmanı olmayan (taranmış) sayfada uzun basış cihaz-içi OCR'ı
///   tetikler ("Metin tanınıyor…" çipi), sonuç [PdfOcrText] önbelleğine girer
///   ve seçim pdfium metniyle AYNI yoldan çalışır (bkz. `OcrPageText`).
///
/// Niye kendimiz çiziyoruz: pdfrx 1.3.x'in SelectionArea tabanlı seçimi
/// Android'de güvenilir değil (uzun basış tepki verir ama vurgu çıkmaz);
/// düzgün seçim 2.x'te yeniden yazıldı ama 2.x bu projede KULLANILAMAZ —
/// motoru (pdfrx_engine) Dart >=3.8.1 ve `archive ^4` istiyor, CI Dart 3.7 +
/// excel paketinin `archive ^3` kısıtıyla çözümlenemiyor (bkz. HAFIZA).
///
/// **ASIL KÖK NEDEN — `CustomPaint` bütün dokunuşları yutuyordu
/// (2026-07-26, 11. tur).** Kullanıcının bu turların EN BAŞINDAN beri
/// bildirdiği *"sayfayı kaydıramıyorum, zoom yapamıyorum"* hatasının sebebi
/// buydu; ayrıntı ve mekanizma [_SelectionPainter.hitTest] açıklamasında.
/// Özeti: `painter:` verilen bir `CustomPaint`, `hitTest` geçersiz kılınmazsa
/// kapladığı alandaki her dokunuşu yutar; bu katmanın boyayıcısı da sayfanın
/// TAMAMINI kaplıyordu, dolayısıyla pdfrx'in `InteractiveViewer`'ı işaretçiyi
/// hiç görmüyordu.
///
/// **İKİNCİ neden — katman neden hiç jest tanıyıcısı kullanmıyor (10. tur).**
/// Katman sayfanın üstünde durduğu için buraya konacak bir uzun basış
/// tanıyıcısı HER dokunuşta jest arenasına girer; süresi dolunca kazanıp
/// pdfrx'in kaydırma/ölçek tanıyıcılarını eler. Parmağını bir an dinlendirip
/// kaydıran ya da iki parmağını koyup duraklayan kullanıcıda gezinme tümüyle
/// ölür. Bu yüzden katman yalnız bir [Listener] kullanır — `Listener`
/// işaretçi olaylarını dinler ama arenaya HİÇ girmez; uzun basış elle ölçülür
/// (zamanlayıcı + kayma toleransı + ikinci parmak iptali).
///
/// Uzun basış SONRASI sürükleyerek seçimi büyütmek bu tasarımda şöyle mümkün
/// oluyor (eski sürümde hiç yoktu): seçim başladığı anda üst katman
/// `panEnabled: false` yapar; pdfrx'in tanıyıcısı olayları almaya devam eder
/// ama pan uygulamaz (`InteractiveViewer` bayrağı HER olayda yeniden okur),
/// bizim `Listener` da aynı olayları arenasız gördüğü için seçimi büyütür.
/// Kilit parmak kalkınca (up/cancel/ikinci parmak) kalkar — eski
/// "seçim modu açıkken pan hep kapalı" hatasına (HAFIZA 2026-07-26) dönüş yok.
class PdfSelectLayer extends StatefulWidget {
  final PdfPage page;

  /// Sayfanın ekrandaki (ölçekli) boyutu — overlay tam sayfayı kaplar.
  final Size pageSize;

  /// Seçim her değiştiğinde çağrılır. [rects] seçili metnin PDF-koordinat
  /// dikdörtgenleri (satır başına bir; kalıcı vurgu annotation'ı için),
  /// [pageNumber] bu katmanın sayfası (1-tabanlı). Boş metin = seçim
  /// temizlendi. [precedingText] seçimden hemen önceki metin (yerinde
  /// düzenlemenin doğru geçişi bulması için). [fromOcr] true ise metin
  /// taranmış sayfadan OCR ile geldi — sayfada gerçek metin katmanı YOK,
  /// yerinde düzenleme yapılamaz (vurgu/kopya/çeviri çalışır).
  final void Function(
    String text,
    List<PdfRect> rects,
    int pageNumber,
    String precedingText,
    bool fromOcr,
  ) onSelected;

  /// Parmakla/fareyle SÜRÜKLEYEREK seçim o an sürüyor mu? Üst katman true
  /// iken pan'ı kilitler (sayfa kaymadan seçim büyüsün), false olunca açar.
  final ValueChanged<bool>? onSelectingChanged;

  const PdfSelectLayer({
    super.key,
    required this.page,
    required this.pageSize,
    required this.onSelected,
    this.onSelectingChanged,
  });

  @override
  State<PdfSelectLayer> createState() => _PdfSelectLayerState();
}

class _PdfSelectLayerState extends State<PdfSelectLayer> {
  final _overlayKey = GlobalKey(); // global→local çevirisi (tutamaç sürükleme)
  PdfPageText? _text;

  /// `loadText` bitti mi? Bitmeden OCR'a düşülmez: hızlı bir uzun basış,
  /// metin katmanı OLAN sayfayı yanlışlıkla OCR'a göndermesin.
  bool _textLoaded = false;

  /// [_text] OCR'dan mı geldi (taranmış sayfa)?
  bool _fromOcr = false;

  int? _anchor; // seçim çapası (karakter indeksi, fullText üzerinde)
  int? _extent; // seçim ucu (dahil)

  // ── Elle uzun basış ölçümü (jest arenasına girmeden) ─────────────────────
  static const _longPressDelay = Duration(milliseconds: 500);

  /// Parmağın "kıpırdamadı" sayılacağı en büyük kayma (Flutter'ın kTouchSlop'u).
  static const _slop = 18.0;

  /// "En yakın karakteri bul" için sınırsız tolerans: sürükleme sırasında
  /// parmak kenar boşluğuna taşsa da seçim en yakın satıra kilitli kalır
  /// (Chrome satır sonuna kadar seçer; ölçü uzaklık karesi, taşmaz).
  static const _unbounded = 1.0e9;

  /// Ekranda olan işaretçiler. İkinci parmak inince uzun basış/seçim bırakılır —
  /// iki parmak "yakınlaştırıyorum" demektir.
  final _pointers = <int>{};

  Timer? _pressTimer;
  int? _pressPointer;
  Offset _pressStart = Offset.zero;

  /// Bu dokunuşta uzun basış ateşlendi mi? (Parmak kalkınca "boş dokunuş"
  /// sayılıp seçimin temizlenmemesi için.)
  bool _pressFired = false;

  // ── Uzun basış sonrası sürükleyerek büyütme ──────────────────────────────
  /// Uzun basışla seçilen ÇAPA kelimenin sınırları: sürükleme bu kelimeyi hep
  /// içeride tutar (Android/Chrome davranışı).
  bool _dragSelecting = false;
  int _dragAnchorStart = 0;
  int _dragAnchorEnd = -1;

  /// Sürüklerken parmağın üstünde gezen büyütecin yeri (yoksa kapalı).
  Offset? _magnifier;

  /// [onSelectingChanged]'e en son bildirilen değer (tekrarları ele).
  bool _notifiedSelecting = false;

  // ── Fare (masaüstü) ──────────────────────────────────────────────────────
  bool _mouseSelecting = false;
  bool _mouseMoved = false;
  bool _mouseWordSelected = false; // çift tık kelime seçti (up temizlemesin)
  int _mouseAnchorChar = 0;
  Offset _mouseDownPos = Offset.zero;
  DateTime? _lastMouseDownAt;
  Offset _lastMouseDownPos = Offset.zero;
  bool _hoverOnText = false;

  // ── Taranmış sayfa: OCR durumu ───────────────────────────────────────────
  bool _ocrRunning = false;
  bool _ocrTried = false;
  bool _ocrEmpty = false; // "metin bulunamadı" çipi kısa süre görünür
  Timer? _ocrEmptyTimer;

  // ── Karakter kutusu önbelleği ────────────────────────────────────────────
  //
  // "En yakın karakter" araması sürüklemede HER işaretçi olayında koşar;
  // her seferinde PdfRect→Rect çevirisi yapmak yoğun sayfada takılma yapar.
  // Kutular metin/sayfa boyutu değişene dek düz dizide tutulur.
  List<Rect> _charScreenRects = const [];
  List<int> _charTextIndex = const [];
  PdfPageText? _geomText;
  Size? _geomSize;

  @override
  void initState() {
    super.initState();
    widget.page.loadText().then((t) {
      if (mounted) {
        setState(() {
          _text = t;
          _textLoaded = true;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _textLoaded = true);
    });
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _ocrEmptyTimer?.cancel();
    if (_notifiedSelecting) {
      // Katman aktif seçim ortasında sökülürse pan kilidi üstte asılı
      // kalmasın. dispose içinde parent setState'i çağrılamaz → kare sonuna.
      final cb = widget.onSelectingChanged;
      WidgetsBinding.instance.addPostFrameCallback((_) => cb?.call(false));
    }
    super.dispose();
  }

  void _setSelecting(bool v) {
    if (_notifiedSelecting == v) return;
    _notifiedSelecting = v;
    widget.onSelectingChanged?.call(v);
  }

  void _cancelPress() {
    _pressTimer?.cancel();
    _pressTimer = null;
    _pressPointer = null;
  }

  // ═══ Dokunma (parmak/kalem) ═══════════════════════════════════════════════

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      _onMouseDown(event);
      return;
    }
    _pointers.add(event.pointer);
    if (_pointers.length > 1) {
      // Yakınlaştırma başlıyor: uzun basış ölçümünü ve sürükleme seçimini
      // bırak (pan kilidi de açılır ki iki parmak jesti özgür kalsın).
      _cancelPress();
      if (_dragSelecting) _endTouchDragSelection();
      return;
    }
    _pressFired = false;
    _pressPointer = event.pointer;
    _pressStart = event.localPosition;
    _pressTimer?.cancel();
    _pressTimer = Timer(_longPressDelay, () {
      _pressTimer = null;
      final pointer = _pressPointer;
      if (!mounted || pointer == null) return;
      _pressFired = true;
      _beginTouchSelection(_pressStart, pointer);
    });
  }

  /// Uzun basış ateşlendi: kelimeyi seç ve sürükleyerek büyütme kipine gir.
  /// Metin yoksa (taranmış sayfa) OCR'ı tetikle.
  void _beginTouchSelection(Offset at, int pointer) {
    if (_selectWordAt(at)) {
      _dragAnchorStart = _selStart;
      _dragAnchorEnd = _selEnd;
      _dragSelecting = true;
      _setSelecting(true);
      setState(() => _magnifier = at);
    } else if (_shouldTryOcr) {
      _startOcr(at, pointer);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      _onMouseMove(event);
      return;
    }
    if (_dragSelecting && event.pointer == _pressPointer) {
      _extendDragTo(event.localPosition);
      setState(() => _magnifier = event.localPosition);
      return;
    }
    if (event.pointer != _pressPointer || _pressTimer == null) return;
    if ((event.localPosition - _pressStart).distance > _slop) {
      // Kaydırma: uzun basış değil. (Sayfa zaten pdfrx tarafından kaydırılıyor;
      // bizim iptal etmemiz yalnız yanlışlıkla seçim yapılmasını önler.)
      _cancelPress();
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      _onMouseUp(event);
      return;
    }
    _pointers.remove(event.pointer);
    if (_dragSelecting && event.pointer == _pressPointer) {
      _endTouchDragSelection();
    }
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

  void _endTouchDragSelection() {
    _dragSelecting = false;
    _setSelecting(false);
    if (_magnifier != null) setState(() => _magnifier = null);
    _report();
  }

  /// Sürükleme ucunu [local] altındaki karaktere taşır — KELİME kelime
  /// (Chrome/Android yerel davranışı): çapa kelime hep seçili kalır, uç
  /// kelime sınırına yapışır.
  void _extendDragTo(Offset local) {
    final i = _charIndexAt(local, maxDist: _unbounded);
    if (i == null) return;
    final (ws, we) = _wordBoundsAt(i);
    final int a, b;
    if (i >= _dragAnchorStart) {
      a = _dragAnchorStart;
      b = math.max(we, _dragAnchorEnd);
    } else {
      a = ws;
      b = _dragAnchorEnd;
    }
    if (a != _selStart || b != _selEnd) {
      HapticFeedback.selectionClick();
      setState(() {
        _anchor = a;
        _extent = b;
      });
    }
  }

  // ═══ Fare (masaüstü/web) — Chrome davranışı ══════════════════════════════

  void _onMouseDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryButton == 0) return;
    final now = DateTime.now();
    final local = event.localPosition;
    final isDoubleClick = _lastMouseDownAt != null &&
        now.difference(_lastMouseDownAt!) < const Duration(milliseconds: 400) &&
        (local - _lastMouseDownPos).distance < 14;
    _lastMouseDownAt = now;
    _lastMouseDownPos = local;
    _mouseDownPos = local;
    _mouseMoved = false;
    _mouseWordSelected = false;
    if (isDoubleClick) {
      // Çift tık kelime seçer (Chrome). Tolerans dar: fare hassastır.
      _mouseWordSelected = _selectWordAt(local, tolerance: 8);
      return;
    }
    final i = _charIndexAt(local, maxDist: 8);
    if (i != null) {
      // Metnin üstünde basıldı: sürükleme SEÇİMDİR, kaydırma değil (Chrome).
      // Pan kilidi hemen konur ki ilk birkaç piksel pdfrx'e gitmesin;
      // metin dışında basılırsa kilit yok, sayfa fareyle kaydırılabilir.
      _mouseSelecting = true;
      _mouseAnchorChar = i;
      _setSelecting(true);
    }
  }

  void _onMouseMove(PointerMoveEvent event) {
    if (!_mouseSelecting || event.buttons & kPrimaryButton == 0) return;
    if (!_mouseMoved &&
        (event.localPosition - _mouseDownPos).distance < 4) {
      return; // titreme değil gerçek sürükleme olsun
    }
    _mouseMoved = true;
    final i = _charIndexAt(event.localPosition, maxDist: _unbounded);
    if (i == null) return;
    if (_anchor != _mouseAnchorChar || _extent != i) {
      setState(() {
        _anchor = _mouseAnchorChar;
        _extent = i;
      });
    }
  }

  void _onMouseUp(PointerEvent event) {
    if (_mouseSelecting) {
      _mouseSelecting = false;
      _setSelecting(false);
      if (_mouseMoved) {
        _report();
      } else if (!_mouseWordSelected && _hasSelection) {
        // Metne sürüklemeden tıklandı: seçim çöker (Chrome'daki gibi).
        _clear();
      }
      return;
    }
    if (!_mouseWordSelected &&
        _hasSelection &&
        (event.localPosition - _mouseDownPos).distance <= _slop) {
      _clear(); // boşluğa tık
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    final on = _charIndexAt(event.localPosition, maxDist: 4) != null;
    if (on != _hoverOnText) setState(() => _hoverOnText = on);
  }

  // ═══ Taranmış sayfa: OCR ═════════════════════════════════════════════════

  /// Uzun basış karaktere denk gelmediyse OCR denemeye değer mi?
  /// pdfium metni "ince" olmalı (yalnız sayfa numarası gibi kırıntılar da
  /// taranmış sayıdadır) ve bu sayfa için daha önce denenmemiş olmalı.
  bool get _shouldTryOcr =>
      _textLoaded &&
      !_ocrTried &&
      !_ocrRunning &&
      PdfOcrText.isSupported &&
      (_text?.fullText.trim().length ?? 0) < 8;

  Future<void> _startOcr(Offset at, int pointer) async {
    setState(() => _ocrRunning = true);
    OcrPageText? t;
    try {
      t = await PdfOcrText.forPage(widget.page);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _ocrRunning = false;
      _ocrTried = true;
      if (t != null) {
        _text = t;
        _fromOcr = true;
      }
    });
    if (t == null) {
      _flashOcrEmpty();
      return;
    }
    // Kullanıcının niyeti belliydi: bastığı kelimeyi şimdi seç. Parmak hâlâ
    // yerdeyse sürükleyerek büyütme kipi de açılır (Chrome hissi).
    if (_selectWordAt(at) && _pointers.contains(pointer)) {
      _dragAnchorStart = _selStart;
      _dragAnchorEnd = _selEnd;
      _dragSelecting = true;
      _setSelecting(true);
      setState(() => _magnifier = at);
    }
  }

  void _flashOcrEmpty() {
    _ocrEmptyTimer?.cancel();
    setState(() => _ocrEmpty = true);
    _ocrEmptyTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _ocrEmpty = false);
    });
  }

  // ═══ Seçim durumu / geometri ═════════════════════════════════════════════

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

  /// Karakter kutularının ekran-koordinat önbelleğini tazeler (gerekirse).
  void _ensureGeometry() {
    final t = _text;
    if (t == null) {
      _charScreenRects = const [];
      _charTextIndex = const [];
      _geomText = null;
      return;
    }
    if (identical(_geomText, t) &&
        _geomSize == widget.pageSize &&
        _charScreenRects.isNotEmpty) {
      return;
    }
    final rects = <Rect>[];
    final indexes = <int>[];
    for (final f in t.fragments) {
      final n = f.charRects.length;
      for (var i = 0; i < n; i++) {
        rects.add(f.charRects[i]
            .toRect(page: widget.page, scaledPageSize: widget.pageSize));
        indexes.add(f.index + i);
      }
    }
    _charScreenRects = rects;
    _charTextIndex = indexes;
    _geomText = t;
    _geomSize = widget.pageSize;
  }

  /// [local] noktasına en yakın karakterin fullText indeksi (yoksa null).
  /// [maxDist]: kutu dışına bu kadar piksele kadar tolerans (parmak kalın;
  /// sürüklemede [_unbounded] verilir — en yakın karakter her zaman bulunur).
  int? _charIndexAt(Offset local, {double maxDist = 28}) {
    _ensureGeometry();
    int? best;
    var bestD = maxDist * maxDist;
    for (var k = 0; k < _charScreenRects.length; k++) {
      final r = _charScreenRects[k];
      final dx = local.dx < r.left
          ? r.left - local.dx
          : (local.dx > r.right ? local.dx - r.right : 0.0);
      final dy = local.dy < r.top
          ? r.top - local.dy
          : (local.dy > r.bottom ? local.dy - r.bottom : 0.0);
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = _charTextIndex[k];
      }
    }
    return best;
  }

  static bool _isWordChar(String ch) => ch.trim().isNotEmpty;

  /// [i] karakterini içeren kelimenin sınırları (dahil). Boşluk/karakter satır
  /// sonuysa kelime sayılmaz, kendisi döner — sürükleme ucu boşluktan
  /// geçerken seçim oraya kadar uzar, komşu kelimeye zıplamaz.
  (int, int) _wordBoundsAt(int i) {
    final s = _text!.fullText;
    if (!_isWordChar(s[i])) return (i, i);
    var a = i, b = i;
    while (a > 0 && _isWordChar(s[a - 1])) {
      a--;
    }
    while (b + 1 < s.length && _isWordChar(s[b + 1])) {
      b++;
    }
    return (a, b);
  }

  /// [local] altındaki kelimeyi seçer; seçebildiyse true. Uzun basış boşluğun
  /// kıyısına denk gelirse komşu karaktere kayılır: kullanıcı "yazının
  /// üstüne" bastığını sanır, birkaç piksel ıskalamak sinir bozucu.
  bool _selectWordAt(Offset local, {double tolerance = 44}) {
    final t = _text;
    if (t == null) return false;
    var i = _charIndexAt(local, maxDist: tolerance);
    if (i == null) return false;
    final s = t.fullText;
    if (!_isWordChar(s[i])) {
      if (i > 0 && _isWordChar(s[i - 1])) {
        i = i - 1;
      } else if (i + 1 < s.length && _isWordChar(s[i + 1])) {
        i = i + 1;
      } else {
        return false;
      }
    }
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
    return true;
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

  Offset? _globalToOverlay(Offset global) {
    final box = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  /// Tutamaç sürüklendi: [global] parmak noktasını en yakın karaktere eşle,
  /// seçimin ilgili ucunu (başı ya da sonu) oraya taşı, diğer ucu sabit tut.
  /// Karakter hassasiyetinde (ince ayar tutamaçların işi).
  void _dragHandle(bool isStart, Offset global) {
    final at = _globalToOverlay(global);
    if (at == null) return;
    // Parmak tutamacın ORTASINDA değil, ucundadır; hedefi biraz yukarı al ki
    // kullanıcı gördüğü karakteri seçsin, altındakini değil.
    final local = at - const Offset(0, 14);
    final i = _charIndexAt(local, maxDist: _unbounded);
    if (i == null) return;
    final fixed = isStart ? _selEnd : _selStart;
    if (fixed < 0) return;
    setState(() {
      _anchor = fixed;
      _extent = i;
      _magnifier = local;
    });
  }

  void _clear() {
    if (_anchor == null && _extent == null) return;
    setState(() {
      _anchor = null;
      _extent = null;
    });
    widget.onSelected('', const [], widget.page.pageNumber, '', false);
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
    widget.onSelected(_selectedText, rects, widget.page.pageNumber,
        _precedingText, _fromOcr);
  }

  bool get _hasSelection =>
      _anchor != null && _extent != null && _selEnd >= _selStart;

  // ═══ Görünüm ═════════════════════════════════════════════════════════════

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
          // MouseRegion yalnız imleci değiştirir (opaque: false → hit-test'te
          // saydam, alttaki katmanlardan hiçbir şey çalmaz).
          MouseRegion(
            opaque: false,
            cursor:
                _hoverOnText ? SystemMouseCursors.text : MouseCursor.defer,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              onPointerHover: _onPointerHover,
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
          ),
          if (_hasSelection) ...[
            _handle(isStart: true, color: scheme.primary),
            _handle(isStart: false, color: scheme.primary),
          ],
          if (_magnifier != null) _buildMagnifier(scheme),
          if (_ocrRunning || _ocrEmpty) _ocrChip(context, scheme),
        ],
      ),
    );
  }

  /// Sürüklerken parmağın üstünde gezen büyüteç — Android'in yerel seçim
  /// büyüteciyle aynı his. Parmağın 66 px üstünde durur, altındaki içeriği
  /// (seçim vurgusu dahil) 1,6 kat büyütür. Sayfa kenarında yatayda kıstırılır
  /// ki mercek ekrandan taşmasın; odak parmakta kalır.
  Widget _buildMagnifier(ColorScheme scheme) {
    final p = _magnifier!;
    const size = Size(112, 56);
    const above = 66.0;
    final maxLeft = widget.pageSize.width - size.width + 8.0;
    final left = maxLeft < -8.0
        ? -8.0
        : (p.dx - size.width / 2).clamp(-8.0, maxLeft);
    final top = p.dy - size.height / 2 - above;
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: RawMagnifier(
          size: size,
          focalPointOffset: Offset(p.dx - (left + size.width / 2), above),
          magnificationScale: 1.6,
          decoration: MagnifierDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(0, 3),
                blurStyle: BlurStyle.outer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Taranmış sayfada OCR durum çipi: "Metin tanınıyor…" / "metin bulunamadı".
  /// Uzun basılan yerin değil sayfanın üstünde durur ki parmağın altında
  /// kaybolmasın.
  Widget _ocrChip(BuildContext context, ColorScheme scheme) {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          child: Material(
            color: scheme.inverseSurface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_ocrRunning)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: scheme.onInverseSurface,
                      ),
                    )
                  else
                    Icon(Icons.search_off,
                        size: 14, color: scheme.onInverseSurface),
                  const SizedBox(width: 7),
                  Text(
                    _ocrRunning
                        ? context.t('vw.select_ocr_running')
                        : context.t('vw.select_ocr_none'),
                    style: TextStyle(
                      color: scheme.onInverseSurface,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
        onPanStart: (d) {
          final at = _globalToOverlay(d.globalPosition);
          if (at != null) setState(() => _magnifier = at - const Offset(0, 14));
        },
        onPanUpdate: (d) => _dragHandle(isStart, d.globalPosition),
        onPanEnd: (_) {
          setState(() => _magnifier = null);
          _report();
        },
        onPanCancel: () => setState(() => _magnifier = null),
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

  /// **Bu boyayıcı dokunuşu YUTMAZ.** Silinmesi/atlanması yasak.
  ///
  /// KÖK NEDEN (2026-07-26, 11. tur — kullanıcı: *"sadece kenardaki çubuktan
  /// kayıyor, dokunarak olmuyor, zoom hiç yok"*): Flutter'da arka plan
  /// boyayıcısı için
  /// `RenderCustomPaint.hitTestSelf => _painter != null && (_painter!.hitTest(p) ?? true)`
  /// yazar. `CustomPainter.hitTest` varsayılan olarak **null** döner, `?? true`
  /// yüzünden sonuç **true** olur: yani `painter:` verilmiş her `CustomPaint`,
  /// kapladığı alandaki bütün dokunuşları sessizce yutar.
  ///
  /// Bu katmanın `CustomPaint`'i sayfanın TAMAMINI kaplıyor. Sarmalayıcıya
  /// `HitTestBehavior.translucent` vermek hiçbir şeyi değiştirmiyordu, çünkü
  /// translucent yalnız "çocuk vurmazsa yine de kaydol" demek — çocuk
  /// (CustomPaint) vuruyordu. Sonuç: pdfrx'in `InteractiveViewer`'ı, Stack'in
  /// en altında olduğu için işaretçiyi HİÇ görmüyordu. Kaydırma ve
  /// yakınlaştırma bu yüzden tümüyle ölüydü; kenardaki kaydırma çubuğu ise
  /// ayrı bir katman olduğu için çalışmaya devam ediyordu — kullanıcının
  /// tarifiyle birebir aynı.
  ///
  /// (`foregroundPainter` tarafında `?? false` yazıyor; tuzak yalnız arka plan
  /// boyayıcısında.)
  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.text != text ||
      old.start != start ||
      old.end != end ||
      old.pageSize != pageSize ||
      old.color != color;
}
