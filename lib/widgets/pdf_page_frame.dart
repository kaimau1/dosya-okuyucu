import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_colors.dart';
import '../core/skin.dart';
import '../core/theme.dart' show AppSkinData;

/// PDF görüntüleyicide **kâğıt teması sayfa çerçevesi** (2026-11-02,
/// KALANLAR A7.7): kâğıt temasında sayfanın gölgesi kalkar, yerine Word
/// sayfasıyla aynı ince çerçeve (`#D2C8B4`) çizilir. Öteki temalarda pdfrx'in
/// varsayılan gölgesi.
///
/// Sınır: sayfanın İÇİ pdfium'un beyaz çizimi (pdfrx 1.3.5 görüntüleyicisi
/// zemin rengini dışarı açmıyor) — `#FBF8F1` kâğıt zemini yalnız Word'de.
class PdfPageFrame {
  const PdfPageFrame._(this.enabled);

  final bool enabled;

  static PdfPageFrame of(BuildContext context) {
    final skin = AppSkinData.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark ||
        skin.skin.forcesDark;
    return PdfPageFrame._(skin.skin == AppSkin.clay && !dark);
  }

  /// `PdfViewerParams.pageDropShadow` için: çerçeveliyken gölge yok.
  /// `null` dönerse çağıran pdfrx varsayılanını kullanır.
  BoxShadow? get shadowOrDefault => enabled ? null : _pdfrxDefault;

  static const _pdfrxDefault = BoxShadow(
      color: AppColors.mediaScrim, // = pdfrx varsayılanı black54
      blurRadius: 4,
      spreadRadius: 2,
      offset: Offset(2, 2));

  /// `pagePaintCallbacks`'e eklenir: sayfanın kenarına tek piksellik çizgi
  /// (kalınlık 0 = yakınlığa bakmadan 1 cihaz pikseli).
  void paint(Canvas canvas, Rect pageRect, PdfPage page) {
    if (!enabled) return;
    canvas.drawRect(
      pageRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0
        ..color = AppColors.paperFrame,
    );
  }
}
