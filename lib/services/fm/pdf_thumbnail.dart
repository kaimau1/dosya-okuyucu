import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'thumbnail_cache.dart';

/// PDF'in **ilk sayfasını** küçük resim olarak üretir ve diskte önbelleğe alır.
///
/// **Niye (KALANLAR maddesi):** listelerde her PDF aynı kırmızı simgeyle
/// görünüyordu; on tane faturanın hangisinin hangisi olduğu ancak dosya adından
/// anlaşılıyordu. Kapak sayfası tek bakışta ayırt ettirir.
///
/// **Niye disk önbelleği:** pdfium ile sayfa çizmek dosya başına onlarca-yüzlerce
/// ms sürer; her kaydırmada yeniden çizmek listeyi kastırırdı. Anahtar
/// (yol + değişiklik zamanı + boy) [ThumbnailCache.cacheName] ile üretiliyor —
/// video küçük resimleriyle **aynı kural**, aynı klasör, aynı budama.
///
/// **Sınırlar bilinçli:**
/// - Yalnız ilk sayfa çizilir (kapak). Belgenin ortasını göstermek bir küçük
///   resmin işi değil.
/// - Parola korumalı belge sessizce atlanır: kullanıcıya listede parola
///   sormak kabul edilemez, simge gösterilir.
/// - Üretilemeyen dosya işaretlenir ve bir daha denenmez (bozuk PDF her
///   kaydırmada pdfium'u yeniden çalıştırmasın).
abstract final class PdfThumbnail {
  static final Map<String, Future<String?>> _inFlight = {};
  static const _failedLimit = 256;
  static final Set<String> _failed = <String>{};

  static Directory? _dir;

  /// Yalnız test: durumu sıfırlar.
  static void debugReset() {
    _inFlight.clear();
    _failed.clear();
    _dir = null;
  }

  /// [path] PDF'inin kapak küçük resmini döndürür (yoksa üretir).
  /// Üretilemezse null — çağıran simgeyi gösterir.
  static Future<String?> forPdf(String path, {int size = 256}) {
    if (_failed.contains(path)) return Future.value(null);
    final existing = _inFlight[path];
    if (existing != null) return existing;
    final future = _generate(path, size);
    _inFlight[path] = future;
    future.whenComplete(() => _inFlight.remove(path));
    return future;
  }

  static Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'pdf_thumbs'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  static Future<String?> _generate(String path, int size) async {
    PdfDocument? doc;
    try {
      final stat = File(path).statSync();
      final dir = await _cacheDir();
      final dest = p.join(
        dir.path,
        ThumbnailCache.cacheName(path, stat.modified.millisecondsSinceEpoch,
                size)
            .replaceAll('.jpg', '.png'),
      );
      if (File(dest).existsSync()) return dest;

      doc = await PdfDocument.openFile(path);
      if (doc.pages.isEmpty) {
        _markFailed(path);
        return null;
      }
      final page = doc.pages.first;
      // En-boy oranı korunur: kutuya sığan ölçü hesaplanır. Sabit kare
      // çizmek A4'ü yamultur ve küçük resim "yanlış belge" gibi görünür.
      final scale = size / (page.width > page.height ? page.width : page.height);
      final width = (page.width * scale).round().clamp(16, size);
      final height = (page.height * scale).round().clamp(16, size);
      final rendered = await page.render(
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
        // Beyaz zemin: saydam çizim koyu temada okunmaz bir leke olurdu.
        backgroundColor: const ui.Color(0xFFFFFFFF),
      );
      if (rendered == null) {
        _markFailed(path);
        return null;
      }
      ui.Image? image;
      try {
        image = await rendered.createImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) {
          _markFailed(path);
          return null;
        }
        await File(dest).writeAsBytes(png.buffer.asUint8List(), flush: true);
      } finally {
        image?.dispose();
        rendered.dispose();
      }
      return dest;
    } catch (_) {
      // Parola korumalı, bozuk ya da PDF olmayan dosya.
      _markFailed(path);
      return null;
    } finally {
      await doc?.dispose();
    }
  }

  static void _markFailed(String path) {
    if (_failed.length >= _failedLimit) {
      for (final old in _failed.take(_failedLimit ~/ 2).toList()) {
        _failed.remove(old);
      }
    }
    _failed.add(path);
  }
}
