import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:xml/xml.dart';

/// PPTX (Open XML) slaytlarını **gerçek tasarımıyla** çizebilmek için gereken
/// geometri/renk/metin bilgisini çıkarır. Çizim `widgets/slide_canvas.dart`te.
///
/// Ölçü birimi: **punto (pt)**. EMU -> pt = /12700.
/// Kapsam: arka plan, düzen/asıl slayt (master) grafikleri, dikdörtgen/elips
/// şekiller, dolgu + çerçeve, görseller, gruplar, metin (boyut/kalın/italik/
/// renk/hizalama/madde işareti).
// ponytail: SmartArt, tablo, grafik, animasyon, gradient dolgu ve gömülü yazı
// tipleri çizilmez — düz renk/görsel/metin ile %80 sadakat hedefi. Gerekirse
// gradient ve a:tbl bir sonraki turda eklenir.

const double _emuPerPt = 12700;

class SlideVM {
  final double widthPt;
  final double heightPt;
  final Color? background;
  final Uint8List? backgroundImage;
  final List<ShapeVM> shapes;
  const SlideVM({
    required this.widthPt,
    required this.heightPt,
    required this.shapes,
    this.background,
    this.backgroundImage,
  });
}

class ShapeVM {
  final double x, y, w, h;
  final double rotationDeg;
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
  final bool isEllipse;
  final double cornerRadius;
  final Uint8List? image;
  final List<ParaVM> paragraphs;
  final String vAnchor; // t | ctr | b
  final EdgeInsets inset;
  final double fontScale;

  const ShapeVM({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.rotationDeg = 0,
    this.fill,
    this.stroke,
    this.strokeWidth = 0,
    this.isEllipse = false,
    this.cornerRadius = 0,
    this.image,
    this.paragraphs = const [],
    this.vAnchor = 't',
    this.inset = const EdgeInsets.fromLTRB(7.2, 3.6, 7.2, 3.6),
    this.fontScale = 1,
  });

  bool get hasText => paragraphs.any((p) => p.plainText.isNotEmpty);
}

class ParaVM {
  final TextAlign align;
  final double indentPt;
  final String bullet;
  final double lineHeight;
  final double spaceBeforePt;
  final List<RunVM> runs;

  /// Düzenlemeyi orijinal XML'e bağlayan `<a:p>` düğümü (slayt XML'inden).
  final XmlElement? source;

  const ParaVM({
    required this.runs,
    this.align = TextAlign.left,
    this.indentPt = 0,
    this.bullet = '',
    this.lineHeight = 1.2,
    this.spaceBeforePt = 0,
    this.source,
  });

  String get plainText => runs.map((r) => r.text).join();
}

class RunVM {
  final String text;
  final double sizePt;
  final bool bold;
  final bool italic;
  final bool underline;
  final Color color;
  const RunVM({
    required this.text,
    this.sizePt = 18,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color = const Color(0xFF000000),
  });
}

/// Şekil koordinatlarını üst uzaya taşıyan basit ölçek+öteleme dönüşümü
/// (grup şekilleri için).
class _Xf {
  final double dx, dy, sx, sy;
  const _Xf([this.dx = 0, this.dy = 0, this.sx = 1, this.sy = 1]);
  double px(double v) => dx + v * sx;
  double py(double v) => dy + v * sy;
  _Xf then(_Xf inner) => _Xf(
        dx + inner.dx * sx,
        dy + inner.dy * sy,
        sx * inner.sx,
        sy * inner.sy,
      );
}

class _TextDefaults {
  final double size;
  final Color color;
  final bool bold;
  const _TextDefaults(this.size, this.color, this.bold);
}

/// Bir .pptx arşivini slayt görünüm modellerine çevirir.
class PptxRender {
  final Archive _archive;
  double slideW = 960;
  double slideH = 540;

  final Map<String, Map<String, String>> _relsCache = {};
  final Map<String, XmlDocument?> _xmlCache = {};
  final Map<String, Map<String, Color>> _themeCache = {};

  PptxRender(this._archive) {
    final pres = _xml('ppt/presentation.xml');
    final sz = pres == null ? null : _first(pres.rootElement, 'p:sldSz');
    if (sz != null) {
      slideW = _pt(sz.getAttribute('cx')) ?? 960;
      slideH = _pt(sz.getAttribute('cy')) ?? 540;
    }
  }

