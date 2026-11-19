import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../models/fs_entry.dart';
import '../../services/conversion_service.dart';
import '../../services/fm/checklists.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/gemini_decisions.dart';
import '../../services/gemini_service.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/app_dialog.dart';
import 'ai_quick_check.dart';
import 'entry_actions.dart';

/// **AI kontrol listesi** (B2 dilim 3, PLAN §1.2): seçili dosyalar ya da
/// klasör(ler)in doğrudan içindeki dosyalar bir evrak listesine karşı
/// denetlenir → madde başına ✓/✗ + güven, eksik evrak, PDF rapor paylaş.
///
/// Dosya başına TEK istek (listenin bütün maddeleri aynı istekte),
/// aynı anda [_parallel]; AI kapsamı dışındaki dosya gönderilmez.
Future<void> showAiChecklist(BuildContext context, List<FsEntry> entries) async {
  final files = <FsEntry>[];
  for (final e in entries) {
    if (!e.isDir) {
      files.add(e);
      continue;
    }
    try {
      files.addAll((await FsScan.list(e.path)).where((f) => !f.isDir));
    } catch (_) {
      // Bilinçli: okunamayan klasör atlanır; hiç dosya kalmazsa aşağıda söylenir.
    }
  }
  if (!context.mounted) return;
  if (files.isEmpty) {
    showSnack(context, context.t('ckl.no_files'));
    return;
  }
  if (!await ensureAiKey(context) || !context.mounted) return;
  final saved = await Checklists.loadSaved();
  if (!context.mounted) return;
  await showAppSheet<void>(
    context,
    title: context.t('ckl.title', {'n': files.length}),
    builder: (_) =>
        _ChecklistSheet(files: files.take(_maxFiles).toList(), saved: saved),
  );
}

const _maxFiles = 60;
const _parallel = 3;

class _ChecklistSheet extends StatefulWidget {
  final List<FsEntry> files;
  final List<Checklist> saved;

  const _ChecklistSheet({required this.files, required this.saved});

  @override
  State<_ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends State<_ChecklistSheet> {
  late final AppStrings _s = AppStrings.of(context);
  late final List<Checklist> _presets = Checklists.presets(_s);
  late List<Checklist> _saved = widget.saved;
  late Checklist _list = _saved.isNotEmpty ? _saved.last : _presets.first;

  final Map<String, List<DecisionAnswer>> _answers = {};
  int _done = 0;
  int _errors = 0;
  String? _lastError;
  bool _running = false;
  List<ChecklistItemResult>? _results;

  Future<void> _newList() async {
    final name = await showAppPrompt(context,
        title: _s.t('ckl.new'), label: _s.t('ckl.new_name'), maxLength: 60);
    if (name == null || !mounted) return;
    final raw = await showAppPrompt(context,
        title: name, label: _s.t('ckl.new_items'), multiline: true);
    if (raw == null || !mounted) return;
    final items = Checklists.parseItems(raw);
    if (items.isEmpty) return;
    final c = Checklist(
        'u_${DateTime.now().millisecondsSinceEpoch}', name, items);
    final all = await Checklists.save(c);
    if (!mounted) return;
    setState(() {
      _saved = all;
      _list = c;
      _results = null;
    });
  }

  Future<void> _delete(Checklist c) async {
    final all = await Checklists.delete(c.id);
    if (!mounted) return;
    setState(() {
      _saved = all;
      if (_list.id == c.id) _list = _presets.first;
      _results = null;
    });
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    final keys = state.aiCredentials.normalized.keys;
    final scope = state.aiScopeRules;
    final list = _list;
    final questions = Checklists.questions(list);
    setState(() {
      _answers.clear();
      _done = 0;
      _errors = 0;
      _lastError = null;
      _running = true;
      _results = null;
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
            questions: questions,
          );
          _answers[f.path] = r.answers;
        } catch (e) {
          _errors++;
          _lastError = e is GeminiException ? e.message : userErrorText(e);
        }
        if (mounted) setState(() => _done++);
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    if (!mounted) return;
    setState(() {
      _running = false;
      _results = Checklists.evaluate(list, _answers);
    });
  }

  Future<void> _sharePdf() async {
    final results = _results;
    if (results == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final conv = ConversionService();
      final bytes = await conv.textToPdf(
          _list.name,
          Checklists.report(
              _s, _list, results, widget.files.length, DateTime.now()));
      final path = await conv.writeToTemp('${_list.name}.pdf', bytes);
      await shareEntries([path]);
    } catch (e) {
      if (messenger != null) showSnackOn(messenger, userErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.files.length;
    final results = _results;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_s.t('ckl.intro'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (final c in [..._presets, ..._saved])
                InputChip(
                  key: ValueKey('ckl-${c.id}'),
                  label: Text(c.name),
                  selected: _list.id == c.id,
                  onSelected: _running
                      ? null
                      : (_) => setState(() {
                            _list = c;
                            _results = null;
                          }),
                  onDeleted: c.builtIn || _running
                      ? null
                      : () => unawaited(_delete(c)),
                  deleteButtonTooltipMessage: _s.t('ckl.delete'),
                ),
              ActionChip(
                key: const ValueKey('ckl-new'),
                avatar: const Icon(AppIcons.add, size: AppIcons.small),
                label: Text(_s.t('ckl.new')),
                onPressed: _running ? null : () => unawaited(_newList()),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(_list.items.join(' · '),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            key: const ValueKey('ckl-run'),
            onPressed: _running ? null : _run,
            icon: const Icon(AppIcons.ai),
            label: Text(_running
                ? _s.t('ckl.progress', {'done': _done, 'total': total})
                : _s.t(results == null ? 'ckl.run' : 'qc.again')),
          ),
          if (_running) ...[
            const SizedBox(height: Gap.xs),
            LinearProgressIndicator(value: total == 0 ? null : _done / total),
          ],
          if (_errors > 0 && !_running && _lastError != null) ...[
            const SizedBox(height: Gap.xs),
            Text('$_errors × $_lastError',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ],
          if (results != null) ..._resultView(theme, results),
        ],
      ),
    );
  }

  List<Widget> _resultView(ThemeData theme, List<ChecklistItemResult> results) {
    final scheme = theme.colorScheme;
    final ok = results.where((r) => r.ok).length;
    final missing = results.length - ok;
    return [
      const SizedBox(height: Gap.sm),
      Text(
        '${_s.t('ckl.summary', {'ok': ok, 'total': results.length})} · '
        '${missing == 0 ? _s.t('ckl.all_ok') : _s.t('ckl.missing', {'n': missing})}',
        style: theme.textTheme.titleSmall,
      ),
      for (final r in results)
        ListTile(
          key: ValueKey('ckl-item-${r.item}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(r.ok ? AppIcons.checkCircle : AppIcons.close,
              color: r.ok ? scheme.tertiary : scheme.error),
          title: Text(r.item),
          subtitle: r.path == null
              ? null
              : Text(r.path!.split(RegExp(r'[\\/]')).last,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: r.answered
              ? Text('%${(r.confidence * 100).round()}',
                  style: theme.textTheme.labelLarge)
              : null,
        ),
      const SizedBox(height: Gap.sm),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FilledButton.tonalIcon(
          key: const ValueKey('ckl-share'),
          onPressed: () => unawaited(_sharePdf()),
          icon: const Icon(AppIcons.pdf, size: AppIcons.small),
          label: Text(_s.t('ckl.share_pdf')),
        ),
      ),
    ];
  }
}
