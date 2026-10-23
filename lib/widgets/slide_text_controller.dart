import 'package:flutter/material.dart';

import '../core/doc_fonts.dart';
import '../core/edit/edit_history.dart';
import '../services/pptx_rich_text.dart';
import 'slide_canvas.dart' show slideRunStyle;

/// Belge paragraf hizaları (PowerPoint `l`/`ctr`/`r`/`just` — FİZİKSEL:
/// slayt dosyası arayüz dilinden bağımsız soldan sağa yazılır).
const kSlideAligns = [
  TextAlign.left,
  TextAlign.center,
  TextAlign.right,
  TextAlign.justify,
];

/// Hizanın [kSlideAligns] sırası (start/end soldan sağa sayılır).
int slideAlignIndex(TextAlign a) => switch (a) {
      TextAlign.center => 1,
      TextAlign.right || TextAlign.end => 2,
      TextAlign.justify => 3,
      _ => 0,
    };

/// Hizalama düğmesinin döngüsü: sol → orta → sağ → iki yana → sol.
TextAlign slideNextAlign(TextAlign a) =>
    kSlideAligns[(slideAlignIndex(a) + 1) % kSlideAligns.length];

/// Slayt metin kutusunun düzenleme denetleyicisi (Faz 28).
///
/// Metin [SlideRichText] modelinde yaşar: klavyeden gelen her değişiklik
/// modele fark olarak işlenir (biçimler kaymaz), çizim run run yapılır —
/// kalın kelime yazarken de kalın görünür (SL4). Biçim düğmeleri seçime,
/// seçim yoksa **yazılacak** harfe uygulanır (Word/PowerPoint gibi).
class SlideTextController extends TextEditingController {
  final SlideRichText model;

  /// Model puntosunu çizim birimine çeviren çarpan (normAutofit küçültmesi
  /// dahil). Kanvas punto biriminde çizdiği için yakınlaşma ayrıca uygulanmaz.
  double fontScale;

  /// Satır aralığı küçültmesi (`a:normAutofit@lnSpcReduction`).
  final double lnSpcReduction;

  /// Seçim yokken basılan biçim düğmesinin bekleyen biçimi ve yeri.
  RunStyle? _pending;
  int _pendingAt = -1;

  final _undo = SnapshotHistory<(RichSnapshot, TextEditingValue)>(limit: 100);
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  bool _lastWasTyping = false;

  SlideTextController(this.model,
      {this.fontScale = 1, this.lnSpcReduction = 0})
      : super(text: model.text);

  bool get canUndo => _undo.canUndo;
  bool get canRedo => _undo.canRedo;

  (RichSnapshot, TextEditingValue) _state() => (model.snapshot(), value);

  /// Yazmayı kelime/duraklama sınırında böler (Word gibi: geri al son
  /// kelimeyi alır).
  void _record({required bool typing, String? inserted}) {
    final now = DateTime.now();
    final boundary = inserted != null && inserted.contains(RegExp(r'[\s\n]'));
    if (!typing ||
        !_lastWasTyping ||
        boundary ||
        now.difference(_lastPush) > const Duration(seconds: 1)) {
      _undo.push(_state());
    }
    _lastPush = now;
    _lastWasTyping = typing && !boundary;
  }

  @override
  set value(TextEditingValue next) {
    if (next.text != model.text) {
      final old = model.text;
      final at = _commonPrefix(old, next.text);
      _record(
          typing: true,
          inserted: next.text.length > old.length
              ? next.text.substring(at, at + next.text.length - old.length)
              : null);
      final typing = _pending != null && _pendingAt == at ? _pending : null;
      model.applyText(next.text, typing: typing);
      if (typing != null) {
        _pendingAt = at + (next.text.length - old.length);
      }
    } else if (next.selection != value.selection &&
        next.selection.baseOffset != _pendingAt) {
      _pending = null;
    }
    super.value = next;
  }

