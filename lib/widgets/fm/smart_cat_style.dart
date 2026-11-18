import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/fm/smart_folder_prefs.dart';
import '../../services/fm/smart_user_cats.dart';

/// Akıllı düzen kategorisinin simgesi, rengi ve adı (tek yer).
abstract final class SmartCatStyle {
  /// Kullanıcı kategorisi simge anahtarı → simge ([SmartUserCats.icons]).
  static IconData userIcon(String key) => switch (key) {
        'star' => AppIcons.star,
        'bookmark' => AppIcons.bookmark,
        'tag' => AppIcons.tag,
        'home' => AppIcons.home,
        'child' => AppIcons.childCare,
        'work' => AppIcons.topicWork,
        'school' => AppIcons.topicEducation,
        'health' => AppIcons.topicHealth,
        'car' => AppIcons.topicVehicle,
        'travel' => AppIcons.topicTicket,
        'money' => AppIcons.topicBank,
        'receipt' => AppIcons.receiptLong,
        'music' => AppIcons.libraryMusic,
        'photo' => AppIcons.image,
        'idea' => AppIcons.lightbulbOutline,
        'build' => AppIcons.construction,
        'place' => AppIcons.place,
        'palette' => AppIcons.palette,
        'code' => AppIcons.code,
        _ => AppIcons.folder,
      };

  /// Kullanıcı kategorisi renk anahtarı → renk ([SmartUserCats.colors]).
  static Color userColor(String key) => switch (key) {
        'teal' => AppHues.teal,
        'green' => AppHues.green,
        'amber' => AppHues.amber,
        'orange' => AppHues.orange,
        'red' => AppHues.red,
        'pink' => AppHues.pink,
        'violet' => AppHues.violet,
        'indigo' => AppHues.indigo,
        'slate' => AppHues.slate,
        _ => AppHues.blue,
      };

  static IconData icon(String cat) {
    if (SmartUserCats.isUserId(cat)) {
      return userIcon(SmartUserCats.byId(cat)?.icon ?? '');
    }
    return _builtinIcon(cat);
  }

  static IconData _builtinIcon(String cat) => switch (cat) {
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
        'package' => AppIcons.archiveView,
        'audio' => AppIcons.audio,
        'video' => AppIcons.video,
        _ => AppIcons.typeAll,
      };

  static Color color(String cat) {
    if (SmartUserCats.isUserId(cat)) {
      return userColor(SmartUserCats.byId(cat)?.color ?? '');
    }
    return _builtinColor(cat);
  }

  static Color _builtinColor(String cat) => switch (cat) {
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
        'package' => AppHues.olive,
        'audio' => AppHues.purple,
        'video' => AppHues.red,
        _ => AppHues.plum,
      };

  /// Görünen ad: kullanıcının akıllı klasöre verdiği ad (2026-11-18), yoksa
  /// çeviri tablosundaki ad.
  /// Kullanıcı kategorisinde kendi adı (silinmişse "Kategorim").
  static String label(BuildContext context, String cat) =>
      SmartUserCats.isUserId(cat)
          ? (SmartUserCats.byId(cat)?.name ?? context.t('suc.section'))
          : (SmartFolderPrefs.nameOf(cat) ?? context.t('sm.c_$cat'));

  /// Çeviri tablosundaki (değiştirilmemiş) ad.
  static String defaultLabel(BuildContext context, String cat) =>
      context.t('sm.c_$cat');
}
