import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute, listEquals;
import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../core/theme.dart' show OverlayBar;
import '../services/doc_edges.dart';
import '../services/perspective.dart';

/// **Sayfayı kırpma** ekranı — dörtgeni ayarlar, kırpmayı ÇAĞIRANA bırakır.
///
/// Döndürdüğü şey bir DÖRTGEN (görsel pikseli; sol-üst, sağ-üst, sağ-alt,
/// sol-alt); iptalde ve çerçeve görselin TAMAMIYKEN `null` (kırpılacak bir
/// şey yok — görsel yeniden örneklenmez). Görseli açıp yeniden kodlamak (`ScanPageOps`)
/// çağıranın işi — böylece ekran tek bir şey yapar ve kırpılan dosyanın
/// biçimi (JPEG) tek yerde belirlenir.
///
/// ## 2026-10-18 — baştan tasarım
/// Kullanıcı: *"manuel kırpma daha kolay olmalı, şu an görülmüyor, basit
/// olmalı"*. Eski ekranın sorunları:
/// * Kırpmaya giden yol gömülüydü: sonuç ekranı → "Sayfaları düzenle" →
///   "Köşeleri ayarla". Artık tarama ekranında her sayfanın altında
///   doğrudan "Kırp" var.
/// * Yalnız dört köşe sürüklenebiliyordu; bir kenarı içeri almak iki köşeyi
///   ayrı ayrı ve aynı miktarda sürüklemek demekti. Artık her kenarın
///   ortasında bir tutamaç var: kenarı topluca taşır (çoğu kırpma budur).
/// * Ne yapılacağı belli değildi ("Uygula" + üstte simgeler). Artık altta
///   tek büyük "Kırp" düğmesi, iki yardımcı ("Tam sayfa", "Kenarları bul")
///   ve tek satırlık ipucu.
///
/// Açılışta HİÇBİR ŞEY KESİLMEZ (2026-10-17 dersi): çerçeve görselin tam
/// sınırında başlar. Kâğıt kenarı araması yalnız [autoDetect] ile (galeriden
/// gelen, hiç kırpılmamış FOTOĞRAF) ya da "Kenarları bul" dokunuşuyla
/// uygulanır — tarayıcının kırptığı sayfada bulucu çoğu zaman sayfanın
/// içindeki bir tabloyu "kâğıt" sanıyor.
class ScanEditScreen extends StatefulWidget {
  const ScanEditScreen({
    super.key,
    required this.imagePath,
    this.autoDetect = false,
  });

  final String imagePath;

  /// Açılışta kâğıt kenarını bulup çerçeveyi oraya oturt (ham fotoğraf).
  final bool autoDetect;

