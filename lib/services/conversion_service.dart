import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Basit format dönüştürme: metin/office içeriğini PDF veya TXT'e çevirir,
/// AI metninden PDF slayt destesi üretir.
class ConversionService {
  /// Düz metni tek bir PDF belgesine dönüştürür.
  Future<Uint8List> textToPdf(String title, String content) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Header(level: 0, text: title),
          pw.SizedBox(height: 8),
          pw.Paragraph(
            text: content.isEmpty ? '(Boş belge)' : content,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// AI/metin içeriğinden slayt destesi (PDF) üretir.
  /// Slaytlar "---" veya "— Slayt" ile ayrılabilir; yoksa paragraflara bölünür.
  Future<Uint8List> textToSlidesPdf(String title, String content) async {
    final slides = _splitIntoSlides(content);
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ),
    );

    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i];
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                slide.title,
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.SizedBox(height: 12),
              ...slide.bullets.map(
                (b) => pw.Bullet(
                  text: b,
                  style: const pw.TextStyle(fontSize: 15, lineSpacing: 3),
                ),
              ),
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text('${i + 1}',
                    style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }

  /// Byte içeriğini geçici dizine yazıp yolunu döndürür (paylaşım için).
  Future<String> writeToTemp(String fileName, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final file = File(p.join(dir.path, safe));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  List<_Slide> _splitIntoSlides(String content) {
    final blocks = content.contains('— Slayt')
        ? content.split(RegExp(r'—\s*Slayt\s*\d*\s*—'))
        : content.split(RegExp(r'\n-{3,}\n'));

    final result = <_Slide>[];
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;
      final title = lines.first;
      final bullets = lines.length > 1 ? lines.sublist(1) : <String>[title];
      result.add(_Slide(title: title, bullets: bullets));
    }
    if (result.isEmpty) {
      result.add(_Slide(title: 'Slayt', bullets: [content]));
    }
    return result;
  }
}

class _Slide {
  final String title;
  final List<String> bullets;
  _Slide({required this.title, required this.bullets});
}