  /// Tek bir slaytı çizilebilir modele çevirir. [slideDoc] verilirse (düzenleyici
  /// tarafından ayrıştırılmış olan) o kullanılır — böylece `<a:p>` düğümleri
  /// düzenleme nesneleriyle aynı olur.
  SlideVM slide(String slideFile, [XmlDocument? slideDoc]) {
    final doc = slideDoc ?? _xml(slideFile);
    if (doc == null) {
      return SlideVM(widthPt: slideW, heightPt: slideH, shapes: const []);
    }
    final rels = _rels(slideFile);
    final layoutFile = _relOfType(rels, 'slideLayout');
    final layoutDoc = layoutFile == null ? null : _xml(layoutFile);
    final masterFile = layoutFile == null
        ? null
        : _relOfType(_rels(layoutFile), 'slideMaster');
    final masterDoc = masterFile == null ? null : _xml(masterFile);

    final theme = _themeOf(masterFile);
    final clrMap = _clrMap(masterDoc);
    final defaults = _textDefaults(masterDoc, theme, clrMap);

    Color? bg;
    Uint8List? bgImage;
    // Arka plan: slayt -> düzen -> asıl slayt sırasıyla ilk bulunan kazanır.
    final bgSources = <(XmlDocument?, String?)>[
      (doc, slideFile),
      (layoutDoc, layoutFile),
      (masterDoc, masterFile),
    ];
    for (final (d, file) in bgSources) {
      if (d == null || file == null) continue;
      final bgEl = _first(_first(d.rootElement, 'p:cSld'), 'p:bg');
      if (bgEl == null) continue;
      bg = _bgColor(bgEl, theme, clrMap);
      bgImage ??= _bgImage(bgEl, file);
      if (bg != null || bgImage != null) break;
    }

    final shapes = <ShapeVM>[];
    // Çizim sırası: asıl slayt -> düzen -> slayt (üstte).
    final showMaster = doc.rootElement.getAttribute('showMasterSp') != '0';
    if (showMaster && masterDoc != null && masterFile != null) {
      _collect(masterDoc, masterFile, shapes, theme, clrMap, defaults,
          skipPlaceholders: true);
    }
    if (layoutDoc != null && layoutFile != null) {
      _collect(layoutDoc, layoutFile, shapes, theme, clrMap, defaults,
          skipPlaceholders: true);
    }
    _collect(doc, slideFile, shapes, theme, clrMap, defaults,
        skipPlaceholders: false,
        placeholderSource: [layoutDoc, masterDoc],
        editable: true);

    return SlideVM(
      widthPt: slideW,
      heightPt: slideH,
      background: bg,
      backgroundImage: bgImage,
      shapes: shapes,
    );
  }

  // --------------------------------------------------------------- toplama

  void _collect(
    XmlDocument doc,
    String file,
    List<ShapeVM> out,
    Map<String, Color> theme,
    Map<String, String> clrMap,
    Map<String, _TextDefaults> defaults, {
    required bool skipPlaceholders,
    List<XmlDocument?> placeholderSource = const [],
    bool editable = false,
  }) {
    final tree = _first(_first(doc.rootElement, 'p:cSld'), 'p:spTree');
    if (tree == null) return;
    _walk(tree, const _Xf(), file, out, theme, clrMap, defaults,
        skipPlaceholders: skipPlaceholders,
        placeholderSource: placeholderSource,
        editable: editable);
  }

  void _walk(
    XmlElement parent,
    _Xf xf,
    String file,
    List<ShapeVM> out,
    Map<String, Color> theme,
    Map<String, String> clrMap,
    Map<String, _TextDefaults> defaults, {
    required bool skipPlaceholders,
    required List<XmlDocument?> placeholderSource,
    required bool editable,
  }) {
    for (final el in parent.childElements) {
      switch (el.name.qualified) {
        case 'p:sp':
        case 'p:pic':
          final ph = _placeholder(el);
          if (skipPlaceholders && ph != null) continue;
          final shape = _shape(el, xf, file, theme, clrMap, defaults, ph,
              placeholderSource, editable);
          if (shape != null) out.add(shape);
          break;
        case 'p:grpSp':
          final grpXf = _groupXf(el);
          _walk(el, xf.then(grpXf), file, out, theme, clrMap, defaults,
              skipPlaceholders: skipPlaceholders,
              placeholderSource: placeholderSource,
              editable: editable);
          break;
        case 'p:graphicFrame':
          _table(el, xf, out, theme, clrMap, defaults, editable);
          break;
        default:
          break; // connector, ole nesnesi vb. atlanır
      }
    }
  }

