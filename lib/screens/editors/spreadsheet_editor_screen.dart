import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/gestures.dart'
    show Drag, DoubleTapGestureRecognizer, ImmediateMultiDragGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, RenderMetaData;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/excel_format.dart';
import '../../core/doc_fonts.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/sheet_metrics.dart';
import '../../core/sheet_overflow.dart';
import '../../core/sheet_text_measure.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../services/fm/activity_log.dart';
import '../../services/csv_codec.dart';
import '../../services/text_decode.dart';
import '../../services/formula_engine.dart';
import '../../services/sheet_edit.dart';
import '../../services/xlsx_editor.dart';
import '../../widgets/doc_action_bar.dart';
import '../../widgets/doc_more_sheet.dart';
import '../../widgets/office_ribbon.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/pinch_zoom_area.dart';
import '../../widgets/sheet_cell.dart';
import '../../widgets/translate_flow.dart';
import '../chat_screen.dart';
import '../../core/snack.dart';

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

  /// Doldurma tutamağının anahtarı — `SheetCell` kendi içinde de hareket
  /// tanıyıcıları kuruyor, test tutamağı tipe göre ayırt edemiyor.
  @visibleForTesting
  static const fillHandleKey = Key('sheet-fill-handle');

  /// Kaydetmenin gideceği yol. `null` ise [path]'in kendisi. Eski `.xls`
  /// dosyalarında [path] geçici bir `.xlsx` çalışma kopyasıdır; kaydetme
  /// özgün dosyanın yanına `.xlsx` bırakır (BIFF yazmıyoruz).
  final String? savePath;

  const SpreadsheetEditorScreen({
    super.key,
    required this.path,
    required this.name,
    required this.plainText,
    this.savePath,
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

  /// Formül çubuğunun odağı. Hücre parmakla yazılamayacak kadar küçükse
  /// düzenleme HÜCREDE değil burada açılır (bkz. [_select]).
  final _barFocus = FocusNode();

  double _zoom = 1;

  /// Şeritteki −/%/+ düğmeleri pinch ile AYNI ölçeği sürer.
  final _zoomCtl = PinchZoomController();

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

  /// Metin ölçer (taşma + otomatik satır yüksekliği) — bkz.
  /// `core/sheet_text_measure.dart`.
  final _measure = SheetTextMeasure();

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

  /// Değiştir alanı (Bul çubuğu açıkken).
  final _replaceField = TextEditingController();

  /// Geri alma yığını **sayfa başına**: kullanıcı hangi sayfaya bakıyorsa
  /// geri al onun son işlemini alır. Tek ortak yığın olsaydı geri al bazen
  /// görünmeyen bir sayfayı değiştirirdi.
  final _undoBySheet = <String, SheetUndoStack>{};

  SheetUndoStack get _undo =>
      _undoBySheet.putIfAbsent(_sheet?.name ?? '', SheetUndoStack.new);

  /// Uygulama içi pano. Sistem panosu da yazılır (TSV) ama formül kaydırması
  /// ve "kesme" bilgisi yalnız burada durur.
  SheetClip? _clip;

  /// Doldurma tutamağı sürüklenirken hedeflenen son satır/sütun
  /// (null = sürükleme yok). Hedef aralık seçili gibi vurgulanır.
  int? _fillToRow;
  int? _fillToCol;

  /// Izgara alanının render kutusu — doldurma tutamağı sürüklenirken parmağın
  /// altındaki hücreyi bulmak için gerekiyor (`_cellAtGlobal`).
  final _gridAreaKey = GlobalKey();

  /// Şerit açık mı? (Kullanıcı 2026-08-17: *"üst bilgi alanı … prime alanı
  /// kaplıyor"*.) Kapatınca ızgaraya 68 dp daha kalır; formül çubuğundaki
  /// çift yönlü okla açılır. Veri girerken kapalı, biçim verirken açık —
  /// kullanıcı kendi ritmine göre seçer.
  bool _ribbonOpen = true;

  /// Başlık kenarından sürükleyerek boyutlandırma sürüyor mu (ve neyi)?
  /// `null` = sürükleme yok. Sürüklerken canlı ölçü rozeti gösterilir.
  int? _resizeCol;
  int? _resizeRow;
  double _resizeStart = 0;

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
    _barFocus.dispose();
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
    _autoFitRows(sheet);
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

  /// Dosyada **açık yüksekliği olmayan** satırları içeriğe göre yükseltir —
  /// Excel'in "otomatik satır yüksekliği"nin karşılığı.
  ///
  /// Niye gerekli: pek çok üretici (LibreOffice, Google E-Tablolar, kütüphane
  /// çıktıları) `<row ht="…">` yazmaz; yüksekliği açan Excel'in kendisidir.
  /// Biz varsayılan 15 puntoda bırakınca dört satırlık bir hücre tek satıra
  /// kırpılıyordu (kullanıcı ekran görüntüsü 2026-08-07).
  ///
  /// Sınırlar bilinçli:
  /// * Yalnız **metin kaydırma açık** ya da içinde satır sonu olan hücreler.
  /// * **Birleşik hücreler hariç** — Excel de birleşik hücre için otomatik
  ///   yükseklik hesaplamaz.
  /// * En çok [_autoFitCellLimit] hücre ölçülür: 200 bin hücrelik bir dosyada
  ///   her hücreyi ölçmek açılışı dakikalara çıkarırdı. Kalan satırlar
  ///   varsayılan yükseklikte kalır (eskisi gibi), veri kaybı olmaz.
  static const int _autoFitCellLimit = 4000;

  void _autoFitRows(XlsxSheet sheet) {
    sheet.autoRowHeights.clear();
    final byRow = <int, List<double>>{};
    var measured = 0;
    for (final entry in sheet.layout.cells.entries) {
      if (measured >= _autoFitCellLimit) break;
      final r = rowOfKey(entry.key);
      final c = colOfKey(entry.key);
      // Dosya bu satırın yüksekliğini SÖYLEDİYSE ona dokunulmaz: kullanıcının
      // (ya da Excel'in) verdiği ölçü bizim tahminimizden önce gelir.
      if (sheet.layout.rowHeights.containsKey(r)) continue;
      if (sheet.isRowHidden(r) || sheet.isColHidden(c)) continue;
      if (sheet.mergeAt(r, c) != null) continue;
      // ÖNCE ucuz eleme: kaydırma bayrağı (önbellekli stil) ve ham metindeki
      // satır sonu. Biçimlendirilmiş metni (`viewAt`) üretmek 200 bin hücrelik
      // bir dosyada her ölçü tazelemesinde sayfayı bekletirdi.
      final style = sheet.styleAt(r, c);
      final raw = sheet.rawAt(r, c);
      if (raw.isEmpty) continue;
      if (!(style?.wrap ?? false) && !raw.contains('\n')) continue;
      final text = _autoFitText(sheet, r, c);
      if (text.isEmpty) continue;
      final width = sheet.colWidth(c) -
          SheetCell.horizontalPadding(style);
      if (width <= 8) continue;
      measured++;
      byRow
          .putIfAbsent(r, () => <double>[])
          .add(_measure.heightOf(
            text,
            SheetCell.metricsStyle(style, numeric: false),
            width,
          ));
    }
    byRow.forEach((r, heights) {
      final pt = autoRowHeightPt(
        contentHeights: heights,
        defaultPt: sheet.layout.defaultRowHeightPt,
      );
      if (pt != null) sheet.autoRowHeights[r] = pt;
    });
  }

  /// Otomatik yükseklikte ölçülecek metin. Formül hücrelerinde motoru
  /// çalıştırmak yerine Excel'in dosyaya yazdığı SONUÇ kullanılır: açılışta
  /// bütün sayfanın formüllerini hesaplatmak (yalnız yükseklik için) pahalı.
  String _autoFitText(XlsxSheet sheet, int r, int c) {
    final raw = sheet.rawAt(r, c);
    if (raw.startsWith('=')) return sheet.cachedResultAt(r, c) ?? '';
    if (raw.isEmpty) return '';
    return sheet.viewAt(r, c, raw).text;
  }

  /// Satırın **taşma planı** — hangi hücre komşusunun üstüne sarkıyor.
  /// Görünen sütunlar için her karede kurulur; ölçüm önbelleklidir.
  SheetSpillPlan _spillPlan(
    _RenderContext ctx,
    int r,
    List<int> cols,
    Map<int, XlsxCellView> views,
  ) {
    final sheet = ctx.sheet;
    final rtl = sheet.rightToLeft;
    final cells = <SheetSpillCell>[];
    for (final c in cols) {
      final view = views[c] ?? const XlsxCellView('');
      final style = sheet.styleAt(r, c);
      final align = style?.alignFor(view.numeric, rightToLeft: rtl) ??
          (rtl ? TextAlign.right : TextAlign.left);
      cells.add(SheetSpillCell(
        col: c,
        text: view.text,
        columnWidth: sheet.colWidth(c),
        textWidth: view.text.isEmpty
            ? 0
            : _measure.widthOf(view.text,
                    SheetCell.metricsStyle(style, numeric: view.numeric)) +
                SheetCell.horizontalPadding(style),
        wrap: style?.wrap ?? false,
        merged: sheet.mergeAt(r, c) != null,
        numeric: view.numeric,
        align: switch (align) {
          TextAlign.right => SheetSpillAlign.right,
          TextAlign.center => SheetSpillAlign.center,
          _ => SheetSpillAlign.left,
        },
      ));
    }
    // Sağdan sola sayfada ekranda soldaki sütun, dosyada sağdaki sütundur:
    // taşma yönü ekran sırasına göre çözülür.
    return planRowSpill(rtl ? cells.reversed.toList() : cells);
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
      _beginEdit(r, c);
      return;
    }
    _jumpTo(r, c);
  }

  /// Bir hücreye **yazmaya** başlar.
  ///
  /// Kullanıcı 2026-08-17: *"karelere veri girişi çok zor"*, *"yazarken çıkan
  /// mavi alan gereksiz ve çok dar"*. Sebebi: 15 puntoluk (≈20 dp) bir satırda
  /// hücrenin İÇİNE açılan yazı alanı parmakla imleç konulamayacak kadar
  /// inceydi ve seçim tutamakları hücrenin dışına taşıyordu.
  ///
  /// Çözüm Excel Mobile'ınkiyle aynı: hücre yazmak için yeterince büyükse
  /// yerinde düzenlenir; küçükse düzenleme **formül çubuğuna** taşınır (orası
  /// gerektiğinde üç satıra kadar büyür). İki durumda da hedef hücre seçili
  /// kalır, kullanıcı nereye yazdığını görür.
  static const double _inCellMinHeight = 30;
  static const double _inCellMinWidth = 72;

  void _beginEdit(int r, int c) {
    final sheet = _sheet;
    final tooSmall = sheet == null ||
        sheet.rowHeight(r) * _zoom < _inCellMinHeight ||
        sheet.colWidth(c) * _zoom < _inCellMinWidth;
    if (tooSmall) {
      setState(() => _editing = false);
      _barFocus.requestFocus();
      return;
    }
    setState(() => _editing = true);
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
    if (_range.contains(r, c)) return true;
    // Doldurma tutamağı sürüklenirken hedef alan da vurgulanır: kullanıcı
    // bırakmadan önce nereye yazılacağını görsün (Excel'in önizleme çerçevesi).
    return _fillPreview?.contains(r, c) ?? false;
  }

  /// Sürükleme sırasında doldurulacak aralık (yoksa null). Yalnız TEK eksende
  /// büyür — Excel de köşegen doldurma yapmaz.
  CellRange? get _fillPreview {
    final toRow = _fillToRow, toCol = _fillToCol;
    if (toRow == null || toCol == null) return null;
    final src = _range;
    if (toRow < src.top || toRow > src.bottom) {
      return CellRange(math.min(src.top, toRow), src.left,
          math.max(src.bottom, toRow), src.right);
    }
    if (toCol < src.left || toCol > src.right) {
      return CellRange(src.top, math.min(src.left, toCol), src.bottom,
          math.max(src.right, toCol));
    }
    return null;
  }

  bool get _hasRange => _anchorRow != _selRow || _anchorCol != _selCol;

  /// Açık düzenlemeyi **kaydeder**. Formül çubuğuna yazılmış ama onaylanmamış
  /// metin de buradan geçer.
  ///
  /// Kullanıcı 2026-08-17: *"tik işaretine basmadan kaydolmuyor"*. Eskiden ilk
  /// satır `if (!_editing) return;` idi: hücre İÇİNDE düzenleme açık değilken
  /// (yani formül çubuğuna yazılmışken) yazılan metin sessizce atılıyordu —
  /// başka bir hücreye dokunmak `_syncField()` ile üstüne yazıyordu. Artık
  /// bayraktan bağımsız olarak, alandaki metin hücrenin değerinden FARKLIYSA
  /// yazılır; Excel'in davranışı da budur (imleci taşımak girişi onaylar).
  void _endEdit() {
    final changed = _cellField.text != _valueAt(_selRow, _selCol);
    final wasEditing = _editing;
    _editing = false;
    if (changed) {
      _applyCell(_cellField.text);
    } else if (wasEditing) {
      setState(() {});
    }
  }

  /// Enter: girişi yazar, ALT hücreye geçer ve **yazmaya devam eder**.
  ///
  /// Eskiden `_select` çağrılıyordu: seçim iniyordu ama düzenleme kapanıyor,
  /// klavye her satırda kapanıp açılıyordu. Bir sütuna arka arkaya veri girmek
  /// (kullanıcı 2026-08-17: *"karelere veri girişi çok zor"*) bu yüzden her
  /// satırda iki fazladan dokunuş istiyordu. Excel'de Enter zinciri kesmez.
  void _commitAndMoveDown(int rowCount) {
    _endEdit();
    if (_selRow + 1 >= rowCount) return;
    _jumpTo(_selRow + 1, _selCol);
    _beginEdit(_selRow, _selCol);
  }

  void _applyCell(String value) =>
      _editCells('excel.undo_typing', {CellRef(_selRow, _selCol): value});

  // ── geri alınabilir düzenleme ───────────────────────────────────────────

  /// Seçili aralık (tek hücrede de geçerli).
  CellRange get _range =>
      CellRange.between(_anchorRow, _anchorCol, _selRow, _selCol);

  /// Bir grup hücre yazımını uygular ve **tek** geri alma adımı olarak kaydeder.
  ///
  /// Yapıştırma, doldurma, temizleme, Σ ve düz yazma hepsi buradan geçer:
  /// böylece "geri al" her zaman kullanıcının yaptığı TEK işlemi geri alır,
  /// hücre hücre değil.
  ///
  /// [formatSources] verilirse hedef hücrelerin **görünümü** de kaynağınkine
  /// çekilir (yapıştırma). Değer ve biçim TEK adımda kaydedilir — ayrı iki
  /// adım olsaydı kullanıcı "geri al"a iki kez basmak zorunda kalırdı.
  void _editCells(String label, Map<CellRef, String> values,
      {Map<CellRef, CellRef>? formatSources}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null || values.isEmpty) return;
    final name = sheet.name;
    final valueStep = SheetValueStep(
      label: label,
      before: {for (final k in values.keys) k: sheet.rawAt(k.row, k.col)},
      after: values,
      write: (at, v) => editor.setCell(name, at.row, at.col, v),
    );
    final formats = formatSources ?? const <CellRef, CellRef>{};
    if (valueStep.isNoop && formats.isEmpty) return;

    final stylesBefore = <CellRef, XlsxCellStyle?>{
      for (final at in formats.keys) at: sheet.overrideAt(at.row, at.col),
    };
    final step = _CallbackStep(
      label,
      () {
        valueStep.apply();
        formats.forEach((at, src) =>
            editor.copyCellFormat(name, src.row, src.col, at.row, at.col));
      },
      () {
        valueStep.revert();
        stylesBefore.forEach((at, s) => sheet.patchStyle(at.row, at.col, s));
        // Kaydetmeye giden iz de silinir; yoksa geri alınmış bir yapıştırmanın
        // biçimi dosyaya yine yazılırdı.
        for (final at in formats.keys) {
          sheet.styleCopies.remove((at.row, at.col));
        }
      },
    );
    _undo.push(step);
    _dirty = true;
    _gridVersion++; // yazma kullanılan alanı büyütebilir → ölçüler yenilenir
    // Yapıştırma/doldurma/Σ imlecin ALTINDAKİ değeri de değiştirmiş olabilir;
    // formül çubuğu tazelenmezse eski değeri gösterip bir sonraki düzenlemede
    // onu geri yazardı.
    _syncField();
    setState(() {});
  }

  /// Geri alma yığınına, uygulanmış bir işlemin tersini kaydeder.
  void _recordStep(String label, VoidCallback apply, VoidCallback revert) =>
      _undo.record(_CallbackStep(label, apply, revert));

  void _undoStep() {
    final step = _undo.undo();
    if (step == null) return;
    _afterHistory(step.label, undone: true);
  }

  void _redoStep() {
    final step = _undo.redo();
    if (step == null) return;
    _afterHistory(step.label, undone: false);
  }

  void _afterHistory(String label, {required bool undone}) {
    _editing = false;
    _dirty = true;
    _gridVersion++;
    final sheet = _sheet;
    if (sheet != null) {
      // Yapısal geri alma satır/sütun sayısını değiştirmiş olabilir; imleç
      // sayfanın dışında kalmasın.
      _selRow = _selRow.clamp(0, math.max(0, _rowCount(sheet) - 1));
      _selCol = _selCol.clamp(0, math.max(0, _colCount(sheet) - 1));
      _anchorRow = _anchorRow.clamp(0, math.max(0, _rowCount(sheet) - 1));
      _anchorCol = _anchorCol.clamp(0, math.max(0, _colCount(sheet) - 1));
    }
    _syncField();
    setState(() {});
    _snack(context.t(undone ? 'excel.undone' : 'excel.redone',
        {'what': context.t(label)}));
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
    final name = sheet.name;
    final at = below ? _selRow + 1 : _selRow;
    editor.insertRow(name, at);
    // Eklemenin tersi düz silmedir (eklenen satır boştur, içerik kaybı yok).
    _recordStep('excel.undo_insert_row', () => editor.insertRow(name, at),
        () => editor.deleteRow(name, at));
    if (below) _selRow += 1;
    _afterStructural();
  }

  void _deleteRow() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final name = sheet.name;
    final at = _selRow;
    // Silmenin tersi "ekle" DEĞİL, "ekle + içeriği geri koy": satırın
    // değerleri, biçimleri ve yüksekliği yakalanmadan geri alma veri kaybeder.
    final snap = editor.captureRow(name, at);
    editor.deleteRow(name, at);
    _recordStep('excel.undo_delete_row', () => editor.deleteRow(name, at), () {
      editor.insertRow(name, at);
      editor.restoreRow(name, at, snap);
    });
    _afterStructural();
  }

  void _insertColumn({required bool right}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final name = sheet.name;
    final at = right ? _selCol + 1 : _selCol;
    editor.insertColumn(name, at);
    _recordStep('excel.undo_insert_col', () => editor.insertColumn(name, at),
        () => editor.deleteColumn(name, at));
    if (right) _selCol += 1;
    _afterStructural();
  }

  void _deleteColumn() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final name = sheet.name;
    final at = _selCol;
    final snap = editor.captureColumn(name, at);
    editor.deleteColumn(name, at);
    _recordStep('excel.undo_delete_col', () => editor.deleteColumn(name, at),
        () {
      editor.insertColumn(name, at);
      editor.restoreColumn(name, at, snap);
    });
    _afterStructural();
  }

  // ── pano · temizle · otomatik toplam · doldurma ─────────────────────────

  /// Seçili aralığı panoya alır. [cut] ise yapıştırdıktan sonra kaynak
  /// temizlenir — Excel'de kesme budur (kaynak hemen değil, YAPIŞTIRINCA
  /// boşalır; kullanıcı vazgeçerse veri yerinde kalır).
  Future<void> _copySelection({bool cut = false}) async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _range;
    final clip = SheetClip(
      values: [
        for (var row = r.top; row <= r.bottom; row++)
          [for (var col = r.left; col <= r.right; col++) sheet.rawAt(row, col)],
      ],
      origin: CellRef(r.top, r.left),
      cut: cut,
    );
    setState(() => _clip = clip);
    // Sistem panosuna TSV: kullanıcı başka bir uygulamaya (gerçek Excel dahil)
    // yapıştırabilsin.
    await Clipboard.setData(ClipboardData(text: clip.toTsv()));
    if (!mounted) return;
    _snack(context.t(cut ? 'excel.cut_done' : 'excel.copy_done',
        {'n': r.cellCount}));
  }

  /// Panoyu seçime yapıştırır.
  ///
  /// Uygulama içi pano varsa o kullanılır (formül kaydırması ve kesme bilgisi
  /// oradadır); yoksa **sistem panosundaki metin** TSV olarak çözümlenir —
  /// böylece başka uygulamadan kopyalanan tablo da yapışır.
  Future<void> _paste() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    var clip = _clip;
    if (clip == null) {
      final data = await Clipboard.getData('text/plain');
      clip = SheetClip.fromTsv(data?.text ?? '',
          origin: CellRef(_selRow, _selCol));
    }
    if (clip == null || clip.isEmpty) {
      if (mounted) _snack(context.t('excel.clipboard_empty'));
      return;
    }
    final values = pasteCells(clip, _range);
    // Excel yapıştırırken hücrenin BİÇİMİNİ de taşır. Yalnız uygulama içi
    // panoda yapılabilir: sistem panosundan gelen düz metnin biçimi yok.
    final formats = _clip == null ? null : pasteSources(clip, _range);
    if (clip.cut) {
      // Kesmede kaynak da aynı adımda temizlenir; iki ayrı adım olsaydı
      // "geri al" yarım bir durum bırakırdı.
      for (var r = 0; r < clip.rows; r++) {
        for (var c = 0; c < clip.cols; c++) {
          final at = CellRef(clip.origin.row + r, clip.origin.col + c);
          values.putIfAbsent(at, () => '');
        }
      }
    }
    _editCells('excel.undo_paste', values, formatSources: formats);
    if (clip.cut) setState(() => _clip = null);
  }

  /// Seçili aralığın içeriğini siler (Excel'de Delete tuşu).
  void _clearSelection() {
    _endEdit();
    final r = _range;
    _editCells('excel.undo_clear', {
      for (var row = r.top; row <= r.bottom; row++)
        for (var col = r.left; col <= r.right; col++) CellRef(row, col): '',
    });
  }

  /// Σ — imlecin üstündeki (yoksa solundaki) bitişik sayı bloğunu toplar.
  void _autoSum() {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final range = autoSumRange(
        _selRow, _selCol, (r, c) => sheet.isNumericAt(r, c));
    final formula = range == null
        ? '=TOPLA()'
        : '=TOPLA(${CellRef(range.top, range.left)}:'
            '${CellRef(range.bottom, range.right)})';
    _editCells('excel.undo_autosum', {CellRef(_selRow, _selCol): formula});
    if (range == null && mounted) _snack(context.t('excel.autosum_empty'));
  }

  /// Doldurma tutamağı bırakıldığında seriyi yazar.
  ///
  /// Yalnız TEK eksende doldurma yapılır (Excel de öyle): sürükleme daha çok
  /// hangi yönde ilerlediyse o eksen seçilir.
  void _applyFill(int toRow, int toCol) {
    final sheet = _sheet;
    if (sheet == null) return;
    final src = _range;
    final vertical = toRow < src.top || toRow > src.bottom;
    final horizontal = toCol < src.left || toCol > src.right;
    if (!vertical && !horizontal) return;

    final values = <CellRef, String>{};
    if (vertical) {
      final backwards = toRow < src.top;
      final count = backwards ? src.top - toRow : toRow - src.bottom;
      for (var col = src.left; col <= src.right; col++) {
        final source = [
          for (var row = src.top; row <= src.bottom; row++) sheet.rawAt(row, col),
        ];
        final out = FillSeries.extend(source, count, backwards: backwards);
        for (var i = 0; i < out.length; i++) {
          final row = backwards ? toRow + i : src.bottom + 1 + i;
          values[CellRef(row, col)] = out[i];
        }
      }
    } else {
      final backwards = toCol < src.left;
      final count = backwards ? src.left - toCol : toCol - src.right;
      for (var row = src.top; row <= src.bottom; row++) {
        final source = [
          for (var col = src.left; col <= src.right; col++) sheet.rawAt(row, col),
        ];
        final out = FillSeries.extend(source, count,
            backwards: backwards, horizontal: true);
        for (var i = 0; i < out.length; i++) {
          final col = backwards ? toCol + i : src.right + 1 + i;
          values[CellRef(row, col)] = out[i];
        }
      }
    }
    _editCells('excel.undo_fill', values);
    // Doldurulan alan Excel'de seçili kalır.
    setState(() {
      if (vertical) {
        _anchorRow = math.min(src.top, toRow);
        _selRow = math.max(src.bottom, toRow);
      } else {
        _anchorCol = math.min(src.left, toCol);
        _selCol = math.max(src.right, toCol);
      }
    });
  }

  Future<void> _save() async {
    _endEdit();
    final editor = _editor;
    if (editor == null) return;
    final target = widget.savePath ?? widget.path;
    try {
      final bytes = editor.save();
      await File(target).writeAsBytes(bytes);
      // Çevrilmiş dosyada çalışma kopyası da tazelenir: kullanıcı kaydettikten
      // sonra düzenlemeye devam edip yine kaydedebilsin.
      if (widget.savePath != null) {
        await File(widget.path).writeAsBytes(bytes);
      }
      // "Yaptıklarım" defteri: kaydedilen HEDEF yazılır (.xls açıldıysa
      // kullanıcının elindeki dosya .xlsx olan odur).
      unawaited(ActivityLog.add(ActivityKind.documentEdit, target));
      _dirty = false;
      if (mounted) {
        showSnack(context, widget.savePath == null
              ? context.t('common.saved_hint')
              : context.t('excel.saved_as_xlsx',
                  {'name': p.basename(target)}));
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
              subtitle: Text(context.t('excel.csv_utf8_sub')),
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
    showSnack(context, m);
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
        // Geri al / yinele Excel'de de en görünür yerdedir: her düzenleme
        // güvenle denenebilsin.
        // Sayfa git / bölme / yön ve arama artık ŞERİTTE (Veri ve Görünüm
        // sekmeleri) — üst çubukta yalnız her an lazım olan ikili kaldı.
        IconButton(
          tooltip: context.t('excel.undo'),
          icon: const Icon(OfficeIcons.undo),
          onPressed: editor == null || !_undo.canUndo ? null : _undoStep,
        ),
        IconButton(
          tooltip: context.t('excel.redo'),
          icon: const Icon(OfficeIcons.redo),
          onPressed: editor == null || !_undo.canRedo ? null : _redoStep,
        ),
        IconButton(
          tooltip: context.t('common.search'),
          icon: const Icon(OfficeIcons.search),
          onPressed: editor == null ? null : _toggleFind,
        ),
      ],
      body: _error != null
          ? Center(
              child: Text(context.t('common.open_failed', {'error': _error})))
          : editor == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (_finding) ...[_findBar(), _replaceBar()],
                    _cellBar(),
                    _formulaSuggestions(),
                    _formulaPreview(),
                    if (_ribbonOpen) _ribbon(),
                    Expanded(
                      child: PinchZoomArea(
                        minZoom: 0.3,
                        maxZoom: 3,
                        controller: _zoomCtl,
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
    // Şeritteki zoom yüzdesi ölçekle birlikte yenilensin (rozet pinch'te
    // görünür, düğmeyle zoomda görünmez — kullanıcının tek göstergesi bu).
    if (mounted) setState(() {});
  }

  /// Seçim adresi (tek hücre ya da aralık) — "Ad Kutusu".
  String get _selectionLabel => _hasRange
      ? '${XlsxRange.colName(math.min(_anchorCol, _selCol))}'
          '${math.min(_anchorRow, _selRow) + 1}:'
          '${XlsxRange.colName(math.max(_anchorCol, _selCol))}'
          '${math.max(_anchorRow, _selRow) + 1}'
      : '${XlsxRange.colName(_selCol)}${_selRow + 1}';

  /// Alandaki metin hücrenin değerinden farklı mı (onaylanmamış giriş var mı)?
  bool get _hasPendingInput =>
      _cellField.text != _valueAt(_selRow, _selCol);

  /// **Formül çubuğu** — tek satır, sıkışık.
  ///
  /// Kullanıcı 2026-08-17: *"yazarken çıkan mavi alan gereksiz ve çok dar"* +
  /// *"üst bilgi alanı çok kalabalık"*. Değişenler:
  /// * Çerçeveli (`OutlineInputBorder`) kutu gitti — odaklanınca çevresinde
  ///   beliren mavi hat kadar yer kaplayan ikinci bir çerçeveydi. Yerine
  ///   yüzey tonunda, çerçevesiz bir alan geldi.
  /// * Yükseklik 50 → 38 dp; ✓ ve ✗ **yalnız onaylanmamış giriş varken**
  ///   çıkar (Excel de böyle yapar), yer boşuna durmaz.
  /// * Yazarken alan **büyür** (en çok 3 satır): uzun bir hücre metnini tek
  ///   satırlık bir yarıkta düzenlemek imkânsızdı.
  /// * Şeridi açıp kapatan çift yönlü ok sağda: ızgaraya 68 dp daha yer.
  Widget _cellBar() {
    final scheme = Theme.of(context).colorScheme;
    final pending = _hasPendingInput;
    return Container(
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ad Kutusu: dokununca "Hücreye git" (Excel'de de yazılabilir bir
          // alandır; telefonda diyalog daha güvenli).
          InkWell(
            onTap: _editor == null ? null : _showGoTo,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Container(
              width: 62,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Text(
                _selectionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _cellField,
              focusNode: _barFocus,
              onSubmitted: (_) {
                final sheet = _sheet;
                if (sheet == null) {
                  _applyCell(_cellField.text);
                  return;
                }
                _commitAndMoveDown(_rowCount(sheet));
              },
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              minLines: 1,
              maxLines: pending ? 3 : 1,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: context.t('excel.cell_content'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
            ),
          ),
          // Veri doğrulama listesi olan hücrede Excel'deki açılır ok.
          if (_validationOptions().isNotEmpty)
            PopupMenuButton<String>(
              tooltip: context.t('excel.pick_from_list'),
              icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20),
              padding: EdgeInsets.zero,
              onSelected: (v) {
                _cellField.text = v;
                _applyCell(v);
              },
              itemBuilder: (_) => [
                for (final o in _validationOptions())
                  PopupMenuItem(value: o, child: Text(o)),
              ],
            ),
          // ✗ / ✓ yalnız onaylanmamış giriş varken. (Kaydetmek için ✓'e basmak
          // ZORUNLU DEĞİL — başka hücreye geçmek de yazar, bkz. `_endEdit`.)
          if (pending) ...[
            IconButton(
              tooltip: context.t('common.cancel'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(Icons.close),
              onPressed: () {
                _editing = false;
                _syncField();
                setState(() {});
              },
            ),
            IconButton(
              tooltip: context.t('common.apply'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              color: OfficeColors.excel,
              icon: const Icon(Icons.check),
              onPressed: () {
                _editing = false;
                _applyCell(_cellField.text);
              },
            ),
          ],
          IconButton(
            tooltip: context.t(_ribbonOpen ? 'excel.ribbon_hide' : 'excel.ribbon_show'),
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(
                _ribbonOpen ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => _ribbonOpen = !_ribbonOpen),
          ),
        ],
      ),
    );
  }

  /// Seçili hücrenin veri doğrulama listesi (yoksa boş).
  List<String> _validationOptions() =>
      _sheet?.validationAt(_selRow, _selCol)?.options ?? const [];

  /// Formül yazarken **işlev adı önerileri**.
  ///
  /// Motor 100'ün üzerinde işlev biliyordu ama kullanıcı adını ezberlemek
  /// zorundaydı (KALANLAR maddesi). Öneriler imlecin solundaki YARIM SÖZCÜKTEN
  /// üretilir: `=TOP` → TOPLA, `=DÜŞ` → DÜŞEYARA. Ayrı bir "işlev sihirbazı"
  /// ekranı yerine satır içi öneri seçildi — telefonda ekran değiştirmeden,
  /// yazma ritmini bozmadan çalışıyor.
  Widget _formulaSuggestions() {
    final names = _currentCompletions();
    if (names.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.only(left: 68, right: 8, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final name in names)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 12),
                  label: Text(name),
                  onPressed: () => _completeFunction(name),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// İmlecin solundaki yarım işlev adı (yoksa boş).
  ///
  /// Yalnız formülde ve **harf** dizisi üzerinde çalışır: `=A1+` sonrası
  /// başvuru yazılıyor olabilir, oraya işlev önermek yanıltıcı olurdu.
  (int, String) _functionPrefixAt() {
    final text = _cellField.text;
    if (!text.startsWith('=')) return (-1, '');
    final sel = _cellField.selection;
    final caret = sel.isValid ? sel.baseOffset : text.length;
    var start = caret.clamp(0, text.length);
    while (start > 1 && _isNameChar(text.codeUnitAt(start - 1))) {
      start--;
    }
    final word = text.substring(start, caret.clamp(0, text.length));
    return word.isEmpty ? (-1, '') : (start, word);
  }

  /// İşlev adında geçebilen karakter: harf, rakam, alt çizgi, Türkçe harfler.
  static bool _isNameChar(int u) =>
      (u >= 65 && u <= 90) ||
      (u >= 97 && u <= 122) ||
      (u >= 48 && u <= 57) ||
      u == 95 ||
      u > 127;

  List<String> _currentCompletions() {
    final (start, word) = _functionPrefixAt();
    if (start < 0 || word.length < 2) return const [];
    // Zaten tam bir işlev adı yazıldıysa öneri göstermeye gerek yok.
    final hits = FormulaEngine.completionsFor(word);
    if (hits.length == 1 && hits.first.length == word.length) return const [];
    return hits;
  }

  /// Yarım adı seçilen işlevle tamamlar ve imleci parantezin içine koyar.
  void _completeFunction(String name) {
    final (start, word) = _functionPrefixAt();
    if (start < 0) return;
    final text = _cellField.text;
    final end = start + word.length;
    final inserted = '$name(';
    final next = text.replaceRange(start, end, inserted);
    _cellField.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    setState(() {});
  }

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
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(70, 0, 12, 4),
      child: Text(
        '= $result',
        style: TextStyle(
          fontSize: 12,
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
    setState(() {});
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
    setState(() {});
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
    setState(() {});
  }

  /// Excel'in standart renk paleti + "yok". Serbest renk seçici bilinçli
  /// olarak yok: telefonda çarkla renk aramak yavaş, Excel mobil de sabit
  /// paletle çalışıyor.
  static const _palette = <int>[
    0xFFFFFFFF, 0xFF000000, 0xFF808080, 0xFFD9D9D9,
    0xFFC00000, 0xFFFF0000, 0xFFFFC000, 0xFFFFFF00,
    0xFF92D050, 0xFF00B050, 0xFF00B0F0, 0xFF0070C0,
    0xFF002060, 0xFF7030A0, 0xFFFCE4D6, 0xFFDDEBF7,
  ];

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
                  for (final argb in _palette)
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
              icon: const Icon(Icons.format_color_reset),
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

  /// Excel mobilin "Sayı biçimi" listesi. Kodlar Türkçe Excel'in yazdığı
  /// kodlarla aynı (para birimi ₺, tarih `dd.mm.yyyy`).
  static const _numberFormatPresets = <(String, String)>[
    ('excel.fmt_general', 'General'),
    ('excel.fmt_number', '#,##0.00'),
    ('excel.fmt_thousands', '#,##0'),
    ('excel.fmt_currency', r'#,##0.00\ ₺'),
    ('excel.fmt_percent', '0%'),
    ('excel.fmt_date', 'dd.mm.yyyy'),
    ('excel.fmt_time', 'hh:mm'),
    ('excel.fmt_text', '@'),
  ];

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
    setState(() {});
  }

  /// **Excel şeridi** (2026-08-07 kullanıcı isteği: *"xls şeritte Excel gibi
  /// simgeler bile yok"*).
  ///
  /// Sekmeler Excel'in kendi düzeni: Giriş / Ekle / Veri / Görünüm. Simge dili
  /// üç editörde ortak (`OfficeIcons`) — aynı iş Word'de de aynı simge.
  ///
  /// Eski "sade altı düğme + Daha fazla" kararı BURADA GEÇERSİZ: sadeliğin
  /// bedeli, kullanıcının Excel'de refleksle bulduğu her şeyin (yazı tipi,
  /// punto, kenarlık, süzgeç, zoom) menü içinde kaybolmasıydı. Etiketli
  /// "Daha fazla" sayfası **duruyor** — sekmelerin dışında kalan seyrek
  /// işler hâlâ orada.
  Widget _ribbon() {
    final selStyle = _sheet?.styleAt(_selRow, _selCol);
    final align = selStyle?.hAlign;
    final merged = _sheet?.mergeAt(_selRow, _selCol) != null;

    return OfficeRibbon(
      compact: true,
      tabs: [
        RibbonTab(context.t('excel.tab_home'), [
          RibbonChip(
            icon: OfficeIcons.fontFamily,
            label: selStyle?.fontFamily ?? context.t('excel.font_default'),
            tooltip: context.t('word.font_family'),
            onTap: _pickFontFamily,
          ),
          RibbonChip(
            icon: OfficeIcons.fontSize,
            label: _sizeText(selStyle?.fontSize),
            tooltip: context.t('word.font_size'),
            onTap: _pickFontSize,
          ),
          RibbonButton(OfficeIcons.fontGrow, context.t('vw.text_bigger'),
              onTap: () => _bumpFontSize(1)),
          RibbonButton(OfficeIcons.fontShrink, context.t('vw.text_smaller'),
              onTap: () => _bumpFontSize(-1)),
          const RibbonSep(),
          RibbonButton(OfficeIcons.bold, context.t('common.bold'),
              active: selStyle?.bold ?? false,
              onTap: () => _applyStyle(bold: !(selStyle?.bold ?? false))),
          RibbonButton(OfficeIcons.italic, context.t('common.italic'),
              active: selStyle?.italic ?? false,
              onTap: () => _applyStyle(italic: !(selStyle?.italic ?? false))),
          RibbonButton(OfficeIcons.textColor, context.t('excel.font_color'),
              onTap: () =>
                  _pickColor(context.t('excel.font_color'), _applyFontColor)),
          RibbonButton(OfficeIcons.fillColor, context.t('excel.fill_color'),
              onTap: () =>
                  _pickColor(context.t('excel.fill_color'), _applyFillColor)),
          RibbonButton(OfficeIcons.borders, context.t('excel.borders'),
              onTap: _showBorders),
          const RibbonSep(),
          RibbonMenu<TextAlign>(
            icon: _alignIcon(align),
            tooltip: context.t('excel.alignment'),
            onSelected: (a) => _applyStyle(align: a),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: TextAlign.left,
                checked: align == XlsxHAlign.left,
                child: Text(context.t('common.align_left')),
              ),
              CheckedPopupMenuItem(
                value: TextAlign.center,
                checked: align == XlsxHAlign.center,
                child: Text(context.t('common.align_center')),
              ),
              CheckedPopupMenuItem(
                value: TextAlign.right,
                checked: align == XlsxHAlign.right,
                child: Text(context.t('common.align_right')),
              ),
            ],
          ),
          RibbonButton(OfficeIcons.wrapText, context.t('excel.wrap_text'),
              active: selStyle?.wrap ?? false,
              onTap: () => _applyWrap(!(selStyle?.wrap ?? false))),
          RibbonButton(OfficeIcons.merge,
              context.t(merged ? 'excel.unmerge' : 'excel.merge'),
              active: merged, onTap: _toggleMerge),
          const RibbonSep(),
          RibbonMenu<String>(
            icon: OfficeIcons.numberFormat,
            tooltip: context.t('excel.number_format'),
            onSelected: (code) => _applyNumberFormat((_) => code),
            itemBuilder: (_) => [
              for (final (key, code) in _numberFormatPresets)
                CheckedPopupMenuItem(
                  value: code,
                  checked: _sheet?.numFmtCode(_selRow, _selCol) == code,
                  child: Text(context.t(key)),
                ),
            ],
          ),
          RibbonButton(Icons.add, context.t('excel.decimal_more'),
              onTap: () => _applyNumberFormat((c) => bumpDecimals(c, 1))),
          RibbonButton(Icons.remove, context.t('excel.decimal_less'),
              onTap: () => _applyNumberFormat((c) => bumpDecimals(c, -1))),
          RibbonButton(OfficeIcons.autoSum, context.t('excel.autosum'),
              onTap: _autoSum),
        ]),
        RibbonTab(context.t('excel.tab_insert'), [
          RibbonButton(Icons.keyboard_arrow_up,
              context.t('excel.insert_row_above'),
              onTap: () => _insertRow(below: false)),
          RibbonButton(Icons.keyboard_arrow_down,
              context.t('excel.insert_row_below'),
              onTap: () => _insertRow(below: true)),
          RibbonButton(Icons.keyboard_arrow_left,
              context.t('excel.insert_col_left'),
              onTap: () => _insertColumn(right: false)),
          RibbonButton(Icons.keyboard_arrow_right,
              context.t('excel.insert_col_right'),
              onTap: () => _insertColumn(right: true)),
          const RibbonSep(),
          RibbonButton(OfficeIcons.insertRow, context.t('excel.delete_row'),
              onTap: _deleteRow),
          RibbonButton(
              OfficeIcons.insertColumn, context.t('excel.delete_col'),
              onTap: _deleteColumn),
          RibbonButton(
              OfficeIcons.clearContents, context.t('excel.clear_contents'),
              onTap: _clearSelection),
          const RibbonSep(),
          RibbonButton(OfficeIcons.rowHeight, context.t('excel.row_height'),
              onTap: () => _showSizeDialog(row: _selRow)),
          RibbonButton(
              OfficeIcons.columnWidth, context.t('excel.column_width'),
              onTap: () => _showSizeDialog(col: _selCol)),
          RibbonButton(OfficeIcons.sheetAdd, context.t('excel.add_sheet'),
              onTap: _addSheet),
        ]),
        RibbonTab(context.t('excel.tab_data'), [
          RibbonButton(OfficeIcons.sortAsc, context.t('excel.sort_asc'),
              onTap: () => _sortSelection(true)),
          RibbonButton(OfficeIcons.sortDesc, context.t('excel.sort_desc'),
              onTap: () => _sortSelection(false)),
          RibbonButton(OfficeIcons.filter, context.t('excel.filter'),
              onTap: _filterSelectedColumn),
          const RibbonSep(),
          RibbonButton(OfficeIcons.condFormat, context.t('excel.cond_format'),
              onTap: _showCondFormat),
          RibbonButton(OfficeIcons.search, context.t('common.search'),
              active: _finding, onTap: _toggleFind),
          RibbonButton(OfficeIcons.goTo, context.t('excel.goto_cell_menu'),
              onTap: _showGoTo),
          const RibbonSep(),
          RibbonButton(OfficeIcons.cut, context.t('excel.cut'),
              onTap: () => _copySelection(cut: true)),
          RibbonButton(OfficeIcons.copy, context.t('common.copy'),
              onTap: _copySelection),
          RibbonButton(OfficeIcons.paste, context.t('excel.paste'),
              onTap: _paste),
        ]),
        RibbonTab(context.t('excel.tab_view'), [
          RibbonButton(OfficeIcons.zoomOut, context.t('excel.zoom_out'),
              onTap: () => _zoomCtl.zoomBy(1 / 1.25)),
          RibbonChip(
            icon: Icons.search,
            label: '%${(_zoom * 100).round()}',
            tooltip: context.t('excel.zoom_reset'),
            onTap: () => _zoomCtl.setZoom(1),
          ),
          RibbonButton(OfficeIcons.zoomIn, context.t('excel.zoom_in'),
              onTap: () => _zoomCtl.zoomBy(1.25)),
          const RibbonSep(),
          if (_sheetHasFreeze)
            RibbonButton(
                OfficeIcons.freeze,
                context.t(_freeze
                    ? 'excel.unfreeze_panes'
                    : 'excel.freeze_panes'),
                active: _freeze,
                onTap: _toggleFreeze),
          RibbonButton(Icons.format_textdirection_r_to_l,
              context.t('excel.sheet_rtl'),
              active: _sheet?.rightToLeft ?? false,
              onTap: _toggleSheetDirection),
          RibbonButton(OfficeIcons.undo, context.t('excel.undo'),
              onTap: _undo.canUndo ? _undoStep : null),
          RibbonButton(OfficeIcons.redo, context.t('excel.redo'),
              onTap: _undo.canRedo ? _redoStep : null),
        ]),
      ],
      // Etiketli sayfa: seyrek ama gerekli olan her şey burada kalır.
      trailing: TextButton.icon(
        onPressed: _showMore,
        icon: const Icon(OfficeIcons.more, size: 20),
        label: Text(context.t('common.more')),
      ),
    );
  }

  /// Seçili hücrenin puntosu (yoksa dosyanın tabanı 11).
  String _sizeText(double? size) => '${(size ?? 11).round()}';

  /// Seçili aralığın yazı tipini değiştirir. Liste uygulamada GÖMÜLÜ olan ve
  /// her cihazda bulunan ailelerle sınırlı: seçilen ad hem ekranda çizilebilsin
  /// hem de dosyaya yazılınca Excel'de aynı görünsün.
  Future<void> _pickFontFamily() async {
    _endEdit();
    final current = _sheet?.styleAt(_selRow, _selCol)?.fontFamily;
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final f in _fontFamilies)
              ListTile(
                // Örnek yazı GÖMÜLÜ karşılıkla çizilir: "Georgia" adıyla
                // çizmeye kalkmak Android'de sessizce Roboto'ya düşerdi.
                title: Text(f, style: TextStyle(fontFamily: renderFamilyFor(f))),
                trailing: f == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (pick == null) return;
    _applyCellFormat(
      'excel.undo_font',
      (ed, s, r, c) => ed.setFontFamily(s, r, c, pick),
      (ed, s, r, c, before) => ed.setFontFamily(s, r, c, before.fontFamily),
    );
  }

  Future<void> _pickFontSize() async {
    _endEdit();
    final current = _sheet?.styleAt(_selRow, _selCol)?.fontSize ?? 11;
    final pick = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in _fontSizes)
              ListTile(
                title: Text('${s.round()}'),
                trailing:
                    (s - current).abs() < 0.25 ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (pick == null) return;
    _applyFontSize(pick);
  }

  /// Puntoyu bir kademe büyütür/küçültür (Excel'in A▲ A▼ düğmeleri).
  void _bumpFontSize(int delta) {
    final current = _sheet?.styleAt(_selRow, _selCol)?.fontSize ?? 11;
    _applyFontSize((current + delta).clamp(6, 72).toDouble());
  }

  void _applyFontSize(double size) => _applyCellFormat(
        'excel.undo_font',
        (ed, s, r, c) => ed.setFontSize(s, r, c, size),
        (ed, s, r, c, before) => ed.setFontSize(s, r, c, before.fontSize ?? 11),
      );

  /// Word/slayt ile ORTAK liste — kullanıcı bir uygulamada bulduğu yazı
  /// tipini diğerinde de bulsun (`kDocFonts`).
  static final _fontFamilies = kDocFonts.map((f) => f.name).toList();

  static const _fontSizes = kDocFontSizes;

  /// Seçili sütuna göre sıralar.
  ///
  /// Kaynak aralık sırayla: (1) çok satırlı seçim, (2) sayfanın otomatik
  /// süzgeç aralığı. İkisi de yoksa sıralamıyoruz — "hangi satırlar veri,
  /// hangisi başlık" tahmini yanlış çıkarsa tablo bozulur ve kullanıcı bunu
  /// ancak kaydettikten sonra fark eder.
  void _sortSelection(bool ascending) {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r1 = math.min(_anchorRow, _selRow);
    final r2 = math.max(_anchorRow, _selRow);
    if (r2 > r1) {
      _sortByColumn(sheet, _selCol, r1, r2, ascending);
      return;
    }
    final range = _filterRange(sheet);
    if (range != null && _selCol >= range.c1 && _selCol <= range.c2) {
      _sortByColumn(sheet, _selCol, range.r1 + 1,
          math.max(range.r1 + 1, sheet.maxRows - 1), ascending);
      return;
    }
    _snack(context.t('excel.sort_needs_range'));
  }

  /// Süzgeç okunun yaptığını şeritten yapar (aralık yoksa açıklar).
  void _filterSelectedColumn() {
    final sheet = _sheet;
    if (sheet == null) return;
    if (!_filterCoversColumn(sheet, _selCol)) {
      _snack(context.t('excel.filter_needs_table'));
      return;
    }
    _showColumnFilter(sheet, _selCol);
  }

  IconData _alignIcon(XlsxHAlign? align) => switch (align) {
        XlsxHAlign.center => Icons.format_align_center,
        XlsxHAlign.right => Icons.format_align_right,
        XlsxHAlign.justify => Icons.format_align_justify,
        _ => Icons.format_align_left,
      };

  /// Çubuğa sığmayan eylemler — hepsi ETİKETLİ ve konusuna göre gruplu.
  void _showMore() {
    _endEdit();
    DocMoreSheet.show(context, [
      DocMoreGroup(context.t('excel.group_clipboard'), [
        DocMoreItem(Icons.content_cut, context.t('excel.cut'),
            () => _copySelection(cut: true)),
        DocMoreItem(
            Icons.content_copy, context.t('common.copy'), _copySelection),
        DocMoreItem(Icons.content_paste, context.t('excel.paste'), _paste),
        DocMoreItem(Icons.backspace_outlined,
            context.t('excel.clear_contents'), _clearSelection),
      ]),
      DocMoreGroup(context.t('excel.group_number'), [
        DocMoreItem(Icons.add, context.t('excel.decimal_more'),
            () => _applyNumberFormat((c) => bumpDecimals(c, 1))),
        DocMoreItem(Icons.remove, context.t('excel.decimal_less'),
            () => _applyNumberFormat((c) => bumpDecimals(c, -1))),
      ]),
      DocMoreGroup(context.t('excel.group_format'), [
        DocMoreItem(Icons.format_color_fill, context.t('excel.fill_color'),
            () => _pickColor(context.t('excel.fill_color'), _applyFillColor)),
        DocMoreItem(Icons.format_color_text, context.t('excel.font_color'),
            () => _pickColor(context.t('excel.font_color'), _applyFontColor)),
        DocMoreItem(Icons.border_all, context.t('excel.borders'), _showBorders),
        DocMoreItem(
          Icons.wrap_text,
          context.t('excel.wrap_text'),
          () => _applyWrap(!(_sheet?.styleAt(_selRow, _selCol)?.wrap ?? false)),
        ),
        DocMoreItem(
          Icons.merge_type,
          context.t(_sheet?.mergeAt(_selRow, _selCol) != null
              ? 'excel.unmerge'
              : 'excel.merge'),
          _toggleMerge,
        ),
        DocMoreItem(Icons.rule, context.t('excel.cond_format'),
            _showCondFormat),
      ]),
      DocMoreGroup(context.t('excel.row'), [
        DocMoreItem(Icons.keyboard_arrow_up,
            context.t('excel.insert_row_above'), () => _insertRow(below: false)),
        DocMoreItem(Icons.keyboard_arrow_down,
            context.t('excel.insert_row_below'), () => _insertRow(below: true)),
        DocMoreItem(
            Icons.delete_outline, context.t('excel.delete_row'), _deleteRow),
        DocMoreItem(Icons.height, context.t('excel.row_height'),
            () => _showSizeDialog(row: _selRow)),
      ]),
      DocMoreGroup(context.t('excel.column'), [
        DocMoreItem(Icons.keyboard_arrow_left, context.t('excel.insert_col_left'),
            () => _insertColumn(right: false)),
        DocMoreItem(Icons.keyboard_arrow_right,
            context.t('excel.insert_col_right'), () => _insertColumn(right: true)),
        DocMoreItem(
            Icons.delete_outline, context.t('excel.delete_col'), _deleteColumn),
        DocMoreItem(Icons.straighten, context.t('excel.column_width'),
            () => _showSizeDialog(col: _selCol)),
      ]),
    ]);
  }

  /// Koşullu biçimlendirme kuralları — eskiden yalnız OKUNUYORDU, kullanıcı
  /// kural ekleyemiyordu (KALANLAR maddesi).
  ///
  /// Kural seçili aralığa uygulanır. Karşılaştırma değeri **serbest metin**:
  /// sayı kuralları için sayı, metin kuralları için aranan sözcük.
  void _showCondFormat() {
    _endEdit();
    DocMoreSheet.show(context, [
      DocMoreGroup(context.t('excel.cond_format'), [
        DocMoreItem(Icons.trending_up, context.t('excel.cond_greater'),
            () => _askCondRule('cellIs', operator: 'greaterThan')),
        DocMoreItem(Icons.trending_down, context.t('excel.cond_less'),
            () => _askCondRule('cellIs', operator: 'lessThan')),
        DocMoreItem(Icons.drag_handle, context.t('excel.cond_equal'),
            () => _askCondRule('cellIs', operator: 'equal')),
        DocMoreItem(Icons.text_fields, context.t('excel.cond_contains'),
            () => _askCondRule('containsText')),
      ]),
    ]);
  }

  /// Kuralın eşiğini ve rengini sorar, sonra uygular.
  Future<void> _askCondRule(String type, {String? operator}) async {
    final editor = _editor;
    final sheet = _sheet;
    if (editor == null || sheet == null) return;
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('excel.cond_format')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: type == 'cellIs'
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
              labelText: ctx.t(type == 'cellIs'
                  ? 'excel.cond_value'
                  : 'excel.cond_text')),
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
    );
    if (value == null || value.isEmpty || !mounted) return;

    await _pickColor(context.t('excel.fill_color'), (color) {
      final range = _range;
      final xr = XlsxRange(range.top, range.left, range.bottom, range.right);
      // "Renk yok" seçilirse Excel'in varsayılan açık kırmızısı kullanılır:
      // renksiz bir kuralın ekranda hiçbir etkisi olmazdı.
      final fill = _argbOf(color ?? const Color(0xFFFFC7CE));
      // Yinele (redo) kuralı YENİDEN kurar; hangi nesnenin söküleceğini
      // bilmek için son eklenen tutulur.
      XlsxCondRule? added;
      void apply() {
        added = sheet.addCondRule(
          range: xr,
          type: type,
          operator: operator,
          formulas: type == 'cellIs' ? [value] : const [],
          text: type == 'cellIs' ? null : value,
          fillArgb: fill,
        );
      }

      apply();
      _recordStep('excel.undo_cond_format', apply, () {
        final rule = added;
        if (rule != null) sheet.removeCondRule(rule);
      });
      _dirty = true;
      _gridVersion++;
      setState(() {});
    });
  }

  static int _argbOf(Color c) =>
      ((c.a * 255).round() << 24) |
      ((c.r * 255).round() << 16) |
      ((c.g * 255).round() << 8) |
      (c.b * 255).round();

  /// Kenarlık ön ayarları (Excel'in "Kenarlıklar" menüsü).
  void _showBorders() {
    const thin = 'thin';
    DocMoreSheet.show(context, [
      DocMoreGroup(context.t('excel.borders'), [
        DocMoreItem(Icons.border_all, context.t('excel.border_all'),
            () => _applyBorder(const {
                  'left': thin,
                  'right': thin,
                  'top': thin,
                  'bottom': thin,
                })),
        DocMoreItem(Icons.border_outer, context.t('excel.border_outline'),
            _applyOutlineBorder),
        DocMoreItem(Icons.border_bottom, context.t('excel.border_bottom'),
            () => _applyBorder(const {'bottom': thin})),
        DocMoreItem(Icons.border_top, context.t('excel.border_top'),
            () => _applyBorder(const {'top': thin})),
        DocMoreItem(Icons.border_clear, context.t('excel.border_none'),
            () => _applyBorder(const {
                  'left': null,
                  'right': null,
                  'top': null,
                  'bottom': null,
                })),
      ]),
    ]);
  }

  /// "Dış kenarlık": aralığın yalnız DIŞ kenarlarına çizgi — içteki hücre
  /// sınırları boş kalır. Her hücrenin hangi kenarı dışta olduğu konumuna
  /// bağlı olduğu için bu, [_applyCellFormat]'ın tek biçimli döngüsüne
  /// sığmıyor; adım burada elle kurulur.
  void _applyOutlineBorder() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final range = _range;
    final name = sheet.name;
    final before = <CellRef, XlsxBorder>{
      for (var r = range.top; r <= range.bottom; r++)
        for (var c = range.left; c <= range.right; c++)
          CellRef(r, c): (sheet.styleAt(r, c) ?? const XlsxCellStyle()).border,
    };
    void applyNow() {
      for (var r = range.top; r <= range.bottom; r++) {
        for (var c = range.left; c <= range.right; c++) {
          editor.setCellBorder(name, r, c, {
            'left': c == range.left ? 'thin' : null,
            'right': c == range.right ? 'thin' : null,
            'top': r == range.top ? 'thin' : null,
            'bottom': r == range.bottom ? 'thin' : null,
          });
        }
      }
    }

    applyNow();
    _recordStep('excel.undo_border', applyNow, () {
      before.forEach((at, b) => editor.setCellBorder(name, at.row, at.col, {
            'left': b.left.visible ? b.left.style : null,
            'right': b.right.visible ? b.right.style : null,
            'top': b.top.visible ? b.top.style : null,
            'bottom': b.bottom.visible ? b.bottom.style : null,
          }));
    });
    _dirty = true;
    setState(() {});
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

  /// Durum çubuğu — solda seçim bilgisi, sağda **kaçıncı sayfadayız**
  /// (2026-08-01 kullanıcı isteği: toplam sayfa sayısı her belgede görünsün).
  /// Excel'in "sayfa"sı çalışma sayfasıdır; gizli sayfalar sayılmaz çünkü
  /// sekmelerde de görünmezler.
  Widget _statusText(String text, ColorScheme scheme) {
    final sheets =
        _editor?.sheets.where((s) => !s.layout.hidden).toList() ?? const [];
    final at = _sheet == null ? -1 : sheets.indexWhere((s) => s.name == _sheet!.name);
    final style = TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant);
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: style),
          ),
          if (at >= 0) ...[
            const SizedBox(width: 8),
            Text(
              context.t('excel.sheet_pos',
                  {'n': at + 1, 'total': sheets.length}),
              style: style,
            ),
          ],
        ],
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
            ),
          // Yeni sayfa — sekmelerin sonunda, Excel'deki "+" gibi.
          IconButton(
            tooltip: context.t('excel.add_sheet'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 20),
            onPressed: _addSheet,
          ),
        ],
      ),
    );
  }

  /// Sekmeye uzun basınca: yeniden adlandır / sil.
  ///
  /// Sayfa **taşıma** bilinçli olarak yok: `excel 4.0.6` sayfa sırasını kendi
  /// haritasının ekleme sırasından yazıyor ve sırayı değiştirecek bir API
  /// sunmuyor; sıralamayı zorlamak sayfaları kopyala-sil ile yeniden kurmak
  /// demek olurdu ve her sayfanın biçim tablosu bağını riske atardı.
  void _sheetActions(XlsxSheet sheet) {
    _endEdit();
    DocMoreSheet.show(context, [
      DocMoreGroup(sheet.name, [
        DocMoreItem(Icons.drive_file_rename_outline,
            context.t('excel.rename_sheet'), () => _renameSheet(sheet)),
        DocMoreItem(Icons.delete_outline, context.t('excel.delete_sheet'),
            () => _deleteSheet(sheet)),
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
    setState(() {
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
    setState(() => _dirty = true);
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
    setState(() {
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

  /// Bul çubuğunun ikinci satırı: **değiştir**.
  Widget _replaceBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replaceField,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: context.t('excel.replace_with'),
                prefixIcon: const Icon(Icons.find_replace, size: 18),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
    final next = _replaceOnce(old, query, _replaceField.text);
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
      final next = _replaceAllIn(old, query, to);
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

  /// Büyük/küçük harf duyarsız TEK değiştirme (arama da duyarsız arıyor).
  static String _replaceOnce(String source, String find, String to) {
    final at = source.toLowerCase().indexOf(find.toLowerCase());
    if (at < 0) return source;
    return source.replaceRange(at, at + find.length, to);
  }

  static String _replaceAllIn(String source, String find, String to) {
    if (find.isEmpty) return source;
    final lowerFind = find.toLowerCase();
    final buf = StringBuffer();
    var i = 0;
    while (i < source.length) {
      final at = source.toLowerCase().indexOf(lowerFind, i);
      if (at < 0) break;
      buf
        ..write(source.substring(i, at))
        ..write(to);
      i = at + find.length;
    }
    buf.write(source.substring(i));
    return buf.toString();
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
      return Container(
        // Izgaranın zemini BEYAZ: kağıt teması uygulamanın kabuğuna ait,
        // belgenin içine değil (2026-08-07 kullanıcı isteği).
        color: Paper.docSurface(context),
        child: Directionality(
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
      ),
      );
    });
  }

  /// Basılı tut + kaydır = aralık seçimi (Excel'in seçim tutamacının mobil
  /// karşılığı). Hücrelerin kendi uzun basışı YOKTUR — olsaydı jest arenasını
  /// çocuk kazanır, sürükleme hiç başlamazdı.
  Widget _dragSelectArea(Widget child) => Builder(
        builder: (areaContext) => GestureDetector(
          key: _gridAreaKey,
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

  /// Başlık kenarındaki **boyutlandırma tutamağının** dokunma genişliği.
  /// Excel'de fare imleci 3-4 px'lik bir hatta değişir; parmak o hattı
  /// vuramaz. 18 dp Material'in en küçük dokunma hedefinin yarısı ama tutamak
  /// başlığın İÇİNDE, kenara yaslı duruyor — daha genişi başlığa dokunup
  /// sütunu seçmeyi zorlaştırırdı.
  static const double _resizeGrip = 18;

  /// Sütun genişliğini/satır yüksekliğini **sürükleyerek** değiştirir.
  ///
  /// Kullanıcı 2026-08-17: *"sütun genişliği ayarlama çok zor, satır yüksekliği
  /// ayarlama çok zor"*. Eskiden tek yol başlığa uzun basıp açılan kaydırıcılı
  /// diyalogdu: hem keşfedilemiyordu hem de sonucu ancak "Uygula"dan sonra
  /// görülüyordu. Artık Excel'deki gibi kenar sürükleniyor ve genişlik ANINDA
  /// büyüyor. Diyalog kalıyor (uzun basış) — sayısal kesinlik isteyen için.
  ///
  /// [_resizeGrip] genişliğindeki tutamak `Positioned` ile başlığın sağ/alt
  /// kenarına yaslanır; `HitTestBehavior.opaque` sayesinde sürükleme jesti
  /// altındaki "sütunu seç" dokunuşunu yutar.
  Widget _resizeGripFor({int? col, int? row}) {
    final sheet = _sheet;
    if (sheet == null) return const SizedBox.shrink();
    final isCol = col != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Yatay/dikey ayrı tanıyıcı: sütun tutamağı YALNIZ yatay sürüklemeyi
      // üstlenir, dikey kaydırma ızgaraya geçer (ve tersi).
      onHorizontalDragStart: !isCol
          ? null
          : (_) {
              _endEdit();
              _resizeCol = col;
              _resizeStart = sheet.layout.colWidthChars(col);
            },
      onHorizontalDragUpdate: !isCol
          ? null
          : (d) {
              if (_resizeCol == null) return;
              // Piksel → karakter: Excel'in sütun birimi ~7 px'lik "0" genişliği.
              _resizeStart =
                  (_resizeStart + d.delta.dx / (7 * _zoom)).clamp(0.0, 255.0);
              sheet.setColWidthChars(col, _resizeStart);
              _dirty = true;
              _gridVersion++;
              setState(() {});
            },
      onHorizontalDragEnd: !isCol ? null : (_) => setState(() => _resizeCol = null),
      onHorizontalDragCancel: !isCol ? null : () => setState(() => _resizeCol = null),
      onVerticalDragStart: isCol
          ? null
          : (_) {
              _endEdit();
              _resizeRow = row;
              _resizeStart = sheet.layout.rowHeightPt(row!);
            },
      onVerticalDragUpdate: isCol
          ? null
          : (d) {
              if (_resizeRow == null) return;
              // Piksel → punto: 1 pt ≈ 4/3 px.
              _resizeStart =
                  (_resizeStart + d.delta.dy * 0.75 / _zoom).clamp(0.0, 409.0);
              sheet.setRowHeightPt(row!, _resizeStart);
              _dirty = true;
              _gridVersion++;
              setState(() {});
            },
      onVerticalDragEnd: isCol ? null : (_) => setState(() => _resizeRow = null),
      onVerticalDragCancel: isCol ? null : () => setState(() => _resizeRow = null),
      child: Align(
        alignment: isCol ? Alignment.centerRight : Alignment.bottomCenter,
        child: Container(
          width: isCol ? 2 : double.infinity,
          height: isCol ? double.infinity : 2,
          margin: EdgeInsets.only(right: isCol ? 1 : 0, bottom: isCol ? 0 : 1),
          color: (isCol ? _resizeCol == col : _resizeRow == row)
              ? OfficeColors.excel
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _colHeader(XlsxSheet sheet, int c) {
    final scheme = Theme.of(context).colorScheme;
    final active = _inSelection(_selRow, c) ||
        (c >= math.min(_anchorCol, _selCol) &&
            c <= math.max(_anchorCol, _selCol));
    final width = sheet.colWidth(c) * _zoom;
    final height = _headerH * _zoom;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? OfficeColors.excel.withValues(alpha: 0.22)
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                      color: Theme.of(context).dividerColor, width: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(XlsxRange.colName(c),
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11 * _zoom)),
                      ),
                    ),
                    // Otomatik süzgeç oku: dosyada `<autoFilter>` varsa ve bu
                    // sütun aralığındaysa çizilir.
                    if (_filterCoversColumn(sheet, c))
                      GestureDetector(
                        onTap: () => _showColumnFilter(sheet, c),
                        child: Icon(
                          sheet.isColFiltered(c)
                              ? Icons.filter_alt
                              : Icons.arrow_drop_down,
                          size: 12 * _zoom,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Sağ kenardaki sürükleme tutamağı — dar sütunda başlığın yarısından
          // fazlasını kaplamasın (yoksa sütun seçilemez olurdu).
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: math.min(_resizeGrip, math.max(8, width * 0.45)),
            child: _resizeGripFor(col: c),
          ),
        ],
      ),
    );
  }

  /// Bu sütunda süzgeç oku çizilmeli mi (aralık sütunu kapsıyor mu)?
  bool _filterCoversColumn(XlsxSheet sheet, int c) {
    final range = _filterRange(sheet);
    return range != null && c >= range.c1 && c <= range.c2;
  }

  /// Sayfanın otomatik süzgeç aralığı (yoksa null).
  XlsxRange? _filterRange(XlsxSheet sheet) {
    final ref = sheet.layout.autoFilterRef;
    if (ref == null) return null;
    return XlsxRange.parse(ref);
  }

  /// Süzgeç oku menüsü: A→Z / Z→A sırala + değere göre süz.
  Future<void> _showColumnFilter(XlsxSheet sheet, int c) async {
    _endEdit();
    final range = _filterRange(sheet);
    if (range == null) return;
    // Başlık satırı süzgecin ilk satırıdır; veri onun altından başlar.
    final firstData = range.r1 + 1;
    final lastData = math.max(firstData, sheet.maxRows - 1);

    final values = <String>{};
    for (var r = firstData; r <= lastData; r++) {
      values.add(sheet.rawAt(r, c));
    }
    final sorted = values.toList()..sort(_compareCellText);
    final hidden = {...(sheet.filterHidden[c] ?? const <int>{})};
    // Gizli satırların değerleri "işaretsiz" gelmeli.
    final unchecked = <String>{
      for (final r in hidden)
        if (r >= firstData && r <= lastData) sheet.rawAt(r, c),
    };

    if (!mounted) return;
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ColumnFilterSheet(
        title: context.t('excel.filter_column',
            {'col': XlsxRange.colName(c)}),
        values: sorted,
        unchecked: unchecked,
        onSort: (asc) {
          Navigator.pop(ctx);
          _sortByColumn(sheet, c, firstData, lastData, asc);
        },
      ),
    );
    if (result == null || !mounted) return;
    _applyColumnFilter(sheet, c, firstData, lastData, result);
  }

  /// Sayılar sayısal, gerisi metin olarak karşılaştırılır (Excel de böyle
  /// sıralar: "10" metin sıralamasında "9"dan önce gelirdi).
  static int _compareCellText(String a, String b) {
    final na = double.tryParse(a);
    final nb = double.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  /// Seçilmeyen değerlere sahip satırları gizler (geri alınabilir).
  void _applyColumnFilter(XlsxSheet sheet, int c, int firstData, int lastData,
      Set<String> unchecked) {
    final before = {...(sheet.filterHidden[c] ?? const <int>{})};
    final after = <int>{
      for (var r = firstData; r <= lastData; r++)
        if (unchecked.contains(sheet.rawAt(r, c))) r,
    };
    void write(Set<int> rows) {
      // Önce bu sütunun eski gizlemeleri kaldırılır: başka bir sütunun
      // süzgeci ya da kullanıcının elle gizlediği satır ETKİLENMEMELİ.
      for (final r in sheet.filterHidden[c] ?? const <int>{}) {
        final stillHidden = sheet.filterHidden.entries
            .any((e) => e.key != c && e.value.contains(r));
        if (!stillHidden) sheet.layout.hiddenRows.remove(r);
      }
      sheet.filterHidden[c] = {...rows};
      sheet.layout.hiddenRows.addAll(rows);
    }

    write(after);
    _recordStep('excel.undo_filter', () => write(after), () => write(before));
    _dirty = true;
    _gridVersion++;
    setState(() {});
  }

  /// Süzgeç aralığını bu sütuna göre sıralar. Satırlar **bütün olarak**
  /// taşınır (değer + biçim + hücre kaydı), yoksa satırın gerisi yerinde
  /// kalıp veri birbirine karışırdı.
  void _sortByColumn(
      XlsxSheet sheet, int c, int firstData, int lastData, bool ascending) {
    final editor = _editor;
    if (editor == null || lastData <= firstData) return;
    final name = sheet.name;
    final before = [
      for (var r = firstData; r <= lastData; r++) editor.captureRow(name, r),
    ];
    final order = [for (var r = firstData; r <= lastData; r++) r]
      ..sort((a, b) {
        final cmp = _compareCellText(sheet.rawAt(a, c), sheet.rawAt(b, c));
        return ascending ? cmp : -cmp;
      });
    final after = [
      for (final r in order) before[r - firstData],
    ];
    void write(List<SheetLineSnapshot> rows) {
      for (var i = 0; i < rows.length; i++) {
        editor.restoreRow(name, firstData + i, rows[i]);
      }
    }

    write(after);
    _recordStep('excel.undo_sort', () => write(after), () => write(before));
    _dirty = true;
    _gridVersion++;
    setState(() {});
  }

  Widget _rowHeader(XlsxSheet sheet, int r) {
    final scheme = Theme.of(context).colorScheme;
    final active = r >= math.min(_anchorRow, _selRow) &&
        r <= math.max(_anchorRow, _selRow);
    final width = _rowHeaderW * _zoom;
    final height = sheet.rowHeight(r) * _zoom;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? OfficeColors.excel.withValues(alpha: 0.22)
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                      color: Theme.of(context).dividerColor, width: 0.5),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${r + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 11 * _zoom)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: math.min(_resizeGrip, math.max(6, height * 0.45)),
            child: _resizeGripFor(row: r),
          ),
        ],
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
    // Görünen değerler satır başına BİR KEZ çözülür: hem taşma hesabı hem
    // hücre çizimi aynı değeri kullanır (formül hücrelerinde motor iki kez
    // koşmasın).
    final views = <int, XlsxCellView>{
      for (final c in cols)
        c: sheet.viewAt(r, c, ctx.engine.displayValue(r, c)),
    };
    final spill = _spillPlan(ctx, r, cols, views);
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
      out.add(_cell(ctx, r, c, cols, views: views, spill: spill));
    }
    return out;
  }

  /// [cols] bu bölgede çizilen sütunlar — birleşik hücre genişliği YALNIZ bu
  /// bölgedeki sütunları toplar. (Dondurulmuş bölmede A1:C1 birleşmesi tüm
  /// genişliğiyle çizilirse sol bölme taşar; Excel de bölme sınırında keser.)
  Widget _cell(
    _RenderContext ctx,
    int r,
    int c,
    List<int> cols, {
    Map<int, XlsxCellView>? views,
    SheetSpillPlan spill = SheetSpillPlan.empty,
  }) {
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
    // Doldurma tutamağı seçimin SAĞ ALT köşesinde durur (Excel'deki gibi).
    final range = _range;
    final showHandle =
        !_editing && r == range.bottom && c == range.right && !hideContent;

    final spillHere = spill.spillAt(c);
    final cell = SheetCell(
      row: r,
      col: c,
      width: width,
      height: height,
      zoom: _zoom,
      style: sheet.styleAt(r, c),
      view: hideContent
          ? const XlsxCellView('')
          : (views?[c] ?? sheet.viewAt(r, c, ctx.engine.displayValue(r, c))),
      cond: hideContent ? null : ctx.condFor(r, c),
      selected: selected,
      cursor: isCursor,
      editing: isCursor && _editing,
      spillLeft: spillHere.left * _zoom,
      spillRight: spillHere.right * _zoom,
      // Sarkan metnin ALTINDAKİ hücre kendi ızgara çizgisini çizmez: çizerse
      // harflerin ortasından geçen bir kıl çizgi kalırdı (Excel de gizler).
      showGridLines: sheet.showGridLines && !spill.isCovered(c),
      controller: _cellField,
      onTap: () => _select(r, c),
      onSubmitted: () => _commitAndMoveDown(_rowCount(sheet)),
      onEditingComplete: _endEdit,
    );
    // Hücre notu (Excel'in "Açıklama"sı): sağ ÜST köşede küçük kırmızı üçgen,
    // dokununca metni gösterir. Excel'in kendi işareti de budur.
    final note = hideContent ? null : sheet.commentAt(r, c);
    if (!showHandle && note == null) return cell;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: cell),
          if (note != null)
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => _showComment(r, c, note),
                child: CustomPaint(
                  size: Size(6 * _zoom, 6 * _zoom),
                  painter: const _NoteMarkPainter(),
                ),
              ),
            ),
          if (showHandle)
            Positioned(right: 0, bottom: 0, child: _fillHandle()),
        ],
      ),
    );
  }

  /// Excel'in doldurma tutamağı: seçimin sağ alt köşesindeki küçük kare.
  ///
  /// **Neden `RawGestureDetector` + [ImmediateMultiDragGestureRecognizer]:**
  /// tutamak kaydırılabilir ızgaranın İÇİNDE duruyor. Sıradan bir
  /// `GestureDetector` sürüklemeyi kaydırma tanıyıcısıyla arenada paylaşır ve
  /// çoğu zaman kaydırma kazanır — tutamak sürüklenmez, sayfa kayar. Anında
  /// kabul eden tanıyıcı (Flutter'ın kendi sürükle-bırak listelerinde
  /// kullandığı yöntem) pointer'ı hemen üstlenir.
  Widget _fillHandle() {
    final scheme = Theme.of(context).colorScheme;
    return RawGestureDetector(
      key: SpreadsheetEditorScreen.fillHandleKey,
      behavior: HitTestBehavior.opaque,
      gestures: {
        ImmediateMultiDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                ImmediateMultiDragGestureRecognizer>(
          ImmediateMultiDragGestureRecognizer.new,
          (r) => r.onStart = (_) => _FillDrag(
                onMove: _onFillMove,
                onDone: _onFillEnd,
              ),
        ),
        // Çift dokunuş: masaüstü Excel'deki "tutamağa çift tıkla" — komşu
        // sütun nereye kadar doluysa oraya kadar doldurur. Sürükleme
        // tanıyıcısıyla çakışmaz: biri sürüklemeyi, öteki dokunuşu üstlenir.
        DoubleTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
          DoubleTapGestureRecognizer.new,
          (r) => r.onDoubleTap = _fillDownToNeighbour,
        ),
      },
      child: SizedBox(
        // Görünen kare küçük, dokunma alanı parmağa göre büyük.
        width: 22,
        height: 22,
        child: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: scheme.primary,
              border: Border.all(color: scheme.onPrimary, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  /// Hücre notunu gösterir.
  void _showComment(int r, int c, XlsxComment note) {
    _endEdit();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${XlsxRange.colName(c)}${r + 1}'
            '${note.author.isEmpty ? '' : ' · ${note.author}'}'),
        content: SingleChildScrollView(child: Text(note.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.close')),
          ),
        ],
      ),
    );
  }

  /// Tutamağa çift dokunuş: seçimi **komşu sütunun bittiği yere kadar**
  /// aşağı doldurur. Excel'in en çok kullanılan kısayollarından biri — formülü
  /// bin satır sürüklemeye gerek kalmıyor.
  ///
  /// Sınırı komşu sütun belirler: önce SOLDAKİ (Excel'in kuralı), o boşsa
  /// sağdaki. İkisi de boşsa yapacak bir şey yok — nereye kadar dolduracağını
  /// bilemeyiz ve tahmin etmek binlerce boş satır yazmak olurdu.
  void _fillDownToNeighbour() {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final src = _range;
    final lastRow = math.max(0, sheet.maxRows - 1);

    int runEnd(int col) {
      if (col < 0) return src.bottom;
      var r = src.bottom + 1;
      while (r <= lastRow && sheet.rawAt(r, col).isNotEmpty) {
        r++;
      }
      return r - 1;
    }

    var target = runEnd(src.left - 1);
    if (target <= src.bottom) target = runEnd(src.right + 1);
    if (target <= src.bottom) {
      _snack(context.t('excel.fill_no_neighbour'));
      return;
    }
    _applyFill(target, src.right);
  }

  void _onFillMove(Offset global) {
    final ctx = _gridAreaKey.currentContext;
    if (ctx == null) return;
    final pos = _cellAtGlobal(ctx, global);
    if (pos == null) return;
    if (pos.$1 == _fillToRow && pos.$2 == _fillToCol) return;
    setState(() {
      _fillToRow = pos.$1;
      _fillToCol = pos.$2;
    });
  }

  void _onFillEnd({required bool apply}) {
    final row = _fillToRow;
    final col = _fillToCol;
    setState(() {
      _fillToRow = null;
      _fillToCol = null;
    });
    if (apply && row != null && col != null) _applyFill(row, col);
  }
}

