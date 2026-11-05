/// **Faz 37 madde 7 — DOCX'e yazı tipi gömme.**
///
/// Word'ün "Yazı tiplerini dosyaya katıştır"ı: `word/fonts/*.odttf`
/// (ECMA-376 §17.8.1: ilk 32 bayt GUID anahtarıyla XOR'lanır) +
/// `fontTable.xml` `w:embedRegular/Bold/Italic/BoldItalic` + `settings.xml`
/// `w:embedTrueTypeFonts`. Dağıtılabilir olduğu için yalnız açık lisanslı
/// metrik eşleri gömülür: belgedeki Calibri → **Carlito**, Times New Roman /
/// Georgia / Cambria → **Tinos** adıyla yazılır (satır kırılımı aynı kalır,
/// belge her cihazda bizdeki gibi görünür). OFL 1.1 gömmeye izin verir.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'docx_package.dart';
import 'docx_style_ops.dart' show DocxOp;

const kFontTableCt =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml';
const kFontTableRel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable';
const kFontRel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/font';
const kSettingsCt =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml';
const kSettingsRel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings';
const kOdttfCt = 'application/vnd.openxmlformats-officedocument.obfuscatedFont';

/// Belgedeki ad → gömülecek aile.
const kEmbedFamilyFor = {
  'calibri': 'Carlito',
  'carlito': 'Carlito',
  'times new roman': 'Tinos',
  'tinos': 'Tinos',
  'georgia': 'Tinos',
  'cambria': 'Tinos',
};

abstract final class DocxFonts {
  /// GUID anahtarıyla gizleme (aynı işlem açar da: XOR).
  static Uint8List obfuscate(Uint8List font, String guid) {
    final hex = guid.replaceAll(RegExp(r'[{}\-]'), '');
    final key = [
      for (var i = 0; i < 16; i++)
        int.parse(hex.substring(30 - 2 * i, 32 - 2 * i), radix: 16),
    ];
    final out = Uint8List.fromList(font);
    for (var i = 0; i < 32 && i < out.length; i++) {
      out[i] ^= key[i % 16];
    }
    return out;
  }

  static String newGuid(Random rnd) {
    String h(int n) => List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join().toUpperCase();
    return '{${h(8)}-${h(4)}-${h(4)}-${h(4)}-${h(12)}}';
  }

  /// Belgede geçen yazı tipi adları (rFonts ascii/hAnsi, tema hariç).
  static Set<String> usedFonts(DocxPackage pkg) {
    final out = <String>{};
    for (final name in const ['word/document.xml', 'word/styles.xml']) {
      for (final e in pkg.read(name)?.rootElement.descendantElements ?? const <XmlElement>[]) {
        if (e.name.local != 'rFonts') continue;
        for (final a in const ['ascii', 'hAnsi', 'cs']) {
          final v = attrOf(e, a);
          if (v != null && v.isNotEmpty) out.add(v);
        }
      }
    }
    // Tema yazı tipi (rFonts yoksa varsayılan Calibri).
    final theme = pkg.read('word/theme/theme1.xml');
    for (final e in theme?.rootElement.descendantElements ?? const <XmlElement>[]) {
      if (e.name.local == 'latin' && e.parent is XmlElement &&
          const {'majorFont', 'minorFont'}.contains((e.parent as XmlElement).name.local)) {
        final v = e.getAttribute('typeface');
        if (v != null && v.isNotEmpty) out.add(v);
      }
    }
    if (out.isEmpty) out.add('Calibri');
    return out;
  }

