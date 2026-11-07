import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'pptx_package.dart';

/// Bağlantı / eylem hedefi.
enum SlideLinkKind { url, next, prev, first, last, slide, end, none }

/// Tablo biçimi: başlık rengi, şerit rengi, kenarlık rengi (RRGGBB).
class SlideTableStyle {
  final String id, header, band, border;
  final String headerText;
  const SlideTableStyle(this.id, this.header, this.band, this.border,
      {this.headerText = 'FFFFFF'});
}

/// Eylem düğmesi önayarı → varsayılan eylemi.
const kActionButtonTargets = {
  'actionButtonForwardNext': SlideLinkKind.next,
  'actionButtonBackPrevious': SlideLinkKind.prev,
  'actionButtonBeginning': SlideLinkKind.first,
  'actionButtonHome': SlideLinkKind.first,
  'actionButtonEnd': SlideLinkKind.last,
  'actionButtonReturn': SlideLinkKind.prev,
};

/// Canlı sayaç işareti (`p:cNvPr@descr`): `dosya:sayac=<saniye>`.
const kCounterMarker = 'dosya:sayac=';

/// **Faz 38 / madde 8 — şekil araçları (paket düzeyi).** Bağlayıcı çizgi,
/// gradyan/gölge/yansıma, görsel kırpma/şekle kırp/görsel değiştir (arka plan
/// kaldırma sonucu), tablo biçimleri, köprü/eylem, canlı sayaç.
abstract final class PptxShapeOps {
  static const tableStyles = [
    SlideTableStyle('blue', '1F5AA6', 'DCE6F2', '8EA9DB'),
    SlideTableStyle('green', '2E7D32', 'E2EFDA', 'A9D08E'),
    SlideTableStyle('orange', 'C55A11', 'FBE5D6', 'F4B183'),
    SlideTableStyle('gray', '595959', 'EDEDED', 'BFBFBF'),
    SlideTableStyle('dark', '111827', '374151', '4B5563', headerText: 'F9FAFB'),
    SlideTableStyle('lines', 'FFFFFF', 'FFFFFF', '7F7F7F', headerText: '000000'),
  ];

  static XmlDocument _doc(PptxPackage pkg, int slide) =>
      pkg.edit(pkg.slidePart(slide))!;

  static XmlElement _shape(XmlDocument d, int id) =>
      PptxPackage.shapeById(d, id) ?? (throw StateError('shape $id'));

  static XmlElement? _spPr(XmlElement shape) => shape.getElement('p:spPr');

  static List<int>? _frame(XmlElement shape) {
    final x = shape.name.local == 'graphicFrame'
        ? shape.getElement('p:xfrm')
        : shape.name.local == 'grpSp'
            ? shape.getElement('p:grpSpPr')?.getElement('a:xfrm')
            : _spPr(shape)?.getElement('a:xfrm');
    final off = x?.getElement('a:off'), ext = x?.getElement('a:ext');
    if (off == null || ext == null) return null;
    int v(XmlElement e, String a) => int.tryParse(e.getAttribute(a) ?? '') ?? 0;
    return [v(off, 'x'), v(off, 'y'), v(ext, 'cx'), v(ext, 'cy')];
  }

  /// spPr içinde ECMA sırası: xfrm, geom, fill, ln, effectLst, scene3d …
  static void _putInSpPr(XmlElement spPr, XmlElement el, List<String> before) {
    final kids = spPr.children;
    for (var i = 0; i < kids.length; i++) {
      final k = kids[i];
      if (k is XmlElement && before.contains(k.name.local)) {
        kids.insert(i, el);
        return;
      }
    }
    final ext = spPr.getElement('a:extLst');
    kids.insert(ext == null ? kids.length : kids.indexOf(ext), el);
  }

  static const _fills = {'noFill', 'solidFill', 'gradFill', 'blipFill', 'pattFill', 'grpFill'};

  // ── Bağlayıcı ────────────────────────────────────────────────────────────

