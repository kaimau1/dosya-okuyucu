import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../models/fs_entry.dart';
import '../../services/file_service.dart';
import '../../services/gemini_decisions.dart';
import '../../services/gemini_service.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/app_dialog.dart';

/// **AI ile hızlı kontrol** (2026-11-18) — Gemini Decisions API
/// ([GeminiDecisions]) ile dosyanın KENDİSİNE kapalı uçlu sorular: imzalı mı,
/// kişisel veri var mı, belge türü ne, okunaklı mı, kayıtta konuşma var mı…
/// Kullanıcı kendi evet/hayır sorularını da yazabilir (her satır bir soru).
///
/// Neden üretken model değil: yanıt serbest metin değil olasılık → uydurma
/// yok, saniyenin altında, çıktı belirteci ücretsiz. Ağ isteği yalnız
/// "Kontrol et"e basınca; AI kapsamı dışındaki dosya hiç gönderilmez.
Future<void> showAiQuickCheck(BuildContext context, FsEntry entry) async {
  if (entry.isDir) return;
  final state = context.read<AppState>();
  if (!state.aiScopeRules.allowsFile(entry)) {
    showSnack(context, context.t('qc.scope_off'));
    return;
  }
  if (!await ensureAiKey(context) || !context.mounted) return;
  await showAppSheet<void>(
    context,
    title: context.t('qc.title'),
    builder: (_) => _QuickCheckSheet(entry: entry),
  );
}

/// Dosya türüne göre hazır sorular. Talimatlar İngilizce (model en iyi orada
/// kalibre); kullanıcı yalnız [DecisionQuestion.label]'ı görür.
List<DecisionQuestion> quickCheckPresets(FmCategory category, AppStrings s) {
  final quality = DecisionQuestion.score(
    'quality',
    s.t('qc.q_quality'),
    'How legible and clear is this content overall?',
    const [
      'Poor: hard to read or understand, blurry, cut off or noisy.',
      'Acceptable: mostly readable with some problems.',
      'Good: clear, sharp and easy to read or understand.',
    ],
  );
  final pii = DecisionQuestion.yesNo(
    'pii',
    s.t('qc.q_pii'),
    'Does this content contain personal data such as a national ID number, '
        'phone number, home address, bank account / IBAN or health information?',
  );
  final textIn = DecisionQuestion.yesNo('text_in', s.t('qc.q_text_in'),
      'Is there readable written text visible in this content?');
  final people = DecisionQuestion.yesNo('people', s.t('qc.q_people'),
      'Are there one or more people visible?');
  final speech = DecisionQuestion.yesNo('speech', s.t('qc.q_speech'),
      'Does the recording contain human speech?');
  final type = DecisionQuestion.choice(
    'doc_type',
    s.t('qc.q_type'),
    'What kind of document or content is this?',
    const {
      'invoice': 'An invoice, bill or receipt.',
      'contract': 'A contract, agreement or legal document.',
      'id': 'An identity document, passport, license or card.',
      'bank': 'A bank statement, transfer receipt or financial record.',
      'health': 'A medical report, prescription or health record.',
      'official': 'An official letter or government / institutional document.',
      'cv': 'A CV or résumé.',
      'study': 'Lecture notes, a book, an article or study material.',
      'presentation': 'A presentation or slides.',
      'screenshot': 'A screenshot of a phone or computer screen.',
      'photo': 'A personal photo with no document in it.',
      'other': 'Something else.',
    },
  );
  return switch (category) {
    FmCategory.image => [
        type,
        DecisionQuestion.yesNo('screenshot', s.t('qc.q_screenshot'),
            'Is this image a screenshot of a phone or computer screen?'),
        textIn,
        pii,
        people,
        quality,
      ],
    FmCategory.audio => [
        speech,
        pii,
        DecisionQuestion.score(
          'audio_quality',
          s.t('qc.q_audio_quality'),
          'How clear is the audio quality?',
          const [
            'Poor: noisy, distorted or hard to follow.',
            'Acceptable: understandable with some noise.',
            'Good: clean and easy to follow.',
          ],
        ),
      ],
    FmCategory.video => [speech, people, textIn, quality],
    _ => [
        type,
        DecisionQuestion.yesNo('signed', s.t('qc.q_signed'),
            'Does this document carry a handwritten or digital signature?'),
        pii,
        DecisionQuestion.yesNo('money', s.t('qc.q_money'),
            'Does this document state an amount of money, price or payment?'),
        DecisionQuestion.yesNo('deadline', s.t('qc.q_deadline'),
            'Does this document state a deadline, due date or expiry date?'),
        quality,
      ],
  };
}

/// Çevirisi olan belge türü seçenekleri (`qc.t_<kimlik>`).
const _typeIds = {
  'invoice', 'contract', 'id', 'bank', 'health', 'official', 'cv', 'study',
  'presentation', 'screenshot', 'photo', 'other',
};

class _QuickCheckSheet extends StatefulWidget {
  final FsEntry entry;

  const _QuickCheckSheet({required this.entry});

  @override
  State<_QuickCheckSheet> createState() => _QuickCheckSheetState();
}

