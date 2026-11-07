import 'package:xml/xml.dart';

import 'pptx_package.dart';

/// Temanın 12 renk yuvası (ECMA-376 `a:clrScheme` sırası).
const kThemeSlots = [
  'dk1', 'lt1', 'dk2', 'lt2', //
  'accent1', 'accent2', 'accent3', 'accent4', 'accent5', 'accent6',
  'hlink', 'folHlink',
];

/// Tema: renk yuvaları (6 haneli hex, `#`siz) + başlık/gövde yazı tipi.
class PptxThemeInfo {
  final String part;
  final String name;
  final Map<String, String> colors;
  final String major, minor;
  const PptxThemeInfo(
      this.part, this.name, this.colors, this.major, this.minor);
}

/// Ana slayt/yerleşimdeki yer tutucu (konum EMU).
class PptxPlaceholderInfo {
  final int id;
  final String name;

  /// `p:ph@type` (yoksa `body`).
  final String type;
  final String? idx;
  final int x, y, cx, cy;

  /// Kendi `a:xfrm`'i yok — konumu ana slayttan miras alıyor.
  final bool inherited;
  const PptxPlaceholderInfo(this.id, this.name, this.type, this.idx, this.x,
      this.y, this.cx, this.cy, {this.inherited = false});
}

class PptxLayoutDetail {
  final String part;
  final String name;
  final String? type;
  final List<PptxPlaceholderInfo> placeholders;
  const PptxLayoutDetail(this.part, this.name, this.type, this.placeholders);
}

class PptxMasterInfo {
  final String part;
  final String? theme;
  final List<PptxPlaceholderInfo> placeholders;
  final List<PptxLayoutDetail> layouts;

  /// Başlık ve gövde 1. düzey puntosu (`p:txStyles`), yoksa null.
  final double? titlePt, bodyPt;

  /// Ana slayt arka planı düz renkse hex'i.
  final String? background;
  const PptxMasterInfo(this.part, this.theme, this.placeholders, this.layouts,
      this.titlePt, this.bodyPt, this.background);
}

/// Yer tutucu türleri — "yer tutucu ekle" menüsü bu sırayla.
const kPlaceholderTypes = [
  'title', 'body', 'pic', 'chart', 'tbl', 'media', 'dt', 'ftr', 'sldNum',
];

/// **Faz 38 / madde 1 — ana slayt / yerleşim düzenleme.** Tema renk ve yazı
/// tipleri, ana slayt metin stilleri ve arka planı, yerleşimin yer tutucuları
/// (taşı/boyutlandır/ekle/sil), yerleşim adı ve kopyası.
abstract final class PptxMasterOps {
  static const _layoutCt =
      'application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml';

  // ── Okuma ────────────────────────────────────────────────────────────────

  static PptxThemeInfo? theme(PptxPackage pkg, {int master = 0}) {
    final masters = pkg.masters();
    if (masters.isEmpty) return null;
    final part = pkg.themeOf(masters[master.clamp(0, masters.length - 1)]);
    final d = part == null ? null : pkg.xml(part);
    if (d == null) return null;
    final scheme = d.findAllElements('a:clrScheme').firstOrNull;
    final colors = <String, String>{};
    for (final slot in kThemeSlots) {
      final el = scheme?.getElement('a:$slot');
      final c = el?.childElements.firstOrNull;
      final v = c?.name.qualified == 'a:sysClr'
          ? c?.getAttribute('lastClr')
          : c?.getAttribute('val');
      colors[slot] = (v ?? '000000').toUpperCase();
    }
    String font(String tag) =>
        d
            .findAllElements(tag)
            .firstOrNull
            ?.getElement('a:latin')
            ?.getAttribute('typeface') ??
        '';
    return PptxThemeInfo(
      part!,
      d.rootElement.getAttribute('name') ?? '',
      colors,
      font('a:majorFont'),
      font('a:minorFont'),
    );
  }

