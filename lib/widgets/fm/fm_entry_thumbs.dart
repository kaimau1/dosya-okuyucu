part of 'fm_entry_icon.dart';

/// Uzantısı olmayan bir dosyayı, **imzası görsel diyorsa** küçük resim olarak
/// çizer; demiyorsa (ya da bakılana kadar) [fallback] glifi kalır.
class _SniffedImage extends StatefulWidget {
  final String path;
  final double size;
  final double radius;
  final Widget fallback;

  const _SniffedImage({
    required this.path,
    required this.size,
    required this.fallback,
    this.radius = Radii.control,
  });

  @override
  State<_SniffedImage> createState() => _SniffedImageState();
}

class _SniffedImageState extends State<_SniffedImage> {
  // Önbellekte varsa İLK karede doğru çizilir (kaydırırken yanıp sönme olmaz).
  late bool? _isImage = ImageSniff.cached(widget.path);

  @override
  void initState() {
    super.initState();
    if (_isImage == null) _check();
  }

  @override
  void didUpdateWidget(covariant _SniffedImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _isImage = ImageSniff.cached(widget.path);
      if (_isImage == null) _check();
    }
  }

  Future<void> _check() async {
    final path = widget.path;
    final result = await ImageSniff.check(path);
    if (!mounted || path != widget.path) return;
    setState(() => _isImage = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage != true) return widget.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image(
        image: FmFileImage(widget.path,
            cover: true,
            cacheWidth: fmThumbWidth(widget.size,
                MediaQuery.maybeDevicePixelRatioOf(context) ?? 3)),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        frameBuilder: _placeholder(widget.size),
        errorBuilder: (_, _, _) => widget.fallback,
      ),
    );
  }
}

/// APK'nın kendi uygulama simgesi: önbellekten gelir, yoksa arka planda
/// çıkarılır. [_PdfThumb] / [_VideoThumb] ile aynı kalıp — üretim bitene kadar
/// (ve çıkarılamazsa) [fallback] görünür, liste asla boş kutu göstermez.
class _ApkIconImage extends StatefulWidget {
  final String path;
  final double size;
  final double radius;
  final Widget fallback;

  const _ApkIconImage({
    required this.path,
    required this.size,
    required this.fallback,
    this.radius = Radii.control,
  });

  @override
  State<_ApkIconImage> createState() => _ApkIconImageState();
}

class _ApkIconImageState extends State<_ApkIconImage> {
  String? _icon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ApkIconImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _icon = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    final result = await ApkIcon.forApk(path);
    if (!mounted || path != widget.path) return;
    setState(() => _icon = result);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    if (icon == null) return widget.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image(
        image: FmFileImage(icon, cacheWidth: fmThumbWidth(widget.size,
                MediaQuery.maybeDevicePixelRatioOf(context) ?? 3)),
        width: widget.size,
        height: widget.size,
        // `contain`: uygulama simgeleri kare ama kenar boşluklu olabiliyor;
        // `cover` onları kırpıp gliften bir parça koparırdı.
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      ),
    );
  }
}

/// PDF kapak küçük resmi: önbellekten gelir, yoksa arka planda üretilir.
///
/// [_VideoThumb] ile aynı kalıp — üretim bitene kadar (ve üretilemezse)
/// [fallback] simgesi görünür, liste asla boş kutu göstermez.
class _PdfThumb extends StatefulWidget {
  final String path;
  final double size;
  final double radius;
  final Widget fallback;

  /// Kapak üreticisi (yol, piksel boyu); verilmezse PDF'in ilk sayfası.
  /// Office belgeleri aynı "kâğıt" çerçevesini kullanır.
  final Future<String?> Function(String path, int size)? loader;

  const _PdfThumb({
    required this.path,
    required this.size,
    required this.fallback,
    this.radius = Radii.control,
    this.loader,
  });

  @override
  State<_PdfThumb> createState() => _PdfThumbState();
}

class _PdfThumbState extends State<_PdfThumb> {
  String? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PdfThumb old) {
    super.didUpdateWidget(old);
    // Liste öğesi geri dönüştürülüp başka belgeye bağlanabilir.
    if (old.path != widget.path) {
      _thumb = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    final size = (widget.size * 2).round().clamp(96, 512);
    final loader = widget.loader;
    final result = loader != null
        ? await loader(path, size)
        : await PdfThumbnail.forPdf(path, size: size);
    if (!mounted || path != widget.path) return;
    setState(() => _thumb = result);
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumb;
    if (thumb == null) return widget.fallback;
    // **Kağıt sayfası gibi çizilir** (2026-09-23 tasarım turu, kullanıcı
    // ekran görüntüsü: Belgeler listesi). Kapak kutuya `contain` ile
    // oturuyordu ama çerçevesi yoktu: beyaz sayfa beyaz zeminde eriyor,
    // listede yalnız yüzen birkaç yazı satırı görünüyordu. Artık sayfanın
    // KENDİ boyunda ince kenarlık + hafif gölge: satırda gerçek bir belge
    // kapağı duruyor. Kutu kare kalıyor (satır hizası bozulmaz); sayfa
    // oranı korunuyor (kırpılmış kapak yanlış belgeymiş gibi görünür).
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.onMedia,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: scheme.outlineVariant, width: 0.8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 4,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3.5),
            child: Image(
              image: FmFileImage(thumb, cacheWidth: fmThumbWidth(widget.size,
                MediaQuery.maybeDevicePixelRatioOf(context) ?? 3)),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => widget.fallback,
            ),
          ),
        ),
      ),
    );
  }
}

