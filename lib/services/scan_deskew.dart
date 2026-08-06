import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show compute;

import 'doc_edges.dart';
import 'perspective.dart';

/// Taranan sayfayı **kendiliğinden** düzeltme (2026-08-06 kullanıcı bulgusu:
/// *"sayfa eğimli tarandığında düzeltilmeli"* — ekran görüntüsünde ML Kit'ten
/// eğik çıkmış bir kitap sayfası vardı ve kullanıcı köşeleri elle ayarlamak
/// zorunda kalıyordu).
///
/// Önizleme ekranı açılırken her sayfa için kâğıt kenarları aranır
/// ([DocEdges]); dörtgen bulunursa VE uygulamaya değerse ([worthApplying])
/// sayfa [Perspective] ile düz dikdörtgene açılır. Elle "Köşeleri ayarla"
/// yolu aynen duruyor — otomatik düzeltme yalnız İLK hazırlıkta koşar, elle
/// yapılan ayarı asla ezmez.
abstract final class ScanDeskew {
  /// Bulunan dörtgen kendiliğinden uygulanmaya değer mi? Saf karar — birim
  /// testli. [corners] sol-üst, sağ-üst, sağ-alt, sol-alt; görsel piksel
  /// koordinatında.
  ///
  /// Kurallar (yanlış kırpma, kırpmamaktan KÖTÜdür — DocEdges ilkesi):
  /// * Dörtgen alanı görselin %45'inden az → kâğıt değil başka bir şey
  ///   bulunmuş olabilir (metin bloğu, masa deseni) → dokunma.
  /// * %98'den büyük → sayfa zaten düzgün kırpılmış → dokunma (yeniden
  ///   örnekleme kaliteyi sebepsiz düşürür).
  /// * Her köşe kendi görsel köşesine çok yakınsa (kenarın %2,5'i) → düzeltme
  ///   kayda değer bir şey değiştirmez → dokunma.
  static bool worthApplying(List<Offset> corners, double width, double height) {
    if (corners.length != 4 || width <= 0 || height <= 0) return false;
    final area = _quadArea(corners);
    final ratio = area / (width * height);
    if (ratio < 0.45 || ratio > 0.98) return false;
    final frame = <Offset>[
      Offset.zero,
      Offset(width, 0),
      Offset(width, height),
      Offset(0, height),
    ];
    final tolX = width * 0.025;
    final tolY = height * 0.025;
    var nearIdentity = true;
    for (var i = 0; i < 4; i++) {
      final d = corners[i] - frame[i];
      if (d.dx.abs() > tolX || d.dy.abs() > tolY) {
        nearIdentity = false;
        break;
      }
    }
    return !nearIdentity;
  }

  /// [imagePath] sayfasını gerekiyorsa düzeltip YENİ dosyanın yolunu döndürür;
  /// düzeltme gerekmiyorsa / kenar bulunamazsa null (kaynak dosyaya dokunulmaz).
  ///
  /// Kenar arama izolatta (Sobel+Hough ana izleği kilitler); perspektif
  /// açılımı `dart:ui` istediği için ana izlekte kalır.
  static Future<String?> autoStraighten(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final found = await compute(_detect, bytes);
    if (found == null) return null;
    final image = await decodeImageFile(imagePath);
    try {
      final corners = [
        for (final c in found)
          Offset(
            c.x.clamp(0.0, image.width.toDouble()),
            c.y.clamp(0.0, image.height.toDouble()),
          )
      ];
      if (!worthApplying(
          corners, image.width.toDouble(), image.height.toDouble())) {
        return null;
      }
      final png = await Perspective.warpToPng(image, corners);
      return writeTempPng(imagePath, 'duzeltildi', png);
    } finally {
      image.dispose();
    }
  }

  /// Gauss alan formülü (shoelace).
  static double _quadArea(List<Offset> c) {
    var sum = 0.0;
    for (var i = 0; i < c.length; i++) {
      final a = c[i];
      final b = c[(i + 1) % c.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2;
  }
}

/// İzolat giriş noktası — üst düzey fonksiyon olmalı (`compute` kuralı).
List<({double x, double y})>? _detect(Uint8List bytes) => DocEdges.detect(bytes);
