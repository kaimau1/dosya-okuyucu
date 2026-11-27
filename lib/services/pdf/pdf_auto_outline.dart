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
/// * "BÖLÜM 3", "Birinci Kısım", "BAB", "الفصل" gibi kalıplar gövde boyunda da
///   başlıktır (düzey 0) ve altındaki satırla birleşir;
/// * yanlış başlık süzgeci (B19, 2026-11-27 — 750 sayfalık Türkçe+Arapça
///   kitap): Latin yazılı belgede Arapça satır (alıntılar çoğu zaman iri
///   dizilir), noktayla biten uzun ya da 14 kelimeden uzun satır ve art arda
///   3 satırdan uzun eş boy blok (alıntı paragrafı) başlık sayılmaz;
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
  ///
  /// B19 kök neden (2026-11-27): görüntüleyicinin belgesi pdfrx'in kademeli
  /// yüklemesiyle açılıyor; henüz yüklenmemiş sayfada `loadText()` null
  /// döndüğü için 750 sayfalık METİNLİ kitap "taranmış" sayılıp OCR'a
  /// giriyordu. Önce tüm sayfalar yüklenir ([_ensureLoaded]).
  static Future<bool> looksScanned(PdfDocument doc) async {
    await _ensureLoaded(doc);
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

  static Future<void> _ensureLoaded(PdfDocument doc) async {
    if (doc.pages.any((p) => !p.isLoaded)) await doc.loadPagesProgressively();
  }

  static int _letters(List<OutlineLine> lines) {
    var n = 0;
    for (final l in lines) {
      n += l.text.replaceAll(RegExp(r'\s'), '').length;
    }
    return n;
  }

  /// Belgenin içindekilerini çıkarır. Her sayfada önce metin katmanı okunur;
  /// [ocr] true ise (belge taranmış) YALNIZ metinsiz sayfa OCR'lanır.
  /// [cancelled] true dönerse o ana kadarki sayfalarla devam edilir.
  static Future<List<PdfOutlineItem>> detect(
    PdfDocument doc, {
    required bool ocr,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    await _ensureLoaded(doc);
    final pages = <List<OutlineLine>>[];
    final total = doc.pages.length;
    for (var i = 0; i < total; i++) {
      if (cancelled?.call() ?? false) break;
      final page = doc.pages[i];
      var lines = await _textLines(page);
      if (ocr && _letters(lines) < 20) lines = await _ocrLines(page);
      pages.add(lines);
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

    // Belgenin ana yazısı Latin mi (Arapça alıntılar başlık sayılmasın).
    var latin = 0, arabic = 0;
    for (final page in pages) {
      for (final l in page) {
        final (la, ar) = _scriptCounts(l.text);
        latin += la;
        arabic += ar;
      }
    }
    final latinDoc = latin >= arabic * 2;

    // 3) Adaylar.
    final raw = <_Cand>[];
    for (var pi = 0; pi < pages.length; pi++) {
      final page = pages[pi];
      for (var li = 0; li < page.length; li++) {
        final l = page[li];
        final t = l.text.trim();
        if (running(l) || !_titleLike(t)) continue;
        final ratio = l.size / body;
        // Gövdede "Bölüm sonunda…" diye başlayan satır kalıp sayılmasın:
        // büyük harf, iri ya da kısa ve noktasız olmalı.
        if (ratio >= 0.95 &&
            t.length <= 70 &&
            isChapterLine(t) &&
            (_allCaps(t) ||
                ratio >= 1.2 ||
                (t.length <= 30 && !t.endsWith('.')))) {
          raw.add(_Cand(pi, li, t, l.size, big: true, key: true));
          continue;
        }
        if (bodyLike(t)) continue;
        if (latinDoc) {
          final (la, ar) = _scriptCounts(t);
          if (ar > la) continue;
        }
        if (ratio >= 1.2) {
          raw.add(_Cand(pi, li, t, l.size, big: true));
        } else if (ratio >= 0.95 && _allCaps(t) && t.length <= 90) {
          raw.add(_Cand(pi, li, t, l.size, big: false));
        }
      }
    }

    // Art arda 3 satırdan uzun eş boy blok başlık değil, alıntı paragrafı
    // (kalıp satırı varsa yalnız o kalır).
    final cands = <_Cand>[];
    for (var i = 0; i < raw.length;) {
      var j = i;
      while (j + 1 < raw.length &&
          raw[j + 1].page == raw[i].page &&
          raw[j + 1].line == raw[j].line + 1 &&
          (raw[j + 1].size - raw[i].size).abs() <= raw[i].size * 0.06) {
        j++;
      }
      final run = raw.sublist(i, j + 1);
      cands.addAll(run.length <= 3 ? run : run.where((c) => c.key));
      i = j + 1;
    }

    // Aşırı aday = sezgi bu belgede tutmuyor: önce büyük harf adayları,
    // sonra küçük farklar düşer.
    var kept = cands;
    final cap = math.max(8, pages.length * 4);
    if (kept.length > cap) kept = [for (final c in kept) if (c.big) c];
    if (kept.length > cap) {
      kept = [for (final c in kept) if (c.key || c.size / body >= 1.35) c];
    }
    if (kept.isEmpty) return const [];

    // 4) Aynı sayfada art arda, eş boylu satırlar tek başlık.
    final merged =
        <({int page, String text, double size, bool big, bool key})>[];
    for (var i = 0; i < kept.length; i++) {
      final c = kept[i];
      var text = c.text;
      var j = i;
      while (j + 1 < kept.length &&
          j - i < 2 &&
          kept[j + 1].page == c.page &&
          kept[j + 1].line == kept[j].line + 1 &&
          !kept[j + 1].key &&
          // "BİRİNCİ BÖLÜM" + altındaki ad tek başlık.
          ((c.key && j == i) ||
              (kept[j + 1].big == c.big &&
                  (kept[j + 1].size - c.size).abs() <= c.size * 0.06))) {
        j++;
        text = '$text ${kept[j].text}';
      }
      i = j;
      merged.add(
          (page: c.page, text: text, size: c.size, big: c.big, key: c.key));
    }

    // 5) Düzey: en büyük boy kümesi 0, gerisi 1. Yalnız büyük harf adayı
    // varsa hepsi 0; bölüm kalıbı varsa o 0, gerisi 1.
    // Kalıp satırı gövde boyunda da olabilir: yalnız gerçekten iri olanlar.
    final bigSizes = [
      for (final m in merged)
        if (m.big && m.size >= body * 1.2) m.size
    ];
    final anyKey = merged.any((m) => m.key);
    final top = bigSizes.isEmpty ? null : bigSizes.reduce(math.max);
    final out = <PdfOutlineItem>[];
    String? last;
    for (final m in merged) {
      final level = m.key
          ? 0
          : top == null
              ? (anyKey ? 1 : 0)
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

  /// Gövde cümlesine benzer: noktayla biten uzun satır ya da 14+ kelime.
  static bool bodyLike(String t) {
    if (t.endsWith('.') && !t.endsWith('..') && t.length > 40) return true;
    return t.split(RegExp(r'\s+')).length > 14;
  }

  static final _chapterRe = RegExp(
      r'^(\d+\s*[.)\-]?\s*)?(bolum|kisim|bab|fasil|fasl|unite|chapter|part)(\s|[.:\-–]|$)'
      r'|^(birinci|ikinci|ucuncu|dorduncu|besinci|altinci|yedinci|sekizinci|dokuzuncu|onuncu|\d+\.)\s+(bolum|kisim|bab|fasil|kitap|cilt)(\s|[.:\-–]|$)'
      r'|^(الباب|الفصل|باب|فصل)(\s|$)');

  /// "BÖLÜM 3", "Birinci Kısım", "2. BAB", "الفصل الأول" gibi bölüm kalıbı.
  static bool isChapterLine(String t) => _chapterRe.hasMatch(asciiFold(t));

  /// (Latin harf, Arapça harf) sayısı.
  static (int, int) _scriptCounts(String t) {
    var la = 0, ar = 0;
    for (final r in t.runes) {
      if (r >= 0x0600 && r <= 0x06FF || r >= 0xFB50 && r <= 0xFEFF) {
        ar++;
      } else if (r >= 0x41 && r <= 0x5A ||
          r >= 0x61 && r <= 0x7A ||
          r >= 0xC0 && r <= 0x24F) {
        la++;
      }
    }
    return (la, ar);
  }

  static bool _allCaps(String t) {
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(t).length;
    if (letters < 4 || t.endsWith('.')) return false;
    // Türkçe büyük harf: 'i' → 'İ' (Dart `toUpperCase` yerel-duyarsız).
    final upper = t.replaceAll('i', 'İ').toUpperCase();
    return t == upper && t != t.toLowerCase();
  }
}

class _Cand {
  final int page, line;
  final String text;
  final double size;
  final bool big, key;
  const _Cand(this.page, this.line, this.text, this.size,
      {required this.big, this.key = false});
}
