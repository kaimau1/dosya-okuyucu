import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'office_zip_guard.dart';

/// UDF neden açılamadı (kullanıcıya "ne oldu, ne yapmalı" metni seçmek için).
enum UdfFailure { corrupt, encrypted }

class UdfError implements Exception {
  final UdfFailure kind;
  const UdfError(this.kind);
  @override
  String toString() => 'UdfError($kind)';
}

/// **UYAP Doküman Editörü (.udf) → .docx** (P23, 2026-11-20).
///
/// UDF = ZIP içinde `content.xml`: `<content>` CDATA tüm düz metin;
/// `<elements>` altında `<paragraph>` / `<table><row><cell>` ve paragraf
/// içinde metne `startOffset`+`length` ile bakan `<content>` parçaları
/// (yazı tipi, punto, kalın, eğik, renk) ile `<image imageData=base64>`.
/// Ayrı görüntüleyici YAZILMAZ: belge Word paketine çevrilir, Word
/// okuyucusunun çizimi, PDF'e aktarımı ve paylaşımı aynen kullanılır.
abstract final class UdfReader {
  /// UYAP editörü Java Swing: hiza `StyleConstants` (0 sol, 1 orta, 2 sağ,
  /// 3 iki yana), ölçüler punto, renk işaretli ARGB tamsayı.
  static const _jc = {'1': 'center', '2': 'right', '3': 'both'};

  /// Arama/Akıllı düzen için düz metin ('' = okunamadı).
  static String plainText(Uint8List bytes) {
    try {
      return _text(_parse(bytes).rootElement);
    } catch (_) {
      return '';
    }
  }

  /// UDF baytlarını geçerli bir .docx paketine çevirir; [UdfError] atar.
  static Uint8List toDocx(Uint8List bytes) {
    final root = _parse(bytes).rootElement;
    return _DocxBuilder(root, _text(root)).build();
  }

  static XmlDocument _parse(Uint8List bytes) {
    if (bytes.length < 30 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw const UdfError(UdfFailure.corrupt);
    }
    // ZIP yerel başlığında genel amaçlı bayrak biti 0 = parçalar şifreli.
    if ((bytes[6] & 1) == 1) throw const UdfError(UdfFailure.encrypted);
    try {
      final zip = OfficeZipGuard.decode(bytes);
      final f = zip.files.where((f) => f.name == 'content.xml').firstOrNull;
      if (f == null) throw const UdfError(UdfFailure.corrupt);
      final xml = XmlDocument.parse(
          utf8.decode(f.content as List<int>, allowMalformed: true));
      if (xml.rootElement.name.local != 'template') {
        throw const UdfError(UdfFailure.corrupt);
      }
      return xml;
    } on UdfError {
      rethrow;
    } catch (_) {
      throw const UdfError(UdfFailure.corrupt);
    }
  }

  static String _text(XmlElement root) =>
      (root.getElement('content')?.innerText ?? '').replaceAll('\r', '');
}

class _DocxBuilder {
  final XmlElement root;
  final String text;
  _DocxBuilder(this.root, this.text);

  final _media = <String, Uint8List>{};
  final _body = StringBuffer();
  late final double _textWidthPt;
  late final String _font;
  late final double _size;

  static const _esc = HtmlEscape(HtmlEscapeMode.element);
  // XML 1.0'da yasak denetim karakterleri (sekme hariç).
  static final _bad = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');

  Uint8List build() {
    final page = root.getElement('properties')?.getElement('pageFormat');
    double pt(String name, double def) =>
        double.tryParse(page?.getAttribute(name) ?? '') ?? def;
    // A4 nokta ölçüsü; Java PageFormat: 0 = yatay.
    final landscape = page?.getAttribute('paperOrientation') == '0';
    final w = landscape ? 841.89 : 595.28, h = landscape ? 595.28 : 841.89;
    final l = pt('leftMargin', 70.87), r = pt('rightMargin', 70.87);
    final t = pt('topMargin', 56.69), b = pt('bottomMargin', 56.69);
    _textWidthPt = (w - l - r).clamp(100.0, w);

    final styles = root.getElement('styles')?.findElements('style') ?? const [];
    final resolver =
        root.getElement('elements')?.getAttribute('resolver') ?? 'hvl-default';
    final def = styles.where((s) => s.getAttribute('name') == resolver).firstOrNull ??
        styles.firstOrNull;
    _font = def?.getAttribute('family') ?? 'Times New Roman';
    _size = double.tryParse(def?.getAttribute('size') ?? '') ?? 12;

    final elements = root.getElement('elements');
    if (elements != null) _blocks(elements);
    if (_body.isEmpty) {
      // Biçim bilgisi yoksa metin satır satır paragraf olur.
      for (final line in text.split('\n')) {
        _body.write('<w:p>${_run(line, const {})}</w:p>');
      }
    }

    int tw(double v) => (v * 20).round();
    final doc = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:document xmlns:w="$_w" xmlns:r="$_r" xmlns:wp="$_wp" '
        'xmlns:a="$_a" xmlns:pic="$_pic"><w:body>$_body'
        '<w:sectPr><w:pgSz w:w="${tw(w)}" w:h="${tw(h)}"'
        '${landscape ? ' w:orient="landscape"' : ''}/>'
        '<w:pgMar w:top="${tw(t)}" w:right="${tw(r)}" w:bottom="${tw(b)}" '
        'w:left="${tw(l)}" w:header="708" w:footer="708" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';
    final styleXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:styles xmlns:w="$_w"><w:docDefaults><w:rPrDefault><w:rPr>'
        '<w:rFonts w:ascii="${_attr(_font)}" w:hAnsi="${_attr(_font)}" '
        'w:cs="${_attr(_font)}"/><w:sz w:val="${(_size * 2).round()}"/>'
        '<w:szCs w:val="${(_size * 2).round()}"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="0"/></w:pPr></w:pPrDefault>'
        '</w:docDefaults><w:style w:type="paragraph" w:default="1" '
        'w:styleId="Normal"><w:name w:val="Normal"/></w:style></w:styles>';
    final rels = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="$_pr"><Relationship Id="rId1" '
        'Type="$_r/styles" Target="styles.xml"/>');
    _media.forEach((name, _) => rels.write('<Relationship Id="${_rid(name)}" '
        'Type="$_r/image" Target="media/$name"/>'));
    rels.write('</Relationships>');

