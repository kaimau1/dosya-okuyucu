import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdfrx/pdfrx.dart' show PdfPage, PdfRect;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../pdf_tools.dart' show pdfToSyncfusionRect, stampTransform;

/// Taranmış sayfadaki BİR OCR satırı: tanınan metin + PDF koordinatında
/// (y yukarı; `top > bottom`) kutusu.
class ScannedLine {
  final String text;
  final PdfRect box;
  const ScannedLine(this.text, this.box);
}

/// Taranmış (görüntü) PDF sayfasında **satır üstüne yazma** (2026-08-06
/// kullanıcı isteği: *"taranmış belge deyip düzenleme yaptırmıyor — PDF'de
/// yapılabilmeli"*).
///
/// Gerçek bir metin akışı olmadığı için "yerinde düzenleme" fiziksel olarak
/// imkânsız; yapılabilir olan, tarayıcı uygulamalarının da yaptığı şey:
/// satırın görüntüsü beyaz bir kapakla örtülür ve yeni metin AYNI yere,
/// gömülü fontla (Carlito — Türkçe glifler tam) YAZILIR. Görüntünün geri
/// kalanı hiç bozulmaz; işlem çalışma kopyasında yapılır, geri alınabilir.
///
/// P19 m.2 (2026-11-26): kapak artık düz beyaz değil — [sampleColors] satırın
/// çevresinden kâğıt rengini, içinden mürekkep rengini örnekler (sararmış /
/// renkli kâğıtta yama görünmesin). Örnek alınamazsa (sayfa çizilemedi)
/// eski beyaz kapak + koyu gri metin. Sınır: desenli/dokulu zeminde düz renk
/// kapak yine seçilebilir (inpainting yok).
abstract final class PdfScannedRetype {
  static Uint8List? _fontCache;

