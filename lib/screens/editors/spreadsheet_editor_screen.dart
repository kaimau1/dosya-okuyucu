import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, RenderMetaData;
import 'package:share_plus/share_plus.dart';

import '../../core/excel_format.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../services/csv_codec.dart';
import '../../services/text_decode.dart';
import '../../services/formula_engine.dart';
import '../../services/xlsx_editor.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/pinch_zoom_area.dart';
import '../../widgets/sheet_cell.dart';
import '../../widgets/translate_flow.dart';
import '../chat_screen.dart';

/// Excel görünümü — hedef: dosya telefonda **Excel'deki gibi** görünsün.
///
/// - Satır/sütun başlıkları SABİT (kaydırınca kaçmaz), Excel'deki gibi.
/// - Dosyadaki **dondurulmuş bölmeler** (pane frozen) uygulanır.
/// - Hücre dolgusu, kenarlıkları, yazı tipi/boyutu/rengi, dikey+yatay
///   hizalama, metin kaydırma, girinti ve sayı biçimi (para/yüzde/tarih)
///   `styles.xml`den okunur (bkz. xlsx_reader.dart).
/// - Koşullu biçimlendirme (hücre kuralı / renk ölçeği / veri çubuğu) çizilir.
/// - Aralık seçimi (basılı tut + kaydır) ve Excel'in durum çubuğu
///   (Ortalama · Sayı · Toplam).
class SpreadsheetEditorScreen extends StatefulWidget {
  final String path;
  final String name;
  final String plainText;

  /// Çözümleme arka plan izolatında yapılsın mı? Cihazda DAİMA evet (büyük
  /// dosyada ana izlek donmasın). `flutter_test` ortamında `compute` izolatı
  /// asılı kaldığı için widget testleri bunu kapatır — üretim yolu değişmez.
  @visibleForTesting
  static bool parseInIsolate = true;

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
  static const double _rowHeaderW = 44;
  static const double _headerH = 24;

  /// Sütunlar yatayda da sanallaştırılır (yalnız görünen pencere çizilir), bu
  /// yüzden sınır yüksek tutulabilir.
  static const int _maxCols = 512;


  XlsxEditor? _editor;
  int _sheetIndex = 0;
  String? _error;
  bool _dirty = false;

  int _selRow = 0;
  int _selCol = 0;

  /// Aralık seçimi (basılı tut + kaydır). Tek hücrede çapa = seçim.
  int _anchorRow = 0;
  int _anchorCol = 0;

  final _cellField = TextEditingController();
  bool _editing = false;

  double _zoom = 1;

  // Bağlı kaydırma: gövde sürüklenir, başlıklar onu takip eder.
  final _hBody = ScrollController();
  final _hTop = ScrollController();
  final _vBody = ScrollController();
  final _vLeft = ScrollController();
  bool _syncing = false;

  /// Yatay sanallaştırma penceresi (görünen ilk/son sütun).
  int _firstCol = 0;
  int _lastCol = 0;
  double _viewportW = 400;

  @override
  void initState() {
    super.initState();
    _hBody.addListener(_onHScroll);
    _vBody.addListener(_onVScroll);
    _load();
  }

  @override
  void dispose() {
    _cellField.dispose();
    _hBody.dispose();
    _hTop.dispose();
    _vBody.dispose();
    _vLeft.dispose();
    super.dispose();
  }

  // ── bağlı kaydırma ────────────────────────────────────────────────────────

  void _onHScroll() {
    if (!_syncing && _hTop.hasClients) {
      _syncing = true;
      final target = _hBody.offset.clamp(
          _hTop.position.minScrollExtent, _hTop.position.maxScrollExtent);
      if ((target - _hTop.offset).abs() > 0.01) _hTop.jumpTo(target);
      _syncing = false;
    }
    _updateColWindow();
  }

  void _onVScroll() {
    if (_syncing || !_vLeft.hasClients) return;
    _syncing = true;
    final target = _vBody.offset.clamp(
        _vLeft.position.minScrollExtent, _vLeft.position.maxScrollExtent);
    if ((target - _vLeft.offset).abs() > 0.01) _vLeft.jumpTo(target);
    _syncing = false;
  }

