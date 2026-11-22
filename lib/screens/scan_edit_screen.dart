import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute, listEquals;
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/motion.dart';
import '../core/snack.dart';
import '../core/theme.dart' show AppTypeContext, OverlayBar;
import '../services/doc_edges.dart';
import '../core/user_error.dart';

/// Kırpma ekranının tip güvenli dönüş sonucu.
enum ScanCropStatus { cancelled, fullFrame, cropped }

class ScanCropResult {
  final ScanCropStatus status;
  final List<Offset>? corners;

  const ScanCropResult._(this.status, [this.corners]);

  /// Kullanıcı X (Vazgeç) veya sistem geri tuşuyla çıktı.
  static const ScanCropResult cancelled =
      ScanCropResult._(ScanCropStatus.cancelled);

  /// Kullanıcı tam çerçeveyi koruyarak "Kırp"a bastı (yeniden örnekleme yok).
  static const ScanCropResult fullFrame =
      ScanCropResult._(ScanCropStatus.fullFrame);

  /// Kullanıcı dörtgeni kırparak "Kırp"a bastı.
  const ScanCropResult.cropped(List<Offset> corners)
      : this._(ScanCropStatus.cropped, corners);

  bool get isCancelled => status == ScanCropStatus.cancelled;
  bool get isFullFrame => status == ScanCropStatus.fullFrame;
  bool get isCropped => status == ScanCropStatus.cropped && corners != null;
}

/// **Sayfayı kırpma** ekranı — dörtgeni ayarlar, kırpmayı ÇAĞIRANA bırakır.
///
/// Döndürdüğü şey [ScanCropResult] (`cancelled`, `fullFrame`,
/// `cropped(List<Offset>)`); böylece galeriden tek fotoğraf eklerken
/// **X (Vazgeç)** tuşuna basmakla **Tam sayfa** seçip onaylamak birbirinden
/// ayrılır.
class ScanEditScreen extends StatefulWidget {
  const ScanEditScreen({
    super.key,
    required this.imagePath,
    this.autoDetect = false,
  });

  final String imagePath;

  /// Açılışta kâğıt kenarını bulup çerçeveyi oraya oturt (ham fotoğraf).
  final bool autoDetect;

  /// Ön izleme dokusunun uzun kenar tavanı (piksel). 50 MP (8000×6000)
  /// fotoğraflarda tam çözünürlüklü GPU dokusu ~192 MB harcıyordu; 1600 px
  /// ekranda ve büyüteçte tam keskinlik verirken GPU belleğini ~8 MB'da tutar.
  /// Köşe koordinatları her zaman özgün görselin piksel uzayında tutulur.
  static const int maxPreviewEdge = 1600;

  static Future<ScanCropResult> open(BuildContext context, String imagePath,
      {bool autoDetect = false}) async {
    final result = await Navigator.of(context).push<ScanCropResult>(
      MaterialPageRoute(
        builder: (_) =>
            ScanEditScreen(imagePath: imagePath, autoDetect: autoDetect),
      ),
    );
    return result ?? ScanCropResult.cancelled;
  }

