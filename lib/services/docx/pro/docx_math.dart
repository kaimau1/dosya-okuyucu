/// **Faz 37 madde 3 — denklem düzenleyici (OMML).**
///
/// Temel LaTeX girişi → Office Math (`m:oMath`) ve tersi: belgedeki denklem
/// doğrusal LaTeX'e çevrilip düzenlenir, aynı yere geri yazılır. Desteklenen:
/// `\frac{a}{b}`, `\sqrt{x}`, `\sqrt[n]{x}`, `x^{2}`, `x_{i}`, `x_i^2`,
/// `\sum/\prod/\int/\oint` alt-üst sınırlı, `\left( … \right)`, `\text{…}`,
/// Yunan harfleri ve sık işlemler (`\times \pm \leq \geq \neq \infty …`).
library;

import 'package:xml/xml.dart';

import 'docx_package.dart';
import 'docx_style_ops.dart' show DocxOp;

const kLatexSymbols = <String, String>{
  'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ', 'epsilon': 'ε',
  'zeta': 'ζ', 'eta': 'η', 'theta': 'θ', 'iota': 'ι', 'kappa': 'κ',
  'lambda': 'λ', 'mu': 'μ', 'nu': 'ν', 'xi': 'ξ', 'pi': 'π', 'rho': 'ρ',
  'sigma': 'σ', 'tau': 'τ', 'upsilon': 'υ', 'phi': 'φ', 'chi': 'χ',
  'psi': 'ψ', 'omega': 'ω', 'Gamma': 'Γ', 'Delta': 'Δ', 'Theta': 'Θ',
  'Lambda': 'Λ', 'Xi': 'Ξ', 'Pi': 'Π', 'Sigma': 'Σ', 'Phi': 'Φ',
  'Psi': 'Ψ', 'Omega': 'Ω',
  'times': '×', 'div': '÷', 'pm': '±', 'mp': '∓', 'cdot': '·',
  'leq': '≤', 'le': '≤', 'geq': '≥', 'ge': '≥', 'neq': '≠', 'ne': '≠',
  'approx': '≈', 'equiv': '≡', 'infty': '∞', 'partial': '∂',
  'nabla': '∇', 'rightarrow': '→', 'to': '→', 'leftarrow': '←',
  'Rightarrow': '⇒', 'Leftrightarrow': '⇔', 'in': '∈', 'notin': '∉',
  'subset': '⊂', 'supset': '⊃', 'cup': '∪', 'cap': '∩', 'forall': '∀',
  'exists': '∃', 'degree': '°', 'cdots': '⋯', 'ldots': '…', 'propto': '∝',
  'angle': '∠', 'perp': '⊥', 'parallel': '∥', 'emptyset': '∅',
};

const _nary = {'sum': '∑', 'prod': '∏', 'int': '∫', 'oint': '∮', 'iint': '∬'};

XmlElement _m(String local, [List<XmlNode> kids = const [],
        Map<String, String> attrs = const {}]) =>
    XmlElement(XmlName.fromString('m:$local'), [
      for (final MapEntry(:key, :value) in attrs.entries)
        XmlAttribute(XmlName.fromString('m:$key'), value),
    ], kids);

XmlElement _mr(String text) => _m('r', [
      XmlElement(XmlName.fromString('m:t'),
          [XmlAttribute(XmlName.fromString('xml:space'), 'preserve')],
          [XmlText(text)]),
    ]);

XmlElement _e(List<XmlElement> k) => _m('e', k);

/// LaTeX → `m:oMath`. Geçersiz giriş istisna atmaz; tanınmayan komut düz
/// metin olarak kalır.
XmlElement latexToOmml(String latex) => _m('oMath', _LatexParser(latex).parseAll());

class _LatexParser {
  final String s;
  int i = 0;
  _LatexParser(this.s);

  bool get _end => i >= s.length;

