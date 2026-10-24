/// Word Mobil görünüm editörünün denetleyicisi (Faz 22 — K18 = b-ii).
///
/// Faz 21b'deki ince çekirdeğin (`lib/labs/word_editor/thin_editor.dart`)
/// gerçek belge modeline ([DocxDocument]) bağlanmış hâli:
/// * belge düzeyinde TEK `DeltaTextInputClient`; klavyeye yalnız imlecin
///   paragrafı verilir (IME'nin metni küçük kalır, 1000 paragrafta da tuş
///   maliyeti sabit);
/// * IME metninin başında görünmez bekçi (`U+200B`): bazı klavyeler boş
///   metinde geri silme olayı üretmez — bekçi silinirse paragraf öncekine
///   katılır;
/// * Enter: paragraf böler (stil sürer; başlıkta `w:next` stiline geçer; boş
///   liste öğesinde listeden çıkar). Tablo hücresinin sınırı aşılmaz.
/// * Geri al: paragraf listesinin sığ kopyası (paragraflar değişmez nesne).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/edit/edit_history.dart';
import '../../services/docx/docx_document.dart';
import '../../services/docx/docx_styles.dart';

/// Belgede bir konum (paragraf sırası + paragraf içi harf).
@immutable
class DocPos implements Comparable<DocPos> {
  final int para;
  final int offset;
  const DocPos(this.para, this.offset);

  @override
  int compareTo(DocPos o) =>
      para != o.para ? para.compareTo(o.para) : offset.compareTo(o.offset);

  @override
  bool operator ==(Object other) =>
      other is DocPos && other.para == para && other.offset == offset;

  @override
  int get hashCode => Object.hash(para, offset);

  @override
  String toString() => '($para:$offset)';
}

typedef _State = (List<DocxPara>, DocPos, DocPos);

