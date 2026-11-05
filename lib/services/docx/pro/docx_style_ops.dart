/// **Faz 37 madde 1 — stil galerisi işlemleri.**
///
/// * [updateStyleFromParagraph]: Word'ün "Stili seçimle eşleşecek şekilde
///   güncelleştir" komutu — imleç paragrafının doğrudan biçimi (paragraf +
///   ilk run) stil tanımına taşınır, paragraftan silinir; aynı stili kullanan
///   bütün paragraflar yeni görünüşü alır.
/// * [applyStyleSet]: belge teması — başlık/gövde yazı tipi (tema
///   `majorFont`/`minorFont` + docDefaults), başlık rengi, gövde puntosu.
library;

import 'package:xml/xml.dart';

import 'docx_package.dart';

typedef DocxOp = void Function(DocxPackage pkg);

/// Hazır belge temaları (yazı tipleri yalnız `kDocFonts`'ta olanlardan —
/// cihazda çizilebilsinler).
class DocxStyleSet {
  final String id;
  final String headingFont, bodyFont;

  /// RRGGBB; null → başlık rengine dokunma.
  final String? headingColor;
  final double bodyPt;
  const DocxStyleSet(this.id, this.headingFont, this.bodyFont,
      this.headingColor, this.bodyPt);
}

const kDocxStyleSets = <DocxStyleSet>[
  DocxStyleSet('office', 'Calibri', 'Calibri', '2F5496', 11),
  DocxStyleSet('classic', 'Times New Roman', 'Times New Roman', '000000', 12),
  DocxStyleSet('modern', 'Arial', 'Arial', '1F3864', 11),
  DocxStyleSet('elegant', 'Georgia', 'Garamond', '7B2C2C', 12),
  DocxStyleSet('formal', 'Cambria', 'Calibri', '385623', 11),
];

/// İçerik türleri.
const kStylesCt =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml';
const kStylesRel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles';

abstract final class DocxStyleOps {
  /// styles.xml (yoksa kurulur ve ilişkilendirilir).
  static XmlElement stylesRoot(DocxPackage pkg) {
    var d = pkg.part('word/styles.xml');
    if (d == null) {
      d = XmlDocument.parse('<?xml version="1.0" encoding="UTF-8" '
          'standalone="yes"?><w:styles xmlns:w="$kW"/>');
      pkg.putXml('word/styles.xml', d);
      pkg.ensureOverride('word/styles.xml', kStylesCt);
      pkg.relate(kStylesRel, 'styles.xml');
    }
    return d.rootElement;
  }

  static XmlElement? styleById(XmlElement root, String id) {
    for (final s in kids(root, 'style')) {
      if (attrOf(s, 'styleId') == id) return s;
    }
    return null;
  }

  /// Stil yoksa yerleşik ada göre en yalın tanımla kurar.
  static XmlElement ensureStyle(XmlElement root, String id, {String? name}) {
    final have = styleById(root, id);
    if (have != null) return have;
    final s = w('style', attrs: {'type': 'paragraph', 'styleId': id}, kids: [
      wv('name', name ?? _builtinName(id)),
      if (id != 'Normal') wv('basedOn', 'Normal'),
      if (id != 'Normal') wv('next', 'Normal'),
      w('qFormat'),
    ]);
    root.children.add(s);
    return s;
  }

  static String _builtinName(String id) {
    final h = RegExp(r'^Heading(\d)$').firstMatch(id);
    if (h != null) return 'heading ${h.group(1)}';
    return switch (id) {
      'ListParagraph' => 'List Paragraph',
      _ => id,
    };
  }

  /// pPr'den stile taşınMAYACAK öğeler.
  static const _keepOnPara = {'pStyle', 'numPr', 'rPr', 'sectPr', 'pPrChange'};

  static DocxOp updateStyleFromParagraph(int paraIndex) => (pkg) {
        final paras = pkg.modelParagraphs();
        if (paraIndex < 0 || paraIndex >= paras.length) return;
        final p = paras[paraIndex];
        if (p.name.local != 'p') return;
        final pPr = kid(p, 'pPr');
        final id = attrOf(kid(pPr, 'pStyle')) ?? 'Normal';
        final root = stylesRoot(pkg);
        final style = ensureStyle(root, id);
        // 1) Paragraf özellikleri.
        final moved = [
          for (final k in pPr?.childElements.toList() ?? const <XmlElement>[])
            if (!_keepOnPara.contains(k.name.local)) k,
        ];
        if (moved.isNotEmpty) {
          final sp = ensureKid(style, 'pPr', order: _styleOrder);
          for (final k in moved) {
            kid(sp, k.name.local)?.remove();
            k.remove();
            _insertOrdered(sp, k, kPPrOrder);
          }
        }
        // 2) Harf özellikleri: ilk metinli run'ın rPr'si (rStyle hariç).
        final runs = p.descendantElements
            .where((e) => e.name.local == 'r' && kid(e, 't') != null)
            .toList();
        final first = runs.isEmpty ? null : kid(runs.first, 'rPr');
        if (first != null) {
          final sr = ensureKid(style, 'rPr', order: _styleOrder);
          final props = [
            for (final k in first.childElements)
              if (k.name.local != 'rStyle') k,
          ];
          for (final k in props) {
            kid(sr, k.name.local)?.remove();
            _insertOrdered(sr, k.copy(), kRPrOrder);
          }
          // Aynı değerdeki doğrudan biçim paragraf boyunca silinir.
          final sig = {for (final k in props) k.name.local: k.toXmlString()};
          for (final r in runs) {
            final rp = kid(r, 'rPr');
            if (rp == null) continue;
            for (final k in rp.childElements.toList()) {
              if (sig[k.name.local] == k.toXmlString()) k.remove();
            }
            if (rp.childElements.isEmpty) rp.remove();
          }
        }
      };

