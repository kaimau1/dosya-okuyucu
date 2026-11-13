import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';

/// Aktarımın şifreli olup olmadığını söyleyen küçük rozet (Faz G5).
///
/// * **Şifreli:** yeşil kilit; [verifyCode] doluysa yanında "Doğrulama
///   123 456" — iki ekranda aynı sayı görünmeli (görünmüyorsa araya biri
///   girmiştir, kabul edilmemeli).
/// * **Şifresiz:** eski sürüm eşle düz protokol; turuncu açık kilit.
class SecureBadge extends StatelessWidget {
  final bool encrypted;
  final String verifyCode;

  const SecureBadge({super.key, required this.encrypted, this.verifyCode = ''});

  /// `123456` → `123 456` (okunurken karıştırılmasın).
  static String spaced(String code) => code.length == 6
      ? '${code.substring(0, 3)} ${code.substring(3)}'
      : code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        encrypted ? Paper.success(context) : theme.colorScheme.tertiary;
    final label = encrypted
        ? (verifyCode.isEmpty
            ? context.t('g5.encrypted')
            : context.t('g5.encrypted_code', {'code': spaced(verifyCode)}))
        : context.t('g5.unencrypted');
    return Row(
      key: ValueKey(encrypted ? 'g5-secure' : 'g5-plain'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(encrypted ? AppIcons.lock : AppIcons.unlock, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: color)),
        ),
      ],
    );
  }
}
