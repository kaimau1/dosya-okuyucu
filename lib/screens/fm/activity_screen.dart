import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/activity_log.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/section_header.dart';

/// **Yaptıklarım** — üretilen dosyaların türe göre gruplanmış defteri.
///
/// KÖK NEDEN (kullanıcı 2026-08-07: *"benim yaptıklarım kartı lazım; mesela
/// video boyutu düşürdük, düşen video orada; PDF düzenledik, orada — ama her
/// şey kategorize olmalı"*): sonuçlar dağınıktı. İşlemler ekranı yalnız son
/// İŞLERİ gösteriyor (liste kırpılıyor ve tarama/temizlik işleri de orada),
/// düzenlenen belgeler ise hiçbir yere yazılmıyordu. Burada tek soru
/// cevaplanıyor: "ben bu uygulamayla ne ürettim, nerede?"
///
/// Diskte artık olmayan kayıtlar ELENİR: dokununca açılmayan satır kullanıcıya
/// uygulamanın bozuk olduğunu düşündürür.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<ActivityRecord> _records = const [];
  bool _loading = true;

  /// Seçili tür süzgeci (null = hepsi).
  ActivityKind? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = ActivityLog.existing(await ActivityLog.load());
    if (!mounted) return;
    setState(() {
      _records = all;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = ActivityLog.group(_records);
    final shown = _filter == null
        ? groups
        : {
            if (groups[_filter] case final list?) _filter!: list,
          };
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('act.title')),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              tooltip: context.t('act.clear'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Text(context.t('act.empty'),
                        textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.md, Gap.sm, Gap.md, Gap.lg),
                    children: [
                      _filterChips(groups),
                      for (final entry in shown.entries) ...[
                        SectionHeader(
                          context.t(entry.key.labelKey),
                          count: '${entry.value.length}',
                          padding: const EdgeInsets.only(
                              top: Gap.md, bottom: Gap.sm),
                        ),
                        for (final record in entry.value) _tile(record),
                      ],
                    ],
                  ),
                ),
    );
  }

  /// Tür süzgeçleri — sayılarla. Tek tür varsa çizilmez: tek çipli bir süzgeç
  /// satırı hiçbir şey seçtirmez, yalnız yer kaplar.
  Widget _filterChips(Map<ActivityKind, List<ActivityRecord>> groups) {
    if (groups.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.xs,
        children: [
          ChoiceChip(
            label: Text(context.t('act.all', {'n': _records.length})),
            selected: _filter == null,
            onSelected: (_) => setState(() => _filter = null),
          ),
          for (final entry in groups.entries)
            ChoiceChip(
              label: Text(
                  '${context.t(entry.key.labelKey)} (${entry.value.length})'),
              selected: _filter == entry.key,
              onSelected: (_) => setState(() => _filter = entry.key),
            ),
        ],
      ),
    );
  }

  Widget _tile(ActivityRecord record) {
    final entry = FsEntry.ofPath(record.path);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: entry == null
          ? Icon(FmColors.iconFor(FmCategory.other))
          : FmEntryIcon(entry: entry, size: 38),
      title: Text(record.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          FsPaths.humanDate(record.whenMs),
          if (record.detail.isNotEmpty) record.detail,
          p.basename(p.dirname(record.path)),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => EntryOpener.open(context, record.path),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(ctx.t('act.clear_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('common.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    // **Yalnız defter silinir, dosyalar DURUR.** Onay metni de bunu yazıyor:
    // "geçmişi temizle" deyip kullanıcının videolarını silmek felaket olurdu.
    await ActivityLog.clear();
    await _load();
  }
}