  /// Başlangıç dörtgeni: görselin TAMAMI — tam sınırda. "Kırp"a dokunmadan
  /// basan kullanıcının sayfasından tek piksel bile gitmez.
  static List<Offset> fullFrame(int width, int height) {
    final w = width.toDouble();
    final h = height.toDouble();
    return [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)];
  }

  /// [quad] görselin tamamı mı (yarım pikselden az fark)?
  static bool isFullFrame(List<Offset> quad, int width, int height) =>
      sameQuad(quad, fullFrame(width, height));

  static bool sameQuad(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).distance > 0.5) return false;
    }
    return true;
  }

  /// Dörtgen dışbükey (convex), saat yönünde (sol-üst → sağ-üst → sağ-alt →
  /// sol-alt) ve anlamlı bir alana sahip mi?
  static bool isValidQuad(List<Offset> quad, Size bounds,
      {double minAreaRatio = 0.01}) {
    if (quad.length != 4) return false;
    const minEdge = 16.0;
    for (var i = 0; i < 4; i++) {
      final a = quad[i];
      final b = quad[(i + 1) % 4];
      final c = quad[(i + 2) % 4];
      final ab = b - a;
      final bc = c - b;
      if (ab.distance < minEdge) return false;
      // Ekran koordinatında (y aşağı) saat yönü dörtgende ardışık kenarların
      // çapraz çarpımı pozitif olmalı; sıfır/negatif = içbükey veya kelebek.
      final cross = ab.dx * bc.dy - ab.dy * bc.dx;
      if (cross <= 1e-2) return false;
    }
    final minArea =
        math.max(256.0, bounds.width * bounds.height * minAreaRatio);
    return quadArea(quad) >= minArea;
  }

  /// Ayakkabı bağı formülüyle dörtgen alanı.
  static double quadArea(List<Offset> quad) {
    var sum = 0.0;
    for (var i = 0; i < quad.length; i++) {
      final a = quad[i];
      final b = quad[(i + 1) % quad.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2;
  }

  /// Kenar tutamacı sürüklemesi: [edge] (0 üst, 1 sağ, 2 alt, 3 sol)
  /// kenarının iki ucu kenarın NORMALİ boyunca [delta]'nın izdüşümü kadar
  /// taşınır; sonuç görsel sınırına kıstırılır. Saf → birim testli.
  static List<Offset> dragEdge(
      List<Offset> quad, int edge, Offset delta, Size bounds) {
    final a = edge, b = (edge + 1) % 4;
    final dir = quad[b] - quad[a];
    final length = dir.distance;
    if (length < 1e-6) return quad;
    final normal = Offset(-dir.dy / length, dir.dx / length);
    final along = delta.dx * normal.dx + delta.dy * normal.dy;
    final move = normal * along;
    Offset clampTo(Offset p) => Offset(
          p.dx.clamp(0.0, bounds.width),
          p.dy.clamp(0.0, bounds.height),
        );
    return [
      for (var i = 0; i < 4; i++)
        (i == a || i == b) ? clampTo(quad[i] + move) : quad[i],
    ];
  }

  @override
  State<ScanEditScreen> createState() => _ScanEditScreenState();
}

class _ScanEditScreenState extends State<ScanEditScreen> {
  ui.Image? _image;

  /// Özgün görselin tam piksel boyutu (ön izleme dokusu küçültülmüş olsa bile
  /// köşeler bu koordinat uzayında tutulur).
  int _sourceWidth = 0;
  int _sourceHeight = 0;
  String? _error;

  /// Köşeler **özgün görsel piksel** koordinatında. Ekran koordinatında
  /// tutulmuyor: ekran dönerse/ölçek değişirse ayar kaymasın.
  late List<Offset> _corners;
  bool _detecting = false;

  /// Sürüklenen tutamaç: 0-3 köşe, 4-7 kenar ortası (yoksa null). Büyüteç
  /// bunu izler — parmak köşeyi kapattığı için büyüteçsiz hassas ayar
  /// yapılamıyor (2026-08-06 bulgusu).
  int? _drag;

  /// Tutamaçların ekran dışına taşmaması için editörün iç payı.
  static const _editorPad = 28.0;

  static const _accent = Color(0xFF4F8CF7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Ön izleme görselini `ImmutableBuffer.fromFilePath` + `targetWidth` ile
  /// çözer (50 MP fotoğraflarda 192 MB GPU doku sıçramasını keser).
  Future<void> _load() async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(widget.imagePath);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final srcW = descriptor.width;
      final srcH = descriptor.height;
      final longEdge = math.max(srcW, srcH);
      final ratio = longEdge > ScanEditScreen.maxPreviewEdge
          ? ScanEditScreen.maxPreviewEdge / longEdge
          : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (srcW * ratio).round()),
        targetHeight: math.max(1, (srcH * ratio).round()),
      );
      final image = (await codec.getNextFrame()).image;
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _sourceWidth = srcW;
        _sourceHeight = srcH;
        _corners = ScanEditScreen.fullFrame(srcW, srcH);
      });
      if (widget.autoDetect) await _findEdges(quiet: true);
    } catch (e) {
      if (mounted) setState(() => _error = userErrorText(e));
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  List<Offset> _full() => ScanEditScreen.fullFrame(_sourceWidth, _sourceHeight);

  bool get _isFull =>
      _image == null ||
      ScanEditScreen.isFullFrame(_corners, _sourceWidth, _sourceHeight);

  bool get _isValid =>
      _image != null &&
      ScanEditScreen.isValidQuad(
        _corners,
        Size(_sourceWidth.toDouble(), _sourceHeight.toDouble()),
      );

  /// Kâğıdın kenarlarını bulup çerçeveyi oraya oturtur. Bulamazsa çerçeve
  /// OLDUĞU GİBİ kalır (elle yapılan ayarı bir tahminle ezmek, tahmin
  /// yanlışsa geri alınamaz bir kayıp olurdu). Çözümleme izolatta.
  Future<void> _findEdges({bool quiet = false}) async {
    final img = _image;
    if (img == null || _detecting) return;
    setState(() => _detecting = true);
    List<({double x, double y})>? found;
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      found = await compute(_detectCorners, bytes);
    } catch (_) {
      found = null;
    }
    if (!mounted) return;
    setState(() {
      _detecting = false;
      if (found != null) {
        final candidate = [
          for (final c in found)
            Offset(
              c.x.clamp(0.0, _sourceWidth.toDouble()),
              c.y.clamp(0.0, _sourceHeight.toDouble()),
            ),
        ];
        if (ScanEditScreen.isValidQuad(
            candidate, Size(_sourceWidth.toDouble(), _sourceHeight.toDouble()))) {
          _corners = candidate;
        }
      }
    });
    if (found == null && !quiet) {
      showSnack(context, context.t('se.not_found'));
    }
  }

  /// Görselin ekrandaki (contain) yerleşimi (özgün piksel koordinatına göre).
  ({double scale, Offset origin}) _fit(Size viewport) {
    final sx = viewport.width / _sourceWidth;
    final sy = viewport.height / _sourceHeight;
    final scale = sx < sy ? sx : sy;
    return (
      scale: scale,
      origin: Offset(
        (viewport.width - _sourceWidth * scale) / 2,
        (viewport.height - _sourceHeight * scale) / 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0F12),
        foregroundColor: AppColors.onMedia,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: OverlayBar.title(context),
        shape: const Border(),
        leading: IconButton(
          tooltip: context.t('common.cancel'),
          icon: const Icon(AppIcons.close),
          onPressed: () =>
              Navigator.of(context).pop(ScanCropResult.cancelled),
        ),
        title: Text(context.t('se.crop_title')),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.t('se.open_failed', {'error': _error}),
                    style: const TextStyle(color: AppColors.onMedia)),
              ),
            )
          : img == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(child: _editor(img)),
                    _controls(),
                  ],
                ),
    );
  }

  /// Alt panel: ipucu · iki yardımcı · büyük "Kırp". Sistem gezinme
  /// çubuğunun üstünde (SafeArea) — düğme hiçbir zaman çubuğun altında
  /// kalmaz.
  Widget _controls() {
    final valid = _isValid;
    final errorColor = Theme.of(context).colorScheme.error;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              valid ? context.t('se.crop_hint') : context.t('se.invalid_quad'),
              textAlign: TextAlign.center,
              style: context.type.compact.copyWith(
                color: valid ? AppColors.onMediaSoft : errorColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    icon: AppIcons.fitScreen,
                    label: context.t('se.full_page'),
                    selected: _isFull,
                    onPressed: () => setState(() => _corners = _full()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillButton(
                    icon: AppIcons.organize,
                    label: context.t('se.find_edges'),
                    busy: _detecting,
                    onPressed: _detecting ? null : _findEdges,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: AppColors.onMedia,
                  disabledBackgroundColor:
                      AppColors.onMedia.withValues(alpha: 0.12),
                  disabledForegroundColor:
                      AppColors.onMedia.withValues(alpha: 0.38),
                  textStyle: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: !valid
                    ? null
                    : () => Navigator.of(context).pop(
                          _isFull
                              ? ScanCropResult.fullFrame
                              : ScanCropResult.cropped(
                                  List<Offset>.of(_corners)),
                        ),
                icon: const Icon(AppIcons.check),
                label: Text(context.t('se.apply_crop')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editor(ui.Image img) {
    final valid = _isValid;
    final frameColor = valid ? _accent : Theme.of(context).colorScheme.error;
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        final viewport = Size(
          (constraints.maxWidth - 2 * _editorPad).clamp(1.0, double.infinity),
          (constraints.maxHeight - 2 * _editorPad).clamp(1.0, double.infinity),
        );
        final inner = _fit(viewport);
        final scale = inner.scale;
        final origin = inner.origin + const Offset(_editorPad, _editorPad);
        Offset toScreen(Offset p) => origin + p * scale;
        final bounds =
            Size(_sourceWidth.toDouble(), _sourceHeight.toDouble());
        final screen = [for (final c in _corners) toScreen(c)];

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _QuadPainter(
                  image: img,
                  sourceSize: bounds,
                  corners: _corners,
                  scale: scale,
                  origin: origin,
                  color: frameColor,
                  showGrid: _drag != null,
                ),
              ),
            ),
            // Kenar tutamaçları önce (köşeler üstte kalsın: kısa kenarda
            // iki tutamaç üst üste binerse köşe kazanır).
            for (var e = 0; e < 4; e++)
              _edgeHandle(e, screen, scale, bounds, frameColor),
            for (var i = 0; i < 4; i++)
              _cornerHandle(i, screen[i], scale, bounds, frameColor),
            if (_drag != null) _magnifier(_dragPoint(screen), area, frameColor),
          ],
        );
      },
    );
  }

  Offset _dragPoint(List<Offset> screen) {
    final d = _drag!;
    if (d < 4) return screen[d];
    final e = d - 4;
    return (screen[e] + screen[(e + 1) % 4]) / 2;
  }

  /// Sürüklenirken parmağın yakınında duran büyüteç (1,8×).
  ///
  /// Üst köşelerde ekran dışına taşmaması için dinamik olarak aşağıya/yana
  /// kaydırılır ve `focalPointOffset` her zaman gerçek sürükleme noktasını
  /// (`at`) merkezde tutacak biçimde hesaplanır. İçinde artı nişangâh vardır.
  Widget _magnifier(Offset at, Size area, Color accentColor) {
    const size = Size(112, 112);
    const halfW = 56.0;
    const halfH = 56.0;
    const offsetDist = 76.0;
    const margin = 8.0;

    // Varsayılan konum parmağın üstü; üstte yer yoksa parmağın altına geçer.
    var cy = at.dy - offsetDist;
    if (cy - halfH < margin) {
      cy = at.dy + offsetDist;
    }
    var cx = at.dx;
    final minX = math.min(halfW + margin, area.width / 2);
    final maxX = math.max(minX, area.width - halfW - margin);
    final minY = math.min(halfH + margin, area.height / 2);
    final maxY = math.max(minY, area.height - halfH - margin);
    cx = cx.clamp(minX, maxX);
    cy = cy.clamp(minY, maxY);

    // Eğer parmakla büyüteç üst üste biniyorsa yan tarafa kaydır.
    if ((Offset(cx, cy) - at).distance < halfW + 10) {
      final tryRight = at.dx + offsetDist;
      final tryLeft = at.dx - offsetDist;
      if (tryRight + halfW + margin <= area.width) {
        cx = tryRight;
      } else if (tryLeft - halfW >= margin) {
        cx = tryLeft;
      }
    }

    final focalPointOffset = Offset(at.dx - cx, at.dy - cy);

    return Positioned(
      left: cx - halfW,
      top: cy - halfH,
      child: IgnorePointer(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RawMagnifier(
                size: size,
                focalPointOffset: focalPointOffset,
                magnificationScale: 1.8,
                decoration: const MagnifierDecoration(
                  shape: CircleBorder(
                    side: BorderSide(color: AppColors.onMedia, width: 2.5),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Color(0x88000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                      blurStyle: BlurStyle.outer,
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: size,
                painter: _CrosshairPainter(color: accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Köşe: 52 px dokunma alanı; sürüklenirken içi boş ince nişangâh halkasına
  /// dönüşür ki kâğıdın köşesi büyüteçte ve ekranda kapanmasın.
  Widget _cornerHandle(
      int index, Offset at, double scale, Size bounds, Color frameColor) {
    const touch = 52.0;
    final active = _drag == index;
    return Positioned(
      left: at.dx - touch / 2,
      top: at.dy - touch / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _drag = index),
        onPanUpdate: (d) {
          final next = _corners[index] + d.delta / scale;
          setState(() {
            _corners[index] = Offset(
              next.dx.clamp(0.0, bounds.width),
              next.dy.clamp(0.0, bounds.height),
            );
          });
        },
        onPanEnd: (_) => setState(() => _drag = null),
        onPanCancel: () => setState(() => _drag = null),
        child: SizedBox(
          width: touch,
          height: touch,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.short),
              width: active ? 28 : 24,
              height: active ? 28 : 24,
              decoration: BoxDecoration(
                color: active ? Colors.transparent : AppColors.onMedia,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? AppColors.onMedia : frameColor,
                  width: active ? 1.6 : 3,
                ),
                boxShadow: active
                    ? null
                    : const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 6),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Kenar ortası: kenarı topluca içeri/dışarı taşıyan hap tutamaç.
  Widget _edgeHandle(int edge, List<Offset> screen, double scale, Size bounds,
      Color frameColor) {
    const touch = 48.0;
    final a = screen[edge], b = screen[(edge + 1) % 4];
    final mid = (a + b) / 2;
    if ((a - b).distance < 96) return const SizedBox.shrink();
    final angle = (b - a).direction;
    final active = _drag == 4 + edge;
    return Positioned(
      left: mid.dx - touch / 2,
      top: mid.dy - touch / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _drag = 4 + edge),
        onPanUpdate: (d) => setState(() {
          _corners =
              ScanEditScreen.dragEdge(_corners, edge, d.delta / scale, bounds);
        }),
        onPanEnd: (_) => setState(() => _drag = null),
        onPanCancel: () => setState(() => _drag = null),
        child: SizedBox(
          width: touch,
          height: touch,
          child: Center(
            child: Transform.rotate(
              angle: angle,
              child: Container(
                width: 30,
                height: 10,
                decoration: BoxDecoration(
                  color: active ? Colors.transparent : AppColors.onMedia,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: active ? AppColors.onMedia : frameColor,
                      width: active ? 1.5 : 2),
                  boxShadow: active
                      ? null
                      : const [
                          BoxShadow(color: Color(0x66000000), blurRadius: 5),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Büyüteç içi artı (`+`) nişangâh çizicisi.
class _CrosshairPainter extends CustomPainter {
  final Color color;
  const _CrosshairPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const arm = 12.0;
    const gap = 3.5;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(center.dx - arm, center.dy), Offset(center.dx - gap, center.dy), paint);
    canvas.drawLine(
        Offset(center.dx + gap, center.dy), Offset(center.dx + arm, center.dy), paint);
    canvas.drawLine(
        Offset(center.dx, center.dy - arm), Offset(center.dx, center.dy - gap), paint);
    canvas.drawLine(
        Offset(center.dx, center.dy + gap), Offset(center.dx, center.dy + arm), paint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => old.color != color;
}

/// Koyu zeminde yuvarlak hatlı yardımcı düğme ("Tam sayfa", "Kenarları bul").
class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool busy;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: AppColors.onMedia,
        backgroundColor: selected
            ? AppColors.onMedia.withValues(alpha: 0.14)
            : Colors.transparent,
        side: BorderSide(
            color: AppColors.onMedia.withValues(alpha: selected ? 0.7 : 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.onMedia),
            )
          : Icon(icon, size: 20),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// İzolat giriş noktası — üst düzey fonksiyon olmalı (`compute` kuralı).
List<({double x, double y})>? _detectCorners(Uint8List bytes) =>
    DocEdges.detect(bytes);

class _QuadPainter extends CustomPainter {
  final ui.Image image;
  final Size sourceSize;
  final List<Offset> corners;
  final double scale;
  final Offset origin;
  final Color color;
  final bool showGrid;

  _QuadPainter({
    required this.image,
    required this.sourceSize,
    required this.corners,
    required this.scale,
    required this.origin,
    required this.color,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromLTWH(origin.dx, origin.dy, sourceSize.width * scale,
        sourceSize.height * scale);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );

    final pts = [for (final c in corners) origin + c * scale];
    final path = Path()..addPolygon(pts, true);

    // Dörtgen DIŞI karartılır: neyin kalacağı bir bakışta görünür.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        path,
      ),
      Paint()..color = AppColors.mediaSurface.withValues(alpha: 0.6),
    );

    // Sürüklerken üçte bir ızgarası: satırların düz durup durmadığı görülür.
    if (showGrid) {
      final grid = Paint()
        ..color = AppColors.onMedia.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      Offset lerp(Offset a, Offset b, double t) => a + (b - a) * t;
      for (final t in const [1 / 3, 2 / 3]) {
        canvas.drawLine(
            lerp(pts[0], pts[1], t), lerp(pts[3], pts[2], t), grid);
        canvas.drawLine(
            lerp(pts[0], pts[3], t), lerp(pts[1], pts[2], t), grid);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_QuadPainter old) =>
      old.image != image ||
      old.sourceSize != sourceSize ||
      old.scale != scale ||
      old.origin != origin ||
      old.color != color ||
      old.showGrid != showGrid ||
      !listEquals(old.corners, corners);
}
