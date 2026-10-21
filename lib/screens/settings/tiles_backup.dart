import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_version.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/settings_backup.dart';
import 'settings_widgets.dart';
import '../../core/user_error.dart';

/// **Ayar yedeği** — dışa aktar / geri yükle.
///
/// Uygulama mağazadan değil GitHub Releases'ten dağıtılıyor; Android'in
/// otomatik uygulama yedeği burada bir güvence değil. Telefon değiştiren ya
/// da uygulamayı silip kuran kullanıcı 40'tan fazla ayarı elle kuruyordu.
///
/// Yedeğin **neyi taşımadığı** alt satırda yazıyor (API anahtarları, PIN):
/// yeni telefonda "anahtarım nerede" diye aramasın.
class SettingsBackupTile extends StatelessWidget {
  const SettingsBackupTile({super.key});

  @override
  Widget build(BuildContext context) {
    // Yedekle ve geri yükle TEK satır (2026-10-21, Faz 2 ayar sadeleşmesi):
    // iki satır aynı dosyanın iki yönüydü.
    return SettingTile(
      icon: Icons.backup_outlined,
      title: context.t('backup.title'),
      subtitle: context.t('backup.sub'),
      wrapSubtitle: true,
      onTap: () => _choose(context),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: Text(ctx.t('backup.title')),
              subtitle: Text(ctx.t('backup.sub')),
              onTap: () => Navigator.pop(ctx, 'export'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: Text(ctx.t('backup.restore')),
              subtitle: Text(ctx.t('backup.restore_sub')),
              onTap: () => Navigator.pop(ctx, 'restore'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'export':
        await _export(context);
      case 'restore':
        await _restore(context);
    }
  }

  Future<void> _export(BuildContext context) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Yedek **İndirilenler**e yazılıyor: kullanıcının dosya paylaşırken
      // ilk baktığı yer ve uygulamanın kendi dizini gibi silinince kaybolan
      // bir yer değil.
      final downloads = p.join(FmEnv.primaryRoot, 'Download');
      final dir = Directory(downloads).existsSync()
          ? downloads
          : FmEnv.primaryRoot;
      final target =
          FileOps.uniquePath(p.join(dir, SettingsBackup.suggestedName()));
      await SettingsBackup.saveTo(target, prefs, appVersion: appVersionName);
      showSnackOn(messenger,
          strings.t('backup.saved', {'name': p.basename(target)}));
    } catch (e) {
      showSnackOn(messenger, strings.t('backup.failed', {'error': userErrorText(e)}));
    }
  }

  /// Yedekten geri yükleme. Dosya seçici ile bir `.json` seçtirir.
  Future<void> _restore(BuildContext context) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // `FileType.any`: bazı cihazların seçicisi `.json` uzantı süzgecini
      // desteklemiyor ve dosyayı hiç göstermiyor (uygulamanın başka
      // yerlerinde de aynı tuzağa düşüldü).
      final picked = await FilePicker.platform.pickFiles(type: FileType.any);
      final path = picked?.files.single.path;
      if (path == null) return;
      final prefs = await SharedPreferences.getInstance();
      final count = await SettingsBackup.restoreFrom(path, prefs);
      showSnackOn(messenger, strings.t('backup.restored', {'n': count}));
    } catch (e) {
      showSnackOn(
          messenger, strings.t('backup.restore_failed', {'error': userErrorText(e)}));
    }
  }
}
