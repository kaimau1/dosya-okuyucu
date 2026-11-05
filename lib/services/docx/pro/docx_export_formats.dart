/// **Faz 37 madde 11 — ODT / RTF / Markdown / düz metin dışa aktarımı.**
///
/// Editör modelinden ([DocxDocument]): başlık düzeyi, harf biçimi (kalın,
/// eğik, altı/üstü çizili, punto, renk), hizalama, liste etiketleri, tablolar
/// (hücre paragrafları), sayfa sonu. Hepsi saf Dart (izolatta koşar).
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../docx_document.dart';
import '../docx_styles.dart';
import 'docx_package.dart' show DocxPro;

/// Biçimli parça: aynı görünüşlü ardışık harfler.
class _Span {
  final String text;
  final DocxRunLook look;
  final bool link;
  const _Span(this.text, this.look, {this.link = false});
}

/// Gövde blokları: paragraf ya da tablo.
sealed class _Block {}

class _ParaBlock extends _Block {
  final DocxPara para;
  final int index;
  _ParaBlock(this.para, this.index);
}

class _TableBlock extends _Block {
  /// satır → sütun → hücre paragrafları (dizinleriyle).
  final List<List<List<(DocxPara, int)>>> rows;
  _TableBlock(this.rows);
}

abstract final class DocxExportFormats {
  /// [fmt]: `odt` | `rtf` | `md` | `txt` — ayrıştırma + üretim izolatta.
  static Future<Uint8List> inBackground(Uint8List docx, String fmt) {
    Uint8List work() {
      final doc = DocxDocument.parse(docx);
      return switch (fmt) {
        'odt' => toOdt(doc),
        'rtf' => Uint8List.fromList(latin1.encode(toRtf(doc))),
        'md' => Uint8List.fromList(utf8.encode(toMarkdown(doc))),
        _ => Uint8List.fromList(utf8.encode(toText(doc))),
      };
    }

    if (DocxPro.inIsolate) return Isolate.run(work);
    return Future.value(work());
  }

  static List<_Span> _spans(DocxPara p) {
    final out = <_Span>[];
    final sb = StringBuffer();
    DocxRunLook? cur;
    void flush() {
      if (sb.isNotEmpty && cur != null) out.add(_Span(sb.toString(), cur));
      sb.clear();
    }

    for (var k = 0; k < p.length; k++) {
      final a = p.atoms[k];
      if (a != null) {
        flush();
        cur = null;
        if (a.kind == DocxAtomKind.pageBreak) {
          out.add(_Span('\f', p.styles[k].effective));
        } else if (a.display.isNotEmpty) {
          out.add(_Span(a.display, p.styles[k].effective, link: a.kind == DocxAtomKind.link));
        }
        continue;
      }
      final l = p.styles[k].effective;
      if (cur != null && !_same(cur, l)) flush();
      cur = l;
      sb.write(p.text[k]);
    }
    flush();
    return out;
  }

  static bool _same(DocxRunLook a, DocxRunLook b) =>
      a.bold == b.bold &&
      a.italic == b.italic &&
      a.underline == b.underline &&
      a.strike == b.strike &&
      a.sizePt == b.sizePt &&
      a.color == b.color &&
      a.vertAlign == b.vertAlign;

  static List<_Block> _blocks(DocxDocument doc) {
    final out = <_Block>[];
    final paras = doc.paras;
    var i = 0;
    while (i < paras.length) {
      final p = paras[i];
      final cell = p.cell;
      if (cell == null) {
        out.add(_ParaBlock(p, i));
        i++;
        continue;
      }
      final table = cell.table;
      final rows = <List<List<(DocxPara, int)>>>[];
      while (i < paras.length && identical(paras[i].cell?.table, table)) {
        final c = paras[i].cell!;
        while (rows.length <= c.row) {
          rows.add([]);
        }
        final row = rows[c.row];
        if (row.isEmpty || !identical(row.last.first.$1.cell!.cell, c.cell)) {
          row.add([]);
        }
        row.last.add((paras[i], i));
        i++;
      }
      out.add(_TableBlock(rows));
    }
    return out;
  }

