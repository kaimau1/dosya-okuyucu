/// **Faz 37 madde 9 — gelişmiş ekleme işlemleri** (paket düzeyi).
///
/// İmleç KONUMUNA eklenen öğeler (alan, çapraz başvuru, kaynak gösterme)
/// için iki adım: editör imlece [kDocxMarker] yazar, işlem kaydedilmiş XML'de
/// işareti bulup run'ı böler ve öğeyi tam o noktaya koyar.
library;

import 'package:xml/xml.dart';

import '../docx_document.dart';
import 'docx_package.dart';
import 'docx_style_ops.dart' show DocxOp, DocxStyleOps;

/// İmleç işareti (özel kullanım alanı; belgede doğal olarak geçmez).
const kDocxMarker = '';

/// Alan türleri → Word alan kodu.
const kDocxFieldCodes = {
  'date': r'DATE \@ "dd.MM.yyyy"',
  'time': r'TIME \@ "HH:mm"',
  'page': 'PAGE',
  'numpages': 'NUMPAGES',
  'filename': 'FILENAME',
  'author': 'AUTHOR',
};

/// Şekil türleri (DrawingML hazır geometri).
const kDocxShapes = ['rect', 'roundRect', 'ellipse', 'triangle', 'rightArrow', 'star5'];

/// Görsel sarma kipleri.
const kDocxWrapModes = ['inline', 'square', 'topBottom', 'behind', 'front'];

