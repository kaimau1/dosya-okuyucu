import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/fm/content_search.dart';
import '../../../widgets/app_dialog.dart';
import '../../qr_share_screen.dart';
import 'nearby_screen.dart';

/// "Paylaş" dendiğinde çıkan seçim: **Yakındakiler** mi, başka uygulama mı?
///
/// 2026-10-29: üç yol (yakındaki cihaz / QR / diğer uygulamalar) ikiye indi —
/// QR artık Yakındakiler ekranının içinde, uygulaması olmayan da oradan alır.
/// 2026-11-02 (HAFIZA 2026-11-02, eski A2.1): tek ve küçük bir **metin** dosyasında üçüncü
/// seçenek geri geldi — "Metni QR'da göster" ([QrShareScreen]): yazı QR'ın
/// kendisinde, ağ/sunucu yok (kullanıcı 2026-10-22'de istemişti).
/// `true` = iş burada bitti (ya da vazgeçildi); `false` = çağıran sistem
/// paylaşımını açsın.
Future<bool> showShareChoice(BuildContext context, List<String> paths) async {
  final textQr = paths.length == 1 && await isQrTextCandidate(paths.first);
  if (!context.mounted) return true;
  final choice = await showAppSheet<String>(
    context,
    title: context.t('common.share'),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: const ValueKey('share-nearby'),
          leading: const Icon(AppIcons.nearMe),
          title: Text(ctx.t('near.title')),
          subtitle: Text(ctx.t('near.share_sub')),
          onTap: () => Navigator.pop(ctx, 'near'),
        ),
        if (textQr)
          ListTile(
            key: const ValueKey('share-text-qr'),
            leading: const Icon(AppIcons.qr),
            title: Text(ctx.t('qr.text_choice')),
            subtitle: Text(ctx.t('qr.text_choice_sub')),
            onTap: () => Navigator.pop(ctx, 'qr'),
          ),
        ListTile(
          leading: const Icon(AppIcons.iosShare),
          title: Text(ctx.t('peer.other_apps_title')),
          subtitle: Text(ctx.t('peer.other_apps')),
          onTap: () => Navigator.pop(ctx, 'system'),
        ),
        const SizedBox(height: Gap.sm),
      ],
    ),
  );
  if (choice == null || !context.mounted) return true;
  if (choice == 'system') return false;
  if (choice == 'qr') {
    final text = await readQrText(paths.first);
    if (!context.mounted) return true;
    if (text == null || text.trim().isEmpty) return false; // okunamadı → sistem
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          QrShareScreen(title: p.basename(paths.first), text: text),
    ));
    return true;
  }
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => NearbyScreen(sendPaths: paths),
  ));
  return true;
}

/// QR'a metin olarak konabilecek en büyük dosya: ~8 kod
/// ([QrShareScreen.maxBytes] × 8). Daha uzunu sırayla okutmak eziyet;
/// onlar için Yakındakiler var.
const qrTextMaxBytes = QrShareScreen.maxBytes * 8;

/// Metin uzantılı, var olan ve [qrTextMaxBytes]'tan küçük dosya mı?
/// Seçim levhası açılmadan önce çağrılır; tek `stat`, içerik okunmaz.
Future<bool> isQrTextCandidate(String path) async {
  if (!ContentSearch.isSearchable(path)) return false;
  try {
    final st = await File(path).stat();
    return st.type == FileSystemEntityType.file &&
        st.size > 0 &&
        st.size <= qrTextMaxBytes;
  } on FileSystemException {
    return false; // yok / izin yok → seçenek gösterilmez
  }
}

/// Dosyayı UTF-8 okur (bozuk bayt `�` olur); okunamazsa `null`.
Future<String?> readQrText(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  } on FileSystemException {
    return null;
  }
}
