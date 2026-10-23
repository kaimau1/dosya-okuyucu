part of '../spreadsheet_editor_screen.dart';


/// Doldurma tutamağının sürükleme oturumu (bkz. `_fillHandle`).
class _FillDrag extends Drag {
  final void Function(Offset global) onMove;
  final void Function({required bool apply}) onDone;

  _FillDrag({required this.onMove, required this.onDone});

  @override
  void update(DragUpdateDetails details) => onMove(details.globalPosition);

  @override
  void end(DragEndDetails details) => onDone(apply: true);

  /// İptal (ör. sistem geri hareketi) doldurma YAPMAZ — yarım bir seri
  /// yazmaktansa hiç yazmamak doğru.
  @override
  void cancel() => onDone(apply: false);
}

/// Uygulanmış bir işlemin tersini taşıyan genel geri alma adımı
/// (yapısal işlemler ve biçim değişiklikleri buradan geçer).
class _CallbackStep implements SheetUndoStep {
  @override
  final String label;

  final VoidCallback _apply;
  final VoidCallback _revert;

  _CallbackStep(this.label, this._apply, this._revert);

  @override
  void apply() => _apply();

  @override
  void revert() => _revert();
}

/// Bir çizim geçişi boyunca paylaşılan bağlam (koşullu biçim min/max
/// hesapları sayfa başına BİR kez yapılır).
class _RenderContext {
  final XlsxSheet sheet;
  final FormulaEngine engine;
  final double zoom;
  final Map<XlsxCondRule, _CondStats> condCache;

  /// Formül yazılırken başvurulan aralıklar + renkleri (Faz 25).
  final List<(XlsxRange, Color)> refs;

  _RenderContext({
    required this.sheet,
    required this.engine,
    required this.zoom,
    required this.condCache,
    this.refs = const [],
  });

  /// Hücrede uygulanacak koşullu biçim sonucu (yoksa null).
  SheetCondPaint? condFor(int r, int c) {
    final rule = sheet.condRuleAt(r, c);
    if (rule == null) return null;
    final raw = engine.displayValue(r, c);
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);

    switch (rule.type) {
      case 'colorScale':
        if (value == null || rule.scaleColors == null) return null;
        final stats = _statsFor(rule);
        if (stats.max <= stats.min) return null;
        final t = ((value - stats.min) / (stats.max - stats.min)).clamp(0.0, 1.0);
        return SheetCondPaint(
            background: _scaleColor(rule.scaleColors!, t));
      case 'dataBar':
        if (value == null) return null;
        final stats = _statsFor(rule);
        final span = math.max(stats.max, 0) - math.min(stats.min, 0);
        if (span <= 0) return null;
        final ratio = ((value - math.min(stats.min, 0)) / span).clamp(0.0, 1.0);
        return SheetCondPaint(
          barRatio: ratio,
          barColor: Color(rule.barColorArgb ?? 0xFF638EC6),
        );
      case 'cellIs':
        if (!_cellIsMatch(rule, value, raw)) return null;
        return _dxfPaint(rule);
      case 'containsText':
        if (!raw.toLowerCase().contains((rule.text ?? '').toLowerCase())) {
          return null;
        }
        return _dxfPaint(rule);
      case 'notContainsText':
        if (raw.toLowerCase().contains((rule.text ?? '').toLowerCase())) {
          return null;
        }
        return _dxfPaint(rule);
      case 'beginsWith':
        if (!raw.toLowerCase().startsWith((rule.text ?? '').toLowerCase())) {
          return null;
        }
        return _dxfPaint(rule);
      case 'endsWith':
        if (!raw.toLowerCase().endsWith((rule.text ?? '').toLowerCase())) {
          return null;
        }
        return _dxfPaint(rule);
      default:
        return null;
    }
  }

  SheetCondPaint? _dxfPaint(XlsxCondRule rule) {
    final id = rule.dxfId;
    if (id == null || id < 0 || id >= sheet.styles.dxfs.length) return null;
    final dxf = sheet.styles.dxfs[id];
    return SheetCondPaint(
      background: dxf.fill?.effectiveArgb == null
          ? null
          : Color(dxf.fill!.effectiveArgb!),
      foreground:
          dxf.font?.colorArgb == null ? null : Color(dxf.font!.colorArgb!),
      bold: dxf.font?.bold ?? false,
      italic: dxf.font?.italic ?? false,
    );
  }

  bool _cellIsMatch(XlsxCondRule rule, double? value, String raw) {
    final a = rule.formulas.isNotEmpty
        ? double.tryParse(rule.formulas[0].replaceAll('"', ''))
        : null;
    final b = rule.formulas.length > 1
        ? double.tryParse(rule.formulas[1].replaceAll('"', ''))
        : null;
    if (value == null || a == null) {
      // Metin karşılaştırması
      final t = rule.formulas.isNotEmpty
          ? rule.formulas[0].replaceAll('"', '')
          : '';
      return switch (rule.operator) {
        'equal' => raw == t,
        'notEqual' => raw != t,
        _ => false,
      };
    }
    return switch (rule.operator) {
      'greaterThan' => value > a,
      'greaterThanOrEqual' => value >= a,
      'lessThan' => value < a,
      'lessThanOrEqual' => value <= a,
      'equal' => value == a,
      'notEqual' => value != a,
      'between' => b != null && value >= math.min(a, b) && value <= math.max(a, b),
      'notBetween' =>
        b != null && (value < math.min(a, b) || value > math.max(a, b)),
      _ => false,
    };
  }

  _CondStats _statsFor(XlsxCondRule rule) {
    final cached = condCache[rule];
    if (cached != null) return cached;
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (final range in rule.ranges) {
      for (var r = range.r1; r <= range.r2 && r < sheet.rows.length + 1; r++) {
        for (var c = range.c1; c <= range.c2; c++) {
          final v = double.tryParse(engine.displayValue(r, c));
          if (v == null) continue;
          if (v < min) min = v;
          if (v > max) max = v;
        }
      }
    }
    final stats = _CondStats(
      min.isFinite ? min : 0,
      max.isFinite ? max : 0,
    );
    condCache[rule] = stats;
    return stats;
  }

  static Color _scaleColor(List<int> colors, double t) {
    if (colors.isEmpty) return AppColors.none;
    if (colors.length == 1) return Color(colors.first);
    final segment = 1.0 / (colors.length - 1);
    final idx = (t / segment).floor().clamp(0, colors.length - 2);
    final local = ((t - idx * segment) / segment).clamp(0.0, 1.0);
    return Color.lerp(Color(colors[idx]), Color(colors[idx + 1]), local)!;
  }
}

