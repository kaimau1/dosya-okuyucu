import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, LogicalKeyboardKey;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/doc_fonts.dart';
import '../core/image_budget.dart';
import '../core/l10n/app_strings.dart';
import '../core/app_state.dart';
import '../core/copy_text.dart';
import '../core/text_search.dart';
import '../core/theme.dart';
import '../models/document.dart';
import '../models/fs_entry.dart';
import '../services/conversion_service.dart';
import '../services/doc_translate.dart';
import '../services/file_service.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/reading_positions.dart';
import '../services/ocr_service.dart';
import '../services/pdf/edge_auto_scroll.dart';
import '../services/pdf/page_arrival.dart';
import '../services/pdf/pdf_form.dart';
import '../services/pdf/pdf_ocr_search.dart';
import '../services/pdf_annotator.dart';
import '../services/pdf_edit_flow.dart';
import '../services/pdf_reload.dart';
import '../services/pdf_tools.dart';
import '../services/tts_service.dart';
import '../widgets/office_ribbon.dart' show OfficeIcons;
import '../widgets/ai_rewrite_sheet.dart';
import '../widgets/ai_slides_flow.dart';
import '../widgets/doc_action_bar.dart';
import '../widgets/office_shell.dart';
import 'fm/entry_actions.dart';
import '../widgets/pdf_action_bars.dart';
import '../widgets/pdf_inline_editor.dart';
import '../widgets/pdf_save_dialog.dart';
import '../widgets/pdf_select_layer.dart';
import '../widgets/translate_flow.dart';
import '../widgets/tts_voice_sheet.dart';
import 'chat_screen.dart';
import 'pdf_ai_edit_screen.dart';
import 'reader_screen.dart';
import 'pdf_form_screen.dart';
import 'pdf_sign_screen.dart';
import 'pdf_editor_screen.dart';
import 'pdf_tools_screen.dart';
import '../core/snack.dart';

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

  /// Seçim taranmış sayfadan OCR ile mi geldi? OCR metni sayfada GERÇEKTEN
  /// yazılı değildir: kopyalama/vurgu/çeviri çalışır ama yerinde düzenleme
  /// çalışamaz (değiştirilecek içerik akışı yok) — Düzenle düğmesi gizlenir.
  bool _pdfSelFromOcr = false;

  /// Sürükleyerek seçim ŞU AN sürüyor mu? (Uzun basış sonrası parmak yerde ya
  /// da fare metin üzerinde basılı.) True iken pdfrx'in pan'ı kilitlenir ki
  /// sürükleme sayfayı kaydırmasın; işaretçi kalkar kalkmaz katman false
  /// bildirir ve kilit açılır. Eski "seçim modu açıkken pan hep kapalı"
  /// hatasından farkı bu anlıklık (bkz. HAFIZA 2026-07-26 ve 2026-08-05).
  bool _pdfSelecting = false;

  /// Kenar oto-kaydırması: seçim sürüklenirken işaretçinin son EKRAN konumu
  /// (katman bildirir; null = sürükleme yok) ve 60 Hz itme zamanlayıcısı.
  /// Parmak ekran kenarına dayanınca sayfa o yöne akar, seçim büyümeye devam
  /// eder — Chrome'un seçim oto-kaydırması. Matris `PdfViewerController.value`
  /// üzerinden itilir; ayarlayıcı `makeMatrixInSafeRange`ten geçtiği için
  /// belge sınırının dışına ASLA çıkılamaz (pdfrx 1.3.5 kaynağından
  /// doğrulandı) — kilitli pan'dan bağımsız çalışır (programatik).
  Offset? _pdfSelDragPos;
  Timer? _pdfEdgeScrollTimer;

  /// Sayfa üzerinde açık olan yerinde düzenleme kutusu (yoksa null).
  _InlineEdit? _pdfEdit;

  /// Düzenleme kaydediliyor mu (kutunun düğmeleri kilitlensin).
  bool _pdfEditBusy = false;

  /// Yerinde düzenleme kutusunun metni. Kutu sayfanın üzerinde, düğme çubuğu
  /// ekranın altında; ikisi de aynı denetleyiciyi okusun diye burada.
  TextEditingController? _pdfEditCtl;

  /// Yerinde düzenleme kutusunun **kalıcı** odak düğümü.
  ///
  /// Kullanıcı hatası (2026-08-29): *"pdf'de düzenle deyince klavye
  /// açılmıyor."* Kök neden: kutu pdfrx'in SAYFA KATMANI üzerinde çiziliyor
  /// ve o katman kaydırma/yakınlaştırma/sayfa yeniden çiziminde yeniden
  /// kuruluyor. `autofocus` yalnız widget'ın İLK kurulumunda çalışır; katman
  /// hemen ardından yeniden kurulunca odak düşüyor ve klavye ya hiç
  /// açılmıyor ya da açılıp kapanıyordu.
  ///
  /// Odak düğümü artık burada — yani yeniden kurulan ağacın DIŞINDA — ve
  /// düzenleme açılırken ilk kareden sonra açıkça isteniyor. Aynı düğüm
  /// hangi `TextField` çizilirse ona bağlanıyor, klavye ayakta kalıyor.
  FocusNode? _pdfEditFocus;

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

  /// Okuma yazı tipi. `null` = temanın gövde yazı tipi (Arimo).
  String? _fontFamily;

  /// Seçilebilir yazı tipleri: (görünen ad, çizilen aile). Boş aile =
  /// temanın kendi gövde yazı tipi.
  ///
  /// Adlar tanıdık ofis adları (`kDocFonts`), çizim ise APK'da GÖMÜLÜ
  /// karşılıklarıyla yapılır — indirilecek font yok, boyut artmıyor. Eskiden
  /// listede gömülü ailelerin kendi adları vardı ("Arimo", "Tinos") ve
  /// kullanıcı aradığı yazı tipini bulamıyordu (2026-08-07).
  static final _readerFonts = <(String, String)>[
    ('Varsayılan', ''),
    for (final f in kDocFonts) (f.name, f.render),
  ];
  final TransformationController _imgTx = TransformationController();
  TapDownDetails? _doubleTapDetails;

  /// Görselin kaç piksel genişlikte çözüleceği (bellek/pil koruması —
  /// bkz. `core/image_budget.dart`). Yakınlaştırma kademe atlayınca artar.
  int _imgDecodeWidth = ImageBudget.minWidth;

  /// Yakınlaştırma değişince çözme genişliğini kademeye göre günceller.
  void _onImgTransform() {
    if (!mounted) return;
    final media = MediaQuery.maybeOf(context);
    if (media == null) return;
    final want = ImageBudget.forViewport(
      logicalWidth: media.size.width,
      devicePixelRatio: media.devicePixelRatio,
      scale: _imgTx.value.getMaxScaleOnAxis(),
    );
    if (want == _imgDecodeWidth) return;
    setState(() => _imgDecodeWidth = want);
  }

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

  /// Taranmış sayfalarda arama (Faz 2, 2026-08-05): pdfrx arayıcısı yalnız
  /// pdfium metin katmanını görür; metin katmanı olmayan sayfalar
  /// [PdfOcrSearch] ile OCR üzerinden aranır. İki kaynak [_findEntries]'te
  /// sayfa sırasına göre birleşir, ileri/geri tek listede gezer.
  PdfOcrSearch? _ocrSearch;

  /// Birleşik arama imleci: pdfrx (ocr:false) ya da OCR (ocr:true) eşleşmesi.
  /// Konum SAYI olarak tutulmaz — OCR eşleşmeleri damla damla geldikçe liste
  /// büyür, sayı kayardı; kayıt yapısal eşitlikle taze listede yeniden bulunur.
  ({bool ocr, int index, int page})? _findEntry;

  /// pdfrx + OCR eşleşmeleri, sayfa sırasında.
  List<({bool ocr, int index, int page})> get _findEntries {
    final s = _pdfSearcher;
    final o = _ocrSearch;
    final out = <({bool ocr, int index, int page})>[];
    if (s != null) {
      for (var i = 0; i < s.matches.length; i++) {
        out.add((ocr: false, index: i, page: s.matches[i].pageNumber));
      }
    }
    if (o != null) {
      for (var i = 0; i < o.matches.length; i++) {
        out.add((ocr: true, index: i, page: o.matches[i].pageNumber));
      }
    }
    out.sort((a, b) {
      final byPage = a.page.compareTo(b.page);
      if (byPage != 0) return byPage;
      if (a.ocr != b.ocr) return a.ocr ? 1 : -1;
      return a.index.compareTo(b.index);
    });
    return out;
  }

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
      _ocrSearch = PdfOcrSearch()..addListener(_onPdfSearch);
      unawaited(_offerFormFilling());
      unawaited(_restoreReadingPage());
    }
    if (doc.kind == DocKind.image) _imgTx.addListener(_onImgTransform);
  }

  /// **Kaldığın sayfadan devam** (2026-09-04).
  ///
  /// 400 sayfalık bir kitap her açılışta 1. sayfadan başlıyordu; kullanıcı
  /// kaldığı yeri her seferinde elle arıyordu. Kayıt `ReadingPositions`ta;
  /// kural orada (ilk/son sayfa ve kısa belgeler kaydedilmez).
  ///
  /// Sayfa `initialPageNumber` ile veriliyor: görüntüleyici kurulmadan ÖNCE
  /// bilinmesi gerekiyor, sonradan atlamak kullanıcıya bir sıçrama gösterirdi.
  Future<void> _restoreReadingPage() async {
    if (!context.mounted) return;
    if (!context.read<AppState>().resumePosition) return;
    await ReadingPositions.ensureLoaded();
    final page = ReadingPositions.pageOf(widget.doc.path);
    if (!mounted || page == null || page <= 1) return;
    setState(() {
      _pdfPage = page;
      _resumedPage = page;
    });
  }

  /// Devam edilen sayfa (bir kez şerit gösterilir), yoksa null.
  int? _resumedPage;

  /// "42. sayfadan devam ediliyor · Baştan başla" şeridi.
  ///
  /// Sessizce ortadan açmak "belge bozuk mu?" dedirtiyor; bir cümle + tek
  /// dokunuşluk geri dönüş yolu bırakılıyor.
  void _showResumeNotice() {
    final page = _resumedPage;
    if (page == null || !mounted) return;
    _resumedPage = null;
    showSnack(
      context,
      context.t('vw.resumed_page', {'n': '$page'}),
      action: SnackBarAction(
        label: context.t('vw.restart_doc'),
        onPressed: () {
          ReadingPositions.clear(widget.doc.path);
          _pdfController.goToPage(pageNumber: 1);
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ekran ölçüsü ilk kez burada bilinir; çözme genişliği ona göre kurulur.
    if (widget.doc.kind == DocKind.image) _onImgTransform();
  }

  /// Belge doldurulabilir bir formsa kullanıcıya **söylenir**.
  ///
  /// Menüdeki "Formu doldur" tek başına keşfedilmiyor: kullanıcı bir form
  /// PDF'ini açtığında yapabileceği ilk şey onu doldurmaktır ve bunu ⋮
  /// menüsünde aramaz. Bakış ucuz (dosyada `/AcroForm` anahtarı aranır),
  /// yanlış pozitifte ekran zaten "form alanı yok" diyor.
  Future<void> _offerFormFilling() async {
    if (!await PdfFormFiller.looksLikeForm(widget.doc.path)) return;
    if (!mounted) return;
    showSnackBarReplacing(ScaffoldMessenger.of(context), SnackBar(
      content: Text(context.t('vw.form_detected')),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: context.t('vw.fill_form'),
        onPressed: _fillPdfForm,
      ),
    ));
  }

  /// Arayıcılar (pdfrx + OCR) eşleşme bulup ilerledikçe sayaç/konum etiketini
  /// güncelle. pdfrx ilk eşleşmeye KENDİLİĞİNDEN atlar; birleşik konum imleci
  /// boşsa o eşleşmeye oturtulur ki etiket "1/n" desin ve ileri/geri oradan
  /// devam etsin.
  void _onPdfSearch() {
    if (!mounted) return;
    setState(() {
      final s = _pdfSearcher;
      if (_findEntry == null &&
          s != null &&
          s.currentIndex != null &&
          s.matches.isNotEmpty) {
        _findEntry = (ocr: false, index: s.currentIndex!,
            page: s.matches[s.currentIndex!].pageNumber);
      }
    });
  }

  @override
  void dispose() {
    // Bekleyen okuma konumu diske yazılsın: uygulama kapansa da "kaldığın
    // sayfa" çalışsın (kayıt üç saniyelik gecikmeyle yazılıyor).
    unawaited(ReadingPositions.save());
    _pdfEdgeScrollTimer?.cancel();
    _textController?.dispose();
    _imgTx.removeListener(_onImgTransform);
    _imgTx.dispose();
    _findCtl.dispose();
    _textFocus.dispose();
    _pdfSearcher?.dispose(); // PdfViewerController = ValueListenable, dispose'suz
    _ocrSearch?.dispose();
    _tts?.dispose(); // ekran kapanınca konuşma sürmesin
    _pdfEditCtl?.dispose();
    _pdfEditFocus?.dispose();
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
      note: context.t('vw.edits_applied'),
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
        title: Text(context.t('vw.unsaved_title')),
        content: Text(context.t('vw.unsaved_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(context.t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: Text(context.t('vw.dont_save'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(context.t('common.save'))),
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
        _ocrSearch?.reset();
        _findEntry = null;
      }
    });
  }

  void _runFind(String query) {
    final q = query.trim();
    if (_isPdf) {
      _findEntry = null;
      // pdfrx arayıcısı: sayfa sayfa bulur, vurgular, ilk eşleşmeye kaydırır.
      if (q.isEmpty) {
        _pdfSearcher?.resetTextSearch();
        _ocrSearch?.reset();
      } else {
        // Paketin `caseInsensitive`i yerel-duyarsız (İ/ı kaçıyordu); harf
        // biçimlerini kendimiz kapsayıp eşleştirmeyi duyarlı koşturuyoruz.
        _pdfSearcher?.startTextSearch(turkishSearchPattern(q),
            caseInsensitive: false);
        // Taranmış sayfalar: aynı desen OCR metninde aranır. Kullanıcının
        // baktığı sayfadan başlar — ilk sonuçlar gözün önünden gelir.
        final doc = _pdfDoc;
        if (doc != null) {
          _ocrSearch?.start(doc, turkishSearchPattern(q), fromPage: _pdfPage);
        }
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
      final entries = _findEntries;
      if (entries.isEmpty) return;
      var i = _findEntry == null ? -1 : entries.indexOf(_findEntry!);
      if (i == -1) {
        i = delta > 0 ? 0 : entries.length - 1;
      } else {
        i = (i + delta) % entries.length;
        if (i < 0) i += entries.length;
      }
      final e = entries[i];
      setState(() => _findEntry = e);
      if (e.ocr) {
        final o = _ocrSearch!;
        o.currentIndex = e.index; // vurgu turuncuya döner
        final m = o.matches[e.index];
        _pdfController.goToRectInsidePage(
            pageNumber: m.pageNumber, rect: m.bounds);
      } else {
        _ocrSearch?.currentIndex = -1;
        _pdfSearcher?.goToMatchOfIndex(e.index);
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

  /// Taranmış sayfa arama eşleşmelerini boyar. Renkler pdfrx'in
  /// varsayılanlarıyla birebir (sarı/turuncu, %50 saydam) — kullanıcı hangi
  /// eşleşmenin hangi motordan geldiğini AYIRT EDEMEMELİ.
  void _paintOcrSearchMatches(Canvas canvas, Rect pageRect, PdfPage page) {
    final o = _ocrSearch;
    if (o == null || o.matches.isEmpty) return;
    final normal = Paint()..color = Colors.yellow.withAlpha(127);
    final active = Paint()..color = Colors.orange.withAlpha(127);
    for (var i = 0; i < o.matches.length; i++) {
      final m = o.matches[i];
      if (m.pageNumber != page.pageNumber) continue;
      final paint = i == o.currentIndex ? active : normal;
      for (final r in m.rects) {
        canvas.drawRect(
          r
              .toRect(page: page, scaledPageSize: pageRect.size)
              .translate(pageRect.left, pageRect.top),
          paint,
        );
      }
    }
  }

  /// Belge içi arama çubuğu (app bar altında).
  PreferredSizeWidget _findBar() {
    final int count;
    final String label;
    if (_isPdf) {
      // Birleşik sayaç: metin katmanı + OCR (taranmış sayfa) eşleşmeleri.
      final entries = _findEntries;
      final busy = (_pdfSearcher?.isSearching ?? false) ||
          (_ocrSearch?.isSearching ?? false);
      count = entries.length;
      if (count > 0) {
        final pos =
            _findEntry == null ? -1 : entries.indexOf(_findEntry!);
        final head = pos >= 0 ? '${pos + 1}/$count' : '$count';
        // OCR hâlâ sayfa tarıyorsa üç nokta: sayı büyümeye devam edebilir.
        label = busy ? '$head…' : head;
      } else if (busy) {
        label = context.t('vw.searching');
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
                tooltip: context.t('vw.goto_page_short'),
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
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.t('vw.find_in_doc'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            IconButton(
              tooltip: context.t('common.previous'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: count == 0 ? null : () => _jumpMatch(-1),
            ),
            IconButton(
              tooltip: context.t('common.next'),
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
    // Etiketler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    try {
      if (doc.kind == DocKind.text) {
        await _fileService.saveText(doc.path, text);
        _dirty = false;
        _snack(str.t('common.saved'));
      } else {
        // Word/Slayt: özgün formata güvenli yazım yerine dışa aktarma öner.
        await _exportPdf();
      }
    } catch (e) {
      _snack(str.t('common.save_failed', {'error': e}));
    }
    if (mounted) setState(() {});
  }

  Future<void> _exportPdf() async {
    // Etiket await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final exportedLabel = context.t('vw.pdf_exported');
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
    await Share.shareXFiles([XFile(path)], text: exportedLabel);
  }

  /// Görseli tam çözünürlükte PDF'e gömer; istenirse OCR ile görünmez metin
  /// katmanı ekleyip PDF'i aranabilir yapar.
  Future<void> _exportImagePdf() async {
    final pdfPreparing = context.t('vw.pdf_preparing');
    final withOcr = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('vw.image_to_pdf')),
        content: Text(context.t('vw.image_to_pdf_body') +
            context.t('vw.ocr_in_pdf')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('vw.image_only')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('vw.ocr_also')),
          ),
        ],
      ),
    );
    if (withOcr == null || !mounted) return;

    final progress = ValueNotifier<String>(
        withOcr ? context.t('vw.scanning_text') : context.t('vw.pdf_preparing'));
    _showProgressDialog(progress);

    String? path;
    String? error;
    try {
      final lines = withOcr
          ? await OcrService.recognizeImageLines(widget.doc.path)
          : const <OcrLine>[];
      progress.value = pdfPreparing;
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
      _snack(context.t('vw.pdf_failed', {'error': error}));
      return;
    }
    await Share.shareXFiles([XFile(path!)], text: context.t('vw.pdf_exported'));
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

  /// Belgeyi **düzenlenebilir bir sunuma** (.pptx) çevirir.
  ///
  /// Eskiden çıktı PDF'ti (`textToSlidesPdf`); "PDF'ten slayta" isteğinin
  /// karşılığı düzenlenebilir bir dosyadır, o yüzden gerçek .pptx üretiliyor.
  /// Dosya hem bizim slayt düzenleyicimizde hem PowerPoint'te açılır.
  ///
  /// Metin `_documentText`ten geliyor: eski hâli `_textController?.text ??
  /// doc.plainText` idi ve PDF'te ikisi de BOŞTU (PDF metin türü değil, metni
  /// `_pdfText`te duruyor) — yani asıl hedef olan PDF'te boş deste üretiyordu.
  /// Belgeyi sunuma çevirir: **AI ile** (okuyup özetleyerek) ya da hızlı
  /// sezgiyle; çıktı .pptx (düzenlenebilir) ya da PDF deste.
  ///
  /// Metin `_documentText`ten geliyor: eski hâli `_textController?.text ??
  /// doc.plainText` idi ve PDF'te ikisi de BOŞTU (PDF metin türü değil, metni
  /// `_pdfText`te durur) — yani asıl hedef olan PDF'te boş deste üretiyordu.
  Future<void> _exportSlides() =>
      AiSlidesFlow.run(context, _documentText, fileName: widget.doc.name);

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
  /// Belge açıkken dosya işlemleri (taşı / kopyala / paylaş / yeniden
  /// adlandır / sil) — dosya yöneticisiyle AYNI sayfa kullanılır, iki yerde
  /// ayrı menü tutmak tutarsızlığa yol açardı.
  Future<void> _fileActions() async {
    await showEntryActions(
      context,
      FsEntry.fromEntity(File(widget.doc.path)),
    );
  }

  /// **Tek düğme çeviri** (istek 2026-07-31): metin nereden gelirse gelsin
  /// kullanıcı ayrıca OCR çalıştırmaz.
  ///
  /// - PDF: her sayfa için önce metin katmanı, boşsa OCR (bkz.
  ///   [DocTranslate.collectPdfPages]) → sayfa yapısı korunarak çevrilir.
  /// - Görsel: OCR (bir kez tanındıysa sonucu yeniden kullanılır).
  /// - Diğer belgeler: zaten yüklü olan metin.
  Future<void> _translateDocument() async {
    final doc = widget.doc;
    if (doc.kind == DocKind.pdf) {
      final pdf = _pdfDoc;
      if (pdf == null) {
        _snack(context.t('vw.pdf_loading'));
        return;
      }
      // **İki farklı iş, ikisi de "çeviri"** (kullanıcı 2026-08-30): biri
      // okumak/kopyalamak için metin, öteki *belgenin kendisi* hedef dilde.
      // Hangisinin istendiği belgeden anlaşılamaz — soruyoruz.
      final inPlace = await _askTranslateMode();
      if (inPlace == null || !mounted) return;
      if (inPlace) {
        // Bekleyen düzenleme varsa önce çözülür: çeviri DİSKTEKİ baytları
        // okuyor, kaydedilmemiş bir düzeltme sessizce kaybolmasın.
        if (!await _confirmLeavePending() || !mounted) return;
        final bytes = await _fileService.readBytes(widget.doc.path);
        if (!mounted) return;
        await TranslateFlow.runPdfInPlace(
          context,
          path: widget.doc.path,
          bytes: bytes,
          pageCount: pdf.pages.length,
        );
        return;
      }
      await TranslateFlow.runDocument(
        context,
        title: doc.name,
        load: (progress) => DocTranslate.collectPdfPages(
          pdf,
          onLayer: (done, total) => progress.status(
              context.t('tf.page_reading', {'n': done + 1, 'total': total})),
          onOcr: (done, total) => progress.status(
              context.t('tf.page_ocr', {'n': done + 1, 'total': total})),
          cancelled: () => progress.cancelled,
        ),
      );
      return;
    }
    if (doc.kind == DocKind.image) {
      await TranslateFlow.runDocument(
        context,
        title: doc.name,
        load: (progress) async {
          if (_ocrImageText.trim().isNotEmpty) {
            return [OcrPage(1, _ocrImageText.trim())];
          }
          progress.status(context.t('vw.ocr_running'));
          final text = await OcrService.recognizeImageFile(doc.path);
          if (text.trim().isEmpty) return const <OcrPage>[];
          // Tanınan metin ekranda da kalsın: AI sohbeti ve "Metni tanı"
          // sayfası aynı sonucu yeniden taramasın.
          if (mounted) setState(() => _ocrImageText = text);
          return [OcrPage(1, text.trim())];
        },
      );
      return;
    }
    final text = _documentText.trim();
    if (text.isEmpty) {
      _snack(context.t('vw.no_text_to_translate'));
      return;
    }
    await TranslateFlow.run(context, text, title: doc.name);
  }

  /// "Belgenin kendisi mi, metin mi?" — PDF çevirisinde tek soru.
  ///
  /// Vazgeçilirse null; true = yerinde (düzeni koruyan) çeviri.
  Future<bool?> _askTranslateMode() => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('tf.mode_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(ctx.t('tf.mode_inplace')),
                subtitle: Text(ctx.t('tf.mode_inplace_hint')),
                onTap: () => Navigator.pop(ctx, true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.subject),
                title: Text(ctx.t('tf.mode_text')),
                subtitle: Text(ctx.t('tf.mode_text_hint')),
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel')),
            ),
          ],
        ),
      );

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
        title: Text(context.t('vw.doc_info')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statRow(context.t('vw.word'), s.words),
            _statRow(context.t('vw.chars'), s.characters),
            _statRow(context.t('vw.chars_nospace'), s.charactersNoSpaces),
            _statRow(context.t('vw.line'), s.lines),
            _statRow(context.t('vw.paragraph'), s.paragraphs),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.close')),
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
    showSnack(context, m);
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
            tooltip: context.t('vw.page_layout'),
            icon: Icon(_pdfColumns == 1
                ? Icons.view_agenda_outlined
                : (_pdfColumns == 2
                    ? Icons.view_column_outlined
                    : Icons.grid_view_outlined)),
            onSelected: _setPdfColumns,
            itemBuilder: (_) => [
              PopupMenuItem(value: 1, child: Text(context.t('vw.one_column'))),
              PopupMenuItem(value: 2, child: Text(context.t('vw.two_columns'))),
              PopupMenuItem(value: 4, child: Text(context.t('vw.four_columns'))),
            ],
          ),
          IconButton(
            tooltip: context.t('vw.toc'),
            icon: const Icon(Icons.toc),
            onPressed: _showOutline,
          ),
          // Sayfa döndürme üst çubuktan ÜÇ NOKTAYA taşındı (2026-08-02):
          // dar telefonda 7 eylem başlığa yer bırakmıyordu ve iki ikon
          // birbirinin aynası olduğu için hangisinin ne yaptığı anlaşılmıyordu.
          // Menüde etiketli ve seyrek kullanılan bir iş için doğru yer.
          // Gece/gündüz düğmesi üst çubuktan ÜÇ NOKTAYA taşındı
          // (2026-07-26 kullanıcı isteği) — üst çubuk kalabalıktı.
          if (_pdfDirty)
            IconButton(
              tooltip: context.t('vw.save_edits'),
              icon: const Icon(Icons.save_outlined),
              onPressed: _savePendingPdf,
            ),
        ],
        if (_textController != null || doc.kind == DocKind.pdf)
          IconButton(
            tooltip: context.t('vw.find_in_doc_short'),
            icon: Icon(_findOpen ? Icons.search_off : Icons.search),
            onPressed: _toggleFind,
          ),
        if (doc.kind == DocKind.image) ...[
          IconButton(
            tooltip: context.t('vw.zoom_out'),
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _zoomImg(1 / 1.4),
          ),
          IconButton(
            tooltip: context.t('vw.zoom_in'),
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _zoomImg(1.4),
          ),
          IconButton(
            tooltip: context.t('vw.rotate'),
            icon: const Icon(Icons.rotate_right),
            onPressed: () =>
                setState(() => _imgQuarterTurns = (_imgQuarterTurns + 1) % 4),
          ),
        ],
        if (_textController != null) ...[
          IconButton(
            tooltip: context.t('vw.text_smaller'),
            icon: const Icon(OfficeIcons.fontShrink),
            onPressed: () => _changeFont(-2),
          ),
          IconButton(
            tooltip: context.t('vw.text_bigger'),
            icon: const Icon(OfficeIcons.fontGrow),
            onPressed: () => _changeFont(2),
          ),
          // Yazı TİPİ de değişebilsin (2026-08-07 kullanıcı isteği: "yazı
          // boyutu ve font değiştirme"). Boyut zaten vardı, aile yoktu.
          PopupMenuButton<String>(
            tooltip: context.t('word.font_family'),
            icon: const Icon(OfficeIcons.fontFamily),
            onSelected: (f) =>
                setState(() => _fontFamily = f.isEmpty ? null : f),
            itemBuilder: (_) => [
              for (final f in _readerFonts)
                CheckedPopupMenuItem(
                  value: f.$2,
                  checked: (_fontFamily ?? '') == f.$2,
                  child: Text(f.$1,
                      style: TextStyle(
                          fontFamily: f.$2.isEmpty ? null : f.$2)),
                ),
            ],
          ),
        ],
        // "Kaydet", "Paylaş", "Yazdır", "PDF araçları" ve görselde "Metni tanı"
        // / "PDF'e dönüştür" buradan KALDIRILDI: hepsi alt eylem çubuğunda
        // etiketli duruyor (2026-07-28 kullanıcı isteği).
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
              case 'stats':
                _showStats();
                break;
              case 'sign':
                _signPdf();
                break;
              case 'form':
                _fillPdfForm();
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
              case 'reader':
                final pdf = _pdfDoc;
                if (pdf != null) {
                  ReaderScreen.open(context,
                      document: pdf, title: widget.doc.name);
                }
                break;
              case 'rotl':
                _rotateCurrentPage(-1);
                break;
              case 'rotr':
                _rotateCurrentPage(1);
                break;
              case 'speak':
                _toggleSpeech();
                break;
              case 'fileops':
                _fileActions();
                break;
            }
          },
          itemBuilder: (_) => [
            if (doc.kind == DocKind.pdf) ...[
              // "Sayfaya git" üç yerde birden: burada (etiketli, bulunabilir),
              // arama çubuğunda ve alttaki sayfa rozetine dokununca. Kullanıcı
              // 2026-07-26'da yalnız arama çubuğundakini bulamadığını söyledi
              // ("nerede olduğu anlaşılmıyor, kişiler bulamaz").
              PopupMenuItem(
                  value: 'gotopage',
                  child: Text(context.t('vw.goto_page'))),
              // E-kitap okuma görünümü (2026-08-06 isteği): taranmış PDF'te
              // bile sayfanın METNİ akar — OCR arka planda, sayfa görüntüsü
              // yerine kitap gibi okunur.
              PopupMenuItem(
                  value: 'reader',
                  enabled: _pdfDoc != null,
                  child: Text(context.t('reader.open'))),
              PopupMenuItem(
                value: 'night',
                child: Text(context
                    .t(_pdfNight ? 'vw.night_off' : 'vw.night_on')),
              ),
              PopupMenuItem(
                value: 'rotl',
                enabled: !_pdfBusy,
                child: Text(context.t('vw.rotate_left')),
              ),
              PopupMenuItem(
                value: 'rotr',
                enabled: !_pdfBusy,
                child: Text(context.t('vw.rotate_right')),
              ),
              PopupMenuItem(
                  value: 'aiedit', child: Text(context.t('vw.ai_edit'))),
              PopupMenuItem(value: 'sign', child: Text(context.t('vw.sign'))),
              PopupMenuItem(
                  value: 'form', child: Text(context.t('vw.fill_form'))),
              PopupMenuItem(
                  value: 'ocr', child: Text(context.t('vw.ocr'))),
            ],
            if (_ttsTotal == 0)
              PopupMenuItem(
                  value: 'speak', child: Text(context.t('vw.speak'))),
            // "Çevir" buradan KALDIRILDI: alt eylem çubuğunda etiketli duruyor
            // (2026-07-31 — "tek butonla" isteği; menüde de tutmak aynı işi
            // iki yere koymak olurdu).
            if (doc.kind != DocKind.image)
              PopupMenuItem(value: 'pdf', child: Text(context.t('vw.to_pdf'))),
            PopupMenuItem(
                value: 'slides', child: Text(context.t('vw.to_slides'))),
            if (_hasText)
              PopupMenuItem(
                  value: 'stats', child: Text(context.t('vw.word_count'))),
            // Belgeyi okurken "bunu Önemli Dosyalar'a taşıyayım" demek için
            // görüntüleyiciyi kapatıp dosyayı listede aramak gerekmesin
            // (kullanıcı isteği 2026-07-29: "her türlü dosyada bu olmalı").
            PopupMenuItem(
                value: 'fileops',
                child: Text(context.t('vw.file_ops'))),
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
        tooltip: hasApiKey ? context.t('common.ai') : 'AI (anahtar gerekli)',
        child: const Icon(Icons.smart_toy_outlined),
      ),
    );
  }

  /// Türüne göre dolan eylem çubuğu; ortak son iki düğme **Paylaş · Yazdır**.
  ///
  /// Etiketli, çünkü kullanıcı ne yapacağını ekrandan okuyabilmeli.
  /// "Yazdır" görselde YOK: `_print` metni PDF'e çevirip basar, görselin metni
  /// olmadığı için boş sayfa çıkardı — orada iş "PDF'e dönüştür".
  ///
  /// **Çevir** her türde var (2026-07-31): eskiden yalnız taşma menüsündeydi ve
  /// taranmış belgede önce OCR istiyordu; artık düğme tek başına yetiyor.
  Widget _actionBar(LoadedDoc doc) {
    final isImage = doc.kind == DocKind.image;
    return DocActionBar([
      if (doc.kind == DocKind.pdf) ...[
        DocAction(Icons.edit_document, context.t('vw.editor'), _openPdfEditor),
        DocAction(Icons.construction, context.t('vw.tools'), _openPdfTools),
      ],
      if (isImage) ...[
        DocAction(Icons.document_scanner_outlined, context.t('vw.ocr_short'), _runOcr),
        DocAction(Icons.picture_as_pdf_outlined, context.t('vw.to_pdf'), _exportPdf),
      ],
      if (doc.isEditableText) ...[
        DocAction(Icons.edit_outlined, context.t('common.edit'), _textFocus.requestFocus),
        DocAction(Icons.save_outlined, 'Kaydet', _save),
      ],
      DocAction(
          Icons.translate, context.t('common.translate'), _translateDocument),
      DocAction(Icons.share_outlined, context.t('common.share'), _share),
      if (!isImage) DocAction(Icons.print_outlined, context.t('vw.print'), _print),
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

  /// Seçim sürüklemesinin ekran konumu değişti (null = bitti). Kenara
  /// yaklaşınca 60 Hz'lik zamanlayıcı görüntüyü o yöne iter; sürükleme bitince
  /// zamanlayıcı ölür. Zamanlayıcı işaretçi olaylarından AYRI koşar ki parmak
  /// kenarda hiç kımıldamadan dursa da akış sürsün.
  void _onPdfSelDragAt(Offset? global) {
    _pdfSelDragPos = global;
    if (global == null) {
      _pdfEdgeScrollTimer?.cancel();
      _pdfEdgeScrollTimer = null;
      return;
    }
    _pdfEdgeScrollTimer ??=
        Timer.periodic(const Duration(milliseconds: 16), (_) {
      final pos = _pdfSelDragPos;
      if (pos == null || !mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final delta = edgeAutoScrollDelta(box.globalToLocal(pos), box.size);
      if (delta == Offset.zero) return;
      try {
        // Görüntü matrisi işaretçinin TERS yönüne itilir (alt kenar →
        // içerik yukarı). Ayarlayıcı güvenli aralığa kıstırır.
        _pdfController.value = _pdfController.value.clone()
          ..leftTranslate(-delta.dx, -delta.dy);
      } catch (_) {
        // Görüntüleyici henüz hazır değilse (yarış) itme sessizce atlanır.
      }
    });
  }

  /// Seçim çubuğu — tasarımı ve taşma güvencesi [PdfSelectionBar]'da.
  Widget _selectionBar() => PdfSelectionBar(
        preview: _shorten(_pdfSelection, 34),
        colors: _highlightColors,
        selectedColor: _highlightColor,
        onHighlight: (argb) {
          setState(() => _highlightColor = argb);
          _highlightPdf();
        },
        onRemoveHighlight: _removeHighlight,
        onCopy: _copyPdfSelection,
        // Yerinde düzenleme: yalnız bu satırlar değişir, sayfa düzeni korunur
        // (tam belge AI düzenlemesinden farkı bu). OCR seçiminde PDF
        // düzenleyicisine gider — orada OCR satırının üstüne yazılır
        // (2026-08-06: "taranmış belge deyip düzenleme yaptırmıyor").
        onEdit: _pdfSelFromOcr ? _openPdfEditor : _startInlineEdit,
        onTranslate: () => TranslateFlow.run(context, _pdfSelection,
            title: context.t('vw.selected_text')),
        highlightTooltip: context.t('vw.highlight_hint'),
        removeTooltip: context.t('vw.highlight_remove'),
        copyLabel: context.t('common.copy'),
        editLabel: context.t('common.edit'),
        translateLabel: context.t('common.translate'),
      );

  /// Yerinde düzenleme çubuğu — bkz. [PdfEditBar] (niye ekranın altında
  /// olduğu da orada yazılı).
  Widget _editBar() => PdfEditBar(
        busy: _pdfEditBusy,
        onCancel: _cancelInlineEdit,
        onRewrite: _rewriteInlineEdit,
        onApply: _submitInlineEdit,
        onCaretLeft: () => _moveCaret(-1),
        onCaretRight: () => _moveCaret(1),
        onSelectAll: _selectAllInlineEdit,
        cancelLabel: context.t('common.cancel'),
        aiLabel: context.t('vw.ai_fix'),
        applyLabel: context.t('common.apply'),
        caretLeftLabel: context.t('vw.caret_left'),
        caretRightLabel: context.t('vw.caret_right'),
        selectAllLabel: context.t('vw.select_all_text'),
      );

  /// İmleci [delta] karakter kaydırır (çubuktaki ◀ ▶).
  ///
  /// Seçim varsa önce **daraltılır**: kullanıcı bir kelimeyi seçmişken sağ oka
  /// bastığında beklenen şey seçimin ucuna gitmek, seçimin silinmesi değil —
  /// masaüstü klavye davranışının aynısı.
  void _moveCaret(int delta) {
    final ctl = _pdfEditCtl;
    if (ctl == null) return;
    final selection = ctl.selection;
    final length = ctl.text.length;
    final int from;
    if (!selection.isValid) {
      from = delta < 0 ? 0 : length;
    } else if (!selection.isCollapsed) {
      from = delta < 0 ? selection.start : selection.end;
      ctl.selection = TextSelection.collapsed(offset: from);
      _focusInlineEdit();
      return;
    } else {
      from = selection.baseOffset;
    }
    ctl.selection =
        TextSelection.collapsed(offset: (from + delta).clamp(0, length));
    _focusInlineEdit();
  }

  /// Kutudaki metnin tamamını seçer — "hepsini silip baştan yaz" en sık
  /// yapılan düzeltme ve minik yazıda üç kez dokunmak zor.
  void _selectAllInlineEdit() {
    final ctl = _pdfEditCtl;
    if (ctl == null) return;
    ctl.selection =
        TextSelection(baseOffset: 0, extentOffset: ctl.text.length);
    _focusInlineEdit();
  }

  static String _shorten(String s, int max) {
    final t = s.replaceAll('\n', ' ').trim();
    return t.length <= max ? '“$t”' : '“${t.substring(0, max)}…”';
  }

  Future<void> _copyPdfSelection() async {
    // Ham seçim değil TEMİZ metin kopyalanır (2026-08-06 kullanıcı bulgusu):
    // pdfium'un satır sonları ve görünmez karakterleri panoya taşınmasın,
    // satırlara bölünmüş "Fizik / Muayene" tek satır "Fizik Muayene" olsun.
    final text = cleanPdfCopyText(_pdfSelection);
    if (text.isEmpty) return;
    final copied = context.t('vw.copied_chars', {'n': text.length});
    await Clipboard.setData(ClipboardData(text: text));
    _snack(copied);
  }

  /// Seçili metni PDF'e kalıcı highlight annotation olarak yazar (Syncfusion),
  /// dosyayı günceller ve pdfrx'i yeniden yükler (vurgu görünsün). Seçim modu
  /// açık kalır → kullanıcı üst üste vurgulayabilir.
  ///
  /// ponytail: annotate+save ana izlekte. Büyük PDF'te takılırsa xlsx gibi
  /// `compute`'a taşınır (bkz. HAFIZA 2026-07-22 XLSX isolate).
  /// Seçime değen vurguları siler (kullanıcı 2026-08-29: *"vurgu kaldır vb
  /// işlemler yok"*). Seçim vurgunun bir parçasına denk gelse yeter.
  Future<void> _removeHighlight() async {
    final rects = _pdfSelRects;
    final page = _pdfSelPage;
    if (rects.isEmpty || page < 1) return;
    try {
      final bytes = await _fileService.readBytes(widget.doc.path);
      final (out, removed) = await PdfAnnotator.removeHighlights(
        bytes: bytes,
        pageIndex: page - 1,
        pdfRects: rects,
      );
      if (!mounted) return;
      if (removed == 0) {
        // Seçim kalsın: kullanıcı biraz kaydırıp yeniden deneyebilsin.
        _snack(context.t('vw.highlight_none_here'));
        return;
      }
      setState(() {
        _pdfSelection = '';
        _pdfSelRects = const [];
      });
      await _writePending(out);
      if (mounted) {
        _snack(context.t('vw.highlight_removed', {'n': removed}));
      }
    } catch (e) {
      if (mounted) _snack(context.t('vw.highlight_failed', {'error': e}));
    }
  }

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
    _ocrSearch?.reset();
    _findEntry = null;
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
    final linkFailed = context.t('vw.link_failed');
    final linkFailedE = context.t('vw.link_failed_e');
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
        title: Text(context.t('vw.link_title')),
        content: Text(context.t('vw.link_body', {'url': url})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.t('common.open'))),
        ],
      ),
    );
    if (go != true) return;
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) _snack(linkFailed);
    } catch (e) {
      _snack(linkFailedE.replaceAll('{error}', '$e'));
    }
  }

  /// Belge ana hattı (içindekiler). PDF'te yoksa kullanıcıya söylenir.
  Future<void> _showOutline() async {
    final doc = _pdfDoc;
    if (doc == null) return;
    final outline = await doc.loadOutline();
    if (!mounted) return;
    if (outline.isEmpty) {
      _snack(context.t('vw.no_toc'));
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
          ? context.t('vw.no_readable_text')
          : 'Okunacak metin yok');
      return;
    }
    final service = TtsService(prefs: context.read<AppState>().ttsPrefs)
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
              tooltip: context.t(
                  _ttsPlaying ? 'common.pause' : 'common.resume'),
              icon: Icon(_ttsPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _toggleSpeech,
            ),
            Expanded(
              child: Text(
                  context.t('vw.speaking',
                      {'n': _ttsIndex + 1, 'total': _ttsTotal}),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            IconButton(
              tooltip: context.t('tts.voice_settings'),
              icon: const Icon(Icons.record_voice_over_outlined),
              onPressed: () async {
                await TtsVoiceSheet.show(context);
                // Okuma sürerken ses değiştirilebilsin: yeni tercih sonraki
                // parçadan itibaren geçerli olur.
                if (mounted) _tts?.prefs = context.read<AppState>().ttsPrefs;
              },
            ),
            IconButton(
              tooltip: context.t('common.stop'),
              icon: const Icon(Icons.stop),
              onPressed: _stopSpeech,
            ),
          ],
        ),
      ),
    );
  }

  /// Form doldurma ekranı — belgenin kendi alanları düzenlenir.
  ///
  /// Menüde HER PDF'te duruyor: alan olup olmadığı ancak belge çözümlenince
  /// bilinir ve her açılışta bunu yapmak büyük dosyalarda saniyeler alırdı.
  /// Alan yoksa ekran bunu söyleyip ne yapılabileceğini yazıyor.
  Future<void> _fillPdfForm() async {
    if (!await _confirmLeavePending() || !mounted) return;
    final filled = await PdfFormScreen.open(context, widget.doc.path);
    if (filled == true && mounted) await _reloadPdf();
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
    _pdfEditFocus?.dispose();
    _pdfEditFocus = FocusNode(debugLabel: 'pdf-inline-edit');
    // Kutu bir sonraki karede çiziliyor; odak ondan SONRA isteniyor.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusInlineEdit());
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
    _pdfEditFocus?.dispose();
    setState(() {
      _pdfEdit = null;
      _pdfEditCtl = null;
      _pdfEditFocus = null;
    });
  }

  /// Klavyeyi açar (ve düşen odağı geri alır).
  void _focusInlineEdit() {
    final node = _pdfEditFocus;
    if (node == null || !mounted || _pdfEdit == null) return;
    if (!node.hasFocus) node.requestFocus();
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
    // AI sayfası kapanınca odak kutuya geri döner; yoksa kullanıcı yazmaya
    // devam etmek için kutuya bir kez daha dokunmak zorunda kalıyordu.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInlineEdit());
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
        _pdfEditFocus?.dispose();
        _pdfEditCtl = null;
        _pdfEditFocus = null;
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
      _snack(context.t('vw.change_failed', {'error': e}));
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
        _snack(context.t(
            quarterTurns < 0 ? 'vw.rotated_left' : 'vw.rotated_right',
            {'n': page}));
      }
    } catch (e) {
      if (mounted) _snack(context.t('vw.rotate_failed', {'error': e}));
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
      if (mounted) _snack(context.t('vw.highlighted'));
    } catch (e) {
      if (mounted) _snack(context.t('vw.highlight_failed', {'error': e}));
    }
  }

  // ── OCR ───────────────────────────────────────────────────────────────────

  /// Görselde veya (taranmış) PDF'te cihaz-içi OCR koşturur; sonucu seçilebilir
  /// bir sayfada gösterir ve AI sohbet bağlamına işler.
  Future<void> _runOcr() async {
    final doc = widget.doc;
    if (doc.kind == DocKind.pdf && _pdfDoc == null) {
      _snack(context.t('vw.pdf_loading'));
      return;
    }
    final progress = ValueNotifier<String>(context.t('vw.preparing'));
    _showProgressDialog(progress);

    String text = '';
    String? error;
    try {
      if (doc.kind == DocKind.image) {
        progress.value = context.t('vw.ocr_running');
        text = await OcrService.recognizeImageFile(doc.path);
      } else if (doc.kind == DocKind.pdf) {
        text = await OcrService.recognizePdf(
          _pdfDoc!,
          onProgress: (done, total) => progress.value = done >= total
              ? 'Bitiriliyor…'
              : context.t('vw.ocr_page', {'n': done + 1, 'total': total}),
        );
      }
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // ilerleme penceresi

    if (error != null) {
      _snack(context.t('vw.ocr_failed', {'error': error}));
      return;
    }
    if (text.isEmpty) {
      _snack(context.t('vw.ocr_none'));
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
    final copiedAll = context.t('vw.copied_all');
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
                  Text(context.t('vw.ocr_text'),
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack(copiedAll);
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(context.t('vw.copy_all')),
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
    // Yeni düzen ölçüldükten SONRA genişliğe sığdır.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitPdfWidth());
  }

  /// Belgeyi **genişliğine sığdırır** — çok sütunlu dizilimin can alıcı yarısı.
  ///
  /// KÖK NEDEN (2026-08-07 kullanıcı: *"2 sütun 4 sütun yapınca oto genişlemeli
  /// alan görülsün"*): sütun sayısı değişince pdfrx yakınlaştırma oranını
  /// OLDUĞU GİBİ bırakıyor. 4 sütunluk düzen bir anda dört kat genişliyor ama
  /// ekranda hâlâ tek sütunluk kadarı görünüyor; kullanıcı "hiçbir şey
  /// değişmedi" ya da "sayfalar kayboldu" diyor. Sığdırma, düzenin tamamını
  /// bir bakışta gösterir.
  ///
  /// Dikey konum korunur (üstteki satır neredeyse orada kalır); yalnız ölçek
  /// değişir. Belge hazır değilse sessizce vazgeçilir.
  Future<void> _fitPdfWidth() async {
    try {
      if (!_pdfController.isReady) return;
      final doc = _pdfController.documentSize;
      final view = _pdfController.viewSize;
      if (doc.width <= 0 || view.width <= 0 || view.height <= 0) return;
      final top = _pdfController.visibleRect.top;
      // Görünüm oranıyla aynı oranda bir dikdörtgen istersek sığdırma
      // genişliği belirler (pdfrx en dar kenara göre ölçekler).
      final height = doc.width * view.height / view.width;
      await _pdfController.goToArea(
        rect: Rect.fromLTWH(0, top, doc.width, height),
      );
    } catch (_) {
      // Belge kapanmış/yeniden yükleniyor olabilir — sığdırma kritik değil.
    }
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
    // Sayfa sayısı yoksa belge daha okunuyor demektir. SESSİZCE vazgeçmek
    // "dokunuyorum hiçbir şey olmuyor" diye görünüyordu (2026-08-07).
    if (count <= 0) {
      _snack(context.t('vw.still_loading'));
      return;
    }
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
          title: Text(context.t('vw.goto_page_short')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.t('vw.page_number', {'count': count}),
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
                child: Text(context.t('common.cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, resolve()),
              child: Text(context.t('common.go')),
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
  /// (`_updateLayout` → düzen ya da GÖRÜNÜM BOYU değiştiyse `_goToPage(o anki
  /// sayfa)`) atlayışı yarıda kesip bulunulan yere geri çekebiliyor.
  ///
  /// 2026-08-07 turunda üç ayrı "bazen çalışmıyor" nedeni daha çıktı:
  /// 1. **Klavye:** pencere kapanınca yumuşak klavye de kapanıyor ve görünüm
  ///    yeniden boyutlanıyor → pdfrx tam biz atlarken "o anki sayfaya" geri
  ///    çekiyordu. Artık önce yerleşmesi bekleniyor ([_waitViewerSettled]).
  /// 2. **Bağlantısız denetleyici:** dosyada işlem yapıldıysa (vurgu, imza,
  ///    düzenleme…) belge yeniden okunuyor; o aralıkta `goToPage` FIRLATIYOR
  ///    ve hata yakalanmadığı için ekranda hiçbir şey olmuyordu — kullanıcı
  ///    için "düğme ölü". Artık hazır olması bekleniyor, olmazsa söyleniyor.
  /// 3. **Yanlış ölçü:** varış pdfrx'in tahmini sayfa numarasıyla ölçülüyordu;
  ///    yakınlaştırılmış/çok sütunlu görünümde doğru sayfadayken bile
  ///    tutmuyordu (bkz. [arrivedAtPage]). Artık geometriyle ölçülüyor.
  ///
  /// Sonuç her hâlükârda kullanıcıya söyleniyor: başarılıysa nereye gidildiği,
  /// başarısızsa nerede kalındığı. Sessizce yanlış yerde bırakmak, kullanıcının
  /// "çalışmıyor" deyip nedenini bilememesi demekti.
  Future<void> _goToPdfPage(int target, int total) async {
    // Klavye kapanışı + düzen yerleşmesi bitmeden atlamak boşuna: pdfrx
    // görünüm boyu değişince bulunulan sayfaya geri çekiyor.
    final ready = await _waitViewerSettled();
    if (!mounted) return;
    if (!ready) {
      _snack(context.t('vw.still_loading'));
      return;
    }
    var arrived = false;
    for (var attempt = 0; attempt < 3 && !arrived; attempt++) {
      // İlk deneme animasyonlu (kullanıcı nereye gittiğini görsün); yeniden
      // denerken anlık, yoksa iki animasyon birbirini kesiyor.
      if (!await _tryGoToPage(target, animate: attempt == 0)) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
        continue;
      }
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
      arrived = _arrivedAtPdfPage(target);
    }
    if (!mounted) return;
    if (arrived) {
      // Rozet pdfrx'in tahminiyle değil, gerçekten gidilen sayfayla
      // güncellensin — yoksa "8'e gittim ama altta 7 yazıyor" olurdu.
      if (_pdfPage != target) setState(() => _pdfPage = target);
      _snack(context.t('vw.page_of', {'n': target, 'total': total}));
    } else {
      _snack(context.t('vw.page_jump_failed_total', {
        'target': target,
        'landed': _livePdfPage() ?? _pdfPage,
        'total': total,
      }));
    }
  }

  /// Tek atlayış denemesi. Denetleyici belgeye bağlı değilse (yeniden yükleme
  /// sürüyor) pdfrx null denetimiyle FIRLATIR — bu yakalanmazsa ekranda hiçbir
  /// şey olmuyor ve düğme bozuk sanılıyordu.
  Future<bool> _tryGoToPage(int target, {required bool animate}) async {
    try {
      await _pdfController.goToPage(
        pageNumber: target,
        duration: animate
            ? const Duration(milliseconds: 200)
            : Duration.zero,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Görüntüleyici atlamaya hazır mı: belge yüklü, düzen ölçülmüş ve **görünüm
  /// boyu oturmuş**.
  ///
  /// Ölçüt "klavye kapandı" DEĞİL, "klavye artık kımıldamıyor": pencere
  /// kapandıktan sonra odak arama kutusuna geri dönerse klavye açık kalır ve
  /// kapanmasını beklemek boşuna 1 saniye eklerdi. Kritik olan, biz atlarken
  /// görünümün yeniden boyutlanmaması (pdfrx bunu görünce bulunulan sayfaya
  /// geri çeker). En çok ~1,2 sn beklenir.
  Future<bool> _waitViewerSettled() async {
    double? previous;
    for (var i = 0; i < 24; i++) {
      if (!mounted) return false;
      final inset = MediaQuery.viewInsetsOf(context).bottom;
      if (inset == previous && _viewerLaidOut()) return true;
      previous = inset;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    // Klavye hiç durulmadıysa da düzen hazırsa yine deneriz.
    return mounted && _viewerLaidOut();
  }

  /// Belge + düzen + görünüm boyu elimizde mi? (Hepsi pdfrx'te `null!`
  /// erişimi; hazır değilken okumak fırlatır.)
  bool _viewerLaidOut() {
    try {
      if (!_pdfController.isReady) return false;
      return _pdfController.layout.pageLayouts.isNotEmpty &&
          _pdfController.viewSize.width > 0;
    } catch (_) {
      return false;
    }
  }

  /// Hedef sayfa gerçekten ekranda mı (geometriyle — bkz. [arrivedAtPage]).
  /// Ölçemezsek pdfrx'in kendi sayfa numarasına düşülür.
  bool _arrivedAtPdfPage(int target) {
    try {
      final layouts = _pdfController.layout.pageLayouts;
      if (target < 1 || target > layouts.length) return false;
      return arrivedAtPage(
        pageRect: layouts[target - 1],
        visibleRect: _pdfController.visibleRect,
      );
    } catch (_) {
      return _livePdfPage() == target;
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
        // Kağıt teması: saf siyah yerine mürekkep tonu (rgba(38,34,25,.72)).
        color: const Color(0xB8262219),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.unfold_more, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: AppFonts.of(context).mono,
              )),
        ],
      ),
    );
  }

  Widget _buildBody(LoadedDoc doc) {
    switch (doc.kind) {
      case DocKind.pdf:
        // Ctrl/Cmd+C: seçili metni panoya kopyalar (masaüstü alışkanlığı —
        // Chrome'un PDF görüntüleyicisiyle aynı). Focus çevresi klavye
        // olayını alabilmek için; arama kutusu gibi alanlar açılınca odağı
        // onlar devralır, kısayol da doğal olarak onlara akar.
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyC, control: true):
                _copyPdfSelection,
            const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
                _copyPdfSelection,
          },
          child: Focus(
            autofocus: true,
            child: Stack(
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
                  // Sürükleyerek seçim sürerken pan kapalı: parmak/fare
                  // seçimi büyütür, sayfa kaymaz (Chrome davranışı).
                  // InteractiveViewer bu bayrağı HER olayda okuduğu için jest
                  // ortasında kapatmak da işler; belge yeniden YÜKLENMEZ
                  // (pdfrx yalnız documentRef değişiminde yükler).
                  panEnabled: !_pdfSelecting,
                  // Çok sütunlu dizilim (uzun belge). 1 sütunda pdfrx'in kendi
                  // düzeni kullanılır — gereksiz yere devralmıyoruz.
                  layoutPages: _pdfColumns == 1 ? null : _layoutPdfColumns,
                  // Arama eşleşmelerini sayfada vurgula: metin katmanı
                  // (pdfrx, Faz 1) + taranmış sayfaların OCR eşleşmeleri
                  // (Faz 2) — renkler aynı, kullanıcı fark görmez.
                  pagePaintCallbacks: [
                    if (_pdfSearcher != null)
                      _pdfSearcher!.pageTextMatchPaintCallback,
                    if (_ocrSearch != null) _paintOcrSearchMatches,
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
                    // Belge çizildikten SONRA haber ver: açılışta gösterilen
                    // şerit ilk kareyle birlikte kayboluyordu.
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _showResumeNotice());
                  },
                  onPageChanged: (page) {
                    if (mounted && page != null) {
                      setState(() => _pdfPage = page);
                      // Kaldığın yerden devam: kayıt kuralları
                      // `ReadingPositions`ta (ilk/son sayfa ve kısa belge
                      // kaydedilmez), yazma gecikmeli.
                      if (context.read<AppState>().resumePosition) {
                        ReadingPositions.record(
                            widget.doc.path, page, _pageCount);
                      }
                    }
                  },
                  // Yerinde düzenleme açıkken seçim katmanı kurulmaz: kutunun
                  // içindeki dokunuşları yutar, imleç konumlandırılamazdı.
                  pageOverlaysBuilder: (context, pageRect, page) => [
                    if (_pdfEdit != null &&
                        _pdfEdit!.page == page.pageNumber &&
                        _pdfEditCtl != null &&
                        _pdfEditFocus != null)
                      PdfInlineEditor(
                        page: page,
                        pageSize: pageRect.size,
                        rects: _pdfEdit!.rects,
                        original: _pdfEdit!.original,
                        controller: _pdfEditCtl!,
                        focusNode: _pdfEditFocus!,
                        busy: _pdfEditBusy,
                        onSubmit: _submitInlineEdit,
                      )
                    else if (_pdfEdit == null)
                      PdfSelectLayer(
                        page: page,
                        pageSize: pageRect.size,
                        // Tek etkin seçim: seçim hangi sayfadaysa öbür
                        // sayfaların katmanları kendi vurgusunu bırakır.
                        activeSelectionPage:
                            _pdfSelection.isEmpty ? 0 : _pdfSelPage,
                        onSelected: (t, rects, pageNo, preceding, fromOcr) {
                          if (mounted) {
                            setState(() {
                              _pdfSelection = t;
                              _pdfSelRects = rects;
                              _pdfSelPage = t.isEmpty ? 0 : pageNo;
                              _pdfSelPreceding = preceding;
                              _pdfSelFromOcr = fromOcr;
                            });
                          }
                        },
                        onSelectingChanged: (s) {
                          if (mounted && _pdfSelecting != s) {
                            setState(() => _pdfSelecting = s);
                          }
                        },
                        onDragAt: _onPdfSelDragAt,
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
                    // Rozet İngilizce/Arapça arayüzde de çevrilmeli — eskiden
                    // "— sayfaya git" kısmı koda gömülü Türkçeydi.
                    child: _pageBadge('$_pdfPage / $_pageCount · '
                        '${context.t('vw.goto_page_short')}'),
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
            ),
          ),
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
                    // Bellek/pil: tam çözünürlük yerine ekranın gerektirdiği
                    // kadar piksel (bkz. core/image_budget.dart). 12 MP'lik
                    // bir fotoğraf tam açıldığında 48 MB bitmap ediyordu.
                    cacheWidth: _imgDecodeWidth,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Text(
                      context.t('vw.image_failed'),
                      style: const TextStyle(color: Colors.white),
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
          fontFamily: _fontFamily,
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
                      : context.t('vw.no_viewer'),
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
                  label: Text(context.t('fm.open_with_other')),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_outlined),
                  label: Text(context.t('common.share')),
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

  /// `null` = temanın gövde yazı tipi.
  final String? fontFamily;
  final VoidCallback onChanged;
  const _TextEditor({
    required this.controller,
    required this.focusNode,
    required this.editable,
    required this.fontSize,
    required this.onChanged,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Metin sayfası BEYAZ: kağıt teması uygulamanın kabuğuna ait, belgenin
      // içine değil (2026-08-07 kullanıcı isteği — "txt de öyle").
      color: Paper.docSurface(context),
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
          hintText: editable ? context.t('vw.doc_content') : null,
          filled: false,
        ),
        style: TextStyle(
          fontSize: fontSize,
          height: 1.5,
          fontFamily: fontFamily,
          color: Theme.of(context).brightness == Brightness.dark
              ? Paper.inkDark
              : Paper.ink,
        ),
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
      return Center(child: Text(context.t('vw.table_empty')));
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
