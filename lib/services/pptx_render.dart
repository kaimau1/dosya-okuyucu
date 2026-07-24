import 'dart:convert';
import 'dart:math' as math;
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
// Kapsam: düz renk + gradient dolgu, görsel, tablo (a:tbl), metin (Calibri/
// Arial/Times metrik-uyumlu gömülü fontlarla), bağlayıcı/çizgi, gölge, grafik.
// ponytail: SmartArt ve animasyon efekt türleri hâlâ kapsam dışı.

const double _emuPerPt = 12700;

class SlideVM {
  final double widthPt;
  final double heightPt;
  final Color? background;

  /// Slayt arka planı gradient dolgu ise (düz renk yerine). Varsa çizimde
  /// [background]'ın yerine kullanılır.
  final Gradient? backgroundGradient;
  final Uint8List? backgroundImage;
  final List<ShapeVM> shapes;

  /// Tıklama adımları (`p:timing`): her adım o tıklamada beliren hedeflerin listesi.
  /// Boşsa slaytta animasyon yoktur, her şey baştan görünür.
  final List<List<AnimTarget>> steps;

  const SlideVM({
    required this.widthPt,
    required this.heightPt,
    required this.shapes,
    this.background,
    this.backgroundGradient,
    this.backgroundImage,
    this.steps = const [],
  });

  /// Verilen şekil/paragraf hangi tıklamada belirir? 0 = baştan görünür.
  int stepFor(int shapeId, int paragraphIndex) {
    for (var i = 0; i < steps.length; i++) {
      for (final t in steps[i]) {
        if (t.shapeId != shapeId) continue;
        if (t.paraFrom == null) return i + 1;
        if (paragraphIndex >= t.paraFrom! && paragraphIndex <= t.paraTo!) {
          return i + 1;
        }
      }
    }
    return 0;
  }
}

/// Bir animasyon adımının hedefi: şekil (ve istenirse paragraf aralığı).
class AnimTarget {
  final int shapeId;
  final int? paraFrom;
  final int? paraTo;
  const AnimTarget(this.shapeId, [this.paraFrom, this.paraTo]);

  @override
  bool operator ==(Object other) =>
      other is AnimTarget &&
      other.shapeId == shapeId &&
      other.paraFrom == paraFrom &&
      other.paraTo == paraTo;

  @override
  int get hashCode => Object.hash(shapeId, paraFrom, paraTo);
}

class ShapeVM {
  /// Slayt içindeki şekil kimliği (`p:cNvPr@id`) — animasyon hedefleri buna bağlanır.
  final int id;
  final double x, y, w, h;
  final double rotationDeg;
  final Color? fill;

  /// Şekil dolgusu gradient ise (düz [fill] yerine). Varsa çizimde öncelikli.
  final Gradient? gradient;
  final Color? stroke;
  final double strokeWidth;
  final bool isEllipse;
  final double cornerRadius;

  /// Şekil bir çizgi/bağlayıcı mı (`p:cxnSp` ya da line/connector geometrisi).
  /// true ise kutu yerine köşe-köşe bir çizgi çizilir (bkz. slide_canvas
  /// `_LinePainter`). Eğik/kavisli bağlayıcılar düz çizgiyle yaklaşıklanır.
  final bool isLine;

  /// Çizgi yönü için ayna bayrakları (`a:xfrm@flipH/flipV`).
  final bool flipH;
  final bool flipV;

  /// Çizgi uçlarında ok var mı (`a:ln` head/tail End type != none).
  final bool arrowStart;
  final bool arrowEnd;

  /// Çizgi kesikli mi (`a:ln > a:prstDash` != solid).
  final bool dashed;

  /// Dış gölge (`a:effectLst > a:outerShdw`) — kutu şekillere uygulanır.
  final BoxShadow? shadow;

  /// Tablo hücresi için kenar-başına (sol/sağ/üst/alt) kenarlık. Tek `stroke`
  /// (tüm kenar) yerine kullanılır: PowerPoint tablo hücreleri yalnız tanımlı
  /// kenarları çizer (`a:tcPr > a:lnL/lnR/lnT/lnB`). null = tekil stroke kuralı.
  final Border? cellBorder;

