import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/fm/smart_folder_prefs.dart';

/// Akıllı düzen kategorisinin simgesi, rengi ve adı (tek yer).
abstract final class SmartCatStyle {
  static IconData icon(String cat) => switch (cat) {
        'invoice' => AppIcons.topicInvoice,
        'receipt' => AppIcons.receiptLong,
        'bank' => AppIcons.topicBank,
        'tax_salary' => AppIcons.topicTax,
        'contract' => AppIcons.topicContract,
        'official' => AppIcons.topicOfficial,
        'id' => AppIcons.badge,
        'health' => AppIcons.topicHealth,
        'insurance_vehicle' => AppIcons.topicVehicle,
        'travel' => AppIcons.topicTicket,
        'education' => AppIcons.topicEducation,
        'work' => AppIcons.topicWork,
        'manual' => AppIcons.menuBook,
        'reading' => AppIcons.kindBook,
        'note' => AppIcons.notes,
        'screenshot_chat' => AppIcons.chat,
        'screenshot' => AppIcons.screenshot,
        'greeting' => AppIcons.celebration,
        'meme' => AppIcons.emojiEmotions,
        'photo_people' => AppIcons.groups,
        'photo_other' => AppIcons.image,
        _ => AppIcons.typeAll,
      };

  static Color color(String cat) => switch (cat) {
        'invoice' || 'receipt' => AppHues.tangerine,
        'bank' || 'tax_salary' => AppHues.teal,
        'contract' || 'official' => AppHues.navy,
        'id' => AppHues.violet,
        'health' => AppHues.pink,
        'insurance_vehicle' => AppHues.olive,
        'travel' => AppHues.blue,
        'education' || 'reading' => AppHues.indigo,
        'work' || 'manual' => AppHues.cyan,
        'note' => AppHues.amber,
        'screenshot_chat' || 'screenshot' => AppHues.royal,
        'greeting' || 'meme' => AppHues.honey,
        'photo_people' || 'photo_other' => AppHues.leaf,
        _ => AppHues.plum,
      };

  /// Görünen ad: kullanıcının akıllı klasöre verdiği ad (2026-11-18), yoksa
  /// çeviri tablosundaki ad.
  static String label(BuildContext context, String cat) =>
      SmartFolderPrefs.nameOf(cat) ?? context.t('sm.c_$cat');

  /// Çeviri tablosundaki (değiştirilmemiş) ad.
  static String defaultLabel(BuildContext context, String cat) =>
      context.t('sm.c_$cat');
}
