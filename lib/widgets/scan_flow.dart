import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/busy_dialog.dart';
import '../core/safe_insets.dart';
import '../core/l10n/app_strings.dart';
import '../screens/scan_result_screen.dart';
import '../services/document_scanner.dart';
import '../services/fm/activity_log.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/job_queue.dart' show FmJobTarget;
import '../services/fm/tracked_task.dart';
import '../services/ocr_service.dart';
import '../services/scan_prepare.dart' show ScanPage;
import '../services/scan_title.dart';
import '../core/snack.dart';

/// Belge tarama akışı: tarayıcı → OCR (hep) → akıllı ad → tek PDF →
/// Belgeler dizinine **doğrudan kaydet** → tarama stüdyosu.
///
/// Tek giriş noktası [run]; ana ekrandan ve PDF araçlarından aynı akış çağrılır
/// ([TranslateFlow] ile aynı kalıp).
///
/// **"Aranabilir olsun mu?" penceresi KALDIRILDI (2026-08-05).** Kullanıcı
/// ilkesi: *"kullanıcıya bir şey bırakma, otomatik olmalı."*
///
/// **Önizleme ekranı akıştan ÇIKTI (2026-10-17)**: ML Kit'te "Kaydet"e basan
/// kullanıcı ikinci bir onay ekranı görmüyor.
///
/// **Sayfaya kendiliğinden DOKUNULMAZ (2026-10-18).** Kullanıcı: *"belge
/// tarandıktan ve onaylandıktan sonra arka planda yapılan iyileştirmeler
/// resmin patlamasına ve bozulmasına sebep oluyor"*. Önceki tur her sayfayı
/// onaydan SONRA düzleştirip netleştiriyordu; resimli sayfada ikisi de
/// fotoğrafı bozuyordu (bkz. `ScanPrepare`). Artık kaydedilen sayfa,
/// kullanıcının ML Kit ekranında onayladığı sayfanın ta kendisi; netleştirme,
/// düzleştirme ve kırpma stüdyoda tek dokunuş uzakta.
class ScanFlow {
  /// Taramayı çalıştırır. Üretilen PDF'in yolunu döndürür (iptal edilirse null).
  /// [open] true ise sonunda tarama stüdyosu açılır.
  static Future<String?> run(BuildContext context, {bool open = true}) async {
    if (!await showTipsIfNeeded(context) || !context.mounted) return null;
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

    final total = scanned.length;
    final progress = ValueNotifier<({String text, double? value})>((
      text: AppStrings.current.t('sf.ocr_progress', {'n': 1, 'total': total}),
      value: 0,
    ));
    final busy = _showProgress(context, progress);
    // Çok sayfalı taramada OCR uzun sürebilir: 1,5 sn'yi geçerse ana ekran
    // şeridinde ve bildirimde "Sayfa 4 / 12 · ~20 sn kaldı" diye görünür.
    final task = TrackedTask(
      title: AppStrings.current.t('sf.title'),
      name: AppStrings.current.t('sf.job_name'),
    );

    String? path;
    String? error;
    final pages = [for (final path in scanned) ScanPage.raw(path)];
    var textPages = const <OcrPage>[];
    var ocrLines = const <List<OcrLine>>[];
    try {
      final images = ScanPage.displays(pages);
      // OCR bir kez koşar; sonucu ÜÇ yere gider: PDF'in görünmez metin
      // katmanı, stüdyonun "Metin" sekmesi ve belgenin akıllı adı.
      ocrLines = await DocumentScanner.recognizePages(
        images,
        onProgress: (done, total) {
          final text = AppStrings.current.t('sf.ocr_progress',
              {'n': (done + 1).clamp(1, total), 'total': total});
          progress.value = (
            text: text,
            // Son %15 PDF'e ayrılır: çubuk "bitti" deyip beklemesin.
            value: 0.85 * done / total,
          );
          task.report(detail: text, done: done, total: total);
        },
      );
      textPages = DocumentScanner.textPages(ocrLines);
      progress.value =
          (text: AppStrings.current.t('sf.building_pdf'), value: 0.9);
      final bytes =
          await DocumentScanner.renderPdf(images, ocrLinesPerPage: ocrLines);
      final title =
          suggestScanTitle(ocrLines.isNotEmpty ? ocrLines.first : const []);
      path = await DocumentScanner.savePdf(bytes,
          fileName: scanFileName(title, DateTime.now()));
      progress.value = (text: AppStrings.current.t('sf.building_pdf'), value: 1);
    } catch (e) {
      error = '$e';
    }

    busy.close();
    progress.dispose();
    final watched = TrackedTask.userWatching;
    if (error != null || path == null) {
      await task.fail(error ?? '-', quiet: watched);
    } else {
      task.target = FmJobTarget.files([path]);
      await task.complete(
          detail: AppStrings.current.t('sf.saved_n', {'n': pages.length}),
          quiet: watched);
    }
    if (!context.mounted) return path;

    if (error != null || path == null) {
      _snack(context, AppStrings.current.t('sf.save_failed', {'error': error}));
      return null;
    }

    // Belge üretildi → "Son belgeler"e YAZ (2026-08-06 bulgusu). Stüdyo
    // açılmadan ÖNCE: kullanıcı geri tuşuyla çıksa da belge listede duruyor.
    await EntryOpener.rememberFile(context, path);
    // "Yaptıklarım" defteri de: eskiden yalnız sonuç ekranında bir düzenleme
    // PDF'i yeniden yazınca kaydediliyordu — düzenlenmeyen tarama defterde
    // hiç görünmüyordu (2026-10-18 hata taraması).
    unawaited(ActivityLog.add(ActivityKind.scan, path));
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

  static const _kTipsShown = 'scan_tips_shown';

  /// Rehber kaç taramada kendiliğinden çıkar (sonra hiç çıkmaz).
  static const tipsAutoShowLimit = 3;

  /// **Taramadan önce kısa rehber** (2026-10-18, kullanıcı ekran
  /// görüntüsüyle: *"sayfa ekle daha açıklayıcı olmalı, insanlar sayfa
  /// eklemek için Sonraki'ye basıyor ve ekleyemiyor"*).
  ///
  /// Tarama ekranı Google ML Kit'in KENDİ arayüzü (bkz. `DocumentScanner`):
  /// düğmelerine, yazılarına, yerleşimine koddan dokunulamıyor — sağ alttaki
  /// "sayfa ekle" simgesi yazısız, "Sonraki" ise taramayı BİTİRİYOR. Yapılabilen
  /// tek şey kullanıcıyı o ekrana girmeden önce hazırlamak: hangi düğmenin ne
  /// yaptığı, ML Kit ekranındaki görünüşüyle çizilir. İlk [tipsAutoShowLimit]
  /// taramada çıkar; "Bir daha gösterme" ile hemen kapanır. Ayrıca stüdyodaki
  /// "Sayfa ekle" kutusu, Sonraki'ye erken basanın geri dönüş yolu.
  ///
  /// `false` = kullanıcı vazgeçti (taramaya girilmez).
  static Future<bool> showTipsIfNeeded(BuildContext context) async {
    var shown = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      shown = prefs.getInt(_kTipsShown) ?? 0;
    } catch (_) {}
    if (shown >= tipsAutoShowLimit || !context.mounted) return true;
    final result = await _showScanTips(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _kTipsShown, result == _TipsResult.never ? 999 : shown + 1);
    } catch (_) {}
    return result != null;
  }

  /// Rehberi her durumda gösterir. `null` = kapatıldı/vazgeçildi.
  static Future<_TipsResult?> _showScanTips(BuildContext context) =>
      showModalBottomSheet<_TipsResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (ctx) => const _ScanTipsSheet(),
      );

  /// İlerleme penceresini açar ve **onu kapatacak tutamağı** döner (bkz.
  /// `core/busy_dialog.dart` — `Navigator.pop` arkadaki sayfayı kapatabilir).
  static BusyDialog _showProgress(BuildContext context,
      ValueNotifier<({String text, double? value})> progress) {
    return showBusyDialog(
      context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          content: ValueListenableBuilder<({String text, double? value})>(
            valueListenable: progress,
            builder: (_, v, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.document_scanner_outlined,
                      color: scheme.onPrimaryContainer, size: 28),
                ),
                const SizedBox(height: 16),
                Text(ctx.t('sf.title'),
                    style: Theme.of(ctx).textTheme.titleMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(v.text,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: v.value, minHeight: 6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _snack(BuildContext context, String msg) {
    showSnack(context, msg);
  }
}

enum _TipsResult { start, never }

/// Rehber sayfası: ML Kit ekranının üç düğmesi, o ekrandaki görünüşleriyle.
class _ScanTipsSheet extends StatelessWidget {
  const _ScanTipsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // ML Kit ekranının kendi renkleri (koyu zemin, açık mavi düğmeler):
    // kullanıcı rehberdeki düğmeyi o ekranda AYNI görünüşle tanısın.
    const mlDark = Color(0xFF1F1F1F);
    const mlBlue = Color(0xFFA8C7FA);
    const mlDeep = Color(0xFF0B57D0);
    Widget step(Widget visual, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 92, child: Center(child: visual)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );
    // **Alt boşluk gezinme çubuğunu aşar** (kullanıcı ekran görüntüsü
    // 2026-10-18: "Anladım, bir daha gösterme" sistem çubuğunun altında
    // kalıyordu). `useSafeArea` yalnız ÜST kenarı korur; alt kenar burada.
    return SingleChildScrollView(
      padding: withNavInset(context, const EdgeInsets.fromLTRB(20, 0, 20, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('sf.tips_title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(context.t('sf.tips_sub'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          step(
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.document_scanner_outlined,
                  color: scheme.onPrimaryContainer, size: 28),
            ),
            context.t('sf.tip1_title'),
            context.t('sf.tip1_body'),
          ),
          step(
            // ML Kit'in "sayfa ekle" düğmesi: koyu mavi yuvarlak kare,
            // içinde artılı sayfa — yazısız olduğu için gözden kaçıyor.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: mlDeep.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.note_add_outlined,
                      color: Colors.white, size: 30),
                ),
                const Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(Icons.touch_app_rounded,
                      size: 30, color: Color(0xFFF57C00)),
                ),
              ],
            ),
            context.t('sf.tip2_title'),
            context.t('sf.tip2_body'),
          ),
          step(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: mlBlue,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(context.t('sf.tip_next_label'),
                  style: const TextStyle(
                      color: mlDark, fontWeight: FontWeight.w600)),
            ),
            context.t('sf.tip3_title'),
            context.t('sf.tip3_body'),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            onPressed: () => Navigator.pop(context, _TipsResult.start),
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(context.t('sf.tips_start')),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context, _TipsResult.never),
            child: Text(context.t('sf.tips_never')),
          ),
        ],
      ),
    );
  }
}
