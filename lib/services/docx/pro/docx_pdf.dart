/// **Faz 37 madde 2 + 7 — Word → PDF (baskı önizleme ve dışa aktarım).**
///
/// Editör modelinden ([DocxDocument]) `pdf` paketiyle sayfa kurar: bölüm
/// ölçüsü/kenar boşluğu, sütun, başlık düzeyleri, harf biçimi (kalın, eğik,
/// altı çizili, üstü çizili, renk, vurgu, punto, üst/alt simge), hizalama,
/// girinti, aralık, liste etiketleri, tablolar, resimler (PNG/JPEG), sayfa sonu
/// / `pageBreakBefore`, başlığın sonraki paragraftan kopmaması (keepNext) ve
/// sayfa numarası. **Yazı tipleri gömülüdür** (Carlito / Tinos — metrik
/// uyumlu, Türkçe karakterli; base-14 Helvetica `ğ ş ı İ`yi sessizce
/// bozuyordu, bkz. `conversion_service`).
///
/// Üretim izolatta ([DocxPdf.renderInBackground]; anayasa k.1); yazı tipi
/// baytları ana izlekte bir kez okunur ([DocxPdfFonts.load]).
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import '../docx_document.dart';
import '../docx_styles.dart';
import 'docx_package.dart';

/// Gömülecek yazı tipi baytları (izolata gönderilebilir).
class DocxPdfFonts {
  final Map<String, Uint8List> files;
  const DocxPdfFonts(this.files);

  static DocxPdfFonts? _cache;

  static const _names = [
    'Carlito-Regular', 'Carlito-Bold', 'Carlito-Italic', 'Carlito-BoldItalic',
    'Tinos-Regular', 'Tinos-Bold', 'Tinos-Italic', 'Tinos-BoldItalic',
  ];

  static Future<DocxPdfFonts> load() async {
    final have = _cache;
    if (have != null) return have;
    final out = <String, Uint8List>{};
    for (final n in _names) {
      final d = await rootBundle.load('assets/fonts/$n.ttf');
      out[n] = d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    }
    return _cache = DocxPdfFonts(out);
  }
}

/// Sayfa ölçüsü (pt) + kenar boşlukları + sütun.
class DocxPdfPage {
  final double width, height, top, right, bottom, left;
  final int columns;
  final bool titlePage;
  const DocxPdfPage(this.width, this.height, this.top, this.right,
      this.bottom, this.left, this.columns, this.titlePage);

  static DocxPdfPage of(DocxPackage pkg) {
    final s = kid(pkg.body, 'sectPr');
    double tw(XmlElement? e, String a, double def) {
      final v = double.tryParse(attrOf(e, a) ?? '');
      return v == null ? def : v / 20;
    }

    final sz = kid(s, 'pgSz');
    final mar = kid(s, 'pgMar');
    final cols = int.tryParse(attrOf(kid(s, 'cols'), 'num') ?? '') ?? 1;
    return DocxPdfPage(
      tw(sz, 'w', 595.3),
      tw(sz, 'h', 841.9),
      tw(mar, 'top', 72).abs(),
      tw(mar, 'right', 72),
      tw(mar, 'bottom', 72).abs(),
      tw(mar, 'left', 72),
      cols.clamp(1, 4),
      kid(s, 'titlePg') != null,
    );
  }
}

abstract final class DocxPdf {
  static Future<Uint8List> renderInBackground(Uint8List docx,
      {required DocxPdfFonts fonts, bool pageNumbers = true}) {
    Future<Uint8List> work() => render(docx, fonts: fonts, pageNumbers: pageNumbers);
    return DocxPro.inIsolate ? Isolate.run(work) : work();
  }

  static Future<Uint8List> render(Uint8List docx,
      {required DocxPdfFonts fonts, bool pageNumbers = true}) async {
    final doc = DocxDocument.parse(docx);
    final page = DocxPdfPage.of(DocxPackage.open(docx));
    final r = _Renderer(doc, fonts);
    final out = pw.Document(compress: true);
    final format = PdfPageFormat(page.width, page.height,
        marginTop: page.top,
        marginBottom: page.bottom,
        marginLeft: page.left,
        marginRight: page.right);
    final body = r.build(format.availableWidth);
    // Sayfa sonu atomlarına göre bölümler: her bölüm yeni sayfada başlar.
    var first = true;
    for (final chunk in body) {
      out.addPage(pw.MultiPage(
        pageFormat: format,
        theme: r.theme,
        maxPages: 2000,
        footer: !pageNumbers
            ? null
            : (ctx) => (page.titlePage && ctx.pageNumber == 1)
                ? pw.SizedBox()
                : pw.Container(
                    alignment: pw.Alignment.center,
                    margin: const pw.EdgeInsets.only(top: 8),
                    child: pw.Text('${ctx.pageNumber}',
                        style: const pw.TextStyle(fontSize: 9))),
        // Çok sütunlu bölüm PDF'te tek sütun akar (pdf paketinde gazete
        // sütunu yok); sütun ayarı belgede korunur.
        build: (_) => chunk,
      ));
      first = false;
    }
    if (first) out.addPage(pw.Page(pageFormat: format, build: (_) => pw.SizedBox()));
    return out.save();
  }
}