  /// Görünen sütun penceresini yeniden hesaplar; DEĞİŞTİYSE yeniden çizer.
  /// (Her kaydırma pikselinde değil, sütun sınırı geçilince.)
  void _updateColWindow() {
    final sheet = _sheet;
    if (sheet == null) return;
    final cols = _scrollCols(sheet);
    final offset = _hBody.hasClients ? _hBody.offset : 0.0;
    var acc = 0.0;
    var first = 0;
    while (first < cols.length &&
        acc + sheet.colWidth(cols[first]) * _zoom < offset) {
      acc += sheet.colWidth(cols[first]) * _zoom;
      first++;
    }
    var last = first;
    var width = acc;
    while (last < cols.length && width < offset + _viewportW) {
      width += sheet.colWidth(cols[last]) * _zoom;
      last++;
    }
    last = math.min(cols.length - 1, last + 1);
    if (first != _firstCol || last != _lastCol) {
      setState(() {
        _firstCol = first;
        _lastCol = last;
      });
    }
  }

  // ── yükleme ───────────────────────────────────────────────────────────────

  /// Dosyayı OKUR ve çözümler — ikisi de arka plan izolatında olsun diye tek
  /// fonksiyon (ana izlekte ne disk G/Ç'si ne de ayrıştırma kalır; büyük
  /// dosyada açılışta donma → ANR bu yüzden yaşanmıştı, bkz. HAFIZA).
  static XlsxEditor _readAndParse(String path) =>
      XlsxEditor.parse(File(path).readAsBytesSync());

  Future<void> _load() async {
    try {
      if (SpreadsheetEditorScreen.parseInIsolate) {
        try {
          _editor = await compute(_readAndParse, widget.path);
        } catch (_) {
          // İzolat üretilemezse/sonuç taşınamazsa ana izlekte çöz.
          _editor = _readAndParse(widget.path);
        }
      } else {
        _editor = _readAndParse(widget.path);
      }
      _syncField();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateColWindow());
  }

  XlsxSheet? get _sheet {
    final e = _editor;
    if (e == null || e.sheets.isEmpty) return null;
    if (_sheetIndex >= e.sheets.length) return e.sheets.first;
    return e.sheets[_sheetIndex];
  }

  /// Formül motoru: tüm sayfalar görünür (çapraz sayfa referansı çalışsın).
  FormulaEngine _engineFor(XlsxSheet sheet) => FormulaEngine(
        sheet.rows,
        sheetName: sheet.name,
        sheets: {
          for (final s in _editor?.sheets ?? const <XlsxSheet>[])
            s.name: s.rows,
        },
      );

  // ── satır/sütun listeleri ─────────────────────────────────────────────────

  int _rowCount(XlsxSheet sheet) =>
      math.max(sheet.rows.length, sheet.layout.rowCount);

  int _colCount(XlsxSheet sheet) => sheet.maxCols.clamp(1, _maxCols);

  /// Donmuş bölümden SONRAKİ (kaydırılan) satırlar — gizli satırlar atlanır.
  List<int> _scrollRows(XlsxSheet sheet) {
    final out = <int>[];
    final total = _rowCount(sheet);
    for (var r = sheet.frozenRows; r < total; r++) {
      if (sheet.isRowHidden(r)) continue;
      out.add(r);
    }
    return out;
  }

  List<int> _scrollCols(XlsxSheet sheet) {
    final out = <int>[];
    final total = _colCount(sheet);
    for (var c = sheet.frozenCols; c < total; c++) {
      if (sheet.isColHidden(c)) continue;
      out.add(c);
    }
    return out;
  }

  List<int> _frozenRowList(XlsxSheet sheet) => [
        for (var r = 0; r < sheet.frozenRows && r < _rowCount(sheet); r++)
          if (!sheet.isRowHidden(r)) r,
      ];

  List<int> _frozenColList(XlsxSheet sheet) => [
        for (var c = 0; c < sheet.frozenCols && c < _colCount(sheet); c++)
          if (!sheet.isColHidden(c)) c,
      ];

  // ── seçim / düzenleme ─────────────────────────────────────────────────────

  String _valueAt(int r, int c) => _sheet?.rawAt(r, c) ?? '';

  void _syncField() => _cellField.text = _valueAt(_selRow, _selCol);