  /// Şekil bir grafikse (graphicFrame > c:chart) çizilecek grafik modeli.
  final ChartVM? chart;
  final Uint8List? image;
  final List<ParaVM> paragraphs;
  final String vAnchor; // t | ctr | b
  final EdgeInsets inset;
  final double fontScale;

  /// `a:normAutofit` var mı: PowerPoint bu kutuda yazıyı KUTUYA SIĞDIRIR.
  /// Canvas bunu görünce kendi ölçümüyle ek küçültme uygular (font farkını da kapatır).
  final bool autofit;

  /// `a:normAutofit@lnSpcReduction` (0-1): satır aralığı küçültmesi.
  final double lnSpcReduction;

  /// Şekil bir yer tutucu mu (başlık/gövde/altbaşlık)? PowerPoint yer tutucu
  /// metnini varsayılan olarak kutuya sığdırır ("shrink on overflow") ama
  /// autofit ayarı çoğu dosyada slayt yerine ŞABLONDA durur — bu yüzden
  /// canvas yer tutucularda da sığdırma uygular.
  final bool isPlaceholder;

  const ShapeVM({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.id = 0,
    this.rotationDeg = 0,
    this.fill,
    this.gradient,
    this.stroke,
    this.strokeWidth = 0,
    this.isEllipse = false,
    this.cornerRadius = 0,
    this.isLine = false,
    this.flipH = false,
    this.flipV = false,
    this.arrowStart = false,
    this.arrowEnd = false,
    this.dashed = false,
    this.shadow,
    this.cellBorder,
    this.chart,
    this.image,
    this.paragraphs = const [],
    this.vAnchor = 't',
    this.inset = const EdgeInsets.fromLTRB(7.2, 3.6, 7.2, 3.6),
    this.fontScale = 1,
    this.autofit = false,
    this.lnSpcReduction = 0,
    this.isPlaceholder = false,
  });

  bool get hasText => paragraphs.any((p) => p.plainText.isNotEmpty);
}

/// Desteklenen grafik türleri. Bar (yatay çubuk), sütun (dikey çubuk), pasta
/// (halka dahil), çizgi (alan grafiği çizgiyle yaklaşıklanır). Diğerleri
/// (dağılım/radar/borsa) çizilmez.
enum ChartType { bar, column, pie, line }

/// Bir grafik serisi: adı, rengi ve değerleri. Pasta grafikte tek seri olur;
/// dilim renkleri [pointColors] ile (yoksa paletten) verilir.
class ChartSeries {
  final String name;
  final Color color;
  final List<double> values;
  final Map<int, Color> pointColors;
  const ChartSeries({
    required this.name,
    required this.color,
    required this.values,
    this.pointColors = const {},
  });
}

/// Bir grafiği (c:chart) çizilebilir modele indirger. Çizim
/// `widgets/chart_painter.dart` (ChartPainter). Veri, seri renkleri ve
/// kategoriler PowerPoint'teki gibi; 3B/gradient/eksen stili yaklaşıktır.
class ChartVM {
  final ChartType type;
  final bool doughnut;
  final List<String> categories;
  final List<ChartSeries> series;
  final bool showLegend;
  const ChartVM({
    required this.type,
    required this.series,
    this.doughnut = false,
    this.categories = const [],
    this.showLegend = false,
  });
}

class ParaVM {
  final TextAlign align;
  final double indentPt;
  final String bullet;
  final double lineHeight;
  final double spaceBeforePt;

  /// Paragraf sonrası boşluk (`a:spcAft > a:spcPts`, punto). PowerPoint
  /// paragraflar arasına bu boşluğu ekler.
  final double spaceAfterPt;
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
    this.spaceAfterPt = 0,
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

