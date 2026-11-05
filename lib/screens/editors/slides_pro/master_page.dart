import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/pptx/pro/pptx_master_ops.dart';
import '../../../services/pptx/pro/pptx_package.dart';
import '../../../services/pptx/pro/pptx_templates.dart';
import '../../../widgets/app_action_sheet.dart';
import '../../../widgets/app_dialog.dart';
import 'pro_common.dart';

typedef _MasterModel = (List<PptxMasterInfo>, PptxThemeInfo?, (int, int));

_MasterModel _read(PptxPackage pkg) =>
    (PptxMasterOps.masters(pkg), PptxMasterOps.theme(pkg), pkg.slideSize());

/// İzolata giden okuyucu yalnız [part]'ı yakalar (durum nesnesini değil).
(List<PptxPlaceholderInfo>, String, (int, int)) Function(PptxPackage)
    _readLayout(String part) => (pkg) => (
          PptxMasterOps.placeholders(pkg, part),
          pkg.xml(part)?.findAllElements('p:cSld').firstOrNull?.getAttribute('name') ?? '',
          pkg.slideSize(),
        );

const _fontChoices = [
  'Calibri', 'Calibri Light', 'Arial', 'Arial Black', 'Segoe UI', 'Verdana',
  'Trebuchet MS', 'Century Gothic', 'Georgia', 'Times New Roman', 'Cambria',
];

/// **Faz 38 / madde 1 — Ana slayt ve yerleşimler.** Tema renkleri/yazı
/// tipleri, ana slayt metin stili ve arka planı, yerleşim listesi; yerleşime
/// dokununca yer tutucu düzenleyici ([LayoutEditPage]).
class SlidesMasterPage extends StatefulWidget {
  final Uint8List bytes;
  final SlidesProApply apply;
  const SlidesMasterPage({super.key, required this.bytes, required this.apply});

  @override
  State<SlidesMasterPage> createState() => _SlidesMasterPageState();
}

class _SlidesMasterPageState extends State<SlidesMasterPage> {
  late Uint8List _bytes = widget.bytes;
  _MasterModel? _m;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final m = await PptxPro.query(_bytes, _read);
    if (mounted) setState(() => _m = m);
  }

  Future<void> _run(PptxOp op) async {
    if (_busy) return;
    setState(() => _busy = true);
    final next = await widget.apply(op);
    if (!mounted) return;
    if (next != null) {
      _bytes = next;
      await _reload();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _gallery() async {
    final id = await showTemplateGallery(context);
    if (id != null) await _run(PptxTemplates.apply(id));
  }

  Future<void> _font(bool major) async {
    final t = _m?.$2;
    if (t == null) return;
    final pick = await showAppActionSheet<String>(context,
        title: context.t(major ? 'sp.font_major' : 'sp.font_minor'),
        groups: [
          AppActionGroup(actions: [
            for (final f in _fontChoices)
              AppAction(
                  value: f,
                  icon: (major ? t.major : t.minor) == f
                      ? AppIcons.check
                      : AppIcons.fontDownload,
                  label: f),
          ]),
        ]);
    if (pick == null) return;
    await _run(PptxMasterOps.setThemeFonts(
        major ? pick : t.major, major ? t.minor : pick));
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('sp.master')),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: m == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ListTile(
                  key: const ValueKey('sp-gallery'),
                  leading: const Icon(AppIcons.autoAwesomeMosaic),
                  title: Text(context.t('sp.templates')),
                  subtitle: Text(context.t('sp.templates_hint')),
                  onTap: _gallery,
                ),
                const Divider(),
                _header(context.t('sp.theme_colors')),
                if (m.$2 != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final slot in kThemeSlots)
                        _swatch(slot, m.$2!.colors[slot] ?? '000000'),
                    ]),
                  ),
                ListTile(
                  leading: const Icon(AppIcons.title),
                  title: Text(context.t('sp.font_major')),
                  subtitle: Text(m.$2?.major ?? '—'),
                  onTap: () => _font(true),
                ),
                ListTile(
                  leading: const Icon(AppIcons.textFields),
                  title: Text(context.t('sp.font_minor')),
                  subtitle: Text(m.$2?.minor ?? '—'),
                  onTap: () => _font(false),
                ),
                const Divider(),
                _header(context.t('sp.master_style')),
                if (m.$1.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(AppIcons.formatSize),
                    title: Text(context.t('sp.title_size')),
                    subtitle: Text('${m.$1.first.titlePt?.round() ?? '—'} pt'),
                    onTap: () async {
                      final v = await promptNumber(
                          context, context.t('sp.title_size'),
                          initial: m.$1.first.titlePt, min: 6, max: 200);
                      if (v != null) {
                        await _run(PptxMasterOps.setMasterTextStyle(titlePt: v));
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(AppIcons.formatSize),
                    title: Text(context.t('sp.body_size')),
                    subtitle: Text('${m.$1.first.bodyPt?.round() ?? '—'} pt'),
                    onTap: () async {
                      final v = await promptNumber(
                          context, context.t('sp.body_size'),
                          initial: m.$1.first.bodyPt, min: 6, max: 200);
                      if (v != null) {
                        await _run(PptxMasterOps.setMasterTextStyle(bodyPt: v));
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(AppIcons.formatColorFill),
                    title: Text(context.t('sp.master_bg')),
                    trailing: m.$1.first.background == null
                        ? null
                        : _dot(m.$1.first.background!),
                    onTap: () async {
                      final hex = await pickHexColor(context,
                          current: m.$1.first.background);
                      if (hex != null) {
                        await _run(PptxMasterOps.setMasterBackground(hex));
                      }
                    },
                  ),
                ],
                const Divider(),
                _header(context.t('sp.layouts')),
                for (final (mi, master) in m.$1.indexed)
                  for (final l in master.layouts)
                    ListTile(
                      key: ValueKey('sp-layout-${l.part}'),
                      leading: SizedBox(
                        width: 72,
                        child: SlideSchematic(
                          widthEmu: m.$3.$1,
                          heightEmu: m.$3.$2,
                          boxes: [
                            for (final p in l.placeholders)
                              (Rect.fromLTWH(p.x.toDouble(), p.y.toDouble(),
                                  p.cx.toDouble(), p.cy.toDouble()), ''),
                          ],
                        ),
                      ),
                      title: Text(l.name.isEmpty ? l.part.split('/').last : l.name),
                      subtitle: m.$1.length > 1
                          ? Text(context.t('sp.master_n', {'n': mi + 1}))
                          : null,
                      trailing: const Icon(AppIcons.chevron),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LayoutEditPage(
                            bytes: _bytes,
                            part: l.part,
                            apply: (op) async {
                              final next = await widget.apply(op);
                              if (next != null) _bytes = next;
                              return next;
                            },
                          ),
                        ));
                        await _reload();
                      },
                    ),
              ],
            ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(t,
            style: context.type.small
                .copyWith(color: Theme.of(context).colorScheme.primary)),
      );

  Widget _dot(String hex) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: hexColor(hex),
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      );

  Widget _swatch(String slot, String hex) => Tooltip(
        message: context.t('sp.slot_$slot'),
        child: InkWell(
          key: ValueKey('sp-slot-$slot'),
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final v = await pickHexColor(context, current: hex);
            if (v != null) await _run(PptxMasterOps.setThemeColors({slot: v}));
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 28,
              decoration: BoxDecoration(
                color: hexColor(hex),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            Text(context.t('sp.slot_$slot'), style: context.type.micro),
          ]),
        ),
      );
}

