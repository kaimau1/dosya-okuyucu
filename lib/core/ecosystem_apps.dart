import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Kardeş uygulama **Notlar** ile iki yönlü paylaşım, belge aktarımı ve
/// zorlamasız ekosistem tanıtımı.
abstract final class EcosystemApps {
  static const String notlarPackage = 'dev.kaimau.notlar';
  static final Uri notlarMarketUri = Uri.parse(
    'market://details?id=$notlarPackage',
  );
  static final Uri notlarPlayUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=$notlarPackage',
  );

  static const String promoHiddenUntilKey = 'notlar_promo_hidden_until';
  static const Duration promoHideDuration = Duration(days: 30);

  static bool shouldShowPromo(SharedPreferences prefs, {DateTime? now}) {
    final until = prefs.getInt(promoHiddenUntilKey) ?? 0;
    return (now ?? DateTime.now()).millisecondsSinceEpoch >= until;
  }

  static Future<void> dismissPromo(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final next = (now ?? DateTime.now()).add(promoHideDuration);
    await prefs.setInt(promoHiddenUntilKey, next.millisecondsSinceEpoch);
  }

  static Future<bool> openNotlarStore() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        if (await launchUrl(
          notlarMarketUri,
          mode: LaunchMode.externalApplication,
        )) {
          return true;
        }
      } catch (_) {
        // Play yüklü değilse web bağlantısına düş.
      }
    }
    return launchUrl(notlarPlayUri, mode: LaunchMode.externalApplication);
  }

  static Future<void> handoffToNotlar({
    String? filePath,
    String? text,
    String? subject,
  }) async {
    if (filePath != null &&
        filePath.isNotEmpty &&
        File(filePath).existsSync()) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(filePath)], text: text, subject: subject),
      );
      return;
    }
    if (text != null && text.trim().isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(text: text.trim(), subject: subject),
      );
      return;
    }
    await openNotlarStore();
  }
}