  void _select(int r, int c, {bool extend = false}) {
    if (extend) {
      setState(() {
        _selRow = r;
        _selCol = c;
      });
      return;
    }
    if (r == _selRow && c == _selCol && _anchorRow == r && _anchorCol == c) {
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
      _anchorRow = r;
      _anchorCol = c;
    });
    _syncField();
  }

  bool _inSelection(int r, int c) {
    final r1 = math.min(_anchorRow, _selRow);
    final r2 = math.max(_anchorRow, _selRow);
    final c1 = math.min(_anchorCol, _selCol);
    final c2 = math.max(_anchorCol, _selCol);
    return r >= r1 && r <= r2 && c >= c1 && c <= c2;
  }

  bool get _hasRange => _anchorRow != _selRow || _anchorCol != _selCol;

  void _endEdit() {
    if (!_editing) return;
    final changed = _cellField.text != _valueAt(_selRow, _selCol);
    _editing = false;
    if (changed) {
      _applyCell(_cellField.text);
    } else {
      setState(() {});
    }
  }

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

  void _afterStructural() {
    _editing = false;
    final sheet = _sheet;
    if (sheet != null) {
      final maxRow = math.max(0, _rowCount(sheet) - 1);
      final maxCol = math.max(0, sheet.maxCols - 1);
      _selRow = _selRow.clamp(0, maxRow);
      _selCol = _selCol.clamp(0, maxCol);
      _anchorRow = _selRow;
      _anchorCol = _selCol;
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
    _endEdit();
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

  /// Etkin sayfayı CSV olarak dışa aktarır — hücreler **ekranda göründüğü
  /// gibi** yazılır (tarih seri numarası değil `21.07.2026`, para `₺1.500,00`).
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
    if (enc == null) return;
    try {
      final engine = _engineFor(sheet);
      final rows = <List<String>>[];
      for (var r = 0; r < sheet.rows.length; r++) {
        final row = <String>[];
        for (var c = 0; c < sheet.rows[r].length; c++) {
          row.add(sheet.viewAt(r, c, engine.displayValue(r, c)).text);
        }
        rows.add(row);
      }
      final csv = CsvCodec.encode(rows, delimiter: ';');
      final base = widget.name.replaceAll(RegExp(r'\.[^.]*$'), '');
      final f = File('${Directory.systemTemp.path}/$base.csv');
      final bytes = enc == 'cp1254'
          ? TextDecode.encodeCp1254(csv)
          : utf8.encode('\u{FEFF}$csv');
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

  // ── arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    final visibleSheets =
        editor?.sheets.where((s) => !s.layout.hidden).toList() ?? const [];
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
            if (v == 'translate') {
              TranslateFlow.run(context, widget.plainText, title: widget.name);
            }
            if (v == 'goto') _showGoTo();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'goto', child: Text('Hücreye git…')),
            PopupMenuItem(value: 'export', child: Text('Paylaş / Dışa aktar')),
            PopupMenuItem(value: 'csv', child: Text('CSV olarak dışa aktar')),
            PopupMenuItem(value: 'translate', child: Text('Belgeyi çevir')),
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
                    _statusBar(),
                  ],
                ),
      bottomBar: visibleSheets.length < 2 ? null : _sheetTabs(visibleSheets),
      fab: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            fileContext: widget.plainText,
            fileName: widget.name,
          ),
        )),
        tooltip: 'AI ile çalış',
        child: const Icon(Icons.smart_toy_outlined),
      ),
    );
  }

  /// Pinch odağındaki içerik yerinde kalsın.
  void _fixScroll(double f, Offset focal) {
    if (_hBody.hasClients) {
      _hBody.jumpTo(((_hBody.offset + focal.dx) * f - focal.dx)
          .clamp(0.0, _hBody.position.maxScrollExtent));
    }
    if (_vBody.hasClients) {
      _vBody.jumpTo(((_vBody.offset + focal.dy) * f - focal.dy)
          .clamp(0.0, _vBody.position.maxScrollExtent));
    }
    _updateColWindow();
  }

  Widget _cellBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              _hasRange
                  ? '${XlsxRange.colName(math.min(_anchorCol, _selCol))}'
                      '${math.min(_anchorRow, _selRow) + 1}:'
                      '${XlsxRange.colName(math.max(_anchorCol, _selCol))}'
                      '${math.max(_anchorRow, _selRow) + 1}'
                  : '${XlsxRange.colName(_selCol)}${_selRow + 1}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _cellField,
              onSubmitted: _applyCell,
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
          // Veri doğrulama listesi olan hücrede Excel'deki açılır ok.
          if (_validationOptions().isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Listeden seç',
              icon: const Icon(Icons.arrow_drop_down_circle_outlined),
              onSelected: (v) {
                _cellField.text = v;
                _applyCell(v);
              },
              itemBuilder: (_) => [
                for (final o in _validationOptions())
                  PopupMenuItem(value: o, child: Text(o)),
              ],
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

  /// Seçili hücrenin veri doğrulama listesi (yoksa boş).
  List<String> _validationOptions() =>
      _sheet?.validationAt(_selRow, _selCol)?.options ?? const [];

  Widget _formulaPreview() {
    final sheet = _sheet;
    final text = _cellField.text;
    if (sheet == null || !text.startsWith('=') || text.length < 2) {
      return const SizedBox.shrink();
    }
    final result = _engineFor(sheet).preview(text, _selRow, _selCol);
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

  void _applyStyle({bool? bold, bool? italic, TextAlign? align}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    // Aralık seçiliyse tüm aralığa uygulanır (Excel gibi).
    final r1 = math.min(_anchorRow, _selRow);
    final r2 = math.max(_anchorRow, _selRow);
    final c1 = math.min(_anchorCol, _selCol);
    final c2 = math.max(_anchorCol, _selCol);
    for (var r = r1; r <= r2; r++) {
      for (var c = c1; c <= c2; c++) {
        editor.setCellStyle(sheet.name, r, c,
            bold: bold, italic: italic, align: align);
      }
    }
    _dirty = true;
    setState(() {});
  }

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
    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(width: 1, height: 22, color: scheme.outlineVariant),
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
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            btn(Icons.keyboard_arrow_up, 'Üste satır ekle',
                () => _insertRow(below: false)),
            btn(Icons.keyboard_arrow_down, 'Alta satır ekle',
                () => _insertRow(below: true)),
            btn(Icons.remove, 'Satırı sil', _deleteRow),
            divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('Sütun',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            btn(Icons.keyboard_arrow_left, 'Sola sütun ekle',
                () => _insertColumn(right: false)),
            btn(Icons.keyboard_arrow_right, 'Sağa sütun ekle',
                () => _insertColumn(right: true)),
            btn(Icons.remove, 'Sütunu sil', _deleteColumn),
            divider(),
            toggle(Icons.format_bold, 'Kalın', selStyle?.bold ?? false,
                () => _applyStyle(bold: !(selStyle?.bold ?? false))),
            toggle(Icons.format_italic, 'İtalik', selStyle?.italic ?? false,
                () => _applyStyle(italic: !(selStyle?.italic ?? false))),
            toggle(
                Icons.format_align_left,
                'Sola yasla',
                selStyle?.hAlign == XlsxHAlign.left,
                () => _applyStyle(align: TextAlign.left)),
            toggle(
                Icons.format_align_center,
                'Ortala',
                selStyle?.hAlign == XlsxHAlign.center,
                () => _applyStyle(align: TextAlign.center)),
            toggle(
                Icons.format_align_right,
                'Sağa yasla',
                selStyle?.hAlign == XlsxHAlign.right,
                () => _applyStyle(align: TextAlign.right)),
          ],
        ),
      ),
    );
  }

  /// Excel'in durum çubuğu: seçili aralığın ortalaması / sayısı / toplamı.
  Widget _statusBar() {
    final sheet = _sheet;
    if (sheet == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    String text;
    if (!_hasRange) {
      final fmt = sheet.numFmtCode(_selRow, _selCol);
      text = 'Hücre ${XlsxRange.colName(_selCol)}${_selRow + 1}'
          '${fmt == 'General' ? '' : '  ·  $fmt'}';
    } else {
      final engine = _engineFor(sheet);
      final r1 = math.min(_anchorRow, _selRow);
      final r2 = math.max(_anchorRow, _selRow);
      final c1 = math.min(_anchorCol, _selCol);
      final c2 = math.max(_anchorCol, _selCol);
      var sum = 0.0;
      var count = 0;
      var filled = 0;
      for (var r = r1; r <= r2; r++) {
        for (var c = c1; c <= c2; c++) {
          final raw = engine.displayValue(r, c);
          if (raw.isEmpty) continue;
          filled++;
          final v = double.tryParse(raw);
          if (v == null) continue;
          sum += v;
          count++;
        }
      }
      final cells = (r2 - r1 + 1) * (c2 - c1 + 1);
      text = count == 0
          ? 'Seçili: $cells hücre  ·  Dolu: $filled'
          : 'Ortalama: ${generalNumber(sum / count)}  ·  '
              'Sayı: $count  ·  Toplam: ${generalNumber(sum)}';
    }
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _sheetTabs(List<XlsxSheet> sheets) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in sheets)
            Padding(
              padding: const EdgeInsets.all(4),
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
                  setState(() {
                    _sheetIndex = idx < 0 ? 0 : idx;
                    _selRow = 0;
                    _selCol = 0;
                    _anchorRow = 0;
                    _anchorCol = 0;
                    _firstCol = 0;
                    _lastCol = 0;
                  });
                  _syncField();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _updateColWindow());
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showGoTo() async {
    final controller = TextEditingController(
        text: '${XlsxRange.colName(_selCol)}${_selRow + 1}');
    final ref = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hücreye git'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              labelText: 'Hücre başvurusu', hintText: 'ör. C15'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Git'),
          ),
        ],
      ),
    );
    controller.dispose();
    final rc = XlsxRange.cellRef(ref?.trim());
    if (rc == null) return;
    _select(rc.$1, rc.$2);
  }

  // ── ızgara ────────────────────────────────────────────────────────────────

  Widget _grid(ScrollPhysics? physics) {
    final sheet = _sheet;
    if (sheet == null) return const Center(child: Text('Sayfa yok.'));

    final engine = _engineFor(sheet);
    final ctx = _RenderContext(
      sheet: sheet,
      engine: engine,
      zoom: _zoom,
      condCache: {},
    );

    final scrollRows = _scrollRows(sheet);
    final scrollCols = _scrollCols(sheet);
    final frozenRows = _frozenRowList(sheet);
    final frozenCols = _frozenColList(sheet);

    final leftW = _rowHeaderW * _zoom +
        frozenCols.fold<double>(0, (a, c) => a + sheet.colWidth(c) * _zoom);
    final topH = _headerH * _zoom +
        frozenRows.fold<double>(0, (a, r) => a + sheet.rowHeight(r) * _zoom);
    final totalW =
        scrollCols.fold<double>(0, (a, c) => a + sheet.colWidth(c) * _zoom);

    // Görünen sütun penceresi (yatay sanallaştırma).
    final maxIndex = math.max(0, scrollCols.length - 1);
    final first = _firstCol.clamp(0, maxIndex).toInt();
    final last = _lastCol.clamp(first, maxIndex).toInt();
    final window = scrollCols.isEmpty
        ? const <int>[]
        : scrollCols.sublist(first, last + 1);
    final padLeft = scrollCols
        .take(first)
        .fold<double>(0, (a, c) => a + sheet.colWidth(c) * _zoom);
    final padRight = scrollCols
        .skip(last + 1)
        .fold<double>(0, (a, c) => a + sheet.colWidth(c) * _zoom);

    return LayoutBuilder(builder: (context, constraints) {
      _viewportW = constraints.maxWidth;
      return Column(
        children: [
          // ── üst şerit: köşe + sütun başlıkları + donmuş satırlar ──
          SizedBox(
            height: topH,
            child: Row(
              children: [
                SizedBox(
                  width: leftW,
                  child: Column(
                    children: [
                      SizedBox(
                        height: _headerH * _zoom,
                        child: Row(
                          children: [
                            _cornerCell(),
                            for (final c in frozenCols) _colHeader(sheet, c),
                          ],
                        ),
                      ),
                      for (final r in frozenRows)
                        SizedBox(
                          height: sheet.rowHeight(r) * _zoom,
                          child: Row(
                            children: [
                              _rowHeader(sheet, r),
                              ..._rowCells(ctx, r, frozenCols),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _hTop,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: totalW,
                      child: Column(
                        children: [
                          SizedBox(
                            height: _headerH * _zoom,
                            child: Row(children: [
                              SizedBox(width: padLeft),
                              for (final c in window) _colHeader(sheet, c),
                              SizedBox(width: padRight),
                            ]),
                          ),
                          for (final r in frozenRows)
                            SizedBox(
                              height: sheet.rowHeight(r) * _zoom,
                              child: Row(children: [
                                SizedBox(width: padLeft),
                                ..._rowCells(ctx, r, window),
                                SizedBox(width: padRight),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── gövde: satır başlıkları + donmuş sütunlar + hücreler ──
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: leftW,
                  child: ListView.builder(
                    controller: _vLeft,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: scrollRows.length,
                    itemExtentBuilder: (i, _) =>
                        sheet.rowHeight(scrollRows[i]) * _zoom,
                    itemBuilder: (_, i) {
                      final r = scrollRows[i];
                      return Row(children: [
                        _rowHeader(sheet, r),
                        ..._rowCells(ctx, r, frozenCols),
                      ]);
                    },
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _hBody,
                    physics: physics,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalW,
                      child: _dragSelectArea(
                        ListView.builder(
                          controller: _vBody,
                          physics: physics,
                          padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).padding.bottom),
                          itemCount: scrollRows.length,
                          itemExtentBuilder: (i, _) =>
                              sheet.rowHeight(scrollRows[i]) * _zoom,
                          itemBuilder: (_, i) {
                            final r = scrollRows[i];
                            return Row(children: [
                              SizedBox(width: padLeft),
                              ..._rowCells(ctx, r, window),
                              SizedBox(width: padRight),
                            ]);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  /// Basılı tut + kaydır = aralık seçimi (Excel'in seçim tutamacının mobil
  /// karşılığı). Hücrelerin kendi uzun basışı YOKTUR — olsaydı jest arenasını
  /// çocuk kazanır, sürükleme hiç başlamazdı.
  Widget _dragSelectArea(Widget child) => Builder(
        builder: (areaContext) => GestureDetector(
          onLongPressStart: (d) {
            final pos = _cellAtGlobal(areaContext, d.globalPosition);
            if (pos == null) return;
            _endEdit();
            setState(() {
              _anchorRow = pos.$1;
              _anchorCol = pos.$2;
              _selRow = pos.$1;
              _selCol = pos.$2;
            });
            _syncField();
          },
          onLongPressMoveUpdate: (d) {
            final pos = _cellAtGlobal(areaContext, d.globalPosition);
            if (pos == null) return;
            if (pos.$1 == _selRow && pos.$2 == _selCol) return;
            setState(() {
              _selRow = pos.$1;
              _selCol = pos.$2;
            });
          },
          child: child,
        ),
      );

  /// Ekran koordinatındaki hücreyi bulur (MetaData işaretleriyle, ölçüm yok).
  (int, int)? _cellAtGlobal(BuildContext areaContext, Offset globalPos) {
    final box = areaContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    var local = box.globalToLocal(globalPos);
    local = Offset(
      local.dx.clamp(0.5, box.size.width - 0.5),
      local.dy.clamp(0.5, box.size.height - 0.5),
    );
    final result = BoxHitTestResult();
    box.hitTest(result, position: local);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData) {
        final meta = target.metaData;
        if (meta is SheetCellPos) return (meta.row, meta.col);
      }
    }
    return null;
  }

  Widget _cornerCell() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        final sheet = _sheet;
        if (sheet == null) return;
        setState(() {
          _anchorRow = 0;
          _anchorCol = 0;
          _selRow = math.max(0, _rowCount(sheet) - 1);
          _selCol = math.max(0, sheet.maxCols - 1);
        });
      },
      child: Container(
        width: _rowHeaderW * _zoom,
        height: _headerH * _zoom,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
    );
  }

  Widget _colHeader(XlsxSheet sheet, int c) {
    final scheme = Theme.of(context).colorScheme;
    final active = _inSelection(_selRow, c) ||
        (c >= math.min(_anchorCol, _selCol) &&
            c <= math.max(_anchorCol, _selCol));
    return GestureDetector(
      onTap: () {
        _endEdit();
        setState(() {
          _anchorRow = 0;
          _anchorCol = c;
          _selRow = math.max(0, _rowCount(sheet) - 1);
          _selCol = c;
        });
      },
      child: Container(
        width: sheet.colWidth(c) * _zoom,
        height: _headerH * _zoom,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? OfficeColors.excel.withValues(alpha: 0.22)
              : scheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(XlsxRange.colName(c),
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 11 * _zoom)),
        ),
      ),
    );
  }

  Widget _rowHeader(XlsxSheet sheet, int r) {
    final scheme = Theme.of(context).colorScheme;
    final active = r >= math.min(_anchorRow, _selRow) &&
        r <= math.max(_anchorRow, _selRow);
    return GestureDetector(
      onTap: () {
        _endEdit();
        setState(() {
          _anchorRow = r;
          _anchorCol = 0;
          _selRow = r;
          _selCol = math.max(0, sheet.maxCols - 1);
        });
      },
      child: Container(
        width: _rowHeaderW * _zoom,
        height: sheet.rowHeight(r) * _zoom,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? OfficeColors.excel.withValues(alpha: 0.22)
              : scheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('${r + 1}',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 11 * _zoom)),
        ),
      ),
    );
  }

  /// Bir satırın hücreleri — birleştirilmiş hücrelerde ÇAPA tüm genişliği
  /// kaplar, kapsanan sütunlar atlanır (yoksa satır taşar). Çapa görünen
  /// pencerenin solunda kalmışsa kapsanan hücreler boş çizilir.
  List<Widget> _rowCells(_RenderContext ctx, int r, List<int> cols) {
    final sheet = ctx.sheet;
    final out = <Widget>[];
    final drawn = <int>{};
    for (final c in cols) {
      if (drawn.contains(c)) continue;
      final merge = sheet.mergeAt(r, c);
      if (merge != null && merge.colStart < c && cols.contains(merge.colStart)) {
        continue; // çapa bu satırda zaten çizildi ve genişliği kapsıyor
      }
      if (merge != null && merge.colStart == c) {
        for (var k = merge.colStart; k <= merge.colEnd; k++) {
          drawn.add(k);
        }
      }
      out.add(_cell(ctx, r, c, cols));
    }
    return out;
  }

  /// [cols] bu bölgede çizilen sütunlar — birleşik hücre genişliği YALNIZ bu
  /// bölgedeki sütunları toplar. (Dondurulmuş bölmede A1:C1 birleşmesi tüm
  /// genişliğiyle çizilirse sol bölme taşar; Excel de bölme sınırında keser.)
  Widget _cell(_RenderContext ctx, int r, int c, List<int> cols) {
    final sheet = ctx.sheet;
    final merge = sheet.mergeAt(r, c);
    var width = sheet.colWidth(c) * _zoom;
    // Yükseklik DAİMA kendi satırının yüksekliğidir: satırlar tembel listede
    // sabit uzantıyla çizilir, daha yüksek bir çocuk komşu satıra taşardı.
    // Dikey birleşmede içerik üst satırda görünür, altlar boş kalır.
    final height = sheet.rowHeight(r) * _zoom;
    var hideContent = false;

    if (merge != null) {
      if (merge.colStart == c) {
        width = 0;
        for (var k = merge.colStart; k <= merge.colEnd; k++) {
          if (!cols.contains(k)) continue;
          width += sheet.colWidth(k) * _zoom;
        }
        if (width <= 0) width = sheet.colWidth(c) * _zoom;
      }
      if (!merge.isAnchor(r, c)) hideContent = true;
    }

    final selected = _inSelection(r, c);
    final isCursor = r == _selRow && c == _selCol;

    return SheetCell(
      row: r,
      col: c,
      width: width,
      height: height,
      zoom: _zoom,
      style: sheet.styleAt(r, c),
      view: hideContent
          ? const XlsxCellView('')
          : sheet.viewAt(r, c, ctx.engine.displayValue(r, c)),
      cond: hideContent ? null : ctx.condFor(r, c),
      selected: selected,
      cursor: isCursor,
      editing: isCursor && _editing,
      showGridLines: sheet.showGridLines,
      controller: _cellField,
      onTap: () => _select(r, c),
      onSubmitted: () => _commitAndMoveDown(_rowCount(sheet)),
      onEditingComplete: _endEdit,
    );
  }
}

/// Bir çizim geçişi boyunca paylaşılan bağlam (koşullu biçim min/max
/// hesapları sayfa başına BİR kez yapılır).
class _RenderContext {
  final XlsxSheet sheet;
  final FormulaEngine engine;
  final double zoom;
  final Map<XlsxCondRule, _CondStats> condCache;

  _RenderContext({
    required this.sheet,
    required this.engine,
    required this.zoom,
    required this.condCache,
  });

  /// Hücrede uygulanacak koşullu biçim sonucu (yoksa null).
  SheetCondPaint? condFor(int r, int c) {
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
    if (colors.isEmpty) return const Color(0x00000000);
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