  /// İki şekli bağlayan çizgi (`p:cxnSp` + stCxn/endCxn; şekil taşınınca
  /// PowerPoint çizgiyi yeniden yönlendirir). [elbow]: dirsekli.
  static PptxOp connect(int slide, int fromId, int toId,
          {bool arrow = true, bool elbow = false}) =>
      (pkg) {
        final d = _doc(pkg, slide);
        final a = _frame(_shape(d, fromId)), b = _frame(_shape(d, toId));
        if (a == null || b == null) throw StateError('frame');
        final acx = a[0] + a[2] / 2, acy = a[1] + a[3] / 2;
        final bcx = b[0] + b[2] / 2, bcy = b[1] + b[3] / 2;
        final horizontal = (bcx - acx).abs() >= (bcy - acy).abs();
        // Bağlantı noktaları (dikdörtgen: 0 üst, 1 sol, 2 alt, 3 sağ).
        late double sx, sy, ex, ey;
        late int si, ei;
        if (horizontal) {
          final right = bcx > acx;
          sx = right ? (a[0] + a[2]).toDouble() : a[0].toDouble();
          sy = acy;
          ex = right ? b[0].toDouble() : (b[0] + b[2]).toDouble();
          ey = bcy;
          si = right ? 3 : 1;
          ei = right ? 1 : 3;
        } else {
          final down = bcy > acy;
          sx = acx;
          sy = down ? (a[1] + a[3]).toDouble() : a[1].toDouble();
          ex = bcx;
          ey = down ? b[1].toDouble() : (b[1] + b[3]).toDouble();
          si = down ? 2 : 0;
          ei = down ? 0 : 2;
        }
        final x = sx < ex ? sx : ex, y = sy < ey ? sy : ey;
        final w = (ex - sx).abs(), h = (ey - sy).abs();
        final flipH = ex < sx ? ' flipH="1"' : '';
        final flipV = ey < sy ? ' flipV="1"' : '';
        final id = PptxPackage.nextShapeId(d);
        final prst = elbow ? 'bentConnector3' : 'straightConnector1';
        PptxPackage.spTree(d)!.children.add(PptxPackage.frag('<p:cxnSp><p:nvCxnSpPr>'
            '<p:cNvPr id="$id" name="Bağlayıcı $id"/><p:cNvCxnSpPr>'
            '<a:stCxn id="$fromId" idx="$si"/><a:endCxn id="$toId" idx="$ei"/></p:cNvCxnSpPr><p:nvPr/></p:nvCxnSpPr>'
            '<p:spPr><a:xfrm$flipH$flipV><a:off x="${x.round()}" y="${y.round()}"/>'
            '<a:ext cx="${w.round()}" cy="${h.round()}"/></a:xfrm>'
            '<a:prstGeom prst="$prst"><a:avLst/></a:prstGeom>'
            '<a:ln w="19050"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill>'
            '${arrow ? '<a:tailEnd type="triangle"/>' : ''}</a:ln></p:spPr></p:cxnSp>'));
      };

  // ── Efektler ─────────────────────────────────────────────────────────────

  /// Doğrusal gradyan dolgu ([angle] derece, 0 = soldan sağa).
  static PptxOp setGradient(int slide, int id, String from, String to,
          {double angle = 90}) =>
      (pkg) {
        final spPr = _spPr(_shape(_doc(pkg, slide), id));
        if (spPr == null) throw StateError('spPr');
        spPr.children.removeWhere((n) => n is XmlElement && _fills.contains(n.name.local));
        _putInSpPr(
            spPr,
            PptxPackage.frag('<a:gradFill rotWithShape="1"><a:gsLst>'
                '<a:gs pos="0"><a:srgbClr val="${from.replaceAll('#', '')}"/></a:gs>'
                '<a:gs pos="100000"><a:srgbClr val="${to.replaceAll('#', '')}"/></a:gs>'
                '</a:gsLst><a:lin ang="${(angle * 60000).round()}" scaled="0"/></a:gradFill>'),
            const ['ln', 'effectLst', 'effectDag', 'scene3d', 'sp3d']);
      };

  static XmlElement _effectLst(XmlElement spPr) {
    var e = spPr.getElement('a:effectLst');
    if (e == null) {
      e = XmlElement(const XmlName.qualified('a:effectLst'));
      _putInSpPr(spPr, e, const ['scene3d', 'sp3d']);
    }
    return e;
  }

  /// effectLst içi sıra: blur, fillOverlay, glow, innerShdw, outerShdw,
  /// prstShdw, reflection, softEdge.
  static const _effOrder = [
    'blur', 'fillOverlay', 'glow', 'innerShdw', 'outerShdw', 'prstShdw', 'reflection', 'softEdge',
  ];

