import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../models/fs_entry.dart';
import '../../services/gemini_decisions.dart';
import '../../services/gemini_service.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'ai_quick_check.dart';
import 'entry_actions.dart';

/// **AI ile toplu kontrol** (2026-11-18, kullanıcı: *"yeni modelle başka neler
/// yapılabilir … her türlü kullanalım"*) — seçili dosyaların HEPSİNE aynı
/// soru (Gemini Decisions API): "hangileri imzalı?", "hangilerinde kişisel
/// veri var?", "belge türüne göre ayır". Sonuçta süzgeç (yalnız Evet / tek
/// tür) ve eşleşenlere doğrudan Paylaş · Taşı · Önemli'ye kopyala.
///
/// Dosya başına tek istek, aynı anda [_parallel]; ekran kapanınca kalanlar
/// sorulmaz. AI kapsamı dışındaki dosya hiç gönderilmez.
Future<bool> showAiBatchCheck(BuildContext context, List<FsEntry> entries) async {
  final files = [
    for (final e in entries)
      if (!e.isDir) e
  ];
  if (files.isEmpty) return false;
  if (!await ensureAiKey(context) || !context.mounted) return false;
  final changed = await showAppSheet<bool>(
    context,
    title: context.t('qcb.title', {'n': files.length}),
    builder: (_) => _BatchSheet(files: files.take(_maxFiles).toList()),
  );
  return changed ?? false;
}

const _maxFiles = 60;
const _parallel = 3;

class _BatchSheet extends StatefulWidget {
  final List<FsEntry> files;

  const _BatchSheet({required this.files});

