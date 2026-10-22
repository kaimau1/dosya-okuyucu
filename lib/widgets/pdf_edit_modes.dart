/// **PDF'te tek düzenleme kapısı** (Faz 8 — "PDF tek çatı").
///
/// Eskiden PDF'i değiştirmenin yedi ayrı yüzeyi vardı ve her biri başka bir
/// yerden açılıyordu: alt çubukta Kalem + Düzenleyici, "Daha fazla" sayfasında
/// İmzala / Formu doldur / AI ile düzenle, seçim çubuğunda kelime-bazlı
/// yerinde düzenleme. Kullanıcı hangisinin ne yaptığını deneyerek öğreniyordu.
///
/// Artık görüntüleyicinin alt çubuğunda TEK "Düzenle" düğmesi var; bu sayfa
/// kipi sordurur. Her kip kendi ekranını açar ama kaydetme akışı ortaktır
/// (çalışma kopyası → "Orijinali değiştir / Kopyasını kaydet").
library;

import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import 'doc_more_sheet.dart';

/// Düzenleme kipleri — sıra, sayfadaki sıradır (en sık kullanılan önde).
enum PdfEditMode { text, pen, sign, form, pages, ai }

/// Kip seçme sayfasının öğeleri. Ayrı işlev: `pdf_edit_modes_test` sayfanın
/// altı kipi de etiketiyle gösterdiğini görüntüleyiciyi kurmadan sınar.
List<DocMoreItem> pdfEditModeItems(
  BuildContext context,
  void Function(PdfEditMode mode) onPick,
) {
  DocMoreItem item(PdfEditMode mode, IconData icon, String key) =>
      DocMoreItem(icon, context.t(key), () => onPick(mode));
  return [
    item(PdfEditMode.text, AppIcons.textFields, 'pdfm.text'),
    item(PdfEditMode.pen, Icons.draw_rounded, 'pdfm.pen'),
    item(PdfEditMode.sign, Icons.history_edu_rounded, 'pdfm.sign'),
    item(PdfEditMode.form, Icons.assignment_rounded, 'pdfm.form'),
    item(PdfEditMode.pages, Icons.auto_stories_rounded, 'pdfm.pages'),
    item(PdfEditMode.ai, AppIcons.organize, 'pdfm.ai'),
  ];
}

/// "Düzenle" sayfasını açar; seçilen kip [onPick] ile döner (sayfa kapandıktan
/// SONRA — açılan ekran sayfanın altında kalmasın, bkz. [DocMoreSheet.show]).
Future<void> showPdfEditModes(
  BuildContext context,
  void Function(PdfEditMode mode) onPick,
) =>
    DocMoreSheet.show(
      context,
      [
        DocMoreGroup(
          context.t('pdfm.title'),
          pdfEditModeItems(context, onPick),
        ),
      ],
      header: Text(
        context.t('pdfm.subtitle'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
