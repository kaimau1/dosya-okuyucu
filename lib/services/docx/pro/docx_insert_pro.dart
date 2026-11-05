/// **Faz 37 madde 9 — gelişmiş ekleme işlemleri** (paket düzeyi).
///
/// İmleç KONUMUNA eklenen öğeler (alan, çapraz başvuru, kaynak gösterme)
/// için iki adım: editör imlece [kDocxMarker] yazar, işlem kaydedilmiş XML'de
/// işareti bulup run'ı böler ve öğeyi tam o noktaya koyar.
library;

import 'package:xml/xml.dart';

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
      XmlElement(XmlName.fromString(q), [
        for (final e in attrs.entries) XmlAttribute(XmlName.fromString(e.key), e.value),
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
              kids: [extent, docPr, if (frame != null) frame, graphic]);
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
            if (frame != null) frame,
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
