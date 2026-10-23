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

  const QrCode({super.key, required this.data, this.size = 180});

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

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.pageInk;
    final elements = Barcode.qrCode()
        .make(data, width: size.width, height: size.height, drawText: false);
    for (final e in elements) {
      if (e is BarcodeBar && e.black) {
        // Yarım pikselli boşluk kalmasın diye hafif taşırılır.
        canvas.drawRect(
            Rect.fromLTWH(e.left, e.top, e.width + 0.5, e.height + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}
