import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../core/app_state.dart';
import '../services/conversion_service.dart';
import '../services/gemini_service.dart';
import '../widgets/pdf_save_dialog.dart';

/// **PDF'i AI'a düzenletme.**
///
/// Ne yapar: belgenin metin katmanı Gemini'ye verilir, kullanıcının verdiği
/// yönergeyle (düzelt / sadeleştir / özetle / resmîleştir / serbest metin)
/// yeniden yazılır, sonuç DÜZENLENEBİLİR olarak gösterilir ve istenirse
/// PDF'e basılır.
///
/// **Dürüst sınır — bilerek böyle:** üretilen PDF metin tabanlıdır, özgün
/// belgenin sayfa düzeni (sütun, tablo, logo, imza) KORUNMAZ. PDF'in içindeki
/// metni yerinde değiştirmek, yazı tipinin gömülü alt kümesini ve satır
/// kırımlarını yeniden kurmayı gerektirir; cihaz-içi/ücretsiz kalma ilkesiyle
/// (bkz. CLAUDE.md §1) makul bir sadakatte yapılamıyor. Bu yüzden varsayılan
/// kaydetme yolu **kopya**dır ve üzerine yazmak açıkça uyarır.
class PdfAiEditScreen extends StatefulWidget {
  const PdfAiEditScreen({
    super.key,
    required this.path,
    required this.fileName,
    required this.sourceText,
  });

  final String path;
  final String fileName;
  final String sourceText;

  /// Dosyanın üzerine yazıldıysa `true` döner (çağıran görüntüleyiciyi tazeler).
  static Future<bool?> open(
    BuildContext context, {
    required String path,
    required String fileName,
    required String sourceText,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PdfAiEditScreen(
          path: path,
          fileName: fileName,
          sourceText: sourceText,
        ),
      ),
    );
  }

  @override
  State<PdfAiEditScreen> createState() => _PdfAiEditScreenState();
}

/// Hazır yönergeler — en sık istenen dört düzenleme. Serbest metin de
/// yazılabilir. Çift: (etiket anahtarı, **AI'ya gidecek istem** anahtarı);
/// ikisi de arayüz diliyle çözülür, yoksa Arapça arayüzde Türkçe istem giderdi.
const _presets = <(String, String)>[
  ('pa.preset_grammar', 'pa.preset_grammar_prompt'),
  ('pa.preset_simplify', 'pa.preset_simplify_prompt'),
  ('pa.preset_summary', 'pa.preset_summary_prompt'),
  ('pa.preset_formal', 'pa.preset_formal_prompt'),
];

class _PdfAiEditScreenState extends State<PdfAiEditScreen> {
  final _instruction = TextEditingController();
  final _result = TextEditingController();
  final _conversion = ConversionService();

  bool _busy = false;
  String? _error;

  /// Kullanıcı sonucu elle değiştirdiyse "kaydet" anlamlı olur.
  bool get _hasResult => _result.text.trim().isNotEmpty;

  @override
  void dispose() {
    _instruction.dispose();
    _result.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    if (!state.hasApiKey) {
      setState(() => _error = context.t('pa.need_key'));
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
    final prompt = context.t('pa.prompt', {'task': task});
    try {
      final gemini =
          state.gemini;
      final answer = await gemini.chat(
        history: [
          ChatTurn(
            fromUser: true,
            text: prompt,
          ),
        ],
        fileContext: widget.sourceText,
      );
      if (!mounted) return;
      setState(() => _result.text = answer.trim());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final text = _result.text.trim();
    if (text.isEmpty) return;
    // Not await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final note = context.t('pa.save_note');
    setState(() => _busy = true);
    try {
      final bytes = await _conversion.textToPdf(widget.fileName, text);
      if (!mounted) return;
      setState(() => _busy = false);
      final outcome = await savePdfWithChoice(
        context,
        originalPath: widget.path,
        bytes: bytes,
        note: note,
      );
      if (outcome == null || !mounted) return;
      Navigator.of(context).pop(outcome.overwritten);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Kaydedilemedi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('vw.ai_edit')),
        actions: [
          IconButton(
            tooltip: context.t('pa.save_pdf'),
            icon: const Icon(Icons.save_outlined),
            onPressed: _hasResult && !_busy ? _save : null,
          ),
        ],
      ),
      body: widget.sourceText.trim().isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.t('pa.no_text'),
                    textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(context.t('pa.what'),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
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
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: context.t('pa.hint'),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _run,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high),
                  label: Text(
                      context.t(_busy ? 'pa.working' : 'vw.ai_edit')),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(context.t('pa.result'),
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    if (_hasResult)
                      Text(context.t('pa.editable'),
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _result,
                  minLines: 10,
                  maxLines: 30,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: context.t('pa.result_hint'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(context.t('pa.footer'),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
    );
  }
}
