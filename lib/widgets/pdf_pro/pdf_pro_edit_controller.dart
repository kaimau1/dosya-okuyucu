import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../services/pdf/pro/pdf_edit_bridge.dart';
import '../../services/pdf/pro/pdf_edit_recovery.dart';
import '../../services/pdf/pro/pdf_edit_save.dart';
import '../../services/pdf/pro/pdf_edit_session.dart';
import '../../services/pdf/pro/pdf_sensitive.dart';

/// Alt araç çubuğunun araçları (etkileşim sözleşmesi §5).
enum PdfProTool { text, image, markup, sign, form, pages, more }

/// İşaretleme aracının kipi (Faz 60).
enum PdfMarkupKind { none, highlight, underline, strikeout, squiggly, note, ink, eraser, rect, ellipse, line, arrow, redact }

/// Belge geneli aramada bir eşleşme.
class PdfFindHit {
  final int pageIndex, block, start, end;
  const PdfFindHit(this.pageIndex, this.block, this.start, this.end);
}

/// Karartma önerisi: bir kişisel veri eşleşmesi ve sayfadaki kutuları.
class PdfRedactHit {
  final int pageIndex;
  final PdfSensitiveKind kind;
  final String text;

  /// Düz liste: sol, alt, sağ, üst …
  final List<double> rects;
  const PdfRedactHit(this.pageIndex, this.kind, this.text, this.rects);
}

/// UTF-16 ofseti → kod noktası (rune) sırası; yazıcı ve imleç haritası kod
/// noktasıyla çalışır.
int pdfRuneIndex(String s, int utf16) {
  final n = utf16.clamp(0, s.length);
  var r = 0;
  for (var i = 0; i < n; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0xDC00 && c <= 0xDFFF && i > 0) continue;
    r++;
  }
  return r;
}

/// Kod noktası sırası → UTF-16 ofseti.
int pdfUtf16Index(String s, int rune) {
  var r = 0, i = 0;
  while (i < s.length && r < rune) {
    final c = s.codeUnitAt(i);
    i += (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) ? 2 : 1;
    r++;
  }
  return i;
}

/// Türkçe büyük/küçük harf katlaması (İ/ı): arama için.
String pdfFold(String s) => s
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll('ı', 'i');

/// **Yerinde yazma durumu** (Faz 57): bir bloğun yazım boyunca metni, karakter
/// başına biçim kaynağı, biçim bindirmeleri ve güncel imleç haritası.
class PdfLiveEdit {
  PdfLiveEdit._({
    required this.pageIndex,
    required this.block,
    required this.base,
    required this.map,
    required this.text,
    required this.styles,
    required this.spans,
    required this.align,
  })  : _origText = text,
        _origSpans = List.of(spans),
        _origAlign = align;

  final int pageIndex;

  /// Düzenlenen blok; yeni metin kutusunda null.
  final PdfTextBlock? block;

  /// Özgün sayfaya göre istek (geometri + kaldırılacak nesneler).
  final PdfTypesetRequest base;

  /// Güncel metin (kod noktaları), karakter başına biçim kaynağı (özgün nesne
  /// dizini) ve bindirmeler.
  String text;
  List<int> styles;
  List<PdfStyleSpan> spans;
  PdfBlockAlign align;
  double? size, width, leading;
  int? color;
  double dx = 0, dy = 0;

  /// İmleç/seçim (kod noktası ofseti).
  int selStart = 0, selEnd = 0;

  /// IME bileşim aralığı (kod noktası; yoksa -1).
  int composeStart = -1, composeEnd = -1;

  /// Yazılacak yeni metne uygulanacak biçim (seçim yokken B/I/U'ya basıldı).
  PdfStyleSpan? pending;

  PdfBlockTextMap map;

  /// Belgeye en az bir kez yazıldı mı; son yazımın sonucu.
  bool applied = false;
  List<int> created = const [];
  Map<int, int> _srcAt = const {}; // özgün nesne dizini → şimdiki dizini
  List<int> _hidden = const [];
  String? error;
  bool glyphError = false;
  int fallbackChars = 0;
  final PdfTypesetFonts fonts = PdfTypesetFonts();

  final String _origText;
  final List<PdfStyleSpan> _origSpans;
  final PdfBlockAlign _origAlign;

  bool get changed =>
      text != _origText ||
      align != _origAlign ||
      size != null ||
      color != null ||
      width != null ||
      leading != null ||
      dx != 0 ||
      dy != 0 ||
      !listEquals(
          [for (final s in spans) s.toJson().toString()],
          [for (final s in _origSpans) s.toJson().toString()]);

  bool get collapsed => selStart == selEnd;
  int get length => text.runes.length;

  List<int> get _runs => PdfBlockRequest.runs(
      [for (final s in styles) _srcAt[s] ?? s]);

  PdfTypesetRequest _shaped(PdfTypesetRequest r,
          {required List<int> remove,
          required String oldText,
          List<int> hide = const [],
          List<int> track = const [],
          List<int>? runs}) =>
      PdfTypesetRequest(
        pageIndex: pageIndex,
        remove: remove,
        hide: hide,
        track: track,
        oldText: oldText,
        text: text,
        styleRuns: runs ?? PdfBlockRequest.runs(styles),
        angle: r.angle,
        firstX: r.firstX + dx,
        bodyX: r.bodyX + dx,
        base: r.base + dy,
        width: width ?? r.width,
        leading: leading ?? r.leading,
        align: align,
        size: size,
        color: color,
        spans: spans,
      );

