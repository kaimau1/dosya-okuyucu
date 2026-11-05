/// **Sayfa işlemleri (pro)** — Faz 39 madde 8: boş sayfa algılama, kırpma,
/// boyutlandırma / A4'e sığdırma. (Çoklu seç → döndür/sil/çıkar/sırala
/// `PdfTools`'ta; sıralama ekranı `selectPages` sırasını kullanır.)
///
/// Kırpma ve sığdırma sayfayı şablon olarak YENİ belgeye çizer (vektör
/// korunur, annotation'lar taşınmaz — arayüz bunu `_confirmAnnotationLoss`
/// ile sorar). Kaynak sayfanın `/Rotate`'i [composedPageTransform] ile
/// uygulanır: kullanıcı GÖRDÜĞÜ sayfayı kırpar.
library;

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_tools.dart' show composedPageTransform, PdfToolsException;

abstract final class PdfPagePro {
  /// A4 dikey (pt).
  static const a4 = Size(595.28, 841.89);

  /// Saf: gri küçük çizimden "boş sayfa" kararı. Kenarlardan %3 pay atılır
  /// (tarama gölgesi/zımba izi), parlaklığı [threshold] altındaki piksellerin
  /// oranı [maxInk] altındaysa boş.
  static bool isBlank(int w, int h, Uint8List luma,
      {int threshold = 200, double maxInk = 0.0025}) {
    if (w == 0 || h == 0) return true;
    final mx = (w * 0.03).round(), my = (h * 0.03).round();
    var ink = 0, total = 0;
    for (var y = my; y < h - my; y++) {
      final row = y * w;
      for (var x = mx; x < w - mx; x++) {
        total++;
        if (luma[row + x] < threshold) ink++;
      }
    }
    return total == 0 || ink / total < maxInk;
  }

  /// [pages] sayfalarını (yoksa hepsini) [crop] kutusuna kırpar — kutu
  /// GÖRÜNEN sayfa puntosunda (sol-üst). Sayfadan taşan kısım kenetlenir.
  static Future<List<int>> crop(List<int> bytes, Rect crop,
      {List<int>? pages, String? password}) async {
    final src = PdfDocument(inputBytes: bytes, password: password);
    final out = PdfDocument();
    try {
      out.compressionLevel = PdfCompressionLevel.best;
      final targets = pages?.toSet();
      for (var i = 0; i < src.pages.count; i++) {
        final page = src.pages[i];
        final t = composedPageTransform(page.size, page.rotation.index);
        final shown = Offset.zero & t.size;
        final r = (targets == null || targets.contains(i))
            ? crop.intersect(shown)
            : shown;
        final box = r.width < 1 || r.height < 1 ? shown : r;
        final section = out.sections!.add()
          ..pageSettings = (PdfPageSettings(box.size)..margins.all = 0);
        final g = section.pages.add().graphics;
        g.setClip(bounds: Rect.fromLTWH(0, 0, box.width, box.height));
        g.translateTransform(-box.left, -box.top);
        if (t.angle != 0) {
          g.translateTransform(t.translate.dx, t.translate.dy);
          g.rotateTransform(t.angle);
        }
        g.drawPdfTemplate(page.createTemplate(), Offset.zero, page.size);
      }
      return await out.save();
    } finally {
      out.dispose();
      src.dispose();
    }
  }

  /// Saf: [content] boyutlu sayfanın [target] içine sığdırma ölçeği ve
  /// ortalama ötelemesi. [matchOrientation] ise hedef, içeriğin yönüne
  /// döndürülür (yatay sayfa → yatay A4).
  static ({Size page, double scale, Offset offset}) fit(Size content, Size target,
      {bool matchOrientation = true}) {
    var page = target;
    if (matchOrientation &&
        (content.width > content.height) != (target.width > target.height)) {
      page = Size(target.height, target.width);
    }
    final scale =
        math.min(page.width / content.width, page.height / content.height);
    final offset = Offset((page.width - content.width * scale) / 2,
        (page.height - content.height * scale) / 2);
    return (page: page, scale: scale, offset: offset);
  }

  /// Sayfaları [target] boyutuna (varsayılan A4) oranı koruyarak sığdırır.
  static Future<List<int>> resize(List<int> bytes,
      {Size target = a4, List<int>? pages, String? password}) async {
    final src = PdfDocument(inputBytes: bytes, password: password);
    final out = PdfDocument();
    try {
      out.compressionLevel = PdfCompressionLevel.best;
      final targets = pages?.toSet();
      for (var i = 0; i < src.pages.count; i++) {
        final page = src.pages[i];
        final t = composedPageTransform(page.size, page.rotation.index);
        final apply = targets == null || targets.contains(i);
        final f = apply
            ? fit(t.size, target)
            : (page: t.size, scale: 1.0, offset: Offset.zero);
        final section = out.sections!.add()
          ..pageSettings = (PdfPageSettings(f.page)..margins.all = 0);
        final g = section.pages.add().graphics;
        // Syncfusion'da ölçek dönüşümü yok: şablon hedef boyutta çizilir,
        // döndürme ötelemesi aynı ölçekle çarpılır (döndürme ölçekten bağımsız).
        g.translateTransform(f.offset.dx, f.offset.dy);
        if (t.angle != 0) {
          g.translateTransform(t.translate.dx * f.scale, t.translate.dy * f.scale);
          g.rotateTransform(t.angle);
        }
        g.drawPdfTemplate(page.createTemplate(), Offset.zero, page.size * f.scale);
      }
      return await out.save();
    } finally {
      out.dispose();
      src.dispose();
    }
  }

  static Future<List<int>> cropInBackground(List<int> bytes, Rect rect,
          {List<int>? pages, String? password}) =>
      _bg(() => crop(bytes, rect, pages: pages, password: password));

  static Future<List<int>> resizeInBackground(List<int> bytes,
          {Size target = a4, List<int>? pages, String? password}) =>
      _bg(() => resize(bytes, target: target, pages: pages, password: password));

  static Future<List<int>> _bg(Future<List<int>> Function() task) =>
      Isolate.run(() async {
        try {
          return await task();
        } catch (e) {
          throw PdfToolsException('$e');
        }
      });
}
