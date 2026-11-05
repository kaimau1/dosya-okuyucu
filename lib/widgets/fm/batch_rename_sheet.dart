import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/batch_rename.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/job_queue.dart' show JobChange;
import '../../services/fm/tracked_task.dart';
import '../../core/snack.dart';
import '../../core/user_error.dart';

/// **Toplu yeniden adlandırma** sayfası: kalıp yaz → **canlı önizleme** → uygula.
///
/// Önizleme şart: 200 dosyayı yeniden adlandırmak geri alınması zahmetli bir
/// iştir; kullanıcı "IMG_0001.jpg → Tatil-01.jpg" dönüşümünü uygulamadan ÖNCE
/// görmeli. Çakışan/boş adlar kırmızı yazılır ve o dosyalar atlanır.
///
/// Uzantı otomatik korunur (bkz. `planBatchRename`) — kullanıcı `.jpg`'yi
/// yanlışlıkla silerse dosya açılamaz hâle gelirdi.
Future<bool> showBatchRenameSheet(
  BuildContext context,
  List<FsEntry> entries,
) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _BatchRenameSheet(entries: entries),
  );
  return changed ?? false;
}

class _BatchRenameSheet extends StatefulWidget {
  final List<FsEntry> entries;
  const _BatchRenameSheet({required this.entries});

  @override
  State<_BatchRenameSheet> createState() => _BatchRenameSheetState();
}

class _BatchRenameSheetState extends State<_BatchRenameSheet> {
  final _patternController = TextEditingController(text: '{ad}');
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  int _startAt = 1;
  bool _running = false;

  /// Kaydedilmiş kalıplar (Faz 41 / 1).
  List<String> _saved = const [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getStringList(BatchRenameTemplates.prefKey) ?? const [];
      if (mounted) setState(() => _saved = v);
    } catch (_) {
      // Bilinçli: kayıt okunamazsa yalnız hazır kalıplar görünür.
    }
  }

  Future<void> _storeSaved(List<String> next) async {
    setState(() => _saved = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(BatchRenameTemplates.prefKey, next);
    } catch (_) {
      // Bilinçli: yazılamazsa yalnız bu oturumda geçerli.
    }
  }

  @override
  void dispose() {
    _patternController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  List<RenamePreview> get _preview => planBatchRename(
        widget.entries,
        pattern: _patternController.text,
        startAt: _startAt,
        find: _findController.text,
        replace: _replaceController.text,
      );

  Future<void> _apply() async {
    final plan = _preview.where((r) => r.isValid && r.changed).toList();
    if (plan.isEmpty) return;
    setState(() => _running = true);
    final str = AppStrings.of(context);
    // İş sonucu sayfası (2026-11-02, KALANLAR A5): dosya dosya eski → yeni ad
    // iş kaydına yazılır; İşlemler'deki karttan "Adları geri al".
    final task = TrackedTask(title: str.t('br.title'));
    var ok = 0;
    final errors = <String>[];
    final changes = <JobChange>[];
    for (final item in plan) {
      try {
        final renamed = await FileOps.rename(item.entry.path, item.newName);
        ok++;
        changes.add(renamedChange(item.entry.path, renamed));
      } catch (e) {
        errors.add('${item.entry.name}: ${userErrorText(e)}');
      }
    }
    if (changes.isNotEmpty) task.recordChanges(changes);
    await task.complete(
        detail: str.t('br.done', {'n': ok}), quiet: true, notify: false);
    if (!mounted) return;
    setState(() => _running = false);
    showSnack(context, errors.isEmpty
          ? context.t('br.done', {'n': ok})
          : context.t('br.partial', {
              'n': ok,
              'fail': errors.length,
              'first': errors.first,
            }));
    if (mounted) Navigator.pop(context, ok > 0);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final valid = preview.where((r) => r.isValid && r.changed).length;
    final problems = preview.where((r) => !r.isValid).length;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(context.t('br.title'),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Text(context
                        .t('br.file_count', {'n': widget.entries.length}),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Divider(height: Gap.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  children: [
                    Wrap(
                      spacing: Gap.sm,
                      children: [
                        for (final preset in batchRenamePresets)
                          ActionChip(
                            label: Text(context.t(preset.labelKey)),
                            onPressed: () => setState(() =>
                                _patternController.text = preset.pattern),
                          ),
                        // Kullanıcının kalıpları: dokun = uygula, ✕ = sil.
                        for (final t in _saved)
                          InputChip(
                            key: ValueKey('br-saved-$t'),
                            avatar: const Icon(AppIcons.bookmark, size: 16),
                            label: Text(t),
                            onPressed: () =>
                                setState(() => _patternController.text = t),
                            onDeleted: () => _storeSaved(
                                BatchRenameTemplates.remove(_saved, t)),
                            deleteButtonTooltipMessage:
                                context.t('common.delete'),
                          ),
                        ActionChip(
                          key: const ValueKey('br-save-template'),
                          avatar: const Icon(AppIcons.add, size: 16),
                          label: Text(context.t('br.save_template')),
                          onPressed: _patternController.text.trim().isEmpty
                              ? null
                              : () => _storeSaved(BatchRenameTemplates.add(
                                  _saved, _patternController.text)),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.sm),
                    TextField(
                      controller: _patternController,
                      decoration: InputDecoration(
                        labelText: context.t('br.pattern'),
                        // Yer tutucular ÇEVRİLMEZ (bkz. batchRenamePresets).
                        helperText: batchRenamePlaceholders,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _findController,
                            decoration: InputDecoration(
                              labelText: context.t('br.find'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: TextField(
                            controller: _replaceController,
                            decoration: InputDecoration(
                              labelText: context.t('br.replace'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        SizedBox(
                          width: 92,
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: context.t('br.start'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            controller:
                                TextEditingController(text: '$_startAt'),
                            onChanged: (v) => setState(
                                () => _startAt = int.tryParse(v) ?? 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    Text(context.t('br.preview'),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: Gap.xs),
                    // İlk 30 satır: kalıbın doğru olduğunu görmek için yeter,
                    // 5.000 satır çizmek sayfayı kilitlerdi.
                    for (final item in preview.take(30))
                      _row(item),
                    if (preview.length > 30)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.xs),
                        child: Text(
                            context.t('br.more_files',
                                {'n': preview.length - 30}),
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    const SizedBox(height: Gap.md),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        problems > 0
                            ? context.t('br.will_change_problems',
                                {'n': valid, 'problems': problems})
                            : context.t('br.will_change', {'n': valid}),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    FilledButton.icon(
                      onPressed: _running || valid == 0 ? null : _apply,
                      icon: _running
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(AppIcons.check),
                      label: Text(context.t('common.apply')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(RenamePreview item) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(item.entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const Icon(AppIcons.arrowRightAlt, size: 16),
          Expanded(
            child: Text(
              item.problem ?? item.newName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: item.isValid ? scheme.primary : scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