  /// Yazarken ara istek: ilk seferde özgün metin nesneleri gizlenir (biçim
  /// kaynağı olarak yaşarlar), sonrakilerde yalnız son yazılanlar kalkar.
  PdfTypesetRequest liveRequest() {
    if (!applied) {
      final texts = block?.objectIndexes ?? const <int>[];
      final own = texts.toSet();
      return _shaped(base,
          remove: [for (final i in base.remove) if (!own.contains(i)) i],
          hide: texts,
          oldText: '');
    }
    return _shaped(base, remove: created, track: _hidden, oldText: '', runs: _runs);
  }

  /// Yazım bitişinde canlı belgeyi temizleyen istek: gizlenenler de kalkar.
  PdfTypesetRequest finishRequest() =>
      _shaped(base, remove: [...created, ..._hidden], oldText: '', runs: _runs);

  /// Kalıcı (yeniden oynatılabilir) istek — özgün sayfaya göre.
  PdfTypesetRequest finalRequest() =>
      _shaped(base, remove: base.remove, oldText: base.oldText);

  void _took(PdfTypesetResult r, {required bool first}) {
    created = r.created;
    final orig = first ? (block?.objectIndexes ?? const <int>[]) : _origOrder;
    if (first) _origOrder = orig;
    _hidden = r.tracked;
    _srcAt = {
      for (var i = 0; i < orig.length && i < r.tracked.length; i++)
        orig[i]: r.tracked[i]
    };
    if (r.map != null) map = r.map!;
    fallbackChars = r.fallbackChars;
    applied = true;
    error = null;
    glyphError = false;
  }

  List<int> _origOrder = const [];

  /// Metin değişti: biçim kaynakları ve bindirmeler yeni metne taşınır.
  void setText(String next) {
    if (next == text) return;
    final o = text.runes.toList(), n = next.runes.toList();
    var pre = 0;
    while (pre < o.length && pre < n.length && o[pre] == n[pre]) {
      pre++;
    }
    var suf = 0;
    while (suf < o.length - pre &&
        suf < n.length - pre &&
        o[o.length - 1 - suf] == n[n.length - 1 - suf]) {
      suf++;
    }
    final oldMid = o.length - pre - suf, newMid = n.length - pre - suf;
    // Biçim kaynakları: değişmeyen baş ve son aynen; araya giren, yerine
    // yazdığının ya da solundakinin kaynağını alır.
    final src = styles.isEmpty
        ? -1
        : oldMid > 0
            ? styles[pre]
            : styles[pre > 0 ? pre - 1 : 0];
    styles = [
      ...styles.take(pre),
      ...List.filled(newMid, src),
      ...styles.skip(pre + oldMid),
    ];
    int shift(int b) {
      if (b <= pre) return b;
      if (b >= pre + oldMid) return b + newMid - oldMid;
      return pre + newMid;
    }

    spans = [
      for (final s in spans)
        if (shift(s.end) > shift(s.start))
          s.shifted(shift(s.start), shift(s.end)),
    ];
    final p = pending;
    if (p != null && newMid > 0) {
      spans = [...spans, p.shifted(pre, pre + newMid)];
    }
    text = next;
  }

  /// [start]–[end] aralığında bir biçim özelliği etkin mi (tümünde).
  bool has(bool? Function(PdfStyleSpan) get, int start, int end) {
    if (start >= end) {
      final p = pending;
      return p != null && (get(p) ?? false);
    }
    for (var i = start; i < end; i++) {
      bool? v;
      for (final s in spans) {
        if (i >= s.start && i < s.end) v = get(s) ?? v;
      }
      if (v != true) return false;
    }
    return true;
  }
}

/// **Düzenleme kipinin durumu** (PDF Pro Faz 54–60, PK3 — tek yüzey).
///
/// Görüntüleyici ekranı düzenleme kipine girince bunu kurar: oturum (komut
/// yığını), kayıt, sayfa başına içerik/blok önbelleği, seçim, yerinde yazma,
/// nesne ve açıklama işlemleri, çökme günlüğü ve 30 sn'lik geçici kayıt.
/// Ekran değişmez; belge yeniden yüklenmez.
class PdfProEditController extends ChangeNotifier {
  PdfProEditController({
    required this.document,
    required this.path,
    PdfPasswordProvider? password,
    Duration? snapshotEvery,
  })  : session = PdfEditSession.forDocument(document),
        super() {
    saver = PdfEditSaver(session: session, path: path, password: password);
    session.addListener(_onSession);
    PdfEditRecovery.begin(path);
    _timer = Timer.periodic(
        snapshotEvery ?? PdfEditRecovery.snapshotEvery, (_) => _snapshot());
  }

  final PdfDocument document;
  final String path;
  final PdfEditSession session;
  late final PdfEditSaver saver;

  Timer? _timer;
  final Map<int, PdfPageContent> _content = {};
  final Map<int, List<PdfTextBlock>> _blocks = {};
  final Map<int, List<PdfAnnotInfo>> _annots = {};
  final Set<int> _loading = {}, _loadingAnnots = {};
  bool _closed = false;
  bool _busy = false;
  int _changes = 0, _snapshotAt = 0;

  // ── araç durumu ─────────────────────────────────────────────────────────
  PdfProTool _tool = PdfProTool.text;
  PdfProTool get tool => _tool;
  set tool(PdfProTool t) {
    if (_tool == t) return;
    _tool = t;
    if (t != PdfProTool.markup) _markup = PdfMarkupKind.none;
    selectedPage = null;
    selectedBlock = null;
    selectedItem = null;
    selectedAnnot = null;
    _notify();
  }

  PdfMarkupKind _markup = PdfMarkupKind.none;
  PdfMarkupKind get markup => _markup;
  set markup(PdfMarkupKind k) {
    _markup = _markup == k ? PdfMarkupKind.none : k;
    _notify();
  }

