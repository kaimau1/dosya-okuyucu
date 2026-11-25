import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

// Hero etiketi dosya listesiyle ortak (Ferrari H6.3) — tanım simge dosyasında.
export '../../widgets/fm/fm_entry_icon.dart' show fmMediaHeroTag;

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
import '../../services/fm/image_rotate.dart';
import '../../services/fm/important_files.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../core/user_error.dart';
import '../../services/image_enhance.dart';
import '../../services/fm/enhance_jobs.dart';
import '../../services/fm/job_queue.dart';
import '../../services/image_repair.dart';
import '../../services/fm/native_extras.dart';
import '../../services/side_menu.dart';
import '../../core/snack.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_file_image.dart';
import '../../widgets/fm/image_qr_chip.dart';
import '../image_edit_screen.dart';
import '../viewer_screen.dart';
import 'entry_actions.dart';
import 'resize_compare_screen.dart';

part 'image_gallery/widgets.dart';


final _galleryFadeCurve = CurveTween(curve: Curves.easeOut);
final _galleryScaleTween = Tween<double>(begin: 0.90, end: 1.0);
final _galleryChromeCurve =
    CurveTween(curve: const Interval(0.28, 1.0, curve: Curves.easeOut));

/// Galerinin rotası (2026-09-26 galeri turu · 2026-11-24 animasyon güvencesi).
///
/// **Saydam** (`opaque: false`) ve arka plan perdesi solarak gelir:
/// - Kaynak ekranda eşleşen bir `Hero` varsa ([hasHero] true) fotoğraf
///   hücreden doğrudan büyür; tam ekran `saveLayer` açılmaz.
/// - Kaynakta `Hero` yoksa ([hasHero] false — ör. temizlik, bildirim veya
///   kısayol satırları) fotoğraf çat diye açılmak yerine yumuşak ölçek +
///   solma ile açılır ve kapanır.
PageRouteBuilder<void> imageGalleryRoute({
  required List<String> paths,
  required int initialIndex,
  bool hasHero = true,
}) =>
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Motion.long,
      reverseTransitionDuration: Motion.medium,
      pageBuilder: (_, _, _) =>
          ImageGalleryScreen(paths: paths, initialIndex: initialIndex),
      transitionsBuilder: (context, animation, _, child) {
        if (Motion.reduced(context) || hasHero) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Motion.enter,
          reverseCurve: Motion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: _galleryScaleTween.animate(curved),
            child: child,
          ),
        );
      },
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

  /// **Slayt gösterisi** (Faz 18 / G19): 3/5/10 sn'de bir sonraki fotoğraf;
  /// dokunuşla ya da son fotoğrafta durur. Çubuklar gösteri boyunca gizli.
  Timer? _slideTimer;
  bool get _slideshow => _slideTimer != null;

  /// Yakınlaştırılmış sayfa varken sayfa geçişi kilitlenir.
  bool _zoomed = false;

  /// **Görünümde döndürme** (kullanıcı isteği 2026-11-04: *"sağa sola çevir
  /// butonu … görsellerde de"*): yol → saat yönünde çeyrek tur. Dosyaya
  /// dokunulmaz; ⋮ → "Döndürülmüş hâlini kaydet" yanına yeni dosya yazar.
  final Map<String, int> _turns = {};

  int _turnsOf(String path) => _turns[path] ?? 0;

  void _rotateBy(int delta) {
    final path = _current;
    setState(() {
      final t = (_turnsOf(path) + delta) % 4;
      if (t == 0) {
        _turns.remove(path);
      } else {
        _turns[path] = t;
      }
    });
  }

  Future<void> _saveRotation() async {
    final path = _current;
    final turns = _turnsOf(path);
    if (turns == 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    showSnackOn(messenger, strings.t('rotate.working'));
    try {
      final out = await ImageRotate.rotate(path, quarterTurns: turns);
      if (!mounted) return;
      setState(() {
        _turns.remove(path);
        // Yeni dosya hemen yanında açılır: kullanıcı sonucu görür.
        _paths.insert(_index + 1, out);
      });
      showSnackOn(messenger, strings.t('rotate.done', {'name': p.basename(out)}));
    } catch (e) {
      showSnackOn(messenger, strings.t('rotate.failed', {'error': userErrorText(e)}));
    }
  }

  // ── Aşağı kaydırıp kapatma (2026-09-26) ───────────────────────────────────
  /// Sayfanın dikey kayması (aşağı artı). Yalnız arka perde + Transform
  /// dinler — sürüklerken tüm PageView yeniden kurulmaz.
  final ValueNotifier<double> _dragDy = ValueNotifier<double>(0);
  bool _dragging = false;
  double _snapFrom = 0;
  late final AnimationController _snap;
  Timer? _precacheTimer;

  @override
  void initState() {
    super.initState();
    _snap = AnimationController(
      vsync: this,
      duration: Motion.medium,
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_snap.value);
        _dragDy.value = _snapFrom * (1 - t);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) setState(() {});
      });
    // Komşuların çözümü açılış geçişi BİTİNCE (2026-11-18): iki tam boy
    // çözüm büyüme animasyonuyla aynı çekirdekleri paylaşıp kare
    // kaçırtıyordu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) {
        _precacheAround(_index);
        return;
      }
      late final AnimationStatusListener listener;
      listener = (status) {
        if (status == AnimationStatus.forward) return;
        animation.removeStatusListener(listener);
        if (mounted && status == AnimationStatus.completed) {
          _precacheAround(_index);
        }
      };
      animation.addStatusListener(listener);
    });
    _enhanceSub = EnhanceJobs.results.listen(_onEnhanced);
    _unhideMenuHandle = SideMenu.instance.hideHandle();
  }

  VoidCallback? _unhideMenuHandle;

  StreamSubscription<EnhanceResult>? _enhanceSub;

  @override
  void dispose() {
    _unhideMenuHandle?.call();
    _enhanceSub?.cancel();
    _slideTimer?.cancel();
    _precacheTimer?.cancel();
    _dragDy.dispose();
    _snap.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _schedulePrecache(int i) {
    _precacheTimer?.cancel();
    // 150 ms yerleşme gecikmesi: hızlı sayfa kaydırmada ara görselleri çözme.
    _precacheTimer = Timer(const Duration(microseconds: 150000), () {
      if (mounted) _precacheAround(i);
    });
  }

  /// Komşu sayfaları önceden çözer: sağa/sola geçişte görsel HAZIR gelir
  /// (Google Foto'daki anında geçiş). Anahtar sayfanın kendi çözme
  /// boyuyla aynı (`ImageBudget.forViewport`, ölçek 1) — önbellekte
  /// aynı kayıt kullanılır, ikinci kez çözülmez.
  void _precacheAround(int i) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return;
    final budget = ImageBudget.forViewport(
      logicalWidth: media.size.width,
      logicalHeight: media.size.height,
      devicePixelRatio: media.devicePixelRatio,
      scale: 1,
    );
    for (final j in [i + 1, i - 1]) {
      if (j < 0 || j >= _paths.length) continue;
      precacheImage(
        FmFileImage(_paths[j], cacheWidth: budget, maxLongSide: budget),
        context,
        onError: (_, _) {},
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
    final cur = _dragDy.value;
    _dragDy.value = cur + (cur + dy < 0 ? dy * 0.35 : dy);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dy = _dragDy.value;
    setState(() => _dragging = false);
    if (dy > 110 || (v > 900 && dy > 0)) {
      popOwnPage(context);
      return;
    }
    final showInfo = dy < -60 || (v < -900 && dy < 0);
    _snapFrom = dy;
    _snap.forward(from: 0);
    if (showInfo) showProperties(context, _currentEntry);
  }

  /// Sürüklemenin ilerlemesi (0 → 1): arka plan inceltmesi ve küçülme.
  double _dragProgress(double height, double dy) =>
      height <= 0 ? 0 : (dy / (height * 0.55)).clamp(0.0, 1.0);

  String get _current => _paths[_index];

  /// Dosya bilgisi (boyut/tarih) yol başına bir kez EŞZAMANSIZ ölçülür.
  final Map<String, FsEntry> _statCache = {};
  final Set<String> _statLoading = {};

  FsEntry get _currentEntry => _entryFor(_current);

  FsEntry _entryFor(String path) {
    final cached = _statCache[path];
    if (cached != null) return cached;
    if (!_statLoading.contains(path)) {
      _statLoading.add(path);
      unawaited(File(path).stat().then((stat) {
        _statLoading.remove(path);
        if (!mounted) return;
        if (_statCache.length > 64) _statCache.clear();
        _statCache[path] = FsEntry(
          path: path,
          name: p.basename(path),
          isDir: false,
          sizeBytes: stat.size,
          modifiedMs: stat.modified.millisecondsSinceEpoch,
        );
        if (path == _current) setState(() {});
      }, onError: (Object _) {
        _statLoading.remove(path);
      }));
    }
    return FsEntry(
      path: path,
      name: p.basename(path),
      isDir: false,
      sizeBytes: 0,
      modifiedMs: 0,
    );
  }

  // ── Seçim kipi (kullanıcı isteği 2026-11-07: *"alt alanda seç seçeneği …
  // toplu silme"*): alttaki "Seç" ile açılır; küçük resim şeridine dokunmak
  // ilgili fotoğrafı seçer/bırakır (ve ona geçer). Silme/paylaşma seçilenlere.
  bool _selecting = false;
  final Set<String> _selected = {};

  void _startSelect() => setState(() {
        _selecting = true;
        _selected
          ..clear()
          ..add(_current);
      });

  void _endSelect() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  void _toggle(String path) => setState(() {
        if (!_selected.remove(path)) _selected.add(path);
      });

  void _pickInSelect(int i) {
    _toggle(_paths[i]);
    _jumpTo(i);
  }

  void _selectAllOrNone() => setState(() {
        if (_selected.length == _paths.length) {
          _selected.clear();
        } else {
          _selected.addAll(_paths);
        }
      });

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final victims = [for (final p0 in _paths) if (_selected.contains(p0)) p0];
    await deleteEntries(context, [for (final v in victims) _entryFor(v)]);
    if (!mounted) return;
    // Başarıyı dosyanın yokluğundan ölç (kısmi başarısızlıkta kalanlar kalır).
    final gone = <String>{
      for (final v in victims)
        if (!await File(v).exists()) v
    };
    if (gone.isEmpty || !mounted) return;
    final current = _current;
    setState(() {
      _paths.removeWhere(gone.contains);
      _selected.removeAll(gone);
      for (final g in gone) {
        _statCache.remove(g);
        _turns.remove(g);
      }
      if (_paths.isNotEmpty) {
        final at = _paths.indexOf(current);
        _index = at >= 0 ? at : _index.clamp(0, _paths.length - 1);
      }
      if (_selected.isEmpty) _selecting = false;
    });
    if (_paths.isEmpty) {
      popOwnPage(context);
      return;
    }
    _pages.jumpToPage(_index);
  }

  Widget _selectionBar() {
    final total = _paths.length;
    return Row(
      children: [
        IconButton(
          key: const ValueKey<String>('gal-select-close'),
          tooltip: context.t('common.cancel'),
          icon: const Icon(AppIcons.close, color: AppColors.onMedia),
          onPressed: _endSelect,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            context.t('fm.selected_count',
                {'n': _selected.length, 'total': total}),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OverlayBar.title(context),
          ),
        ),
        IconButton(
          key: const ValueKey<String>('gal-select-all'),
          tooltip: context.t(_selected.length == total
              ? 'fm.select_none'
              : 'fm.select_all'),
          icon: Icon(
              _selected.length == total
                  ? AppIcons.selectNone
                  : AppIcons.selectAll,
              color: AppColors.onMedia),
          onPressed: _selectAllOrNone,
        ),
      ],
    );
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

  /// **İyileştir** (kullanıcı isteği 2026-11-02: *"bulanık görselleri
  /// iyileştirme"*): seçilen yöntemle `<ad>_iyi.jpg` kopyası kaydedilir ve
  /// galeri ona geçer — önce/sonra kaydırarak karşılaştırılabilsin.
  Future<void> _enhance() async {
    final str = AppStrings.of(context);
    final kind = await showAppActionSheet<EnhanceKind>(
      context,
      title: str.t('gal.enhance'),
      groups: [
        AppActionGroup(actions: [
          AppAction(
            value: EnhanceKind.auto,
            icon: AppIcons.autoFixNormal,
            label: str.t('gal.enh_auto'),
            hint: str.t('gal.enh_auto_hint'),
          ),
          AppAction(
            value: EnhanceKind.sharpen,
            icon: AppIcons.zoomIn,
            label: str.t('gal.enh_sharpen'),
          ),
          AppAction(
            value: EnhanceKind.denoise,
            icon: AppIcons.blur,
            label: str.t('gal.enh_denoise'),
          ),
          AppAction(
            value: EnhanceKind.upscale,
            icon: AppIcons.photoFilter,
            label: str.t('gal.enh_ai'),
            hint: str.t(ImageEnhance.modelReady
                ? 'gal.enh_ai_hint'
                : 'gal.enh_ai_download'),
            accent: true,
          ),
        ]),
      ],
    );
    if (kind == null || !mounted) return;
    // Arka planda (2026-11-03): modal pencere yok, kullanıcı gezinmeye devam
    // eder; ilerleme bu ekranda hap olarak, şeritte ve bildirimde görünür.
    final job = EnhanceJobs.start(_current, kind);
    showSnack(context, str.t(job == null ? 'gal.enh_already' : 'gal.enh_started'));
  }

  /// Arka plandaki iyileştirme bitti: yeni kopya özgünün hemen ardına girer
  /// (kaydırınca önce/sonra) ve "Önce / sonra" karşılaştırması sunulur.
  void _onEnhanced(EnhanceResult r) {
    if (!mounted) return;
    final at = _paths.indexOf(r.source);
    if (at < 0 || _paths.contains(r.output)) return;
    setState(() {
      _paths.insert(at + 1, r.output);
      if (_index > at) _index++;
    });
    if (_index != _pages.page?.round()) _pages.jumpToPage(_index);
    final str = AppStrings.of(context);
    showSnack(
      context,
      str.t('gal.enh_saved', {'name': p.basename(r.output)}),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: str.t('gal.enh_compare'),
        onPressed: () => _openCompare(r.source, r.output),
      ),
    );
  }

  void _openCompare(String source, String output) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResizeCompareScreen(
          pairs: [ResizePair(source, output)], enhance: true),
    ));
  }

  /// Bu görsel için süren iyileştirme (ilerleme hapı).
  FmJob? _enhanceJobFor(String path) {
    for (final j in JobQueue.instance.jobs) {
      final t = j.target;
      if (t?.kind == FmJobTargetKind.enhance &&
          t!.paths.isNotEmpty &&
          t.paths.first == path &&
          j.status.isActive) {
        return j;
      }
    }
    return null;
  }

  final Map<String, bool> _enhancedExists = {};
  final Set<String> _enhancedChecking = {};

  /// Bu görselin biten son iyileştirmesinin kopyası (hâlâ diskteyse, eşzamansız).
  String? _enhancedOf(String path) {
    for (final j in JobQueue.instance.jobs) { // en yeni önce
      if (j.target?.kind != FmJobTargetKind.enhance) continue;
      for (final out in j.outputs) {
        if (j.outputSources[out] != path) continue;
        final cached = _enhancedExists[out];
        if (cached == true) return out;
        if (cached == null && !_enhancedChecking.contains(out)) {
          _enhancedChecking.add(out);
          unawaited(File(out).exists().then((ok) {
            _enhancedChecking.remove(out);
            if (!mounted) return;
            _enhancedExists[out] = ok;
            if (ok) setState(() {});
          }));
        }
      }
    }
    return null;
  }

  Widget _enhanceChip() => ListenableBuilder(
        listenable: JobQueue.instance,
        builder: (context, _) {
          final path = _current;
          final job = _enhanceJobFor(path);
          final done = job == null ? _enhancedOf(path) : null;
          if (job == null && done == null) return const SizedBox.shrink();
          final pct = job == null || job.total <= 0
              ? null
              : (job.done * 100 ~/ job.total).clamp(0, 100);
          return Material(
            key: const ValueKey('gal-enhance-chip'),
            color: AppColors.mediaScrim,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: done == null ? null : () => _openCompare(path, done),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (job != null)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: pct == null || pct == 0 ? null : pct / 100,
                        color: AppColors.onMedia,
                      ),
                    )
                  else
                    const Icon(AppIcons.compare,
                        size: 16, color: AppColors.onMedia),
                  const SizedBox(width: 8),
                  Text(
                    job != null
                        ? (pct == null
                            ? context.t('gal.enh_working')
                            : context.t('gal.enh_running', {'n': pct}))
                        : context.t('gal.enh_compare'),
                    style: context.type.caption
                        .copyWith(color: AppColors.onMedia),
                  ),
                ]),
              ),
            ),
          );
        },
      );

  /// **⋮ = ortak dosya levhası** (2026-11-15, kullanıcı: *"hepsi ortak bir
  /// dile ve düzene kavuşmalı"*). Eskiden ayrı küçük açılır menüydü ve dosya
  /// işleri "Diğer işlemler"in arkasındaydı (üç kat). Artık üstte taşı /
  /// kopyala / yeniden adlandır / önemli / sil, altında galeriye özel işler
  /// ayrı renkte. Paylaş alt çubukta olduğu için levhada yok.
  Future<void> _otherActions() async {
    final path = _current;
    final changed = await showEntryActions(
      context,
      _currentEntry,
      inViewer: true,
      showShare: false,
      groups: [
        EntryExtraGroup(context.t('dm.image'), [
          if (_turnsOf(path) != 0 && ImageRotate.canRotate(path))
            EntryExtraAction(
              icon: AppIcons.save,
              label: context.t('gal.save_rotation'),
              onTap: () => unawaited(_saveRotation()),
            ),
          if (_paths.length > 1)
            EntryExtraAction(
              icon: AppIcons.slideshow,
              label: context.t('gal.slideshow'),
              onTap: () => unawaited(_pickSlideshow()),
            ),
          EntryExtraAction(
            icon: AppIcons.checkCircleOutline,
            label: context.t('gal.multi_select'),
            onTap: _startSelect,
          ),
          if (Platform.isAndroid)
            EntryExtraAction(
              icon: AppIcons.openWith,
              label: context.t('gal.use_as'),
              onTap: () => unawaited(_attachAs()),
            ),
        ]),
      ],
    );
    // Yeniden adlandırma/taşıma dosyayı değiştirmiş olabilir: ölçüm önbelleği
    // bayat kalmasın.
    _statCache.remove(path);
    if (!mounted) return;
    // Silindi / taşındı / adı değişti: artık bu yolda yok → şeritten çıkar.
    if (changed && !await File(path).exists() && mounted) {
      setState(() {
        final at = _paths.indexOf(path);
        if (at >= 0) _paths.removeAt(at);
        if (_paths.isEmpty) {
          popOwnPage(context);
          return;
        }
        _index = _index.clamp(0, _paths.length - 1);
        _pages.jumpToPage(_index);
      });
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickSlideshow() async {
    final secs = await showAppSheet<int>(
      context,
      title: context.t('gal.slideshow'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in const [3, 5, 10])
            ListTile(
              key: ValueKey('slideshow-$s'),
              leading: const Icon(AppIcons.slideshow),
              title: Text(ctx.t('gal.slideshow_every', {'n': s})),
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (secs != null && mounted) _startSlideshow(Duration(seconds: secs));
  }

  void _startSlideshow(Duration every) {
    _slideTimer?.cancel();
    setState(() {
      _chromeVisible = false;
      _slideTimer = Timer.periodic(every, (_) {
        if (!mounted) return;
        if (_index >= _paths.length - 1) {
          _stopSlideshow();
          return;
        }
        Motion.toPage(context, _pages, _index + 1, duration: Motion.long);
      });
    });
  }

  void _stopSlideshow() {
    _slideTimer?.cancel();
    setState(() {
      _slideTimer = null;
      _chromeVisible = true;
    });
  }

  /// "Farklı kullan" — duvar kâğıdı, kişi fotoğrafı (sistem seçicisi).
  Future<void> _attachAs() async {
    final ok = await NativeExtras.attachData(
        _current, _mimeOf(_current), context.t('gal.use_as'));
    if (!ok && mounted) showSnack(context, context.t('gal.use_as_failed'));
  }

  static String _mimeOf(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        '.heic' || '.heif' => 'image/heif',
        _ => 'image/jpeg',
      };

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
    final routeAnim = ModalRoute.of(context)?.animation;
    final reduced = Motion.reduced(context);
    // Sürüklerken çubuklar hızla söner (fotoğrafla birlikte kaymasınlar).
    final chromeOpacity = _chromeVisible && !_dragging && _dragDy.value.abs() < 1
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
    Widget chrome({required Widget child}) {
      Widget body = IgnorePointer(
        // Gizliyken dokunuşları yutmasın: görünmez çubuğa değil resme gitsin.
        ignoring: chromeOpacity == 0,
        child: AnimatedOpacity(
          opacity: chromeOpacity,
          duration: Motion.of(context, Motion.short),
          child: child,
        ),
      );
      if (routeAnim != null && !reduced) {
        body = FadeTransition(
          opacity: routeAnim.drive(_galleryChromeCurve),
          child: body,
        );
      }
      return body;
    }

    // Başlık dosya ADI, altında yalnız TARİH (kullanıcı 2026-11-15: *"tarihi
    // varsa adının altına yazsın, diğer detay bilgiler gereksiz"*). Sıra/boyut
    // alt satırdan kalktı; boyut Bilgi'de duruyor.
    final title = entry.name;
    final moment =
        entry.modifiedMs > 0 ? photoMomentTitle(entry.modifiedMs) : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: !_selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selecting) _endSelect();
        },
        child: Scaffold(
        // Rota saydam: siyah zemin burada, sürüklendikçe incelir ve arkadaki
        // ızgara görünür.
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  _dragDy,
                  if (routeAnim != null && !reduced) routeAnim,
                ]),
                builder: (context, _) {
                  final routeAlpha = (routeAnim == null || reduced)
                      ? 1.0
                      : _galleryFadeCurve.evaluate(routeAnim);
                  final progress = _dragProgress(height, _dragDy.value);
                  final alpha = (routeAlpha * (1 - progress)).clamp(0.0, 1.0);
                  return ColoredBox(
                    color: AppColors.mediaSurface.withValues(alpha: alpha),
                  );
                },
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
                child: ValueListenableBuilder<double>(
                  valueListenable: _dragDy,
                  builder: (context, dy, child) {
                    final progress = _dragProgress(height, dy);
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.scale(
                        scale: 1 - progress * 0.22,
                        child: child,
                      ),
                    );
                  },
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
                      _schedulePrecache(i);
                    },
                    itemCount: _paths.length,
                    itemBuilder: (context, i) => RotatedBox(
                      quarterTurns: _turnsOf(_paths[i]),
                      child: _ZoomableImage(
                        key: ValueKey(_paths[i]),
                        path: _paths[i],
                        heroTag: fmMediaHeroTag(_paths[i]),
                        onTap: () => _slideshow
                            ? _stopSlideshow()
                            : setState(() => _chromeVisible = !_chromeVisible),
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
            // ── İyileştirme hapı: sürüyorsa ilerleme, bittiyse "Önce / sonra"
            Positioned(
              top: padding.top + 64,
              left: 0,
              right: 0,
              child: chrome(child: Center(child: _enhanceChip())),
            ),
            // ── Görseldeki QR (2026-11-18): durunca tanınır, dokununca bağlantı.
            // Ağaç şekli sabit (kasma-kontrol 3): Positioned hep var.
            PositionedDirectional(
              top: padding.top + 64,
              end: 12,
              child: chrome(
                  child: _selecting
                      ? const SizedBox.shrink()
                      : ImageQrChip(path: _current)),
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
                      colors: [Color(0xCC000000), AppColors.none],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4, padding.top + 4, 4, 28),
                    child: _selecting
                        ? _selectionBar()
                        : Row(
                      children: [
                        const BackButton(color: AppColors.onMedia),
                        const SizedBox(width: 4),
                        if (ImportantFiles.isImportant(_current)) ...[
                          const FmImportantBadge(size: 22),
                          const SizedBox(width: 6),
                        ],
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
                              if (moment != null)
                                Text(
                                  moment,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OverlayBar.subtitle(context),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const ValueKey<String>('gal-rotate-left'),
                          tooltip: context.t('mp.rotate_left'),
                          icon: const Icon(AppIcons.rotateLeft,
                              color: AppColors.onMedia),
                          onPressed: () => _rotateBy(3),
                        ),
                        IconButton(
                          key: const ValueKey<String>('gal-rotate-right'),
                          tooltip: context.t('mp.rotate_right'),
                          icon: const Icon(AppIcons.rotateRight,
                              color: AppColors.onMedia),
                          onPressed: () => _rotateBy(1),
                        ),
                        IconButton(
                          key: const ValueKey<String>('gal-more'),
                          tooltip: context.t('common.more'),
                          icon: const Icon(AppIcons.more, color: AppColors.onMedia),
                          onPressed: () => unawaited(_otherActions()),
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
                      colors: [Color(0xE6000000), AppColors.none],
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
                            onPick: _selecting ? _pickInSelect : _jumpTo,
                            selected: _selecting ? _selected : null,
                          ),
                        // KÖK (kullanıcı 2026-11-25: "silindi bildirimi silme
                        // alanını kapatıyor, sıradaki fotoğrafı silemiyorum"):
                        // "Geri al" kartı ekranın en altına oturuyor ve bu
                        // satırın üstüne biniyordu. Satır yüksekliğini
                        // bildirir → kart düğmelerin ÜSTÜNDE durur, Sil'e art
                        // arda basılabilir.
                        if (_selecting)
                          ToastAvoider(child: Row(
                            children: [
                              _GalleryAction(
                                icon: _selected.contains(_current)
                                    ? AppIcons.checkCircle
                                    : AppIcons.checkCircleOutline,
                                label: context.t('ied.select'),
                                onTap: () => _toggle(_current),
                              ),
                              _GalleryAction(
                                icon: AppIcons.share,
                                label: context.t('common.share'),
                                onTap: _selected.isEmpty
                                    ? () {}
                                    : () => shareEntriesFrom(
                                        context, _selected.toList()),
                              ),
                              _GalleryAction(
                                icon: AppIcons.delete,
                                label: context.t('common.delete'),
                                onTap: _deleteSelected,
                              ),
                            ],
                          ))
                        else
                        // Ortak düzen (2026-11-15): en çok 5 düğme — Paylaş ·
                        // Düzenle · İyileştir · Metin ve PDF · Sil. Boyut ve
                        // Bilgi ⋮'da (Boyut düşür, Özellikler), Seç de ⋮'da.
                        // Sil bilerek altta da var: fotoğraf ayıklamak
                        // galerinin en sık işi.
                        ToastAvoider(child: Row(
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
                            _GalleryAction(
                              icon: AppIcons.autoFixNormal,
                              label: context.t('gal.enhance'),
                              onTap: _enhance,
                            ),
                            // Metni tanı, çevir, PDF'e dönüştür: görüntüleyicide.
                            _GalleryAction(
                              icon: AppIcons.ocr,
                              label: context.t('gal.tools'),
                              onTap: _openInViewer,
                            ),
                            _GalleryAction(
                              icon: AppIcons.delete,
                              label: context.t('common.delete'),
                              onTap: _delete,
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
