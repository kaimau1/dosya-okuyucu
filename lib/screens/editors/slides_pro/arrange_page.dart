import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/pptx/pro/pptx_arrange_ops.dart';
import '../../../services/pptx/pro/pptx_package.dart';
import '../../../widgets/app_action_sheet.dart';
import '../../../widgets/app_dialog.dart';
import 'pro_common.dart';

(List<SlideLayer>, List<SlideAnimStep>) Function(PptxPackage) _read(int slide) =>
    (pkg) => (PptxArrangeOps.layers(pkg, slide), PptxArrangeOps.animations(pkg, slide));

/// **Faz 38 / madde 6 — katman paneli + hizala/dağıt + animasyon sırası.**
/// Katmanlar: üstte öndeki şekil; sürükle → z sırası, göz → gizle, dokun →
/// seç (çoklu), uzun bas → adlandır. Seçime hizalama/dağıtma çubuğu.
/// Animasyonlar: tıklama adımları; sürükle → sıra, sil, ekle.
class SlideArrangePage extends StatefulWidget {
  final Uint8List bytes;
  final int slide;
  final SlidesProApply apply;
  final int initialTab;
  const SlideArrangePage({
    super.key,
    required this.bytes,
    required this.slide,
    required this.apply,
    this.initialTab = 0,
  });

  @override
  State<SlideArrangePage> createState() => _SlideArrangePageState();
}

