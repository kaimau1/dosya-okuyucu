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
                  style: context.type.caption.copyWith(
                    color: AppColors.onMedia,
                    fontWeight: FontWeight.w600,
                    shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)],
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

/// Bozuk görselin kurtarılmış hâli ([ImageRepair]); o da olmazsa "açılamadı".
class _RepairedImage extends StatefulWidget {
  final String path;
  final BoxFit fit;

  /// Çözme genişliği (piksel) — asıl görselinkiyle aynı bütçe (B12 m.4):
  /// kurtarılan bayt tam çözünürlükte açılırsa 12 MP ≈ 48 MB bitmap.
  final int? cacheWidth;
  const _RepairedImage(this.path, {required this.fit, this.cacheWidth});

  @override
  State<_RepairedImage> createState() => _RepairedImageState();
}

class _RepairedImageState extends State<_RepairedImage> {
  late final Future<Uint8List?> _bytes = ImageRepair.repairFile(widget.path);

  @override
  Widget build(BuildContext context) {
    Widget failed() => Center(
          child: Text(context.t('vw.image_failed'),
              style: const TextStyle(color: AppColors.onMediaSoft)),
        );
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        // Kurtarma kısa sürer; dönen gösterge yerine boş alan (gösterge
        // açılıp kapanınca görsel bir kare "titriyordu").
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.expand();
        }
        final data = snap.data;
        if (data == null) return failed();
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(data,
                fit: widget.fit,
                cacheWidth: widget.cacheWidth,
                errorBuilder: (_, _, _) => failed()),
            Positioned(
              left: Gap.md,
              right: Gap.md,
              bottom: Gap.md,
              child: Text(
                context.t('gal.repaired'),
                textAlign: TextAlign.center,
                style: context.type.caption.copyWith(
                  color: AppColors.onMedia,
                  shadows: const [
                    Shadow(color: AppColors.mediaSurface, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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

  /// Seçim kipinde seçili yollar (null = seçim kipi kapalı).
  final Set<String>? selected;

  const _FilmStrip({
    required this.paths,
    required this.index,
    required this.onPick,
    this.selected,
  });

  @override
  State<_FilmStrip> createState() => _FilmStripState();
}

class _FilmStripState extends State<_FilmStrip> {
  static const _item = 48.0;
  static const _gap = 6.0;
  final _scroll = ScrollController();
  final Map<String, ImageProvider<Object>> _thumbProviders = {};
  double _lastDpr = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(jump: true));
  }

  @override
  void didUpdateWidget(_FilmStrip old) {
    super.didUpdateWidget(old);
    if (old.paths.length != widget.paths.length ||
        !identical(old.paths, widget.paths)) {
      _thumbProviders.clear();
    }
    if (old.index != widget.index) _center();
  }

  ImageProvider<Object> _providerFor(String path, double dpr) {
    if (_lastDpr != dpr) {
      _lastDpr = dpr;
      _thumbProviders.clear();
    }
    if (_thumbProviders.length > 128) _thumbProviders.clear();
    return _thumbProviders.putIfAbsent(
      path,
      () => fmCachedThumb(path) ??
          FmFileImage(path, cacheWidth: fmThumbWidth(_item, dpr)),
    );
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
      // **Sabit öğe boyu** (G1, 2026-11-20, kullanıcı: "eski görüntülere
      // hızlıca inip açınca donma"). Eskiden `ListView.separated`: boyu
      // bilinmeyen öğeler + ayraçlar. Açılışta şerit seçili fotoğrafa
      // atlarken liste o ofsete kadar BÜTÜN öğeleri sırayla kurup ölçüyordu —
      // 5 bin fotoğraflık galeride en eski fotoğrafta ~10 bin öğe, tek karede
      // ~700 ms (tablette ölçüldü). `itemExtent` ile atlama O(1): yalnız
      // görünen öğeler kurulur. Boşluk öğenin içinde (görünüm aynı).
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: 8 - _gap / 2, vertical: 6),
        itemExtent: _item + _gap,
        itemCount: widget.paths.length,
        itemBuilder: (context, i) {
          final active = i == widget.index;
          final sel = widget.selected;
          final picked = sel != null && sel.contains(widget.paths[i]);
          final dimmed = !active && !picked;
          return Padding(
           padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
           child: GestureDetector(
            onTap: () => widget.onPick(i),
            child: Container(
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
                child: Stack(fit: StackFit.expand, children: [
                  Image(
                    image: _providerFor(widget.paths[i], dpr),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.mediaSurface),
                  ),
                  if (dimmed)
                    Positioned.fill(
                      child: ColoredBox(
                        color: AppColors.mediaSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  if (sel != null)
                    PositionedDirectional(
                      end: 2,
                      top: 2,
                      child: Icon(
                        picked
                            ? AppIcons.checkCircle
                            : AppIcons.checkCircleOutline,
                        size: 18,
                        color: AppColors.onMedia,
                        shadows: const [
                          Shadow(color: AppColors.mediaChrome, blurRadius: 3)
                        ],
                      ),
                    ),
                ]),
              ),
            ),
          ));
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
    super.key,
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

  /// Ekrandaki parmak sayısı. İki parmak inince sayfa kaydırma ve aşağı
  /// çekip kapatma HEMEN kilitlenir (2026-11-20, kullanıcı: "zoom yapmak
  /// zor, çift tıklamadan zoom yapılmıyor"): yoksa çimdik hareketi yatay
  /// sayfa ya da dikey kapatma sürüklemesine kaptırılıyordu.
  int _pointers = 0;

  /// Tam boy görselin ilk karesi geldi mi. Geldikten sonra çözünürlük
  /// kademesi değişse de küçük resme DÖNÜLMEZ (kullanıcı 2026-11-20: "zoom
  /// yapınca fotoğraf her seferinde bulanıklaşıp yeniden düzeliyor" — yeni
  /// akışta `frame` null'a dönüyor, `frameBuilder` küçük resmi çiziyordu).
  bool _hadFullFrame = false;

  void _onPointer(int delta) {
    final before = _pointers >= 2;
    _pointers = (_pointers + delta).clamp(0, 10);
    if (before != (_pointers >= 2)) _reportLock();
  }

  void _reportLock() => widget.onZoomChanged(
      _tx.value.getMaxScaleOnAxis() > 1.02 || _pointers >= 2);

  /// Görselin kaç piksel boyunda çözüleceği. Yakınlaştırınca kademeli
  /// olarak artar (bkz. [ImageBudget]); tam çözünürlükte açmak 12 MP'lik bir
  /// fotoğrafta 48 MB bitmap demekti.
  int _decodeWidth = ImageBudget.minWidth;

  /// Izgaradan kalan küçük resim (önbellekte duruyorsa) — ilk kare.
  late FmFileImage? _thumb = fmCachedThumb(widget.path);

  /// Görselin en-boy oranı; bilinene kadar null (kutu ekranı kaplar).
  late double? _aspect = _initialAspect();

  double? _initialAspect() {
    final thumb = _thumb;
    return thumb == null ? null : fmCachedAspect(thumb);
  }

  ImageStream? _aspectStream;
  ImageStreamListener? _aspectListener;
  Timer? _decodeTimer;

  /// Açılış geçişi sürerken (küçük resim varsa) yalnız küçük resim çizilir;
  /// tam boy çözüm geçiş bitince başlar (2026-11-18, kullanıcı: "fotoğraf
  /// takıla takıla açılıyor"). Büyük JPEG'in çözümü ve doku yüklemesi büyüme
  /// animasyonunun ortasına düşüp kare kaçırtıyordu.
  bool _full = true;
  Animation<double>? _routeAnim;
  AnimationStatusListener? _routeListener;

  void _watchRoute() {
    if (_routeAnim != null || _thumb == null || _aspect == null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) return;
    _full = false;
    _routeAnim = animation;
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.forward) return;
      _stopRoute();
      if (mounted && !_full) setState(() => _full = true);
    };
    _routeListener = listener;
    animation.addStatusListener(listener);
  }

  void _stopRoute() {
    final listener = _routeListener;
    if (listener != null) _routeAnim?.removeStatusListener(listener);
    _routeListener = null;
    _routeAnim = null;
  }

  @override
  void initState() {
    super.initState();
    _tx.addListener(_onTransform);
  }

  @override
  void didUpdateWidget(covariant _ZoomableImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _decodeTimer?.cancel();
      _stopRoute();
      _stopAspect();
      _tx.value = Matrix4.identity();
      _pointers = 0;
      _hadFullFrame = false;
      _full = true;
      _thumb = fmCachedThumb(widget.path);
      _aspect = _initialAspect();
      _syncDecodeWidth(1.0);
      _watchRoute();
      _watchAspect();
    }
  }

  @override
  void dispose() {
    _decodeTimer?.cancel();
    _stopRoute();
    _stopAspect();
    _tx.removeListener(_onTransform);
    _tx.dispose();
    super.dispose();
  }

  void _onTransform() {
    // Çimdik sırasında her karede tam çözünürlük çözme: yalnız kilidi güncelle.
    _reportLock();
  }

  void _scheduleDecodeSync() {
    _decodeTimer?.cancel();
    // 150 ms yerleşme sonrası çöz.
    _decodeTimer = Timer(const Duration(microseconds: 150000), () {
      if (mounted) _syncDecodeWidth(_tx.value.getMaxScaleOnAxis());
    });
  }

  /// Yakınlaştırma kademe atladıysa görseli daha yüksek çözünürlükte açar.
  void _syncDecodeWidth(double scale) {
    if (!mounted) return;
    final media = MediaQuery.maybeOf(context);
    if (media == null) return;
    final want = ImageBudget.forViewport(
      logicalWidth: media.size.width,
      logicalHeight: media.size.height,
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
    _watchRoute();
    _watchAspect();
  }

  /// En-boy oranı küçük resimden gelmediyse tam görsel çözülünce öğrenilir
  /// (kapanıştaki kahraman geçişi de görselin tam kutusundan başlasın diye).
  void _watchAspect() {
    if (_aspect != null || _aspectStream != null) return;
    final stream = FmFileImage(widget.path,
            cacheWidth: _decodeWidth, maxLongSide: _decodeWidth)
        .resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final w = info.image.width;
      final h = info.image.height;
      info.dispose();
      if (!mounted || w <= 0 || h <= 0) return;
      setState(() => _aspect = w / h);
      // Dinleyici kendi çağrısı içinde kaldırılmasın: bir sonraki karede.
      WidgetsBinding.instance.addPostFrameCallback((_) => _stopAspect());
    }, onError: (_, _) {});
    _aspectStream = stream;
    _aspectListener = listener;
    stream.addListener(listener);
  }