  _Xf _groupXf(XmlElement grp) {
    final xfrm = _first(_first(grp, 'p:grpSpPr'), 'a:xfrm');
    if (xfrm == null) return const _Xf();
    final off = _first(xfrm, 'a:off');
    final ext = _first(xfrm, 'a:ext');
    final chOff = _first(xfrm, 'a:chOff');
    final chExt = _first(xfrm, 'a:chExt');
    if (off == null || ext == null || chOff == null || chExt == null) {
      return const _Xf();
    }
    final cw = _pt(chExt.getAttribute('cx')) ?? 0;
    final ch = _pt(chExt.getAttribute('cy')) ?? 0;
    if (cw == 0 || ch == 0) return const _Xf();
    final sx = (_pt(ext.getAttribute('cx')) ?? 0) / cw;
    final sy = (_pt(ext.getAttribute('cy')) ?? 0) / ch;
    final dx = (_pt(off.getAttribute('x')) ?? 0) - (_pt(chOff.getAttribute('x')) ?? 0) * sx;
    final dy = (_pt(off.getAttribute('y')) ?? 0) - (_pt(chOff.getAttribute('y')) ?? 0) * sy;
    return _Xf(dx, dy, sx, sy);
  }

  /// Tabloyu (a:tbl) hücre başına bir dikdörtgen şekle açar — çizim katmanı
  /// böylece tablo için ayrı koda ihtiyaç duymaz.
  // ponytail: grafik/SmartArt içeren graphicFrame'ler atlanır; sadece tablo çizilir.
  void _table(
    XmlElement frame,
    _Xf xf,
    List<ShapeVM> out,
    Map<String, Color> theme,
    Map<String, String> clrMap,
    Map<String, _TextDefaults> defaults,
    bool editable,
  ) {
    final tbl = _firstDeep(frame, 'a:tbl');
    if (tbl == null) return;
    final xfrm = _first(frame, 'p:xfrm');
    final off = _first(xfrm, 'a:off');
    if (off == null) return;
    final x0 = xf.px(_pt(off.getAttribute('x')) ?? 0);
    final y0 = xf.py(_pt(off.getAttribute('y')) ?? 0);

    final widths = <double>[];
    final grid = _first(tbl, 'a:tblGrid');
    if (grid != null) {
      for (final col in grid.childElements) {
        widths.add((_pt(col.getAttribute('w')) ?? 0) * xf.sx);
      }
    }
    if (widths.isEmpty) return;

    var y = y0;
    for (final row in tbl.findElements('a:tr')) {
      final rowH = (_pt(row.getAttribute('h')) ?? 0) * xf.sy;
      var x = x0;
      var col = 0;
      for (final cell in row.findElements('a:tc')) {
        if (col >= widths.length) break;
        final span = int.tryParse(cell.getAttribute('gridSpan') ?? '') ?? 1;
        var w = 0.0;
        for (var i = col; i < col + span && i < widths.length; i++) {
          w += widths[i];
        }
        final merged = cell.getAttribute('hMerge') == '1' ||
            cell.getAttribute('vMerge') == '1';
        final tcPr = _first(cell, 'a:tcPr');
        final body = _first(cell, 'a:txBody');
        if (!merged && w > 0 && rowH > 0) {
          final ln = tcPr == null
              ? null
              : (_first(tcPr, 'a:lnB') ?? _first(tcPr, 'a:lnT'));
          out.add(ShapeVM(
            x: x,
            y: y,
            w: w,
            h: rowH,
            fill: tcPr == null ? null : _solidFill(tcPr, theme, clrMap),
            stroke: ln == null ? null : _solidFill(ln, theme, clrMap),
            strokeWidth: ln == null ? 0 : ((_pt(ln.getAttribute('w')) ?? 1)),
            vAnchor: tcPr?.getAttribute('anchor') ?? 'ctr',
            paragraphs: body == null
                ? const []
                : _paragraphs(body, theme, clrMap, defaults, null, editable),
          ));
        }
        x += w;
        col += span;
      }
      y += rowH;
    }
  }

