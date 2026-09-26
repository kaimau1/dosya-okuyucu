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
import '../../models/photo_group.dart';
import '../../services/fm/image_rotate.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/fm_file_image.dart';
import '../viewer_screen.dart';
import 'entry_actions.dart';

/// Izgara hücresi ile galeri sayfasının ortak kahraman (Hero) etiketi:
/// fotoğraf hücreden büyüyerek açılır, kapanınca hücresine döner.
String fmMediaHeroTag(String path) => 'fm-media:$path';

/// Galerinin rotası (2026-09-26 galeri turu).
///
/// **Saydam** (`opaque: false`) ve SOLARAK gelir: fotoğraf hücreden büyürken
/// (Hero) arkadaki siyah yumuşakça belirir; aşağı kaydırıp kapatırken siyah
/// incelir ve altta ızgara görünür — Google Foto'daki his. Eskiden standart
/// sayfa geçişiyle sağdan kayıyordu: fotoğraf ile açılan sayfa arasında
/// görsel bir bağ yoktu.
Route<void> imageGalleryRoute({
  required List<String> paths,
  required int initialIndex,
}) =>
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) =>
          ImageGalleryScreen(paths: paths, initialIndex: initialIndex),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );

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

class _ImageGalleryScreenState extends State<ImageGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late final List<String> _paths = [...widget.paths];
  late int _index = widget.initialIndex.clamp(0, widget.paths.length - 1);
  bool _chromeVisible = true;

  /// Yakınlaştırılmış sayfa varken sayfa geçişi kilitlenir.
  bool _zoomed = false;

  // ── Aşağı kaydırıp kapatma (2026-09-26) ───────────────────────────────────
  /// Sayfanın dikey kayması (aşağı artı). Sürükleme bitince ya kapanır ya da
  /// [_snap] ile 0'a yaylanır.
  double _dragDy = 0;
  bool _dragging = false;
  double _snapFrom = 0;
  late final AnimationController _snap;

  @override
  void initState() {
    super.initState();
    _snap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_snap.value);
        setState(() => _dragDy = _snapFrom * (1 - t));
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precacheAround(_index);
    });
  }

  @override
  void dispose() {
    _snap.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// Komşu sayfaları önceden çözer: sağa/sola geçişte görsel HAZIR gelir
  /// (Google Foto'daki anında geçiş). Anahtar sayfanın kendi çözme
  /// genişliğiyle aynı (`ImageBudget.forViewport`, ölçek 1) — önbellekte
  /// aynı kayıt kullanılır, ikinci kez çözülmez.
  void _precacheAround(int i) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return;
    final width = ImageBudget.forViewport(
      logicalWidth: media.size.width,
      devicePixelRatio: media.devicePixelRatio,
      scale: 1,
    );
    for (final j in [i + 1, i - 1]) {
      if (j < 0 || j >= _paths.length) continue;
      precacheImage(
        FmFileImage(_paths[j], cacheWidth: width),
        context,
        onError: (_, __) {},
      );
    }
  }

  void _onDragStart(DragStartDetails d) {
    _snap.stop();
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // Yukarı sürükleme dirençli (bilgi sayfası için kısa bir çekiş yeter;
    // görsel yukarı uçup gitmesin).
    final dy = d.primaryDelta ?? d.delta.dy;
    setState(() => _dragDy += _dragDy + dy < 0 ? dy * 0.35 : dy);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    setState(() => _dragging = false);
    if (_dragDy > 110 || (v > 900 && _dragDy > 0)) {
      popOwnPage(context);
      return;
    }
    final showInfo = _dragDy < -60 || (v < -900 && _dragDy < 0);
    _snapFrom = _dragDy;
    _snap.forward(from: 0);
    if (showInfo) showProperties(context, _currentEntry);
  }

  /// Sürüklemenin ilerlemesi (0 → 1): arka plan inceltmesi ve küçülme.
  double _dragProgress(double height) =>
      height <= 0 ? 0 : (_dragDy / (height * 0.55)).clamp(0.0, 1.0);

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
    final height = MediaQuery.sizeOf(context).height;
    final progress = _dragProgress(height);
    // Sürüklerken çubuklar hızla söner (fotoğrafla birlikte kaymasınlar).
    final chromeOpacity = _chromeVisible && !_dragging && _dragDy.abs() < 1
        ? 1.0
        : 0.0;

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
          ignoring: chromeOpacity == 0,
          child: AnimatedOpacity(
            opacity: chromeOpacity,
            duration: const Duration(milliseconds: 180),
            child: child,
          ),
        );

    // Başlık ZAMAN (Google Foto): "Bugün · 18:44". "e8e4fcfccc…jpg" gibi
    // karma dosya adları bir şey anlatmıyordu; ad alt satırda duruyor.
    final title = entry.modifiedMs > 0
        ? photoMomentTitle(entry.modifiedMs)
        : entry.name;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // Rota saydam: siyah zemin burada, sürüklendikçe incelir ve arkadaki
        // ızgara görünür.
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 1 - progress),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                // Yakınlaştırılmışken dikey sürükleme resmi kaydırır; kapatma
                // yalnız tam görünümde (yoksa yakınlaştırılmış fotoğrafta
                // aşağı bakmak ekranı kapatırdı).
                onVerticalDragStart: _zoomed ? null : _onDragStart,
                onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
                onVerticalDragEnd: _zoomed ? null : _onDragEnd,
                child: Transform.translate(
                  offset: Offset(0, _dragDy),
                  child: Transform.scale(
                    scale: 1 - progress * 0.22,
                    child: PageView.builder(
                      controller: _pages,
                      physics: _zoomed || _dragging
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      onPageChanged: (i) {
                        setState(() {
                          _index = i;
                          _zoomed = false;
                        });
                        _precacheAround(i);
                      },
                      itemCount: _paths.length,
                      itemBuilder: (context, i) => _ZoomableImage(
                        path: _paths[i],
                        heroTag: fmMediaHeroTag(_paths[i]),
                        onTap: () =>
                            setState(() => _chromeVisible = !_chromeVisible),
                        onZoomChanged: (zoomed) {
                          if (zoomed != _zoomed) {
                            setState(() => _zoomed = zoomed);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Üst perde: geri, zaman, sıra/boyut/ad, daha fazla ──────────
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
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OverlayBar.title(context)),
                              Text(
                                '${_index + 1}/${_paths.length} · '
                                '${FsPaths.humanSize(entry.sizeBytes)} · '
                                '${entry.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
      ..translate(-position.dx * 1.5, -position.dy * 1.5)
      ..scale(2.5);
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
            style: const TextStyle(color: Colors.white70)),
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
