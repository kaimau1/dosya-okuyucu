/// **Deneme (Faz 21b / K18 — b-ii):** kendi ince belge editörü çekirdeğimiz.
///
/// Amaç ölçmek: Word'ün kalıcı düzenleme yüzeyi WebView `contenteditable`
/// mı kalsın (Android klavyelerinin bitmeyen hata kuyruğu, bkz.
/// DUZENLEME_PLANI §4.1), yoksa Flutter'ın kendi klavye altyapısıyla mı
/// yazılsın? Bu dosya ikinci yolun en ince hâli:
/// * belge düzeyinde TEK bir `DeltaTextInputClient`; klavyeye (IME) belgenin
///   tamamı değil yalnız imlecin paragrafı verilir (super_editor'ün yolu);
/// * paragraf başında geri silmeyi yakalamak için IME metninin başında
///   görünmez bir bekçi karakter (`​`) durur — silinirse paragraf
///   bir öncekine katılır (bazı klavyeler boş metinde geri silme olayı
///   üretmez);
/// * çizim `RichText` (paragraf başına), imleç/seçim `RenderParagraph`
///   ölçüleriyle; dokun = imleç, çift dokun = kelime, uzun bas + sürükle =
///   paragraflar arası seçim.
///
/// Geliştirici menüsündeki "Yeni Word editörü (deneme)" bayrağının
/// arkasındadır; kullanıcı açmadıkça görünmez. Kaydetmez.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Harf biçimi bit maskesi.
abstract final class ThinStyle {
  static const bold = 1;
  static const italic = 2;
  static const underline = 4;
}

class ThinPara {
  String text;

  /// Her harfin biçim maskesi (`text.length` uzunlukta).
  List<int> styles;

  ThinPara(this.text, [List<int>? styles])
      : styles = styles ?? List.filled(text.length, 0, growable: true);
}

/// Belgede bir konum.
@immutable
class ThinPos implements Comparable<ThinPos> {
  final int para;
  final int offset;
  const ThinPos(this.para, this.offset);

  @override
  int compareTo(ThinPos o) =>
      para != o.para ? para.compareTo(o.para) : offset.compareTo(o.offset);

  @override
  bool operator ==(Object other) =>
      other is ThinPos && other.para == para && other.offset == offset;

  @override
  int get hashCode => Object.hash(para, offset);

  @override
  String toString() => '($para:$offset)';
}

