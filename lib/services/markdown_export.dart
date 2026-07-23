import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;

import '../core/markdown.dart';

/// AI/Markdown metnini gerçek bir Word (.docx) belgesine çevirir.
///
/// *Niye:* AI yanıtları çoğu zaman başlık/liste/tablo içeren yapılı içerik
/// üretir; kullanıcı bunu "iyi bir Office programı"ndan beklediği gibi
/// düzenlenebilir bir Word dosyası olarak dışa aktarabilmeli. Üretilen paket
/// geçerli OOXML olduğundan hem uygulamanın kendi Word editöründe hem
/// Microsoft Word'de açılır. Biçim DOĞRUDAN (rPr/pPr) verilir — `styles.xml`
/// bağımlılığı yok, böylece paket her zaman geçerli kalır.
class MarkdownExport {
  /// Markdown → .docx bayt listesi.
  static List<int> toDocx(String markdown, {String title = ''}) {
    final blocks = parseMarkdown(markdown);
    final body = StringBuffer();

    if (title.trim().isNotEmpty) {
      body.write(_para(
        [MdSpan(title.trim(), bold: true)],
        sizeHalfPt: 36,
      ));
    }

    for (final block in blocks) {
      switch (block.type) {
        case MdBlockType.heading:
          const sizes = [36, 32, 28, 26, 24, 22];
          body.write(_para(
            block.spans,
            bold: true,
            sizeHalfPt: sizes[(block.level - 1).clamp(0, 5)],
            spaceBefore: 160,
          ));
          break;
        case MdBlockType.paragraph:
          body.write(_para(block.spans));
          break;
        case MdBlockType.quote:
          body.write(_para(block.spans, italic: true, indentLeft: 360));
          break;
        case MdBlockType.bullet:
          for (final it in block.items) {
            body.write(_para(
              [const MdSpan('•  '), ...it],
              indentLeft: 360,
            ));
          }
          break;
        case MdBlockType.numbered:
          var n = block.start;
          for (final it in block.items) {
            body.write(_para(
              [MdSpan('${n++}.  '), ...it],
              indentLeft: 360,
            ));
          }
          break;
        case MdBlockType.rule:
          body.write('<w:p><w:pPr><w:pBdr>'
              '<w:bottom w:val="single" w:sz="6" w:space="1" w:color="auto"/>'
              '</w:pBdr></w:pPr></w:p>');
          break;
        case MdBlockType.code:
          for (final line in block.rawCode.split('\n')) {
            body.write(_para(
              [MdSpan(line, code: true)],
              monospace: true,
            ));
          }
          break;
        case MdBlockType.table:
          body.write(_table(block.rows));
          // Word tablo sonrası bir paragraf ister (aksi halde onarım uyarısı).
          body.write('<w:p/>');
          break;
      }
    }

    if (body.isEmpty) body.write('<w:p/>');

    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body<w:sectPr/></w:body>'
        '</w:document>';

    return _zip({
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
          '</Types>',
      '_rels/.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
          '</Relationships>',
      'word/document.xml': document,
    });
  }

  /// Markdown → .xlsx bayt listesi (`excel` paketiyle).
  ///
  /// Markdown tabloları gerçek satır/sütunlara açılır; tablo dışı içerik
  /// (başlık/paragraf/liste) tek sütunlu satırlar olarak yazılır — hiçbir şey
  /// kaybolmaz. Sayısal hücreler gerçek sayı olur (metin değil), böylece
  /// Excel'de toplama/formül çalışır.
  static List<int> toXlsx(String markdown) {
    final excel = xls.Excel.createExcel();
    // `Excel.createExcel()` varsayılan olarak "Sheet1" üretir; `[]` operatörü o
    // sayfayı döndürür (yoksa oluşturur). `cell(...).value =` ve `encode()` bu
    // projede kanıtlı API (bkz. xlsx_editor).
    final sheet = excel['Sheet1'];

    var rowIndex = 0;
    void row(List<String> cells) {
      for (var c = 0; c < cells.length; c++) {
        sheet
            .cell(xls.CellIndex.indexByColumnRow(
                columnIndex: c, rowIndex: rowIndex))
            .value = _xlsxCell(cells[c]);
      }
      rowIndex++;
    }

    for (final block in parseMarkdown(markdown)) {
      switch (block.type) {
        case MdBlockType.table:
          for (final r in block.rows) {
            row([for (final cell in r) _spansPlain(cell)]);
          }
          break;
        case MdBlockType.bullet:
        case MdBlockType.numbered:
          for (final it in block.items) {
            row([_spansPlain(it)]);
          }
          break;
        case MdBlockType.code:
          for (final line in block.rawCode.split('\n')) {
            row([line]);
          }
          break;
        case MdBlockType.rule:
          row(const ['']);
          break;
        case MdBlockType.heading:
        case MdBlockType.paragraph:
        case MdBlockType.quote:
          row([_spansPlain(block.spans)]);
          break;
      }
    }

    // Hiç içerik yoksa en az bir hücre (boş .xlsx çökme riskini önler).
    if (rowIndex == 0) row(const ['']);

    return excel.encode() ?? const <int>[];
  }