class _CondStats {
  final double min, max;
  const _CondStats(this.min, this.max);
}

/// Sütun süzgeci sayfası: sırala düğmeleri + değer onay listesi.
///
/// Değer listesi Excel'in süzgeç açılırıyla aynı mantıkta: sütundaki BENZERSİZ
/// değerler, işaretlenmeyenlerin satırları gizlenir. "Tümü" kutusu üç durumlu
/// değil iki durumlu — telefonda üçüncü durumu ayırt etmek zor.
class _ColumnFilterSheet extends StatefulWidget {
  const _ColumnFilterSheet({
    required this.title,
    required this.values,
    required this.unchecked,
    required this.onSort,
  });

  final String title;
  final List<String> values;
  final Set<String> unchecked;
  final void Function(bool ascending) onSort;

  @override
  State<_ColumnFilterSheet> createState() => _ColumnFilterSheetState();
}

class _ColumnFilterSheetState extends State<_ColumnFilterSheet> {
  late final Set<String> _off = {...widget.unchecked};

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(widget.title,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => widget.onSort(true),
                  icon: const Icon(AppIcons.arrowUp, size: 18),
                  label: Text(t.t('excel.sort_asc')),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => widget.onSort(false),
                  icon: const Icon(AppIcons.arrowDown, size: 18),
                  label: Text(t.t('excel.sort_desc')),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          CheckboxListTile(
            dense: true,
            value: _off.isEmpty,
            title: Text(t.t('excel.filter_all')),
            onChanged: (v) => setState(() {
              _off
                ..clear()
                ..addAll(v == true ? const <String>[] : widget.values);
            }),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.values.length,
              itemBuilder: (_, i) {
                final v = widget.values[i];
                return CheckboxListTile(
                  dense: true,
                  value: !_off.contains(v),
                  title: Text(v.isEmpty ? t.t('excel.filter_blank') : v,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onChanged: (on) => setState(() {
                    on == true ? _off.remove(v) : _off.add(v);
                  }),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, <String>{}),
                  child: Text(t.t('excel.filter_clear')),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _off),
                  child: Text(t.t('common.apply')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hücre notu işareti: sağ üst köşede küçük kırmızı üçgen (Excel'in kendi
/// göstergesi). `CustomPaint` seçildi çünkü bir `Icon` bu boyutta ne okunur
/// ne de Excel'e benzer duruyordu.
class _NoteMarkPainter extends CustomPainter {
  const _NoteMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFB23A2E));
  }

  @override
  bool shouldRepaint(_NoteMarkPainter oldDelegate) => false;
}