  static bool _numbered(String label) => RegExp(r'^[0-9ivxlcdmIVXLCDMa-zA-Z]+[.)]$').hasMatch(label);

  // ── Markdown ─────────────────────────────────────────────────────────────

  static String _mdEscape(String s) => s.replaceAllMapped(
      RegExp(r'([\\`*_\[\]<>|])'), (m) => '\\${m.group(1)}');

  static String _mdInline(DocxPara p) {
    final sb = StringBuffer();
    for (final s in _spans(p)) {
      if (s.text == '\f') continue;
      var t = _mdEscape(s.text);
      final lead = RegExp(r'^\s*').stringMatch(t)!;
      final trail = RegExp(r'\s*$').stringMatch(t)!;
      var core = t.trim();
      if (core.isEmpty) {
        sb.write(t);
        continue;
      }
      if (s.look.strike) core = '~~$core~~';
      if (s.look.italic) core = '*$core*';
      if (s.look.bold) core = '**$core**';
      t = '$lead$core$trail';
      sb.write(t);
    }
    return sb.toString();
  }

  static String toMarkdown(DocxDocument doc) {
    final labels = doc.listLabels();
    final out = <String>[];
    for (final b in _blocks(doc)) {
      switch (b) {
        case _ParaBlock(:final para, :final index):
          final text = _mdInline(para);
          final level = para.look.headingLevel;
          final label = index < labels.length ? labels[index] : '';
          if (para.atoms.any((a) => a?.kind == DocxAtomKind.pageBreak)) {
            if (text.trim().isNotEmpty) out.add(text);
            out.add('---');
          } else if (level > 0) {
            out.add('${'#' * level.clamp(1, 6)} ${text.trim()}');
          } else if (label.isNotEmpty) {
            final indent = '  ' * para.look.ilvl;
            out.add('$indent${_numbered(label) ? '1.' : '-'} ${text.trim()}');
          } else if (para.look.styleId == 'Quote' || para.look.styleId == 'IntenseQuote') {
            out.add('> ${text.trim()}');
          } else {
            out.add(text);
          }
        case _TableBlock(:final rows):
          if (rows.isEmpty) continue;
          final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
          String cell(List<(DocxPara, int)> c) =>
              c.map((x) => _mdInline(x.$1).trim()).join('<br>');
          for (var r = 0; r < rows.length; r++) {
            final cells = [for (var k = 0; k < cols; k++) k < rows[r].length ? cell(rows[r][k]) : ''];
            out.add('| ${cells.join(' | ')} |');
            if (r == 0) out.add('|${List.filled(cols, ' --- ').join('|')}|');
          }
      }
    }
    // Ardışık liste satırları arasında boş satır olmaz; diğer bloklar arası bir boş satır.
    final sb = StringBuffer();
    for (var k = 0; k < out.length; k++) {
      final line = out[k];
      sb.write(line);
      if (k + 1 < out.length) {
        final next = out[k + 1];
        final tight = (RegExp(r'^\s*(-|1\.) ').hasMatch(line) && RegExp(r'^\s*(-|1\.) ').hasMatch(next)) ||
            (line.startsWith('|') && next.startsWith('|'));
        sb.write(tight ? '\n' : '\n\n');
      }
    }
    return '${sb.toString().trimRight()}\n';
  }

  // ── düz metin ────────────────────────────────────────────────────────────

  static String toText(DocxDocument doc) {
    final labels = doc.listLabels();
    final out = <String>[];
    for (final b in _blocks(doc)) {
      switch (b) {
        case _ParaBlock(:final para, :final index):
          final label = index < labels.length ? labels[index] : '';
          final t = _spans(para).map((s) => s.text).join();
          out.add('${label.isEmpty ? '' : '$label '}$t');
        case _TableBlock(:final rows):
          for (final r in rows) {
            out.add(r.map((c) => c.map((x) => _spans(x.$1).map((s) => s.text).join()).join(' ')).join('\t'));
          }
      }
    }
    return '${out.join('\n')}\n';
  }

  // ── RTF ──────────────────────────────────────────────────────────────────

  static String _rtfText(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r == 0x5C || r == 0x7B || r == 0x7D) {
        sb.write('\\${String.fromCharCode(r)}');
      } else if (r == 0x09) {
        sb.write('\\tab ');
      } else if (r == 0x0C) {
        sb.write('\\page ');
      } else if (r == 0x0A) {
        sb.write('\\line ');
      } else if (r < 0x80) {
        sb.writeCharCode(r);
      } else if (r <= 0xFFFF) {
        // \uN işaretli 16 bit; yedek karakter '?'.
        sb.write('\\u${r > 0x7FFF ? r - 0x10000 : r}?');
      } else {
        final v = r - 0x10000;
        final hi = 0xD800 + (v >> 10), lo = 0xDC00 + (v & 0x3FF);
        sb.write('\\u${hi - 0x10000}?\\u${lo - 0x10000}?');
      }
    }
    return sb.toString();
  }

  static String toRtf(DocxDocument doc) {
    final colors = <int>[];
    int colorIdx(int? argb) {
      if (argb == null) return 0;
      final rgb = argb & 0xFFFFFF;
      var k = colors.indexOf(rgb);
      if (k < 0) {
        colors.add(rgb);
        k = colors.length - 1;
      }
      return k + 1;
    }

    final fonts = <String>['Calibri'];
    int fontIdx(String? f) {
      final name = (f == null || f.isEmpty) ? 'Calibri' : f;
      var k = fonts.indexOf(name);
      if (k < 0) {
        fonts.add(name);
        k = fonts.length - 1;
      }
      return k;
    }

    final labels = doc.listLabels();
    final body = StringBuffer();
    void writePara(DocxPara p, int index, {bool inCell = false}) {
      final look = p.look;
      final jc = switch (look.align) {
        'center' => '\\qc',
        'right' || 'end' => '\\qr',
        'both' => '\\qj',
        _ => '\\ql',
      };
      if (!inCell) body.write('\\pard');
      body.write('$jc\\sb${(look.spaceBeforePt * 20).round()}\\sa${(look.spaceAfterPt * 20).round()}');
      if (look.indentLeftPt > 0) body.write('\\li${(look.indentLeftPt * 20).round()}');
      if (look.headingLevel > 0) body.write('\\outlinelevel${look.headingLevel - 1}');
      if (look.bidi) body.write('\\rtlpar');
      body.write(' ');
      final label = index < labels.length ? labels[index] : '';
      if (label.isNotEmpty) body.write('${_rtfText(label)}\\tab ');
      for (final s in _spans(p)) {
        final l = s.look;
        body.write('{\\f${fontIdx(l.font)}\\fs${(l.sizePt * 2).round()}');
        if (l.bold) body.write('\\b');
        if (l.italic) body.write('\\i');
        if (l.underline || s.link) body.write('\\ul');
        if (l.strike) body.write('\\strike');
        if (l.vertAlign == 'superscript') body.write('\\super');
        if (l.vertAlign == 'subscript') body.write('\\sub');
        final c = colorIdx(l.color);
        if (c > 0) body.write('\\cf$c');
        body.write(' ${_rtfText(s.text)}}');
      }
      body.write(inCell ? '' : '\\par\n');
    }

    for (final b in _blocks(doc)) {
      switch (b) {
        case _ParaBlock(:final para, :final index):
          writePara(para, index);
        case _TableBlock(:final rows):
          for (final r in rows) {
            body.write('\\trowd\\trgaph108');
            final w = r.isEmpty ? 9000 : (9000 / r.length).floor();
            for (var k = 0; k < r.length; k++) {
              body.write('\\clbrdrt\\brdrs\\clbrdrl\\brdrs\\clbrdrb\\brdrs\\clbrdrr\\brdrs\\cellx${w * (k + 1)}');
            }
            body.write('\n');
            for (final c in r) {
              body.write('\\pard\\intbl');
              for (var j = 0; j < c.length; j++) {
                if (j > 0) body.write('\\par ');
                writePara(c[j].$1, c[j].$2, inCell: true);
              }
              body.write('\\cell\n');
            }
            body.write('\\row\n');
          }
          body.write('\\pard\n');
      }
    }
    final sb = StringBuffer('{\\rtf1\\ansi\\ansicpg1254\\uc1\\deff0\n{\\fonttbl');
    for (var k = 0; k < fonts.length; k++) {
      sb.write('{\\f$k\\fnil\\fcharset162 ${_rtfText(fonts[k])};}');
    }
    sb.write('}\n{\\colortbl;');
    for (final c in colors) {
      sb.write('\\red${(c >> 16) & 0xFF}\\green${(c >> 8) & 0xFF}\\blue${c & 0xFF};');
    }
    sb.write('}\n\\viewkind4\n');
    sb.write(body);
    sb.write('}\n');
    return sb.toString();
  }

  // ── ODT (OpenDocument Text) ──────────────────────────────────────────────

  static String _x(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static Uint8List toOdt(DocxDocument doc) {
    final autoStyles = <String, String>{}; // imza → ad
    final styleXml = StringBuffer();
    String textStyle(DocxRunLook l) {
      final props = [
        if (l.bold) 'fo:font-weight="bold"',
        if (l.italic) 'fo:font-style="italic"',
        if (l.underline) 'style:text-underline-style="solid" style:text-underline-width="auto" style:text-underline-color="font-color"',
        if (l.strike) 'style:text-line-through-style="solid"',
        'fo:font-size="${_n(l.sizePt <= 0 ? 11 : l.sizePt)}pt"',
        if (l.color != null) 'fo:color="#${(l.color! & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}"',
        if (l.font != null) 'style:font-name="${_x(l.font!)}"',
        if (l.vertAlign == 'superscript') 'style:text-position="super 58%"',
        if (l.vertAlign == 'subscript') 'style:text-position="sub 58%"',
      ].join(' ');
      final key = 'T|$props';
      return autoStyles[key] ??= () {
        final name = 'T${autoStyles.length + 1}';
        styleXml.write('<style:style style:name="$name" style:family="text"><style:text-properties $props/></style:style>');
        return name;
      }();
    }

    String paraStyle(DocxParaLook look, {bool breakBefore = false}) {
      final align = switch (look.align) {
        'center' => 'center',
        'right' || 'end' => 'end',
        'both' => 'justify',
        _ => 'start',
      };
      final props = [
        'fo:text-align="$align"',
        'fo:margin-top="${_n(look.spaceBeforePt)}pt"',
        'fo:margin-bottom="${_n(look.spaceAfterPt)}pt"',
        if (look.indentLeftPt > 0) 'fo:margin-left="${_n(look.indentLeftPt)}pt"',
        if (breakBefore || look.pageBreakBefore) 'fo:break-before="page"',
        if (look.bidi) 'style:writing-mode="rl-tb"',
      ].join(' ');
      final key = 'P|$props';
      return autoStyles[key] ??= () {
        final name = 'P${autoStyles.length + 1}';
        styleXml.write('<style:style style:name="$name" style:family="paragraph"><style:paragraph-properties $props/></style:style>');
        return name;
      }();
    }

    final labels = doc.listLabels();
    final body = StringBuffer();
    var breakNext = false;
    String inline(DocxPara p) {
      final sb = StringBuffer();
      for (final s in _spans(p)) {
        if (s.text == '\f') {
          breakNext = true;
          continue;
        }
        final parts = s.text.split('\t');
        sb.write('<text:span text:style-name="${textStyle(s.look)}">');
        for (var k = 0; k < parts.length; k++) {
          if (k > 0) sb.write('<text:tab/>');
          sb.write(_x(parts[k]).replaceAll('\n', '<text:line-break/>'));
        }
        sb.write('</text:span>');
      }
      return sb.toString();
    }

    void writePara(DocxPara p, int index) {
      final style = paraStyle(p.look, breakBefore: breakNext);
      breakNext = false;
      final label = index < labels.length ? labels[index] : '';
      final content = '${label.isEmpty ? '' : '${_x(label)}<text:tab/>'}${inline(p)}';
      final level = p.look.headingLevel;
      if (level > 0) {
        body.write('<text:h text:style-name="$style" text:outline-level="$level">$content</text:h>');
      } else {
        body.write('<text:p text:style-name="$style">$content</text:p>');
      }
    }

    var tables = 0;
    for (final b in _blocks(doc)) {
      switch (b) {
        case _ParaBlock(:final para, :final index):
          writePara(para, index);
        case _TableBlock(:final rows):
          tables++;
          final cols = rows.isEmpty ? 1 : rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
          body.write('<table:table table:name="Tablo$tables" table:style-name="Tbl">'
              '<table:table-column table:number-columns-repeated="$cols"/>');
          for (final r in rows) {
            body.write('<table:table-row>');
            for (var k = 0; k < cols; k++) {
              body.write('<table:table-cell table:style-name="Cell" office:value-type="string">');
              if (k < r.length) {
                for (final (p, i) in r[k]) {
                  writePara(p, i);
                }
              } else {
                body.write('<text:p/>');
              }
              body.write('</table:table-cell>');
            }
            body.write('</table:table-row>');
          }
          body.write('</table:table>');
      }
    }

    const ns = 'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
        'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
        'xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" office:version="1.3"';
    final content = '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-content $ns><office:automatic-styles>'
        '<style:style style:name="Tbl" style:family="table"><style:table-properties style:width="16cm" table:align="margins"/></style:style>'
        '<style:style style:name="Cell" style:family="table-cell"><style:table-cell-properties fo:border="0.5pt solid #000000" fo:padding="0.1cm"/></style:style>'
        '$styleXml</office:automatic-styles><office:body><office:text>$body</office:text></office:body></office:document-content>';
    final page = doc.pageSetup();
    String cm(int tw) => '${(tw / 566.93).toStringAsFixed(2)}cm';
    final styles = '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-styles $ns><office:styles>'
        '<style:default-style style:family="paragraph"><style:text-properties style:font-name="Calibri" fo:font-size="11pt" fo:language="tr" fo:country="TR"/></style:default-style>'
        '</office:styles><office:automatic-styles>'
        '<style:page-layout style:name="PL"><style:page-layout-properties fo:page-width="${cm(page.width)}" fo:page-height="${cm(page.height)}" '
        'style:print-orientation="${page.landscape ? 'landscape' : 'portrait'}" fo:margin-top="${cm(page.top)}" fo:margin-bottom="${cm(page.bottom)}" '
        'fo:margin-left="${cm(page.left)}" fo:margin-right="${cm(page.right)}"/></style:page-layout>'
        '</office:automatic-styles><office:master-styles><style:master-page style:name="Standard" style:page-layout-name="PL"/></office:master-styles>'
        '</office:document-styles>';
    const manifest = '<?xml version="1.0" encoding="UTF-8"?>'
        '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">'
        '<manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.text"/>'
        '<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>'
        '<manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>'
        '</manifest:manifest>';
    final a = Archive();
    // mimetype: İLK dosya ve SIKIŞTIRILMAMIŞ (ODF §3.3).
    final mt = utf8.encode('application/vnd.oasis.opendocument.text');
    a.addFile(ArchiveFile.noCompress('mimetype', mt.length, mt));
    for (final (name, text) in [
      ('content.xml', content),
      ('styles.xml', styles),
      ('META-INF/manifest.xml', manifest),
    ]) {
      final b = utf8.encode(text);
      a.addFile(ArchiveFile(name, b.length, b));
    }
    return Uint8List.fromList(ZipEncoder().encode(a));
  }

  static String _n(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}