  static String _spansPlain(List<MdSpan> spans) =>
      spans.map((s) => s.text).join();

  /// Metni uygun hücre tipine çevirir: baştaki sıfır/uzun diziler ve `=` ile
  /// başlayanlar metin; diğer sayılar gerçek sayı hücresi.
  static xls.CellValue _xlsxCell(String value) {
    final v = value.trim();
    if (v.isEmpty) return xls.TextCellValue('');
    final code = v.length > 15 ||
        (v.length > 1 && v.startsWith('0') && !v.startsWith('0.') &&
            !v.startsWith('0,'));
    if (!code) {
      final i = int.tryParse(v);
      if (i != null) return xls.IntCellValue(i);
      final d = double.tryParse(v.replaceAll(',', '.'));
      if (d != null && d.isFinite) return xls.DoubleCellValue(d);
    }
    return xls.TextCellValue(value);
  }

  /// Bir paragrafı OOXML olarak üretir.
  static String _para(
    List<MdSpan> spans, {
    bool bold = false,
    bool italic = false,
    bool monospace = false,
    int? sizeHalfPt,
    int indentLeft = 0,
    int spaceBefore = 0,
  }) {
    final pPr = StringBuffer('<w:pPr>');
    if (spaceBefore > 0) {
      pPr.write('<w:spacing w:before="$spaceBefore"/>');
    }
    if (indentLeft > 0) {
      pPr.write('<w:ind w:left="$indentLeft"/>');
    }
    pPr.write('</w:pPr>');

    final runs = StringBuffer();
    for (final s in spans) {
      runs.write(_run(
        s,
        forceBold: bold,
        forceItalic: italic,
        forceMono: monospace,
        sizeHalfPt: sizeHalfPt,
      ));
    }
    return '<w:p>$pPr$runs</w:p>';
  }

  static String _run(
    MdSpan s, {
    bool forceBold = false,
    bool forceItalic = false,
    bool forceMono = false,
    int? sizeHalfPt,
  }) {
    final rPr = StringBuffer('<w:rPr>');
    if (s.bold || forceBold) rPr.write('<w:b/>');
    if (s.italic || forceItalic) rPr.write('<w:i/>');
    if (s.strike) rPr.write('<w:strike/>');
    if (s.code || forceMono) {
      rPr.write('<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" '
          'w:cs="Consolas"/>');
    }
    if (sizeHalfPt != null) {
      rPr.write('<w:sz w:val="$sizeHalfPt"/>'
          '<w:szCs w:val="$sizeHalfPt"/>');
    }
    rPr.write('</w:rPr>');
    return '<w:r>$rPr'
        '<w:t xml:space="preserve">${_esc(s.text)}</w:t></w:r>';
  }

  static String _table(List<List<List<MdSpan>>> rows) {
    if (rows.isEmpty) return '';
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final buf = StringBuffer('<w:tbl><w:tblPr>'
        '<w:tblStyle w:val="TableGrid"/>'
        '<w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>'
        '${_edge("top")}${_edge("left")}${_edge("bottom")}'
        '${_edge("right")}${_edge("insideH")}${_edge("insideV")}'
        '</w:tblBorders></w:tblPr>');
    for (var r = 0; r < rows.length; r++) {
      buf.write('<w:tr>');
      for (var c = 0; c < cols; c++) {
        final cell = c < rows[r].length ? rows[r][c] : const <MdSpan>[];
        final runs = StringBuffer();
        for (final s in cell) {
          runs.write(_run(s, forceBold: r == 0));
        }
        buf.write('<w:tc><w:tcPr/><w:p>$runs</w:p></w:tc>');
      }
      buf.write('</w:tr>');
    }
    buf.write('</w:tbl>');
    return buf.toString();
  }

  static String _edge(String side) =>
      '<w:$side w:val="single" w:sz="4" w:space="0" w:color="auto"/>';

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static List<int> _zip(Map<String, String> files) {
    final archive = Archive();
    files.forEach((name, content) {
      final data = utf8.encode(content);
      archive.addFile(ArchiveFile(name, data.length, data));
    });
    return ZipEncoder().encode(archive) ?? const <int>[];
  }
}
