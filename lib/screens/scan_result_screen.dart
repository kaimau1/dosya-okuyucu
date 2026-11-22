import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_haptics.dart';
import '../core/app_icons.dart';
import '../core/app_state.dart';
import '../core/busy_dialog.dart';
import '../core/l10n/app_strings.dart';
import '../core/motion.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../services/document_scanner.dart';
import '../services/fm/image_resize.dart';
import '../services/gemini_decisions.dart';
import '../widgets/ai_key_gate.dart';
import '../services/fm/activity_log.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/doc_classifier.dart';
import '../services/fm/file_ops.dart';
import '../services/fm/fm_env.dart';
import '../services/fm/fs_events.dart';
import '../services/fm/safe_write.dart';
import '../services/ocr_service.dart';
import '../services/scan_dewarp.dart';
import '../services/scan_enhance.dart';
import '../services/scan_export.dart';
import '../services/scan_actions.dart';
import '../services/scan_quality.dart';
import '../services/fm/job_queue.dart' show FmJobTarget;
import '../services/fm/tracked_task.dart';
import '../services/scan_kind.dart';
import '../services/scan_page_ops.dart';
import '../services/scan_prepare.dart';
import '../services/scan_text_fix.dart';
import '../widgets/motion.dart' show PressScale;
import '../widgets/translate_flow.dart';
import 'fm/browser_screen.dart' show BrowserScreen, browserRoute;
import 'fm/folder_picker_screen.dart';
import 'fm/important_screen.dart';
import 'fm/vault_screen.dart' show addToVault;
import 'scan_edit_screen.dart';
import '../core/user_error.dart';
import '../core/app_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/fm/fm_file_image.dart';
import 'fm/pick_file_screen.dart';
import '../widgets/app_action_sheet.dart';

part 'scan_result/actions.dart';
part 'scan_result/views.dart';
part 'scan_result/widgets.dart';

/// PDF'i [pages]'ten AYNI YOLDA yeniden yazan iş. [ocr] sayfanın KAYNAĞINA
/// göre OCR satırları; eksik olanları tamamlayıp içine yazar.
typedef ScanSaver = Future<void> Function(
    String pdfPath, List<ScanPage> pages, Map<String, List<OcrLine>> ocr);

/// **Tarama stüdyosu** — taranan belgenin kaydedildiği, sayfa sayfa
/// düzenlendiği ve paylaşıldığı tek ekran.
class ScanResultScreen extends StatefulWidget {
  /// Kaydedilmiş PDF'in yolu.
  final String pdfPath;

  /// Sayfalar (kaynak + görünen görsel + filtre).
  final List<ScanPage> pages;

  /// Tanınan metin, sayfa sayfa (eski çağıranlar için; [ocrLines] varsa
  /// metin onlardan kurulur).
  final List<OcrPage> textPages;

  /// OCR satırları (kutularıyla), [pages] ile aynı sırada. PDF yeniden
  /// kurulurken görünmez metin katmanı kaybolmasın diye taşınır.
  final List<List<OcrLine>> ocrLines;

  /// Testler için kaydetme işi (varsayılan: OCR + PDF + `SafeWrite`).
  final ScanSaver? saver;

  const ScanResultScreen({
    super.key,
    required this.pdfPath,
    required this.pages,
    this.textPages = const [],
    this.ocrLines = const [],
    this.saver,
  });

  static Future<void> open(
    BuildContext context, {
    required String pdfPath,
    required List<ScanPage> pages,
    List<OcrPage> textPages = const [],
    List<List<OcrLine>> ocrLines = const [],
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          pdfPath: pdfPath,
          pages: pages,
          textPages: textPages,
          ocrLines: ocrLines,
        ),
      ));

  /// Varsayılan kaydetme: OCR'ı eksik sayfaları tanır, PDF'i kurar, aynı
  /// yola bölünmez yazar ve "değişti" der.
  ///
  /// [ocrSourcePaths] olarak `page.source` geçirilir: sayfa filtrelendiğinde
  /// `page.display` 2480 px'e küçültülmüş olsa bile kaynak boyutundan
  /// `display` boyutuna OCR kutuları orantılı ölçeklenir.
  static Future<void> defaultSaver(
    String pdfPath,
    List<ScanPage> pages,
    Map<String, List<OcrLine>> ocr, {
    bool uniformA4 = true,
    Map<String, ({int width, int height})>? ocrSizes,
  }) async {
    for (final page in pages) {
      if (ocr.containsKey(page.source)) continue;
      final lines = await DocumentScanner.recognizePages([page.source]);
      ocr[page.source] = lines.isEmpty ? const [] : lines.first;
    }
    final bytes = await DocumentScanner.renderPdf(
      ScanPage.displays(pages),
      ocrLinesPerPage: [for (final page in pages) ocr[page.source] ?? const []],
      uniformA4: uniformA4,
      ocrSourceSizes: [
        for (final page in pages) ocrSizes?[page.source],
      ],
      ocrSourcePaths: [for (final page in pages) page.source],
    );
    await SafeWrite.bytes(pdfPath, bytes);
    FsEvents.changed();
  }

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

