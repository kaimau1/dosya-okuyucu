/// **Faz 37 — Word pro işlemlerinin ortak paketi.**
///
/// Editör modeli ([DocxDocument]) paragraf düzeyinde yazar; stil tanımı,
/// bölüm (sectPr), tablo ızgarası, tema, denklem, metin kutusu gibi yapısal
/// değişiklikler ise doğrudan OOXML parçalarında yapılır. Akış:
/// `doc.saveAsync()` → [DocxPackage.open] → işlem → [DocxPackage.save] →
/// yeniden ayrıştır. Böylece her pro işlemi saf Dart, izolatta koşabilir
/// (anayasa k.1) ve test edilebilir.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

const kW = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const kR =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const kM = 'http://schemas.openxmlformats.org/officeDocument/2006/math';
const kWp =
    'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
const kA = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const kWps = 'http://schemas.microsoft.com/office/word/2010/wordprocessingShape';
const kPkgRels = 'http://schemas.openxmlformats.org/package/2006/relationships';
const kCt = 'http://schemas.openxmlformats.org/package/2006/content-types';

/// `w:` önekli öğe kurar: `w('p', attrs: {'val': '1'}, kids: [...])`.
XmlElement w(String local,
        {Map<String, String> attrs = const {},
        List<XmlNode> kids = const []}) =>
    XmlElement(XmlName.fromString('w:$local'), [
      for (final MapEntry(:key, :value) in attrs.entries)
        XmlAttribute(XmlName.fromString(key.contains(':') ? key : 'w:$key'), value),
    ], kids);

/// `w:val` öznitelikli kısa öğe.
XmlElement wv(String local, String val) => w(local, attrs: {'val': val});

/// Düz metin run'ı (`xml:space="preserve"`), isteğe bağlı rPr ile.
XmlElement wRun(String text, {XmlElement? rPr}) => w('r', kids: [
      ?rPr,
      XmlElement(XmlName.fromString('w:t'),
          [XmlAttribute(XmlName.fromString('xml:space'), 'preserve')], [XmlText(text)]),
    ]);

/// Yerel adla ilk alt öğe.
XmlElement? kid(XmlElement? e, String local) {
  if (e == null) return null;
  for (final c in e.childElements) {
    if (c.name.local == local) return c;
  }
  return null;
}

Iterable<XmlElement> kids(XmlElement? e, String local) =>
    e == null ? const [] : e.childElements.where((c) => c.name.local == local);

/// `w:val` (ya da verilen yerel ad) öznitelik değeri.
String? attrOf(XmlElement? e, [String local = 'val']) {
  if (e == null) return null;
  for (final a in e.attributes) {
    if (a.name.local == local) return a.value;
  }
  return null;
}

/// `w:` öznitelik yazar (varsa değiştirir).
void setW(XmlElement e, String local, String value) {
  for (final a in e.attributes) {
    if (a.name.local == local && a.name.prefix == 'w') {
      a.value = value;
      return;
    }
  }
  e.attributes.add(XmlAttribute(XmlName.fromString('w:$local'), value));
}

/// Verilen yerel adlı alt öğeyi döndürür; yoksa [order] sırasına uygun
/// yere ekleyip döndürür.
XmlElement ensureKid(XmlElement parent, String local,
    {List<String> order = const []}) {
  final have = kid(parent, local);
  if (have != null) return have;
  final el = w(local);
  final rank = order.indexOf(local);
  if (rank >= 0) {
    for (final c in parent.childElements) {
      final r = order.indexOf(c.name.local);
      if (r > rank) {
        c.parent!.children.insert(c.parent!.children.indexOf(c), el);
        return el;
      }
    }
  }
  parent.children.add(el);
  return el;
}

