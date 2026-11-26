import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/edition.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/smart_sort_taxonomy.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/pro_gate.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_file_image.dart';
import 'entry_actions.dart';
import 'similar_screen.dart';

/// **Ayıkla** (Akıllı düzen, 2026-11-18, kullanıcı: *"bulanıkları, WhatsApp'taki
/// gereksiz kutlama mesajlarını ayıklamak, bir butonla gizlemek … sil
/// seçeneği de; toplu sil, seçerek sil"*).
///
/// İki sekme: **Gereksizler** (kutlama/selamlaşma, mem, yanlışlıkla çekilmiş,
/// bulanık — neden çipleriyle süzülür) ve **Gizlenenler**. Dokununca seçilir
/// (seçim yokken dokunuş açar); alt çubukta Gizle / Geri getir · Sil, seçim
/// yoksa "hepsi". Gizlemek dosyaya dokunmaz (listelerden kalkar); silmek çöp
/// kutusuna gönderir (geri alınabilir). "Gereksiz değil" uzun basışla.
class SmartClutterScreen extends StatefulWidget {
  final bool startHidden;

  const SmartClutterScreen({super.key, this.startHidden = false});

  static Future<void> open(BuildContext context, {bool hidden = false}) async {
    if (!await ProGate.check(context, Feature.smartFolders)) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SmartClutterScreen(startHidden: hidden)));
  }

  @override
  State<SmartClutterScreen> createState() => _SmartClutterScreenState();
}

class _SmartClutterScreenState extends State<SmartClutterScreen> {
  static const _reasons = [
    'greeting',
    'meme',
    'accidental',
    'blurry',
    'old_shot',
    'wa_copy',
  ];

  late bool _hiddenTab = widget.startHidden;
  String? _reason;
  final Set<String> _selected = {};

  /// Diskte hâlâ var olan yollar (silinenler kayıttan düşer).
  Set<String>? _alive;

  @override
  void initState() {
    super.initState();
    if (!Edition.current.has(Feature.smartFolders)) return;
    SmartSort.revision.addListener(_onChange);
    unawaited(_checkAlive());
  }

