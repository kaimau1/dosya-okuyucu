/// Dosya yaşı / dokunulmama süresi — "gereksizleri kolay silmek" için
/// listelerde renkli rozet olarak gösterilir. Saf Dart, birim testli.
library;

enum AgeLevel {
  /// Son 7 gün.
  fresh,

  /// 7–30 gün.
  recent,

  /// 30–180 gün.
  old,

  /// 180 günden eski — silme adayı.
  ancient,

  /// Tarih bilinmiyor.
  unknown,
}

extension AgeLevelLabel on AgeLevel {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        AgeLevel.fresh => 'enum.age_fresh',
        AgeLevel.recent => 'enum.age_recent',
        AgeLevel.old => 'enum.age_old',
        AgeLevel.ancient => 'enum.age_ancient',
        AgeLevel.unknown => 'enum.age_unknown',
      };

  String get label => switch (this) {
        AgeLevel.fresh => 'yeni',
        AgeLevel.recent => 'bu ay',
        AgeLevel.old => 'eski',
        AgeLevel.ancient => 'çok eski',
        AgeLevel.unknown => 'bilinmiyor',
      };
}

/// Gün cinsinden yaştan seviye. Negatif/boş değerler `unknown`.
AgeLevel ageLevelFor(int? days) {
  if (days == null || days < 0) return AgeLevel.unknown;
  if (days < 7) return AgeLevel.fresh;
  if (days < 30) return AgeLevel.recent;
  if (days < 180) return AgeLevel.old;
  return AgeLevel.ancient;
}

/// İki zaman damgası arasındaki gün farkı (ms). Geçersizse null.
int? daysBetween(int fromMs, int toMs) {
  if (fromMs <= 0 || toMs <= 0 || toMs < fromMs) return null;
  return ((toMs - fromMs) / 86400000).floor();
}

/// "3 gün önce" / "2 ay önce" gibi kısa Türkçe ifade.
String relativeDays(int? days) {
  if (days == null) return '—';
  if (days <= 0) return 'bugün';
  if (days == 1) return 'dün';
  if (days < 30) return '$days gün önce';
  if (days < 365) return '${(days / 30).floor()} ay önce';
  return '${(days / 365).floor()} yıl önce';
}