/// pPr alt öğe sırası (ECMA-376 §17.3.1.26) — sırasız yazılan pPr'yi Word
/// "onarır" diye açıyor.
const kPPrOrder = [
  'pStyle', 'keepNext', 'keepLines', 'pageBreakBefore', 'framePr',
  'widowControl', 'numPr', 'suppressLineNumbers', 'pBdr', 'shd', 'tabs',
  'suppressAutoHyphens', 'kinsoku', 'wordWrap', 'overflowPunct', 'topLinePunct',
  'autoSpaceDE', 'autoSpaceDN', 'bidi', 'adjustRightInd', 'snapToGrid',
  'spacing', 'ind', 'contextualSpacing', 'mirrorIndents', 'suppressOverlap',
  'jc', 'textDirection', 'textAlignment', 'textboxTightWrap',
  'outlineLvl', 'divId', 'cnfStyle', 'rPr', 'sectPr', 'pPrChange',
];

/// rPr alt öğe sırası (§17.3.2.28).
const kRPrOrder = [
  'rStyle', 'rFonts', 'b', 'bCs', 'i', 'iCs', 'caps', 'smallCaps', 'strike',
  'dstrike', 'outline', 'shadow', 'emboss', 'imprint', 'noProof', 'snapToGrid',
  'vanish', 'webHidden', 'color', 'spacing', 'w', 'kern', 'position', 'sz',
  'szCs', 'highlight', 'u', 'effect', 'bdr', 'shd', 'fitText', 'vertAlign',
  'rtl', 'cs', 'em', 'lang', 'eastAsianLayout', 'specVanish', 'oMath',
];

/// sectPr alt öğe sırası (§17.6.17).
const kSectOrder = [
  'headerReference', 'footerReference', 'footnotePr', 'endnotePr', 'type',
  'pgSz', 'pgMar', 'paperSrc', 'pgBorders', 'lnNumType', 'pgNumType', 'cols',
  'formProt', 'vAlign', 'noEndnote', 'titlePg', 'textDirection', 'bidi',
  'rtlGutter', 'docGrid', 'printerSettings', 'sectPrChange',
];

/// tcPr / tblPr sıraları.
const kTcPrOrder = [
  'cnfStyle', 'tcW', 'gridSpan', 'hMerge', 'vMerge', 'tcBorders', 'shd',
  'noWrap', 'tcMar', 'textDirection', 'tcFitText', 'vAlign', 'hideMark',
];
const kTblPrOrder = [
  'tblStyle', 'tblpPr', 'tblOverlap', 'bidiVisual', 'tblStyleRowBandSize',
  'tblStyleColBandSize', 'tblW', 'jc', 'tblCellSpacing', 'tblInd',
  'tblBorders', 'shd', 'tblLayout', 'tblCellMar', 'tblLook',
];

class DocxPackage {
  final Archive _archive;
  final Map<String, XmlDocument> _xml = {};
  final Set<String> _dirty = {};
  final Map<String, List<int>> _bin = {};

  DocxPackage._(this._archive);

  static DocxPackage open(List<int> bytes) =>
      DocxPackage._(ZipDecoder().decodeBytes(bytes));

  bool has(String name) =>
      _xml.containsKey(name) ||
      _bin.containsKey(name) ||
      _archive.files.any((f) => f.name == name);

  /// Parçayı XML olarak okur (yoksa null). Dönen belge değiştirilirse
  /// [touch] ile işaretlenmelidir — [part] bunu kendisi yapar.
  XmlDocument? read(String name) {
    final have = _xml[name];
    if (have != null) return have;
    final f = _archive.files.where((f) => f.name == name).firstOrNull;
    if (f == null) return null;
    final doc = XmlDocument.parse(utf8.decode(f.content as List<int>));
    _xml[name] = doc;
    return doc;
  }

  /// Değiştirilmek üzere parça (kirli işaretlenir).
  XmlDocument? part(String name) {
    final d = read(name);
    if (d != null) _dirty.add(name);
    return d;
  }

  void putXml(String name, XmlDocument doc) {
    _xml[name] = doc;
    _dirty.add(name);
  }

  void putBytes(String name, List<int> bytes) => _bin[name] = bytes;

