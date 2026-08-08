import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/file_ops.dart';

/// Çakışan adlar için "ne yapayım?" sayfası.
///
/// Üç seçenek [FmConflict]'in üç değeriyle birebir eşleşir. Sıra bilinçli:
/// **Yeniden adlandır** en üstte ve öne çıkarılmış — veri kaybı olmayan tek
/// seçenek o, ve eski davranış da oydu. **Üzerine yaz** kırmızı ve altta:
/// geri alınamaz.
///
/// Kapatma (geri tuşu / dışına dokunma) `null` döndürür = **vazgeç**.
/// Sessizce bir varsayılana düşmek, kullanıcının kapattığı bir pencerenin
/// yine de dosya yazması demek olurdu.
Future<FmConflict?> showPasteConflictSheet(
  BuildContext context, {
  required List<String> names,
}) {
  return showModalBottomSheet<FmConflict>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctx.t('paste.conflict_title', {'n': names.length}),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Gap.xs),
              // Hangi dosyalar çakışıyor GÖRÜNSÜN: "3 dosya çakışıyor" tek
              // başına hangi karar doğru bilinemez. Uzun listede ilk üçü +
              // kalan sayısı (pencere ekranı doldurmasın).
              Text(
                names.length <= 3
                    ? names.join(', ')
                    : ctx.t('paste.conflict_more', {
                        'names': names.take(3).join(', '),
                        'n': names.length - 3,
                      }),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Gap.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(ctx.t('paste.keep_both')),
                subtitle: Text(ctx.t('paste.keep_both_sub')),
                onTap: () => Navigator.pop(ctx, FmConflict.rename),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.skip_next_outlined),
                title: Text(ctx.t('paste.skip')),
                subtitle: Text(ctx.t('paste.skip_sub')),
                onTap: () => Navigator.pop(ctx, FmConflict.skip),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.warning_amber_outlined,
                    color: theme.colorScheme.error),
                title: Text(ctx.t('paste.overwrite'),
                    style: TextStyle(color: theme.colorScheme.error)),
                subtitle: Text(ctx.t('paste.overwrite_sub')),
                onTap: () => Navigator.pop(ctx, FmConflict.overwrite),
              ),
            ],
          ),
        ),
      );
    },
  );
}
