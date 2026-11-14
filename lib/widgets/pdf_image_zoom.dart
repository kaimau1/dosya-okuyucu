import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/busy_dialog.dart' show popOwnPage;
import '../core/l10n/app_strings.dart';
import '../core/motion.dart';
import '../core/theme.dart';

/// Görsel kipinin rotası: belge saydam bir perdeyle solar, görsel siyah
/// zeminde açılır (galeriyle aynı dil).
Route<void> pdfImageZoomRoute(Future<ui.Image?> Function() load) =>
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Motion.long,
      reverseTransitionDuration: Motion.medium,
      pageBuilder: (_, _, _) => PdfImageZoomScreen(load: load),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Motion.enter),
        child: child,
      ),
    );

/// Sayfanın [region] bölgesini (PDF uzayı) ekrana yetecek çözünürlükte
/// çizer: uzun kenar ekranın ~2 katı, görselin kendi pikselinden ([nativePx])
/// fazlası yok, en çok 3072 px (≈ 36 MB üst sınır). Döndürülmüş sayfada da
/// doğru bölge ([PdfRect.toRect] döndürmeyi uygular).
Future<ui.Image?> renderPdfRegion(PdfPage page, PdfRect region,
    {required double screenLongPx, int nativePx = 0}) async {
  final longPt = math.max(region.width, region.height);
  if (longPt <= 0 || page.width <= 0 || page.height <= 0) return null;
  final want = nativePx > 0
      ? math.max(screenLongPx, math.min(nativePx.toDouble(), screenLongPx * 2))
      : screenLongPx * 2;
  final scale = math.min(3072.0, math.max(512.0, want)) / longPt;
  final fullW = page.width * scale, fullH = page.height * scale;
  final r = region.toRect(page: page, scaledPageSize: Size(fullW, fullH));
  final x = math.max(0, math.min(r.left.floor(), fullW.floor()));
  final y = math.max(0, math.min(r.top.floor(), fullH.floor()));
  final w = math.min(r.width.ceil(), fullW.floor() - x);
  final h = math.min(r.height.ceil(), fullH.floor() - y);
  if (w <= 0 || h <= 0) return null;
  return page.renderForDisplay(
    x: x,
    y: y,
    width: w,
    height: h,
    fullWidth: fullW,
    fullHeight: fullH,
    // Saydam görsel siyah zeminde kaybolmasın: kâğıt beyazı.
    backgroundColor: AppColors.page.toARGB32(),
  );
}

/// **Görsel kipi** (Ferrari H3.3, radyoloji atlası kullanımı): PDF
/// sayfasındaki tek görsel siyah zeminde, tam ekran; iki parmakla ya da
/// çift dokunuşla yakınlaşır, aşağı çekince kapanır.
///
/// Görsel [load] ile gelir (sayfanın o bölgesi yüksek çözünürlükte çizilir —
/// kırpma, döndürme ve maske belgedeki gibi). Görüntü bu ekranındır: kapanınca
/// bırakılır.
class PdfImageZoomScreen extends StatefulWidget {
  final Future<ui.Image?> Function() load;

  const PdfImageZoomScreen({super.key, required this.load});

  @override
  State<PdfImageZoomScreen> createState() => _PdfImageZoomScreenState();
}

class _PdfImageZoomScreenState extends State<PdfImageZoomScreen>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  bool _failed = false;
  final _tx = TransformationController();
  bool _zoomed = false;
  TapDownDetails? _doubleTapAt;

  /// Aşağı çekme: görselin dikey kayması; bırakınca ya kapanır ya da yayla
  /// yerine döner.
  double _dragDy = 0;
  double _snapFrom = 0;
  late final AnimationController _snap;

  @override
  void initState() {
    super.initState();
    _snap = AnimationController(vsync: this, duration: Motion.medium)
      ..addListener(() {
        final t = Motion.enter.transform(_snap.value);
        setState(() => _dragDy = _snapFrom * (1 - t));
      });
    _tx.addListener(_onTransform);
    unawaited(_load());
  }

  Future<void> _load() async {
    ui.Image? image;
    try {
      image = await widget.load();
    } catch (_) {
      // Bilinçli: çizilemedi (bellek, belge kapandı) — ekranda "açılamadı".
      image = null;
    }
    if (!mounted) {
      image?.dispose();
      return;
    }
    setState(() {
      _image = image;
      _failed = image == null;
    });
  }

  @override
  void dispose() {
    _snap.dispose();
    _tx
      ..removeListener(_onTransform)
      ..dispose();
    _image?.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _tx.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _onDoubleTap() {
    if (_zoomed) {
      _tx.value = Matrix4.identity();
      return;
    }
    final at = _doubleTapAt?.localPosition;
    if (at == null) return;
    // Dokunulan nokta yerinde kalarak 2,5×.
    _tx.value = Matrix4.identity()
      ..translateByDouble(-at.dx * 1.5, -at.dy * 1.5, 0, 1)
      ..scaleByDouble(2.5, 2.5, 1, 1);
  }

  void _onDragStart(DragStartDetails _) => _snap.stop();

  void _onDragUpdate(DragUpdateDetails d) {
    final dy = d.primaryDelta ?? d.delta.dy;
    // Yukarı çekiş dirençli: kapatma yalnız aşağı.
    setState(() => _dragDy += _dragDy + dy < 0 ? dy * 0.3 : dy);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_dragDy > 110 || (v > 900 && _dragDy > 0)) {
      popOwnPage(context);
      return;
    }
    _snapFrom = _dragDy;
    _snap.duration = Motion.of(context, Motion.medium);
    _snap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final progress =
        height <= 0 ? 0.0 : (_dragDy.abs() / (height * 0.55)).clamp(0.0, 1.0);
    final image = _image;
    final Widget body;
    if (image != null) {
      body = InteractiveViewer(
        transformationController: _tx,
        minScale: 1,
        maxScale: 8,
        child: SizedBox.expand(
          child: RawImage(
              key: const ValueKey('pdf-image-zoom-image'),
              image: image,
              fit: BoxFit.contain),
        ),
      );
    } else if (_failed) {
      body = Center(
        child: Text(
          context.t('pp.image_zoom_failed'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.onMedia),
        ),
      );
    } else {
      body = const Center(
          child: CircularProgressIndicator(color: AppColors.onMedia));
    }
    return Scaffold(
      backgroundColor: AppColors.none,
      body: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.mediaSurface.withValues(alpha: 1 - progress),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              // Yakınken dikey sürükleme görseli gezdirir; kapatma yalnız tam
              // görünümde.
              onVerticalDragStart: _zoomed ? null : _onDragStart,
              onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
              onVerticalDragEnd: _zoomed ? null : _onDragEnd,
              onDoubleTapDown: (d) => _doubleTapAt = d,
              onDoubleTap: image == null ? null : _onDoubleTap,
              child: Transform.translate(
                offset: Offset(0, _dragDy),
                child: Transform.scale(scale: 1 - progress * 0.2, child: body),
              ),
            ),
          ),
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + Gap.xs,
            start: Gap.xs,
            child: Opacity(
              opacity: 1 - progress,
              child: IconButton(
                key: const ValueKey('pdf-image-zoom-close'),
                icon: const Icon(AppIcons.close),
                color: AppColors.onMedia,
                tooltip: context.t('common.close'),
                onPressed: () => popOwnPage(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
