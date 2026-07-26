import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

/// Hazır yönergeler — en sık istenen dört düzenleme. Serbest metin de yazılabilir.
const _presets = <(String, String)>[
  ('Yazım/dil bilgisi düzelt', 'Metindeki yazım ve dil bilgisi hatalarını '
      'düzelt. Anlamı ve üslubu değiştirme, cümleleri yeniden kurma.'),
  ('Sadeleştir', 'Metni daha kısa ve anlaşılır hâle getir. Bilgi kaybetme, '
      'gereksiz tekrarları ve dolgu ifadeleri at.'),
  ('Özetle', 'Metni ana başlıklar ve maddeler hâlinde özetle.'),
  ('Resmî dile çevir', 'Metni resmî yazışma diline uygun hâle getir.'),
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
      final gemini =
          GeminiService(apiKey: state.apiKey, model: state.model);
      final answer = await gemini.chat(
        history: [
          ChatTurn(
            fromUser: true,
            text: 'Aşağıdaki belgenin metnini şu yönergeye göre yeniden yaz:\n'
                '"$task"\n\n'
                'ÇOK ÖNEMLİ: yalnızca düzenlenmiş metni döndür. Açıklama, '
                'giriş cümlesi, "işte metin" gibi ifadeler ve kod bloğu '
                'işaretleri EKLEME.',
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
    setState(() => _busy = true);
    try {
      final bytes = await _conversion.textToPdf(widget.fileName, text);
      if (!mounted) return;
      setState(() => _busy = false);
      final outcome = await savePdfWithChoice(
        context,
        originalPath: widget.path,
        bytes: bytes,
        note: 'Yeni PDF düz metinden üretilir: özgün belgenin sayfa düzeni '
            '(sütun, tablo, logo, imza) KORUNMAZ.',
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
        title: const Text('AI ile düzenle'),
        actions: [
          IconButton(
            tooltip: 'PDF olarak kaydet',
            icon: const Icon(Icons.save_outlined),
            onPressed: _hasResult && !_busy ? _save : null,
          ),
        ],
      ),
      body: widget.sourceText.trim().isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu belgede okunabilir metin yok (taranmış olabilir).\n'
                  'Önce ⋮ menüsünden "Metni tanı (OCR)" çalıştırın.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text('Ne yapılsın?',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
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
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Örn. "Başlıkları numaralandır ve maddeleri kısalt"',
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
                  label: Text(_busy ? 'Çalışıyor…' : 'AI ile düzenle'),
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
                    Text('Sonuç',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    if (_hasResult)
                      Text('elle düzenlenebilir',
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _result,
                  minLines: 10,
                  maxLines: 30,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'AI çıktısı burada görünecek…',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kaydederken üretilen PDF düz metindir: özgün sayfa düzeni '
                  '(sütun, tablo, logo) korunmaz. Özgün belgeyi bozmamak için '
                  '"Kopyasını kaydet"i seçin.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
