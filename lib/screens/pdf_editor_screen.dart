import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../core/app_icons.dart';
import '../core/app_state.dart';
import '../core/edit/edit_session.dart';
import '../core/edit/editor_chrome.dart';
import '../core/edit/editor_shortcuts.dart';
import '../core/motion.dart';
import '../core/l10n/app_strings.dart';
import '../services/gemini_service.dart';
import '../services/pdf/pdf_edit_history.dart';
import '../services/pdf/pdf_fling.dart';
import '../services/pdf/pdf_form.dart';
import '../services/pdf/pdf_pending_objects.dart';
import '../services/pdf/pdf_ocr_text.dart';
import '../services/pdf/pdf_scanned_retype.dart';
import '../services/pdf_page_edit.dart';
import '../services/pdf_reload.dart';
import '../services/pdf_tools.dart';
import '../services/scan_ai_fix.dart';
import '../services/scan_text_fix.dart';
import '../widgets/app_dialog.dart';
import '../widgets/office_ribbon.dart';
import '../widgets/pdf_edit_overlay.dart';
import '../widgets/pdf_object_layer.dart';
import '../widgets/signature_pad.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/pdf_save_dialog.dart';
import '../core/snack.dart';
import '../core/user_error.dart';
import '../widgets/ai_key_gate.dart';
import '../core/theme.dart';

part 'pdf_editor/actions.dart';
part 'pdf_editor/views.dart';
part 'pdf_editor/layer.dart';

/// **Tek PDF düzenleme ekranı** — metin, görsel, filigran ve sayfa işlerinin
/// hepsi burada (2026-07-27 kullanıcı isteği: *"tüm bu işler tek bir pdf
/// düzenleme editör sayfasında yapılmalı"*).
///
/// Akış tasarımı, kullanıcının tarif ettiği gibi:
/// 1. Bir mod seç (alt çubuk: Metin · Görsel · Filigran · Sayfa),
/// 2. sayfada düzenlenecek öğeye dokun — çerçeveli kutular neyin
///    düzenlenebilir olduğunu peşinen gösterir, kullanıcı aramak zorunda değil,
/// 3. küçük bir pencerede düzenle → **Uygula** → sonuç HEMEN sayfada görünür,
/// 4. beğenmediysen **Geri al**,
/// 5. **Kaydet** → *Orijinali değiştir* / *Kopyasını kaydet* / *Klasör seç*.
///
/// Özgün dosyaya kaydedilene kadar DOKUNULMAZ: bütün düzenlemeler geçici bir
/// çalışma kopyasında yapılır. Kullanıcı vazgeçerse hiçbir iz kalmaz.
class PdfEditorScreen extends StatefulWidget {
  final String path;
  final int initialPage;

  const PdfEditorScreen({
    super.key,
    required this.path,
    this.initialPage = 1,
  });

  /// Ekranı açar; bir şey kaydedildiyse `true` döner (çağıran tazelesin).
  static Future<bool> open(
    BuildContext context, {
    required String path,
    int initialPage = 1,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PdfEditorScreen(path: path, initialPage: initialPage),
      ),
    );
    return saved ?? false;
  }

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

/// Şerit sekmeleri = düzenleme kipleri (Faz 31: Office editörleriyle aynı
/// şerit dili; eskiden alt `NavigationBar`).
enum _EditMode { text, image, sign, form, background, page }

