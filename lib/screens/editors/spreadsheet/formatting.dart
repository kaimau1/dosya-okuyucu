part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenFormattingPart on _SpreadsheetEditorScreenState {
  void _applyStyle({bool? bold, bool? italic, TextAlign? align}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    // Aralık seçiliyse tüm aralığa uygulanır (Excel gibi).
    final r1 = math.min(_anchorRow, _selRow);
    final r2 = math.max(_anchorRow, _selRow);
    final c1 = math.min(_anchorCol, _selCol);
    final c2 = math.max(_anchorCol, _selCol);
    // Geri alma için ÖNCEKİ örtmeler yakalanır; `setCellStyle` dosyadaki
    // paylaşımlı stile değil bu örtme haritasına yazdığı için tersi budur.
    final name = sheet.name;
    final before = <CellRef, XlsxCellStyle?>{
      for (var r = r1; r <= r2; r++)
        for (var c = c1; c <= c2; c++)
          CellRef(r, c): sheet.overrideAt(r, c),
    };
    void applyNow() {
      for (var r = r1; r <= r2; r++) {
        for (var c = c1; c <= c2; c++) {
          editor.setCellStyle(name, r, c,
              bold: bold, italic: italic, align: align);
        }
      }
    }

    applyNow();
    _recordStep('excel.undo_format', applyNow, () {
      before.forEach((at, style) => sheet.patchStyle(at.row, at.col, style));
    });
    _dirty = true;
    _partSetState(() {});
  }

  /// Seçili aralığa görünüm değişikliği uygular ve **tek** geri alma adımı
  /// olarak kaydeder.
  ///
  /// [write] her hücreye ne yazılacağını, [restore] o hücrenin ÖNCEKİ hâlini
  /// geri koymayı bilir. İkisi de aynı `XlsxEditor` API'sini çağırır: böylece
  /// geri alma yalnız ekrandaki örtmeyi değil, **kaydetmeye giden izi** de
  /// eski hâline döndürür (yoksa geri alınan dolgu dosyaya yine yazılırdı).
  void _applyCellFormat(
    String label,
    void Function(XlsxEditor ed, String sheet, int r, int c) write,
    void Function(XlsxEditor ed, String sheet, int r, int c, XlsxCellStyle before)
        restore,
  ) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final range = _range;
    final name = sheet.name;
    final before = <CellRef, XlsxCellStyle>{
      for (var r = range.top; r <= range.bottom; r++)
        for (var c = range.left; c <= range.right; c++)
          CellRef(r, c): sheet.styleAt(r, c) ?? const XlsxCellStyle(),
    };
    void applyNow() {
      for (var r = range.top; r <= range.bottom; r++) {
        for (var c = range.left; c <= range.right; c++) {
          write(editor, name, r, c);
        }
      }
    }

    applyNow();
    _recordStep(label, applyNow, () {
      before.forEach((at, style) => restore(editor, name, at.row, at.col, style));
    });
    _dirty = true;
    _partSetState(() {});
  }

  void _applyFillColor(Color? color) => _applyCellFormat(
        'excel.undo_fill_color',
        (ed, s, r, c) => ed.setCellFill(s, r, c, color),
        (ed, s, r, c, before) => ed.setCellFill(s, r, c, before.background),
      );

  void _applyFontColor(Color? color) => _applyCellFormat(
        'excel.undo_font_color',
        (ed, s, r, c) => ed.setFontColor(s, r, c, color),
        (ed, s, r, c, before) => ed.setFontColor(s, r, c, before.fontColor),
      );

  void _applyWrap(bool wrap) => _applyCellFormat(
        'excel.undo_wrap',
        (ed, s, r, c) => ed.setWrapText(s, r, c, wrap),
        (ed, s, r, c, before) => ed.setWrapText(s, r, c, before.wrap),
      );

  /// Kenarlık ön ayarları — Excel'in "Kenarlıklar" menüsünün karşılığı.
  /// Değer `null` olan kenar SİLİNİR.
  void _applyBorder(Map<String, String?> sides) => _applyCellFormat(
        'excel.undo_border',
        (ed, s, r, c) => ed.setCellBorder(s, r, c, sides),
        (ed, s, r, c, before) => ed.setCellBorder(s, r, c, {
          'left': before.border.left.visible ? before.border.left.style : null,
          'right': before.border.right.visible ? before.border.right.style : null,
          'top': before.border.top.visible ? before.border.top.style : null,
          'bottom':
              before.border.bottom.visible ? before.border.bottom.style : null,
        }),
      );

  /// Seçili aralığı birleştirir; imleç zaten birleşik bir hücredeyse çözer.
  void _toggleMerge() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final name = sheet.name;
    final existing = sheet.mergeAt(_selRow, _selCol);
    if (existing != null) {
      void undo() => editor.mergeCells(name, existing.rowStart,
          existing.colStart, existing.rowEnd, existing.colEnd);
      void apply() => editor.unmergeAt(name, _selRow, _selCol);
      apply();
      _recordStep('excel.undo_unmerge', apply, undo);
    } else {
      final range = _range;
      if (range.cellCount < 2) {
        _snack(context.t('excel.merge_needs_range'));
        return;
      }
      void apply() => editor.mergeCells(
          name, range.top, range.left, range.bottom, range.right);
      void undo() => editor.unmergeAt(name, range.top, range.left);
      apply();
      _recordStep('excel.undo_merge', apply, undo);
    }
    _dirty = true;
    _gridVersion++;
    _partSetState(() {});
  }

  /// Renk seçme sayfası. [onPick] `null` alırsa "yok / otomatik" seçilmiştir.
  Future<void> _pickColor(String title, void Function(Color?) onPick) async {
    final chosen = await showModalBottomSheet<Object?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final argb in _SpreadsheetEditorScreenState._palette)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, Color(argb)),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(argb),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Theme.of(ctx).colorScheme.outlineVariant),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, 'none'),
              icon: const Icon(Icons.format_color_reset_rounded),
              label: Text(ctx.t('excel.color_none')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen == null) return; // sayfa kapatıldı — değişiklik yok
    onPick(chosen is Color ? chosen : null);
  }

  /// Seçili aralığa sayı biçimi uygular (geri alınabilir).
  void _applyNumberFormat(String Function(String current) codeFor) {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _range;
    final before = <(int, int), String>{};
    final after = <(int, int), String>{};
    for (var row = r.top; row <= r.bottom; row++) {
      for (var col = r.left; col <= r.right; col++) {
        final current = sheet.numFmtCode(row, col);
        final next = codeFor(current);
        if (next == current) continue;
        before[(row, col)] = current;
        after[(row, col)] = next;
      }
    }
    if (after.isEmpty) return;
    void write(Map<(int, int), String> map) {
      map.forEach((at, code) => sheet.setNumberFormat(at.$1, at.$2, code));
    }

    write(after);
    _recordStep('excel.undo_number_format', () => write(after), () => write(before));
    _dirty = true;
    _partSetState(() {});
  }
}
