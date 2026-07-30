/// Medyanın **kaynağı**: kamera mı, WhatsApp'tan mı geldi, ekran görüntüsü mü…
///
/// Saf Dart, yalnızca yola bakar (dosya açılmaz) — binlerce görselde anında
/// gruplama yapılabilsin diye. Sınıflandırma kuralları Android'de fiilen
/// kullanılan klasör düzenlerine göredir; testlerle sabitlenmiştir.
library;

enum MediaBucket {
  camera,
  screenshot,
  whatsapp,
  telegram,
  instagram,
  download,
  bluetooth,
  other,
}

extension MediaBucketLabel on MediaBucket {
  /// Çeviri anahtarı. Uygulama adları (WhatsApp…) her dilde aynı yazılır ama
  /// anahtar üzerinden geçmeleri tabloyu tek yerde tutar.
  String get labelKey => switch (this) {
        MediaBucket.camera => 'enum.bucket_camera',
        MediaBucket.screenshot => 'enum.bucket_screenshot',
        MediaBucket.whatsapp => 'enum.bucket_whatsapp',
        MediaBucket.telegram => 'enum.bucket_telegram',
        MediaBucket.instagram => 'enum.bucket_instagram',
        MediaBucket.download => 'enum.bucket_download',
        MediaBucket.bluetooth => 'enum.bucket_bluetooth',
        MediaBucket.other => 'enum.bucket_other',
      };

  String get label => switch (this) {
        MediaBucket.camera => 'Kamera',
        MediaBucket.screenshot => 'Ekran görüntüsü',
        MediaBucket.whatsapp => 'WhatsApp',
        MediaBucket.telegram => 'Telegram',
        MediaBucket.instagram => 'Instagram',
        MediaBucket.download => 'İndirilenler',
        MediaBucket.bluetooth => 'Bluetooth',
        MediaBucket.other => 'Diğer',
      };
}

/// Dosya yolundan (ve gerekirse adından) kaynağı bulur.
///
/// Sıra önemlidir: "ekran görüntüsü" klasörü DCIM altında da olabilir, bu
/// yüzden kameradan ÖNCE bakılır. WhatsApp/Telegram modern Android'de
/// `Android/media/com.whatsapp/...` altına yazar — paket adı da eşleşir.
MediaBucket bucketForPath(String path) {
  final lower = path.toLowerCase();

  bool has(String needle) => lower.contains(needle);

  if (has('screenshot') || has('ekran görüntü') || has('screen_shot')) {
    return MediaBucket.screenshot;
  }
  if (has('whatsapp') || has('com.whatsapp')) return MediaBucket.whatsapp;
  if (has('telegram') || has('org.telegram')) return MediaBucket.telegram;
  if (has('instagram') || has('com.instagram')) return MediaBucket.instagram;
  if (has('/bluetooth')) return MediaBucket.bluetooth;
  if (has('/dcim/')) return MediaBucket.camera;
  if (has('/download/') || has('/downloads/')) return MediaBucket.download;
  return MediaBucket.other;
}

/// Bir liste için kaynak sayıları (filtre çiplerinde rozet olarak gösterilir).
Map<MediaBucket, int> bucketCounts(Iterable<String> paths) {
  final counts = <MediaBucket, int>{};
  for (final path in paths) {
    final bucket = bucketForPath(path);
    counts[bucket] = (counts[bucket] ?? 0) + 1;
  }
  return counts;
}
