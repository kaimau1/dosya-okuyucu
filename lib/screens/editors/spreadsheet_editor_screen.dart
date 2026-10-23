import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/gestures.dart'
    show Drag, DoubleTapGestureRecognizer, ImmediateMultiDragGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, RenderMetaData;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/app_icons.dart';
import '../../core/excel_format.dart';
import '../../core/doc_fonts.dart';
import '../../core/edit/edit_session.dart';
import '../../core/edit/editor_chrome.dart';
import '../../core/edit/editor_shortcuts.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/sheet_metrics.dart';
import '../../core/sheet_overflow.dart';
import '../../core/sheet_text_measure.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../services/fm/safe_write.dart';
import '../../services/fm/activity_log.dart';
import '../../services/fm/save_to_downloads.dart';
import '../../services/csv_codec.dart';
import '../../services/text_decode.dart';
import '../../services/formula_engine.dart';
import '../../services/formula_help.dart';
import '../../services/sheet_edit.dart';
import '../../services/sheet_input.dart';
import '../../services/xlsx_save_patch.dart' show XlsxStyleEdit;
import '../../services/xlsx_editor.dart';
import '../../widgets/doc_action_bar.dart';
import '../../widgets/doc_find_bar.dart';
import '../../widgets/doc_more_sheet.dart';
import '../../widgets/chart_insert_dialog.dart';
import '../../widgets/office_ribbon.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/pinch_zoom_area.dart';
import '../../widgets/sheet_cell.dart';
import '../../widgets/translate_flow.dart';
import '../../widgets/quick_sheets.dart';
import '../../widgets/download_action.dart';
import '../chat_screen.dart';
import '../../core/snack.dart';
import '../../core/user_error.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_dialog.dart';

part 'spreadsheet/edit_ops.dart';
part 'spreadsheet/file_ops.dart';
part 'spreadsheet/formula_bar.dart';
part 'spreadsheet/formatting.dart';
part 'spreadsheet/ribbon.dart';
part 'spreadsheet/dialogs.dart';
part 'spreadsheet/sheet_tabs.dart';
part 'spreadsheet/find_replace.dart';
part 'spreadsheet/grid.dart';
part 'spreadsheet/headers.dart';
part 'spreadsheet/cells.dart';
part 'spreadsheet/widgets.dart';
part 'spreadsheet/entry.dart';

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