  @override
  void dispose() {
    if (Edition.current.has(Feature.smartFolders)) {
      SmartSort.revision.removeListener(_onChange);
    }
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _checkAlive() async {
    await SmartSort.ensureLoaded();
    final paths = <String>{
      for (final r in SmartSort.records)
        if (r.hidden || r.clutter) r.path,
      ...SmartSort.waCopies(),
    }.toList();
    final alive = {for (final e in await FsScan.statPaths(paths)) e.path};
    final gone = paths.where((x) => !alive.contains(x)).toList();
    if (gone.isNotEmpty) await SmartSort.forget(gone);
    if (mounted) setState(() => _alive = alive);
  }

  List<SmartRecord> get _allClutter {
    final alive = _alive;
    return [
      for (final r in SmartSort.clutter())
        if (alive == null || alive.contains(r.path)) r,
    ];
  }

  List<SmartRecord> get _allHidden {
    final alive = _alive;
    return [
      for (final r in SmartSort.hiddenRecords())
        if (alive == null || alive.contains(r.path)) r,
    ];
  }

  Map<String, int> get _reasonCounts {
    final out = <String, int>{};
    for (final r in _allClutter) {
      final reason = SmartSort.reasonOf(r);
      if (reason != null) {
        out[reason] = (out[reason] ?? 0) + 1;
      }
    }
    return out;
  }

  List<SmartRecord> get _items {
    if (_hiddenTab) return _allHidden;
    final list = _allClutter;
    final reason = _reason;
    if (reason == null || (_reasonCounts[reason] ?? 0) == 0) return list;
    return [
      for (final r in list)
        if (SmartSort.reasonOf(r) == reason) r,
    ];
  }

  /// İşlenecekler: yalnız kullanıcının seçtiği öğeler.
  List<String> get _targets {
    final items = _items;
    return [
      for (final r in items)
        if (_selected.contains(r.path)) r.path,
    ];
  }

  Future<void> _hideOrRestore() async {
    final paths = _targets;
    if (paths.isEmpty) return;
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hide = !_hiddenTab;
    await SmartSort.setHidden(paths, hide);
    if (!mounted) return;
    setState(_selected.clear);
    showSnackOn(
      messenger,
      s.t(hide ? 'sm.hidden_n' : 'sm.restored_n', {'n': paths.length}),
      action: SnackBarAction(
        label: s.t('common.undo'),
        onPressed: () => unawaited(SmartSort.setHidden(paths, !hide)),
      ),
    );
  }

  Future<void> _delete() async {
    final paths = _targets;
    if (paths.isEmpty) return;
    final byPath = {for (final r in SmartSort.records) r.path: r};
    final entries = [
      for (final path in paths)
        if (byPath[path] case final r?)
          FsEntry(
            path: path,
            name: path.split('/').last,
            isDir: false,
            sizeBytes: r.size,
            modifiedMs: r.modifiedMs,
          ),
    ];
    if (await deleteEntries(context, entries)) {
      await SmartSort.forget(paths);
      if (mounted) setState(_selected.clear);
    }
  }

  Future<void> _keepSelected() async {
    final paths = _targets;
    if (paths.isEmpty) return;
    final s = AppStrings.of(context);
    final ok = await showAppConfirm(
      context,
      title: s.t('sm.keep_title'),
      message: s.t('sm.keep_body'),
      confirmLabel: s.t('sm.keep'),
    );
    if (!ok) return;
    for (final path in paths) {
      await SmartSort.keep(path);
    }
    if (mounted) setState(_selected.clear);
  }

  void _toggle(String path) => setState(() {
        if (!_selected.remove(path)) _selected.add(path);
      });

  @override
  Widget build(BuildContext context) {
    if (!Edition.current.has(Feature.smartFolders)) {
      return ProLockedView(
        feature: Feature.smartFolders,
        title: context.t('sm.clutter'),
      );
    }
    final clutterAll = _allClutter;
    final hiddenAll = _allHidden;
    final reasonCounts = _reasonCounts;
    final activeReasons = [
      for (final r in _reasons)
        if ((reasonCounts[r] ?? 0) > 0) r,
    ];
    final effectiveReason =
        (_reason != null && (reasonCounts[_reason] ?? 0) > 0) ? _reason : null;
    final items = _items;
    final selecting = _selected.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(selecting
            ? context.t('sm.selected', {'n': _selected.length})
            : context.t('sm.clutter')),
        actions: [
          if (selecting && !_hiddenTab)
            IconButton(
              key: const ValueKey('sm-keep'),
              tooltip: context.t('sm.keep'),
              icon: const Icon(AppIcons.check),
              onPressed: () => unawaited(_keepSelected()),
            ),
          // Ayıkla 2: düzenlenmiş kişisel fotoğraflarda benzer kare grupları,
          // en net kare ⭐ (bkz. SimilarFinder.orderBest).
          if (!selecting)
            IconButton(
              key: const ValueKey('sm-similar'),
              tooltip: context.t('sm.similar'),
              icon: const Icon(AppIcons.burstMode),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SimilarScreen(
                  scopeId: 'smart_photos',
                  title: context.t('sm.similar'),
                  loadAll: () => FsScan.statPaths([
                    ...SmartSort.pathsOf('photo_people'),
                    ...SmartSort.pathsOf('photo_other'),
                  ]),
                ),
              )),
            ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: context.t('sm.select_all'),
              icon: const Icon(AppIcons.selectAll),
              onPressed: () => setState(() {
                if (_selected.length == items.length) {
                  _selected.clear();
                } else {
                  _selected
                    ..clear()
                    ..addAll(items.map((r) => r.path));
                }
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: false,
                    icon: const Icon(AppIcons.cleanEmpty),
                    label: Text(context.t('sm.tab_clutter',
                        {'n': clutterAll.length}))),
                ButtonSegment(
                    value: true,
                    icon: const Icon(AppIcons.hiddenOff),
                    label: Text(context.t('sm.tab_hidden',
                        {'n': hiddenAll.length}))),
              ],
              selected: {_hiddenTab},
              onSelectionChanged: (v) => setState(() {
                _hiddenTab = v.first;
                _selected.clear();
              }),
            ),
          ),
          // Gizlenenler sekmesinde 48dp ölü şerit yok; yalnız aktif nedenler
          // sayılarıyla çizilir.
          if (!_hiddenTab && activeReasons.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Gap.xs),
                    child: ChoiceChip(
                      label: Text(
                          '${context.t('sm.r_all')} (${clutterAll.length})'),
                      selected: effectiveReason == null,
                      onSelected: (_) => setState(() {
                        _reason = null;
                        _selected.clear();
                      }),
                    ),
                  ),
                  for (final reason in activeReasons)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: Gap.xs),
                      child: ChoiceChip(
                        label: Text(
                            '${context.t('sm.r_$reason')} (${reasonCounts[reason]})'),
                        selected: effectiveReason == reason,
                        onSelected: (_) => setState(() {
                          _reason = reason;
                          _selected.clear();
                        }),
                      ),
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: Gap.sm),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Text(
                        context.t(_hiddenTab ? 'sm.hidden_empty' : 'sm.clutter_empty'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: withNavInset(
                        context, const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.sm, 96)),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 128,
                      mainAxisExtent: 128,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final r = items[i];
                      return RepaintBoundary(
                        child: _Cell(
                          key: ValueKey(r.path),
                          record: r,
                          selected: _selected.contains(r.path),
                          onTap: () => selecting
                              ? _toggle(r.path)
                              : unawaited(EntryOpener.open(context, r.path)),
                          // Uzun basma her iki sekmede de seçim açar.
                          onLongPress: () => _toggle(r.path),
                          onCheck: () => _toggle(r.path),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: !selecting
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.t('ux47.clutter_select_hint'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                          const SizedBox(width: Gap.sm),
                          TextButton.icon(
                            key: const ValueKey('ss-select-all-btn'),
                            onPressed: () => setState(() {
                              _selected
                                ..clear()
                                ..addAll(items.map((r) => r.path));
                            }),
                            icon: const Icon(AppIcons.selectAll, size: 18),
                            label: Text(context.t('sm.select_all')),
                          ),
                        ],
                      )
                    : Row(children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            key: const ValueKey('ss-hide'),
                            onPressed: () => unawaited(_hideOrRestore()),
                            icon: Icon(_hiddenTab
                                ? AppIcons.hidden
                                : AppIcons.hiddenOff),
                            label: Text(
                              context.t(
                                _hiddenTab ? 'sm.restore_sel' : 'sm.hide_sel',
                                {'n': _selected.length},
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('ss-delete'),
                            onPressed: () => unawaited(_delete()),
                            icon: const Icon(AppIcons.delete),
                            label: Text(
                              context.t(
                                  'sm.delete_sel', {'n': _selected.length}),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ]),
              ),
            ),
    );
  }
}

