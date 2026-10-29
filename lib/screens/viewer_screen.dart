import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        LogicalKeyboardKey,
        SystemChrome,
        TextInputFormatter,
        SystemUiMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_icons.dart';
import '../core/line_endings.dart';
import '../core/motion.dart';
import '../core/pretty_format.dart';
import '../core/text_replace.dart';
import '../core/doc_fonts.dart';
import '../core/image_budget.dart';
import '../core/edit/edit_session.dart';
import '../core/edit/code_editing.dart';
import '../core/edit/code_highlight.dart';
import '../core/edit/code_text_controller.dart';
import '../core/edit/editor_chrome.dart';
import '../core/edit/markdown_edit.dart';
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
import '../services/fm/pdf_edit_journal.dart';
import '../services/fm/pdf_bookmarks.dart';
import '../services/fm/reading_positions.dart';
import '../services/fm/safe_write.dart';
import '../services/ocr_service.dart';
import '../services/pdf/edge_auto_scroll.dart';
import '../services/fm/save_to_downloads.dart';
import '../services/pdf/current_page.dart';
import '../services/pdf/pdf_fling.dart';
import '../services/pdf/page_arrival.dart';
import '../services/pdf/pdf_form.dart';
import '../services/pdf/pdf_ocr_search.dart';
import '../services/pdf_annotator.dart';
import '../services/pdf_reload.dart';
import '../services/pdf_tools.dart';
import '../services/tts_service.dart';
import '../widgets/office_ribbon.dart' show OfficeIcons;
import '../widgets/download_action.dart';
import '../widgets/tracked_busy.dart';
import 'pdf_ink_screen.dart';
import '../widgets/ai_slides_flow.dart';
import '../widgets/doc_action_bar.dart';
import '../widgets/code_gutter.dart';
import '../widgets/doc_find_bar.dart';
import '../widgets/markdown_text.dart';
import '../widgets/doc_more_sheet.dart';
import '../widgets/office_shell.dart';
import 'fm/entry_actions.dart';
import '../widgets/pdf_action_bars.dart';
import '../widgets/pdf_edit_modes.dart';
import '../widgets/large_text_view.dart';
import '../widgets/legacy_banner.dart';
import '../services/legacy_convert.dart';
import '../widgets/pdf_save_dialog.dart';
import '../widgets/quick_sheets.dart';
import '../widgets/pdf_page_navigator.dart';
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
import '../core/safe_insets.dart';
import '../core/user_error.dart';

import '../core/app_haptics.dart';
import 'audiobook/audiobook_screen.dart';
import 'fm/remote/peer_share_screen.dart' show showShareChoice;
import '../core/app_colors.dart';
import '../widgets/app_dialog.dart';
part 'viewer/pending_save.dart';
part 'viewer/find_replace.dart';
part 'viewer/doc_actions.dart';
part 'viewer/shell_menus.dart';
part 'viewer/pdf_selection.dart';
part 'viewer/pdf_marks.dart';
part 'viewer/pdf_navigation.dart';
part 'viewer/body.dart';
part 'viewer/code_tools.dart';
part 'viewer/widgets.dart';

/// PDF vurgu renkleri (0xAARRGGBB) — vurgu kipindeki sıra. Pastel tonlar
/// (2026-09-27): eski doygun pembe (F06292) çarpımsal harmanda bile kelimeyi
/// kiremit rengi bir kutuya çeviriyordu (kullanıcının ekran görüntüsü).
const List<int> _highlightColors = [
  0xFFFFE066, // sarı
  0xFF9BE09F, // yeşil
  0xFFF9A8CB, // pembe
  0xFF96CDF7, // mavi
  0xFFFFC07A, // turuncu
];

/// Son kullanılan vurgu rengi — belgeler arası hatırlanır (Vurgula düğmesi
/// bu renkle vurgular).
int _lastHighlightColor = _highlightColors.first;