  static List<PptxPlaceholderInfo> placeholders(PptxPackage pkg, String part) {
    final d = pkg.xml(part);
    if (d == null) return const [];
    final out = <PptxPlaceholderInfo>[];
    // Mirası çözmek için ana slaytın yer tutucuları (yerleşimde xfrm yoksa).
    final master = pkg.masterOf(part);
    final inherit = master == null ? const <PptxPlaceholderInfo>[] : placeholders(pkg, master);
    for (final sp in PptxPackage.spTree(d)?.childElements ?? const <XmlElement>[]) {
      final ph = sp.findAllElements('p:ph').firstOrNull;
      if (ph == null) continue;
      final c = sp.findAllElements('p:cNvPr').firstOrNull;
      final type = ph.getAttribute('type') ?? 'body';
      final idx = ph.getAttribute('idx');
      final xfrm = sp.getElement('p:spPr')?.getElement('a:xfrm');
      final off = xfrm?.getElement('a:off');
      final ext = xfrm?.getElement('a:ext');
      int v(XmlElement? e, String a) => int.tryParse(e?.getAttribute(a) ?? '') ?? 0;
      if (xfrm == null) {
        final base = inherit
            .where((p) => p.type == type || (type == 'body' && p.type == 'body'))
            .firstOrNull;
        out.add(PptxPlaceholderInfo(
          int.tryParse(c?.getAttribute('id') ?? '') ?? 0,
          c?.getAttribute('name') ?? type,
          type,
          idx,
          base?.x ?? 0,
          base?.y ?? 0,
          base?.cx ?? 0,
          base?.cy ?? 0,
          inherited: true,
        ));
        continue;
      }
      out.add(PptxPlaceholderInfo(
        int.tryParse(c?.getAttribute('id') ?? '') ?? 0,
        c?.getAttribute('name') ?? type,
        type,
        idx,
        v(off, 'x'),
        v(off, 'y'),
        v(ext, 'cx'),
        v(ext, 'cy'),
      ));
    }
    return out;
  }

  static List<PptxMasterInfo> masters(PptxPackage pkg) {
    final out = <PptxMasterInfo>[];
    for (final m in pkg.masters()) {
      final d = pkg.xml(m);
      if (d == null) continue;
      double? lvl1(String style) {
        final sz = d
            .findAllElements(style)
            .firstOrNull
            ?.getElement('a:lvl1pPr')
            ?.getElement('a:defRPr')
            ?.getAttribute('sz');
        final n = int.tryParse(sz ?? '');
        return n == null ? null : n / 100;
      }

      final bg = d
          .findAllElements('p:bgPr')
          .firstOrNull
          ?.getElement('a:solidFill')
          ?.getElement('a:srgbClr')
          ?.getAttribute('val');
      out.add(PptxMasterInfo(
        m,
        pkg.themeOf(m),
        placeholders(pkg, m),
        [
          for (final l in pkg.layoutsOf(m))
            PptxLayoutDetail(
              l,
              pkg.xml(l)?.findAllElements('p:cSld').firstOrNull?.getAttribute('name') ?? '',
              pkg.xml(l)?.rootElement.getAttribute('type'),
              placeholders(pkg, l),
            ),
        ],
        lvl1('p:titleStyle'),
        lvl1('p:bodyStyle'),
        bg?.toUpperCase(),
      ));
    }
    return out;
  }

  // ── Tema ─────────────────────────────────────────────────────────────────

  static Iterable<String> _themes(PptxPackage pkg, int? master) sync* {
    final ms = pkg.masters();
    for (var i = 0; i < ms.length; i++) {
      if (master != null && i != master) continue;
      if (pkg.themeOf(ms[i]) case final t?) yield t;
    }
  }

