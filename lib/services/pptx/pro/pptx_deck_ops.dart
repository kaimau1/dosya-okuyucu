import 'dart:math' as math;

import 'package:xml/xml.dart';

import 'pptx_package.dart';

/// Bir bölüm: ad + destedeki ilk slaytın sırası (0 tabanlı) + slayt sayısı.
class SlideSection {
  final String name;
  final int start, count;
  const SlideSection(this.name, this.start, this.count);
}

/// Özel gösteri: ad + slayt sıraları (destedeki, 0 tabanlı; gösteri sırası).
class SlideCustomShow {
  final String name;
  final List<int> slides;
  const SlideCustomShow(this.name, this.slides);
}

/// **Faz 38 / madde 7 — bölümler ve özel gösteriler.** Bölümler
/// `p14:sectionLst` (presentation.xml extLst), özel gösteriler `p:custShowLst`.
/// Bölümler slayt SIRASIYLA bitişiktir: her bölüm ilk slaytından bir sonraki
/// bölümün ilk slaytına kadar sürer ([normalize], editör kaydında da koşar).
abstract final class PptxDeckOps {
  static const _sectionExt = '{521415D9-36F7-43E2-AB2F-B90AF26B5E84}';

  static List<String> _order(XmlDocument pres) => [
        for (final e in pres.findAllElements('p:sldId')) e.getAttribute('id') ?? '',
      ];

  static XmlElement? _sectionLst(XmlDocument pres) =>
      pres.findAllElements('p14:sectionLst').firstOrNull;

  /// Bölüm üyeliklerini slayt sırasına göre yeniden kurar. Silinen slayt
  /// düşer, üyesiz bölüm silinir, ilk bölümden önceki slaytlar ilk bölüme
  /// katılır. Bölüm yoksa dokunmaz.
  static void normalize(XmlDocument pres) {
    final lst = _sectionLst(pres);
    if (lst == null) return;
    final order = _order(pres);
    final pos = {for (var i = 0; i < order.length; i++) order[i]: i};
    final secs = <(int, XmlElement)>[];
    for (final s in lst.findElements('p14:section')) {
      final ids = [
        for (final e in s.findAllElements('p14:sldId'))
          ?pos[e.getAttribute('id')],
      ];
      if (ids.isEmpty) continue;
      secs.add((ids.reduce(math.min), s));
    }
    secs.sort((a, b) => a.$1.compareTo(b.$1));
    lst.children.clear();
    for (var i = 0; i < secs.length; i++) {
      final from = i == 0 ? 0 : secs[i].$1;
      final to = i + 1 < secs.length ? secs[i + 1].$1 : order.length;
      final s = secs[i].$2;
      s.children.removeWhere(
          (n) => n is XmlElement && n.name.qualified == 'p14:sldIdLst');
      s.children.add(PptxPackage.frag('<p14:sldIdLst>'
          '${[for (var k = from; k < to; k++) '<p14:sldId id="${order[k]}"/>'].join()}'
          '</p14:sldIdLst>'));
      lst.children.add(s);
    }
    if (secs.isEmpty) {
      // Boş bölüm listesi geçersiz değil ama anlamsız: uzantıyı kaldır.
      final ext = lst.parentElement;
      ext?.parent?.children.remove(ext);
    }
  }

  static List<SlideSection> sections(PptxPackage pkg) {
    final pres = pkg.xml(PptxPackage.presentation);
    if (pres == null) return const [];
    final copy = XmlDocument.parse(pres.toXmlString());
    normalize(copy);
    final lst = _sectionLst(copy);
    if (lst == null) return const [];
    final order = _order(copy);
    return [
      for (final s in lst.findElements('p14:section'))
        () {
          final ids = [for (final e in s.findAllElements('p14:sldId')) e.getAttribute('id')];
          return SlideSection(s.getAttribute('name') ?? '',
              ids.isEmpty ? 0 : order.indexOf(ids.first ?? ''), ids.length);
        }(),
    ];
  }

  static String _guid(int seed) {
    final r = math.Random(seed);
    String h(int n) => [for (var i = 0; i < n; i++) r.nextInt(16).toRadixString(16)].join().toUpperCase();
    return '{${h(8)}-${h(4)}-4${h(3)}-A${h(3)}-${h(12)}}';
  }