  void _stopAspect() {
    final listener = _aspectListener;
    if (listener != null) _aspectStream?.removeListener(listener);
    _aspectListener = null;
    _aspectStream = null;
  }

  void _handleDoubleTap() {
    if (_tx.value.getMaxScaleOnAxis() > 1.02) {
      _tx.value = Matrix4.identity();
      _syncDecodeWidth(1.0);
      return;
    }
    final position = _doubleTapAt?.localPosition;
    if (position == null) return;
    // Dokunulan noktayı merkeze alarak 2.5x yakınlaştır.
    _tx.value = Matrix4.identity()
      ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0, 1)
      ..scaleByDouble(2.5, 2.5, 1, 1);
    _syncDecodeWidth(2.5);
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect;
    // Oran biliniyorsa kutu görselin tam kendisidir → `cover` = `contain`
    // (kırpma yok), kahraman geçişinde ise kare hücreden tam fotoğrafa
    // kesintisiz açılır. Bilinmiyorsa kutu ekranı kaplar, görsel sığdırılır.
    final fit = aspect == null ? BoxFit.contain : BoxFit.cover;
    final thumb = _thumb;
    Widget image = !_full && thumb != null
        ? Image(image: thumb, fit: fit, gaplessPlayback: true)
        : Image(
      // `Image.file` DEĞİL: dosyayı Dart yığınına kopyalıyordu (bkz.
      // `FmFileImage`, 2026-08-17 donma kök nedeni).
      image: FmFileImage(widget.path,
          cacheWidth: _decodeWidth, maxLongSide: _decodeWidth),
      fit: fit,
      // Yeni çözünürlük gelene kadar eskisi ekranda kalsın: yoksa her
      // kademede görsel bir kare boyunca kayboluyordu.
      gaplessPlayback: true,
      frameBuilder: thumb == null
          ? null
          : (context, child, frame, sync) {
              if (frame != null || sync) _hadFullFrame = true;
              return _hadFullFrame
                  ? child
                  : Image(image: thumb, fit: fit, gaplessPlayback: true);
            },
      // Çözücü reddetti → kurtarmayı dene (başında çöp, yarım JPEG …).
      errorBuilder: (_, _, _) =>
          _RepairedImage(widget.path, fit: fit, cacheWidth: _decodeWidth),
    );
    final tag = widget.heroTag;
    if (tag != null) image = Hero(tag: tag, child: image);
    return Listener(
      onPointerDown: (_) => _onPointer(1),
      onPointerUp: (_) => _onPointer(-1),
      onPointerCancel: (_) => _onPointer(-1),
      child: GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _tx,
        minScale: 1,
        maxScale: 6,
        onInteractionEnd: (_) => _scheduleDecodeSync(),
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
      ),
    );
  }
}
