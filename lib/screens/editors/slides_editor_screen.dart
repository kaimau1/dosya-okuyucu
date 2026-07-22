import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/document.dart';
import '../../services/pptx_editor.dart';
import '../../services/pptx_render.dart';
import '../../widgets/office_shell.dart';
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

  // PowerPoint mobil hissi: yatay sayfa geçişi + seçili slaytta pinch zoom.
  final _pageCtrl = PageController();
  final _tc = TransformationController();
  bool _zoomed = false; // zoom > 1 iken sayfa kaydırma kilitlenir, pan IV'ye kalır
  int _page = 0;
  late final _badge = ZoomBadgeController((fn) {
    if (mounted) setState(fn);
  });

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _tc.dispose();
    _badge.dispose();
    super.dispose();
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
          onPressed: editor == null ? null : () => _play(_page),
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
    final n = editor.slides.length;
    return Stack(
      children: [
        PageView.builder(
          controller: _pageCtrl,
          // Zoom'dayken yatay sürükleme slaydı gezdirir, sayfa değiştirmez.
          physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
          itemCount: n,
          onPageChanged: (i) {
            setState(() {
              _page = i;
              _zoomed = false;
            });
            _tc.value = Matrix4.identity();
          },
          itemBuilder: (context, i) => _slidePage(editor.slides[i], i, n),
        ),
        Positioned(
          left: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          child: ZoomBadge(zoom: _badge.zoom, visible: _badge.visible),
        ),
      ],
    );
  }

  Widget _slidePage(PptxSlide slide, int i, int total) {
    final scheme = Theme.of(context).colorScheme;
    final view = slide.view;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 4, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Slayt ${i + 1} / $total',
                  style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Tam ekran sunum',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.fullscreen, size: 20),
                onPressed: () => _play(i),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: InteractiveViewer(
                transformationController: _tc,
                minScale: 1,
                maxScale: 5,
                onInteractionUpdate: (d) {
                  if (d.pointerCount >= 2) {
                    _badge.bump(_tc.value.getMaxScaleOnAxis());
                  }
                },
                onInteractionEnd: (_) {
                  final z = _tc.value.getMaxScaleOnAxis() > 1.02;
                  if (z != _zoomed) setState(() => _zoomed = z);
                },
                child: AspectRatio(
                  aspectRatio:
                      view == null ? 16 / 9 : view.widthPt / view.heightPt,
                  child: Container(
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
              ),
            ),
          ),
        ],
      ),
    );
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
