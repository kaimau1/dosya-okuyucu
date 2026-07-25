import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/document.dart';

/// Dosya türüne göre renkli ikon.
///
/// [framed] false (varsayılan) → **çerçevesiz**: kutu/kenarlık olmadan doğrudan
/// glif çizilir ve kutunun neredeyse tamamını kaplar. Kullanıcı isteği
/// (2026-07-25): "öyle dış çerçeve olmasın direkt simge olsun, daha büyük ve
/// premium görünür." Çerçeveli hâl yalnız rozet gerektiren yerlerde
/// ([framed] true) kalır.
class FileTypeIcon extends StatelessWidget {
  final DocKind kind;
  final double size;
  final bool framed;

  const FileTypeIcon({
    super.key,
    required this.kind,
    this.size = 40,
    this.framed = false,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style(kind);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Koyu temada marka renkleri koyu zeminde söner → ikon biraz açılır
    // (her iki temada da 3:1 glif kontrastı korunur).
    final tint = dark ? Color.lerp(color, Colors.white, 0.25)! : color;
    if (!framed) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(icon, color: tint, size: size * 0.92),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: dark ? 0.22 : 0.13),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: tint, size: size * 0.52),
    );
  }

  /// Dosya türü ikonu + rengi.
  ///
  /// Office dörtlüsünün rengi [OfficeColors]'tan gelir — üst şeritle AYNI marka
  /// tonu olsun diye (eskiden burada ayrı bir hex seti vardı: PDF #E53935 vs
  /// şeritteki #C50F1F gibi, aynı dosya iki ayrı kırmızıyla görünüyordu).
  /// Metin/görsel/bilinmeyen şeritte tek nötr renge düşer; listede birbirinden
  /// ayrılmaları gerektiği için burada kendi ayırt edici tonları var.
  (IconData, Color) _style(DocKind kind) {
    switch (kind) {
      case DocKind.pdf:
        return (Icons.picture_as_pdf, OfficeColors.pdf);
      case DocKind.word:
        return (Icons.description, OfficeColors.word);
      case DocKind.spreadsheet:
        return (Icons.table_chart, OfficeColors.excel);
      case DocKind.slides:
        return (Icons.slideshow, OfficeColors.slides);
      case DocKind.text:
        return (Icons.article_outlined, const Color(0xFF6D4C41));
      case DocKind.image:
        return (Icons.image, const Color(0xFF8E24AA));
      case DocKind.unknown:
        return (Icons.insert_drive_file, const Color(0xFF757575));
    }
  }
}
