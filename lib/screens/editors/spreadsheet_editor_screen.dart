import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, RenderMetaData;
import 'package:share_plus/share_plus.dart';

import '../../core/excel_format.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/sheet_metrics.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../services/csv_codec.dart';
import '../../services/text_decode.dart';
import '../../services/formula_engine.dart';
import '../../services/xlsx_editor.dart';
import '../../widgets/doc_action_bar.dart';
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

  /// Excel'in kendi sınırı. Sütunlar yatayda sanallaştırıldığı ve ölçüler
  /// önbelleklendiği için dosyanın kullanılan alanını KISALTMAYA gerek yok
  /// (eski 512 sınırı 512. sütundan sonraki verileri gizliyordu).
  static const int _maxCols = 16384;

  /// Boş sayfa da Excel gibi ızgara görünsün diye en az bu kadar satır/sütun
  /// çizilir (sanallaştırma sayesinde maliyeti yok).
  static const int _minCols = 26;
  static const int _minRows = 60;


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

  /// Kaydırılan bölgenin (sabit başlıklar/donmuş bölme HARİÇ) ölçüsü.
  double _viewportW = 400;
  double _viewportH = 400;

  /// Dosyadaki dondurulmuş bölme kullanıcı tarafından açık/kapalı.
  bool _freeze = true;

  /// Ekrana SIĞAN dondurulmuş satır/sütun sayısı — bölme pencereden genişse
  /// kalanı kaydırılan bölgeye bırakılır (yoksa sağ taraf hiç görünmezdi).
  int _frozenColsFit = 0;
  int _frozenRowsFit = 0;
  bool _paneTrimmed = false;
  bool _paneNoticeShown = false;

  /// Ölçü önbelleğini geçersiz kılan imza + önbellek.
  String _metricsKey = '';
  SheetAxisMetrics _colMetrics = SheetAxisMetrics.empty;
  SheetAxisMetrics _rowMetrics = SheetAxisMetrics.empty;

  /// Satır/sütun ekle-sil ve hücre yazma ölçüleri değiştirebilir.
  int _gridVersion = 0;

  /// Bul çubuğu açık mı, eşleşmeler ve etkin eşleşme.
  bool _finding = false;
  final _findField = TextEditingController();
  List<(int, int)> _hits = const [];
  int _hitIndex = -1;

  /// Eşleşme üst sınırı — "a" gibi bir aramada 100 bin hücreyi listelemek
  /// ekranı dondurur; Excel de sonuç listesini sınırlar.
  static const int _maxHits = 500;

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
    _findField.dispose();
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
    if (_colMetrics.isEmpty) return;
    final offset = _hBody.hasClients ? _hBody.offset : 0.0;
    final first = _colMetrics.firstAt(offset);
    final last = _colMetrics.lastAt(offset + _viewportW);
    if (first != _firstCol || last != _lastCol) {
      setState(() {
        _firstCol = first;
        _lastCol = last;
      });
    }
  }

  /// Seçili hücreyi görünür yapar (Hücreye git, Enter ile aşağı inme,
  /// pencere dışında kalan seçim). Excel de seçimi kendine doğru kaydırır.
  void _ensureVisible(int r, int c) {
    if (_hBody.hasClients && !_colMetrics.isEmpty && _viewportW > 0) {
      final i = _colMetrics.positionOf(c);
      if (i >= 0) {
        final start = _colMetrics.startAt(i);
        final size = _colMetrics.sizeAt(i);
        final off = _hBody.offset;
        double? target;
        if (start < off) {
          target = start;
        } else if (start + size > off + _viewportW) {
          target = start + size - _viewportW;
        }
        if (target != null) {
          _hBody.jumpTo(target.clamp(0.0, _hBody.position.maxScrollExtent));
        }
      }
    }
    if (_vBody.hasClients && !_rowMetrics.isEmpty && _viewportH > 0) {
      final i = _rowMetrics.positionOf(r);
      if (i >= 0) {
        final start = _rowMetrics.startAt(i);
        final size = _rowMetrics.sizeAt(i);
        final off = _vBody.offset;
        double? target;
        if (start < off) {
          target = start;
        } else if (start + size > off + _viewportH) {
          target = start + size - _viewportH;
        }
        if (target != null) {
          _vBody.jumpTo(target.clamp(0.0, _vBody.position.maxScrollExtent));
        }
      }
    }
    _updateColWindow();
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

  int _rowCount(XlsxSheet sheet) => math.max(
      math.max(sheet.rows.length, sheet.layout.rowCount), _minRows);

  int _colCount(XlsxSheet sheet) =>
      math.max(sheet.maxCols, _minCols).clamp(1, _maxCols);

  /// Dosyadaki dondurulmuş satır/sütun sayısı (kullanıcı bölmeleri çözdüyse 0).
  int _frozenColsWanted(XlsxSheet sheet) =>
      _freeze ? math.min(sheet.frozenCols, _colCount(sheet)) : 0;

  int _frozenRowsWanted(XlsxSheet sheet) =>
      _freeze ? math.min(sheet.frozenRows, _rowCount(sheet)) : 0;

  List<int> _frozenRowList(XlsxSheet sheet) => [
        for (var r = 0; r < _frozenRowsFit; r++)
          if (!sheet.isRowHidden(r)) r,
      ];

  List<int> _frozenColList(XlsxSheet sheet) => [
        for (var c = 0; c < _frozenColsFit; c++)
          if (!sheet.isColHidden(c)) c,
      ];

  /// Kaydırılan bölgenin satır/sütun ölçüleri — imza değişmedikçe yeniden
  /// hesaplanmaz (zoom, sayfa, bölme ya da yapı değişince yenilenir).
  void _refreshMetrics(XlsxSheet sheet) {
    final key = '${sheet.name}|$_zoom|$_frozenRowsFit|$_frozenColsFit|'
        '${_rowCount(sheet)}|${_colCount(sheet)}|$_gridVersion';
    if (key == _metricsKey) return;
    _metricsKey = key;
    _colMetrics = SheetAxisMetrics.build(
      from: _frozenColsFit,
      to: _colCount(sheet),
      sizeOf: (c) => sheet.colWidth(c) * _zoom,
      hidden: sheet.isColHidden,
    );
    _rowMetrics = SheetAxisMetrics.build(
      from: _frozenRowsFit,
      to: _rowCount(sheet),
      sizeOf: (r) => sheet.rowHeight(r) * _zoom,
      hidden: sheet.isRowHidden,
    );
  }

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
    _jumpTo(r, c);
  }

  /// Seçimi taşır — [_select]'in aksine aynı hücreye ikinci kez gelince
  /// düzenlemeye GEÇMEZ (Hücreye git / Bul bunu istemez).
  void _jumpTo(int r, int c) {
    _endEdit();
    setState(() {
      _selRow = r;
      _selCol = c;
      _anchorRow = r;
      _anchorCol = c;
    });
    _syncField();
    _ensureVisible(r, c);
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
    _gridVersion++; // yazma kullanılan alanı büyütebilir → ölçüler yenilenir
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
    _gridVersion++;
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('common.saved_hint'))));
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
    // Hata metni await'ten ÖNCE çevrilir (asenkron boşluktan sonra `context`
    // kullanılamaz).
    final csvFailed = context.t('excel.csv_failed');
    final enc = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(context.t('excel.csv_encoding')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'utf8'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('excel.csv_utf8')),
              subtitle: const Text('Modern Excel / Google E-Tablolar'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'cp1254'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Windows-1254'),
              subtitle: Text(context.t('excel.csv_legacy')),
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
      _snack(csvFailed.replaceAll('{error}', '$e'));
    }
  }

  /// Etkin sayfada dosyadan gelen dondurulmuş bölme var mı?
  bool get _sheetHasFreeze {
    final sheet = _sheet;
    return sheet != null && (sheet.frozenRows > 0 || sheet.frozenCols > 0);
  }

  /// Sabit satır/sütunları açıp kapatır. Telefonda sabit bölme ekranın
  /// önemli bir kısmını yiyebiliyor; kullanıcı "sağ/sol ayrı oynamasın"
  /// diyebilsin.
  void _toggleFreeze() {
    setState(() {
      _freeze = !_freeze;
      _firstCol = 0;
      _lastCol = 0;
    });
    if (_hBody.hasClients) _hBody.jumpTo(0);
    if (_vBody.hasClients) _vBody.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateColWindow());
  }

  /// Sayfa yönünü (soldan sağa / sağdan sola) değiştirir — Excel'in
  /// *Sayfa Düzeni → Sayfayı Sağdan Sola* düğmesinin karşılığı.
  ///
  /// Yön **dosyanın** özelliği: kaydetmede `<sheetView rightToLeft>` olarak
  /// geri yazılır (bkz. `XlsxSavePatch`), arayüz dilini değiştirmez.
  void _toggleSheetDirection() {
    final sheet = _sheet;
    if (sheet == null) return;
    final next = !sheet.rightToLeft;
    setState(() {
      sheet.setRightToLeft(next);
      _dirty = true;
      // Sanallaştırma penceresi ve kaydırma konumu yön değişince anlamsızlaşır.
      _firstCol = 0;
      _lastCol = 0;
    });
    if (_hBody.hasClients) _hBody.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateColWindow());
    _snack(context.t(next ? 'excel.sheet_rtl_on' : 'excel.sheet_rtl_off'));
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
      // Kaydet/Paylaş/CSV/Çevir ALT çubukta; burada yalnız karşılığı olmayanlar
      // kalır (2026-07-28 kullanıcı isteği: tekrar eden düğmeler kalksın).
      actions: [
        IconButton(
          tooltip: context.t('common.search'),
          icon: const Icon(Icons.search),
          onPressed: editor == null ? null : _toggleFind,
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'goto') _showGoTo();
            if (v == 'freeze') _toggleFreeze();
            if (v == 'colw') _showSizeDialog(col: _selCol);
            if (v == 'rowh') _showSizeDialog(row: _selRow);
            if (v == 'rtl') _toggleSheetDirection();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'goto', child: Text(context.t('excel.goto_cell_menu'))),
            PopupMenuItem(
                value: 'colw', child: Text(context.t('excel.column_width'))),
            PopupMenuItem(
                value: 'rowh', child: Text(context.t('excel.row_height'))),
            CheckedPopupMenuItem(
              value: 'rtl',
              checked: _sheet?.rightToLeft ?? false,
              child: Text(context.t('excel.sheet_rtl')),
            ),
            if (_sheetHasFreeze)
              PopupMenuItem(
                value: 'freeze',
                child: Text(context.t(
                    _freeze ? 'excel.unfreeze_panes' : 'excel.freeze_panes')),
              ),
          ],
        ),
      ],
      body: _error != null
          ? Center(
              child: Text(context.t('common.open_failed', {'error': _error})))
          : editor == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (_finding) _findBar(),
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
      // Sayfa sekmeleri + etiketli eylem çubuğu (2026-07-28 kullanıcı isteği —
      // PDF'teki gibi). Sekmeler üstte kalır: hangi sayfadasınız bilgisi
      // eylemlerden önce gelir.
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (visibleSheets.length >= 2) _sheetTabs(visibleSheets),
          DocActionBar([
            DocAction(Icons.save_outlined, context.t('common.save'),
                editor == null ? null : _save),
            DocAction(Icons.share_outlined, context.t('common.share'),
                editor == null ? null : _export),
            DocAction(Icons.table_view_outlined, 'CSV',
                editor == null ? null : _exportCsv),
            DocAction(
              Icons.translate,
              context.t('common.translate'),
              () => TranslateFlow.run(context, widget.plainText,
                  title: widget.name),
            ),
          ]),
        ],
      ),
      fab: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            fileContext: widget.plainText,
            fileName: widget.name,
          ),
        )),
        tooltip: context.t('common.ai'),
        child: const Icon(Icons.smart_toy_outlined),
      ),
    );
  }

  /// Pinch odağındaki içerik yerinde kalsın.
  void _fixScroll(double f, Offset focal) {
    if (_hBody.hasClients) {
      // Kaydırma konumu her iki yönde de BAŞLANGIÇTAN ölçülür; `focal.dx` ise
      // daima ekranın SOLUNDAN. Sağdan sola sayfada odağın başlangıca uzaklığı
      // bu yüzden aynalanmalı, yoksa pinch odağın simetriği etrafında zoomlar.
      final dx = (_sheet?.rightToLeft ?? false) && _viewportW > 0
          ? _viewportW - focal.dx
          : focal.dx;
      _hBody.jumpTo(((_hBody.offset + dx) * f - dx)
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
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: context.t('excel.cell_content'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),
          // Veri doğrulama listesi olan hücrede Excel'deki açılır ok.
          if (_validationOptions().isNotEmpty)
            PopupMenuButton<String>(
              tooltip: context.t('excel.pick_from_list'),
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
            tooltip: context.t('common.apply'),
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
              child: Text(context.t('excel.row'),
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            btn(Icons.keyboard_arrow_up, context.t('excel.insert_row_above'),
                () => _insertRow(below: false)),
            btn(Icons.keyboard_arrow_down, context.t('excel.insert_row_below'),
                () => _insertRow(below: true)),
            btn(Icons.remove, context.t('excel.delete_row'), _deleteRow),
            divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(context.t('excel.column'),
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            btn(Icons.keyboard_arrow_left, context.t('excel.insert_col_left'),
                () => _insertColumn(right: false)),
            btn(Icons.keyboard_arrow_right, context.t('excel.insert_col_right'),
                () => _insertColumn(right: true)),
            btn(Icons.remove, context.t('excel.delete_col'), _deleteColumn),
            divider(),
            toggle(Icons.format_bold, context.t('common.bold'),
                selStyle?.bold ?? false,
                () => _applyStyle(bold: !(selStyle?.bold ?? false))),
            toggle(Icons.format_italic, context.t('common.italic'),
                selStyle?.italic ?? false,
                () => _applyStyle(italic: !(selStyle?.italic ?? false))),
            toggle(
                Icons.format_align_left,
                context.t('common.align_left'),
                selStyle?.hAlign == XlsxHAlign.left,
                () => _applyStyle(align: TextAlign.left)),
            toggle(
                Icons.format_align_center,
                context.t('common.align_center'),
                selStyle?.hAlign == XlsxHAlign.center,
                () => _applyStyle(align: TextAlign.center)),
            toggle(
                Icons.format_align_right,
                context.t('common.align_right'),
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
      text = context.t('excel.cell_label',
              {'ref': '${XlsxRange.colName(_selCol)}${_selRow + 1}'}) +
          (fmt == 'General' ? '' : '  ·  $fmt');
    } else {
      final engine = _engineFor(sheet);
      final r1 = math.min(_anchorRow, _selRow);
      final r2 = math.max(_anchorRow, _selRow);
      final c1 = math.min(_anchorCol, _selCol);
      final c2 = math.max(_anchorCol, _selCol);
      final cellCount = (r2 - r1 + 1) * (c2 - c1 + 1);
      // Çok büyük seçimde (tümünü seç) hücre hücre hesap ekranı dondurur;
      // Excel de yalnız sayıyı gösterir.
      if (cellCount > 200000) {
        return _statusText(
            context.t('excel.selection_cells', {'n': cellCount}), scheme);
      }
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
      text = count == 0
          ? context.t(
              'excel.selection_filled', {'n': cellCount, 'filled': filled})
          : context.t('excel.selection_stats', {
              'avg': generalNumber(sum / count),
              'count': count,
              'sum': generalNumber(sum),
            });
    }
    return _statusText(text, scheme);
  }

  Widget _statusText(String text, ColorScheme scheme) => Container(
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
                    _hits = const []; // eşleşmeler sayfaya özgü
                    _hitIndex = -1;
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

  // ── bul ───────────────────────────────────────────────────────────────────

  /// Etkin sayfada metin arar (büyük/küçük harf duyarsız).
  ///
  /// Excel'in "Bul"u varsayılan olarak FORMÜLLERDE arar; biz de ham metni
  /// tararız. Ek olarak formül hücrelerinde SONUCA da bakarız: kullanıcı
  /// ekranda gördüğü değeri arıyor olabilir.
  void _runFind(String query) {
    final sheet = _sheet;
    final q = query.trim().toLowerCase();
    if (sheet == null || q.isEmpty) {
      setState(() {
        _hits = const [];
        _hitIndex = -1;
      });
      return;
    }
    final engine = _engineFor(sheet);
    final hits = <(int, int)>[];
    for (var r = 0; r < sheet.rows.length && hits.length < _maxHits; r++) {
      final row = sheet.rows[r];
      for (var c = 0; c < row.length && hits.length < _maxHits; c++) {
        final raw = row[c];
        if (raw.isEmpty) continue;
        if (raw.toLowerCase().contains(q) ||
            (raw.startsWith('=') &&
                engine.displayValue(r, c).toLowerCase().contains(q))) {
          hits.add((r, c));
        }
      }
    }
    setState(() {
      _hits = hits;
      _hitIndex = hits.isEmpty ? -1 : 0;
    });
    if (hits.isNotEmpty) _jumpTo(hits.first.$1, hits.first.$2);
  }

  void _stepHit(int delta) {
    if (_hits.isEmpty) return;
    var i = (_hitIndex + delta) % _hits.length;
    if (i < 0) i += _hits.length;
    setState(() => _hitIndex = i);
    _jumpTo(_hits[i].$1, _hits[i].$2);
  }

  void _toggleFind() {
    setState(() {
      _finding = !_finding;
      if (!_finding) {
        _findField.clear();
        _hits = const [];
        _hitIndex = -1;
      }
    });
  }

  Widget _findBar() {
    final scheme = Theme.of(context).colorScheme;
    final typed = _findField.text.trim().isNotEmpty;
    final counter = !typed
        ? ''
        : _hits.isEmpty
            ? 'yok'
            : '${_hitIndex + 1}/${_hits.length}'
                '${_hits.length >= _maxHits ? '+' : ''}';
    return Container(
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _findField,
              autofocus: true,
              onChanged: _runFind,
              onSubmitted: (_) => _stepHit(1),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: context.t('excel.find_in_sheet'),
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(counter,
              style:
                  TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          IconButton(
            tooltip: context.t('common.previous'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: _hits.isEmpty ? null : () => _stepHit(-1),
          ),
          IconButton(
            tooltip: context.t('common.next'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: _hits.isEmpty ? null : () => _stepHit(1),
          ),
          IconButton(
            tooltip: context.t('common.close'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: _toggleFind,
          ),
        ],
      ),
    );
  }

  // ── sütun genişliği / satır yüksekliği ────────────────────────────────────

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
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
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
    setState(() {});
  }

  // ── ızgara ────────────────────────────────────────────────────────────────

  /// Sabit (donmuş) bölgeye ayrılabilecek en büyük ölçü. Kaydırılan bölgeye
  /// DAİMA yer bırakır — yoksa `Expanded` sıfır ölçü alır ve dosyanın sağ/alt
  /// tarafı hiç görünmez (kullanıcının bildirdiği hata).
  static double _paneBudget(double viewport, double headerSize) {
    final body = math.max(72.0, math.min(viewport * 0.45, 280.0));
    return math.max(0.0, viewport - headerSize - body);
  }

  Widget _grid(ScrollPhysics? physics) {
    final sheet = _sheet;
    if (sheet == null) return Center(child: Text(context.t('excel.no_sheet')));

    final engine = _engineFor(sheet);
    final ctx = _RenderContext(
      sheet: sheet,
      engine: engine,
      zoom: _zoom,
      condCache: {},
    );

    return LayoutBuilder(builder: (context, constraints) {
      final headerW = _rowHeaderW * _zoom;
      final headerH = _headerH * _zoom;

      // Dondurulmuş bölme ekrana sığdırılır; sığmayan satır/sütunlar
      // kaydırılan bölgeye bırakılır (içerik erişilebilir kalır).
      final wantCols = _frozenColsWanted(sheet);
      final wantRows = _frozenRowsWanted(sheet);
      _frozenColsFit = fitFrozen(
        count: wantCols,
        sizeOf: (c) => sheet.colWidth(c) * _zoom,
        budget: _paneBudget(constraints.maxWidth, headerW),
      );
      _frozenRowsFit = fitFrozen(
        count: wantRows,
        sizeOf: (r) => sheet.rowHeight(r) * _zoom,
        budget: _paneBudget(constraints.maxHeight, headerH),
      );
      _paneTrimmed = _frozenColsFit < wantCols || _frozenRowsFit < wantRows;
      if (_paneTrimmed && !_paneNoticeShown) {
        _paneNoticeShown = true;
        final message = context.t('excel.panes_trimmed');
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _snack(message));
      }

      _refreshMetrics(sheet);
      final rows = _rowMetrics;
      final cols = _colMetrics;
      final frozenRows = _frozenRowList(sheet);
      final frozenCols = _frozenColList(sheet);

      final leftW = math.min(
        headerW + frozenCols.fold<double>(0, (a, c) => a + sheet.colWidth(c) * _zoom),
        math.max(headerW, constraints.maxWidth - 48),
      );
      final topH = headerH +
          frozenRows.fold<double>(0, (a, r) => a + sheet.rowHeight(r) * _zoom);
      _viewportW = math.max(0.0, constraints.maxWidth - leftW);
      _viewportH = math.max(0.0, constraints.maxHeight - topH);

      // Görünen sütun penceresi (yatay sanallaştırma).
      final maxIndex = math.max(0, cols.length - 1);
      final first = _firstCol.clamp(0, maxIndex).toInt();
      final last = _lastCol.clamp(first, maxIndex).toInt();
      final window = cols.isEmpty ? const <int>[] : cols.indices.sublist(first, last + 1);
      final padLeft = cols.isEmpty ? 0.0 : cols.startAt(first);
      final padRight = cols.isEmpty
          ? 0.0
          : cols.total - (cols.startAt(last) + cols.sizeAt(last));
      final bottomInset = MediaQuery.of(context).padding.bottom;

      // **Sayfa yönü belgeden gelir, arayüz dilinden DEĞİL** (Excel de böyle:
      // Arapça Excel'de soldan sağa bir tablo yine soldan sağa açılır). Bu
      // yüzden yön her iki durumda da AÇIKÇA yazılır — Arapça arayüzde
      // sarmalayıcı olmasa soldan sağa sayfalar da ters çizilirdi.
      //
      // `Row`/`SingleChildScrollView` yönü kendiliğinden uygular: sütunlar
      // sağdan sola dizilir, yatay kaydırma sağ kenardan başlar. Kaydırma
      // konumu (`_hBody.offset`) her iki yönde de BAŞLANGIÇTAN ölçüldüğü için
      // sanallaştırma (`cols.startAt`) ve `_ensureVisible` matematiği aynen
      // geçerli kalır.
      return Directionality(
        textDirection:
            sheet.rightToLeft ? TextDirection.rtl : TextDirection.ltr,
        child: Scrollbar(
        controller: _hBody,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: Column(
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
                          height: headerH,
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
                        width: cols.total,
                        child: Column(
                          children: [
                            SizedBox(
                              height: headerH,
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
              child: Scrollbar(
                controller: _vBody,
                notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                child: Row(
                  children: [
                    SizedBox(
                      width: leftW,
                      child: ListView.builder(
                        controller: _vLeft,
                        physics: const NeverScrollableScrollPhysics(),
                        // Alt boşluk İKİ listede de aynı olmalı; yoksa en altta
                        // satır başlıkları hücrelerden kayıyor.
                        padding: EdgeInsets.only(bottom: bottomInset),
                        itemCount: rows.length,
                        itemExtentBuilder: (i, _) => rows.sizeAt(i),
                        itemBuilder: (_, i) {
                          final r = rows.indices[i];
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
                          width: cols.total,
                          child: _dragSelectArea(
                            ListView.builder(
                              controller: _vBody,
                              physics: physics,
                              padding: EdgeInsets.only(bottom: bottomInset),
                              itemCount: rows.length,
                              itemExtentBuilder: (i, _) => rows.sizeAt(i),
                              itemBuilder: (_, i) {
                                final r = rows.indices[i];
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
            ),
          ],
        ),
      ),
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
        // Seçim KULLANILAN alanla sınırlı: ızgara boş satır/sütunlarla
        // doldurulmuş olsa da "tümünü seç" veri dışına taşmaz.
        setState(() {
          _anchorRow = 0;
          _anchorCol = 0;
          _selRow = math.max(0, sheet.maxRows - 1);
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
          _selRow = math.max(0, sheet.maxRows - 1);
          _selCol = c;
        });
      },
      onLongPress: () => _showSizeDialog(col: c),
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
      onLongPress: () => _showSizeDialog(row: r),
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
