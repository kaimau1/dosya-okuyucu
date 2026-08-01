import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../services/gemini_service.dart';
import 'markdown_text.dart';

/// Özetin ne kadar ayrıntılı olacağı.
///
/// **Neden iki seçenek, neden tek "özetle" değil:** kullanıcı bir sunumu iki
/// ayrı sebeple özetletir — ya "toplantıya girerken 20 saniyede ne anlatıyor"
/// (kısa) ya da "slayt slayt neyi kaçırdım" (detaylı). Tek bir uzunluk
/// ikisinden birini daima yanlış boyda verirdi.
enum SummaryLength { short, detailed }

/// AI özet akışı: uzunluk seç → Gemini'ye sor → sonucu kopyalanabilir/
/// paylaşılabilir bir sayfada göster.
///
/// [TranslateFlow] ile aynı kalıp: ekranlar yalnız metni verir, akışın kendisi
/// (anahtar denetimi, ilerleme penceresi, sonuç sayfası) tek yerde durur.
class AiSummaryFlow {
  /// Modele gönderilen üst sınır. Uzun bir sunumun tamamını yollamak hem
  /// pahalı hem gereksiz; kesildiğinde sonuç sayfasında YAZAR (sessizce
  /// kırpılmış bir özeti tam sanmak kötü olurdu).
  static const int maxChars = 24000;

  static Future<void> run(
    BuildContext context,
    String text, {
    required String title,
  }) async {
    final str = AppStrings.of(context);
    final source = text.trim();
    if (source.isEmpty) {
      _snack(context, str.t('ai.sum_no_text'));
      return;
    }

    final appState = context.read<AppState>();
    if (!appState.hasApiKey) {
      _snack(context, str.t('aia.need_key'));
      return;
    }

    final length = await _pickLength(context);
    if (length == null || !context.mounted) return;

    final trimmed =
        source.length > maxChars ? source.substring(0, maxChars) : source;
    final prompt = str.t(length == SummaryLength.short
        ? 'ai.sum_prompt_short'
        : 'ai.sum_prompt_detailed');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator()),
            const SizedBox(width: 16),
            Expanded(child: Text(ctx.t('ai.sum_working'))),
          ],
        ),
      ),
    );

    String? summary;
    String? error;
    try {
      final gemini =
          GeminiService(apiKey: appState.apiKey, model: appState.model);
      summary = await gemini.chat(
        history: [ChatTurn(fromUser: true, text: prompt)],
        fileContext: trimmed,
      );
    } catch (e) {
      error = '$e';
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // ilerleme penceresi
    if (!context.mounted) return;

    if (error != null || summary == null) {
      _snack(context, str.t('aia.summary_failed', {'error': error ?? ''}));
      return;
    }
    _showResult(
      context,
      title: title,
      summary: summary,
      length: length,
      truncated: source.length > maxChars,
    );
  }

  static Future<SummaryLength?> _pickLength(BuildContext context) {
    return showModalBottomSheet<SummaryLength>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.short_text),
              title: Text(ctx.t('ai.sum_short')),
              subtitle: Text(ctx.t('ai.sum_short_hint')),
              onTap: () => Navigator.pop(ctx, SummaryLength.short),
            ),
            ListTile(
              leading: const Icon(Icons.notes),
              title: Text(ctx.t('ai.sum_detailed')),
              subtitle: Text(ctx.t('ai.sum_detailed_hint')),
              onTap: () => Navigator.pop(ctx, SummaryLength.detailed),
            ),
          ],
        ),
      ),
    );
  }

  static void _showResult(
    BuildContext context, {
    required String title,
    required String summary,
    required SummaryLength length,
    required bool truncated,
  }) {
    final str = AppStrings.of(context);
    final header = '$title — ${str.t(length == SummaryLength.short
        ? 'ai.sum_short'
        : 'ai.sum_detailed')}';
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
                  IconButton(
                    tooltip: ctx.t('common.share'),
                    icon: const Icon(Icons.share_outlined, size: 20),
                    onPressed: () => Share.share(summary, subject: title),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: summary));
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
              // Kırpılmış girdi sonuç sayfasında AÇIKÇA yazar.
              if (truncated)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    ctx.t('ai.sum_truncated', {'n': maxChars}),
                    style: Theme.of(ctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(ctx).colorScheme.error),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.only(top: 12),
                  child: MarkdownText(summary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