  List<XmlElement> parseAll() {
    final out = <XmlElement>[];
    while (!_end) {
      final a = _atom(out);
      if (a != null) out.add(a);
    }
    return _mergeRuns(out);
  }

  /// `{…}` grubu ya da tek atom.
  List<XmlElement> _arg() {
    _skipSpace();
    if (_end) return [];
    if (s[i] == '{') {
      i++;
      final out = <XmlElement>[];
      while (!_end && s[i] != '}') {
        final a = _atom(out);
        if (a != null) out.add(a);
      }
      if (!_end) i++; // }
      return _mergeRuns(out);
    }
    final a = _atom([]);
    return a == null ? [] : [a];
  }

  void _skipSpace() {
    while (!_end && s[i] == ' ') {
      i++;
    }
  }

  String _command() {
    final start = i;
    while (!_end && RegExp(r'[A-Za-z]').hasMatch(s[i])) {
      i++;
    }
    if (i == start && !_end) i++; // \{ \, gibi tek karakter
    return s.substring(start, i);
  }

  /// Bir atom okur; `^`/`_` önceki atomu ([prev] son öğe) üst/alt simgeye
  /// sarar (null döner, [prev] yerinde değişir).
  XmlElement? _atom(List<XmlElement> prev) {
    final ch = s[i];
    if (ch == '^' || ch == '_') {
      i++;
      final arg = _arg();
      final base = prev.isEmpty ? <XmlElement>[] : [prev.removeLast()];
      // x_i^2: önceki sSub'a üst simge eklenir → sSubSup.
      if (ch == '^' && base.isNotEmpty && base.first.name.local == 'sSub') {
        final b = base.first;
        return _m('sSubSup', [
          _e(kid(b, 'e')!.childElements.map((e) => e.copy()).toList()),
          _m('sub', kid(b, 'sub')!.childElements.map((e) => e.copy()).toList()),
          _m('sup', arg),
        ]);
      }
      if (base.isNotEmpty && base.first.name.local == 'nary') {
        final n = base.first;
        n.children.removeWhere((c) => c is XmlElement && c.name.local == (ch == '^' ? 'sup' : 'sub'));
        final e = kid(n, 'e')!;
        final limit = _m(ch == '^' ? 'sup' : 'sub', arg);
        // sub, sup sırası korunur (naryPr, sub, sup, e).
        if (ch == '_' && kid(n, 'sup') != null) {
          n.children.insert(n.children.indexOf(kid(n, 'sup')!), limit);
        } else {
          n.children.insert(n.children.indexOf(e), limit);
        }
        if (e.childElements.isEmpty) e.children.addAll(_naryBody());
        return n;
      }
      return _m(ch == '^' ? 'sSup' : 'sSub', [
        _e(base),
        _m(ch == '^' ? 'sup' : 'sub', arg),
      ]);
    }
    if (ch == '{') {
      final g = _arg();
      return g.length == 1 ? g.single : _m('box', [_e(g)]);
    }
    if (ch == '}') {
      i++;
      return null;
    }
    if (ch == '\\') {
      i++;
      final cmd = _command();
      switch (cmd) {
        case 'frac':
        case 'dfrac':
        case 'tfrac':
          final num = _arg();
          final den = _arg();
          return _m('f', [_m('num', num), _m('den', den)]);
        case 'sqrt':
          _skipSpace();
          List<XmlElement>? deg;
          if (!_end && s[i] == '[') {
            final close = s.indexOf(']', i);
            final inner = s.substring(i + 1, close < 0 ? s.length : close);
            i = close < 0 ? s.length : close + 1;
            deg = _LatexParser(inner).parseAll();
          }
          final body = _arg();
          return _m('rad', [
            if (deg == null)
              _m('radPr', [_m('degHide', const [], {'val': '1'})]),
            _m('deg', deg ?? const []),
            _e(body),
          ]);
        case 'left':
          final open = _end ? '(' : s[i++];
          final inner = <XmlElement>[];
          var close = ')';
          while (!_end) {
            if (s.startsWith(r'\right', i)) {
              i += 6;
              close = _end ? ')' : s[i++];
              break;
            }
            final a = _atom(inner);
            if (a != null) inner.add(a);
          }
          return _m('d', [
            _m('dPr', [
              _m('begChr', const [], {'val': open == '.' ? '' : open}),
              _m('endChr', const [], {'val': close == '.' ? '' : close}),
            ]),
            _e(_mergeRuns(inner)),
          ]);
        case 'text':
        case 'mathrm':
          _skipSpace();
          if (!_end && s[i] == '{') {
            final close = s.indexOf('}', i);
            final t = s.substring(i + 1, close < 0 ? s.length : close);
            i = close < 0 ? s.length : close + 1;
            return _m('r', [
              _m('rPr', [_m('sty', const [], {'val': 'p'})]),
              XmlElement(XmlName.fromString('m:t'),
                  [XmlAttribute(XmlName.fromString('xml:space'), 'preserve')],
                  [XmlText(t)]),
            ]);
          }
          return null;
        case ',':
        case ';':
        case ' ':
          return _mr(' ');
        case '{':
        case '}':
          return _mr(cmd);
      }
      if (_nary[cmd] case final chr?) {
        return _m('nary', [
          _m('naryPr', [
            _m('chr', const [], {'val': chr}),
            _m('limLoc', const [], {'val': cmd.contains('int') ? 'subSup' : 'undOvr'}),
          ]),
          _m('sub'),
          _m('sup'),
          _e(_naryBody()),
        ]);
      }
      if (kLatexSymbols[cmd] case final sym?) return _mr(sym);
      // sin, cos, log… ve tanınmayan: düz harfler.
      return _mr(cmd);
    }
    i++;
    if (ch == ' ') return null;
    return _mr(ch);
  }