/// Video küçük resmi: önbellekten gelir, yoksa arka planda üretilir.
/// Üretim bitene kadar (ve üretilemezse) [fallback] ikonu görünür — liste
/// asla boş kutu göstermez.
/// Fotoğraf hücresi: Android'in ürettiği küçük JPEG'i gösterir (2026-11-03
/// kaydırma takılması — kök neden [ThumbnailCache.forImage] notunda).
class _PhotoThumb extends StatefulWidget {
  final FsEntry entry;
  final double size;
  final double radius;
  final Widget fallback;

  const _PhotoThumb({
    required this.entry,
    required this.size,
    required this.radius,
    required this.fallback,
  });

  @override
  State<_PhotoThumb> createState() => _PhotoThumbState();
}

class _PhotoThumbState extends State<_PhotoThumb> {
  String? _thumb;

  /// Başka ölçüde hazır duran küçük resim (bkz.
  /// [ThumbnailCache.anyKnownImage]): keskini gelene kadar gösterilir.
  String? _preview;
  bool _failed = false;
  int _width = 0;

  String get _path => widget.entry.path;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = fmThumbWidth(
        widget.size, MediaQuery.maybeDevicePixelRatioOf(context) ?? 3);
    if (w == _width) return;
    _width = w;
    _start();
  }

  @override
  void didUpdateWidget(covariant _PhotoThumb old) {
    super.didUpdateWidget(old);
    if (old.entry.path != _path ||
        old.entry.modifiedMs != widget.entry.modifiedMs) {
      _start();
    }
  }

  void _start() {
    _failed = false;
    // Diskte olduğu biliniyorsa EŞZAMANLI: geri kaydırınca boş kare yok.
    _thumb = ThumbnailCache.knownImage(_path, widget.entry.modifiedMs, _width);
    if (_thumb == null) {
      _preview =
          ThumbnailCache.anyKnownImage(_path, widget.entry.modifiedMs);
      _load();
    }
  }

  Future<void> _load() async {
    final path = _path;
    // Hızlı savurmada bekle (aynı kural: [_VideoThumbState._load]).
    if (Scrollable.recommendDeferredLoadingForContext(context)) {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        scheduleMicrotask(() {
          if (mounted && path == _path && _thumb == null && !_failed) _load();
        });
      });
      return;
    }
    final result = await ThumbnailCache.forImage(path,
        modifiedMs: widget.entry.modifiedMs,
        size: _width,
        wanted: () => mounted && path == _path);
    if (!mounted || path != _path) return;
    setState(() {
      _thumb = result;
      _failed = result == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    final exact = _thumb;
    final thumb = exact ?? _preview;
    if (thumb == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest),
      );
    }
    // Küçük resim dosyası zaten hücre ölçüsünde (kısa kenarı [_width]):
    // ikinci kez küçültülmez. Eskiden `cacheWidth` GENİŞLİĞİ kısıtlıyordu —
    // yatay fotoğrafta yükseklik hücrenin altına düşüp `cover` ile yeniden
    // büyütülüyordu (bulanıklığın ikinci kaynağı, 2026-11-04).
    final provider = FmFileImage(thumb);
    if (exact != null) fmRememberThumb(_path, provider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image(
        image: provider,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        // Orta: küçültürken kenarlar tırtıklanmaz (küçük resim ≤ 768 px,
        // maliyeti ihmal edilir).
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        frameBuilder: _placeholder(widget.size),
        errorBuilder: (_, _, _) => widget.fallback,
      ),
    );
  }
}

class _VideoThumb extends StatefulWidget {
  final String path;
  final double size;
  final double radius;
  final Widget fallback;

  const _VideoThumb({
    required this.path,
    required this.size,
    required this.fallback,
    this.radius = Radii.control,
  });

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  String? _thumb;

  /// Süre rozeti (kullanıcı isteği 2026-08-28: *"videolarda dk ve sn'si
  /// önizlemedeyken sağ alt köşesinde yazmalı"*). Küçük resimden AYRI
  /// yükleniyor: ikisi farklı native çağrı ve süre gelmeden küçük resmi
  /// bekletmek listeyi geciktirirdi.
  String? _duration;
  bool _started = false;