  /// Tema renklerini yazar ([hex] yuva → `RRGGBB`). [master] null → hepsi.
  static PptxOp setThemeColors(Map<String, String> hex, {int? master}) =>
      (pkg) {
        for (final t in _themes(pkg, master)) {
          final scheme = pkg.edit(t)?.findAllElements('a:clrScheme').firstOrNull;
          if (scheme == null) continue;
          for (final MapEntry(:key, :value) in hex.entries) {
            if (!kThemeSlots.contains(key)) continue;
            final v = value.replaceAll('#', '').toUpperCase();
            if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(v)) continue;
            var el = scheme.getElement('a:$key');
            if (el == null) {
              el = XmlElement(XmlName.qualified('a:$key'));
              // ECMA sırası korunur: yuvayı doğru yere koy.
              final at = kThemeSlots.indexOf(key);
              final after = scheme.childElements
                  .where((e) => kThemeSlots.indexOf(e.name.local) < at)
                  .lastOrNull;
              final kids = scheme.children;
              kids.insert(after == null ? 0 : kids.indexOf(after) + 1, el);
            }
            el.children
              ..clear()
              ..add(PptxPackage.frag('<a:srgbClr val="$v"/>'));
          }
        }
      };

  static PptxOp setThemeFonts(String major, String minor, {int? master}) =>
      (pkg) {
        for (final t in _themes(pkg, master)) {
          final d = pkg.edit(t);
          if (d == null) continue;
          for (final (tag, face) in [('a:majorFont', major), ('a:minorFont', minor)]) {
            if (face.trim().isEmpty) continue;
            final f = d.findAllElements(tag).firstOrNull;
            final latin = f?.getElement('a:latin');
            if (latin != null) {
              latin.setAttribute('typeface', face.trim());
            } else {
              f?.children.insert(0, PptxPackage.frag(
                  '<a:latin typeface="${PptxPackage.esc(face.trim())}"/>'));
            }
          }
        }
      };

  // ── Ana slayt metin stili / arka plan ─────────────────────────────────────

  /// Başlık / gövde 1. düzey puntosu; gövdenin alt düzeyleri aynı oranla.
  static PptxOp setMasterTextStyle(
          {int? master, double? titlePt, double? bodyPt, String? titleColor}) =>
      (pkg) {
        final ms = pkg.masters();
        for (var i = 0; i < ms.length; i++) {
          if (master != null && i != master) continue;
          final d = pkg.edit(ms[i]);
          if (d == null) continue;
          void scale(String style, double? pt, {String? color}) {
            if (pt == null && color == null) return;
            var st = d.findAllElements(style).firstOrNull;
            if (st == null) {
              // Stil yoksa (ör. sıfırdan üretilmiş deste) kurulur. ECMA sırası:
              // … hf, txStyles, extLst; txStyles içinde title, body, other.
              var tx = d.rootElement.getElement('p:txStyles');
              if (tx == null) {
                tx = XmlElement(const XmlName.qualified('p:txStyles'));
                final ext = d.rootElement.getElement('p:extLst');
                final kids = d.rootElement.children;
                kids.insert(ext == null ? kids.length : kids.indexOf(ext), tx);
              }
              st = PptxPackage.frag('<$style><a:lvl1pPr><a:defRPr/></a:lvl1pPr></$style>');
              final title = style == 'p:titleStyle';
              tx.children.insert(title ? 0 : tx.children.length, st);
            }
            var l1p = st.getElement('a:lvl1pPr');
            if (l1p == null) {
              l1p = PptxPackage.frag('<a:lvl1pPr><a:defRPr/></a:lvl1pPr>');
              st.children.insert(0, l1p);
            }
            var l1 = l1p.getElement('a:defRPr');
            if (l1 == null) {
              l1 = XmlElement(const XmlName.qualified('a:defRPr'));
              l1p.children.add(l1);
            }
            final old = int.tryParse(l1.getAttribute('sz') ?? '');
            if (pt != null) {
              final k = old == null || old == 0 ? 1.0 : pt * 100 / old;
              for (var lvl = 1; lvl <= 9; lvl++) {
                final r = st.getElement('a:lvl${lvl}pPr')?.getElement('a:defRPr');
                if (r == null) continue;
                final s = int.tryParse(r.getAttribute('sz') ?? '');
                final next = lvl == 1 || s == null ? pt * 100 : s * k;
                r.setAttribute('sz', '${next.round().clamp(100, 400000)}');
              }
            }
            if (color != null) {
              l1.children.removeWhere((n) =>
                  n is XmlElement && n.name.local.endsWith('Fill'));
              l1.children.insert(0, PptxPackage.frag(
                  '<a:solidFill><a:srgbClr val="${color.replaceAll('#', '')}"/></a:solidFill>'));
            }
          }

          scale('p:titleStyle', titlePt, color: titleColor);
          scale('p:bodyStyle', bodyPt);
        }
      };

  /// Ana slayt arka planı (düz renk; null → temadaki `bg1`).
  static PptxOp setMasterBackground(String? hex, {int? master}) => (pkg) {
        final ms = pkg.masters();
        for (var i = 0; i < ms.length; i++) {
          if (master != null && i != master) continue;
          final d = pkg.edit(ms[i]);
          final cSld = d?.findAllElements('p:cSld').firstOrNull;
          if (cSld == null) continue;
          cSld.children.removeWhere((n) => n is XmlElement && n.name.qualified == 'p:bg');
          final fill = hex == null
              ? '<a:solidFill><a:schemeClr val="bg1"/></a:solidFill>'
              : '<a:solidFill><a:srgbClr val="${hex.replaceAll('#', '')}"/></a:solidFill>';
          cSld.children.insert(0,
              PptxPackage.frag('<p:bg><p:bgPr>$fill<a:effectLst/></p:bgPr></p:bg>'));
        }
      };

  // ── Yer tutucular ─────────────────────────────────────────────────────────

  /// Yer tutucunun konum/boyutu (EMU). Mirasçı yer tutucuya kendi xfrm'i yazılır.
  static PptxOp setPlaceholderFrame(
          String part, int shapeId, int x, int y, int cx, int cy) =>
      (pkg) {
        final d = pkg.edit(part);
        final sp = d == null ? null : PptxPackage.shapeById(d, shapeId);
        if (sp == null) throw StateError('placeholder');
        var spPr = sp.getElement('p:spPr');
        if (spPr == null) {
          spPr = XmlElement(const XmlName.qualified('p:spPr'));
          final nv = sp.getElement('p:nvSpPr');
          sp.children.insert(nv == null ? 0 : sp.children.indexOf(nv) + 1, spPr);
        }
        spPr.children.removeWhere((n) => n is XmlElement && n.name.qualified == 'a:xfrm');
        spPr.children.insert(
            0,
            PptxPackage.frag('<a:xfrm><a:off x="${x.clamp(0, 1 << 30)}" '
                'y="${y.clamp(0, 1 << 30)}"/><a:ext cx="${cx.clamp(1, 1 << 30)}" '
                'cy="${cy.clamp(1, 1 << 30)}"/></a:xfrm>'));
      };

  static String _phLabel(String type) => switch (type) {
        'title' => 'Başlık',
        'pic' => 'Resim',
        'chart' => 'Grafik',
        'tbl' => 'Tablo',
        'media' => 'Medya',
        'dt' => 'Tarih',
        'ftr' => 'Alt bilgi',
        'sldNum' => 'Slayt no',
        _ => 'Metin',
      };

  /// Yerleşime (ya da ana slayta) yeni yer tutucu ekler; yeni şekil kimliği.
  static PptxOp addPlaceholder(String part, String type) => (pkg) {
        final d = pkg.edit(part);
        final tree = d == null ? null : PptxPackage.spTree(d);
        if (d == null || tree == null) throw StateError('layout');
        final (w, h) = pkg.slideSize();
        final id = PptxPackage.nextShapeId(d);
        var idx = 10;
        for (final ph in d.findAllElements('p:ph')) {
          final v = int.tryParse(ph.getAttribute('idx') ?? '') ?? 0;
          if (v >= idx) idx = v + 1;
        }
        final (x, y, cx, cy) = switch (type) {
          'title' => (w ~/ 12, h ~/ 20, w * 10 ~/ 12, h ~/ 6),
          'dt' => (w ~/ 24, h * 9 ~/ 10, w ~/ 4, h ~/ 16),
          'ftr' => (w * 3 ~/ 8, h * 9 ~/ 10, w ~/ 4, h ~/ 16),
          'sldNum' => (w * 17 ~/ 24, h * 9 ~/ 10, w ~/ 4, h ~/ 16),
          _ => (w ~/ 6, h ~/ 4, w * 2 ~/ 3, h ~/ 2),
        };
        final typeAttr = type == 'body' ? '' : ' type="$type"';
        final idxAttr = type == 'title' ? '' : ' idx="$idx"';
        final label = _phLabel(type);
        final text = switch (type) {
          'pic' || 'chart' || 'tbl' || 'media' || 'sldNum' || 'dt' => '',
          _ => '<a:r><a:rPr lang="tr-TR"/><a:t>$label</a:t></a:r>',
        };
        tree.children.add(PptxPackage.frag('<p:sp><p:nvSpPr>'
            '<p:cNvPr id="$id" name="$label $id"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
            '<p:nvPr><p:ph$typeAttr$idxAttr/></p:nvPr></p:nvSpPr>'
            '<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/></a:xfrm></p:spPr>'
            '<p:txBody><a:bodyPr/><a:lstStyle/><a:p>$text</a:p></p:txBody></p:sp>'));
      };

  static PptxOp removePlaceholder(String part, int shapeId) => (pkg) {
        final d = pkg.edit(part);
        final sp = d == null ? null : PptxPackage.shapeById(d, shapeId);
        sp?.parent?.children.remove(sp);
      };

  // ── Yerleşim adı / kopya ──────────────────────────────────────────────────

  static PptxOp renameLayout(String layout, String name) => (pkg) {
        pkg
            .edit(layout)
            ?.findAllElements('p:cSld')
            .firstOrNull
            ?.setAttribute('name', name.trim());
      };

  /// Yerleşimi kopyalar (aynı ana slayt altında, listenin sonuna).
  static PptxOp duplicateLayout(String layout, String name) => (pkg) {
        final src = pkg.xml(layout);
        final master = pkg.masterOf(layout);
        if (src == null || master == null) throw StateError('layout');
        final part = pkg.freeName('ppt/slideLayouts/slideLayout', 'xml');
        final copy = XmlDocument.parse(src.toXmlString());
        copy.findAllElements('p:cSld').firstOrNull?.setAttribute('name', name.trim());
        // Kopya "özel" yerleşimdir; `type` tekil olmalı (title, obj …).
        copy.rootElement.removeAttribute('type');
        copy.rootElement.removeAttribute('preserve');
        pkg.putXml(part, copy.toXmlString());
        for (final r in pkg.rels(layout)) {
          if (r.external) continue;
          pkg.addRel(part, r.type, r.target);
        }
        // Kopyanın ilişki kimlikleri yeniden numaralandı → eski rId'ler
        // eşlenmeli. addRel sırayla rId1.. verdiği için aynı sırayla eşle.
        final oldIds = [for (final r in pkg.rels(layout)) if (!r.external) r.id];
        final map = <String, String>{
          for (var i = 0; i < oldIds.length; i++) oldIds[i]: 'rId${i + 1}'
        };
        final d = pkg.edit(part)!;
        for (final e in d.descendantElements) {
          final fix = [
            for (final a in e.attributes)
              if (a.name.prefix == 'r' && map.containsKey(a.value))
                (a.name.qualified, map[a.value]!),
          ];
          for (final (n, v) in fix) {
            e.setAttribute(n, v);
          }
        }
        pkg.addOverride(part, _layoutCt);
        final rid = pkg.addRel(master, 'slideLayout', part);
        final md = pkg.edit(master)!;
        var lst = md.findAllElements('p:sldLayoutIdLst').firstOrNull;
        if (lst == null) {
          lst = XmlElement(const XmlName.qualified('p:sldLayoutIdLst'));
          final tx = md.findAllElements('p:txStyles').firstOrNull;
          final root = md.rootElement.children;
          root.insert(tx == null ? root.length : root.indexOf(tx), lst);
        }
        // Kimlik: ana slayt + tüm yerleşim kimliklerinden büyük (≥ 2^31).
        var maxId = 2147483648;
        for (final m in pkg.masters()) {
          for (final e in [
            ...?pkg.xml(m)?.findAllElements('p:sldLayoutId'),
          ]) {
            final v = int.tryParse(e.getAttribute('id') ?? '') ?? 0;
            if (v > maxId) maxId = v;
          }
        }
        for (final e in pkg.xml(PptxPackage.presentation)?.findAllElements('p:sldMasterId') ??
            const <XmlElement>[]) {
          final v = int.tryParse(e.getAttribute('id') ?? '') ?? 0;
          if (v > maxId) maxId = v;
        }
        lst.children.add(PptxPackage.frag(
            '<p:sldLayoutId id="${maxId + 1}" r:id="$rid"/>'));
      };
}
