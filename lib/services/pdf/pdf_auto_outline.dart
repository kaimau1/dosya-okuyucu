/// **Yer imi olmayan PDF'ten içindekiler çıkarma** (2026-11-26).
///
/// Kullanıcı: *"pdf'lerde olmayan pdf'ler için de programımız bu tür şeyleri
/// pdf'i tarayıp yapabilsin"*. Sayfa sayfa satırlar toplanır (metin katmanı
/// varsa pdfium'dan, taranmış belgede cihaz-içi OCR'dan), sonra başlık
/// sezgisi uygulanır:
/// * gövde boyu = karakter sayısıyla ağırlıklı en sık satır boyu;
/// * gövdeden ≥ %20 büyük satır **başlık**; gövde boyunda ama TÜMÜ BÜYÜK,
///   kısa ve noktasız satır **alt başlık** adayı;
/// * sayfaların üst/alt şeridinde tekrarlanan satırlar (kitap adı, sayfa
///   başlığı, sayfa no) atılır;
/// * aynı sayfada art arda gelen eş boy başlık satırları birleşir (iki
///   satıra taşan başlık);
/// * en büyük boy → düzey 0, geri kalan → düzey 1 (en çok iki düzey).
///
/// Sezgi saf Dart ([pickHeadings]) ve birim testli; G/Ç yalnız [detect]'te.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:pdfrx/pdfrx.dart';

import '../../core/text_search.dart' show asciiFold;
import '../ocr_service.dart';
import '../pdf_doc_pro.dart' show PdfOutlineItem;

/// Sayfadaki tek metin satırı.
class OutlineLine {
  final String text;

  /// Satırın yazı boyu (birimi önemsiz; yalnız aynı belgede karşılaştırılır).
  final double size;

  /// Satırın sayfadaki dikey yeri: 1 = en üst, 0 = en alt.
  final double pos;

  const OutlineLine(this.text, this.size, this.pos);
}

abstract final class PdfAutoOutline {
  /// Taranmış sayılmak için metinsiz örnek sayfa oranı.
  static const scannedRatio = 0.6;

  /// Belge **taranmış** mı: örneklenen sayfaların çoğunda metin katmanı yok.
  ///
  /// Kullanıcı: "taranmışlar iyi ayırt edilsin, gereksiz uyarı olmasın" —
  /// birkaç görsel sayfası olan metin PDF'i taranmış SAYILMAZ; OCR ile
  /// görünmez metin katmanı eklenmiş PDF de metinli sayılır.
  static Future<bool> looksScanned(PdfDocument doc) async {
    final n = doc.pages.length;
    if (n == 0) return false;
    final step = math.max(1, n ~/ 12);
    var sampled = 0, textless = 0;
    for (var i = 0; i < n && sampled < 12; i += step) {
      sampled++;
      final raw = await doc.pages[i].loadText();
      final letters =
          (raw?.fullText ?? '').replaceAll(RegExp(r'\s'), '').length;
      if (letters < 20) textless++;
    }
    return textless / sampled >= scannedRatio;
  }