  ShapeVM? _shape(
    XmlElement el,
    _Xf xf,
    String file,
    Map<String, Color> theme,
    Map<String, String> clrMap,
    Map<String, _TextDefaults> defaults,
    _Ph? ph,
    List<XmlDocument?> placeholderSource,
    bool editable,
  ) {
    final spPr = _first(el, 'p:spPr');
    var xfrm = spPr == null ? null : _first(spPr, 'a:xfrm');
    // Yer tutucunun konumu slaytta yoksa düzen/asıl slayttan devralınır.
    if (xfrm == null && ph != null) {
      for (final src in placeholderSource) {
        final inherited = src == null ? null : _findPlaceholder(src, ph);
        if (inherited != null) {
          xfrm = _first(_first(inherited, 'p:spPr'), 'a:xfrm');
          if (xfrm != null) break;
        }
      }
    }
    if (xfrm == null) return null;
    final off = _first(xfrm, 'a:off');
    final ext = _first(xfrm, 'a:ext');
    if (off == null || ext == null) return null;

    final x = xf.px(_pt(off.getAttribute('x')) ?? 0);
    final y = xf.py(_pt(off.getAttribute('y')) ?? 0);
    final w = (_pt(ext.getAttribute('cx')) ?? 0) * xf.sx;
    final h = (_pt(ext.getAttribute('cy')) ?? 0) * xf.sy;
    if (w <= 0 || h <= 0) return null;

    final rot = (int.tryParse(xfrm.getAttribute('rot') ?? '') ?? 0) / 60000.0;

    final prst = _first(spPr, 'a:prstGeom')?.getAttribute('prst') ?? 'rect';
    final isEllipse = prst == 'ellipse' || prst == 'chord' || prst == 'pie';

    Color? fill;
    if (spPr != null && _first(spPr, 'a:noFill') == null) {
      fill = _solidFill(spPr, theme, clrMap);
    }

    Color? stroke;
    double strokeW = 0;
    final ln = spPr == null ? null : _first(spPr, 'a:ln');
    if (ln != null && _first(ln, 'a:noFill') == null) {
      stroke = _solidFill(ln, theme, clrMap);
      strokeW = (_pt(ln.getAttribute('w')) ?? 1);
      if (stroke != null && strokeW <= 0) strokeW = 1;
    }

    Uint8List? image;
    if (el.name.qualified == 'p:pic') {
      final blip = _firstDeep(el, 'a:blip');
      final rid = blip?.getAttribute('r:embed');
      if (rid != null) {
        final target = _rels(file)[rid];
        if (target != null) image = _imageBytes(target);
      }
      if (image == null) return null; // desteklenmeyen görsel (emf/wmf) atlanır
    }

    final txBody = _first(el, 'p:txBody');
    final bodyPr = txBody == null ? null : _first(txBody, 'a:bodyPr');
    final paras = txBody == null
        ? <ParaVM>[]
        : _paragraphs(txBody, theme, clrMap, defaults, ph, editable);

    return ShapeVM(
      x: x,
      y: y,
      w: w,
      h: h,
      rotationDeg: rot,
      fill: fill,
      stroke: stroke,
      strokeWidth: strokeW,
      isEllipse: isEllipse,
      cornerRadius: prst == 'roundRect' ? (w < h ? w : h) * 0.12 : 0,
      image: image,
      paragraphs: paras,
      vAnchor: bodyPr?.getAttribute('anchor') ?? 't',
      inset: EdgeInsets.fromLTRB(
        _pt(bodyPr?.getAttribute('lIns')) ?? 7.2,
        _pt(bodyPr?.getAttribute('tIns')) ?? 3.6,
        _pt(bodyPr?.getAttribute('rIns')) ?? 7.2,
        _pt(bodyPr?.getAttribute('bIns')) ?? 3.6,
      ),
      fontScale: _fontScale(bodyPr),
    );
  }

  double _fontScale(XmlElement? bodyPr) {
    final fit = bodyPr == null ? null : _first(bodyPr, 'a:normAutofit');
    final v = int.tryParse(fit?.getAttribute('fontScale') ?? '');
    return v == null ? 1 : v / 100000.0;
  }

