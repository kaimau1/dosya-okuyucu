import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../models/document.dart';
import '../../services/csv_codec.dart';
import '../../services/text_decode.dart';
import '../../services/formula_engine.dart';
import '../../services/xlsx_editor.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/pinch_zoom_area.dart';
import '../chat_screen.dart';

/// Excel görünümü: gerçek sütun genişlikleri, satır yükseklikleri, hücre
/// renkleri/yazı tipleri, birleştirilmiş hücreler. Hücreye dokun → seç;
/// seçili hücreye tekrar dokun → hücrenin İÇİNDE yaz. Üstteki formül çubuğu
/// aynı içeriği gösterir (Excel'in fx çubuğu gibi).
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

  /// Formül çubuğu ile hücre içi düzenleme AYNI controller'ı paylaşır:
  /// hücrede yazdıkça çubuk (ve tersi) bedavaya güncellenir. Aynı anda tek
  /// alan düzenlenebilir durumda olduğu için çakışma yok.
  final _cellField = TextEditingController();

  /// Hücrenin içinde yazma açık mı (seçili hücreye ikinci dokunuş).
  bool _editing = false;

  // Pinch zoom ortak PinchZoomArea'dan gelir; ölçek burada tutulur ki hücre
  // metrikleri/yazılar bununla çizilsin (bırakınca net yeniden çizim).
  double _zoom = 1;
  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cellField.dispose();
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  double get _headerH => 30 * _zoom;

  /// Pinch odağındaki içerik yerinde kalsın: (ofset+odak)*çarpan-odak.
  void _fixScroll(double f, Offset focal) {
    if (_hCtrl.hasClients) {
      _hCtrl.jumpTo(((_hCtrl.offset + focal.dx) * f - focal.dx)
          .clamp(0.0, _hCtrl.position.maxScrollExtent));
    }
    if (_vCtrl.hasClients) {
      _vCtrl.jumpTo(((_vCtrl.offset + focal.dy) * f - focal.dy)
          .clamp(0.0, _vCtrl.position.maxScrollExtent));
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      // Çözümleme arka plan isolate'inde: excel paketinin decodeBytes'ı çok
      // hücreli dosyada onlarca saniye sürüyor; ana izlekte koşarsa açılışta
      // donma → ANR → çökme (996×26 gerçek dosyada görüldü, bkz. HAFIZA).
      try {
        _editor = await compute(XlsxEditor.parse, bytes);
      } catch (_) {
        // Sonuç isolate'ten taşınamazsa/spawn edilemezse ana izlekte çöz.
        _editor = XlsxEditor.parse(bytes);
      }
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
    if (r == _selRow && c == _selCol) {
      // Seçili hücreye ikinci dokunuş = hücre içinde yazma. Çift dokunuş DEĞİL:
      // kDoubleTapTimeout tek dokunuşu 300 ms geciktirir (bkz. HAFIZA).
      if (_editing) return;
      _syncField();
      _cellField.selection =
          TextSelection.collapsed(offset: _cellField.text.length);
      setState(() => _editing = true);
      return;
    }
    _endEdit();
    setState(() {
      _selRow = r;
      _selCol = c;
    });
    _syncField();
  }

  /// Hücre içi düzenlemeyi kapatır; içerik gerçekten değiştiyse yazar
  /// (değişmediyse dosya "kirli" işaretlenmez).
  void _endEdit() {
    if (!_editing) return;
    final changed = _cellField.text != _valueAt(_selRow, _selCol);
    _editing = false;
    if (changed) {
      _applyCell(_cellField.text); // kendi setState'i var
    } else {
      setState(() {});
    }
  }

  /// Enter: yaz ve Excel'deki gibi bir alt hücreye geç.
  void _commitAndMoveDown(int rowCount) {
    _endEdit();
    if (_selRow + 1 < rowCount) _select(_selRow + 1, _selCol);
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
    _editing = false; // satır/sütun kayınca açık hücre editörü yanlış yere yazar
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
    _endEdit(); // hücrede yazılmakta olan içerik kaydın dışında kalmasın
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

  /// Etkin sayfayı CSV olarak dışa aktarır (Türkçe Excel `;` ayracıyla açsın
  /// diye noktalı virgül; alan içi ayraç/tırnak CsvCodec'te otomatik kaçırılır).
  /// Kodlama kullanıcıya sorulur: modern (UTF-8 BOM) ya da eski (Windows-1254).
  Future<void> _exportCsv() async {
    final sheet = _sheet;
    if (sheet == null) return;
    final enc = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('CSV kodlaması'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'utf8'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('UTF-8 (önerilir)'),
              subtitle: Text('Modern Excel / Google E-Tablolar'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'cp1254'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Windows-1254'),
              subtitle: Text('Eski Türkçe Excel / Not Defteri'),
            ),
          ),
        ],
      ),
    );
    if (enc == null) return; // vazgeçildi
    try {
      final csv = CsvCodec.encode(sheet.rows, delimiter: ';');
      final base = widget.name.replaceAll(RegExp(r'\.[^.]*$'), '');
      final f = File('${Directory.systemTemp.path}/$base.csv');
      // UTF-8: BOM ekli (Excel Türkçe'yi doğru açar). cp1254: eski sistem uyumu.
      final bytes = enc == 'cp1254'
          ? TextDecode.encodeCp1254(csv)
          : utf8.encode('﻿$csv');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)], text: '$base.csv');
    } catch (e) {
      _snack('CSV dışa aktarılamadı: $e');
    }
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
    return OfficeShell(
      kind: DocKind.spreadsheet,
      title: widget.name,
      dirty: _dirty,
      actions: [
        IconButton(
          tooltip: 'Kaydet',
          icon: const Icon(Icons.save_outlined),
          onPressed: editor == null ? null : _save,
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'export') _export();
            if (v == 'csv') _exportCsv();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'export', child: Text('Paylaş / Dışa aktar')),
            PopupMenuItem(value: 'csv', child: Text('CSV olarak dışa aktar')),
          ],
        ),
      ],
      body: _error != null
          ? Center(child: Text('Açılamadı: $_error'))
          : editor == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _cellBar(),
                    _formulaPreview(),
                    _rowColBar(),
                    Expanded(
                      child: PinchZoomArea(
                        minZoom: 0.3,
                        maxZoom: 3,
                        onCommitted: _fixScroll,
                        builder: (context, zoom, physics) {
                          _zoom = zoom;
                          return _grid(physics);
                        },
                      ),
                    ),
                  ],
                ),
      bottomBar: editor == null || editor.sheets.length < 2
          ? null
          : _sheetTabs(editor),
      fab: FloatingActionButton.extended(
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
              // Formül yazılırken canlı sonuç önizlemesi için yeniden çiz.
              onChanged: (_) => setState(() {}),
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

  /// Formül çubuğunun altında, `=` ile başlayan içerik için canlı sonuç
  /// (`= 42` gibi). Excel'in formül girerken gösterdiği önizlemenin karşılığı.
  Widget _formulaPreview() {
    final sheet = _sheet;
    final text = _cellField.text;
    if (sheet == null || !text.startsWith('=') || text.length < 2) {
      return const SizedBox.shrink();
    }
    final result = FormulaEngine(sheet.rows).preview(text, _selRow, _selCol);
    if (result.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(70, 0, 12, 6),
      child: Text(
        '= $result',
        style: TextStyle(
          fontSize: 13,
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Seçili hücreye yazı biçimi uygular (kalın/italik/hizalama) — Excel'in
  /// giriş sekmesindeki temel biçim düğmeleri.
  void _applyStyle({bool? bold, bool? italic, TextAlign? align}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    editor.setCellStyle(sheet.name, _selRow, _selCol,
        bold: bold, italic: italic, align: align);
    _dirty = true;
    setState(() {});
  }

  /// Seçili satır/sütun üzerinde ekle-sil işlemleri (Excel'in sağ tık menüsü gibi).
  Widget _rowColBar() {
    final scheme = Theme.of(context).colorScheme;
    final selStyle = _sheet?.styleAt(_selRow, _selCol);
    Widget btn(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          icon: Icon(icon),
          onPressed: onTap,
        );
    Widget toggle(IconData icon, String tip, bool active, VoidCallback onTap) =>
        IconButton(
          tooltip: tip,
          isSelected: active,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          style: active
              ? IconButton.styleFrom(backgroundColor: scheme.primaryContainer)
              : null,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                  width: 1, height: 22, color: scheme.outlineVariant),
            ),
            // Hücre biçimi: kalın/italik + hizalama (seçili hücreye uygulanır).
            toggle(Icons.format_bold, 'Kalın', selStyle?.bold ?? false,
                () => _applyStyle(bold: !(selStyle?.bold ?? false))),
            toggle(Icons.format_italic, 'İtalik', selStyle?.italic ?? false,
                () => _applyStyle(italic: !(selStyle?.italic ?? false))),
            toggle(Icons.format_align_left, 'Sola yasla',
                selStyle?.align == TextAlign.left,
                () => _applyStyle(align: TextAlign.left)),
            toggle(Icons.format_align_center, 'Ortala',
                selStyle?.align == TextAlign.center,
                () => _applyStyle(align: TextAlign.center)),
            toggle(Icons.format_align_right, 'Sağa yasla',
                selStyle?.align == TextAlign.right,
                () => _applyStyle(align: TextAlign.right)),
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
                  _endEdit();
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

  Widget _grid(ScrollPhysics? physics) {
    final sheet = _sheet;
    if (sheet == null) return const Center(child: Text('Sayfa yok.'));

    final rowCount = sheet.rows.length;
    final colCount = sheet.maxCols.clamp(1, _maxCols);
    // Formül motoru kare başına BİR kez kurulur (eskiden her hücrede yeniden
    // kuruluyordu — 25 bin hücrelik dosyada gereksiz yük).
    final engine = FormulaEngine(sheet.rows);
    var total = _rowHeaderW * _zoom;
    for (var c = 0; c < colCount; c++) {
      total += sheet.colWidth(c) * _zoom;
    }

    return SingleChildScrollView(
      controller: _hCtrl,
      physics: physics,
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
                controller: _vCtrl,
                physics: physics,
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 88),
                itemCount: rowCount,
                itemBuilder: (_, r) => _row(sheet, engine, r, colCount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(XlsxSheet sheet, FormulaEngine engine, int r, int colCount) {
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
        cells.add(_cell(sheet, engine, r, c, sheet.colWidth(c) * _zoom, h,
            forceEmpty: true));
        continue;
      }
      var w = sheet.colWidth(c) * _zoom;
      if (merge != null) {
        for (var k = merge.colStart + 1; k <= merge.colEnd && k < colCount; k++) {
          w += sheet.colWidth(k) * _zoom;
        }
      }
      cells.add(_cell(sheet, engine, r, c, w, h));
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
      {double? height, bool highlight = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height ?? _headerH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Seçili satır/sütun başlığı Excel'deki gibi marka yeşiliyle vurgulanır.
        color: highlight
            ? OfficeColors.excel.withOpacity(0.18)
            : scheme.surfaceContainerHighest,
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11 * _zoom)),
    );
  }

  Widget _cell(XlsxSheet sheet, FormulaEngine engine, int r, int c, double w,
      double h,
      {bool forceEmpty = false}) {
    final style = sheet.styleAt(r, c);
    final selected = r == _selRow && c == _selCol;

    return GestureDetector(
      onTap: () => _select(r, c),
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 4 * _zoom),
        decoration: BoxDecoration(
          color: style?.background,
          // Seçim çerçevesi Excel yeşili — Office kimliği hücrede de hissedilir.
          border: Border.all(
            color: selected
                ? OfficeColors.excel
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 0.5,
          ),
        ),
        child: forceEmpty
            ? null
            : (selected && _editing)
            ? TextField(
                controller: _cellField,
                autofocus: true,
                maxLines: 1,
                onSubmitted: (_) => _commitAndMoveDown(sheet.rows.length),
                onTapOutside: (_) => _endEdit(),
                textInputAction: TextInputAction.done,
                textAlign: style?.align ?? TextAlign.left,
                style: TextStyle(fontSize: (style?.fontSize ?? 12) * _zoom),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : Text(
                // Formülse hesaplanmış sonucu göster (çubuk ham formülü tutar);
                // ardından hücrenin Excel sayı biçimini (yüzde/para/binlik) uygula.
                sheet.displayText(r, c, engine.displayValue(r, c)),
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