  static XmlElement _ensureSectionLst(XmlDocument pres) {
    final have = _sectionLst(pres);
    if (have != null) return have;
    final root = pres.rootElement;
    var extLst = root.getElement('p:extLst');
    if (extLst == null) {
      extLst = XmlElement(XmlName.fromString('p:extLst'));
      root.children.add(extLst); // extLst her zaman sonda
    }
    final ext = PptxPackage.frag('<p:ext uri="$_sectionExt">'
        '<p14:sectionLst xmlns:p14="${PptxPackage.nsP14}"/></p:ext>');
    extLst.children.insert(0, ext);
    return _sectionLst(pres)!;
  }

  /// [start] sırasındaki slayttan başlayan bölüm ekler (o slayt zaten bir
  /// bölümün başıysa adını değiştirir). Bölüm yokken ilk ekleme, öncesini
  /// "Varsayılan Bölüm" yapar.
  static PptxOp addSection(int start, String name, {String defaultName = 'Varsayılan Bölüm'}) =>
      (pkg) {
        final pres = pkg.edit(PptxPackage.presentation)!;
        final order = _order(pres);
        if (start < 0 || start >= order.length) throw RangeError.index(start, order);
        final fresh = _sectionLst(pres) == null;
        final lst = _ensureSectionLst(pres);
        String sec(String n, int seed, Iterable<String> ids) =>
            '<p14:section name="${PptxPackage.esc(n.trim())}" id="${_guid(seed)}"><p14:sldIdLst>'
            '${ids.map((i) => '<p14:sldId id="$i"/>').join()}</p14:sldIdLst></p14:section>';
        if (fresh || lst.findElements('p14:section').isEmpty) {
          if (start > 0) {
            lst.children.add(PptxPackage.frag(sec(defaultName, order.length, order.take(start))));
          }
          lst.children.add(PptxPackage.frag(sec(name, order.length + start + 1, order.skip(start))));
          return;
        }
        normalize(pres);
        final secs = _sectionLst(pres)!.findElements('p14:section').toList();
        for (final s in secs) {
          final first = s.findAllElements('p14:sldId').firstOrNull?.getAttribute('id');
          if (first == order[start]) {
            s.setAttribute('name', name.trim()); // zaten bölüm başı: adlandır
            return;
          }
        }
        // Yeni bölüm başlangıç slaytını alır; [normalize] aralığı kurar
        // (her bölüm en küçük üyesinden bir sonrakinin başına dek).
        for (final s in secs) {
          s.findAllElements('p14:sldId')
              .where((e) => e.getAttribute('id') == order[start])
              .toList()
              .forEach((e) => e.parent?.children.remove(e));
        }
        _sectionLst(pres)!
            .children
            .add(PptxPackage.frag(sec(name, order.length * 31 + start, [order[start]])));
        normalize(pres);
      };

  static PptxOp renameSection(int index, String name) => (pkg) {
        final pres = pkg.edit(PptxPackage.presentation)!;
        normalize(pres);
        final s = _sectionLst(pres)?.findElements('p14:section').elementAtOrNull(index);
        s?.setAttribute('name', name.trim());
      };

  /// Bölümü kaldırır; slaytları bir önceki bölüme katılır (ilkse sonrakine).
  static PptxOp removeSection(int index) => (pkg) {
        final pres = pkg.edit(PptxPackage.presentation)!;
        normalize(pres);
        final lst = _sectionLst(pres);
        final secs = lst?.findElements('p14:section').toList() ?? const [];
        if (index < 0 || index >= secs.length) return;
        final gone = secs[index];
        final ids = gone.findAllElements('p14:sldId').map((e) => e.copy()).toList();
        lst!.children.remove(gone);
        final into = index > 0 ? secs[index - 1] : (secs.length > 1 ? secs[1] : null);
        into?.getElement('p14:sldIdLst')?.children.addAll(ids);
        normalize(pres);
      };

