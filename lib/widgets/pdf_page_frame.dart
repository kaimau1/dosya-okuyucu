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
/// Sayfanın İÇİ (A9.2, 2026-11-12): pdfium beyaz çiziyor; çizimin üstüne
/// `#FBF8F1` ÇARPMA (multiply) kipinde boyanır → beyaz kâğıt rengine döner,
/// siyah yazı ve görseller (beyaz alanları dışında) değişmez.
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
    canvas.drawRect(pageRect, paperTint);
    canvas.drawRect(
      pageRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0
        ..color = AppColors.paperFrame,
    );
  }

  /// Kâğıt zemini boyası (çarpma kipi: beyaz → `#FBF8F1`, siyah aynı).
  static final Paint paperTint = Paint()
    ..color = AppColors.paperPage
    ..blendMode = BlendMode.multiply;
}
