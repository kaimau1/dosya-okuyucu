import 'dart:io';
import 'dart:typed_data';

/// **Uzantısız dosya görsel mi?** — imza (magic byte) baytlarına bakar.
///
/// Kullanıcı 2026-08-17 (*"burada görselleri göremiyorum"*): "Birebir kopyalar"
/// ekranında WhatsApp önbelleğinden gelen dosyalar
/// (`0dc1773b99bd9094f44c5c713c66b30f` — nokta yok, uzantı yok) düz kahverengi
/// bir dosya glifiyle görünüyordu. Yan yana duran `.jpg` kopyaları küçük
/// resimliydi; yani aynı fotoğrafın iki kopyasından biri görünüyor, öteki
/// görünmüyordu ve kullanıcı hangisini sileceğini göremiyordu.
///
/// Kök neden: [FsEntry.category] **yalnız uzantıya** bakıyor; uzantısı olmayan
/// dosya `FmCategory.other`a düşüyor ve küçük resim hiç denenmiyor.
///
/// *Niye ayrı ve minik bir sınıf:* `FileService._sniffKind` aynı işi yapıyor
/// ama 16 bayt okuduktan sonra zip içine girip OOXML türü de ayırt ediyor ve
/// bir `DocKind` döndürüyor. Liste satırının tek sorusu "bunu `Image.file`a
/// verebilir miyim?" — o yüzden burada 12 baytlık, kilitlenmeyen, önbellekli
/// bir yanıt var.
abstract final class ImageSniff {
  /// Yol → görsel mi? Kaydırırken aynı satır defalarca çizilir; her çizimde
  /// diske gitmemek için sonuç akılda tutulur.
  static final Map<String, bool> _cache = {};

  /// Önbellek üst sınırı: 20 bin dosyalık bir klasörde sınırsız büyürse
  /// bellekte gereksiz yer tutar.
  static const _maxCache = 4096;

  /// Süren okumalar — aynı dosya için iki kez disk açılmasın.
  static final Map<String, Future<bool>> _inFlight = {};

  /// Yalnız test: durumu sıfırlar.
  static void debugReset() {
    _cache.clear();
    _inFlight.clear();
  }

  /// Daha önce bakılmışsa sonucu, bakılmamışsa null (çağıran o zaman
  /// [check] ile asenkron sorar). Senkron olması önemli: `build` içinde
  /// beklemeden karar verilebilsin.
  static bool? cached(String path) => _cache[path];

  static Future<bool> check(String path) {
    final known = _cache[path];
    if (known != null) return Future.value(known);
    final running = _inFlight[path];
    if (running != null) return running;
    final future = _read(path);
    _inFlight[path] = future;
    future.whenComplete(() => _inFlight.remove(path));
    return future;
  }

  static Future<bool> _read(String path) async {
    var result = false;
    RandomAccessFile? raf;
    try {
      raf = await File(path).open();
      final head = await raf.read(12);
      result = looksLikeImage(head);
    } catch (_) {
      result = false;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
    if (_cache.length >= _maxCache) {
      for (final key in _cache.keys.take(_maxCache ~/ 2).toList()) {
        _cache.remove(key);
      }
    }
    _cache[path] = result;
    return result;
  }

  /// İlk baytlar bilinen bir görsel imzası mı?
  ///
  /// Liste `FileService._sniffKind`teki görsel dallarıyla aynı: PNG, JPEG,
  /// GIF, BMP, WEBP (RIFF….WEBP) ve HEIC/HEIF. **`ftyp` tek başına yetmez** —
  /// mp4 de `ftyp` ile başlar; yalnız görsel markaları kabul edilir, yoksa her
  /// videoyu `Image.file`a verip hata ürettirirdik.
  static bool looksLikeImage(Uint8List head) {
    if (head.length < 4) return false;
    bool at(int i, List<int> sig) {
      if (i + sig.length > head.length) return false;
      for (var k = 0; k < sig.length; k++) {
        if (head[i + k] != sig[k]) return false;
      }
      return true;
    }

    if (at(0, [0x89, 0x50, 0x4E, 0x47])) return true; // PNG
    if (at(0, [0xFF, 0xD8, 0xFF])) return true; // JPEG
    if (at(0, [0x47, 0x49, 0x46, 0x38])) return true; // GIF8
    if (at(0, [0x42, 0x4D])) return true; // BMP
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
      return true; // WEBP
    }
    if (at(4, [0x66, 0x74, 0x79, 0x70]) &&
        (at(8, [0x68, 0x65, 0x69, 0x63]) ||
            at(8, [0x68, 0x65, 0x69, 0x78]) ||
            at(8, [0x6D, 0x69, 0x66, 0x31]) ||
            at(8, [0x68, 0x65, 0x69, 0x66]))) {
      return true; // HEIC/HEIF
    }
    return false;
  }
}
