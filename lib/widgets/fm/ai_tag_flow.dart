import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/text_search.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/ai_tagger.dart';
import '../../services/fm/file_tags.dart';
import '../ai_key_gate.dart';
import '../app_dialog.dart';
import '../tracked_busy.dart';

/// **AI ile etiketle** akışı: öneri getir → levhada gözden geçir → uygula.
///
/// Değişiklik yapıldıysa true döner. Öneri yoksa (ya da kullanıcı vazgeçerse)
/// hiçbir etiket yazılmaz.
Future<bool> showAiTagFlow(BuildContext context, List<FsEntry> entries) async {
  final files = [for (final e in entries) if (!e.isDir) e];
  if (files.isEmpty) return false;
  final str = AppStrings.of(context);
  final appState = context.read<AppState>();
  await FileTags.ensureLoaded();
  if (!context.mounted || !await ensureAiKey(context) || !context.mounted) {
    return false;
  }
  final existing = FileTags.counts().keys.toSet();
  final busy = showTrackedBusy(
    context,
    title: str.t('tagai.busy'),
    name: str.t('tagai.job_name'),
    message: str.t('tagai.busy_n', {'n': files.length}),
  );
  Map<String, Set<String>> suggestions;
  try {
    suggestions = await AiTagger.suggest(
      entries: files,
      gemini: appState.gemini,
      scope: appState.aiScopeRules,
      existing: existing,
      onProgress: (done, total) => busy.status(
          str.t('tagai.busy_progress', {'done': done, 'total': total}),
          done: done,
          total: total),
    );
    await busy.done(
        detail: str.t('tagai.found', {'n': suggestions.length}));
  } catch (e) {
    await busy.failed(e);
    if (context.mounted) {
      showSnack(context, str.t('tagai.error', {'error': userErrorText(e)}));
    }
    return false;
  }
  if (!context.mounted) return false;
  if (suggestions.isEmpty) {
    showSnack(context, str.t('tagai.none'));
    return false;
  }
  // Kullanıcının zaten kullandığı yazımı tercih et ("fatura" önerisi mevcut
  // "Fatura" etiketine katılır, ikinci bir etiket doğmaz).
  final byFold = {for (final t in existing) turkishFold(t): t};
  final merged = <String, Set<String>>{};
  suggestions.forEach((tag, paths) {
    final name = byFold[turkishFold(tag)] ?? tag;
    (merged[name] ??= {}).addAll(paths);
  });
  final picked = await showAppSheet<Map<String, Set<String>>>(
    context,
    scrollable: false,
    builder: (_) => _ReviewSheet(suggestions: merged, total: files.length),
  );
  if (picked == null || picked.isEmpty) return false;
  for (final e in picked.entries) {
    await FileTags.add(e.value, e.key);
  }
  if (context.mounted) {
    showSnack(context,
        str.t('tagai.applied', {'tags': picked.length, 'n': {
          for (final s in picked.values) ...s
        }.length}));
  }
  return true;
}

class _ReviewSheet extends StatefulWidget {
  final Map<String, Set<String>> suggestions;
  final int total;
  const _ReviewSheet({required this.suggestions, required this.total});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final List<MapEntry<String, Set<String>>> _sorted =
      widget.suggestions.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
  late final Set<String> _on = {for (final e in _sorted) e.key};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = FileTags.counts();
    return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, Gap.xs),
              child: Row(
                children: [
                  Icon(AppIcons.ai, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(context.t('tagai.review_title'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, Gap.sm),
              child: Text(
                context.t('tagai.review_body', {'n': widget.total}),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Paper.faint(context)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in _sorted)
                    CheckboxListTile(
                      value: _on.contains(e.key),
                      onChanged: (v) => setState(() =>
                          v == true ? _on.add(e.key) : _on.remove(e.key)),
                      secondary: Icon(AppIcons.tag,
                          color: existing.containsKey(e.key)
                              ? theme.colorScheme.primary
                              : null),
                      title: Text(e.key),
                      subtitle: Text(existing.containsKey(e.key)
                          ? context.t('tagai.row_existing',
                              {'n': e.value.length})
                          : context.t('tagai.row_new', {'n': e.value.length})),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.t('common.cancel')),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey('tagai-apply'),
                    onPressed: _on.isEmpty
                        ? null
                        : () => Navigator.pop(context, {
                              for (final e in _sorted)
                                if (_on.contains(e.key)) e.key: e.value,
                            }),
                    icon: const Icon(AppIcons.check, size: 18),
                    label: Text(context.t('tagai.apply', {'n': _on.length})),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}
