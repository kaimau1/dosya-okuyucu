/// **PDF → Excel / Word / PDF-A** — Faz 39 madde 3.
///
/// * **Tablo → Excel:** sayfa sözcükleri (Syncfusion metin çıkarıcı, kutulu)
///   önce aralarındaki boşluğa göre "öbek"lere (hücre adayı) toplanır, sonra
///   taramadaki tablo algılayıcıya ([ScanExport.detectTable]) verilir — aynı
///   satır/sütun kümeleme, aynı sayı ayrıştırma. Her sayfa bir çalışma sayfası.
/// * **Sayfa metni → Word (düzen korunarak):** her metin satırı bir paragraf;
///   sol girinti, satır üstü boşluk, punto ve kalınlık PDF'teki ölçülerden;
///   sayfa sonları ve sayfa boyutu korunur. (Görsel/çizim taşınmaz.)
/// * **PDF/A-2b:** [PdfRedact.apply] ile yeni, uyum düzeyli belgeye kurulur
///   (şablon kipi ya da görüntü + görünmez metin kipi — UI seçer).
///
/// Hepsi saf + izolatta koşar (anayasa k.1); metin isteğe bağlı çıkarılır
/// (P4 — açılışta değil).
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'ocr_service.dart' show OcrLine;
import 'scan_export.dart';
import 'xlsx_writer.dart';

/// Sayfadaki bir metin satırı (sözcük öbekleriyle).
class PdfTextRow {
  final String text;
  final Rect bounds;
  final double fontSize;
  final bool bold;

  /// Aynı satırdaki büyük boşlukla ayrılmış öbekler (tablo hücresi adayı).
  final List<OcrLine> chunks;

  const PdfTextRow(this.text, this.bounds, this.fontSize, this.bold, this.chunks);
}

