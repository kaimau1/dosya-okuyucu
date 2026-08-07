import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/doc_fonts.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/text_search.dart';
import '../../models/document.dart';
import '../../services/pptx_editor.dart';
import '../../services/pptx_render.dart';
import '../../widgets/ai_summary_flow.dart';
import '../../widgets/doc_action_bar.dart';
import '../../widgets/office_ribbon.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/pinch_zoom_area.dart';
import '../../widgets/slide_canvas.dart';
import '../../widgets/translate_flow.dart';
import '../chat_screen.dart';
import 'slideshow_screen.dart';

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

  /// Pinch odağındaki içerik yerinde kalsın: (ofset+odak)*çarpan-odak.
  void _fixScroll(double f, Offset focal) {
    if (_hCtrl.hasClients) {
      _hCtrl.jumpTo(((_hCtrl.offset + focal.dx) * f - focal.dx)
          .clamp(0.0, _hCtrl.position.maxScrollExtent));
    }
    if (_vCtrl.hasClients) {
      _vCtrl.jumpTo(((_vCtrl.offset + focal.dy) * f - focal.dy)
          .clamp(0.0, _vCtrl.position.maxScrollExtent));
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      _editor = PptxEditor.parse(bytes);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final editor = _editor;
    if (editor == null) return;
    try {
      final bytes = editor.save();
      await File(widget.path).writeAsBytes(bytes);
      _dirty = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('common.saved_hint'))));
        setState(() {});
      }
    } catch (e) {
      _snack(AppStrings.current.t('common.save_failed', {'error': e}));
    }
  }

  Future<void> _export() async {
    final editor = _editor;
    if (editor == null) return;
    final f = File('${Directory.systemTemp.path}/${widget.name}');
    await f.writeAsBytes(editor.save());
    await Share.shareXFiles([XFile(f.path)], text: widget.name);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ── Konum, "slayta git" ve arama ──────────────────────────────────────────

  int get _slideCount => _editor?.slides.length ?? 0;

  /// Bir slayt kartının listedeki toplam yüksekliği (başlık şeridi + kart +
  /// alt boşluk). `_buildSlides`/`_slideCard` yerleşimiyle BİREBİR aynı
  /// formül — ikisi ayrışırsa "slayta git" yanlış yere atlar.
  double _slideExtent(int i) {
    final cardW = _baseW * _zoom;
    final slide = _editor!.slides[i];
    final view = slide.view;
    final aspect = view == null ? 16 / 9 : view.widthPt / view.heightPt;
    final cardH = aspect <= 0 ? cardW * 9 / 16 : cardW / aspect;
    return 40 * _zoom + cardH + _notesHeight(slide) * _zoom + 20 * _zoom;
  }

  /// Konuşmacı notu şeridinin zoom UYGULANMAMIŞ yüksekliği (not yoksa 0).
  /// `_notesStrip` ile birebir aynı formül — ikisi ayrışırsa "slayta git"
  /// notlu destelerde kayar.
  double _notesHeight(PptxSlide slide) {
    final editor = _editor;
    if (editor == null) return 0;
    if (editor.notesOf(slide).trim().isEmpty) return 0;
    return _openNotes.contains(slide.fileName) ? 30 + 18.0 * 5 : 30;
  }

  /// [i]. slaydın (0 tabanlı) liste içindeki kaydırma konumu.
  double _slideOffset(int i) {
    var offset = 8 * _zoom; // ListView'ın üst dolgusu
    for (var j = 0; j < i; j++) {
      offset += _slideExtent(j);
    }
    return offset;
  }

  /// Kaydırma konumundan "kaçıncı slayttayız". Ekranın üstünden bir tutam
  /// aşağısı (60 px) ölçüt: iki slaydın sınırı tam tepedeyken kullanıcı
  /// gözüyle ALTTAKİ slayda bakıyordur.
  void _onScroll() {
    if (!_vCtrl.hasClients || _baseW <= 0 || _slideCount == 0) return;
    final target = _vCtrl.offset + 60;
    var at = 8 * _zoom;
    var index = 0;
    for (var i = 0; i < _slideCount; i++) {
      at += _slideExtent(i);
      if (at > target) {
        index = i;
        break;
      }
      index = i;
    }
    final next = index + 1;
    if (next != _currentSlide) setState(() => _currentSlide = next);
  }

  /// [number] 1 tabanlı slayt numarasına kaydırır.
  Future<void> _goToSlide(int number) async {
    if (!_vCtrl.hasClients || _slideCount == 0) return;
    final index = (number - 1).clamp(0, _slideCount - 1);
    final target = _slideOffset(index)
        .clamp(0.0, _vCtrl.position.maxScrollExtent);
    await _vCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (mounted) setState(() => _currentSlide = index + 1);
  }

  Future<void> _showGoToSlide() async {
    final total = _slideCount;
    if (total == 0) return;
    final ctrl = TextEditingController(text: '$_currentSlide');
    // Metin SEÇİLİ açılır: kullanıcı numarayı silmeden üstüne yazabilsin.
    ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('sl.goto')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(labelText: ctx.t('sl.goto_hint', {'total': total})),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text(ctx.t('common.go')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null) await _goToSlide(value);
  }

  /// Slaytların düz metni — arama ve AI özeti aynı kaynağı kullanır.
  /// Slayt numarası metne yazılır: özet "3. slaytta…" diyebilsin, arama
  /// sonucu hangi slaytta olduğunu gösterebilsin.
  List<String> _slideTexts() => [
        for (final slide in _editor?.slides ?? const <PptxSlide>[])
          slide.paragraphs.map((p) => p.text).join('\n'),
      ];

  void _toggleFind() {
    setState(() {
      _finding = !_finding;
      if (!_finding) {
        _findCtrl.clear();
        _hits = const [];
        _hitIndex = -1;
        _hitLimit = false;
      }
    });
  }

  void _runSearch(String query) {
    final result = searchSections(_slideTexts(), query);
    setState(() {
      _hits = result.hits;
      _hitLimit = result.hitLimit;
      _hitIndex = _hits.isEmpty ? -1 : 0;
    });
    if (_hits.isNotEmpty) _goToSlide(_hits.first.section + 1);
  }

  void _stepHit(int delta) {
    if (_hits.isEmpty) return;
    final next = (_hitIndex + delta) % _hits.length;
    setState(() => _hitIndex = next < 0 ? _hits.length - 1 : next);
    _goToSlide(_hits[_hitIndex].section + 1);
  }

  /// AI özeti — slayt numaralı düz metinle (bkz. [_slideTexts]).
  Future<void> _summarize() async {
    final texts = _slideTexts();
    final buffer = StringBuffer();
    for (var i = 0; i < texts.length; i++) {
      if (texts[i].trim().isEmpty) continue;
      buffer.writeln(
          context.t('sl.slide_of', {'n': i + 1, 'total': texts.length}));
      buffer.writeln(texts[i].trim());
      buffer.writeln();
    }
    await AiSummaryFlow.run(context, buffer.toString(), title: widget.name);
  }

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
        // Bütün eylemler ALT çubukta (2026-07-28 kullanıcı isteği: aynı işlev
        // iki yerde durmasın). İstisna: metin kutusu düzenlenirken alt çubuk
        // gizlendiği için Kaydet buraya çıkar; arama da altta karşılığı
        // olmadığı için üstte durur (Excel'le aynı yer).
        actions: [
          if (editing)
            IconButton(
              tooltip: context.t('common.save'),
              icon: const Icon(Icons.save_outlined),
              onPressed: editor == null ? null : _save,
            ),
          if (!editing)
            IconButton(
              tooltip: context.t('common.search'),
              icon: const Icon(Icons.search),
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
                DocAction(Icons.play_arrow, context.t('sl.play'),
                    editor == null ? null : () => _play(0)),
                DocAction(Icons.summarize_outlined, context.t('ai.summarize'),
                    editor == null ? null : _summarize),
                DocAction(Icons.save_outlined, context.t('common.save'),
                    editor == null ? null : _save),
                DocAction(Icons.share_outlined, context.t('common.share'),
                    editor == null ? null : _export),
                DocAction(
                  Icons.translate,
                  context.t('common.translate'),
                  () => TranslateFlow.run(context, widget.plainText,
                      title: widget.name),
                ),
              ]),
        fab: editing
            ? null
            : FloatingActionButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    fileContext: widget.plainText,
                    fileName: widget.name,
                  ),
                )),
                tooltip: context.t('common.ai'),
                child: const Icon(Icons.smart_toy_outlined),
              ),
      ),
    );
  }

  /// "Slayt 3 / 12" rozeti — dokununca [_showGoToSlide].
  Widget _slideBadge(int total) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: SlidesEditorScreen.badgeKey,
        borderRadius: BorderRadius.circular(16),
        onTap: _showGoToSlide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            context.t('sl.slide_of', {'n': _currentSlide, 'total': total}),
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// Arama çubuğu — Excel'in "Bul"uyla aynı kurgu: yaz, ‹ › ile eşleşmeler
  /// arasında gez, sayaç kaçıncı eşleşmede olduğunu söyler.
  Widget _findBar() {
    final scheme = Theme.of(context).colorScheme;
    final hit = _hitIndex >= 0 && _hitIndex < _hits.length ? _hits[_hitIndex] : null;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _findCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: context.t('sl.search_hint'),
                    ),
                    onChanged: _runSearch,
                    onSubmitted: (_) => _stepHit(1),
                  ),
                ),
                Text(
                  _findCtrl.text.trim().isEmpty
                      ? ''
                      : _hits.isEmpty
                          ? context.t('sl.no_match')
                          : context.t('sl.match_pos', {
                              'n': _hitIndex + 1,
                              'total': '${_hits.length}${_hitLimit ? '+' : ''}',
                            }),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed: _hits.isEmpty ? null : () => _stepHit(-1),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: _hits.isEmpty ? null : () => _stepHit(1),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: _toggleFind,
                ),
              ],
            ),
            // Eşleşmenin BAĞLAMI: slaytın üstünde vurgulama yapamıyoruz
            // (kanvas biçimli metin çiziyor), o yüzden bulunan yer buradan
            // okunur — yoksa "3/12" sayacı hangi metni bulduğunu söylemezdi.
            if (hit != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    '${context.t('sl.slide_of', {
                          'n': hit.section + 1,
                          'total': _slideCount,
                        })} · ${hit.snippet}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlides(PptxEditor editor) {
    if (editor.slides.isEmpty) {
      return Center(child: Text(context.t('sl.none')));
    }
    return LayoutBuilder(builder: (context, box) {
      return PinchZoomArea(
        minZoom: 0.5,
        maxZoom: 3,
        onCommitted: _fixScroll,
        builder: (context, zoom, physics) {
          _zoom = zoom;
          // Kart genişliği ve boşluklar zoom ile DOĞRUSAL ölçeklenir. PinchZoomArea
          // canlı önizlemeyi tek tip (odaktan) GPU dönüşümüyle büyütür; yerleşim de
          // doğrusal olursa parmak kalkınca commit edilen düzen canlı önizlemeyle
          // birebir örtüşür ve "slaytlar zıplıyor" hissi kalkar (bkz. HAFIZA).
          final baseW = math.max(120.0, box.maxWidth - 32);
          // "Slayta git" ve konum rozeti kart yüksekliklerini bu genişlikten
          // hesaplıyor (bkz. _slideExtent) — build dışında da lazım.
          _baseW = baseW;
          final cardW = baseW * _zoom;
          final totalW = math.max(box.maxWidth, cardW + 32 * _zoom);
          return SingleChildScrollView(
            controller: _hCtrl,
            physics: physics,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalW,
              // Kenar boşlukları da zoom ile ölçeklenir — tüm dikey/yatay
              // yerleşim doğrusal kalır (bkz. yukarıdaki doğrusallık notu).
              child: ListView.builder(
                controller: _vCtrl,
                physics: physics,
                padding: EdgeInsets.fromLTRB(16 * _zoom, 8 * _zoom, 16 * _zoom,
                    MediaQuery.of(context).padding.bottom + 88),
                itemCount: editor.slides.length,
                itemBuilder: (context, i) => Center(
                  child: SizedBox(
                    width: cardW,
                    child: _slideCard(editor.slides[i], i, baseW),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _slideCard(PptxSlide slide, int i, double baseW) {
    final scheme = Theme.of(context).colorScheme;
    final view = slide.view;
    return Padding(
      // Slaytlar arası boşluk da zoom ile ölçeklenir → dikey yerleşim doğrusal
      // kalır, commit'te zıplama olmaz (bkz. _buildSlides).
      padding: EdgeInsets.only(bottom: 20 * _zoom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık şeridi ("Slayt N" + düğmeler) zoom ile birlikte ölçeklenir:
          // sabit yükseklikte kalsaydı yerleşim doğrusal olmaz, pinch bırakılınca
          // slaytlar zıplardı (kalan zoom sorununun kök nedeni). FittedBox,
          // doğal (zoom=1) yerleşimi kurup bütün şeridi oranla büyütür/küçültür.
          SizedBox(
            height: 40 * _zoom,
            child: FittedBox(
              fit: BoxFit.fitHeight,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: baseW,
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Row(
                    children: [
                      // Toplam da yazılır (2026-08-01 kullanıcı isteği):
                      // tek slayda bakarken destenin kaç slayt olduğu
                      // görünmüyordu.
                      Text(
                        context.t('sl.slide_of', {
                          'n': slide.index,
                          'total': _editor?.slides.length ?? 0,
                        }),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: context.t('sl.fullscreen'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.fullscreen, size: 20),
                        onPressed: () => _play(i),
                      ),
                      _slideMenu(slide),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Zoom liste seviyesindeki PinchZoomArea'dan gelir (kart içinde ayrı
          // InteractiveViewer YOK — ikisi birden çift zoom yapardı).
          AspectRatio(
            aspectRatio: view == null ? 16 / 9 : view.widthPt / view.heightPt,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: view == null
                  ? _fallbackText(slide)
                  : SlideCanvas(
                      slide: view,
                      onEditShape: (shape) => _beginEdit(slide, shape),
                      editingShape:
                          identical(_editSlide, slide) ? _editShapeVM : null,
                      editControllers:
                          identical(_editSlide, slide) ? _editCtrls : null,
                    ),
            ),
          ),
          _notesStrip(slide, baseW),
        ],
      ),
    );
  }

  /// Konuşmacı notu şeridi — kanvasın hemen altında, kağıt teması devir
  /// notundaki yerinde. Notu olmayan slaytta hiç yer kaplamaz.
  ///
  /// Şerit de kanvasla aynı zoom oranında ölçeklenir; sabit yükseklikte
  /// kalsaydı dikey yerleşim doğrusallığını bozup pinch bırakılınca slaytları
  /// zıplatırdı (kart başlığındaki aynı ders).
  Widget _notesStrip(PptxSlide slide, double baseW) {
    final editor = _editor;
    if (editor == null) return const SizedBox.shrink();
    final text = editor.notesOf(slide);
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final expanded = _openNotes.contains(slide.fileName);
    // Kapalıyken tek satır, açıkken en çok altı satır (uzun not kartı
    // ezmesin — devamı kaydırılarak okunur).
    final lines = expanded ? 6 : 1;
    final height = _notesHeight(slide);

    return SizedBox(
      height: height * _zoom,
      child: FittedBox(
        fit: BoxFit.fitHeight,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: baseW,
          height: height,
          child: InkWell(
            onTap: () => setState(() {
              expanded
                  ? _openNotes.remove(slide.fileName)
                  : _openNotes.add(slide.fileName);
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                border: Border(
                  left: BorderSide(color: scheme.outlineVariant, width: 3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: lines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Slayt işlemleri menüsü (çoğalt / sil / yukarı-aşağı taşı).
  Widget _slideMenu(PptxSlide slide) {
    final editor = _editor;
    final structural = editor?.canEditStructure ?? false;
    return PopupMenuButton<String>(
      tooltip: context.t('sl.actions'),
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) => _onSlideAction(slide, v),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'dup',
          enabled: structural,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.copy_all_outlined),
            title: Text(context.t('sl.duplicate')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'up',
          enabled: structural && slide.index > 1,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_upward),
            title: Text(context.t('sl.move_up')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'down',
          enabled:
              structural && slide.index < (editor?.slides.length ?? 0),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_downward),
            title: Text(context.t('sl.move_down')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'del',
          enabled: structural && (editor?.slides.length ?? 0) > 1,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline),
            title: Text(context.t('sl.delete')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _onSlideAction(PptxSlide slide, String action) {
    final editor = _editor;
    if (editor == null) return;
    if (!editor.canEditStructure) {
      _snack(context.t('sl.no_structure'));
      return;
    }
    switch (action) {
      case 'dup':
        final added = editor.duplicateSlide(slide);
        if (added != null) {
          _dirty = true;
          setState(() {});
          _snack(context.t('sl.duplicated'));
        }
        break;
      case 'up':
        if (editor.moveSlide(slide, -1)) {
          _dirty = true;
          setState(() {});
        }
        break;
      case 'down':
        if (editor.moveSlide(slide, 1)) {
          _dirty = true;
          setState(() {});
        }
        break;
      case 'del':
        _confirmDeleteSlide(slide);
        break;
    }
  }

  Future<void> _confirmDeleteSlide(PptxSlide slide) async {
    final editor = _editor;
    if (editor == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('sl.delete')),
        content: Text(ctx.t('sl.delete_body', {'n': slide.index})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('common.delete'))),
        ],
      ),
    );
    if (ok == true && editor.deleteSlide(slide)) {
      _dirty = true;
      if (mounted) setState(() {});
    }
  }

  /// Tam ekran sunum modunu [index]. slayttan başlatır.
  void _play(int index) {
    final views = <SlideVM>[];
    var start = 0;
    for (var i = 0; i < (_editor?.slides.length ?? 0); i++) {
      final v = _editor!.slides[i].view;
      if (v == null) continue;
      if (i <= index) start = views.length;
      views.add(v);
    }
    if (views.isEmpty) {
      _snack(context.t('sl.nothing_to_play'));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SlideshowScreen(slides: views, initialIndex: start),
    ));
  }

  /// Çizim yapılamadıysa (bozuk/desteklenmeyen slayt) düz metin listesi.
  Widget _fallbackText(PptxSlide slide) {
    if (slide.paragraphs.isEmpty) {
      return Center(child: Text(context.t('ss.no_text')));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final para in slide.paragraphs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: TextFormField(
                initialValue: para.text,
                onChanged: (v) {
                  para.text = v;
                  if (!_dirty) setState(() => _dirty = true);
                },
                maxLines: null,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Bir metin kutusunda **yerinde** düzenlemeyi başlatır: kutunun paragrafları
  /// slaytın üstünde TextField olur (popup yok). Önceki düzenleme varsa yazılır.
  /// Denetleyiciler şeklin paragraf sırasıyla hizalıdır (düzenlenemeyen = null).
  void _beginEdit(PptxSlide slide, ShapeVM shape) {
    _commitEdit(); // açık başka kutu varsa değişikliğini yaz
    _editCtrls.clear();
    _editTargets.clear();
    for (final p in shape.paragraphs) {
      final para = p.source == null ? null : slide.paragraphOf(p.source);
      if (para == null) {
        _editCtrls.add(null);
        _editTargets.add(null);
      } else {
        _editCtrls.add(TextEditingController(text: para.text));
        _editTargets.add(para);
      }
    }
    if (!_editTargets.any((t) => t != null)) return; // düzenlenebilir metin yok

    // Başlangıç biçimi: kutudaki ilk çalıştırmadan okunur.
    RunVM? firstRun;
    for (final p in shape.paragraphs) {
      if (p.runs.isNotEmpty) {
        firstRun = p.runs.first;
        break;
      }
    }
    _fBold = firstRun?.bold ?? false;
    _fItalic = firstRun?.italic ?? false;
    _fUnder = firstRun?.underline ?? false;
    _fSize = (firstRun?.sizePt ?? 18.0).clamp(6.0, 96.0).roundToDouble();
    // Yazı tipi XML'den okunur: çizim modelindeki ad gömülü aileye eşlenmiş
    // olur (Arial → Arimo) ve geri dönülemez.
    final firstTarget = _editTargets.firstWhere((t) => t != null, orElse: () => null);
    _fFont = firstTarget == null
        ? ''
        : (PptxEditor.fontOfParagraph(firstTarget) ?? '');
    _tBold = _tItalic = _tUnder = _tSize = _tFont = false;

    setState(() {
      _editSlide = slide;
      _editShapeVM = shape;
    });
  }

  /// Açık düzenlemeyi kalıcılaştırır (metin + dokunulan biçim), slaytı yeniden
  /// çizer ve durumu temizler. Açık düzenleme yoksa hiçbir şey yapmaz.
  /// Not: setState çağırmaz — çağıran sarar (build sırasında da güvenli kullanılır).
  void _commitEdit() {
    final slide = _editSlide;
    final editor = _editor;
    if (slide == null || editor == null) return;
    for (var i = 0; i < _editTargets.length; i++) {
      final t = _editTargets[i];
      final c = _editCtrls[i];
      if (t != null && c != null) editor.updateParagraph(slide, t, c.text);
    }
    if (_tBold || _tItalic || _tUnder || _tSize || _tFont) {
      for (final t in _editTargets) {
        if (t == null) continue;
        editor.formatParagraph(
          slide,
          t,
          bold: _tBold ? _fBold : null,
          italic: _tItalic ? _fItalic : null,
          underline: _tUnder ? _fUnder : null,
          sizePt: _tSize ? _fSize : null,
          fontFamily: _tFont && _fFont.isNotEmpty ? _fFont : null,
        );
      }
    }
    _dirty = true;
    for (final c in _editCtrls) {
      c?.dispose();
    }
    _editCtrls.clear();
    _editTargets.clear();
    _editSlide = null;
    _editShapeVM = null;
  }

  void _finishEdit() {
    FocusScope.of(context).unfocus();
    setState(_commitEdit);
  }

  /// Yazı tipi ailesi seçimi. Seçilen ad DOSYAYA yazılır (PowerPoint'te
  /// gerçek Arial görünsün), ekranda ise gömülü karşılığıyla çizilir.
  Future<void> _pickSlideFont() async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final f in kDocFonts)
              ListTile(
                title: Text(f.name, style: TextStyle(fontFamily: f.render)),
                trailing: f.name == _fFont ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, f.name),
              ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    setState(() {
      _fFont = pick;
      _tFont = true;
    });
  }

  Future<void> _pickSlideFontSize() async {
    final pick = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in kDocFontSizes)
              ListTile(
                title: Text('${s.round()}'),
                trailing: (s - _fSize).abs() < 0.25
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    setState(() {
      _fSize = pick;
      _tSize = true;
    });
  }

  /// Klavyenin üstünde yüzen biçim çubuğu (yerinde düzenleme aktifken).
  Widget _formatBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHighest,
      // Scaffold.resizeToAvoidBottomInset (varsayılan) body'yi klavyenin üstüne
      // sıkıştırır → çubuk zaten klavyenin hemen üstünde durur; ek viewInsets
      // payı çift sayardı. SafeArea klavye kapalıyken alt çentiği korur.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        // Simgeler Word/Excel ile ORTAK (`OfficeIcons`, 2026-08-07): aynı iş
        // üç uygulamada da aynı simge.
        child: SafeArea(
          top: false,
          child: OfficeRibbon(
            tabs: [
              RibbonTab('', [
                RibbonButton(OfficeIcons.bold, context.t('common.bold'),
                    active: _fBold,
                    onTap: () => setState(() {
                          _fBold = !_fBold;
                          _tBold = true;
                        })),
                RibbonButton(OfficeIcons.italic, context.t('common.italic'),
                    active: _fItalic,
                    onTap: () => setState(() {
                          _fItalic = !_fItalic;
                          _tItalic = true;
                        })),
                RibbonButton(
                    OfficeIcons.underline, context.t('common.underline'),
                    active: _fUnder,
                    onTap: () => setState(() {
                          _fUnder = !_fUnder;
                          _tUnder = true;
                        })),
                const RibbonSep(),
                // Yazı tipi ailesi (2026-08-07 kullanıcı: *"yazı tipi fontu
                // boyutu seçimi yok"*): Word ve Excel'de vardı, slaytta hiç
                // yoktu. Liste üçünde de aynı (`kDocFonts`).
                RibbonChip(
                  icon: OfficeIcons.fontFamily,
                  label: _fFont.isEmpty
                      ? context.t('word.font_family')
                      : _fFont,
                  tooltip: context.t('word.font_family'),
                  onTap: _pickSlideFont,
                ),
                RibbonButton(
                    OfficeIcons.fontShrink, context.t('vw.text_smaller'),
                    onTap: () => setState(() {
                          _fSize = (_fSize - 2).clamp(6.0, 96.0).toDouble();
                          _tSize = true;
                        })),
                RibbonChip(
                  icon: OfficeIcons.fontSize,
                  label: '${_fSize.round()}',
                  tooltip: context.t('word.font_size'),
                  onTap: _pickSlideFontSize,
                ),
                RibbonButton(OfficeIcons.fontGrow, context.t('vw.text_bigger'),
                    onTap: () => setState(() {
                          _fSize = (_fSize + 2).clamp(6.0, 96.0).toDouble();
                          _tSize = true;
                        })),
              ]),
            ],
            trailing: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _finishEdit,
                child: Text(context.t('sl.done')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
