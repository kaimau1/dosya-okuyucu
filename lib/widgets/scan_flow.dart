import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../screens/scan_review_screen.dart';
import '../services/document_scanner.dart';
import '../services/fm/entry_opener.dart';

/// Belge tarama akışı: kamera/tarayıcı arayüzü → (isteğe bağlı) OCR →
/// tek PDF → Belgeler dizinine kaydet → belgeyi aç.
///
/// Tek giriş noktası [run]; ana ekrandan ve PDF araçlarından aynı akış çağrılır
/// ([TranslateFlow] ile aynı kalıp).
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

    final searchable = await _askSearchable(context, pages.length);
    if (searchable == null || !context.mounted) return null;

    final progress = ValueNotifier<String>(
        searchable ? 'Yazılar taranıyor…' : 'PDF hazırlanıyor…');
    _showProgress(context, progress);

    String? path;
    String? error;
    try {
      path = await DocumentScanner.buildPdf(
        pages,
        searchable: searchable,
        onProgress: (done, total) =>
            progress.value = AppStrings.current
                .t('sf.ocr_progress', {'n': done + 1, 'total': total}),
      );
    } catch (e) {
      error = '$e';
    }

    if (!context.mounted) return null;
    Navigator.of(context).pop(); // ilerleme penceresi

    if (error != null || path == null) {
      _snack(context, 'Tarama kaydedilemedi: $error');
      return null;
    }

    _snack(context, '${pages.length} sayfa PDF olarak kaydedildi');
    if (open) await EntryOpener.open(context, path);
    return path;
  }

  /// Aranabilir PDF (OCR metin katmanı) isteniyor mu? Görüntüyü değiştirmez,
  /// yalnızca süre ekler — bu yüzden soruluyor, sessizce yapılmıyor.
  static Future<bool?> _askSearchable(BuildContext context, int pageCount) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('sf.scanned_title', {'n': pageCount})),
        content: Text(ctx.t('sf.scanned_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('sf.image_only')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('sf.with_ocr')),
          ),
        ],
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
