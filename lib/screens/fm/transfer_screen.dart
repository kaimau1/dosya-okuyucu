import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/theme.dart';
import '../../services/fm/download_service.dart';
import '../../services/fm/remote/ftp_service.dart';
import 'download_manager_screen.dart';
import 'remote/ftp_server_screen.dart';
import 'remote/peer_share_screen.dart';
import 'remote/remote_connections_screen.dart';

/// **Aktar** — telefonun dışına/dışından dosya taşımanın tek kapısı
/// (2026-10-21, Faz 2 / FAZ_PLANI §3.5).
///
/// Panoda dört ayrı kutu vardı (Ağdan erişim, Yakındaki cihaz, Ağ depolama,
/// İndir); kullanıcı "bilgisayara nasıl atarım" sorusunda hangisine
/// basacağını bilmek zorundaydı. Burada her biri sorunun kendisiyle
/// adlandırılır: *Bilgisayarla* (tarayıcı + QR + FTP, tek ekran),
/// *Telefonla*, *Ağ depolama*, *İndirmeler*. Canlı durum (paylaşım açık,
/// süren indirme) satırın altında yazar.
class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('xfer.title'))),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [FtpService.instance, DownloadService.instance]),
        builder: (context, _) {
          final sharing = FtpService.instance.running;
          final downloading = DownloadService.instance.activeTasks.length;
          return ListView(
            padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
            children: [
              _Row(
                icon: sharing ? Icons.wifi_tethering : Icons.computer_outlined,
                color: const Color(0xFF00897B),
                title: context.t('xfer.computer'),
                note: sharing
                    ? context.t('ftpd.running')
                    : context.t('xfer.computer_note'),
                live: sharing,
                screen: const FtpServerScreen(),
              ),
              _Row(
                icon: Icons.send_to_mobile_outlined,
                color: const Color(0xFF00838F),
                title: context.t('xfer.phone'),
                note: context.t('xfer.phone_note'),
                screen: const PeerShareScreen(),
              ),
              _Row(
                icon: Icons.dns_outlined,
                color: const Color(0xFF5E35B1),
                title: context.t('fm.network_storage'),
                note: context.t('xfer.nas_note'),
                screen: const RemoteConnectionsScreen(),
              ),
              _Row(
                icon: Icons.download_for_offline_outlined,
                color: const Color(0xFF1565C0),
                title: context.t('xfer.downloads'),
                note: downloading > 0
                    ? context.t('fm.jobs_running', {'n': downloading})
                    : context.t('xfer.downloads_note'),
                live: downloading > 0,
                screen: const DownloadManagerScreen(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String note;
  final bool live;
  final Widget screen;

  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.note,
    required this.screen,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(
          note,
          style: live ? TextStyle(color: Paper.success(context)) : null,
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => screen)),
      ),
    );
  }
}
