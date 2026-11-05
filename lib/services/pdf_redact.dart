/// **Kalıcı karartma (redaction)** — Faz 39 madde 2.
///
/// Siyah kutu ÇİZMEK karartma değildir: altındaki metin seçilip kopyalanır,
/// görüntü çıkarılır. Burada karartılan sayfa:
/// 1. pdfium ile görüntüye çizilir ve kutuların pikselleri SİYAHA boyanır
///    (`PdfRaster.encodeJpeg` — görüntü verisinin kendisi yok edilir);
/// 2. sayfa **yeni bir belgede** yalnız bu görüntüden kurulur — özgün içerik
///    akışı, gömülü görseller, açıklamalar ve formlar kopyalanmaz (artımlı
///    güncellemenin eski sürümü de yok: belge sıfırdan yazılır);
/// 3. kutuların DIŞINDA kalan sözcükler görünmez metin katmanı olarak geri
///    yazılır (sayfa aranabilir kalsın), kutuya değen sözcük asla yazılmaz;
/// 4. [leakedWords] çıktıyı yeniden açıp kutulara değen tek sözcük kalmadığını
///    DOĞRULAR — kalırsa işlem hata verir.
///
/// Dokunulmayan sayfalar şablon olarak kopyalanır (görünüm aynı).
/// Belge bilgileri (başlık/yazar) de taşınmaz — gizli veri orada da olabilir.
library;

import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_tools.dart' show composedPageTransform, PdfToolsException;

/// Karartılmış sayfanın görüntüsü (görünen yönde).
class RedactedRaster {
  final int index;
  final Uint8List jpeg;
  const RedactedRaster(this.index, this.jpeg);
}

