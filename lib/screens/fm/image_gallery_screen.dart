import 'dart:async';
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
import '../../services/fm/image_rotate.dart';
import '../../services/fm/important_files.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../core/user_error.dart';
import '../../services/image_enhance.dart';
import '../../services/fm/enhance_jobs.dart';
import '../../services/fm/job_queue.dart';
import '../../services/image_repair.dart';
import '../../services/fm/native_extras.dart';
import '../../core/snack.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_file_image.dart';
import '../image_edit_screen.dart';
import '../viewer_screen.dart';
import 'entry_actions.dart';
import 'resize_actions.dart';
import 'resize_compare_screen.dart';

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
      pageBuilder: (_, _, _) =>
          ImageGalleryScreen(paths: paths, initialIndex: initialIndex),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
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
    _enhanceSub = EnhanceJobs.results.listen(_onEnhanced);
  }

  StreamSubscription<EnhanceResult>? _enhanceSub;

  @override
  void dispose() {
    _enhanceSub?.cancel();
    _slideTimer?.cancel();
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

  /// Bu görselin biten son iyileştirmesinin kopyası (hâlâ diskteyse).
  String? _enhancedOf(String path) {
    for (final j in JobQueue.instance.jobs) { // en yeni önce
      if (j.target?.kind != FmJobTargetKind.enhance) continue;
      for (final out in j.outputs) {
        if (j.outputSources[out] == path && File(out).existsSync()) return out;
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

  Future<void> _otherActions() async {
    await showEntryActions(context, _currentEntry);
    // Yeniden adlandırma/taşıma dosyayı değiştirmiş olabilir: ölçüm önbelleği
    // bayat kalmasın.
    _statCache.remove(_current);
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
                      itemBuilder: (context, i) => RotatedBox(
                       quarterTurns: _turnsOf(_paths[i]),
                       child: _ZoomableImage(
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
            ),
            // ── İyileştirme hapı: sürüyorsa ilerleme, bittiyse "Önce / sonra"
            Positioned(
              top: padding.top + 64,
              left: 0,
              right: 0,
              child: chrome(child: Center(child: _enhanceChip())),
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
                        PopupMenuButton<String>(
                          icon: const Icon(AppIcons.more, color: AppColors.onMedia),
                          onSelected: (v) async {
                            switch (v) {
                              case 'viewer':
                                _openInViewer();
                              case 'actions':
                                await _otherActions();
                              case 'slideshow':
                                await _pickSlideshow();
                              case 'important':
                                if (mounted) {
                                  await copyToImportant(context, [_current]);
                                }
                              case 'attach':
                                await _attachAs();
                              case 'save_rotation':
                                await _saveRotation();
                            }
                          },
                          itemBuilder: (_) => [
                            if (_turnsOf(_current) != 0 &&
                                ImageRotate.canRotate(_current))
                              PopupMenuItem(
                                  value: 'save_rotation',
                                  child: Text(context.t('gal.save_rotation'))),
                            PopupMenuItem(
                                value: 'viewer',
                                child: Text(context.t('gal.open_in_viewer'))),
                            if (_paths.length > 1)
                              PopupMenuItem(
                                  value: 'slideshow',
                                  child: Text(context.t('gal.slideshow'))),
                            PopupMenuItem(
                                value: 'important',
                                child: Text(context.t('fm.copy_to_important'))),
                            if (Platform.isAndroid)
                              PopupMenuItem(
                                  value: 'attach',
                                  child: Text(context.t('gal.use_as'))),
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
                        if (_selecting)
                          Row(
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
                          )
                        else
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
                            _GalleryAction(
                              icon: AppIcons.autoFixNormal,
                              label: context.t('gal.enhance'),
                              onTap: _enhance,
                            ),
                            // Faz 14 (G4i): boyutlandırma eskiden yalnız ⋮ →
                            // eylem sayfasındaydı; "fotoğrafı küçült" galerinin
                            // en sık işlerinden biri.
                            _GalleryAction(
                              icon: AppIcons.resize,
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
                              icon: AppIcons.checkCircleOutline,
                              label: context.t('ied.select'),
                              onTap: _startSelect,
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
      ),
    );
  }
}
