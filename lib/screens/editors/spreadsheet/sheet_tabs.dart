part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenSheetTabsPart on _SpreadsheetEditorScreenState {
  Widget _sheetTabs(List<XlsxSheet> sheets) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
          bottom:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        ),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm, vertical: 6),
          child: Row(
            children: [
              for (final s in sheets)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: _draggableTab(
                    s,
                    Builder(builder: (_) {
                      final selected = _sheet?.name == s.name;
                      final tabColor = s.layout.tabColorArgb == null
                          ? null
                          : Color(s.layout.tabColorArgb!);
                      return AnimatedContainer(
                        duration: Motion.of(context, Motion.short),
                        curve: Motion.standard,
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.surfaceContainerLowest
                              : scheme.surfaceContainerHigh
                                  .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(Radii.pill),
                          border: Border.all(
                            color: selected
                                ? (tabColor ?? scheme.primary)
                                    .withValues(alpha: 0.7)
                                : scheme.outlineVariant.withValues(alpha: 0.45),
                            width: selected ? 1.5 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.studioShadow(dark),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () {
                              _endEdit();
                              final idx = _editor?.sheets.indexOf(s) ?? 0;
                              _partSetState(() {
                                _sheetIndex = idx < 0 ? 0 : idx;
                                _selRow = 0;
                                _selCol = 0;
                                _anchorRow = 0;
                                _anchorCol = 0;
                                _hits = const []; // eşleşmeler sayfaya özgü
                                _hitIndex = -1;
                              });
                              _resetColWindow();
                              _syncField();
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _updateColWindow(force: true));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (tabColor != null) ...[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: tabColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    s.name,
                                    style: context.type.small.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              // Yeni sayfa — sekmelerin sonunda, Excel'deki "+" gibi.
              IconButton(
                tooltip: context.t('excel.add_sheet'),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor:
                      scheme.primaryContainer.withValues(alpha: 0.65),
                  foregroundColor: scheme.primary,
                  shape: const CircleBorder(),
                  side: BorderSide(
                    color: scheme.primary.withValues(alpha: 0.28),
                  ),
                  minimumSize: const Size(32, 32),
                ),
                icon: const Icon(AppIcons.add, size: 18),
                onPressed: _addSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sekmeye UZUN BASIŞ: parmak kıpırdamadan bırakılırsa işlem menüsü
  /// (yeniden adlandır / sil …; Excel mobil de sekme işlemlerini böyle
  /// sunuyor), basılı tutup başka sekmenin üstüne sürüklenirse sayfa oraya
  /// taşınır. İkisi aynı jestte: `LongPressDraggable` uzun basışı kendisi
  /// yakaladığı için menü, kabul edilmemiş ve neredeyse hiç yer
  /// değiştirmemiş bir sürüklemenin sonundan açılır.
  Widget _draggableTab(XlsxSheet sheet, Widget chip) {
    final scheme = Theme.of(context).colorScheme;
    Offset? start;
    var moved = 0.0;
    return DragTarget<XlsxSheet>(
      onWillAcceptWithDetails: (d) => d.data != sheet,
      onAcceptWithDetails: (d) {
        final to = _editor?.sheets.indexOf(sheet) ?? -1;
        if (to < 0) return;
        AppHaptics.drop();
        _moveSheet(d.data, to);
      },
      builder: (context, cand, _) => LongPressDraggable<XlsxSheet>(
        key: ValueKey('sheet-tab-${sheet.name}'),
        data: sheet,
        // Ayarlardaki titreşim anahtarına uysun diye kendi titreşimimiz.
        hapticFeedbackOnStart: false,
        onDragStarted: () {
          AppHaptics.longPress();
          start = null;
          moved = 0;
        },
        onDragUpdate: (d) {
          start ??= d.globalPosition;
          moved = (d.globalPosition - start!).distance;
        },
        onDragEnd: (d) {
          if (!d.wasAccepted && moved < 24) _sheetActions(sheet);
        },
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(sheet.name),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: chip),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: cand.isEmpty
                ? null
                : BorderDirectional(
                    start: BorderSide(color: scheme.primary, width: 3)),
          ),
          child: chip,
        ),
      ),
    );
  }

  /// Sekmeye uzun basınca: sola/sağa taşı, yeniden adlandır, sil.
  ///
  /// Sayfa **taşıma** Faz 9'da geldi (Y2): `excel` paketi çıkınca sıra
  /// kendi yazıcımızın elinde (`XlsxEditor.moveSheet` → `<sheets>` sırası ve
  /// yerel adların `localSheetId`si).
  void _sheetActions(XlsxSheet sheet) {
    _endEdit();
    final index = _editor?.sheets.indexOf(sheet) ?? -1;
    final count = _editor?.sheets.length ?? 0;
    DocMoreSheet.show(context, [
      DocMoreGroup(sheet.name, [
        DocMoreItem(AppIcons.back, context.t('excel.move_sheet_left'),
            index > 0 ? () => _moveSheet(sheet, index - 1) : null),
        DocMoreItem(
            AppIcons.arrowForward,
            context.t('excel.move_sheet_right'),
            index >= 0 && index < count - 1
                ? () => _moveSheet(sheet, index + 1)
                : null),
        DocMoreItem(AppIcons.rename,
            context.t('excel.rename_sheet'), () => _renameSheet(sheet)),
        DocMoreItem(AppIcons.copy, context.t('excel.duplicate_sheet'),
            () => _duplicateSheet(sheet)),
        DocMoreItem(AppIcons.palette, context.t('excel.tab_color'),
            () => _pickTabColor(sheet)),
        DocMoreItem(AppIcons.hidden, context.t('excel.hide_sheet'),
            () => _hideSheet(sheet)),
        if (_editor?.sheets.any((s) => s.layout.hidden) ?? false)
          DocMoreItem(AppIcons.hiddenOff, context.t('excel.unhide_sheet'),
              _unhideSheet),
        DocMoreItem(AppIcons.delete, context.t('excel.delete_sheet'),
            () => _deleteSheet(sheet),
            danger: true),
      ]),
    ]);
  }

  Future<void> _addSheet() async {
    final editor = _editor;
    if (editor == null) return;
    _endEdit();
    // Kullanılmayan ilk "Sayfa N" önerilir.
    var n = editor.sheets.length + 1;
    while (editor.hasSheet(context.t('excel.sheet_name', {'n': n}))) {
      n++;
    }
    final name = await _askSheetName(
        context.t('excel.add_sheet'), context.t('excel.sheet_name', {'n': n}));
    if (name == null || !mounted) return;
    if (editor.hasSheet(name)) {
      _snack(context.t('excel.sheet_name_taken'));
      return;
    }
    final added = editor.addSheet(name);
    if (added == null) return;
    _partSetState(() {
      _sheetIndex = editor.sheets.indexOf(added);
      _selRow = 0;
      _selCol = 0;
      _anchorRow = 0;
      _anchorCol = 0;
      _session.changed();
      _gridVersion++;
    });
    _syncField();
  }

  void _moveSheet(XlsxSheet sheet, int to) {
    final editor = _editor;
    if (editor == null || !editor.moveSheet(sheet.name, to)) return;
    _partSetState(() {
      _sheetIndex = editor.sheets.indexOf(sheet);
      _session.changed();
    });
  }

  void _migrateSheetNameKeys(String from, String to) {
    final stack = _undoBySheet.remove(from);
    if (stack != null) _undoBySheet[to] = stack;
    final pivot = _pivots.remove(from);
    if (pivot != null) _pivots[to] = pivot;
    for (final k in _pivots.keys.toList()) {
      final link = _pivots[k]!;
      if (link.source == from) {
        _pivots[k] = _PivotLink(to, link.range, link.spec);
      }
    }
    if (_clipSheetName == from) _clipSheetName = to;
    if (_arrowsSheet == from) _arrowsSheet = to;
  }

  Future<void> _renameSheet(XlsxSheet sheet) async {
    final editor = _editor;
    if (editor == null) return;
    final oldName = sheet.name;
    final name = await _askSheetName(context.t('excel.rename_sheet'), oldName);
    if (name == null || !mounted || name == oldName) return;
    if (editor.hasSheet(name)) {
      _snack(context.t('excel.sheet_name_taken'));
      return;
    }
    if (!editor.renameSheet(oldName, name)) return;
    _migrateSheetNameKeys(oldName, name);
    _recordStep('excel.rename_sheet', () {
      if (editor.renameSheet(oldName, name)) {
        _migrateSheetNameKeys(oldName, name);
      }
    }, () {
      if (editor.renameSheet(name, oldName)) {
        _migrateSheetNameKeys(name, oldName);
      }
    });
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  Future<void> _deleteSheet(XlsxSheet sheet) async {
    final editor = _editor;
    if (editor == null) return;
    if (editor.sheets.length <= 1) {
      _snack(context.t('excel.last_sheet'));
      return;
    }
    final ok = await showAppConfirm(
        context,
        title: context.t('excel.delete_sheet'),
        message: context.t('excel.delete_sheet_confirm', {'name': sheet.name}),
        confirmLabel: context.t('common.delete'),
        destructive: true,
    );
    if (ok != true || !mounted) return;
    if (!editor.deleteSheet(sheet.name)) return;
    _partSetState(() {
      _sheetIndex = _sheetIndex.clamp(0, editor.sheets.length - 1);
      _selRow = 0;
      _selCol = 0;
      _anchorRow = 0;
      _anchorCol = 0;
      _session.changed();
      _gridVersion++;
    });
    _syncField();
  }

  Future<String?> _askSheetName(String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              InputDecoration(labelText: ctx.t('excel.sheet_name_label')),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(ctx.t('common.ok'))),
        ],
      ),
    ).whenComplete(ctrl.dispose).then((v) => v == null || v.isEmpty ? null : v);
  }

  Future<void> _showGoTo() async {
    final sheet = _sheet;
    final lastRow = math.max(0, (sheet?.maxRows ?? 1) - 1);
    final lastCol = math.max(0, (sheet?.maxCols ?? 1) - 1);
    final lastRowRef = '${XlsxRange.colName(_selCol)}${lastRow + 1}';
    final lastCellRef = '${XlsxRange.colName(lastCol)}${lastRow + 1}';
    final controller = TextEditingController(
        text: '${XlsxRange.colName(_selCol)}${_selRow + 1}');
    controller.selection =
        TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    final ref = await showAppSheet<String>(
      context,
      title: context.t('excel.goto_cell'),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        Widget quickPill(IconData icon, String label, String coord) => Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(Radii.control),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.control),
                onTap: () => Navigator.pop(ctx, coord),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md, vertical: Gap.sm + 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.control),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: ctx.type.small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          coord,
                          style: ctx.type.caption.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: ctx.t('excel.cell_reference'),
                        hintText: ctx.t('excel.cell_reference_hint'),
                        prefixIcon: const Icon(AppIcons.pageJump, size: 20),
                      ),
                      onSubmitted: (v) => Navigator.pop(ctx, v),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: Gap.lg, vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx, controller.text),
                    child: Text(ctx.t('excel.go')),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Text(
                ctx.t('excel.goto_quick'),
                style: ctx.type.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  quickPill(AppIcons.home, ctx.t('excel.goto_start'), 'A1'),
                  quickPill(AppIcons.arrowDown, ctx.t('excel.goto_last_row'),
                      lastRowRef),
                  quickPill(AppIcons.fitScreen, ctx.t('excel.goto_last_cell'),
                      lastCellRef),
                ],
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    final rc = XlsxRange.cellRef(ref?.trim());
    if (rc == null) return;
    _jumpTo(rc.$1, rc.$2);
  }
}