class _Renderer {
  final DocxDocument doc;
  late final pw.ThemeData theme;
  late final pw.Font _sans, _sansB, _sansI, _sansBI, _serif, _serifB, _serifI, _serifBI;

  _Renderer(this.doc, DocxPdfFonts fonts) {
    pw.Font f(String n) => pw.Font.ttf(fonts.files[n]!.buffer.asByteData());
    _sans = f('Carlito-Regular');
    _sansB = f('Carlito-Bold');
    _sansI = f('Carlito-Italic');
    _sansBI = f('Carlito-BoldItalic');
    _serif = f('Tinos-Regular');
    _serifB = f('Tinos-Bold');
    _serifI = f('Tinos-Italic');
    _serifBI = f('Tinos-BoldItalic');
    theme = pw.ThemeData.withFont(
        base: _sans, bold: _sansB, italic: _sansI, boldItalic: _sansBI);
  }

  static bool _isSerif(String? font) {
    final f = (font ?? '').toLowerCase();
    return f.contains('times') ||
        f.contains('georgia') ||
        f.contains('cambria') ||
        f.contains('garamond') ||
        f.contains('antiqua') ||
        f.contains('serif') && !f.contains('sans');
  }

  pw.Font _font(DocxRunLook l) {
    final serif = _isSerif(l.font);
    if (l.bold && l.italic) return serif ? _serifBI : _sansBI;
    if (l.bold) return serif ? _serifB : _sansB;
    if (l.italic) return serif ? _serifI : _sansI;
    return serif ? _serif : _sans;
  }

  static PdfColor? _color(int? argb) =>
      argb == null ? null : PdfColor.fromInt(argb | 0xFF000000);

  pw.TextStyle _style(DocxRunLook l) {
    final small = l.vertAlign != null;
    return pw.TextStyle(
      font: _font(l),
      fontSize: (l.sizePt <= 0 ? 11 : l.sizePt) * (small ? 0.65 : 1),
      color: _color(l.color) ?? PdfColors.black,
      background: l.highlight == null
          ? null
          : pw.BoxDecoration(color: _color(l.highlight)),
      decoration: pw.TextDecoration.combine([
        if (l.underline) pw.TextDecoration.underline,
        if (l.strike) pw.TextDecoration.lineThrough,
      ]),
    );
  }

  static pw.TextAlign _align(String a, bool bidi) => switch (a) {
        'center' => pw.TextAlign.center,
        'right' || 'end' => pw.TextAlign.right,
        'both' || 'distribute' => pw.TextAlign.justify,
        _ => bidi ? pw.TextAlign.right : pw.TextAlign.left,
      };

  late final List<String> _labels = doc.listLabels();
  late final Map<DocxPara, int> _index = Map.identity()
    ..addAll({for (var i = 0; i < doc.paras.length; i++) doc.paras[i]: i});

