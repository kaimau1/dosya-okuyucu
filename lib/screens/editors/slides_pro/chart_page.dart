import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/pptx/pro/pptx_chart_ops.dart';

/// **Faz 38 / madde 3 — grafik veri düzenleyicisi.** Kategoriler satır,
/// seriler sütun; tür ve başlık. "Uygula" verinin son hâlini döndürür.
class SlideChartPage extends StatefulWidget {
  final SlideChartData initial;
  const SlideChartPage({super.key, required this.initial});

  @override
  State<SlideChartPage> createState() => _SlideChartPageState();
}

class _SlideChartPageState extends State<SlideChartPage> {
  late SlideChartKind _kind = widget.initial.kind;
  late final _title = TextEditingController(text: widget.initial.title);
  late final List<TextEditingController> _cats = [
    for (final c in widget.initial.categories) TextEditingController(text: c),
  ];
  late final List<TextEditingController> _names = [
    for (final s in widget.initial.series) TextEditingController(text: s.$1),
  ];
  late final List<List<TextEditingController>> _vals = [
    for (final s in widget.initial.series)
      [
        for (var r = 0; r < widget.initial.categories.length; r++)
          TextEditingController(
              text: r < s.$2.length ? _fmt(s.$2[r]) : '0'),
      ],
  ];

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_title, ..._cats, ..._names, ..._vals.expand((e) => e)]) {
      c.dispose();
    }
    super.dispose();
  }

  SlideChartData _result() => SlideChartData(
        _kind,
        [for (final c in _cats) c.text.trim()],
        [
          for (var i = 0; i < _names.length; i++)
            (
              _names[i].text.trim().isEmpty ? '${i + 1}' : _names[i].text.trim(),
              [
                for (final v in _vals[i])
                  PptxChartOps.parseNumber(v.text) ?? 0.0,
              ],
            ),
        ],
        title: _title.text,
      );

  void _addRow() => setState(() {
        _cats.add(TextEditingController(text: '${_cats.length + 1}'));
        for (final col in _vals) {
          col.add(TextEditingController(text: '0'));
        }
      });

  void _addSeries() => setState(() {
        _names.add(TextEditingController(text: '${_names.length + 1}'));
        _vals.add([
          for (var k = 0; k < _cats.length; k++) TextEditingController(text: '0'),
        ]);
      });

  void _removeRow(int r) => setState(() {
        if (_cats.length <= 1) return;
        _cats.removeAt(r).dispose();
        for (final col in _vals) {
          col.removeAt(r).dispose();
        }
      });

  void _removeSeries(int i) => setState(() {
        if (_names.length <= 1) return;
        _names.removeAt(i).dispose();
        for (final c in _vals.removeAt(i)) {
          c.dispose();
        }
      });

  Widget _cell(TextEditingController c, {bool number = false, Key? key}) =>
      SizedBox(
        width: 96,
        child: TextField(
          key: key,
          controller: c,
          style: context.type.compact,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : TextInputType.text,
          decoration: const InputDecoration(
              isDense: true, border: OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('sp.chart_data')),
        actions: [
          TextButton(
            key: const ValueKey('sp-chart-apply'),
            onPressed: () => Navigator.pop(context, _result()),
            child: Text(context.t('sp.apply')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<SlideChartKind>(
            segments: [
              for (final k in SlideChartKind.values)
                ButtonSegment(
                  value: k,
                  label: Text(context.t('sp.chart_${k.name}')),
                ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: InputDecoration(
                labelText: context.t('sp.chart_title'),
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const SizedBox(width: 136),
                  for (var i = 0; i < _names.length; i++)
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: Row(children: [
                        _cell(_names[i]),
                        IconButton(
                          tooltip: context.t('sp.remove_series'),
                          icon: const Icon(AppIcons.close),
                          onPressed: () => _removeSeries(i),
                        ),
                      ]),
                    ),
                ]),
                for (var r = 0; r < _cats.length; r++)
                  Row(children: [
                    IconButton(
                      tooltip: context.t('sp.remove_row'),
                      icon: const Icon(AppIcons.remove),
                      onPressed: () => _removeRow(r),
                    ),
                    Padding(
                        padding: const EdgeInsets.all(2),
                        child: _cell(_cats[r])),
                    for (var i = 0; i < _names.length; i++)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 2, 50, 2),
                        child: _cell(_vals[i][r],
                            number: true, key: ValueKey('sp-val-$i-$r')),
                      ),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(AppIcons.tableRows),
              label: Text(context.t('sp.add_row')),
              onPressed: _addRow,
            ),
            OutlinedButton.icon(
              icon: const Icon(AppIcons.viewColumn),
              label: Text(context.t('sp.add_series')),
              onPressed: _addSeries,
            ),
          ]),
        ],
      ),
    );
  }
}
