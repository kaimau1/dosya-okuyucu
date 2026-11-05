import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../services/fm/app_storage_service.dart';
import '../../services/fm/saf_write.dart';

/// SD karta yazma izni (SAF ağaç izni) iste — Faz 41 / 1 (A7.2).
///
/// Sistem klasör seçicisi kartın kökünde açılır; kullanıcı "Bu klasörü
/// kullan"a basınca kalıcı izin alınır ve yazılabilirlik önbelleği
/// tazelenir. İzin alındıysa true.
Future<bool> requestSafGrant(BuildContext context, String path) async {
  final volume = SafWrite.splitVolumePath(path)?.$1;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final strings = AppStrings.of(context);
  final uri = await AppStorageService.safPickTree(volume: volume);
  SafWrite.resetForTest();
  final ok = uri != null && uri.isNotEmpty;
  if (messenger != null) {
    showSnackOn(messenger,
        strings.t(ok ? 'saf.granted' : 'saf.not_granted'));
  }
  return ok;
}

/// "SD karta yazmak için izin gerekli · İzin ver" bildirimi.
void showSafGrantSnack(BuildContext context, String path) {
  showSnack(
    context,
    context.t('saf.needs_grant'),
    action: SnackBarAction(
      label: context.t('saf.grant'),
      onPressed: () => requestSafGrant(context, path),
    ),
  );
}