  // ---------------------------------------------------------------- metin

  List<ParaVM> _paragraphs(
    XmlElement txBody,
    Map<String, Color> theme,
    Map<String, String> clrMap,
    Map<String, _TextDefaults> defaults,
    _Ph? ph,
    bool editable,
  ) {
    final isTitle = ph != null &&
        (ph.type == 'title' || ph.type == 'ctrTitle');
    final def = isTitle ? defaults['title']! : defaults['body']!;
    final wantsBullet = ph != null &&
        (ph.type == 'body' || ph.type == 'subTitle' || ph.type == null);

    final out = <ParaVM>[];
    var autoNum = 0;
    for (final p in txBody.findElements('a:p')) {
      final pPr = _first(p, 'a:pPr');
      final lvl = int.tryParse(pPr?.getAttribute('lvl') ?? '') ?? 0;

      final runs = <RunVM>[];
      for (final r in p.childElements) {
        if (r.name.qualified == 'a:br') {
          runs.add(const RunVM(text: '\n'));
          continue;
        }
        if (r.name.qualified != 'a:r' && r.name.qualified != 'a:fld') continue;
        final t = _first(r, 'a:t');
        if (t == null) continue;
        final rPr = _first(r, 'a:rPr');
        final size = double.tryParse(rPr?.getAttribute('sz') ?? '');
        final defRPr = pPr == null ? null : _first(pPr, 'a:defRPr');
        final defSize = double.tryParse(defRPr?.getAttribute('sz') ?? '');
        runs.add(RunVM(
          text: t.innerText,
          sizePt: (size ?? defSize ?? def.size * 100) / 100,
          bold: (rPr?.getAttribute('b') ?? (def.bold ? '1' : '0')) == '1',
          italic: rPr?.getAttribute('i') == '1',
          underline: (rPr?.getAttribute('u') ?? 'none') != 'none',
          color: (rPr == null ? null : _solidFill(rPr, theme, clrMap)) ??
              (defRPr == null ? null : _solidFill(defRPr, theme, clrMap)) ??
              def.color,
        ));
      }
      if (runs.isEmpty) {
        out.add(ParaVM(runs: const [], source: editable ? p : null));
        continue;
      }

      var bullet = '';
      if (pPr == null || _first(pPr, 'a:buNone') == null) {
        final buChar = _first(pPr, 'a:buChar')?.getAttribute('char');
        if (buChar != null) {
          bullet = buChar;
        } else if (pPr != null && _first(pPr, 'a:buAutoNum') != null) {
          bullet = '${++autoNum}.';
        } else if (wantsBullet) {
          bullet = '•';
        }
      }

      final lnSpc = _first(_first(pPr, 'a:lnSpc'), 'a:spcPct')?.getAttribute('val');
      final spcBef = _first(_first(pPr, 'a:spcBef'), 'a:spcPts')?.getAttribute('val');

      out.add(ParaVM(
        runs: runs,
        align: _align(pPr?.getAttribute('algn')),
        indentPt: (_pt(pPr?.getAttribute('marL')) ?? lvl * 28.8),
        bullet: bullet,
        lineHeight: lnSpc == null
            ? 1.2
            : ((double.tryParse(lnSpc) ?? 100000) / 100000).clamp(0.5, 3.0),
        spaceBeforePt: spcBef == null ? 0 : (double.tryParse(spcBef) ?? 0) / 100,
        source: editable ? p : null,
      ));
    }
    return out;
  }