/// Doldurma tutamağının sürükleme oturumu (bkz. `_fillHandle`).
class _FillDrag extends Drag {
  final void Function(Offset global) onMove;
  final void Function({required bool apply}) onDone;

  _FillDrag({required this.onMove, required this.onDone});

  @override
  void update(DragUpdateDetails details) => onMove(details.globalPosition);

  @override
  void end(DragEndDetails details) => onDone(apply: true);

  /// İptal (ör. sistem geri hareketi) doldurma YAPMAZ — yarım bir seri
  /// yazmaktansa hiç yazmamak doğru.
  @override
  void cancel() => onDone(apply: false);
}

/// Uygulanmış bir işlemin tersini taşıyan genel geri alma adımı
/// (yapısal işlemler ve biçim değişiklikleri buradan geçer).
class _CallbackStep implements SheetUndoStep {
  @override
  final String label;

  final VoidCallback _apply;
  final VoidCallback _revert;

  _CallbackStep(this.label, this._apply, this._revert);

  @override
  void apply() => _apply();

  @override
  void revert() => _revert();
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

/// Sütun süzgeci sayfası: sırala düğmeleri + değer onay listesi.
///
/// Değer listesi Excel'in süzgeç açılırıyla aynı mantıkta: sütundaki BENZERSİZ
/// değerler, işaretlenmeyenlerin satırları gizlenir. "Tümü" kutusu üç durumlu
/// değil iki durumlu — telefonda üçüncü durumu ayırt etmek zor.
class _ColumnFilterSheet extends StatefulWidget {
  const _ColumnFilterSheet({
    required this.title,
    required this.values,
    required this.unchecked,
    required this.onSort,
  });

