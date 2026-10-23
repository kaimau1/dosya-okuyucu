/// Word belge modelinin **görünüş** tarafı (Faz 22): stil zinciri, tema
/// yazı tipleri, numaralandırma. Yalnız okur — yazma `docx_document.dart`.
///
/// Çözüm sırası Word'ünkiyle aynı: `docDefaults` → paragraf stili zinciri
/// (`basedOn`) → karakter stili zinciri → doğrudan biçim (`w:rPr`/`w:pPr`).
library;

import 'package:xml/xml.dart';

import '../../core/doc_fonts.dart';
import '../../core/symbol_fonts.dart';


XmlElement? _child(XmlElement? e, String local) {
  if (e == null) return null;
  for (final c in e.childElements) {
    if (c.name.local == local) return c;
  }
  return null;
}

String? _val(XmlElement? e) =>
    e?.getAttribute('val', namespace: _ns) ?? e?.getAttribute('w:val');

const _ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

/// `w:b`, `w:i` gibi aç/kapa özelliği: varsa açık, `val="0|false|off"` kapalı.
bool? _toggle(XmlElement? rPr, String local) {
  final e = _child(rPr, local);
  if (e == null) return null;
  final v = _val(e);
  return !(v == '0' || v == 'false' || v == 'off');
}

/// Çözülmüş harf görünüşü (punto biriminde).
class DocxRunLook {
  final bool bold, italic, underline, strike;
  final double sizePt;

  /// ARGB; null = otomatik (tema metin rengi).
  final int? color;

  /// Vurgu (fosforlu kalem) ARGB.
  final int? highlight;

  /// Belgede yazılı yazı tipi adı (ekranda gömülü karşılığıyla çizilir).
  final String? font;

  /// `superscript` | `subscript` | null.
  final String? vertAlign;

  const DocxRunLook({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.sizePt = 11,
    this.color,
    this.highlight,
    this.font,
    this.vertAlign,
  });

  /// Ekranda kullanılacak aile (Calibri → Carlito …; bilinmeyen → cihaz).
  String? get renderFamily {
    final f = font;
    if (f == null) return null;
    final r = renderFamilyFor(f);
    return r == f ? null : r;
  }
}

/// Çözülmüş paragraf görünüşü.
class DocxParaLook {
  /// `left` | `center` | `right` | `both`.
  final String align;
  final double indentLeftPt, firstLinePt, spaceBeforePt, spaceAfterPt;

  /// Satır aralığı çarpanı (auto); null = tek.
  final double? lineMultiple;
  final bool bidi;

  /// Başlık düzeyi (1–9; 0 = başlık değil).
  final int headingLevel;
  final String? styleId;
  final String? styleName;

  /// Liste: (numId, düzey) — numaralandırma etiketini [DocxNumbering] verir.
  final int? numId;
  final int ilvl;
  final bool pageBreakBefore;

  const DocxParaLook({
    this.align = 'left',
    this.indentLeftPt = 0,
    this.firstLinePt = 0,
    this.spaceBeforePt = 0,
    this.spaceAfterPt = 0,
    this.lineMultiple,
    this.bidi = false,
    this.headingLevel = 0,
    this.styleId,
    this.styleName,
    this.numId,
    this.ilvl = 0,
    this.pageBreakBefore = false,
  });
}

class _Style {
  final String id;
  final String type;
  final String? name;
  final String? basedOn;
  final String? next;
  final XmlElement? rPr;
  final XmlElement? pPr;
  const _Style(this.id, this.type, this.name, this.basedOn, this.next, this.rPr,
      this.pPr);
}

/// `word/styles.xml` + tema yazı tipleri.
class DocxStyles {
  final Map<String, _Style> _styles;
  final XmlElement? _defRPr;
  final XmlElement? _defPPr;
  final String? _defaultParaStyle;
  final String _majorFont;
  final String _minorFont;

  /// pPr düğümü başına çözülmüş görünüş (pPr'ler değişmez: değişen kopyadır).
  final _paraCache = Expando<DocxParaLook>('docxParaLook');
  DocxParaLook? _nullLook;

  DocxStyles._(this._styles, this._defRPr, this._defPPr, this._defaultParaStyle,
      this._majorFont, this._minorFont);

