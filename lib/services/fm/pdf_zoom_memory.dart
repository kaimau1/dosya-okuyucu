import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **PDF yakınlığı hatırlanır** (2026-11-13, kullanıcı: *"tablette PDF
/// açtığımda çok zoomlu görülüyor, daha zoom out görülmeli ve zoom in zoom
/// outum hatırlanmıyor"*).
///
/// Belge başına son yakınlık (yol → ölçek). Kayıt yoksa görüntüleyici
/// geniş ekranda (tablet) sayfanın TAMAMINI sığdırır, telefonda eski
/// davranış (genişliğe sığdır). Son [_cap] belge tutulur, en eskisi düşer.
abstract final class PdfZoomMemory {
  static const _key = 'pdf_zoom_v1';
  static const _cap = 300;

  static final Map<String, double> _zoom = {};
  static bool _loaded = false;
  static Future<void>? _loading;

  static bool get isLoaded => _loaded;

  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final map = jsonDecode(raw);
        if (map is Map) {
          for (final e in map.entries) {
            final v = e.value;
            if (e.key is String && v is num && v > 0) {
              _zoom[e.key as String] = v.toDouble();
            }
          }
        }
      }
    } catch (_) {
      // Bilinçli: bozuk/okunamayan kayıt — varsayılan yakınlıkla açılır.
    }
    _loaded = true;
  }

  static double? of(String path) => _zoom[path];

  /// Yakınlığı kaydeder (yazma gecikmesiz ama ucuz: tek dize).
  static Future<void> record(String path, double zoom) async {
    if (!zoom.isFinite || zoom <= 0) return;
    final old = _zoom[path];
    if (old != null && (old - zoom).abs() < 0.005) return;
    _zoom.remove(path); // sona taşı (en yeni)
    _zoom[path] = zoom;
    while (_zoom.length > _cap) {
      _zoom.remove(_zoom.keys.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_zoom));
    } catch (_) {
      // Bilinçli: yazılamadı — bellekteki değer bu oturumda geçerli.
    }
  }

  /// Görüntüleyicinin açılış yakınlığı: kayıt > geniş ekranda sayfayı
  /// sığdır ([fitZoom]) > null (pdfrx varsayılanı).
  static double? initialZoom(String path,
      {required double shortestSide, required double fitZoom}) {
    final saved = of(path);
    if (saved != null) return saved;
    if (shortestSide >= 600) return fitZoom;
    return null;
  }

  @visibleForTesting
  static void debugReset() {
    _zoom.clear();
    _loaded = false;
    _loading = null;
  }
}
