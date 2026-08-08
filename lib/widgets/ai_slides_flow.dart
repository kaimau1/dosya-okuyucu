import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/app_strings.dart';
import '../services/ai_slides.dart';
import '../services/conversion_service.dart';
import '../services/gemini_service.dart';
import '../services/pptx_writer.dart';
import '../services/text_to_slides.dart';

/// Çıktı biçimi.
enum SlidesFormat {
  /// Düzenlenebilir sunum — bizim düzenleyicimizde ve PowerPoint'te açılır.
  pptx,

  /// Sabit deste — herkes açar, kimse bozamaz.
  pdf,
}

/// Belgeden slayt üretme akışı: **AI ile** (anlayarak özetler) ya da **hızlı**
/// (biçime bakan sezgi), sonra .pptx / PDF.
///
/// [AiSummaryFlow] ile aynı kalıp: ekranlar yalnız metni verir; anahtar
/// denetimi, ilerleme penceresi ve paylaşım burada tek yerde durur.
class AiSlidesFlow {
  static Future<void> run(
    BuildContext context,
    String text, {
    required String fileName,
  }) async {
    final str = AppStrings.of(context);
    final source = text.trim();
    if (source.isEmpty) {
      _snack(context, str.t('vw.slides_no_text'));
      return;
    }

    final useAi = await _pickMode(context);
    if (useAi == null || !context.mounted) return;

    final format = await _pickFormat(context);
    if (format == null || !context.mounted) return;

    final appState = context.read<AppState>();
    if (useAi && !appState.hasApiKey) {
      _snack(context, str.t('aia.need_key'));
      return;
    }

    SlidePlan? plan;
    String? error;

    if (useAi) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                  width: 24, height: 24, child: CircularProgressIndicator()),
              const SizedBox(width: 16),
              Expanded(child: Text(ctx.t('ais.working'))),
            ],
          ),
        ),
      );
      try {
        plan = await AiSlides.generate(
          gemini:
              GeminiService(apiKey: appState.apiKey, model: appState.model),
          text: source,
          // Deste kullanıcının ARAYÜZ dilinde çıksın: Arapça arayüz kullanan
          // birine Türkçe slayt üretmek işe yaramaz. Dilin KENDİ adı
          // gönderiliyor ('Türkçe'/'English'/'العربية') — modele 'tr' gibi bir
          // koddan daha net gelir. `system` çözülmemişse `AppStrings.t`in
          // varsayılanıyla aynı yere, Türkçe'ye düşer.
          language: str.language == AppLanguage.system
              ? AppLanguage.tr.nativeLabel
              : str.language.nativeLabel,
        );
      } catch (e) {
        error = '$e';
      }
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;
      if (error != null || plan == null) {
        _snack(context, str.t('ais.failed', {'error': error ?? ''}));
        return;
      }
    } else {
      final drafts = TextToSlides.split(source);
      if (drafts.isEmpty) {
        _snack(context, str.t('vw.slides_no_text'));
        return;
      }
      plan = SlidePlan('', drafts);
    }

    final stem = _stem(fileName);
    try {
      if (format == SlidesFormat.pptx) {
        final path = await ConversionService()
            .writeToTemp('$stem.pptx', PptxWriter.build(plan.slides));
        if (!context.mounted) return;
        await Share.shareXFiles([XFile(path)],
            text: str.t('vw.slides_share'));
      } else {
        final title = plan.title.isEmpty ? stem : plan.title;
        final bytes = await ConversionService().slidesToPdf(title, plan.slides);
        final path =
            await ConversionService().writeToTemp('$stem-slayt.pdf', bytes);
        if (!context.mounted) return;
        await Share.shareXFiles([XFile(path)], text: str.t('sl.pdf_share'));
      }
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, str.t('ais.failed', {'error': e}));
    }
  }

  /// AI mi sezgi mi. **Sezgi yolu duruyor** çünkü AI anahtar ister ve para
  /// harcar; ücretsiz/çevrimdışı seçeneği kaldırmak uygulamanın "sade, hızlı,
  /// ücretsiz" konumlandırmasına aykırı olurdu.
  static Future<bool?> _pickMode(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(ctx.t('ais.with_ai')),
              subtitle: Text(ctx.t('ais.with_ai_hint')),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: Text(ctx.t('ais.quick')),
              subtitle: Text(ctx.t('ais.quick_hint')),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
  }

  static Future<SlidesFormat?> _pickFormat(BuildContext context) {
    return showModalBottomSheet<SlidesFormat>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.slideshow_outlined),
              title: Text(ctx.t('ais.as_pptx')),
              subtitle: Text(ctx.t('ais.as_pptx_hint')),
              onTap: () => Navigator.pop(ctx, SlidesFormat.pptx),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(ctx.t('ais.as_pdf')),
              subtitle: Text(ctx.t('ais.as_pdf_hint')),
              onTap: () => Navigator.pop(ctx, SlidesFormat.pdf),
            ),
          ],
        ),
      ),
    );
  }

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