/// Yerinde alanın özgün geometrisi (PDF noktası) — bkz. `_inlineGeometry`.
typedef _InlineGeom = ({
  PdfRect box,
  String original,
  int lines,
  double basePt,
  double? lineHeight,
  TextAlign align,
});

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  /// Bu ekranın mesajları uzun asenkron işlerin **içinden** üretiliyor
  /// (`_run`, `_apply`, `catch` dalları); orada `context` kullanmak
  /// `use_build_context_synchronously` demektir. Dil uygulama genelinde tek
  /// olduğu için statik olan okunur. Doğrudan çizilen parçalarda `context.t`.
  AppStrings get _str => AppStrings.current;

  final _controller = PdfViewerController();

  /// Çalışma kopyası — özgün dosyaya kaydedene kadar hiç dokunulmaz.
  Directory? _workDir;
  String? _workPath;

  /// **İşlem listesi** (Faz 31 / PD4): geri al + yinele, belge bellekte,
  /// disk kopyası yok; eklenen nesneler ve form değerleri de adım olarak.
  PdfEditHistory<PdfOverlayLayer>? _history;

  bool get _dirty => _history?.dirty ?? false;
  PdfOverlayLayer get _layer => _history?.layer ?? PdfOverlayLayer.empty;

  _EditMode _mode = _EditMode.text;
  int _page = 1;
  int _pageCount = 0;
  PdfPageOutline _outline = PdfPageOutline.empty;

  /// Sayfa çözümlemesi REDDEDİLDİYSE sebebi (şeritte kalıcı olarak yazar).
  ///
  /// Kullanıcı bulgusu 2026-09-04: bir belgede hem "gömülü görsel yok" hem
  /// "düzenlenebilir metin yok" yazıyordu, oysa sayfada iki büyük görsel
  /// duruyordu. Çözümleme aslında HATA vermişti; hata bir anlık şeritte
  /// geçip gidiyor, geriye "boş sayfa" mesajı kalıyordu. Artık sebep ekranda
  /// duruyor — kullanıcı da, biz de neyin olmadığını görebiliyoruz.
  String? _outlineError;
  List<PdfBackgroundEntry> _background = const [];
  final Set<int> _backgroundPicked = {};

  int? _selectedObject;

  /// Süren jest iki parmaklı mı — fırlatma sürtünmesi (bkz. [kPdfPanFriction]).
  bool _pinch = false;
  bool _busy = false;

  /// Meşgulken ne yapıldığı (ipucu şeridinde) — bkz. `_setBusy`.
  String? _busyNote;
  bool _ready = false;
  String? _error;

  // ── Taranmış sayfa düzenleme (2026-08-06: "taranmış belge deyip düzenleme
  // yaptırmıyor — PDF'de yapılabilmeli") ───────────────────────────────────
  /// Bu oturumda "taranmış" olarak sınıflanan sayfalar (1-tabanlı). YAPIŞKAN:
  /// bir satırın üstüne yazılınca sayfada gerçek metin oluşur ve paragraf
  /// sayısı artar; sınıf değişseydi kalan OCR satırları düzenlenemez kalırdı.
  final Set<int> _scannedPages = {};

  /// Açık sayfanın OCR satırları (yalnız taranmış sayfada dolu).
  List<ScannedLine> _scannedLines = const [];

  /// [_scannedLines] hangi (belge sürümü, sayfa) için yüklendi.
  String _scannedKey = '';
  bool _scannedLoading = false;

  /// Her başarılı düzenlemede artar — OCR kutuları yeniden yüklensin.
  int _docRev = 0;

  /// "Yazı ekle" yerleştirme kipi: sıradaki dokunuş yazının yeridir.
  bool _placingText = false;

  /// Açık sayfanın katman ölçeği (katman pikseli / PDF noktası) ve görünen
  /// ölçüsü (PDF noktası) — kaplama kurucusundan güncellenir.
  double _pageScale = 1;
  Size _pageViewSize = Size.zero;

  // ── Yerinde paragraf düzenleme (Faz 31 / PD1–PD2) ──────────────────────
  int? _inlineIndex;

  /// Yerinde düzenlenen OCR satırı (taranmış sayfa) — paragrafla aynı alan.
  int? _inlineScanned;

  /// Uygulanıyor: alan yeni metinle, salt okunur, sayfa yenilenene kadar.
  bool _inlineApplying = false;

  /// Alanın son çizildiği özgün kutu (uygularken donar).
  _InlineGeom? _inlineGeom;
  TextEditingController? _inlineCtrl;
  final FocusNode _inlineFocus = FocusNode();

  /// Kullanıcının seçtiği punto (null → özgün).
  double? _inlineSize;

  /// Arka plan denemesinin reddi (satır içinde gösterilir) / sürüyor mu.
  String? _inlineRefusal;
  bool _inlineChecking = false;
  bool _inlineFits = false;
  Timer? _inlineTimer;
  int _inlineSeq = 0;

  // ── Bekleyen nesneler (Faz 31 / PD3) ───────────────────────────────────
  int _nextObjectId = 1;
  int? _selectedPending;
  int? _editingPending;
  TextEditingController? _pendingCtrl;
  final FocusNode _pendingFocus = FocusNode();

  // ── Sayfa üstünde form (Faz 31 / PD5) ──────────────────────────────────
  List<PdfFormFieldInfo>? _formFields;
  String? _activeField;
  TextEditingController? _fieldCtrl;
  final FocusNode _fieldFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _prepare();
  }

  @override
  void dispose() {
    _inlineTimer?.cancel();
    _inlineCtrl?.dispose();
    _pendingCtrl?.dispose();
    _fieldCtrl?.dispose();
    _inlineFocus.dispose();
    _pendingFocus.dispose();
    _fieldFocus.dispose();
    // Kaydedilmemiş çalışma kopyasını bırakma: geçici klasör silinir.
    final dir = _workDir;
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Silinemezse sistem geçici klasörü zaten temizler.
      }
    }
    super.dispose();
  }

  // ── Veri ──────────────────────────────────────────────────────────────────

  // ── İşlemler ──────────────────────────────────────────────────────────────

  // ── Kaydetme ──────────────────────────────────────────────────────────────

  // ── Arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final history = _history;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Navigator ÖNCE alınıyor: `await`ten sonra `context` kullanmak
        // ekran kapanmışsa hatalı (use_build_context_synchronously).
        final navigator = Navigator.of(context);
        final leave = await _confirmLeave();
        if (leave && mounted) navigator.pop(!_dirty);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.basename(widget.path),
              overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              key: const ValueKey('pdf-undo'),
              tooltip: context.t('common.undo'),
              icon: const Icon(AppIcons.undo),
              onPressed: history == null || !history.canUndo || _busy
                  ? null
                  : _undoLast,
            ),
            IconButton(
              key: const ValueKey('pdf-redo'),
              tooltip: context.t('common.redo'),
              icon: const Icon(AppIcons.redo),
              onPressed: history == null || !history.canRedo || _busy
                  ? null
                  : _redoLast,
            ),
            IconButton(
              tooltip: context.t('common.save'),
              icon: const Icon(AppIcons.save),
              onPressed: !_dirty || _busy
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      if (await _save() && mounted) navigator.pop(true);
                    },
            ),
          ],
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(minHeight: 3),
                )
              : null,
        ),
        // Faz 20 ortak kabuğu: klavye açıkken klavyenin hemen üstünde hızlı
        // çubuk, kapalıyken şerit (sekmeler = kipler).
        // Donanım klavyesi (Faz 33): geri al / yinele / kaydet, Esc, Ctrl+/.
        body: EditorShortcuts(
          undo: history == null || !history.canUndo || _busy ? null : _undoLast,
          redo: history == null || !history.canRedo || _busy ? null : _redoLast,
          save: !_dirty || _busy
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  if (await _save() && mounted) navigator.pop(true);
                },
          escape: _inlineOpen && !_inlineApplying ? _cancelInline : null,
          child: EditorChrome(
            accessory: _accessory(),
            ribbon: _ribbon(),
            body: _body(),
          ),
        ),
      ),
    );
  }

  // ── Küçük yardımcılar ─────────────────────────────────────────────────────



  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
