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

  /// Hücrede uygulanacak koşullu biçim + mini grafik (yoksa null).
  SheetCondPaint? condFor(int r, int c) {
    final base = _condRule(r, c);
    final sp = sheet.sparklineAt(r, c);
    if (sp == null) return base;
    final values = _sparkValues(sp);
    if (values == null) return base;
    return SheetCondPaint(
      background: base?.background,
      foreground: base?.foreground,
      bold: base?.bold ?? false,
      italic: base?.italic ?? false,
      barRatio: base?.barRatio,
      barColor: base?.barColor,
      iconColor: base?.iconColor,
      sparkValues: values,
      sparkType: sp.type,
      sparkColor: Color(sp.colorArgb),
    );
  }

  /// Mini grafiğin kaynak değerleri (yalnız aynı sayfa; boş hücre = NaN).
  /// Yalnız GÖRÜNEN hücre boyanırken hesaplanır (anayasa k.5).
  List<double>? _sparkValues(XlsxSparkline sp) {
    final other = sp.sheet;
    if (other != null && other.toLowerCase() != sheet.name.toLowerCase()) {
      return null;
    }
    final range = sp.range;
    if (range == null) return null;
    final out = <double>[];
    for (var rr = range.r1; rr <= range.r2; rr++) {
      for (var cc = range.c1; cc <= range.c2; cc++) {
        out.add(double.tryParse(engine.displayValue(rr, cc)) ?? double.nan);
        if (out.length >= 400) return out;
      }
    }
    return out;
  }

  SheetCondPaint? _condRule(int r, int c) {
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
      case 'iconSet':
        if (value == null) return null;
        final stats = _statsFor(rule);
        final t = stats.max <= stats.min
            ? 1.0
            : ((value - stats.min) / (stats.max - stats.min)).clamp(0.0, 1.0);
        return SheetCondPaint(iconColor: _iconColor(t));
      case 'expression':
        if (!_expressionMatch(rule, r, c)) return null;
        return _dxfPaint(rule);
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

  /// Üç kademeli simge (trafik ışığı): alt üçte bir kırmızı, orta sarı,
  /// üst yeşil — Excel `3TrafficLights1` eşikleri (yüzde 33/67).
  static Color _iconColor(double t) =>
      t < 0.33 ? AppHues.red : (t < 0.67 ? AppHues.amber : AppHues.green);

  /// Formül kuralı: formül aralığın SOL-ÜST hücresine göre yazılır (Excel
  /// gibi); her hücre için göreli başvurular kaydırılıp değerlendirilir.
  bool _expressionMatch(XlsxCondRule rule, int r, int c) {
    if (rule.formulas.isEmpty || rule.ranges.isEmpty) return false;
    final anchor = rule.ranges.first;
    final f = shiftFormula(rule.formulas.first, r - anchor.r1, c - anchor.c1);
    final v = engine.preview('=$f', r, c).trim().toUpperCase();
    if (v == 'TRUE' || v == 'DOĞRU') return true;
    final n = double.tryParse(v);
    return n != null && n != 0;
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

//// Sütun süzgeci sayfası: sırala düğmeleri + "içerir" araması + ilk/son 10
/// + renge göre + değer onay listesi (B10 m.5). Sonuç tek [ColumnFilter];
/// boş ölçüt = sütun süzgecini kaldır.
///
/// Değer listesi Excel'in süzgeç açılırıyla aynı mantıkta: sütundaki BENZERSİZ
/// değerler, işaretlenmeyenlerin satırları gizlenir. "Tümü" kutusu üç durumlu
/// değil iki durumlu — telefonda üçüncü durumu ayırt etmek zor. Arama kutusu
/// listeyi daraltır; doluyken "Uygula" "içerir" süzgecidir (Excel'deki arama).
class _ColumnFilterSheet extends StatefulWidget {
  const _ColumnFilterSheet({
    required this.title,
    required this.values,
    required this.initial,
    required this.fills,
    required this.onSort,
  });

  final String title;
  final List<String> values;
  final ColumnFilter initial;

  /// Sütundaki farklı dolgu renkleri (ikiden azsa renk seçimi gösterilmez).
  final List<int> fills;
  final void Function(bool ascending) onSort;

  @override
  State<_ColumnFilterSheet> createState() => _ColumnFilterSheetState();
}

class _ColumnFilterSheetState extends State<_ColumnFilterSheet> {
  late final Set<String> _off = {...widget.initial.hiddenValues};
  late final TextEditingController _search =
      TextEditingController(text: widget.initial.contains ?? '');
  late int? _top = widget.initial.top;
  late bool _bottom = widget.initial.bottom;
  late int? _fill = widget.initial.fillArgb;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ColumnFilter _result() {
    if (_top != null) return ColumnFilter(top: _top, bottom: _bottom);
    final q = _search.text.trim();
    if (q.isNotEmpty) return ColumnFilter(contains: q);
    if (_fill != null) return ColumnFilter(fillArgb: _fill);
    return ColumnFilter(hiddenValues: _off);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.values
        : [
            for (final v in widget.values)
              if (v.toLowerCase().contains(q)) v,
          ];
    Widget topChip(bool bottom, String key) => ChoiceChip(
          key: ValueKey('xl-filter-${bottom ? 'bottom' : 'top'}10'),
          label: Text(t.t(key)),
          selected: _top != null && _bottom == bottom,
          onSelected: (on) => setState(() {
            _top = on ? 10 : null;
            _bottom = bottom;
          }),
        );
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 4),
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
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
              child: TextField(
                key: const ValueKey('xl-filter-search'),
                controller: _search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(AppIcons.search, size: 18),
                  hintText: t.t('excel.filter_contains'),
                ),
                onChanged: (_) => setState(() => _top = null),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  topChip(false, 'excel.filter_top10'),
                  topChip(true, 'excel.filter_bottom10'),
                  if (widget.fills.length > 1) ...[
                    Text(t.t('excel.filter_by_color')),
                    for (final argb in widget.fills)
                      ChoiceChip(
                        key: ValueKey('xl-filter-fill-$argb'),
                        label: const SizedBox(width: 16, height: 16),
                        avatar: CircleAvatar(backgroundColor: Color(argb)),
                        selected: _fill == argb,
                        onSelected: (on) =>
                            setState(() => _fill = on ? argb : null),
                      ),
                  ],
                ],
              ),
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
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final v = shown[i];
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
                    onPressed: () =>
                        Navigator.pop(context, const ColumnFilter()),
                    child: Text(t.t('excel.filter_clear')),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('xl-filter-apply'),
                    onPressed: () => Navigator.pop(context, _result()),
                    child: Text(t.t('common.apply')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Hücre notu işareti: sağ üst köşede küçük kırmızı üçgen (Excel'in kendi
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

/// [SpreadsheetEditorScreen] aşamalı açılışı: okunacak hücre tavanı (ilk
/// ekranı doldurur) ve paylaşılan dize tavanı (karakter).
const kXlsxHeadCells = 800;
const kXlsxHeadSharedChars = 1 << 20;

/// B13 m.4 — tam kitap hazırlanırken ilk sayfanın başı, salt okunur düz
/// ızgara (sütun harfleri + satır numaraları, ham değerler). En çok
/// [maxCols] sütun: önizleme hücre sayısı sınırlı kalsın.
class SheetHeadPreview extends StatelessWidget {
  final XlsxStreamSheet sheet;
  const SheetHeadPreview({super.key, required this.sheet});

  static const maxCols = 26;
  static const _cellW = 96.0, _cellH = 28.0, _headW = 44.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = BorderSide(color: scheme.outlineVariant, width: 0.5);
    final cols = math.min(sheet.maxCol + 1, maxCols);
    final style = context.type.small;
    final headStyle = style.copyWith(color: scheme.onSurfaceVariant);
    Widget cell(String text, double w, {TextStyle? s, bool head = false}) =>
        Container(
          width: w,
          height: _cellH,
          alignment: head ? Alignment.center : AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          decoration: BoxDecoration(
            color: head ? scheme.surfaceContainerHighest : null,
            border: Border(right: line, bottom: line),
          ),
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: s ?? style),
        );
    Widget row(int r) {
      final values = sheet.cells[r];
      return Row(children: [
        cell('${r + 1}', _headW, s: headStyle, head: true),
        for (var c = 0; c < cols; c++) cell(values?[c] ?? '', _cellW),
      ]);
    }

    return OfficeLoadingPreview(
      key: const ValueKey('excel-loading-preview'),
      label: context.t('excel.opening_preview'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _headW + cols * _cellW,
          child: Column(children: [
            Row(children: [
              cell('', _headW, head: true),
              for (var c = 0; c < cols; c++)
                cell(String.fromCharCode(0x41 + c), _cellW,
                    s: headStyle, head: true),
            ]),
            Expanded(
              child: ListView.builder(
                itemExtent: _cellH,
                itemCount: sheet.maxRow + 1,
                itemBuilder: (_, r) => row(r),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