class ViewerScreen extends StatefulWidget {
  final LoadedDoc doc;

  /// PDF hazır olunca kalem ekranını kendiliğinden aç (başka uygulamanın
  /// "düzenle/işaretle" düğmesiyle gelindi — bkz. [PdfInkScreen]).
  final bool startInk;

  const ViewerScreen({super.key, required this.doc, this.startInk = false});

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

  /// Az önce kodla gidilen sayfa ("sayfaya git", arama, içindekiler,
  /// bağlantı). Birden çok sayfa ekrana tam sığdığında rozet bu sayfayı
  /// göstersin diye tutulur; kullanıcı ekrana dokununca düşer
  /// (bkz. [currentPdfPage]).
  int? _pdfJumpTarget;

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
  int _highlightColor = _lastHighlightColor;

  /// **Ekranda bekleyen vurgular** (2026-09-27) — henüz dosyaya yazılmadı.
  ///
  /// Kullanıcı: *"vurgulama yapılırken PDF kapanıp açılıyor gibi oluyor."*
  /// Eskiden her vurgu belgenin tamamını Syncfusion ile ana izlekte açıp
  /// kaydediyor, özgün dosyanın ÜSTÜNE yazıyor ve pdfrx'e belgeyi baştan
  /// yükletiyordu: ekran kararıyor, 3239 sayfalık kitapta saniyelerce
  /// donuyordu. Üstüne bu yazma zinciri dosyanın 0 bayt kalmasına da açıktı.
  /// Şimdi vurgu yalnız çizilir ([_paintPendingMarks]) — anında, belge
  /// yeniden yüklenmeden — ve kaydederken (ya da dosyayı değiştiren başka
  /// bir işten hemen önce, [_flushPendingMarks]) hepsi birlikte, izolatta
  /// yazılır.
  final List<_PendingMark> _pendingMarks = [];

  /// Az önce eklenen vurgu: seçim çubuğu "vurgu kipi"ndeyken rengi
  /// değiştirilebilir ya da geri alınabilir.
  _PendingMark? _lastMark;

  /// Dosyaya yazma sürüyor mu? Sürerken ekrandan çıkılmaz: eskiden
  /// `_pdfDirty` ancak yazma BİTİNCE true oluyordu ve arada geri tuşuna basan
  /// kullanıcı yazmanın ortasında ekranı kapatabiliyordu.
  int _pdfWriting = 0;

  /// Bu dosyanın önceki oturumundan kalan geri yükleme sürüyor: belge ancak
  /// o bitince açılır (yoksa kaydedilmemiş düzenleme özgün sanılırdı).
  bool _waitingRestore = false;

  /// Kaydedilmemiş bir şey var mı (dosyaya yazılmış düzenleme ya da ekranda
  /// bekleyen vurgu)?
  bool get _hasUnsaved => _pdfDirty || _pendingMarks.isNotEmpty;

  /// Kaldığın yer çözüldü mü? Görüntüleyici ANCAK o zaman kurulur: pdfrx
  /// başlangıç sayfasını belge yüklenirken bir kez okur; sonradan gelen
  /// sayfa (eskiden `setState` ile geliyordu) önbellekteki belgede hiç
  /// uygulanmıyordu — "kaldığı yerden devam düzgün çalışmıyor" (2026-09-27).
  bool _resumeReady = true;

  /// Dosyanın boyu (bayt) — okuma konumu ve yer imleri yol değişince de
  /// bulunsun diye (bkz. [ReadingPositions.pageOf]).
  int _docSize = 0;

  /// Son atlayıştan (sayfaya git, arama, içindekiler) önceki sayfa —
  /// gezginde "N. sayfaya dön".
  int? _pageBeforeJump;

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

  /// Değiştirme satırı açık mı (2026-09-06 denetim turu). Arama vardı,
  /// **değiştirme yoktu**: bir metin dosyasındaki 200 tarihi düzeltmek
  /// isteyen kullanıcı tek tek elle yazmak zorundaydı.
  bool _replaceOpen = false;
  final _replaceCtl = TextEditingController();

