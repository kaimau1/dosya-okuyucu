import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../models/fs_entry.dart';
import '../../services/ai_pool.dart';
import '../../services/fm/doc_classifier.dart';
import '../../services/fm/image_resize.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/gemini_decisions.dart';
import '../../services/ocr_service.dart';
import '../../services/offline_mode.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/smart_cat_style.dart';
import 'ai_actions.dart' show fileIntoSuggestedFolder;

/// AI'nın görsel için kısa açıklaması.
class ImageInsight {
  /// Kısa tür ("Uygulama ekran görüntüsü", "Elektrik faturası").
  final String kind;

  /// Bir-iki cümle: görselde ne var, ne işe yarar.
  final String summary;

  /// En çok dört kısa ayrıntı (tutar, tarih, başlık…).
  final List<String> points;

  /// Ekran görüntüsüyse uygulama / site adı.
  final String app;

  const ImageInsight({
    required this.kind,
    required this.summary,
    this.points = const [],
    this.app = '',
  });

  /// Saf: model yanıtı → açıklama (bozuk/boşsa null). Birim testli.
  static ImageInsight? parse(String raw) {
    Object? data;
    try {
      var body = raw.trim();
      if (body.startsWith('```')) {
        body = body
            .replaceFirst(RegExp(r'^```[a-zA-Z]*'), '')
            .replaceFirst(RegExp(r'```$'), '')
            .trim();
      }
      data = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (data is! Map) return null;
    String str(Object? v) => v is String ? v.trim() : '';
    final summary = str(data['summary']);
    if (summary.isEmpty) return null;
    final points = data['points'];
    return ImageInsight(
      kind: str(data['kind']),
      summary: summary,
      app: str(data['app']),
      points: [
        if (points is List)
          for (final p in points.take(4))
            if (str(p).isNotEmpty) str(p),
      ],
    );
  }
}

/// **"Görselde ne var?"** (2026-11-18, kullanıcı ekran görüntüsüyle: *"bu
/// şekilde çok anlamsız bir şey açıyor, daha düzgün olmalı; gerekirse küçük
/// AI özet olabilir — bir program arayüzü var gibi"*).
///
/// Eskiden düğme yalnız metin tanıyıp HAM satırları ("Q Ara ve Yardım",
/// "7.1 GE", "Dneml Desy"…) bir sayfaya döküyordu; başlık da "Bu bir ekran
/// görüntüsü gibi görünüyor" + "İpuçları: dosya adı" idi. Artık:
/// * **AI kısa özeti** (anahtar varsa, AI kapsamı izin veriyorsa, çevrimiçiyse
///   kendiliğinden): tür + bir-iki cümle + en çok dört ayrıntı. Görsel küçük
///   önizleme olarak gider (1280 px), kişisel veri istemde dışlanır.
///   Anahtar yoksa "AI ile kısa özet" düğmesi; bu oturumda aynı dosya yeniden
///   sorulmaz.
/// * **Tür** çipleri: Akıllı düzen kategorisi + cihazdaki sınıflandırma.
/// * **Görseldeki yazı** katlanır bölümde (kopyala / paylaş) — artık ana içerik
///   değil, isteyen açar.
/// * Cihazdaki tahmin güvenliyse "… klasörüne taşı" önerisi (eskisi gibi).
Future<void> showImageInsightSheet(BuildContext context, FsEntry entry) =>
    showAppSheet<void>(
      context,
      scrollable: false,
      builder: (_) => ImageInsightSheet(entry: entry),
    );

enum _AiState { idle, loading, done, needKey, blocked, offline, error }

class ImageInsightSheet extends StatefulWidget {
  final FsEntry entry;

  /// Testler için: AI ve metin tanıma yerine verilen sonuçlar.
  @visibleForTesting
  final ImageInsight? insightForTest;
  @visibleForTesting
  final String? textForTest;

  const ImageInsightSheet({
    super.key,
    required this.entry,
    this.insightForTest,
    this.textForTest,
  });

  @override
  State<ImageInsightSheet> createState() => _ImageInsightSheetState();
}

class _ImageInsightSheetState extends State<ImageInsightSheet> {
  /// Oturum önbelleği: aynı dosya (yol + değişme zamanı + dil) yeniden
  /// sorulmaz.
  static final Map<String, ImageInsight> _cache = {};

  String? _text;
  String? _ocrError;
  ImageInsight? _ai;
  _AiState _aiState = _AiState.idle;
  String? _aiError;

  String get _cacheKey =>
      '${widget.entry.path}|${widget.entry.modifiedMs}|'
      '${AppStrings.current.language.name}';

