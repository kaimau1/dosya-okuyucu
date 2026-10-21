import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../screens/settings_screen.dart';

/// **Anahtarsız AI deneyimi** (Faz 5, 2026-10-21 — FAZ_PLANI I8 / N3).
///
/// Eskiden anahtar yokken AI düğmesine basan kullanıcı "anahtar gerekli"
/// diyen bir bildirimle çıkmaz sokağa giriyordu (her ekran kendi metniyle).
/// Artık hepsi buradan geçer: anahtar varsa `true`; yoksa TEK bir "AI'yı
/// etkinleştir" penceresi — ne işe yarar, neden anahtar ister, ücretsiz
/// olduğu, verinin nereye gittiği — ve "Anahtar ekle" düğmesi doğrudan AI
/// ayarlarını açar.
Future<bool> ensureAiKey(BuildContext context) async {
  if (context.read<AppState>().hasApiKey) return true;
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome_outlined,
                  color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(ctx.t('aikey.title'),
                    style: Theme.of(ctx).textTheme.titleLarge),
              ),
            ]),
            const SizedBox(height: 12),
            Text(ctx.t('aikey.body')),
            const SizedBox(height: 8),
            Text(ctx.t('aikey.privacy'),
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(ctx.t('common.cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.key_outlined),
                  label: Text(ctx.t('aikey.add')),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (go == true && context.mounted) {
    await openSettingsCategory(context, 'ai');
    if (context.mounted) return context.read<AppState>().hasApiKey;
  }
  return false;
}