/// Başlık paragrafının İçindekiler metni: atomlar görünen yazısıyla (not ve
/// yorum işareti hariç), boşluklar tek — [DocxInsertPro.toc] XML'deki
/// paragrafı bu metinle doğrular.
String wordTocText(DocxPara p) {
  final sb = StringBuffer();
  for (var k = 0; k < p.length; k++) {
    final a = k < p.atoms.length ? p.atoms[k] : null;
    if (a == null) {
      sb.write(p.text[k]);
    } else if (a.kind != DocxAtomKind.note && a.kind != DocxAtomKind.comment) {
      sb.write(a.display);
    }
  }
  return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// İçindekiler girdisi: editör paragraf sırası, düzey (1–3), başlık metni,
/// tahmini sayfa (1 tabanlı).
typedef DocxTocEntry = ({int para, int level, String text, int page});

class DocxSource {
  final String author, year, title, publisher;
  const DocxSource(this.author, this.year, this.title, this.publisher);

  /// Metin içi gösterim: (Soyad, Yıl).
  String get citation {
    final first = author.split(RegExp(r'[,;&]| ve | and ')).first.trim();
    final surname = first.contains(' ') ? first.split(' ').last : first;
    return '(${surname.isEmpty ? '?' : surname}, ${year.isEmpty ? 't.y.' : year})';
  }

  /// APA benzeri kaynakça satırı: Yazar (Yıl). *Başlık*. Yayıncı.
  String get entryPlain =>
      '$author (${year.isEmpty ? 't.y.' : year}). $title.${publisher.isEmpty ? '' : ' $publisher.'}';
}

abstract final class DocxInsertPro {
  // ── kenarlık ──────────────────────────────────────────────────────────────

  /// Paragraf kenarlığı: `box` | `top` | `bottom` | `shade` | `none`.
  static DocxOp paraBorder(int i, String preset) => (pkg) {
        final paras = pkg.modelParagraphs();
        if (i < 0 || i >= paras.length || paras[i].name.local != 'p') return;
        final pPr = _pPr(paras[i]);
        kid(pPr, 'pBdr')?.remove();
        kid(pPr, 'shd')?.remove();
        XmlElement edge(String side) => w(side, attrs: {
              'val': 'single', 'sz': '6', 'space': side == 'left' || side == 'right' ? '4' : '1',
              'color': 'auto',
            });
        final sides = switch (preset) {
          'box' => const ['top', 'left', 'bottom', 'right'],
          'top' => const ['top'],
          'bottom' => const ['bottom'],
          _ => const <String>[],
        };
        if (sides.isNotEmpty) {
          _put(pPr, w('pBdr', kids: [for (final s in sides) edge(s)]), kPPrOrder);
        }
        if (preset == 'shade') {
          _put(pPr, w('shd', attrs: {'val': 'clear', 'color': 'auto', 'fill': 'F2F2F2'}), kPPrOrder);
        }
      };

  static XmlElement _pPr(XmlElement p) {
    final have = kid(p, 'pPr');
    if (have != null) return have;
    final pPr = w('pPr');
    p.children.insert(0, pPr);
    return pPr;
  }

  static void _put(XmlElement parent, XmlElement el, List<String> order) {
    final rank = order.indexOf(el.name.local);
    for (final c in parent.childElements) {
      if (order.indexOf(c.name.local) > rank) {
        parent.children.insert(parent.children.indexOf(c), el);
        return;
      }
    }
    parent.children.add(el);
  }

  // ── şekil / metin kutusu ─────────────────────────────────────────────────

  static int _docPrId(DocxPackage pkg) {
    var max = 0;
    for (final e in pkg.body.descendantElements) {
      if (e.name.local == 'docPr') {
        final v = int.tryParse(e.getAttribute('id') ?? '') ?? 0;
        if (v > max) max = v;
      }
    }
    return max + 1;
  }

  static void _drawingNs(DocxPackage pkg) {
    pkg.ensureNs('wp', kWp);
    pkg.ensureNs('a', kA);
    pkg.ensureNs('wps', kWps);
  }

  static XmlElement _x(String q, {Map<String, String> attrs = const {}, List<XmlNode> kids = const []}) =>
      XmlElement(XmlName.qualified(q), [
        for (final e in attrs.entries) XmlAttribute(XmlName.qualified(e.key), e.value),
      ], kids);

  /// Satır içi DrawingML şekli; [text] verilirse metin kutusu.
  static XmlElement _shapeRun(DocxPackage pkg,
      {required String geom, String? text, int cx = 2743200, int cy = 914400, String fill = 'DEEAF6'}) {
    final id = _docPrId(pkg);
    final sp = _x('wps:wsp', kids: [
      _x('wps:cNvSpPr', attrs: text == null ? {} : {'txBox': '1'}),
      _x('wps:spPr', kids: [
        _x('a:xfrm', kids: [
          _x('a:off', attrs: {'x': '0', 'y': '0'}),
          _x('a:ext', attrs: {'cx': '$cx', 'cy': '$cy'}),
        ]),
        _x('a:prstGeom', attrs: {'prst': geom}, kids: [_x('a:avLst')]),
        _x('a:solidFill', kids: [_x('a:srgbClr', attrs: {'val': text == null ? fill : 'FFFFFF'})]),
        _x('a:ln', attrs: {'w': '12700'}, kids: [
          _x('a:solidFill', kids: [_x('a:srgbClr', attrs: {'val': '2F5496'})]),
        ]),
      ]),
      if (text != null)
        _x('wps:txbx', kids: [
          w('txbxContent', kids: [
            for (final line in text.split('\n')) w('p', kids: [if (line.isNotEmpty) wRun(line)]),
          ]),
        ]),
      _x('wps:bodyPr', attrs: {'rot': '0', 'vert': 'horz', 'wrap': 'square', 'anchor': 't'}),
    ]);
    return w('r', kids: [
      w('drawing', kids: [
        _x('wp:inline', attrs: {'distT': '0', 'distB': '0', 'distL': '0', 'distR': '0'}, kids: [
          _x('wp:extent', attrs: {'cx': '$cx', 'cy': '$cy'}),
          _x('wp:docPr', attrs: {'id': '$id', 'name': '${text == null ? 'Shape' : 'Text Box'} $id'}),
          _x('a:graphic', kids: [
            _x('a:graphicData', attrs: {'uri': kWps}, kids: [sp]),
          ]),
        ]),
      ]),
    ]);
  }

  static DocxOp textBox(int i, String text) => (pkg) {
        _drawingNs(pkg);
        pkg.insertAfterPara(i, [
          w('p', kids: [_shapeRun(pkg, geom: 'rect', text: text, cy: 640080 + 228600 * '\n'.allMatches(text).length)]),
        ]);
      };

  static DocxOp shape(int i, String geom) => (pkg) {
        _drawingNs(pkg);
        final square = geom == 'ellipse' || geom == 'star5' || geom == 'triangle';
        pkg.insertAfterPara(i, [
          w('p', kids: [_shapeRun(pkg, geom: geom, cx: square ? 1371600 : 2743200, cy: square ? 1371600 : 914400)]),
        ]);
      };

  // ── görsel sarma ─────────────────────────────────────────────────────────

  /// [i]. paragraftaki ilk çizimin sarma kipi.
  static DocxOp imageWrap(int i, String mode) => (pkg) {
        final paras = pkg.modelParagraphs();
        if (i < 0 || i >= paras.length) return;
        final drawing = paras[i].descendantElements
            .where((e) => e.name.local == 'drawing')
            .firstOrNull;
        if (drawing == null) throw StateError('no_image');
        final holder = drawing.childElements.first; // wp:inline | wp:anchor
        XmlElement? part(String local) => kid(holder, local);
        final extent = part('extent')!.copy();
        final docPr = part('docPr')!.copy();
        final graphic = part('graphic')!.copy();
        final frame = part('cNvGraphicFramePr')?.copy();
        _drawingNs(pkg);
        XmlElement out;
        if (mode == 'inline') {
          out = _x('wp:inline', attrs: {'distT': '0', 'distB': '0', 'distL': '0', 'distR': '0'},
              kids: [extent, docPr, ?frame, graphic]);
        } else {
          final behind = mode == 'behind';
          final wrap = switch (mode) {
            'square' => _x('wp:wrapSquare', attrs: {'wrapText': 'bothSides'}),
            'topBottom' => _x('wp:wrapTopAndBottom'),
            _ => _x('wp:wrapNone'),
          };
          out = _x('wp:anchor', attrs: {
            'distT': '0', 'distB': '0', 'distL': '114300', 'distR': '114300',
            'simplePos': '0', 'relativeHeight': '251659264', 'behindDoc': behind ? '1' : '0',
            'locked': '0', 'layoutInCell': '1', 'allowOverlap': '1',
          }, kids: [
            _x('wp:simplePos', attrs: {'x': '0', 'y': '0'}),
            _x('wp:positionH', attrs: {'relativeFrom': 'column'}, kids: [_x('wp:posOffset', kids: [XmlText('0')])]),
            _x('wp:positionV', attrs: {'relativeFrom': 'paragraph'}, kids: [_x('wp:posOffset', kids: [XmlText('0')])]),
            extent,
            _x('wp:effectExtent', attrs: {'l': '0', 't': '0', 'r': '0', 'b': '0'}),
            wrap,
            docPr,
            ?frame,
            graphic,
          ]);
        }
        holder.replace(out);
      };

  /// [i]. paragraftaki çizimin şu anki sarma kipi (yoksa null).
  static String? wrapOf(DocxPackage pkg, int i) {
    final paras = pkg.modelParagraphs();
    if (i < 0 || i >= paras.length) return null;
    final d = paras[i].descendantElements.where((e) => e.name.local == 'drawing').firstOrNull;
    final h = d?.childElements.firstOrNull;
    if (h == null) return null;
    if (h.name.local == 'inline') return 'inline';
    if (attrOf(h, 'behindDoc') == '1') return 'behind';
    if (kid(h, 'wrapSquare') != null) return 'square';
    if (kid(h, 'wrapTopAndBottom') != null) return 'topBottom';
    return 'front';
  }

  // ── kapak ────────────────────────────────────────────────────────────────

  static DocxOp cover(String title, String subtitle, String author, String date) => (pkg) {
        final root = DocxStyleOps.stylesRoot(pkg);
        DocxStyleOps.ensureStyle(root, 'Title', name: 'Title');
        DocxStyleOps.ensureStyle(root, 'Subtitle', name: 'Subtitle');
        XmlElement para(String text, {String? style, String jc = 'center', int before = 0, int sz = 0}) =>
            w('p', kids: [
              w('pPr', kids: [
                if (style != null) wv('pStyle', style),
                if (before > 0) w('spacing', attrs: {'before': '$before'}),
                wv('jc', jc),
              ]),
              if (text.isNotEmpty)
                wRun(text, rPr: sz > 0 ? w('rPr', kids: [wv('sz', '$sz'), wv('szCs', '$sz')]) : null),
            ]);
        pkg.insertAfterPara(-1, [
          para(title, style: 'Title', before: 4800),
          if (subtitle.isNotEmpty) para(subtitle, style: 'Subtitle'),
          para('', before: 4800),
          if (author.isNotEmpty) para(author, sz: 28),
          if (date.isNotEmpty) para(date, sz: 24),
          w('p', kids: [w('r', kids: [w('br', attrs: {'type': 'page'})])]),
        ]);
      };

  // ── imleçte öğe (işaret yöntemi) ─────────────────────────────────────────

  /// İşaretin olduğu run'ı böler; [build] işaretin yerine konacak düğümleri
  /// verir (işaretin rPr kopyasıyla).
  static void _atMarker(DocxPackage pkg, List<XmlElement> Function(XmlElement? rPr) build) {
    final t = pkg.body.descendantElements
        .where((e) => e.name.local == 't' && e.innerText.contains(kDocxMarker))
        .firstOrNull;
    if (t == null) throw StateError('marker');
    final run = t.parent as XmlElement;
    final rPr = kid(run, 'rPr');
    final text = t.innerText;
    final at = text.indexOf(kDocxMarker);
    final before = text.substring(0, at);
    final after = text.substring(at + kDocxMarker.length);
    final parent = run.parent!;
    final idx = parent.children.indexOf(run);
    // Run içindeki diğer öğeler (tab, br) t'den önce/sonra kalır: t'yi
    // işaret öncesi metinle değiştirip ardına yeni düğümler eklenir.
    final nodes = <XmlElement>[
      ...build(rPr?.copy()),
      if (after.isNotEmpty) wRun(after, rPr: rPr?.copy()),
    ];
    if (before.isEmpty && run.childElements.where((e) => e.name.local != 'rPr').length == 1) {
      run.remove();
      parent.children.insertAll(idx, nodes);
    } else {
      t.children
        ..clear()
        ..add(XmlText(before));
      t.setAttribute('xml:space', 'preserve');
      parent.children.insertAll(idx + 1, nodes);
    }
  }

  /// Basit alan (`w:fldSimple`) — Word açılışta günceller; biz sonucu
  /// [result] olarak yazarız.
  static DocxOp field(String code, String result) => (pkg) {
        _atMarker(pkg, (rPr) => [
              w('fldSimple', attrs: {'instr': ' $code '}, kids: [wRun(result, rPr: rPr)]),
            ]);
      };

  static int _bookmarkId(DocxPackage pkg) {
    var max = 0;
    for (final e in pkg.body.descendantElements) {
      if (e.name.local == 'bookmarkStart') {
        final v = int.tryParse(attrOf(e, 'id') ?? '') ?? 0;
        if (v > max) max = v;
      }
    }
    return max + 1;
  }

  /// [headingPara] başlığına yer imi (yoksa) + imleçte REF/PAGEREF alanı.
  /// [kind]: `text` | `page` | `above` (yukarıda/aşağıda).
  static DocxOp crossRef(int headingPara, String kind, {String result = ''}) => (pkg) {
        final paras = pkg.modelParagraphs();
        if (headingPara < 0 || headingPara >= paras.length) return;
        final h = paras[headingPara];
        var name = h.childElements
            .where((e) => e.name.local == 'bookmarkStart' && (attrOf(e, 'name') ?? '').startsWith('_Ref'))
            .map((e) => attrOf(e, 'name')!)
            .firstOrNull;
        if (name == null) {
          final id = _bookmarkId(pkg);
          name = '_Ref${100000000 + id}';
          final pPr = kid(h, 'pPr');
          final at = pPr == null ? 0 : h.children.indexOf(pPr) + 1;
          h.children.insert(at, w('bookmarkStart', attrs: {'id': '$id', 'name': name}));
          h.children.add(w('bookmarkEnd', attrs: {'id': '$id'}));
        }
        final code = switch (kind) {
          'page' => 'PAGEREF $name \\h',
          'above' => 'PAGEREF $name \\p \\h',
          _ => 'REF $name \\h',
        };
        _atMarker(pkg, (rPr) => [
              w('fldSimple', attrs: {'instr': ' $code '}, kids: [wRun(result, rPr: rPr)]),
            ]);
      };

  // ── İçindekiler ──────────────────────────────────────────────────────────

  /// Word'ün İçindekiler denetiminin galeri adı.
  static const tocGallery = 'Table of Contents';

  /// Başlık 1–3'ten İçindekiler: `w:sdt` (galeri [tocGallery]) içinde
  /// `TOC \o "1-3" \h \z \u` alanı, her girdi başlığın `_Toc` yer imine
  /// köprü + `PAGEREF` sayfa alanı (sonucu [DocxTocEntry.page]). Belgede
  /// İçindekiler varsa YERİNDE güncellenir (denetimin özellikleri kalır;
  /// denetimsiz eski TOC alanı da bulunur), yoksa [at]. paragrafın önüne
  /// konur. Başlığın metni [DocxTocEntry.para]'da tutmazsa aynı metinli ilk
  /// paragraf aranır; bulunamayan girdi atlanır.
  static DocxOp toc(List<DocxTocEntry> entries,
          {int at = 0, String title = 'İçindekiler'}) =>
      (pkg) {
        _tocStyles(pkg);
        final paras = pkg.modelParagraphs();
        final used = <XmlElement>{};
        var nextId = _bookmarkId(pkg);
        final rows = <(DocxTocEntry, String)>[];
        for (final e in entries) {
          final want = e.text.trim();
          if (want.isEmpty) continue;
          bool fits(XmlElement x) =>
              x.name.local == 'p' && !used.contains(x) && _plainText(x) == want;
          var h = e.para >= 0 && e.para < paras.length ? paras[e.para] : null;
          if (h == null || !fits(h)) h = paras.where(fits).firstOrNull;
          if (h == null) continue;
          used.add(h);
          var name = h.childElements
              .where((x) =>
                  x.name.local == 'bookmarkStart' &&
                  (attrOf(x, 'name') ?? '').startsWith('_Toc'))
              .map((x) => attrOf(x, 'name')!)
              .firstOrNull;
          if (name == null) {
            final id = nextId++;
            name = '_Toc${100000000 + id}';
            final pPr = kid(h, 'pPr');
            h.children.insert(pPr == null ? 0 : h.children.indexOf(pPr) + 1,
                w('bookmarkStart', attrs: {'id': '$id', 'name': name}));
            h.children.add(w('bookmarkEnd', attrs: {'id': '$id'}));
          }
          rows.add((e, name));
        }
        final tab = '${_textWidthTw(pkg)}';
        XmlElement fld(String type) =>
            w('r', kids: [w('fldChar', attrs: {'fldCharType': type})]);
        XmlElement instr(String code) => w('r', kids: [
              XmlElement(const XmlName.qualified('w:instrText'),
                  [XmlAttribute(const XmlName.qualified('xml:space'), 'preserve')],
                  [XmlText(' $code ')]),
            ]);
        final head = [fld('begin'), instr(r'TOC \o "1-3" \h \z \u'), fld('separate')];
        final body = <XmlElement>[];
        for (var k = 0; k < rows.length; k++) {
          final (e, name) = rows[k];
          body.add(w('p', kids: [
            w('pPr', kids: [
              wv('pStyle', 'TOC${e.level.clamp(1, 3)}'),
              w('tabs', kids: [
                w('tab', attrs: {'val': 'right', 'leader': 'dot', 'pos': tab}),
              ]),
            ]),
            if (k == 0) ...head,
            w('hyperlink', attrs: {'anchor': name, 'history': '1'}, kids: [
              wRun(e.text.trim()),
              w('r', kids: [w('tab')]),
              fld('begin'),
              instr('PAGEREF $name \\h'),
              fld('separate'),
              wRun('${e.page < 1 ? 1 : e.page}'),
              fld('end'),
            ]),
          ]));
        }
        body.add(w('p', kids: [if (rows.isEmpty) ...head, fld('end')]));
        final heading = w('p', kids: [
          w('pPr', kids: [wv('pStyle', 'TOCHeading')]),
          wRun(title),
        ]);
        final content = [heading, ...body];

        final old = _findToc(pkg);
        if (old case final XmlElement sdt) {
          final c = kid(sdt, 'sdtContent')!;
          c.children
            ..clear()
            ..addAll(content);
        } else if (old case final List<XmlElement> range) {
          final parent = range.first.parent!;
          final i = parent.children.indexOf(range.first);
          for (final x in range) {
            x.remove();
          }
          parent.children.insertAll(i, body);
        } else {
          pkg.insertAfterPara(at - 1, [
            w('sdt', kids: [
              w('sdtPr', kids: [
                w('docPartObj', kids: [
                  wv('docPartGallery', tocGallery),
                  w('docPartUnique'),
                ]),
              ]),
              w('sdtContent', kids: content),
            ]),
          ]);
        }
      };

  /// Belgede İçindekiler var mı (Ekle mi Güncelle mi).
  static bool hasToc(DocxPackage pkg) => _findToc(pkg) != null;

  /// Var olan İçindekiler: galeri adlı `w:sdt` (XmlElement) ya da
  /// denetimsiz `TOC` alanının yayıldığı gövde paragrafları (liste); yoksa null.
  static Object? _findToc(DocxPackage pkg) {
    for (final e in pkg.body.descendantElements) {
      if (e.name.local == 'docPartGallery' && attrOf(e) == tocGallery) {
        XmlNode? n = e;
        while (n != null && !(n is XmlElement && n.name.local == 'sdt')) {
          n = n.parent;
        }
        if (n is XmlElement && kid(n, 'sdtContent') != null) return n;
      }
    }
    for (final t in pkg.body.descendantElements) {
      if (t.name.local != 'instrText' ||
          !t.innerText.trimLeft().toUpperCase().startsWith('TOC ')) {
        continue;
      }
      // Alanın başladığı paragraftan bittiği paragrafa (iç içe PAGEREF
      // alanları derinlikle sayılır).
      XmlNode? n = t;
      while (n != null && !(n is XmlElement && n.name.local == 'p')) {
        n = n.parent;
      }
      if (n is! XmlElement || n.parent == null) return null;
      final out = <XmlElement>[];
      var depth = 0;
      var started = false;
      XmlElement? p = n;
      while (p != null) {
        if (p.name.local == 'p') {
          out.add(p);
          for (final f in p.descendantElements) {
            if (f.name.local != 'fldChar') continue;
            final type = attrOf(f, 'fldCharType');
            if (type == 'begin') {
              depth++;
              started = true;
            } else if (type == 'end') {
              depth--;
            }
          }
          if (started && depth <= 0) return out;
        }
        p = p.nextElementSibling;
      }
      return out;
    }
    return null;
  }

  /// Paragrafın görünen düz metni (alan kodu ve silinmiş yazı hariç).
  static String _plainText(XmlElement p) {
    final sb = StringBuffer();
    for (final e in p.descendantElements) {
      if (e.name.local == 't') sb.write(e.innerText);
      if (const {'tab', 'br', 'cr'}.contains(e.name.local)) sb.write(' ');
    }
    return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Sağ sekme konumu: son bölümün yazı alanı genişliği (twip; A4 varsayılan).
  static int _textWidthTw(DocxPackage pkg) {
    final s = kid(pkg.body, 'sectPr');
    int tw(XmlElement? e, String a, int d) =>
        int.tryParse(attrOf(e, a) ?? '') ?? d;
    final wPg = tw(kid(s, 'pgSz'), 'w', 11906);
    final mar = kid(s, 'pgMar');
    final v = wPg - tw(mar, 'left', 1440) - tw(mar, 'right', 1440);
    return v > 1440 ? v : 9026;
  }

  /// İçindekiler stilleri (yoksa): başlık (anahat dışı — kendini listelemez)
  /// ve 1–3 düzey girintileri.
  static void _tocStyles(DocxPackage pkg) {
    final root = DocxStyleOps.stylesRoot(pkg);
    XmlElement style(String id, String name, List<XmlElement> pPr,
            [List<XmlElement> rPr = const []]) =>
        w('style', attrs: {'type': 'paragraph', 'styleId': id}, kids: [
          wv('name', name),
          wv('basedOn', 'Normal'),
          wv('next', 'Normal'),
          wv('uiPriority', '39'),
          w('unhideWhenUsed'),
          w('pPr', kids: pPr),
          if (rPr.isNotEmpty) w('rPr', kids: rPr),
        ]);
    final want = [
      style('TOCHeading', 'TOC Heading', [
        w('keepNext'),
        w('spacing', attrs: {'before': '240', 'after': '120'}),
        wv('outlineLvl', '9'),
      ], [
        w('b'),
        wv('sz', '32'),
        wv('szCs', '32'),
      ]),
      style('TOC1', 'toc 1', [w('spacing', attrs: {'after': '100'})]),
      style('TOC2', 'toc 2', [
        w('spacing', attrs: {'after': '100'}),
        w('ind', attrs: {'left': '220'}),
      ]),
      style('TOC3', 'toc 3', [
        w('spacing', attrs: {'after': '100'}),
        w('ind', attrs: {'left': '440'}),
      ]),
    ];
    for (final s in want) {
      if (DocxStyleOps.styleById(root, attrOf(s, 'styleId')!) == null) {
        root.children.add(s);
      }
    }
  }

  // ── kaynakça ─────────────────────────────────────────────────────────────

  static const bibBookmark = '_DoKaynakca';

  /// İmleçte kaynak gösterme + belge sonundaki "Kaynakça" bölümüne alfabetik
  /// girdi (bölüm yoksa başlığıyla kurulur; aynı girdi iki kez yazılmaz).
  static DocxOp cite(DocxSource src, {String heading = 'Kaynakça'}) => (pkg) {
        _atMarker(pkg, (rPr) => [wRun(src.citation, rPr: rPr)]);
        final body = pkg.body;
        XmlElement? head;
        for (final p in kids(body, 'p')) {
          if (p.childElements.any((e) => e.name.local == 'bookmarkStart' && attrOf(e, 'name') == bibBookmark)) {
            head = p;
          }
        }
        if (head == null) {
          final root = DocxStyleOps.stylesRoot(pkg);
          DocxStyleOps.ensureStyle(root, 'Heading1');
          final id = _bookmarkId(pkg);
          head = w('p', kids: [
            w('pPr', kids: [wv('pStyle', 'Heading1')]),
            w('bookmarkStart', attrs: {'id': '$id', 'name': bibBookmark}),
            wRun(heading),
            w('bookmarkEnd', attrs: {'id': '$id'}),
          ]);
          final sect = kid(body, 'sectPr');
          if (sect == null) {
            body.children.add(head);
          } else {
            body.children.insert(body.children.indexOf(sect), head);
          }
        }
        // Başlıktan sonraki girdiler (bir sonraki başlığa / gövde sonuna dek).
        final entries = <XmlElement>[];
        var n = head.nextElementSibling;
        while (n != null && n.name.local == 'p' && kid(kid(n, 'pPr'), 'pStyle') == null) {
          entries.add(n);
          n = n.nextElementSibling;
        }
        final plain = src.entryPlain;
        if (entries.any((e) => e.innerText.trim() == plain.trim())) return;
        final entry = w('p', kids: [
          w('pPr', kids: [w('ind', attrs: {'left': '720', 'hanging': '720'})]),
          wRun('${src.author} (${src.year.isEmpty ? 't.y.' : src.year}). '),
          wRun(src.title, rPr: w('rPr', kids: [w('i')])),
          wRun('.${src.publisher.isEmpty ? '' : ' ${src.publisher}.'}'),
        ]);
        XmlElement after = head;
        for (final e in entries) {
          if (e.innerText.toLowerCase().compareTo(plain.toLowerCase()) < 0) after = e;
        }
        after.parent!.children.insert(after.parent!.children.indexOf(after) + 1, entry);
      };
}
