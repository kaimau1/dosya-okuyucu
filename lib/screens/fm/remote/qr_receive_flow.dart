import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:path/path.dart' as p;

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/snack.dart';
import '../../../core/theme.dart';
import '../../../core/user_error.dart';
import '../../../models/fs_entry.dart';
import '../../../services/fm/entry_opener.dart';
import '../../../services/fm/file_ops.dart' show FmProgress;
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/fs_events.dart';
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/remote/qr_transfer.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/fm/fm_entry_icon.dart';
import '../../../widgets/fm/fm_progress_dialog.dart';
import '../browser_screen.dart';

/// **QR ile al** — tek akış: kodu tara → gelecek dosyaları GÖSTER ve onay
/// iste → indir (ilerleme penceresiyle) → "N dosya alındı · Aç".
///
/// Kullanıcı isteği (2026-10-28): *"QR'la al seçeneği yüzen buton olmalı —
/// biri paylaşırken uygulama içinden alma; şu an pek işe yaramıyor"* ve
/// *"dosya almada onay olmalı en sonda"*. Eskiden alma yalnız Yakındaki
/// cihaz → Al sekmesinin içindeydi (üç dokunuş, bulunmuyordu) ve kod
/// okunur okunmaz ne geldiği söylenmeden indirme başlıyordu.
///
/// Panonun yüzen çubuğundan ve Yakındaki cihaz ekranından AYNI akış çağrılır.
/// Dönen liste indirilen yollardır (vazgeçildiyse/başarısızsa boş).
abstract final class QrReceiveFlow {
  static String defaultSaveDir() {
    final download = p.join(FmEnv.primaryRoot, 'Download');
    return Directory(download).existsSync() ? download : FmEnv.primaryRoot;
  }

  static Future<List<String>> run(
    BuildContext context, {
    String? saveDir,
    bool showResult = true,
  }) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dir = saveDir ?? defaultSaveDir();
    final String? raw;
    try {
      raw = await QrNative.scan();
    } on PlatformException {
      showSnackOn(messenger, strings.t('qrf.scan_unavailable'));
      return const [];
    }
    if (raw == null || !context.mounted) return const []; // vazgeçildi
    final payload = QrPayload.parse(raw);
    if (payload == null) {
      showSnackOn(messenger, strings.t('qrf.scan_unknown'));
      return const [];
    }
    final url = payload.url;
    if (url == null) {
      showSnackOn(messenger, strings.t('qrf.scan_wifi_only'));
      return const [];
    }
    var joined = false;
    try {
      if (payload.ssid != null) {
        joined = await QrNative.joinWifi(
            payload.ssid!, payload.pass ?? '', payload.sec);
        if (!joined) {
          showSnackOn(messenger, strings.t('qrf.join_failed'));
          return const [];
        }
      }
      final items = await QrReceiver.list(url);
      if (!context.mounted || items.isEmpty) return const [];
      // **Onay** — ne geleceği, ne kadar tuttuğu ve nereye yazılacağı.
      final ok = await confirm(context, items: items, saveDir: dir);
      if (!ok || !context.mounted) {
        showSnackOn(messenger, strings.t('qrr.declined'));
        return const [];
      }
      final total = items.fold<int>(0, (a, e) => a + e.size);
      var before = 0, lastName = '';
      final paths = await showFmProgress<List<String>>(
        context,
        title: strings.t('qrr.receiving'),
        name: strings.t('qrr.receiving'),
        task: (report, isCancelled) => QrReceiver.download(
          url,
          dir,
          listed: items,
          isCancelled: isCancelled,
          onProgress: (name, received, size) {
            // Bayt sayacı TÜM dosyalar boyunca birikir.
            if (name != lastName) {
              if (lastName.isNotEmpty) {
                before += items
                    .firstWhere((e) => e.name == lastName,
                        orElse: () => (name: lastName, size: 0))
                    .size;
              }
              lastName = name;
            }
            report(FmProgress(before + received, total, name));
          },
        ),
        describe: (v) => v.total <= 0
            ? ''
            : '${FsPaths.humanSize(v.done)} / ${FsPaths.humanSize(v.total)}',
      );
      if (paths.isNotEmpty) FsEvents.changed(paths);
      if (showResult && context.mounted && paths.isNotEmpty) {
        showSnack(
          context,
          strings.t('qrr.done_title', {'n': paths.length}),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: paths.length == 1
                ? strings.t('common.open')
                : strings.t('qrr.open_folder'),
            onPressed: () {
              if (!context.mounted) return;
              if (paths.length == 1) {
                EntryOpener.open(context, paths.first);
              } else {
                Navigator.of(context)
                    .push(browserRoute(BrowserScreen(path: dir)));
              }
            },
          ),
        );
      }
      return paths;
    } catch (e) {
      showSnackOn(messenger, userErrorText(e));
      return const [];
    } finally {
      if (joined) await QrNative.leaveWifi();
    }
  }

  static Widget _icon(String name) {
    final ext = p.extension(name).replaceFirst('.', '');
    final c = FsEntry.categoryForExtension(ext);
    final (icon, color) = FmColors.forExtension(ext.toLowerCase()) ??
        (FmColors.iconFor(c), FmColors.forCategory(c));
    return Icon(icon, color: color, size: 26);
  }

  /// "Dosyalar alınsın mı?" levhası: ilk birkaç dosya simgesi/boyutuyla,
  /// toplam ve hedef klasör. Vazgeç = hiçbir şey indirilmez.
  static Future<bool> confirm(
    BuildContext context, {
    required List<({String name, int size})> items,
    required String saveDir,
  }) async {
    final total = items.fold<int>(0, (a, e) => a + e.size);
    final shown = items.take(6).toList();
    final ok = await showAppSheet<bool>(
      context,
      title: context.t('qrr.confirm_title'),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding:
              const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: Gap.sm, bottom: Gap.sm),
                child: Text(
                  ctx.t('qrr.confirm_body', {
                    'n': items.length,
                    'size': FsPaths.humanSize(total),
                    'dir': p.basename(saveDir),
                  }),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              for (final item in shown)
                ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsetsDirectional.only(start: Gap.sm),
                  leading: _icon(item.name),
                  title: Text(item.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(FsPaths.humanSize(item.size),
                      style: theme.textTheme.bodySmall),
                ),
              if (items.length > shown.length)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                      start: Gap.sm, top: Gap.xs),
                  child: Text('+${items.length - shown.length}',
                      style: theme.textTheme.bodySmall),
                ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('qrr-cancel'),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(ctx.t('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('qrr-accept'),
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(AppIcons.download),
                      label: Text(ctx.t('qrr.accept')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return ok ?? false;
  }
}
