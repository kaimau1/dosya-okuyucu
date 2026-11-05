import 'package:xml/xml.dart';

import 'pptx_media_ops.dart';
import 'pptx_package.dart';
import 'pptx_shape_ops.dart';

export 'pptx_media_ops.dart' show SlideMediaRef;
export 'pptx_shape_ops.dart' show SlideLinkKind;

/// Sunumda tıklanabilir şekil (köprü / eylem düğmesi). Konum punto.
class SlideLink {
  final double x, y, w, h;
  final SlideLinkKind kind;
  final String? url;

  /// [SlideLinkKind.slide] hedefi (destedeki sıra, 0 tabanlı).
  final int? slide;
  const SlideLink(this.x, this.y, this.w, this.h, this.kind, {this.url, this.slide});
}

/// Canlı geri sayım kutusu.
class SlideCounter {
  final double x, y, w, h;
  final int seconds;
  const SlideCounter(this.x, this.y, this.w, this.h, this.seconds);
}

/// Sunum sırasında bir slaytın etkileşimli öğeleri.
class SlideShowInfo {
  final List<SlideMediaRef> media;
  final List<SlideLink> links;
  final List<SlideCounter> counters;

  /// Otomatik ilerleme (`p:transition@advTm`, ms); null = tıklamayla.
  final int? advanceMs;
  const SlideShowInfo({
    this.media = const [],
    this.links = const [],
    this.counters = const [],
    this.advanceMs,
  });
}

/// **Faz 38 — sunum bilgisi.** Destenin her slaytı (paket sırası) için medya,
/// köprü/eylem, sayaç ve zamanlama; sunum açılınca bir kez, izolatta okunur.
abstract final class PptxShowInfo {
  static List<SlideShowInfo> read(PptxPackage pkg) {
    final parts = pkg.slideParts();
    final out = <SlideShowInfo>[];
    for (final part in parts) {
      final d = pkg.xml(part);
      final tr = d?.findAllElements('p:transition').firstOrNull;
      final links = <SlideLink>[];
      final counters = <SlideCounter>[];
      for (final e in PptxPackage.spTree(d ?? XmlDocument())?.childElements ??
          const <XmlElement>[]) {
        final c = e.childElements
            .where((n) => n.name.local.startsWith('nv'))
            .map((n) => n.getElement('p:cNvPr'))
            .whereType<XmlElement>()
            .firstOrNull;
        if (c == null) continue;
        final xf = e.name.local == 'graphicFrame'
            ? e.getElement('p:xfrm')
            : e.name.local == 'grpSp'
                ? e.getElement('p:grpSpPr')?.getElement('a:xfrm')
                : e.getElement('p:spPr')?.getElement('a:xfrm');
        double v(String tag, String a) =>
            (int.tryParse(xf?.getElement(tag)?.getAttribute(a) ?? '') ?? 0) / 12700;
        final x = v('a:off', 'x'), y = v('a:off', 'y');
        final w = v('a:ext', 'cx'), h = v('a:ext', 'cy');
        final descr = c.getAttribute('descr') ?? '';
        if (descr.startsWith(kCounterMarker)) {
          final s = int.tryParse(descr.substring(kCounterMarker.length));
          if (s != null) counters.add(SlideCounter(x, y, w, h, s));
        }
        final link = c.getElement('a:hlinkClick');
        if (link == null) continue;
        final action = link.getAttribute('action') ?? '';
        final rid = link.getAttribute('r:id') ?? '';
        if (action == 'ppaction://media') continue; // medya: ayrı yol
        if (action.startsWith('ppaction://hlinkshowjump')) {
          final jump = Uri.tryParse(action.replaceFirst('ppaction://hlinkshowjump', 'x://a'))
              ?.queryParameters['jump'];
          final kind = switch (jump) {
            'nextslide' => SlideLinkKind.next,
            'previousslide' || 'lastslideviewed' => SlideLinkKind.prev,
            'firstslide' => SlideLinkKind.first,
            'lastslide' => SlideLinkKind.last,
            'endshow' => SlideLinkKind.end,
            _ => null,
          };
          if (kind != null) links.add(SlideLink(x, y, w, h, kind));
        } else if (action == 'ppaction://hlinksldjump') {
          final t = pkg.relTarget(part, rid);
          final i = t == null ? -1 : parts.indexOf(t);
          if (i >= 0) links.add(SlideLink(x, y, w, h, SlideLinkKind.slide, slide: i));
        } else if (action.isEmpty && rid.isNotEmpty) {
          final rel = pkg.rels(part).where((r) => r.id == rid).firstOrNull;
          if (rel != null && rel.external) {
            links.add(SlideLink(x, y, w, h, SlideLinkKind.url, url: rel.target));
          }
        }
      }
      out.add(SlideShowInfo(
        media: PptxMediaOps.mediaOf(pkg, part),
        links: links,
        counters: counters,
        advanceMs: int.tryParse(tr?.getAttribute('advTm') ?? ''),
      ));
    }
    return out;
  }
}
