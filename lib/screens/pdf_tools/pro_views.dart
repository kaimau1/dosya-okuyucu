part of '../pdf_tools_screen.dart';

/// Pro araç levhasındaki bir satır.
class _ProTool {
  final String id;
  final IconData icon;
  final String title;
  final String? subtitle;
  const _ProTool(this.id, this.icon, this.title, [this.subtitle]);
}

/// Faz 39 araçları — gruplu. Yeni araç buraya bir satır + [_openProTools]
/// içinde bir dal.
const _proTools = <List<_ProTool>>[
  [
    _ProTool('dsign', AppIcons.pdfSignCert, 'pp.dsign', 'pp.dsign_sub'),
    _ProTool('dsign_list', AppIcons.draw, 'pp.dsign_list'),
  ],
  [
    _ProTool('redact', AppIcons.pdfRedact, 'pp.redact', 'pp.redact_sub'),
  ],
  [
    _ProTool('to_xlsx', AppIcons.pdfTable, 'pp.to_xlsx', 'pp.to_xlsx_sub'),
    _ProTool('to_docx', AppIcons.pdfToWord, 'pp.to_docx', 'pp.to_docx_sub'),
    _ProTool('pdfa', AppIcons.pdfArchive, 'pp.pdfa', 'pp.pdfa_sub'),
  ],
  [
    _ProTool('compare', AppIcons.pdfCompare, 'pp.compare', 'pp.compare_sub'),
  ],
  [
    _ProTool('permissions', AppIcons.pdfKey, 'pp.permissions', 'pp.permissions_sub'),
    _ProTool('outline', AppIcons.bookmarks, 'pp.outline', 'pp.outline_sub'),
    _ProTool('stamp', AppIcons.pdfStamp, 'pp.stamp', 'pp.stamp_sub'),
    _ProTool('numbering', AppIcons.formatListNumbered, 'pp.numbering', 'pp.numbering_sub'),
  ],
  [
    _ProTool('compress_hard', AppIcons.pdfCompressHard, 'pp.compress_hard',
        'pp.compress_hard_sub'),
  ],
];

class _ProToolsSheet extends StatelessWidget {
  const _ProToolsSheet();

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var g = 0; g < _proTools.length; g++) ...[
            if (g > 0) const Divider(height: 1),
            for (final t in _proTools[g])
              ListTile(
                leading: Icon(t.icon),
                title: Text(context.t(t.title)),
                subtitle:
                    t.subtitle == null ? null : Text(context.t(t.subtitle!)),
                onTap: () => Navigator.pop(context, t.id),
              ),
          ],
        ],
      );
}

// ── Dijital imza ──────────────────────────────────────────────────────────

class _DSignOptions {
  final bool pfx;
  final String name;
  final String reason;
  final String location;
  final bool visible;
  final bool lastPage;
  final bool exportCertificate;
  const _DSignOptions({
    required this.pfx,
    required this.name,
    required this.reason,
    required this.location,
    required this.visible,
    required this.lastPage,
    this.exportCertificate = false,
  });
}

class _DigitalSignSheet extends StatefulWidget {
  const _DigitalSignSheet({required this.initialName, required this.hasIdentity});

  final String initialName;
  final bool hasIdentity;

  @override
  State<_DigitalSignSheet> createState() => _DigitalSignSheetState();
}

class _DigitalSignSheetState extends State<_DigitalSignSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  final _reason = TextEditingController();
  final _location = TextEditingController();
  bool _pfx = false;
  bool _visible = true;
  bool _lastPage = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    _location.dispose();
    super.dispose();
  }

  _DSignOptions _options({bool export = false}) => _DSignOptions(
        pfx: _pfx,
        name: _name.text.trim(),
        reason: _reason.text.trim(),
        location: _location.text.trim(),
        visible: _visible,
        lastPage: _lastPage,
        exportCertificate: export,
      );

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = context.t('pp.dsign_name_needed'));
      return;
    }
    Navigator.pop(context, _options());
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('pp.dsign_source'),
                style: context.type.caption),
            const SizedBox(height: Gap.xs),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: false, label: Text(context.t('pp.dsign_self'))),
                ButtonSegment(
                    value: true, label: Text(context.t('pp.dsign_pfx'))),
              ],
              selected: {_pfx},
              onSelectionChanged: (v) => setState(() => _pfx = v.first),
            ),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: context.t('pp.dsign_name'), errorText: _error),
            ),
            TextField(
              controller: _reason,
              decoration:
                  InputDecoration(labelText: context.t('pp.dsign_reason')),
            ),
            TextField(
              controller: _location,
              decoration:
                  InputDecoration(labelText: context.t('pp.dsign_location')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _visible,
              onChanged: (v) => setState(() => _visible = v),
              title: Text(context.t('pp.dsign_visible')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _lastPage,
              onChanged: (v) => setState(() => _lastPage = v),
              title: Text(context.t('pp.dsign_last_page')),
            ),
            if (widget.hasIdentity && !_pfx)
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, _options(export: true)),
                icon: const Icon(AppIcons.share),
                label: Text(context.t('pp.dsign_export_cert')),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(AppIcons.pdfSignCert),
                label: Text(context.t('pp.dsign_go')),
              ),
            ),
          ],
        ),
      );
}

