/// Google Fotoğraflar tarzı zaman gruplaması (gün / ay / yıl).
///
/// Saf Dart: başlık metni ve grup anahtarı birim testiyle sabitlenir — "bugün /
/// dün" gibi göreli başlıkların yanlış güne kayması sessizce fark edilmesin.
library;

import 'file_age.dart';

enum PhotoGroup { day, month, year }

extension PhotoGroupLabel on PhotoGroup {
  /// Çeviri anahtarı (bkz. `FmLayoutInfo.labelKey`).
  String get labelKey => switch (this) {
        PhotoGroup.day => 'enum.photo_group_day',
        PhotoGroup.month => 'enum.photo_group_month',
        PhotoGroup.year => 'enum.photo_group_year',
      };

  String get label => switch (this) {
        PhotoGroup.day => 'Gün',
        PhotoGroup.month => 'Ay',
        PhotoGroup.year => 'Yıl',
      };

  static PhotoGroup byName(String? name) {
    for (final g in PhotoGroup.values) {
      if (g.name == name) return g;
    }
    return PhotoGroup.day;
  }
}

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const _weekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

/// Aynı gruba düşen öğelerin ortak anahtarı ("2026-07-25" / "2026-07" / "2026").
///
/// Sıralanabilir olması bilinçli: anahtar üzerinde string karşılaştırması
/// zaman sırasıyla aynı sonucu verir.
String photoGroupKey(int millis, PhotoGroup group) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int n) => n.toString().padLeft(2, '0');
  return switch (group) {
    PhotoGroup.day => '${d.year}-${two(d.month)}-${two(d.day)}',
    PhotoGroup.month => '${d.year}-${two(d.month)}',
    PhotoGroup.year => '${d.year}',
  };
}

/// Grup başlığı. Gün gruplamasında bugün/dün ve "bu yıl" kısaltmaları
/// kullanılır (Google Fotoğraflar davranışı); [now] test için verilebilir.
String photoGroupTitle(int millis, PhotoGroup group, {DateTime? now}) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final today = now ?? DateTime.now();
  switch (group) {
    case PhotoGroup.year:
      return '${d.year}';
    case PhotoGroup.month:
      return d.year == today.year
          ? _months[d.month - 1]
          : '${_months[d.month - 1]} ${d.year}';
    case PhotoGroup.day:
      // Gün farkı TEK yerden (bkz. `calendarDaysBetween`): yaz saati
      // geçişinde `.difference().inDays` 0 yerine -1/1 verebiliyordu.
      final days = calendarDaysBetween(d, today);
      if (days == 0) return 'Bugün';
      if (days == 1) return 'Dün';
      final base = d.year == today.year
          ? '${d.day} ${_months[d.month - 1]}'
          : '${d.day} ${_months[d.month - 1]} ${d.year}';
      // Son bir hafta içindeyse gün adı da yazılır ("23 Temmuz Perşembe").
      return days < 7 ? '$base ${_weekdays[d.weekday - 1]}' : base;
  }
}