  /// [files]: `Carlito-Regular` … `Tinos-BoldItalic` → TTF baytı.
  static DocxOp embed(Map<String, Uint8List> files, {int seed = 0}) => (pkg) {
        final rnd = seed == 0 ? Random.secure() : Random(seed);
        final used = usedFonts(pkg);
        final families = {
          for (final f in used)
            if (kEmbedFamilyFor[f.toLowerCase()] case final fam?) fam,
        };
        if (families.isEmpty) return;
        // 1) Adlar metrik eşine çevrilir (belge + stiller + tema).
        String? map(String? v) =>
            v == null ? null : kEmbedFamilyFor[v.toLowerCase()];
        for (final name in const ['word/document.xml', 'word/styles.xml']) {
          final d = pkg.part(name);
          for (final e in d?.rootElement.descendantElements ?? const <XmlElement>[]) {
            if (e.name.local != 'rFonts') continue;
            for (final a in e.attributes) {
              if (const {'ascii', 'hAnsi', 'cs', 'eastAsia'}.contains(a.name.local)) {
                final m = map(a.value);
                if (m != null) a.value = m;
              }
            }
          }
        }
        if (pkg.has('word/theme/theme1.xml')) {
          for (final e in pkg.part('word/theme/theme1.xml')!.rootElement.descendantElements) {
            if (e.name.local == 'latin') {
              final m = map(e.getAttribute('typeface'));
              if (m != null) e.setAttribute('typeface', m);
            }
          }
        }
        // 2) fontTable.
        var ft = pkg.part('word/fontTable.xml');
        if (ft == null) {
          ft = XmlDocument.parse('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<w:fonts xmlns:w="$kW" xmlns:r="$kR"/>');
          pkg.putXml('word/fontTable.xml', ft);
          pkg.ensureOverride('word/fontTable.xml', kFontTableCt);
          pkg.relate(kFontTableRel, 'fontTable.xml');
        }
        final root = ft.rootElement;
        if (!root.attributes.any((a) => a.name.prefix == 'xmlns' && a.name.local == 'r')) {
          root.attributes.add(XmlAttribute(XmlName('r', 'xmlns'), kR));
        }
        pkg.ensureDefault('odttf', kOdttfCt);
        const rels = 'word/_rels/fontTable.xml.rels';
        var rd = pkg.part(rels);
        if (rd == null) {
          rd = XmlDocument.parse('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<Relationships xmlns="$kPkgRels"/>');
          pkg.putXml(rels, rd);
        }
        var n = 1;
        for (final fam in families) {
          XmlElement? font;
          for (final f in kids(root, 'font')) {
            if (attrOf(f, 'name') == fam) font = f;
          }
          if (font == null) {
            font = w('font', attrs: {'name': fam}, kids: [
              wv('charset', '00'),
              wv('family', fam == 'Tinos' ? 'roman' : 'swiss'),
              wv('pitch', 'variable'),
            ]);
            root.children.add(font);
          }
          font.children.removeWhere((x) => x is XmlElement && x.name.local.startsWith('embed'));
          for (final (style, tag) in const [
            ('Regular', 'embedRegular'),
            ('Bold', 'embedBold'),
            ('Italic', 'embedItalic'),
            ('BoldItalic', 'embedBoldItalic'),
          ]) {
            final ttf = files['$fam-$style'];
            if (ttf == null) continue;
            final guid = newGuid(rnd);
            final file = 'font${n++}.odttf';
            pkg.putBytes('word/fonts/$file', obfuscate(ttf, guid));
            final id = 'rIdF${n - 1}';
            rd.rootElement.children.add(XmlElement(XmlName('Relationship'), [
              XmlAttribute(XmlName('Id'), id),
              XmlAttribute(XmlName('Type'), kFontRel),
              XmlAttribute(XmlName('Target'), 'fonts/$file'),
            ]));
            font.children.add(w(tag, attrs: {'fontKey': guid, 'r:id': id}));
          }
        }
        // 3) settings.xml: katıştırma açık (yalnız kullanılan karakterler
        // DEĞİL — tam yazı tipi; düzenleyen kişi de aynı yazı tipini görür).
        var st = pkg.part('word/settings.xml');
        if (st == null) {
          st = XmlDocument.parse('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<w:settings xmlns:w="$kW"/>');
          pkg.putXml('word/settings.xml', st);
          pkg.ensureOverride('word/settings.xml', kSettingsCt);
          pkg.relate(kSettingsRel, 'settings.xml');
        }
        final sr = st.rootElement;
        if (kid(sr, 'embedTrueTypeFonts') == null) {
          // Şemada ilk öğelerden (writeProtection, view, zoom … sonrası);
          // başa yakın konur.
          var at = 0;
          for (final c in sr.childElements) {
            if (const {'writeProtection', 'view', 'zoom', 'removePersonalInformation', 'removeDateAndTime', 'doNotDisplayPageBoundaries', 'displayBackgroundShape', 'printPostScriptOverText', 'printFractionalCharacterWidth', 'printFormsData'}.contains(c.name.local)) {
              at = sr.children.indexOf(c) + 1;
            }
          }
          sr.children.insert(at, w('embedTrueTypeFonts'));
        }
      };
}