  /// ∑'nin gövdesi: sınırlardan sonra gelen ilk terim (sonraki + / − / = ya
  /// da grup sonuna dek).
  List<XmlElement> _naryBody() {
    final out = <XmlElement>[];
    // Önce sınırlar gelebilir: \sum_{i=1}^{n} x — onları üst atom işler,
    // burada yalnız gövde. Sınırlar gövdeden sonra yazılırsa (_atom ^/_)
    // nary dalı onları yerine koyar.
    final save = i;
    _skipSpace();
    if (!_end && (s[i] == '_' || s[i] == '^')) {
      i = save;
      return out;
    }
    while (!_end && !'+-=}'.contains(s[i])) {
      final a = _atom(out);
      if (a != null) out.add(a);
    }
    return _mergeRuns(out);
  }

  /// Bitişik düz `m:r`'ler tek run (Word'ün yazdığı gibi).
  static List<XmlElement> _mergeRuns(List<XmlElement> list) {
    final out = <XmlElement>[];
    for (final e in list) {
      final last = out.isEmpty ? null : out.last;
      if (last != null &&
          last.name.local == 'r' &&
          e.name.local == 'r' &&
          kid(last, 'rPr') == null &&
          kid(e, 'rPr') == null) {
        final t = kid(last, 't')!;
        t.children
          ..clear()
          ..add(XmlText(t.innerText + kid(e, 't')!.innerText));
        continue;
      }
      out.add(e);
    }
    return out;
  }
}