  final String title;
  final List<String> values;
  final Set<String> unchecked;
  final void Function(bool ascending) onSort;

  @override
  State<_ColumnFilterSheet> createState() => _ColumnFilterSheetState();
}

class _ColumnFilterSheetState extends State<_ColumnFilterSheet> {
  late final Set<String> _off = {...widget.unchecked};

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(widget.title,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => widget.onSort(true),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: Text(t.t('excel.sort_asc')),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => widget.onSort(false),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: Text(t.t('excel.sort_desc')),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          CheckboxListTile(
            dense: true,
            value: _off.isEmpty,
            title: Text(t.t('excel.filter_all')),
            onChanged: (v) => setState(() {
              _off
                ..clear()
                ..addAll(v == true ? const <String>[] : widget.values);
            }),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.values.length,
              itemBuilder: (_, i) {
                final v = widget.values[i];
                return CheckboxListTile(
                  dense: true,
                  value: !_off.contains(v),
                  title: Text(v.isEmpty ? t.t('excel.filter_blank') : v,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onChanged: (on) => setState(() {
                    on == true ? _off.remove(v) : _off.add(v);
                  }),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, <String>{}),
                  child: Text(t.t('excel.filter_clear')),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _off),
                  child: Text(t.t('common.apply')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hücre notu işareti: sağ üst köşede küçük kırmızı üçgen (Excel'in kendi
/// göstergesi). `CustomPaint` seçildi çünkü bir `Icon` bu boyutta ne okunur
/// ne de Excel'e benzer duruyordu.
class _NoteMarkPainter extends CustomPainter {
  const _NoteMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFB23A2E));
  }

  @override
  bool shouldRepaint(_NoteMarkPainter oldDelegate) => false;
}