/// Şablon galerisi (8 sade tema). Seçilen şablonun kimliği; [suggested]
/// verilirse ilk sırada "önerilen" rozetiyle gösterilir.
Future<String?> showTemplateGallery(BuildContext context,
    {List<String>? suggested}) {
  final order = suggested ?? [for (final t in PptxTemplates.all) t.id];
  return showAppSheet<String>(
    context,
    title: context.t('sp.templates'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: [
          for (final (i, id) in order.indexed)
            _TemplateCard(
              tpl: PptxTemplates.byId(id),
              suggested: suggested != null && i == 0,
              onTap: () => Navigator.pop(ctx, id),
            ),
        ],
      ),
    ),
  );
}

class _TemplateCard extends StatelessWidget {
  final SlideTemplate tpl;
  final bool suggested;
  final VoidCallback onTap;
  const _TemplateCard(
      {required this.tpl, required this.suggested, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = hexColor(tpl.background);
    final fg = hexColor(tpl.title);
    final body = hexColor(tpl.colors['dk1'] ?? '000000');
    return Semantics(
      button: true,
      label: context.t(tpl.labelKey),
      child: InkWell(
        key: ValueKey('sp-tpl-${tpl.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: suggested ? scheme.primary : scheme.outlineVariant,
                      width: suggested ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aa',
                        style: context.type.heading.copyWith(
                            color: fg, fontFamily: tpl.major)),
                    Container(height: 2, width: 28, color: fg),
                    const SizedBox(height: 4),
                    Text('• ${context.t('sp.tpl_sample')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.micro.copyWith(color: body)),
                    const Spacer(),
                    Row(children: [
                      for (var k = 1; k <= 6; k++)
                        Expanded(
                          child: Container(
                              height: 6,
                              color: hexColor(tpl.colors['accent$k'] ?? '000000')),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              suggested
                  ? '${context.t(tpl.labelKey)} · ${context.t('sp.suggested')}'
                  : context.t(tpl.labelKey),
              textAlign: TextAlign.center,
              style: context.type.small,
            ),
          ],
        ),
      ),
    );
  }
}

/// Yerleşimin yer tutucu düzenleyicisi: dokun → seç, sürükle → taşı, sağ alt
/// köşeyi sürükle → boyutlandır (bırakınca yazılır). Ekle / sil / adlandır /
/// kopyala.
class LayoutEditPage extends StatefulWidget {
  final Uint8List bytes;
  final String part;
  final SlidesProApply apply;
  const LayoutEditPage(
      {super.key, required this.bytes, required this.part, required this.apply});

  @override
  State<LayoutEditPage> createState() => _LayoutEditPageState();
}

class _LayoutEditPageState extends State<LayoutEditPage> {
  late Uint8List _bytes = widget.bytes;
  List<PptxPlaceholderInfo> _ph = const [];
  String _name = '';
  (int, int) _size = (12192000, 6858000);
  int? _sel;
  Rect? _drag; // sürüklenen kutu (EMU)
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final r = await PptxPro.query(_bytes, _readLayout(widget.part));
    if (!mounted) return;
    setState(() {
      _ph = r.$1;
      _name = r.$2;
      _size = r.$3;
      if (_sel != null && _sel! >= _ph.length) _sel = null;
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

  Rect _rectOf(PptxPlaceholderInfo p) => Rect.fromLTWH(
      p.x.toDouble(), p.y.toDouble(), p.cx.toDouble(), p.cy.toDouble());

  @override
  Widget build(BuildContext context) {
    final sel = _sel == null ? null : _ph[_sel!];
    return Scaffold(
      appBar: AppBar(
        title: Text(_name.isEmpty ? context.t('sp.layout') : _name),
        actions: [
          IconButton(
            tooltip: context.t('sp.rename'),
            icon: const Icon(AppIcons.rename),
            onPressed: () async {
              final v = await showAppPrompt(context,
                  title: context.t('sp.rename'), initial: _name);
              if (v != null) await _run(PptxMasterOps.renameLayout(widget.part, v));
            },
          ),
          IconButton(
            tooltip: context.t('sp.layout_dup'),
            icon: const Icon(AppIcons.copy),
            onPressed: () async {
              await _run(PptxMasterOps.duplicateLayout(
                  widget.part, '$_name (${context.t('sp.copy_suffix')})'));
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(builder: (context, c) {
            final k = c.maxWidth / _size.$1;
            final boxes = [
              for (final (i, p) in _ph.indexed)
                (i == _sel && _drag != null ? _drag! : _rectOf(p),
                    context.t('sp.ph_${p.type}')),
            ];
            Offset emu(Offset local) => local / k;
            return GestureDetector(
              key: const ValueKey('sp-layout-canvas'),
              onTapUp: (d) {
                final at = emu(d.localPosition);
                int? hit;
                for (var i = boxes.length - 1; i >= 0; i--) {
                  if (boxes[i].$1.contains(at)) {
                    hit = i;
                    break;
                  }
                }
                setState(() => _sel = hit);
              },
              onPanStart: (d) {
                if (_sel == null) return;
                final r = _rectOf(_ph[_sel!]);
                if (!r.inflate(40 / k).contains(emu(d.localPosition))) return;
                setState(() => _drag = r);
              },
              onPanUpdate: (d) {
                final r = _drag;
                if (r == null) return;
                final delta = d.delta / k;
                final at = emu(d.localPosition);
                final nearCorner = (at - r.bottomRight).distance < 60 / k;
                setState(() => _drag = nearCorner
                    ? Rect.fromLTWH(r.left, r.top, (r.width + delta.dx).clamp(20 / k, _size.$1.toDouble()),
                        (r.height + delta.dy).clamp(20 / k, _size.$2.toDouble()))
                    : r.shift(delta));
              },
              onPanEnd: (_) async {
                final r = _drag;
                final s = _sel;
                if (r == null || s == null) return;
                await _run(PptxMasterOps.setPlaceholderFrame(widget.part,
                    _ph[s].id, r.left.round(), r.top.round(), r.width.round(),
                    r.height.round()));
                if (mounted) setState(() => _drag = null);
              },
              child: SlideSchematic(
                widthEmu: _size.$1,
                heightEmu: _size.$2,
                boxes: boxes,
                selected: _sel,
              ),
            );
          }),
        ),
        Text(context.t('sp.layout_hint'),
            textAlign: TextAlign.center, style: context.type.small),
        if (sel != null)
          ListTile(
            title: Text(sel.name),
            subtitle: Text(context.t('sp.ph_${sel.type}') +
                (sel.inherited ? ' · ${context.t('sp.inherited')}' : '')),
            trailing: IconButton(
              tooltip: context.t('common.delete'),
              icon: const Icon(AppIcons.delete),
              onPressed: () async {
                await _run(PptxMasterOps.removePlaceholder(widget.part, sel.id));
                if (mounted) setState(() => _sel = null);
              },
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('sp-add-ph'),
        icon: const Icon(AppIcons.add),
        label: Text(context.t('sp.add_ph')),
        onPressed: () async {
          final t = await showAppActionSheet<String>(context,
              title: context.t('sp.add_ph'),
              groups: [
                AppActionGroup(actions: [
                  for (final t in kPlaceholderTypes)
                    AppAction(
                        value: t,
                        icon: AppIcons.addCircleOutline,
                        label: context.t('sp.ph_$t')),
                ]),
              ]);
          if (t != null) await _run(PptxMasterOps.addPlaceholder(widget.part, t));
        },
      ),
    );
  }
}
