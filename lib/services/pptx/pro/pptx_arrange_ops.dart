import 'package:xml/xml.dart';

import 'pptx_package.dart';

/// Katman panelindeki bir şekil (z sırası: listede SONRAKİ önde).
class SlideLayer {
  final int id;
  final String name;

  /// `sp`, `pic`, `grpSp`, `graphicFrame`, `cxnSp` …
  final String kind;
  final bool hidden;

  /// Konum (EMU); konumu miras alan yer tutucuda null.
  final List<int>? frame;
  const SlideLayer(this.id, this.name, this.kind, this.hidden, this.frame);
}

/// Animasyon sırası panelindeki bir tıklama adımı.
class SlideAnimStep {
  final List<int> shapeIds;

  /// `entr` / `exit` / `emph` / `path` (yoksa boş).
  final String presetClass;
  final int presetId;
  const SlideAnimStep(this.shapeIds, this.presetClass, this.presetId);
}

enum SlideAlign { left, hcenter, right, top, vcenter, bottom }

/// Eklenebilir giriş efektleri (PowerPoint önayar kimlikleri).
enum SlideEntrance { appear, fade, wipe, zoom }

/// **Faz 38 / madde 6 — hizala/dağıt, katman paneli, animasyon sırası.**
abstract final class PptxArrangeOps {
  // ── Katmanlar ────────────────────────────────────────────────────────────

  static XmlElement? _cNvPr(XmlElement shape) {
    for (final nv in shape.childElements) {
      if (!nv.name.local.startsWith('nv')) continue;
      final c = nv.getElement('p:cNvPr');
      if (c != null) return c;
    }
    return null;
  }

  static XmlElement? _xfrm(XmlElement shape) => switch (shape.name.local) {
        'graphicFrame' => shape.getElement('p:xfrm'),
        'grpSp' => shape.getElement('p:grpSpPr')?.getElement('a:xfrm'),
        _ => shape.getElement('p:spPr')?.getElement('a:xfrm'),
      };

  static List<int>? _frame(XmlElement shape) {
    final x = _xfrm(shape);
    final off = x?.getElement('a:off'), ext = x?.getElement('a:ext');
    if (off == null || ext == null) return null;
    int v(XmlElement e, String a) => int.tryParse(e.getAttribute(a) ?? '') ?? 0;
    return [v(off, 'x'), v(off, 'y'), v(ext, 'cx'), v(ext, 'cy')];
  }

  static void _setOff(XmlElement shape, int x, int y) {
    final off = _xfrm(shape)?.getElement('a:off');
    off?.setAttribute('x', '$x');
    off?.setAttribute('y', '$y');
  }

  static List<XmlElement> _shapes(XmlDocument d) => [
        for (final e in PptxPackage.spTree(d)?.childElements ?? const <XmlElement>[])
          if (!e.name.local.startsWith('nvGrpSpPr') &&
              e.name.local != 'grpSpPr' &&
              e.name.local != 'extLst' &&
              _cNvPr(e) != null)
            e,
      ];

  static List<SlideLayer> layers(PptxPackage pkg, int slide) {
    final d = pkg.xml(pkg.slidePart(slide));
    if (d == null) return const [];
    return [
      for (final e in _shapes(d))
        SlideLayer(
          int.tryParse(_cNvPr(e)!.getAttribute('id') ?? '') ?? 0,
          _cNvPr(e)!.getAttribute('name') ?? '',
          e.name.local,
          const {'1', 'true'}.contains(_cNvPr(e)!.getAttribute('hidden')),
          _frame(e),
        ),
    ];
  }

  static XmlElement _shape(XmlDocument d, int id) {
    for (final e in _shapes(d)) {
      if (_cNvPr(e)!.getAttribute('id') == '$id') return e;
    }
    throw StateError('shape $id');
  }

  static PptxOp setHidden(int slide, int id, bool hidden) => (pkg) {
        final c = _cNvPr(_shape(pkg.edit(pkg.slidePart(slide))!, id))!;
        hidden ? c.setAttribute('hidden', '1') : c.removeAttribute('hidden');
      };

  static PptxOp rename(int slide, int id, String name) => (pkg) {
        _cNvPr(_shape(pkg.edit(pkg.slidePart(slide))!, id))!
            .setAttribute('name', name.trim());
      };

  /// Şekli z sırasında [to] konumuna taşır (0 = en arka).
  static PptxOp moveLayer(int slide, int id, int to) => (pkg) {
        final d = pkg.edit(pkg.slidePart(slide))!;
        final list = _shapes(d);
        final el = _shape(d, id);
        final tree = PptxPackage.spTree(d)!;
        list.remove(el);
        final i = to.clamp(0, list.length);
        tree.children.remove(el);
        if (i >= list.length) {
          final ext = tree.getElement('p:extLst');
          tree.children.insert(
              ext == null ? tree.children.length : tree.children.indexOf(ext), el);
        } else {
          tree.children.insert(tree.children.indexOf(list[i]), el);
        }
      };

