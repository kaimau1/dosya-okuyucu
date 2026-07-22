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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
              : _buildSlides(editor),
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
          final cardW = math.max(120.0, (box.maxWidth - 32) * _zoom);
          final totalW = math.max(box.maxWidth, cardW + 32);
          return SingleChildScrollView(
            controller: _hCtrl,
            physics: physics,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalW,
              child: ListView.builder(
                controller: _vCtrl,
                physics: physics,
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.of(context).padding.bottom + 88),
                itemCount: editor.slides.length,
                itemBuilder: (context, i) => Center(
                  child: SizedBox(
                    width: cardW,
                    child: _slideCard(editor.slides[i], i),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _slideCard(PptxSlide slide, int i) {
    final scheme = Theme.of(context).colorScheme;
    final view = slide.view;
    return Padding(
      // Slaytlar arası boşluk da zoom ile ölçeklenir → dikey yerleşim doğrusal
      // kalır, commit'te zıplama olmaz (bkz. _buildSlides).
      padding: EdgeInsets.only(bottom: 20 * _zoom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
                      onEditShape: (shape) => _editShape(slide, shape),
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

  /// Bir metin kutusunun paragraflarını düzenler; kaydedince slayt yeniden çizilir.
  Future<void> _editShape(PptxSlide slide, ShapeVM shape) async {
    final editor = _editor;
    if (editor == null) return;

    final targets = <PptxParagraph>[];
    final controllers = <TextEditingController>[];
    for (final p in shape.paragraphs) {
      final para = slide.paragraphOf(p.source);
      if (para == null) continue;
      targets.add(para);
      controllers.add(TextEditingController(text: para.text));
    }
    if (targets.isEmpty) return;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Metni düzenle',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final c in controllers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: c,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Vazgeç'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Uygula'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      for (var i = 0; i < targets.length; i++) {
        editor.updateParagraph(slide, targets[i], controllers[i].text);
      }
      _dirty = true;
      if (mounted) setState(() {});
    }
    for (final c in controllers) {
      c.dispose();
    }
  }
}