abstract final class PdfRedact {
  /// Sayfaların görünen boyutu ve çeyrek tur dönüşü.
  static List<({Size raw, int turns})> pageInfo(List<int> bytes,
      {String? password}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      return [
        for (var i = 0; i < doc.pages.count; i++)
          (raw: doc.pages[i].size, turns: doc.pages[i].rotation.index),
      ];
    } finally {
      doc.dispose();
    }
  }

  /// Ham sayfa uzayındaki (sol-üst) dikdörtgeni görünen sayfaya çevirir
  /// (`/Rotate` saat yönünde).
  static Rect rawToDisplay(Rect r, Size raw, int turns) {
    Offset map(Offset o) => switch (turns % 4) {
          1 => Offset(raw.height - o.dy, o.dx),
          2 => Offset(raw.width - o.dx, raw.height - o.dy),
          3 => Offset(o.dy, raw.width - o.dx),
          _ => o,
        };
    return Rect.fromPoints(map(r.topLeft), map(r.bottomRight));
  }

  /// [terms] geçen her yerin kutusu, sayfa → GÖRÜNEN koordinat.
  static Map<int, List<Rect>> findText(
    List<int> bytes,
    List<String> terms, {
    String? password,
    bool caseSensitive = false,
    bool wholeWords = false,
  }) {
    final clean = [
      for (final t in terms)
        if (t.trim().isNotEmpty) t.trim(),
    ];
    if (clean.isEmpty) return const {};
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final option = caseSensitive && wholeWords
          ? TextSearchOption.both
          : caseSensitive
              ? TextSearchOption.caseSensitive
              : wholeWords
                  ? TextSearchOption.wholeWords
                  : null;
      final found = PdfTextExtractor(doc).findText(clean, searchOption: option);
      final out = <int, List<Rect>>{};
      for (final m in found) {
        final page = doc.pages[m.pageIndex];
        final r = rawToDisplay(
            m.bounds.inflate(1), page.size, page.rotation.index);
        (out[m.pageIndex] ??= []).add(r);
      }
      return out;
    } finally {
      doc.dispose();
    }
  }

  static Future<Map<int, List<Rect>>> findTextInBackground(
    List<int> bytes,
    List<String> terms, {
    String? password,
    bool caseSensitive = false,
    bool wholeWords = false,
  }) =>
      Isolate.run(() => findText(bytes, terms,
          password: password,
          caseSensitive: caseSensitive,
          wholeWords: wholeWords));

  /// Karartmayı uygular. [rects] sayfa → görünen koordinat (sol-üst, pt);
  /// [rasters] o sayfaların kutuları boyanmış görüntüsü. [fontBytes]
  /// görünmez metin katmanı için (Türkçe glif); yoksa standart font.
  static Future<List<int>> apply(
    List<int> bytes, {
    required Map<int, List<Rect>> rects,
    required List<RedactedRaster> rasters,
    List<int>? fontBytes,
    String? password,
    PdfConformanceLevel? conformance,
  }) async {
    final src = PdfDocument(inputBytes: bytes, password: password);
    final out = PdfDocument(conformanceLevel: conformance);
    // PDF/A standart (gömülmeyen) yazı tipine izin vermez: TrueType yoksa
    // görünmez katman yazılmaz.
    final textLayer = conformance == null || fontBytes != null;
    try {
      out.compressionLevel = PdfCompressionLevel.best;
      final byIndex = {for (final r in rasters) r.index: r.jpeg};
      final extractor = PdfTextExtractor(src);
      for (var i = 0; i < src.pages.count; i++) {
        final page = src.pages[i];
        final turns = page.rotation.index;
        final t = composedPageTransform(page.size, turns);
        final section = out.sections!.add()
          ..pageSettings = (PdfPageSettings(t.size)..margins.all = 0);
        final g = section.pages.add().graphics;
        final jpeg = byIndex[i];
        if (jpeg == null) {
          if (t.angle != 0) {
            g.translateTransform(t.translate.dx, t.translate.dy);
            g.rotateTransform(t.angle);
          }
          g.drawPdfTemplate(page.createTemplate(), Offset.zero, page.size);
          continue;
        }
        g.drawImage(PdfBitmap(jpeg), Rect.fromLTWH(0, 0, t.size.width, t.size.height));
        final boxes = rects[i] ?? const <Rect>[];
        final lines = textLayer
            ? extractor.extractTextLines(startPageIndex: i, endPageIndex: i)
            : const <TextLine>[];
        g.save();
        g.setTransparency(0);
        for (final line in lines) {
          for (final word in line.wordCollection) {
            final text = word.text.trim();
            if (text.isEmpty) continue;
            final shown = rawToDisplay(word.bounds, page.size, turns);
            if (boxes.any((b) => b.overlaps(shown))) continue;
            // Döndürülmüş sayfada görünmez metin yan yatmalı; o hesap yerine
            // katman atlanır (görüntü yine doğru, yalnız arama kaybolur).
            if (turns % 4 != 0) continue;
            final size = (word.fontSize > 0 ? word.fontSize : shown.height)
                .clamp(2.0, 96.0)
                .toDouble();
            final font = fontBytes != null
                ? PdfTrueTypeFont(fontBytes, size)
                : PdfStandardFont(PdfFontFamily.helvetica, size);
            // Yazılacak sözcüğün KENDİ kutusu (yazı tipi farklı, genişlik
            // değişebilir): kutuya taşacaksa hiç yazılmaz.
            final measured = font.measureString(text);
            final drawn = Rect.fromLTWH(
                shown.left, shown.top, measured.width, measured.height);
            if (boxes.any((b) => b.inflate(1).overlaps(drawn))) continue;
            // Genişlik 0 → satır kaydırma yok, tek nokta yerleşimi.
            g.drawString(text, font,
                bounds: Rect.fromLTWH(shown.left, shown.top, 0, 0));
          }
        }
        g.restore();
      }
      final result = await out.save();
      final leaks = leakedWords(result, rects);
      if (leaks.isNotEmpty) {
        throw PdfToolsException(
            'Karartma doğrulanamadı: ${leaks.length} sözcük kutuda kaldı');
      }
      return result;
    } finally {
      out.dispose();
      src.dispose();
    }
  }

  static Future<List<int>> applyInBackground(
    List<int> bytes, {
    required Map<int, List<Rect>> rects,
    required List<RedactedRaster> rasters,
    List<int>? fontBytes,
    String? password,
    PdfConformanceLevel? conformance,
  }) =>
      Isolate.run(() async {
        try {
          return await apply(bytes,
              rects: rects,
              rasters: rasters,
              fontBytes: fontBytes,
              password: password,
              conformance: conformance);
        } catch (e) {
          throw PdfToolsException('$e');
        }
      });

  /// Doğrulama: [bytes] belgesinde [rects] kutularına (1 pt içeriden) değen
  /// sözcükler. Boş liste = karartma sağlam.
  static List<String> leakedWords(List<int> bytes, Map<int, List<Rect>> rects,
      {String? password}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final extractor = PdfTextExtractor(doc);
      final leaks = <String>[];
      rects.forEach((i, boxes) {
        if (i >= doc.pages.count) return;
        final page = doc.pages[i];
        final inner = [for (final b in boxes) b.deflate(1)];
        for (final line
            in extractor.extractTextLines(startPageIndex: i, endPageIndex: i)) {
          for (final word in line.wordCollection) {
            if (word.text.trim().isEmpty) continue;
            final shown =
                rawToDisplay(word.bounds, page.size, page.rotation.index);
            if (inner.any((b) => b.overlaps(shown))) leaks.add(word.text);
          }
        }
      });
      return leaks;
    } finally {
      doc.dispose();
    }
  }
}