class DocxEditController extends ChangeNotifier
    implements DeltaTextInputClient {
  final DocxDocument doc;

  DocPos base = const DocPos(0, 0);
  DocPos extent = const DocPos(0, 0);
  TextRange composing = TextRange.empty;

  /// Her içerik değişikliğinde artar (oturum "değişti" der, görünüm tazelenir).
  int revision = 0;

  /// Yapı (paragraf sayısı) değişikliği sayacı — blok listesi önbelleği.
  int structure = 0;

  /// Seçim yokken basılan K/T/A: sıradaki yazının biçimi.
  DocxCharStyle? _pending;
  DocPos? _pendingAt;

  TextInputConnection? _conn;
  static const _guard = '​';

  final _history = SnapshotHistory<_State>(limit: 200);
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  bool _lastTyping = false;

  /// Seçim araç çubuğu görünsün mü (uzun bas / çift dokun / tutamak sonrası).
  bool toolbar = false;

  DocxEditController(this.doc) {
    final first = doc.paras.indexWhere((p) => !p.opaque);
    base = extent = DocPos(first < 0 ? 0 : first, 0);
  }

  List<DocxPara> get paras => doc.paras;

  bool get collapsed => base == extent;
  DocPos get start => base.compareTo(extent) <= 0 ? base : extent;
  DocPos get end => base.compareTo(extent) <= 0 ? extent : base;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  List<String>? _labels;
  int _labelsAt = -1;

  /// Liste etiketleri (yapı ya da içerik değişince yeniden sayılır).
  List<String> get labels {
    if (_labels == null || _labelsAt != revision) {
      _labels = doc.listLabels();
      _labelsAt = revision;
    }
    return _labels!;
  }

  // ── klavye bağlantısı ─────────────────────────────────────────────────────

  bool get attached => _conn?.attached ?? false;

  /// IME'ye bağlanır ve klavyeyi açar (yazım denetimi klavyenin kendi
  /// önerileriyle; `autocorrect` + `enableSuggestions` açık).
  void attach({bool autocorrect = true}) {
    if (paras[extent.para].opaque) return;
    if (!attached) {
      _conn = TextInput.attach(
        this,
        TextInputConfiguration(
          enableDeltaModel: true,
          inputType: TextInputType.multiline,
          inputAction: TextInputAction.newline,
          autocorrect: autocorrect,
          enableSuggestions: autocorrect,
          textCapitalization: TextCapitalization.sentences,
        ),
      );
    }
    _conn!.show();
    _syncIme();
  }

  void detach() {
    _conn?.close();
    _conn = null;
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  void _syncIme() {
    if (!attached) return;
    _conn!.setEditingState(currentTextEditingValue!);
  }

  @override
  TextEditingValue? get currentTextEditingValue {
    final p = paras[extent.para];
    final sameParaSel = !collapsed && base.para == extent.para;
    final s = sameParaSel
        ? TextSelection(
            baseOffset: base.offset + 1, extentOffset: extent.offset + 1)
        : TextSelection.collapsed(offset: extent.offset + 1);
    return TextEditingValue(
      text: _guard + p.text,
      selection: s,
      composing: composing.isValid
          ? TextRange(start: composing.start + 1, end: composing.end + 1)
          : TextRange.empty,
    );
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    // Delta kipi açık: tam değer yalnız eski motorlarda gelir.
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    var resync = false;
    for (final d in deltas) {
      resync |= _applyDelta(d);
    }
    _changed(notify: true);
    if (resync) _syncIme();
  }

  bool _applyDelta(TextEditingDelta d) {
    int un(int o) => o - 1;
    if (d is! TextEditingDeltaNonTextUpdate && !collapsed && base.para != extent.para) {
      deleteSelection();
      if (d is TextEditingDeltaInsertion && d.textInserted != '\n') {
        insertText(d.textInserted);
      }
      return true;
    }
    final i = extent.para;
    if (paras[i].opaque) return true;
    switch (d) {
      case TextEditingDeltaInsertion():
        if (d.textInserted.contains('\n')) {
          final parts = d.textInserted.split('\n');
          _replace(i, un(d.insertionOffset), un(d.insertionOffset), parts.first);
          for (final part in parts.skip(1)) {
            enter(notify: false);
            _replace(extent.para, extent.offset, extent.offset, part);
          }
          return true;
        }
        _replace(i, un(d.insertionOffset), un(d.insertionOffset), d.textInserted);
        _setComposing(d.composing);
        return false;
      case TextEditingDeltaDeletion():
        final r = d.deletedRange;
        if (r.start == 0) {
          if (r.end > 1) _replace(i, 0, r.end - 1, '');
          mergeWithPrevious(i, notify: false);
          return true;
        }
        _replace(i, un(r.start), un(r.end), '');
        _setComposing(d.composing);
        return false;
      case TextEditingDeltaReplacement():
        final r = d.replacedRange;
        final from = r.start == 0 ? 0 : un(r.start);
        _replace(i, from, un(r.end), d.replacementText);
        _setComposing(d.composing);
        return r.start == 0;
      case TextEditingDeltaNonTextUpdate():
        final s = d.selection;
        final len = paras[i].length;
        int c(int o) => (o - 1).clamp(0, len);
        base = DocPos(i, c(s.baseOffset));
        extent = DocPos(i, c(s.extentOffset));
        _setComposing(d.composing);
        return s.baseOffset == 0 || s.extentOffset == 0;
    }
    return false;
  }

  void _setComposing(TextRange r) {
    composing = r.isValid && r.start > 0
        ? TextRange(start: r.start - 1, end: r.end - 1)
        : TextRange.empty;
  }

  // ── geri al ──────────────────────────────────────────────────────────────

  _State _state() => ([...paras], base, extent);

  /// Değişiklikten ÖNCE çağrılır; yazma kelime/duraklama sınırında bölünür.
  void _record({required bool typing, String inserted = ''}) {
    final now = DateTime.now();
    final boundary = inserted.contains(RegExp(r'[\s.,;:!?]'));
    if (!typing ||
        !_lastTyping ||
        boundary ||
        now.difference(_lastPush) > const Duration(seconds: 1)) {
      _history.push(_state());
    }
    _lastPush = now;
    _lastTyping = typing && !boundary;
  }

  void undo() => _restore(_history.undo(_state()));
  void redo() => _restore(_history.redo(_state()));

  void _restore(_State? s) {
    if (s == null) return;
    doc.paras = [...s.$1];
    base = s.$2;
    extent = s.$3;
    composing = TextRange.empty;
    _pending = null;
    _lastTyping = false;
    structure++;
    _changed(notify: true);
    _syncIme();
  }

  void _changed({bool notify = false}) {
    revision++;
    if (notify) notifyListeners();
  }

  // ── düzenleme ────────────────────────────────────────────────────────────

  DocxCharStyle _typingStyle(int i, int at) {
    final pend = _pending;
    if (pend != null && _pendingAt == DocPos(i, at)) return pend;
    return paras[i].typingStyleAt(at);
  }

  /// Paragraf [i]'de [from, to) yerine [text].
  void _replace(int i, int from, int to, String text) {
    final p = paras[i];
    final a = from.clamp(0, p.length), b = to.clamp(a, p.length);
    _record(typing: true, inserted: text);
    final style = _typingStyle(i, a);
    doc.paras[i] = p.replace(a, b, text, style);
    base = extent = DocPos(i, a + text.length);
    if (_pending != null) _pendingAt = extent;
  }

  /// Enter.
  void enter({bool notify = true}) {
    if (!collapsed) deleteSelection(notify: false);
    final i = extent.para;
    final p = paras[i];
    if (p.opaque) return;
    _record(typing: false);
    // Boş liste öğesinde Enter listeden çıkarır (Word gibi).
    if (p.length == 0 && p.look.numId != null) {
      doc.paras[i] = doc.withoutList(p);
      composing = TextRange.empty;
      _changed(notify: notify);
      return;
    }
    final atEnd = extent.offset >= p.length;
    final (pPr, look) =
        atEnd ? doc.nextParagraphProps(p) : (p.pPr, p.look);
    final (left, right) = p.split(extent.offset, nextPPr: pPr, nextLook: look);
    doc.paras[i] = left;
    doc.paras.insert(i + 1, right);
    base = extent = DocPos(i + 1, 0);
    composing = TextRange.empty;
    structure++;
    _changed(notify: notify);
    if (notify) _syncIme();
  }

  /// Paragraf başında geri silme: öncekine katılır (aynı kapsayıcıdaysa).
  void mergeWithPrevious(int i, {bool notify = true}) {
    composing = TextRange.empty;
    if (i <= 0 || i >= paras.length) {
      base = extent = DocPos(i.clamp(0, paras.length - 1), 0);
      return;
    }
    final prev = paras[i - 1], cur = paras[i];
    // Liste öğesinin başında geri silme önce listeden çıkarır (Word).
    if (cur.look.numId != null && !cur.opaque) {
      _record(typing: false);
      doc.paras[i] = doc.withoutList(cur);
      base = extent = DocPos(i, 0);
      _changed(notify: notify);
      return;
    }
    if (prev.opaque || cur.opaque || !identical(prev.container, cur.container)) {
      base = extent = DocPos(i, 0);
      return;
    }
    _record(typing: false);
    final at = prev.length;
    doc.paras[i - 1] = prev.join(cur);
    doc.paras.removeAt(i);
    base = extent = DocPos(i - 1, at);
    structure++;
    _changed(notify: notify);
  }

  /// Seçimi siler. Farklı kapsayıcılardaki (gövde / hücre) paragraflar
  /// birleştirilmez: yalnız metinleri silinir.
  void deleteSelection({bool notify = true}) {
    if (collapsed) return;
    _record(typing: false);
    final s = start, e = end;
    if (s.para == e.para) {
      final p = paras[s.para];
      doc.paras[s.para] = p.replace(s.offset, e.offset, '', p.mark);
    } else {
      final a = paras[s.para], b = paras[e.para];
      var sameBox = !a.opaque && !b.opaque;
      for (var k = s.para; k <= e.para && sameBox; k++) {
        sameBox = identical(paras[k].container, a.container) && !paras[k].opaque;
      }
      if (sameBox) {
        final left = a.replace(s.offset, a.length, '', a.mark);
        final right = b.replace(0, e.offset, '', b.mark);
        doc.paras[s.para] = left.join(right);
        doc.paras.removeRange(s.para + 1, e.para + 1);
        structure++;
      } else {
        for (var k = s.para; k <= e.para; k++) {
          final p = paras[k];
          if (p.opaque) continue;
          final from = k == s.para ? s.offset : 0;
          final to = k == e.para ? e.offset : p.length;
          doc.paras[k] = p.replace(from, to, '', p.mark);
        }
      }
    }
    base = extent = s;
    composing = TextRange.empty;
    toolbar = false;
    _changed(notify: notify);
    if (notify) _syncIme();
  }

  /// Yapıştır / programla yaz: satır sonları yeni paragraf.
  void insertText(String text) {
    if (!collapsed) deleteSelection(notify: false);
    if (paras[extent.para].opaque) return;
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    _lastTyping = false;
    _replace(extent.para, extent.offset, extent.offset, lines.first);
    for (final l in lines.skip(1)) {
      enter(notify: false);
      _replace(extent.para, extent.offset, extent.offset, l);
    }
    toolbar = false;
    _changed(notify: true);
    _syncIme();
  }

  // ── biçim (K/T/A) ────────────────────────────────────────────────────────

  bool _all(bool Function(DocxCharStyle) test) {
    if (collapsed) {
      return test(_typingStyle(extent.para, extent.offset));
    }
    var any = false;
    final s = start, e = end;
    for (var i = s.para; i <= e.para; i++) {
      final p = paras[i];
      if (p.opaque) continue;
      final from = i == s.para ? s.offset : 0;
      final to = i == e.para ? e.offset : p.length;
      for (var k = from; k < to; k++) {
        if (p.atoms[k] != null) continue;
        any = true;
        if (!test(p.styles[k])) return false;
      }
    }
    return any;
  }

  bool get isBold => _all((s) => s.isBold);
  bool get isItalic => _all((s) => s.isItalic);
  bool get isUnderline => _all((s) => s.isUnderline);
  bool get isStrike => _all((s) => s.effective.strike);
  bool get isSuperscript =>
      _all((s) => s.effective.vertAlign == 'superscript');
  bool get isSubscript => _all((s) => s.effective.vertAlign == 'subscript');

  /// Seçimdeki harflerin ortak değeri; karışıksa `(null, true)`.
  (T?, bool) _common<T>(T Function(DocxRunLook) get) {
    final caret = get(_typingStyle(extent.para, extent.offset).effective);
    if (collapsed) return (caret, false);
    T? v;
    var any = false;
    final s = start, e = end;
    for (var i = s.para; i <= e.para; i++) {
      final p = paras[i];
      if (p.opaque) continue;
      final from = i == s.para ? s.offset : 0;
      final to = i == e.para ? e.offset : p.length;
      for (var k = from; k < to; k++) {
        if (p.atoms[k] != null) continue;
        final x = get(p.styles[k].effective);
        if (!any) {
          v = x;
          any = true;
        } else if (x != v) {
          return (null, true);
        }
      }
    }
    return any ? (v, false) : (caret, false);
  }

  /// Punto (karışık seçimde null — şeritte "—").
  double? get fontSize => _common((l) => l.sizePt).$1;

  /// Yazı tipi adı (karışık seçimde null).
  String? get fontName => _common((l) => l.font).$1;

  void _format({bool? bold, bool? italic, bool? underline}) =>
      applyPatch(DocxRunPatch(bold: bold, italic: italic, underline: underline));

  /// Harf biçimi uygular: seçim varsa seçime, yoksa sıradaki yazıya.
  void applyPatch(DocxRunPatch patch) {
    if (collapsed) {
      _pending = _typingStyle(extent.para, extent.offset).merge(patch: patch);
      _pendingAt = extent;
      notifyListeners();
      return;
    }
    _record(typing: false);
    final s = start, e = end;
    for (var i = s.para; i <= e.para; i++) {
      final p = paras[i];
      if (p.opaque) continue;
      final from = i == s.para ? s.offset : 0;
      final to = i == e.para ? e.offset : p.length;
      doc.paras[i] = p.format(from, to, patch: patch);
    }
    _changed(notify: true);
  }

  void toggleBold() => _format(bold: !isBold);
  void toggleItalic() => _format(italic: !isItalic);
  void toggleUnderline() => _format(underline: !isUnderline);
  void toggleStrike() => applyPatch(DocxRunPatch(strike: !isStrike));
  void toggleSuperscript() => applyPatch(
      DocxRunPatch(vertAlign: isSuperscript ? '' : 'superscript'));
  void toggleSubscript() =>
      applyPatch(DocxRunPatch(vertAlign: isSubscript ? '' : 'subscript'));
  void setFontSize(double pt) => applyPatch(DocxRunPatch(sizePt: pt));
  void setFont(String name) => applyPatch(DocxRunPatch(font: name));

  /// Son kullanılan yazı renkleri (en yeni başta, en çok 6).
  final List<int> recentColors = [];

  /// Yazı rengi; [DocxRunPatch.autoColor] = otomatik.
  void setColor(int argb) {
    if (argb != DocxRunPatch.autoColor) {
      recentColors
        ..remove(argb)
        ..insert(0, argb);
      if (recentColors.length > 6) recentColors.removeLast();
    }
    applyPatch(DocxRunPatch(color: argb));
  }

  /// Vurgu adı; `''` = kaldır.
  void setHighlight(String name) => applyPatch(DocxRunPatch(highlight: name));

  /// A+ / A−: punto kademesinde bir adım.
  void growFont(int dir, List<double> steps) {
    final cur = fontSize ?? 11;
    double next = cur;
    if (dir > 0) {
      next = steps.firstWhere((v) => v > cur + 0.01, orElse: () => cur);
    } else {
      next = steps.lastWhere((v) => v < cur - 0.01, orElse: () => cur);
    }
    if (next != cur) setFontSize(next);
  }

  /// "Biçimi temizle": seçimdeki (seçim yoksa paragraftaki) doğrudan harf
  /// biçimi kalkar; paragraf stilinin biçimi kalır.
  void clearFormatting() {
    _record(typing: false);
    if (collapsed) {
      final i = extent.para;
      if (paras[i].opaque) return;
      doc.paras[i] = doc.clearFormatting(paras[i], 0, paras[i].length);
      _pending = null;
    } else {
      final s = start, e = end;
      for (var i = s.para; i <= e.para; i++) {
        final p = paras[i];
        if (p.opaque) continue;
        final from = i == s.para ? s.offset : 0;
        final to = i == e.para ? e.offset : p.length;
        doc.paras[i] = doc.clearFormatting(p, from, to);
      }
    }
    _changed(notify: true);
  }

  // ── paragraf biçimi (Faz 23) ─────────────────────────────────────────────

  DocxPara get currentPara => paras[extent.para];
  DocxParaLook get paraLook => currentPara.look;

  /// Seçimdeki paragrafların ortak stili (karışıksa null).
  String? get styleId {
    String? v;
    var first = true;
    for (var i = start.para; i <= end.para; i++) {
      final p = paras[i];
      if (p.opaque) continue;
      if (first) {
        v = p.look.styleId;
        first = false;
      } else if (p.look.styleId != v) {
        return null;
      }
    }
    return v;
  }

  /// İmlecin paragrafının liste türü (`bullet` | `number` | `multi` | null).
  String? get listKind => doc.listKind(currentPara);

  void _editParas(DocxPara Function(int i, DocxPara p) edit) {
    _record(typing: false);
    for (var i = start.para; i <= end.para; i++) {
      final p = paras[i];
      if (p.opaque) continue;
      doc.paras[i] = edit(i, p);
    }
    _changed(notify: true);
  }

  void setAlign(String align) => _editParas((_, p) => doc.setAlign(p, align));

  /// Hizalamayı sırayla çevirir: sola → ortala → sağa → iki yana.
  void cycleAlign() {
    const order = ['left', 'center', 'right', 'both'];
    setAlign(order[(order.indexOf(paraLook.align) + 1) % order.length]);
  }

  void indent(int delta) => _editParas((_, p) => doc.indent(p, delta));

  void setLineSpacing(double multiple) =>
      _editParas((_, p) => doc.setLineSpacing(p, multiple));

  /// Paragraf öncesine 12 nk boşluk ekler / kaldırır.
  void toggleSpaceBefore() {
    final on = paraLook.spaceBeforePt > 0;
    _editParas((_, p) => doc.setSpacing(p, beforePt: on ? 0 : 12));
  }

  /// Paragraf sonrasına 8 nk boşluk ekler / kaldırır.
  void toggleSpaceAfter() {
    final on = paraLook.spaceAfterPt > 0;
    _editParas((_, p) => doc.setSpacing(p, afterPt: on ? 0 : 8));
  }

  void toggleRtl() {
    final on = !paraLook.bidi;
    _editParas((_, p) => doc.setBidi(p, on));
  }

  /// Madde / numara / çok düzeyli liste — hepsi o türdeyse listeden çıkar.
  void toggleList(String kind) {
    var all = true;
    for (var i = start.para; i <= end.para; i++) {
      if (!paras[i].opaque && doc.listKind(paras[i]) != kind) all = false;
    }
    _editParas((i, p) {
      if (all) return doc.withoutList(p);
      final prev = i > 0 && identical(paras[i - 1].container, p.container)
          ? paras[i - 1]
          : null;
      final next = i + 1 < paras.length &&
              i + 1 > end.para &&
              identical(paras[i + 1].container, p.container)
          ? paras[i + 1]
          : null;
      return doc.setList(p, kind, prev: prev, next: next);
    });
  }

  void applyStyle(String id) => _editParas((_, p) => doc.applyStyle(p, id));

  /// Gezinti: başlıklar (paragraf sırası, düzey, metin).
  List<(int, int, String)> headings() => [
        for (var i = 0; i < paras.length; i++)
          if (!paras[i].opaque &&
              paras[i].look.headingLevel > 0 &&
              paras[i].text.trim().isNotEmpty)
            (i, paras[i].look.headingLevel, paras[i].text.replaceAll(kDocxAtom, '').trim()),
      ];

  /// Sözcük / karakter (boşluklu, boşluksuz) / paragraf sayısı.
  ({int words, int chars, int charsNoSpace, int paragraphs}) counts() {
    final text = doc.plainText();
    return (
      words: RegExp(r'\S+').allMatches(text).length,
      chars: text.replaceAll('\n', '').length,
      charsNoSpace: text.replaceAll(RegExp(r'\s'), '').length,
      paragraphs: paras.where((p) => !p.opaque && p.text.trim().isNotEmpty).length,
    );
  }

  /// [i]. paragrafa imleç koyar (gezinti).
  void goToParagraph(int i) => select(DocPos(i, 0), DocPos(i, 0));

  // ── biçim boyacısı ───────────────────────────────────────────────────────

  DocxCharStyle? _painter;

  /// Çift dokunuşla kilitli: birden çok yere uygulanır, ✕ ile biter.
  bool painterLocked = false;
  bool get painterActive => _painter != null;

  /// Biçimi kopyalar (tek dokunuş: bir kez; [lock]: kilitli). Etkinken
  /// yeniden basmak kapatır.
  void pickPainter({bool lock = false}) {
    if (painterActive && !lock) return cancelPainter();
    DocxCharStyle src = _typingStyle(extent.para, extent.offset);
    if (!collapsed) {
      final p = paras[start.para];
      for (var k = start.offset; k < p.length; k++) {
        if (p.atoms[k] == null) {
          src = p.styles[k];
          break;
        }
      }
    }
    _painter = src;
    painterLocked = lock;
    notifyListeners();
  }

  void cancelPainter() {
    _painter = null;
    painterLocked = false;
    notifyListeners();
  }

  /// Görünüm seçim bitince çağırır (uzun bas / tutamak / dokunuş): boyacı
  /// etkinse biçimi seçime uygular.
  void selectionFinished() {
    final src = _painter;
    if (src == null || collapsed) return;
    _record(typing: false);
    final s = start, e = end;
    for (var i = s.para; i <= e.para; i++) {
      final p = paras[i];
      if (p.opaque) continue;
      final from = i == s.para ? s.offset : 0;
      final to = i == e.para ? e.offset : p.length;
      doc.paras[i] = doc.paintFormat(p, from, to, src);
    }
    if (!painterLocked) _painter = null;
    _changed(notify: true);
  }

  // ── seçim ────────────────────────────────────────────────────────────────

  void select(DocPos b, DocPos e, {bool showToolbar = false}) {
    base = _clampPos(b);
    extent = _clampPos(e);
    composing = TextRange.empty;
    if (_pendingAt != extent) _pending = null;
    toolbar = showToolbar && !collapsed;
    notifyListeners();
    _syncIme();
  }

  DocPos _clampPos(DocPos p) {
    final i = p.para.clamp(0, paras.length - 1);
    return DocPos(i, p.offset.clamp(0, paras[i].length));
  }

  static bool _wordChar(String ch) =>
      ch.trim().isNotEmpty && !RegExp(r'[.,;:!?()\[\]{}"«»“”]').hasMatch(ch);

  /// Çift dokunuş: kelime.
  void selectWord(DocPos at) {
    final t = paras[at.para].text;
    var a = at.offset.clamp(0, t.length), b = a;
    while (a > 0 && _wordChar(t[a - 1])) {
      a--;
    }
    while (b < t.length && _wordChar(t[b])) {
      b++;
    }
    select(DocPos(at.para, a), DocPos(at.para, b), showToolbar: true);
  }

  /// Üç dokunuş: paragraf.
  void selectParagraph(int i) =>
      select(DocPos(i, 0), DocPos(i, paras[i].length), showToolbar: true);

  void selectAll() {
    final last = paras.length - 1;
    select(const DocPos(0, 0), DocPos(last, paras[last].length),
        showToolbar: true);
  }

  String selectedText() {
    if (collapsed) return '';
    final s = start, e = end;
    final out = StringBuffer();
    for (var i = s.para; i <= e.para; i++) {
      final p = paras[i];
      final from = i == s.para ? s.offset : 0;
      final to = i == e.para ? e.offset : p.length;
      for (var k = from; k < to; k++) {
        out.write(p.atoms[k]?.display ?? p.text[k]);
      }
      if (i < e.para) out.write('\n');
    }
    return out.toString().replaceAll(kDocxLineBreak, '\n');
  }

  Future<void> copy() async {
    final t = selectedText();
    if (t.isNotEmpty) await Clipboard.setData(ClipboardData(text: t));
    toolbar = false;
    notifyListeners();
  }

  Future<void> cut() async {
    await copy();
    deleteSelection();
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t == null || t.isEmpty) return;
    insertText(t);
  }

  /// Seçimi [text] ile değiştirir (yazım önerisi, AI düzeltmesi, çeviri).
  void replaceSelection(String text) {
    if (!collapsed) deleteSelection(notify: false);
    insertText(text);
  }

  // ── donanım klavyesi ─────────────────────────────────────────────────────

  /// Geri silme tuşu (yazılım klavyesinin KEYCODE_DEL'i de buraya gelir).
  ///
  /// Android motoru DEL tuş olayını editable'a UYGULAMAZ; normal metin
  /// alanında bunu `EditableText`'in `DeleteCharacterIntent` eylemi yapar.
  /// Kendi istemcimizde işlenmezse yazma çalışır ama silme düşer.
  void deleteBackward() {
    if (!collapsed) return deleteSelection();
    final i = extent.para, at = extent.offset;
    if (paras[i].opaque) return;
    if (at == 0) {
      mergeWithPrevious(i, notify: false);
    } else {
      final t = paras[i].text;
      final n = at >= 2 && _isLow(t.codeUnitAt(at - 1)) &&
              _isHigh(t.codeUnitAt(at - 2))
          ? 2
          : 1;
      _lastTyping = false;
      _replace(i, at - n, at, '');
      composing = TextRange.empty;
    }
    _changed(notify: true);
    _syncIme();
  }

  /// İleri silme (Delete): paragraf sonunda sonrakini buna katar.
  void deleteForward() {
    if (!collapsed) return deleteSelection();
    final i = extent.para, at = extent.offset;
    final p = paras[i];
    if (p.opaque) return;
    if (at >= p.length) {
      if (i + 1 >= paras.length) return;
      final next = paras[i + 1];
      if (next.opaque || !identical(next.container, p.container)) return;
      _record(typing: false);
      doc.paras[i] = p.join(next);
      doc.paras.removeAt(i + 1);
      base = extent = DocPos(i, at);
      structure++;
    } else {
      final n = at + 1 < p.length && _isHigh(p.text.codeUnitAt(at)) &&
              _isLow(p.text.codeUnitAt(at + 1))
          ? 2
          : 1;
      _lastTyping = false;
      _replace(i, at, at + n, '');
    }
    composing = TextRange.empty;
    _changed(notify: true);
    _syncIme();
  }

  static bool _isHigh(int u) => u >= 0xD800 && u <= 0xDBFF;
  static bool _isLow(int u) => u >= 0xDC00 && u <= 0xDFFF;

  /// Ok tuşları paragraf sınırını aşar (IME paragraf içinde kalır);
  /// Geri sil / Sil tuşları modelde uygulanır.
  bool handleKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return false;
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      deleteBackward();
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.delete) {
      deleteForward();
      return true;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;
    DocPos? to;
    final x = extent;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft && x.offset == 0 && x.para > 0) {
      to = DocPos(x.para - 1, paras[x.para - 1].length);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight &&
        x.offset >= paras[x.para].length &&
        x.para < paras.length - 1) {
      to = DocPos(x.para + 1, 0);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp && x.para > 0) {
      to = DocPos(x.para - 1, x.offset.clamp(0, paras[x.para - 1].length));
    } else if (e.logicalKey == LogicalKeyboardKey.arrowDown &&
        x.para < paras.length - 1) {
      to = DocPos(x.para + 1, x.offset.clamp(0, paras[x.para + 1].length));
    }
    if (to == null) return false;
    select(shift ? base : to, to);
    return true;
  }

  // ── TextInputClient gerisi ────────────────────────────────────────────────

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline) {
      enter();
      notifyListeners();
    }
  }

  @override
  void connectionClosed() => _conn = null;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  bool onFocusReceived() => false;

  @override
  void didChangeInputControl(
      TextInputControl? oldControl, TextInputControl? newControl) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void performSelector(String selectorName) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void showToolbar() {
    toolbar = !collapsed;
    notifyListeners();
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}
}
