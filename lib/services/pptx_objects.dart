part of 'pptx_editor.dart';

/// Faz 29 — slayt nesneleri: çerçeve (taşı/boyutlandır/döndür), metin kutusu
/// ve şekil ekleme, dolgu, arka plan, geçiş, düzenden yeni slayt.
/// Hepsi XML'e doğrudan yazar; geri al, deste anlık görüntüsüyle (`snapshot`)
/// ekranda yapılır.

const _emuPt = 12700;

/// Eklenebilir ön tanımlı şekiller (`a:prstGeom@prst`).
const kPptxShapeKinds = [
  'rect', 'roundRect', 'ellipse', 'triangle', 'rightArrow', 'star5', 'line',
];

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
    if (el == null || (el.parent as XmlElement?)?.name.qualified != 'p:spTree') {
      return false;
    }
    final xf = _xfrmOf(el);
    if (xf == null) return false;
    final off = PptxEditor._firstOrNull(xf.findElements('a:off'));
    final ext = PptxEditor._firstOrNull(xf.findElements('a:ext'));
    if (off == null || ext == null) return false;
    off.setAttribute('x', '${(x * _emuPt).round()}');
    off.setAttribute('y', '${(y * _emuPt).round()}');
    ext.setAttribute('cx', '${(math.max(w, 0) * _emuPt).round()}');
    ext.setAttribute('cy', '${(math.max(h, 0) * _emuPt).round()}');
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
}
