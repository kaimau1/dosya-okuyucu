/// **Tek "Paylaş / Dışa aktar" sayfası** (Faz 40 / madde 7, 2026-11-05).
///
/// KÖK NEDEN: her editör dışa aktarımı başka yerde ve başka adla sunuyordu —
/// Excel'de alt çubukta Paylaş + CSV, Slayt'ta alt çubukta PDF + Paylaş ve
/// Araçlar'da PNG/MP4, Word'de Araçlar sekmesinde altı biçimli bir seçici.
/// Artık her editörün ⋮ menüsündeki "Paylaş / Dışa aktar" AYNI sayfayı açar:
/// üstte **Biçim** (PDF, belgenin kendi biçimi, görüntü, diğerleri), altta
/// **Gönder** (paylaş, İndirilenler'e kaydet, yakındaki cihaza / bağlantı).
///
/// Sayfa yalnız bir menüdür: her satır editörün ZATEN var olan işini çağırır
/// (PDF üretimi izolatta/ilerleme penceresiyle vb. — anayasa §1 korunur).
/// Sayfa kapanır, sonra iş başlar (levha işin ilerleme penceresini örtmesin).
library;

import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../screens/fm/remote/nearby_screen.dart';
import 'app_dialog.dart';

enum ShareExportGroup { format, send }

class ShareExportEntry {
  final String id;
  final IconData icon;
  final String label;
  final String? hint;
  final ShareExportGroup group;
  final Future<void> Function() run;

  const ShareExportEntry({
    required this.id,
    required this.icon,
    required this.label,
    required this.run,
    this.hint,
    this.group = ShareExportGroup.format,
  });

  /// "Yakındaki cihaza gönder" — [path] KAYITLI dosya; [beforeSend] (ör.
  /// kirliyse kaydet) önce çalışır.
  static ShareExportEntry nearby(
    BuildContext context, {
    required String path,
    Future<void> Function()? beforeSend,
  }) {
    final nav = Navigator.of(context);
    return ShareExportEntry(
      id: 'nearby',
      icon: AppIcons.qr,
      label: context.t('ux.send_nearby'),
      hint: context.t('ux.send_nearby_hint'),
      group: ShareExportGroup.send,
      run: () async {
        await beforeSend?.call();
        await nav.push(MaterialPageRoute<void>(
            builder: (_) => NearbyScreen(sendPaths: [path])));
      },
    );
  }
}

/// Sayfayı açar; seçilen satırın işini sayfa kapandıktan SONRA çalıştırır.
Future<void> showShareExportSheet(
  BuildContext context, {
  required List<ShareExportEntry> entries,
}) async {
  final picked = await showAppSheet<ShareExportEntry>(
    context,
    title: context.t('ux.share_export'),
    builder: (ctx) => ShareExportList(entries: entries),
  );
  if (picked != null) await picked.run();
}

/// Sayfanın gövdesi (test edilebilsin diye ayrı).
class ShareExportList extends StatelessWidget {
  final List<ShareExportEntry> entries;
  const ShareExportList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget header(String key) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 4),
          child: Text(context.t(key),
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary)),
        );
    Widget tile(ShareExportEntry e) => ListTile(
          key: ValueKey('share-export-${e.id}'),
          leading: Icon(e.icon),
          title: Text(e.label),
          subtitle: e.hint == null ? null : Text(e.hint!),
          onTap: () => Navigator.of(context).pop(e),
        );
    final formats =
        entries.where((e) => e.group == ShareExportGroup.format).toList();
    final send = entries.where((e) => e.group == ShareExportGroup.send).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (formats.isNotEmpty) ...[
          header('ux.group_format'),
          for (final e in formats) tile(e),
        ],
        if (send.isNotEmpty) ...[
          header('ux.group_send'),
          for (final e in send) tile(e),
        ],
      ],
    );
  }
}