class _SlideArrangePageState extends State<SlideArrangePage> {
  late Uint8List _bytes = widget.bytes;
  List<SlideLayer> _layers = const [];
  List<SlideAnimStep> _anims = const [];
  final Set<int> _sel = {};
  bool _busy = false, _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final r = await PptxPro.query(_bytes, _read(widget.slide));
    if (!mounted) return;
    setState(() {
      _layers = r.$1;
      _anims = r.$2;
      _sel.removeWhere((id) => !_layers.any((l) => l.id == id));
      _loaded = true;
    });
  }

  Future<void> _run(PptxOp op) async {
    if (_busy) return;
    setState(() => _busy = true);
    final next = await widget.apply(op);
    if (next != null) {
      _bytes = next;
      await _reload();
    }
    if (mounted) setState(() => _busy = false);
  }

  String _nameOf(int id) {
    final l = _layers.where((l) => l.id == id).firstOrNull;
    return l == null || l.name.isEmpty ? '#$id' : l.name;
  }

  IconData _kindIcon(String kind) => switch (kind) {
        'pic' => AppIcons.image,
        'grpSp' => AppIcons.layers,
        'graphicFrame' => AppIcons.tableView,
        'cxnSp' => AppIcons.lineTool,
        _ => AppIcons.rectTool,
      };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('sp.arrange_title', {'n': widget.slide + 1})),
          bottom: TabBar(tabs: [
            Tab(text: context.t('sp.layers')),
            Tab(text: context.t('sp.animations')),
          ]),
        ),
        body: Column(children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [_layersTab(), _animTab()]),
          ),
        ]),
      ),
    );
  }

  // ── Katmanlar ─────────────────────────────────────────────────────────────

  Widget _layersTab() {
    // Görünüm: en öndeki üstte → z listesinin tersi.
    final rows = _layers.reversed.toList();
    return Column(children: [
      Expanded(
        child: rows.isEmpty
            ? Center(child: Text(context.t('sp.no_shapes')))
            : ReorderableListView.builder(
                key: const ValueKey('sp-layers'),
                itemCount: rows.length,
                onReorderItem: (from, to) {
                  final l = rows[from];
                  // Görünüm sırası → z sırası (ters).
                  _run(PptxArrangeOps.moveLayer(
                      widget.slide, l.id, rows.length - 1 - to));
                },
                itemBuilder: (context, i) {
                  final l = rows[i];
                  final on = _sel.contains(l.id);
                  return ListTile(
                    key: ValueKey('sp-layer-${l.id}'),
                    selected: on,
                    leading: Icon(_kindIcon(l.kind)),
                    title: Text(l.name.isEmpty ? '#${l.id}' : l.name,
                        style: l.hidden
                            ? context.type.body.copyWith(
                                color: Theme.of(context).colorScheme.outline)
                            : null),
                    subtitle: l.frame == null ? Text(context.t('sp.inherited')) : null,
                    onTap: () => setState(() {
                      if (on) {
                        _sel.remove(l.id);
                      } else {
                        _sel.add(l.id);
                      }
                    }),
                    onLongPress: () async {
                      final v = await showAppPrompt(context,
                          title: context.t('sp.rename'), initial: l.name);
                      if (v != null) await _run(PptxArrangeOps.rename(widget.slide, l.id, v));
                    },
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        key: ValueKey('sp-eye-${l.id}'),
                        tooltip: context.t(l.hidden ? 'sp.show' : 'sp.hide'),
                        icon: Icon(l.hidden ? AppIcons.hiddenOff : AppIcons.hidden),
                        onPressed: () => _run(
                            PptxArrangeOps.setHidden(widget.slide, l.id, !l.hidden)),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Icon(AppIcons.dragHandle),
                      ),
                    ]),
                  );
                },
              ),
      ),
      _alignBar(),
    ]);
  }

  Widget _alignBar() {
    final ids = [for (final l in _layers) if (_sel.contains(l.id)) l.id];
    final any = ids.isNotEmpty && !_busy;
    final three = ids.length >= 3 && !_busy;
    Widget b(IconData icon, String key, VoidCallback? on) => IconButton(
          key: ValueKey('sp-$key'),
          tooltip: context.t('sp.$key'),
          icon: Icon(icon),
          onPressed: on,
        );
    return SafeArea(
      top: false,
      child: Material(
        elevation: 3,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                  ids.isEmpty
                      ? context.t('sp.align_hint')
                      : context.t('sp.selected_n', {'n': ids.length}),
                  style: context.type.small),
            ),
            for (final (m, icon) in [
              (SlideAlign.left, AppIcons.formatAlignLeft),
              (SlideAlign.hcenter, AppIcons.formatAlignCenter),
              (SlideAlign.right, AppIcons.formatAlignRight),
              (SlideAlign.top, AppIcons.borderTop),
              (SlideAlign.vcenter, AppIcons.alignHorizontalLeft),
              (SlideAlign.bottom, AppIcons.borderBottom),
            ])
              b(icon, 'align_${m.name}',
                  any ? () => _run(PptxArrangeOps.align(widget.slide, ids, m)) : null),
            b(AppIcons.swapHoriz, 'dist_h',
                three ? () => _run(PptxArrangeOps.distribute(widget.slide, ids, horizontal: true)) : null),
            b(AppIcons.swapVert, 'dist_v',
                three ? () => _run(PptxArrangeOps.distribute(widget.slide, ids, horizontal: false)) : null),
          ]),
        ),
      ),
    );
  }

  // ── Animasyonlar ──────────────────────────────────────────────────────────

  String _effectName(SlideAnimStep s) {
    final key = switch ((s.presetClass, s.presetId)) {
      ('entr', 1) => 'sp.fx_appear',
      ('entr', 10) => 'sp.fx_fade',
      ('entr', 22) => 'sp.fx_wipe',
      ('entr', 53) => 'sp.fx_zoom',
      ('entr', _) => 'sp.fx_entr',
      ('exit', _) => 'sp.fx_exit',
      ('emph', _) => 'sp.fx_emph',
      ('path', _) => 'sp.fx_path',
      _ => 'sp.fx_other',
    };
    return context.t(key);
  }

  Widget _animTab() {
    return Scaffold(
      body: _anims.isEmpty
          ? Center(child: Text(context.t('sp.no_anims')))
          : ReorderableListView.builder(
              key: const ValueKey('sp-anims'),
              itemCount: _anims.length,
              onReorderItem: (from, to) {
                _run(PptxArrangeOps.moveAnimation(widget.slide, from, to));
              },
              itemBuilder: (context, i) {
                final s = _anims[i];
                return ListTile(
                  key: ValueKey('sp-anim-$i'),
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(s.shapeIds.map(_nameOf).join(', ')),
                  subtitle: Text(_effectName(s)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: context.t('sp.delete'),
                      icon: const Icon(AppIcons.delete),
                      onPressed: () =>
                          _run(PptxArrangeOps.removeAnimation(widget.slide, i)),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Icon(AppIcons.dragHandle),
                    ),
                  ]),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('sp-add-anim'),
        icon: const Icon(AppIcons.add),
        label: Text(context.t('sp.add_anim')),
        onPressed: _layers.isEmpty || _busy ? null : _addAnim,
      ),
    );
  }

  Future<void> _addAnim() async {
    final shape = await showAppActionSheet<int>(context,
        title: context.t('sp.anim_pick_shape'),
        groups: [
          AppActionGroup(actions: [
            for (final l in _layers.reversed)
              AppAction(value: l.id, icon: _kindIcon(l.kind), label: _nameOf(l.id)),
          ]),
        ]);
    if (shape == null || !mounted) return;
    final fx = await showAppActionSheet<SlideEntrance>(context,
        title: context.t('sp.anim_pick_fx'),
        groups: [
          AppActionGroup(actions: [
            for (final e in SlideEntrance.values)
              AppAction(value: e, icon: AppIcons.autoAwesomeMotion, label: context.t('sp.fx_${e.name}')),
          ]),
        ]);
    if (fx == null) return;
    await _run(PptxArrangeOps.addEntrance(widget.slide, shape, fx));
  }
}
