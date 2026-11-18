import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/smart_folder_prefs.dart';
import '../../services/fm/smart_learn.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/smart_sort_taxonomy.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/smart_cat_style.dart';
import '../../widgets/section_header.dart';
import 'category_screen.dart';
import 'smart_clutter_screen.dart';

/// **Akıllı düzen** ana ekranı (2026-11-18): aç/kapat ve gizlilik metni,
/// "Şimdi düzenle", akıllı klasörler (AI kategorileri, dosyalar yerinde),
/// Ayıkla kapısı ve ayarlar. Bkz. [SmartSort].
///
/// **Klasör düzeni (2026-11-18, kullanıcı):** akıllı klasörler yeniden
/// adlandırılır, sırası değiştirilir (basılı tut → menü ya da "Sırala ve
/// adlandır"), 2/3/4 sütun seçilir — menüden ya da İKİ PARMAKLA sıkıştırıp
/// açarak ([Listener]: hareket yarışına girmez, tek parmak kaydırma bozulmaz).
/// **Öğrenme:** dosyanın ⋮ menüsü → "Kategori yanlış mı?" ([SmartLearn]).
class SmartSortScreen extends StatefulWidget {
  const SmartSortScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SmartSortScreen()));

  @override
  State<SmartSortScreen> createState() => _SmartSortScreenState();
}

class _SmartSortScreenState extends State<SmartSortScreen> {
  bool _ready = false;

  // İki parmak sıkıştırma → sütun sayısı.
  final Map<int, Offset> _pointers = {};
  double? _pinchStart;

  double _span() {
    final v = _pointers.values.toList();
    return (v[0] - v[1]).distance;
  }

