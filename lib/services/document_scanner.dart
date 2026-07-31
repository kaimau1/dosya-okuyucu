import 'dart:io';
import 'dart:typed_data';

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
    final ocrLines = searchable
        ? await recognizePages(imagePaths, onProgress: onProgress)
        : const <List<OcrLine>>[];
    final bytes = await renderPdf(imagePaths, ocrLinesPerPage: ocrLines);
    return savePdf(bytes);
  }

  /// Sayfaları OCR'lar — satır **kutularıyla** birlikte.
  ///
  /// Ayrı bir adım olması gerekiyor: aynı sonuç iki yerde kullanılıyor —
  /// PDF'in görünmez metin katmanı **ve** tarama sonucu ekranındaki "Metin"
  /// sekmesi (kullanıcı isteği 2026-07-31: *"bir sayfada belge, bir sayfada
  /// yazılar düzgün formatta"*). İki kez taramak süreyi ikiye katlardı.
  static Future<List<List<OcrLine>>> recognizePages(
    List<String> imagePaths, {
    void Function(int done, int total)? onProgress,
  }) async {
    final out = <List<OcrLine>>[];
    for (var i = 0; i < imagePaths.length; i++) {
      onProgress?.call(i, imagePaths.length);
      out.add(await OcrService.recognizeImageLines(imagePaths[i]));
    }
    onProgress?.call(imagePaths.length, imagePaths.length);
    return out;
  }

  /// Sayfa görsellerinden PDF baytları üretir (diske yazmaz).
  ///
  /// Her sayfa A4: gerçek bir tarayıcı gibi tek boy kâğıt. Görsel oranı
  /// korunarak sayfaya tam oturtulur (kırpılmaz), yatay sayfa yatay basılır.
  static Future<Uint8List> renderPdf(
    List<String> imagePaths, {
    List<List<OcrLine>> ocrLinesPerPage = const [],
  }) =>
      ConversionService().imagesToPdf(
        imagePaths,
        ocrLinesPerPage: ocrLinesPerPage,
        uniformPage: PdfPageFormat.a4,
      );

  /// PDF'i diske yazar ve yolunu döner. [dir] verilmezse Belgeler dizini
  /// (kullanıcı sonuç ekranından başka bir klasör seçebiliyor).
  static Future<String> savePdf(Uint8List bytes,
      {String? dir, String? fileName}) async {
    final target = dir ?? (await defaultDir()).path;
    await Directory(target).create(recursive: true);
    final path = p.join(target, fileName ?? 'Tarama ${_stamp()}.pdf');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Taranan sayfaların düz metni — sayfa sayfa (boş sayfa listeye girmez).
  static List<OcrPage> textPages(List<List<OcrLine>> ocrLinesPerPage) {
    final out = <OcrPage>[];
    for (var i = 0; i < ocrLinesPerPage.length; i++) {
      final text = ocrLinesPerPage[i]
          .map((line) => line.text.trim())
          .where((line) => line.isNotEmpty)
          .join('\n');
      if (text.isNotEmpty) out.add(OcrPage(i + 1, text));
    }
    return out;
  }

  /// Yeni belgelerle aynı yer (bkz. `BlankDocs`): kullanıcı taramasını "Son
  /// belgeler"de ve dosya yöneticisinde aynı klasörde bulsun.
  static Future<Directory> defaultDir() async {
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
