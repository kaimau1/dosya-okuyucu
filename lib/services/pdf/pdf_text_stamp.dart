import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **Sayfaya yazı kutusu ekle** — paragraf motorunun düzenleyemediği
/// sayfaların yedeği (Faz 8, karar K12).
///
/// Eski kelime-bazlı yerinde düzenleme yolu (`PdfContentEditor`, ~1.600
/// satır) kalkınca, paragraf motorunun REDDETTİĞİ belgelerde (genişlik
/// tablosu olmayan font, çözülemeyen içerik akışı, `/ToUnicode`'suz eski
/// üretici çıktısı) kullanıcının elinde hiçbir yol kalmasın diye: dokunulan
/// noktaya yeni yazı basılır. Var olan metne dokunulmaz — "düzelt" değil
/// "ekle"; eski bir yazıyı örtmek isteyen önce Kalem'in silgisini kullanır.
///
/// Koordinatlar **görünen sayfaya** göredir: sol-üst köşe (0,0), birim PDF
/// noktası, sayfa döndürülmüşse DÖNDÜRÜLMÜŞ hâli (kullanıcının ekranda
/// gördüğü). Ham sayfa uzayına çeviri [viewToRaw]'da; yazı da döndürmeye
/// göre çevrilir ki kullanıcı onu ekranda düz okusun.
abstract final class PdfTextStamp {
  static Uint8List? _fontCache;

  static Future<Uint8List> _font() async =>
      _fontCache ??= (await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
          .buffer
          .asUint8List();

  /// [text]'i [pageIndex] sayfasında görünen (x, y) noktasından başlayarak
  /// yazar; yeni belge baytlarını döndürür. Uzun satır sayfanın sağ
  /// kenarında sarılır.
  static Future<List<int>> add({
    required List<int> bytes,
    required int pageIndex,
    required double x,
    required double y,
    required String text,
    double size = 12,
    int colorArgb = 0xFF191919,
  }) async {
    final clean = text.trimRight();
    if (clean.trim().isEmpty) return bytes;
    final font = await _font();
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final page = doc.pages[pageIndex];
      final turns = quarterTurnsOf(page.rotation);
      final raw = page.size;
      final at = viewToRaw(turns, raw.width, raw.height, Offset(x, y));
      final viewWidth = turns.isOdd ? raw.height : raw.width;
      final viewHeight = turns.isOdd ? raw.width : raw.height;
      final g = page.graphics;
      final state = g.save();
      try {
        g.translateTransform(at.dx, at.dy);
        if (turns != 0) g.rotateTransform(-90.0 * turns);
        g.drawString(
          clean,
          PdfTrueTypeFont(font, size.clamp(4.0, 144.0).toDouble()),
          brush: PdfSolidBrush(PdfColor(
            (colorArgb >> 16) & 0xFF,
            (colorArgb >> 8) & 0xFF,
            colorArgb & 0xFF,
          )),
          bounds: Rect.fromLTWH(
            0,
            0,
            math.max(size * 2, viewWidth - x - 8),
            math.max(size * 2, viewHeight - y),
          ),
        );
      } finally {
        g.restore(state);
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// Syncfusion döndürme değerinin çeyrek tur sayısı (saat yönünde 0-3).
  static int quarterTurnsOf(PdfPageRotateAngle angle) => switch (angle) {
        PdfPageRotateAngle.rotateAngle0 => 0,
        PdfPageRotateAngle.rotateAngle90 => 1,
        PdfPageRotateAngle.rotateAngle180 => 2,
        PdfPageRotateAngle.rotateAngle270 => 3,
      };

  /// Görünen (döndürülmüş) sayfadaki sol-üst kökenli noktayı HAM sayfa
  /// uzayına (yine sol-üst kökenli, Syncfusion'ın çizim uzayı) çevirir.
  ///
  /// [rawWidth]/[rawHeight] döndürülmemiş sayfa ölçüsüdür. Sayfa saat
  /// yönünde [turns] çeyrek tur döndürülüp gösterilir; ters dönüşüm:
  /// - 0: aynı nokta,
  /// - 1 (90°): ham (y, H − x),
  /// - 2 (180°): ham (W − x, H − y),
  /// - 3 (270°): ham (W − y, x).
  ///
  /// Yazı yönü de aynı dönüşümle döner: ham uzayda `turns × 90°` saat
  /// yönünde döndürülen yazı, ekranda düz okunur.
  static Offset viewToRaw(
      int turns, double rawWidth, double rawHeight, Offset view) {
    return switch (turns % 4) {
      1 => Offset(view.dy, rawHeight - view.dx),
      2 => Offset(rawWidth - view.dx, rawHeight - view.dy),
      3 => Offset(rawWidth - view.dy, view.dx),
      _ => view,
    };
  }
}
