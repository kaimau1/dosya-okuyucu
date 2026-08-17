/// **Seçilebilir AI dosya listesi** — analiz sonucunun eyleme dönüştüğü yer.
///
/// KÖK NEDEN (2026-08-11 kullanıcı): *"AI analiz ediyor ama ne işe yarıyor,
/// kullanıcı ne yapacak belli değil… rapor menüsünde etkileşim yok,
/// silinebilir adayları göremiyorum."* Analiz sonucu sayı olarak duruyordu;
/// sayının arkasındaki dosyalara ne ulaşılabiliyor ne de toplu bir şey
/// yapılabiliyordu.
///
/// Bu liste o boşluğu kapatır ve **dosya yöneticisinin kendi dilini** kullanır:
/// dokun → aç, uzun bas → seçim kipi, seçimde alt şeritte toplu işlemler
/// (paylaş, taşı, sil, öneriyi uygula). Yeni bir etkileşim dili icat etmiyoruz;
/// kullanıcı bunu uygulamanın geri kalanından zaten biliyor.
library;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../screens/fm/entry_actions.dart';
import '../../services/fm/ai_buckets.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/ai_report.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import 'fm_entry_icon.dart';

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
            itemCount: widget.records.length,
            itemBuilder: (context, i) => _row(widget.records[i]),
          ),
        ),
        if (_selecting) _actionBar(),
      ],
    );
  }

  Widget _row(AiRecord record) {
    final faint = Paper.faint(context);
    final entry = AiBuckets.entryOf(record);
    final picked = _selected.contains(record.path);
    final subtitle = <String>[
      if (record.docType.isNotEmpty)
        AiBuckets.label(AiBuckets.canonicalDocType(record.docType)),
      FsPaths.humanSize(record.sizeBytes),
      // Klasör adı: aynı adlı iki dosyayı ayırt etmenin tek yolu.
      p.basename(p.dirname(record.path)),
      if (!widget.showSuggestion && record.summary.isNotEmpty) record.summary,
    ].join(' · ');

    return ListTile(
      leading: FmSelectableIcon(
        entry: entry,
        selecting: _selecting,
        selected: picked,
        onCheck: () => _toggle(record),
      ),
      title: Text(
        record.title.isEmpty ? record.name : record.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: faint)),
          if (widget.showSuggestion && record.hasSuggestion)
            Text(
              _suggestionLine(record),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
      isThreeLine: widget.showSuggestion && record.hasSuggestion,
      trailing: _selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (record.importance >= AiImportance.important)
                  Icon(Icons.star,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                IconButton(
                  tooltip: context.t('fm.actions'),
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _openActions(entry),
                ),
              ],
            ),
      selected: picked,
      onTap: () => _selecting
          ? _toggle(record)
          : EntryOpener.open(context, record.path),
      onLongPress: () => _toggle(record),
    );
  }

  String _suggestionLine(AiRecord record) {
    final parts = <String>[];
    if (record.suggestedName.isNotEmpty &&
        record.suggestedName != record.name) {
      parts.add('→ ${record.suggestedName}');
    }
    if (record.suggestedFolder.isNotEmpty) {
      parts.add('→ ${record.suggestedFolder}/');
    }
    return parts.join('   ');
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
                    icon: const Icon(Icons.close),
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
                        Icons.auto_fix_high,
                        context.t('aif.apply'),
                        () async {
                          await widget.onApply!(selected);
                          if (mounted) setState(_selected.clear);
                        },
                      ),
                    _barButton(Icons.share_outlined, context.t('aif.share'),
                        () => shareEntries(_selected.toList())),
                    _barButton(
                      Icons.drive_file_move_outlined,
                      context.t('aif.move'),
                      () async => _afterFileOp(await moveOrCopyEntries(
                          context, _selected.toList(),
                          move: true)),
                    ),
                    _barButton(
                      Icons.delete_outline,
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