enum _SaveState { saved, saving, failed }

class _ScanResultScreenState extends State<ScanResultScreen>
    with WidgetsBindingObserver {
  late String _pdfPath = widget.pdfPath;
  late List<ScanPage> _pages = List.of(widget.pages);

  /// OCR satırları sayfanın KAYNAĞINA göre: filtre değişince geometri aynı
  /// kaldığı için satırlar geçerli; kırpma/döndürme yeni kaynak üretir ve o
  /// sayfa yeniden tanınır.
  final Map<String, List<OcrLine>> _ocr = {};

  /// OCR yapıldığı andaki kaynak görsel boyutları (`page.source` → boyut).
  final Map<String, ({int width, int height})> _ocrSizes = {};

  /// Filtre önizlemeleri önbelleği (`page.source` → 6 filtre JPEG baytları).
  final Map<String, Map<ScanFilter, Uint8List>> _previewCache = {};
  final Map<String, Future<Map<ScanFilter, Uint8List>>> _previewLoading = {};

  /// Eğiklik ölçümü önbelleği (`page.source` → derece). Filtre değiştiğinde
  /// geometri değişmediği için eğiklik yeniden ölçülmez.
  final Map<String, double> _skewCache = {};

  /// Geri alma yığını: değişiklikten ÖNCEKİ sayfa listesi.
  final List<List<ScanPage>> _history = [];
  static const _historyLimit = 20;

  var _pager = PageController();
  final ScrollController _thumbScroll = ScrollController();
  final TransformationController _zoomController = TransformationController();
  bool _zoomed = false;
  Offset _doubleTapPos = Offset.zero;

  /// Yerinde canlı filtre şeridi açık mı?
  bool _filterStripOpen = false;
  bool _applyFilterToAll = false;

  /// Filtreli sayfada basılı tutarken özgün görüntüyü gösterme durumu.
  bool _comparingOriginal = false;

  void _resetZoom() {
    if (_zoomController.value != Matrix4.identity()) {
      _zoomController.value = Matrix4.identity();
    }
    if (_zoomed) _zoomed = false;
  }

  /// Sayfa görünümü ızgaradan/Metin sekmesinden geri gelirken denetleyici
  /// SEÇİLİ sayfadan başlamalı.
  void _resetPager() {
    _resetZoom();
    if (_pager.hasClients) return;
    _pager.dispose();
    _pager = PageController(initialPage: _index);
  }

  int _index = 0;
  int _tab = 0;

  /// Toplu inceleme ızgarası açık mı (Faz 35 / madde 2).
  bool _grid = false;

  /// Seçili belge türü (Faz 35 / madde 1): filtre ve PDF sayfa düzeni.
  ScanKind _kind = ScanKind.document;

  /// Kullanıcı açıkça bir belge türü seçti mi? Başlangıçta sayfalar ham
  /// (`ScanFilter.original`) geldiği için `Belge` (`ScanFilter.auto`) henüz
  /// uygulanmamıştır; başlangıç durumunun tutarlı olması için takip edilir.
  bool _kindExplicit = false;

  /// Sayfa kalite ölçümleri (Faz 35 / madde 5), görünen görselin yoluna
  /// göre. Yalnız görünen sayfa, sırayla, izolatta ölçülür.
  final Map<String, ScanQualityReport?> _quality = {};
  bool _measuring = false;
  final Set<String> _qualityDismissed = {};

  /// AI kalite önerisi, görünen görselin yoluna göre ('' = AI sorun görmedi).
  final Map<String, String> _aiQuality = {};

  /// O an sürmekte olan sayfa işi ("Kırpılıyor…"); null = boşta.
  String? _work;

  _SaveState _saveState = _SaveState.saved;
  bool _dirty = false;
  Future<void>? _saving;
  Timer? _saveTimer;
  bool _logged = false;

  ScanSaver get _saver {
    final custom = widget.saver;
    if (custom != null) return custom;
    return (path, pages, ocr) => ScanResultScreen.defaultSaver(
          path,
          pages,
          ocr,
          uniformA4: _kind.uniformA4,
          ocrSizes: _ocrSizes,
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (var i = 0; i < widget.pages.length && i < widget.ocrLines.length; i++) {
      _ocr[widget.pages[i].source] = widget.ocrLines[i];
    }
    if (widget.ocrLines.isEmpty && widget.textPages.isNotEmpty) {
      for (final tp in widget.textPages) {
        final idx = tp.number - 1;
        if (idx >= 0 && idx < widget.pages.length) {
          final lines = tp.text
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .toList();
          _ocr[widget.pages[idx].source] = [
            for (var i = 0; i < lines.length; i++)
              OcrLine(lines[i], Rect.fromLTWH(0, i * 24.0, 400, 20)),
          ];
        }
      }
    }
    // Başlangıçta tüm sayfalar zaten belirli bir filtreyle geldiyse tür
    // durumunu tutarlı başlat.
    if (_pages.isNotEmpty &&
        _pages.every((p) => p.filter == ScanKind.document.defaultFilter)) {
      _kindExplicit = true;
    }
    // **Otomatik sınıflandırma** (2026-10-18): taranan metin bir türe
    // (fatura, kimlik, sözleşme…) güvenle uyuyorsa ilgili klasör önerilir.
    final text = _text.map((page) => page.text).join('\n');
    if (text.trim().isNotEmpty) {
      final guess = classifyDocumentText(text);
      if (guess.isConfident) _classGuess = guess;
    }
    unawaited(_measureVisible());
  }

  /// Görünen sayfanın kalitesini (bir kez) ölçer; eğikliği `page.source`
  /// bazında önbellekler.
  Future<void> _measureVisible() async {
    if (_measuring || _pages.isEmpty) return;
    final page = _pages[_index.clamp(0, _pages.length - 1)];
    final path = page.display;
    final source = page.source;
    if (_quality.containsKey(path) || !await File(path).exists()) return;
    if (!mounted || _measuring) return;
    _measuring = true;
    try {
      final report = await ScanQualityCheck.measure(
        path,
        knownSkew: _skewCache[source],
      );
      if (!mounted) return;
      if (report != null) {
        _skewCache[source] = report.skew;
      }
      setState(() => _quality[path] = report);
    } finally {
      _measuring = false;
    }
    if (mounted) unawaited(_measureVisible());
  }

  /// `page.source` bazında filtre önizlemelerini önbellekten döner veya
  /// izolatta üretip önbellekler.
  Future<Map<ScanFilter, Uint8List>> _ensurePreviews(String source) {
    final cached = _previewCache[source];
    if (cached != null) return Future.value(cached);
    return _previewLoading[source] ??=
        compute(ScanEnhance.previews, ScanPreviewRequest(source)).then((v) {
      _previewLoading.remove(source);
      if (v.isNotEmpty) _previewCache[source] = v;
      if (mounted) setState(() {});
      return v;
    }).catchError((_) {
      _previewLoading.remove(source);
      return const <ScanFilter, Uint8List>{};
    });
  }

  /// Tarama sonrası tür tahmini (yalnız güvenliyse); kullanıcı kapatınca null.
  DocGuess? _classGuess;

  /// Önerilen klasör: `Önemli Dosyalar / <tür klasörü>`.
  String? get _suggestedFolder {
    final guess = _classGuess;
    if (guess == null) return null;
    final target = p.join(
        ImportantScreen.pathIn(FmEnv.primaryRoot), guess.type.folder);
    return p.equals(target, _folder) ? null : target;
  }

  /// **Önerilen eylem** (Faz 35 / ek 6): kimlik → şifreli kasa, fiş/fatura →
  /// gider satırı (Giderler.csv). Kullanıcı kapatınca/uygulayınca gizlenir.
  bool _actionDismissed = false;

  String? get _suggestedAction {
    if (_actionDismissed) return null;
    final type = _classGuess?.type;
    if ((_kindExplicit && _kind == ScanKind.idCard) || type == DocClass.kimlik) {
      return 'vault';
    }
    if ((_kindExplicit && _kind == ScanKind.receipt) ||
        type == DocClass.makbuz ||
        type == DocClass.fatura) {
      return 'expense';
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _pager.dispose();
    _thumbScroll.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  /// Uygulama arka plana giderken bekleyen değişiklik hemen yazılır.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _dirty) unawaited(_save());
  }

  String get _folder => p.dirname(_pdfPath);

  bool get _pending => _dirty || _saving != null;

  bool get _busy => _work != null;

  /// Tanınan metin, sayfa sırasıyla.
  List<OcrPage> get _text {
    final hasLines = _pages.any((page) => _ocr.containsKey(page.source));
    if (!hasLines) return widget.textPages;
    return DocumentScanner.textPages(
        [for (final page in _pages) _ocr[page.source] ?? const []]);
  }

  String _plainText(BuildContext context) => OcrService.joinPages(
      _text, (n) => context.t('tf.page_header', {'n': n}));

  /// Kaynağı değişen sayfaya filtresini yeniden uygular.
  static Future<ScanPage> _withFilter(String source, ScanFilter filter) =>
      ScanPrepare.page(source, filter: filter);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_pending && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: OfficeColors.canvas(context),
        appBar: AppBar(
          backgroundColor: scheme.surface,
          titleSpacing: 0,
          title: _titleBlock(context),
          actions: [
            if (_tab == 0)
              IconButton(
                tooltip: context.t(_grid ? 'sg.single' : 'sg.grid'),
                icon: Icon(_grid ? AppIcons.layoutDetail : AppIcons.layoutGrid),
                onPressed: () => setState(() {
                  _grid = !_grid;
                  if (!_grid) _resetPager();
                }),
              ),
            if (_history.isNotEmpty)
              IconButton(
                tooltip: context.t('common.undo'),
                icon: const Icon(AppIcons.undo),
                onPressed: _busy ? null : _undo,
              ),
            IconButton(
              tooltip: context.t('sx.title'),
              icon: const Icon(AppIcons.exportList),
              onPressed: _busy ? null : _export,
            ),
            PopupMenuButton<String>(
              tooltip: context.t('common.more'),
              enabled: !_busy,
              onSelected: (v) => switch (v) {
                'export' => _export(),
                'open' => _openPdf(),
                'rename' => _rename(),
                'move' => _changeLocation(),
                'ai_quality' => _aiQualityCheck(),
                _ => null,
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.exportList),
                    title: Text(ctx.t('sx.title')),
                  ),
                ),
                PopupMenuItem(
                  value: 'open',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.pdf),
                    title: Text(ctx.t('scr.open_pdf')),
                  ),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.edit),
                    title: Text(ctx.t('scr.rename')),
                  ),
                ),
                PopupMenuItem(
                  value: 'move',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.move),
                    title: Text(ctx.t('scr.change_location')),
                  ),
                ),
                PopupMenuItem(
                  value: 'ai_quality',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.ai),
                    title: Text(ctx.t('sq.ai_check')),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Material(
                  color: scheme.surface,
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: 0,
                            icon: const Icon(AppIcons.newWord, size: 18),
                            label: Text(
                                context.t('ss.pages_tab', {'n': _pages.length})),
                          ),
                          ButtonSegment(
                            value: 1,
                            icon: const Icon(AppIcons.subject, size: 18),
                            label: Text(context.t('scr.tab_text')),
                          ),
                        ],
                        selected: {_tab},
                        onSelectionChanged: (v) => setState(() {
                          _tab = v.first;
                          if (_tab == 0 && !_grid) _resetPager();
                        }),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                if (_tab == 0) _kindPills(context),
                if (_suggestedFolder != null) _classBanner(context),
                if (_suggestedAction != null) _actionBanner(context),
                Expanded(
                    child: _tab == 0
                        ? (_grid ? _gridView(context) : _pagesView(context))
                        : _textView(context)),
                if (_tab == 0 && !_grid && _filterStripOpen)
                  _filterStrip(context),
                if (_tab == 0 && !_grid) _thumbStrip(context),
              ],
            ),
            if (_work != null)
              Positioned.fill(
                child: ColoredBox(
                  color: scheme.surface.withValues(alpha: 0.55),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.lg, vertical: Gap.md),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4)),
                            const SizedBox(width: Gap.md),
                            Flexible(child: Text(_work!)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar:
            _tab == 0 ? _toolBar(context) : _textBar(context),
      ),
    );
  }

  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
