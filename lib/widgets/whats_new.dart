import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_icons.dart';
import '../core/app_version.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import 'app_dialog.dart';

/// **Neler yeni** (Play yorum çalışması, 2026-11-08): güncelleme alışkanlığı
/// bozmasın — büyük değişiklikte (ANA.ARA değişince) güncelleyen kullanıcıya
/// BİR KEZ ne değiştiği söylenir. Yeni kurulum rehberi görür, bunu görmez.
/// Yama sürümleri (her APK) göstermez.
abstract final class WhatsNew {
  static const prefKey = 'whats_new_seen';
  static const current = '$appVersionMajor.$appVersionMinor';

  /// Bu ara sürümün yenilikleri (çeviri anahtarları). ARA hane artınca
  /// listeyi yenile — boşsa levha hiç açılmaz.
  static const items = [
    'whatsnew.privacy',
    'whatsnew.offline',
    'whatsnew.ai_ask',
    'whatsnew.add_folder',
    'whatsnew.reading',
    'whatsnew.faster',
  ];

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, current);
    } catch (_) {
      // Yazılamadı: levha bir sonraki açılışta yeniden çıkar (zararsız).
    }
  }

  /// Rehberi daha önce bitirmiş kullanıcı için: bu ara sürüm görülmediyse göster.
  static Future<void> maybeShow(BuildContext context) async {
    if (items.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(prefKey) == current) return;
    } catch (_) {
      return;
    }
    await markSeen();
    if (!context.mounted) return;
    await showAppSheet<void>(
      context,
      title: context.t('whatsnew.title', {'v': current}),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final k in items)
            ListTile(
              leading: const Icon(AppIcons.checkCircle),
              title: Text(ctx.t(k)),
            ),
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                key: const ValueKey('whats-new-ok'),
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.t('common.ok')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
