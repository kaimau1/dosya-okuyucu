import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../services/doc_edges.dart';
import '../services/perspective.dart';
import '../core/snack.dart';

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
///
/// ## Açılışta HİÇBİR ŞEY KESİLMEZ (2026-10-17)
/// Kullanıcı: *"belge taramada kesme sorunu"*. İki yol sayfayı kullanıcı
/// istemeden kırpıyordu:
/// * Başlangıç çerçevesi görselin %2 İÇİNDEN başlıyordu (tutamaçlar ekran
///   dışına taşmasın diye). Köşelere dokunmadan "Uygula" diyen kullanıcı her
///   kenardan %2 kaybediyordu. Artık çerçeve görselin tam sınırında; tutamaçlar
///   editörün iç payı sayesinde yine yakalanabiliyor.
/// * Kenar bulucu açılışta kendiliğinden UYGULANIYORDU. ML Kit sayfayı zaten
///   kâğıdın kenarından kırpıp getirdiği için bulucu çoğu zaman sayfanın
///   içindeki bir tabloyu/çerçeveyi buluyor; "Uygula" o çerçevenin dışını
///   kesiyordu. Bulucu yine açılışta koşar ama sonucu yalnız **öneri** olarak
///   gösterilir ("Kenar bulundu — oturt"); dokunulmadıkça çerçeve değişmez.
class ScanEditScreen extends StatefulWidget {
  const ScanEditScreen({super.key, required this.imagePath});

  final String imagePath;

  static Future<String?> open(BuildContext context, String imagePath) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ScanEditScreen(imagePath: imagePath)),
    );
  }

  /// Başlangıç dörtgeni: görselin TAMAMI — tam sınırda. "Uygula"ya dokunmadan
  /// basan kullanıcının sayfasından tek piksel bile gitmez.
  static List<Offset> fullFrame(int width, int height) {
    final w = width.toDouble();
    final h = height.toDouble();
    return [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)];
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

  /// Açılıştaki aramanın bulduğu, henüz UYGULANMAMIŞ dörtgen (öneri).
  List<Offset>? _suggested;

  /// Tutamaçların ekran dışına taşmaması için editörün iç payı. Çerçeve artık
  /// görselin tam sınırında başlıyor; pay olmasa kenardaki tutamacın yarısı
  /// ekran dışında kalırdı.
  static const _editorPad = 24.0;

  /// Sürüklenmekte olan köşenin İNDEKSİ (yoksa null) — büyüteç bu köşeyi
  /// izler. 2026-08-06 kullanıcı bulgusu: *"köşeleri ayarlarken eskiden ufak
  /// bir zoom ekranı geliyordu, o kaybolmuş"* — parmak köşeyi kapattığı için
  /// büyüteç olmadan hassas ayar yapılamıyor.
  int? _dragCorner;

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
      // Ekran açılır açılmaz kenarlar aranır (istek 2026-07-30: kullanıcı dört
      // köşeyi tek tek sürüklemek zorunda kalmasın) — ama sonuç yalnız ÖNERİ:
      // bkz. sınıf notu, "Açılışta hiçbir şey kesilmez".
      await _autoDetect(apply: false);
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
  ///
  /// [apply] false ise (açılış) bulunan dörtgen yalnız öneri olarak saklanır.
  Future<void> _autoDetect({bool apply = true}) async {
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
          _suggested = null;
          return;
        }
        final corners = [
          for (final c in found)
            Offset(
              c.x.clamp(0.0, img.width.toDouble()),
              c.y.clamp(0.0, img.height.toDouble()),
            )
        ];
        if (apply) {
          _autoFound = true;
          _suggested = null;
          _corners = corners;
        } else {
          _suggested = corners;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _detecting = false);
    }
  }

  void _useSuggestion() {
    final suggested = _suggested;
    if (suggested == null) return;
    setState(() {
      _corners = List.of(suggested);
      _suggested = null;
      _autoFound = true;
    });
  }

  List<Offset> _fullFrame(ui.Image img) =>
      ScanEditScreen.fullFrame(img.width, img.height);

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
    // Çerçeveye dokunulmadıysa ortada düzeltilecek bir şey yok: görseli
    // yeniden örneklemek yalnız kaliteyi düşürürdü.
    if (_sameQuad(_corners, _fullFrame(img))) {
      Navigator.of(context).pop(widget.imagePath);
      return;
    }
    setState(() => _busy = true);
    try {
      final png = await Perspective.warpToPng(img, _corners);
      final path = await writeTempPng(widget.imagePath, 'duzeltildi', png);
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, AppStrings.current.t('se.failed', {'error': e}));
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
                  label: Text(context.t(_busy ? 'se.working' : 'common.apply')),
                ),
              ),
            ),
    );
  }

  Widget _hint() {
    final text = Text(
      _detecting
          ? context.t('se.detecting')
          : context.t(_autoFound ? 'se.auto_found' : 'se.hint'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: _suggested == null || _detecting
          ? text
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                text,
                const SizedBox(height: 6),
                // Öneri: bulunan kâğıt kenarı, dokununca çerçeve oraya oturur.
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _useSuggestion,
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(context.t('se.use_found')),
                ),
              ],
            ),
    );
  }

  Widget _editor(ui.Image img) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Görsel iç payla küçültülüp ortalanır: köşe tutamacı tam görsel
        // sınırındayken bile 48 dp dokunma alanının tamamı ekranda kalır.
        final viewport = Size(
          (constraints.maxWidth - 2 * _editorPad).clamp(1.0, double.infinity),
          (constraints.maxHeight - 2 * _editorPad).clamp(1.0, double.infinity),
        );
        final inner = _fit(viewport, img);
        final fit = (
          scale: inner.scale,
          origin: inner.origin + const Offset(_editorPad, _editorPad),
        );
        Offset toScreen(Offset imagePoint) =>
            fit.origin + imagePoint * fit.scale;

        return Stack(
          clipBehavior: Clip.none,
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
            if (_dragCorner != null)
              _buildMagnifier(toScreen(_corners[_dragCorner!])),
          ],
        );
      },
    );
  }

  /// Köşe sürüklenirken parmağın üstünde duran büyüteç — PDF seçim
  /// katmanındakiyle aynı his (RawMagnifier, 1,8 kat). Parmağın 70 px
  /// üstünde durur, odak parmaktadır; kenarda yatayda kıstırılır.
  Widget _buildMagnifier(Offset at) {
    const size = Size(120, 120);
    const above = 70.0;
    final left = at.dx - size.width / 2;
    final top = at.dy - size.height / 2 - above;
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: RawMagnifier(
          size: size,
          focalPointOffset: const Offset(0, above),
          magnificationScale: 1.8,
          decoration: MagnifierDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(60),
              side: const BorderSide(color: Colors.white70, width: 2),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 10,
                offset: Offset(0, 3),
                blurStyle: BlurStyle.outer,
              ),
            ],
          ),
        ),
      ),
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
        onPanStart: (_) => setState(() => _dragCorner = index),
        onPanUpdate: (d) {
          final next = _corners[index] + d.delta / scale;
          setState(() {
            _corners[index] = Offset(
              next.dx.clamp(0.0, img.width.toDouble()),
              next.dy.clamp(0.0, img.height.toDouble()),
            );
          });
        },
        onPanEnd: (_) => setState(() => _dragCorner = null),
        onPanCancel: () => setState(() => _dragCorner = null),
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

bool _sameQuad(List<Offset> a, List<Offset> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).distance > 0.5) return false;
  }
  return true;
}

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
    canvas.drawPath(
        outside, Paint()..color = Colors.black.withValues(alpha: 0.55));
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