  void _pointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) _pinchStart = _span();
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _pinchStart;
    if (_pointers.length != 2 || start == null || start < 24) return;
    final ratio = _span() / start;
    final cols = SmartFolderPrefs.columns;
    // Açmak (yakınlaştırma) = daha büyük kutu = daha az sütun.
    final next = ratio > 1.3
        ? cols - 1
        : (ratio < 0.77 ? cols + 1 : cols);
    if (next == cols ||
        next < SmartFolderPrefs.minColumns ||
        next > SmartFolderPrefs.maxColumns) {
      return;
    }
    _pinchStart = _span();
    AppHaptics.selection();
    unawaited(SmartFolderPrefs.setColumns(next));
  }

  void _pointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStart = null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(SmartSort.ensureLoaded().then((_) {
      if (mounted) setState(() => _ready = true);
    }));
  }

  Future<void> _enable() async {
    if (!await ensureAiKey(context) || !mounted) return;
    await SmartSort.setSettings(enabled: true);
    if (mounted) await _run();
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r = await SmartSort.run(
        credentials: state.aiCredentials, scope: state.aiScopeRules);
    var msg = r.stoppedBy != null
        ? s.t('sm.stopped', {'n': r.processed})
        : (r.processed == 0 && r.failed == 0
            ? s.t('sm.nothing_new')
            : s.t('sm.done', {'n': r.processed}));
    // Yapılamayanlar da söylenir (eskiden sessizdi: "300'den 27 çıktı").
    if (r.failed > 0 && r.stoppedBy == null) {
      msg += ' · ${s.t('sm.failed', {'n': r.failed})}'
          '${r.lastError != null ? ': ${r.lastError}' : ''}';
    }
    showSnackOn(messenger, msg);
  }

  Future<void> _openCat(String cat) async {
    final nav = Navigator.of(context);
    final title = SmartCatStyle.label(context, cat);
    final files = await FsScan.statPaths(SmartSort.pathsOf(cat));
    if (!mounted) return;
    await nav.push(MaterialPageRoute(
      builder: (_) => CategoryScreen(
        title: title,
        files: files,
        loadAll: () => FsScan.statPaths(SmartSort.pathsOf(cat)),
        replaceOnLoad: true,
        memoryId: 'smart.$cat',
        // Öğrenme kapısı: yanlış düzenlenen dosya nasıl düzeltilir.
        header: const _FixHint(),
      ),
    ));
  }

  Future<void> _rename(String cat) async {
    final def = SmartCatStyle.defaultLabel(context, cat);
    final v = await showAppPrompt(
      context,
      title: context.t('smo.rename_title'),
      label: context.t('smo.rename_label', {'name': def}),
      initial: SmartCatStyle.label(context, cat),
      maxLength: 32,
    );
    if (v == null) return;
    final name = v.trim();
    await SmartFolderPrefs.setName(cat, name == def ? null : name);
    SmartSort.invalidateLabels();
  }

  Future<void> _tileMenu(String cat, List<String> cats) async {
    AppHaptics.selection();
    final i = cats.indexOf(cat);
    final pick = await showAppSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(SmartCatStyle.icon(cat), color: SmartCatStyle.color(cat)),
            title: Text(SmartCatStyle.label(ctx, cat)),
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('smo-rename'),
            leading: const Icon(AppIcons.rename),
            title: Text(ctx.t('smo.rename')),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          if (i > 0)
            ListTile(
              leading: const Icon(AppIcons.arrowUp),
              title: Text(ctx.t('smo.move_first')),
              onTap: () => Navigator.pop(ctx, 'first'),
            ),
          ListTile(
            leading: const Icon(AppIcons.dragIndicator),
            title: Text(ctx.t('smo.arrange')),
            onTap: () => Navigator.pop(ctx, 'arrange'),
          ),
          if (SmartFolderPrefs.nameOf(cat) != null)
            ListTile(
              leading: const Icon(AppIcons.reset),
              title: Text(ctx.t('smo.default_name',
                  {'name': SmartCatStyle.defaultLabel(ctx, cat)})),
              onTap: () => Navigator.pop(ctx, 'default'),
            ),
        ]),
      ),
    );
    if (!mounted || pick == null) return;
    switch (pick) {
      case 'rename':
        await _rename(cat);
      case 'first':
        await SmartFolderPrefs.setOrder([cat, ...cats.where((c) => c != cat)]);
      case 'arrange':
        await _arrange(cats);
      case 'default':
        await SmartFolderPrefs.setName(cat, null);
        SmartSort.invalidateLabels();
    }
  }

  Future<void> _arrange(List<String> cats) => showAppSheet<void>(
        context,
        scrollable: false,
        builder: (_) => _ArrangeSheet(cats: cats, onRename: _rename),
      );

  Future<void> _forgetLearning() async {
    final ok = await showAppConfirm(
      context,
      title: context.t('smo.learn_reset_title'),
      message: context.t('smo.learn_reset_body'),
      confirmLabel: context.t('smo.learn_reset'),
      destructive: true,
    );
    if (ok) await SmartLearn.forgetAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('sm.title'))),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: Listenable.merge([
                SmartSort.revision,
                SmartSort.progress,
                SmartFolderPrefs.revision,
                SmartLearn.revision,
              ]),
              builder: (context, _) => SmartSort.enabled
                  ? Listener(
                      onPointerDown: _pointerDown,
                      onPointerMove: _pointerMove,
                      onPointerUp: _pointerUp,
                      onPointerCancel: _pointerUp,
                      child: _main(context),
                    )
                  : _intro(context),
            ),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: withNavInset(context, const EdgeInsets.all(Gap.lg)),
      children: [
        Icon(AppIcons.ai, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: Gap.md),
        Text(context.t('sm.intro_title'),
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: Gap.sm),
        Text(context.t('sm.intro_body'), style: theme.textTheme.bodyLarge),
        const SizedBox(height: Gap.md),
        for (final k in ['sm.point_place', 'sm.point_name', 'sm.point_clean'])
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(AppIcons.check,
                  size: AppIcons.small, color: theme.colorScheme.primary),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(context.t(k))),
            ]),
          ),
        const SizedBox(height: Gap.md),
        _settingsCard(context),
        const SizedBox(height: Gap.md),
        Text(context.t('sm.privacy'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: Gap.lg),
        FilledButton.icon(
          key: const ValueKey('ss-enable'),
          onPressed: _enable,
          icon: const Icon(AppIcons.ai),
          label: Text(context.t('sm.enable')),
        ),
      ],
    );
  }

  Widget _settingsCard(BuildContext context, {bool learning = false}) => Card(
        margin: EdgeInsets.zero,
        child: Column(children: [
          if (learning)
            ListTile(
              key: const ValueKey('ss-learn'),
              leading: const Icon(AppIcons.insights),
              title: Text(context.t('smo.learn_title')),
              subtitle: Text(SmartLearn.count == 0
                  ? context.t('smo.learn_none')
                  : context.t('smo.learn_n', {'n': SmartLearn.count})),
              trailing: SmartLearn.count == 0
                  ? null
                  : TextButton(
                      onPressed: () => unawaited(_forgetLearning()),
                      child: Text(context.t('smo.learn_reset')),
                    ),
            ),
          SwitchListTile(
            key: const ValueKey('ss-camera'),
            secondary: const Icon(AppIcons.photoCamera),
            title: Text(context.t('sm.camera')),
            subtitle: Text(context.t('sm.camera_sub')),
            value: SmartSort.includeCamera,
            onChanged: (v) => unawaited(SmartSort.setSettings(camera: v)),
          ),
          SwitchListTile(
            key: const ValueKey('ss-auto'),
            secondary: const Icon(AppIcons.moveToInbox),
            title: Text(context.t('sm.auto')),
            subtitle: Text(context.t('sm.auto_sub')),
            value: SmartSort.autoNew,
            onChanged: (v) => unawaited(SmartSort.setSettings(auto: v)),
          ),
        ]),
      );

  Widget _main(BuildContext context) {
    final theme = Theme.of(context);
    final counts = SmartSort.counts();
    final cats = SmartFolderPrefs.arrange([
      for (final c in SmartTaxonomy.categoryIds)
        if ((counts[c] ?? 0) > 0 && c != SmartTaxonomy.other) c
    ]);
    final cols = SmartFolderPrefs.columns;
    final clutter = SmartSort.clutter().length;
    final hidden = SmartSort.hiddenRecords().length;
    final prog = SmartSort.progress.value;
    return ListView(
      padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('sm.status',
                      {'n': SmartSort.records.length, 'c': cats.length}),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: Gap.xs),
                Text(context.t('sm.status_sub'),
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: Gap.sm),
                if (prog != null) ...[
                  LinearProgressIndicator(
                      value: prog.total == 0 ? null : prog.done / prog.total),
                  const SizedBox(height: Gap.xs),
                  Text(context.t('sm.progress',
                      {'done': prog.done, 'total': prog.total})),
                ] else
                  FilledButton.icon(
                    key: const ValueKey('ss-run'),
                    onPressed: _run,
                    icon: const Icon(AppIcons.ai),
                    label: Text(context.t('sm.run')),
                  ),
              ],
            ),
          ),
        ),
        if (clutter > 0 || hidden > 0) ...[
          const SizedBox(height: Gap.md),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('ss-clutter'),
              leading: const Icon(AppIcons.cleanEmpty),
              title: Text(context.t('sm.clutter_title', {'n': clutter})),
              subtitle: Text(hidden > 0
                  ? context.t('sm.clutter_hidden', {'n': hidden})
                  : context.t('sm.clutter_sub')),
              trailing: const Icon(AppIcons.chevron),
              onTap: () => SmartClutterScreen.open(context),
            ),
          ),
        ],
        SectionHeader(context.t('sm.folders'),
            trailing: cats.isEmpty ? null : _layoutMenu(context, cats),
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xs)),
        if (cats.isEmpty)
          Text(context.t('sm.folders_empty'))
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Text(context.t('smo.hint'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          // Sütun değişimi TEK ADIMDA (kasma listesi m.1/6: ızgarada opaklık
          // ya da boy animasyonu yok).
          GridView.builder(
            key: const ValueKey('ss-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: _tileExtent(context, cols),
              crossAxisSpacing: Gap.sm,
              mainAxisSpacing: Gap.sm,
            ),
            itemCount: cats.length,
            itemBuilder: (context, i) => RepaintBoundary(
              child: _catTile(
                  context, cats[i], counts[cats[i]] ?? 0, cols, cats),
            ),
          ),
        ],
        SectionHeader(context.t('sm.settings'),
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
        _settingsCard(context, learning: true),
        const SizedBox(height: Gap.sm),
        TextButton.icon(
          key: const ValueKey('ss-disable'),
          onPressed: () => unawaited(SmartSort.setSettings(enabled: false)),
          icon: const Icon(AppIcons.close),
          label: Text(context.t('sm.disable')),
        ),
      ],
    );
  }

  /// Sütun menüsü: 2/3/4 sütun, sırala ve adlandır, varsayılana dön.
  Widget _layoutMenu(BuildContext context, List<String> cats) =>
      PopupMenuButton<Object>(
        key: const ValueKey('ss-layout'),
        tooltip: context.t('smo.layout'),
        icon: const Icon(AppIcons.viewComfy),
        onSelected: (v) {
          if (v is int) {
            unawaited(SmartFolderPrefs.setColumns(v));
          } else if (v == 'arrange') {
            unawaited(_arrange(cats));
          } else if (v == 'reset') {
            unawaited(SmartFolderPrefs.reset()
                .then((_) => SmartSort.invalidateLabels()));
          }
        },
        itemBuilder: (ctx) => [
          for (var n = SmartFolderPrefs.minColumns;
              n <= SmartFolderPrefs.maxColumns;
              n++)
            CheckedPopupMenuItem(
              value: n,
              checked: SmartFolderPrefs.columns == n,
              child: Text(ctx.t('smo.cols', {'n': n})),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'arrange',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.dragIndicator),
              title: Text(ctx.t('smo.arrange')),
            ),
          ),
          if (SmartFolderPrefs.hasCustomNames ||
              SmartFolderPrefs.order.isNotEmpty)
            PopupMenuItem(
              value: 'reset',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.reset),
                title: Text(ctx.t('smo.reset')),
              ),
            ),
        ],
      );

  /// Hücre yüksekliği yazı ölçeğiyle büyür (büyük yazıda taşma yok).
  static double _tileExtent(BuildContext context, int cols) {
    final sc = MediaQuery.textScalerOf(context);
    return switch (cols) {
      2 => math.max(84.0, 20 + sc.scale(14) * 1.3 * 2 + sc.scale(12) * 1.4),
      3 => math.max(
          100.0, 20 + 26 + 4 + sc.scale(12) * 1.3 * 2 + sc.scale(11) * 1.4),
      _ => math.max(
          92.0, 20 + 22 + 4 + sc.scale(11) * 1.3 * 2 + sc.scale(11) * 1.4),
    };
  }

  Widget _catTile(
      BuildContext context, String cat, int n, int cols, List<String> cats) {
    final theme = Theme.of(context);
    final color = SmartCatStyle.color(cat);
    final label = SmartCatStyle.label(context, cat);
    if (cols >= 3) {
      final small = cols >= 4;
      return Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          key: ValueKey('ss-cat-$cat'),
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => unawaited(_openCat(cat)),
          onLongPress: () => unawaited(_tileMenu(cat, cats)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.xs, vertical: Gap.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(SmartCatStyle.icon(cat),
                    color: color, size: small ? 22 : 26),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: (small
                            ? theme.textTheme.labelSmall
                            : theme.textTheme.labelMedium)
                        ?.copyWith(fontWeight: FontWeight.w600, height: 1.2)),
                Text('$n', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        key: ValueKey('ss-cat-$cat'),
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => unawaited(_openCat(cat)),
        onLongPress: () => unawaited(_tileMenu(cat, cats)),
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm),
          child: Row(children: [
            Icon(SmartCatStyle.icon(cat), color: color),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge),
                  Text('$n', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Akıllı klasör listesinin başındaki öğrenme ipucu.
class _FixHint extends StatelessWidget {
  const _FixHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xs),
      child: Row(children: [
        Icon(AppIcons.rule,
            size: AppIcons.small, color: theme.colorScheme.primary),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(context.t('smf.list_hint'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ]),
    );
  }
}

/// "Sırala ve adlandır": tutamaçtan sürükle, kalemle yeniden adlandır.
class _ArrangeSheet extends StatefulWidget {
  final List<String> cats;
  final Future<void> Function(String cat) onRename;

  const _ArrangeSheet({required this.cats, required this.onRename});

  @override
  State<_ArrangeSheet> createState() => _ArrangeSheetState();
}

class _ArrangeSheetState extends State<_ArrangeSheet> {
  late final List<String> _order = [...widget.cats];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(context.t('smo.arrange')),
              subtitle: Text(context.t('smo.arrange_sub')),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListenableBuilder(
                listenable: SmartFolderPrefs.revision,
                builder: (context, _) => ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  onReorderStart: (_) => AppHaptics.selection(),
                  itemCount: _order.length,
                  // onReorderItem: [to] çıkarılan öğeye göre düzeltilmiş gelir.
                  onReorderItem: (from, to) {
                    if (from == to) return;
                    setState(() {
                      final c = _order.removeAt(from);
                      _order.insert(to, c);
                    });
                    unawaited(SmartFolderPrefs.setOrder(List.of(_order)));
                  },
                  itemBuilder: (context, i) {
                    final cat = _order[i];
                    return ListTile(
                      key: ValueKey('smo-row-$cat'),
                      leading: Icon(SmartCatStyle.icon(cat),
                          color: SmartCatStyle.color(cat)),
                      title: Text(SmartCatStyle.label(context, cat),
                          style: theme.textTheme.bodyLarge),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: context.t('smo.rename'),
                          icon: const Icon(AppIcons.rename),
                          onPressed: () => unawaited(widget.onRename(cat)),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(Gap.sm),
                            child: Icon(AppIcons.dragHandle),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