  // ── Hizala / dağıt ───────────────────────────────────────────────────────

  /// Tek şekil → slayta göre; çoklu → seçimin sınır kutusuna göre.
  static PptxOp align(int slide, List<int> ids, SlideAlign mode) => (pkg) {
        final d = pkg.edit(pkg.slidePart(slide))!;
        final els = [for (final id in ids) _shape(d, id)]
            .where((e) => _frame(e) != null)
            .toList();
        if (els.isEmpty) return;
        final (sw, sh) = pkg.slideSize();
        var l = 0, t = 0, r = sw, b = sh;
        if (els.length > 1) {
          final fs = [for (final e in els) _frame(e)!];
          l = fs.map((f) => f[0]).reduce((a, c) => a < c ? a : c);
          t = fs.map((f) => f[1]).reduce((a, c) => a < c ? a : c);
          r = fs.map((f) => f[0] + f[2]).reduce((a, c) => a > c ? a : c);
          b = fs.map((f) => f[1] + f[3]).reduce((a, c) => a > c ? a : c);
        }
        for (final e in els) {
          final f = _frame(e)!;
          final (x, y) = switch (mode) {
            SlideAlign.left => (l, f[1]),
            SlideAlign.hcenter => ((l + r - f[2]) ~/ 2, f[1]),
            SlideAlign.right => (r - f[2], f[1]),
            SlideAlign.top => (f[0], t),
            SlideAlign.vcenter => (f[0], (t + b - f[3]) ~/ 2),
            SlideAlign.bottom => (f[0], b - f[3]),
          };
          _setOff(e, x, y);
        }
      };

  /// Eşit aralıkla dağıtır (en az 3 şekil; uçtakiler yerinde kalır).
  static PptxOp distribute(int slide, List<int> ids, {required bool horizontal}) =>
      (pkg) {
        final d = pkg.edit(pkg.slidePart(slide))!;
        final els = [for (final id in ids) _shape(d, id)]
            .where((e) => _frame(e) != null)
            .toList();
        if (els.length < 3) throw StateError('distribute');
        final a = horizontal ? 0 : 1, s = horizontal ? 2 : 3;
        els.sort((p, q) => _frame(p)![a].compareTo(_frame(q)![a]));
        final first = _frame(els.first)!, last = _frame(els.last)!;
        final span = last[a] + last[s] - first[a];
        final total = els.fold<int>(0, (acc, e) => acc + _frame(e)![s]);
        final gap = (span - total) / (els.length - 1);
        var pos = first[a] + first[s] + gap;
        for (final e in els.sublist(1, els.length - 1)) {
          final f = _frame(e)!;
          horizontal ? _setOff(e, pos.round(), f[1]) : _setOff(e, f[0], pos.round());
          pos += f[s] + gap;
        }
      };

  // ── Animasyon sırası ─────────────────────────────────────────────────────

  static XmlElement? _mainList(XmlDocument d) {
    final timing = d.rootElement.getElement('p:timing');
    if (timing == null) return null;
    for (final c in timing.findAllElements('p:cTn')) {
      if (c.getAttribute('nodeType') == 'mainSeq') return c.getElement('p:childTnLst');
    }
    return null;
  }

  static List<SlideAnimStep> animations(PptxPackage pkg, int slide) {
    final d = pkg.xml(pkg.slidePart(slide));
    final list = d == null ? null : _mainList(d);
    if (list == null) return const [];
    return [
      for (final par in list.findElements('p:par'))
        () {
          final ids = <int>[];
          for (final t in par.findAllElements('p:spTgt')) {
            final v = int.tryParse(t.getAttribute('spid') ?? '');
            if (v != null && !ids.contains(v)) ids.add(v);
          }
          final eff = par
              .findAllElements('p:cTn')
              .where((c) => c.getAttribute('presetClass') != null)
              .firstOrNull;
          return SlideAnimStep(ids, eff?.getAttribute('presetClass') ?? '',
              int.tryParse(eff?.getAttribute('presetID') ?? '') ?? 0);
        }(),
    ];
  }

  /// cTn kimlikleri benzersiz olmalı: işlemden sonra 1'den yeniden sayılır.
  static void _renumber(XmlDocument d) {
    var n = 1;
    for (final c in d.rootElement.getElement('p:timing')?.findAllElements('p:cTn') ??
        const <XmlElement>[]) {
      c.setAttribute('id', '${n++}');
    }
  }

  static PptxOp moveAnimation(int slide, int from, int to) => (pkg) {
        final d = pkg.edit(pkg.slidePart(slide))!;
        final list = _mainList(d);
        final pars = list?.findElements('p:par').toList() ?? const [];
        if (from < 0 || from >= pars.length) return;
        final el = pars[from];
        list!.children.remove(el);
        final rest = list.findElements('p:par').toList();
        final i = to.clamp(0, rest.length);
        list.children.insert(
            i >= rest.length ? list.children.length : list.children.indexOf(rest[i]), el);
        _renumber(d);
      };