// ── İzinler ───────────────────────────────────────────────────────────────

class _PermOptions {
  final String owner;
  final String user;
  final Set<PdfAllow> allow;
  const _PermOptions(this.owner, this.user, this.allow);
}

class _PermissionsSheet extends StatefulWidget {
  const _PermissionsSheet({required this.initial});

  final Set<PdfAllow> initial;

  @override
  State<_PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends State<_PermissionsSheet> {
  late final Set<PdfAllow> _allow = {...widget.initial};
  final _owner = TextEditingController();
  final _user = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _owner.dispose();
    _user.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in PdfAllow.values)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _allow.contains(a),
                onChanged: (v) => setState(() => v ? _allow.add(a) : _allow.remove(a)),
                title: Text(context.t('pp.allow_${a.name}')),
              ),
            TextField(
              controller: _owner,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: context.t('pp.owner_password'), errorText: _error),
            ),
            TextField(
              controller: _user,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: context.t('pp.user_password'),
                  helperText: context.t('pp.user_password_hint')),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: FilledButton(
                onPressed: () {
                  if (_owner.text.isEmpty) {
                    setState(() => _error = context.t('pp.owner_needed'));
                    return;
                  }
                  Navigator.pop(context,
                      _PermOptions(_owner.text, _user.text, {..._allow}));
                },
                child: Text(context.t('common.ok')),
              ),
            ),
          ],
        ),
      );
}

// ── Yer imi düzenleyici ───────────────────────────────────────────────────

class _OutlineEditor extends StatefulWidget {
  const _OutlineEditor({
    required this.items,
    required this.pageCount,
    required this.suggestPage,
  });

  final List<PdfOutlineItem> items;
  final int pageCount;
  final int suggestPage;

  @override
  State<_OutlineEditor> createState() => _OutlineEditorState();
}

class _OutlineEditorState extends State<_OutlineEditor> {
  late final List<PdfOutlineItem> _items = List.of(widget.items);

  Future<void> _edit(int? index) async {
    final item = index == null
        ? PdfOutlineItem('', widget.suggestPage, 0)
        : _items[index];
    final title = await showAppPrompt(
      context,
      title: context.t(index == null ? 'pp.outline_add' : 'pp.outline_rename'),
      label: context.t('pp.outline_title'),
      initial: item.title,
    );
    if (title == null || !mounted) return;
    final pageText = await showAppPrompt(
      context,
      title: context.t('pp.outline_page', {'count': widget.pageCount}),
      initial: '${item.page + 1}',
    );
    if (!mounted) return;
    final page = (int.tryParse(pageText ?? '') ?? item.page + 1)
            .clamp(1, widget.pageCount) -
        1;
    setState(() {
      final next = item.copyWith(title: title, page: page.toInt());
      if (index == null) {
        _items.add(next);
      } else {
        _items[index] = next;
      }
    });
  }

