import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/document.dart';
import '../../services/pptx_editor.dart';
import '../../services/pptx_render.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/pinch_zoom_area.dart';
import '../../widgets/slide_canvas.dart';
import '../chat_screen.dart';
import 'slideshow_screen.dart';

/// Slaytlar PowerPoint'teki gibi **gerçek tasarımıyla** çizilir; bir metin
/// kutusuna dokunmak o kutunun yazılarını düzenlemeyi açar. Kaydederken orijinal
/// tasarım korunur (yalnızca metin güncellenir).
class SlidesEditorScreen extends StatefulWidget {
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

  // ── Canlı (yerinde) metin düzenleme durumu ─────────────────────────────────
  // Popup yerine kutu doğrudan slaytın üstünde TextField olur; biçim çubuğu
  // klavyenin üstünde yüzer. Denetleyiciler şeklin paragraflarıyla hizalıdır.
  PptxSlide? _editSlide;
  ShapeVM? _editShapeVM;
  final List<TextEditingController?> _editCtrls = [];
  final List<PptxParagraph?> _editTargets = [];
  bool _fBold = false, _fItalic = false, _fUnder = false;
  double _fSize = 18;
  bool _tBold = false, _tItalic = false, _tUnder = false, _tSize = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _editCtrls) {
      c?.dispose();
    }
    _hCtrl.dispose();
    _vCtrl.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kaydedildi. Kalıcı yer için ⋮ > Paylaş/Dışa aktar.')));
        setState(() {});
      }
    } catch (e) {
      _snack('Kaydedilemedi: $e');
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

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    return OfficeShell(
      kind: DocKind.slides,
      title: widget.name,
      dirty: _dirty,
      actions: [
        IconButton(
          tooltip: 'Sunumu oynat',
          icon: const Icon(Icons.play_arrow),
          onPressed: editor == null ? null : () => _play(0),
        ),
        IconButton(
          tooltip: 'Kaydet',
          icon: const Icon(Icons.save_outlined),
          onPressed: editor == null ? null : _save,
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'export') _export();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'export', child: Text('Paylaş / Dışa aktar')),
          ],
        ),
      ],
      body: _error != null
          ? Center(child: Text('Açılamadı: $_error'))
          : editor == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(child: _buildSlides(editor)),
                    if (_editShapeVM != null) _formatBar(),
                  ],
                ),
      fab: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            fileContext: widget.plainText,
            fileName: widget.name,
          ),
        )),
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('AI'),
      ),
    );
  }

  Widget _buildSlides(PptxEditor editor) {
    if (editor.slides.isEmpty) {
      return const Center(child: Text('Slayt bulunamadı.'));
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
                      Text('Slayt ${slide.index}',
                          style: Theme.of(context).textTheme.labelMedium),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Tam ekran sunum',
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
                    color: Colors.black.withOpacity(0.10),
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
        ],
      ),
    );
  }

  /// Slayt işlemleri menüsü (çoğalt / sil / yukarı-aşağı taşı).
  Widget _slideMenu(PptxSlide slide) {
    final editor = _editor;
    final structural = editor?.canEditStructure ?? false;
    return PopupMenuButton<String>(
      tooltip: 'Slayt işlemleri',
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) => _onSlideAction(slide, v),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'dup',
          enabled: structural,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.copy_all_outlined),
            title: Text('Slaytı çoğalt'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'up',
          enabled: structural && slide.index > 1,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.arrow_upward),
            title: Text('Yukarı taşı'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'down',
          enabled:
              structural && slide.index < (editor?.slides.length ?? 0),
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.arrow_downward),
            title: Text('Aşağı taşı'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'del',
          enabled: structural && (editor?.slides.length ?? 0) > 1,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline),
            title: Text('Slaytı sil'),
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
      _snack('Bu dosyada slayt yapısı düzenlenemiyor (eksik sunum bilgisi).');
      return;
    }
    switch (action) {
      case 'dup':
        final added = editor.duplicateSlide(slide);
        if (added != null) {
          _dirty = true;
          setState(() {});
          _snack('Slayt çoğaltıldı.');
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
        title: const Text('Slaytı sil'),
        content: Text('Slayt ${slide.index} silinsin mi? Bu işlem geri alınamaz '
            '(kaydedene kadar dosya değişmez).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
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
      _snack('Bu dosyada gösterilecek slayt yok.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SlideshowScreen(slides: views, initialIndex: start),
    ));
  }

  /// Çizim yapılamadıysa (bozuk/desteklenmeyen slayt) düz metin listesi.
  Widget _fallbackText(PptxSlide slide) {
    if (slide.paragraphs.isEmpty) {
      return const Center(child: Text('(Metin yok)'));
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
    _tBold = _tItalic = _tUnder = _tSize = false;

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
    if (_tBold || _tItalic || _tUnder || _tSize) {
      for (final t in _editTargets) {
        if (t == null) continue;
        editor.formatParagraph(
          slide,
          t,
          bold: _tBold ? _fBold : null,
          italic: _tItalic ? _fItalic : null,
          underline: _tUnder ? _fUnder : null,
          sizePt: _tSize ? _fSize : null,
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
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Kalın',
                isSelected: _fBold,
                icon: const Icon(Icons.format_bold),
                onPressed: () => setState(() {
                  _fBold = !_fBold;
                  _tBold = true;
                }),
              ),
              IconButton(
                tooltip: 'İtalik',
                isSelected: _fItalic,
                icon: const Icon(Icons.format_italic),
                onPressed: () => setState(() {
                  _fItalic = !_fItalic;
                  _tItalic = true;
                }),
              ),
              IconButton(
                tooltip: 'Altı çizili',
                isSelected: _fUnder,
                icon: const Icon(Icons.format_underlined),
                onPressed: () => setState(() {
                  _fUnder = !_fUnder;
                  _tUnder = true;
                }),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Yazıyı küçült',
                icon: const Icon(Icons.text_decrease),
                onPressed: () => setState(() {
                  _fSize = (_fSize - 2).clamp(6.0, 96.0).toDouble();
                  _tSize = true;
                }),
              ),
              Text('${_fSize.round()} pt',
                  style: Theme.of(context).textTheme.labelLarge),
              IconButton(
                tooltip: 'Yazıyı büyüt',
                icon: const Icon(Icons.text_increase),
                onPressed: () => setState(() {
                  _fSize = (_fSize + 2).clamp(6.0, 96.0).toDouble();
                  _tSize = true;
                }),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _finishEdit,
                child: const Text('Bitti'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
