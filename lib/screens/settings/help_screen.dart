import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../widgets/permission_gate.dart';

/// **Yardım / SSS** (Faz 5 iskeleti, 2026-10-21 — FAZ_PLANI N11).
///
/// "Ne oluyor?" sorusunun kalıcı cevabı: izinler, kasa PIN'i, ağ paylaşımı,
/// AI anahtarı, hafif kip. İçerik Faz 11'de genişletilir; her madde üç dilde
/// `help.*` anahtarlarında.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  /// Soru anahtarı kökleri — sırayla gösterilir (`help.<id>_q` / `_a`).
  static const topics = [
    'permissions',
    'vault_pin',
    'network_share',
    'ai_key',
    'light_mode',
    'errors',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('help.title'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final id in topics)
            ExpansionTile(
              leading: const Icon(AppIcons.help),
              title: Text(context.t('help.${id}_q')),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('help.${id}_a')),
                if (id == 'permissions') ...[
                  const SizedBox(height: 8),
                  for (final p in AppPermission.values)
                    PermissionStatusRow(permission: p),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
