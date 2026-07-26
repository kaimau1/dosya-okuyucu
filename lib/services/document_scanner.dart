import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

import 'conversion_service.dart';
import 'ocr_service.dart';

/// **Belge tarayıcı** — kamerayla çekilen sayfayı masaüstü tarayıcıdan çıkmış
/// gibi (kenar tespiti, perspektif düzeltme, kontrast/gri filtre) belgeye
/// çevirir, çok sayfayı tek PDF'te toplar.
///
/// Kenar bulma/kırpma/filtre işini **Google ML Kit Belge Tarayıcı** yapıyor
/// (`cunning_document_scanner` → `play-services-mlkit-document-scanner`,
/// SCANNER_MODE_FULL). Kendi kamera+kırpma ekranımızı yazmak yerine bu seçildi:
/// kenar tespiti Google'ın modeli, bakımı bizde değil, sonuç JPEG olarak geliyor.
/// Play Services yoksa paket kendi yedek tarayıcısına düşüyor.
///
/// Bizim payımız: gelen sayfaları **tek PDF** yapmak, istenirse OCR ile
/// görünmez metin katmanı ekleyip belgeyi **aranabilir** kılmak ve Belgeler
/// dizinine yazmak.
class DocumentScanner {
  const DocumentScanner._();

  /// Tarama arayüzünü açar; kullanıcı vazgeçerse `null`, aksi hâlde taranan
  /// sayfaların (JPEG) yolları döner. Kamera izni paket tarafından isteniyor.
  static Future<List<String>?> scanPages({int maxPages = 30}) async {
    final pages = await CunningDocumentScanner.getPictures(
      noOfPages: maxPages,
      isGalleryImportAllowed: true,
    );
    if (pages == null || pages.isEmpty) return null;
    return pages;
  }

  /// Taranan sayfalardan PDF üretip **Belgeler dizinine** yazar, yolunu döndürür.
  ///
  /// [searchable] ise her sayfa OCR'lanıp görünmez metin katmanı eklenir —
  /// belge hem aranabilir hem kopyalanabilir olur (görüntü değişmez).
  /// [onProgress] sayfa sayfa ilerlemeyi bildirir (OCR uzun sürebilir).
  static Future<String> buildPdf(
    List<String> imagePaths, {
    bool searchable = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final ocrLines = <List<OcrLine>>[];
    if (searchable) {
      for (var i = 0; i < imagePaths.length; i++) {
        onProgress?.call(i, imagePaths.length);
        ocrLines.add(await OcrService.recognizeImageLines(imagePaths[i]));
      }
      onProgress?.call(imagePaths.length, imagePaths.length);
    }

    // Her sayfa A4: gerçek bir tarayıcı gibi tek boy kâğıt. Görsel oranı
    // korunarak sayfaya tam oturtulur (kırpılmaz), yatay sayfa yatay basılır.
    final bytes = await ConversionService().imagesToPdf(
      imagePaths,
      ocrLinesPerPage: ocrLines,
      uniformPage: PdfPageFormat.a4,
    );

    final dir = await _targetDir();
    final path = p.join(dir.path, 'Tarama ${_stamp()}.pdf');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Yeni belgelerle aynı yer (bkz. `BlankDocs`): kullanıcı taramasını "Son
  /// belgeler"de ve dosya yöneticisinde aynı klasörde bulsun.
  static Future<Directory> _targetDir() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return await getApplicationSupportDirectory();
    }
  }

  static String _stamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }
}