  List<int>? bytesOf(String name) {
    if (_bin[name] case final b?) return b;
    final f = _archive.files.where((f) => f.name == name).firstOrNull;
    return f?.content as List<int>?;
  }

  XmlDocument get document => part('word/document.xml')!;
  XmlElement get body => kid(document.rootElement, 'body')!;

  /// Gövdenin SON (belge sonu) sectPr'si; yoksa A4 + 1" ile kurulur.
  XmlElement get bodySectPr {
    final have = kid(body, 'sectPr');
    if (have != null) return have;
    final s = w('sectPr', kids: [
      w('pgSz', attrs: {'w': '11906', 'h': '16838'}),
      w('pgMar', attrs: {
        'top': '1440', 'right': '1440', 'bottom': '1440', 'left': '1440',
        'header': '708', 'footer': '708', 'gutter': '0',
      }),
    ]);
    body.children.add(s);
    return s;
  }

  /// Kök öğede ad alanı bildirimi yoksa ekler (denklem, şekil, çizim).
  void ensureNs(String prefix, String uri) {
    final root = document.rootElement;
    if (root.attributes.any((a) => a.name.prefix == 'xmlns' && a.name.local == prefix)) {
      return;
    }
    root.attributes.add(XmlAttribute(XmlName(prefix, 'xmlns'), uri));
  }

  /// İçerik türü bildirimi (Override) — yoksa ekler.
  void ensureOverride(String partName, String contentType) {
    final ct = part('[Content_Types].xml')!;
    final root = ct.rootElement;
    final pn = '/$partName';
    if (root.childElements.any((e) => e.getAttribute('PartName') == pn)) return;
    root.children.add(XmlElement(XmlName('Override'), [
      XmlAttribute(XmlName('PartName'), pn),
      XmlAttribute(XmlName('ContentType'), contentType),
    ]));
  }

  void ensureDefault(String ext, String contentType) {
    final root = part('[Content_Types].xml')!.rootElement;
    if (root.childElements
        .any((e) => e.getAttribute('Extension')?.toLowerCase() == ext)) {
      return;
    }
    root.children.insert(0, XmlElement(XmlName('Default'), [
      XmlAttribute(XmlName('Extension'), ext),
      XmlAttribute(XmlName('ContentType'), contentType),
    ]));
  }

  static const _docRels = 'word/_rels/document.xml.rels';

  /// document.xml ilişkisini bulur ya da ekler; kimliği döndürür.
  String relate(String type, String target, {bool external = false}) {
    var rels = part(_docRels);
    if (rels == null) {
      rels = XmlDocument.parse('<?xml version="1.0" encoding="UTF-8" '
          'standalone="yes"?><Relationships xmlns="$kPkgRels"/>');
      putXml(_docRels, rels);
    }
    final root = rels.rootElement;
    for (final r in root.childElements) {
      if (r.getAttribute('Type') == type && r.getAttribute('Target') == target) {
        return r.getAttribute('Id')!;
      }
    }
    var n = 1;
    final ids = {for (final r in root.childElements) r.getAttribute('Id')};
    while (ids.contains('rId$n')) {
      n++;
    }
    root.children.add(XmlElement(XmlName('Relationship'), [
      XmlAttribute(XmlName('Id'), 'rId$n'),
      XmlAttribute(XmlName('Type'), type),
      XmlAttribute(XmlName('Target'), target),
      if (external) XmlAttribute(XmlName('TargetMode'), 'External'),
    ]));
    return 'rId$n';
  }

  /// İlişki hedefi (kimlikten).
  String? relTarget(String id) {
    final rels = read(_docRels);
    for (final r in rels?.rootElement.childElements ?? const <XmlElement>[]) {
      if (r.getAttribute('Id') == id) return r.getAttribute('Target');
    }
    return null;
  }

