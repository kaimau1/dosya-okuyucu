import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/l10n/app_strings.dart';
import '../../../core/snack.dart';
import '../../../core/user_error.dart';
import '../../../services/fm/drive_service.dart';
import '../../../services/fm/entry_opener.dart';
import '../../../services/fm/file_ops.dart' show FmProgress;
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/remote/link_share.dart';
import '../../../services/fm/remote/peer_crypto.dart';
import '../../../services/fm/remote/transfer_history.dart';
import '../../../services/offline_mode.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/fm/fm_progress_dialog.dart';

/// "Bağlantıyla gönder"in alıcı yüzü: yapıştırılan / QR'dan okunan bağlantı
/// indirilir, telefonda çözülür, Geçmiş'e düşer ([LinkShare.receive]).
abstract final class LinkReceiveFlow {
  /// Hata → kullanıcı metni (Drive oturumu gerekiyorsa bunu açıkça söyler).
  static String errorText(Object e, AppStrings s) {
    if (e is OfflineException) return e.message;
    if (e is LinkFormatError) return s.t('link.need_drive');
    if (e is AeadFailure) return s.t('link.bad_key');
    if (e is DriveException) {
      return e.error == DriveError.notFound
          ? s.t('link.gone')
          : e.error == DriveError.notSignedIn
              ? s.t('link.need_signin')
              : s.t('link.drive_error');
    }
    return userErrorText(e);
  }

  /// Panodaki/yazılan metinden bağlantıyı sorar ve alır.
  static Future<String?> ask(BuildContext context, {required String saveDir}) async {
    final s = AppStrings.of(context);
    final text = await showAppPrompt(context,
        title: s.t('link.open'),
        label: s.t('link.open_hint'),
        confirmLabel: s.t('link.open_go'),
        multiline: true);
    if (text == null || !context.mounted) return null;
    final ticket = LinkTicket.parse(text);
    if (ticket == null) {
      showSnack(context, s.t('link.bad'));
      return null;
    }
    return run(context, ticket, saveDir: saveDir);
  }

  static Future<String?> run(BuildContext context, LinkTicket ticket,
      {required String saveDir}) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await showFmProgress<String>(
        context,
        title: s.t('link.receiving'),
        name: s.t('link.receiving'),
        cancellable: false,
        task: (report, _) => LinkShare.instance.receive(ticket, saveDir,
            onProgress: (done, total) =>
                report(FmProgress(done, total, s.t('link.receiving')))),
        describe: (v) => v.total <= 0
            ? FsPaths.humanSize(v.done)
            : '${FsPaths.humanSize(v.done)} / ${FsPaths.humanSize(v.total)}',
      );
      var size = 0;
      try {
        size = await File(path).length();
      } catch (_) {
        // Bilinçli: boyut yalnız bilgi.
      }
      await TransferHistory.instance.add([
        TransferRecord(
          incoming: true,
          path: path,
          name: p.basename(path),
          size: size,
          peer: s.t('link.peer'),
          at: DateTime.now(),
        ),
      ]);
      if (context.mounted) {
        showSnack(context, s.t('link.received', {'name': p.basename(path)}),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: s.t('common.open'),
              onPressed: () {
                if (context.mounted) EntryOpener.open(context, path);
              },
            ));
      }
      return path;
    } catch (e) {
      showSnackOn(messenger, errorText(e, s));
      return null;
    }
  }
}
