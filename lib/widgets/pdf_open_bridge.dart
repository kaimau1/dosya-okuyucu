import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../services/fm/pdf_thumbnail.dart';
import 'fm/fm_file_image.dart';
import 'pdf_page_frame.dart';

/// Kapak bulunamazsa kullanılan sayfa oranı (A4 dikey).
const double kPdfBridgeDefaultAspect = 210 / 297;

/// **PDF açılış köprüsü** (Ferrari H1.1, 2026-11-14).
///
/// Kullanıcı videosu (USB'de 200–700 MB kitaplar): belge yüklenene kadar
/// ekran düz gri/boş kalıyor, "açılmıyor mu?" hissi veriyordu. Artık o arada
/// sayfa oranında bir kâğıt durur; listede zaten üretilmiş kapak varsa
/// üstünde o görünür ([PdfThumbnail.cachedCover] — ÜRETMEZ, pdfium'u
/// görüntüleyiciyle yarıştırmaz). Belge hazır olunca ([visible] false)
/// [Motion.short] ile solar ve ağaçtan çıkar.
///
/// Görüntüleyicinin ÜSTÜNE binen bir katmandır (`Stack`); görünüm boyunu
/// değiştirmez — pdfrx boy değişince sayfa başına atlıyor (HAFIZA
/// 2026-10-23). Dokunuşu hiç almaz.
class PdfOpenBridge extends StatefulWidget {
  const PdfOpenBridge({
    super.key,
    required this.path,
    required this.visible,
    this.useCover = true,
    this.topInset = 0,
    this.background,
    this.coverLoader,
  });

  /// Açılan PDF'in yolu.
  final String path;

  /// false olunca köprü solar.
  final bool visible;

  /// Kapak (1. sayfa) gösterilsin mi? Ortadan devam edilen belgede kapak
  /// yanlış sayfa olur → yalnız nötr kâğıt.
  final bool useCover;

  /// Üst çubuğun kapladığı pay (telefonda kâğıt onun altından başlar).
  final double topInset;

  /// Zemin rengi (görüntüleyiciyle aynı olmalı); null → tema yüzeyi.
  final Color? background;

  /// Testte disk yerine sahte kapak.
  final Future<({String path, double aspect})?> Function(String path)?
      coverLoader;

  @override
  State<PdfOpenBridge> createState() => _PdfOpenBridgeState();
}

class _PdfOpenBridgeState extends State<PdfOpenBridge> {
  ({String path, double aspect})? _cover;
  late bool _gone = !widget.visible;

  @override
  void initState() {
    super.initState();
    if (widget.useCover && widget.visible) unawaited(_loadCover());
  }

  Future<void> _loadCover() async {
    final loader = widget.coverLoader ?? PdfThumbnail.cachedCover;
    final cover = await loader(widget.path);
    if (!mounted || cover == null || !widget.visible) return;
    setState(() => _cover = cover);
  }

  @override
  void didUpdateWidget(PdfOpenBridge old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _gone = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    final bg = widget.background ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    return IgnorePointer(
      child: AnimatedOpacity(
        key: const ValueKey('pdf-open-bridge'),
        opacity: widget.visible ? 1 : 0,
        duration: Motion.of(context, Motion.short),
        curve: Motion.exit,
        onEnd: () {
          if (!widget.visible && mounted) setState(() => _gone = true);
        },
        child: ColoredBox(
          color: bg,
          child: LayoutBuilder(builder: _paper),
        ),
      ),
    );
  }

  Widget _paper(BuildContext context, BoxConstraints c) {
    final cover = _cover;
    final aspect = cover?.aspect ?? kPdfBridgeDefaultAspect;
    // Telefonda pdfrx sayfayı genişliğe oturtup üstten başlatır; tablette
    // (kısa kenar ≥ 600) sayfanın tamamı ortada ([PdfZoomMemory]).
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final maxW = c.maxWidth - 2 * Gap.sm;
    final maxH = c.maxHeight - widget.topInset - 2 * Gap.sm;
    if (maxW <= 0 || maxH <= 0) return const SizedBox.shrink();
    var w = maxW;
    var h = w / aspect;
    if (tablet && h > maxH) {
      h = maxH;
      w = h * aspect;
    }
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    final shadow = PdfPageFrame.of(context).shadowOrDefault;
    return Align(
      alignment: tablet ? Alignment.center : Alignment.topCenter,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
            top: tablet ? widget.topInset : widget.topInset + Gap.sm),
        child: SizedBox(
          key: const ValueKey('pdf-bridge-paper'),
          width: w,
          height: h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.page,
              boxShadow: [?shadow],
            ),
            child: cover == null
                ? null
                : Image(
                    image: FmFileImage(cover.path,
                        cacheWidth: (w * dpr).round().clamp(64, 1024)),
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, sync) {
                      if (sync) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: Motion.of(context, Motion.short),
                        curve: Motion.enter,
                        child: child,
                      );
                    },
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
          ),
        ),
      ),
    );
  }
}
