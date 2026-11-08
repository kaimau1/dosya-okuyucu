import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart' show Archive, ArchiveFile;
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, LogicalKeyboardKey, PlatformException;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_icons.dart';
import '../../core/busy_dialog.dart';
import '../../core/doc_fonts.dart';
import '../../core/edit/edit_history.dart';
import '../../core/edit/save_coordinator.dart' show SaveIsolate;
import '../../core/edit/edit_session.dart';
import '../../core/edit/editor_chrome.dart';
import '../../core/edit/editor_shortcuts.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/text_search.dart';
import '../../models/document.dart';
import '../../services/fm/reading_positions.dart';
import '../../services/fm/safe_write.dart';
import '../../services/conversion_service.dart';
import '../../services/fm/activity_log.dart';
import '../../services/fm/save_to_downloads.dart';
import '../../services/ocr_service.dart' show OcrLine;
import '../../services/pptx/pro/pptx_arrange_ops.dart';
import '../../services/pptx/pro/pptx_chart_ops.dart';
import '../../services/pptx/pro/pptx_media_ops.dart';
import '../../services/pptx/pro/pptx_package.dart';
import '../../services/pptx/pro/pptx_shape_ops.dart';
import '../../services/pptx/pro/pptx_show_info.dart';
import '../../services/pptx/pro/slides_native.dart';
import '../../services/pptx/pro/pptx_templates.dart';
import '../../services/pptx_editor.dart';
import '../../services/pptx_render.dart';
import '../../services/pptx_rich_text.dart';
import '../../services/slides_pdf.dart';
import 'package:xml/xml.dart' show XmlElement, XmlFindExtension;

import '../../widgets/ai_summary_flow.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_type_chips.dart' show FmChoiceTile;
import '../../core/theme.dart';
import '../../widgets/doc_action_bar.dart';
import '../../widgets/editor_top_bar.dart';
import '../../widgets/state_views.dart';
import '../../widgets/share_export_sheet.dart';
import '../../widgets/doc_find_bar.dart';
import '../../widgets/office_ribbon.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/pinch_zoom_area.dart';
import '../../widgets/slide_box_editor.dart';
import '../../widgets/slide_canvas.dart';
import '../../widgets/slide_text_controller.dart';
import '../../widgets/slide_snapshot.dart';
import '../../widgets/translate_flow.dart';
import '../../widgets/quick_sheets.dart';
import '../../widgets/download_action.dart';
import '../chat_screen.dart';
import 'slideshow_screen.dart';
import 'slides_pro/arrange_page.dart';
import 'slides_pro/chart_page.dart';
import 'slides_pro/master_page.dart';
import 'slides_pro/pro_common.dart';
import 'slides_pro/sections_page.dart';
import 'slides_pro/shape_library.dart';
import '../../core/snack.dart';
import '../../core/safe_insets.dart';
import '../../core/user_error.dart';
import '../../core/app_colors.dart';
import '../fm/pick_file_screen.dart';

part 'slides/actions.dart';
part 'slides/objects.dart';
part 'slides/outline.dart';
part 'slides/pro.dart';
part 'slides/pro_shapes.dart';
part 'slides/sorter.dart';
part 'slides/text_edit.dart';
part 'slides/views.dart';
part 'slides/share_export.dart';

/// Slaytlar PowerPoint'teki gibi **gerçek tasarımıyla** çizilir. Faz 28
/// (PowerPoint mobil dili): şekle dokunmak onu SEÇER (çerçeve + tutamaklar +
/// alttaki bağlam çubuğu), ikinci dokunuş / çift dokunuş metni DÜZENLER —
/// kanvas kutuya yakınlaşır, yazı okunur boyda, biçim seçime göre. Kaydederken
/// orijinal tasarım korunur; el değmeyen run'lar aynen yazılır.
class SlidesEditorScreen extends StatefulWidget {
  /// Konum rozetinin anahtarı. Testte rozeti "sondaki InkWell" diye aramak
  /// kırılgan olurdu (slayt kanvası ve alt çubuk da InkWell içeriyor).
  static const badgeKey = ValueKey('slideBadge');

  /// Desteyi ayrı izolatta çöz (Faz 28 / SL7). Testte kapatılır: flutter_test
  /// sahte saatinde izolat yanıtı beklenemez.
  @visibleForTesting
  static bool parseInIsolate = true;

  /// Son yakınlaşmanın çarpanı (punto → dp) — "yazı ≥ 16 dp" testi için.
  @visibleForTesting
  static double? lastFocusScale;

