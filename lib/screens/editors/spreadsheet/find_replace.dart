part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenFindReplacePart on _SpreadsheetEditorScreenState {
  /// Etkin sayfada metin arar (büyük/küçük harf duyarsız).
  ///
  /// Excel'in "Bul"u varsayılan olarak FORMÜLLERDE arar; biz de ham metni
  /// tararız. Ek olarak formül hücrelerinde SONUCA da bakarız: kullanıcı
  /// ekranda gördüğü değeri arıyor olabilir.
  void _runFind(String query) {
    final sheet = _sheet;
    final q = query.trim().toLowerCase();
    if (sheet == null || q.isEmpty) {
      _partSetState(() {
        _hits = const [];
        _hitIndex = -1;
      });
      return;
    }
    final engine = _engineFor(sheet);
    final hits = <(int, int)>[];
    for (var r = 0; r < sheet.rows.length && hits.length < _SpreadsheetEditorScreenState._maxHits; r++) {
      final row = sheet.rows[r];
      for (var c = 0; c < row.length && hits.length < _SpreadsheetEditorScreenState._maxHits; c++) {
        final raw = row[c];
        if (raw.isEmpty) continue;
        if (raw.toLowerCase().contains(q) ||
            (raw.startsWith('=') &&
                engine.displayValue(r, c).toLowerCase().contains(q))) {
          hits.add((r, c));
        }
      }
    }
    _partSetState(() {
      _hits = hits;
      _hitIndex = hits.isEmpty ? -1 : 0;
    });
    if (hits.isNotEmpty) _jumpTo(hits.first.$1, hits.first.$2);
  }

  void _stepHit(int delta) {
    if (_hits.isEmpty) return;
    var i = (_hitIndex + delta) % _hits.length;
    if (i < 0) i += _hits.length;
    _partSetState(() => _hitIndex = i);
    _jumpTo(_hits[i].$1, _hits[i].$2);
  }

  void _toggleFind() {
    _partSetState(() {
      _finding = !_finding;
      if (!_finding) {
        _findField.clear();
        _hits = const [];
        _hitIndex = -1;
      }
    });
  }

  Widget _findBar() {
    final typed = _findField.text.trim().isNotEmpty;
    final counter = !typed
        ? ''
        : _hits.isEmpty
            ? context.t('find.none')
            : '${_hitIndex + 1}/${_hits.length}'
                '${_hits.length >= _SpreadsheetEditorScreenState._maxHits ? '+' : ''}';
    return DocFindBar(
      controller: _findField,
      hint: context.t('excel.find_in_sheet'),
      countLabel: counter,
      onChanged: _runFind,
      onSubmitted: (_) => _stepHit(1),
      onPrev: _hits.isEmpty ? null : () => _stepHit(-1),
      onNext: _hits.isEmpty ? null : () => _stepHit(1),
      onClose: _toggleFind,
    );
  }

  /// Bul çubuğunun ikinci satırı: **değiştir**.
  Widget _replaceBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replaceField,
              style: context.type.body,
              decoration: DocFindBar.decoration(
                context,
                hint: context.t('excel.replace_with'),
                icon: AppIcons.findReplace,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _hits.isEmpty ? null : () => _replaceCurrent(),
            child: Text(context.t('excel.replace')),
          ),
          TextButton(
            onPressed: _hits.isEmpty ? null : _replaceAll,
            child: Text(context.t('excel.replace_all')),
          ),
        ],
      ),
    );
  }

  /// Etkin eşleşmedeki metni değiştirir ve bir sonrakine geçer.
  void _replaceCurrent() {
    final sheet = _sheet;
    if (sheet == null || _hitIndex < 0 || _hitIndex >= _hits.length) return;
    final query = _findField.text;
    if (query.isEmpty) return;
    final (r, c) = _hits[_hitIndex];
    final old = sheet.rawAt(r, c);
    final next = _SpreadsheetEditorScreenState._replaceOnce(old, query, _replaceField.text);
    if (next == old) return;
    _editCells('excel.undo_replace', {CellRef(r, c): next});
    // Eşleşme listesi bayatladı (hücre artık aranan metni içermeyebilir).
    _runFind(query);
    if (_hits.isNotEmpty) _stepHit(0);
  }

  /// Sayfadaki tüm eşleşmeleri tek geri alma adımında değiştirir.
  void _replaceAll() {
    final sheet = _sheet;
    if (sheet == null) return;
    final query = _findField.text;
    if (query.isEmpty) return;
    final to = _replaceField.text;
    final values = <CellRef, String>{};
    for (final (r, c) in _hits) {
      final old = sheet.rawAt(r, c);
      final next = _SpreadsheetEditorScreenState._replaceAllIn(old, query, to);
      if (next != old) values[CellRef(r, c)] = next;
    }
    if (values.isEmpty) {
      _snack(context.t('excel.replace_none'));
      return;
    }
    final n = values.length;
    _editCells('excel.undo_replace', values);
    _runFind(query);
    _snack(context.t('excel.replaced_count', {'n': n}));
  }

  /// Sütun genişliği (karakter) ya da satır yüksekliği (punto) diyaloğu.
  /// Excel'de fare ile başlık kenarı sürüklenir; telefonda kenar hedefi
  /// parmakla vurulamayacak kadar ince, o yüzden başlığa UZUN BASINCA açılır.
  Future<void> _showSizeDialog({int? col, int? row}) async {
    final sheet = _sheet;
    if (sheet == null) return;
    final isCol = col != null;
    final defaultValue = isCol
        ? sheet.layout.defaultColWidthChars
        : sheet.layout.defaultRowHeightPt;
    final maxValue = isCol ? 255.0 : 409.0;
    var value = (isCol
            ? sheet.layout.colWidthChars(col)
            : sheet.layout.rowHeightPt(row!))
        .clamp(0.0, maxValue)
        .toDouble();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isCol
              ? context.t('excel.column_width_of',
                  {'col': XlsxRange.colName(col)})
              : context.t('excel.row_height_of', {'row': row! + 1})),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value <= 0
                    ? context.t('excel.hidden')
                    : '${value.toStringAsFixed(2)} '
                        '${context.t(isCol ? 'excel.unit_chars' : 'excel.unit_points')}',
                style: context.type.heading.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              ),
              Slider(
                value: value,
                max: maxValue,
                divisions: (maxValue * 4).round(),
                onChanged: (v) => setLocal(() => value = v),
              ),
              TextButton(
                onPressed: () => setLocal(() => value = defaultValue),
                child: Text(context.t('excel.default_value',
                    {'value': defaultValue.toStringAsFixed(2)})),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.t('common.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.t('common.apply'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    // Aralık seçiliyse tüm seçili sütunlara/satırlara uygulanır (Excel gibi).
    if (isCol) {
      final c1 = math.min(_anchorCol, _selCol);
      final c2 = math.max(_anchorCol, _selCol);
      final range = (col >= c1 && col <= c2) ? [for (var c = c1; c <= c2; c++) c] : [col];
      for (final c in range) {
        sheet.setColWidthChars(c, value);
      }
    } else {
      final r1 = math.min(_anchorRow, _selRow);
      final r2 = math.max(_anchorRow, _selRow);
      final range = (row! >= r1 && row <= r2) ? [for (var r = r1; r <= r2; r++) r] : [row];
      for (final r in range) {
        sheet.setRowHeightPt(r, value);
      }
    }
    _dirty = true;
    _gridVersion++;
    _partSetState(() {});
  }
}
