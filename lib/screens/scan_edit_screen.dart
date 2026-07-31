import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../services/doc_edges.dart';
import '../services/perspective.dart';

/// Taranan bir sayfanın **köşelerini elle ayarlama** ekranı.
///
/// İstek (2026-07-26): "belge tarandıktan sonra çıkan ekranda sayfanın
/// köşelerini seçebilme seçeneği olsun, çıkan mavi dikdörtgenin köşelerinden
/// tutup ayarlayarak." ML Kit tarayıcısı kenarı çoğu zaman doğru buluyor ama
/// gölgeli/desenli masada kaçırıyor; o durumda sayfa yamuk kalıyordu.
///
/// Burada dörtgen kullanıcının dediği yere getirilir ve [Perspective] ile
/// **düz bir dikdörtgene açılır** (perspektif düzeltme) — yalnız kırpma değil:
/// eğik çekilmiş sayfa da düzelir.
///
/// Sonuç yeni bir PNG dosyasına yazılır ve yolu döndürülür (iptalde `null`).
class ScanEditScreen extends StatefulWidget {
  const ScanEditScreen({super.key, required this.imagePath});

  final String imagePath;

  static Future<String?> open(BuildContext context, String imagePath) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ScanEditScreen(imagePath: imagePath)),
    );
  }

  @override
  State<ScanEditScreen> createState() => _ScanEditScreenState();
}

class _ScanEditScreenState extends State<ScanEditScreen> {
  ui.Image? _image;
  String? _error;
  bool _busy = false;

  /// Köşeler **görsel piksel** koordinatında: sol-üst, sağ-üst, sağ-alt, sol-alt.
  /// Ekran koordinatında tutulmuyor: ekran döndüğünde/ölçek değiştiğinde
  /// kullanıcının ayarı kaymasın.
  late List<Offset> _corners;

  /// Kâğıdın kenarları otomatik bulunabildi mi? (İpucu metni buna göre
  /// değişiyor: bulunmadıysa kullanıcı köşeleri kendi taşımalı, bunu
  /// söylemeden bırakmak "program çalışmadı" hissi veriyordu.)
  bool _autoFound = false;
  bool _detecting = false;

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
        _corners = _fullFrame(image);
      });
      // Ekran açılır açılmaz kenarlar aranır: kullanıcı dört köşeyi tek tek
      // sürüklemek zorunda kalmasın (istek 2026-07-30).
      await _autoDetect();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Kâğıdın kenarlarını otomatik bulur; bulamazsa dörtgeni OLDUĞU GİBİ
  /// bırakır (kullanıcının elle yaptığı ayarı bir tahminle ezmek, tahmin
  /// yanlışsa geri alınamaz bir kayıp olurdu).
  ///
  /// Çözümleme **izolatta**: 12 MP bir fotoğrafta Sobel + Hough ana izleği
  /// yarım saniye kilitler, ekran donuk açılırdı.
  Future<void> _autoDetect() async {
    final img = _image;
    if (img == null || _detecting) return;
    setState(() => _detecting = true);
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final found = await compute(_detectCorners, bytes);
      if (!mounted) return;
      setState(() {
        _detecting = false;
        if (found == null) {
          _autoFound = false;
          return;
        }
        _autoFound = true;
        _corners = [
          for (final c in found)
            Offset(
              c.x.clamp(0.0, img.width.toDouble()),
              c.y.clamp(0.0, img.height.toDouble()),
            )
        ];
      });
    } catch (_) {
      if (mounted) setState(() => _detecting = false);
    }
  }

  /// Başlangıç dörtgeni: görselin tamamı, kenardan biraz içeride. Tam kenarda
  /// başlarsa tutamaçlar ekran dışına taşar ve yakalanamaz.
  List<Offset> _fullFrame(ui.Image img) {
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    final ix = w * 0.02;
    final iy = h * 0.02;
    return [
      Offset(ix, iy),
      Offset(w - ix, iy),
      Offset(w - ix, h - iy),
      Offset(ix, h - iy),
    ];
  }

  /// Görselin ekrandaki (contain) yerleşimi: ölçek + sol-üst kayma.
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

  Future<void> _apply() async {
    final img = _image;
    if (img == null || _busy) return;
    setState(() => _busy = true);
    try {
      final png = await Perspective.warpToPng(img, _corners);
      final path = await writeTempPng(widget.imagePath, 'duzeltildi', png);
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(
              content: Text(AppStrings.current.t('se.failed', {'error': e}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.t('se.title')),
        actions: [
          if (img != null)
            IconButton(
              tooltip: context.t('se.auto_detect'),
              icon: _detecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_fix_high),
              onPressed: _busy || _detecting ? null : _autoDetect,
            ),
          if (img != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _corners = _fullFrame(img);
                        _autoFound = false;
                      }),
              child: Text(context.t('se.reset')),
            ),
        ],
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
                    _hint(),
                  ],
                ),
      bottomNavigationBar: img == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _apply,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.crop_free),
                  label: Text(
                      context.t(_busy ? 'se.working' : 'common.apply')),
                ),
              ),
            ),
    );
  }

  Widget _hint() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          _detecting
              ? context.t('se.detecting')
              : context.t(_autoFound ? 'se.auto_found' : 'se.hint'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );

  Widget _editor(ui.Image img) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final fit = _fit(viewport, img);
        Offset toScreen(Offset imagePoint) =>
            fit.origin + imagePoint * fit.scale;

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _QuadPainter(
                  image: img,
                  corners: _corners,
                  scale: fit.scale,
                  origin: fit.origin,
                  color: const Color(0xFF64B5F6),
                ),
              ),
            ),
            for (var i = 0; i < 4; i++)
              _handle(i, toScreen(_corners[i]), fit.scale, img),
          ],
        );
      },
    );
  }

  /// 48 px dokunma alanı (Material en küçük hedef), ortasında 22 px halka.
  Widget _handle(int index, Offset screenPoint, double scale, ui.Image img) {
    const touch = 48.0;
    return Positioned(
      left: screenPoint.dx - touch / 2,
      top: screenPoint.dy - touch / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          final next = _corners[index] + d.delta / scale;
          setState(() {
            _corners[index] = Offset(
              next.dx.clamp(0.0, img.width.toDouble()),
              next.dy.clamp(0.0, img.height.toDouble()),
            );
          });
        },
        child: SizedBox(
          width: touch,
          height: touch,
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF64B5F6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
      ),
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

  _QuadPainter({
    required this.image,
    required this.corners,
    required this.scale,
    required this.origin,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      image.width * scale,
      image.height * scale,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );

    final pts = [for (final c in corners) origin + c * scale];
    final path = Path()..addPolygon(pts, true);

    // Dörtgen DIŞI karartılır: kullanıcı neyin kalacağını bir bakışta görür.
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      path,
    );
    canvas.drawPath(outside, Paint()..color = Colors.black.withOpacity(0.55));
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
      !_sameCorners(old.corners, corners);

  static bool _sameCorners(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
