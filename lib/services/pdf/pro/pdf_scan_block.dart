/// **Taranmış sayfada yazıyı değiştirme** (2026-11-24, kullanıcı: *"taranmış
/// şeylerde metin tanıması pek doğru değil ve değiştirme de yapılamıyor"*).
///
/// Taranmış sayfanın yazısı bir görüntüdür; üstündeki görünmez tanıma katmanı
/// düzenlenemez (PK7). "Yazıyı değiştir" akışı: bloğun altındaki kâğıt rengi
/// ölçülür ([paperColor]) → eski yazı o renkte bir dikdörtgenle örtülür ve
/// görünmez tanıma metni silinir → tanınan metin (ya da istenirse yapay zekâ
/// ile yeniden okunan metin, [aiRead]) düzenlenebilir bir metin kutusuna
/// konur.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../cloud_ocr.dart';
import 'pdf_text_blocks.dart';

abstract final class PdfScanBlock {
  /// Kâğıt rengi için sayfanın çizileceği uzun kenar (piksel) — hızlı.
  static const _probeEdge = 240;

  /// Bloğun ÇEVRESİNDEKİ (yazının dışı) piksellerden kâğıt rengi (ARGB,
  /// opak). Ölçülemezse null — çağıran beyaz kullanır.
  static Future<int?> paperColor(PdfPage page, PdfTextBlock block) async {
    if (page.width <= 0 || page.height <= 0) return null;
    final k = _probeEdge / (page.width > page.height ? page.width : page.height);
    final w = (page.width * k).round().clamp(16, _probeEdge);
    final h = (page.height * k).round().clamp(16, _probeEdge);
    PdfImage? img;
    try {
      img = await page.render(
          fullWidth: w.toDouble(),
          fullHeight: h.toDouble(),
          backgroundColor: 0xFFFFFFFF);
      if (img == null) return null;
      final r = PdfRect(block.left, block.top, block.right, block.bottom)
          .toRect(page: page, scaledPageSize: Size(w.toDouble(), h.toDouble()));
      return paperFromBgra(img.pixels, img.width, img.height, r);
    } catch (_) {
      return null; // Bilinçli: renk ölçülemezse beyaz örtü.
    } finally {
      img?.dispose();
    }
  }

  /// BGRA piksellerinde [box]'ın 2–5 piksel dışındaki halkanın ortanca
  /// rengi. Halka görüntü dışına taşıyorsa kırpılır; örnek yoksa null.
  static int? paperFromBgra(Uint8List px, int w, int h, Rect box) {
    if (w <= 0 || h <= 0 || px.length < w * h * 4) return null;
    final outer = box.inflate(5), inner = box.inflate(2);
    final samples = <int>[];
    final x0 = outer.left.floor().clamp(0, w - 1);
    final x1 = outer.right.ceil().clamp(0, w - 1);
    final y0 = outer.top.floor().clamp(0, h - 1);
    final y1 = outer.bottom.ceil().clamp(0, h - 1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (inner.contains(Offset(x + 0.5, y + 0.5))) continue;
        final i = (y * w + x) * 4;
        final b = px[i], g = px[i + 1], r = px[i + 2];
        samples.add((r << 16) | (g << 8) | b);
      }
    }
    if (samples.isEmpty) return null;
    // Kâğıt, çevredeki en AÇIK renklerin çoğunluğudur: koyu (yazı/çizgi)
    // pikseller ortancayı kaydırmasın diye parlaklığa göre sıralanıp üst
    // yarının ortancası alınır.
    int lum(int c) =>
        ((c >> 16) & 0xFF) * 3 + ((c >> 8) & 0xFF) * 6 + (c & 0xFF);
    samples.sort((a, b) => lum(a).compareTo(lum(b)));
    final top = samples.sublist(samples.length ~/ 2);
    return 0xFF000000 | top[top.length ~/ 2];
  }

  /// Bloğun bölgesini yüksek çözünürlükte çizip yapay zekâ ile okur (el
  /// yazısı, bozuk tanıma). Anahtar yok / çevrimdışı / hata → null.
  static Future<String?> aiRead(PdfPage page, PdfTextBlock block) async {
    if (!CloudOcr.available) return null;
    PdfImage? img;
    ui.Image? image;
    File? tmp;
    try {
      // Bölge en az 1400 px genişlikte çizilsin (el yazısı okunaklı kalsın).
      final bw = (block.right - block.left).abs();
      if (bw <= 0 || page.width <= 0) return null;
      final scale = (1400 / bw).clamp(1.5, 6.0);
      final fw = page.width * scale, fh = page.height * scale;
      final r = PdfRect(block.left, block.top, block.right, block.bottom)
          .toRect(page: page, scaledPageSize: Size(fw, fh))
          .inflate(6 * scale);
      final x = r.left.floor().clamp(0, fw.floor() - 1);
      final y = r.top.floor().clamp(0, fh.floor() - 1);
      final cw = r.width.ceil().clamp(1, fw.floor() - x);
      final ch = r.height.ceil().clamp(1, fh.floor() - y);
      img = await page.render(
          x: x,
          y: y,
          width: cw,
          height: ch,
          fullWidth: fw,
          fullHeight: fh,
          backgroundColor: 0xFFFFFFFF);
      if (img == null) return null;
      image = await img.createImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      final dir = await getTemporaryDirectory();
      tmp = File(p.join(dir.path,
          'scan_block_${DateTime.now().microsecondsSinceEpoch}.png'));
      await tmp.writeAsBytes(png.buffer.asUint8List(), flush: true);
      final lines = await CloudOcr.lines(tmp.path);
      final text = lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty);
      final joined = text.join(' ').trim();
      return joined.isEmpty ? null : joined;
    } catch (_) {
      return null; // Bilinçli: okunamazsa cihazdaki tanıma metni kullanılır.
    } finally {
      image?.dispose();
      img?.dispose();
      try {
        await tmp?.delete();
      } catch (_) {
        // Bilinçli: geçici dosya silinemezse önbellek temizliği alır.
      }
    }
  }
}