  /// Bölümü bütün slaytlarıyla [delta] kadar taşır (-1 yukarı, +1 aşağı).
  /// Slayt sırası değişir (sldIdLst yeniden yazılır).
  static PptxOp moveSection(int index, int delta) => (pkg) {
        final pres = pkg.edit(PptxPackage.presentation)!;
        normalize(pres);
        final lst = _sectionLst(pres);
        final secs = lst?.findElements('p14:section').toList() ?? const [];
        final to = index + delta;
        if (index < 0 || index >= secs.length || to < 0 || to >= secs.length) return;
        final s = secs.removeAt(index);
        secs.insert(to, s);
        final sldIdLst = pres.findAllElements('p:sldIdLst').first;
        final byId = {
          for (final e in sldIdLst.findElements('p:sldId')) e.getAttribute('id'): e.copy(),
        };
        sldIdLst.children.clear();
        lst!.children.clear();
        for (final sec in secs) {
          lst.children.add(sec);
          for (final e in sec.findAllElements('p14:sldId')) {
            if (byId.remove(e.getAttribute('id')) case final n?) sldIdLst.children.add(n);
          }
        }
        sldIdLst.children.addAll(byId.values); // bölümsüz kalan (olmamalı)
      };

  // ── Özel gösteriler ──────────────────────────────────────────────────────

  static List<SlideCustomShow> customShows(PptxPackage pkg) {
    final pres = pkg.xml(PptxPackage.presentation);
    if (pres == null) return const [];
    final parts = pkg.slideParts();
    return [
      for (final c in pres.findAllElements('p:custShow'))
        SlideCustomShow(c.getAttribute('name') ?? '', [
          for (final s in c.findAllElements('p:sld'))
            if (pkg.relTarget(PptxPackage.presentation, s.getAttribute('r:id') ?? '')
                case final t?)
              if (parts.indexOf(t) case final i when i >= 0) i,
        ]),
    ];
  }

  /// Özel gösteri yazar (aynı adlı varsa değiştirir).
  static PptxOp setCustomShow(String name, List<int> slides) => (pkg) {
        final pres = pkg.edit(PptxPackage.presentation)!;
        final parts = pkg.slideParts();
        final ridOf = <String, String>{};
        for (final r in pkg.rels(PptxPackage.presentation)) {
          if (r.type.endsWith('/slide')) ridOf[r.target] = r.id;
        }
        var lst = pres.findAllElements('p:custShowLst').firstOrNull;
        if (lst == null) {
          lst = XmlElement(XmlName.fromString('p:custShowLst'));
          final root = pres.rootElement;
          // ECMA sırası: … sldSz, notesSz, smartTags, embeddedFontLst, custShowLst …
          XmlElement? after;
          for (final tag in const ['p:sldIdLst', 'p:sldSz', 'p:notesSz', 'p:smartTags', 'p:embeddedFontLst']) {
            after = root.getElement(tag) ?? after;
          }
          root.children.insert(after == null ? 0 : root.children.indexOf(after) + 1, lst);
        }
        final old = lst.findElements('p:custShow').where((c) => c.getAttribute('name') == name.trim()).firstOrNull;
        var id = 0;
        for (final c in lst.findElements('p:custShow')) {
          final v = int.tryParse(c.getAttribute('id') ?? '') ?? 0;
          if (v >= id) id = v + 1;
        }
        final xml = '<p:custShow name="${PptxPackage.esc(name.trim())}" id="${old?.getAttribute('id') ?? id}"><p:sldLst>'
            '${[for (final i in slides) if (i >= 0 && i < parts.length && ridOf[parts[i]] != null) '<p:sld r:id="${ridOf[parts[i]]}"/>'].join()}'
            '</p:sldLst></p:custShow>';
        if (old != null) {
          final at = lst.children.indexOf(old);
          lst.children
            ..removeAt(at)
            ..insert(at, PptxPackage.frag(xml));
        } else {
          lst.children.add(PptxPackage.frag(xml));
        }
      };

  static PptxOp removeCustomShow(String name) => (pkg) {
        final pres = pkg.edit(PptxPackage.presentation)!;
        final lst = pres.findAllElements('p:custShowLst').firstOrNull;
        lst?.children.removeWhere((n) => n is XmlElement && n.getAttribute('name') == name);
        if (lst != null && lst.findElements('p:custShow').isEmpty) {
          lst.parent?.children.remove(lst);
        }
      };
}
