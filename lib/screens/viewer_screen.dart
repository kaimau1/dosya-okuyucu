import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
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
import '../core/device_profile.dart';
import '../core/screen_awake.dart';
import '../services/pptx/pro/slides_native.dart';
import '../core/pretty_format.dart';
import '../core/text_replace.dart';
import '../core/doc_fonts.dart';
import '../core/image_budget.dart';
import '../widgets/fm/fm_file_image.dart';
import '../core/edit/editor_shortcuts.dart';
import '../core/edit/edit_session.dart';
import '../core/edit/code_editing.dart';
import '../core/edit/code_highlight.dart';
import '../core/edit/code_text_controller.dart';
import '../core/edit/editor_chrome.dart';
import '../core/edit/markdown_edit.dart';
import '../core/l10n/app_strings.dart';
import '../core/app_state.dart';
import '../core/state/focused_states.dart';
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
import '../services/fm/pdf_zoom_memory.dart';
import '../services/fm/reading_positions.dart';
import '../services/fm/safe_write.dart';
import '../services/ocr_service.dart';
import '../services/pdf/edge_auto_scroll.dart';
import '../services/fm/save_to_downloads.dart';
import '../services/pdf/current_page.dart';
import '../services/pdf/pdf_fling.dart';
import '../services/pdf/pdf_selection_target.dart';
import '../services/pdf/pdf_viewer_defaults.dart';
import '../services/pdf/page_arrival.dart';
import '../services/pdf/pdf_form.dart';
import '../services/pdf/pdf_ocr_search.dart';
import '../services/pdf/pdf_reading_zoom.dart';
import '../services/pdf_annotator.dart';
import '../services/pdf_notes.dart';
import '../services/pdf_reload.dart';
import '../services/pdf_tools.dart';
import '../services/tts_service.dart';
import '../services/dictation.dart';
import '../services/voice_note.dart';
import '../widgets/office_ribbon.dart' show OfficeIcons;
import '../widgets/download_action.dart';
import '../widgets/pdf_open_bridge.dart';
import '../widgets/pdf_image_zoom.dart';
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
import '../widgets/fm/archive_password_dialog.dart';
import '../widgets/pdf_action_bars.dart';
import '../widgets/pdf_edit_modes.dart';
import '../widgets/pdf_page_frame.dart';
import '../widgets/large_text_view.dart';
import '../widgets/legacy_banner.dart';
import '../services/legacy_convert.dart';
import '../widgets/pdf_save_dialog.dart';
import '../widgets/quick_sheets.dart';
import '../widgets/pdf_page_navigator.dart';
import '../widgets/pdf_resume_note.dart';
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
import '../core/l10n/app_language.dart';

