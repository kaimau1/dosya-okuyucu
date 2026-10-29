import 'dart:io';

import 'package:path/path.dart' as p;

import '../image_resize.dart';
import '../thumbnail_cache.dart';

/// Aktarım önizlemesi için küçük JPEG (kabul penceresi + web sayfası).
/// Görsel ve videoda üretilir, diğer türlerde null.
abstract final class TransferThumbs {
  static const _images = {
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif',
  };
  static const _videos = {'.mp4', '.mkv', '.mov', '.webm', '.3gp', '.avi'};

  static Future<List<int>?> of(String path) async {
    final ext = p.extension(path).toLowerCase();
    try {
      if (_images.contains(ext)) {
        return await ImageResizer.previewJpeg(path, maxEdge: 200);
      }
      if (_videos.contains(ext)) {
        final thumb = await ThumbnailCache.forVideo(path, size: 200);
        return thumb == null ? null : await File(thumb).readAsBytes();
      }
    } catch (_) {}
    return null;
  }
}