  @override
  State<_BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends State<_BatchSheet> {
  late final AppStrings _s = AppStrings.of(context);

  /// Belgeler için hazır sorular (evet/hayır + belge türü).
  late final List<DecisionQuestion> _presets = [
    for (final q in quickCheckPresets(_dominant, _s))
      if (q.kind != DecisionKind.score) q
  ];
  late DecisionQuestion _question = _presets.first;
  final _custom = TextEditingController();

  /// Yol → yanıt (ya da hata metni).
  final Map<String, DecisionAnswer> _answers = {};
  final Map<String, String> _errors = {};
  bool _running = false;
  bool _started = false;
  int _done = 0;

  /// Süzgeç: null = tümü; 'yes' = yalnız Evet; ötekiler = seçenek kimliği.
  String? _filter;

  FmCategory get _dominant {
    final counts = <FmCategory, int>{};
    for (final f in widget.files) {
      counts[f.category] = (counts[f.category] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final custom = _custom.text.trim();
    final question = custom.isEmpty
        ? _question
        : DecisionQuestion.yesNo('custom', custom, custom);
    final state = context.read<AppState>();
    final keys = state.aiCredentials.normalized.keys;
    final scope = state.aiScopeRules;
    setState(() {
      _question = question;
      _answers.clear();
      _errors.clear();
      _filter = null;
      _done = 0;
      _running = true;
      _started = true;
    });
    final queue = [...widget.files];
    Future<void> worker() async {
      while (queue.isNotEmpty && mounted) {
        final f = queue.removeAt(0);
        try {
          if (!scope.allowsFile(f)) {
            throw GeminiException(_s.t('qc.scope_off'), statusCode: -1);
          }
          final r = await GeminiDecisions.ask(
            keys: keys,
            input: await quickCheckInput(f.path, _s),
            questions: [question],
          );
          if (r.answers.isNotEmpty) {
            _answers[f.path] = r.answers.first;
          } else {
            _errors[f.path] =
                r.blockReason != null ? _s.t('qc.blocked') : _s.t('qc.empty');
          }
        } catch (e) {
          _errors[f.path] =
              e is GeminiException ? e.message : userErrorText(e);
        }
        if (mounted) setState(() => _done++);
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    if (mounted) setState(() => _running = false);
  }

  bool _matches(FsEntry f) {
    final a = _answers[f.path];
    final filter = _filter;
    if (filter == null) return true;
    if (a == null) return false;
    return filter == 'yes' ? a.isYes : a.choice == filter;
  }

  List<FsEntry> get _visible => widget.files.where(_matches).toList();

  Future<void> _act(String action) async {
    final paths = [for (final f in _visible) f.path];
    if (paths.isEmpty) return;
    final nav = Navigator.of(context);
    var changed = false;
    switch (action) {
      case 'share':
        await shareEntriesFrom(context, paths);
      case 'move':
        changed = await moveOrCopyEntries(context, paths, move: true);
      case 'important':
        changed = await copyToImportant(context, paths);
    }
    if (changed && nav.mounted) nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.files.length;
    final choices = <String, int>{};
    for (final a in _answers.values) {
      if (a.choice != null) choices[a.choice!] = (choices[a.choice!] ?? 0) + 1;
    }
    final yesCount = _answers.values
        .where((a) => a.question.kind == DecisionKind.noul && a.isYes)
        .length;
    final visible = _visible;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_s.t('qcb.intro'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (final q in _presets)
                ChoiceChip(
                  key: ValueKey('qcb-${q.id}'),
                  label: Text(q.label),
                  selected: _custom.text.trim().isEmpty && _question.id == q.id,
                  onSelected: _running
                      ? null
                      : (_) => setState(() {
                            _custom.clear();
                            _question = q;
                          }),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            key: const ValueKey('qcb-custom'),
            controller: _custom,
            enabled: !_running,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              hintText: _s.t('qcb.custom_hint'),
            ),
          ),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            key: const ValueKey('qcb-run'),
            onPressed: _running ? null : _run,
            icon: const Icon(AppIcons.ai),
            label: Text(_running
                ? _s.t('qcb.progress', {'done': _done, 'total': total})
                : _s.t(_started ? 'qc.again' : 'qc.run')),
          ),
          if (_running) ...[
            const SizedBox(height: Gap.xs),
            LinearProgressIndicator(value: total == 0 ? null : _done / total),
          ],
          if (_started) ...[
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.xs,
              runSpacing: Gap.xs,
              children: [
                ChoiceChip(
                  label: Text(_s.t('qcb.all', {'n': total})),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                if (_question.kind == DecisionKind.noul)
                  ChoiceChip(
                    key: const ValueKey('qcb-only-yes'),
                    label: Text(_s.t('qcb.only_yes', {'n': yesCount})),
                    selected: _filter == 'yes',
                    onSelected: (_) => setState(() => _filter = 'yes'),
                  ),
                for (final c in choices.entries)
                  ChoiceChip(
                    label: Text('${_choiceLabel(c.key)} (${c.value})'),
                    selected: _filter == c.key,
                    onSelected: (_) => setState(() => _filter = c.key),
                  ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            for (final f in visible) _row(context, f),
            if (!_running && visible.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.xs,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_act('important')),
                    icon: const Icon(AppIcons.star, size: AppIcons.small),
                    label: Text(_s.t('qcb.to_important')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_act('move')),
                    icon: const Icon(AppIcons.move, size: AppIcons.small),
                    label: Text(_s.t('qcb.move', {'n': visible.length})),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => unawaited(_act('share')),
                    icon: const Icon(AppIcons.share, size: AppIcons.small),
                    label: Text(_s.t('qcb.share', {'n': visible.length})),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _choiceLabel(String id) {
    final a = _answers.values.firstWhere((a) => a.choice == id);
    return quickCheckValue(_s, a);
  }

  Widget _row(BuildContext context, FsEntry f) {
    final theme = Theme.of(context);
    final a = _answers[f.path];
    final err = _errors[f.path];
    final scheme = theme.colorScheme;
    final Widget trailing;
    if (a != null) {
      final yes = a.question.kind == DecisionKind.noul && a.isYes;
      trailing = Text(
        '${quickCheckValue(_s, a)} · %${(quickCheckP(a) * 100).round()}',
        style: theme.textTheme.labelLarge
            ?.copyWith(color: yes ? scheme.tertiary : scheme.onSurfaceVariant),
      );
    } else if (err != null) {
      trailing = Tooltip(
        message: err,
        child: Icon(AppIcons.error, color: scheme.error, size: AppIcons.small),
      );
    } else {
      trailing = const SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    }
    return ListTile(
      key: ValueKey('qcb-row-${f.path}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: FmEntryIcon(entry: f, size: 36),
      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: err == null
          ? null
          : Text(err,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
      trailing: trailing,
    );
  }
}