class _SpreadsheetEditorScreenState extends State<SpreadsheetEditorScreen>
    with DraftRecoveryMixin<SpreadsheetEditorScreen> {
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

  /// Faz 26: kalıcı hesap durumu (değer önbelleği + bağımlılık grafiği) ve
  /// hangi model/günlük kuşağına ait olduğu. Bkz. [_engineFor].
  CalcState _calc = CalcState();

  static CalcState _warmUp(Map<String, List<List<String>>> sheets) =>
      CalcState()..warmUp(sheets);
  XlsxEditor? _calcEditor;
  int _calcGen = -1;
  String _calcShape = '';

  /// Hesap değiştikçe artar: durum çubuğu ve koşullu biçim min/max
  /// önbellekleri bununla geçersiz olur.
  int _calcStamp = 0;
  final Map<XlsxCondRule, _CondStats> _condCache = {};
  (Object, String)? _statusMemo;

  /// Faz 20: kirli durum, kaydetme durumu, taslak ve otomatik kaydetme.
  /// Kaynak = kaydetme HEDEFİ (eski .xls açıldıysa yeni .xlsx; o dosya henüz
  /// yoksa yazılabilir sayılmaz → otomatik kaydetme ilk elle kayda kadar
  /// kapalı kalır).
  late final EditSession _session = EditSession(
    sourcePath: widget.savePath ?? widget.path,
    editor: 'excel',
    save: _writeFile,
    snapshot: () async => _editor?.saveAsync(),
  );

  int _selRow = 0;
  int _selCol = 0;

  /// Aralık seçimi (basılı tut + kaydır). Tek hücrede çapa = seçim.
  int _anchorRow = 0;
  int _anchorCol = 0;

  final _cellField = _FormulaFieldController();
  bool _editing = false;

  // ── Faz 25: veri girişi ────────────────────────────────────────────────
  /// Yüzer hücre editörünün odağı (formül çubuğununki [_barFocus]).
  final _cellFocus = FocusNode();

  /// Düzenleme imleç kipinde mi (ikinci dokunuş) — değilse "Giriş" kipi:
  /// metin seçili açılır, yazmak değiştirir, oklar hücre değiştirir.
  bool _caretMode = false;

  /// Uygulama içi sayı/formül tuş takımı açık mı (K20).
  bool _keypad = false;
  final _keypadPanel = FormatPanelController();

  /// ⇥ ile girilmeye başlanan satırın ilk sütunu (Enter oraya döner).
  int? _tabStartCol;

  /// İşaret kipinde son eklenen başvurunun metindeki yeri.
  (int, int)? _pointSpan;

  /// Kenara yaklaşınca büyüyen boş ızgara payı (madde 12).
  int _extraRows = 40;
  int _extraCols = 0;

  final _cursorKey = GlobalKey();
  final _tlKey = GlobalKey();
  final _brKey = GlobalKey();
  final _overlayKey = GlobalKey();
  bool _longPressMoved = false;
  (int, int)? _pointAnchor;

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
    // Panelin ⌨ düğmesi tuş takımını kapatınca durum eşitlensin.
    _keypadPanel.addListener(() {
      if (!_keypadPanel.isOpen && _keypad && mounted) {
        setState(() => _keypad = false);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _session.dispose();
    _cellFocus.dispose();
    _keypadPanel.dispose();
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

  // ── yükleme ───────────────────────────────────────────────────────────────

  /// Dosyayı OKUR ve çözümler — ikisi de arka plan izolatında olsun diye tek
  /// fonksiyon (ana izlekte ne disk G/Ç'si ne de ayrıştırma kalır; büyük
  /// dosyada açılışta donma → ANR bu yüzden yaşanmıştı, bkz. HAFIZA).
  static XlsxEditor _readAndParse(String path) =>
      XlsxEditor.parse(File(path).readAsBytesSync());

  // ── satır/sütun listeleri ─────────────────────────────────────────────────

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

  // ── seçim / düzenleme ─────────────────────────────────────────────────────

  // Faz 25 (2026-10-23): eski "hücre küçükse formül çubuğuna kaç" eşiği
  // (30×72 dp) kalktı — düzenleme hücrenin ÜSTÜNDE büyüyen yüzer editörde
  // (en az 16 sp) açılıyor; bkz. `spreadsheet/entry.dart`.

  // ── geri alınabilir düzenleme ───────────────────────────────────────────

  // ── pano · temizle · otomatik toplam · doldurma ─────────────────────────

  // ── arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    final visibleSheets =
        editor?.sheets.where((s) => !s.layout.hidden).toList() ?? const [];
    return EditExitGuard(
      session: _session,
      hasOpenLayer: _editing || _finding,
      closeLayer: () => _editing ? _endEdit() : _toggleFind(),
      child: EditorShortcuts(
      undo: editor == null || !_undo.canUndo ? null : _undoStep,
      redo: editor == null || !_undo.canRedo ? null : _redoStep,
      save: editor == null ? null : _save,
      find: editor == null ? null : _toggleFind,
      child: OfficeShell(
      kind: DocKind.spreadsheet,
      title: widget.name,
      session: _session,
      subtitle: visibleSheets.length >= 2
          ? context.t('shell.sheets', {'n': visibleSheets.length})
          : null,
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
      body: withDraftBanner(restore: _restoreDraft, EditorChrome(
        editing: _editing,
        accessory: _excelAccessory(),
        panel: _keypadPanel,
        panelTabs: [
          FormatPanelTab(
              label: context.t('excel.keyboard_123'), builder: (_) => _keypadGrid()),
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
                    if (_argumentHint() case final hint?) hint,
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
                ))),
      // Sayfa sekmeleri + etiketli eylem çubuğu (2026-07-28 kullanıcı isteği —
      // PDF'teki gibi). Sekmeler üstte kalır: hangi sayfadasınız bilgisi
      // eylemlerden önce gelir.
      // Yazarken alt çubuk gizli: klavye üstü çubuk + klavye yeri kaplıyor.
      bottomBar: _editing ? null : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (visibleSheets.length >= 2) _sheetTabs(visibleSheets),
          DocActionBar([
            DocAction(AppIcons.save, context.t('common.save'),
                editor == null ? null : _save),
            DocAction(AppIcons.share, context.t('common.share'),
                editor == null ? null : _export),
            // Başka uygulamadan açıldıysa dosya özel önbellekte: doğrudan
            // İndirilenler'e (bkz. [SaveToDownloads]).
            if (showDownloadAction(widget.savePath ?? widget.path))
              DocAction(AppIcons.download, context.t('common.download'),
                  editor == null ? null : _download),
            DocAction(AppIcons.tableView, 'CSV',
                editor == null ? null : _exportCsv),
            DocAction(
              AppIcons.translate,
              context.t('common.translate'),
              // Aralık seçiliyse YALNIZ seçim çevrilir (Faz 9 / Y4), yoksa
              // belgenin tamamı.
              _translate,
            ),
          ]),
        ],
      ),
      // Yazarken AI düğmesi gizli: klavye üstü çubuğun üstüne biniyordu.
      fab: _editing ? null : DocAiButton(
        kind: DocKind.spreadsheet,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            fileContext: widget.plainText,
            fileName: widget.name,
          ),
        )),
        tooltip: context.t('common.ai'),
      ),
    )));
  }

  /// İşlev adında geçebilen karakter: harf, rakam, alt çizgi, Türkçe harfler.
  static bool _isNameChar(int u) =>
      (u >= 65 && u <= 90) ||
      (u >= 97 && u <= 122) ||
      (u >= 48 && u <= 57) ||
      u == 95 ||
      u > 127;

  /// Excel'in standart renk paleti + "yok". Serbest renk seçici bilinçli
  /// olarak yok: telefonda çarkla renk aramak yavaş, Excel mobil de sabit
  /// paletle çalışıyor.
  static const _palette = <int>[
    0xFFFFFFFF, 0xFF000000, 0xFF808080, 0xFFD9D9D9,
    0xFFC00000, 0xFFFF0000, 0xFFFFC000, 0xFFFFFF00,
    0xFF92D050, 0xFF00B050, 0xFF00B0F0, 0xFF0070C0,
    0xFF002060, 0xFF7030A0, 0xFFFCE4D6, 0xFFDDEBF7,
  ];

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

  /// Word/slayt ile ORTAK liste — kullanıcı bir uygulamada bulduğu yazı
  /// tipini diğerinde de bulsun (`kDocFonts`).
  static final _fontFamilies = kDocFonts.map((f) => f.name).toList();

  static const _fontSizes = kDocFontSizes;

  static int _argbOf(Color c) =>
      ((c.a * 255).round() << 24) |
      ((c.r * 255).round() << 16) |
      ((c.g * 255).round() << 8) |
      (c.b * 255).round();

  // ── bul ───────────────────────────────────────────────────────────────────



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

  // ── ızgara ────────────────────────────────────────────────────────────────

  /// Sabit (donmuş) bölgeye ayrılabilecek en büyük ölçü. Kaydırılan bölgeye
  /// DAİMA yer bırakır — yoksa `Expanded` sıfır ölçü alır ve dosyanın sağ/alt
  /// tarafı hiç görünmez (kullanıcının bildirdiği hata).
  static double _paneBudget(double viewport, double headerSize) {
    final body = math.max(72.0, math.min(viewport * 0.45, 280.0));
    return math.max(0.0, viewport - headerSize - body);
  }

  /// Başlık kenarındaki **boyutlandırma tutamağının** dokunma genişliği.
  /// Excel'de fare imleci 3-4 px'lik bir hatta değişir; parmak o hattı
  /// vuramaz. 18 dp Material'in en küçük dokunma hedefinin yarısı ama tutamak
  /// başlığın İÇİNDE, kenara yaslı duruyor — daha genişi başlığa dokunup
  /// sütunu seçmeyi zorlaştırırdı.
  static const double _resizeGrip = 18;

  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}