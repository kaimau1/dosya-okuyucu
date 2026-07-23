import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../core/text_search.dart';
import '../models/document.dart';
import '../services/conversion_service.dart';
import '../services/file_service.dart';
import '../services/ocr_service.dart';
import '../widgets/office_shell.dart';
import '../widgets/pdf_select_layer.dart';
import 'chat_screen.dart';

class ViewerScreen extends StatefulWidget {
  final LoadedDoc doc;
  const ViewerScreen({super.key, required this.doc});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _fileService = FileService();
  final _conversion = ConversionService();

  TextEditingController? _textController;
  bool _dirty = false;

  // Görüntüleme durumu (okuma konforu).
  int _pdfPage = 1;
  int _pdfCount = 0;

  /// PDF'ten çıkarılan metin (AI sohbetine bağlam olarak gider). pdfium metin
  /// katmanı sayesinde artık PDF içeriği de AI'a verilebiliyor; sayfa üzerinde
  /// seçme/kopyalama "Metin seç" modundaki kendi katmanımızda.
  String _pdfText = '';

  /// "Metin seç" modu: tek parmak sürükleme sayfayı kaydırmak yerine yazı
  /// seçer (PdfSelectLayer). Kaydırmaya dönmek için mod kapatılır.
  bool _pdfSelectMode = false;

  /// Seçim katmanının bildirdiği güncel seçili metin (kopyalama çubuğu için).
  String _pdfSelection = '';

  /// OCR için açık PDF belgesi (onViewerReady'de gelir).
  PdfDocument? _pdfDoc;

  /// Görselden OCR ile tanınan metin (AI sohbet bağlamı olarak da kullanılır).
  String _ocrImageText = '';
  int _imgQuarterTurns = 0;
  double _fontSize = 15;
  final TransformationController _imgTx = TransformationController();
  TapDownDetails? _doubleTapDetails;

  // Belge içi arama (metin görüntüleyici).
  bool _findOpen = false;
  final _findCtl = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  List<int> _matchStarts = const [];
  int _matchPos = -1;
  int _matchLen = 0;

  /// PDF içi arama (Faz 1): pdfrx'in hazır arayıcısı. Eşleşmeleri sayfa sayfa
  /// bulur, sayfada vurgular (pageTextMatchPaintCallback) ve goToNext/PrevMatch
  /// ile o sayfaya kaydırır. Yalnız PDF belgesinde kurulur.
  final PdfViewerController _pdfController = PdfViewerController();
  PdfTextSearcher? _pdfSearcher;

