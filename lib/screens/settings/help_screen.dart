import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/edition.dart';
import '../../core/l10n/app_strings.dart';
import '../../widgets/permission_gate.dart';
import 'feedback_screen.dart';

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
    // Faz 11a: içerik genişletmesi.
    'open_with',
    'reading',
    'resize',
    'trash',
    'usb',
    'video',
  ];

  /// "Sorun bildir" → Hata / istek bildir ekranı (2026-11-22).
  static Future<void> reportProblem(BuildContext context) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('help.title'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final id in topics)
            if (id != 'ai_key' || Edition.current.has(Feature.ai))
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
                    if (p != AppPermission.overlay || !Edition.current.isPlay)
                      PermissionStatusRow(permission: p),
                ],
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonalIcon(
              key: const ValueKey('help-report'),
              onPressed: () => reportProblem(context),
              icon: const Icon(AppIcons.send),
              label: Text(context.t('help.report')),
            ),
          ),
        ],
      ),
    );
  }
}
