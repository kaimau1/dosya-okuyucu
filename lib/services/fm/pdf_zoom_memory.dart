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
///
/// **Kenar boşluğu kırpma** da belge başına burada (Ferrari H3.4): yol →
/// kesilen paylar `[sol, üst, sağ, alt]` (`pdf_crop_v1`); kayıt yoksa kapalı.
/// Paylar saklandığı için yeniden açılışta tarama yok, düzen ilk karede
/// kırpılmış kurulur (sonradan değişip sayfa atlatmaz).
abstract final class PdfZoomMemory {
  static const _key = 'pdf_zoom_v1';
  static const _cropKey = 'pdf_crop_v1';
  static const _cap = 300;

  static final Map<String, double> _zoom = {};
  static final Map<String, List<double>> _crop = {};
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cropKey);
      if (raw != null) {
        final map = jsonDecode(raw);
        if (map is Map) {
          for (final e in map.entries) {
            final v = e.value;
            if (e.key is String &&
                v is List &&
                v.length == 4 &&
                v.every((x) => x is num)) {
              _crop[e.key as String] = [
                for (final x in v) (x as num).toDouble(),
              ];
            }
          }
        }
      }
    } catch (_) {
      // Bilinçli: bozuk kırpma kaydı — belge kırpılmadan açılır.
    }
    _loaded = true;
  }

  /// Belgenin kırpma payları (yoksa null = kırpma kapalı).
  static List<double>? cropOf(String path) => _crop[path];

  /// Kırpma paylarını saklar; null kırpmayı kapatır.
  static Future<void> recordCrop(String path, List<double>? box) async {
    _crop.remove(path);
    if (box != null) _crop[path] = List<double>.of(box);
    while (_crop.length > _cap) {
      _crop.remove(_crop.keys.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cropKey, jsonEncode(_crop));
    } catch (_) {
      // Bilinçli: yazılamadı — bellekteki tercih bu oturumda geçerli.
    }
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
    _crop.clear();
    _loaded = false;
    _loading = null;
  }
}