  bool get _isPdf => widget.doc.kind == DocKind.pdf;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    if (doc.kind == DocKind.text ||
        doc.kind == DocKind.word ||
        doc.kind == DocKind.slides) {
      _textController = TextEditingController(text: doc.plainText);
    }
    if (doc.kind == DocKind.pdf) {
      _pdfSearcher = PdfTextSearcher(_pdfController)..addListener(_onPdfSearch);
    }
  }

  /// Arayıcı eşleşme bulup ilerledikçe sayaç/konum etiketini güncelle.
  void _onPdfSearch() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _textController?.dispose();
    _imgTx.dispose();
    _findCtl.dispose();
    _textFocus.dispose();
    _pdfSearcher?.dispose(); // PdfViewerController = ValueListenable, dispose'suz
    super.dispose();
  }

  // ── Belge içi arama ───────────────────────────────────────────────────────

  void _toggleFind() {
    setState(() {
      _findOpen = !_findOpen;
      if (!_findOpen) {
        _findCtl.clear();
        _matchStarts = const [];
        _matchPos = -1;
        _pdfSearcher?.resetTextSearch();
      }
    });
  }

  void _runFind(String query) {
    final q = query.trim();
    if (_isPdf) {
      // pdfrx arayıcısı: sayfa sayfa bulur, vurgular, ilk eşleşmeye kaydırır.
      if (q.isEmpty) {
        _pdfSearcher?.resetTextSearch();
      } else {
        _pdfSearcher?.startTextSearch(q, caseInsensitive: true);
      }
      return;
    }
    final text = _textController?.text ?? '';
    // Türkçe-duyarlı, büyük/küçük harf duyarsız arama (İ/I/ı/i doğru eşlenir).
    final starts = findAll(text, q);
    setState(() {
      _matchStarts = starts;
      _matchLen = q.length;
      _matchPos = starts.isEmpty ? -1 : 0;
    });
    // Yazarken odağı çalma (arama kutusunda kal); sadece seçimi ayarla.
    if (_matchPos >= 0) _selectMatch(focus: false);
  }

  void _jumpMatch(int delta) {
    if (_isPdf) {
      if (delta > 0) {
        _pdfSearcher?.goToNextMatch();
      } else {
        _pdfSearcher?.goToPrevMatch();
      }
      return;
    }
    if (_matchStarts.isEmpty) return;
    setState(() {
      _matchPos = (_matchPos + delta) % _matchStarts.length;
      if (_matchPos < 0) _matchPos += _matchStarts.length;
    });
    _selectMatch(focus: true); // ileri/geri: belgeye kaydır
  }

  /// Geçerli eşleşmeyi metin alanında seçer; [focus] ise oraya kaydırır.
  void _selectMatch({required bool focus}) {
    final ctl = _textController;
    if (ctl == null || _matchPos < 0 || _matchPos >= _matchStarts.length) return;
    final start = _matchStarts[_matchPos];
    ctl.selection = TextSelection(
      baseOffset: start,
      extentOffset: (start + _matchLen).clamp(0, ctl.text.length),
    );
    if (focus) _textFocus.requestFocus();
  }

  /// Belge içi arama çubuğu (app bar altında).
  PreferredSizeWidget _findBar() {
    final int count;
    final String label;
    if (_isPdf) {
      final s = _pdfSearcher;
      count = s?.matches.length ?? 0;
      if (count > 0) {
        label = '${(s?.currentIndex ?? 0) + 1}/$count';
      } else if (s != null && s.isSearching) {
        label = 'aranıyor…';
      } else {
        label = _findCtl.text.trim().isEmpty ? '' : 'yok';
      }
    } else {
      count = _matchStarts.length;
      label = count == 0
          ? (_findCtl.text.trim().isEmpty ? '' : 'yok')
          : '${_matchPos + 1}/$count';
    }
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _findCtl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _runFind,
                onSubmitted: (_) => _jumpMatch(1),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Belgede ara…',
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            IconButton(
              tooltip: 'Önceki',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: count == 0 ? null : () => _jumpMatch(-1),
            ),
            IconButton(
              tooltip: 'Sonraki',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: count == 0 ? null : () => _jumpMatch(1),
            ),
          ],
        ),
      ),
    );
  }

  void _handleImgDoubleTap() {
    if (_imgTx.value != Matrix4.identity()) {
      _imgTx.value = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      _imgTx.value = Matrix4.identity()
        ..translate(-pos.dx * 2, -pos.dy * 2)
        ..scale(3.0);
    }
  }

  void _changeFont(double delta) {
    setState(() => _fontSize = (_fontSize + delta).clamp(10.0, 32.0));
  }

  /// Görseli düğmeyle yakınlaştırır/uzaklaştırır (pinch ve çift-dokunmaya ek).
  void _zoomImg(double factor) {
    final current = _imgTx.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 6.0);
    if (target == current) return;
    _imgTx.value = _imgTx.value.clone()..scale(target / current);
  }

  Future<void> _save() async {
    final doc = widget.doc;
    final text = _textController?.text ?? '';
    try {
      if (doc.kind == DocKind.text) {
        await _fileService.saveText(doc.path, text);
        _dirty = false;
        _snack('Kaydedildi');
      } else {
        // Word/Slayt: özgün formata güvenli yazım yerine dışa aktarma öner.
        await _exportPdf();
      }
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _exportPdf() async {
    final text = _textController?.text ?? widget.doc.plainText;
    final bytes = await _conversion.textToPdf(widget.doc.name, text);
    final path = await _conversion.writeToTemp(
      '${_stem(widget.doc.name)}.pdf',
      bytes,
    );
    await Share.shareXFiles([XFile(path)], text: 'PDF olarak dışa aktarıldı');
  }

  Future<void> _exportSlides() async {
    final text = _textController?.text ?? widget.doc.plainText;
    final bytes = await _conversion.textToSlidesPdf(widget.doc.name, text);
    final path = await _conversion.writeToTemp(
      '${_stem(widget.doc.name)}-slayt.pdf',
      bytes,
    );
    await Share.shareXFiles([XFile(path)], text: 'Slayt destesi (PDF)');
  }

  Future<void> _share() async {
    await Share.shareXFiles([XFile(widget.doc.path)]);
  }

  Future<void> _print() async {
    if (widget.doc.kind == DocKind.pdf) {
      final bytes = await _fileService.readBytes(widget.doc.path);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      final bytes = await _conversion.textToPdf(
        widget.doc.name,
        _textController?.text ?? widget.doc.plainText,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  }

  /// PDF sayfalarının metnini arka planda çıkarır (AI sohbet bağlamı için).
  /// Taranmış/metinsiz PDF'te sessizce boş kalır — görüntüleme etkilenmez.
  Future<void> _extractPdfText(PdfDocument document) async {
    if (_pdfText.isNotEmpty) return;
    try {
      final sb = StringBuffer();
      for (final page in document.pages) {
        // dynamic: loadText dönüşü sürümler arasında nullable/nonnull değişti;
        // her iki imzayla da derlensin.
        final dynamic t = await page.loadText();
        final full = t == null ? '' : (t.fullText as String? ?? '');
        if (full.trim().isNotEmpty) sb.writeln(full);
        if (sb.length > 100000) break; // AI bağlamı için fazlası gereksiz
      }
      _pdfText = sb.toString().trim();
    } catch (_) {}
  }

  void _openChat() {
    // PDF'te metin katmanı, görselde OCR sonucu AI'ın bağlamı olur.
    var ctxText = widget.doc.plainText;
    if (widget.doc.kind == DocKind.pdf && _pdfText.isNotEmpty) {
      ctxText = _pdfText;
    } else if (widget.doc.kind == DocKind.image && _ocrImageText.isNotEmpty) {
      ctxText = _ocrImageText;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        fileContext: ctxText,
        fileName: widget.doc.name,
      ),
    ));
  }

  bool get _hasText =>
      (_textController?.text.trim().isNotEmpty ?? false) ||
      widget.doc.plainText.trim().isNotEmpty;

  /// Sözcük/karakter/satır/paragraf sayısını gösteren bilgi kutusu.
  void _showStats() {
    final text = _textController?.text ?? widget.doc.plainText;
    final s = TextStats.of(text);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Belge bilgisi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statRow('Sözcük', s.words),
            _statRow('Karakter', s.characters),
            _statRow('Karakter (boşluksuz)', s.charactersNoSpaces),
            _statRow('Satır', s.lines),
            _statRow('Paragraf', s.paragraphs),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            const SizedBox(width: 24),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? name : name.substring(0, dot);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final hasApiKey = context.watch<AppState>().hasApiKey;
    return OfficeShell(
      kind: doc.kind,
      title: doc.name,
      dirty: _dirty,
      tabBar: _findOpen ? _findBar() : null,
      actions: [
        if (doc.kind == DocKind.pdf)
          IconButton(
            tooltip: _pdfSelectMode
                ? 'Seçim modunu kapat (kaydırmaya dön)'
                : 'Metin seç',
            isSelected: _pdfSelectMode,
            icon: Icon(
                _pdfSelectMode ? Icons.pan_tool_alt_outlined : Icons.text_fields),
            onPressed: () => setState(() {
              _pdfSelectMode = !_pdfSelectMode;
              _pdfSelection = '';
            }),
          ),
        if (_textController != null || doc.kind == DocKind.pdf)
          IconButton(
            tooltip: 'Belgede ara',
            icon: Icon(_findOpen ? Icons.search_off : Icons.search),
            onPressed: _toggleFind,
          ),
        if (doc.kind == DocKind.image) ...[
          IconButton(
            tooltip: 'Uzaklaştır',
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _zoomImg(1 / 1.4),
          ),
          IconButton(
            tooltip: 'Yakınlaştır',
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _zoomImg(1.4),
          ),
          IconButton(
            tooltip: 'Döndür',
            icon: const Icon(Icons.rotate_right),
            onPressed: () =>
                setState(() => _imgQuarterTurns = (_imgQuarterTurns + 1) % 4),
          ),
        ],
        if (_textController != null) ...[
          IconButton(
            tooltip: 'Yazıyı küçült',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => _changeFont(-2),
          ),
          IconButton(
            tooltip: 'Yazıyı büyüt',
            icon: const Icon(Icons.text_increase),
            onPressed: () => _changeFont(2),
          ),
        ],
        if (doc.isEditableText)
          IconButton(
            tooltip: 'Kaydet / Dışa aktar',
            icon: const Icon(Icons.save_outlined),
            onPressed: _save,
          ),
        PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'ocr':
                _runOcr();
                break;
              case 'pdf':
                _exportPdf();
                break;
              case 'slides':
                _exportSlides();
                break;
              case 'share':
                _share();
                break;
              case 'print':
                _print();
                break;
              case 'stats':
                _showStats();
                break;
            }
          },
          itemBuilder: (_) => [
            if (doc.kind == DocKind.pdf || doc.kind == DocKind.image)
              const PopupMenuItem(
                  value: 'ocr', child: Text('Metni tanı (OCR)')),
            const PopupMenuItem(value: 'pdf', child: Text('PDF’e dönüştür')),
            const PopupMenuItem(
                value: 'slides', child: Text('Slayta dönüştür')),
            if (_hasText)
              const PopupMenuItem(
                  value: 'stats', child: Text('Sözcük sayısı / bilgi')),
            const PopupMenuItem(value: 'share', child: Text('Paylaş')),
            const PopupMenuItem(value: 'print', child: Text('Yazdır')),
          ],
        ),
      ],
      body: _buildBody(doc),
      fab: FloatingActionButton.extended(
        onPressed: _openChat,
        icon: const Icon(Icons.smart_toy_outlined),
        label: Text(hasApiKey ? 'AI ile çalış' : 'AI (anahtar gerekli)'),
      ),
    );
  }

  /// Seçim modu çubuğu: ipucu ya da Kopyala düğmesi (yarı saydam koyu pill).
  Widget _selectionBar() {
    return Material(
      color: Colors.black.withOpacity(0.75),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: _pdfSelection.trim().isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Parmağınızı yazının üzerinde sürükleyin',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _shorten(_pdfSelection, 24),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: _copyPdfSelection,
                    icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                    label: const Text('Kopyala',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
      ),
    );
  }

  static String _shorten(String s, int max) {
    final t = s.replaceAll('\n', ' ').trim();
    return t.length <= max ? '“$t”' : '“${t.substring(0, max)}…”';
  }

  Future<void> _copyPdfSelection() async {
    final text = _pdfSelection.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Kopyalandı (${text.length} karakter)');
  }

  // ── OCR ───────────────────────────────────────────────────────────────────

  /// Görselde veya (taranmış) PDF'te cihaz-içi OCR koşturur; sonucu seçilebilir
  /// bir sayfada gösterir ve AI sohbet bağlamına işler.
  Future<void> _runOcr() async {
    final doc = widget.doc;
    if (doc.kind == DocKind.pdf && _pdfDoc == null) {
      _snack('PDF henüz yükleniyor, birazdan tekrar deneyin.');
      return;
    }
    final progress = ValueNotifier<String>('Hazırlanıyor…');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator()),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, v, __) => Text(v),
              ),
            ),
          ],
        ),
      ),
    );

    String text = '';
    String? error;
    try {
      if (doc.kind == DocKind.image) {
        progress.value = 'Metin tanınıyor…';
        text = await OcrService.recognizeImageFile(doc.path);
      } else if (doc.kind == DocKind.pdf) {
        text = await OcrService.recognizePdf(
          _pdfDoc!,
          onProgress: (done, total) => progress.value = done >= total
              ? 'Bitiriliyor…'
              : 'Sayfa ${done + 1} / $total taranıyor…',
        );
      }
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // ilerleme penceresi

    if (error != null) {
      _snack('OCR başarısız: $error');
      return;
    }
    if (text.isEmpty) {
      _snack('Metin bulunamadı (OCR).');
      return;
    }
    setState(() {
      if (doc.kind == DocKind.image) _ocrImageText = text;
      // Taranmış PDF'te metin katmanı boştur → OCR sonucu AI bağlamı olur.
      if (doc.kind == DocKind.pdf && _pdfText.isEmpty) _pdfText = text;
    });
    _showOcrSheet(text);
  }

  void _showOcrSheet(String text) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Tanınan metin',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack('Tümü kopyalandı');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Tümünü kopyala'),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.only(top: 12),
                  child: SelectableText(text,
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// PDF sayfa numarası rozeti (yarı saydam koyu pill).
  Widget _pageBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }

  Widget _buildBody(LoadedDoc doc) {
    switch (doc.kind) {
      case DocKind.pdf:
        return Stack(
          children: [
            Positioned.fill(
              // pdfrx (pdfium). Metin seçimi: paketin SelectionArea'sı Android'de
              // güvenilir çalışmadığı için "Metin seç" modunda sayfa üzerine
              // kendi seçim katmanımız (PdfSelectLayer) biner; tek parmak
              // sürükleme o modda kaydırma yerine seçim yapar (panEnabled=false).
              child: PdfViewer.file(
                doc.path,
                controller: _pdfController,
                params: PdfViewerParams(
                  panEnabled: !_pdfSelectMode,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  // Arama eşleşmelerini sayfada vurgula (Faz 1).
                  pagePaintCallbacks: [
                    if (_pdfSearcher != null)
                      _pdfSearcher!.pageTextMatchPaintCallback,
                  ],
                  onViewerReady: (document, controller) {
                    _pdfDoc = document;
                    if (mounted) {
                      setState(() => _pdfCount = document.pages.length);
                    }
                    _extractPdfText(document);
                  },
                  onPageChanged: (page) {
                    if (mounted && page != null) {
                      setState(() => _pdfPage = page);
                    }
                  },
                  pageOverlaysBuilder: !_pdfSelectMode
                      ? null
                      : (context, pageRect, page) => [
                            PdfSelectLayer(
                              page: page,
                              pageSize: pageRect.size,
                              onSelected: (t) {
                                if (mounted) {
                                  setState(() => _pdfSelection = t);
                                }
                              },
                              onCopy: _copyPdfSelection,
                            ),
                          ],
                ),
              ),
            ),
            if (_pdfCount > 0)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(child: _pageBadge('$_pdfPage / $_pdfCount')),
              ),
            if (_pdfSelectMode)
              Positioned(
                bottom: 64,
                left: 0,
                right: 0,
                child: Center(child: _selectionBar()),
              ),
          ],
        );

      case DocKind.image:
        return Container(
          color: Colors.black,
          child: GestureDetector(
            onDoubleTapDown: (d) => _doubleTapDetails = d,
            onDoubleTap: _handleImgDoubleTap,
            child: InteractiveViewer(
              transformationController: _imgTx,
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: RotatedBox(
                  quarterTurns: _imgQuarterTurns,
                  child: Image.file(
                    File(doc.path),
                    errorBuilder: (_, __, ___) => const Text(
                      'Görsel görüntülenemedi.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

      case DocKind.spreadsheet:
        return _SpreadsheetView(table: doc.table ?? const []);

      case DocKind.text:
      case DocKind.word:
      case DocKind.slides:
        return _TextEditor(
          controller: _textController!,
          focusNode: _textFocus,
          editable: doc.isEditableText,
          fontSize: _fontSize,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
        );

      case DocKind.unknown:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(
                  doc.plainText.isNotEmpty
                      ? doc.plainText
                      : 'Bu dosya türü için yerleşik görüntüleyici yok.\n'
                          'Başka bir uygulamayla açabilir veya AI’a sorabilirsiniz.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _share,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Başka uygulamayla aç'),
                ),
              ],
            ),
          ),
        );
    }
  }
}

