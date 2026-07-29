import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import 'fm_env.dart';
import 'fs_scan.dart';

/// Bir günün depolama fotoğrafı.
class TrendPoint {
  /// Günün başlangıcı (epoch ms) — günde tek kayıt tutulur.
  final int dayMs;
  final int totalBytes;
  final Map<FmCategory, int> byCategory;

  const TrendPoint({
    required this.dayMs,
    required this.totalBytes,
    this.byCategory = const {},
  });

  Map<String, dynamic> toJson() => {
        'day': dayMs,
        'total': totalBytes,
        'cat': {for (final e in byCategory.entries) e.key.name: e.value},
      };

  static TrendPoint? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final day = (raw['day'] as num?)?.toInt();
    final total = (raw['total'] as num?)?.toInt();
    if (day == null || total == null) return null;
    final cat = <FmCategory, int>{};
    final map = raw['cat'];
    if (map is Map) {
      for (final entry in map.entries) {
        for (final c in FmCategory.values) {
          if (c.name == entry.key) {
            cat[c] = (entry.value as num?)?.toInt() ?? 0;
          }
        }
      }
    }
    return TrendPoint(dayMs: day, totalBytes: total, byCategory: cat);
  }
}

/// Bir dönemin değişimi.
class TrendDelta {
  /// Kaç günlük pencere (7 / 30).
  final int days;

  /// Toplam değişim (+ dolmuş, − boşalmış).
  final int deltaBytes;

  /// En çok büyüyen kategori ve büyümesi (yoksa null).
  final FmCategory? topCategory;
  final int topCategoryBytes;

  const TrendDelta({
    required this.days,
    required this.deltaBytes,
    this.topCategory,
    this.topCategoryBytes = 0,
  });

  bool get hasData => deltaBytes != 0 || topCategory != null;
}

/// **Depolama takibi** — "bu hafta 2 GB doldu, sebebi WhatsApp".
///
/// Günde bir fotoğraf kaydedilir (tarama zaten yapılıyor, ek maliyet yok) ve
/// aradaki fark gösterilir. Kayıt **düz bir JSON dosyasıdır**: SharedPreferences
/// listesi 90 günde şişer, veritabanı bu iş için fazla ağır.
abstract final class StorageTrend {
  static const _fileName = 'storage_trend.json';

  /// Kaç günlük geçmiş tutulur.
  static const maxPoints = 90;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// Bugünün kaydını ekler/günceller ve geçmişi döndürür.
  static Future<List<TrendPoint>> record(StorageIndex index,
      {DateTime? now}) async {
    if (FmEnv.appSupportDir.isEmpty) return const [];
    final points = await load();
    final today = _startOfDay(now ?? DateTime.now());
    final point = TrendPoint(
      dayMs: today,
      totalBytes: index.totalBytes,
      byCategory: {
        for (final e in index.stats.entries) e.key: e.value.bytes,
      },
    );
    final merged = mergePoint(points, point);
    try {
      await File(_path)
          .writeAsString(jsonEncode(merged.map((e) => e.toJson()).toList()));
    } catch (_) {
      // yazılamadıysa (izin/yer) takip sessizce devre dışı kalır
    }
    return merged;
  }

  static Future<List<TrendPoint>> load() async {
    if (FmEnv.appSupportDir.isEmpty) return const [];
    try {
      final file = File(_path);
      if (!file.existsSync()) return const [];
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (TrendPoint.fromJson(item) case final point?) point,
      ]..sort((a, b) => a.dayMs.compareTo(b.dayMs));
    } catch (_) {
      return const [];
    }
  }

  static int _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
}

/// Aynı günün ikinci kaydı **üzerine yazar** (gün başına tek nokta) ve
/// geçmişi [StorageTrend.maxPoints] ile sınırlar. Saf → test edilebilir.
List<TrendPoint> mergePoint(List<TrendPoint> points, TrendPoint fresh) {
  final out = [
    for (final p in points)
      if (p.dayMs != fresh.dayMs) p,
    fresh,
  ]..sort((a, b) => a.dayMs.compareTo(b.dayMs));
  if (out.length <= StorageTrend.maxPoints) return out;
  return out.sublist(out.length - StorageTrend.maxPoints);
}

/// Son [days] günün değişimi. Yeterli geçmiş yoksa **en eski** kayıt taban
/// alınır (uygulama yeni kurulduysa da bir şey gösterilebilsin), tek kayıt
/// varsa değişim yok sayılır.
TrendDelta computeTrend(List<TrendPoint> points, {int days = 7, DateTime? now}) {
  if (points.length < 2) return TrendDelta(days: days, deltaBytes: 0);
  final today = now ?? DateTime.now();
  final threshold = DateTime(today.year, today.month, today.day)
      .subtract(Duration(days: days))
      .millisecondsSinceEpoch;

  final latest = points.last;
  // Eşiğe eşit ya da ondan eski EN YENİ kayıt; yoksa en eski kayıt.
  TrendPoint base = points.first;
  for (final point in points) {
    if (point.dayMs <= threshold) base = point;
  }
  if (identical(base, latest)) return TrendDelta(days: days, deltaBytes: 0);

  FmCategory? top;
  var topDelta = 0;
  for (final category in FmCategory.values) {
    final delta =
        (latest.byCategory[category] ?? 0) - (base.byCategory[category] ?? 0);
    if (delta > topDelta) {
      top = category;
      topDelta = delta;
    }
  }

  return TrendDelta(
    days: days,
    deltaBytes: latest.totalBytes - base.totalBytes,
    topCategory: top,
    topCategoryBytes: topDelta,
  );
}
