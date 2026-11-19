import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
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

  static Future<void> open(BuildContext context, {bool hidden = false}) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SmartClutterScreen(startHidden: hidden)));

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
  ];

  late bool _hiddenTab = widget.startHidden;
  String? _reason;
  final Set<String> _selected = {};

  /// Diskte hâlâ var olan yollar (silinenler kayıttan düşer).
  Set<String>? _alive;

  @override
  void initState() {
    super.initState();
    SmartSort.revision.addListener(_onChange);
    unawaited(_checkAlive());
  }

  @override
  void dispose() {
    SmartSort.revision.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _checkAlive() async {
    await SmartSort.ensureLoaded();
    final paths = [
      for (final r in SmartSort.records)
        if (r.hidden || r.clutter) r.path
    ];
    final alive = {for (final e in await FsScan.statPaths(paths)) e.path};
    final gone = paths.where((x) => !alive.contains(x)).toList();
    if (gone.isNotEmpty) await SmartSort.forget(gone);
    if (mounted) setState(() => _alive = alive);
  }

  List<SmartRecord> get _items {
    final alive = _alive;
    final list = _hiddenTab ? SmartSort.hiddenRecords() : SmartSort.clutter();
    return [
      for (final r in list)
        if ((alive == null || alive.contains(r.path)) &&
            (_hiddenTab || _reason == null || r.clutterReason == _reason))
          r
    ];
  }

  /// İşlenecekler: seçim varsa o, yoksa görünen hepsi.
  List<String> get _targets {
    final items = _items;
    return _selected.isEmpty
        ? [for (final r in items) r.path]
        : [for (final r in items) if (_selected.contains(r.path)) r.path];
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

  Future<void> _keep(SmartRecord r) async {
    final s = AppStrings.of(context);
    final ok = await showAppConfirm(
      context,
      title: s.t('sm.keep_title'),
      message: s.t('sm.keep_body'),
      confirmLabel: s.t('sm.keep'),
    );
    if (!ok) return;
    await SmartSort.keep(r.path);
  }

  void _toggle(String path) => setState(() {
        if (!_selected.remove(path)) _selected.add(path);
      });

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final selecting = _selected.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(selecting
            ? context.t('sm.selected', {'n': _selected.length})
            : context.t('sm.clutter')),
        actions: [
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
                        {'n': SmartSort.clutter().length}))),
                ButtonSegment(
                    value: true,
                    icon: const Icon(AppIcons.hiddenOff),
                    label: Text(context.t('sm.tab_hidden',
                        {'n': SmartSort.hiddenRecords().length}))),
              ],
              selected: {_hiddenTab},
              onSelectionChanged: (v) => setState(() {
                _hiddenTab = v.first;
                _selected.clear();
              }),
            ),
          ),
          // Neden çipleri: yükseklik iki sekmede de sabit (liste zıplamasın).
          SizedBox(
            height: 48,
            child: _hiddenTab
                ? const SizedBox.shrink()
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    children: [
                      for (final reason in [null, ..._reasons])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: Gap.xs),
                          child: ChoiceChip(
                            label: Text(context.t(reason == null
                                ? 'sm.r_all'
                                : 'sm.r_$reason')),
                            selected: _reason == reason,
                            onSelected: (_) => setState(() {
                              _reason = reason;
                              _selected.clear();
                            }),
                          ),
                        ),
                    ],
                  ),
          ),
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
                          onLongPress: () => selecting
                              ? _toggle(r.path)
                              : (_hiddenTab ? _toggle(r.path) : unawaited(_keep(r))),
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
                child: Row(children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('ss-hide'),
                      onPressed: () => unawaited(_hideOrRestore()),
                      icon: Icon(_hiddenTab ? AppIcons.hidden : AppIcons.hiddenOff),
                      label: Text(
                        context.t(
                          _hiddenTab
                              ? (selecting ? 'sm.restore_sel' : 'sm.restore_all')
                              : (selecting ? 'sm.hide_sel' : 'sm.hide_all'),
                          {'n': selecting ? _selected.length : items.length},
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
                        context.t(selecting ? 'sm.delete_sel' : 'sm.delete_all',
                            {'n': selecting ? _selected.length : items.length}),
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
    final reason = record.clutterReason;
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
