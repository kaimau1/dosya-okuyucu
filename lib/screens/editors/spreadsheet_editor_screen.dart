import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/formula_engine.dart';
import '../../services/xlsx_editor.dart';
import '../chat_screen.dart';

/// Excel görünümü: gerçek sütun genişlikleri, satır yükseklikleri, hücre
/// renkleri/yazı tipleri, birleştirilmiş hücreler. Hücreye dokun → üstteki
/// düzenleme çubuğundan değiştir (Excel'in formül çubuğu gibi).
class SpreadsheetEditorScreen extends StatefulWidget {
  final String path;
  final String name;
  final String plainText;
  const SpreadsheetEditorScreen({
    super.key,
    required this.path,
    required this.name,
    required this.plainText,
  });

  @override
  State<SpreadsheetEditorScreen> createState() =>
      _SpreadsheetEditorScreenState();
}

class _SpreadsheetEditorScreenState extends State<SpreadsheetEditorScreen> {
  static const _rowHeaderW = 46.0;
  // Satırlar tembel çizildiği için sınır yok (15 bin satırlık dosyada denendi);
  // sütunlar her satırda çizildiğinden 64 ile sınırlı.
  static const _maxCols = 64;

  XlsxEditor? _editor;
  int _sheetIndex = 0;
  String? _error;

  /// Kaydedilmemiş değişiklik var mı (başlıkta • ile gösterilir).
  bool _dirty = false;

  int _selRow = 0;
  int _selCol = 0;
  double _zoom = 1.0;
  final _cellField = TextEditingController();

  void _zoomBy(double f) =>
      setState(() => _zoom = (_zoom * f).clamp(0.5, 3.0));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cellField.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      _editor = XlsxEditor.parse(bytes);
      _syncField();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  XlsxSheet? get _sheet {
    final e = _editor;
    if (e == null || e.sheets.isEmpty) return null;
    return e.sheets[_sheetIndex];
  }

  String _valueAt(int r, int c) {
    final rows = _sheet?.rows;
    if (rows == null || r >= rows.length) return '';
    final row = rows[r];
    return c < row.length ? row[c] : '';
  }

  void _syncField() => _cellField.text = _valueAt(_selRow, _selCol);

  void _select(int r, int c) {
    setState(() {
      _selRow = r;
      _selCol = c;
    });
    _syncField();
  }

