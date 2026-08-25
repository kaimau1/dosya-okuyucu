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

/// İki zaman damgası arasındaki gün farkı. Geçersizse null.
///
/// **TAKVİM günü, 24 saatlik dilim DEĞİL** (kullanıcı hatası 2026-08-25:
/// *"bugün dün kısmı 24 saate göre yapılıyor, gece 00'a göre olmalı"*).
///
/// Eski hesap `(toMs - fromMs) / 86400000` idi: bu, "kaç kez 24 saat geçti"
/// sorusunun cevabı. İnsanın sorduğu soru bu değil — dün akşam 23:00'te
/// indirilen dosya bu sabah 08:00'de "bugün" yazıyordu (arada 9 saat var),
/// oysa kullanıcı için gece yarısı geçilmişti ve o dosya **dün**dü. Aynı
/// hata ters yönde de vardı: bu sabah 01:00'de çekilen fotoğraf akşam
/// 23:00'te hâlâ "bugün"dü ama dün sabah 09:00'da çekilen "1 gün önce"
/// yerine yine "bugün" görünebiliyordu.
///
/// Doğrusu iki damganın **gün başlarını** (00:00) çıkarmak. Yaz saati
/// geçişlerinde gün 23 ya da 25 saat sürer; `DateTime`in kendi gün
/// aritmetiği bunu doğru sayar, elle bölme saymaz.
int? daysBetween(int fromMs, int toMs) {
  if (fromMs <= 0 || toMs <= 0 || toMs < fromMs) return null;
  return calendarDaysBetween(
    DateTime.fromMillisecondsSinceEpoch(fromMs),
    DateTime.fromMillisecondsSinceEpoch(toMs),
  );
}

/// İki tarih arasında kaç kez **gece yarısı** geçildi.
///
/// Tek doğruluk kaynağı: "bugün / dün" yazan her yer bunu kullanır
/// ([daysBetween], fotoğraf grup başlıkları, uygulama kullanım yaşı).
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  // Yaz saatinde gün 23/25 saat sürebilir; `inDays` taban aldığı için
  // öğlene çekip farkı almak bu kaymayı yutar.
  return b
      .add(const Duration(hours: 12))
      .difference(a.add(const Duration(hours: 12)))
      .inDays;
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
