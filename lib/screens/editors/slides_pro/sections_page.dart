import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../services/pptx/pro/pptx_deck_ops.dart';
import '../../../services/pptx/pro/pptx_package.dart';
import '../../../widgets/app_action_sheet.dart';
import '../../../widgets/app_dialog.dart';
import 'pro_common.dart';

(List<SlideSection>, List<SlideCustomShow>) _read(PptxPackage pkg) =>
    (PptxDeckOps.sections(pkg), PptxDeckOps.customShows(pkg));

/// **Faz 38 / madde 7 — bölümler ve özel gösteriler.** "Oynat" seçilen
/// gösterinin slayt sıralarıyla sayfayı kapatır (editör oynatır).
class SlideSectionsPage extends StatefulWidget {
  final Uint8List bytes;

  /// Slayt başına kısa ad (başlık ya da "Slayt n").
  final List<String> labels;
  final SlidesProApply apply;
  const SlideSectionsPage(
      {super.key, required this.bytes, required this.labels, required this.apply});

  @override
  State<SlideSectionsPage> createState() => _SlideSectionsPageState();
}

class _SlideSectionsPageState extends State<SlideSectionsPage> {
  late Uint8List _bytes = widget.bytes;
  List<SlideSection> _secs = const [];
  List<SlideCustomShow> _shows = const [];
  bool _busy = false, _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final r = await PptxPro.query(_bytes, _read);
    if (!mounted) return;
    setState(() {
      _secs = r.$1;
      _shows = r.$2;
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

  String _label(int i) =>
      i < widget.labels.length ? '${i + 1}. ${widget.labels[i]}' : '${i + 1}';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('sp.sections_title')),
          bottom: TabBar(tabs: [
            Tab(text: context.t('sp.sections')),
            Tab(text: context.t('sp.custom_shows')),
          ]),
        ),
        body: Column(children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [_sectionsTab(), _showsTab()]),
          ),
        ]),
      ),
    );
  }

  Widget _sectionsTab() {
    final n = widget.labels.length;
    return Scaffold(
      body: _secs.isEmpty
          ? Center(
              child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.t('sp.no_sections'), textAlign: TextAlign.center),
            ))
          : ListView(children: [
              for (final (i, s) in _secs.indexed) ...[
                ListTile(
                  key: ValueKey('sp-sec-$i'),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  leading: const Icon(AppIcons.bookmark),
                  title: Text(s.name),
                  subtitle: Text(context.t('sp.slides_n', {'n': s.count})),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: context.t('sp.move_up'),
                      icon: const Icon(AppIcons.arrowUp),
                      onPressed: i == 0 ? null : () => _run(PptxDeckOps.moveSection(i, -1)),
                    ),
                    IconButton(
                      tooltip: context.t('sp.move_down'),
                      icon: const Icon(AppIcons.arrowDown),
                      onPressed: i == _secs.length - 1
                          ? null
                          : () => _run(PptxDeckOps.moveSection(i, 1)),
                    ),
                    IconButton(
                      tooltip: context.t('sp.rename'),
                      icon: const Icon(AppIcons.rename),
                      onPressed: () async {
                        final v = await showAppPrompt(context,
                            title: context.t('sp.rename'), initial: s.name);
                        if (v != null) await _run(PptxDeckOps.renameSection(i, v));
                      },
                    ),
                    IconButton(
                      tooltip: context.t('sp.delete'),
                      icon: const Icon(AppIcons.delete),
                      onPressed: () => _run(PptxDeckOps.removeSection(i)),
                    ),
                  ]),
                ),
                for (var k = s.start; k < s.start + s.count && k < n; k++)
                  ListTile(dense: true, title: Text(_label(k))),
              ],
            ]),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('sp-add-section'),
        icon: const Icon(AppIcons.add),
        label: Text(context.t('sp.add_section')),
        onPressed: _busy || n == 0 ? null : _addSection,
      ),
    );
  }

  Future<void> _addSection() async {
    final start = await showAppActionSheet<int>(context,
        title: context.t('sp.section_start'),
        groups: [
          AppActionGroup(actions: [
            for (var i = 0; i < widget.labels.length; i++)
              AppAction(value: i, icon: AppIcons.slideshow, label: _label(i)),
          ]),
        ]);
    if (start == null || !mounted) return;
    final name = await showAppPrompt(context,
        title: context.t('sp.section_name'),
        initial: context.t('sp.section_default', {'n': _secs.length + 1}));
    if (name == null || !mounted) return;
    await _run(PptxDeckOps.addSection(start, name,
        defaultName: context.t('sp.section_first')));
  }

  Widget _showsTab() {
    return Scaffold(
      body: _shows.isEmpty
          ? Center(
              child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.t('sp.no_shows'), textAlign: TextAlign.center),
            ))
          : ListView(children: [
              for (final s in _shows)
                ListTile(
                  key: ValueKey('sp-show-${s.name}'),
                  leading: const Icon(AppIcons.playlistPlay),
                  title: Text(s.name),
                  subtitle: Text(context.t('sp.slides_n', {'n': s.slides.length})),
                  onTap: () => _editShow(s),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      key: ValueKey('sp-play-${s.name}'),
                      tooltip: context.t('sl.play'),
                      icon: const Icon(AppIcons.play),
                      onPressed: s.slides.isEmpty ? null : () => Navigator.pop(context, s.slides),
                    ),
                    IconButton(
                      tooltip: context.t('sp.delete'),
                      icon: const Icon(AppIcons.delete),
                      onPressed: () => _run(PptxDeckOps.removeCustomShow(s.name)),
                    ),
                  ]),
                ),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('sp-add-show'),
        icon: const Icon(AppIcons.add),
        label: Text(context.t('sp.add_show')),
        onPressed: _busy || widget.labels.isEmpty ? null : () => _editShow(null),
      ),
    );
  }

  Future<void> _editShow(SlideCustomShow? show) async {
    var name = show?.name;
    if (name == null) {
      name = await showAppPrompt(context,
          title: context.t('sp.show_name'),
          initial: context.t('sp.show_default', {'n': _shows.length + 1}));
      if (name == null || !mounted) return;
    }
    final picked = <int>{...?show?.slides};
    final ok = await showAppSheet<bool>(
      context,
      title: name,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < widget.labels.length; i++)
            CheckboxListTile(
              key: ValueKey('sp-show-pick-$i'),
              value: picked.contains(i),
              title: Text(_label(i)),
              onChanged: (v) => set(() {
                if (v == true) {
                  picked.add(i);
                } else {
                  picked.remove(i);
                }
              }),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              key: const ValueKey('sp-show-save'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('sp.apply')),
            ),
          ),
        ]),
      ),
    );
    if (ok != true) return;
    await _run(PptxDeckOps.setCustomShow(name, picked.toList()..sort()));
  }
}

/// Sıralayıcı için: slayt sırası → başlayan bölümün adı.
Map<int, String> sectionStarts(PptxPackage pkg) => {
      for (final s in PptxDeckOps.sections(pkg)) s.start: s.name,
    };
