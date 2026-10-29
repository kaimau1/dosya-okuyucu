import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:path/path.dart' as p;

import '../../../core/l10n/app_strings.dart';
import '../../../core/snack.dart';
import '../../../core/user_error.dart';
import '../../../services/fm/entry_opener.dart';
import '../../../services/fm/file_ops.dart' show FmProgress;
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/fs_events.dart';
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/remote/qr_transfer.dart';
import '../../../services/fm/remote/transfer_history.dart';
import '../../../widgets/fm/fm_progress_dialog.dart';
import '../../../widgets/fm/transfer_offer_sheet.dart';
import '../browser_screen.dart';

/// **QR ile al** — tek akış: kodu tara → gelecek dosyaları GÖSTER ve onay
/// iste → indir (ilerleme penceresiyle) → "N dosya alındı · Aç".
///
/// Kullanıcı isteği (2026-10-28): *"QR'la al seçeneği yüzen buton olmalı"* ve
/// *"dosya almada onay olmalı en sonda"*. 2026-10-29: Yakındakiler'deki
/// Bluetooth daveti de AYNI akışa girer ([runPayload]); onay penceresi
/// küçük resimli ortak kabul ekranıdır ([showTransferOffer]); kopan indirme
/// kaldığı yerden sürer; alınanlar "Son alınanlar" geçmişine yazılır.
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
    final String? raw;
    try {
      raw = await QrNative.scan();
    } on PlatformException {
      showSnackOn(messenger, strings.t('qrf.scan_unavailable'));
      return const [];
    }
    if (raw == null || !context.mounted) return const []; // vazgeçildi
    return runPayload(context, raw,
        saveDir: saveDir, showResult: showResult, from: 'QR');
  }

  /// QR metni ya da Bluetooth davetindeki adresle alma. [preAccepted] =
  /// kullanıcı daveti zaten kabul etti (ikinci kez sorulmaz).
  static Future<List<String>> runPayload(
    BuildContext context,
    String raw, {
    String? saveDir,
    bool showResult = true,
    bool preAccepted = false,
    String from = 'QR',
  }) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dir = saveDir ?? defaultSaveDir();
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
      final total = items.fold<int>(0, (a, e) => a + e.size);
      // **Onay** — ne geleceği (küçük resimleriyle), ne kadar tuttuğu ve
      // nereye yazılacağı.
      if (!preAccepted) {
        final ok = await showTransferOffer(
          context,
          from: from,
          count: items.fold<int>(0, (a, e) => a + (e.files ?? 1)),
          totalBytes: total,
          saveDir: dir,
          items: [
            for (var i = 0; i < items.length; i++)
              OfferRow(
                name: items[i].name,
                size: items[i].size,
                folderFiles: items[i].files,
                thumbLater: items[i].thumb ? QrReceiver.thumb(url, i) : null,
              ),
          ],
        );
        if (!ok || !context.mounted) {
          showSnackOn(messenger, strings.t('qrr.declined'));
          return const [];
        }
      }
      var before = 0, lastName = '';
      var waiting = false;
      final paths = await showFmProgress<List<String>>(
        context,
        title: strings.t('qrr.receiving'),
        name: strings.t('qrr.receiving'),
        task: (report, isCancelled) => QrReceiver.download(
          url,
          dir,
          listed: items,
          isCancelled: isCancelled,
          onWaiting: (w) {
            waiting = w;
            if (w) report(FmProgress(before, total, strings.t('near.waiting')));
          },
          onProgress: (name, received, size) {
            // Bayt sayacı TÜM dosyalar boyunca birikir.
            if (name != lastName) {
              if (lastName.isNotEmpty) {
                before += items
                    .firstWhere((e) => e.name == lastName,
                        orElse: () => (name: lastName, size: 0, thumb: false, files: null))
                    .size;
              }
              lastName = name;
            }
            report(FmProgress(before + received, total,
                waiting ? strings.t('near.waiting') : name));
          },
        ),
        describe: (v) => v.total <= 0
            ? ''
            : '${FsPaths.humanSize(v.done)} / ${FsPaths.humanSize(v.total)}',
      );
      if (paths.isNotEmpty) {
        FsEvents.changed(paths);
        await TransferHistory.instance.add([
          for (final path in paths)
            TransferRecord(
              incoming: true,
              path: path,
              name: p.basename(path),
              size: _sizeOf(path),
              peer: from,
              at: DateTime.now(),
            ),
        ]);
      }
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
              if (paths.length == 1 && File(paths.first).existsSync()) {
                EntryOpener.open(context, paths.first);
              } else {
                Navigator.of(context).push(browserRoute(BrowserScreen(
                    path: paths.length == 1 ? paths.first : dir)));
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

  static int _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }
}
