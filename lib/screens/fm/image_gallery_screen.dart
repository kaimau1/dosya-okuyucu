import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/busy_dialog.dart';
import '../../core/image_budget.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../models/fs_entry.dart';
import '../../models/photo_group.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/fm_file_image.dart';
import '../image_edit_screen.dart';
import '../viewer_screen.dart';
import 'entry_actions.dart';
import 'resize_actions.dart';

part 'image_gallery/widgets.dart';

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
      transitionDuration: Motion.long,
      reverseTransitionDuration: Motion.medium,
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
      duration: Motion.medium,
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
    } catch (_) {
      // Bilinçli: bilgi satırı (boyut/tarih) için; dosya o an silindiyse 0 gösterilir, galeri sonraki tazelemede düşürür.
    }
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

  /// Faz 10: döndürme artık düzenleyicinin içinde (kırp/ayarla/işaretle ile).
  Future<void> _edit() async {
    final written = await ImageEditScreen.open(context, _current);
    if (written == null || !mounted) return;
    _statCache.remove(_current);
    setState(() {});
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
            duration: Motion.of(context, Motion.short),
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
                color: AppColors.mediaSurface.withValues(alpha: 1 - progress),
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
                        const BackButton(color: AppColors.onMedia),
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
                          icon: const Icon(AppIcons.more, color: AppColors.onMedia),
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
                              icon: AppIcons.share,
                              label: context.t('common.share'),
                              onTap: () => shareEntriesFrom(context, [_current]),
                            ),
                            _GalleryAction(
                              icon: AppIcons.tune,
                              label: context.t('ied.title'),
                              onTap: _edit,
                            ),
                            // Faz 14 (G4i): boyutlandırma eskiden yalnız ⋮ →
                            // eylem sayfasındaydı; "fotoğrafı küçült" galerinin
                            // en sık işlerinden biri.
                            _GalleryAction(
                              icon: Icons.photo_size_select_large_rounded,
                              label: context.t('gal.resize'),
                              onTap: () =>
                                  startResizeJob(context, [_currentEntry]),
                            ),
                            _GalleryAction(
                              icon: AppIcons.ocr,
                              label: context.t('gal.tools'),
                              onTap: _openInViewer,
                            ),
                            _GalleryAction(
                              icon: AppIcons.info,
                              label: context.t('gal.info'),
                              onTap: () =>
                                  showProperties(context, _currentEntry),
                            ),
                            _GalleryAction(
                              icon: AppIcons.delete,
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
