import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../core/l10n/app_strings.dart';
import '../services/translate_service.dart';

/// Çeviri akışı: dil seç → (ilk kullanımda) dil modelini indir → çevir →
/// sonucu kopyalanabilir bir sayfada göster.
///
/// Tek giriş noktası [run]; hem PDF görüntüleyiciden (seçili metin) hem belge
/// ekranlarından (tüm belge) çağrılır — akış tek yerde durur.
class TranslateFlow {
  static Future<void> run(
    BuildContext context,
    String text, {
    String? title,
  }) async {
    final str = AppStrings.of(context);
    title ??= str.t('tf.title');
    final source = text.trim();
    if (source.isEmpty) {
      _snack(context, str.t('tf.no_text'));
      return;
    }

    final pair = await TranslateService.lastPair();
    if (!context.mounted) return;
    final chosen = await _pickLanguages(context, pair.$1, pair.$2);
    if (chosen == null || !context.mounted) return;
    final (from, to) = chosen;
    await TranslateService.savePair(from, to);
    if (!context.mounted) return;

    final progress = ValueNotifier<String>(str.t('tf.preparing'));
    _showProgress(context, progress);

    String? result;
    String? error;
    try {
      // Modeller yoksa indir (tek seferlik, internet gerekir; sonrası çevrimdışı).
      for (final lang in {from, to}) {
        if (!await TranslateService.isModelReady(lang)) {
          progress.value = '${str.t('tf.downloading', {
                'lang': TranslateService.languages[lang],
              })}\n${str.t('tf.first_use')}';
          await TranslateService.downloadModel(lang);
        }
      }
      result = await TranslateService.translate(
        source,
        from: from,
        to: to,
        onProgress: (done, total) => progress.value = total > 1
            ? str.t('tf.progress', {'n': done + 1, 'total': total})
            : str.t('tf.working'),
      );
    } catch (e) {
      error = '$e';
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // ilerleme penceresi

    if (error != null) {
      _snack(context, str.t('tf.failed', {'error': error}));
      return;
    }
    if (result == null || result.trim().isEmpty) {
      _snack(context, str.t('tf.empty_result'));
      return;
    }
    _showResult(context, title, result, from, to);
  }

  /// Kaynak/hedef dil seçimi. Kullanıcı iptal ederse null döner.
  static Future<(TranslateLanguage, TranslateLanguage)?> _pickLanguages(
    BuildContext context,
    TranslateLanguage initialFrom,
    TranslateLanguage initialTo,
  ) {
    var from = initialFrom;
    var to = initialTo;
    return showDialog<(TranslateLanguage, TranslateLanguage)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget dropdown(
              TranslateLanguage value, ValueChanged<TranslateLanguage> onChange) {
            return DropdownButton<TranslateLanguage>(
              value: value,
              isExpanded: true,
              items: [
                for (final e in TranslateService.languages.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => v == null ? null : onChange(v),
            );
          }

          return AlertDialog(
            title: Text(ctx.t('tf.lang_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(ctx.t('tf.source_lang'))),
                dropdown(from, (v) => setLocal(() => from = v)),
                const SizedBox(height: 8),
                IconButton(
                  tooltip: ctx.t('tf.swap'),
                  icon: const Icon(Icons.swap_vert),
                  onPressed: () => setLocal(() {
                    final t = from;
                    from = to;
                    to = t;
                  }),
                ),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(ctx.t('tf.target_lang'))),
                dropdown(to, (v) => setLocal(() => to = v)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.t('common.cancel')),
              ),
              FilledButton(
                onPressed: from == to
                    ? null // aynı dil → çeviri anlamsız
                    : () => Navigator.pop(ctx, (from, to)),
                child: Text(ctx.t('common.translate')),
              ),
            ],
          );
        },
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

  static void _showResult(
    BuildContext context,
    String title,
    String text,
    TranslateLanguage from,
    TranslateLanguage to,
  ) {
    final header = '$title — ${TranslateService.languages[from]} → '
        '${TranslateService.languages[to]}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(header,
                        style: Theme.of(ctx).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        _snack(context, context.t('tf.copied'));
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(ctx.t('common.copy')),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.only(top: 12),
                  child: SelectableText(text,
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
