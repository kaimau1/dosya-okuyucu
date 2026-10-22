part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenSheetTabsPart on _SpreadsheetEditorScreenState {
  Widget _sheetTabs(List<XlsxSheet> sheets) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in sheets)
            Padding(
              padding: const EdgeInsets.all(4),
              child: GestureDetector(
                // Sekmeye UZUN BASIŞ: yeniden adlandır / sil. Excel mobil de
                // sekme işlemlerini böyle sunuyor; ayrı bir düğme sekme
                // şeridini daraltırdı.
                onLongPress: () => _sheetActions(s),
                child: ChoiceChip(
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
                    _firstCol = 0;
                    _lastCol = 0;
                    _hits = const []; // eşleşmeler sayfaya özgü
                    _hitIndex = -1;
                  });
                  _syncField();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _updateColWindow());
                },
                ),
              ),
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
            Icons.arrow_forward_rounded,
            context.t('excel.move_sheet_right'),
            index >= 0 && index < count - 1
                ? () => _moveSheet(sheet, index + 1)
                : null),
        DocMoreItem(AppIcons.rename,
            context.t('excel.rename_sheet'), () => _renameSheet(sheet)),
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
      _dirty = true;
      _gridVersion++;
    });
    _syncField();
  }

  void _moveSheet(XlsxSheet sheet, int to) {
    final editor = _editor;
    if (editor == null || !editor.moveSheet(sheet.name, to)) return;
    _partSetState(() {
      _sheetIndex = editor.sheets.indexOf(sheet);
      _dirty = true;
    });
  }

  Future<void> _renameSheet(XlsxSheet sheet) async {
    final editor = _editor;
    if (editor == null) return;
    final name = await _askSheetName(context.t('excel.rename_sheet'), sheet.name);
    if (name == null || !mounted || name == sheet.name) return;
    if (editor.hasSheet(name)) {
      _snack(context.t('excel.sheet_name_taken'));
      return;
    }
    if (!editor.renameSheet(sheet.name, name)) return;
    _partSetState(() => _dirty = true);
  }

  Future<void> _deleteSheet(XlsxSheet sheet) async {
    final editor = _editor;
    if (editor == null) return;
    if (editor.sheets.length <= 1) {
      _snack(context.t('excel.last_sheet'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('excel.delete_sheet')),
        content: Text(ctx.t('excel.delete_sheet_confirm', {'name': sheet.name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('common.delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!editor.deleteSheet(sheet.name)) return;
    _partSetState(() {
      _sheetIndex = _sheetIndex.clamp(0, editor.sheets.length - 1);
      _selRow = 0;
      _selCol = 0;
      _anchorRow = 0;
      _anchorCol = 0;
      _dirty = true;
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
    ).then((v) => v == null || v.isEmpty ? null : v);
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