  void _indent(int i, int delta) {
    final max = i == 0 ? 0 : _items[i - 1].level + 1;
    setState(() => _items[i] = _items[i]
        .copyWith(level: (_items[i].level + delta).clamp(0, max).toInt()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.t('pp.outline')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _items),
              child: Text(context.t('common.save')),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: context.t('pp.outline_add'),
          onPressed: () => _edit(null),
          child: const Icon(AppIcons.add),
        ),
        body: _items.isEmpty
            ? Center(child: Text(context.t('pp.outline_empty')))
            : ReorderableListView.builder(
                itemCount: _items.length,
                // `onReorderItem`: [to] öğenin varacağı son dizin.
                onReorderItem: (from, to) => setState(() {
                  final item = _items.removeAt(from);
                  _items.insert(to, item);
                }),
                itemBuilder: (context, i) {
                  final item = _items[i];
                  return ListTile(
                    key: ValueKey('ol-$i-${item.title}-${item.page}'),
                    contentPadding: EdgeInsetsDirectional.only(
                        start: Gap.md + item.level * Gap.lg, end: Gap.lg),
                    title: Text(item.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle:
                        Text(context.t('pp.compare_page', {'n': item.page + 1})),
                    onTap: () => _edit(i),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.t('pp.outline_outdent'),
                          onPressed: item.level > 0 ? () => _indent(i, -1) : null,
                          icon: const Icon(AppIcons.formatIndentDecrease),
                        ),
                        IconButton(
                          tooltip: context.t('pp.outline_indent'),
                          onPressed: () => _indent(i, 1),
                          icon: const Icon(AppIcons.formatIndentIncrease),
                        ),
                        IconButton(
                          tooltip: context.t('common.delete'),
                          onPressed: () => setState(() => _items.removeAt(i)),
                          icon: const Icon(AppIcons.delete),
                        ),
                      ],
                    ),
                  );
                },
              ),
      );
}

// ── Damga ─────────────────────────────────────────────────────────────────

class _StampOptions {
  final String text;
  final int color;
  final PdfStampPlace place;
  final String? subline;
  final bool selectedOnly;
  final bool watermark;
  const _StampOptions({
    required this.text,
    required this.color,
    required this.place,
    required this.subline,
    required this.selectedOnly,
    required this.watermark,
  });
}

class _StampSheet extends StatefulWidget {
  const _StampSheet({required this.hasSelection});

  final bool hasSelection;

  @override
  State<_StampSheet> createState() => _StampSheetState();
}

