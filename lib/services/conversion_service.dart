import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/markdown.dart';
import 'ocr_service.dart';

/// Basit format dönüştürme: metin/office içeriğini PDF veya TXT'e çevirir,
/// AI metninden PDF slayt destesi üretir.
class ConversionService {
  /// Türkçe yazabilen gömülü tema (Carlito).
  ///
  /// **TUZAK (sessiz bozulma):** `pdf` paketinin varsayılan fontu Helvetica'dır
  /// (base-14, WinAnsi) ve `ğ ş ı İ` bu kodlamada YOKTUR. Paket hata ATMAZ —
  /// PDF üretilir ama bu karakterler yanlış/boş çizilir, yani Türkçe belgede
  /// "PDF'e dönüştür" çıktıyı sessizce bozuyordu. Görünmez OCR katmanında font
  /// zaten gömülüyordu; görünen metin yolu atlanmıştı (2026-07-26'da düzeltildi).
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _turkishTheme() async {
    return _theme ??= pw.ThemeData.withFont(
      base: pw.Font.ttf(await rootBundle.load('assets/fonts/Carlito-Regular.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Carlito-Bold.ttf')),
      italic:
          pw.Font.ttf(await rootBundle.load('assets/fonts/Carlito-Italic.ttf')),
      boldItalic: pw.Font.ttf(
          await rootBundle.load('assets/fonts/Carlito-BoldItalic.ttf')),
    );
  }

