part of '../image_gallery_screen.dart';


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
                Icon(icon, color: AppColors.onMedia, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onMedia,
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
      Motion.scrollTo(context, _scroll, target);
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
              duration: Motion.of(context, Motion.short),
              width: _item,
              height: _item,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? AppColors.onMedia : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Opacity(
                  opacity: active ? 1 : 0.6,
                  child: Image(
                    // Izgaranın çözdüğü küçük resim önbellekteyse o (disk
                    // okuması yok); değilse kademeli küçük bir çözme.
                    // `Image.file` DEĞİL: baytları Dart yığınına kopyalıyordu
                    // (bkz. `FmFileImage`).
                    image: fmCachedThumb(widget.paths[i]) ??
                        FmFileImage(widget.paths[i],
                            cacheWidth: fmThumbWidth(_item, dpr)),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
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
///
/// **İlk kare anında** (2026-09-26): ızgaranın çözdüğü küçük resim
/// önbellekteyse (`fmCachedThumb`) tam çözünürlük gelene kadar o çizilir —
/// eskiden açılışta bir an siyah ekran görünüyordu. Aynı küçük resim görselin
/// en-boy oranını da EŞZAMANLI verir: kahraman (Hero) kutusu görselin tam
/// kendisi olur ve hücreden büyüme geçişi kırpılmış kareden tam fotoğrafa
/// kesintisiz akar.
class _ZoomableImage extends StatefulWidget {
  final String path;
  final String? heroTag;
  final VoidCallback onTap;
  final void Function(bool zoomed) onZoomChanged;

  const _ZoomableImage({
    required this.path,
    required this.onTap,
    required this.onZoomChanged,
    this.heroTag,
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

  /// Izgaradan kalan küçük resim (önbellekte duruyorsa) — ilk kare.
  late final FmFileImage? _thumb = fmCachedThumb(widget.path);

  /// Görselin en-boy oranı; bilinene kadar null (kutu ekranı kaplar).
  late double? _aspect = _initialAspect();

  double? _initialAspect() {
    final thumb = _thumb;
    return thumb == null ? null : fmCachedAspect(thumb);
  }

  ImageStream? _aspectStream;
  ImageStreamListener? _aspectListener;

  @override
  void initState() {
    super.initState();
    _tx.addListener(_onTransform);
  }

  @override
  void dispose() {
    _stopAspect();
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
    _watchAspect();
  }

  /// En-boy oranı küçük resimden gelmediyse tam görsel çözülünce öğrenilir
  /// (kapanıştaki kahraman geçişi de görselin tam kutusundan başlasın diye).
  void _watchAspect() {
    if (_aspect != null || _aspectStream != null) return;
    final stream = FmFileImage(widget.path, cacheWidth: _decodeWidth)
        .resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final w = info.image.width;
      final h = info.image.height;
      info.dispose();
      if (!mounted || w <= 0 || h <= 0) return;
      setState(() => _aspect = w / h);
      // Dinleyici kendi çağrısı içinde kaldırılmasın: bir sonraki karede.
      WidgetsBinding.instance.addPostFrameCallback((_) => _stopAspect());
    }, onError: (_, __) {});
    _aspectStream = stream;
    _aspectListener = listener;
    stream.addListener(listener);
  }

  void _stopAspect() {
    final listener = _aspectListener;
    if (listener != null) _aspectStream?.removeListener(listener);
    _aspectListener = null;
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
      ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0, 1)
      ..scaleByDouble(2.5, 2.5, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect;
    // Oran biliniyorsa kutu görselin tam kendisidir → `cover` = `contain`
    // (kırpma yok), kahraman geçişinde ise kare hücreden tam fotoğrafa
    // kesintisiz açılır. Bilinmiyorsa kutu ekranı kaplar, görsel sığdırılır.
    final fit = aspect == null ? BoxFit.contain : BoxFit.cover;
    final thumb = _thumb;
    Widget image = Image(
      // `Image.file` DEĞİL: dosyayı Dart yığınına kopyalıyordu (bkz.
      // `FmFileImage`, 2026-08-17 donma kök nedeni).
      image: FmFileImage(widget.path, cacheWidth: _decodeWidth),
      fit: fit,
      // Yeni çözünürlük gelene kadar eskisi ekranda kalsın: yoksa her
      // kademede görsel bir kare boyunca kayboluyordu.
      gaplessPlayback: true,
      frameBuilder: thumb == null
          ? null
          : (context, child, frame, sync) => frame == null && !sync
              ? Image(image: thumb, fit: fit, gaplessPlayback: true)
              : child,
      errorBuilder: (_, __, ___) => Center(
        child: Text(context.t('vw.image_failed'),
            style: const TextStyle(color: AppColors.onMediaSoft)),
      ),
    );
    final tag = widget.heroTag;
    if (tag != null) image = Hero(tag: tag, child: image);
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _tx,
        minScale: 1,
        maxScale: 6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = constraints.biggest;
            final ratio = aspect ??
                (box.height > 0 && box.width.isFinite
                    ? box.width / box.height
                    : 1.0);
            return Center(
              child: AspectRatio(aspectRatio: ratio, child: image),
            );
          },
        ),
      ),
    );
  }
}
