/// **Office → HTML → PDF** — Faz 39 madde 11 ("PDF'e Word/Excel/PPT aktarım").
///
/// Belgenin yapısı (başlıklar, paragraflar, kalın/italik/altı çizili, punto,
/// hizalama, tablolar; Excel'de sayfa sayfa hücre tablosu; sunumda slayt
/// başına sayfa) yalın HTML'e çevrilir; HTML'den PDF'i Android'in kendi
/// yazdırma motoru üretir (`Printing.convertHtml` — WebView, yeni bağımlılık
/// yok). Görsel/şekil taşınmaz (metin ve tablo odaklı dışa aktarım).
///
/// Saf fonksiyonlar (cihazsız testli); büyük dosya için izolatta çağrılır.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'xlsx_editor.dart';
import 'office_zip_guard.dart';

abstract final class OfficeHtml {
  /// Excel'de sayfa başına en çok satır/sütun (dev tabloda HTML şişmesin).
  static const maxRows = 5000;
  static const maxCols = 60;

  static String fromBytes(Uint8List bytes, String extension, {String title = ''}) =>
      switch (extension.toLowerCase().replaceFirst('.', '')) {
        'docx' => docx(bytes, title: title),
        'xlsx' => xlsx(bytes, title: title),
        'pptx' => pptx(bytes, title: title),
        _ => throw UnsupportedError('Desteklenmeyen biçim: $extension'),
      };

  static String esc(String s) => const HtmlEscape().convert(s);

  static String _page(String title, String body, {bool landscape = false}) =>
      '<!DOCTYPE html><html><head><meta charset="utf-8"><title>${esc(title)}</title>'
      '<style>'
      '@page{size:A4${landscape ? ' landscape' : ''};margin:18mm}'
      'body{font-family:Carlito,Calibri,Arial,sans-serif;font-size:11pt;line-height:1.35;color:#000}'
      'p{margin:0 0 6pt}h1{font-size:20pt}h2{font-size:16pt}h3{font-size:13pt}'
      'table{border-collapse:collapse;margin:6pt 0;width:auto}'
      'td,th{border:0.5pt solid #999;padding:2pt 4pt;vertical-align:top;font-size:9pt}'
      '.slide{page-break-after:always;border:0.5pt solid #ccc;padding:12mm;min-height:150mm}'
      '.slide:last-child{page-break-after:auto}.sheet{page-break-after:always}'
      '.sheet:last-child{page-break-after:auto}.num{text-align:right}'
      '</style></head><body>$body</body></html>';

  static XmlDocument? _xml(Archive a, String name) {
    final f = a.findFile(name);
    if (f == null) return null;
    return XmlDocument.parse(utf8.decode(f.content as List<int>, allowMalformed: true));
  }

  static Iterable<XmlElement> _kids(XmlElement e, String local) =>
      e.childElements.where((c) => c.name.local == local);

  static XmlElement? _kid(XmlElement e, String local) {
    for (final c in e.childElements) {
      if (c.name.local == local) return c;
    }
    return null;
  }

  static String? _val(XmlElement? e) {
    if (e == null) return null;
    for (final a in e.attributes) {
      if (a.name.local == 'val') return a.value;
    }
    return null;
  }

  /// Açık/kapalı özellik: `<w:b/>` açık, `<w:b w:val="0|false"/>` kapalı.
  static bool _on(XmlElement? e) {
    if (e == null) return false;
    final v = _val(e);
    return v == null || !(v == '0' || v == 'false' || v == 'none');
  }

  // ── Word ─────────────────────────────────────────────────────────────────

  static String docx(Uint8List bytes, {String title = ''}) {
    final archive = OfficeZipGuard.decode(bytes);
    final doc = _xml(archive, 'word/document.xml');
    if (doc == null) throw const FormatException('word/document.xml yok');
    final body = doc.rootElement.descendants
        .whereType<XmlElement>()
        .firstWhere((e) => e.name.local == 'body');
    final sb = StringBuffer();
    for (final block in body.childElements) {
      switch (block.name.local) {
        case 'p':
          sb.write(_paragraph(block));
        case 'tbl':
          sb.write(_table(block));
      }
    }
    return _page(title, sb.toString());
  }

