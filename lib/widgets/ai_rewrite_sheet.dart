import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../services/gemini_service.dart';

/// Seçili parça üzerinde en sık istenen düzeltmeler.
const _presets = <(String, String)>[
  ('Yazımı düzelt', 'Bu metindeki yazım ve dil bilgisi hatalarını düzelt. '
      'Anlamı ve üslubu koru, uzunluğu mümkün olduğunca aynı tut.'),
  ('Kısalt', 'Bu metni anlamını kaybetmeden belirgin biçimde kısalt.'),
  ('Sadeleştir', 'Bu metni daha anlaşılır ve sade bir dille yeniden yaz.'),
  ('Resmîleştir', 'Bu metni resmî yazışma diline uygun hâle getir.'),
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
      setState(() => _error =
          'Önce Ayarlar > Gemini API anahtarı bölümünden anahtarınızı girin.');
      return;
    }
    final task = _instruction.text.trim();
    if (task.isEmpty) {
      setState(() => _error = 'Ne yapılmasını istediğinizi yazın ya da seçin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final answer =
          await GeminiService(apiKey: state.apiKey, model: state.model).chat(
        history: [
          ChatTurn(
            fromUser: true,
            text: 'Aşağıdaki metni şu yönergeye göre yeniden yaz: "$task"\n\n'
                'Metin:\n"""\n${widget.text}\n"""\n\n'
                'ÇOK ÖNEMLİ: yalnızca yeni metni döndür. Açıklama, tırnak, '
                'giriş cümlesi ya da kod bloğu işareti EKLEME. Metin bir PDF '
                'sayfasındaki dar bir satıra sığacak; gereksiz uzatma.',
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
            Text('AI ile düzelt',
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
                for (final (label, prompt) in _presets)
                  ActionChip(
                    label: Text(label),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _instruction.text = prompt),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _instruction,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Örn. "daha kibar bir dille yaz"',
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
                  child: const Text('Vazgeç'),
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
                  label: Text(_busy ? 'Çalışıyor…' : 'Uygula'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
