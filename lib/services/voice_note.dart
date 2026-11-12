import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'app_update.dart';

/// **Görüntüleyicide sesli not** (KALANLAR A10, yalnız kişisel derleme
/// `DOSYA_KISISEL=1`): dikte hemen başlar (cihaz tanıyıcısı, `ci/Dikte.kt`),
/// not dosya adı + sayfa + alıntı + dosyayı yeniden açan `file:` bağlantısıyla
/// Notlar'a gider. Notlar'ın "Dosyalar" klasörü konu satırıyla belirtilir
/// (`folder`). Gönderim standart paylaşım niyeti (ACTION_SEND): Notlar
/// tarafında ayrı bir köprü sözleşmesi kurulana dek kullanıcı paylaşım
/// sayfasında Notlar'ı seçer (HAFIZA 2026-11-12).
abstract final class VoiceNote {
  /// Notlar'daki hedef klasör adı (dosya sistemi değil, Notlar klasörü).
  static const folder = 'Dosyalar';

  static bool get enabled => debugEnabled ?? AppUpdate.personalBuild;

  @visibleForTesting
  static bool? debugEnabled;

  /// Testte paylaşım yerine.
  @visibleForTesting
  static Future<void> Function(String subject, String body)? debugSend;

  /// Notun gövdesi (saf; test edilir). Alıntı 280 karakterde kesilir.
  static String compose({
    required String spoken,
    required String path,
    int? page,
    String? quote,
  }) {
    final name = p.basename(path);
    final b = StringBuffer(spoken.trim());
    b.write('\n\n— $name');
    if (page != null && page > 0) b.write(' · s. $page');
    final q = quote?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (q.isNotEmpty) {
      final cut = q.length > 280 ? '${q.substring(0, 280)}…' : q;
      b.write('\n“$cut”');
    }
    b.write('\n${Uri.file(path)}');
    if (page != null && page > 0) b.write('#page=$page');
    return b.toString();
  }

  static Future<void> send(String body) async {
    final hook = debugSend;
    if (hook != null) return hook(folder, body);
    await SharePlus.instance.share(ShareParams(text: body, subject: folder));
  }
}
