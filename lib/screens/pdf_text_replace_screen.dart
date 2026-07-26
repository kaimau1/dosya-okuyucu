import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../services/gemini_service.dart';
import '../services/pdf_save.dart';
import '../services/pdf_tools.dart';
import '../widgets/pdf_save_dialog.dart';

/// **Seçili metni yerinde değiştirme** (elle ya da AI ile).
///
/// `PdfAiEditScreen`'den farkı ve varlık sebebi: orası belgenin TAMAMINI yeniden
/// yazıp düz metin PDF'i üretir, sayfa düzeni kaybolur. Burada yalnız seçilen
/// satırların üstü kapatılıp yerine yeni metin yazılır — **sayfanın geri kalanı
/// (tablo, logo, sütunlar, diğer paragraflar) olduğu gibi kalır.** Kullanıcının
/// "PDF'i AI'a düzenlettirme" isteğinin düzeni koruyan hâli budur.
///
/// Sınırlar ekranda da yazılı: gömülü Carlito kullanılır (PDF'in kendi fontu
/// genelde alt küme olarak gömülüdür, yeni harfler için glifi yoktur) ve arka
/// plan düz renk varsayılır.
class PdfTextReplaceScreen extends StatefulWidget {
  const PdfTextReplaceScreen({
    super.key,
    required this.path,
    required this.pageIndex,
    required this.rawRects,
    required this.originalText,
  });

  final String path;

  /// 0-tabanlı sayfa.
  final int pageIndex;

  /// Değiştirilecek satırlar: her biri `[left, top, right, bottom]` (PDF uzayı).
  final List<List<double>> rawRects;

  final String originalText;

  /// Dosyanın üzerine yazıldıysa `true` döner.
  static Future<bool?> open(
    BuildContext context, {
    required String path,
    required int pageIndex,
    required List<List<double>> rawRects,
    required String originalText,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PdfTextReplaceScreen(
          path: path,
          pageIndex: pageIndex,
          rawRects: rawRects,
          originalText: originalText,
        ),
      ),
    );
  }

  @override
  State<PdfTextReplaceScreen> createState() => _PdfTextReplaceScreenState();
}

/// Seçili parça üzerinde en sık istenen düzeltmeler.
const _presets = <(String, String)>[
  ('Yazımı düzelt', 'Bu metindeki yazım ve dil bilgisi hatalarını düzelt. '
      'Anlamı ve üslubu koru, uzunluğu mümkün olduğunca aynı tut.'),
  ('Kısalt', 'Bu metni anlamını kaybetmeden belirgin biçimde kısalt.'),
  ('Sadeleştir', 'Bu metni daha anlaşılır ve sade bir dille yeniden yaz.'),
  ('Resmîleştir', 'Bu metni resmî yazışma diline uygun hâle getir.'),
];

class _PdfTextReplaceScreenState extends State<PdfTextReplaceScreen> {
  late final TextEditingController _text =
      TextEditingController(text: widget.originalText);
  final _instruction = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _instruction.dispose();
    super.dispose();
  }

  bool get _changed => _text.text.trim() != widget.originalText.trim();

  Future<void> _runAi() async {
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
                'Metin:\n"""\n${_text.text}\n"""\n\n'
                'ÇOK ÖNEMLİ: yalnızca yeni metni döndür. Açıklama, tırnak, '
                'giriş cümlesi ya da kod bloğu işareti EKLEME. Metin bir PDF '
                'sayfasındaki dar bir kutuya sığacak; gereksiz uzatma.',
          ),
        ],
      );
      if (!mounted) return;
      setState(() => _text.text = answer.trim());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final newText = _text.text.trim();
    if (newText.isEmpty) {
      setState(() => _error = 'Yeni metin boş olamaz.');
      return;
    }
    final mode = await askPdfSaveMode(
      context,
      path: widget.path,
      note: 'Yalnız seçtiğiniz satırlar değişir; sayfanın geri kalanına '
          'dokunulmaz.',
    );
    if (mode == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Türkçe çizebilen gömülü font — standart Helvetica ğ/ş/ı çizemez.
      final font =
          (await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
              .buffer
              .asUint8List();
      final bytes = await File(widget.path).readAsBytes();
      final out = await PdfTools.replaceTextInBackground(
        bytes,
        pageIndex: widget.pageIndex,
        rawRects: widget.rawRects,
        newText: newText,
        fontBytes: font,
      );
      final written = await PdfSave.write(widget.path, out, mode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mode == PdfSaveMode.overwrite
            ? 'Metin değiştirildi'
            : 'Değişiklik kopyaya kaydedildi: ${written.split('/').last}'),
      ));
      Navigator.of(context).pop(mode == PdfSaveMode.overwrite);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Değiştirilemedi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metni düzenle'),
        actions: [
          IconButton(
            tooltip: 'Uygula',
            icon: const Icon(Icons.check),
            onPressed: _busy || !_changed ? null : _apply,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Özgün metin', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(widget.originalText,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 16),
          Text('Yeni metin', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 12,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text('AI ile düzelt (isteğe bağlı)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (label, prompt) in _presets)
                ActionChip(
                  label: Text(label),
                  onPressed:
                      _busy ? null : () => setState(() => _instruction.text = prompt),
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _runAi,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_fix_high),
            label: Text(_busy ? 'Çalışıyor…' : 'AI ile düzelt'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          Text(
            'Nasıl çalışır: seçtiğiniz satırların üstü beyazla kapatılır ve yeni '
            'metin aynı kutuya yazılır. Sayfanın geri kalanı değişmez.\n\n'
            'Sınırlar: yazı tipi belgenin kendi fontu değil, gömülü Carlito '
            'olur (PDF fontları genelde yalnız kullanılan harfleri içerir). '
            'Arka plan düz renk varsayılır — desenli/renkli zeminde kapatma '
            'kutusu görünebilir. Yeni metin uzunsa punto küçültülür.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