  TextAlign _align(String? algn) {
    switch (algn) {
      case 'ctr':
        return TextAlign.center;
      case 'r':
        return TextAlign.right;
      case 'just':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  Map<String, _TextDefaults> _textDefaults(
    XmlDocument? master,
    Map<String, Color> theme,
    Map<String, String> clrMap,
  ) {
    _TextDefaults read(String style, double fallbackSize, bool bold) {
      final lvl1 = _first(
        _first(_first(master?.rootElement, 'p:txStyles'), style),
        'a:lvl1pPr',
      );
      final defRPr = lvl1 == null ? null : _first(lvl1, 'a:defRPr');
      final sz = double.tryParse(defRPr?.getAttribute('sz') ?? '');
      return _TextDefaults(
        sz == null ? fallbackSize : sz / 100,
        (defRPr == null ? null : _solidFill(defRPr, theme, clrMap)) ??
            const Color(0xFF000000),
        defRPr?.getAttribute('b') == '1' || bold,
      );
    }

    return {
      'title': read('p:titleStyle', 44, false),
      'body': read('p:bodyStyle', 18, false),
    };
  }

  // ---------------------------------------------------------------- renk

  Color? _solidFill(
      XmlElement parent, Map<String, Color> theme, Map<String, String> clrMap) {
    final fill = _first(parent, 'a:solidFill');
    if (fill == null) return null;
    return _colorOf(fill, theme, clrMap);
  }

  Color? _colorOf(
      XmlElement holder, Map<String, Color> theme, Map<String, String> clrMap) {
    XmlElement? node = _first(holder, 'a:srgbClr');
    Color? base;
    if (node != null) {
      base = _hex(node.getAttribute('val'));
    } else {
      node = _first(holder, 'a:schemeClr');
      if (node != null) {
        final key = node.getAttribute('val') ?? '';
        base = theme[clrMap[key] ?? key];
      } else {
        node = _first(holder, 'a:sysClr');
        if (node != null) base = _hex(node.getAttribute('lastClr'));
      }
    }
    if (base == null || node == null) return base;

    // lumMod/lumOff/shade/tint → HSL parlaklığı üzerinden yaklaşık uygulanır.
    double? pct(String name) {
      final v = _first(node!, name)?.getAttribute('val');
      final n = double.tryParse(v ?? '');
      return n == null ? null : n / 100000;
    }

    final hsl = HSLColor.fromColor(base);
    var l = hsl.lightness;
    final lumMod = pct('a:lumMod');
    final lumOff = pct('a:lumOff');
    final shade = pct('a:shade');
    final tint = pct('a:tint');
    if (lumMod != null) l *= lumMod;
    if (lumOff != null) l += lumOff;
    if (shade != null) l *= shade;
    if (tint != null) l = l * tint + (1 - tint);
    final alpha = pct('a:alpha');
    final out = hsl.withLightness(l.clamp(0.0, 1.0)).toColor();
    return alpha == null ? out : out.withOpacity(alpha.clamp(0.0, 1.0));
  }

  Color? _bgColor(
      XmlElement bg, Map<String, Color> theme, Map<String, String> clrMap) {
    final pr = _first(bg, 'p:bgPr');
    if (pr != null) return _solidFill(pr, theme, clrMap);
    final ref = _first(bg, 'p:bgRef');
    return ref == null ? null : _colorOf(ref, theme, clrMap);
  }

  Uint8List? _bgImage(XmlElement bg, String file) {
    final blip = _firstDeep(bg, 'a:blip');
    final rid = blip?.getAttribute('r:embed');
    if (rid == null) return null;
    final target = _rels(file)[rid];
    return target == null ? null : _imageBytes(target);
  }

  Map<String, String> _clrMap(XmlDocument? master) {
    final el = master == null ? null : _first(master.rootElement, 'p:clrMap');
    final out = <String, String>{
      'bg1': 'lt1',
      'tx1': 'dk1',
      'bg2': 'lt2',
      'tx2': 'dk2',
    };
    if (el != null) {
      for (final a in el.attributes) {
        out[a.name.qualified] = a.value;
      }
    }
    return out;
  }

  Map<String, Color> _themeOf(String? masterFile) {
    if (masterFile == null) return const {};
    final cached = _themeCache[masterFile];
    if (cached != null) return cached;
    final themeFile = _relOfType(_rels(masterFile), 'theme');
    final doc = themeFile == null ? null : _xml(themeFile);
    final scheme = doc == null
        ? null
        : _firstDeep(doc.rootElement, 'a:clrScheme');
    final out = <String, Color>{};
    if (scheme != null) {
      for (final el in scheme.childElements) {
        final name = el.name.local;
        final srgb = _first(el, 'a:srgbClr')?.getAttribute('val');
        final sys = _first(el, 'a:sysClr')?.getAttribute('lastClr');
        final c = _hex(srgb ?? sys);
        if (c != null) out[name] = c;
      }
    }
    _themeCache[masterFile] = out;
    return out;
  }

  // --------------------------------------------------------------- arşiv

  Uint8List? _imageBytes(String path) {
    final lower = path.toLowerCase();
    if (!(lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.webp'))) {
      return null; // Flutter emf/wmf/tiff çözemez
    }
    final data = _bytes(path);
    return data == null ? null : Uint8List.fromList(data);
  }

  List<int>? _bytes(String name) {
    for (final f in _archive.files) {
      if (f.name == name) return f.content as List<int>;
    }
    return null;
  }

  XmlDocument? _xml(String name) {
    if (_xmlCache.containsKey(name)) return _xmlCache[name];
    final data = _bytes(name);
    XmlDocument? doc;
    if (data != null) {
      try {
        doc = XmlDocument.parse(utf8.decode(data, allowMalformed: true));
      } catch (_) {
        doc = null;
      }
    }
    _xmlCache[name] = doc;
    return doc;
  }

  /// `<file>` için ilişki tablosu: rId -> hedef dosyanın arşiv içindeki tam yolu.
  Map<String, String> _rels(String file) {
    final cached = _relsCache[file];
    if (cached != null) return cached;
    final dir = _dir(file);
    final relsPath = '${dir}_rels/${file.substring(dir.length)}.rels';
    final doc = _xml(relsPath);
    final out = <String, String>{};
    if (doc != null) {
      for (final r in doc.rootElement.childElements) {
        final id = r.getAttribute('Id');
        final target = r.getAttribute('Target');
        final type = r.getAttribute('Type') ?? '';
        if (id == null || target == null) continue;
        if (target.startsWith('http')) continue;
        out[id] = _resolve(dir, target);
        out['type:$id'] = type.split('/').last;
      }
    }
    _relsCache[file] = out;
    return out;
  }

  String? _relOfType(Map<String, String> rels, String type) {
    for (final e in rels.entries) {
      if (e.key.startsWith('type:') && e.value == type) {
        return rels[e.key.substring(5)];
      }
    }
    return null;
  }
}

// ------------------------------------------------------------ yer tutucu

class _Ph {
  final String? type;
  final String? idx;
  const _Ph(this.type, this.idx);
}

_Ph? _placeholder(XmlElement shape) {
  final nv = _first(shape, 'p:nvSpPr') ?? _first(shape, 'p:nvPicPr');
  final ph = _first(_first(nv, 'p:nvPr'), 'p:ph');
  if (ph == null) return null;
  return _Ph(ph.getAttribute('type'), ph.getAttribute('idx'));
}

XmlElement? _findPlaceholder(XmlDocument doc, _Ph want) {
  XmlElement? byIdx;
  XmlElement? byType;
  for (final sp in doc.findAllElements('p:sp')) {
    final ph = _placeholder(sp);
    if (ph == null) continue;
    if (want.idx != null && ph.idx == want.idx) byIdx ??= sp;
    if (want.type != null && ph.type == want.type) byType ??= sp;
    if (want.type == null && want.idx == null && ph.type == 'body') {
      byType ??= sp;
    }
  }
  return byIdx ?? byType;
}

// ---------------------------------------------------------------- yardımcı

XmlElement? _first(XmlElement? parent, String name) {
  if (parent == null) return null;
  for (final e in parent.childElements) {
    if (e.name.qualified == name) return e;
  }
  return null;
}

XmlElement? _firstDeep(XmlElement? parent, String name) {
  if (parent == null) return null;
  for (final e in parent.descendantElements) {
    if (e.name.qualified == name) return e;
  }
  return null;
}

double? _pt(String? emu) {
  final v = double.tryParse(emu ?? '');
  return v == null ? null : v / _emuPerPt;
}

Color? _hex(String? v) {
  if (v == null || v.length != 6) return null;
  final n = int.tryParse(v, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

String _dir(String path) {
  final i = path.lastIndexOf('/');
  return i == -1 ? '' : path.substring(0, i + 1);
}

String _resolve(String dir, String target) {
  if (target.startsWith('/')) return target.substring(1);
  final parts = <String>[];
  for (final seg in '$dir$target'.split('/')) {
    if (seg == '.' || seg.isEmpty) continue;
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(seg);
  }
  return parts.join('/');
}