class _QuickCheckSheetState extends State<_QuickCheckSheet> {
  late final List<DecisionQuestion> _presets =
      quickCheckPresets(widget.entry.category, AppStrings.of(context));
  late final Set<String> _on = {for (final q in _presets) q.id};
  final _custom = TextEditingController();
  bool _busy = false;
  DecisionResult? _result;
  String? _error;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  List<DecisionQuestion> _questions() {
    final lines = _custom.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(10)
        .toList();
    return [
      for (final q in _presets)
        if (_on.contains(q.id)) q,
      for (var i = 0; i < lines.length; i++)
        DecisionQuestion.yesNo('custom_$i', lines[i], lines[i]),
    ];
  }

  /// Dosya → girdi bloğu: PDF/görsel/ses/video olduğu gibi; ötekiler (Word,
  /// metin, tablo…) okunan düz yazıyla.
  Future<List<Map<String, Object?>>> _input(AppStrings s) async {
    final path = widget.entry.path;
    if (GeminiDecisions.mediaFor(path) != null) {
      return [
        await GeminiDecisions.fileBlock(path,
            tooLarge: s.t('qc.too_large'), unsupported: s.t('qc.unsupported'))
      ];
    }
    final text = (await FileService().load(path)).plainText.trim();
    if (text.isEmpty) {
      throw GeminiException(s.t('qc.unsupported'), statusCode: -1);
    }
    return [
      GeminiDecisions.textBlock(
          text.length > 60000 ? text.substring(0, 60000) : text)
    ];
  }

  Future<void> _run() async {
    final s = AppStrings.of(context);
    final questions = _questions();
    if (questions.isEmpty) {
      showSnack(context, s.t('qc.none_selected'));
      return;
    }
    final keys = context.read<AppState>().aiCredentials.normalized.keys;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final input = await _input(s);
      final result = await GeminiDecisions.ask(
          keys: keys, input: input, questions: questions);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is GeminiException ? e.message : userErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _valueText(AppStrings s, DecisionAnswer a) => switch (a.question.kind) {
        DecisionKind.noul => s.t(a.isYes ? 'qc.yes' : 'qc.no'),
        DecisionKind.choice => _typeIds.contains(a.choice)
            ? s.t('qc.t_${a.choice}')
            : (a.choiceText ?? a.choice ?? ''),
        DecisionKind.score => s.t(switch ((a.score ?? 0).round()) {
            <= 0 => 'qc.l_low',
            1 => 'qc.l_mid',
            _ => 'qc.l_high',
          }),
      };

  /// Gösterilen yanıtın olasılığı: evet/hayır için seçilen tarafınki.
  double _shownP(DecisionAnswer a) => a.question.kind == DecisionKind.noul
      ? (a.isYes ? a.yes! : 1 - (a.yes ?? 0))
      : a.confidence;

  String _asText(AppStrings s, DecisionResult r) => [
        widget.entry.name,
        for (final a in r.answers)
          '${a.question.label}: ${_valueText(s, a)} '
              '(%${(_shownP(a) * 100).round()})',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final result = _result;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Gap.xs),
          Text(s.t('qc.intro'), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (final q in _presets)
                FilterChip(
                  key: ValueKey('qc-${q.id}'),
                  label: Text(q.label),
                  selected: _on.contains(q.id),
                  onSelected: _busy
                      ? null
                      : (v) => setState(() => v ? _on.add(q.id) : _on.remove(q.id)),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            key: const ValueKey('qc-custom'),
            controller: _custom,
            minLines: 1,
            maxLines: 4,
            enabled: !_busy,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              hintText: s.t('qc.custom_hint'),
            ),
          ),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            key: const ValueKey('qc-run'),
            onPressed: _busy ? null : _run,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(AppIcons.ai),
            label: Text(s.t(_busy
                ? 'qc.running'
                : (result == null ? 'qc.run' : 'qc.again'))),
          ),
          if (_error case final err?) ...[
            const SizedBox(height: Gap.sm),
            Text(err, style: TextStyle(color: scheme.error)),
          ],
          if (result != null) ...[
            const SizedBox(height: Gap.md),
            if (result.blockReason != null)
              Text(s.t('qc.blocked'), style: TextStyle(color: scheme.error))
            else if (result.answers.isEmpty)
              Text(s.t('qc.empty'))
            else ...[
              for (final a in result.answers) _row(context, s, a),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _asText(s, result)));
                    showSnack(context, s.t('near.copied'));
                  },
                  icon: const Icon(AppIcons.copyPlain),
                  label: Text(s.t('qc.copy')),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppStrings s, DecisionAnswer a) {
    final scheme = Theme.of(context).colorScheme;
    final p = _shownP(a).clamp(0.0, 1.0);
    final yesNo = a.question.kind == DecisionKind.noul;
    final color = !yesNo
        ? scheme.primary
        : (a.isYes ? scheme.tertiary : scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(a.question.label,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: Gap.sm),
            Flexible(
              child: Text(
                '${_valueText(s, a)} · %${(p * 100).round()}',
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: color),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: p,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            color: color,
          ),
        ],
      ),
    );
  }
}
