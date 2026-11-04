import 'package:flutter/material.dart';

import '../core/theme.dart';

/// **Sekme içindeki ince araç satırı** (2026-11-04).
///
/// Bir ekran başka bir ekranın sekmesi olarak açıldığında (İşlemler ›
/// Yer aç / Sohbet medyası / Düzenle) kendi tam başlık çubuğunu çizmez — üstte
/// zaten sekmeli bir başlık var, ikinci bir geri oku kafa karıştırırdı. Ekranın
/// eylemleri (yenile, klasörü aç…) bu alçak satıra taşınır; başlık yerine kısa
/// bir bağlam yazısı durabilir.
class EmbeddedToolbar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget> actions;

  const EmbeddedToolbar({super.key, this.title, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: Gap.md, end: Gap.xs),
        child: Row(
          children: [
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