  /// Tek parmak sürükleme şu an sayfaya çiziyor mu (vurgu, kalem, şekil,
  /// karartma). Açıkken görüntüleyici tek parmakla kaymaz; iki parmak
  /// yakınlaştırır.
  bool get drawing =>
      _live == null &&
      _tool == PdfProTool.markup &&
      _markup != PdfMarkupKind.none &&
      _markup != PdfMarkupKind.note &&
      _markup != PdfMarkupKind.eraser;

  /// İşaretleme rengi (ARGB) ve çizgi kalınlığı.
  int markupColor = 0xFFFFD54F;
  double markupWidth = 2;
  void setMarkupColor(int argb) {
    markupColor = argb;
    _notify();
  }

  /// "Metin kutusu ekle" kurulu: boşluğa ilk dokunuş kutuyu açar.
  bool get armTextBox => _armTextBox;
  bool _armTextBox = false;
  set armTextBox(bool v) {
    if (_armTextBox == v) return;
    _armTextBox = v;
    _notify();
  }

  /// Blok birimi: paragraf ya da satır (PDFelement kipi).
  PdfBlockMode _mode = PdfBlockMode.paragraph;
  PdfBlockMode get mode => _mode;
  set mode(PdfBlockMode m) {
    if (_mode == m) return;
    _mode = m;
    _blocks.clear();
    selectedPage = null;
    selectedBlock = null;
    _notify();
  }

  /// Seçili blok: sayfa (0 tabanlı) ve o sayfanın blok listesindeki sıra.
  int? selectedPage, selectedBlock;

  /// Seçili nesne (görsel/şekil) ve açıklama — sayfa [selectedPage].
  PdfPageItem? selectedItem;
  PdfAnnotInfo? selectedAnnot;

  /// Yerinde yazma (varsa).
  PdfLiveEdit? get live => _live;
  PdfLiveEdit? _live;

  /// Kopyalanan blok (oturum içi yapıştırma: metin + biçim).
  ({String text, List<PdfStyleSpan> spans, double size, int color, int source, int page})? clip;

  /// Stil kopyası ("stili kopyala").
  ({double size, int color, PdfBlockAlign align})? styleClip;

  /// Bir düzenleme/kayıt sürüyor (düğmeler bekler).
  bool get busy => _busy;

  /// Bu oturumda özgün dosyanın üstüne kaydedildi mi? Öyleyse diskteki dosya
  /// artık belgenin AÇILDIĞI baytlar değildir; oturum kapanınca görüntüleyici
  /// belgeyi diskten yeniden okur.
  bool get savedOverOriginal => _savedOver;
  bool _savedOver = false;

  void _load(int pageIndex) {
    if (_closed || !_loading.add(pageIndex)) return;
    unawaited(() async {
      try {
        final c = await PdfEditBridge.content(document, pageIndex);
        if (_closed) return;
        _content[pageIndex] = c;
        _blocks[pageIndex] = PdfEditBridge.blocksOf(c, mode: _mode);
      } catch (_) {
        if (_closed) return;
        // Okunamayan sayfa "blok yok" sayılır; önbellek boş listeyle dolar
        // (sonsuz yeniden deneme yok).
        _content[pageIndex] = const PdfPageContent([], [], 0, 0);
        _blocks[pageIndex] = const [];
      } finally {
        _loading.remove(pageIndex);
      }
      _notify();
    }());
  }

  /// Sayfanın blokları; henüz okunmadıysa okumayı başlatır ve null döner
  /// (bitince dinleyiciler uyarılır).
  List<PdfTextBlock>? blocksOf(int pageIndex) {
    final hit = _blocks[pageIndex];
    if (hit != null) return hit;
    final c = _content[pageIndex];
    if (c != null) {
      return _blocks[pageIndex] = PdfEditBridge.blocksOf(c, mode: _mode);
    }
    _load(pageIndex);
    return null;
  }

  /// Sayfanın içerik nesneleri (görsel, yol) — yüklenmediyse null.
  PdfPageContent? contentOf(int pageIndex) {
    final hit = _content[pageIndex];
    if (hit == null) _load(pageIndex);
    return hit;
  }

  /// Sayfanın açıklamaları — yüklenmediyse null (yükleme başlar).
  List<PdfAnnotInfo>? annotsOf(int pageIndex) {
    final hit = _annots[pageIndex];
    if (hit != null) return hit;
    if (_closed || !_loadingAnnots.add(pageIndex)) return null;
    unawaited(() async {
      try {
        final a = await PdfEditBridge.annotations(document, pageIndex);
        if (!_closed) _annots[pageIndex] = a;
      } catch (_) {
        // Bilinçli: açıklaması okunamayan sayfa "açıklama yok" sayılır.
        if (!_closed) _annots[pageIndex] = const [];
      } finally {
        _loadingAnnots.remove(pageIndex);
      }
      _notify();
    }());
    return null;
  }

  Future<PdfPageContent> _contentNow(int pageIndex) async =>
      _content[pageIndex] ??= await PdfEditBridge.content(document, pageIndex);

  Future<List<PdfTextBlock>> _blocksNow(int pageIndex) async =>
      _blocks[pageIndex] ??=
          PdfEditBridge.blocksOf(await _contentNow(pageIndex), mode: _mode);

  PdfTextBlock? get selected {
    final p = selectedPage, b = selectedBlock;
    if (p == null || b == null) return null;
    final list = _blocks[p];
    return list == null || b >= list.length ? null : list[b];
  }

  void select(int pageIndex, int? block) {
    if (selectedPage == pageIndex &&
        selectedBlock == block &&
        selectedItem == null) {
      return;
    }
    selectedPage = block == null ? null : pageIndex;
    selectedBlock = block;
    selectedItem = null;
    selectedAnnot = null;
    _notify();
  }