  /// Belgenin içindekilerini çıkarır. [ocr] true ise sayfalar OCR'lanır.
  /// [cancelled] true dönerse o ana kadarki sayfalarla devam edilir.
  static Future<List<PdfOutlineItem>> detect(
    PdfDocument doc, {
    required bool ocr,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final pages = <List<OutlineLine>>[];
    final total = doc.pages.length;
    for (var i = 0; i < total; i++) {
      if (cancelled?.call() ?? false) break;
      final page = doc.pages[i];
      pages.add(ocr ? await _ocrLines(page) : await _textLines(page));
      onProgress?.call(i + 1, total);
    }
    // Büyük kitapta on binlerce satır: sezgi ana izleği kilitlemesin.
    return Isolate.run(() => pickHeadings(pages));
  }

  static Future<List<OutlineLine>> _textLines(PdfPage page) async {
    final raw = await page.loadText();
    if (raw == null) return const [];
    return linesFromChars(raw.fullText, [
      for (final r in raw.charRects) (top: r.top, bottom: r.bottom),
    ], page.height);
  }

  static Future<List<OutlineLine>> _ocrLines(PdfPage page) async {
    final img = await OcrService.renderPageForOcr(page,
        tag: 'toc', targetWidth: 1400, losslessPng: false);
    if (img == null) return const [];
    try {
      final lines = await OcrService.recognizeImageLines(img.path,
          mode: OcrQualityMode.fast);
      final h = page.height * img.scale;
      return [
        for (final l in lines)
          if (l.text.trim().isNotEmpty)
            OutlineLine(l.text.trim(), l.box.height, 1 - l.box.top / h),
      ];
    } finally {
      try {
        await File(img.path).delete();
      } catch (_) {
        // Bilinçli: geçici dosya; silinemezse sistem temizler.
      }
    }
  }

  /// pdfium karakter kutularından satırlar ([rects] PDF koordinatında,
  /// üst > alt). Satır sonu: metindeki `\n`/`\r` ya da dikey sıçrama.
  static List<OutlineLine> linesFromChars(String text,
      List<({double top, double bottom})> rects, double pageHeight) {
    final out = <OutlineLine>[];
    final n = math.min(text.length, rects.length);
    final sb = StringBuffer();
    final heights = <double>[];
    var top = 0.0;
    double? lastMid;
    void flush() {
      final t = sb.toString().trim();
      if (t.isNotEmpty && heights.isNotEmpty) {
        heights.sort();
        out.add(OutlineLine(
            t, heights[heights.length ~/ 2], pageHeight <= 0 ? 0 : top / pageHeight));
      }
      sb.clear();
      heights.clear();
      top = 0;
      lastMid = null;
    }

    for (var i = 0; i < n; i++) {
      final c = text[i];
      if (c == '\n' || c == '\r') {
        flush();
        continue;
      }
      final r = rects[i];
      final h = r.top - r.bottom;
      if (c.trim().isNotEmpty && h > 0) {
        final mid = (r.top + r.bottom) / 2;
        final prev = lastMid;
        if (prev != null && (mid - prev).abs() > h * 0.8) flush();
        heights.add(h);
        if (r.top > top) top = r.top;
        lastMid = mid;
      }
      sb.write(c);
    }
    flush();
    return out;
  }

  /// Satırlardan yer imi listesi ([pages] sayfa sırasında; sayfa 0'dan).
  static List<PdfOutlineItem> pickHeadings(List<List<OutlineLine>> pages) {
    // 1) Gövde boyu: karakter ağırlıklı en sık boy (0,5 adımlı kova).
    final hist = <double, int>{};
    for (final page in pages) {
      for (final l in page) {
        final k = (l.size * 2).roundToDouble() / 2;
        hist[k] = (hist[k] ?? 0) + l.text.length;
      }
    }
    if (hist.isEmpty) return const [];
    final body = hist.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    if (body <= 0) return const [];

    // 2) Üst/alt şeritte tekrarlananlar (sayfa başlığı, kitap adı, sayfa no).
    String norm(String s) =>
        asciiFold(s).replaceAll(RegExp(r'[0-9\s\-–—.]+'), ' ').trim();
    final edgeCount = <String, int>{};
    for (final page in pages) {
      final seen = <String>{};
      for (final l in page) {
        if (l.pos > 0.88 || l.pos < 0.12) seen.add(norm(l.text));
      }
      for (final s in seen) {
        edgeCount[s] = (edgeCount[s] ?? 0) + 1;
      }
    }
    final repeatMin = math.max(3, (pages.length * 0.15).ceil());
    bool running(OutlineLine l) =>
        (l.pos > 0.88 || l.pos < 0.12) &&
        (norm(l.text).isEmpty || (edgeCount[norm(l.text)] ?? 0) >= repeatMin);

    // 3) Adaylar.
    final cands = <({int page, int line, String text, double size, bool big})>[];
    for (var pi = 0; pi < pages.length; pi++) {
      final page = pages[pi];
      for (var li = 0; li < page.length; li++) {
        final l = page[li];
        final t = l.text.trim();
        if (running(l) || !_titleLike(t)) continue;
        final ratio = l.size / body;
        if (ratio >= 1.2) {
          cands.add((page: pi, line: li, text: t, size: l.size, big: true));
        } else if (ratio >= 0.95 && _allCaps(t) && t.length <= 90) {
          cands.add((page: pi, line: li, text: t, size: l.size, big: false));
        }
      }
    }

    // Aşırı aday = sezgi bu belgede tutmuyor: önce büyük harf adayları,
    // sonra küçük farklar düşer.
    var kept = cands;
    final cap = math.max(8, pages.length * 4);
    if (kept.length > cap) kept = [for (final c in kept) if (c.big) c];
    if (kept.length > cap) {
      kept = [for (final c in kept) if (c.size / body >= 1.35) c];
    }
    if (kept.isEmpty) return const [];

    // 4) Aynı sayfada art arda, eş boylu satırlar tek başlık.
    final merged = <({int page, String text, double size, bool big})>[];
    for (var i = 0; i < kept.length; i++) {
      final c = kept[i];
      var text = c.text;
      var j = i;
      while (j + 1 < kept.length &&
          j - i < 2 &&
          kept[j + 1].page == c.page &&
          kept[j + 1].line == kept[j].line + 1 &&
          kept[j + 1].big == c.big &&
          (kept[j + 1].size - c.size).abs() <= c.size * 0.06) {
        j++;
        text = '$text ${kept[j].text}';
      }
      i = j;
      merged.add((page: c.page, text: text, size: c.size, big: c.big));
    }

    // 5) Düzey: en büyük boy kümesi 0, gerisi 1. Yalnız büyük harf adayı
    // varsa hepsi 0.
    final bigSizes = [for (final m in merged) if (m.big) m.size];
    final top = bigSizes.isEmpty ? null : bigSizes.reduce(math.max);
    final out = <PdfOutlineItem>[];
    String? last;
    for (final m in merged) {
      final level = top == null
          ? 0
          : (m.big && m.size >= top * 0.94)
              ? 0
              : 1;
      final title = m.text.replaceAll(RegExp(r'\s+'), ' ');
      if (title == last) continue; // her sayfada yinelenen bölüm adı
      last = title;
      out.add(PdfOutlineItem(title, m.page, level));
    }
    // İlk öğe kök olmalı (yazıcı düzey sıçramasını kenetler ama sıra bozulmasın).
    if (out.isNotEmpty && out.first.level != 0) {
      out[0] = out.first.copyWith(level: 0);
    }
    return out;
  }

  /// Başlığa benzer mi: en az 2 harf, 2–120 karakter, virgül/noktalı
  /// virgülle bitmiyor, salt sayı değil.
  static bool _titleLike(String t) {
    if (t.length < 2 || t.length > 120) return false;
    if (t.endsWith(',') || t.endsWith(';')) return false;
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(t).length;
    return letters >= 2;
  }

  static bool _allCaps(String t) {
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(t).length;
    if (letters < 4 || t.endsWith('.')) return false;
    // Türkçe büyük harf: 'i' → 'İ' (Dart `toUpperCase` yerel-duyarsız).
    final upper = t.replaceAll('i', 'İ').toUpperCase();
    return t == upper && t != t.toLowerCase();
  }
}
