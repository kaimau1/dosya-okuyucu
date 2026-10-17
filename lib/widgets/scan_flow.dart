import 'package:flutter/material.dart';

import '../core/busy_dialog.dart';
import '../core/l10n/app_strings.dart';
import '../screens/scan_result_screen.dart';
import '../services/document_scanner.dart';
import '../services/fm/entry_opener.dart';
import '../services/ocr_service.dart';
import '../services/scan_prepare.dart';
import '../services/scan_title.dart';
import '../core/snack.dart';

/// Belge tarama akışı: tarayıcı → sayfa hazırlığı (düzleştir + netleştir,
/// KIRPMA YOK) → OCR (hep) → akıllı ad → tek PDF → Belgeler dizinine
/// **doğrudan kaydet** → sonuç ekranı.
///
/// Tek giriş noktası [run]; ana ekrandan ve PDF araçlarından aynı akış çağrılır
/// ([TranslateFlow] ile aynı kalıp).
///
/// **"Aranabilir olsun mu?" penceresi KALDIRILDI (2026-08-05).** Kullanıcı
/// ilkesi: *"kullanıcıya bir şey bırakma, otomatik olmalı."*
///
/// **Önizleme ekranı akıştan ÇIKTI (2026-10-17).** Kullanıcı: *"belge
/// taramada kesme sorunu ve direk kaydetmesi gerekli, baştan sona
/// incelenmeli tüm akış"*. ML Kit'te "Kaydet"e basan kullanıcı bir de
/// önizlemede "Devam" demek zorundaydı ve önizleme açılışta sayfayı ikinci
/// kez kırpıyordu (kök neden: [ScanPrepare]). Artık tek ilerleme penceresi
/// içinde hazırlanıp kaydediliyor; filtre/döndürme/kırpma/sıra isteyen
/// sonuç ekranındaki "Sayfaları düzenle"yi kullanıyor.
class ScanFlow {
  /// Taramayı çalıştırır. Üretilen PDF'in yolunu döndürür (iptal edilirse null).
  /// [open] true ise sonunda sonuç ekranı açılır.
  static Future<String?> run(BuildContext context, {bool open = true}) async {
    List<String>? scanned;
    try {
      scanned = await DocumentScanner.scanPages();
    } catch (e) {
      if (context.mounted) {
        _snack(
            context, AppStrings.current.t('sf.scanner_failed', {'error': e}));
      }
      return null;
    }
    if (scanned == null || scanned.isEmpty || !context.mounted) return null;

    final progress = ValueNotifier<String>(AppStrings.current
        .t('sf.preparing', {'n': 1, 'total': scanned.length}));
    final busy = _showProgress(context, progress);

    String? path;
    String? error;
    var pages = <ScanPage>[];
    var textPages = const <OcrPage>[];
    var ocrLines = const <List<OcrLine>>[];
    try {
      pages = await ScanPrepare.pages(
        scanned,
        onProgress: (done, total) => progress.value = AppStrings.current.t(
            'sf.preparing', {'n': (done + 1).clamp(1, total), 'total': total}),
      );
      final images = ScanPage.displays(pages);
      // OCR bir kez koşar; sonucu ÜÇ yere gider: PDF'in görünmez metin
      // katmanı, sonuç ekranının "Metin" sekmesi ve belgenin akıllı adı.
      ocrLines = await DocumentScanner.recognizePages(
        images,
        onProgress: (done, total) => progress.value = AppStrings.current.t(
            'sf.ocr_progress',
            {'n': (done + 1).clamp(1, total), 'total': total}),
      );
      textPages = DocumentScanner.textPages(ocrLines);
      progress.value = AppStrings.current.t('sf.building_pdf');
      final bytes =
          await DocumentScanner.renderPdf(images, ocrLinesPerPage: ocrLines);
      final title =
          suggestScanTitle(ocrLines.isNotEmpty ? ocrLines.first : const []);
      path = await DocumentScanner.savePdf(bytes,
          fileName: scanFileName(title, DateTime.now()));
    } catch (e) {
      error = '$e';
    }

    busy.close();
    if (!context.mounted) return path;

    if (error != null || path == null) {
      _snack(context, AppStrings.current.t('sf.save_failed', {'error': error}));
      return null;
    }

    // Belge üretildi → "Son belgeler"e YAZ (2026-08-06 bulgusu). Sonuç ekranı
    // açılmadan ÖNCE: kullanıcı geri tuşuyla çıksa da belge listede duruyor.
    await EntryOpener.rememberFile(context, path);
    if (!context.mounted) return path;

    if (open) {
      await ScanResultScreen.open(
        context,
        pdfPath: path,
        pages: pages,
        textPages: textPages,
        ocrLines: ocrLines,
      );
    } else {
      _snack(context, AppStrings.current.t('sf.saved_n', {'n': pages.length}));
    }
    return path;
  }

  /// İlerleme penceresini açar ve **onu kapatacak tutamağı** döner (bkz.
  /// `core/busy_dialog.dart` — `Navigator.pop` arkadaki sayfayı kapatabilir).
  static BusyDialog _showProgress(
      BuildContext context, ValueNotifier<String> progress) {
    return showBusyDialog(
      context,
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
