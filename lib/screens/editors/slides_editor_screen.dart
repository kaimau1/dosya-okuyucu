import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:share_plus/share_plus.dart';

import '../../core/app_icons.dart';
import '../../core/busy_dialog.dart';
import '../../core/doc_fonts.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/text_search.dart';
import '../../models/document.dart';
import '../../services/fm/safe_write.dart';
import '../../services/conversion_service.dart';
import '../../services/fm/activity_log.dart';
import '../../services/fm/save_to_downloads.dart';
import '../../services/ocr_service.dart' show OcrLine;
import '../../services/pptx_editor.dart';
import '../../services/pptx_render.dart';
import '../../services/slides_pdf.dart';
import '../../widgets/ai_summary_flow.dart';
import '../../widgets/doc_action_bar.dart';
import '../../widgets/doc_find_bar.dart';
import '../../widgets/office_ribbon.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/pinch_zoom_area.dart';
import '../../widgets/slide_canvas.dart';
import '../../widgets/slide_snapshot.dart';
import '../../widgets/translate_flow.dart';
import '../../widgets/quick_sheets.dart';
import '../../widgets/download_action.dart';
import '../chat_screen.dart';
import 'slideshow_screen.dart';
import '../../core/snack.dart';
import '../../core/safe_insets.dart';
import '../../core/user_error.dart';

part 'slides/actions.dart';
part 'slides/views.dart';

/// Slaytlar PowerPoint'teki gibi **gerçek tasarımıyla** çizilir; bir metin
/// kutusuna dokunmak o kutunun yazılarını düzenlemeyi açar. Kaydederken orijinal
/// tasarım korunur (yalnızca metin güncellenir).
class SlidesEditorScreen extends StatefulWidget {
  /// Konum rozetinin anahtarı. Testte rozeti "sondaki InkWell" diye aramak
  /// kırılgan olurdu (slayt kanvası ve alt çubuk da InkWell içeriyor).
  static const badgeKey = ValueKey('slideBadge');

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

class _SlidesEditorScreenState extends State<SlidesEditorScreen> {
  PptxEditor? _editor;
  String? _error;
  bool _dirty = false;

  // Tüm slaytlar alt alta akar (kullanıcı kararı 2026-07-22: sayfa sayfa değil);
  // pinch zoom ortak PinchZoomArea'dan (Excel'le aynı his). Zoom > 1'de yatay
  // kaydırma açılır, ofsetler commit'te oranla düzeltilir.
  double _zoom = 1;
  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();

  /// Konuşmacı notu şeridi AÇIK olan slaytların dosya adları. Slayt sırası
  /// değişebildiği için indeks değil dosya adı tutulur.
  final _openNotes = <String>{};

  // ── Konum / gezinme ────────────────────────────────────────────────────────
  // Slaytlar tek bir akışta olduğu için "kaçıncı slayttayım" bilgisi ancak
  // kaydırma konumundan çıkar. Kart yükseklikleri ANALİTİK olarak biliniyor
  // (bkz. _slideExtent), o yüzden hem rozet hem "slayta git" ölçüm yapmadan,
  // tek karede doğru sonucu verir — ölçüme dayansaydı henüz çizilmemiş bir
  // slayda atlanamazdı.
  double _baseW = 0;
  int _currentSlide = 1;

  /// Arama çubuğu açık mı, eşleşmeler ve etkin eşleşme.
  bool _finding = false;
  final _findCtrl = TextEditingController();
  List<SectionHit> _hits = const [];
  bool _hitLimit = false;
  int _hitIndex = -1;

  // ── Canlı (yerinde) metin düzenleme durumu ─────────────────────────────────
  // Popup yerine kutu doğrudan slaytın üstünde TextField olur; biçim çubuğu
  // klavyenin üstünde yüzer. Denetleyiciler şeklin paragraflarıyla hizalıdır.
  PptxSlide? _editSlide;
  ShapeVM? _editShapeVM;
  final List<TextEditingController?> _editCtrls = [];
  final List<PptxParagraph?> _editTargets = [];
  bool _fBold = false, _fItalic = false, _fUnder = false;
  double _fSize = 18;
  /// Seçili kutunun yazı tipi (belgede yazılı ÖZGÜN ad; boş = tema fontu).
  String _fFont = '';
  bool _tBold = false, _tItalic = false, _tUnder = false, _tSize = false;
  bool _tFont = false;