  /// Satır numaraları görünsün mü (kod/kayıt dosyalarında "347. satırda hata"
  /// diyen bir mesajı takip edebilmek için).
  bool _lineNumbers = false;

  /// Satırlar kaydırılsın mı? Kayıt dosyalarında (uzun tek satırlar)
  /// kaydırmayı KAPATIP yatay kaydırmak okumayı kolaylaştırıyor.
  bool _wrapLines = true;

  /// Dosyanın ÖZGÜN satır sonu biçimi. Windows'ta üretilmiş bir dosyayı
  /// (CRLF) düzenleyip `\n` ile kaydetmek dosyanın tamamını değiştirmek
  /// demekti — `.bat`, `.csv`, `.ini` dosyaları bundan bozuluyordu.
  LineEnding _lineEnding = LineEnding.lf;
  final _findCtl = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  List<int> _matchStarts = const [];
  int _matchPos = -1;
  int _matchLen = 0;

  /// Eşleşme bitişleri (düzenli ifadede uzunluk değişken; boşsa `_matchLen`).
  List<int> _matchEnds = const [];

  /// Bul/değiştir seçenekleri (Faz 30): büyük/küçük, tam sözcük, ifade.
  bool _findCase = false;
  bool _findWord = false;
  bool _findRegex = false;
  bool _findRegexBad = false;

  /// Kod düzenleyici (Faz 30): geri al/yinele, kaydırma, girinti genişliği,
  /// Markdown önizleme.
  final UndoHistoryController _undoCtl = UndoHistoryController();
  final ScrollController _textScroll = ScrollController();
  final int _tabWidth = 2;
  bool _mdPreview = false;

  /// PDF içi arama (Faz 1): pdfrx'in hazır arayıcısı. Eşleşmeleri sayfa sayfa
  /// bulur, sayfada vurgular (pageTextMatchPaintCallback) ve goToNext/PrevMatch
  /// ile o sayfaya kaydırır. Yalnız PDF belgesinde kurulur.
  final PdfViewerController _pdfController = PdfViewerController();

  /// Okuma kipi (Faz 18 / G20): kaydırınca çubuklar çekilir. 2026-10-28:
  /// PDF'te de açık — çubuklar artık gövdenin boyunu değiştirmiyor.
  final ReadingBars _readingBars = ReadingBars();

  /// pdfrx jesti (kaydırma/iki parmak) sürüyor mu — sürerken sayfa bitmap
  /// ölçeği değişmez (bkz. [_pdfRenderScale]).
  bool _pdfInteracting = false;

  /// Süren jest iki parmaklı mı (yakınlaştırma)? Fırlatma sürtünmesi buna
  /// göre seçilir (bkz. [kPdfPanFriction]).
  bool _pdfPinch = false;

  /// Son seçilen sayfa bitmap ölçeği (basamaklı, bkz. [_pdfRenderScale]).
  double? _pdfBaseScale;

  /// Önceki matris (PDF kaydırma yönünü çıkarmak için).
  double? _pdfLastTy;
  double? _pdfLastZoom;

  /// PDF kaydırması → okuma kipi. pdfrx kaydırma bildirimi YAYMIYOR; matris
  /// değişimi izlenir. Yakınlaştırma (ölçek değişimi) ve seçim sürüklemesi
  /// çubuklara dokunmaz.
  void _onPdfMatrix() {
    if (!_pdfController.isReady) return;
    final m = _pdfController.value;
    final ty = m.getTranslation().y;
    final zoom = m.getMaxScaleOnAxis();
    final pTy = _pdfLastTy, pZoom = _pdfLastZoom;
    _pdfLastTy = ty;
    _pdfLastZoom = zoom;
    // Görüntüleyici hazır olmadan (açılıştaki "kaldığın sayfaya" atlayış)
    // çubuklar kıpırdamaz.
    if (pTy == null || pZoom == null || _pdfCount == 0) return;
    if ((zoom - pZoom).abs() > pZoom * 0.002) return;
    if (_pdfSelecting || _findOpen) return;
    _readingBars.scrolled(pTy - ty, atTop: ty >= -1);
  }

