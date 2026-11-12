part of '../spreadsheet_editor_screen.dart';

/// İçe aktarma önizlemesi: ayraç, kodlama, başlık + ilk satırlar ve türler.
class _ImportSheet extends StatefulWidget {
  const _ImportSheet({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  String? _delimiter;
  String _encoding = 'auto';
  bool _header = true;

  @override
  Widget build(BuildContext context) {
    final rows = SheetImport.parseText(widget.bytes,
        ImportOptions(delimiter: _delimiter, encoding: _encoding, header: _header));
    final types = SheetImport.columnTypes(rows, header: _header);
    final preview = rows.take(6).toList();
    String typeLabel(ColumnType t) => context.t('xp.type_${t.name}');
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('xp.delimiter'), style: context.type.caption),
          Wrap(spacing: Gap.xs, children: [
            for (final (v, k) in const [
              (null, 'xp.delim_auto'),
              (',', 'xp.delim_comma'),
              (';', 'xp.delim_semi'),
              ('\t', 'xp.delim_tab'),
              ('|', 'xp.delim_pipe'),
            ])
              ChoiceChip(
                label: Text(context.t(k)),
                selected: _delimiter == v,
                onSelected: (_) => setState(() => _delimiter = v),
              ),
          ]),
          Text(context.t('xp.encoding'), style: context.type.caption),
          Wrap(spacing: Gap.xs, children: [
            for (final (v, k) in const [
              ('auto', 'xp.delim_auto'),
              ('utf8', 'xp.enc_utf8'),
              ('cp1254', 'xp.enc_cp1254'),
            ])
              ChoiceChip(
                label: Text(context.t(k)),
                selected: _encoding == v,
                onSelected: (_) => setState(() => _encoding = v),
              ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _header,
            onChanged: (v) => setState(() => _header = v),
            title: Text(context.t('excel.dup_has_header')),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 28,
              dataRowMinHeight: 24,
              dataRowMaxHeight: 28,
              columns: [
                for (var c = 0; c < types.length; c++)
                  DataColumn(
                    label: Text(
                      '${_header && preview.isNotEmpty && c < preview.first.length ? preview.first[c] : CellRef.colName(c)}\n${typeLabel(types[c])}',
                      style: context.type.caption,
                    ),
                  ),
              ],
              rows: [
                for (final row in preview.skip(_header ? 1 : 0))
                  DataRow(cells: [
                    for (var c = 0; c < types.length; c++)
                      DataCell(Text(c < row.length ? row[c] : '',
                          style: context.type.small)),
                  ]),
              ],
            ),
          ),
          Text(context.t('xp.import_rows', {'n': rows.length}),
              style: context.type.caption),
          const SizedBox(height: Gap.sm),
          FilledButton(
            key: const ValueKey('xl-import-go'),
            onPressed: () => Navigator.pop(context, rows),
            child: Text(context.t('xp.import_go')),
          ),
        ],
      ),
    );
  }
}

/// Ara toplam: grup sütunu + toplanacak sütunlar.
class _SubtotalSheet extends StatefulWidget {
  const _SubtotalSheet({required this.header});

  final List<String> header;

  @override
  State<_SubtotalSheet> createState() => _SubtotalSheetState();
}

class _SubtotalSheetState extends State<_SubtotalSheet> {
  int _group = 0;
  late final Set<int> _sum = {widget.header.length - 1};

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _group,
              decoration: InputDecoration(labelText: context.t('xp.subtotal_by')),
              items: [
                for (var i = 0; i < widget.header.length; i++)
                  DropdownMenuItem(value: i, child: Text(widget.header[i])),
              ],
              onChanged: (v) => setState(() => _group = v ?? 0),
            ),
            const SizedBox(height: Gap.sm),
            Text(context.t('xp.subtotal_sum'), style: context.type.caption),
            Wrap(spacing: Gap.xs, children: [
              for (var i = 0; i < widget.header.length; i++)
                if (i != _group)
                  FilterChip(
                    label: Text(widget.header[i]),
                    selected: _sum.contains(i),
                    onSelected: (on) =>
                        setState(() => on ? _sum.add(i) : _sum.remove(i)),
                  ),
            ]),
            const SizedBox(height: Gap.sm),
            FilledButton(
              onPressed: _sum.isEmpty
                  ? null
                  : () => Navigator.pop(context,
                      (_group, (_sum.where((c) => c != _group).toList()..sort()))),
              child: Text(context.t('xp.subtotal_go')),
            ),
          ],
        ),
      );
}

/// Yazdırma ayarları: yön, sayfaya sığdır, başlık yinele, ızgara.
class _PrintSheet extends StatefulWidget {
  const _PrintSheet({required this.title});

  final String title;