  static void _setEffect(XmlElement spPr, String tag, String? xml) {
    final lst = _effectLst(spPr);
    lst.children.removeWhere((n) => n is XmlElement && n.name.local == tag);
    if (xml == null) return;
    final at = _effOrder.indexOf(tag);
    final after = lst.childElements.where((e) => _effOrder.indexOf(e.name.local) > at).firstOrNull;
    final kids = lst.children;
    kids.insert(after == null ? kids.length : kids.indexOf(after), PptxPackage.frag(xml));
  }

  static PptxOp setShadow(int slide, int id, bool on) => (pkg) {
        final spPr = _spPr(_shape(_doc(pkg, slide), id));
        if (spPr == null) throw StateError('spPr');
        _setEffect(
            spPr,
            'outerShdw',
            on
                ? '<a:outerShdw blurRad="76200" dist="38100" dir="2700000" algn="tl" rotWithShape="0">'
                    '<a:srgbClr val="000000"><a:alpha val="40000"/></a:srgbClr></a:outerShdw>'
                : null);
      };

  static PptxOp setReflection(int slide, int id, bool on) => (pkg) {
        final spPr = _spPr(_shape(_doc(pkg, slide), id));
        if (spPr == null) throw StateError('spPr');
        _setEffect(
            spPr,
            'reflection',
            on
                ? '<a:reflection blurRad="6350" stA="50000" endA="300" endPos="55000" '
                    'dist="12700" dir="5400000" sy="-100000" algn="bl" rotWithShape="0"/>'
                : null);
      };

  /// Yumuşak parıltı (vurgu rengi).
  static PptxOp setGlow(int slide, int id, String? hex) => (pkg) {
        final spPr = _spPr(_shape(_doc(pkg, slide), id));
        if (spPr == null) throw StateError('spPr');
        _setEffect(spPr, 'glow',
            hex == null ? null : '<a:glow rad="101600"><a:srgbClr val="$hex"><a:alpha val="60000"/></a:srgbClr></a:glow>');
      };

  // ── Görsel ───────────────────────────────────────────────────────────────

  /// Kırpma (kenarlardan oran 0..0.9). Hepsi 0 → kırpma kalkar.
  static PptxOp setCrop(int slide, int id, double l, double t, double r, double b) =>
      (pkg) {
        final pic = _shape(_doc(pkg, slide), id);
        final fill = pic.getElement('p:blipFill');
        if (fill == null) throw StateError('pic');
        fill.children.removeWhere((n) => n is XmlElement && n.name.local == 'srcRect');
        if (l == 0 && t == 0 && r == 0 && b == 0) return;
        int p(double v) => (v.clamp(0.0, 0.9) * 100000).round();
        final blip = fill.getElement('a:blip');
        final el = PptxPackage.frag('<a:srcRect l="${p(l)}" t="${p(t)}" r="${p(r)}" b="${p(b)}"/>');
        fill.children.insert(blip == null ? 0 : fill.children.indexOf(blip) + 1, el);
      };

  /// Şekle kırp: görselin geometrisi ([prst] ör. ellipse, roundRect, star5).
  static PptxOp cropToShape(int slide, int id, String prst) => (pkg) {
        final pic = _shape(_doc(pkg, slide), id);
        final spPr = _spPr(pic);
        if (spPr == null) throw StateError('pic');
        spPr.children.removeWhere(
            (n) => n is XmlElement && (n.name.local == 'prstGeom' || n.name.local == 'custGeom'));
        final xfrm = spPr.getElement('a:xfrm');
        spPr.children.insert(xfrm == null ? 0 : spPr.children.indexOf(xfrm) + 1,
            PptxPackage.frag('<a:prstGeom prst="$prst"><a:avLst/></a:prstGeom>'));
      };

  /// Görselin baytı (arka plan kaldırma girdisi): (bayt, uzantı).
  static (Uint8List, String)? imageOf(PptxPackage pkg, int slide, int id) {
    final part = pkg.slidePart(slide);
    final d = pkg.xml(part);
    final pic = d == null ? null : PptxPackage.shapeById(d, id);
    final rid = pic?.getElement('p:blipFill')?.getElement('a:blip')?.getAttribute('r:embed');
    final t = rid == null ? null : pkg.relTarget(part, rid);
    final b = t == null ? null : pkg.bytes(t);
    return b == null ? null : (b, t!.split('.').last.toLowerCase());
  }