    final archive = Archive();
    void add(String name, List<int> data) =>
        archive.addFile(ArchiveFile(name, data.length, data));
    add('[Content_Types].xml', utf8.encode(_contentTypes));
    add('_rels/.rels', utf8.encode(_rootRels));
    add('word/document.xml', utf8.encode(doc));
    add('word/styles.xml', utf8.encode(styleXml));
    add('word/_rels/document.xml.rels', utf8.encode(rels.toString()));
    _media.forEach((name, data) => add('word/media/$name', data));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Blok düzeyi: paragraf, tablo; tanınmayan sarmalayıcının içine inilir
  /// (içerik kaybolmasın). Üst/alt bilgi gövdeye akar.
  // ponytail: üst/alt bilgi, madde imi/numara ve hücre birleştirme çevrilmez;
  // gerçek UDF örneğinde eksik görünürse eklenir.
  void _blocks(XmlElement parent) {
    for (final e in parent.childElements) {
      switch (e.name.local) {
        case 'paragraph':
          _body.write(_paragraph(e));
        case 'table':
          _body.write(_table(e));
        default:
          _blocks(e);
      }
    }
  }

  String _paragraph(XmlElement p) {
    final ppr = StringBuffer();
    final jc = UdfReader._jc[p.getAttribute('Alignment')];
    if (jc != null) ppr.write('<w:jc w:val="$jc"/>');
    int tw(String a) => ((double.tryParse(p.getAttribute(a) ?? '') ?? 0) * 20).round();
    final left = tw('LeftIndent'), right = tw('RightIndent'), first = tw('FirstLineIndent');
    if (left != 0 || right != 0 || first != 0) {
      ppr.write('<w:ind w:left="$left" w:right="$right"'
          '${first >= 0 ? ' w:firstLine="$first"' : ' w:hanging="${-first}"'}/>');
    }
    final before = tw('SpaceAbove'), after = tw('SpaceBelow');
    if (before > 0 || after > 0) {
      ppr.write('<w:spacing w:before="$before" w:after="$after"/>');
    }
    final runs = StringBuffer();
    for (final c in p.childElements) {
      if (c.name.local == 'image') {
        runs.write(_image(c));
        continue;
      }
      final start = int.tryParse(c.getAttribute('startOffset') ?? '');
      final len = int.tryParse(c.getAttribute('length') ?? '');
      if (start == null || len == null || start < 0 || start >= text.length) {
        continue;
      }
      final end = (start + len).clamp(start, text.length);
      runs.write(_run(text.substring(start, end).replaceAll('\n', ''),
          {for (final a in c.attributes) a.name.local: a.value}));
    }
    return '<w:p>${ppr.isEmpty ? '' : '<w:pPr>$ppr</w:pPr>'}$runs</w:p>';
  }

