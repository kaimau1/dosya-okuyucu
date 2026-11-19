import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../services/conversion_service.dart';
import '../screens/editors/slides_pro/master_page.dart' show showTemplateGallery;
import '../services/pptx/pro/pptx_package.dart' show PptxPro;
import '../services/pptx/pro/pptx_templates.dart';
import '../services/pptx_writer.dart';
import '../services/text_to_slides.dart';
import '../core/snack.dart';
import '../core/user_error.dart';

/// Çıktı biçimi.
enum SlidesFormat {
  /// Düzenlenebilir sunum — bizim düzenleyicimizde ve PowerPoint'te açılır.
  pptx,

  /// Sabit deste — herkes açar, kimse bozamaz.
  pdf,
}

/// Belgeden slayt üretme akışı: biçime bakan sezgi ([TextToSlides]), sonra
/// .pptx / PDF. 2026-11-19 (B15, kullanıcı kararı): "AI ile hazırla" kipi
/// budandı; ücretsiz/çevrimdışı yol tek başına kaldı.
class SlidesFlow {
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

    final format = await _pickFormat(context);
    if (format == null || !context.mounted) return;

    final slides = TextToSlides.split(source);
    if (slides.isEmpty) {
      _snack(context, str.t('vw.slides_no_text'));
      return;
    }
    final stem = _stem(fileName);
    try {
      if (format == SlidesFormat.pptx) {
        // Faz 38 / madde 2: tasarım önerisi — içeriğe göre sıralı şablon
        // galerisi; vazgeçilirse sade deste.
        var deck = PptxWriter.build(slides);
        final tpl = await showTemplateGallery(context,
            suggested: PptxTemplates.suggest(slides));
        if (!context.mounted) return;
        if (tpl != null) deck = await PptxPro.run(deck, PptxTemplates.apply(tpl));
        final path = await ConversionService().writeToTemp('$stem.pptx', deck);
        if (!context.mounted) return;
        await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: str.t('vw.slides_share')));
      } else {
        final bytes = await ConversionService().slidesToPdf(stem, slides);
        final path =
            await ConversionService().writeToTemp('$stem-slayt.pdf', bytes);
        if (!context.mounted) return;
        await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: str.t('sl.pdf_share')));
      }
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, str.t('ais.failed', {'error': userErrorText(e)}));
    }
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
              leading: const Icon(AppIcons.slideshow),
              title: Text(ctx.t('ais.as_pptx')),
              subtitle: Text(ctx.t('ais.as_pptx_hint')),
              onTap: () => Navigator.pop(ctx, SlidesFormat.pptx),
            ),
            ListTile(
              leading: const Icon(AppIcons.pdf),
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
    showSnack(context, message);
  }
}