  /// Düz metni tek bir PDF belgesine dönüştürür.
  Future<Uint8List> textToPdf(String title, String content) async {
    final doc = pw.Document(theme: await _turkishTheme());
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

  /// Bir görseli PDF'e gömer — VERİ KAYBI OLMADAN.
  ///
  /// * Sayfa oranı resmin oranına eşitlenir → ne kırpma ne kenar boşluğu olur.
  /// * Piksel verisi kayıpsız gömülür — JPEG baytları olduğu gibi (DCTDecode),
  ///   PNG kayıpsız yeniden kodlanır. Hiçbir yeniden ölçekleme yapılmaz; sayfa
  ///   ölçeği yalnızca görüntüleme boyutudur → yakınlaştırınca orijinal
  ///   çözünürlük korunur.
  /// * [ocrLines] verilirse her satır kendi yerine GÖRÜNMEZ metin olarak yazılır
  ///   (hem şeffaf renk hem resmin altında) → PDF içinde arama/kopyalama çalışır.
  ///
  /// Not: HEIC/HEIF baytları `pdf` paketi tarafından çözülemez; çağıran taraf
  /// hatayı kullanıcıya bildirmeli.
  Future<Uint8List> imageToPdf(
    String imagePath, {
    List<OcrLine> ocrLines = const [],
  }) =>
      imagesToPdf(
        [imagePath],
        ocrLinesPerPage: ocrLines.isEmpty ? const [] : [ocrLines],
      );

  /// Birden çok görseli **sırayla, her biri kendi sayfası** olacak şekilde tek
  /// PDF'e gömer (belge tarayıcı: taranan sayfalar → tek belge).
  ///
  /// [ocrLinesPerPage] verilirse i. listedeki satırlar i. sayfaya görünmez metin
  /// olarak yazılır; kısa liste sorun değil, kalan sayfalar metinsiz kalır.
  /// Tek görsellik hâli [imageToPdf] ile aynı yoldan geçer — davranış tek yerde.
  ///
  /// [uniformPage] verilirse (belge tarayıcı bunu A4 ile çağırır) **her sayfa
  /// aynı kâğıt boyunda** olur: görsel oranı korunarak sayfaya sığdırılır
  /// (kırpılmaz, esnetilmez) ve ORTALANIR; yatay görsel için kâğıt yatay
  /// çevrilir, böylece kenarda dev boşluk kalmaz.
  ///
  /// *Niye:* eskiden her sayfa kendi görselinin oranını alıyordu — arka arkaya
  /// çekilen sayfalar birkaç piksel farklı olduğu için PDF'te sayfa boyu sayfa
  /// sayfa oynuyordu ("sayfalar tam oturmuyor, düz değil" bulgusu, 2026-07-26).
  /// Gerçek bir tarayıcı hep aynı kâğıda basar; biz de öyle yapıyoruz.
  Future<Uint8List> imagesToPdf(
    List<String> imagePaths, {
    List<List<OcrLine>> ocrLinesPerPage = const [],
    PdfPageFormat? uniformPage,
  }) async {
    if (imagePaths.isEmpty) throw ArgumentError('PDF için en az bir görsel gerekli');

    // Görünmez katman Türkçe karakter içerebilir → gömülü Carlito (varsayılan
    // Helvetica'da ğ/ş/ı çizilemez ve pdf paketi hata atar).
    final hasOcr = ocrLinesPerPage.any((lines) => lines.isNotEmpty);
    final font = hasOcr
        ? pw.Font.ttf(await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
        : null;

    final doc = pw.Document();
    for (var i = 0; i < imagePaths.length; i++) {
      final bytes = await File(imagePaths[i]).readAsBytes();
      final image = pw.MemoryImage(bytes);

      // Çözülemeyen biçimde (ör. HEIC/HEIF) boyutlar null gelir — sessizce bozuk
      // PDF üretmek yerine çağıranın gösterebileceği bir hata at.
      final imgWidth = image.width;
      final imgHeight = image.height;
      if (imgWidth == null || imgHeight == null || imgWidth == 0) {
        throw const FormatException(
            'Bu görsel biçimi çözülemedi (HEIC/HEIF olabilir). '
            'JPG veya PNG olarak kaydedip tekrar deneyin.');
      }

      final double pageWidth;
      final double pageHeight;
      final double scale;
      // Görselin sayfadaki sol-üst köşesi (ortalama kayması).
      double offsetX = 0;
      double offsetY = 0;

      if (uniformPage == null) {
        // Eski davranış: sayfa oranı resmin oranına eşitlenir (kenar boşluğu yok).
        pageWidth = PdfPageFormat.a4.width;
        pageHeight = pageWidth * imgHeight / imgWidth;
        scale = pageWidth / imgWidth;
      } else {
        // Sabit kâğıt. Yatay görselde kâğıdı da yatay çevir — aynı boy, dolu sayfa.
        final landscape = imgWidth > imgHeight;
        pageWidth = landscape
            ? (uniformPage.width > uniformPage.height
                ? uniformPage.width
                : uniformPage.height)
            : (uniformPage.width < uniformPage.height
                ? uniformPage.width
                : uniformPage.height);
        pageHeight = landscape
            ? (uniformPage.width > uniformPage.height
                ? uniformPage.height
                : uniformPage.width)
            : (uniformPage.width < uniformPage.height
                ? uniformPage.height
                : uniformPage.width);
        final sx = pageWidth / imgWidth;
        final sy = pageHeight / imgHeight;
        scale = sx < sy ? sx : sy; // contain: kırpma yok, esnetme yok
        offsetX = (pageWidth - imgWidth * scale) / 2;
        offsetY = (pageHeight - imgHeight * scale) / 2;
      }

      final drawWidth = imgWidth * scale;
      final drawHeight = imgHeight * scale;
      final ocrLines =
          i < ocrLinesPerPage.length ? ocrLinesPerPage[i] : const <OcrLine>[];

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, pageHeight),
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              // Resim ALTTA, metin katmanı ÜSTTE ama GÖRÜNMEZ çizilir.
              //
              // Kullanıcı hatası 2026-07-31 (ekran görüntüsü): "metinleri de
              // tanı" ile taranan sayfada OCR metni **koyu siyah** ve dev
              // punto olarak sayfanın sağına taşmış hâlde basılıyordu; belge
              // okunamaz hâle geliyordu. İki ayrı kök neden vardı:
              //
              // 1. Görünmezlik `PdfColor(0,0,0,0)` ile, yani **saydam renkle**
              //    deneniyordu. `pdf` paketi metin doldurma renginde alfa
              //    kanalını PDF'e yazmıyor (`… rg` yalnız RGB) → metin
              //    tastamam siyah çıkıyordu. Doğrusu PDF'in kendi "metin
              //    çizim kipi 3" özelliği: `PdfTextRenderingMode.invisible`.
              //    Metin çizilmez ama belgede DURUR: aranabilir, kopyalanabilir.
              // 2. Metin resmin ALTINA konup "resim üstünü örter" varsayılıyordu.
              //    Örtme yalnız resmin sınırları içinde çalışır; OCR kutusuna
              //    sığmayan uzun satır resmin sağından taşıyordu ve orada
              //    örtecek bir şey yok. Artık her satır **kendi kutusuna**
              //    sıkıştırılıyor (`FittedBox`) ve tüm katman resmin dikdörtgeniyle
              //    kırpılıyor — taşma fiziksel olarak imkânsız.
              pw.Positioned(
                left: offsetX,
                top: offsetY,
                child: pw.SizedBox(
                  width: drawWidth,
                  height: drawHeight,
                  child: pw.Image(image, fit: pw.BoxFit.fill),
                ),
              ),
              if (ocrLines.isNotEmpty)
                pw.Positioned(
                  left: offsetX,
                  top: offsetY,
                  child: pw.SizedBox(
                    width: drawWidth,
                    height: drawHeight,
                    child: pw.ClipRect(
                      child: pw.Stack(
                        children: [
                          for (final line in ocrLines)
                            pw.Positioned(
                              left: line.box.left * scale,
                              top: line.box.top * scale,
                              child: pw.SizedBox(
                                width: (line.box.width * scale)
                                    .clamp(1.0, drawWidth),
                                height: (line.box.height * scale)
                                    .clamp(1.0, drawHeight),
                                child: pw.FittedBox(
                                  fit: pw.BoxFit.fill,
                                  child: pw.Text(
                                    line.text,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: pw.TextStyle(
                                      font: font,
                                      fontSize: 12,
                                      renderingMode:
                                          PdfTextRenderingMode.invisible,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }

  /// AI/metin içeriğinden slayt destesi (PDF) üretir.
  /// Slaytlar "---" veya "— Slayt" ile ayrılabilir; yoksa paragraflara bölünür.
  Future<Uint8List> textToSlidesPdf(String title, String content) async {
    final slides = _splitIntoSlides(content);
    final doc = pw.Document(theme: await _turkishTheme());

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
      // Markdown işaretlerini temizle: slaytta ham `**`/`- `/`#` görünmesin.
      final title = stripInlineMarkdown(lines.first);
      final bullets = (lines.length > 1 ? lines.sublist(1) : <String>[lines.first])
          .map(stripInlineMarkdown)
          .where((l) => l.isNotEmpty)
          .toList();
      result.add(_Slide(
          title: title, bullets: bullets.isEmpty ? [title] : bullets));
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