  void _applyCell(String value) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    editor.setCell(sheet.name, _selRow, _selCol, value);
    _dirty = true;
    setState(() {});
  }

  /// Yapısal işlem sonrası (satır/sütun ekle-sil) seçimi geçerli sınırlarda
  /// tutup formül çubuğunu tazeler.
  void _afterStructural() {
    final sheet = _sheet;
    if (sheet != null) {
      final maxRow = sheet.rows.isEmpty ? 0 : sheet.rows.length - 1;
      final maxCol = sheet.maxCols <= 0 ? 0 : sheet.maxCols - 1;
      _selRow = _selRow.clamp(0, maxRow);
      _selCol = _selCol.clamp(0, maxCol);
    }
    _dirty = true;
    setState(() {});
    _syncField();
  }

  void _insertRow({required bool below}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    editor.insertRow(sheet.name, below ? _selRow + 1 : _selRow);
    if (below) _selRow += 1;
    _afterStructural();
  }

  void _deleteRow() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    editor.deleteRow(sheet.name, _selRow);
    _afterStructural();
  }

  void _insertColumn({required bool right}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    editor.insertColumn(sheet.name, right ? _selCol + 1 : _selCol);
    if (right) _selCol += 1;
    _afterStructural();
  }

  void _deleteColumn() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    editor.deleteColumn(sheet.name, _selCol);
    _afterStructural();
  }

  Future<void> _save() async {
    final editor = _editor;
    if (editor == null) return;
    try {
      final bytes = editor.save();
      await File(widget.path).writeAsBytes(bytes);
      _dirty = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Kaydedildi. Kalıcı yer için ⋮ > Paylaş/Dışa aktar.')));
        setState(() {});
      }
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    }
  }

  Future<void> _export() async {
    final editor = _editor;
    if (editor == null) return;
    final f = File('${Directory.systemTemp.path}/${widget.name}');
    await f.writeAsBytes(editor.save());
    await Share.shareXFiles([XFile(f.path)], text: widget.name);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  static String _colLabel(int i) {
    var n = i;
    final sb = StringBuffer();
    do {
      sb.write(String.fromCharCode(65 + (n % 26)));
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return String.fromCharCodes(sb.toString().codeUnits.reversed);
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.name}${_dirty ? ' •' : ''}',
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Uzaklaştır',
            icon: const Icon(Icons.zoom_out),
            onPressed: editor == null ? null : () => _zoomBy(1 / 1.25),
          ),
          IconButton(
            tooltip: 'Yakınlaştır',
            icon: const Icon(Icons.zoom_in),
            onPressed: editor == null ? null : () => _zoomBy(1.25),
          ),
          IconButton(
            tooltip: 'Kaydet',
            icon: const Icon(Icons.save_outlined),
            onPressed: editor == null ? null : _save,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'export') _export();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Paylaş / Dışa aktar')),
            ],
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Açılamadı: $_error'))
          : editor == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _cellBar(),
                    _rowColBar(),
                    Expanded(child: _grid()),
                  ],
                ),
      bottomNavigationBar: editor == null || editor.sheets.length < 2
          ? null
          : _sheetTabs(editor),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            fileContext: widget.plainText,
            fileName: widget.name,
          ),
        )),
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('AI'),
      ),
    );
  }

  /// Excel'in formül çubuğu: seçili hücrenin adı + içeriği.
  Widget _cellBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 56,
            alignment: Alignment.center,
            child: Text('${_colLabel(_selCol)}${_selRow + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _cellField,
              onSubmitted: _applyCell,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Hücre içeriği',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Uygula',
            icon: const Icon(Icons.check),
            onPressed: () => _applyCell(_cellField.text),
          ),
        ],
      ),
    );
  }

  /// Seçili satır/sütun üzerinde ekle-sil işlemleri (Excel'in sağ tık menüsü gibi).
  Widget _rowColBar() {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          icon: Icon(icon),
          onPressed: onTap,
        );
    return Container(
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('Satır',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            btn(Icons.keyboard_arrow_up, 'Üste satır ekle',
                () => _insertRow(below: false)),
            btn(Icons.keyboard_arrow_down, 'Alta satır ekle',
                () => _insertRow(below: true)),
            btn(Icons.remove, 'Satırı sil', _deleteRow),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                  width: 1, height: 22, color: scheme.outlineVariant),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('Sütun',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            btn(Icons.keyboard_arrow_left, 'Sola sütun ekle',
                () => _insertColumn(right: false)),
            btn(Icons.keyboard_arrow_right, 'Sağa sütun ekle',
                () => _insertColumn(right: true)),
            btn(Icons.remove, 'Sütunu sil', _deleteColumn),
          ],
        ),
      ),
    );
  }

  Widget _sheetTabs(XlsxEditor editor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < editor.sheets.length; i++)
            Padding(
              padding: const EdgeInsets.all(4),
              child: ChoiceChip(
                label: Text(editor.sheets[i].name),
                selected: _sheetIndex == i,
                onSelected: (_) {
                  setState(() {
                    _sheetIndex = i;
                    _selRow = 0;
                    _selCol = 0;
                  });
                  _syncField();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _grid() {
    final sheet = _sheet;
    if (sheet == null) return const Center(child: Text('Sayfa yok.'));

    final rowCount = sheet.rows.length;
    final colCount = sheet.maxCols.clamp(1, _maxCols);
    var total = _rowHeaderW * _zoom;
    for (var c = 0; c < colCount; c++) {
      total += sheet.colWidth(c) * _zoom;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: total,
        child: Column(
          children: [
            Row(
              children: [
                _header('', _rowHeaderW * _zoom),
                for (var c = 0; c < colCount; c++)
                  _header(_colLabel(c), sheet.colWidth(c) * _zoom,
                      highlight: c == _selCol),
              ],
            ),
            Expanded(
              // Satırlar tembel çizilir; 2000 satırlık dosyalarda da akıcı kalır.
              child: ListView.builder(
                itemCount: rowCount,
                itemBuilder: (_, r) => _row(sheet, r, colCount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(XlsxSheet sheet, int r, int colCount) {
    final h = sheet.rowHeight(r) * _zoom;
    final cells = <Widget>[
      _header('${r + 1}', _rowHeaderW * _zoom,
          height: h, highlight: r == _selRow),
    ];

    for (var c = 0; c < colCount; c++) {
      final merge = _mergeAt(sheet, r, c);
      if (merge != null && !merge.isAnchor(r, c)) {
        // Birleştirmenin devamı: çapa hücre yerini zaten kapladı.
        if (merge.rowStart == r) continue;
        // Dikey birleştirmenin alt satırları: boş ama aynı zeminde.
        cells.add(
            _cell(sheet, r, c, sheet.colWidth(c) * _zoom, h, forceEmpty: true));
        continue;
      }
      var w = sheet.colWidth(c) * _zoom;
      if (merge != null) {
        for (var k = merge.colStart + 1; k <= merge.colEnd && k < colCount; k++) {
          w += sheet.colWidth(k) * _zoom;
        }
      }
      cells.add(_cell(sheet, r, c, w, h));
    }
    return Row(children: cells);
  }

  XlsxMerge? _mergeAt(XlsxSheet sheet, int r, int c) {
    for (final m in sheet.merges) {
      if (m.covers(r, c)) return m;
    }
    return null;
  }

  Widget _header(String text, double width,
      {double height = 30, bool highlight = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11 * _zoom)),
    );
  }

  Widget _cell(XlsxSheet sheet, int r, int c, double w, double h,
      {bool forceEmpty = false}) {
    final style = sheet.styleAt(r, c);
    final selected = r == _selRow && c == _selCol;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _select(r, c),
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: style?.background,
          border: Border.all(
            color: selected ? scheme.primary : Theme.of(context).dividerColor,
            width: selected ? 2 : 0.5,
          ),
        ),
        child: forceEmpty
            ? null
            : Text(
                // Formülse hesaplanmış sonucu göster (çubuk ham formülü tutar);
                // ardından hücrenin Excel sayı biçimini (yüzde/para/binlik) uygula.
                sheet.displayText(
                    r, c, FormulaEngine(sheet.rows).displayValue(r, c)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: style?.align ?? TextAlign.left,
                style: TextStyle(
                  fontSize: (style?.fontSize ?? 12) * _zoom,
                  fontWeight:
                      (style?.bold ?? false) ? FontWeight.bold : FontWeight.normal,
                  fontStyle:
                      (style?.italic ?? false) ? FontStyle.italic : FontStyle.normal,
                  color: style?.fontColor,
                ),
              ),
      ),
    );
  }
}
