import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/file_service.dart';
import '../file_type_icon.dart';

/// Dosya yöneticisi ikon paleti. Office dörtlüsü [OfficeColors]'tan gelir
/// (liste ve şerit aynı tonu kullansın diye — bkz. HAFIZA 2026-07-24 tutarsızlık
/// bulgusu); yeni kategoriler burada tanımlanır.
abstract final class FmColors {
  static const folder = Color(0xFFF2A93B); // klasör sarısı
  static const image = Color(0xFF8E24AA);
  static const video = Color(0xFFD32F2F);
  static const audio = Color(0xFF00897B);
  static const archive = Color(0xFF6D4C41);
  static const apk = Color(0xFF43A047);
  static const other = Color(0xFF757575);

  static Color forCategory(FmCategory c) => switch (c) {
        FmCategory.folder => folder,
        FmCategory.image => image,
        FmCategory.video => video,
        FmCategory.audio => audio,
        FmCategory.archive => archive,
        FmCategory.apk => apk,
        FmCategory.document => OfficeColors.neutral,
        FmCategory.other => other,
      };

  static IconData iconFor(FmCategory c) => switch (c) {
        FmCategory.folder => Icons.folder_rounded,
        FmCategory.image => Icons.image_rounded,
        FmCategory.video => Icons.movie_rounded,
        FmCategory.audio => Icons.music_note_rounded,
        FmCategory.archive => Icons.folder_zip_rounded,
        FmCategory.apk => Icons.android_rounded,
        FmCategory.document => Icons.description_rounded,
        FmCategory.other => Icons.insert_drive_file_rounded,
      };
}

/// Bir girdinin ikonu. Görsellerde gerçek küçük resim (thumbnail) gösterilir;
/// belgelerde mevcut [FileTypeIcon] rozeti (Word mavisi / Excel yeşili …).
class FmEntryIcon extends StatelessWidget {
  final FsEntry entry;
  final double size;

  /// Küçük resim üretilsin mi? (Hızlı kaydırmada kapatılabilir.)
  final bool thumbnails;

  const FmEntryIcon({
    super.key,
    required this.entry,
    this.size = 44,
    this.thumbnails = true,
  });

  @override
  Widget build(BuildContext context) {
    final category = entry.category;

    if (category == FmCategory.document) {
      return FileTypeIcon(
        kind: FileService.kindForExtension(entry.extension),
        size: size,
      );
    }

    if (thumbnails && category == FmCategory.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.control),
        child: Image.file(
          File(entry.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Bellek koruması: 4000px'lik bir fotoğrafı 44dp'lik kutuya tam
          // çözünürlükte açmak listeyi şişirir (cacheWidth = decode boyutu).
          cacheWidth: (size * 3).round(),
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _badge(context, category),
        ),
      );
    }

    return _badge(context, category);
  }

  Widget _badge(BuildContext context, FmCategory category) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = FmColors.forCategory(category);
    final tint = dark ? Color.lerp(base, Colors.white, 0.25)! : base;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: dark ? 0.22 : 0.13),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Icon(FmColors.iconFor(category), color: tint, size: size * 0.54),
    );
  }
}
