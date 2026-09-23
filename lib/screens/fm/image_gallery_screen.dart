import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/busy_dialog.dart';
import '../../core/image_budget.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/image_rotate.dart';
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
        popOwnPage(context);
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

  Future<void> _rotate() async {
    // Yan çekilmiş fotoğrafı düzeltmenin uygulama içinde hiçbir yolu yoktu
    // (2026-09-06 denetim turu).
    if (await rotateImageEntry(context, _currentEntry)) {
      _statCache.remove(_current);
      if (mounted) setState(() {});
    }
  }

  Future<void> _otherActions() async {
    await showEntryActions(context, _currentEntry);
    // Yeniden adlandırma/taşıma dosyayı değiştirmiş olabilir: ölçüm önbelleği
    // bayat kalmasın.
    _statCache.remove(_current);
    if (mounted) setState(() {});
  }

  void _jumpTo(int i) {
    if (i == _index) return;
    _pages.jumpToPage(i);
  }

  @override
  Widget build(BuildContext context) {
    if (_paths.isEmpty) return const SizedBox.shrink();
    final entry = _currentEntry;
    final padding = MediaQuery.paddingOf(context);

    // 2026-09-23 tasarım turu (kullanıcı: *"görseller … çok basit görünüyor"*).
    // Eski ekran: düz %72 siyah üst şerit + ⋮ menüsü; paylaş/sil dışında her
    // şey menüde gizliydi. Bugünün galeri dili (Google Foto, iOS Fotoğraflar):
    // * Üstte ve altta DEGRADE perde — fotoğrafın kenarını kesen bir bant yok.
    // * Altta etiketli eylem sırası: Paylaş · Döndür · Araçlar · Bilgi · Sil.
    // * Birden çok görselde küçük resim şeridi: sağa sola kaydırmadan atla.
    //
    // Çubuklar gövdenin ÜSTÜNE biner, görünürlük yalnız saydamlıkla değişir:
    // gövdenin ölçüsü hiç değişmez → dokununca görsel ZIPLAMAZ (kullanıcı
    // hatası 2026-07-30: "resimlerde üzerine tıklayınca zıplama oluyor" —
    // `appBar: null` ile gövde ~80 px uzuyor, görsel yeniden ölçekleniyordu).
    Widget chrome({required Widget child}) => IgnorePointer(
          // Gizliyken dokunuşları yutmasın: görünmez çubuğa değil resme gitsin.
          ignoring: !_chromeVisible,
          child: AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: child,
          ),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
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
            ),
            // ── Üst perde: geri, ad, konum/boyut, daha fazla ──────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: chrome(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Color(0x00000000)],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4, padding.top + 4, 4, 28),
                    child: Row(
                      children: [
                        const BackButton(color: Colors.white),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Stil [OverlayBar]'dan: `foregroundColor`
                              // başlığı beyaz YAPMIYOR (kök neden orada).
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
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (v) async {
                            switch (v) {
                              case 'viewer':
                                _openInViewer();
                              case 'actions':
                                await _otherActions();
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'viewer',
                                child: Text(context.t('gal.open_in_viewer'))),
                            PopupMenuItem(
                                value: 'actions',
                                child: Text(context.t('gal.other_actions'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ── Alt perde: küçük resim şeridi + eylemler ──────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: chrome(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xE6000000), Color(0x00000000)],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 32, 8, padding.bottom + 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_paths.length > 1)
                          _FilmStrip(
                            paths: _paths,
                            index: _index,
                            onPick: _jumpTo,
                          ),
                        Row(
                          children: [
                            _GalleryAction(
                              icon: Icons.share_outlined,
                              label: context.t('common.share'),
                              onTap: () => shareEntriesFrom(context, [_current]),
                            ),
                            if (ImageRotate.canRotate(_current))
                              _GalleryAction(
                                icon: Icons.rotate_right,
                                label: context.t('ea.rotate'),
                                onTap: _rotate,
                              ),
                            _GalleryAction(
                              icon: Icons.document_scanner_outlined,
                              label: context.t('gal.tools'),
                              onTap: _openInViewer,
                            ),
                            _GalleryAction(
                              icon: Icons.info_outline,
                              label: context.t('gal.info'),
                              onTap: () =>
                                  showProperties(context, _currentEntry),
                            ),
                            _GalleryAction(
                              icon: Icons.delete_outline,
                              label: context.t('common.delete'),
                              onTap: _delete,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Galerinin alt eylem düğmesi: beyaz simge + küçük etiket (koyu perde üstü).
class _GalleryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GalleryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük resim şeridi — geçerli görsel ortalanır ve beyaz çerçeveyle işaretli.
///
/// Bellek: her küçük resim 48 dp × cihaz yoğunluğu genişlikte çözülür
/// (12 MP'lik fotoğraf tam açılsa 48 MB olurdu); şerit `ListView.builder`
/// olduğu için yalnız görünenler çözülür.
class _FilmStrip extends StatefulWidget {
  final List<String> paths;
  final int index;
  final ValueChanged<int> onPick;

  const _FilmStrip({
    required this.paths,
    required this.index,
    required this.onPick,
  });

  @override
  State<_FilmStrip> createState() => _FilmStripState();
}

class _FilmStripState extends State<_FilmStrip> {
  static const _item = 48.0;
  static const _gap = 6.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(jump: true));
  }

  @override
  void didUpdateWidget(_FilmStrip old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _center();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _center({bool jump = false}) {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final target = (widget.index * (_item + _gap) -
            (pos.viewportDimension - _item) / 2)
        .clamp(0.0, pos.maxScrollExtent);
    if (jump) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      height: _item + 12,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: widget.paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final active = i == widget.index;
          return GestureDetector(
            onTap: () => widget.onPick(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: _item,
              height: _item,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Opacity(
                  opacity: active ? 1 : 0.6,
                  child: Image.file(
                    File(widget.paths[i]),
                    fit: BoxFit.cover,
                    cacheWidth: (_item * dpr).round(),
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF222222)),
                  ),
                ),
              ),
            ),
          );
        },
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
