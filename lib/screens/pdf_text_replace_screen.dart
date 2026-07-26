import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../services/gemini_service.dart';
import '../services/pdf_content_editor.dart';
import '../services/pdf_tools.dart';
import '../widgets/pdf_save_dialog.dart';

/// **Seçili metni değiştirme** (elle ya da AI ile) — Word'deki gibi silip
/// yeniden yazma.
///
/// İki yol var, sırayla denenir:
///
/// 1. **Yerinde düzenleme** ([PdfContentEditor]) — asıl yol. Sayfanın içerik
///    akışındaki metin operatörünün dizesi değiştirilir: yazı tipi, punto,
///    konum, renk aynen kalır, eski metin GERÇEKTEN silinir ve belge yapısı
///    korunur (değişiklik dosyanın sonuna ekleme olarak yazılır).
/// 2. **Üstünü kapatma** ([PdfTools.replaceText]) — yalnız 1. yol reddedilirse
///    ve kullanıcı onaylarsa. Eski yazının üstü boyanır, yenisi üste çizilir.
///    Bedeli açıkça söylenir: yazı tipi gömülü Carlito olur, arka plan düz renk
///    varsayılır ve eski metin belgede aranabilir hâlde kalır.
///
/// `PdfAiEditScreen`'den farkı: orası belgenin TAMAMINI yeniden yazıp düz metin
/// PDF'i üretir, sayfa düzeni kaybolur. Burada sayfanın geri kalanına hiç
/// dokunulmaz.
class PdfTextReplaceScreen extends StatefulWidget {
  const PdfTextReplaceScreen({
    super.key,
    required this.path,
    required this.pageIndex,
    required this.rawRects,
    required this.originalText,
    this.precedingText = '',
  });

  final String path;

  /// 0-tabanlı sayfa.
  final int pageIndex;

  /// Değiştirilecek satırlar: her biri `[left, top, right, bottom]` (PDF uzayı).
  final List<List<double>> rawRects;

  final String originalText;

  /// Seçimden hemen önceki metin — aynı kelime sayfada birkaç kez geçtiğinde
  /// doğru geçişin bulunmasını sağlar.
  final String precedingText;

  /// Dosyanın üzerine yazıldıysa `true` döner.
  static Future<bool?> open(
    BuildContext context, {
    required String path,
    required int pageIndex,
    required List<List<double>> rawRects,
    required String originalText,
    String precedingText = '',
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PdfTextReplaceScreen(
          path: path,
          pageIndex: pageIndex,
          rawRects: rawRects,
          originalText: originalText,
          precedingText: precedingText,
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

  /// Uzunluk farkı uyarısı (yoksa null).
  ///
  /// PDF metni Word gibi yeniden AKITMAZ: yeni metin uzunsa satırın kalanı
  /// sağa kayar, kısaysa boşluk kalır. Kullanıcı bunu kaydetmeden önce bilmeli
  /// — özellikle iki yana yaslı resmî yazılarda göze çarpar.
  String? get _lengthWarning {
    final oldLength = widget.originalText.trim().length;
    final newLength = _text.text.trim().length;
    if (oldLength == 0 || newLength == oldLength) return null;
    final diff = newLength - oldLength;
    // Birkaç karakterlik fark göze çarpmaz; gürültü yapmayalım.
    if (diff.abs() <= 2) return null;
    return diff > 0
        ? 'Yeni metin $diff karakter daha uzun: satırın kalanı sağa kayar '
            '(PDF metni yeniden akıtmaz).'
        : 'Yeni metin ${-diff} karakter daha kısa: satırın sonunda boşluk kalır.';
  }

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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await File(widget.path).readAsBytes();
      List<int> out;
      var inPlace = true;
      try {
        // 1. yol: belgenin kendi metnini değiştir (yapı korunur).
        out = await PdfContentEditor.replaceTextInBackground(
          bytes,
          pageIndex: widget.pageIndex,
          oldText: widget.originalText,
          newText: newText,
          precedingText: widget.precedingText,
        );
      } on PdfEditRefused catch (refusal) {
        if (!mounted) return;
        setState(() => _busy = false);
        final useOverlay = await _askOverlayFallback(refusal.message);
        if (useOverlay != true || !mounted) return;
        setState(() => _busy = true);
        inPlace = false;
        out = await _overlayReplace(bytes, newText);
      }

      // Kaydetme SORUSU en sona bırakıldı: değişiklik gerçekten üretilmeden
      // "nasıl kaydedelim?" diye sormak, sonra da başarısız olmak kötü olurdu.
      if (!mounted) return;
      setState(() => _busy = false);
      final outcome = await savePdfWithChoice(
        context,
        originalPath: widget.path,
        bytes: out,
        note: inPlace
            ? 'Yalnız seçtiğiniz metin değişti; sayfanın geri kalanına '
                'dokunulmadı.'
            : 'Metin ÜSTE yazıldı (yerinde düzenleme yapılamadı).',
      );
      if (outcome == null || !mounted) return;
      Navigator.of(context).pop(outcome.overwritten);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Değiştirilemedi: $e';
      });
    }
  }

  /// Yedek yol: eski yazının üstünü kapatıp yenisini çiz.
  Future<List<int>> _overlayReplace(List<int> bytes, String newText) async {
    // Türkçe çizebilen gömülü font — standart Helvetica ğ/ş/ı çizemez.
    final font = (await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
        .buffer
        .asUint8List();
    return PdfTools.replaceTextInBackground(
      bytes,
      pageIndex: widget.pageIndex,
      rawRects: widget.rawRects,
      newText: newText,
      fontBytes: font,
    );
  }

  /// Yerinde düzenleme reddedilince: bedelini SÖYLEYEREK yedek yolu öner.
  ///
  /// Sessizce üste yazmak yanlış olurdu — kullanıcı belgesinin gerçekten
  /// düzenlendiğini sanır, oysa eski metin içeride kalmış olur (kopyalayınca
  /// ya da arayınca ortaya çıkar).
  Future<bool?> _askOverlayFallback(String reason) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yerinde düzenleme yapılamadı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            const SizedBox(height: 12),
            const Text(
              'Bunun yerine eski yazının ÜSTÜ kapatılıp yenisi çizilebilir. '
              'Bu durumda:\n'
              '• yazı tipi belgenin kendi fontu olmaz,\n'
              '• iki yana yaslı metinde satır hizası bozulur,\n'
              '• arka plan düz renk varsayılır (desenli zeminde kutu görünür),\n'
              '• eski metin belgenin içinde aranabilir hâlde KALIR.\n\n'
              'Kısacası görüntü bozulabilir. Belgeyi korumak istiyorsanız '
              '"Vazgeç" deyip kaydederken "Kopyasını kaydet"i seçin.',
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Üste yaz')),
        ],
      ),
    );
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
          // Uzunluk uyarısı: PDF metni yeniden akıtmaz, satırın kalanı kayar.
          // Kullanıcı bunu KAYDETMEDEN önce bilsin.
          if (_lengthWarning != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_lengthWarning!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ],
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
            'Nasıl çalışır: belgenin kendi metni değiştirilir — yazı tipi, '
            'punto, konum ve sayfa yapısı olduğu gibi kalır, eski yazı gerçekten '
            'silinir. Değişiklik dosyanın sonuna eklenir, özgün içeriğe '
            'dokunulmaz.\n\n'
            'Bazı belgelerde bu mümkün olmaz (taranmış sayfa, alışılmadık '
            'kodlamayla gömülü yazı tipi, şifreli belge). O zaman sebebi '
            'söylenir ve isterseniz "üste yazma" yolu önerilir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
