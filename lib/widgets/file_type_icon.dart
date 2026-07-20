import 'package:flutter/material.dart';

import '../models/document.dart';

/// Dosya türüne göre renkli ikon rozeti.
class FileTypeIcon extends StatelessWidget {
  final DocKind kind;
  final double size;
  const FileTypeIcon({super.key, required this.kind, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style(kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }

  (IconData, Color) _style(DocKind kind) {
    switch (kind) {
      case DocKind.pdf:
        return (Icons.picture_as_pdf, const Color(0xFFE53935));
      case DocKind.word:
        return (Icons.description, const Color(0xFF1E88E5));
      case DocKind.spreadsheet:
        return (Icons.table_chart, const Color(0xFF43A047));
      case DocKind.slides:
        return (Icons.slideshow, const Color(0xFFFB8C00));
      case DocKind.text:
        return (Icons.article_outlined, const Color(0xFF6D4C41));
      case DocKind.image:
        return (Icons.image, const Color(0xFF8E24AA));
      case DocKind.unknown:
        return (Icons.insert_drive_file, const Color(0xFF757575));
    }
  }
}
