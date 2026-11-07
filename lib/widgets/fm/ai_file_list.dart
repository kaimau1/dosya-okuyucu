/// **Seçilebilir AI dosya listesi** — analiz sonucunun eyleme dönüştüğü yer.
///
/// Dosya yöneticisinin kendi dilini kullanır: dokun → aç, uzun bas → seçim
/// kipi, seçimde alt şeritte toplu işlemler (paylaş, taşı, sil, öneriyi
/// uygula).
///
/// 2026-11-07 yeniden yazımı (kullanıcı: *"silinenler hâlâ gösteriliyor,
/// kendi kendine önemli dosyalara taşıma yapıyor"*):
/// - Dokunulan dosya diskte yoksa kayıt indeksten düşer ve kısa bir not
///   çıkar ("Dosya bulunamadı" ile kalakalmak yerine).
/// - Her satırdaki kırmızı yıldız kaldırıldı — "Önemli Dosyalar"ın yıldızıyla
///   karışıyor, dosyanın oraya taşındığı sanılıyordu. Yerine yazılı, küçük
///   bir "Önemli" etiketi.
/// - Öneri satırı ne olacağını açıkça yazar ("Yeni ad: …", "Taşınacak:
///   Documents/…"); satır menüsünde "yalnız bunu uygula" ve "yok say".
/// - Öneriler yalnız [confirmApplyAiSuggestions] levhasından uygulanır.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../screens/fm/entry_actions.dart';
import '../../services/fm/ai_apply.dart';
import '../../services/fm/ai_buckets.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/ai_report.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../app_dialog.dart';
import 'fm_entry_icon.dart';

/// Önerileri uygulamadan ÖNCE ne olacağını gösteren levha.
///
/// Ad ve klasör önerileri ayrı anahtarlarla seçilir; hedef klasör yazılı
/// durur. Kullanıcı "Uygula"ya basmadan hiçbir dosya değişmez. Dönüş: iş
/// başladı mı.
Future<bool> confirmApplyAiSuggestions(
  BuildContext context,
  List<AiRecord> records,
) async {
  final renames = records.where((r) => r.hasNameSuggestion).length;
  final moves = records.where((r) => r.hasFolderSuggestion).length;
  if (renames + moves == 0) return false;
  if (AiApply.isRunning) {
    showSnack(context, context.t('aih2.apply_busy'));
    return false;
  }
  final root = AiApply.folderRootIn(FmEnv.primaryRoot);
  final choice = await showAppSheet<(bool, bool)>(
    context,
    title: context.t('aih2.apply_title', {'n': records.length}),
    builder: (ctx) => _ApplySheet(
      renames: renames,
      moves: moves,
      folderLabel: p.basename(root),
    ),
  );
  if (choice == null || !context.mounted) return false;
  final (rename, move) = choice;
  final count = records
      .where((r) => AiApply.wants(r, rename: rename, move: move))
      .length;
  if (count == 0) return false;
  AiApply.start(records, folderRoot: root, rename: rename, move: move);
  showSnack(context, context.t('aiap.started', {'n': count}));
  return true;
}

class _ApplySheet extends StatefulWidget {
  final int renames;
  final int moves;
  final String folderLabel;

  const _ApplySheet({
    required this.renames,
    required this.moves,
    required this.folderLabel,
  });

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  late bool _rename = widget.renames > 0;
  // Taşıma varsayılan KAPALI: dosyanın yerini değiştirmek daha büyük bir iş,
  // kullanıcı bilerek açsın.
  bool _move = false;

  @override
  Widget build(BuildContext context) {
    final faint = Paper.faint(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('aih2.apply_body'),
              style: context.type.small.copyWith(color: faint)),
          const SizedBox(height: Gap.sm),
          if (widget.renames > 0)
            SwitchListTile(
              key: const ValueKey('aih-apply-rename'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(AppIcons.rename),
              title: Text(
                  context.t('aih2.apply_rename', {'n': widget.renames})),
              subtitle: Text(context.t('aih2.apply_rename_sub')),
              value: _rename,
              onChanged: (v) => setState(() => _rename = v),
            ),
          if (widget.moves > 0)
            SwitchListTile(
              key: const ValueKey('aih-apply-move'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(AppIcons.move),
              title: Text(context.t('aih2.apply_move', {'n': widget.moves})),
              subtitle: Text(context
                  .t('aih2.apply_move_sub', {'folder': widget.folderLabel})),
              value: _move,
              onChanged: (v) => setState(() => _move = v),
            ),
          const SizedBox(height: Gap.xs),
          Text(context.t('aih2.apply_undo'),
              style: context.type.small.copyWith(color: faint)),
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            key: const ValueKey('aih-apply-go'),
            icon: const Icon(AppIcons.check),
            label: Text(context.t('aih2.apply_go')),
            onPressed: _rename || _move
                ? () => Navigator.of(context).pop((_rename, _move))
                : null,
          ),
        ],
      ),
    );
  }
}