  /// Çizimde kullanılacak gömülü yazı ailesi (Carlito/Arimo/Tinos). null =
  /// varsayılan (Roboto). [PptxRender._mapFamily] typeface'i buna eşler.
  final String? fontFamily;
  const RunVM({
    required this.text,
    this.sizePt = 18,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color = const Color(0xFF000000),
    this.fontFamily,
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
  final Map<String, (String, String)> _fontCache = {};

  /// Geçerli slaytın tema başlık/gövde latin yazı tipi adı (`a:majorFont`/
  /// `a:minorFont`). `slide()` başında ayarlanır; `+mj-lt`/`+mn-lt` referansları
  /// bununla çözülür. Office varsayılanı Calibri.
  String _majorLatin = 'Calibri';
  String _minorLatin = 'Calibri';

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
    final themeFonts = _themeFonts(masterFile);
    _majorLatin = themeFonts.$1;
    _minorLatin = themeFonts.$2;

    Color? bg;
    Gradient? bgGradient;
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
      final pr = _first(bgEl, 'p:bgPr');
      bgGradient ??= pr == null ? null : _gradFill(pr, theme, clrMap);
      bgImage ??= _bgImage(bgEl, file);
      if (bg != null || bgGradient != null || bgImage != null) break;
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
      backgroundGradient: bgGradient,
      backgroundImage: bgImage,
      shapes: shapes,
      steps: _timing(doc),
    );
  }

