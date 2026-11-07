import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// **QR kodu** (2026-10-18): ağ paylaşımının adresini başka bir cihazın
/// kamerasıyla okutmak için. Matris `barcode` paketinden (saf Dart, `pdf`
/// zaten çekiyordu), çizim bizim — ek bir widget paketi gerekmedi.
///
/// Koyu temada da QR **beyaz zemin üstünde siyah** çizilir: ters renkli QR'ı
/// bazı okuyucular tanımıyor.
class QrCode extends StatelessWidget {
  final String data;
  final double size;

  const QrCode({super.key, required this.data, this.size = 160});

  /// **Ekrana sığan QR kenarı** (2026-11-07, kullanıcı: *"QR daha küçük
  /// oluşsun ekrana sığsın"*). Kısa kenarın yarısı, kullanılabilir yüksekliğin
  /// en çok üçte biri; 132–220 dp arası. Telefon kamerası 132 dp'lik QR'ı
  /// 20–30 cm'den rahat okur — daha büyüğü yalnız ekranı kaplıyordu.
  static double fitSize(BuildContext context, {double max = 220}) {
    final mq = MediaQuery.of(context);
    final s = mq.size;
    final usableH = s.height - mq.padding.vertical - mq.viewInsets.bottom;
    final v = (s.shortestSide * 0.5).clamp(0.0, usableH / 3);
    return v.clamp(132.0, max);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.page,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Semantics(
          label: data,
          child: CustomPaint(
            size: Size.square(size),
            painter: _QrPainter(data),
          ),
        ),
      );
}

class _QrPainter extends CustomPainter {
  final String data;
  _QrPainter(this.data);

  /// Matris + yol bir kez kurulur (2026-11-07): eskiden HER boyamada
  /// `Barcode.make` yeniden koşuyordu — kaydırma/yeniden çizimde boşa CPU.
  Path? _path;
  Size? _pathSize;

  Path _build(Size size) {
    final path = Path();
    final elements = Barcode.qrCode()
        .make(data, width: size.width, height: size.height, drawText: false);
    for (final e in elements) {
      if (e is BarcodeBar && e.black) {
        // Yarım pikselli boşluk kalmasın diye hafif taşırılır.
        path.addRect(
            Rect.fromLTWH(e.left, e.top, e.width + 0.5, e.height + 0.5));
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_path == null || _pathSize != size) {
      _path = _build(size);
      _pathSize = size;
    }
    canvas.drawPath(_path!, Paint()..color = AppColors.pageInk);
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}
