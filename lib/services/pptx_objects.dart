part of 'pptx_editor.dart';

/// Faz 29 — slayt nesneleri: çerçeve (taşı/boyutlandır/döndür), metin kutusu
/// ve şekil ekleme, tablo, dolgu, çizgi, saydamlık, arka plan, geçiş, slaytı
/// gizle, düzenden yeni slayt, sürükle-bırak sıralama.
/// Hepsi XML'e doğrudan yazar; geri al, deste anlık görüntüsüyle (`snapshot`)
/// ekranda yapılır.

const _emuPt = 12700;

/// Eklenebilir ön tanımlı şekiller (`a:prstGeom@prst`).
const kPptxShapeKinds = [
  'rect', 'roundRect', 'ellipse', 'triangle', 'rightArrow', 'star5', 'line',
];

/// PowerPoint'in varsayılan tablo stili ("Orta Stil 2 - Vurgu 1"); yerleşik
/// GUID — `tableStyles.xml`te tanımı gerekmez.
const kPptxDefaultTableStyle = '{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}';

/// Slayt geçişi türleri.
enum PptxTransition { none, fade, push, wipe }

/// Düzen galerisi öğesi.
class PptxLayoutInfo {
  final String part; // ppt/slideLayouts/slideLayoutN.xml
  final String name;
  final String type;
  const PptxLayoutInfo(this.part, this.name, this.type);
}

extension PptxObjects on PptxEditor {
  XmlElement? _spTree(PptxSlide s) =>
      PptxEditor._firstOrNull(s.doc.findAllElements('p:spTree'));

  int _nextShapeId(PptxSlide s) {
    var next = 1;
    for (final c in s.doc.findAllElements('p:cNvPr')) {
      final v = int.tryParse(c.getAttribute('id') ?? '') ?? 0;
      if (v >= next) next = v + 1;
    }
    return next;
  }

  /// Şeklin `a:xfrm` düğümü (yoksa yaratır); graphicFrame'de `p:xfrm`.
  XmlElement? _xfrmOf(XmlElement el, {bool create = true}) {
    if (el.name.qualified == 'p:graphicFrame') {
      return PptxEditor._firstOrNull(el.findElements('p:xfrm'));
    }
    final spPr = PptxEditor._firstOrNull(el.findElements('p:spPr'));
    if (spPr == null) return null;
    var x = PptxEditor._firstOrNull(spPr.findElements('a:xfrm'));
    if (x == null && create) {
      x = XmlElement(XmlName.fromString('a:xfrm'), const [], [
        XmlElement(XmlName.fromString('a:off'), [
          XmlAttribute(XmlName.fromString('x'), '0'),
          XmlAttribute(XmlName.fromString('y'), '0')
        ]),
        XmlElement(XmlName.fromString('a:ext'), [
          XmlAttribute(XmlName.fromString('cx'), '0'),
          XmlAttribute(XmlName.fromString('cy'), '0')
        ]),
      ]);
      spPr.children.insert(0, x);
    }
    return x;
  }