  /// İlk yükleme `initState`te DEĞİL: [_load] kaydırma hızını soruyor
  /// (`Scrollable.recommendDeferredLoadingForContext` → `View.of`) ve
  /// `initState` içinde kalıtılan widget'a bağımlılık kurmak yasak — hata
  /// ayıklama derlemesinde kırmızı ekran, yayında sessizce eskiyen değer.
  /// (2026-10-18 görsel denetimde dosya işlem menüsünün başlığındaki video
  /// simgesiyle yakalandı.)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void didUpdateWidget(covariant _VideoThumb old) {
    super.didUpdateWidget(old);
    // Liste öğesi geri dönüştürülüp başka videoya bağlanabilir.
    if (old.path != widget.path) {
      _thumb = null;
      _duration = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    // **Hızlı savurmada bekle** (2026-09-26): 748 videoluk ızgarada parmakla
    // savurunca saniyede onlarca hücre bir anlığına kuruluyor ve her biri
    // yerel küçük resim + süre çağrısı başlatıyordu; kuyruk dolunca durduğun
    // yerdeki videolar en son geliyordu. Flutter'ın görsellerde yaptığının
    // aynısı (`ScrollAwareImageProvider`): kaydırma hızı "ertele" diyorsa bir
    // sonraki kareye kadar bekle; hücre o arada ekrandan çıkarsa iş hiç
    // başlamaz.
    if (Scrollable.recommendDeferredLoadingForContext(context)) {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        scheduleMicrotask(() {
          if (mounted && path == widget.path && _thumb == null) _load();
        });
      });
      return;
    }
    unawaited(_loadDuration(path));
    final result = await ThumbnailCache.forVideo(path,
        size: (widget.size * 2).round().clamp(96, 512),
        // Sırası geldiğinde hücre ekrandan çıkmışsa kare hiç çözülmez.
        wanted: () => mounted && path == widget.path);
    if (!mounted || path != widget.path) return;
    // Küçük resim üretilemedi: dosya silinmiş olabilir (bkz. FsEvents).
    if (result == null) FsEvents.reportUnreadable(path);
    setState(() => _thumb = result);
  }

  Future<void> _loadDuration(String path) async {
    final duration = await MediaDuration.forVideo(path);
    if (!mounted || path != widget.path || duration == null) return;
    setState(() => _duration = MediaDuration.format(duration));
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumb;
    if (thumb == null) return widget.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Image(
            image: FmFileImage(thumb,
                cover: true,
                cacheWidth: fmThumbWidth(widget.size,
                    MediaQuery.maybeDevicePixelRatioOf(context) ?? 3)),
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => widget.fallback,
          ),
          // **Tek rozet: ▶ + süre, SAĞ ALT köşe** (2026-09-26 galeri turu).
          // Eskiden iki ayrı rozet vardı — sol altta oynat dairesi, sağ altta
          // süre kutusu — ve küçük hücrede ikisi birlikte karenin alt
          // şeridini kaplıyordu. Google Foto/Samsung Galeri'deki gibi tek hap:
          // "bu bir video" ve "ne kadar sürüyor" aynı yerde okunur.
          // Süre sağ altta KALDI (kullanıcı isteği 2026-08-28: *"videolarda
          // dk ve sn'si önizlemedeyken sağ alt köşesinde yazmalı"*); oynat
          // rozeti köşede kaldı (2026-08-09: ortadaki daire yüzü kapatıyordu).
          //
          // `PositionedDirectional`: Arapça (sağdan sola) arayüzde kendiliğinden
          // karşı köşeye geçer.
          PositionedDirectional(
            end: widget.size * 0.05,
            bottom: widget.size * 0.05,
            child: _VideoBadge(
              size: widget.size,
              // Küçük hücrelerde (liste satırı, 44 px) yazı okunmaz ve karenin
              // yarısını kaplardı; eşik altında yalnız ▶ çizilir.
              duration: widget.size >= 56 ? _duration : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Video rozeti: yarı saydam hap içinde ▶ ve (biliniyorsa) süre.
class _VideoBadge extends StatelessWidget {
  final double size;
  final String? duration;

  const _VideoBadge({required this.size, this.duration});

  @override
  Widget build(BuildContext context) {
    final font = (size * 0.12).clamp(9.0, 12.5);
    final icon = (size * 0.13).clamp(11.0, 16.0);
    final text = duration;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.shade.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: text == null ? 2 : 5,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.play, size: icon, color: AppColors.onMedia),
            if (text != null) ...[
              const SizedBox(width: 1),
              Text(
                text,
                // Kullanıcının uygulama içi yazı ölçeği rozeti taşırmasın.
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: AppColors.onMedia,
                  fontSize: font,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bir depolama biriminin simgesi (ana bellek · SD kart · USB).
///
/// Tek yerde: eskiden üç ekran "birincil değilse SD kart" diyordu ve takılan
/// bir USB bellek SD kart simgesiyle görünüyordu (kullanıcı bulgusu
/// 2026-09-01).
IconData volumeIcon(StorageVolume volume) => switch (volume.iconName) {
      'smartphone' => AppIcons.device,
      'usb' => AppIcons.external,
      _ => AppIcons.sdCard,
    };

/// Önemli dosya rozeti: koyu daire üstünde sarı yıldız (her zeminde okunur).
class FmImportantBadge extends StatelessWidget {
  final double size;
  const FmImportantBadge({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.t('important.badge'),
        child: Container(
          key: const ValueKey<String>('fm-important-badge'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.mediaSurface.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(AppIcons.star,
              size: size * 0.78, color: AppHues.amberBright),
        ),
      );
}
