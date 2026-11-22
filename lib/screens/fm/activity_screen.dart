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
import '../../widgets/motion.dart';
import '../../core/safe_insets.dart';
import '../../core/app_icons.dart';
import '../../widgets/app_dialog.dart';

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
    final activeFilter =
        (_filter != null && groups.containsKey(_filter)) ? _filter : null;
    final shown = activeFilter == null
        ? groups
        : {
            activeFilter: groups[activeFilter]!,
          };
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('act.title')),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              tooltip: context.t('act.clear'),
              icon: const Icon(AppIcons.deleteSweep),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: _loading
          ? const FmListSkeleton()
          : _records.isEmpty
              ? FmEmptyState(
                  icon: AppIcons.history, title: context.t('act.empty'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: withNavInset(
                      context,
                      const EdgeInsets.fromLTRB(
                          Gap.md, Gap.sm, Gap.md, Gap.lg),
                    ),
                    children: [
                      _filterChips(groups, activeFilter),
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

  /// Tek, net, yatay kaydırmalı işlem türü çip şeridi: Hepsi (N),
  /// Küçültülen videolar (N), Düzenlenen PDF'ler (N), Düzenlenen belgeler (N),
  /// Taranan belgeler (N).
  Widget _filterChips(
    Map<ActivityKind, List<ActivityRecord>> groups,
    ActivityKind? activeFilter,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Gap.sm),
              child: ChoiceChip(
                key: const ValueKey('act-chip-all'),
                label: Text(context.t('act.all', {'n': _records.length})),
                selected: activeFilter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
            ),
            for (final entry in groups.entries)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Gap.sm),
                child: ChoiceChip(
                  key: ValueKey('act-chip-${entry.key.name}'),
                  label: Text(
                      '${context.t(entry.key.labelKey)} (${entry.value.length})'),
                  selected: activeFilter == entry.key,
                  onSelected: (_) => setState(() => _filter = entry.key),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Eski bozuk soru/uyarı cümlesi kalıntısı olan detayları temizler; yalnız
  /// kısa ölçü/boyut/sayfa bilgilerini korur.
  static bool _isCleanDetail(String detail) {
    final d = detail.trim();
    if (d.isEmpty || d.length > 36) return false;
    if (d.contains('?') || d.contains('!') || d.contains('\n')) return false;
    return true;
  }

  static final _hasSizeText =
      RegExp(r'\b(KB|MB|GB|TB|B)\b', caseSensitive: false);

  Widget _tile(ActivityRecord record) {
    final entry = FsEntry.ofPath(record.path);
    final cleanDetail = _isCleanDetail(record.detail) ? record.detail.trim() : '';
    final sizeText = (entry != null &&
            entry.sizeBytes > 0 &&
            !_hasSizeText.hasMatch(cleanDetail))
        ? FsPaths.humanSize(entry.sizeBytes)
        : '';
    final rawFolder = p.basename(p.dirname(record.path));
    final folder = (rawFolder.isEmpty ||
            rawFolder == '.' ||
            rawFolder == '/' ||
            rawFolder == '0')
        ? context.t('ux47.internal_root')
        : rawFolder;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: entry == null
          ? Icon(FmColors.iconFor(FmCategory.other))
          : FmEntryIcon(entry: entry, size: 38),
      title: Text(record.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          FsPaths.humanDate(record.whenMs),
          if (cleanDetail.isNotEmpty) cleanDetail,
          if (sizeText.isNotEmpty) sizeText,
          folder,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => EntryOpener.open(context, record.path),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showAppConfirm(
        context,
        message: context.t('act.clear_confirm'),
        confirmLabel: context.t('common.delete'),
        destructive: true,
    );
    if (ok != true) return;
    // **Yalnız defter silinir, dosyalar DURUR.** Onay metni de bunu yazıyor:
    // "geçmişi temizle" deyip kullanıcının videolarını silmek felaket olurdu.
    await ActivityLog.clear();
    await _load();
  }
}