  /// Şeklin çerçevesini (pt) ve dönüşünü (derece) yazar. Yalnız slayt
  /// ağacındaki (grup dışı) şekillerde; yapılamazsa false.
  bool setShapeFrame(PptxSlide slide, ShapeVM shape,
      {required double x,
      required double y,
      required double w,
      required double h,
      double? rotationDeg}) {
    final el = shape.element;
    final parent = el?.parent;
    if (el == null || parent is! XmlElement) return false;
    final parentName = parent.name.qualified;
    if (parentName != 'p:spTree' && parentName != 'p:grpSp') return false;
    // Grup içindeki şekil: ekran (slayt) koordinatı grubun çocuk
    // koordinatına çevrilir (Faz 29 kalanı — "grup içi şekli taşıma").
    var local = Rect.fromLTWH(x, y, w, h);
    if (parentName == 'p:grpSp') {
      final mapped = _toGroupSpace(parent, local);
      if (mapped == null) return false;
      local = mapped;
    }
    final xf = _xfrmOf(el);
    if (xf == null) return false;
    final off = PptxEditor._firstOrNull(xf.findElements('a:off'));
    final ext = PptxEditor._firstOrNull(xf.findElements('a:ext'));
    if (off == null || ext == null) return false;
    // Tablo: sütun genişlikleri ve satır yükseklikleri oranla ölçeklenir
    // (PowerPoint'te çerçeveyi çekmek de böyle yapar).
    final tbl = el.name.qualified == 'p:graphicFrame'
        ? PptxEditor._firstOrNull(el.findAllElements('a:tbl'))
        : null;
    if (tbl != null) {
      final oldW = double.tryParse(ext.getAttribute('cx') ?? '') ?? 0;
      final oldH = double.tryParse(ext.getAttribute('cy') ?? '') ?? 0;
      var gridW = 0.0, rowsH = 0.0;
      for (final c in tbl.findAllElements('a:gridCol')) {
        gridW += double.tryParse(c.getAttribute('w') ?? '') ?? 0;
      }
      for (final r in tbl.findElements('a:tr')) {
        rowsH += double.tryParse(r.getAttribute('h') ?? '') ?? 0;
      }
      final baseW = gridW > 0 ? gridW : oldW;
      final baseH = rowsH > 0 ? rowsH : oldH;
      final sx = baseW > 0 ? local.width * _emuPt / baseW : 1.0;
      final sy = baseH > 0 ? local.height * _emuPt / baseH : 1.0;
      for (final c in tbl.findAllElements('a:gridCol')) {
        final v = double.tryParse(c.getAttribute('w') ?? '') ?? 0;
        c.setAttribute('w', '${(v * sx).round()}');
      }
      for (final r in tbl.findElements('a:tr')) {
        final v = double.tryParse(r.getAttribute('h') ?? '') ?? 0;
        r.setAttribute('h', '${(v * sy).round()}');
      }
      rotationDeg = null; // tablo döndürülemez
    }
    off.setAttribute('x', '${(local.left * _emuPt).round()}');
    off.setAttribute('y', '${(local.top * _emuPt).round()}');
    ext.setAttribute('cx', '${(math.max(local.width, 0) * _emuPt).round()}');
    ext.setAttribute('cy', '${(math.max(local.height, 0) * _emuPt).round()}');
    if (rotationDeg != null) {
      final r = ((rotationDeg % 360) + 360) % 360;
      if (r == 0) {
        xf.removeAttribute('rot');
      } else {
        xf.setAttribute('rot', '${(r * 60000).round()}');
      }
    }
    _rerender(slide);
    return true;
  }

  /// Slayt (punto) dikdörtgenini [group]un çocuk koordinatına çevirir; iç içe
  /// gruplarda dıştan içe. Döndürülmüş grupta null (ters dönüşüm kesin değil).
  Rect? _toGroupSpace(XmlElement group, Rect r) {
    final outer = group.parent;
    if (outer is XmlElement && outer.name.qualified == 'p:grpSp') {
      final m = _toGroupSpace(outer, r);
      if (m == null) return null;
      r = m;
    }
    final grpSpPr = PptxEditor._firstOrNull(group.findElements('p:grpSpPr'));
    final xf = grpSpPr == null
        ? null
        : PptxEditor._firstOrNull(grpSpPr.findElements('a:xfrm'));
    if (xf == null) return r;
    final rot = int.tryParse(xf.getAttribute('rot') ?? '0') ?? 0;
    if (rot % 21600000 != 0) return null;
    double v(String tag, String attr) =>
        (double.tryParse(PptxEditor._firstOrNull(xf.findElements(tag))
                    ?.getAttribute(attr) ??
                '') ??
            0) /
        _emuPt;
    final ox = v('a:off', 'x'), oy = v('a:off', 'y');
    final ew = v('a:ext', 'cx'), eh = v('a:ext', 'cy');
    final cx = v('a:chOff', 'x'), cy = v('a:chOff', 'y');
    var cw = v('a:chExt', 'cx'), ch = v('a:chExt', 'cy');
    if (cw <= 0) cw = ew;
    if (ch <= 0) ch = eh;
    final sx = ew > 0 ? cw / ew : 1.0;
    final sy = eh > 0 ? ch / eh : 1.0;
    return Rect.fromLTWH(cx + (r.left - ox) * sx, cy + (r.top - oy) * sy,
        r.width * sx, r.height * sy);
  }