  static const _styleOrder = [
    'name', 'aliases', 'basedOn', 'next', 'link', 'autoRedefine', 'hidden',
    'uiPriority', 'semiHidden', 'unhideWhenUsed', 'qFormat', 'locked',
    'personal', 'personalCompose', 'personalReply', 'rsid', 'pPr', 'rPr',
    'tblPr', 'trPr', 'tcPr', 'tblStylePr',
  ];

  static void _insertOrdered(XmlElement parent, XmlElement el, List<String> order) {
    final rank = order.indexOf(el.name.local);
    for (final c in parent.childElements) {
      if (order.indexOf(c.name.local) > rank) {
        parent.children.insert(parent.children.indexOf(c), el);
        return;
      }
    }
    parent.children.add(el);
  }

  static XmlElement _fonts(String name) => w('rFonts', attrs: {
        'ascii': name, 'hAnsi': name, 'cs': name, 'eastAsia': name,
      });

  /// Belge teması.
  static DocxOp applyStyleSet(DocxStyleSet set) => (pkg) {
        // Tema dosyası varsa yazı tipi şeması.
        final themeName = pkg.has('word/theme/theme1.xml')
            ? 'word/theme/theme1.xml'
            : null;
        if (themeName != null) {
          final t = pkg.part(themeName)!;
          for (final e in t.rootElement.descendantElements) {
            if (e.name.local != 'latin') continue;
            final parent = e.parent;
            if (parent is! XmlElement) continue;
            final face = switch (parent.name.local) {
              'majorFont' => set.headingFont,
              'minorFont' => set.bodyFont,
              _ => null,
            };
            if (face != null) e.setAttribute('typeface', face);
          }
        }
        final root = stylesRoot(pkg);
        // docDefaults: gövde yazı tipi + punto (tema özniteliği silinir —
        // tema dosyası olmayan belgede de sonuç aynı görünsün).
        final dd = kid(root, 'docDefaults') ??
            (() {
              final e = w('docDefaults');
              root.children.insert(0, e);
              return e;
            })();
        final rprDef = ensureKid(dd, 'rPrDefault', order: const ['rPrDefault', 'pPrDefault']);
        final rPr = ensureKid(rprDef, 'rPr');
        kid(rPr, 'rFonts')?.remove();
        _insertOrdered(rPr, _fonts(set.bodyFont), kRPrOrder);
        final half = (set.bodyPt * 2).round().toString();
        for (final k in const ['sz', 'szCs']) {
          kid(rPr, k)?.remove();
          _insertOrdered(rPr, wv(k, half), kRPrOrder);
        }
        // Normal'de açık yazı tipi varsa o da gövdeye.
        final normal = styleById(root, 'Normal');
        final nr = kid(normal, 'rPr');
        if (nr != null && kid(nr, 'rFonts') != null) {
          kid(nr, 'rFonts')!.remove();
          _insertOrdered(nr, _fonts(set.bodyFont), kRPrOrder);
        }
        // Başlıklar ve Konu Başlığı.
        for (final id in const ['Title', 'Heading1', 'Heading2', 'Heading3', 'Heading4']) {
          final s = id == 'Title' ? ensureStyle(root, id, name: 'Title') : ensureStyle(root, id);
          final r = ensureKid(s, 'rPr', order: _styleOrder);
          kid(r, 'rFonts')?.remove();
          _insertOrdered(r, _fonts(set.headingFont), kRPrOrder);
          if (set.headingColor case final c?) {
            kid(r, 'color')?.remove();
            _insertOrdered(r, wv('color', c), kRPrOrder);
          }
        }
      };

  /// Belgede şu an kullanılan tema (başlık, gövde) yazı tipleri — levhada
  /// seçili gösterilir.
  static (String?, String?) themeFonts(DocxPackage pkg) {
    String? major, minor;
    final t = pkg.read('word/theme/theme1.xml');
    for (final e in t?.rootElement.descendantElements ?? const <XmlElement>[]) {
      if (e.name.local != 'latin') continue;
      final parent = e.parent;
      if (parent is XmlElement && parent.name.local == 'majorFont') {
        major ??= e.getAttribute('typeface');
      }
      if (parent is XmlElement && parent.name.local == 'minorFont') {
        minor ??= e.getAttribute('typeface');
      }
    }
    final root = pkg.read('word/styles.xml')?.rootElement;
    final dd = kid(kid(kid(kid(root, 'docDefaults'), 'rPrDefault'), 'rPr'), 'rFonts');
    minor = attrOf(dd, 'ascii') ?? minor;
    return (major, minor);
  }
}
