part of '../spreadsheet_editor_screen.dart';

/// **Faz 36 madde 9** — biçim boyacısı, koşullu biçim yöneticisi (dosya
/// kuralları dahil sil/geri al), tema renkleri (renk seçicide).
/// (Hücre stilleri galerisi Faz 27'de vardı — `finish_format.dart`.)
extension _SpreadsheetProFormatPart on _SpreadsheetEditorScreenState {
  // ── biçim boyacısı ────────────────────────────────────────────────────

  /// Açar: seçimin biçimi alınır; sonraki dokunuş onu oraya uygular.
  /// Açıkken basmak kapatır.
  void _toggleFormatPainter() {
    _endEdit();
    if (_painter != null) {
      _partSetState(() => _painter = null);
      return;
    }
    final r = _range;
    _partSetState(() => _painter =
        (r.top, r.left, r.bottom - r.top + 1, r.right - r.left + 1));
    _snack(context.t('xp.painter_hint'));
  }

  /// Boyacı açıkken hücreye dokunuş: kaynak bloğun biçimi (r,c)'den
  /// itibaren yazılır (değerler yerinde kalır), boyacı kapanır.
  void _applyFormatPainter(int r, int c) {
    final p = _painter;
    final sheet = _sheet;
    _partSetState(() => _painter = null);
    if (p == null || sheet == null) return;
    final (top, left, rows, cols) = p;
    final out = <CellRef, String>{};
    final fmt = <CellRef, CellRef>{};
    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < cols; j++) {
        final dst = CellRef(r + i, c + j);
        fmt[dst] = CellRef(top + i, left + j);
        out[dst] = sheet.rawAt(dst.row, dst.col);
      }
    }
    _editCells('excel.undo_paste', out, formatSources: fmt);
    _jumpTo(r, c);
  }

  // ── koşullu biçim yöneticisi ──────────────────────────────────────────

  String _condLabel(XlsxCondRule rule) => switch (rule.type) {
        'cellIs' => switch (rule.operator) {
            'greaterThan' => context.t('excel.cond_greater'),
            'lessThan' => context.t('excel.cond_less'),
            'equal' => context.t('excel.cond_equal'),
            _ => rule.operator ?? rule.type,
          },
        'containsText' => context.t('excel.cond_contains'),
        'expression' => context.t('xp.cond_formula'),
        'colorScale' => context.t('xp.color_scale'),
        'dataBar' => context.t('xp.data_bar_plain'),
        'iconSet' => context.t('xp.icon_set_plain'),
        _ => rule.type,
      };

  String _condDetail(XlsxCondRule rule) {
    final what = [
      if (rule.text != null) rule.text!,
      ...rule.formulas,
    ].join(' · ');
    final where = XlsxSheet.condSqref(rule);
    return what.isEmpty ? where : '$where — $what';
  }

  Future<void> _showCondManager() async {
    _endEdit();
    final sheet = _sheet;
    if (sheet == null) return;
    await showAppSheet<void>(
      context,
      title: context.t('xp.cond_manage'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final rules = sheet.layout.condFormats;
          if (rules.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Text(ctx.t('xp.cond_none'), style: ctx.type.body),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final rule in List.of(rules))
                ListTile(
                  leading: Icon(switch (rule.type) {
                    'dataBar' => AppIcons.barChart,
                    'iconSet' => AppIcons.trafficLight,
                    'colorScale' => AppIcons.formatColorFill,
                    'expression' => AppIcons.functions,
                    _ => AppIcons.formatPaint,
                  }),
                  title: Text(_condLabel(rule)),
                  subtitle: Text(_condDetail(rule),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(ctx);
                    final x = rule.ranges.first;
                    _jumpTo(x.r1, x.c1);
                    _partSetState(() {
                      _anchorRow = x.r1;
                      _anchorCol = x.c1;
                      _selRow = x.r2;
                      _selCol = x.c2;
                    });
                  },
                  trailing: IconButton(
                    tooltip: ctx.t('common.delete'),
                    icon: const Icon(AppIcons.delete),
                    onPressed: () {
                      _deleteCondRule(rule);
                      setSheet(() {});
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _deleteCondRule(XlsxCondRule rule) {
    final sheet = _sheet;
    if (sheet == null) return;
    void Function()? undo;
    void apply() => undo = sheet.deleteCondRule(rule);
    apply();
    _recordStep('excel.undo_cond_format', apply, () => undo?.call());
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  /// Dosyanın tema renkleri + tonları (renk seçicinin üst bölümü).
  List<List<int>> get _themeGrid =>
      ThemePalette.grid(_editor?.workbook.theme ?? const []);
}