  /// "Tam ekran" (Aa levhası): sistem çubukları gizli okur. Tercih
  /// kalıcı (`reading_fullscreen`); ekrandan çıkınca sistem çubukları döner.
  bool _fullscreen = false;
  static const _kFullscreen = 'reading_fullscreen';

  Future<void> _loadFullscreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final on = prefs.getBool(_kFullscreen) ?? false;
      if (on && mounted) _setFullscreen(true, save: false);
    } catch (_) {
      // Tercih okunamadı: tam ekran kapalı başlar (zararsız varsayılan).
    }
  }

  void _setFullscreen(bool on, {bool save = true}) {
    setState(() => _fullscreen = on);
    SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (save) {
      SharedPreferences.getInstance()
          .then((p) => p.setBool(_kFullscreen, on))
          .catchError((_) => false);
    }
  }
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
  /// Eski Office dosyası dönüştürülüyor mu (şeritteki düğme kilitlensin).
  bool _legacyBusy = false;

  int _ttsIndex = 0;
  int _ttsTotal = 0;
  bool _ttsPlaying = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFullscreen());
    final doc = widget.doc;
    if (doc.kind == DocKind.text ||
        doc.kind == DocKind.word ||
        doc.kind == DocKind.slides) {
      // Satır sonu biçimi burada ÖĞRENİLİYOR ve kaydederken geri
      // uygulanıyor: düzenleyici (`TextField`) her satır sonunu `\n`e
      // indirger, yani biçimi burada tutmazsak kaydetme onu kalıcı olarak
      // değiştirirdi (bkz. `core/line_endings.dart`).
      _lineEnding = LineEndings.detect(doc.plainText);
      _textController = CodeTextController(
        text: LineEndings.toLf(doc.plainText),
        lang: codeLangFor(p.extension(doc.path)),
        enabled: doc.kind == DocKind.text,
      );
    }
    if (doc.kind == DocKind.pdf) {
      _prepareSafeOpen();
      _pdfSearcher = PdfTextSearcher(_pdfController)..addListener(_onPdfSearch);
      _ocrSearch = PdfOcrSearch()..addListener(_onPdfSearch);
      _pdfController.addListener(_onPdfMatrix);
      unawaited(_offerFormFilling());
      unawaited(_restoreReadingPage());
    }
    if (doc.kind == DocKind.image) _imgTx.addListener(_onImgTransform);
  }

  /// Belge açılmadan önce: önceki bir oturumun geri yüklemesi sürüyorsa onu
  /// bekle; uygulama düzenleme ortasında öldürülmüşse ve açılış kurtarması
  /// henüz koşmadıysa bu dosyanınkini şimdi yap; yarım yazmalardan kalan
  /// gizli geçici dosyaları temizle.
  void _prepareSafeOpen() {
    final path = widget.doc.path;
    if (PdfEditJournal.hasStale(path)) PdfEditJournal.recover(only: path);
    final pending = PdfRestoreQueue.pendingFor(path);
    if (pending != null) {
      _waitingRestore = true;
      pending.whenComplete(() {
        if (!mounted) return;
        setState(() => _waitingRestore = false);
      });
    }
    unawaited(SafeWrite.cleanupLeftovers(path));
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
    try {
      _docSize = File(widget.doc.path).lengthSync();
    } catch (_) {
      // Bilinçli: boyut yalnız okuma konumu anahtarı için; okunamazsa konum hatırlanmaz.
    }
    unawaited(PdfBookmarks.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    }));
    // Kayıt zaten bellekteyse sayfa İLK karede verilir.
    if (ReadingPositions.isLoaded) {
      _applyResumePage();
      return;
    }
    _resumeReady = false;
    try {
      await ReadingPositions.ensureLoaded();
    } finally {
      if (mounted) {
        setState(() {
          _applyResumePage();
          _resumeReady = true;
        });
      }
    }
  }

  void _applyResumePage() {
    final page = ReadingPositions.pageOf(widget.doc.path, size: _docSize);
    if (page == null || page <= 1) return;
    _pdfPage = page;
    _resumedPage = page;
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
          _pdfJumpTarget = 1;
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
    showSnackBarReplacing(
        ScaffoldMessenger.of(context),
        SnackBar(
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
        _findEntry = (
          ocr: false,
          index: s.currentIndex!,
          page: s.matches[s.currentIndex!].pageNumber
        );
      }
    });
  }

  @override
  void dispose() {
    // Bekleyen okuma konumu diske yazılsın: uygulama kapansa da "kaldığın
    // sayfa" çalışsın (kayıt üç saniyelik gecikmeyle yazılıyor).
    unawaited(ReadingPositions.save());
    _pdfController.removeListener(_onPdfMatrix);
    _readingBars.dispose();
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _pdfEdgeScrollTimer?.cancel();
    _textController?.dispose();
    _undoCtl.dispose();
    _textScroll.dispose();
    _imgTx.removeListener(_onImgTransform);
    _imgTx.dispose();
    _findCtl.dispose();
    _replaceCtl.dispose();
    _textFocus.dispose();
    _pdfSearcher
        ?.dispose(); // PdfViewerController = ValueListenable, dispose'suz
    _ocrSearch?.dispose();
    _tts?.dispose(); // ekran kapanınca konuşma sürmesin
    // Geri yazma ARTIK BEKLENMEZ ve ana izleği dondurmaz: eskiden burada
    // büyük dosya eşzamanlı kopyalanıyordu (bkz. [SafeWrite]). İş kuyrukta
    // sürer; aynı dosya yeniden açılırsa görüntüleyici onu bekler.
    unawaited(_restoreOriginal());
    super.dispose();
  }

  // ── Bekleyen (kaydedilmemiş) PDF düzenlemeleri ────────────────────────────

  // ── Belge içi arama ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final hasApiKey = context.watch<AppState>().hasApiKey;
    // Bekleyen PDF düzenlemesi varken geri tuşu doğrudan çıkmaz: önce
    // "kaydetmek ister misiniz?" sorulur (2026-07-26 kullanıcı isteği).
    final textUnsaved = _dirty && doc.kind == DocKind.text;
    return PopScope(
      canPop: !_hasUnsaved && !textUnsaved && _pdfWriting == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (textUnsaved) {
          // Metin düzenleyici: altı editörün ortak çıkış sorusu (Faz 20) —
          // eskiden yazılan metin geri tuşuyla sessizce kayboluyordu.
          final nav = Navigator.of(context);
          final choice = await showUnsavedChanges(this.context);
          switch (choice) {
            case UnsavedChoice.save:
              await _save();
              if (!_dirty && nav.mounted) nav.pop();
            case UnsavedChoice.discard:
              if (nav.mounted) nav.pop();
            case UnsavedChoice.cancel:
              break;
          }
          return;
        }
        final leave = await _confirmLeavePending();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: _buildShell(doc, hasApiKey),
    );
  }

  /// [ViewerScreen.startInk] bir kez uygulanır.
  bool _inkStarted = false;

  static String _shorten(String s, int max) {
    final t = s.replaceAll('\n', ' ').trim();
    return t.length <= max ? '“$t”' : '“${t.substring(0, max)}…”';
  }

  // ── Faz 4: okuma deneyimi ─────────────────────────────────────────────────

  // ── OCR ───────────────────────────────────────────────────────────────────

  // ── Uzun belgede gezinme ──────────────────────────────────────────────────


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