class AiFileList extends StatefulWidget {
  final List<AiRecord> records;

  /// Satır altında ad/klasör önerisi gösterilsin mi? (Öneriler kovası.)
  final bool showSuggestion;

  /// Seçilenlere "Öneriyi uygula" düğmesi eklensin mi?
  final Future<void> Function(List<AiRecord> selected)? onApply;

  /// Dosya sistemi değişince (silme/taşıma) çağrılır — ekran listesini tazeler.
  final VoidCallback? onChanged;

  const AiFileList({
    super.key,
    required this.records,
    this.showSuggestion = false,
    this.onApply,
    this.onChanged,
  });

  @override
  State<AiFileList> createState() => _AiFileListState();
}

class _AiFileListState extends State<AiFileList> {
  final _selected = <String>{};

  bool get _selecting => _selected.isNotEmpty;

  List<AiRecord> get _selectedRecords => [
        for (final record in widget.records)
          if (_selected.contains(record.path)) record
      ];

  @override
  void didUpdateWidget(covariant AiFileList old) {
    super.didUpdateWidget(old);
    // Liste tazelenince (silinen/taşınan) artık olmayan seçimler düşer.
    if (_selected.isNotEmpty) {
      final alive = {for (final r in widget.records) r.path};
      _selected.removeWhere((path) => !alive.contains(path));
    }
  }

  void _toggle(AiRecord record) => setState(() {
        if (!_selected.remove(record.path)) _selected.add(record.path);
      });

  Future<void> _afterFileOp(bool changed) async {
    if (!changed) return;
    // Silinen/taşınan dosya indekste hayalet kalmasın.
    await AiIndex.pruneMissing();
    if (!mounted) return;
    setState(_selected.clear);
    widget.onChanged?.call();
  }

