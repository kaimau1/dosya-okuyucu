import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/app_colors.dart';
import '../../core/private_zone.dart';

/// **Son sayfa görüntüsü** (Ferrari H1.4, 2026-11-14).
///
/// Belge kapanırken görünen sayfa düşük çözünürlükte (en çok [maxWidthPx]
/// piksel, ≤ [maxBytes] JPEG) uygulama önbelleğine yazılır; yeniden açılışta
/// açılış köprüsü (`PdfOpenBridge`) kapak yerine bunu gösterir — ortadan
/// devam edilen kitapta da ilk karede o sayfa durur.
///
/// - Ad: yolun SHA-1'i + sayfa (`<sha1>_<sayfa>.jpg`); belge başına tek
///   görüntü, en çok [maxEntries] belge (en eskiler silinir).
/// - Belge görüntüden SONRA değiştiyse görüntü bayat sayılır, kullanılmaz.
/// - Kasa/özel dosyada ve parolalı belgede **saklanmaz** (içerik şifresiz
///   önbelleğe düşmesin).
abstract final class PdfLastView {
  static const maxEntries = 50;
  static const maxBytes = 200 * 1024;
  static const maxWidthPx = 540;

  static Directory? _dir;

  /// Yalnız test: önbellek klasörü (path_provider testte yok).
  static void debugUseDir(Directory? dir) => _dir = dir;

  /// Bu yol için görüntü saklanabilir mi?
  static bool allowed(String path) =>
      !PrivateZone.active && !PrivateZone.isPrivatePath(path);

  static String keyOf(String path) =>
      sha1.convert(utf8.encode(path)).toString();

  static Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationCacheDirectory();
    final dir = Directory(p.join(base.path, 'pdf_last_view'));
    await dir.create(recursive: true);
    return _dir = dir;
  }

  /// Açık belgenin [page] sayfasını çizip saklar. Kapanırken çağrılır;
  /// başarısızlık sessiz (köprü kapağa/kâğıda döner).
  static Future<void> capture(String path, PdfDocument doc, int page) async {
    if (!allowed(path) || page < 1 || page > doc.pages.length) return;
    try {
      final pg = doc.pages[page - 1];
      final w = maxWidthPx;
      final h = (w * pg.height / pg.width).round().clamp(16, w * 4);
      final rendered = await pg.render(
        fullWidth: w.toDouble(),
        fullHeight: h.toDouble(),
        backgroundColor: AppColors.page.toARGB32(),
      );
      if (rendered == null) return;
      final Uint8List bgra;
      final int rw, rh;
      try {
        bgra = Uint8List.fromList(rendered.pixels);
        rw = rendered.width;
        rh = rendered.height;
      } finally {
        rendered.dispose();
      }
      final jpg = await compute(encode, (bgra, rw, rh));
      if (jpg == null) return;
      await save(path, page, jpg);
    } catch (_) {
      // Bilinçli: görüntü yalnız açılış süsü; belge kapanırken çizim
      // yarıda kalabilir — o zaman köprü kapak/kâğıt gösterir.
    }
  }

  /// BGRA → JPEG; [maxBytes]'ı aşarsa kalite düşürülür, yine aşarsa null.
  @visibleForTesting
  static Uint8List? encode((Uint8List, int, int) a) {
    final (bgra, w, h) = a;
    final im = img.Image.fromBytes(
        width: w, height: h, bytes: bgra.buffer, order: img.ChannelOrder.bgra);
    for (final q in const [70, 50, 35]) {
      final out = Uint8List.fromList(img.encodeJpg(im, quality: q));
      if (out.length <= maxBytes) return out;
    }
    return null;
  }

  /// [jpg]'yi [path]'in [page] görüntüsü olarak yazar; belgenin eski
  /// görüntüsünü ve [maxEntries]'i aşan en eskileri siler.
  static Future<void> save(String path, int page, Uint8List jpg) async {
    if (!allowed(path) || jpg.length > maxBytes) return;
    final dir = await _cacheDir();
    final key = keyOf(path);
    final name = '${key}_$page.jpg';
    final tmp = File(p.join(dir.path, '$name.tmp'));
    await tmp.writeAsBytes(jpg, flush: true);
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final b = p.basename(e.path);
      if (b.startsWith('${key}_') && b != '$name.tmp') {
        await e.delete();
      } else if (b.endsWith('.jpg')) {
        files.add(e);
      }
    }
    await tmp.rename(p.join(dir.path, name));
    // Yeni görüntü + en yeni (maxEntries - 1) kalır.
    if (files.length >= maxEntries) {
      final stamped = [
        for (final f in files) (f, (await f.stat()).modified),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      for (final (f, _) in stamped.skip(maxEntries - 1)) {
        await f.delete();
      }
    }
  }

  /// [path]'in [page] için saklı görüntüsü; yoksa, belge sonradan
  /// değiştiyse ya da saklanamaz bir yolsa null. `aspect` = en / boy.
  static Future<({String path, double aspect})?> find(
      String path, int page) async {
    if (!allowed(path)) return null;
    try {
      final dir = await _cacheDir();
      final f = File(p.join(dir.path, '${keyOf(path)}_$page.jpg'));
      final snap = await f.stat();
      if (snap.type == FileSystemEntityType.notFound) return null;
      final pdf = await File(path).stat();
      if (pdf.modified.isAfter(snap.modified)) return null;
      final aspect = await jpegAspect(f);
      return aspect == null ? null : (path: f.path, aspect: aspect);
    } catch (_) {
      return null;
    }
  }

  /// JPEG SOF başlığından en / boy (ilk 64 KB'de); bulunamazsa null.
  static Future<double?> jpegAspect(File file) async {
    final raf = await file.open();
    try {
      final b = await raf.read(64 * 1024);
      var i = 2;
      while (i + 9 < b.length) {
        if (b[i] != 0xFF) return null;
        final m = b[i + 1];
        final len = (b[i + 2] << 8) | b[i + 3];
        if (m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) {
          final h = (b[i + 5] << 8) | b[i + 6];
          final w = (b[i + 7] << 8) | b[i + 8];
          return w > 0 && h > 0 ? w / h : null;
        }
        i += 2 + len;
      }
      return null;
    } finally {
      await raf.close();
    }
  }
}