  String _run(String s, Map<String, String> a) {
    if (s.isEmpty) return '';
    final rpr = StringBuffer();
    final family = a['family'];
    if (family != null && family != _font) {
      final f = _attr(family);
      rpr.write('<w:rFonts w:ascii="$f" w:hAnsi="$f" w:cs="$f"/>');
    }
    if (a['bold'] == 'true') rpr.write('<w:b/>');
    if (a['italic'] == 'true') rpr.write('<w:i/>');
    if (a['strikethrough'] == 'true') rpr.write('<w:strike/>');
    final color = int.tryParse(a['foreground'] ?? '');
    if (color != null && (color & 0xFFFFFF) != 0) {
      rpr.write('<w:color w:val="'
          '${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}"/>');
    }
    final size = double.tryParse(a['size'] ?? '');
    if (size != null && size > 0 && size != _size) {
      rpr.write('<w:sz w:val="${(size * 2).round()}"/>'
          '<w:szCs w:val="${(size * 2).round()}"/>');
    }
    if (a['underline'] == 'true') rpr.write('<w:u w:val="single"/>');
    final pre = rpr.isEmpty ? '' : '<w:rPr>$rpr</w:rPr>';
    final parts = s.replaceAll(_bad, '').split('\t');
    final b = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) b.write('<w:r>$pre<w:tab/></w:r>');
      if (parts[i].isNotEmpty) {
        b.write('<w:r>$pre<w:t xml:space="preserve">'
            '${_esc.convert(parts[i])}</w:t></w:r>');
      }
    }
    return b.toString();
  }

  String _table(XmlElement t) {
    final spans = (t.getAttribute('columnSpans') ?? '')
        .split(',')
        .map((s) => double.tryParse(s.trim()))
        .whereType<double>()
        .toList();
    final rows = t.findElements('row').toList();
    final cols = rows.fold<int>(spans.length,
        (m, r) => r.findElements('cell').length > m ? r.findElements('cell').length : m);
    if (cols == 0) return '';
    final sum = spans.fold<double>(0, (a, b) => a + b);
    // Sütun genişliği oranlı; toplam metin alanına sığdırılır.
    int width(int i) => (i < spans.length && sum > 0
            ? spans[i] / sum * _textWidthPt * 20
            : _textWidthPt * 20 / cols)
        .round();
    final border = t.getAttribute('border') == 'borderNone' ? 'nil' : 'single';
    final b = StringBuffer('<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>');
    for (final side in const ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']) {
      b.write('<w:$side w:val="$border" w:sz="4" w:space="0" w:color="000000"/>');
    }
    b.write('</w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>');
    for (var i = 0; i < cols; i++) {
      b.write('<w:gridCol w:w="${width(i)}"/>');
    }
    b.write('</w:tblGrid>');
    for (final row in rows) {
      b.write('<w:tr>');
      final cells = row.findElements('cell').toList();
      for (var i = 0; i < cols; i++) {
        final inner = StringBuffer();
        if (i < cells.length) {
          for (final p in cells[i].findAllElements('paragraph')) {
            inner.write(_paragraph(p));
          }
        }
        b.write('<w:tc><w:tcPr><w:tcW w:w="${width(i)}" w:type="dxa"/></w:tcPr>'
            '${inner.isEmpty ? '<w:p/>' : inner}</w:tc>');
      }
      b.write('</w:tr>');
    }
    b.write('</w:tbl>');
    return b.toString();
  }

  String _image(XmlElement e) {
    final Uint8List data;
    try {
      data = base64.decode(
          (e.getAttribute('imageData') ?? '').replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return '';
    }
    if (data.length < 24) return '';
    final png = data[0] == 0x89 && data[1] == 0x50;
    final name = 'udf${_media.length + 1}.${png ? 'png' : 'jpeg'}';
    _media[name] = data;
    // Boyut: öznitelik (punto) → resim başlığı (piksel ≈ punto) → varsayılan.
    var size = (double.tryParse(e.getAttribute('width') ?? ''),
        double.tryParse(e.getAttribute('height') ?? ''));
    if (size.$1 == null || size.$2 == null) size = _pixels(data, png);
    var wPt = size.$1 ?? 200.0, hPt = size.$2 ?? 150.0;
    if (wPt > _textWidthPt) {
      hPt = hPt * _textWidthPt / wPt;
      wPt = _textWidthPt;
    }
    final cx = (wPt * 12700).round(), cy = (hPt * 12700).round();
    final id = _media.length;
    return '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/><wp:docPr id="$id" name="Resim $id"/>'
        '<a:graphic><a:graphicData uri="$_pic">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="$name"/><pic:cNvPicPr/>'
        '</pic:nvPicPr><pic:blipFill><a:blip r:embed="${_rid(name)}"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr>'
        '<a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
        '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
  }

  /// PNG IHDR ya da JPEG SOF başlığından piksel boyu (bulunamazsa null).
  static (double?, double?) _pixels(Uint8List d, bool png) {
    final v = ByteData.sublistView(d);
    if (png) return (v.getUint32(16).toDouble(), v.getUint32(20).toDouble());
    var i = 2;
    while (i + 9 < d.length && d[i] == 0xFF) {
      final m = d[i + 1];
      if (m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) {
        return (v.getUint16(i + 7).toDouble(), v.getUint16(i + 5).toDouble());
      }
      i += 2 + v.getUint16(i + 2);
    }
    return (null, null);
  }

  static String _rid(String media) => 'rIdU${media.replaceAll(RegExp(r'\D'), '')}';
  static String _attr(String s) =>
      const HtmlEscape(HtmlEscapeMode.attribute).convert(s);

  static const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const _r =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _wp =
      'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
  static const _a = 'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const _pic = 'http://schemas.openxmlformats.org/drawingml/2006/picture';
  static const _pr = 'http://schemas.openxmlformats.org/package/2006/relationships';
  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="png" ContentType="image/png"/>'
      '<Default Extension="jpeg" ContentType="image/jpeg"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '</Types>';
  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<Relationships xmlns="$_pr"><Relationship Id="rId1" '
      'Type="$_r/officeDocument" Target="word/document.xml"/></Relationships>';
}
