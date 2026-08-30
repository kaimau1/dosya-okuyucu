import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../screens/scan_result_screen.dart';
import '../screens/scan_review_screen.dart';
import '../services/document_scanner.dart';
import '../services/fm/entry_opener.dart';
import '../services/ocr_service.dart';
import '../services/scan_title.dart';
import '../core/snack.dart';

/// Belge tarama akışı: kamera/tarayıcı arayüzü → OCR (hep) → akıllı ad →
/// tek PDF → Belgeler dizinine kaydet → sonuç ekranı.
///
/// Tek giriş noktası [run]; ana ekrandan ve PDF araçlarından aynı akış çağrılır
/// ([TranslateFlow] ile aynı kalıp).
///
/// **"Aranabilir olsun mu?" penceresi KALDIRILDI (2026-08-05).** Kullanıcı
/// ilkesi: *"kullanıcıya bir şey bırakma, otomatik olmalı."* OCR cihaz içinde
/// ve sayfa başına ~yarım saniye; her tarama artık kendiliğinden aranabilir,
/// metni kopyalanabilir VE adını içeriğinden alır. Soru sormak, doğru cevabı
/// bildiğimiz bir konuda kullanıcıya iş çıkarmaktı.
class ScanFlow {
  /// Taramayı çalıştırır. Üretilen PDF'in yolunu döndürür (iptal edilirse null).
  /// [open] true ise belge sonunda görüntüleyicide açılır (son belgelere düşer).
  static Future<String?> run(BuildContext context, {bool open = true}) async {
    List<String>? pages;
    try {
      pages = await DocumentScanner.scanPages();
    } catch (e) {
      if (context.mounted) {
        _snack(context,
            AppStrings.current.t('sf.scanner_failed', {'error': e}));
      }
      return null;
    }
    if (pages == null || !context.mounted) return null;

    // Önizleme/köşe düzeltme: sayfa yamuksa PDF'e girmeden düzeltilir.
    final reviewed = await ScanReviewScreen.open(context, pages);
    if (reviewed == null || reviewed.isEmpty || !context.mounted) return null;
    pages = reviewed;

    final progress = ValueNotifier<String>(AppStrings.current
        .t('sf.ocr_progress', {'n': 1, 'total': pages.length}));
    _showProgress(context, progress);

    String? path;
    String? error;
    var textPages = const <OcrPage>[];
    var ocrLines = const <List<OcrLine>>[];
    try {
      // OCR bir kez koşar; sonucu ÜÇ yere gider: PDF'in görünmez metin
      // katmanı, sonuç ekranının "Metin" sekmesi ve belgenin akıllı adı.
      ocrLines = await DocumentScanner.recognizePages(
        pages,
        onProgress: (done, total) => progress.value = AppStrings.current
            .t('sf.ocr_progress', {'n': done + 1, 'total': total}),
      );
      textPages = DocumentScanner.textPages(ocrLines);
      progress.value = AppStrings.current.t('sf.building_pdf');
      final bytes =
          await DocumentScanner.renderPdf(pages, ocrLinesPerPage: ocrLines);
      final title =
          suggestScanTitle(ocrLines.isNotEmpty ? ocrLines.first : const []);
      path = await DocumentScanner.savePdf(bytes,
          fileName: scanFileName(title, DateTime.now()));
    } catch (e) {
      error = '$e';
    }

    if (!context.mounted) return null;
    Navigator.of(context).pop(); // ilerleme penceresi

    if (error != null || path == null) {
      _snack(context, AppStrings.current.t('sf.save_failed', {'error': error}));
      return null;
    }

    // Belge üretildi → "Son belgeler"e YAZ. Eskiden bu kayıt yalnız
    // görüntüleyicide açılınca yapılıyordu; tarama kendi sonuç ekranına
    // gittiği için üretilen PDF hiçbir listede görünmüyordu (2026-08-06
    // kullanıcı bulgusu). Kayıt sonuç ekranı açılmadan ÖNCE atılıyor:
    // kullanıcı geri tuşuyla çıksa da belge listede duruyor.
    await EntryOpener.rememberFile(context, path);
    if (!context.mounted) return path;

    // Sonuç ekranı: belge + tanınan metin + çeviri + kaydetme yeri. Eskiden
    // doğrudan görüntüleyici açılıyordu ve tanınan metnin gidecek yeri yoktu.
    if (open) {
      await ScanResultScreen.open(
        context,
        pdfPath: path,
        pages: pages,
        textPages: textPages,
        ocrLines: ocrLines,
      );
    } else {
      _snack(context,
          AppStrings.current.t('sf.saved_n', {'n': pages.length}));
    }
    return path;
  }

  static void _showProgress(
      BuildContext context, ValueNotifier<String> progress) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator()),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, v, __) => Text(v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    showSnack(context, msg);
  }
}