abstract final class PdfExportPro {
  /// Sayfa satırları (görünen sırayla, yukarıdan aşağı).
  static List<List<PdfTextRow>> rows(List<int> bytes,
      {String? password, List<int>? pages}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final extractor = PdfTextExtractor(doc);
      final indexes = pages ?? List<int>.generate(doc.pages.count, (i) => i);
      return [
        for (final i in indexes)
          [
            for (final line in extractor.extractTextLines(
                startPageIndex: i, endPageIndex: i)
              ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top)))
              if (line.text.trim().isNotEmpty)
                PdfTextRow(
                  line.text.trim(),
                  line.bounds,
                  line.fontSize,
                  line.fontStyle.contains(PdfFontStyle.bold) ||
                      line.fontName.toLowerCase().contains('bold'),
                  chunksOf(line.wordCollection
                      .map((w) => (text: w.text, bounds: w.bounds, size: w.fontSize))
                      .toList()),
                ),
          ],
      ];
    } finally {
      doc.dispose();
    }
  }

  /// Saf: sözcükleri yatay boşluğa göre öbekler. Boşluk > 1,2 × punto (en az
  /// 6 pt) → yeni öbek (tablo sütunu).
  static List<OcrLine> chunksOf(
      List<({String text, Rect bounds, double size})> words) {
    final sorted = [
      for (final w in words)
        if (w.text.trim().isNotEmpty) w,
    ]..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    final out = <OcrLine>[];
    String? text;
    Rect? box;
    double size = 10;
    for (final w in sorted) {
      final gap = box == null ? 0.0 : w.bounds.left - box.right;
      final limit = math.max(6.0, (w.size > 0 ? w.size : size) * 1.2);
      if (box != null && gap <= limit) {
        text = '$text ${w.text.trim()}';
        box = box.expandToInclude(w.bounds);
      } else {
        if (box != null) out.add(OcrLine(text!, box));
        text = w.text.trim();
        box = w.bounds;
      }
      if (w.size > 0) size = w.size;
    }
    if (box != null) out.add(OcrLine(text!, box));
    return out;
  }

  /// Tablolar → xlsx (her PDF sayfası bir çalışma sayfası, adı sayfa
  /// numarasıyla; metinsiz sayfa atlanır).
  static Uint8List tablesToXlsx(List<int> bytes,
      {String? password, List<int>? pages, String sheetPrefix = 'Sayfa'}) {
    final all = rows(bytes, password: password, pages: pages);
    final indexes = pages ?? List<int>.generate(all.length, (i) => i);
    final sheets = <XlsxWriteSheet>[];
    for (var n = 0; n < all.length; n++) {
      final table = tableOf(all[n]);
      if (table.isEmpty) continue;
      final cells = <int, Map<int, XlsxWriteCell>>{};
      final widths = <int, double>{};
      for (var r = 0; r < table.length; r++) {
        for (var c = 0; c < table[r].length; c++) {
          final text = table[r][c].trim();
          if (text.isEmpty) continue;
          final number = ScanExport.parseNumber(text);
          (cells[r] ??= {})[c] = number != null
              ? XlsxWriteCell(number: number)
              : XlsxWriteCell(text: text);
          widths[c] = math.max(widths[c] ?? 8, math.min(60, text.length + 2.0));
        }
      }
      sheets.add(XlsxWriteSheet(
          name: '$sheetPrefix${indexes[n] + 1}', cells: cells, colWidths: widths));
    }
    return XlsxWriter.build(sheets);
  }

  static Future<Uint8List> tablesToXlsxInBackground(List<int> bytes,
          {String? password, List<int>? pages, String sheetPrefix = 'Sayfa'}) =>
      Isolate.run(() => tablesToXlsx(bytes,
          password: password, pages: pages, sheetPrefix: sheetPrefix));

  // ── Word ─────────────────────────────────────────────────────────────────

  /// Düzeni korunmuş docx.
  static Uint8List toLayoutDocx(List<int> bytes, {String? password}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    final List<({double w, double h})> sizes;
    try {
      sizes = [
        for (var i = 0; i < doc.pages.count; i++)
          (w: doc.pages[i].size.width, h: doc.pages[i].size.height),
      ];
    } finally {
      doc.dispose();
    }
    return buildDocx(rows(bytes, password: password), sizes);
  }

  static Future<Uint8List> toLayoutDocxInBackground(List<int> bytes,
          {String? password}) =>
      Isolate.run(() => toLayoutDocx(bytes, password: password));

  /// Saf: satırlar → docx baytları. Girinti = satır solu − sayfanın en soldaki
  /// metni (sayfa kenar boşluğu Word'ün kendi boşluğu olur).
  static Uint8List buildDocx(
      List<List<PdfTextRow>> pages, List<({double w, double h})> sizes) {
    final body = StringBuffer();
    final first = sizes.isEmpty ? (w: 595.0, h: 842.0) : sizes.first;
    const margin = 56.7; // 2 cm
    for (var p = 0; p < pages.length; p++) {
      final rows = pages[p];
      final minLeft = rows.isEmpty
          ? 0.0
          : rows.map((r) => r.bounds.left).reduce(math.min);
      double? lastBottom;
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final indent = ((r.bounds.left - minLeft) * 20).round();
        final gap = lastBottom == null
            ? 0
            : ((r.bounds.top - lastBottom) - r.fontSize * 0.3)
                .clamp(0, 400)
                .round();
        lastBottom = r.bounds.bottom;
        final half = (r.fontSize > 0 ? r.fontSize * 2 : 22).round().clamp(8, 144);
        final pageBreak = p > 0 && i == 0;
        body
          ..write('<w:p><w:pPr>')
          ..write(pageBreak ? '<w:pageBreakBefore/>' : '')
          ..write('<w:spacing w:before="${gap * 20}" w:after="0" w:line="240" w:lineRule="auto"/>')
          ..write(indent > 0 ? '<w:ind w:left="$indent"/>' : '')
          ..write('</w:pPr><w:r><w:rPr>')
          ..write(r.bold ? '<w:b/>' : '')
          ..write('<w:sz w:val="$half"/><w:szCs w:val="$half"/></w:rPr>')
          ..write('<w:t xml:space="preserve">${_esc(r.text)}</w:t></w:r></w:p>');
      }
      if (rows.isEmpty) {
        body.write(p > 0
            ? '<w:p><w:pPr><w:pageBreakBefore/></w:pPr></w:p>'
            : '<w:p/>');
      }
    }
    final pgW = (first.w * 20).round(), pgH = (first.h * 20).round();
    final m = (margin * 20).round();
    final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body'
        '<w:sectPr><w:pgSz w:w="$pgW" w:h="$pgH"${first.w > first.h ? ' w:orient="landscape"' : ''}/>'
        '<w:pgMar w:top="$m" w:right="$m" w:bottom="$m" w:left="$m" w:header="0" w:footer="0" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';
    const types = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';
    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';
    final archive = Archive();
    void add(String name, String xml) {
      final data = utf8.encode(xml);
      archive.addFile(ArchiveFile(name, data.length, data));
    }

    add('[Content_Types].xml', types);
    add('_rels/.rels', rels);
    add('word/document.xml', document);
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  /// Bir sayfanın tablo hücreleri (satır × sütun).
  static List<List<String>> tableOf(List<PdfTextRow> page) =>
      ScanExport.detectTable([for (final r in page) ...r.chunks]);
}