  /// Editör modelinin paragraf sırası (gövde `w:p`, üst düzey tablo
  /// hücrelerindeki `w:p`, boş hücre için hücrenin kendisi, metinli diğer
  /// gövde öğeleri) — `DocxDocument._readBody` ile aynı. Paragraf dizini
  /// (imleç) → XML öğesi eşlemesi buradan.
  List<XmlElement> modelParagraphs() {
    final out = <XmlElement>[];
    for (final e in body.childElements) {
      switch (e.name.local) {
        case 'p':
          out.add(e);
        case 'tbl':
          for (final tr in kids(e, 'tr')) {
            for (final tc in kids(tr, 'tc')) {
              var any = false;
              for (final x in tc.childElements) {
                if (x.name.local == 'p') {
                  out.add(x);
                  any = true;
                } else if (x.name.local != 'tcPr' && x.innerText.trim().isNotEmpty) {
                  out.add(x);
                  any = true;
                }
              }
              if (!any) out.add(tc);
            }
          }
        case 'sectPr':
          break;
        default:
          if (e.innerText.trim().isNotEmpty) out.add(e);
      }
    }
    return out;
  }

  /// İmleç paragrafının gövde düzeyindeki öğesi (tablodaysa tablo).
  XmlElement? bodyLevel(XmlElement e) {
    XmlNode? n = e;
    while (n != null && n.parent != body) {
      n = n.parent;
    }
    return n is XmlElement ? n : null;
  }

  /// [i]. model paragrafından SONRA gövdeye öğe ekler (tablodaysa tablodan
  /// sonra). [i] < 0 → başa.
  void insertAfterPara(int i, List<XmlElement> nodes) {
    final paras = modelParagraphs();
    final kids = body.children;
    int at;
    if (i < 0 || paras.isEmpty) {
      at = 0;
    } else {
      final anchor = bodyLevel(paras[i.clamp(0, paras.length - 1)]);
      at = anchor == null ? kids.length : kids.indexOf(anchor) + 1;
    }
    // sectPr hep en sonda kalır.
    final sect = kid(body, 'sectPr');
    if (sect != null && at > kids.indexOf(sect)) at = kids.indexOf(sect);
    kids.insertAll(at, nodes);
  }

  Uint8List save() {
    final out = Archive();
    final seen = <String>{};
    for (final f in _archive.files) {
      if (!f.isFile) continue;
      seen.add(f.name);
      if (_dirty.contains(f.name) && _xml[f.name] != null) {
        out.addFile(_text(f.name, _xml[f.name]!));
      } else if (_bin[f.name] case final b?) {
        out.addFile(ArchiveFile(f.name, b.length, b));
      } else {
        out.addFile(f);
      }
    }
    for (final MapEntry(:key, :value) in _xml.entries) {
      if (!seen.contains(key) && _dirty.contains(key)) {
        out.addFile(_text(key, value));
        seen.add(key);
      }
    }
    for (final MapEntry(:key, :value) in _bin.entries) {
      if (seen.add(key)) out.addFile(ArchiveFile(key, value.length, value));
    }
    return Uint8List.fromList(ZipEncoder().encode(out));
  }

  static ArchiveFile _text(String name, XmlDocument d) {
    final b = utf8.encode(d.toXmlString());
    return ArchiveFile(name, b.length, b);
  }
}

/// Pro işlemini izolatta koşturur (anayasa k.1). Test sahte saatinde izolat
/// beklenemez → [inIsolate] testte kapatılır.
abstract final class DocxPro {
  static bool inIsolate = true;

  static Future<Uint8List> run(
      Uint8List bytes, void Function(DocxPackage pkg) op) async {
    Uint8List work() {
      final pkg = DocxPackage.open(bytes);
      op(pkg);
      return pkg.save();
    }

    if (inIsolate) return Isolate.run(work);
    return work();
  }

  /// Sonuç döndüren salt okuma işlemi.
  static Future<T> query<T>(
      Uint8List bytes, T Function(DocxPackage pkg) op) async {
    if (inIsolate) return Isolate.run(() => op(DocxPackage.open(bytes)));
    return op(DocxPackage.open(bytes));
  }
}