  /// Belge → sayfa sonu atomlarına göre bölünmüş widget dizileri.
  List<List<pw.Widget>> build(double width) {
    final chunks = <List<pw.Widget>>[[]];
    final paras = doc.paras;
    var i = 0;
    while (i < paras.length) {
      final p = paras[i];
      if (p.cell != null) {
        final table = p.cell!.table;
        var j = i;
        while (j < paras.length && identical(paras[j].cell?.table, table)) {
          j++;
        }
        chunks.last.add(_table(paras.sublist(i, j), width));
        i = j;
        continue;
      }
      if (p.look.pageBreakBefore && chunks.last.isNotEmpty) chunks.add([]);
      final parts = _paraParts(p, i, width);
      for (var k = 0; k < parts.length; k++) {
        if (k > 0) chunks.add([]);
        if (parts[k] case final w?) chunks.last.add(w);
      }
      // keepNext: başlık sayfa dibinde yalnız kalmasın — kısa sonraki
      // paragrafla tek blok (bölünmez widget sayfadan uzun olamaz).
      if (p.look.headingLevel > 0 &&
          parts.length == 1 &&
          parts.single != null &&
          i + 1 < paras.length &&
          paras[i + 1].cell == null &&
          paras[i + 1].length < 600 &&
          !paras[i + 1].text.contains(kDocxAtom)) {
        final next = _paraParts(paras[i + 1], i + 1, width);
        if (next.length == 1 && next.single != null) {
          chunks.last.removeLast();
          chunks.last.add(pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [parts.single!, next.single!]));
          i += 2;
          continue;
        }
      }
      i++;
    }
    return chunks;
  }

  /// Paragrafı sayfa sonlarından böler; her parça bir widget (boş → null).
  List<pw.Widget?> _paraParts(DocxPara p, int index, double width) {
    if (p.opaque) {
      return [pw.Text(p.text, style: pw.TextStyle(font: _sans, fontSize: 11))];
    }
    final look = p.look;
    final out = <pw.Widget?>[];
    var spans = <pw.InlineSpan>[];
    final label = index >= 0 && index < _labels.length ? _labels[index] : '';
    if (label.isNotEmpty) {
      spans.add(pw.TextSpan(
          text: '$label\t'.replaceAll('\t', '  '),
          style: _style(p.mark.effective)));
    }
    final sb = StringBuffer();
    DocxRunLook? cur;
    void flush() {
      if (sb.isEmpty || cur == null) return;
      final l = cur;
      spans.add(l.vertAlign == null
          ? pw.TextSpan(text: sb.toString(), style: _style(l))
          : pw.TextSpan(
              text: sb.toString(),
              style: _style(l),
              baseline: l.vertAlign == 'superscript' ? 4 : -2));
      sb.clear();
    }

    void close() {
      flush();
      out.add(_block(spans, look, p.mark.effective, width));
      spans = [];
    }

    for (var k = 0; k < p.length; k++) {
      final a = p.atoms[k];
      final l = p.styles[k].effective;
      if (a != null) {
        flush();
        switch (a.kind) {
          case DocxAtomKind.pageBreak:
            close();
          case DocxAtomKind.image:
            final img = a.image;
            if (img != null && _supported(img)) {
              final wPt = a.widthPt <= 0 ? 200.0 : a.widthPt;
              final hPt = a.heightPt <= 0 ? wPt * 0.75 : a.heightPt;
              final scale = wPt > width ? width / wPt : 1.0;
              spans.add(pw.WidgetSpan(
                  child: pw.Image(pw.MemoryImage(img),
                      width: wPt * scale, height: hPt * scale)));
            }
          default:
            if (a.display.isNotEmpty) {
              spans.add(pw.TextSpan(
                  text: a.display,
                  style: _style(l).copyWith(
                      color: a.kind == DocxAtomKind.link ? PdfColors.blue800 : null)));
            }
        }
        cur = null;
        continue;
      }
      if (cur != null && !identical(cur, l) && !_same(cur, l)) flush();
      cur = l;
      final ch = p.text[k];
      sb.write(ch == '\t' ? '    ' : ch);
    }
    close();
    return out;
  }

  static bool _same(DocxRunLook a, DocxRunLook b) =>
      a.bold == b.bold &&
      a.italic == b.italic &&
      a.underline == b.underline &&
      a.strike == b.strike &&
      a.sizePt == b.sizePt &&
      a.color == b.color &&
      a.highlight == b.highlight &&
      a.font == b.font &&
      a.vertAlign == b.vertAlign;

  static bool _supported(Uint8List b) =>
      b.length > 8 &&
      ((b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E) ||
          (b[0] == 0xFF && b[1] == 0xD8));

  pw.Widget _block(List<pw.InlineSpan> spans, DocxParaLook look,
      DocxRunLook mark, double width) {
    final size = mark.sizePt <= 0 ? 11.0 : mark.sizePt;
    final lineSpacing = ((look.lineMultiple ?? 1.08) - 1).clamp(0, 2) * size;
    final text = spans.isEmpty
        ? pw.SizedBox(height: size * 1.2)
        : pw.RichText(
            text: pw.TextSpan(children: spans, style: pw.TextStyle(font: _sans, fontSize: size, lineSpacing: lineSpacing.toDouble())),
            textAlign: _align(look.align, look.bidi),
            textDirection: look.bidi ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          );
    final indent = look.indentLeftPt.clamp(0, width * 0.6).toDouble();
    return pw.Container(
      margin: pw.EdgeInsets.only(
          left: indent,
          top: look.spaceBeforePt.clamp(0, 72).toDouble(),
          bottom: look.spaceAfterPt.clamp(0, 72).toDouble()),
      decoration: look.borderBottom
          ? const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.75)))
          : null,
      child: text,
    );
  }

  pw.Widget _table(List<DocxPara> cells, double width) {
    var rows = 0, cols = 0;
    for (final p in cells) {
      final c = p.cell!;
      if (c.row + 1 > rows) rows = c.row + 1;
      if (c.col + c.gridSpan > cols) cols = c.col + c.gridSpan;
    }
    final grid = List.generate(rows, (_) => List<List<pw.Widget>>.generate(cols, (_) => []));
    for (final p in cells) {
      final c = p.cell!;
      final idx = _index[p] ?? -1;
      for (final w in _paraParts(p, idx, width / (cols == 0 ? 1 : cols))) {
        if (w != null) grid[c.row][c.col].add(w);
      }
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [
          for (final r in grid)
            pw.TableRow(children: [
              for (final cell in r)
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: cell)),
            ]),
        ],
      ),
    );
  }
}
