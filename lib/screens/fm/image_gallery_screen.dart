import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../models/document.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fs_scan.dart';
import '../viewer_screen.dart';
import 'entry_actions.dart';

/// Galeri: aynı klasördeki görselleri **sağa/sola kaydırarak** gezme.
///
/// Her sayfa kendi yakınlaştırma durumunu tutar; yakınlaştırılmış sayfada
/// yatay kaydırma sayfayı değiştirmez (parmak resmi kaydırır) — slayt
/// listesindeki zoom/kaydırma çekişmesi dersinin aynısı (bkz. HAFIZA).
///
/// OCR, çeviri, "PDF yap" gibi ağır işlevler tek-görsel görüntüleyicide
/// (`ViewerScreen`) kalır; buradaki ⋮ menüsünden oraya geçilir.
class ImageGalleryScreen extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const ImageGalleryScreen({
    super.key,
    required this.paths,
    this.initialIndex = 0,
  });

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late List<String> _paths = [...widget.paths];
  late int _index = widget.initialIndex.clamp(0, widget.paths.length - 1);
  bool _chromeVisible = true;

  /// Yakınlaştırılmış sayfa varken sayfa geçişi kilitlenir.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String get _current => _paths[_index];

  FsEntry get _currentEntry {
    final file = File(_current);
    var size = 0;
    var modified = 0;
    try {
      final stat = file.statSync();
      size = stat.size;
      modified = stat.modified.millisecondsSinceEpoch;
    } catch (_) {}
    return FsEntry(
      path: _current,
      name: p.basename(_current),
      isDir: false,
      sizeBytes: size,
      modifiedMs: modified,
    );
  }

  Future<void> _delete() async {
    final entry = _currentEntry;
    if (!await deleteEntries(context, [entry])) return;
    if (!mounted) return;
    setState(() {
      _paths.removeAt(_index);
      if (_paths.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      _index = _index.clamp(0, _paths.length - 1);
      _pages.jumpToPage(_index);
    });
  }

  void _openInViewer() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ViewerScreen(
        doc: LoadedDoc(
          path: _current,
          name: p.basename(_current),
          kind: DocKind.image,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_paths.isEmpty) return const SizedBox.shrink();
    final entry = _currentEntry;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16)),
                  Text(
                    '${_index + 1}/${_paths.length} · '
                    '${FsPaths.humanSize(entry.sizeBytes)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Paylaş',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => shareEntries([_current]),
                ),
                IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'viewer':
                        _openInViewer();
                      case 'actions':
                        await showEntryActions(context, _currentEntry);
                        if (mounted) setState(() {});
                      case 'info':
                        await showProperties(context, _currentEntry);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'viewer',
                        child: Text('Görüntüleyicide aç (OCR, çeviri, PDF)')),
                    PopupMenuItem(
                        value: 'actions', child: Text('Diğer işlemler')),
                    PopupMenuItem(value: 'info', child: Text('Özellikler')),
                  ],
                ),
              ],
            )
          : null,
      body: PageView.builder(
        controller: _pages,
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: (i) => setState(() {
          _index = i;
          _zoomed = false;
        }),
        itemCount: _paths.length,
        itemBuilder: (context, i) => _ZoomableImage(
          path: _paths[i],
          onTap: () => setState(() => _chromeVisible = !_chromeVisible),
          onZoomChanged: (zoomed) {
            if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
          },
        ),
      ),
    );
  }
}

/// Tek görsel: çift dokunuşla ve iki parmakla yakınlaştırma.
class _ZoomableImage extends StatefulWidget {
  final String path;
  final VoidCallback onTap;
  final void Function(bool zoomed) onZoomChanged;

  const _ZoomableImage({
    required this.path,
    required this.onTap,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _tx = TransformationController();
  TapDownDetails? _doubleTapAt;

  @override
  void initState() {
    super.initState();
    _tx.addListener(() {
      // Ölçek 1'in üstündeyken sayfa kaydırma kilitlenir (üst ekran dinler).
      widget.onZoomChanged(_tx.value.getMaxScaleOnAxis() > 1.02);
    });
  }

  @override
  void dispose() {
    _tx.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_tx.value.getMaxScaleOnAxis() > 1.02) {
      _tx.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapAt?.localPosition;
    if (position == null) return;
    // Dokunulan noktayı merkeze alarak 2.5x yakınlaştır.
    _tx.value = Matrix4.identity()
      ..translate(-position.dx * 1.5, -position.dy * 1.5)
      ..scale(2.5);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _tx,
        minScale: 1,
        maxScale: 6,
        child: Center(
          child: Image.file(
            File(widget.path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('Görsel görüntülenemedi.',
                  style: TextStyle(color: Colors.white70)),
            ),
          ),
        ),
      ),
    );
  }
}
