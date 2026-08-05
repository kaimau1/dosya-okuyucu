import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf/ocr_page_text.dart' show OcrWordBox;

/// Cihaz-içi OCR (Google ML Kit, Latin alfabesi — Türkçe karakterler dahil).
///
/// İnternet gerekmez; model APK ile gelir. Görsel dosyalardan ve taranmış
/// (metin katmanı olmayan) PDF'lerden metin çıkarır. PDF sayfaları pdfium ile
/// bitmap'e çizilir, geçici PNG üzerinden ML Kit'e verilir.
/// OCR'ın bulduğu tek metin satırı ve resmin piksel koordinatındaki kutusu.
class OcrLine {
  final String text;
  final ui.Rect box;
  const OcrLine(this.text, this.box);
}

/// Tek sayfanın metni (sayfa numarası 1'den başlar).
///
/// Niye sayfa sayfa: çeviri sayfa yapısını KORUMALI ("tüm sayfa olarak çevir",
/// kullanıcı isteği 2026-07-31). Metni tek dizede birleştirip içine
/// "— Sayfa 3 —" yazmak, o başlığın da çeviriye girmesi demekti; sayfa ayrımı
/// veride durursa başlığı arayüz kendi dilinde yazar ve çeviriye hiç sokmaz.
class OcrPage {
  final int number;
  final String text;
  const OcrPage(this.number, this.text);
}

class OcrService {
  /// Tek OCR turunda işlenecek en fazla PDF sayfası (süre/pil koruması).
  ///
  /// "Metni tanı" sayfasının varsayılanı budur. Belge ÇEVİRİSİ bu sınırı
  /// [recognizePdfPages]'in `maxPages`'iyle aşabilir: orada kullanıcı işi
  /// istediği an durdurabiliyor ve durdurulan iş o ana kadarki sayfaları
  /// gösteriyor — yani uzun belgede kararı kullanıcı veriyor, sabit bir
  /// kesme değil.
  static const maxPdfPages = 25;

  /// Bir görsel dosyadan metin tanır. Metin yoksa boş dize döner.
  static Future<String> recognizeImageFile(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }

  /// Bir görselden metni SATIR SATIR, resim piksel koordinatındaki kutusuyla
  /// birlikte tanır. Aranabilir PDF üretiminde (görünmez metin katmanı) her
  /// satırı kendi yerine yazmak için gerekir.
  ///
  /// ponytail: kutular ML Kit'in EXIF döndürmesi uygulanmış hâline göredir;
  /// EXIF ile döndürülmüş fotoğraflarda katman kayabilir — şikayet gelirse
  /// resmi önce normalize edip (döndürmeyi baytlara işleyip) OCR'la.
  static Future<List<OcrLine>> recognizeImageLines(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      return [
        for (final block in result.blocks)
          for (final line in block.lines)
            if (line.text.trim().isNotEmpty)
              OcrLine(line.text, line.boundingBox),
      ];
    } finally {
      await recognizer.close();
    }
  }

  /// Bir görselden metni SÖZCÜK SÖZCÜK, satır yapısı korunarak tanır
  /// (satır başına sözcük listesi; kutular resim piksel koordinatında).
  ///
  /// Taranmış PDF sayfasında Chrome benzeri metin seçimi bunun üstüne kurulur:
  /// sözcük kutuları `buildOcrPageText` ile sahte bir `PdfPageText`e çevrilir
  /// ve seçim katmanı yazılmış sayfayla aynı yoldan çalışır.
  static Future<List<List<OcrWordBox>>> recognizeImageWordLines(
      String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      return [
        for (final block in result.blocks)
          for (final line in block.lines)
            [
              for (final e in line.elements)
                if (e.text.trim().isNotEmpty)
                  OcrWordBox(e.text, e.boundingBox),
            ],
      ];
    } finally {
      await recognizer.close();
    }
  }

  /// Açık bir PDF belgesinin sayfalarını (en çok [maxPdfPages]) OCR'lar.
  /// [onProgress] her sayfa öncesi (işlenen, toplam) ile çağrılır.
  static Future<String> recognizePdf(
    PdfDocument document, {
    void Function(int done, int total)? onProgress,
  }) async {
    final pages =
        await recognizePdfPages(document, onProgress: onProgress);
    return joinPages(pages, (n) => '— Sayfa $n —');
  }

  /// PDF sayfalarını **ayrı ayrı** OCR'lar; metni olmayan sayfa listeye girmez.
  ///
  /// [maxPages] sayfa üst sınırı (varsayılan [maxPdfPages]).
  /// [cancelled] her sayfa öncesi yoklanır; true dönerse o ana kadar tanınan
  /// sayfalar döner (hata atılmaz — yarım sonuç, hiç sonuçtan iyidir ve
  /// kullanıcı işi bilerek durdurmuştur).
  /// [onlyPages] verilirse yalnız o sayfa numaraları (1'den) taranır: metin
  /// katmanı olan PDF'te sadece taranmış sayfalar için OCR'a düşülür.
  static Future<List<OcrPage>> recognizePdfPages(
    PdfDocument document, {
    int maxPages = maxPdfPages,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
    Set<int>? onlyPages,
  }) async {
    final pages = [
      for (final page in document.pages)
        if (onlyPages == null || onlyPages.contains(page.pageNumber)) page,
    ];
    final total = pages.length > maxPages ? maxPages : pages.length;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final out = <OcrPage>[];
    try {
      for (var i = 0; i < total; i++) {
        if (cancelled?.call() ?? false) break;
        onProgress?.call(i, total);
        final page = pages[i];
        final path = await _renderPageToPng(page, i);
        if (path == null) continue;
        try {
          final result =
              await recognizer.processImage(InputImage.fromFilePath(path));
          final text = result.text.trim();
          if (text.isNotEmpty) out.add(OcrPage(page.pageNumber, text));
        } finally {
          try {
            File(path).deleteSync();
          } catch (_) {}
        }
      }
      onProgress?.call(total, total);
      return out;
    } finally {
      await recognizer.close();
    }
  }

  /// Sayfaları tek metne dizer; birden çok sayfa varsa [header] ile başlık
  /// yazar. Saf fonksiyon → birim testli (bkz. test/ocr_pages_test.dart).
  static String joinPages(
      List<OcrPage> pages, String Function(int pageNumber) header) {
    final sb = StringBuffer();
    for (final page in pages) {
      if (pages.length > 1) sb.writeln(header(page.number));
      sb.writeln(page.text);
      sb.writeln();
    }
    return sb.toString().trim();
  }

  /// Sayfayı ~1600px genişlikte PNG'ye çizer (OCR için yeterli çözünürlük).
  static Future<String?> _renderPageToPng(PdfPage page, int index) async =>
      (await renderPageToPng(page, tag: '$index'))?.path;

  /// [_renderPageToPng]'nin ölçeği de döndüren biçimi: `scale` = görüntü
  /// pikseli / PDF punto oranı. Taranmış sayfa seçiminde OCR kutularını sayfa
  /// koordinatına geri çevirmek için gerekir (bkz. `PdfOcrText`).
  static Future<({String path, double scale})?> renderPageToPng(
    PdfPage page, {
    String tag = '',
  }) async {
    final scale = (1600 / page.width).clamp(1.0, 4.0);
    final img = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: const ui.Color(0xFFFFFFFF),
    );
    if (img == null) return null;
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        img.pixels,
        img.width,
        img.height,
        img.format,
        completer.complete,
      );
      final uiImage = await completer.future;
      final png = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      if (png == null) return null;
      final f = File(
          '${Directory.systemTemp.path}/ocr_page_${tag}_${page.pageNumber}.png');
      await f.writeAsBytes(png.buffer.asUint8List());
      return (path: f.path, scale: scale);
    } finally {
      img.dispose();
    }
  }
}