  final String path;
  final String name;
  final String plainText;
  const SlidesEditorScreen({
    super.key,
    required this.path,
    required this.name,
    required this.plainText,
  });

  @override
  State<SlidesEditorScreen> createState() => _SlidesEditorScreenState();
}

/// PDF'e basarken slayt puntosunun kaç katı piksel üretileceği.
///
/// 2 = okunur keskinlik, makul dosya. Yükseltmek yazıyı netleştirir ama her
/// slayt kare kare belleğe alındığı için 40 slaytlık bir destede telefonu
/// zorlar; düşürmek başlıkları bulanıklaştırır.
const _pdfPixelRatio = 2.0;

class _SlidesEditorScreenState extends State<SlidesEditorScreen>
    with
        DraftRecoveryMixin<SlidesEditorScreen>,
        SingleTickerProviderStateMixin<SlidesEditorScreen> {
  PptxEditor? _editor;
  String? _error;
  /// Faz 20: kirli durum, kaydetme durumu, taslak ve otomatik kaydetme.
  late final EditSession _session = EditSession(
    sourcePath: widget.path,
    editor: 'slides',
    save: _writeFile,
    snapshot: () async => _editor?.saveAsync(),
  );

  /// Destenin geri al geçmişi (Faz 28 / madde 9): metin onayı, şekil ve
  /// slayt işlemleri, not — her biri önce/sonra anlık görüntüsüyle.
  final EditHistory _history = EditHistory(limit: 60);

  // Tüm slaytlar alt alta akar (kullanıcı kararı 2026-07-22: sayfa sayfa değil);
  // pinch zoom ortak PinchZoomArea'dan (Excel'le aynı his). Zoom > 1'de yatay
  // kaydırma açılır, ofsetler commit'te oranla düzeltilir.
  double _zoom = 1;
  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();

  // ── Konum / gezinme ────────────────────────────────────────────────────────
  // Slaytlar tek bir akışta olduğu için "kaçıncı slayttayım" bilgisi ancak
  // kaydırma konumundan çıkar. Kart yükseklikleri ANALİTİK olarak biliniyor
  // (bkz. _slideExtent), o yüzden hem rozet hem "slayta git" ölçüm yapmadan,
  // tek karede doğru sonucu verir — ölçüme dayansaydı henüz çizilmemiş bir
  // slayda atlanamazdı.
  double _baseW = 0;
  int _currentSlide = 1;

  /// Kaldığın yerden devam: dosya boyutu (kayıt anahtarı, bkz. [ReadingPositions]).
  int _docSize = 0;

  /// Arama çubuğu açık mı, eşleşmeler ve etkin eşleşme.
  bool _finding = false;
  final _findCtrl = TextEditingController();
  List<SectionHit> _hits = const [];
  bool _hitLimit = false;
  int _hitIndex = -1;

  // ── Seçim (Faz 28 / madde 1) ───────────────────────────────────────────────
  PptxSlide? _selSlide;
  ShapeVM? _selShape;

  /// Kes/kopyala ile alınan şeklin XML'i (uygulama içi pano).
  String? _clipShape;

  // ── Metin düzenleme (Faz 28) ───────────────────────────────────────────────
  PptxSlide? _editSlide;
  ShapeVM? _editShapeVM;
  SlideTextController? _textCtrl;
  final FocusNode _textFocus = FocusNode();
  final FormatPanelController _panel = FormatPanelController();
  late final AnimationController _zoomAnim;
  ScrollController? _focusH, _focusV;

  set _focusScaleNow(double k) => SlidesEditorScreen.lastFocusScale = k;

  // ── Anahat (Faz 28 / madde 7) ──────────────────────────────────────────────
  bool _outline = false;

  // ── Küçük resim şeridi (Faz 29b) ───────────────────────────────────────────
  bool _strip = true;

  /// Şeridin kaydırıcısı: ana görünümde slayt değişince güncel küçük resim
  /// şeridin ortasına gelir (2026-11-04 önizleme turu — eskiden şerit yerinde
  /// duruyor, 20. slayttayken şeritte 1–3 görünüyordu).
  final ScrollController _stripCtrl = ScrollController();

  // ── Düzenleme sonrası vurgu (2026-11-01) ───────────────────────────────────
  // Düzenlenen kutu okumaya dönünce ~1,2 sn ince çerçeveyle gösterilir.
  PptxSlide? _flashSlide;
  Rect? _flashRect;
  double? _editOffset;
  Timer? _flashTimer;
  final Map<(PptxSlide, PptxParagraph), String> _outlinePending = {};

  // ── Faz 38 — pro araçlar ───────────────────────────────────────────────────
  bool _proOn = true;
  bool _proBusy = false;
  final List<Uint8List> _proUndo = [];

  @override
  void initState() {
    super.initState();
    _zoomAnim = AnimationController(vsync: this, duration: Motion.long);
    _vCtrl.addListener(_onScroll);
    _load();
    unawaited(_loadProFlag());
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _session.dispose();
    _history.dispose();
    _textCtrl?.dispose();
    _textFocus.dispose();
    _panel.dispose();
    _zoomAnim.dispose();
    _focusH?.dispose();
    _focusV?.dispose();
    unawaited(ReadingPositions.save());
    _vCtrl.removeListener(_onScroll);
    _hCtrl.dispose();
    _vCtrl.dispose();
    _stripCtrl.dispose();
    _findCtrl.dispose();
    super.dispose();
  }

  // ── Konum, "slayta git" ve arama ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    final editing = _editShapeVM != null && _textCtrl != null;
    final selected = _selShape != null && !editing;
    // GERİ TUŞU (2026-08-01 kullanıcı bulgusu: *"düzenleme başladığında geri
    // tuşu düzenlemeyi kapatmalı, direk geri gidiyor"*). Geri tuşu en üstteki
    // katmanı kapatır: düzenleme → seçim → anahat → arama; ekrandan çıkmaz.
    return EditExitGuard(
      session: _session,
      hasOpenLayer: editing || selected || _outline || _finding,
      closeLayer: () {
        if (editing) {
          _finishEdit();
        } else if (selected) {
          _clearSelection();
        } else if (_outline) {
          _toggleOutline();
        } else if (_finding) {
          _toggleFind();
        }
      },
      child: EditorShortcuts(
      save: editor == null ? null : _save,
      find: editor == null ? null : _toggleFind,
      undo: editor == null ? null : _undoDeck,
      redo: editor == null ? null : _redoDeck,
      bold: editing ? _textCtrl!.toggleBold : null,
      italic: editing ? _textCtrl!.toggleItalic : null,
      underline: editing ? _textCtrl!.toggleUnderline : null,
      extraHelp: [('⇥ · ⇧⇥', context.t('ks.s_tab'))],
      child: OfficeShell(
        kind: DocKind.slides,
        title: widget.name,
        session: _session,
        subtitle: (editor?.slides.length ?? 0) > 0
            ? context.t('shell.slides', {'n': editor!.slides.length})
            : null,
        // Bütün eylemler ALT çubukta (2026-07-28 kullanıcı isteği: aynı işlev
        // iki yerde durmasın). Üstte yalnız geri al/yinele, anahat, arama;
        // metin düzenlenirken Kaydet (alt çubuk gizli).
        // Faz 40 / 1: ortak üst çubuk sırası (kaydet · ↶ · ↷ · anahat · ara ·
        // ⋮). Metin düzenlenirken ↶ ↷ metin alanının kendi geçmişinde.
        actions: EditorTopBar.actions(
          context,
          onSave: editor == null ? null : _save,
          history: _history,
          undoKey: const ValueKey('sl-undo'),
          undo: editing
              ? null
              : () =>
                  _history.canUndo || _proUndo.isNotEmpty ? _undoDeck : null,
          redo: editing ? null : () => _history.canRedo ? _redoDeck : null,
          extras: [
            if (!editing)
              IconButton(
                key: const ValueKey('sl-outline'),
                tooltip: context.t('sl.outline'),
                isSelected: _outline,
                icon: const Icon(AppIcons.outline),
                onPressed: editor == null ? null : _toggleOutline,
              ),
            if (!editing && !_outline)
              IconButton(
                tooltip: context.t('common.search'),
                icon: const Icon(AppIcons.search),
                onPressed: editor == null ? null : _toggleFind,
              ),
          ],
          menu: [
            EditorMenuItem(
              id: 'export',
              icon: AppIcons.share,
              label: context.t('ux.share_export'),
              onTap: editor == null ? null : _shareExport,
            ),
            EditorMenuItem(
              id: 'pdf',
              icon: AppIcons.pdf,
              label: context.t('sl.to_pdf'),
              onTap: editor == null ? null : _exportPdf,
            ),
          ],
        ),
        body: withDraftBanner(
          restore: _restoreDraft,
          EditorChrome(
            editing: editing,
            accessory: editing ? _slideAccessory() : null,
            ribbon: editing ? _formatBar() : null,
            panel: _panel,
            panelTabs: [
              FormatPanelTab(label: context.t('sl.tab_font'), builder: _fontPanel),
              FormatPanelTab(
                  label: context.t('sl.tab_paragraph'), builder: _paragraphPanel),
            ],
            body: _error != null
                ? AppErrorView(
                    message: context.t('ux.error_body'),
                    details: context.t('sl.open_failed', {'error': _error}))
                : editor == null
                    ? const AppSkeleton(kind: SkeletonKind.slides)
                    : _outline && !editing
                        ? _outlineView(editor)
                        // Düzenlerken slayt listesi AĞAÇTA kalır (yalnız
                        // gizlenir): eskiden sökülüp dönüşte baştan
                        // kuruluyordu → kaydırma başa atlıyor, ilk karede
                        // takılma oluyordu (kullanıcı 2026-11-01).
                        // expand: gizli liste 0×0 ölçülür, Stack'i küçültmesin.
                        : Stack(fit: StackFit.expand, children: [
                            Offstage(
                              offstage: editing,
                              child: TickerMode(
                                enabled: !editing,
                                child: _withStrip(editor, Column(
                                children: [
                                  if (_finding) _findBar(),
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        _buildSlides(editor),
                                        // Konum rozeti — PDF'teki sayfa rozetiyle
                                        // aynı kurgu ve aynı YER (ortada: sağ altta
                                        // AI düğmesi, sol altta pinch % rozeti).
                                        if (!selected && editor.slides.isNotEmpty)
                                          Positioned(
                                            bottom: 12,
                                            left: 0,
                                            right: 0,
                                            child: Center(
                                              child: _slideBadge(
                                                  editor.slides.length),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              )),
                              ),
                            ),
                            if (editing) Positioned.fill(child: _focusEditor()),
                          ]),
          ),
        ),
        // Etiketli eylem çubuğu (2026-07-28 kullanıcı isteği — PDF'teki gibi).
        // Metin düzenlenirken gizli (klavye üstü çubuk / şerit var); şekil
        // seçiliyken şeklin bağlam çubuğu.
        bottomBar: editing
            ? null
            : selected
                ? _shapeBar()
                : DocActionBar([
                    DocAction(AppIcons.add, context.t('sl.insert'),
                        editor == null ? null : _openInsert),
                    DocAction(AppIcons.palette, context.t('sl.design'),
                        editor == null ? null : _openDesign),
                    if (_proOn)
                      DocAction(AppIcons.handyman, context.t('sp.tools'),
                          editor == null || _proBusy ? null : _openProTools),
                    DocAction(AppIcons.play, context.t('sl.play'),
                        editor == null ? null : () => _play(0)),
                    DocAction(AppIcons.thumbnails, context.t('sl.thumbnails'),
                        editor == null
                            ? null
                            : () => setState(() => _strip = !_strip)),
                    DocAction(AppIcons.sorter, context.t('sl.sorter'),
                        editor == null ? null : _openSorter),
                    DocAction(AppIcons.summarize, context.t('ai.summarize'),
                        editor == null ? null : _summarize),
                    // Kaydet üst çubukta (Faz 40 / 1).
                    DocAction(AppIcons.pdf, context.t('sl.to_pdf'),
                        editor == null ? null : _exportPdf),
                    DocAction(AppIcons.share, context.t('common.share'),
                        editor == null ? null : _export),
                    // Başka uygulamadan açıldıysa dosya özel önbellekte:
                    // doğrudan İndirilenler'e (bkz. [SaveToDownloads]).
                    if (showDownloadAction(widget.path))
                      DocAction(AppIcons.download, context.t('common.download'),
                          editor == null ? null : _download),
                    DocAction(
                      AppIcons.translate,
                      context.t('common.translate'),
                      () => TranslateFlow.run(context, widget.plainText,
                          title: widget.name),
                    ),
                  ]),
        fab: editing || selected
            ? null
            : DocAiButton(
                kind: DocKind.slides,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    fileContext: widget.plainText,
                    fileName: widget.name,
                  ),
                )),
                tooltip: context.t('common.ai'),
              ),
      ),
    ));
  }

  /// Slayt akışına küçük resim şeridini ekler (altta ya da solda).
  Widget _withStrip(PptxEditor editor, Widget body) {
    if (!_strip || editor.slides.length < 2) return body;
    if (_stripVertical) {
      return Row(children: [_thumbStrip(editor), Expanded(child: body)]);
    }
    return Column(children: [Expanded(child: body), _thumbStrip(editor)]);
  }

  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