class _StampSheetState extends State<_StampSheet> {
  PdfStampKind _kind = PdfStampKind.approved;
  PdfStampPlace _place = PdfStampPlace.topRight;
  final _custom = TextEditingController();
  bool _date = true;
  bool _selectedOnly = false;
  bool _watermark = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String _label(BuildContext context) => _kind == PdfStampKind.custom
      ? _custom.text.trim()
      : context.t('pp.stamp_${_kind.name}').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${two(now.day)}.${two(now.month)}.${now.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final k in PdfStampKind.values)
                ChoiceChip(
                  label: Text(context.t('pp.stamp_${k.name}')),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          if (_kind == PdfStampKind.custom)
            TextField(
              controller: _custom,
              textCapitalization: TextCapitalization.characters,
              decoration:
                  InputDecoration(labelText: context.t('pp.stamp_text')),
              onChanged: (_) => setState(() {}),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _watermark,
            onChanged: (v) => setState(() => _watermark = v),
            title: Text(context.t('pp.stamp_as_watermark')),
          ),
          if (!_watermark) ...[
            DropdownButtonFormField<PdfStampPlace>(
              initialValue: _place,
              decoration: InputDecoration(labelText: context.t('pp.place')),
              items: [
                for (final pl in PdfStampPlace.values)
                  DropdownMenuItem(
                      value: pl, child: Text(context.t('pp.place_${pl.name}'))),
              ],
              onChanged: (v) => setState(() => _place = v ?? _place),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _date,
              onChanged: (v) => setState(() => _date = v),
              title: Text(context.t('pp.stamp_date', {'date': date})),
            ),
            if (widget.hasSelection)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _selectedOnly,
                onChanged: (v) => setState(() => _selectedOnly = v),
                title: Text(context.t('pp.selected_pages_only')),
              ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: FilledButton(
              onPressed: _label(context).isEmpty
                  ? null
                  : () => Navigator.pop(
                        context,
                        _StampOptions(
                          text: _label(context),
                          color: PdfDocPro.stampColor(_kind),
                          place: _place,
                          subline: _date ? date : null,
                          selectedOnly: _selectedOnly,
                          watermark: _watermark,
                        ),
                      ),
              child: Text(context.t('pp.stamp_apply')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Numaralandırma ────────────────────────────────────────────────────────

class _NumberingOptions {
  final PageNumberStyle style;
  final PdfNumberPlace place;
  final int startAt;
  final bool skipFirst;
  final String prefix;
  final int digits;
  const _NumberingOptions(this.style, this.place, this.startAt, this.skipFirst,
      this.prefix, this.digits);
}

class _NumberingSheet extends StatefulWidget {
  const _NumberingSheet();

  @override
  State<_NumberingSheet> createState() => _NumberingSheetState();
}

class _NumberingSheetState extends State<_NumberingSheet> {
  PageNumberStyle _style = PageNumberStyle.pageOfTotal;
  PdfNumberPlace _place = PdfNumberPlace.bottomCenter;
  bool _skipFirst = false;
  final _start = TextEditingController(text: '1');
  final _prefix = TextEditingController();
  final _digits = TextEditingController(text: '6');

  @override
  void dispose() {
    _start.dispose();
    _prefix.dispose();
    _digits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bates = _style == PageNumberStyle.bates;
    final preview = PdfDocPro.numberLabel(_style,
        number: int.tryParse(_start.text) ?? 1,
        total: 12,
        prefix: _prefix.text,
        digits: (int.tryParse(_digits.text) ?? 6).clamp(1, 12).toInt(),
        pageWord: context.t('pp.page_word'));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<PageNumberStyle>(
            initialValue: _style,
            decoration: InputDecoration(labelText: context.t('pp.number_style')),
            items: [
              for (final st in PageNumberStyle.values)
                DropdownMenuItem(
                    value: st, child: Text(context.t('pp.number_${st.name}'))),
            ],
            onChanged: (v) => setState(() => _style = v ?? _style),
          ),
          DropdownButtonFormField<PdfNumberPlace>(
            initialValue: _place,
            decoration: InputDecoration(labelText: context.t('pp.place')),
            items: [
              for (final pl in PdfNumberPlace.values)
                DropdownMenuItem(
                    value: pl, child: Text(context.t('pp.nplace_${pl.name}'))),
            ],
            onChanged: (v) => setState(() => _place = v ?? _place),
          ),
          TextField(
            controller: _start,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.t('pp.number_start')),
            onChanged: (_) => setState(() {}),
          ),
          if (bates) ...[
            TextField(
              controller: _prefix,
              decoration:
                  InputDecoration(labelText: context.t('pp.number_prefix')),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _digits,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: context.t('pp.number_digits')),
              onChanged: (_) => setState(() {}),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _skipFirst,
            onChanged: (v) => setState(() => _skipFirst = v),
            title: Text(context.t('pt.pn_skip_first')),
          ),
          Text(context.t('pp.preview', {'text': preview}),
              style: context.type.caption),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _NumberingOptions(
                  _style,
                  _place,
                  int.tryParse(_start.text) ?? 1,
                  _skipFirst,
                  _prefix.text,
                  (int.tryParse(_digits.text) ?? 6).clamp(1, 12).toInt(),
                ),
              ),
              child: Text(context.t('common.ok')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Agresif sıkıştırma ────────────────────────────────────────────────────

class _HardCompressOptions {
  final int dpi;
  final int quality;
  final bool grayscale;
  final bool keepText;
  const _HardCompressOptions(this.dpi, this.quality, this.grayscale, this.keepText);
}

class _HardCompressSheet extends StatefulWidget {
  const _HardCompressSheet();

  @override
  State<_HardCompressSheet> createState() => _HardCompressSheetState();
}

class _HardCompressSheetState extends State<_HardCompressSheet> {
  int _dpi = 120;
  int _quality = 65;
  bool _gray = false;
  bool _keepText = true;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('pp.compress_hard_warn'), style: context.type.small),
            const SizedBox(height: Gap.sm),
            Text(context.t('pp.resolution'), style: context.type.caption),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final d in const [96, 120, 150])
                  ButtonSegment(value: d, label: Text('$d dpi')),
              ],
              selected: {_dpi},
              onSelectionChanged: (v) => setState(() => _dpi = v.first),
            ),
            const SizedBox(height: Gap.sm),
            Text(context.t('pp.quality'), style: context.type.caption),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 50, label: Text(context.t('pp.quality_low'))),
                ButtonSegment(value: 65, label: Text(context.t('pp.quality_mid'))),
                ButtonSegment(value: 80, label: Text(context.t('pp.quality_high'))),
              ],
              selected: {_quality},
              onSelectionChanged: (v) => setState(() => _quality = v.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _gray,
              onChanged: (v) => setState(() => _gray = v),
              title: Text(context.t('pp.grayscale')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _keepText,
              onChanged: (v) => setState(() => _keepText = v),
              title: Text(context.t('pp.keep_text')),
              subtitle: Text(context.t('pp.keep_text_sub')),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: FilledButton(
                onPressed: () => Navigator.pop(context,
                    _HardCompressOptions(_dpi, _quality, _gray, _keepText)),
                child: Text(context.t('pt.compress')),
              ),
            ),
          ],
        ),
      );
}
