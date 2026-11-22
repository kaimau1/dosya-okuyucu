part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenSheetTabsPart on _SpreadsheetEditorScreenState {
  Widget _sheetTabs(List<XlsxSheet> sheets) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm, vertical: Gap.xs),
          child: Row(
            children: [
              for (final s in sheets)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: Gap.xs),
                  child: _draggableTab(s, ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    avatar: s.layout.tabColorArgb == null
                        ? null
                        : CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(s.layout.tabColorArgb!)),
                    label: Text(s.name),
                    selected: _sheet?.name == s.name,
                    onSelected: (_) {
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
                  )),
                ),
              // Yeni sayfa — sekmelerin sonunda, Excel'deki "+" gibi.
              IconButton(
                tooltip: context.t('excel.add_sheet'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(AppIcons.add, size: 20),
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
    final controller = TextEditingController(
        text: '${XlsxRange.colName(_selCol)}${_selRow + 1}');
    final ref = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('excel.goto_cell')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
              labelText: context.t('excel.cell_reference'),
              hintText: context.t('excel.cell_reference_hint')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(context.t('excel.go')),
          ),
        ],
      ),
    );
    controller.dispose();
    final rc = XlsxRange.cellRef(ref?.trim());
    if (rc == null) return;
    _jumpTo(rc.$1, rc.$2);
  }
}