  static Future<List<Offset>?> open(BuildContext context, String imagePath,
      {bool autoDetect = false}) {
    return Navigator.of(context).push<List<Offset>>(
      MaterialPageRoute(
        builder: (_) =>
            ScanEditScreen(imagePath: imagePath, autoDetect: autoDetect),
      ),
    );
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
  String? _error;

  /// Köşeler **görsel piksel** koordinatında. Ekran koordinatında
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

  Future<void> _load() async {
    try {
      final image = await decodeImageFile(widget.imagePath);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _corners = _full(image);
      });
      if (widget.autoDetect) await _findEdges(quiet: true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  List<Offset> _full(ui.Image img) =>
      ScanEditScreen.fullFrame(img.width, img.height);

  bool get _isFull {
    final img = _image;
    return img == null ||
        ScanEditScreen.isFullFrame(_corners, img.width, img.height);
  }

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
        _corners = [
          for (final c in found)
            Offset(
              c.x.clamp(0.0, img.width.toDouble()),
              c.y.clamp(0.0, img.height.toDouble()),
            ),
        ];
      }
    });
    if (found == null && !quiet) {
      showSnack(context, context.t('se.not_found'));
    }
  }

  /// Görselin ekrandaki (contain) yerleşimi.
  ({double scale, Offset origin}) _fit(Size viewport, ui.Image img) {
    final sx = viewport.width / img.width;
    final sy = viewport.height / img.height;
    final scale = sx < sy ? sx : sy;
    return (
      scale: scale,
      origin: Offset(
        (viewport.width - img.width * scale) / 2,
        (viewport.height - img.height * scale) / 2,
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
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        // Temanın başlık stili KOYU renk taşır; koyu çubukta okunmazdı
        // (bkz. `OverlayBar`). Temanın cetvel çizgisi de siyah zeminde beyaz
        // bir şerit gibi duruyordu.
        titleTextStyle: OverlayBar.title(context),
        shape: const Border(),
        leading: IconButton(
          tooltip: context.t('common.cancel'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(context.t('se.crop_title')),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.t('se.open_failed', {'error': _error}),
                    style: const TextStyle(color: Colors.white)),
              ),
            )
          : img == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(child: _editor(img)),
                    _controls(img),
                  ],
                ),
    );
  }

  /// Alt panel: ipucu · iki yardımcı · büyük "Kırp". Sistem gezinme
  /// çubuğunun üstünde (SafeArea) — düğme hiçbir zaman çubuğun altında
  /// kalmaz.
  Widget _controls(ui.Image img) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('se.crop_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    icon: Icons.fit_screen_outlined,
                    label: context.t('se.full_page'),
                    selected: _isFull,
                    onPressed: () => setState(() => _corners = _full(img)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillButton(
                    icon: Icons.auto_fix_high,
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
                  foregroundColor: Colors.white,
                  // Temanın stilinden türetilir: düz `TextStyle` yazı
                  // ailesini düşürüp düğmeyi Roboto'ya çeviriyordu.
                  textStyle: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.of(context)
                    .pop(_isFull ? null : List<Offset>.of(_corners)),
                icon: const Icon(Icons.check_rounded),
                label: Text(context.t('se.apply_crop')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editor(ui.Image img) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(
          (constraints.maxWidth - 2 * _editorPad).clamp(1.0, double.infinity),
          (constraints.maxHeight - 2 * _editorPad).clamp(1.0, double.infinity),
        );
        final inner = _fit(viewport, img);
        final scale = inner.scale;
        final origin = inner.origin + const Offset(_editorPad, _editorPad);
        Offset toScreen(Offset p) => origin + p * scale;
        final bounds = Size(img.width.toDouble(), img.height.toDouble());
        final screen = [for (final c in _corners) toScreen(c)];

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _QuadPainter(
                  image: img,
                  corners: _corners,
                  scale: scale,
                  origin: origin,
                  color: _accent,
                  showGrid: _drag != null,
                ),
              ),
            ),
            // Kenar tutamaçları önce (köşeler üstte kalsın: kısa kenarda
            // iki tutamaç üst üste binerse köşe kazanır).
            for (var e = 0; e < 4; e++)
              _edgeHandle(e, screen, scale, bounds),
            for (var i = 0; i < 4; i++) _cornerHandle(i, screen[i], scale, bounds),
            if (_drag != null) _magnifier(_dragPoint(screen)),
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

  /// Sürüklenirken parmağın üstünde duran büyüteç (1,8×). Parmağın 76 px
  /// üstünde durur, odak parmaktadır.
  Widget _magnifier(Offset at) {
    const size = Size(112, 112);
    const above = 76.0;
    return Positioned(
      left: at.dx - size.width / 2,
      top: at.dy - size.height / 2 - above,
      child: const IgnorePointer(
        child: RawMagnifier(
          size: size,
          focalPointOffset: Offset(0, above),
          magnificationScale: 1.8,
          decoration: MagnifierDecoration(
            shape: CircleBorder(
              side: BorderSide(color: Colors.white, width: 2.5),
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
      ),
    );
  }

  /// Köşe: 52 px dokunma alanı, ortasında 24 px halka.
  Widget _cornerHandle(int index, Offset at, double scale, Size bounds) {
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
              duration: const Duration(milliseconds: 120),
              width: active ? 28 : 24,
              height: active ? 28 : 24,
              decoration: BoxDecoration(
                color: active ? _accent : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: active ? Colors.white : _accent, width: 3),
                boxShadow: const [
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
  Widget _edgeHandle(int edge, List<Offset> screen, double scale, Size bounds) {
    const touch = 48.0;
    final a = screen[edge], b = screen[(edge + 1) % 4];
    final mid = (a + b) / 2;
    // Kenar çok kısaysa (köşeler üst üste) kenar tutamacı köşelerin
    // dokunma alanını yemesin.
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
                  color: active ? _accent : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: active ? Colors.white : _accent, width: 2),
                  boxShadow: const [
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
        foregroundColor: Colors.white,
        backgroundColor:
            selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        side: BorderSide(
            color: Colors.white.withValues(alpha: selected ? 0.7 : 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
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
  final List<Offset> corners;
  final double scale;
  final Offset origin;
  final Color color;
  final bool showGrid;

  _QuadPainter({
    required this.image,
    required this.corners,
    required this.scale,
    required this.origin,
    required this.color,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromLTWH(
        origin.dx, origin.dy, image.width * scale, image.height * scale);
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
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    // Sürüklerken üçte bir ızgarası: satırların düz durup durmadığı görülür.
    if (showGrid) {
      final grid = Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      Offset lerp(Offset a, Offset b, double t) => a + (b - a) * t;
      for (final t in const [1 / 3, 2 / 3]) {
        canvas.drawLine(lerp(pts[0], pts[1], t), lerp(pts[3], pts[2], t), grid);
        canvas.drawLine(lerp(pts[0], pts[3], t), lerp(pts[1], pts[2], t), grid);
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
      old.scale != scale ||
      old.origin != origin ||
      old.showGrid != showGrid ||
      !listEquals(old.corners, corners);
}
