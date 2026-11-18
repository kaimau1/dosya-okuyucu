import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/smart_sort_taxonomy.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/fm/smart_cat_style.dart';
import '../../widgets/section_header.dart';
import 'category_screen.dart';
import 'smart_clutter_screen.dart';

/// **Akıllı düzen** ana ekranı (2026-11-18): aç/kapat ve gizlilik metni,
/// "Şimdi düzenle", akıllı klasörler (AI kategorileri, dosyalar yerinde),
/// Ayıkla kapısı ve ayarlar. Bkz. [SmartSort].
class SmartSortScreen extends StatefulWidget {
  const SmartSortScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SmartSortScreen()));

  @override
  State<SmartSortScreen> createState() => _SmartSortScreenState();
}

class _SmartSortScreenState extends State<SmartSortScreen> {
  bool _ready = false;

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
    final msg = r.stoppedBy != null
        ? s.t('sm.stopped', {'n': r.processed})
        : (r.processed == 0
            ? s.t('sm.nothing_new')
            : s.t('sm.done', {'n': r.processed}));
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
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('sm.title'))),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: Listenable.merge(
                  [SmartSort.revision, SmartSort.progress]),
              builder: (context, _) => SmartSort.enabled
                  ? _main(context)
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

  Widget _settingsCard(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Column(children: [
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
    final cats = [
      for (final c in SmartTaxonomy.categoryIds)
        if ((counts[c] ?? 0) > 0 && c != SmartTaxonomy.other) c
    ];
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
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
        if (cats.isEmpty)
          Text(context.t('sm.folders_empty'))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisExtent: 84,
              crossAxisSpacing: Gap.sm,
              mainAxisSpacing: Gap.sm,
            ),
            itemCount: cats.length,
            itemBuilder: (context, i) => RepaintBoundary(
              child: _catTile(context, cats[i], counts[cats[i]] ?? 0),
            ),
          ),
        SectionHeader(context.t('sm.settings'),
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
        _settingsCard(context),
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

  Widget _catTile(BuildContext context, String cat, int n) {
    final theme = Theme.of(context);
    final color = SmartCatStyle.color(cat);
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        key: ValueKey('ss-cat-$cat'),
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => unawaited(_openCat(cat)),
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
                  Text(SmartCatStyle.label(context, cat),
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
