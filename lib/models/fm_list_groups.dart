/// Dosya listelerinin **gruplanması** ve **tür süzgeci** (Faz 6).
///
/// Saf Dart: "Bugün / Bu hafta / Bu ay / Daha eski" sınırlarının gün
/// başlangıcına oturması ve türe göre sıralı listede başlıkların sırası
/// birim testiyle sabitlensin diye.
library;

import 'fs_entry.dart';

/// Tarih grubunun anahtarı (çeviri: `grp.<ad>`).
enum FmDateGroup { today, week, month, older }

extension FmDateGroupKey on FmDateGroup {
  String get labelKey => 'grp.$name';
}

/// [ms] zamanının hangi tarih grubunda olduğu. Sınırlar YEREL gün
/// başlangıcıdır: dün 23:59 "Bugün" değildir.
FmDateGroup dateGroupOf(int ms, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  if (!t.isBefore(today)) return FmDateGroup.today;
  if (!t.isBefore(today.subtract(const Duration(days: 6)))) {
    return FmDateGroup.week;
  }
  if (!t.isBefore(today.subtract(const Duration(days: 29)))) {
    return FmDateGroup.month;
  }
  return FmDateGroup.older;
}

/// Listede bir satır: ya başlık ya öğe. Öğe [index]i SIRALI listedeki
/// yeridir — sürükleyerek seçim ve "yukarısını seç" bu indeksle çalışır,
/// başlıklar indeks almaz.
sealed class FmListItem {
  const FmListItem();
}

final class FmHeaderItem extends FmListItem {
  /// Çeviri anahtarı (`grp.today`, `enum.cat_image` …).
  final String labelKey;
  final int count;
  const FmHeaderItem(this.labelKey, this.count);
}

final class FmEntryItem extends FmListItem {
  final FsEntry entry;
  final int index;
  const FmEntryItem(this.entry, this.index);
}

/// Sıralı [entries] için başlıklı satır listesi.
///
/// * Tarihe göre → tarih grupları (klasörler de tarihleriyle gruplanır).
/// * Türe göre → tür başlıkları ([FmCategory] sırasıyla değil, listede
///   görünüş sırasıyla — sıralama zaten türü gruplamıştır).
/// * Ada/boyuta göre → başlık yok (ada göre hızlı kaydırıcı harf gösterir).
///
/// Tek grup çıkıyorsa başlık eklenmez: "Daha eski" diye tek bir başlık bilgi
/// taşımaz, yalnız yer kaplar.
List<FmListItem> groupEntries(
  List<FsEntry> entries,
  FmSort sort, {
  required DateTime now,
}) {
  String? keyOf(FsEntry e) => switch (sort) {
        FmSort.date => dateGroupOf(e.modifiedMs, now).labelKey,
        FmSort.type => e.category.labelKey,
        _ => null,
      };
  final plain = [
    for (var i = 0; i < entries.length; i++) FmEntryItem(entries[i], i),
  ];
  if (sort != FmSort.date && sort != FmSort.type) return plain;

  final counts = <String, int>{};
  for (final e in entries) {
    final k = keyOf(e)!;
    counts[k] = (counts[k] ?? 0) + 1;
  }
  if (counts.length < 2) return plain;

  final out = <FmListItem>[];
  String? last;
  for (var i = 0; i < entries.length; i++) {
    final k = keyOf(entries[i])!;
    if (k != last) {
      out.add(FmHeaderItem(k, counts[k]!));
      last = k;
    }
    out.add(FmEntryItem(entries[i], i));
  }
  return out;
}

/// Gezgin tür süzgeci: `null` = tümü.
bool matchesCategory(FsEntry e, FmCategory? category) =>
    category == null || e.category == category;

/// Listede GERÇEKTEN bulunan türler (çip satırı yalnız bunları çizer —
/// boş çipe dokunup "hiçbir şey yok" görmek süzgeci bozuk sandırır).
Map<FmCategory, int> categoryCounts(List<FsEntry> entries) {
  final out = <FmCategory, int>{};
  for (final e in entries) {
    out[e.category] = (out[e.category] ?? 0) + 1;
  }
  return out;
}