  @override
  void initState() {
    super.initState();
    if (widget.textForTest != null || widget.insightForTest != null) {
      _text = widget.textForTest ?? '';
      _ai = widget.insightForTest;
      _aiState = _ai != null ? _AiState.done : _AiState.needKey;
      return;
    }
    unawaited(_readText());
    final cached = _cache[_cacheKey];
    if (cached != null) {
      _ai = cached;
      _aiState = _AiState.done;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runAi(auto: true));
      });
    }
  }

  Future<void> _readText() async {
    try {
      final t = await OcrService.recognizeImageFile(widget.entry.path,
          allowCloud: true);
      if (mounted) setState(() => _text = t.trim());
    } catch (e) {
      if (mounted) {
        setState(() {
          _text = '';
          _ocrError = userErrorText(e);
        });
      }
    }
  }

  static String _langName(AppLanguage l) => switch (l) {
        AppLanguage.en => 'English',
        AppLanguage.ar => 'Arabic',
        _ => 'Turkish',
      };

  Future<void> _runAi({bool auto = false}) async {
    final state = context.read<AppState>();
    if (!state.aiScopeRules.allowsFile(widget.entry)) {
      setState(() => _aiState = _AiState.blocked);
      return;
    }
    if (OfflineMode.enabled) {
      setState(() => _aiState = _AiState.offline);
      return;
    }
    if (!state.hasApiKey) {
      if (auto) {
        setState(() => _aiState = _AiState.needKey);
        return;
      }
      if (!await ensureAiKey(context) || !mounted) return;
    }
    final lang = _langName(AppStrings.of(context).language);
    final key = _cacheKey;
    setState(() {
      _aiState = _AiState.loading;
      _aiError = null;
    });
    try {
      final image = await _imageBytes(widget.entry.path);
      final raw = await PooledGemini(state.aiCredentials).generateJsonFromImage(
        prompt: _prompt(lang),
        schema: _schema,
        image: image.bytes,
        mimeType: image.mime,
      );
      final insight = ImageInsight.parse(raw);
      if (insight == null) throw const FormatException('empty');
      _cache[key] = insight;
      if (mounted) {
        setState(() {
          _ai = insight;
          _aiState = _AiState.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiState = _AiState.error;
          _aiError = e is FormatException
              ? context.t('iin.ai_empty')
              : userErrorText(e);
        });
      }
    }
  }

  /// Küçük önizleme (JPEG, en uzun kenar 1280); çözülemezse dosyanın kendisi.
  static Future<({Uint8List bytes, String mime})> _imageBytes(
      String path) async {
    final preview = await ImageResizer.previewJpeg(path, maxEdge: 1280);
    if (preview != null) return (bytes: preview, mime: 'image/jpeg');
    final bytes = await File(path).readAsBytes();
    if (bytes.length > GeminiDecisions.maxInlineBytes) {
      throw StateError(AppStrings.current.t('qc.too_large'));
    }
    final m = GeminiDecisions.mediaFor(path);
    return (
      bytes: bytes,
      mime: m != null && m.type == 'image' ? m.mime : 'image/png',
    );
  }

  static String _prompt(String lang) =>
      'Look at this image and explain briefly what it is, for a phone user '
      'who wants to know what this file is without opening it. Write every '
      'text value in $lang. '
      'kind: a short label of what the image is (2-4 words, for example '
      '"App screenshot", "Electricity bill", "Chat screenshot", "Family '
      'photo"). '
      'summary: one or two short, plain sentences describing what is visible '
      'and what it is for; if it is a screenshot, say which app or website '
      'and which screen. '
      'points: up to 4 very short key facts that are visible (amounts, dates, '
      'titles, main numbers). Never include personal data such as ID '
      'numbers, phone numbers, e-mail or home addresses, card or account '
      'numbers. '
      'app: the app or website name if this is a screenshot, otherwise an '
      'empty string.';

  static const _schema = <String, Object?>{
    'type': 'OBJECT',
    'properties': {
      'kind': {'type': 'STRING'},
      'summary': {'type': 'STRING'},
      'points': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'app': {'type': 'STRING'},
    },
    'required': ['kind', 'summary'],
  };

  String _shareText() {
    final ai = _ai;
    return [
      if (ai != null) ...[
        if (ai.kind.isNotEmpty) ai.kind,
        ai.summary,
        for (final p in ai.points) '• $p',
      ],
      if ((_text ?? '').isNotEmpty) _text!,
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final text = _text;
    final guess = text == null || text.isEmpty
        ? null
        : classifyDocumentText(text, fileName: entry.name);
    final confident = guess != null && guess.isConfident ? guess : null;
    final smart = SmartSort.of(entry.path);
    final smartCat =
        smart != null && smart.cat != 'other' ? smart.cat : null;
    final title = (_ai?.kind ?? '').isNotEmpty
        ? _ai!.kind
        : smartCat != null
            ? SmartCatStyle.label(context, smartCat)
            : confident != null
                ? context.t(confident.type.labelKey)
                : context.t('ea.image_insight');
    final lines = text == null || text.isEmpty
        ? 0
        : text.split('\n').where((l) => l.trim().isNotEmpty).length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: SizedBox.square(
                  dimension: 48, child: FmEntryIcon(entry: entry, size: 48)),
              title: Text(title,
                  key: const ValueKey('iin-title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(entry.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: context.t('common.share'),
                icon: const Icon(AppIcons.share, size: 20),
                onPressed: _shareText().isEmpty
                    ? null
                    : () => SharePlus.instance.share(
                        ShareParams(text: _shareText(), subject: entry.name)),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _aiCard(context),
                    const SizedBox(height: Gap.sm),
                    Wrap(
                      spacing: Gap.xs,
                      runSpacing: Gap.xs,
                      children: [
                        if (smartCat != null)
                          Chip(
                            avatar: Icon(SmartCatStyle.icon(smartCat),
                                size: 18, color: SmartCatStyle.color(smartCat)),
                            label: Text(SmartCatStyle.label(context, smartCat)),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (confident != null &&
                            (smartCat == null ||
                                context.t(confident.type.labelKey) !=
                                    SmartCatStyle.label(context, smartCat)))
                          Chip(
                            avatar: const Icon(AppIcons.tag, size: 18),
                            label: Text(context.t(confident.type.labelKey)),
                            visualDensity: VisualDensity.compact,
                          ),
                        if ((_ai?.app ?? '').isNotEmpty)
                          Chip(
                            avatar: const Icon(AppIcons.phonelink, size: 18),
                            label: Text(_ai!.app),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (lines > 0)
                          Chip(
                            avatar: const Icon(AppIcons.textSnippet, size: 18),
                            label: Text(context.t('iin.lines', {'n': lines})),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.sm),
                    _textCard(context),
                  ],
                ),
              ),
            ),
            if (confident != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final ok = await fileIntoSuggestedFolder(
                        context, entry, confident.type);
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(AppIcons.move),
                  label: Text(context.t('aia.target_folder',
                      {'folder': confident.type.folder})),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _aiCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ai = _ai;
    late final Widget body;
    switch (_aiState) {
      case _AiState.idle || _AiState.loading:
        body = Row(children: [
          const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(context.t('iin.ai_working'))),
        ]);
      case _AiState.done when ai != null:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(ai.summary,
                key: const ValueKey('iin-summary'),
                style: theme.textTheme.bodyLarge),
            if (ai.points.isNotEmpty) const SizedBox(height: Gap.xs),
            for (final p in ai.points)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: theme.textTheme.bodyMedium),
                    Expanded(
                        child: Text(p, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        );
      case _AiState.needKey || _AiState.done:
        body = Row(children: [
          Expanded(child: Text(context.t('iin.ai_offer'))),
          TextButton(
            key: const ValueKey('iin-ai-run'),
            onPressed: () => unawaited(_runAi()),
            child: Text(context.t('iin.ai_run')),
          ),
        ]);
      case _AiState.blocked:
        body = Text(context.t('iin.ai_blocked'),
            style: theme.textTheme.bodySmall);
      case _AiState.offline:
        body = Text(context.t('iin.ai_offline'),
            style: theme.textTheme.bodySmall);
      case _AiState.error:
        body = Row(children: [
          Expanded(
            child: Text(_aiError ?? context.t('iin.ai_empty'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.error)),
          ),
          TextButton(
            onPressed: () => unawaited(_runAi()),
            child: Text(context.t('common.retry')),
          ),
        ]);
    }
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(AppIcons.ai, size: 18, color: scheme.primary),
              const SizedBox(width: Gap.xs),
              Text(context.t('iin.ai_title'),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.primary)),
            ]),
            const SizedBox(height: Gap.sm),
            body,
          ],
        ),
      ),
    );
  }

  Widget _textCard(BuildContext context) {
    final text = _text;
    if (text == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const SizedBox.square(
            dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text(context.t('aia.reading_image')),
      );
    }
    if (text.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIcons.textSnippet),
        title: Text(_ocrError != null
            ? context.t('aia.ocr_failed', {'error': _ocrError!})
            : context.t('aia.image_no_text')),
      );
    }
    final first = text.split('\n').firstWhere((l) => l.trim().isNotEmpty,
        orElse: () => '');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('iin-text'),
        leading: const Icon(AppIcons.textSnippet),
        title: Text(context.t('iin.text_title')),
        subtitle: Text(first, maxLines: 1, overflow: TextOverflow.ellipsis),
        childrenPadding:
            const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(AppIcons.clipCopy, size: 18),
                label: Text(context.t('common.copy')),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    showSnack(context, context.t('iin.copied'));
                  }
                },
              ),
              TextButton.icon(
                icon: const Icon(AppIcons.share, size: 18),
                label: Text(context.t('common.share')),
                onPressed: () => SharePlus.instance.share(
                    ShareParams(text: text, subject: widget.entry.name)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