class _TextEditor extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool editable;
  final double fontSize;
  final VoidCallback onChanged;
  const _TextEditor({
    required this.controller,
    required this.focusNode,
    required this.editable,
    required this.fontSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: !editable,
        onChanged: (_) => onChanged(),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: editable ? 'Belge içeriği…' : null,
          filled: false,
        ),
        style: TextStyle(fontSize: fontSize, height: 1.5),
      ),
    );
  }
}

/// Salt-okunur Excel ızgarası (eski .xls görüntüleme). A/B/C sütun başlıkları,
/// satır numaraları; iki parmakla yakınlaştırılabilir.
class _SpreadsheetView extends StatelessWidget {
  final List<List<String>> table;
  const _SpreadsheetView({required this.table});

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
    if (table.isEmpty) {
      return const Center(child: Text('Tablo boş veya okunamadı.'));
    }
    final scheme = Theme.of(context).colorScheme;
    final divider = Theme.of(context).dividerColor;
    final maxCols =
        table.fold<int>(0, (m, row) => row.length > m ? row.length : m).clamp(1, 64);
    const rowHeaderW = 46.0;
    const colW = 120.0;
    const cellH = 34.0;

    Widget headerCell(String text, double w) => Container(
          width: w,
          height: cellH,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border.all(color: divider, width: 0.5),
          ),
          child: Text(text,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        );

    Widget dataCell(String text, double w) => Container(
          width: w,
          height: cellH,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(border: Border.all(color: divider, width: 0.5)),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        );

    final rows = table.length > 2000 ? table.sublist(0, 2000) : table;

    return InteractiveViewer(
      panEnabled: false,
      minScale: 1,
      maxScale: 5,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: rowHeaderW + maxCols * colW,
          child: Column(
            children: [
              Row(children: [
                headerCell('', rowHeaderW),
                for (var c = 0; c < maxCols; c++)
                  headerCell(_colLabel(c), colW),
              ]),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, r) {
                    final row = rows[r];
                    return Row(children: [
                      headerCell('${r + 1}', rowHeaderW),
                      for (var c = 0; c < maxCols; c++)
                        dataCell(c < row.length ? row[c] : '', colW),
                    ]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
