import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/image_budget.dart';
import '../../core/l10n/app_strings.dart';
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
  late final List<String> _paths = [...widget.paths];
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

  /// Dosya bilgisi (boyut/tarih) yol başına bir kez ölçülür.
  ///
  /// **Niye önbellek:** bu getter `build` içinden çağrılıyor ve `statSync`
  /// SENKRON disk erişimidir. Yakınlaştırma, çubuğu gizleme, sayfa değişimi —
  /// her `setState` bir kare içinde diske gidiyordu; kaydırırken saniyede
  /// onlarca kez. Ölçüm dosya yolu başına bir kez yapılıp saklanıyor.
  final Map<String, FsEntry> _statCache = {};

  FsEntry get _currentEntry => _entryFor(_current);

  FsEntry _entryFor(String path) {
    final cached = _statCache[path];
    if (cached != null) return cached;
    // Binlerce fotoğraflı klasörde sırayla geçilen her dosya birikmesin;
    // önbellek yalnız "şu an bakılan birkaç dosya" için var.
    if (_statCache.length > 64) _statCache.clear();
    var size = 0;
    var modified = 0;
    try {
      final stat = File(path).statSync();
      size = stat.size;
      modified = stat.modified.millisecondsSinceEpoch;
    } catch (_) {}
    final entry = FsEntry(
      path: path,
      name: p.basename(path),
      isDir: false,
      sizeBytes: size,
      modifiedMs: modified,
    );
    _statCache[path] = entry;
    return entry;
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
      // GÖVDE ÇUBUĞUN ALTINDAN GEÇER — kullanıcı hatası 2026-07-30:
      // "resimlerde üzerine tıklayınca zıplama oluyor".
      //
      // Eskiden çubuk gizlenirken `appBar: null` veriliyordu: Scaffold'un
      // gövdesi o anda ~80 piksel uzuyor, `BoxFit.contain` görseli yeniden
      // ölçekliyor ve resim gözle görülür biçimde ZIPLIYORDU (her dokunuşta
      // iki kez: gizlerken ve gösterirken). Artık çubuk her zaman gövdenin
      // ÜSTÜNE biniyor, gövdenin ölçüsü hiç değişmiyor; görünürlük yalnız
      // saydamlıkla ayarlanıyor — yerleşim sabit, zıplama yok.
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        // Yükseklik SABİT (gizliyken de): Scaffold'un gövdeye verdiği alan
        // değişmediği sürece görsel yerinde kalır.
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: IgnorePointer(
          // Gizliyken dokunuşları yutmasın: ekranın üst şeridine dokunmak
          // görünmez çubuğu değil, resmi tetiklemeli.
          ignoring: !_chromeVisible,
          child: AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: AppBar(
              // Perde 0,6 → 0,72: beyaz/parlak bir fotoğrafın üstünde dosya
              // adı eriyip gidiyordu (kullanıcı 2026-08-29).
              backgroundColor: Colors.black.withValues(alpha: 0.72),
              foregroundColor: Colors.white,
              // Temanın çubuk altı cetveli fotoğrafın üstünde yersiz.
              shape: const Border(),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stil [OverlayBar]'dan: `foregroundColor: Colors.white`
                  // başlığı beyaz YAPMIYOR (kök neden orada yazılı) — ad
                  // temanın koyu `titleLarge` rengiyle çiziliyordu.
                  Text(entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OverlayBar.title(context)),
                  Text(
                    '${_index + 1}/${_paths.length} · '
                    '${FsPaths.humanSize(entry.sizeBytes)}',
                    style: OverlayBar.subtitle(context),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: context.t('common.share'),
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => shareEntries([_current]),
                ),
                IconButton(
                  tooltip: context.t('common.delete'),
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
                        // Yeniden adlandırma/taşıma dosyayı değiştirmiş
                        // olabilir: ölçüm önbelleği bayat kalmasın.
                        _statCache.remove(_current);
                        if (mounted) setState(() {});
                      case 'info':
                        await showProperties(context, _currentEntry);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'viewer',
                        child: Text(context.t('gal.open_in_viewer'))),
                    PopupMenuItem(
                        value: 'actions',
                        child: Text(context.t('gal.other_actions'))),
                    PopupMenuItem(
                        value: 'info', child: Text(context.t('fm.properties'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  /// Görselin kaç piksel genişlikte çözüleceği. Yakınlaştırınca kademeli
  /// olarak artar (bkz. [ImageBudget]); tam çözünürlükte açmak 12 MP'lik bir
  /// fotoğrafta 48 MB bitmap demekti.
  int _decodeWidth = ImageBudget.minWidth;

  @override
  void initState() {
    super.initState();
    _tx.addListener(_onTransform);
  }

  @override
  void dispose() {
    _tx.removeListener(_onTransform);
    _tx.dispose();
    super.dispose();
  }

  void _onTransform() {
    final scale = _tx.value.getMaxScaleOnAxis();
    // Ölçek 1'in üstündeyken sayfa kaydırma kilitlenir (üst ekran dinler).
    widget.onZoomChanged(scale > 1.02);
    _syncDecodeWidth(scale);
  }

  /// Yakınlaştırma kademe atladıysa görseli daha yüksek çözünürlükte açar.
  /// Kademe içinde kalan hareketler hiçbir şey tetiklemez — her karede yeniden
  /// çözmek yakınlaştırmayı takılır hale getirirdi.
  void _syncDecodeWidth(double scale) {
    if (!mounted) return;
    final media = MediaQuery.maybeOf(context);
    if (media == null) return;
    final want = ImageBudget.forViewport(
      logicalWidth: media.size.width,
      devicePixelRatio: media.devicePixelRatio,
      scale: scale,
    );
    if (want == _decodeWidth) return;
    setState(() => _decodeWidth = want);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDecodeWidth(_tx.value.getMaxScaleOnAxis());
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
            // Bellek/pil: ekranda görünecek kadar piksel çöz (bkz.
            // ImageBudget). Kaynak bundan küçükse Flutter değeri kendiliğinden
            // kaynağa kısar — küçük görsel büyütülüp şişmez.
            cacheWidth: _decodeWidth,
            // Yeni çözünürlük gelene kadar eskisi ekranda kalsın: yoksa her
            // kademede görsel bir kare boyunca kayboluyordu.
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Center(
              child: Text(context.t('vw.image_failed'),
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ),
      ),
    );
  }
}