  /// `p:timing` içindeki ana diziden tıklama adımlarını çıkarır.
  // ponytail: efekt türü/süresi okunmaz — sadece "hangi tıklamada ne belirir".
  // Çıkış (transition="out") animasyonları da giriş sayılır; nadir ve zararsız.
  List<List<AnimTarget>> _timing(XmlDocument doc) {
    final timing = _first(doc.rootElement, 'p:timing');
    if (timing == null) return const [];

    XmlElement? mainSeq;
    for (final el in timing.descendantElements) {
      if (el.name.qualified == 'p:cTn' &&
          el.getAttribute('nodeType') == 'mainSeq') {
        mainSeq = el;
        break;
      }
    }
    final childList = _first(mainSeq, 'p:childTnLst');
    if (childList == null) return const [];

    final steps = <List<AnimTarget>>[];
    for (final par in childList.childElements) {
      if (par.name.qualified != 'p:par') continue;
      final targets = <AnimTarget>[];
      for (final tgt in par.descendantElements) {
        if (tgt.name.qualified != 'p:spTgt') continue;
        final spid = int.tryParse(tgt.getAttribute('spid') ?? '');
        if (spid == null) continue;
        final rg = _firstDeep(tgt, 'p:pRg') ?? _firstDeep(tgt, 'a:pRg');
        final from = int.tryParse(rg?.getAttribute('st') ?? '');
        final to = int.tryParse(rg?.getAttribute('end') ?? '') ?? from;
        final t = from == null
            ? AnimTarget(spid)
            : AnimTarget(spid, from, to);
        if (!targets.contains(t)) targets.add(t);
      }
      if (targets.isNotEmpty) steps.add(targets);
    }
    return steps;
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
        case 'p:cxnSp': // bağlayıcı (çizgi/ok) — çizgi şekli olarak çizilir
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
          _graphicFrame(el, xf, file, out, theme, clrMap, defaults, editable);
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

  /// graphicFrame içeriğine göre dallanır: tablo (a:tbl) → [_table]; grafik
  /// (c:chart) → [_parseChart] + tek grafik ShapeVM. SmartArt/OLE atlanır.
  void _graphicFrame(
    XmlElement frame,
    _Xf xf,
    String file,
    List<ShapeVM> out,
    Map<String, Color> theme,
    Map<String, String> clrMap,
    Map<String, _TextDefaults> defaults,
    bool editable,
  ) {
    if (_firstDeep(frame, 'a:tbl') != null) {
      _table(frame, xf, out, theme, clrMap, defaults, editable);
      return;
    }
    final rid = _firstDeep(frame, 'c:chart')?.getAttribute('r:id');
    if (rid == null) return;
    final target = _rels(file)[rid];
    final chart = target == null ? null : _parseChart(target, theme, clrMap);
    if (chart == null) return;

    final xfrm = _first(frame, 'p:xfrm');
    final off = _first(xfrm, 'a:off');
    final ext = _first(xfrm, 'a:ext');
    if (off == null || ext == null) return;
    final w = (_pt(ext.getAttribute('cx')) ?? 0) * xf.sx;
    final h = (_pt(ext.getAttribute('cy')) ?? 0) * xf.sy;
    if (w <= 0 || h <= 0) return;
    out.add(ShapeVM(
      x: xf.px(_pt(off.getAttribute('x')) ?? 0),
      y: xf.py(_pt(off.getAttribute('y')) ?? 0),
      w: w,
      h: h,
      chart: chart,
    ));
  }

  /// Tabloyu (a:tbl) hücre başına bir dikdörtgen şekle açar — çizim katmanı
  /// böylece tablo için ayrı koda ihtiyaç duymaz.
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
    final frameId = int.tryParse(
            _first(_first(frame, 'p:nvGraphicFramePr'), 'p:cNvPr')
                    ?.getAttribute('id') ??
                '') ??
        0;

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
          // Kenar başına (sol/sağ/üst/alt) kenarlık: PowerPoint yalnız tanımlı
          // kenarları çizer; eskiden yalnız lnB/lnT okunup tüm kenara uygulanıyordu.
          BorderSide side(String name) {
            final l = tcPr == null ? null : _first(tcPr, name);
            if (l == null || _first(l, 'a:noFill') != null) return BorderSide.none;
            final c = _solidFill(l, theme, clrMap);
            if (c == null) return BorderSide.none;
            final bw = _pt(l.getAttribute('w')) ?? 1;
            return BorderSide(color: c, width: bw <= 0 ? 1 : bw);
          }

          out.add(ShapeVM(
            id: frameId,
            x: x,
            y: y,
            w: w,
            h: rowH,
            fill: tcPr == null ? null : _solidFill(tcPr, theme, clrMap),
            cellBorder: Border(
              left: side('a:lnL'),
              right: side('a:lnR'),
              top: side('a:lnT'),
              bottom: side('a:lnB'),
            ),
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

    final prst = _first(spPr, 'a:prstGeom')?.getAttribute('prst') ?? 'rect';
    final isLine = el.name.qualified == 'p:cxnSp' ||
        prst == 'line' ||
        prst == 'straightConnector1' ||
        prst.startsWith('bentConnector') ||
        prst.startsWith('curvedConnector');
    // Çizginin tek boyutu 0 olabilir (yatay/dikey bağlayıcı); düz şekilde 0 = atla.
    if (w < 0 || h < 0) return null;
    if (isLine ? (w == 0 && h == 0) : (w <= 0 || h <= 0)) return null;

    final rot = (int.tryParse(xfrm.getAttribute('rot') ?? '') ?? 0) / 60000.0;
    final flipH = xfrm.getAttribute('flipH') == '1';
    final flipV = xfrm.getAttribute('flipV') == '1';
    final nv = _first(el, 'p:nvSpPr') ??
        _first(el, 'p:nvPicPr') ??
        _first(el, 'p:nvCxnSpPr');
    final id = int.tryParse(_first(nv, 'p:cNvPr')?.getAttribute('id') ?? '') ?? 0;

    final isEllipse = prst == 'ellipse' || prst == 'chord' || prst == 'pie';

    // Modern PPTX'te tema temelli şekiller dolgu/çizgiyi `spPr`'de DEĞİL,
    // `p:style`'daki stil matrisi referanslarında taşır (`a:fillRef`/`a:lnRef`
    // içindeki schemeClr). Bunlar okunmadığında şekil boş/şeffaf çiziliyordu —
    // en büyük tekil sadakat kaybı. idx="0" = tema arka planı (dolgusuz) → atla.
    final style = _first(el, 'p:style');

    Color? fill;
    Gradient? gradient;
    if (!isLine && spPr != null && _first(spPr, 'a:noFill') == null) {
      fill = _solidFill(spPr, theme, clrMap);
      gradient = _gradFill(spPr, theme, clrMap);
      if (fill == null && gradient == null) {
        final fillRef = style == null ? null : _first(style, 'a:fillRef');
        if (fillRef != null && (fillRef.getAttribute('idx') ?? '0') != '0') {
          fill = _colorOf(fillRef, theme, clrMap);
          gradient = _gradFill(fillRef, theme, clrMap);
        }
      }
    }

    Color? stroke;
    double strokeW = 0;
    var arrowStart = false, arrowEnd = false, dashed = false;
    final ln = spPr == null ? null : _first(spPr, 'a:ln');
    if (ln != null && _first(ln, 'a:noFill') == null) {
      stroke = _solidFill(ln, theme, clrMap);
      strokeW = (_pt(ln.getAttribute('w')) ?? 1);
      if (stroke != null && strokeW <= 0) strokeW = 1;
      final head = _first(ln, 'a:headEnd')?.getAttribute('type');
      final tail = _first(ln, 'a:tailEnd')?.getAttribute('type');
      arrowStart = head != null && head != 'none';
      arrowEnd = tail != null && tail != 'none';
      final dash = _first(ln, 'a:prstDash')?.getAttribute('val');
      dashed = dash != null && dash != 'solid';
    }
    // spPr'de çizgi yoksa tema stil referansına düş (p:style > a:lnRef). Gerçek
    // çizgi kalınlığı tema lnStyleLst'te; onu çözmeden tema minör çizgisi ~0.75pt
    // varsayılır (görünür ince kenarlık, PowerPoint bu şekilleri kenarlıkla çizer).
    if (stroke == null && !isLine) {
      final lnRef = style == null ? null : _first(style, 'a:lnRef');
      if (lnRef != null && (lnRef.getAttribute('idx') ?? '0') != '0') {
        stroke = _colorOf(lnRef, theme, clrMap);
        if (stroke != null) strokeW = 0.75;
      }
    }
    if (isLine) {
      stroke ??= const Color(0xFF595959); // PP varsayılan bağlayıcı ~ koyu gri
      if (strokeW <= 0) strokeW = 1;
    }

    final shadow = _outerShadow(
        spPr == null ? null : _first(spPr, 'a:effectLst'), theme, clrMap);

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
      id: id,
      x: x,
      y: y,
      w: w,
      h: h,
      rotationDeg: rot,
      fill: fill,
      gradient: gradient,
      stroke: stroke,
      strokeWidth: strokeW,
      isEllipse: isEllipse,
      cornerRadius: prst == 'roundRect' ? (w < h ? w : h) * 0.12 : 0,
      isLine: isLine,
      flipH: flipH,
      flipV: flipV,
      arrowStart: arrowStart,
      arrowEnd: arrowEnd,
      dashed: dashed,
      shadow: shadow,
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
      autofit: bodyPr != null && _first(bodyPr, 'a:normAutofit') != null,
      lnSpcReduction: _lnSpcReduction(bodyPr),
      isPlaceholder: ph != null,
    );
  }

  double _fontScale(XmlElement? bodyPr) {
    final fit = bodyPr == null ? null : _first(bodyPr, 'a:normAutofit');
    final v = int.tryParse(fit?.getAttribute('fontScale') ?? '');
    return v == null ? 1 : v / 100000.0;
  }

  double _lnSpcReduction(XmlElement? bodyPr) {
    final fit = bodyPr == null ? null : _first(bodyPr, 'a:normAutofit');
    final v = int.tryParse(fit?.getAttribute('lnSpcReduction') ?? '');
    return v == null ? 0 : (v / 100000.0).clamp(0.0, 0.5);
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
          fontFamily: _resolveFont(rPr, defRPr, isTitle),
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

      final lnSpcPct =
          _first(_first(pPr, 'a:lnSpc'), 'a:spcPct')?.getAttribute('val');
      final lnSpcPts =
          _first(_first(pPr, 'a:lnSpc'), 'a:spcPts')?.getAttribute('val');
      final spcBef = _first(_first(pPr, 'a:spcBef'), 'a:spcPts')?.getAttribute('val');
      final spcAft = _first(_first(pPr, 'a:spcAft'), 'a:spcPts')?.getAttribute('val');

      // Satır aralığı: yüzde (spcPct) doğrudan çarpan; mutlak punto (spcPts) ise
      // font boyutuna bölünüp çarpana çevrilir (Flutter `height` çarpan ister).
      double lineHeight;
      if (lnSpcPct != null) {
        lineHeight = ((double.tryParse(lnSpcPct) ?? 100000) / 100000).clamp(0.5, 3.0);
      } else if (lnSpcPts != null) {
        final ptsHeight = (double.tryParse(lnSpcPts) ?? 0) / 100;
        final refSize = runs.first.sizePt;
        lineHeight = refSize > 0 ? (ptsHeight / refSize).clamp(0.5, 3.0) : 1.2;
      } else {
        lineHeight = 1.2;
      }

      out.add(ParaVM(
        runs: runs,
        align: _align(pPr?.getAttribute('algn')),
        indentPt: (_pt(pPr?.getAttribute('marL')) ?? lvl * 28.8),
        bullet: bullet,
        lineHeight: lineHeight,
        spaceBeforePt: spcBef == null ? 0 : (double.tryParse(spcBef) ?? 0) / 100,
        spaceAfterPt: spcAft == null ? 0 : (double.tryParse(spcAft) ?? 0) / 100,
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

  /// `a:gradFill` → Flutter [Gradient]. Doğrusal (`a:lin`, açı 60000'de bir
  /// derece) veya radyal (`a:path`) desteklenir. En az iki durak gerekir;
  /// yoksa null (düz dolguya düşülür).
  // ponytail: açı yaklaşık uygulanır (ekran y-ekseni aşağı → PowerPoint saat yönü
  // ile uyumlu); durak konumları pos/100000. Renk lumMod/tint _colorOf ile.
  Gradient? _gradFill(
      XmlElement parent, Map<String, Color> theme, Map<String, String> clrMap) {
    final grad = _first(parent, 'a:gradFill');
    if (grad == null) return null;
    final gsLst = _first(grad, 'a:gsLst');
    if (gsLst == null) return null;

    final entries = <(double, Color)>[];
    for (final gs in gsLst.childElements) {
      if (gs.name.qualified != 'a:gs') continue;
      final pos = (double.tryParse(gs.getAttribute('pos') ?? '') ?? 0) / 100000.0;
      final c = _colorOf(gs, theme, clrMap);
      if (c != null) entries.add((pos.clamp(0.0, 1.0), c));
    }
    if (entries.length < 2) return null;
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    final stops = [for (final e in entries) e.$1];
    final colors = [for (final e in entries) e.$2];

    // Radyal (path="circle"/"rect"/"shape") → merkezden dışa.
    if (_first(grad, 'a:path') != null) {
      return RadialGradient(colors: colors, stops: stops, radius: 0.75);
    }

    // Doğrusal: açıyı yön vektörüne çevir (y aşağı pozitif → saat yönü).
    final lin = _first(grad, 'a:lin');
    final ang = (double.tryParse(lin?.getAttribute('ang') ?? '') ?? 0) / 60000.0;
    final rad = ang * math.pi / 180.0;
    final dx = math.cos(rad);
    final dy = math.sin(rad);
    return LinearGradient(
      begin: Alignment(-dx, -dy),
      end: Alignment(dx, dy),
      colors: colors,
      stops: stops,
    );
  }

  /// Testler için: bir `a:gradFill` içeren XML parçasını gradient'e çevirir.
  static Gradient? debugParseGradient(String xmlFragment) {
    final doc = XmlDocument.parse(xmlFragment);
    final render = PptxRender(Archive());
    return render._gradFill(doc.rootElement, const {}, const {});
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

  /// `a:effectLst > a:outerShdw` → Flutter [BoxShadow]. Yön (`dir`, 60000'de bir
  /// derece; ekran y aşağı → saat yönü) ve uzaklık (`dist`, EMU) ofsete çevrilir.
  BoxShadow? _outerShadow(XmlElement? effectLst, Map<String, Color> theme,
      Map<String, String> clrMap) {
    final shdw = effectLst == null ? null : _first(effectLst, 'a:outerShdw');
    if (shdw == null) return null;
    final color = _colorOf(shdw, theme, clrMap) ?? const Color(0x66000000);
    final blur = _pt(shdw.getAttribute('blurRad')) ?? 0;
    final dist = _pt(shdw.getAttribute('dist')) ?? 0;
    final dir = (double.tryParse(shdw.getAttribute('dir') ?? '') ?? 0) / 60000.0;
    final rad = dir * math.pi / 180.0;
    return BoxShadow(
      color: color,
      blurRadius: blur,
      offset: Offset(dist * math.cos(rad), dist * math.sin(rad)),
    );
  }

  // --------------------------------------------------------------- grafik

  /// Bir grafik XML parçasını ([chartFile]) [ChartVM]'e çevirir. Desteklenen
  /// tür yoksa null. Seri renkleri açık `c:spPr` yoksa tema aksan paletinden.
  ChartVM? _parseChart(String chartFile, Map<String, Color> theme,
      Map<String, String> clrMap) {
    final doc = _xml(chartFile);
    final root = doc == null ? null : _firstDeep(doc.rootElement, 'c:chart');
    final plotArea = root == null ? null : _first(root, 'c:plotArea');
    if (plotArea == null) return null;

    ChartType? type;
    var doughnut = false;
    XmlElement? chartEl;
    for (final child in plotArea.childElements) {
      switch (child.name.qualified) {
        case 'c:barChart':
          type = (_first(child, 'c:barDir')?.getAttribute('val') ?? 'col') ==
                  'bar'
              ? ChartType.bar
              : ChartType.column;
          break;
        case 'c:pieChart':
          type = ChartType.pie;
          break;
        case 'c:doughnutChart':
          type = ChartType.pie;
          doughnut = true;
          break;
        case 'c:lineChart':
        case 'c:areaChart': // alan → çizgiyle yaklaşıklanır
          type = ChartType.line;
          break;
        default:
          continue;
      }
      chartEl = child;
      break;
    }
    if (chartEl == null || type == null) return null;

    final palette = _chartPalette(theme);
    final serEls = chartEl.findElements('c:ser').toList();
    final series = <ChartSeries>[];
    var categories = const <String>[];
    for (var i = 0; i < serEls.length; i++) {
      final ser = serEls[i];
      final name =
          _firstDeep(_first(ser, 'c:tx'), 'c:v')?.innerText ?? 'Seri ${i + 1}';
      final spPr = _first(ser, 'c:spPr');
      final color = (spPr == null ? null : _solidFill(spPr, theme, clrMap)) ??
          palette[i % palette.length];
      final ptColors = <int, Color>{};
      for (final dPt in ser.findElements('c:dPt')) {
        final idx = int.tryParse(_first(dPt, 'c:idx')?.getAttribute('val') ?? '');
        final sp = _first(dPt, 'c:spPr');
        final c = sp == null ? null : _solidFill(sp, theme, clrMap);
        if (idx != null && c != null) ptColors[idx] = c;
      }
      if (categories.isEmpty) categories = _strValues(_first(ser, 'c:cat'));
      series.add(ChartSeries(
        name: name,
        color: color,
        values: _numValues(_first(ser, 'c:val')),
        pointColors: ptColors,
      ));
    }
    if (series.isEmpty || series.every((s) => s.values.isEmpty)) return null;

    // Pasta: her dilim ayrı renk — açık dPt yoksa paletten doldur.
    if (type == ChartType.pie && series.isNotEmpty) {
      final s = series.first;
      final filled = <int, Color>{
        for (var i = 0; i < s.values.length; i++)
          i: s.pointColors[i] ?? palette[i % palette.length],
      };
      series[0] = ChartSeries(
          name: s.name, color: s.color, values: s.values, pointColors: filled);
    }

    return ChartVM(
      type: type,
      doughnut: doughnut,
      categories: categories,
      series: series,
      showLegend: _firstDeep(root, 'c:legend') != null,
    );
  }

  /// Grafik renk paleti: tema accent1..6 (yoksa Office varsayılan aksanları).
  List<Color> _chartPalette(Map<String, Color> theme) {
    final accents = [
      for (var i = 1; i <= 6; i++)
        if (theme['accent$i'] != null) theme['accent$i']!,
    ];
    if (accents.isNotEmpty) return accents;
    return const [
      Color(0xFF4472C4),
      Color(0xFFED7D31),
      Color(0xFFA5A5A5),
      Color(0xFFFFC000),
      Color(0xFF5B9BD5),
      Color(0xFF70AD47),
    ];
  }

  /// `c:numRef/c:numCache` (veya `c:numLit`) sayısal noktalarını idx sırasıyla
  /// listeye çevirir (eksik idx = 0).
  List<double> _numValues(XmlElement? ref) {
    final cache = _firstDeep(ref, 'c:numCache') ?? _firstDeep(ref, 'c:numLit');
    if (cache == null) return const [];
    final map = <int, double>{};
    var maxIdx = -1;
    for (final pt in cache.findElements('c:pt')) {
      final idx = int.tryParse(pt.getAttribute('idx') ?? '') ?? 0;
      final v = double.tryParse(_first(pt, 'c:v')?.innerText ?? '');
      if (v != null) {
        map[idx] = v;
        if (idx > maxIdx) maxIdx = idx;
      }
    }
    return [for (var i = 0; i <= maxIdx; i++) map[i] ?? 0];
  }

  /// Kategori etiketleri (`c:cat` → strCache/numCache), idx sırasıyla.
  List<String> _strValues(XmlElement? ref) {
    final cache = _firstDeep(ref, 'c:strCache') ??
        _firstDeep(ref, 'c:numCache') ??
        _firstDeep(ref, 'c:strLit');
    if (cache == null) return const [];
    final map = <int, String>{};
    var maxIdx = -1;
    for (final pt in cache.findElements('c:pt')) {
      final idx = int.tryParse(pt.getAttribute('idx') ?? '') ?? 0;
      map[idx] = _first(pt, 'c:v')?.innerText ?? '';
      if (idx > maxIdx) maxIdx = idx;
    }
    return [for (var i = 0; i <= maxIdx; i++) map[i] ?? ''];
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

  /// Temanın başlık (major) ve gövde (minor) latin yazı tipi adları.
  (String, String) _themeFonts(String? masterFile) {
    if (masterFile == null) return ('Calibri', 'Calibri');
    final cached = _fontCache[masterFile];
    if (cached != null) return cached;
    final themeFile = _relOfType(_rels(masterFile), 'theme');
    final doc = themeFile == null ? null : _xml(themeFile);
    final scheme =
        doc == null ? null : _firstDeep(doc.rootElement, 'a:fontScheme');
    String latin(String group) {
      final tf = _first(_first(scheme, group), 'a:latin')?.getAttribute('typeface');
      return (tf == null || tf.isEmpty) ? 'Calibri' : tf;
    }

    final res = (latin('a:majorFont'), latin('a:minorFont'));
    _fontCache[masterFile] = res;
    return res;
  }

  /// Bir çalıştırmanın (run) yazı ailesini çözer: rPr → defRPr → tema
  /// (başlık major, gövde minor) sırasıyla `a:latin@typeface`, sonra gömülü
  /// aileye eşlenir. `+mj-lt`/`+mn-lt` tema referansları çözülür.
  String _resolveFont(XmlElement? rPr, XmlElement? defRPr, bool isTitle) {
    var tf = _first(rPr, 'a:latin')?.getAttribute('typeface') ??
        _first(defRPr, 'a:latin')?.getAttribute('typeface') ??
        (isTitle ? '+mj-lt' : '+mn-lt');
    if (tf.startsWith('+mj')) {
      tf = _majorLatin;
    } else if (tf.startsWith('+mn')) {
      tf = _minorLatin;
    }
    return _mapFamily(tf);
  }

  /// PowerPoint yazı tipi adını gömülü metrik-uyumlu aileye eşler. Bilinen
  /// serif → Tinos, Arial/Helvetica → Arimo, kalanı (Calibri + her sans) →
  /// Carlito. (bkz. assets/fonts/FONTS-NOTICE.txt)
  String _mapFamily(String name) {
    final n = name.toLowerCase();
    if (n.contains('times') ||
        n.contains('georgia') ||
        n.contains('cambria') ||
        n.contains('garamond') ||
        n.contains('minion') ||
        n.contains('palatino') ||
        n.contains('constantia') ||
        n.contains('book antiqua') ||
        n.contains('serif')) {
      return 'Tinos';
    }
    if (n.contains('arial') ||
        n.contains('helvetica') ||
        n.contains('liberation sans')) {
      return 'Arimo';
    }
    return 'Carlito';
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