  Future<void> _open(AiRecord record) async {
    if (!await File(record.path).exists()) {
      await AiIndex.pruneMissing();
      if (mounted) showSnack(context, context.t('aih2.gone'));
      widget.onChanged?.call();
      return;
    }
    if (!mounted) return;
    await EntryOpener.open(context, record.path);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(context.t('aif.empty'), textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: Gap.xl),
            itemCount: widget.records.length,
            itemBuilder: (context, i) => _row(widget.records[i]),
          ),
        ),
        if (_selecting) _actionBar(),
      ],
    );
  }

  Widget _row(AiRecord record) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    final entry = AiBuckets.entryOf(record);
    final picked = _selected.contains(record.path);
    final important = record.importance >= AiImportance.important;
    final meta = <String>[
      if (record.docType.isNotEmpty)
        AiBuckets.label(AiBuckets.canonicalDocType(record.docType)),
      FsPaths.humanSize(record.sizeBytes),
      // Klasör adı: aynı adlı iki dosyayı ayırt etmenin tek yolu.
      p.basename(p.dirname(record.path)),
    ].join(' · ');
    final hasTitle = record.title.isNotEmpty && record.title != record.name;

    final lines = <Widget>[
      Text(meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type.small.copyWith(color: faint)),
      if (widget.showSuggestion && record.hasSuggestion) ...[
        if (hasTitle)
          Text(record.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.small.copyWith(color: faint)),
        if (record.hasNameSuggestion)
          _suggestLine(AppIcons.rename,
              context.t('aih2.sug_name', {'name': record.suggestedName})),
        if (record.hasFolderSuggestion)
          _suggestLine(
              AppIcons.move,
              context.t('aih2.sug_folder', {
                'folder': p.join(
                    p.basename(AiApply.folderRootIn(FmEnv.primaryRoot)),
                    record.suggestedFolder)
              })),
      ] else if (record.summary.isNotEmpty)
        Text(record.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.type.small.copyWith(color: faint)),
    ];

    return ListTile(
      leading: FmSelectableIcon(
        entry: entry,
        selecting: _selecting,
        selected: picked,
        onCheck: () => _toggle(record),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              hasTitle ? record.title : record.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (important) ...[
            const SizedBox(width: Gap.xs),
            _ImportantTag(color: theme.colorScheme.primary),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
      isThreeLine: lines.length > 1,
      trailing: _selecting
          ? null
          : IconButton(
              tooltip: context.t('fm.actions'),
              icon: const Icon(AppIcons.more),
              onPressed: () => widget.showSuggestion && record.hasSuggestion
                  ? _suggestionMenu(record)
                  : _openActions(entry),
            ),
      selected: picked,
      onTap: () => _selecting ? _toggle(record) : _open(record),
      onLongPress: () => _toggle(record),
    );
  }

  Widget _suggestLine(IconData icon, String text) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: Gap.xs),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.small.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  /// Öneri satırının menüsü: yalnız bunu uygula · yok say · dosya işlemleri.
  Future<void> _suggestionMenu(AiRecord record) async {
    final choice = await showAppSheet<String>(
      context,
      title: record.title.isNotEmpty ? record.title : record.name,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.check),
            title: Text(ctx.t('aih.apply_one')),
            onTap: () => Navigator.of(ctx).pop('apply'),
          ),
          ListTile(
            leading: const Icon(AppIcons.close),
            title: Text(ctx.t('aih.ignore_one')),
            onTap: () => Navigator.of(ctx).pop('ignore'),
          ),
          ListTile(
            leading: const Icon(AppIcons.more),
            title: Text(ctx.t('fm.actions')),
            onTap: () => Navigator.of(ctx).pop('more'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'apply':
        await confirmApplyAiSuggestions(context, [record]);
      case 'ignore':
        await AiIndex.dismissSuggestion(record.path);
        widget.onChanged?.call();
      case 'more':
        await _openActions(AiBuckets.entryOf(record));
    }
  }

  Future<void> _openActions(FsEntry entry) async {
    final changed = await showEntryActions(context, entry, allowReveal: true);
    await _afterFileOp(changed);
  }

  /// Seçim şeridi — toplu işlemler.
  Widget _actionBar() {
    final selected = _selectedRecords;
    final bytes = AiBuckets.totalBytes(selected);
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, Gap.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: context.t('common.cancel'),
                    icon: const Icon(AppIcons.close),
                    onPressed: () => setState(_selected.clear),
                  ),
                  Expanded(
                    child: Text(
                      context.t('aif.selected_n', {
                        'n': selected.length,
                        'size': FsPaths.humanSize(bytes),
                      }),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (_selected.length == widget.records.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(widget.records.map((r) => r.path));
                      }
                    }),
                    child: Text(context.t('aih.select_all')),
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (widget.onApply != null)
                      _barButton(
                        AppIcons.organize,
                        context.t('aif.apply'),
                        () async {
                          await widget.onApply!(selected);
                          if (mounted) setState(_selected.clear);
                        },
                      ),
                    _barButton(AppIcons.share, context.t('aif.share'),
                        () => shareEntriesFrom(context, _selected.toList())),
                    _barButton(
                      AppIcons.move,
                      context.t('aif.move'),
                      () async => _afterFileOp(await moveOrCopyEntries(
                          context, _selected.toList(),
                          move: true)),
                    ),
                    _barButton(
                      AppIcons.delete,
                      context.t('common.delete'),
                      () async => _afterFileOp(await deleteEntries(
                        context,
                        [for (final r in selected) AiBuckets.entryOf(r)],
                      )),
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

  Widget _barButton(IconData icon, String label, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
        child: TextButton.icon(
          icon: Icon(icon, size: 20),
          label: Text(label),
          onPressed: onPressed,
        ),
      );
}

/// Küçük yazılı "Önemli" etiketi (AI önem puanı ≥ 70).
class _ImportantTag extends StatelessWidget {
  final Color color;
  const _ImportantTag({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Text(
          context.t('aih2.important_tag'),
          style: context.type.caption
              .copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      );
}
