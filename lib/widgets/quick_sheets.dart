import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../services/gemini_service.dart';
import '../services/lang_detect.dart';
import '../services/translate_service.dart';
import 'markdown_text.dart';
import 'translate_flow.dart';

/// Belgenin üstünde açılan **kısa, yüzen kart** — hızlı çeviri ve "AI'ya
/// sor" ortak kabı.
///
/// Kullanıcı (2026-09-27): *"kısa çeviriler için ayrı bir sayfa açmadan sayfa
/// içindeki bir popup gibi bir şeyde çeviri gösterilebilir; her seferinde
/// çeviri yapabilmek için 3 sayfa değişiyor."* Eski akış: dil penceresi →
/// ilerleme penceresi → sonuç sayfası. Şimdi tek kart: dil kendiliğinden
/// bulunur, çeviri kartın içinde belirir; belge arkada görünür kalır.
Future<void> _showCard(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    // Hafif perde: belge arkada okunur kalsın.
    barrierColor: Colors.black.withValues(alpha: 0.12),
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            10, 0, 10, 10 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.62,
            ),
            child: Material(
              color: Theme.of(ctx).colorScheme.surfaceContainerLow,
              elevation: 6,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Kartın başlığı: renkli rozet + başlık + kapat.
class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

// ── Hızlı çeviri ────────────────────────────────────────────────────────────

/// Seçili (kısa) metnin **yerinde** çevirisi.
abstract final class QuickTranslateSheet {
  /// Uzun metin (belgenin tamamı gibi) için eski tam akış daha uygun; kart
  /// yalnız seçimler içindir.
  static const maxChars = 4000;

  static Future<void> show(BuildContext context, String text, {String? title}) {
    final source = text.trim();
    if (source.length > maxChars) {
      return TranslateFlow.run(context, source, title: title);
    }
    return _showCard(context, _QuickTranslate(text: source, title: title));
  }
}

class _QuickTranslate extends StatefulWidget {
  final String text;
  final String? title;

  const _QuickTranslate({required this.text, this.title});

  @override
  State<_QuickTranslate> createState() => _QuickTranslateState();
}

class _QuickTranslateState extends State<_QuickTranslate> {
  TranslateLanguage? _from;
  TranslateLanguage? _to;

  /// Kaynak dil metinden mi bulundu (etikette "otomatik" yazar)?
  bool _auto = false;
  String? _result;
  String? _error;
  String? _status;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final pair = await TranslateService.lastPair();
    final detected = LangDetect.detect(widget.text);
    var from = detected ?? pair.$1;
    var to = pair.$2;
    // Metin zaten hedef dilde: kullanıcı büyük olasılıkla ÖTEKİ yöne çevirmek
    // istiyor (Türkçe okurken Türkçe'ye çevir anlamsız).
    if (from == to) to = pair.$1 == from ? TranslateLanguage.english : pair.$1;
    if (from == to) to = TranslateLanguage.turkish;
    if (!mounted) return;
    setState(() {
      _from = from;
      _to = to;
      _auto = detected != null;
    });
    await _translate();
  }

  Future<void> _translate() async {
    final from = _from, to = _to;
    if (from == null || to == null) return;
    final run = ++_run;
    final str = AppStrings.of(context);
    setState(() {
      _result = null;
      _error = null;
      _status = str.t('tf.working');
    });
    try {
      for (final lang in {from, to}) {
        if (!await TranslateService.isModelReady(lang)) {
          if (mounted && run == _run) {
            setState(() => _status = str.t('tf.downloading', {
                  'lang': TranslateService.languages[lang],
                }));
          }
          await TranslateService.downloadModel(lang);
        }
      }
      final out =
          await TranslateService.translate(widget.text, from: from, to: to);
      if (!mounted || run != _run) return;
      setState(() {
        _result = out;
        _status = null;
      });
      await TranslateService.savePair(from, to);
    } catch (e) {
      if (!mounted || run != _run) return;
      setState(() {
        _error = str.t('tf.failed', {'error': e});
        _status = null;
      });
    }
  }

  Widget _langButton(TranslateLanguage? value, {required bool source}) {
    final scheme = Theme.of(context).colorScheme;
    final name = value == null ? '…' : TranslateService.languages[value] ?? '';
    final label =
        source && _auto ? '$name · ${context.t('tf.auto_short')}' : name;
    return PopupMenuButton<TranslateLanguage>(
      tooltip: context.t(source ? 'tf.source_lang' : 'tf.target_lang'),
      onSelected: (v) {
        setState(() {
          if (source) {
            _from = v;
            _auto = false;
            if (_to == v) _to = null;
          } else {
            _to = v;
            if (_from == v) _from = null;
          }
          _from ??= TranslateLanguage.english;
          _to ??= TranslateLanguage.turkish;
        });
        _translate();
      },
      itemBuilder: (_) => [
        for (final e in TranslateService.languages.entries)
          CheckedPopupMenuItem(
              value: e.key, checked: e.key == value, child: Text(e.value)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final result = _result;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardHeader(
          icon: Icons.translate_rounded,
          title: widget.title ?? context.t('tf.title'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Flexible(child: _langButton(_from, source: true)),
              IconButton(
                tooltip: context.t('tf.swap'),
                onPressed: _from == null || _to == null
                    ? null
                    : () {
                        setState(() {
                          final t = _from;
                          _from = _to;
                          _to = t;
                          _auto = false;
                        });
                        _translate();
                      },
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
              Flexible(child: _langButton(_to, source: false)),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                ),
                const SizedBox(height: 10),
                if (_status != null)
                  Row(
                    children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_status!, style: text.bodyMedium)),
                    ],
                  ),
                if (_error != null)
                  Text(_error!,
                      style: text.bodyMedium?.copyWith(color: scheme.error)),
                if (result != null)
                  SelectableText(result,
                      style: text.bodyLarge?.copyWith(height: 1.45)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: result == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: result));
                        if (context.mounted) Navigator.maybePop(context);
                      },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(context.t('common.copy')),
              ),
              TextButton.icon(
                onPressed: result == null ? null : () => Share.share(result),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(context.t('common.share')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── AI'ya sor ───────────────────────────────────────────────────────────────

/// Seçili metin hakkında **yerinde** AI yanıtı: açıkla, özetle, basitleştir,
/// ya da serbest soru. Belgenin kalanı bağlam olarak gider (kısaltılmış).
abstract final class QuickAiSheet {
  static Future<void> show(
    BuildContext context, {
    required String selection,
    String documentName = '',
    String documentText = '',
  }) =>
      _showCard(
        context,
        _QuickAi(
          selection: selection,
          documentName: documentName,
          documentText: documentText,
        ),
      );
}

class _QuickAi extends StatefulWidget {
  final String selection;
  final String documentName;
  final String documentText;

  const _QuickAi({
    required this.selection,
    required this.documentName,
    required this.documentText,
  });

  @override
  State<_QuickAi> createState() => _QuickAiState();
}

class _QuickAiState extends State<_QuickAi> {
  final _question = TextEditingController();
  String? _answer;
  String? _error;
  bool _busy = false;
  String? _activeKey;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask(String instruction, {String? key}) async {
    final state = context.read<AppState>();
    final str = AppStrings.of(context);
    if (!state.hasApiKey) {
      setState(() => _error = str.t('chat.key_required_body'));
      return;
    }
    setState(() {
      _busy = true;
      _answer = null;
      _error = null;
      _activeKey = key;
    });
    // Yanıt dili ARAYÜZ dili: sohbetin sistem istemi Türkçe'ye sabitti.
    final lang = str.t('ai.answer_language');
    final prompt = '$instruction\n\n'
        '${str.t('ai.reply_in', {'lang': lang})}\n\n'
        '«${widget.selection}»';
    final ctxText = widget.documentText.trim().isEmpty
        ? null
        : '${widget.documentName}\n${widget.documentText}';
    try {
      final reply = await state.gemini.chat(
        history: [ChatTurn(fromUser: true, text: prompt)],
        fileContext: ctxText,
      );
      if (!mounted) return;
      setState(() => _answer = reply);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final presets = <(String, IconData, String, String)>[
      (
        'explain',
        Icons.lightbulb_outline_rounded,
        context.t('ai.q_explain'),
        context.t('ai.q_explain_prompt'),
      ),
      (
        'simplify',
        Icons.child_care_rounded,
        context.t('ai.q_simplify'),
        context.t('ai.q_simplify_prompt'),
      ),
      (
        'summary',
        Icons.short_text_rounded,
        context.t('ai.q_summary'),
        context.t('ai.q_summary_prompt'),
      ),
      (
        'terms',
        Icons.menu_book_rounded,
        context.t('ai.q_terms'),
        context.t('ai.q_terms_prompt'),
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardHeader(
          icon: Icons.auto_awesome_rounded,
          title: context.t('vw.ask_ai_selection'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '“${widget.selection}”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final (key, icon, label, prompt) in presets)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    selected: _activeKey == key,
                    onSelected: _busy ? null : (_) => _ask(prompt, key: key),
                  ),
                ),
            ],
          ),
        ),
        Flexible(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: _busy
                  ? Row(
                      children: [
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text(context.t('ai.thinking')),
                      ],
                    )
                  : _error != null
                      ? Text(_error!,
                          style: text.bodyMedium?.copyWith(color: scheme.error))
                      : _answer != null
                          ? SelectionArea(child: MarkdownText(_answer!))
                          : const SizedBox.shrink(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _question,
                  enabled: !_busy,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (q) {
                    if (q.trim().isNotEmpty) _ask(q.trim());
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: context.t('ai.ask_about_hint'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: context.t('common.send'),
                onPressed: _busy
                    ? null
                    : () {
                        final q = _question.text.trim();
                        if (q.isNotEmpty) _ask(q);
                      },
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              if (_answer != null)
                IconButton(
                  tooltip: context.t('common.copy'),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: _answer!)),
                  icon: const Icon(Icons.copy_rounded),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