import '../core/app_haptics.dart';
import 'audiobook/audiobook_screen.dart';
import 'fm/pick_file_screen.dart';
import 'fm/remote/peer_share_screen.dart' show showShareChoice;
import '../core/app_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_action_sheet.dart';
import '../services/pdf/pro/pdf_ai_rewrite.dart';
import '../services/pdf/pro/pdf_pro_images.dart';
import '../widgets/ai_key_gate.dart';
import '../widgets/pdf_pro/pdf_block_layer.dart';
import '../widgets/pdf_pro/pdf_pro_bars.dart';
import '../widgets/pdf_pro/pdf_pro_panels.dart';
import '../widgets/pdf_pro/pdf_pro_edit_controller.dart';
import '../widgets/pdf_pro/pdf_pro_sheets.dart';
import '../services/docs_home.dart';
import '../services/pdf_save.dart';
import '../services/pdf/pro/pdf_edit_access.dart';
import '../services/pdf/pro/pdf_edit_bridge.dart';
import '../services/pdf/pro/pdf_edit_recovery.dart';
import '../services/pdf/pro/pdf_edit_session.dart';
import '../services/pdf/pro/pdf_version_history.dart';
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
part 'viewer/pdf_reading_pro.dart';
part 'viewer/pdf_reading_aids.dart';
part 'viewer/pdf_reading_comfort.dart';
part 'viewer/pdf_pro_edit.dart';
part 'viewer/pdf_pro_tools.dart';

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

  /// Bu oturumda girilen PDF parolası: yeniden okumada (düzenleme dönüşü)
  /// tekrar sorulmasın. Yalnız bellekte.
  String? _pdfPassword;

  /// Elimizdeki parola bu açılışta denendi mi (denendiyse yanlıştır).
  bool _pdfPasswordTried = false;

  /// PDF Pro düzenleme kipi (Faz 54, bayrak `pdf_pro_engine`): null = okuma.
  /// Aynı ekran, aynı belge — bkz. `viewer/pdf_pro_edit.dart`.
  PdfProEditController? _pro;

  /// Kısıtlı belgede sahip parolası bu ekranda doğrulandı.
  bool _proOwnerOk = false;

  /// Yarıda kalmış oturum bu açılışta bir kez sorulur.
  bool _proRecoveryAsked = false;

  /// Yerinde yazmanın gizli klavye girişi (Faz 57).
  final TextEditingController _proInput = TextEditingController();
  final FocusNode _proFocus = FocusNode(debugLabel: 'pdf-pro-input');
  int _proCaretSeen = -1;

  /// Düzenleme kipinde belge olayları: içeriği değişen sayfanın görüntüsü
  /// yeniden çizdirilir (pdfrx geometri aynıysa çizmiyor — third_party/pdfrx/YAMA.md).
  StreamSubscription<PdfDocumentEvent>? _proDocSub;

  void _onProChanged() {
    if (!mounted) return;
    setState(() {});
    // Yazarken imleç klavyenin arkasında kalmasın.
    final live = _pro?.live;
    if (live == null) {
      _proCaretSeen = -1;
      return;
    }
    final mark = live.selEnd * 131 + live.map.length * 7 + live.map.lineCount;
    if (mark != _proCaretSeen) {
      _proCaretSeen = mark;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _proRevealCaret());
    }
  }

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

  /// PS5 (PDF Pro Faz 51): seçim çubuğunun önizlemesi açık mı (yeni seçimde
  /// kapanır) ve çubuk seçimi ÖRTTÜĞÜ için ekranın üstüne mi alındı.
  bool _pdfSelExpanded = false;
  bool _pdfSelBarTop = false;
  Timer? _pdfSelRevealTimer;

  /// Seçim çubuğunun örttüğü yeri ÖLÇMEK için (tahmin yerine).
  final GlobalKey _pdfViewerKey = GlobalKey();
  final GlobalKey _pdfSelBarKey = GlobalKey();

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
  int _tabWidth = 2;

  /// Metin düzenleyicide satır aralığı (Okuma ayarları; Faz 30 kalanı).
  double _lineHeight = 1.5;
  bool _mdPreview = false;

  /// PDF içi arama (Faz 1): pdfrx'in hazır arayıcısı. Eşleşmeleri sayfa sayfa
  /// bulur, sayfada vurgular (pageTextMatchPaintCallback) ve goToNext/PrevMatch
  /// ile o sayfaya kaydırır. Yalnız PDF belgesinde kurulur.
  final PdfViewerController _pdfController = PdfViewerController();

  /// Okuma kipi (Faz 18 / G20): kaydırınca çubuklar çekilir. 2026-10-28:
  /// PDF'te de açık — çubuklar artık gövdenin boyunu değiştirmiyor.
  final ReadingBars _readingBars = ReadingBars();

  /// Süren jest iki parmaklı mı (yakınlaştırma)? Fırlatma sürtünmesi buna
  /// göre seçilir (bkz. [kPdfPanFriction]).
  bool _pdfPinch = false;

  /// Okuma konforu (Ferrari H3): çift dokunma / görsel kipinin okuduğu
  /// sayfa nesneleri (PDF Pro köprüsü) — son birkaç sayfa, belgeye bağlı.
  final Map<int, PdfPageContent> _comfortContent = {};
  PdfDocument? _comfortDoc;

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

  // Okuma yardımcıları (Faz 48) — bkz. viewer/pdf_reading_aids.dart.
  bool _keepAwake = false;
  VoidCallback? _keepAwakeRelease;
  bool _volumeKeys = false;
  StreamSubscription<(String, Object?)>? _volumeSub;
  int _autoScroll = 0;
  int? _autoScrollFrame;
  Duration? _autoScrollLast;
  bool _autoScrollHeld = false;
  VoidCallback? _autoScrollAwake;

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

  /// Kâğıt (sepya) tonu — gece kipinin gündüz karşılığı (A9.2, Faz 39).
  bool _pdfSepia = false;

  /// Kaydırma kilidi: yalnız dikey kaydırma, yakınlaştırma/yatay kayma
  /// kapalı (Faz 39) — okurken sayfa yana kaçmasın.
  bool _pdfScrollLock = false;

  /// Geniş ekranda (≥ 840 dp) sayfa küçük resimleri şeridi açık mı?
  /// Varsayılan KAPALI — içerik önce (Ferrari H1.3); tercih kalıcı.
  bool _pdfSidePanel = false;

  /// Yan şeridin kaydırması (güncel sayfayı izler).
  final ScrollController _sidePanelScroll = ScrollController();

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
    unawaited(_loadReadingAids());
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
        markdown: const {'.md', '.markdown'}
            .contains(p.extension(doc.path).toLowerCase()),
      );
      // Düzenlerken alt eylem çubuğu ve AI düğmesi gizlenir (klavye üstünde
      // iki çubuk + çubuğa binen düğme — kullanıcı 2026-11-12 "panel garip").
      _textFocus.addListener(_onTextFocus);
    }
    if (doc.kind == DocKind.pdf) {
      _prepareSafeOpen();
      // `_pdfSearcher` `onViewerReady`'de kurulur: pdfrx 2.x'in yapıcısı
      // denetleyicinin belgesine hemen abone oluyor ve görüntüleyici
      // bağlanmadan çağrılınca "Null check" ile ekranı düşürüyordu
      // (sürüm 475, her PDF — 2026-11-03 hata kaydı).
      _ocrSearch = PdfOcrSearch()..addListener(_onPdfSearch);
      _pdfController.addListener(_onPdfMatrix);
      // Gecikmeli: tarama aynı dosyayı okur; ilk sayfalar önce çizilsin
      // (USB'de okuma yarışı — 2026-11-14). Zamanlayıcı dispose'ta iptal.
      _formOfferTimer =
          Timer(Motion.afterOpen, () => unawaited(_offerFormFilling()));
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
    if (ReadingPositions.isLoaded && PdfZoomMemory.isLoaded) {
      _applyResumePage();
      return;
    }
    _resumeReady = false;
    try {
      // Yakınlık kaydı da görüntüleyici kurulmadan bilinmeli (açılış ölçeği).
      await Future.wait(
          [ReadingPositions.ensureLoaded(), PdfZoomMemory.ensureLoaded()]);
    } finally {
      if (mounted) {
        setState(() {
          _applyResumePage();
          _resumeReady = true;
        });
      }
    }
  }

  /// Açılış yakınlığı (yalnız tek sütun): belgenin kayıtlı yakınlığı, yoksa
  /// tablette sayfanın tamamı, telefonda pdfrx varsayılanı (bkz.
  /// [PdfZoomMemory]).
  double? _pdfInitialZoom(PdfDocument document, PdfViewerController controller,
          double fitZoom, double coverZoom) =>
      PdfZoomMemory.initialZoom(widget.doc.path,
          shortestSide: MediaQuery.sizeOf(context).shortestSide,
          fitZoom: fitZoom);

  /// Kullanıcının yakınlığını belge için saklar (tek sütunda).
  void _recordPdfZoom() {
    if (widget.doc.kind != DocKind.pdf || _pdfColumns != 1) return;
    if (!_pdfController.isReady) return;
    final z = _pdfController.currentZoom;
    if (z > 0) unawaited(PdfZoomMemory.record(widget.doc.path, z));
  }

  void _applyResumePage() {
    final page = ReadingPositions.pageOf(widget.doc.path, size: _docSize);
    if (page == null || page <= 1) return;
    _pdfPage = page;
    _resumedPage = page;
  }

  /// Devam edilen sayfa (bir kez şerit gösterilir), yoksa null.
  int? _resumedPage;

  /// Ekranda görünen "N. sayfadan devam ediliyor" notu (yoksa null).
  int? _resumeNotePage;

  /// "42. sayfadan devam ediliyor · Baştan başla" notu.
  ///
  /// Sessizce ortadan açmak "belge bozuk mu?" dedirtiyor; bir cümle + tek
  /// dokunuşluk geri dönüş yolu bırakılıyor. Alttaki SnackBar yerine sayfanın
  /// üstünde okuma kipine uygun ince hap ([PdfResumeNote], 2026-11-02).
  void _showResumeNotice() {
    final page = _resumedPage;
    if (page == null || !mounted) return;
    _resumedPage = null;
    _partSetState(() => _resumeNotePage = page);
  }

  void _restartFromFirstPage() {
    ReadingPositions.clear(widget.doc.path);
    _pdfJumpTarget = 1;
    _pdfController.goToPage(pageNumber: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ekran ölçüsü ilk kez burada bilinir; çözme genişliği ona göre kurulur.
    if (widget.doc.kind == DocKind.image) _onImgTransform();
  }

  /// [_offerFormFilling]'in gecikme zamanlayıcısı.
  Timer? _formOfferTimer;

  /// Belge yüklendi ve ilk sayfaya çizim payı geçti → açılış köprüsü
  /// ([PdfOpenBridge]) solar (Ferrari H1.1).
  bool _pdfOpened = false;
  Timer? _pdfBridgeTimer;

  /// Köprüyü kaldırır; pdfrx sayfayı `onViewerReady`den SONRA çiziyor, o
  /// arada kâğıt beyaz kalmasın diye kısa pay ([Motion.medium]).
  void _markPdfOpened() {
    if (_pdfOpened) return;
    _pdfBridgeTimer?.cancel();
    _pdfBridgeTimer = Timer(Motion.medium, () {
      if (mounted) _partSetState(() => _pdfOpened = true);
    });
  }

  /// Belge doldurulabilir bir form mu ([_offerFormFilling] bulur)?
  bool _pdfIsForm = false;

  /// Belge doldurulabilir bir formsa üst çubukta **"Formu doldur"** düğmesi
  /// belirir (İçindekiler'in yerine).
  ///
  /// Menüdeki "Formu doldur" tek başına keşfedilmiyor: kullanıcı bir form
  /// PDF'ini açtığında yapabileceği ilk şey onu doldurmaktır ve bunu ⋮
  /// menüsünde aramaz. Bakış ucuz (dosyada `/AcroForm` anahtarı aranır),
  /// yanlış pozitifte ekran zaten "form alanı yok" diyor.
  ///
  /// Eskiden 4 sn'lik SnackBar'dı (Ferrari H1.2, 2026-11-14): "N. sayfadan
  /// devam" hapıyla aynı anda çıkıp alt kenarı kapatıyordu, ders kitaplarında
  /// da (yanlış alarm) her açılışta. Düğme kalıcı ve sessiz.
  Future<void> _offerFormFilling() async {
    if (!await PdfFormFiller.looksLikeForm(widget.doc.path)) return;
    if (!mounted) return;
    _partSetState(() => _pdfIsForm = true);
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
    _recordPdfZoom();
    _formOfferTimer?.cancel();
    _pdfBridgeTimer?.cancel();
    _pdfController.removeListener(_onPdfMatrix);
    // Kaydedilmemiş düzenleme varsa çökme kaydı kalır (yeniden açılışta sunulur).
    _pro
      ?..removeListener(_onProChanged)
      ..dispose();
    _proDocSub?.cancel();
    _proInput.dispose();
    _proFocus.dispose();
    _readingBars.dispose();
    _disposeReadingAids();
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _pdfEdgeScrollTimer?.cancel();
    _pdfSelRevealTimer?.cancel();
    _textController?.dispose();
    _undoCtl.dispose();
    _textScroll.dispose();
    _imgTx.removeListener(_onImgTransform);
    _imgTx.dispose();
    _findCtl.dispose();
    _replaceCtl.dispose();
    _textFocus.removeListener(_onTextFocus);
    _textFocus.dispose();
    _pdfSearcher
        ?.dispose(); // PdfViewerController = ValueListenable, dispose'suz
    _ocrSearch?.dispose();
    _sidePanelScroll.dispose();
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
    final hasApiKey = context.watchAi().hasApiKey;
    // Bekleyen PDF düzenlemesi varken geri tuşu doğrudan çıkmaz: önce
    // "kaydetmek ister misiniz?" sorulur (2026-07-26 kullanıcı isteği).
    final textUnsaved = _dirty && doc.kind == DocKind.text;
    return PopScope(
      canPop:
          !_hasUnsaved && !textUnsaved && _pdfWriting == 0 && _pro == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Düzenleme kipi: geri önce okuma kipine döndürür (etkileşim §8).
        if (_pro != null) {
          await _exitProEdit();
          return;
        }
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
      // Donanım klavyesi (Faz 33): düzenlenebilir metinde Ctrl+S/Z/Y/F, Ctrl+/.
      child: doc.isEditableText
          ? EditorShortcuts(
              save: _save,
              undo: _undoCtl.undo,
              redo: _undoCtl.redo,
              find: _toggleFind,
              child: _buildShell(doc, hasApiKey),
            )
          : _buildShell(doc, hasApiKey),
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

  /// Metin düzenleniyor mu (odak alanda)? Öyleyse alt çubuk/AI düğmesi gizli.
  bool get _editingText =>
      widget.doc.isEditableText && _textFocus.hasFocus;

  void _onTextFocus() {
    if (mounted) setState(() {});
  }
}