  static String _paragraph(XmlElement p) {
    final ppr = _kid(p, 'pPr');
    final style = (_val(ppr == null ? null : _kid(ppr, 'pStyle')) ?? '').toLowerCase();
    final jc = _val(ppr == null ? null : _kid(ppr, 'jc'));
    final heading = RegExp(r'(heading|baslik|başlık)\s*([1-6])').firstMatch(style);
    final tag = style == 'title' || style == 'konubasligi'
        ? 'h1'
        : heading != null
            ? 'h${heading.group(2)}'
            : 'p';
    final align = switch (jc) {
      'center' => 'center',
      'right' || 'end' => 'right',
      'both' || 'distribute' => 'justify',
      _ => null,
    };
    final runs = StringBuffer();
    for (final r in p.descendants.whereType<XmlElement>()) {
      if (r.name.local != 'r') continue;
      final rpr = _kid(r, 'rPr');
      final text = StringBuffer();
      for (final c in r.childElements) {
        switch (c.name.local) {
          case 't':
            text.write(esc(c.innerText));
          case 'tab':
            text.write('&emsp;');
          case 'br' || 'cr':
            text.write('<br>');
        }
      }
      if (text.isEmpty) continue;
      final css = <String>[];
      final sz = _val(rpr == null ? null : _kid(rpr, 'sz'));
      final half = int.tryParse(sz ?? '');
      if (half != null && tag == 'p') css.add('font-size:${half / 2}pt');
      final color = _val(rpr == null ? null : _kid(rpr, 'color'));
      if (color != null && RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(color)) {
        css.add('color:#$color');
      }
      var html = text.toString();
      if (rpr != null) {
        if (_on(_kid(rpr, 'b'))) html = '<b>$html</b>';
        if (_on(_kid(rpr, 'i'))) html = '<i>$html</i>';
        if (_on(_kid(rpr, 'u'))) html = '<u>$html</u>';
        if (_on(_kid(rpr, 'strike'))) html = '<s>$html</s>';
      }
      runs.write(css.isEmpty ? html : '<span style="${css.join(';')}">$html</span>');
    }
    final content = runs.isEmpty ? '&nbsp;' : runs.toString();
    final attr = align == null ? '' : ' style="text-align:$align"';
    return '<$tag$attr>$content</$tag>';
  }

  static String _table(XmlElement tbl) {
    final sb = StringBuffer('<table>');
    for (final tr in _kids(tbl, 'tr')) {
      sb.write('<tr>');
      for (final tc in _kids(tr, 'tc')) {
        final tcpr = _kid(tc, 'tcPr');
        final span = int.tryParse(_val(tcpr == null ? null : _kid(tcpr, 'gridSpan')) ?? '');
        sb.write(span != null && span > 1 ? '<td colspan="$span">' : '<td>');
        for (final p in _kids(tc, 'p')) {
          sb.write(_paragraph(p));
        }
        for (final inner in _kids(tc, 'tbl')) {
          sb.write(_table(inner));
        }
        sb.write('</td>');
      }
      sb.write('</tr>');
    }
    sb.write('</table>');
    return sb.toString();
  }

  // ── Excel ────────────────────────────────────────────────────────────────

  static String xlsx(Uint8List bytes, {String title = ''}) {
    final book = XlsxEditor.parse(bytes);
    final sb = StringBuffer();
    for (final sheet in book.sheets) {
      final rows = sheet.rows;
      // Sondaki boş satır/sütunlar atılır.
      var lastRow = -1, lastCol = -1;
      for (var r = 0; r < rows.length && r < maxRows; r++) {
        for (var c = 0; c < rows[r].length && c < maxCols; c++) {
          if (rows[r][c].trim().isNotEmpty) {
            if (r > lastRow) lastRow = r;
            if (c > lastCol) lastCol = c;
          }
        }
      }
      sb.write('<div class="sheet"><h2>${esc(sheet.name)}</h2>');
      if (lastRow < 0) {
        sb.write('<p>&nbsp;</p></div>');
        continue;
      }
      sb.write('<table>');
      for (var r = 0; r <= lastRow; r++) {
        sb.write('<tr>');
        for (var c = 0; c <= lastCol; c++) {
          final raw = c < rows[r].length ? rows[r][c] : '';
          final computed =
              raw.startsWith('=') ? (sheet.cachedResultAt(r, c) ?? raw) : raw;
          final view = raw.isEmpty
              ? null
              : sheet.viewAt(r, c, computed);
          final cls = view?.numeric == true ? ' class="num"' : '';
          sb.write('<td$cls>${esc(view?.text ?? '')}</td>');
        }
        sb.write('</tr>');
      }
      sb.write('</table></div>');
    }
    return _page(title, sb.toString(), landscape: true);
  }

  // ── Sunum ────────────────────────────────────────────────────────────────

  static String pptx(Uint8List bytes, {String title = ''}) {
    final archive = OfficeZipGuard.decode(bytes);
    final slides = [
      for (final f in archive.files)
        if (RegExp(r'^ppt/slides/slide(\d+)\.xml$').hasMatch(f.name)) f.name,
    ]..sort((a, b) => _num(a).compareTo(_num(b)));
    final sb = StringBuffer();
    for (final name in slides) {
      final doc = _xml(archive, name);
      if (doc == null) continue;
      sb.write('<div class="slide">');
      var first = true;
      for (final sp in doc.descendants.whereType<XmlElement>()) {
        if (sp.name.local != 'txBody') continue;
        for (final p in _kids(sp, 'p')) {
          final text = p.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join();
          if (text.trim().isEmpty) continue;
          sb.write(first ? '<h2>${esc(text)}</h2>' : '<p>${esc(text)}</p>');
          first = false;
        }
      }
      sb.write('</div>');
    }
    return _page(title, sb.toString(), landscape: true);
  }

  static int _num(String path) =>
      int.parse(RegExp(r'(\d+)\.xml$').firstMatch(path)!.group(1)!);
}