  factory DocxStyles.parse(XmlDocument? styles, XmlDocument? theme) {
    final map = <String, _Style>{};
    XmlElement? defR, defP;
    String? defaultPara;
    if (styles != null) {
      final root = styles.rootElement;
      final dd = _child(root, 'docDefaults');
      defR = _child(_child(dd, 'rPrDefault'), 'rPr');
      defP = _child(_child(dd, 'pPrDefault'), 'pPr');
      for (final s in root.childElements) {
        if (s.name.local != 'style') continue;
        final id = s.getAttribute('styleId', namespace: _ns) ??
            s.getAttribute('w:styleId');
        if (id == null) continue;
        final type = s.getAttribute('type', namespace: _ns) ??
            s.getAttribute('w:type') ??
            'paragraph';
        final st = _Style(
          id,
          type,
          _val(_child(s, 'name')),
          _val(_child(s, 'basedOn')),
          _val(_child(s, 'next')),
          _child(s, 'rPr'),
          _child(s, 'pPr'),
        );
        map[id] = st;
        final isDefault = s.getAttribute('default', namespace: _ns) ??
            s.getAttribute('w:default');
        if (type == 'paragraph' && (isDefault == '1' || isDefault == 'true')) {
          defaultPara = id;
        }
      }
    }
    var major = 'Calibri Light', minor = 'Calibri';
    if (theme != null) {
      for (final e in theme.descendantElements) {
        if (e.name.local == 'majorFont') {
          major = _child(e, 'latin')?.getAttribute('typeface') ?? major;
        } else if (e.name.local == 'minorFont') {
          minor = _child(e, 'latin')?.getAttribute('typeface') ?? minor;
        }
      }
    }
    return DocxStyles._(map, defR, defP, defaultPara, major, minor);
  }

  /// Stil adı / kimliği (yoksa null).
  String? nameOf(String? id) => id == null ? null : _styles[id]?.name;

  /// Enter'dan sonra gelecek paragraf stili (`w:next`; yoksa aynı stil).
  String? nextStyleOf(String? id) {
    if (id == null) return null;
    return _styles[id]?.next ?? id;
  }

  String? get defaultParagraphStyle => _defaultParaStyle;

  /// Stil zinciri (en temelden en özele).
  List<_Style> _chain(String? id) {
    final out = <_Style>[];
    final seen = <String>{};
    var cur = id;
    while (cur != null && seen.add(cur)) {
      final s = _styles[cur];
      if (s == null) break;
      out.insert(0, s);
      cur = s.basedOn;
    }
    return out;
  }

  /// Paragraf stilinin kimliği (`w:pStyle`; yoksa varsayılan paragraf stili).
  String? paraStyleId(XmlElement? pPr) =>
      _val(_child(pPr, 'pStyle')) ?? _defaultParaStyle;

  /// Paragraf görünüşü (stil + doğrudan pPr).
  DocxParaLook paraLook(XmlElement? pPr) => pPr == null
      ? (_nullLook ??= _paraLook(null))
      : (_paraCache[pPr] ??= _paraLook(pPr));

  DocxParaLook _paraLook(XmlElement? pPr) {
    final styleId = paraStyleId(pPr);
    final layers = <XmlElement?>[
      _defPPr,
      for (final s in _chain(styleId)) s.pPr,
      pPr,
    ];
    String align = 'left';
    double left = 0, first = 0, before = 0, after = 0;
    double? line;
    var bidi = false;
    int? numId;
    var ilvl = 0;
    var outline = -1;
    var pageBreak = false;
    for (final l in layers) {
      if (l == null) continue;
      final jc = _val(_child(l, 'jc'));
      if (jc != null) align = _normAlign(jc);
      final ind = _child(l, 'ind');
      if (ind != null) {
        final s = _twips(ind, 'start') ?? _twips(ind, 'left');
        if (s != null) left = s;
        final f = _twips(ind, 'firstLine');
        final h = _twips(ind, 'hanging');
        if (f != null) first = f;
        if (h != null) first = -h;
      }
      final sp = _child(l, 'spacing');
      if (sp != null) {
        final b = _twips(sp, 'before');
        final a = _twips(sp, 'after');
        if (b != null) before = b;
        if (a != null) after = a;
        final ln = double.tryParse(sp.getAttribute('line', namespace: _ns) ??
            sp.getAttribute('w:line') ??
            '');
        final rule = sp.getAttribute('lineRule', namespace: _ns) ??
            sp.getAttribute('w:lineRule') ??
            'auto';
        if (ln != null && rule == 'auto') line = ln / 240;
      }
      final bd = _toggle(l, 'bidi');
      if (bd != null) bidi = bd;
      final np = _child(l, 'numPr');
      if (np != null) {
        final id = int.tryParse(_val(_child(np, 'numId')) ?? '');
        if (id != null) numId = id;
        final lv = int.tryParse(_val(_child(np, 'ilvl')) ?? '');
        if (lv != null) ilvl = lv;
      }
      final ol = int.tryParse(_val(_child(l, 'outlineLvl')) ?? '');
      if (ol != null) outline = ol;
      final pb = _toggle(l, 'pageBreakBefore');
      if (pb != null) pageBreak = pb;
    }
    // Başlık: anahat düzeyi ya da "heading N" adlı stil.
    var heading = outline >= 0 && outline < 9 ? outline + 1 : 0;
    if (heading == 0) {
      final m = RegExp(r'^heading (\d)$', caseSensitive: false)
          .firstMatch(nameOf(styleId) ?? '');
      if (m != null) heading = int.parse(m[1]!);
      if ((nameOf(styleId) ?? '').toLowerCase() == 'title') heading = 1;
    }
    return DocxParaLook(
      align: align,
      indentLeftPt: left,
      firstLinePt: first,
      spaceBeforePt: before,
      spaceAfterPt: after,
      lineMultiple: line,
      bidi: bidi,
      headingLevel: heading,
      styleId: styleId,
      styleName: nameOf(styleId),
      numId: numId == 0 ? null : numId,
      ilvl: ilvl,
      pageBreakBefore: pageBreak,
    );
  }