  @override
  void initState() {
    super.initState();
    _vCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    for (final c in _editCtrls) {
      c?.dispose();
    }
    _vCtrl.removeListener(_onScroll);
    _hCtrl.dispose();
    _vCtrl.dispose();
    _findCtrl.dispose();
    super.dispose();
  }

  // ── Konum, "slayta git" ve arama ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    final editing = _editShapeVM != null;
    // GERİ TUŞU (2026-08-01 kullanıcı bulgusu: *"düzenleme başladığında geri
    // tuşu düzenlemeyi kapatmalı, direk geri gidiyor"*). Metin kutusu açıkken
    // geri, yazılanı kaydedip düzenlemeyi kapatır; ekrandan çıkmaz. Aynısı
    // arama çubuğu için de geçerli — geri tuşu en üstteki katmanı kapatır.
    return PopScope(
      canPop: !editing && !_finding,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (editing) {
          _finishEdit();
        } else if (_finding) {
          _toggleFind();
        }
      },
      child: OfficeShell(
        kind: DocKind.slides,
        title: widget.name,
        dirty: _dirty,
        subtitle: (editor?.slides.length ?? 0) > 0
            ? context.t('shell.slides', {'n': editor!.slides.length})
            : null,
        // Bütün eylemler ALT çubukta (2026-07-28 kullanıcı isteği: aynı işlev
        // iki yerde durmasın). İstisna: metin kutusu düzenlenirken alt çubuk
        // gizlendiği için Kaydet buraya çıkar; arama da altta karşılığı
        // olmadığı için üstte durur (Excel'le aynı yer).
        actions: [
          if (editing)
            IconButton(
              tooltip: context.t('common.save'),
              icon: const Icon(AppIcons.save),
              onPressed: editor == null ? null : _save,
            ),
          if (!editing)
            IconButton(
              tooltip: context.t('common.search'),
              icon: const Icon(AppIcons.search),
              onPressed: editor == null ? null : _toggleFind,
            ),
        ],
        body: _error != null
            ? Center(child: Text(context.t('sl.open_failed', {'error': _error})))
            : editor == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_finding) _findBar(),
                      Expanded(
                        child: Stack(
                          children: [
                            _buildSlides(editor),
                            // Konum rozeti — PDF'teki sayfa rozetiyle aynı
                            // kurgu ve aynı YER: nerede olduğunu söyler ve
                            // dokununca "slayta git"i açar.
                            //
                            // ORTADA duruyor, sağda değil: sağ altta AI
                            // düğmesi (FAB), sol altta pinch'in % rozeti var —
                            // ilk sürümde sağa konmuştu ve FAB rozeti yarıdan
                            // kesiyordu (2026-08-01 kullanıcı ekran görüntüsü).
                            if (!editing && editor.slides.isNotEmpty)
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _slideBadge(editor.slides.length),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (editing) _formatBar(),
                    ],
                  ),
        // Etiketli eylem çubuğu (2026-07-28 kullanıcı isteği — PDF'teki gibi).
        // Metin kutusu düzenlenirken gizli: altta zaten biçim çubuğu var.
        bottomBar: editing
            ? null
            : DocActionBar([
                DocAction(AppIcons.play, context.t('sl.play'),
                    editor == null ? null : () => _play(0)),
                DocAction(Icons.summarize_rounded, context.t('ai.summarize'),
                    editor == null ? null : _summarize),
                DocAction(AppIcons.save, context.t('common.save'),
                    editor == null ? null : _save),
                DocAction(AppIcons.pdf, context.t('sl.to_pdf'),
                    editor == null ? null : _exportPdf),
                DocAction(AppIcons.share, context.t('common.share'),
                    editor == null ? null : _export),
                // Başka uygulamadan açıldıysa dosya özel önbellekte: doğrudan
                // İndirilenler'e (bkz. [SaveToDownloads]).
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
        fab: editing
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
    );
  }




  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
