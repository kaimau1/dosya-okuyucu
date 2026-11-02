import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// **Bozuk görseli açmayı dener** — görüntüleyici "açılamadı" demeden önce.
///
/// Kullanıcı isteği 2026-11-02: *"bozuk görselleri açabilme"*. Sahada en çok
/// görülen üç bozulma:
/// 1. **Başında çöp** — kurtarma araçlarının, bazı mesajlaşma yedeklerinin ya
///    da yarım kalmış kopyaların ürettiği; asıl JPEG/PNG imzası birkaç bayt
///    ileride başlıyor ve çözücü ilk baytta vazgeçiyor.
/// 2. **Yarım inmiş JPEG** — dosya sonu (EOI) yok. Sonu eklenince libjpeg
///    eldeki satırları çözüyor, kalanı gri kalıyor.
/// 3. **Platformun reddettiği ama okunabilen** dosya (ör. CRC'si bozuk PNG
///    öbeği) — saf Dart `image` paketi daha hoşgörülü; çözülürse JPEG'e
///    yeniden kodlanıp gösteriliyor.
///
/// Dosyanın kendisine DOKUNULMAZ; kurtarılan bayt yalnız ekranda.
abstract final class ImageRepair {
  static Future<Uint8List?> repairFile(String path) =>
      compute(_repairPath, path);

  static Uint8List? _repairPath(String path) {
    try {
      return repair(File(path).readAsBytesSync());
    } catch (_) {
      // okunamayan dosya: kurtarılacak bir şey yok
      return null;
    }
  }

  static const _jpeg = [0xFF, 0xD8, 0xFF];
  static const _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  /// Kurtarılmış görsel baytları; hiçbir yol tutmazsa `null`.
  static Uint8List? repair(Uint8List bytes) {
    // ponytail: imza ilk 64 KB'ta aranıyor; daha derindeki gömülü görseller
    // (ör. bir arşivin ortası) kapsam dışı.
    final jpegAt = _find(bytes, _jpeg, 65536);
    final pngAt = _find(bytes, _png, 65536);
    var data = bytes;
    if (jpegAt >= 0 && (pngAt < 0 || jpegAt <= pngAt)) {
      data = Uint8List.sublistView(bytes, jpegAt);
      final n = data.length;
      if (n < 2 || data[n - 2] != 0xFF || data[n - 1] != 0xD9) {
        data = Uint8List.fromList([...data, 0xFF, 0xD9]);
      }
    } else if (pngAt >= 0) {
      data = Uint8List.sublistView(bytes, pngAt);
    }
    try {
      final decoded = img.decodeImage(data);
      if (decoded != null) return img.encodeJpg(decoded, quality: 92);
    } catch (_) {
      // saf Dart çözücü de vazgeçti; aşağıda ham kırpılmış bayt deneniyor
    }
    // Paket çözemese de platform çözücüsü (libjpeg) yarım JPEG'i çizebilir.
    return identical(data, bytes) ? null : data;
  }

  static int _find(Uint8List b, List<int> sig, int limit) {
    final end = (b.length < limit ? b.length : limit) - sig.length;
    outer:
    for (var i = 0; i <= end; i++) {
      for (var j = 0; j < sig.length; j++) {
        if (b[i + j] != sig[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}