  void selectItem(int pageIndex, PdfPageItem? item) {
    selectedPage = item == null ? null : pageIndex;
    selectedBlock = null;
    selectedAnnot = null;
    selectedItem = item;
    _notify();
  }

  void selectAnnot(int pageIndex, PdfAnnotInfo? annot) {
    selectedPage = annot == null ? null : pageIndex;
    selectedBlock = null;
    selectedItem = null;
    selectedAnnot = annot;
    _notify();
  }

  void clearSelection() {
    if (selectedBlock == null && selectedItem == null && selectedAnnot == null) {
      return;
    }
    selectedPage = null;
    selectedBlock = null;
    selectedItem = null;
    selectedAnnot = null;
    _notify();
  }

  Future<T> _guard<T>(Future<T> Function() job) async {
    _busy = true;
    _notify();
    try {
      return await job();
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _invalidate(int pageIndex) {
    _content.remove(pageIndex);
    _blocks.remove(pageIndex);
    _annots.remove(pageIndex);
    if (selectedPage == pageIndex) {
      selectedPage = null;
      selectedBlock = null;
      selectedItem = null;
      selectedAnnot = null;
    }
  }

  // ── blok bölme / birleştirme (Faz 55 / 3) ────────────────────────────────
  /// Seçili bloğu [lineIndex] satırından böler.
  void splitSelected(int lineIndex) {
    final p = selectedPage, b = selectedBlock;
    final list = p == null ? null : _blocks[p];
    if (p == null || b == null || list == null || b >= list.length) return;
    final parts = splitTextBlock(list[b], lineIndex);
    if (parts.length < 2) return;
    _blocks[p] = [...list.take(b), ...parts, ...list.skip(b + 1)];
    selectedBlock = b;
    _notify();
  }

  /// Seçili bloğu bir alttaki (aynı yöndeki, okuma sırasında sonraki) blokla
  /// birleştirir; birleşemiyorsa false.
  bool mergeSelectedWithNext() {
    final p = selectedPage, b = selectedBlock;
    final list = p == null ? null : _blocks[p];
    if (p == null || b == null || list == null || b + 1 >= list.length) {
      return false;
    }
    final merged = mergeTextBlocks([list[b], list[b + 1]]);
    if (merged == null) return false;
    _blocks[p] = [...list.take(b), merged, ...list.skip(b + 2)];
    _notify();
    return true;
  }

  // ── yerinde yazma (Faz 57) ───────────────────────────────────────────────
  bool _liveBusy = false, _livePending = false;
  Completer<void>? _liveIdle;

  /// [block]'ta yazmayı başlatır; imleç [offset]'te (kod noktası), seçim
  /// verilirse [selection]. Kilitli blokta (PK7) false döner.
  Future<bool> beginEdit(int pageIndex, PdfTextBlock block,
      {int? offset, (int, int)? selection}) async {
    if (_live != null || _busy || !block.editable) return false;
    final content = await _contentNow(pageIndex);
    final base = PdfBlockRequest.of(pageIndex, block, content: content);
    final map = block.map;
    try {
      await session.beginLive(pageIndex);
    } on PdfEditBridgeRefused {
      return false;
    }
    final live = PdfLiveEdit._(
      pageIndex: pageIndex,
      block: block,
      base: base,
      map: map,
      text: map.text,
      styles: List.of(map.obj),
      spans: List.of(base.spans),
      align: base.align,
    );
    final n = live.length;
    live
      ..selStart = (selection?.$1 ?? offset ?? n).clamp(0, n)
      ..selEnd = (selection?.$2 ?? offset ?? n).clamp(0, n);
    _live = live;
    final list = _blocks[pageIndex];
    selectedPage = pageIndex;
    selectedBlock = list?.indexOf(block);
    _notify();
    return true;
  }

  /// Yeni metin kutusu (Faz 58 / 1): [x], [y] sayfa noktasında; biçim çevredeki
  /// gövde metninden ("eşleşen stil").
  Future<bool> beginTextBox(int pageIndex, double x, double y,
      {double? width}) async {
    if (_live != null || _busy) return false;
    final content = await _contentNow(pageIndex);
    final blocks = await _blocksNow(pageIndex);
    // En yakın düzenlenebilir, dik blok biçim kaynağıdır.
    PdfTextBlock? near;
    var best = double.infinity;
    for (final b in blocks) {
      if (!b.editable || b.angle != 0 || b.kind == PdfBlockKind.heading) continue;
      final cx = (b.left + b.right) / 2, cy = (b.bottom + b.top) / 2;
      final d = (cx - x).abs() + (cy - y).abs() * 2;
      if (d < best) {
        best = d;
        near = b;
      }
    }
    final src = near?.lines.first.objects.first;
    final size = near?.size ?? 12.0;
    final maxW = content.width > 0 ? content.width - x - 24 : 240.0;
    final base = PdfTypesetRequest(
      pageIndex: pageIndex,
      remove: const [],
      oldText: '',
      text: '',
      styleRuns: const [],
      angle: 0,
      firstX: x,
      bodyX: x,
      base: y,
      width: math.max(60, width ?? math.min(maxW, 260)),
      leading: near?.leading ?? size * 1.2,
      size: src == null ? size : null,
    );
    try {
      await session.beginLive(pageIndex);
    } on PdfEditBridgeRefused {
      return false;
    }
    final live = PdfLiveEdit._(
      pageIndex: pageIndex,
      block: null,
      base: base,
      map: PdfBlockTextMap(
        text: '',
        angle: 0,
        xs: const [],
        xe: const [],
        line: const [],
        obj: const [],
        chr: const [],
        bases: [y],
        sizes: [size],
        starts: [x],
      ),
      text: '',
      styles: const [],
      spans: const [],
      align: PdfBlockAlign.left,
    ).._boxSource = src?.index ?? -1;
    _live = live;
    selectedPage = null;
    selectedBlock = null;
    _notify();
    return true;
  }

  /// Yazarken: metin ve seçim değişti (UTF-16 ofsetleri).
  void liveInput(String text, int selStart, int selEnd,
      {int composeStart = -1, int composeEnd = -1}) {
    final live = _live;
    if (live == null) return;
    final changed = text != live.text;
    if (changed) {
      if (live.block == null && live.styles.isEmpty && text.isNotEmpty) {
        // Yeni kutunun ilk harfi: biçim kaynağı çevredeki gövde.
        live.styles = List.filled(0, live._boxSource, growable: true);
      }
      live.setText(text);
      if (live.block == null) {
        live.styles = List.filled(live.length, live._boxSource);
      }
    }
    live
      ..selStart = pdfRuneIndex(text, selStart)
      ..selEnd = pdfRuneIndex(text, selEnd)
      ..composeStart = composeStart < 0 ? -1 : pdfRuneIndex(text, composeStart)
      ..composeEnd = composeEnd < 0 ? -1 : pdfRuneIndex(text, composeEnd);
    if (changed) {
      _scheduleLive();
    }
    _notify();
  }

  /// Seçili aralığa (yoksa yazılacak metne) biçim uygular.
  void liveStyle(PdfStyleSpan Function(int start, int end) make) {
    final live = _live;
    if (live == null) return;
    final a = math.min(live.selStart, live.selEnd);
    final b = math.max(live.selStart, live.selEnd);
    if (a == b) {
      final add = make(0, 0);
      final p = live.pending;
      live.pending = PdfStyleSpan(0, 0,
          bold: add.bold ?? p?.bold,
          italic: add.italic ?? p?.italic,
          underline: add.underline ?? p?.underline,
          strike: add.strike ?? p?.strike,
          size: add.size ?? p?.size,
          color: add.color ?? p?.color,
          highlight: add.highlight ?? p?.highlight);
      _notify();
      return;
    }
    live.spans = [...live.spans, make(a, b)];
    _scheduleLive();
    _notify();
  }

  /// Paragraf düzeyi biçim: hizalama, punto, renk, satır aralığı.
  void liveParagraph(
      {PdfBlockAlign? align, double? size, int? color, double? leading}) {
    final live = _live;
    if (live == null) return;
    if (align != null) live.align = align;
    if (size != null) live.size = size.clamp(4.0, 144.0);
    if (color != null) live.color = color;
    if (leading != null) live.leading = leading;
    _scheduleLive();
    _notify();
  }

  void _scheduleLive() {
    if (_liveBusy) {
      _livePending = true;
      return;
    }
    unawaited(_runLive());
  }

  Future<void> _runLive() async {
    final live = _live;
    if (live == null) return;
    _liveBusy = true;
    _liveIdle ??= Completer<void>();
    try {
      do {
        _livePending = false;
        final first = !live.applied;
        // Yeni kutuda yazılacak bir şey yokken belgeye dokunulmaz.
        if (first && live.block == null && live.text.isEmpty) continue;
        final req = live.liveRequest();
        try {
          final r = await session.liveApply(
              () => PdfEditBridge.typeset(document, req, fonts: live.fonts));
          if (r.ok) {
            live._took(r, first: first);
          } else {
            live
              ..error = r.error
              ..glyphError = r.glyph;
          }
        } catch (e) {
          // Arayüz hatanın metnini göstermez (yalnız "yazılamadı" durumunu).
          live.error = e.runtimeType.toString();
        }
        _notify();
      } while (_livePending && !_closed && identical(_live, live));
    } finally {
      _liveBusy = false;
      _liveIdle?.complete();
      _liveIdle = null;
    }
  }

  Future<void> _settleLive() async {
    while (_liveBusy) {
      await (_liveIdle?.future ?? Future<void>.value());
    }
  }

  /// Yazmayı bitirir: değişiklik tek geri alınabilir adım olur. Yazılamayan
  /// son hâl (glif reddi) varsa false döner ve yazma sürer.
  Future<bool> commitEdit({required String label}) async {
    final live = _live;
    if (live == null) return true;
    await _settleLive();
    if (live.error != null) return false;
    if (!live.changed || (live.block == null && live.text.trim().isEmpty)) {
      await cancelEdit();
      return true;
    }
    return _guard(() async {
      if (live.applied) {
        // Canlı belgeden gizlenen özgün nesneleri kaldır.
        final r = await session.liveApply(() => PdfEditBridge.typeset(
            document, live.finishRequest(),
            fonts: live.fonts));
        if (!r.ok) {
          live
            ..error = r.error
            ..glyphError = r.glyph;
          return false;
        }
      } else {
        final r = await session.liveApply(() => PdfEditBridge.typeset(
            document, live.finalRequest(),
            fonts: live.fonts));
        if (!r.ok) {
          live
            ..error = r.error
            ..glyphError = r.glyph;
          return false;
        }
      }
      await session.commitLive(
          label: label,
          detail: _excerpt(live.text),
          op: PdfTypesetOp(live.finalRequest()));
      _live = null;
      _invalidate(live.pageIndex);
      return true;
    });
  }

  /// Yazmayı bırakır; sayfa yazmadan önceki hâline döner.
  Future<void> cancelEdit() async {
    final live = _live;
    if (live == null) return;
    await _settleLive();
    _live = null;
    await session.cancelLive(changed: live.applied);
    if (live.applied) _invalidate(live.pageIndex);
    _notify();
  }

  // ── blok komutları ───────────────────────────────────────────────────────
  /// [block]'un metnini değiştirir (geri alınabilir komut). Reddedilirse
  /// [PdfEditBridgeRefused]; belge değişmez.
  Future<void> replace(int pageIndex, PdfTextBlock block, String text,
          {required String label}) =>
      _guard(() async {
        final content = await _contentNow(pageIndex);
        final req = PdfBlockRequest.of(pageIndex, block,
            text: text.replaceAll(RegExp(r'[ \t]+'), ' ').trim(),
            content: content);
        await session.apply(PdfTypesetOp(req),
            label: label, detail: _excerpt(text));
        _invalidate(pageIndex);
      });

  /// Bloğu yeniden yazar: taşı ([dx], [dy]), genişlet ([width]), hizala,
  /// punto/renk değiştir. Reddedilirse [PdfEditBridgeRefused].
  Future<void> reshape(int pageIndex, PdfTextBlock block,
          {double dx = 0,
          double dy = 0,
          double? width,
          PdfBlockAlign? align,
          double? size,
          int? color,
          required String label}) =>
      _guard(() async {
        final content = await _contentNow(pageIndex);
        final req = PdfBlockRequest.of(pageIndex, block,
            dx: dx,
            dy: dy,
            width: width,
            align: align,
            size: size,
            color: color,
            content: content);
        await session.apply(PdfTypesetOp(req),
            label: label, detail: _excerpt(block.text));
        _invalidate(pageIndex);
      });

  /// Bloğu siler. [pullUp] true ise altındaki bloklar boşluk kadar yukarı
  /// çekilir (Faz 58 / 6).
  Future<void> deleteBlock(int pageIndex, PdfTextBlock block,
          {bool pullUp = false, required String label}) =>
      _guard(() async {
        final content = await _contentNow(pageIndex);
        final blocks = await _blocksNow(pageIndex);
        final deco = PdfBlockRequest.decorations(block, content);
        final actions = <PdfMutAction>[
          PdfMutAction.delete(
              [...block.objectIndexes, for (final d in deco) d.index]),
        ];
        if (pullUp && block.angle == 0) {
          final gap = block.top - block.bottom + block.leading - block.size;
          final below = <int>[];
          for (final b in blocks) {
            if (identical(b, block) || b.angle != 0) continue;
            final overlaps = math.min(b.right, block.right) -
                    math.max(b.left, block.left) >
                0;
            if (b.top < block.bottom + 0.5 && overlaps) {
              below.addAll(b.objectIndexes);
            }
          }
          if (below.isNotEmpty) {
            actions.add(PdfMutAction.transform(below, [1, 0, 0, 1, 0, gap]));
          }
        }
        await session.apply(PdfMutateOp(PdfMutation(pageIndex, actions)),
            label: label, detail: _excerpt(block.text));
        _invalidate(pageIndex);
      });

  /// Bloğu kopyalar (oturum içi; dışarıya düz metin çağıranın işi).
  Future<void> copyBlock(int pageIndex, PdfTextBlock block) async {
    final content = await _contentNow(pageIndex);
    final o = block.lines.first.objects.first;
    clip = (
      text: block.map.text,
      spans: PdfBlockRequest.spansOf(block, content),
      size: block.size,
      color: o.fill,
      source: o.index,
      page: pageIndex,
    );
    _notify();
  }

  /// Kopyalanan bloğu [pageIndex]'te [x], [y] noktasına (ilk taban çizgisi)
  /// yapıştırır — aynı sayfadaysa özgün yazı tipiyle, başka sayfada eşleşen
  /// yedekle.
  Future<void> pasteBlock(int pageIndex, double x, double y,
          {double? width, required String label}) =>
      _guard(() async {
        final c = clip;
        if (c == null) return;
        final content = await _contentNow(pageIndex);
        final same = c.page == pageIndex;
        final n = c.text.runes.length;
        final req = PdfTypesetRequest(
          pageIndex: pageIndex,
          remove: const [],
          oldText: '',
          text: c.text,
          styleRuns: [same ? c.source : -1, n],
          angle: 0,
          firstX: x,
          bodyX: x,
          base: y,
          width: width ??
              math.max(80, (content.width > 0 ? content.width : 595) - x - 36),
          leading: c.size * 1.25,
          size: same ? null : c.size,
          color: same ? null : c.color,
          spans: c.spans,
        );
        await session.apply(PdfTypesetOp(req),
            label: label, detail: _excerpt(c.text));
        _invalidate(pageIndex);
      });

  /// Bloğu hemen altına çoğaltır.
  Future<void> duplicateBlock(int pageIndex, PdfTextBlock block,
      {required String label}) async {
    await copyBlock(pageIndex, block);
    final height = block.top - block.bottom + block.leading;
    final c = clip!;
    await _guard(() async {
      final content = await _contentNow(pageIndex);
      final base = PdfBlockRequest.of(pageIndex, block, content: content);
      final req = PdfTypesetRequest(
        pageIndex: pageIndex,
        remove: const [],
        oldText: '',
        text: c.text,
        styleRuns: base.styleRuns,
        angle: base.angle,
        firstX: base.firstX,
        bodyX: base.bodyX,
        base: base.base - height,
        width: base.width,
        leading: base.leading,
        align: base.align,
        spans: c.spans,
      );
      await session.apply(PdfTypesetOp(req),
          label: label, detail: _excerpt(c.text));
      _invalidate(pageIndex);
    });
  }

  /// Bloğu madde işaretli / numaralı listeye çevirir ya da listeden çıkarır
  /// (Faz 58 / 2): her satır sonu (`\n`) bir madde.
  Future<void> toggleList(int pageIndex, PdfTextBlock block,
      {required bool numbered, required String label}) {
    final marker = RegExp(r'^(?:[•◦▪–-]|\(?\d{1,3}[.)])\s+');
    final lines = block.lines.map((l) => l.text).toList();
    final has = lines.every((l) => marker.hasMatch(l));
    final out = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final bare = lines[i].replaceFirst(marker, '');
      out.add(has ? bare : '${numbered ? '${i + 1}.' : '•'} $bare');
    }
    return _guard(() async {
      final content = await _contentNow(pageIndex);
      final req = PdfBlockRequest.of(pageIndex, block,
          text: out.join('\n'), content: content);
      await session.apply(PdfTypesetOp(req),
          label: label, detail: _excerpt(block.text));
      _invalidate(pageIndex);
    });
  }

  // ── bul ve değiştir (Faz 58 / 3) ─────────────────────────────────────────
  /// [query]'nin belgedeki eşleşmeleri (düzenlenebilir bloklarda).
  Future<List<PdfFindHit>> find(String query,
      {bool matchCase = false, bool wholeWord = false, int? onlyPage}) async {
    final hits = <PdfFindHit>[];
    if (query.isEmpty) return hits;
    final q = matchCase ? query : pdfFold(query);
    final from = onlyPage ?? 0;
    final to = onlyPage == null ? document.pages.length : onlyPage + 1;
    bool letter(int c) =>
        RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(String.fromCharCode(c));
    for (var p = from; p < to; p++) {
      final blocks = await _blocksNow(p);
      for (var b = 0; b < blocks.length; b++) {
        if (!blocks[b].editable) continue;
        final t = blocks[b].map.text;
        final hay = matchCase ? t : pdfFold(t);
        // Katlama uzunluğu değiştirmez (İ→i, I→ı tek kod birimi).
        var at = hay.indexOf(q);
        while (at >= 0) {
          final end = at + q.length;
          final ok = !wholeWord ||
              ((at == 0 || !letter(t.codeUnitAt(at - 1))) &&
                  (end >= t.length || !letter(t.codeUnitAt(end))));
          if (ok) {
            hits.add(PdfFindHit(
                p, b, pdfRuneIndex(t, at), pdfRuneIndex(t, end)));
          }
          at = hay.indexOf(q, end);
        }
      }
    }
    return hits;
  }

  /// Eşleşmeleri [replacement] ile değiştirir; her blok tek geri alınabilir
  /// adım. Dönen: (değişen eşleşme sayısı, reddedilen blok sayısı).
  Future<(int, int)> replaceHits(List<PdfFindHit> hits, String replacement,
          {required String label}) =>
      _guard(() async {
        var done = 0, refused = 0;
        // Blok başına grupla; bloktaki eşleşmeler sondan başa uygulanır.
        final byBlock = <(int, int), List<PdfFindHit>>{};
        for (final h in hits) {
          (byBlock[(h.pageIndex, h.block)] ??= []).add(h);
        }
        // Aynı sayfada bir blok değişince dizinler kayar: sayfa başına
        // blokları metinleriyle yeniden bul.
        final pages = byBlock.keys.map((k) => k.$1).toSet().toList()..sort();
        for (final p in pages) {
          final targets = <String, List<PdfFindHit>>{};
          final blocks = await _blocksNow(p);
          for (final e in byBlock.entries) {
            if (e.key.$1 != p || e.key.$2 >= blocks.length) continue;
            targets[blocks[e.key.$2].map.text] = e.value;
          }
          for (final e in targets.entries) {
            final now = await _blocksNow(p);
            final block = now
                .where((b) => b.map.text == e.key && b.editable)
                .firstOrNull;
            if (block == null) {
              refused++;
              continue;
            }
            final runes = e.key.runes.toList();
            final list = [...e.value]..sort((a, b) => b.start.compareTo(a.start));
            for (final h in list) {
              runes.replaceRange(h.start, h.end, replacement.runes);
            }
            try {
              final content = await _contentNow(p);
              final req = PdfBlockRequest.of(p, block,
                  text: String.fromCharCodes(runes), content: content);
              await session.apply(PdfTypesetOp(req),
                  label: label, detail: _excerpt(replacement));
              done += list.length;
            } on PdfEditBridgeRefused {
              refused++;
            }
            _invalidate(p);
          }
        }
        return (done, refused);
      });

  // ── nesneler (Faz 59) ────────────────────────────────────────────────────
  Future<void> mutate(int pageIndex, List<PdfMutAction> actions,
          {required String label, String detail = ''}) =>
      _guard(() async {
        await session.apply(PdfMutateOp(PdfMutation(pageIndex, actions)),
            label: label, detail: detail);
        _invalidate(pageIndex);
      });

  /// Sayfayı 90° saat yönünde döndürür (geri alınabilir).
  Future<void> rotatePage(int pageIndex, {required String label}) =>
      _guard(() async {
        await session.apply(PdfRotatePageOp(pageIndex, 1),
            label: label, detail: '${pageIndex + 1}');
        _invalidate(pageIndex);
      });

  // ── karartma (Faz 64) ────────────────────────────────────────────────────
  /// Belgede kişisel veri desenlerini arar (KVKK): öneri listesi döner,
  /// hiçbir şey değişmez.
  Future<List<PdfRedactHit>> findSensitive(
      {Set<PdfSensitiveKind>? kinds, List<String> custom = const []}) async {
    final out = <PdfRedactHit>[];
    for (var p = 0; p < document.pages.length; p++) {
      for (final b in await _blocksNow(p)) {
        final map = b.map;
        final t = map.text;
        final found = kinds == null
            ? PdfSensitive.find(t, custom: custom)
            : PdfSensitive.find(t, kinds: kinds, custom: custom);
        for (final m in found) {
          final rects = <double>[];
          for (final q in map.selection(
              pdfRuneIndex(t, m.start), pdfRuneIndex(t, m.end))) {
            var l = double.infinity, bo = double.infinity;
            var r = -double.infinity, to = -double.infinity;
            for (var i = 0; i < 8; i += 2) {
              l = math.min(l, q[i]);
              r = math.max(r, q[i]);
              bo = math.min(bo, q[i + 1]);
              to = math.max(to, q[i + 1]);
            }
            rects.addAll([l - 1, bo - 1, r + 1, to + 1]);
          }
          if (rects.isNotEmpty) {
            out.add(PdfRedactHit(p, m.kind, t.substring(m.start, m.end), rects));
          }
        }
      }
    }
    return out;
  }

  /// [hits]'i karartır: sayfa başına tek geri alınabilir adım. Dönen:
  /// karartılan öneri sayısı.
  Future<int> redact(List<PdfRedactHit> hits, {required String label}) =>
      _guard(() async {
        var n = 0;
        final byPage = <int, List<PdfRedactHit>>{};
        for (final h in hits) {
          (byPage[h.pageIndex] ??= []).add(h);
        }
        for (final e in byPage.entries) {
          await session.apply(
              PdfMutateOp(PdfMutation(e.key, [
                PdfMutAction.redact([for (final h in e.value) ...h.rects]),
              ])),
              label: label,
              detail: '${e.value.length}');
          _invalidate(e.key);
          n += e.value.length;
        }
        return n;
      });

  // ── açıklamalar (Faz 60) ─────────────────────────────────────────────────
  Future<void> annotate(PdfAnnotChange change,
          {required String label, String detail = ''}) =>
      _guard(() async {
        await session.apply(PdfAnnotOp(change), label: label, detail: detail);
        _invalidate(change.pageIndex);
      });

  /// Belgenin bütün açıklamaları (yorum paneli).
  Future<List<PdfAnnotInfo>> allAnnotations() async {
    final out = <PdfAnnotInfo>[];
    for (var p = 0; p < document.pages.length; p++) {
      out.addAll(
          _annots[p] ??= await PdfEditBridge.annotations(document, p));
    }
    return out;
  }

  Future<bool> undo() => _guard(() async {
        final page = session.undoStep?.pageIndex;
        final ok = await session.undo();
        if (ok && page != null) _invalidate(page);
        return ok;
      });

  Future<bool> redo() => _guard(() async {
        final page = session.redoStep?.pageIndex;
        final ok = await session.redo();
        if (ok && page != null) _invalidate(page);
        return ok;
      });

  Future<PdfEditSaveResult> save() => _guard(() async {
        final r = await saver.save();
        if (r.overwritten) {
          _savedOver = true;
          await PdfEditRecovery.clear(path);
        }
        return r;
      });

  Future<PdfEditSaveResult> saveAs({bool documents = false}) =>
      _guard(() => saver.saveAs(documents: documents));

  /// Kaydedilmemiş değişiklikleri bırakır; false → çağıran belgeyi diskten
  /// yeniden okumalı (kayıtlı hâle yığından dönülemedi).
  Future<bool> revert() => _guard(() async {
        final ok = await session.revertToSaved();
        _content.clear();
        _blocks.clear();
        _annots.clear();
        selectedPage = null;
        selectedBlock = null;
        selectedItem = null;
        selectedAnnot = null;
        return ok;
      });

  /// Çökmeden kalan günlüğü oynatır; uygulanan adım sayısı.
  Future<int> recover(PdfEditRecoveryEntry entry) => _guard(() async {
        final n = await PdfEditRecovery.replay(session, entry);
        _content.clear();
        _blocks.clear();
        _annots.clear();
        return n;
      });

  void _onSession() {
    _changes++;
    unawaited(PdfEditRecovery.writeJournal(path, session.stepsSinceSaved));
    _notify();
  }

  Future<void> _snapshot() async {
    if (_closed ||
        _busy ||
        _live != null ||
        !session.dirty ||
        _snapshotAt == _changes) {
      return;
    }
    final at = _changes;
    try {
      final bytes = await saver.encode();
      if (_closed) return;
      await PdfEditRecovery.writeSnapshot(path, bytes);
      _snapshotAt = at;
    } catch (_) {
      // Bilinçli: geçici kayıt bir emniyet ağı; sıradaki turda yeniden denenir.
    }
  }

  /// Geçici kaydı hemen yazar (test ve uygulama arka plana giderken).
  @visibleForTesting
  Future<void> snapshotNow() => _snapshot();

  static String _excerpt(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= 24 ? t : '${t.substring(0, 24)}…';
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  /// Oturumu kapatır. [keepRecovery] true → çökme kaydı silinmez (belge
  /// arkamızdan yeniden yüklendiyse kaydedilmemiş iş kurtarılabilsin).
  Future<void> close({bool keepRecovery = false}) async {
    if (_closed) return;
    final live = _live;
    if (live != null) {
      await _settleLive();
      _live = null;
      try {
        await session.cancelLive(changed: live.applied);
      } catch (_) {
        // Bilinçli: belge kapanıyorsa yarım yazım belleğiyle birlikte gider.
      }
    }
    _closed = true;
    _timer?.cancel();
    session.removeListener(_onSession);
    await session.close();
    await saver.dispose();
    PdfFallbackFonts.clear();
    if (keepRecovery) {
      PdfEditRecovery.abandon(path);
    } else {
      await PdfEditRecovery.end(path);
    }
  }

  @override
  void dispose() {
    unawaited(close(keepRecovery: session.dirty));
    super.dispose();
  }
}

extension on PdfLiveEdit {
  // Yeni metin kutusunun biçim kaynağı (çevredeki gövde nesnesi; -1 = yedek).
  static final _box = Expando<int>();
  int get _boxSource => _box[this] ?? -1;
  set _boxSource(int v) => _box[this] = v;
}
