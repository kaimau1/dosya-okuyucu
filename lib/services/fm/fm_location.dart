import 'package:path/path.dart' as p;

import '../../models/media_bucket.dart';
import 'fs_scan.dart';
import 'storage_stats.dart';

/// Dosya listelerinde **"nerede?"** sorusunun kısa cevabı.
///
/// 2026-09-23 tasarım turu (kullanıcı ekran görüntüsü, Belgeler listesi):
/// her satırın alt yazısı `/storage/emulated/0/Android/media/co…` idi — yolun
/// ekrana sığan kısmı hep aynı ve hiçbir şey söylemiyordu. İnsanın bildiği
/// ad kaynaktır: "WhatsApp", "İndirilenler", "Kamera"; bilinmeyen yerde de
/// dosyanın durduğu klasörün adı ("Documents").
///
/// Saf Dart (yalnız yola bakar) → testle sabitlenir.
abstract final class FmLocation {
  /// [t] çeviri işlevi (genelde `context.t`), [volumes] bağlı birimler
  /// (genelde `FmEnv.volumes`).
  static String label(
    String path,
    String Function(String) t, {
    List<StorageVolume> volumes = const [],
  }) {
    final bucket = bucketForPath(path);
    if (bucket != MediaBucket.other) return t(bucket.labelKey);
    final dir = p.normalize(p.dirname(path));
    for (final v in volumes) {
      final root = p.normalize(v.path);
      if (p.equals(root, dir)) return v.displayLabel(t);
    }
    final name = p.basename(dir);
    return name.isEmpty ? dir : name;
  }

  /// Kısa tarih: bu yılsa "18 Eyl", değilse "18 Eyl 2025". Listelerde saat
  /// gereksiz uzunluk — ayrıntısı Özellikler'de.
  static String shortDate(int ms, {DateTime? now}) {
    if (ms <= 0) return '';
    final full = FsPaths.humanDate(ms); // "18 Eyl 2026 13:15"
    final parts = full.split(' ');
    if (parts.length < 3) return full;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final year = (now ?? DateTime.now()).year;
    return d.year == year
        ? '${parts[0]} ${parts[1]}'
        : '${parts[0]} ${parts[1]} ${parts[2]}';
  }

  /// Liste satırının alt yazısı: "115 KB · WhatsApp · 18 Eyl".
  static String subtitle(
    String path,
    int sizeBytes,
    int modifiedMs,
    String Function(String) t, {
    List<StorageVolume> volumes = const [],
  }) {
    final date = shortDate(modifiedMs);
    return [
      FsPaths.humanSize(sizeBytes),
      label(path, t, volumes: volumes),
      if (date.isNotEmpty) date,
    ].join(' · ');
  }
}
