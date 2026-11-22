import 'package:flutter/material.dart';

/// Kategori ekranlarının (Fotoğraflar · Videolar · Belgeler · İndirilenler)
/// ortak **üst çubuk başlığı**: başlık + tek satır özet.
///
/// 2026-11-22 (kullanıcı: "üst alanları toparla — videolar, belgeler,
/// indirilenler, fotolar hepsinde"): 22 sp başlık + 5 simge yan yana
/// sığmıyor, "Fotoğr…" / "3171 / 3417 …" diye kesiliyordu. Başlık 18 sp,
/// özet 12 sp; çubukta en çok üç simge (Ara · Süzgeç · ⋮) kalır, gerisi ⋮'de.
class FmBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const FmBarTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}
