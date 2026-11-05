/// **Sayfa → PDF (yazdırma düzeni)** — Faz 36 madde 6.
///
/// Ekranda görünen değerler (biçimli metin) A4 sayfalara dizilir:
/// yatay/dikey, "sayfa genişliğine sığdır" (sütunlar orantılı küçülür),
/// başlık satırlarını her sayfada yinele (`pw.Table.headerCount`), kenar
/// boşlukları, sayfa numarası. Gizli satır/sütun yazılmaz. Saf; çağıran
/// izolatta koşturur (anayasa k.1).
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SheetPrintSpec {
  final bool landscape;
  final bool fitWidth;

  /// Her sayfada yinelenecek üst satır sayısı (0 = yok).
  final int repeatRows;
  final bool gridLines;
  final String title;
  const SheetPrintSpec({
    this.landscape = false,
    this.fitWidth = true,
    this.repeatRows = 1,
    this.gridLines = true,
    this.title = '',
  });
}

abstract final class SheetPdf {
  /// [cells] satır × sütun görünen metin; [colWidthsPx] ekran genişlikleri;
  /// [numeric] sağa yaslanacak hücreler (`r * 16384 + c`).
  static Future<Uint8List> build({
    required List<List<String>> cells,
    required List<double> colWidthsPx,
    required SheetPrintSpec spec,
    Set<int> numeric = const {},
    List<int>? fontBytes,
    String Function(int page, int total)? pageLabel,
  }) async {
    final font = fontBytes == null
        ? pw.Font.helvetica()
        : pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(fontBytes)));
    final format = spec.landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    const margin = 28.0;
    final usable = format.width - margin * 2;
    // Ekran pikseli → punto (96 dpi → 72).
    final widths = [for (final w in colWidthsPx) w * 0.75];
    final total = widths.fold<double>(0, (a, b) => a + b);
    final scale = spec.fitWidth && total > usable ? usable / total : 1.0;
    final fontSize = (9.0 * scale).clamp(4.0, 9.0).toDouble();
    final cols = colWidthsPx.length;
    final style = _ts(font, fontSize);
    final head = style.copyWith(fontWeight: pw.FontWeight.bold);
    final rows = [
      for (var r = 0; r < cells.length; r++)
        // Başlık yinele: ilk N satır her sayfanın başında tekrar edilir.
        pw.TableRow(repeat: r < spec.repeatRows, children: [
          for (var c = 0; c < cols; c++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: pw.Text(
                c < cells[r].length ? cells[r][c] : '',
                style: r < spec.repeatRows ? head : style,
                maxLines: 3,
                textAlign: numeric.contains(r * 16384 + c)
                    ? pw.TextAlign.right
                    : pw.TextAlign.left,
              ),
            ),
        ]),
    ];
    final doc = pw.Document(title: spec.title);
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(margin),
      maxPages: 2000,
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          pageLabel?.call(ctx.pageNumber, ctx.pagesCount) ??
              '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: _ts(font, 7),
        ),
      ),
      build: (_) => [
        pw.Table(
          border: spec.gridLines
              ? pw.TableBorder.all(color: PdfColors.grey500, width: 0.3)
              : null,
          columnWidths: {
            for (var c = 0; c < cols; c++)
              c: pw.FixedColumnWidth(widths[c] * scale),
          },
          children: rows,
        ),
      ],
    ));
    return doc.save();
  }

  /// PDF İÇERİK yazı stili (arayüz tokenı değil — `design_tokens_baseline`).
  static pw.TextStyle _ts(pw.Font f, double size) =>
      pw.TextStyle(font: f, fontSize: size);
}