/// Izgara hücresi: küçük resim + neden rozeti + seçim işareti.
class _Cell extends StatelessWidget {
  final SmartRecord record;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheck;

  const _Cell({
    super.key,
    required this.record,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final px = (128 * MediaQuery.devicePixelRatioOf(context)).round();
    final reason = SmartSort.reasonOf(record);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.control),
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            // Video (yanlışlıkla çekilmiş, 2026-11-18): ilk kare küçük resmi
            // listelerle aynı yoldan (önbellekli); görsel doğrudan çözülür.
            child: record.cat == SmartTaxonomy.video
                ? LayoutBuilder(
                    builder: (_, box) => FmEntryIcon(
                      entry: FsEntry(
                        path: record.path,
                        name: record.path.split('/').last,
                        isDir: false,
                        sizeBytes: record.size,
                        modifiedMs: record.modifiedMs,
                      ),
                      size: box.biggest.shortestSide,
                      radius: 0,
                    ),
                  )
                : Image(
                    image: FmFileImage(record.path, cacheWidth: px, cover: true),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Center(
                        child: Icon(AppIcons.brokenImage, color: scheme.outline)),
                  ),
          ),
        ),
        if (selected)
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(color: scheme.primary, width: 3),
            ),
          ),
        if (reason != null)
          PositionedDirectional(
            start: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(context.t('sm.r_$reason'),
                    style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
          ),
        PositionedDirectional(
          top: 2,
          end: 2,
          child: IconButton(
            tooltip: context.t(selected ? 'sm.deselect_one' : 'sm.select_one'),
            visualDensity: VisualDensity.compact,
            onPressed: onCheck,
            icon: Icon(
              selected ? AppIcons.checkCircle : AppIcons.checkCircleOutline,
              color: selected ? scheme.primary : scheme.surface,
            ),
          ),
        ),
      ]),
    );
  }
}