  /// Harf görünüşü: docDefaults → paragraf stili → karakter stili → doğrudan.
  DocxRunLook runLook(XmlElement? pPr, XmlElement? rPr) {
    final charStyle = _val(_child(rPr, 'rStyle'));
    final layers = <XmlElement?>[
      _defRPr,
      for (final s in _chain(paraStyleId(pPr))) s.rPr,
      for (final s in _chain(charStyle)) s.rPr,
      rPr,
    ];
    var bold = false, italic = false, underline = false, strike = false;
    var size = 10.0; // Word: sz yoksa 10 pt
    int? color, highlight;
    String? font, vert;
    for (final l in layers) {
      if (l == null) continue;
      bold = _toggle(l, 'b') ?? bold;
      italic = _toggle(l, 'i') ?? italic;
      strike = _toggle(l, 'strike') ?? strike;
      final u = _child(l, 'u');
      if (u != null) underline = (_val(u) ?? 'single') != 'none';
      final sz = double.tryParse(_val(_child(l, 'sz')) ?? '');
      if (sz != null) size = sz / 2;
      final c = _val(_child(l, 'color'));
      if (c != null) color = c == 'auto' ? null : _argb(c);
      final hl = _val(_child(l, 'highlight'));
      if (hl != null) highlight = _highlightArgb(hl);
      final shd = _child(l, 'shd');
      final fill = shd?.getAttribute('fill', namespace: _ns) ??
          shd?.getAttribute('w:fill');
      if (fill != null && fill != 'auto' && highlight == null) {
        highlight = _argb(fill);
      }
      final f = _child(l, 'rFonts');
      if (f != null) {
        String? a(String n) =>
            f.getAttribute(n, namespace: _ns) ?? f.getAttribute('w:$n');
        final theme = a('asciiTheme');
        if (theme != null) {
          font = theme.startsWith('major') ? _majorFont : _minorFont;
        }
        font = a('ascii') ?? a('hAnsi') ?? font;
      }
      final va = _val(_child(l, 'vertAlign'));
      if (va != null) vert = va == 'baseline' ? null : va;
    }
    font ??= _minorFont;
    return DocxRunLook(
      bold: bold,
      italic: italic,
      underline: underline,
      strike: strike,
      sizePt: size,
      color: color,
      highlight: highlight,
      font: font,
      vertAlign: vert,
    );
  }

  static double? _twips(XmlElement e, String name) {
    final v = e.getAttribute(name, namespace: _ns) ?? e.getAttribute('w:$name');
    final d = v == null ? null : double.tryParse(v);
    return d == null ? null : d / 20;
  }

  static String _normAlign(String v) => switch (v) {
        'center' => 'center',
        'right' || 'end' => 'right',
        'both' || 'distribute' => 'both',
        _ => 'left',
      };

  static int? _argb(String hex) {
    final v = int.tryParse(hex, radix: 16);
    return v == null || hex.length != 6 ? null : 0xFF000000 | v;
  }

  static int? _highlightArgb(String name) => switch (name) {
        'yellow' => 0xFFFFFF00,
        'green' => 0xFF00FF00,
        'cyan' => 0xFF00FFFF,
        'magenta' => 0xFFFF00FF,
        'blue' => 0xFF0000FF,
        'red' => 0xFFFF0000,
        'darkBlue' => 0xFF000080,
        'darkCyan' => 0xFF008080,
        'darkGreen' => 0xFF008000,
        'darkMagenta' => 0xFF800080,
        'darkRed' => 0xFF800000,
        'darkYellow' => 0xFF808000,
        'darkGray' => 0xFF808080,
        'lightGray' => 0xFFC0C0C0,
        'black' => 0xFF000000,
        _ => null,
      };
}

/// Bir liste düzeyi.
class _Level {
  final String fmt;
  final String text;
  final int start;
  final String? font;
  final double indentPt;
  const _Level(this.fmt, this.text, this.start, this.font, this.indentPt);
}