  static Future<Uint8List> _font() async => _fontCache ??=
      (await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
          .buffer
          .asUint8List();

  /// [box] satırını beyazla örtüp [newText]'i aynı konuma yazar; yeni PDF
  /// baytlarını döndürür. [newText] boşsa satır yalnız SİLİNİR (kapak kalır).
  static Future<List<int>> apply({
    required List<int> bytes,
    required int pageIndex,
    required PdfRect box,
    required String newText,
    ({int background, int ink})? colors,
  }) =>
      applyMany(
        bytes: bytes,
        pageIndex: pageIndex,
        edits: [
          ScannedEdit(box, newText,
              background: colors?.background, ink: colors?.ink)
        ],
      );

  /// Birden çok satırı **tek belge açılışında** düzeltir.
  ///
  /// Sayfa düzeltme ("Düzelt" / "AI ile düzelt") satır satır [apply]
  /// çağırsaydı 30 satırlık bir sayfa için belge 30 kez açılıp kaydedilirdi —
  /// her kayıt bir artımlı güncelleme (dosya büyür) ve saniyeler süren bir iş.
  /// Buradaki tek geçiş hem hızlı hem de tek bir geri alma adımı bırakıyor.
  static Future<List<int>> applyMany({
    required List<int> bytes,
    required int pageIndex,
    required List<ScannedEdit> edits,
  }) async {
    if (edits.isEmpty) return bytes;
    final font = await _font();
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final page = doc.pages[pageIndex];
      // P19: OCR kutusu GÖRÜNEN (döndürülmüş) sayfadadır; grafik uzayı ham.
      // İmza damgasıyla aynı köprü ([stampTransform]) — eskiden döndürülmüş
      // taranmış sayfada kapak ve metin yanlış yere düşüyordu.
      final turns = page.rotation.index % 4;
      final raw = page.size;
      final visW = turns.isOdd ? raw.height : raw.width;
      final visH = turns.isOdd ? raw.width : raw.height;
      final g = page.graphics;
      final state = g.save();
      final t = stampTransform(raw, turns);
      if (t.angle != 0) {
        g.translateTransform(t.translate.dx, t.translate.dy);
        g.rotateTransform(t.angle);
      }
      for (final edit in edits) {
        final rect = pdfToSyncfusionRect(
          left: edit.box.left,
          pdfTop: edit.box.top,
          width: edit.box.width,
          height: edit.box.height,
          pageHeight: visH,
        );
        // Kapak satırdan bir tık büyük: OCR kutusu glif uçlarını (ç/ğ kuyruğu,
        // noktalama) kıl payı kaçırabiliyor; artık görünmesin.
        final cover = Rect.fromLTRB(
            rect.left - 2, rect.top - 2, rect.right + 2, rect.bottom + 2);
        g.drawRectangle(
            brush: PdfSolidBrush(_pdfColor(edit.background ?? 0xFFFFFFFF)),
            bounds: cover);

        final text = edit.text.trim();
        if (text.isEmpty) continue;
        // Punto satır yüksekliğinden: OCR kutusu glif kutusudur, x-yüksekliği
        // payı için ~%74'ü alınır. Yazım alanı sağa doğru sayfa kenarına
        // kadar uzar — kullanıcı satırı UZATIRSA metin kırpılmasın.
        final size = (rect.height * 0.74).clamp(6.0, 96.0).toDouble();
        final drawBounds = Rect.fromLTWH(
          rect.left,
          rect.top - 1,
          math.max(rect.width, visW - rect.left - 8),
          rect.height + 2,
        );
        g.drawString(
          text,
          PdfTrueTypeFont(font, size),
          brush: PdfSolidBrush(_pdfColor(edit.ink ?? 0xFF191919)),
          bounds: drawBounds,
          format: PdfStringFormat(
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
      }
      g.restore(state);
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static PdfColor _pdfColor(int argb) =>
      PdfColor((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

  /// [box] satırının kâğıt ve mürekkep rengini canlı pdfrx sayfasından
  /// örnekler (yalnız satır çevresi küçük bir bölge çizilir — düzenleme
  /// anında bir kez, sıcak yolda değil). Çizilemezse null → beyaz/koyu gri.
  static Future<({int background, int ink})?> sampleFromPage(
      PdfPage page, PdfRect box) async {
    try {
      const scale = 2.0, pad = 3.0;
      final x = ((box.left - pad) * scale).floor();
      final y = ((page.height - box.top - pad) * scale).floor();
      final w = ((box.width + pad * 2) * scale).ceil();
      final h = ((box.height + pad * 2) * scale).ceil();
      if (w <= 2 || h <= 2) return null;
      final img = await page.render(
        x: math.max(0, x),
        y: math.max(0, y),
        width: w,
        height: h,
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (img == null) return null;
      try {
        return sampleColors(img.pixels, img.width, img.height);
      } finally {
        img.dispose();
      }
    } catch (_) {
      return null; // Bilinçli: örnek yoksa eski beyaz kapak.
    }
  }

  /// Saf hesap (test edilebilir): BGRA [bgra] bölgesinde **kenar halkası**
  /// piksellerinin kanal medyanı = kâğıt rengi; kâğıttan en uzak %10'luk
  /// piksellerin ortalaması = mürekkep. Bölgede yazı seçilemiyorsa (karşıtlık
  /// düşük) mürekkep koyu gri kalır. Dönüş ARGB32.
  static ({int background, int ink})? sampleColors(
      Uint8List bgra, int w, int h) {
    if (w < 3 || h < 3 || bgra.length < w * h * 4) return null;
    final rs = <int>[], gs = <int>[], bs = <int>[];
    void ring(int i) {
      bs.add(bgra[i]);
      gs.add(bgra[i + 1]);
      rs.add(bgra[i + 2]);
    }

    for (var x = 0; x < w; x++) {
      ring(x * 4);
      ring(((h - 1) * w + x) * 4);
    }
    for (var y = 1; y < h - 1; y++) {
      ring(y * w * 4);
      ring((y * w + w - 1) * 4);
    }
    int median(List<int> v) => (v..sort())[v.length ~/ 2];
    final br = median(rs), bgc = median(gs), bb = median(bs);

    final n = w * h;
    final dist = List<int>.filled(n, 0);
    for (var p = 0; p < n; p++) {
      final i = p * 4;
      dist[p] = (bgra[i + 2] - br).abs() +
          (bgra[i + 1] - bgc).abs() +
          (bgra[i] - bb).abs();
    }
    final sorted = List<int>.of(dist)..sort();
    final cut = sorted[(n * 0.9).floor().clamp(0, n - 1)];
    var ink = 0xFF191919;
    // ponytail: sabit eşik (kanal toplamı 90) — belgeye göre ayar gerekirse
    // burası; ΔE ≤ 3 ölçümü cihaz turunda (CIHAZ_TESTI B4-P19).
    if (cut >= 90) {
      var r = 0, g = 0, b = 0, c = 0;
      for (var p = 0; p < n; p++) {
        if (dist[p] < cut) continue;
        final i = p * 4;
        b += bgra[i];
        g += bgra[i + 1];
        r += bgra[i + 2];
        c++;
      }
      ink = 0xFF000000 | ((r ~/ c) << 16) | ((g ~/ c) << 8) | (b ~/ c);
    }
    return (
      background: 0xFF000000 | (br << 16) | (bgc << 8) | bb,
      ink: ink,
    );
  }
}

/// Tek satırlık düzeltme isteği: hangi kutu, yerine ne yazılacak.
class ScannedEdit {
  final PdfRect box;
  final String text;

  /// Örneklenen kâğıt / mürekkep rengi (ARGB32); null → beyaz / koyu gri.
  final int? background;
  final int? ink;
  const ScannedEdit(this.box, this.text, {this.background, this.ink});
}