  static const _aNs = 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"';
  static const _pNs = 'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"';

  static String _hex(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');

  static String _escX(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  XmlElement? _addToTree(PptxSlide slide, String xml) {
    final tree = _spTree(slide);
    if (tree == null) return null;
    final el = XmlDocument.parse(xml).rootElement.copy();
    PptxEditor._insertBefore(tree, el, const {'p:extLst'});
    _rerender(slide);
    return el;
  }

  /// Slayda metin kutusu ekler; eklenen düğümü döndürür (seçim için).
  XmlElement? addTextBox(PptxSlide slide, String text,
      {double? x, double? y, double w = 360, double h = 60}) {
    final (sw, sh) = _slideSizeEmu;
    final px = x ?? (sw / _emuPt - w) / 2, py = y ?? (sh / _emuPt - h) / 2;
    final id = _nextShapeId(slide);
    return _addToTree(
        slide,
        '<p:sp $_pNs $_aNs><p:nvSpPr><p:cNvPr id="$id" name="TextBox $id"/>'
        '<p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr>'
        '<a:xfrm><a:off x="${(px * _emuPt).round()}" y="${(py * _emuPt).round()}"/>'
        '<a:ext cx="${(w * _emuPt).round()}" cy="${(h * _emuPt).round()}"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>'
        '<p:txBody><a:bodyPr wrap="square" rtlCol="0"><a:normAutofit/></a:bodyPr><a:lstStyle/>'
        '<a:p><a:r><a:rPr lang="tr-TR" sz="2400"/><a:t>${_escX(text)}</a:t></a:r></a:p>'
        '</p:txBody></p:sp>');
  }

  /// Slayda ön tanımlı şekil ekler (`line` çizgi bağlayıcıdır).
  XmlElement? addShape(PptxSlide slide, String prst,
      {Color fill = const Color.fromARGB(255, 68, 114, 196),
      double? x,
      double? y,
      double w = 200,
      double h = 120}) {
    if (!kPptxShapeKinds.contains(prst)) return null;
    final (sw, sh) = _slideSizeEmu;
    final px = x ?? (sw / _emuPt - w) / 2, py = y ?? (sh / _emuPt - h) / 2;
    final id = _nextShapeId(slide);
    final xfrm = '<a:xfrm><a:off x="${(px * _emuPt).round()}" y="${(py * _emuPt).round()}"/>'
        '<a:ext cx="${(w * _emuPt).round()}" cy="${(prst == 'line' ? 0 : h * _emuPt).round()}"/></a:xfrm>';
    if (prst == 'line') {
      return _addToTree(
          slide,
          '<p:cxnSp $_pNs $_aNs><p:nvCxnSpPr><p:cNvPr id="$id" name="Line $id"/>'
          '<p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr>$xfrm'
          '<a:prstGeom prst="line"><a:avLst/></a:prstGeom>'
          '<a:ln w="28575"><a:solidFill><a:srgbClr val="${_hex(fill)}"/></a:solidFill></a:ln>'
          '</p:spPr></p:cxnSp>');
    }
    return _addToTree(
        slide,
        '<p:sp $_pNs $_aNs><p:nvSpPr><p:cNvPr id="$id" name="Shape $id"/>'
        '<p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr>$xfrm'
        '<a:prstGeom prst="$prst"><a:avLst/></a:prstGeom>'
        '<a:solidFill><a:srgbClr val="${_hex(fill)}"/></a:solidFill>'
        '<a:ln w="12700"><a:solidFill><a:srgbClr val="${_hex(_darken(fill))}"/></a:solidFill></a:ln>'
        '</p:spPr><p:txBody><a:bodyPr rtlCol="0" anchor="ctr"/><a:lstStyle/>'
        '<a:p><a:pPr algn="ctr"/><a:endParaRPr lang="tr-TR"/></a:p></p:txBody></p:sp>');
  }

  static Color _darken(Color c) => Color.from(
      alpha: 1,
      red: c.r * 0.7,
      green: c.g * 0.7,
      blue: c.b * 0.7);

  /// Şeklin dolgusunu (null = dolgusuz) ayarlar.
  bool setShapeFill(PptxSlide slide, ShapeVM shape, Color? color) {
    final el = shape.element;
    if (el == null || el.name.qualified != 'p:sp') return false;
    final spPr = PptxEditor._firstOrNull(el.findElements('p:spPr'));
    if (spPr == null) return false;
    const fills = {'a:noFill', 'a:solidFill', 'a:gradFill', 'a:blipFill', 'a:pattFill', 'a:grpFill'};
    spPr.children.removeWhere(
        (n) => n is XmlElement && fills.contains(n.name.qualified));
    final fill = color == null
        ? XmlElement(XmlName.fromString('a:noFill'))
        : XmlDocument.parse('<a:solidFill $_aNs><a:srgbClr val="${_hex(color)}"/></a:solidFill>')
            .rootElement
            .copy();
    var at = 0;
    for (var i = 0; i < spPr.children.length; i++) {
      final k = spPr.children[i];
      if (k is XmlElement &&
          const {'a:xfrm', 'a:custGeom', 'a:prstGeom'}.contains(k.name.qualified)) {
        at = i + 1;
      }
    }
    spPr.children.insert(at, fill);
    _rerender(slide);
    return true;
  }

  // ── çizgi ve saydamlık ──────────────────────────────────────────────────

  XmlElement? _spPrOf(ShapeVM shape) {
    final el = shape.element;
    if (el == null || !const {'p:sp', 'p:cxnSp', 'p:pic'}.contains(el.name.qualified)) {
      return null;
    }
    return PptxEditor._firstOrNull(el.findElements('p:spPr'));
  }

  /// Şeklin çizgisi (`a:ln`): [color] null = çizgisiz (`a:noFill`), [widthPt]
  /// kalınlık, [dashed] kesik (`a:prstDash val="dash"`). Ok uçları korunur.
  bool setShapeLine(PptxSlide slide, ShapeVM shape,
      {Color? color, double widthPt = 1, bool dashed = false}) {
    final spPr = _spPrOf(shape);
    if (spPr == null) return false;
    var ln = PptxEditor._firstOrNull(spPr.findElements('a:ln'));
    if (ln == null) {
      ln = XmlElement(XmlName.fromString('a:ln'));
      PptxEditor._insertBefore(
          spPr, ln, const {'a:effectLst', 'a:effectDag', 'a:scene3d', 'a:sp3d', 'a:extLst'});
    }
    // ln içi sıra: dolgu, prstDash/custDash, birleşim, headEnd, tailEnd, extLst.
    ln.children.removeWhere((n) =>
        n is XmlElement &&
        const {'a:noFill', 'a:solidFill', 'a:gradFill', 'a:pattFill', 'a:prstDash', 'a:custDash'}
            .contains(n.name.qualified));
    if (color == null) {
      ln.removeAttribute('w');
      ln.children.insert(0, XmlElement(XmlName.fromString('a:noFill')));
    } else {
      ln.setAttribute('w', '${(math.max(widthPt, 0.25) * _emuPt).round()}');
      ln.children.insert(
          0,
          XmlDocument.parse('<a:solidFill $_aNs><a:srgbClr val="${_hex(color)}"/></a:solidFill>')
              .rootElement
              .copy());
      if (dashed) {
        ln.children.insert(
            1,
            XmlElement(XmlName.fromString('a:prstDash'),
                [XmlAttribute(XmlName.fromString('val'), 'dash')]));
      }
    }
    _rerender(slide);
    return true;
  }

  /// Dolgunun renk düğümü (`a:solidFill > a:srgbClr|a:schemeClr|…`).
  XmlElement? _fillColorNode(ShapeVM shape) {
    final spPr = _spPrOf(shape);
    final fill = spPr == null ? null : PptxEditor._firstOrNull(spPr.findElements('a:solidFill'));
    return fill == null ? null : PptxEditor._firstOrNull(fill.childElements);
  }

  /// Dolgunun saydamlığı (0 = opak, 1 = tamamen saydam); düz dolgu yoksa null.
  double? shapeTransparency(ShapeVM shape) {
    final c = _fillColorNode(shape);
    if (c == null) return null;
    final a = PptxEditor._firstOrNull(c.findElements('a:alpha'));
    final v = double.tryParse(a?.getAttribute('val') ?? '');
    return v == null ? 0 : (1 - v / 100000).clamp(0.0, 1.0);
  }

  /// Düz dolgunun saydamlığını yazar (`a:alpha`; 0 = öğe kaldırılır).
  /// Düz dolgusu olmayan şekilde false.
  bool setShapeTransparency(PptxSlide slide, ShapeVM shape, double transparency) {
    final c = _fillColorNode(shape);
    if (c == null) return false;
    c.children.removeWhere((n) => n is XmlElement && n.name.qualified == 'a:alpha');
    final t = transparency.clamp(0.0, 1.0);
    if (t > 0) {
      c.children.add(XmlElement(XmlName.fromString('a:alpha'),
          [XmlAttribute(XmlName.fromString('val'), '${((1 - t) * 100000).round()}')]));
    }
    _rerender(slide);
    return true;
  }

  // ── tablo ───────────────────────────────────────────────────────────────

  /// Slaytın ortasına [rows]×[cols] tablo ekler (`a:tbl` + tema tablo stili).
  /// Çizicimiz tablo stillerini çözmediği için stilin görünümü (başlık satırı
  /// vurgu rengi, bantlı satırlar, beyaz kılavuz) hücrelere de açıkça yazılır;
  /// PowerPoint açık hücre biçimini stile tercih eder → iki yerde aynı görünür.
  XmlElement? addTable(PptxSlide slide, int rows, int cols) {
    if (rows < 1 || cols < 1 || rows > 30 || cols > 20) return null;
    final (sw, sh) = _slideSizeEmu;
    final w = (sw * 0.8).round();
    final colW = w ~/ cols;
    const rowH = 370840; // 0,4 inç — PowerPoint'in varsayılanı
    final h = rowH * rows;
    final x = ((sw - colW * cols) / 2).round(), y = ((sh - h) / 2).round();
    final id = _nextShapeId(slide);
    const side = '<a:solidFill><a:schemeClr val="lt1"/></a:solidFill>';
    String border(String tag) => '<a:$tag w="12700" cmpd="sng">$side</a:$tag>';
    final sb = StringBuffer(
        '<p:graphicFrame $_pNs $_aNs><p:nvGraphicFramePr><p:cNvPr id="$id" name="Table $id"/>'
        '<p:cNvGraphicFramePr><a:graphicFrameLocks noGrp="1"/></p:cNvGraphicFramePr><p:nvPr/>'
        '</p:nvGraphicFramePr><p:xfrm><a:off x="$x" y="$y"/><a:ext cx="${colW * cols}" cy="$h"/>'
        '</p:xfrm><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">'
        '<a:tbl><a:tblPr firstRow="1" bandRow="1"><a:tableStyleId>$kPptxDefaultTableStyle'
        '</a:tableStyleId></a:tblPr><a:tblGrid>');
    for (var c = 0; c < cols; c++) {
      sb.write('<a:gridCol w="$colW"/>');
    }
    sb.write('</a:tblGrid>');
    for (var r = 0; r < rows; r++) {
      sb.write('<a:tr h="$rowH">');
      final header = r == 0;
      final fill = header
          ? '<a:schemeClr val="accent1"/>'
          : '<a:schemeClr val="accent1"><a:tint val="${r.isOdd ? 40000 : 20000}"/></a:schemeClr>';
      final rPr = header
          ? '<a:endParaRPr lang="tr-TR" sz="1800" b="1" dirty="0"><a:solidFill>'
              '<a:schemeClr val="lt1"/></a:solidFill></a:endParaRPr>'
          : '<a:endParaRPr lang="tr-TR" sz="1800" dirty="0"/>';
      for (var c = 0; c < cols; c++) {
        sb.write('<a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p>$rPr</a:p></a:txBody>'
            '<a:tcPr anchor="ctr">${border('lnL')}${border('lnR')}${border('lnT')}${border('lnB')}'
            '<a:solidFill>$fill</a:solidFill></a:tcPr></a:tc>');
      }
      sb.write('</a:tr>');
    }
    sb.write('</a:tbl></a:graphicData></a:graphic></p:graphicFrame>');
    return _addToTree(slide, sb.toString());
  }

  /// Slayt arka plan rengi (null = kaldır, düzenin arka planı geçerli).
  bool setSlideBackground(PptxSlide slide, Color? color) {
    final cSld = PptxEditor._firstOrNull(slide.doc.findAllElements('p:cSld'));
    if (cSld == null) return false;
    cSld.children.removeWhere((n) => n is XmlElement && n.name.qualified == 'p:bg');
    if (color != null) {
      final bg = XmlDocument.parse('<p:bg $_pNs $_aNs><p:bgPr><a:solidFill>'
              '<a:srgbClr val="${_hex(color)}"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>')
          .rootElement
          .copy();
      cSld.children.insert(0, bg);
    }
    _rerender(slide);
    return true;
  }

  PptxTransition transitionOf(PptxSlide slide) {
    final t = PptxEditor._firstOrNull(slide.doc.rootElement.findElements('p:transition'));
    if (t == null) return PptxTransition.none;
    for (final k in t.childElements) {
      switch (k.name.local) {
        case 'fade':
          return PptxTransition.fade;
        case 'push':
          return PptxTransition.push;
        case 'wipe':
          return PptxTransition.wipe;
      }
    }
    return PptxTransition.none;
  }

  /// Geçiş yazar (`p:transition`; sıra: cSld, clrMapOvr, transition, timing).
  bool setTransition(PptxSlide slide, PptxTransition kind) {
    final root = slide.doc.rootElement;
    root.children.removeWhere(
        (n) => n is XmlElement && n.name.qualified == 'p:transition');
    if (kind != PptxTransition.none) {
      final inner = switch (kind) {
        PptxTransition.fade => '<p:fade/>',
        PptxTransition.push => '<p:push dir="l"/>',
        _ => '<p:wipe dir="l"/>',
      };
      final t = XmlDocument.parse('<p:transition $_pNs spd="med">$inner</p:transition>')
          .rootElement
          .copy();
      PptxEditor._insertBefore(root, t, const {'p:timing', 'p:extLst'});
    }
    _rerender(slide); // sunum geçişi çizim modelinden okur
    return true;
  }

  /// Slayt gizli mi (`p:sld@show="0"`) — sunumda atlanır, düzenlemede görünür.
  bool isHidden(PptxSlide slide) {
    final v = slide.doc.rootElement.getAttribute('show');
    return v == '0' || v == 'false';
  }

  /// **Slaytı gizle / göster.** Gösterilen slaytta öznitelik hiç yazılmaz
  /// (varsayılan `true`; PowerPoint de böyle kaydeder).
  bool setHidden(PptxSlide slide, bool hidden) {
    final root = slide.doc.rootElement;
    if (hidden) {
      root.setAttribute('show', '0');
    } else {
      root.removeAttribute('show');
    }
    return true;
  }

  /// Sürükle-bırak sıralama: [slide]'ı [to] konumuna (0 tabanlı) taşır;
  /// `sldIdLst` sırası da güncellenir. Yer değişmediyse false.
  bool moveSlideTo(PptxSlide slide, int to) {
    if (!canEditStructure) return false;
    final i = slides.indexOf(slide);
    final j = to.clamp(0, slides.length - 1);
    if (i < 0 || i == j) return false;
    slides.removeAt(i);
    slides.insert(j, slide);
    _syncSldIdOrder();
    _reindex();
    return true;
  }

  // ── düzenden yeni slayt ─────────────────────────────────────────────────

  /// Sunumdaki düzenler (galeri).
  List<PptxLayoutInfo> layouts() {
    final out = <PptxLayoutInfo>[];
    final names = _archive.files
        .map((f) => f.name)
        .where((n) => RegExp(r'^ppt/slideLayouts/slideLayout\d+\.xml$').hasMatch(n))
        .toList()
      ..sort((a, b) => PptxEditor._idx(a).compareTo(PptxEditor._idx(b)));
    for (final n in names) {
      final doc = PptxEditor._tryParse(_archive, n);
      if (doc == null) continue;
      final root = doc.rootElement;
      final cSld = PptxEditor._firstOrNull(root.findElements('p:cSld'));
      out.add(PptxLayoutInfo(
          n, cSld?.getAttribute('name') ?? n.split('/').last, root.getAttribute('type') ?? ''));
    }
    return out;
  }

  /// [layout]'tan yer tutuculu yeni slayt ekler ([after]'ın ardına).
  PptxSlide? addSlideFromLayout(PptxLayoutInfo layout, {PptxSlide? after}) {
    if (!canEditStructure) return null;
    final ldoc = PptxEditor._tryParse(_archive, layout.part);
    if (ldoc == null) return null;
    final num = _nextSlideNumber();
    final newName = 'ppt/slides/slide$num.xml';
    final sb = StringBuffer(
        '<p:sld $_pNs $_aNs xmlns:r="${PptxEditor._nsR}"><p:cSld><p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr/>');
    var id = 2;
    for (final sp in ldoc.findAllElements('p:sp')) {
      final ph = PptxEditor._firstOrNull(sp.findAllElements('p:ph'));
      if (ph == null) continue;
      final type = ph.getAttribute('type') ?? 'body';
      if (const {'dt', 'ftr', 'sldNum'}.contains(type)) continue;
      final attrs = StringBuffer();
      for (final a in ph.attributes) {
        attrs.write(' ${a.name.qualified}="${a.value}"');
      }
      sb.write('<p:sp><p:nvSpPr><p:cNvPr id="$id" name="Placeholder $id"/>'
          '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph$attrs/></p:nvPr></p:nvSpPr>'
          '<p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:endParaRPr lang="tr-TR"/></a:p></p:txBody></p:sp>');
      id++;
    }
    sb.write('</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>');
    final newDoc = XmlDocument.parse(sb.toString());
    _addFile(newName, newDoc.toXmlString());
    _addFile('ppt/slides/_rels/slide$num.xml.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="${PptxEditor._relsNs}"><Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" '
        'Target="../slideLayouts/${layout.part.split('/').last}"/></Relationships>');
    _addContentOverride(newName, PptxEditor._slideContentType);
    final rid = _nextRelId();
    _addPresRel(rid, PptxEditor._slideRelType, 'slides/slide$num.xml');
    _appendSldId(_nextSldId(), rid);
    final s = PptxSlide(0, PptxEditor._paragraphsOf(newDoc), newDoc, newName,
        PptxEditor._tryRender(_render, newName, newDoc));
    final i = after == null ? -1 : slides.indexOf(after);
    slides.insert(i < 0 ? slides.length : i + 1, s);
    _syncSldIdOrder();
    _reindex();
    return s;
  }

  /// Slaydın şu anki düzeni (galeride işaretli gösterilir).
  String? layoutOf(PptxSlide slide) {
    final rels = _slideRelsDoc(slide);
    if (rels == null) return null;
    for (final r in rels.rootElement.childElements) {
      if ((r.getAttribute('Type') ?? '').endsWith('/slideLayout')) {
        final t = r.getAttribute('Target') ?? '';
        return 'ppt/slideLayouts/${t.split('/').last}';
      }
    }
    return null;
  }

  XmlDocument? _slideRelsDoc(PptxSlide slide) {
    final bytes = PptxEditor._fileByName(
        _archive, PptxEditor._relsPathOf(slide.fileName));
    if (bytes == null) return null;
    try {
      return XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  /// Yer tutucu türünün eşleşme sınıfı (`ctrTitle` ↔ `title`, içerik ↔ gövde).
  static String _phClass(XmlElement ph) {
    final t = ph.getAttribute('type') ?? 'body';
    return switch (t) {
      'ctrTitle' || 'title' => 'title',
      'subTitle' || 'body' || 'obj' => 'body',
      _ => t,
    };
  }

  static XmlElement? _phOf(XmlElement sp) =>
      PptxEditor._firstOrNull(sp.findAllElements('p:ph'));

  /// **Düzeni değiştir** (PowerPoint: Giriş > Düzen). Slaytın ilişkisi yeni
  /// düzene bağlanır; yer tutucular türüne göre eşleşir (başlık → başlık,
  /// içerik → ilk boş gövde) ve yeni düzenin `idx`ini alır — konum/biçim
  /// yeni düzenden kalıtılır. Yeni düzende karşılığı olmayan:
  /// * **boş** yer tutucu silinir;
  /// * **dolu** yer tutucu kalır, eski düzendeki yeri slayta yazılır (metin
  ///   kaybolmaz, yerinde durur).
  /// Yeni düzende olup slaytta olmayan yer tutucular boş eklenir.
  bool changeLayout(PptxSlide slide, PptxLayoutInfo layout) {
    final newDoc = PptxEditor._tryParse(_archive, layout.part);
    final rels = _slideRelsDoc(slide);
    final tree = _spTree(slide);
    if (newDoc == null || rels == null || tree == null) return false;
    final oldPart = layoutOf(slide);
    if (oldPart == layout.part) return false;
    final oldDoc = oldPart == null ? null : PptxEditor._tryParse(_archive, oldPart);

    // Yeni düzenin yer tutucuları (alt bilgi/tarih/numara hariç).
    final targets = <XmlElement>[];
    for (final sp in newDoc.findAllElements('p:sp')) {
      final ph = _phOf(sp);
      if (ph == null) continue;
      if (const {'dt', 'ftr', 'sldNum'}.contains(ph.getAttribute('type'))) {
        continue;
      }
      targets.add(sp);
    }
    final used = <XmlElement>{};

    XmlElement? oldXfrm(XmlElement ph) {
      if (oldDoc == null) return null;
      final cls = _phClass(ph);
      final idx = ph.getAttribute('idx');
      for (final sp in oldDoc.findAllElements('p:sp')) {
        final o = _phOf(sp);
        if (o == null) continue;
        if ((idx != null && o.getAttribute('idx') == idx) ||
            (idx == null && _phClass(o) == cls)) {
          final spPr = PptxEditor._firstOrNull(sp.findElements('p:spPr'));
          final x = spPr == null
              ? null
              : PptxEditor._firstOrNull(spPr.findElements('a:xfrm'));
          if (x != null) return x;
        }
      }
      return null;
    }

    for (final sp in tree.findElements('p:sp').toList()) {
      final ph = _phOf(sp);
      if (ph == null) continue;
      final type = ph.getAttribute('type');
      if (const {'dt', 'ftr', 'sldNum'}.contains(type)) continue;
      final cls = _phClass(ph);
      XmlElement? match;
      for (final t in targets) {
        if (used.contains(t)) continue;
        if (_phClass(_phOf(t)!) == cls) {
          match = t;
          break;
        }
      }
      final text = sp.findAllElements('a:t').map((e) => e.innerText).join();
      if (match != null) {
        used.add(match);
        final nph = _phOf(match)!;
        for (final a in ph.attributes.toList()) {
          ph.removeAttribute(a.name.qualified);
        }
        for (final a in nph.attributes) {
          ph.setAttribute(a.name.qualified, a.value);
        }
        continue;
      }
      if (text.trim().isEmpty) {
        tree.children.remove(sp);
        continue;
      }
      // Dolu ama yeni düzende yeri yok: eski yeri slayta sabitlenir.
      final spPr = PptxEditor._firstOrNull(sp.findElements('p:spPr'));
      final hasXfrm = spPr != null &&
          PptxEditor._firstOrNull(spPr.findElements('a:xfrm')) != null;
      final x = oldXfrm(ph);
      if (spPr != null && !hasXfrm && x != null) {
        spPr.children.insert(0, x.copy());
      }
    }

    var id = _nextShapeId(slide);
    for (final t in targets) {
      if (used.contains(t)) continue;
      final ph = _phOf(t)!;
      final attrs = StringBuffer();
      for (final a in ph.attributes) {
        attrs.write(' ${a.name.qualified}="${a.value}"');
      }
      final sp = XmlDocument.parse(
              '<p:sp $_pNs $_aNs><p:nvSpPr><p:cNvPr id="$id" name="Placeholder $id"/>'
              '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph$attrs/></p:nvPr></p:nvSpPr>'
              '<p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:endParaRPr lang="tr-TR"/></a:p></p:txBody></p:sp>')
          .rootElement
          .copy();
      PptxEditor._insertBefore(tree, sp, const {'p:extLst'});
      id++;
    }

    for (final r in rels.rootElement.childElements) {
      if ((r.getAttribute('Type') ?? '').endsWith('/slideLayout')) {
        r.setAttribute('Target', '../slideLayouts/${layout.part.split('/').last}');
      }
    }
    _addFile(PptxEditor._relsPathOf(slide.fileName), rels.toXmlString());
    _rerender(slide);
    return true;
  }
}