  static PptxOp removeAnimation(int slide, int index) => (pkg) {
        final d = pkg.edit(pkg.slidePart(slide))!;
        final list = _mainList(d);
        final pars = list?.findElements('p:par').toList() ?? const [];
        if (index < 0 || index >= pars.length) return;
        list!.children.remove(pars[index]);
        // Metin animasyonunun derleme kaydı (bldP) artık hedefsizse temizlenir.
        final left = {
          for (final t in d.rootElement.getElement('p:timing')!.findAllElements('p:spTgt'))
            t.getAttribute('spid'),
        };
        d.rootElement
            .getElement('p:timing')
            ?.getElement('p:bldLst')
            ?.children
            .removeWhere((n) => n is XmlElement && !left.contains(n.getAttribute('spid')));
        _renumber(d);
      };

  static const _timingSkeleton = '<p:timing><p:tnLst><p:par>'
      '<p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot"><p:childTnLst>'
      '<p:seq concurrent="1" nextAc="seek"><p:cTn id="2" dur="indefinite" nodeType="mainSeq"><p:childTnLst/></p:cTn>'
      '<p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>'
      '<p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>'
      '</p:seq></p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>';

  /// Tıklamayla gelen yeni giriş efekti (sona eklenir).
  static PptxOp addEntrance(int slide, int shapeId, SlideEntrance effect) => (pkg) {
        final d = pkg.edit(pkg.slidePart(slide))!;
        _shape(d, shapeId); // yoksa hata
        var list = _mainList(d);
        if (list == null) {
          d.rootElement.children.removeWhere(
              (n) => n is XmlElement && n.name.qualified == 'p:timing');
          final ext = d.rootElement.getElement('p:extLst');
          final kids = d.rootElement.children;
          kids.insert(ext == null ? kids.length : kids.indexOf(ext),
              PptxPackage.frag(_timingSkeleton));
          list = _mainList(d)!;
        }
        final tgt = '<p:tgtEl><p:spTgt spid="$shapeId"/></p:tgtEl>';
        const cond0 = '<p:stCondLst><p:cond delay="0"/></p:stCondLst>';
        final set = '<p:set><p:cBhvr><p:cTn id="0" dur="1" fill="hold">$cond0</p:cTn>$tgt'
            '<p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr>'
            '<p:to><p:strVal val="visible"/></p:to></p:set>';
        final (preset, sub, extra) = switch (effect) {
          SlideEntrance.appear => (1, 0, ''),
          SlideEntrance.fade => (10, 0,
              '<p:animEffect transition="in" filter="fade"><p:cBhvr><p:cTn id="0" dur="500"/>$tgt</p:cBhvr></p:animEffect>'),
          SlideEntrance.wipe => (22, 4,
              '<p:animEffect transition="in" filter="wipe(down)"><p:cBhvr><p:cTn id="0" dur="500"/>$tgt</p:cBhvr></p:animEffect>'),
          SlideEntrance.zoom => (53, 16,
              '<p:anim calcmode="lin" valueType="num"><p:cBhvr><p:cTn id="0" dur="500" fill="hold"/>$tgt'
                  '<p:attrNameLst><p:attrName>ppt_w</p:attrName></p:attrNameLst></p:cBhvr><p:tavLst>'
                  '<p:tav tm="0"><p:val><p:fltVal val="0"/></p:val></p:tav>'
                  '<p:tav tm="100000"><p:val><p:strVal val="#ppt_w"/></p:val></p:tav></p:tavLst></p:anim>'
                  '<p:anim calcmode="lin" valueType="num"><p:cBhvr><p:cTn id="0" dur="500" fill="hold"/>$tgt'
                  '<p:attrNameLst><p:attrName>ppt_h</p:attrName></p:attrNameLst></p:cBhvr><p:tavLst>'
                  '<p:tav tm="0"><p:val><p:fltVal val="0"/></p:val></p:tav>'
                  '<p:tav tm="100000"><p:val><p:strVal val="#ppt_h"/></p:val></p:tav></p:tavLst></p:anim>'
                  '<p:animEffect transition="in" filter="fade"><p:cBhvr><p:cTn id="0" dur="500"/>$tgt</p:cBhvr></p:animEffect>'),
        };
        list.children.add(PptxPackage.frag('<p:par><p:cTn id="0" fill="hold">'
            '<p:stCondLst><p:cond delay="indefinite"/></p:stCondLst><p:childTnLst>'
            '<p:par><p:cTn id="0" fill="hold">$cond0<p:childTnLst>'
            '<p:par><p:cTn id="0" presetID="$preset" presetClass="entr" presetSubtype="$sub" fill="hold" nodeType="clickEffect">'
            '$cond0<p:childTnLst>$set$extra</p:childTnLst></p:cTn></p:par>'
            '</p:childTnLst></p:cTn></p:par>'
            '</p:childTnLst></p:cTn></p:par>'));
        _renumber(d);
      };
}