  /// Görseli yenisiyle değiştirir (eski parça başka yerde kullanılıyor
  /// olabilir → silinmez, yeni parça eklenir).
  static PptxOp replaceImage(int slide, int id, Uint8List png) => (pkg) {
        final part = pkg.slidePart(slide);
        final pic = _shape(_doc(pkg, slide), id);
        final blip = pic.getElement('p:blipFill')?.getElement('a:blip');
        if (blip == null) throw StateError('pic');
        final name = pkg.freeName('ppt/media/image', 'png');
        pkg.putBytes(name, png);
        pkg.ensureDefault('png', 'image/png');
        blip.setAttribute('r:embed', pkg.addRel(part, 'image', name));
      };

  // ── Tablo biçimi ─────────────────────────────────────────────────────────

  static PptxOp applyTableStyle(int slide, int id, String styleId) => (pkg) {
        final st = tableStyles.firstWhere((s) => s.id == styleId);
        final frame = _shape(_doc(pkg, slide), id);
        final tbl = frame.findAllElements('a:tbl').firstOrNull;
        if (tbl == null) throw StateError('table');
        var pr = tbl.getElement('a:tblPr');
        if (pr == null) {
          pr = XmlElement(const XmlName.qualified('a:tblPr'));
          tbl.children.insert(0, pr);
        }
        pr.setAttribute('firstRow', '1');
        pr.setAttribute('bandRow', '1');
        pr.children.removeWhere((n) => n is XmlElement && n.name.local == 'tableStyleId');
        final rows = tbl.findElements('a:tr').toList();
        for (var r = 0; r < rows.length; r++) {
          final head = r == 0;
          final fill = head ? st.header : (r.isEven ? st.band : 'FFFFFF');
          for (final tc in rows[r].findElements('a:tc')) {
            tc.children.removeWhere((n) => n is XmlElement && n.name.local == 'tcPr');
            String side(String tag) =>
                '<a:$tag w="12700"><a:solidFill><a:srgbClr val="${st.border}"/></a:solidFill></a:$tag>';
            tc.children.add(PptxPackage.frag('<a:tcPr>${side('lnL')}${side('lnR')}${side('lnT')}${side('lnB')}'
                '<a:solidFill><a:srgbClr val="$fill"/></a:solidFill></a:tcPr>'));
            // Başlık yazısı: kalın + zıt renk.
            for (final rPr in [
              ...tc.findAllElements('a:rPr'),
              ...tc.findAllElements('a:endParaRPr'),
            ]) {
              rPr.children.removeWhere((n) => n is XmlElement && _fills.contains(n.name.local));
              if (head || styleId == 'dark') {
                rPr.children.insert(0, PptxPackage.frag(
                    '<a:solidFill><a:srgbClr val="${head ? st.headerText : 'F9FAFB'}"/></a:solidFill>'));
              }
              if (head) rPr.setAttribute('b', '1');
            }
          }
        }
      };

  // ── Köprü / eylem ────────────────────────────────────────────────────────

  static XmlElement _cNvPr(XmlElement shape) {
    for (final nv in shape.childElements) {
      if (!nv.name.local.startsWith('nv')) continue;
      final c = nv.getElement('p:cNvPr');
      if (c != null) return c;
    }
    throw StateError('cNvPr');
  }

  static String _jump(SlideLinkKind k) => switch (k) {
        SlideLinkKind.next => 'nextslide',
        SlideLinkKind.prev => 'previousslide',
        SlideLinkKind.first => 'firstslide',
        SlideLinkKind.last => 'lastslide',
        _ => 'endshow',
      };

