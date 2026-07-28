import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/text_search.dart';
import '../models/document.dart';
import '../services/conversion_service.dart';
import '../services/file_service.dart';
import '../services/fm/entry_opener.dart';
import '../services/ocr_service.dart';
import '../services/pdf_annotator.dart';
import '../services/pdf_edit_flow.dart';
import '../services/pdf_reload.dart';
import '../services/pdf_tools.dart';
import '../services/tts_service.dart';
import '../widgets/ai_rewrite_sheet.dart';
import '../widgets/doc_action_bar.dart';
import '../widgets/office_shell.dart';
import '../widgets/pdf_inline_editor.dart';
import '../widgets/pdf_save_dialog.dart';
import '../widgets/pdf_select_layer.dart';
import '../widgets/translate_flow.dart';
import 'chat_screen.dart';
import 'pdf_ai_edit_screen.dart';
import 'pdf_sign_screen.dart';
import 'pdf_editor_screen.dart';
import 'pdf_tools_screen.dart';

/// PDF vurgu renkleri (0xAARRGGBB) — seçim çubuğundaki sıra. Syncfusion highlight
/// annotation'ı altındaki metni boyamaz (çarpımsal harman), renk okunurluğu bozmaz.
const List<int> _highlightColors = [
  0xFFFFF176, // sarı
  0xFF81C784, // yeşil
  0xFFF06292, // pembe
  0xFF64B5F6, // mavi
];

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

  /// Belgenin sayfa sayısı (`onViewerReady`'de okunur).
  int _pdfCount = 0;

  /// Sayfa sayısının **o anki** değeri: belge elimizdeyse doğrudan ondan
  /// okunur, yoksa son bilinen sayaç. Bir olay ıskalansa bile "sayfaya git"
  /// yanlış sınırla çalışmasın diye.
  int get _pageCount {
    final live = _pdfDoc?.pages.length ?? 0;
    return live > _pdfCount ? live : _pdfCount;
  }

  /// PDF'ten çıkarılan metin (AI sohbetine bağlam olarak gider). pdfium metin
  /// katmanı sayesinde artık PDF içeriği de AI'a verilebiliyor; sayfa üzerinde
  /// seçme/kopyalama "Metin seç" modundaki kendi katmanımızda.
  String _pdfText = '';

  /// Seçim katmanının bildirdiği güncel seçili metin (kopyalama çubuğu için).
  String _pdfSelection = '';

  /// Güncel seçimin PDF-koordinat dikdörtgenleri + sayfası (1-tabanlı) — kalıcı
  /// vurgu annotation'ı bunları Syncfusion'a verir (bkz. PdfSelectLayer.onSelected).
  List<PdfRect> _pdfSelRects = const [];
  int _pdfSelPage = 0;

  /// Seçimden önceki metin — yerinde düzenlemede aynı kelimenin doğru geçişini
  /// bulmak için (bkz. `PdfContentEditor.replaceText`).
  String _pdfSelPreceding = '';

  /// Sayfa üzerinde açık olan yerinde düzenleme kutusu (yoksa null).
  _InlineEdit? _pdfEdit;

  /// Düzenleme kaydediliyor mu (kutunun düğmeleri kilitlensin).
  bool _pdfEditBusy = false;

  /// Yerinde düzenleme kutusunun metni. Kutu sayfanın üzerinde, düğme çubuğu
  /// ekranın altında; ikisi de aynı denetleyiciyi okusun diye burada.
  TextEditingController? _pdfEditCtl;

  /// **Özgün baytların yedeği** — düzenleme sürerken tutulan geçici dosya.
  ///
  /// Kullanıcı isteği (2026-07-26): *"canlı metin düzenlerken her seferinde
  /// kaydet diye sormasın; en sonda kaydetmek istenirse nasıl kaydedileceği
  /// sorulsun ve kopyası kaydedilsin, çıkarken de kaydetmek ister misiniz diye
  /// sorulsun."*
  ///
  /// **Niye dosyanın kendisi düzenleniyor da ayrı bir çalışma kopyası
  /// gösterilmiyor (2026-07-26, 9. tur):** önce düzenlemeler geçici bir
  /// kopyaya yazılıp görüntüleyici O YOLA çevriliyordu. Yol değişimi pdfrx
  /// için belgenin baştan yüklenmesi demek (belgeleri statik bir haritada
  /// YOLA göre tutuyor) ve kullanıcıda "sayfa geçemiyorum, zoom yapamıyorum"
  /// diye biten kararsızlığa yol açtı. Şimdi görüntüleyici DAİMA aynı yolu
  /// gösteriyor; tazeleme, 5. turdan beri sorunsuz çalışan [PdfReload] ile
  /// yapılıyor. Özgün baytlar bu yedekte duruyor ve kullanıcı "üzerine yaz"
  /// demedikçe ekrandan çıkarken geri yazılıyor.
  String? _pdfBackupPath;

  /// Kaydedilmemiş değişiklik var mı?
  bool _pdfDirty = false;

  /// Sayfa döndürme gibi bir PDF işlemi sürüyor mu? (Düğmeleri kilitler —
  /// arka arkaya basılırsa aynı dosya iki kez yazılırdı.)
  bool _pdfBusy = false;

  /// Kullanıcı "üzerine yaz" dedi mi? (Dedi ise yedek geri yüklenmez.)
  bool _pdfKeepEdits = false;

  /// Vurgu rengi (0xAARRGGBB). Seçim çubuğundaki renk sırasından değişir.
  int _highlightColor = _highlightColors.first;

  /// PDF'in kaç sütun hâlinde dizileceği (1 / 2 / 4). Uzun belgelerde sayfaları
  /// yan yana görmek hem gezinmeyi hızlandırır hem tablet/yatay ekranda boşluğu
  /// değerlendirir. 1 = pdfrx'in kendi dikey düzeni.
  int _pdfColumns = 1;

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

  /// PDF gece modu: sayfayı renk matrisiyle TERSLER (beyaz kağıt → siyah).
  /// Salt görsel; dosyaya dokunmaz.
  bool _pdfNight = false;

  /// Sesli okuma. Yalnız kullanıcı başlatınca kurulur (motor uyandırmayalım).
  TtsService? _tts;
  int _ttsIndex = 0;
  int _ttsTotal = 0;
  bool _ttsPlaying = false;

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
    _tts?.dispose(); // ekran kapanınca konuşma sürmesin
    _pdfEditCtl?.dispose();
    _restoreOriginal();
    super.dispose();
  }

  // ── Bekleyen (kaydedilmemiş) PDF düzenlemeleri ────────────────────────────

  /// Yeni belge baytlarını dosyaya yazar ve görüntüyü tazeler.
  ///
  /// İlk yazıştan ÖNCE özgün baytlar bir yedeğe kopyalanır; kullanıcı
  /// "üzerine yaz" demeden çıkarsa ekran kapanırken o yedek geri yazılır.
  /// Görüntüleyicinin gördüğü yol hiç değişmez — tazeleme [PdfReload] ile,
  /// yani kullanıcı sayfasında ve ölçeğinde kalır.
  Future<void> _writePending(List<int> bytes) async {
    if (_pdfBackupPath == null) {
      final dir = await Directory.systemTemp.createTemp('dosya_okuyucu_edit');
      final backup = p.join(dir.path, p.basename(widget.doc.path));
      await File(backup)
          .writeAsBytes(await File(widget.doc.path).readAsBytes(), flush: true);
      _pdfBackupPath = backup;
    }
    await File(widget.doc.path).writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    setState(() {
      _pdfDirty = true;
      _pdfText = '';
    });
    await _reloadPdf();
  }

  /// Yedeği geri yazar (kullanıcı "üzerine yaz" demediyse) ve yedeği siler.
  ///
  /// `dispose` içinden de çağrıldığı için eşzamanlı (sync) dosya işlemi:
  /// ekran kapanırken bekleyecek bir `await` yok.
  void _restoreOriginal() {
    final backup = _pdfBackupPath;
    if (backup == null) return;
    _pdfBackupPath = null;
    try {
      final file = File(backup);
      if (!_pdfKeepEdits && file.existsSync()) {
        File(widget.doc.path).writeAsBytesSync(file.readAsBytesSync(),
            flush: true);
      }
      if (file.existsSync()) file.deleteSync();
      final dir = file.parent;
      if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
    } catch (_) {
      // Yedek geri yazılamadı — dosya kilitli olabilir; kullanıcıya
      // gösterilecek bir şey yok, belge zaten ekranda göründüğü gibi.
    }
  }

  /// Düzenlemeleri atar: özgün baytları geri yazar ve görüntüyü tazeler.
  Future<void> _discardPending() async {
    _restoreOriginal();
    if (!mounted) return;
    setState(() {
      _pdfDirty = false;
      _pdfText = '';
    });
    await _reloadPdf();
  }

  /// Bekleyen değişiklikleri kaydeder (nasıl kaydedileceğini SORARAK).
  /// Kaydedildiyse true, vazgeçildiyse false döner.
  Future<bool> _savePendingPdf() async {
    if (!_pdfDirty) return true;
    final bytes = await File(widget.doc.path).readAsBytes();
    if (!mounted) return false;
    final outcome = await savePdfWithChoice(
      context,
      originalPath: widget.doc.path,
      bytes: bytes,
      note: 'Yaptığınız düzenlemeler bu belgeye işlendi.',
    );
    if (outcome == null) return false;
    // "Üzerine yaz" ise dosya zaten güncel — yedek atılır. Kopya/klasör
    // seçildiyse özgün belge ekrandan çıkarken eski hâline döndürülür.
    if (outcome.overwritten) _pdfKeepEdits = true;
    if (mounted) setState(() => _pdfDirty = false);
    return true;
  }

  /// Ekrandan çıkarken / başka bir PDF aracına geçerken sorulan soru.
  /// Devam edilebilirse true döner.
  Future<bool> _confirmLeavePending() async {
    if (!_pdfDirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydedilmemiş düzenleme var'),
        content: const Text(
          'Belgede yaptığınız değişiklikler henüz kaydedilmedi. '
          'Kaydetmek ister misiniz?\n\n'
          '"Kaydetme" derseniz belge düzenlemeden önceki hâline döner.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text('Kaydetme')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (choice == 'save') return _savePendingPdf();
    if (choice == 'discard') {
      await _discardPending();
      return true;
    }
    return false;
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
            // "Sayfaya git" arama çubuğunun içinde (2026-07-26 kullanıcı
            // isteği): üst çubukta ayrı bir düğme yerine, aramayla aynı
            // "belgede gezinme" kutusunda.
            if (_isPdf)
              IconButton(
                tooltip: 'Sayfaya git',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.numbers),
                onPressed: _askGoToPage,
              ),
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
    // Görselde plainText boştur: metin yoluna sokulursa PDF'e "(Boş belge)"
    // yazılıp resim tamamen kaybolurdu — görsel kendi yolundan gider.
    if (widget.doc.kind == DocKind.image) {
      await _exportImagePdf();
      return;
    }
    final text = _textController?.text ?? widget.doc.plainText;
    final bytes = await _conversion.textToPdf(widget.doc.name, text);
    final path = await _conversion.writeToTemp(
      '${_stem(widget.doc.name)}.pdf',
      bytes,
    );
    await Share.shareXFiles([XFile(path)], text: 'PDF olarak dışa aktarıldı');
  }

  /// Görseli tam çözünürlükte PDF'e gömer; istenirse OCR ile görünmez metin
  /// katmanı ekleyip PDF'i aranabilir yapar.
  Future<void> _exportImagePdf() async {
    final withOcr = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resmi PDF yap'),
        content: const Text(
          'Resim tam çözünürlükte, kırpılmadan PDF\'e gömülecek.\n\n'
          'İçindeki yazılar da PDF içinde aranabilir/kopyalanabilir olsun mu? '
          '(Metin tanıma birkaç saniye sürer, görüntüyü değiştirmez.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Sadece resim'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yazıları da tanı'),
          ),
        ],
      ),
    );
    if (withOcr == null || !mounted) return;

    final progress = ValueNotifier<String>(
        withOcr ? 'Yazılar taranıyor…' : 'PDF hazırlanıyor…');
    _showProgressDialog(progress);

    String? path;
    String? error;
    try {
      final lines = withOcr
          ? await OcrService.recognizeImageLines(widget.doc.path)
          : const <OcrLine>[];
      progress.value = 'PDF hazırlanıyor…';
      final bytes =
          await _conversion.imageToPdf(widget.doc.path, ocrLines: lines);
      path = await _conversion.writeToTemp(
          '${_stem(widget.doc.name)}.pdf', bytes);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // ilerleme penceresi

    if (error != null) {
      _snack('PDF oluşturulamadı: $error');
      return;
    }
    await Share.shareXFiles([XFile(path!)], text: 'PDF olarak dışa aktarıldı');
  }

  void _showProgressDialog(ValueNotifier<String> progress) {
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

  /// Paylaş / yazdır: PDF'te GÖRÜLEN hâli gönderilir — bekleyen düzenlemeler
  /// çalışma kopyasındadır, özgün dosya henüz eski hâlindedir.
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
  ///
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

  /// Belgenin okunabilir metni: PDF'te metin katmanı, görselde OCR sonucu,
  /// diğerlerinde ham içerik. AI bağlamı ve çeviri aynı kaynağı kullanır.
  String get _documentText {
    if (widget.doc.kind == DocKind.pdf && _pdfText.isNotEmpty) return _pdfText;
    if (widget.doc.kind == DocKind.image && _ocrImageText.isNotEmpty) {
      return _ocrImageText;
    }
    return _textController?.text ?? widget.doc.plainText;
  }

  void _openChat() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        fileContext: _documentText,
        fileName: widget.doc.name,
      ),
    ));
  }

  /// Tüm belgeyi cihaz-içi çevirir. Metin katmanı olmayan taranmış PDF'te
  /// önce OCR gerekir (kullanıcı menüden "Metni tanı" ile çalıştırır).
  Future<void> _translateDocument() async {
    final text = _documentText.trim();
    if (text.isEmpty) {
      _snack(widget.doc.kind == DocKind.pdf || widget.doc.kind == DocKind.image
          ? 'Metin bulunamadı. Önce “Metni tanı (OCR)” çalıştırın.'
          : 'Çevrilecek metin yok.');
      return;
    }
    await TranslateFlow.run(context, text, title: widget.doc.name);
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
    // Bekleyen PDF düzenlemesi varken geri tuşu doğrudan çıkmaz: önce
    // "kaydetmek ister misiniz?" sorulur (2026-07-26 kullanıcı isteği).
    return PopScope(
      canPop: !_pdfDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeavePending();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: _buildShell(doc, hasApiKey),
    );
  }

  Widget _buildShell(LoadedDoc doc, bool hasApiKey) {
    return OfficeShell(
      kind: doc.kind,
      title: doc.name,
      dirty: _dirty || _pdfDirty,
      tabBar: _findOpen ? _findBar() : null,
      actions: [
        if (doc.kind == DocKind.pdf) ...[
          PopupMenuButton<int>(
            tooltip: 'Sayfa düzeni',
            icon: Icon(_pdfColumns == 1
                ? Icons.view_agenda_outlined
                : (_pdfColumns == 2
                    ? Icons.view_column_outlined
                    : Icons.grid_view_outlined)),
            onSelected: _setPdfColumns,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1, child: Text('Tek sütun')),
              PopupMenuItem(value: 2, child: Text('2 sütun')),
              PopupMenuItem(value: 4, child: Text('4 sütun')),
            ],
          ),
          IconButton(
            tooltip: 'İçindekiler',
            icon: const Icon(Icons.toc),
            onPressed: _showOutline,
          ),
          // Sayfa döndürme (2026-07-27 kullanıcı isteği). Kayıpsız: sayfanın
          // `/Rotate` girdisi değişir, içerik yeniden çizilmez.
          IconButton(
            tooltip: '90° sola döndür',
            icon: const Icon(Icons.rotate_90_degrees_ccw),
            onPressed: _pdfBusy ? null : () => _rotateCurrentPage(-1),
          ),
          IconButton(
            tooltip: '90° sağa döndür',
            icon: const Icon(Icons.rotate_90_degrees_cw),
            onPressed: _pdfBusy ? null : () => _rotateCurrentPage(1),
          ),
          // Gece/gündüz düğmesi üst çubuktan ÜÇ NOKTAYA taşındı
          // (2026-07-26 kullanıcı isteği) — üst çubuk kalabalıktı.
          if (_pdfDirty)
            IconButton(
              tooltip: 'Düzenlemeleri kaydet',
              icon: const Icon(Icons.save_outlined),
              onPressed: _savePendingPdf,
            ),
        ],
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
              case 'pdftools':
                _openPdfTools();
                break;
              case 'sign':
                _signPdf();
                break;
              case 'aiedit':
                _aiEditPdf();
                break;
              case 'night':
                setState(() => _pdfNight = !_pdfNight);
                break;
              case 'gotopage':
                _askGoToPage();
                break;
              case 'speak':
                _toggleSpeech();
                break;
              case 'translate':
                _translateDocument();
                break;
            }
          },
          itemBuilder: (_) => [
            if (doc.kind == DocKind.pdf) ...[
              // "Sayfaya git" üç yerde birden: burada (etiketli, bulunabilir),
              // arama çubuğunda ve alttaki sayfa rozetine dokununca. Kullanıcı
              // 2026-07-26'da yalnız arama çubuğundakini bulamadığını söyledi
              // ("nerede olduğu anlaşılmıyor, kişiler bulamaz").
              const PopupMenuItem(
                  value: 'gotopage', child: Text('Sayfaya git…')),
              PopupMenuItem(
                value: 'night',
                child: Text(_pdfNight ? 'Gece modunu kapat' : 'Gece modu'),
              ),
              const PopupMenuItem(
                  value: 'aiedit', child: Text('AI ile düzenle')),
              const PopupMenuItem(value: 'sign', child: Text('İmzala')),
              const PopupMenuItem(
                  value: 'pdftools',
                  child: Text('PDF araçları (sayfa, birleştir, parola)')),
            ],
            if (doc.kind == DocKind.pdf || doc.kind == DocKind.image)
              const PopupMenuItem(
                  value: 'ocr', child: Text('Metni tanı (OCR)')),
            if (_ttsTotal == 0)
              const PopupMenuItem(
                  value: 'speak', child: Text('Sesli oku')),
            const PopupMenuItem(
                value: 'translate', child: Text('Belgeyi çevir')),
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
      body: _ttsTotal == 0
          ? _buildBody(doc)
          : Column(
              children: [
                Expanded(child: _buildBody(doc)),
                _speechBar(),
              ],
            ),
      // Etiketli eylem çubuğu — artık her belge türünde (2026-07-28 kullanıcı
      // isteği: "alttaki araç çubuğu güzel, diğer word txt gibi şeylerde de
      // olsun"). Ayrıntı: `widgets/doc_action_bar.dart`.
      bottomBar: _actionBar(doc),
      // Dairesel FAB: geniş etiketli (.extended) hâli belgenin sağ alt köşesini
      // kapatıyordu; etiket tooltip'e taşındı.
      fab: FloatingActionButton(
        onPressed: _openChat,
        tooltip: hasApiKey ? 'AI ile çalış' : 'AI (anahtar gerekli)',
        child: const Icon(Icons.smart_toy_outlined),
      ),
    );
  }

  /// Türüne göre dolan eylem çubuğu; ortak son iki düğme **Paylaş · Yazdır**.
  ///
  /// Etiketli, çünkü kullanıcı ne yapacağını ekrandan okuyabilmeli.
  /// "Yazdır" görselde YOK: `_print` metni PDF'e çevirip basar, görselin metni
  /// olmadığı için boş sayfa çıkardı — orada iş "PDF'e dönüştür".
  Widget _actionBar(LoadedDoc doc) {
    final isImage = doc.kind == DocKind.image;
    return DocActionBar([
      if (doc.kind == DocKind.pdf) ...[
        DocAction(Icons.edit_document, 'Düzenleyici', _openPdfEditor),
        DocAction(Icons.construction, 'Araçlar', _openPdfTools),
      ],
      if (isImage) ...[
        DocAction(Icons.document_scanner_outlined, 'Metni tanı', _runOcr),
        DocAction(Icons.picture_as_pdf_outlined, 'PDF’e dönüştür', _exportPdf),
      ],
      if (doc.isEditableText) ...[
        DocAction(Icons.edit_outlined, 'Düzenle', _textFocus.requestFocus),
        DocAction(Icons.save_outlined, 'Kaydet', _save),
      ],
      DocAction(Icons.share_outlined, 'Paylaş', _share),
      if (!isImage) DocAction(Icons.print_outlined, 'Yazdır', _print),
    ]);
  }

  /// Tek PDF düzenleme ekranı: metin (paragraf), görsel, filigran ve sayfa.
  Future<void> _openPdfEditor() async {
    // Editör ÖZGÜN dosyanın kopyası üzerinde çalışır; bekleyen düzenlemeler
    // önce kaydedilmezse sessizce kaybolurdu.
    if (!await _confirmLeavePending() || !mounted) return;
    final saved = await PdfEditorScreen.open(
      context,
      path: widget.doc.path,
      initialPage: _livePdfPage() ?? _pdfPage,
    );
    if (saved && mounted) {
      setState(() => _pdfText = '');
      await _reloadPdf();
    }
  }

  /// Seçim çubuğu: **Vurgula / Kopyala / Düzenle / Çevir** ve vurgu renkleri.
  /// Yalnız seçim varken görünür.
  Widget _selectionBar() {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                _shorten(_pdfSelection, 28),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              children: [
                for (final argb in _highlightColors) _colorDot(argb),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _highlightPdf,
                  icon: const Icon(Icons.border_color,
                      color: Colors.white, size: 18),
                  label: const Text('Vurgula',
                      style: TextStyle(color: Colors.white)),
                ),
                TextButton.icon(
                  onPressed: _copyPdfSelection,
                  icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                  label: const Text('Kopyala',
                      style: TextStyle(color: Colors.white)),
                ),
                // Yerinde düzenleme: yalnız bu satırlar değişir, sayfa
                // düzeni korunur (tam belge AI düzenlemesinden farkı bu).
                TextButton.icon(
                  onPressed: _startInlineEdit,
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 18),
                  label: const Text('Düzenle',
                      style: TextStyle(color: Colors.white)),
                ),
                TextButton.icon(
                  onPressed: () => TranslateFlow.run(context, _pdfSelection,
                      title: 'Seçili metin'),
                  icon:
                      const Icon(Icons.translate, color: Colors.white, size: 18),
                  label:
                      const Text('Çevir', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Yerinde düzenleme çubuğu: **Vazgeç / AI ile düzelt / Uygula.**
  ///
  /// KÖK NEDEN — niye sayfanın üzerinde değil de ekranın altında
  /// (2026-07-26 kullanıcı bulgusu: *"x, onay, ai işaretlerine tıklanmıyor"*):
  /// `linkHandlerParams` verilince pdfrx TÜM görüntüyü kaplayan translucent bir
  /// `GestureDetector` kurar ve bunu sayfa katmanlarının ÜSTÜNE koyar. Hit-test
  /// yolunda bizden önce geldiği için tap tanıyıcısı arenaya önce girer;
  /// kimse erken kazanmayınca `GestureArenaManager.sweep()` **ilk üyeyi**
  /// seçer → sayfa katmanındaki hiçbir düğme ateşlenmez. (Metin kutusu
  /// çalışıyordu: metin alanı tanıyıcısı arenayı erken kazanır.)
  ///
  /// İlk çözüm "düzenleme açıkken köprüyü kapat" idi; ama bu, düzenleme her
  /// açılıp kapandığında `PdfViewerParams`'ı değiştiriyordu. Çubuk buraya
  /// alınınca köprü hiç kapanmıyor: burası pdfrx'in TAMAMEN dışında, üstteki
  /// Stack'te, dolayısıyla dokunuşu doğal olarak ilk o alıyor. Ek fayda:
  /// çubuk sayfa kenarına taşıp kırpılmıyor ve klavyenin hemen üstünde duruyor.
  Widget _editBar() {
    Widget button(IconData icon, String label, VoidCallback? onPressed) =>
        TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon,
              color: onPressed == null ? Colors.white38 : Colors.white,
              size: 20),
          label: Text(label,
              style: TextStyle(
                  color: onPressed == null ? Colors.white38 : Colors.white)),
        );

    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(Icons.close, 'Vazgeç',
                _pdfEditBusy ? null : _cancelInlineEdit),
            button(Icons.auto_fix_high, 'AI',
                _pdfEditBusy ? null : _rewriteInlineEdit),
            if (_pdfEditBusy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            else
              button(Icons.check, 'Uygula', _submitInlineEdit),
          ],
        ),
      ),
    );
  }

  /// Seçilebilir vurgu rengi noktası; seçili olan beyaz halkalı.
  Widget _colorDot(int argb) {
    final selected = _highlightColor == argb;
    return GestureDetector(
      onTap: () => setState(() => _highlightColor = argb),
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Color(argb),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
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

  /// Seçili metni PDF'e kalıcı highlight annotation olarak yazar (Syncfusion),
  /// dosyayı günceller ve pdfrx'i yeniden yükler (vurgu görünsün). Seçim modu
  /// açık kalır → kullanıcı üst üste vurgulayabilir.
  ///
  /// ponytail: annotate+save ana izlekte. Büyük PDF'te takılırsa xlsx gibi
  /// `compute`'a taşınır (bkz. HAFIZA 2026-07-22 XLSX isolate).
  /// PDF araçları ekranı; kaydedilerek dönülürse dosya değişmiştir → pdfrx
  /// aynı yolu "eşit" saydığı için remount ile yeniden okutulur.
  Future<void> _openPdfTools() async {
    // Bu araçlar ÖZGÜN dosya üzerinde çalışır; bekleyen düzenlemeler önce
    // kaydedilmezse sessizce kaybolurdu.
    if (!await _confirmLeavePending() || !mounted) return;
    final saved = await PdfToolsScreen.open(context, path: widget.doc.path);
    if (saved == true && mounted) {
      setState(() => _pdfText = '');
      await _reloadPdf();
    }
  }

  /// Dosya diskte değiştikten sonra görüntüyü tazeler.
  ///
  /// Eskiden `ValueKey` artırılıp widget yeniden bağlanıyordu; pdfrx belgeleri
  /// statik bir haritada dosya YOLUNA göre önbelleklediği için bu İŞE YARAMIYOR
  /// ve vurgu/imza ekranda hiç görünmüyordu (bkz. [PdfReload]). Şimdi belge
  /// gerçekten yeniden okunuyor ve kullanıcı aynı sayfada kalıyor.
  Future<void> _reloadPdf() async {
    // Eski PdfDocument yeniden yükleme sırasında dispose edilir; elimizdeki
    // referansı hemen bırakıyoruz ki OCR/içindekiler ölü belgeye dokunmasın.
    // Yenisi `onViewerReady` ile geri gelir.
    _pdfDoc = null;
    _pdfSearcher?.resetTextSearch(); // eşleşmeler eski belgeye aitti
    await PdfReload.reloadFile(widget.doc.path);
    if (mounted) setState(() {});
  }

  /// Belgeyi AI'a düzenletir (metin katmanı üzerinden). Üzerine yazıldıysa
  /// görüntü tazelenir.
  Future<void> _aiEditPdf() async {
    if (!await _confirmLeavePending() || !mounted) return;
    final overwritten = await PdfAiEditScreen.open(
      context,
      path: widget.doc.path,
      fileName: widget.doc.name,
      sourceText: _documentText,
    );
    if (overwritten == true && mounted) {
      setState(() => _pdfText = '');
      await _reloadPdf();
    }
  }

  // ── Faz 4: okuma deneyimi ─────────────────────────────────────────────────

  /// PDF içindeki bağlantıya dokunulunca. Dış adresler ONAY İSTER: belgedeki
  /// bağlantı metni gerçek hedefi gizleyebilir, kullanıcı tam URL'yi görmeli.
  Future<void> _onPdfLink(PdfLink link) async {
    final dest = link.dest;
    if (dest != null) {
      await _pdfController.goToDest(dest);
      return;
    }
    final url = link.url;
    if (url == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bağlantıyı aç'),
        content: Text('Bu belge sizi şu adrese götürmek istiyor:\n\n$url\n\n'
            'Tanımadığınız adreslere dikkat edin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aç')),
        ],
      ),
    );
    if (go != true) return;
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) _snack('Bağlantı açılamadı');
    } catch (e) {
      _snack('Bağlantı açılamadı: $e');
    }
  }

  /// Belge ana hattı (içindekiler). PDF'te yoksa kullanıcıya söylenir.
  Future<void> _showOutline() async {
    final doc = _pdfDoc;
    if (doc == null) return;
    final outline = await doc.loadOutline();
    if (!mounted) return;
    if (outline.isEmpty) {
      _snack('Bu belgede içindekiler yok');
      return;
    }
    // ponytail: ağaç yerine girintili düz liste — açılır/kapanır düğüm yönetimi
    // olmadan aynı işi görür; şikayet gelirse ExpansionTile'a geçilir.
    final flat = <(PdfOutlineNode, int)>[];
    void walk(List<PdfOutlineNode> nodes, int depth) {
      for (final n in nodes) {
        flat.add((n, depth));
        walk(n.children, depth + 1);
      }
    }

    walk(outline, 0);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scroll) => ListView.builder(
          controller: scroll,
          itemCount: flat.length,
          itemBuilder: (ctx, i) {
            final (node, depth) = flat[i];
            return ListTile(
              dense: true,
              contentPadding:
                  EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
              title: Text(node.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: node.dest == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _pdfController.goToDest(node.dest);
                    },
            );
          },
        ),
      ),
    );
  }

  /// Sesli okumayı başlatır/duraklatır. Metin belgenin kendi metnidir; taranmış
  /// PDF'te önce "Metni tanı (OCR)" gerekir (metin katmanı yoksa okunacak şey
  /// yok — kullanıcıya söylenir).
  Future<void> _toggleSpeech() async {
    final tts = _tts;
    if (tts != null && _ttsPlaying) {
      await tts.pause();
      return;
    }
    if (tts != null && _ttsTotal > 0) {
      await tts.resume();
      return;
    }
    final text = _documentText;
    if (text.trim().isEmpty) {
      _snack(_isPdf
          ? 'Okunacak metin bulunamadı. Taranmış belgede önce "Metni tanı (OCR)".'
          : 'Okunacak metin yok');
      return;
    }
    final service = TtsService()
      ..onProgress = (i, total, playing) {
        if (!mounted) return;
        setState(() {
          _ttsIndex = i;
          _ttsTotal = total;
          _ttsPlaying = playing;
        });
      };
    setState(() => _tts = service);
    await service.start(text);
  }

  Future<void> _stopSpeech() async {
    await _tts?.stop();
    if (mounted) setState(() => _ttsTotal = 0);
  }

  /// Sesli okuma çubuğu — okuma sürerken belgenin altında durur.
  Widget _speechBar() {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: _ttsPlaying ? 'Duraklat' : 'Devam et',
              icon: Icon(_ttsPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _toggleSpeech,
            ),
            Expanded(
              child: Text('Sesli okuma  ${_ttsIndex + 1} / $_ttsTotal',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            IconButton(
              tooltip: 'Durdur',
              icon: const Icon(Icons.stop),
              onPressed: _stopSpeech,
            ),
          ],
        ),
      ),
    );
  }

  /// İmza ekranı; imza basılırsa dosya değişmiştir → görüntüleyici tazelenir.
  Future<void> _signPdf() async {
    if (!await _confirmLeavePending() || !mounted) return;
    final signed = await PdfSignScreen.open(context, widget.doc.path);
    if (signed == true && mounted) await _reloadPdf();
  }

  /// Seçili metnin **tam üstünde** düzenleme kutusunu açar.
  ///
  /// Ayrı bir ekran açılmıyor: kullanıcı sayfayı görmeye devam ediyor, klavye
  /// geliyor ve yazdığı şey belgenin kendi metni oluyor (bkz. [PdfInlineEditor],
  /// `PdfContentEditor`). Sayfanın geri kalanına dokunulmaz — belgenin tamamını
  /// yeniden yazan "AI ile düzenle"den farkı budur.
  void _startInlineEdit() {
    final rects = _pdfSelRects;
    final page = _pdfSelPage;
    final text = _pdfSelection.trim();
    if (rects.isEmpty || page < 1 || text.isEmpty) return;
    _pdfEditCtl?.dispose();
    setState(() {
      // Metin baştan seçili: kullanıcı doğrudan yazmaya başlayabilir
      // (Word'de bir kelimeye çift tıklamak gibi).
      _pdfEditCtl = TextEditingController(text: text)
        ..selection =
            TextSelection(baseOffset: 0, extentOffset: text.length);
      _pdfEdit = _InlineEdit(
        page: page,
        rects: rects,
        original: text,
        preceding: _pdfSelPreceding,
      );
      _pdfSelection = '';
      _pdfSelRects = const [];
    });
  }

  void _cancelInlineEdit() {
    FocusScope.of(context).unfocus();
    _pdfEditCtl?.dispose();
    setState(() {
      _pdfEdit = null;
      _pdfEditCtl = null;
    });
  }

  /// Alt çubuktaki ✓ (ve klavyenin "bitti" tuşu).
  void _submitInlineEdit() {
    final text = _pdfEditCtl?.text ?? '';
    if (text.trim().isNotEmpty) _applyInlineEdit(text);
  }

  /// Kutudaki metni AI'a yeniden yazdırır.
  Future<void> _rewriteInlineEdit() async {
    final ctl = _pdfEditCtl;
    if (ctl == null) return;
    final result = await showAiRewriteSheet(context, ctl.text);
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => ctl.text = result);
    }
  }

  /// Kutudaki metni belgeye işler.
  ///
  /// **Kaydetmez, sormaz:** sonuç çalışma kopyasına yazılır ve hemen ekranda
  /// görünür. Kullanıcı arka arkaya düzeltme yapabilsin diye
  /// (2026-07-26 isteği); nasıl kaydedileceği çıkarken bir kez sorulur.
  Future<void> _applyInlineEdit(String newText) async {
    final edit = _pdfEdit;
    if (edit == null || _pdfEditBusy) return;
    if (newText.trim() == edit.original.trim()) {
      _cancelInlineEdit();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _pdfEditBusy = true);
    try {
      final applied = await PdfEditFlow.apply(
        context,
        path: widget.doc.path,
        pageIndex: edit.page - 1,
        // PdfRect → düz sayı listesi: servis katmanı pdfrx'i tanımıyor ve bu
        // biçim isolate sınırından sorunsuz geçiyor.
        rawRects: [
          for (final r in edit.rects) [r.left, r.top, r.right, r.bottom],
        ],
        oldText: edit.original,
        newText: newText.trim(),
        precedingText: edit.preceding,
      );
      if (!mounted) return;
      if (applied != null) {
        _pdfEditCtl?.dispose();
        _pdfEditCtl = null;
      }
      setState(() {
        _pdfEditBusy = false;
        if (applied != null) _pdfEdit = null;
      });
      if (applied == null) return;
      await _writePending(applied.bytes);
      if (mounted) _snack(applied.note);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pdfEditBusy = false);
      _snack('Değiştirilemedi: $e');
    }
  }

  /// Açık sayfayı çeyrek tur döndürür ([quarterTurns] −1 sola, +1 sağa).
  ///
  /// Kayıpsız: sayfanın `/Rotate` girdisi değişir, içerik yeniden ÇİZİLMEZ.
  /// Değişiklik bekleyen düzenleme olarak durur; çıkarken bir kez sorulur —
  /// metin düzenleme ve vurgulama ile aynı akış.
  Future<void> _rotateCurrentPage(int quarterTurns) async {
    if (_pdfBusy) return;
    final page = _livePdfPage() ?? _pdfPage;
    if (page < 1) return;
    setState(() => _pdfBusy = true);
    try {
      final bytes = await _fileService.readBytes(widget.doc.path);
      final out = await PdfTools.rotatePagesInBackground(
        bytes,
        pageIndexes: [page - 1],
        quarterTurns: quarterTurns,
      );
      if (!mounted) return;
      await _writePending(out);
      if (mounted) {
        _snack('$page. sayfa ${quarterTurns < 0 ? 'sola' : 'sağa'} döndürüldü');
      }
    } catch (e) {
      if (mounted) _snack('Döndürülemedi: $e');
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _highlightPdf() async {
    final rects = _pdfSelRects;
    final page = _pdfSelPage;
    if (rects.isEmpty || page < 1) return;
    try {
      final bytes = await _fileService.readBytes(widget.doc.path);
      final out = await PdfAnnotator.addHighlight(
        bytes: bytes,
        pageIndex: page - 1,
        pdfRects: rects,
        colorArgb: _highlightColor,
      );
      if (!mounted) return;
      setState(() {
        _pdfSelection = '';
        _pdfSelRects = const [];
      });
      // Vurgu da metin düzenlemesi gibi bekleyen değişikliktir: özgün dosyaya
      // dokunulmaz, çıkarken bir kez kaydedilir.
      await _writePending(out);
      if (mounted) _snack('Vurgulandı');
    } catch (e) {
      if (mounted) _snack('Vurgulama başarısız: $e');
    }
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
    _showProgressDialog(progress);

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

  /// Gece modu açıksa çocuğu renk-tersleyen matrisle sarar.
  ///
  /// Matris: R'=255-R, G'=255-G, B'=255-B (alfa aynı). Beyaz kağıt siyah,
  /// siyah yazı beyaz olur — karanlıkta göz yormaz. `Colors.white` yerine
  /// matris kullanılıyor çünkü sayfadaki resim/grafikler de terslenmeli.
  Widget _nightFilter({required Widget child}) {
    if (!_pdfNight) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -1, 0, 0, 0, 255, //
        0, -1, 0, 0, 255, //
        0, 0, -1, 0, 255, //
        0, 0, 0, 1, 0, //
      ]),
      child: child,
    );
  }

  // ── Uzun belgede gezinme ──────────────────────────────────────────────────

  /// Sayfaları [_pdfColumns] sütun hâlinde dizer.
  ///
  /// Sütun genişliği belgenin EN GENİŞ sayfasına göre sabittir; farklı boydaki
  /// sayfalar sütun içinde ortalanır. Böylece sütunlar sayfa sayfa kaymaz
  /// (kayan sütun okumayı zorlaştırır ve kaydırma çubuğunu yanıltır).
  PdfPageLayout _layoutPdfColumns(List<PdfPage> pages, PdfViewerParams params) {
    final cols = _pdfColumns;
    final margin = params.margin;
    var colWidth = 0.0;
    for (final page in pages) {
      colWidth = math.max(colWidth, page.width);
    }

    final layouts = <Rect>[];
    var y = margin;
    var rowHeight = 0.0;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final col = i % cols;
      final x = margin + col * (colWidth + margin);
      layouts.add(Rect.fromLTWH(
        x + (colWidth - page.width) / 2,
        y,
        page.width,
        page.height,
      ));
      rowHeight = math.max(rowHeight, page.height);
      if (col == cols - 1 || i == pages.length - 1) {
        y += rowHeight + margin;
        rowHeight = 0;
      }
    }
    return PdfPageLayout(
      pageLayouts: layouts,
      documentSize: Size(margin + cols * (colWidth + margin), y),
    );
  }

  /// Sütun sayısını değiştirir.
  ///
  /// Ayrıca bir "relayout" çağrısı GEREKMİYOR: pdfrx 1.3.x düzeni her build'de
  /// `_updateLayout` içinde yeniden hesaplayıp eskisiyle karşılaştırıyor
  /// (paket belgesindeki `PdfViewerController.relayout` 2.x API'si). setState
  /// yeterli.
  void _setPdfColumns(int cols) {
    if (cols == _pdfColumns) return;
    setState(() => _pdfColumns = cols);
  }

  /// "Sayfaya git": numara yaz ya da kaydırıcıyı sürükle.
  ///
  /// KÖK NEDEN (2026-07-26 kullanıcı bulgusu: *"8 yazıyorum 2'ye gidiyor"*):
  /// kutu güncel sayfa numarasıyla dolu açılıyordu ve metin SEÇİLİ gelmiyordu.
  /// Kullanıcı 8'e basınca yazı "28" oluyor, bu da aralık dışında kaldığı için
  /// `onChanged` hedefi güncellemiyor, "Git" ise kutuyu değil eski hedefi
  /// okuyordu → 2. sayfa. Şimdi (a) metin seçili açılıyor, (b) "Git" doğrudan
  /// kutudaki sayıyı okuyup sınırlara kısıyor.
  Future<void> _askGoToPage() async {
    final count = _pageCount;
    if (count <= 0) return;
    var target = _pdfPage.toDouble();
    final controller = TextEditingController(text: '$_pdfPage')
      ..selection = TextSelection(baseOffset: 0, extentOffset: '$_pdfPage'.length);

    int resolve() {
      final typed = int.tryParse(controller.text.trim());
      return (typed ?? target.round()).clamp(1, count);
    }

    final page = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Sayfaya git'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Sayfa numarası (1 – $count)',
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null) {
                    setLocal(() => target = n.clamp(1, count).toDouble());
                  }
                },
                onSubmitted: (_) => Navigator.pop(ctx, resolve()),
              ),
              if (count > 1)
                Slider(
                  value: target.clamp(1, count.toDouble()),
                  min: 1,
                  max: count.toDouble(),
                  divisions: count - 1,
                  label: '${target.round()}',
                  onChanged: (v) => setLocal(() {
                    target = v;
                    controller.text = '${v.round()}';
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, resolve()),
              child: const Text('Git'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (page == null) return;
    await _goToPdfPage(page.clamp(1, count), count);
  }

  /// pdfrx'in o an bildirdiği sayfa (bağlı değilse null).
  int? _livePdfPage() {
    try {
      return _pdfController.isReady ? _pdfController.pageNumber : null;
    } catch (_) {
      return null;
    }
  }

  /// Sayfaya gitmeyi **doğrulayarak** yapar ve sonucu söyler.
  ///
  /// Niye tek `goToPage` yetmiyor (2026-07-26 kullanıcı bulgusu: *"ne yazarsam
  /// yazayım sadece 1 sayfa ilerliyor"*): pdfrx hedefe 200 ms'lik bir
  /// animasyonla gidiyor ve bu sırada gelen her yeniden yerleşim
  /// (`_updateLayout` → düzen değiştiyse `_goToPage(o anki sayfa)`) atlayışı
  /// yarıda kesip bulunulan yere geri çekebiliyor. Sayfa boyutları belge
  /// açıldıktan sonra da yükleniyor, yani bu tam da "aç, hemen sayfaya git"
  /// anında oluyor. Bu yüzden varış NOKTASI ölçülüyor ve tutmazsa yeniden
  /// deneniyor.
  ///
  /// Sonuç her hâlükârda kullanıcıya söyleniyor: başarılıysa nereye gidildiği,
  /// başarısızsa nerede kalındığı. Sessizce yanlış yerde bırakmak, kullanıcının
  /// "çalışmıyor" deyip nedenini bilememesi demekti.
  Future<void> _goToPdfPage(int target, int total) async {
    int? landed;
    for (var attempt = 0; attempt < 3; attempt++) {
      await _pdfController.goToPage(pageNumber: target);
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
      landed = _livePdfPage() ?? _pdfPage;
      if (landed == target) break;
    }
    if (!mounted) return;
    if (landed == target) {
      _snack('$target. sayfa (toplam $total)');
    } else {
      _snack('$target. sayfaya gidilemedi; $landed. sayfada kalındı '
          '(toplam $total).');
    }
  }

  /// Kaydırma çubuğunun topuzu: üstünde güncel sayfa numarası.
  Widget _scrollThumb(int? pageNumber) {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      child: Center(
        child: Text(
          '${pageNumber ?? _pdfPage}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// PDF sayfa numarası rozeti — aynı zamanda "sayfaya git" düğmesi.
  ///
  /// Simge ve "git" yazısı bilerek duruyor: rozet eskiden düz metindi ve
  /// kullanıcı dokunulabilir olduğunu anlamıyordu.
  Widget _pageBadge(String text) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.unfold_more, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBody(LoadedDoc doc) {
    switch (doc.kind) {
      case DocKind.pdf:
        return Stack(
          children: [
            Positioned.fill(
              // pdfrx (pdfium). Metin seçimi: paketin SelectionArea'sı Android'de
              // güvenilir çalışmadığı için sayfa üzerine kendi seçim katmanımız
              // (PdfSelectLayer) biner. Katman DAİMA açıktır ve parmağı ASLA
              // yutmaz: uzun basış seçer, tek parmak kaydırır, iki parmak
              // yakınlaştırır. (Eski "sürükleyerek seç" modu kaldırıldı —
              // açıkken `panEnabled: false` yapıyordu ve kullanıcı sayfayı
              // kaydıramıyor/yakınlaştıramıyordu; bkz. HAFIZA 2026-07-26.)
              //
              // Dosya yolu HİÇ DEĞİŞMEZ (2026-07-26, 9. tur): düzenlemeler
              // dosyanın kendisine yazılıp [PdfReload] ile tazeleniyor. Yolu
              // geçici bir çalışma kopyasına çevirmek pdfrx'e belgeyi baştan
              // yükletiyor ve görüntüleyiciyi kararsızlaştırıyordu ("sayfa
              // geçemiyorum, zoom yapamıyorum"). Özgün baytlar yedekte duruyor.
              //
              // Gece modu: sayfa görüntüsü renk matrisiyle terslenir. Dosyaya
              // dokunmaz, seçim/arama koordinatlarını da etkilemez (yalnız boya).
              child: _nightFilter(
                child: PdfViewer.file(
                doc.path,
                controller: _pdfController,
                initialPageNumber: _pdfPage,
                params: PdfViewerParams(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  // Çok sütunlu dizilim (uzun belge). 1 sütunda pdfrx'in kendi
                  // düzeni kullanılır — gereksiz yere devralmıyoruz.
                  layoutPages: _pdfColumns == 1 ? null : _layoutPdfColumns,
                  // Arama eşleşmelerini sayfada vurgula (Faz 1).
                  pagePaintCallbacks: [
                    if (_pdfSearcher != null)
                      _pdfSearcher!.pageTextMatchPaintCallback,
                  ],
                  // Sağ kenarda sürüklenebilir kaydırma çubuğu: uzun belgede
                  // sayfa sayfa kaydırmak yerine tutup atlanır, üstünde de
                  // güncel sayfa numarası yazar.
                  viewerOverlayBuilder: (context, size, handleLinkTap) => [
                    PdfViewerScrollThumb(
                      controller: _pdfController,
                      orientation: ScrollbarOrientation.right,
                      thumbSize: const Size(44, 40),
                      thumbBuilder: (ctx, thumbSize, pageNumber, controller) =>
                          _scrollThumb(pageNumber),
                    ),
                  ],
                  // Köprüler: iç hedef → o sayfaya git, dış adres → onay + tarayıcı.
                  linkHandlerParams: PdfLinkHandlerParams(
                    onLinkTap: _onPdfLink,
                    linkColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                  ),
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
                  // Yerinde düzenleme açıkken seçim katmanı kurulmaz: kutunun
                  // içindeki dokunuşları yutar, imleç konumlandırılamazdı.
                  pageOverlaysBuilder: (context, pageRect, page) => [
                    if (_pdfEdit != null &&
                        _pdfEdit!.page == page.pageNumber &&
                        _pdfEditCtl != null)
                      PdfInlineEditor(
                        page: page,
                        pageSize: pageRect.size,
                        rects: _pdfEdit!.rects,
                        original: _pdfEdit!.original,
                        controller: _pdfEditCtl!,
                        busy: _pdfEditBusy,
                        onSubmit: _submitInlineEdit,
                      )
                    else if (_pdfEdit == null)
                      PdfSelectLayer(
                        page: page,
                        pageSize: pageRect.size,
                        onSelected: (t, rects, pageNo, preceding) {
                          if (mounted) {
                            setState(() {
                              _pdfSelection = t;
                              _pdfSelRects = rects;
                              _pdfSelPage = pageNo;
                              _pdfSelPreceding = preceding;
                            });
                          }
                        },
                      ),
                  ],
                  ),
                ),
              ),
            ),
            if (_pageCount > 0 && _pdfEdit == null)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: InkWell(
                    onTap: _askGoToPage,
                    borderRadius: BorderRadius.circular(20),
                    child: _pageBadge('$_pdfPage / $_pageCount — sayfaya git'),
                  ),
                ),
              ),
            if (_pdfEdit == null && _pdfSelection.trim().isNotEmpty)
              Positioned(
                bottom: 64,
                left: 8,
                right: 8,
                child: Center(child: _selectionBar()),
              ),
            if (_pdfEdit != null)
              Positioned(
                bottom: 16,
                left: 8,
                right: 8,
                child: Center(child: _editBar()),
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
                  // Gerçekten sistemin varsayılan uygulamasında açar
                  // (eskiden "paylaş" sayfasını açıyordu — kullanıcı dosyayı
                  // açmak isterken paylaşım listesiyle karşılaşıyordu).
                  onPressed: () =>
                      EntryOpener.openExternally(context, widget.doc.path),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Başka uygulamayla aç'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Paylaş'),
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

/// Sayfa üzerinde açık olan yerinde düzenleme kutusunun durumu.
class _InlineEdit {
  /// 1-tabanlı sayfa numarası.
  final int page;

  /// Düzenlenen metnin PDF-koordinat dikdörtgenleri.
  final List<PdfRect> rects;

  final String original;

  /// Seçimden önceki metin — aynı kelimenin doğru geçişini bulmak için.
  final String preceding;

  const _InlineEdit({
    required this.page,
    required this.rects,
    required this.original,
    required this.preceding,
  });
}