/// `m:oMath` → doğrusal LaTeX (düzenleme kutusu için).
String ommlToLatex(XmlElement e) {
  String all(XmlElement? x) =>
      x == null ? '' : x.childElements.map(ommlToLatex).join();
  String grp(XmlElement? x) {
    final t = all(x);
    return t.length == 1 ? t : '{$t}';
  }

  switch (e.name.local) {
    case 'oMathPara':
    case 'oMath':
    case 'e':
    case 'num':
    case 'den':
    case 'sub':
    case 'sup':
    case 'deg':
    case 'box':
      return all(e);
    case 'r':
      final t = e.descendantElements
          .where((x) => x.name.local == 't')
          .map((x) => x.innerText)
          .join();
      final plain = attrOf(kid(kid(e, 'rPr'), 'sty')) == 'p' &&
          RegExp(r'\s').hasMatch(t);
      if (plain) return '\\text{$t}';
      final rev = {for (final MapEntry(:key, :value) in kLatexSymbols.entries) value: key};
      return t.split('').map((c) => rev[c] == null ? c : '\\${rev[c]} ').join();
    case 'f':
      return '\\frac{${all(kid(e, 'num'))}}{${all(kid(e, 'den'))}}';
    case 'sSup':
      return '${grp(kid(e, 'e'))}^${grp(kid(e, 'sup'))}';
    case 'sSub':
      return '${grp(kid(e, 'e'))}_${grp(kid(e, 'sub'))}';
    case 'sSubSup':
      return '${grp(kid(e, 'e'))}_${grp(kid(e, 'sub'))}^${grp(kid(e, 'sup'))}';
    case 'rad':
      final deg = all(kid(e, 'deg'));
      return deg.isEmpty
          ? '\\sqrt{${all(kid(e, 'e'))}}'
          : '\\sqrt[$deg]{${all(kid(e, 'e'))}}';
    case 'nary':
      final chr = attrOf(kid(kid(e, 'naryPr'), 'chr')) ?? '∫';
      final name = _nary.entries
              .where((x) => x.value == chr)
              .map((x) => x.key)
              .firstOrNull ??
          'int';
      final sub = all(kid(e, 'sub')), sup = all(kid(e, 'sup'));
      return '\\$name${sub.isEmpty ? '' : '_{$sub}'}${sup.isEmpty ? '' : '^{$sup}'} ${all(kid(e, 'e'))}';
    case 'd':
      final pr = kid(e, 'dPr');
      final beg = attrOf(kid(pr, 'begChr')) ?? '(';
      final end = attrOf(kid(pr, 'endChr')) ?? ')';
      final inner = kids(e, 'e').map(all).join(',');
      return '\\left${beg.isEmpty ? '.' : beg}$inner\\right${end.isEmpty ? '.' : end}';
    case 'rPr':
    case 'ctrlPr':
    case 'fPr':
    case 'radPr':
    case 'naryPr':
    case 'dPr':
    case 'sSupPr':
    case 'sSubPr':
    case 'oMathParaPr':
      return '';
    default:
      return all(e);
  }
}

abstract final class DocxMathOps {
  /// [i]. paragrafın denklemleri (doğrusal).
  static List<String> read(DocxPackage pkg, int i) {
    final paras = pkg.modelParagraphs();
    if (i < 0 || i >= paras.length) return const [];
    return [
      for (final m in paras[i].descendantElements)
        if (m.name.local == 'oMath' && m.name.prefix == 'm') ommlToLatex(m).trim(),
    ];
  }

  /// [i]. paragraftan sonra ortalanmış (display) denklem paragrafı.
  static DocxOp insert(int i, String latex) => (pkg) {
        pkg.ensureNs('m', kM);
        pkg.insertAfterPara(i, [
          w('p', kids: [
            _m('oMathPara', [latexToOmml(latex)]),
          ]),
        ]);
      };

  /// [i]. paragraftaki [k]. denklemi değiştirir.
  static DocxOp replace(int i, int k, String latex) => (pkg) {
        pkg.ensureNs('m', kM);
        final paras = pkg.modelParagraphs();
        if (i < 0 || i >= paras.length) return;
        final maths = paras[i]
            .descendantElements
            .where((m) => m.name.local == 'oMath' && m.name.prefix == 'm')
            .toList();
        if (k < 0 || k >= maths.length) return;
        final old = maths[k];
        old.replace(latexToOmml(latex));
      };
}