  /// Şekle tıklama eylemi. [url] (url kipinde) ya da [target] (slide kipinde,
  /// 0 tabanlı) gerekir; [SlideLinkKind.none] köprüyü kaldırır.
  static PptxOp setLink(int slide, int id, SlideLinkKind kind,
          {String? url, int? target}) =>
      (pkg) {
        final part = pkg.slidePart(slide);
        final c = _cNvPr(_shape(_doc(pkg, slide), id));
        for (final old in c.findElements('a:hlinkClick').toList()) {
          final rid = old.getAttribute('r:id');
          if (rid != null && rid.isNotEmpty) pkg.removeRel(part, rid);
          c.children.remove(old);
        }
        if (kind == SlideLinkKind.none) return;
        final String xml;
        switch (kind) {
          case SlideLinkKind.url:
            final u = (url ?? '').trim();
            if (u.isEmpty) throw ArgumentError('url');
            final rid = pkg.addRel(part, 'hyperlink', u, external: true);
            xml = '<a:hlinkClick r:id="$rid"/>';
          case SlideLinkKind.slide:
            final parts = pkg.slideParts();
            final t = target ?? -1;
            if (t < 0 || t >= parts.length) throw RangeError.index(t, parts);
            final rid = pkg.addRel(part, 'slide', parts[t]);
            xml = '<a:hlinkClick r:id="$rid" action="ppaction://hlinksldjump"/>';
          default:
            xml = '<a:hlinkClick r:id="" action="ppaction://hlinkshowjump?jump=${_jump(kind)}"/>';
        }
        c.children.insert(0, PptxPackage.frag(xml));
      };

  // ── Canlı sayaç ──────────────────────────────────────────────────────────

  /// Geri sayım kutusu: sunumda canlı sayar (işaret `descr`'de); başka
  /// programlarda başlangıç süresini gösteren düz metindir.
  static PptxOp addCounter(int slide, int seconds) => (pkg) {
        final d = _doc(pkg, slide);
        final (w, h) = pkg.slideSize();
        final id = PptxPackage.nextShapeId(d);
        final s = seconds.clamp(1, 359999);
        final label = '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
        PptxPackage.spTree(d)!.children.add(PptxPackage.frag('<p:sp><p:nvSpPr>'
            '<p:cNvPr id="$id" name="Sayaç $id" descr="$kCounterMarker$s"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
            '<p:spPr><a:xfrm><a:off x="${w * 3 ~/ 8}" y="${h * 2 ~/ 5}"/><a:ext cx="${w ~/ 4}" cy="${h ~/ 5}"/></a:xfrm>'
            '<a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom><a:solidFill><a:schemeClr val="accent1"/></a:solidFill></p:spPr>'
            '<p:txBody><a:bodyPr anchor="ctr"/><a:lstStyle/><a:p><a:pPr algn="ctr"/>'
            '<a:r><a:rPr lang="tr-TR" sz="4400" b="1"><a:solidFill><a:schemeClr val="bg1"/></a:solidFill></a:rPr>'
            '<a:t>$label</a:t></a:r></a:p></p:txBody></p:sp>'));
      };

  /// Eylem düğmesi: şekil + varsayılan eylemi tek adımda.
  static PptxOp addActionButton(int slide, String prst) => (pkg) {
        final kind = kActionButtonTargets[prst];
        if (kind == null) throw ArgumentError(prst);
        final d = _doc(pkg, slide);
        final (w, h) = pkg.slideSize();
        final id = PptxPackage.nextShapeId(d);
        final side = h ~/ 9;
        // Sağ alt köşeye, var olan düğmelerle üst üste binmesin.
        final n = d.findAllElements('a:prstGeom')
            .where((g) => (g.getAttribute('prst') ?? '').startsWith('actionButton'))
            .length;
        PptxPackage.spTree(d)!.children.add(PptxPackage.frag('<p:sp><p:nvSpPr>'
            '<p:cNvPr id="$id" name="Eylem $id"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
            '<p:spPr><a:xfrm><a:off x="${w - side * (n + 1) - side ~/ 2 * (n + 1)}" y="${h - side * 3 ~/ 2}"/>'
            '<a:ext cx="$side" cy="$side"/></a:xfrm><a:prstGeom prst="$prst"><a:avLst/></a:prstGeom>'
            '<a:solidFill><a:schemeClr val="accent1"/></a:solidFill></p:spPr>'
            '<p:txBody><a:bodyPr anchor="ctr"/><a:lstStyle/><a:p><a:endParaRPr lang="tr-TR"/></a:p></p:txBody></p:sp>'));
        setLink(slide, id, kind)(pkg);
      };
}