/// `word/numbering.xml` — liste etiketleri ("1.", "a)", "•").
class DocxNumbering {
  final Map<int, Map<int, _Level>> _byNum;

  DocxNumbering._(this._byNum);

  factory DocxNumbering.parse(XmlDocument? doc) {
    final abstract = <String, Map<int, _Level>>{};
    final byNum = <int, Map<int, _Level>>{};
    if (doc != null) {
      for (final a in doc.rootElement.childElements) {
        if (a.name.local != 'abstractNum') continue;
        final id = a.getAttribute('abstractNumId', namespace: _ns) ??
            a.getAttribute('w:abstractNumId');
        if (id == null) continue;
        final levels = <int, _Level>{};
        for (final l in a.childElements) {
          if (l.name.local != 'lvl') continue;
          final ilvl = int.tryParse(l.getAttribute('ilvl', namespace: _ns) ??
                  l.getAttribute('w:ilvl') ??
                  '') ??
              0;
          final ind = _child(_child(l, 'pPr'), 'ind');
          final left = ind == null
              ? (ilvl + 1) * 36.0
              : (DocxStyles._twips(ind, 'start') ??
                  DocxStyles._twips(ind, 'left') ??
                  (ilvl + 1) * 36.0);
          final fonts = _child(_child(l, 'rPr'), 'rFonts');
          levels[ilvl] = _Level(
            _val(_child(l, 'numFmt')) ?? 'decimal',
            _val(_child(l, 'lvlText')) ?? '',
            int.tryParse(_val(_child(l, 'start')) ?? '') ?? 1,
            fonts?.getAttribute('ascii', namespace: _ns) ??
                fonts?.getAttribute('w:ascii'),
            left,
          );
        }
        abstract[id] = levels;
      }
      for (final n in doc.rootElement.childElements) {
        if (n.name.local != 'num') continue;
        final id = int.tryParse(n.getAttribute('numId', namespace: _ns) ??
            n.getAttribute('w:numId') ??
            '');
        final abs = _val(_child(n, 'abstractNumId'));
        if (id == null || abs == null) continue;
        final levels = abstract[abs];
        if (levels != null) byNum[id] = levels;
      }
    }
    return DocxNumbering._(byNum);
  }

  bool isBullet(int numId, int ilvl) =>
      _byNum[numId]?[ilvl]?.fmt == 'bullet';

  /// Liste düzeyinin sol girintisi (punto); bilinmiyorsa null.
  double? indentOf(int numId, int ilvl) => _byNum[numId]?[ilvl]?.indentPt;

  /// Belge sırasıyla verilen (numId, düzey) dizisinin etiketleri. Sayaçlar
  /// liste başına tutulur; üst düzeye dönünce alt düzeyler sıfırlanır.
  List<String> labels(List<(int?, int)> seq) {
    final counters = <int, List<int>>{};
    final out = <String>[];
    for (final (numId, ilvl) in seq) {
      if (numId == null) {
        out.add('');
        continue;
      }
      final levels = _byNum[numId];
      final lvl = levels?[ilvl];
      if (levels == null || lvl == null) {
        out.add('•');
        continue;
      }
      final c = counters.putIfAbsent(numId, () => List.filled(9, 0));
      for (var k = 0; k < 9; k++) {
        if (k == ilvl) {
          c[k] = c[k] == 0 ? lvl.start : c[k] + 1;
        } else if (k > ilvl) {
          c[k] = 0;
        }
      }
      if (lvl.fmt == 'bullet') {
        out.add(mapSymbolFont(lvl.text.isEmpty ? '•' : lvl.text, lvl.font,
            bullet: true));
        continue;
      }
      if (lvl.fmt == 'none') {
        out.add('');
        continue;
      }
      var label = lvl.text;
      for (var k = 0; k <= ilvl && k < 9; k++) {
        final l = levels[k];
        final n = c[k] == 0 ? (l?.start ?? 1) : c[k];
        label = label.replaceAll('%${k + 1}', _fmt(n, l?.fmt ?? 'decimal'));
      }
      out.add(label);
    }
    return out;
  }

  static String _fmt(int n, String fmt) => switch (fmt) {
        'lowerLetter' => _letters(n).toLowerCase(),
        'upperLetter' => _letters(n),
        'lowerRoman' => _roman(n).toLowerCase(),
        'upperRoman' => _roman(n),
        _ => '$n',
      };

  static String _letters(int n) {
    var s = '';
    var v = n;
    while (v > 0) {
      v--;
      s = String.fromCharCode(65 + v % 26) + s;
      v ~/= 26;
    }
    return s;
  }

  static String _roman(int n) {
    const vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const syms = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
    var v = n, out = '';
    for (var i = 0; i < vals.length; i++) {
      while (v >= vals[i]) {
        out += syms[i];
        v -= vals[i];
      }
    }
    return out;
  }
}