  static int _commonPrefix(String a, String b) {
    var i = 0;
    final n = a.length < b.length ? a.length : b.length;
    while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) {
      i++;
    }
    return i;
  }

  // ── Biçim ────────────────────────────────────────────────────────────────

  (int, int) get _range {
    final s = selection;
    if (!s.isValid) return (text.length, text.length);
    return (s.start, s.end);
  }

  /// Seçimin (yoksa yazma noktasının) biçimi — düğmelerin açık/kapalı hâli.
  RunStyle get currentStyle {
    final (a, b) = _range;
    if (a == b && _pending != null && _pendingAt == a) return _pending!;
    return a == b ? model.typingStyleAt(a) : (model.charStyle(a) ?? model.typingStyleAt(a));
  }

  ParaStyle get currentPara => model.paras[model.paraIndexAt(_range.$1)];

  /// Seçimdeki bütün karakterler [test]'i sağlıyor mu.
  bool all(bool Function(RunStyle) test) {
    final (a, b) = _range;
    if (a == b) return test(currentStyle);
    return model.every(a, b, test);
  }

  void format({
    bool? bold,
    bool? italic,
    bool? underline,
    double? sizePt,
    Color? color,
    String? font,
  }) {
    final (a, b) = _range;
    _record(typing: false);
    if (a == b) {
      _pending = currentStyle.merge(
          bold: bold,
          italic: italic,
          underline: underline,
          sizePt: sizePt,
          color: color,
          font: font);
      _pendingAt = a;
    } else {
      model.formatRange(a, b,
          bold: bold,
          italic: italic,
          underline: underline,
          sizePt: sizePt,
          color: color,
          font: font);
    }
    notifyListeners();
  }

  void toggleBold() => format(bold: !all((s) => s.isBold));
  void toggleItalic() => format(italic: !all((s) => s.isItalic));
  void toggleUnderline() => format(underline: !all((s) => s.isUnderline));

  /// Punto ±[delta] (seçimdeki her harfin kendi puntosundan değil, seçimin
  /// ilk harfinden — PowerPoint'in "yazı tipini büyüt"ü gibi tek değer).
  void growFont(double delta) =>
      format(sizePt: (currentStyle.size + delta).clamp(6.0, 200.0).roundToDouble());

  void paragraph({TextAlign? align, String? bullet, int? levelDelta}) {
    final (a, b) = _range;
    _record(typing: false);
    model.formatParagraphs(a, b,
        align: align, bullet: bullet, levelDelta: levelDelta);
    notifyListeners();
  }

  void toggleBullet(String kind) =>
      paragraph(bullet: currentPara.effBullet == kind ? 'none' : kind);

  // ── Geri al ──────────────────────────────────────────────────────────────

  void undo() => _restore(_undo.undo(_state()));
  void redo() => _restore(_undo.redo(_state()));

  void _restore((RichSnapshot, TextEditingValue)? s) {
    if (s == null) return;
    model.restore(s.$1);
    _pending = null;
    _lastWasTyping = false;
    super.value = s.$2;
  }

  // ── Çizim ────────────────────────────────────────────────────────────────

  /// Bir biçimin çizim stili (punto biriminde).
  TextStyle styleOf(RunStyle st, ParaStyle para) {
    final family = st.font != null ? renderFamilyFor(st.font) : st.look.fontFamily;
    return slideRunStyle(
      family: family,
      size: st.size * fontScale,
      bold: st.isBold,
      italic: st.isItalic,
      underline: st.isUnderline,
      color: st.fg,
      height: (para.look?.lineHeight ?? 1.2) * (1 - lnSpcReduction),
    );
  }

  /// Boş kutuda imlecin boyu/rengi için ilk paragrafın yazma biçimi.
  TextStyle get baseStyle => styleOf(model.typingStyleAt(0), model.paras.first);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final children = <TextSpan>[];
    final t = text;
    final comp = value.composing;
    final showComposing = withComposing && comp.isValid && !comp.isCollapsed;
    var pi = 0;
    for (final (s, e, st) in model.spans()) {
      var from = s;
      while (from < e) {
        // Parça paragraf sonunda (`\n` dahil) ve birleştirme bölgesi
        // sınırlarında kesilir: satır aralığı paragrafa, alt çizgi IME
        // bölgesine aittir.
        var to = e;
        final nl = t.indexOf('\n', from);
        if (nl >= 0 && nl < e) to = nl + 1;
        if (showComposing) {
          if (from < comp.start && comp.start < to) to = comp.start;
          if (from < comp.end && comp.end < to) to = comp.end;
        }
        var ts = styleOf(st, model.paras[pi.clamp(0, model.paras.length - 1)]);
        if (showComposing && from >= comp.start && to <= comp.end) {
          ts = ts.copyWith(decoration: TextDecoration.underline);
        }
        children.add(TextSpan(text: t.substring(from, to), style: ts));
        if (t.codeUnitAt(to - 1) == 0x0A) pi++;
        from = to;
      }
    }
    return TextSpan(style: style ?? baseStyle, children: children);
  }
}
