import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../core/app_state.dart';
import '../services/gemini_service.dart';

/// Seçili parça üzerinde en sık istenen düzeltmeler.
///
/// Çift: (etiket anahtarı, **AI'ya gidecek istem** anahtarı); ikisi de arayüz
/// diliyle çözülür, yoksa Arapça arayüzde Türkçe istem giderdi.
const _presets = <(String, String)>[
  ('aw.preset_fix', 'aw.preset_fix_prompt'),
  ('aw.preset_shorten', 'aw.preset_shorten_prompt'),
  ('aw.preset_simplify', 'aw.preset_simplify_prompt'),
  ('aw.preset_formal', 'aw.preset_formal_prompt'),
];

/// Seçili metni AI ile yeniden yazdırır; sonucu döndürür (vazgeçilirse null).
///
/// Sayfa üzerindeki yerinde düzenleyiciden açılır: kullanıcı düzenleme kutusunu
/// KAYBETMEDEN metni AI'a düzelttirip aynı kutuya geri alır.
Future<String?> showAiRewriteSheet(BuildContext context, String text) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AiRewriteSheet(text: text),
    ),
  );
}

class _AiRewriteSheet extends StatefulWidget {
  const _AiRewriteSheet({required this.text});
  final String text;

  @override
  State<_AiRewriteSheet> createState() => _AiRewriteSheetState();
}

class _AiRewriteSheetState extends State<_AiRewriteSheet> {
  final _instruction = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    if (!state.hasApiKey) {
      setState(() => _error = context.t('aia.need_key'));
      return;
    }
    final task = _instruction.text.trim();
    if (task.isEmpty) {
      setState(() => _error = context.t('pa.need_task'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // İstem await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final prompt =
        context.t('aw.prompt', {'task': task, 'text': widget.text});
    try {
      final answer =
          await GeminiService(apiKey: state.apiKey, model: state.model).chat(
        history: [
          ChatTurn(
            fromUser: true,
            text: prompt,
          ),
        ],
      );
      if (!mounted) return;
      Navigator.of(context).pop(answer.trim());
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('aw.title'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(widget.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (labelKey, promptKey) in _presets)
                  ActionChip(
                    label: Text(context.t(labelKey)),
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _instruction.text = context.t(promptKey)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _instruction,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: context.t('aw.hint'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: Text(context.t('common.cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _run,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high),
                  label: Text(
                      context.t(_busy ? 'aw.working' : 'common.apply')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