class ThinEditorController extends ChangeNotifier
    implements DeltaTextInputClient {
  final List<ThinPara> paras;

  ThinPos base = const ThinPos(0, 0);
  ThinPos extent = const ThinPos(0, 0);

  /// Klavyeden yazılacak harfin biçimi (K/T/A düğmeleri imleçteyken).
  int typingStyle = 0;

  TextRange composing = TextRange.empty;
  TextInputConnection? _conn;

  /// IME'ye verilen metnin başındaki bekçi.
  static const _guard = '​';

  ThinEditorController(List<String> texts)
      : paras = [
          for (final t in texts) ThinPara(t),
          if (texts.isEmpty) ThinPara(''),
        ];

  bool get collapsed => base == extent;
  ThinPos get start => base.compareTo(extent) <= 0 ? base : extent;
  ThinPos get end => base.compareTo(extent) <= 0 ? extent : base;

  String get plainText => paras.map((p) => p.text).join('\n');

  // ── klavye bağlantısı ─────────────────────────────────────────────────────

  bool get attached => _conn?.attached ?? false;

  void attach() {
    if (!attached) {
      _conn = TextInput.attach(
        this,
        const TextInputConfiguration(
          enableDeltaModel: true,
          inputType: TextInputType.multiline,
          inputAction: TextInputAction.newline,
          autocorrect: true,
          enableSuggestions: true,
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

  /// IME'ye imlecin paragrafını verir (bekçi + metin, seçim +1 kaydırılmış).
  void _syncIme() {
    if (!attached) return;
    _conn!.setEditingState(currentTextEditingValue!);
  }

  @override
  TextEditingValue? get currentTextEditingValue {
    final p = paras[extent.para];
    final s = collapsed || base.para != extent.para
        ? TextSelection.collapsed(offset: extent.offset + 1)
        : TextSelection(
            baseOffset: base.offset + 1, extentOffset: extent.offset + 1);
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
    notifyListeners();
    if (resync) _syncIme();
  }

  /// Bir IME deltasını uygular; IME'nin değeri yeniden kurulmalıysa true.
  bool _applyDelta(TextEditingDelta d) {
    int unshift(int o) => o - 1;
    if (!collapsed && base.para != extent.para &&
        d is! TextEditingDeltaNonTextUpdate) {
      deleteSelection();
      return true;
    }
    final i = extent.para;
    switch (d) {
      case TextEditingDeltaInsertion():
        if (d.textInserted.contains('\n')) {
          final parts = d.textInserted.split('\n');
          _insert(i, unshift(d.insertionOffset), parts.first);
          for (final part in parts.skip(1)) {
            splitAtCaret();
            _insert(extent.para, extent.offset, part);
          }
          return true;
        }
        _insert(i, unshift(d.insertionOffset), d.textInserted);
        _setComposing(d.composing);
        return false;
      case TextEditingDeltaDeletion():
        final r = d.deletedRange;
        if (r.start == 0) {
          // Bekçi silindi: paragraf başında geri silme → birleştir.
          if (r.end > 1) _delete(i, 0, r.end - 1);
          mergeWithPrevious(i);
          return true;
        }
        _delete(i, unshift(r.start), unshift(r.end));
        _setComposing(d.composing);
        return false;
      case TextEditingDeltaReplacement():
        final r = d.replacedRange;
        // Otomatik düzeltme / öneri: aralığın yerine yazılır.
        final from = r.start == 0 ? 0 : unshift(r.start);
        _delete(i, from, unshift(r.end));
        _insert(i, from, d.replacementText);
        _setComposing(d.composing);
        return r.start == 0;
      case TextEditingDeltaNonTextUpdate():
        final s = d.selection;
        final p = paras[i];
        int clampOff(int o) => (o - 1).clamp(0, p.text.length);
        base = ThinPos(i, clampOff(s.baseOffset));
        extent = ThinPos(i, clampOff(s.extentOffset));
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

  void _insert(int i, int at, String text) {
    final p = paras[i];
    final o = at.clamp(0, p.text.length);
    p.text = p.text.substring(0, o) + text + p.text.substring(o);
    p.styles.insertAll(o, List.filled(text.length, typingStyle));
    base = extent = ThinPos(i, o + text.length);
  }

  void _delete(int i, int from, int to) {
    final p = paras[i];
    final a = from.clamp(0, p.text.length), b = to.clamp(0, p.text.length);
    if (b <= a) return;
    p.text = p.text.substring(0, a) + p.text.substring(b);
    p.styles.removeRange(a, b);
    base = extent = ThinPos(i, a);
  }

  // ── yapısal işlemler ──────────────────────────────────────────────────────

  /// Enter: imleçte böler.
  void splitAtCaret() {
    if (!collapsed) deleteSelection();
    final i = extent.para, o = extent.offset;
    final p = paras[i];
    final next = ThinPara(p.text.substring(o), p.styles.sublist(o));
    p.text = p.text.substring(0, o);
    p.styles.removeRange(o, p.styles.length);
    paras.insert(i + 1, next);
    base = extent = ThinPos(i + 1, 0);
    composing = TextRange.empty;
  }

  /// [i] paragrafını öncekine katar.
  void mergeWithPrevious(int i) {
    if (i <= 0 || i >= paras.length) {
      base = extent = ThinPos(i.clamp(0, paras.length - 1), 0);
      return;
    }
    final prev = paras[i - 1], cur = paras[i];
    final at = prev.text.length;
    prev.text += cur.text;
    prev.styles.addAll(cur.styles);
    paras.removeAt(i);
    base = extent = ThinPos(i - 1, at);
    composing = TextRange.empty;
  }

  /// Seçimi siler (paragraflar arası da).
  void deleteSelection() {
    if (collapsed) return;
    final s = start, e = end;
    if (s.para == e.para) {
      _delete(s.para, s.offset, e.offset);
    } else {
      final a = paras[s.para], b = paras[e.para];
      a.text = a.text.substring(0, s.offset) + b.text.substring(e.offset);
      a.styles
        ..removeRange(s.offset, a.styles.length)
        ..addAll(b.styles.sublist(e.offset));
      paras.removeRange(s.para + 1, e.para + 1);
      base = extent = s;
    }
    composing = TextRange.empty;
  }

  /// Yapıştır: satır sonları yeni paragraf.
  void insertText(String text) {
    if (!collapsed) deleteSelection();
    final lines = text.replaceAll('\r', '').split('\n');
    _insert(extent.para, extent.offset, lines.first);
    for (final l in lines.skip(1)) {
      splitAtCaret();
      _insert(extent.para, extent.offset, l);
    }
    notifyListeners();
    _syncIme();
  }

  /// K/T/A: seçime uygular; imleçteyse yazma biçimini değiştirir.
  void toggle(int bit) {
    if (collapsed) {
      typingStyle ^= bit;
      notifyListeners();
      return;
    }
    final s = start, e = end;
    var allOn = true;
    _forRange(s, e, (p, k) => allOn &= (p.styles[k] & bit) != 0);
    _forRange(s, e, (p, k) {
      p.styles[k] = allOn ? p.styles[k] & ~bit : p.styles[k] | bit;
    });
    notifyListeners();
  }

  void _forRange(ThinPos s, ThinPos e, void Function(ThinPara p, int k) f) {
    for (var i = s.para; i <= e.para; i++) {
      final p = paras[i];
      final from = i == s.para ? s.offset : 0;
      final to = i == e.para ? e.offset : p.text.length;
      for (var k = from; k < to; k++) {
        f(p, k);
      }
    }
  }

  void select(ThinPos b, ThinPos e) {
    base = b;
    extent = e;
    composing = TextRange.empty;
    notifyListeners();
    _syncIme();
  }

  /// Çift dokunuş: kelimeyi seç.
  void selectWord(ThinPos at) {
    final t = paras[at.para].text;
    var a = at.offset, b = at.offset;
    bool word(int k) => k >= 0 && k < t.length && t[k].trim().isNotEmpty;
    while (a > 0 && word(a - 1)) {
      a--;
    }
    while (b < t.length && word(b)) {
      b++;
    }
    select(ThinPos(at.para, a), ThinPos(at.para, b));
  }

  String selectedText() {
    if (collapsed) return '';
    final s = start, e = end;
    final out = StringBuffer();
    for (var i = s.para; i <= e.para; i++) {
      final t = paras[i].text;
      out.write(t.substring(i == s.para ? s.offset : 0,
          i == e.para ? e.offset : t.length));
      if (i < e.para) out.write('\n');
    }
    return out.toString();
  }

  // ── TextInputClient gerisi ────────────────────────────────────────────────

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline) {
      splitAtCaret();
      notifyListeners();
      _syncIme();
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
  void showToolbar() {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}
}

/// İnce editörün görünümü.
class ThinEditor extends StatefulWidget {
  final ThinEditorController controller;
  final TextStyle? style;
  const ThinEditor({super.key, required this.controller, this.style});

  @override
  State<ThinEditor> createState() => _ThinEditorState();
}

class _ThinEditorState extends State<ThinEditor> {
  final _keys = <int, GlobalKey>{};

  ThinEditorController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  @override
  void didUpdateWidget(ThinEditor old) {
    super.didUpdateWidget(old);
    if (old.controller != c) {
      old.controller.removeListener(_changed);
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  GlobalKey _key(int i) => _keys.putIfAbsent(i, GlobalKey.new);

  /// Genel ekran noktası → belge konumu (görünen paragraflar arasında).
  ThinPos? _hit(Offset global) {
    ThinPos? best;
    var bestDy = double.infinity;
    _keys.forEach((i, k) {
      if (i >= c.paras.length) return;
      final ro = k.currentContext?.findRenderObject();
      if (ro is! RenderParagraph || !ro.attached) return;
      final local = ro.globalToLocal(global);
      final dy = local.dy < 0
          ? -local.dy
          : (local.dy > ro.size.height ? local.dy - ro.size.height : 0.0);
      if (dy < bestDy) {
        bestDy = dy;
        final pos = ro.getPositionForOffset(Offset(
            local.dx, local.dy.clamp(0, ro.size.height - 1).toDouble()));
        best = ThinPos(i, pos.offset.clamp(0, c.paras[i].text.length));
      }
    });
    return best;
  }

  TextSpan _span(ThinPara p, TextStyle base) {
    if (p.text.isEmpty) return TextSpan(text: '', style: base);
    final kids = <TextSpan>[];
    var k = 0;
    while (k < p.text.length) {
      final s = p.styles[k];
      var j = k;
      while (j < p.text.length && p.styles[j] == s) {
        j++;
      }
      kids.add(TextSpan(
        text: p.text.substring(k, j),
        style: TextStyle(
          fontWeight: s & ThinStyle.bold != 0 ? FontWeight.w700 : null,
          fontStyle: s & ThinStyle.italic != 0 ? FontStyle.italic : null,
          decoration:
              s & ThinStyle.underline != 0 ? TextDecoration.underline : null,
        ),
      ));
      k = j;
    }
    return TextSpan(style: base, children: kids);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = (widget.style ?? theme.textTheme.bodyLarge ?? const TextStyle())
        .copyWith(color: theme.colorScheme.onSurface, height: 1.5);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final p = _hit(d.globalPosition);
        if (p == null) return;
        c.select(p, p);
        c.attach();
      },
      onDoubleTapDown: (d) {
        final p = _hit(d.globalPosition);
        if (p != null) c.selectWord(p);
      },
      onLongPressStart: (d) {
        final p = _hit(d.globalPosition);
        if (p != null) c.selectWord(p);
        HapticFeedback.selectionClick();
      },
      onLongPressMoveUpdate: (d) {
        final p = _hit(d.globalPosition);
        if (p != null) c.select(c.base, p);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: c.paras.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CustomPaint(
            foregroundPainter: _SelectionPainter(c, i, _key(i),
                theme.colorScheme.primary),
            child: RichText(
              key: _key(i),
              text: _span(c.paras[i], base),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  final ThinEditorController c;
  final int i;
  final GlobalKey key;
  final Color color;
  _SelectionPainter(this.c, this.i, this.key, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final ro = key.currentContext?.findRenderObject();
    if (ro is! RenderParagraph) return;
    final s = c.start, e = c.end;
    if (i < s.para || i > e.para) return;
    final len = c.paras[i].text.length;
    if (c.collapsed) {
      if (i != c.extent.para) return;
      final at = ro.getOffsetForCaret(
          TextPosition(offset: c.extent.offset.clamp(0, len)), Rect.zero);
      final h = ro.getFullHeightForCaret(
          TextPosition(offset: c.extent.offset.clamp(0, len)));
      canvas.drawRect(Rect.fromLTWH(at.dx, at.dy, 2, h), Paint()..color = color);
      return;
    }
    final from = i == s.para ? s.offset : 0;
    final to = i == e.para ? e.offset : len;
    final paint = Paint()..color = color.withValues(alpha: 0.25);
    for (final b in ro.getBoxesForSelection(
        TextSelection(baseOffset: from, extentOffset: to))) {
      canvas.drawRect(b.toRect(), paint);
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => true;
}