  @override
  State<_PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends State<_PrintSheet> {
  bool _landscape = false;
  bool _fit = true;
  int _repeat = 1;
  bool _grid = true;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(context.t('xp.portrait'))),
                ButtonSegment(value: true, label: Text(context.t('xp.landscape'))),
              ],
              selected: {_landscape},
              onSelectionChanged: (v) => setState(() => _landscape = v.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _fit,
              onChanged: (v) => setState(() => _fit = v),
              title: Text(context.t('xp.fit_width')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _grid,
              onChanged: (v) => setState(() => _grid = v),
              title: Text(context.t('xp.print_grid')),
            ),
            Text(context.t('xp.repeat_rows'), style: context.type.caption),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final n in const [0, 1, 2])
                  ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {_repeat},
              onSelectionChanged: (v) => setState(() => _repeat = v.first),
            ),
            const SizedBox(height: Gap.sm),
            FilledButton(
              key: const ValueKey('xl-print-go'),
              onPressed: () => Navigator.pop(
                context,
                SheetPrintSpec(
                  landscape: _landscape,
                  fitWidth: _fit,
                  repeatRows: _repeat,
                  gridLines: _grid,
                  title: widget.title,
                ),
              ),
              child: Text(context.t('xp.print_go')),
            ),
          ],
        ),
      );
}

/// Parola girişi (gizli) + isteğe bağlı doğrulama alanı.
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({this.error, this.confirm = false});

  final String? error;
  final bool confirm;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _pw = TextEditingController();
  final _again = TextEditingController();
  late String? _error = widget.error;

  @override
  void dispose() {
    _pw.dispose();
    _again.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pw.text.isEmpty) return;
    if (widget.confirm && _pw.text != _again.text) {
      setState(() => _error = context.t('xp.password_mismatch'));
      return;
    }
    Navigator.pop(context, _pw.text);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('xl-password'),
              controller: _pw,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.t('xp.password'),
                errorText: widget.confirm ? null : _error,
              ),
              onSubmitted: widget.confirm ? null : (_) => _submit(),
            ),
            if (widget.confirm)
              TextField(
                key: const ValueKey('xl-password-again'),
                controller: _again,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: context.t('xp.password_again'),
                    errorText: _error),
                onSubmitted: (_) => _submit(),
              ),
            const SizedBox(height: Gap.sm),
            FilledButton(onPressed: _submit, child: Text(context.t('common.ok'))),
          ],
        ),
      );
}

/// Özet tablo ayar levhası: satır / sütun / değer alanı, işlev, süzgeç.
class _PivotSheet extends StatefulWidget {
  const _PivotSheet({required this.header, required this.data});

  final List<String> header;
  final List<List<String>> data;

  @override
  State<_PivotSheet> createState() => _PivotSheetState();
}

class _PivotSheetState extends State<_PivotSheet> {
  int _row = 0;
  int? _col;
  late int _value = widget.header.length - 1;
  PivotAgg _agg = PivotAgg.sum;
  int? _filter;
  Set<String> _allowed = {};

  DropdownButtonFormField<int?> _field(String key, String label, int? value,
          ValueChanged<int?> onChanged, {bool optional = false}) =>
      DropdownButtonFormField<int?>(
        key: ValueKey(key),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (optional)
            DropdownMenuItem<int?>(value: null, child: Text(context.t('xp.none'))),
          for (var i = 0; i < widget.header.length; i++)
            DropdownMenuItem<int?>(value: i, child: Text(widget.header[i])),
        ],
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final values = _filter == null
        ? const <String>[]
        : Pivot.distinct(widget.data, _filter!, limit: 60);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('pv-row', context.t('xp.rows'), _row,
              (v) => setState(() => _row = v ?? 0)),
          _field('pv-col', context.t('xp.cols'), _col,
              (v) => setState(() => _col = v), optional: true),
          _field('pv-value', context.t('xp.values'), _value,
              (v) => setState(() => _value = v ?? _value)),
          DropdownButtonFormField<PivotAgg>(
            key: const ValueKey('pv-agg'),
            initialValue: _agg,
            decoration: InputDecoration(labelText: context.t('xp.agg')),
            items: [
              for (final a in PivotAgg.values)
                DropdownMenuItem(value: a, child: Text(context.t('xp.agg_${a.name}'))),
            ],
            onChanged: (v) => setState(() => _agg = v ?? _agg),
          ),
          _field('pv-filter', context.t('xp.filter'), _filter,
              (v) => setState(() {
                    _filter = v;
                    _allowed = {};
                  }),
              optional: true),
          if (values.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final v in values)
                    FilterChip(
                      label: Text(v.isEmpty ? context.t('xp.blank') : v),
                      selected: _allowed.contains(v),
                      onSelected: (on) => setState(
                          () => on ? _allowed.add(v) : _allowed.remove(v)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: Gap.sm),
          FilledButton(
            key: const ValueKey('pv-run'),
            onPressed: () => Navigator.pop(
              context,
              PivotSpec(
                rowField: _row,
                colField: _col,
                valueField: _value,
                agg: _agg,
                filterField: _filter,
                filterValues: {..._allowed},
              ),
            ),
            child: Text(context.t('xp.pivot_create')),
          ),
        ],
      ),
    );
  }
}
