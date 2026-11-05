part of '../spreadsheet_editor_screen.dart';

/// **Faz 36 madde 10** — formül denetimi: öncül/ardıl okları (ızgara
/// üstünde, salt çizim), döngüsel başvuru uyarısı, "Ne-olursa → Hedef ara".
extension _SpreadsheetProAuditPart on _SpreadsheetEditorScreenState {
  String _a1(int r, int c) => '${XlsxRange.colName(c)}${r + 1}';

  void _tracePrecedents() {
    _endEdit();
    final sheet = _sheet;
    if (sheet == null) return;
    final refs = FormulaAudit.precedents(sheet.rawAt(_selRow, _selCol));
    if (refs.isEmpty) {
      _snack(context.t('xp.audit_none'));
      return;
    }
    _partSetState(() {
      _arrowsSheet = sheet.name;
      _arrows = [
        ..._arrows,
        for (final p in refs) (p, _selRow, _selCol),
      ];
    });
  }

  void _traceDependents() {
    _endEdit();
    final sheet = _sheet;
    if (sheet == null) return;
    final deps = FormulaAudit.dependents(sheet.rows, _selRow, _selCol);
    if (deps.isEmpty) {
      _snack(context.t('xp.audit_none'));
      return;
    }
    final src = AuditRef(_selRow, _selCol, _selRow, _selCol);
    _partSetState(() {
      _arrowsSheet = sheet.name;
      _arrows = [
        ..._arrows,
        for (final (r, c) in deps) (src, r, c),
      ];
    });
  }

  void _clearArrows() => _partSetState(() => _arrows = const []);

  /// Yazılan formül kendine (dolaylı) başvuruyorsa uyarır.
  void _warnIfCycle(int r, int c) {
    final sheet = _sheet;
    if (sheet == null || !sheet.rawAt(r, c).startsWith('=')) return;
    if (_engineFor(sheet).displayValue(r, c) == '#DÖNGÜ') {
      _snack(context.t('xp.cycle_warn', {'cell': _a1(r, c)}));
    }
  }

  /// Okların çizim katmanı (ızgara gövdesinin üstünde, dokunuşu geçirir).
  Widget _auditLayer(SheetAxisMetrics rows, SheetAxisMetrics cols) {
    final scheme = Theme.of(context).colorScheme;
    Rect box(AuditRef a) => Rect.fromLTRB(
          _SpreadsheetChartLayerPart._axisStart(cols, a.c1),
          _SpreadsheetChartLayerPart._axisStart(rows, a.r1),
          _SpreadsheetChartLayerPart._axisStart(cols, a.c2 + 1),
          _SpreadsheetChartLayerPart._axisStart(rows, a.r2 + 1),
        );
    final arrows = [
      for (final (src, r, c) in _arrows)
        (box(src), box(AuditRef(r, c, r, c)).center, !src.isCell),
    ];
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _vBody,
          builder: (context, _) => CustomPaint(
            painter: _AuditArrowPainter(
              arrows,
              _vBody.hasClients ? _vBody.offset : 0,
              scheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Hedef ara ─────────────────────────────────────────────────────────

  Future<void> _goalSeek() async {
    _endEdit();
    final sheet = _sheet;
    if (sheet == null) return;
    final input = await showAppSheet<(String, String, String)>(
      context,
      title: context.t('xp.goal_seek'),
      builder: (_) => _GoalSeekSheet(setCell: _a1(_selRow, _selCol)),
    );
    if (input == null || !mounted) return;
    AuditRef? cell(String t) {
      final refs = FormulaAudit.precedents('=${t.trim()}');
      return refs.length == 1 && refs.first.isCell ? refs.first : null;
    }

    final set = cell(input.$1), by = cell(input.$3);
    final target = double.tryParse(input.$2.trim().replaceAll(',', '.'));
    if (set == null || by == null || target == null) {
      _snack(context.t('xp.goal_bad_input'));
      return;
    }
    if (!sheet.rawAt(set.r1, set.c1).startsWith('=')) {
      _snack(context.t('xp.goal_need_formula'));
      return;
    }
    if (sheet.rawAt(by.r1, by.c1).startsWith('=')) {
      _snack(context.t('xp.goal_need_value'));
      return;
    }
    final base = sheet.rows;
    final others = {
      for (final s in _editor?.sheets ?? const <XlsxSheet>[])
        if (s.name != sheet.name) s.name: s.rows,
    };
    final tables = _formulaTables();
    double eval(double x) {
      final grid = List<List<String>>.of(base);
      while (grid.length <= by.r1) {
        grid.add(<String>[]);
      }
      final row = List<String>.of(grid[by.r1]);
      while (row.length <= by.c1) {
        row.add('');
      }
      row[by.c1] = FormulaEngine.fmt(x);
      grid[by.r1] = row;
      final e = FormulaEngine(grid,
          sheetName: sheet.name,
          sheets: {...others, sheet.name: grid},
          tables: tables);
      return double.tryParse(e.displayValue(set.r1, set.c1)) ?? double.nan;
    }

    final start = double.tryParse(sheet.rawAt(by.r1, by.c1)) ?? 0;
    final res = GoalSeek.solve(eval, target, start: start);
    if (!res.converged) {
      _snack(context.t('xp.goal_failed'));
      return;
    }
    _editCells('xp.goal_seek', {CellRef(by.r1, by.c1): FormulaEngine.fmt(res.x)});
    _snack(context.t('xp.goal_done',
        {'cell': _a1(by.r1, by.c1), 'value': FormulaEngine.fmt(res.x)}));
  }
}

/// Ok: kaynak aralığın çevresi (aralıksa) + merkezden hedefe çizgi ve uç.
class _AuditArrowPainter extends CustomPainter {
  _AuditArrowPainter(this.arrows, this.dy, this.color);

  final List<(Rect, Offset, bool)> arrows;
  final double dy;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;
    canvas.save();
    canvas.translate(0, -dy);
    for (final (src, to, isRange) in arrows) {
      if (isRange) canvas.drawRect(src.deflate(1), line);
      final from = src.center;
      canvas.drawCircle(from, 3, fill);
      canvas.drawLine(from, to, line);
      final d = to - from;
      final len = d.distance;
      if (len < 1) continue;
      final u = d / len;
      final n = Offset(-u.dy, u.dx);
      final head = Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(to.dx - u.dx * 9 + n.dx * 4, to.dy - u.dy * 9 + n.dy * 4)
        ..lineTo(to.dx - u.dx * 9 - n.dx * 4, to.dy - u.dy * 9 - n.dy * 4)
        ..close();
      canvas.drawPath(head, fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuditArrowPainter old) =>
      old.dy != dy || old.color != color || old.arrows != arrows;
}

class _GoalSeekSheet extends StatefulWidget {
  const _GoalSeekSheet({required this.setCell});

  final String setCell;

  @override
  State<_GoalSeekSheet> createState() => _GoalSeekSheetState();
}

class _GoalSeekSheetState extends State<_GoalSeekSheet> {
  late final _set = TextEditingController(text: widget.setCell);
  final _to = TextEditingController();
  final _by = TextEditingController();

  @override
  void dispose() {
    _set.dispose();
    _to.dispose();
    _by.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _set,
              decoration: InputDecoration(labelText: context.t('xp.goal_set')),
            ),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: _to,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(labelText: context.t('xp.goal_to')),
            ),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: _by,
              decoration: InputDecoration(labelText: context.t('xp.goal_by')),
            ),
            const SizedBox(height: Gap.md),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (_set.text, _to.text, _by.text)),
              child: Text(context.t('common.ok')),
            ),
          ],
        ),
      );
}
