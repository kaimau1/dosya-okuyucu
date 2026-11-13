/// **PDF Pro düzenleme köprüsü** (Faz 52, PK1 adayı): görüntüleyicinin AÇIK
/// PDFium belgesinde nesne düzeyi metin düzenleme.
///
/// Her çağrı pdfrx'in PDFium işçisinde, belgenin çizimi yokken koşar
/// (`PdfDocument.computeOnIdleDocument` — `third_party/pdfrx_engine/YAMA.md`).
/// PDFium iş parçacığı güvenli değil: ikinci izolatta paralel çağrı YASAK.
///
/// Değişiklik bellekteki belgeye uygulanır, `FPDFPage_GenerateContent` ile
/// sayfa akışı yeniden üretilir; sonra çağıran `doc.reloadPages([n])` ile
/// yalnız o sayfanın önbelleğini düşürür (PK2). Kayıt artımlıdır
/// (`encodePdf(incremental: true)` → `FPDF_INCREMENTAL`, özgün baytlar korunur).
///
/// **Sessiz bozulma yok:** yeni metin yazıldıktan sonra PDFium'un kendi metin
/// çıkarıcısıyla geri okunur; tutmazsa (eksik glif, eşlenemeyen karakter)
/// eski nesneler yerine konur ve [PdfEditBridgeRefused] fırlatılır.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium_bindings;
import 'package:pdfrx/pdfrx.dart';

import 'pdf_fallback_fonts.dart';
import 'pdf_incremental_trim.dart';
import 'pdf_object_types.dart';
import 'pdf_text_blocks.dart';
import 'pdf_typeset_types.dart';

export 'pdf_fallback_fonts.dart' show PdfFallbackFonts, PdfTypesetFonts;
export 'pdf_object_types.dart';
export 'pdf_text_blocks.dart';
export 'pdf_typeset_types.dart';

part 'pdf_mutate.dart';
part 'pdf_typeset.dart';

class PdfEditBridgeRefused implements Exception {
  final String message;

  /// Ret nedeni eksik/eşlenemeyen glif mi (glif bazlı yedek gerekir — Faz 56).
  final bool glyph;
  const PdfEditBridgeRefused(this.message, {this.glyph = false});
  @override
  String toString() => message;
}

const _fpdfPageObjText = 1; // FPDF_PAGEOBJ_TEXT

final _rtl = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');

abstract final class PdfEditBridge {
  /// Sayfanın metin nesneleri (sıra, metin, kutu, font, punto, matris).
  static Future<List<PdfTextObjectInfo>> textObjects(
          PdfDocument doc, int pageIndex) async =>
      (await content(doc, pageIndex)).texts;

  /// Sayfanın bütün içerik nesneleri: metinler + yol/görsel/form kutuları.
  static Future<PdfPageContent> content(PdfDocument doc, int pageIndex) =>
      doc.computeOnIdleDocument(_readObjects, pageIndex);

  /// Blokları (paragrafları) kurar — [textObjects] + [groupTextBlocks].
  static Future<List<PdfTextBlock>> blocks(PdfDocument doc, int pageIndex,
          {PdfBlockMode mode = PdfBlockMode.paragraph}) async =>
      blocksOf(await content(doc, pageIndex), mode: mode);

  /// [content]'ten bloklar (çizgiler ve sayfa boyu dahil).
  static List<PdfTextBlock> blocksOf(PdfPageContent content,
          {PdfBlockMode mode = PdfBlockMode.paragraph}) =>
      groupTextBlocks(content.texts,
          mode: mode,
          pageHeight: content.height,
          rules: content.rules,
          bullets: content.bullets);

  /// Karakter → nesne sırası (`FPDFText_GetTextObject`); karakter sırası
  /// pdfrx'in `loadText().fullText` sırasıyla aynıdır. Nesnesi olmayan
  /// (üretilmiş boşluk) karakterde -1.
  static Future<List<int>> charObjects(PdfDocument doc, int pageIndex) =>
      doc.computeOnIdleDocument(_charObjects, pageIndex);

  /// [block]'un metnini [newText] ile değiştirir (blok biçimini, hizalamasını
  /// ve değişmeyen karakterlerin biçimini koruyarak — bkz. [typeset]).
  /// Satır sayısı artarsa blok aşağı uzar. Reddedilirse
  /// [PdfEditBridgeRefused]; belge değişmez.
  static Future<PdfTypesetResult> replaceBlock(
    PdfDocument doc,
    int pageIndex,
    PdfTextBlock block,
    String newText, {
    PdfPageContent? content,
    PdfTypesetFonts? fonts,
  }) async {
    final req = PdfBlockRequest.of(pageIndex, block,
        text: newText.replaceAll(RegExp(r'\s+'), ' ').trim(), content: content);
    final r = await typeset(doc, req, fonts: fonts);
    if (!r.ok) throw PdfEditBridgeRefused(r.error ?? 'Düzenlenemedi.', glyph: r.glyph);
    return r;
  }

  /// Bir bloğu yazar ([PdfTypesetRequest]). Eksik glif için yedek font
  /// gerekirse [PdfFallbackFonts]'tan yalnız o harfler alt kümelenip gömülür
  /// (PK5); [fonts] verilirse art arda çağrılarda (yazarken) yeniden kullanılır.
  /// Başarılıysa yalnız o sayfanın görüntü önbelleği düşer (PK2).
  static Future<PdfTypesetResult> typeset(
    PdfDocument doc,
    PdfTypesetRequest req, {
    PdfTypesetFonts? fonts,
  }) async {
    final f = fonts ?? PdfTypesetFonts();
    var r = await doc.computeOnIdleDocument(_typesetEntry, f.apply(req));
    for (var round = 0; r.error == null && r.need.isNotEmpty && round < 3; round++) {
      if (!await f.provide(r.family, r.need)) {
        return const PdfTypesetResult(
            error: 'Yazdığınız karakterlerden biri kullanılabilir yazı '
                'tiplerinde yok.',
            glyph: true);
      }
      r = await doc.computeOnIdleDocument(_typesetEntry, f.apply(req));
    }
    if (r.error == null && r.need.isNotEmpty) {
      return const PdfTypesetResult(
          error: 'Yedek yazı tipi yüklenemedi.', glyph: true);
    }
    if (r.ok && !req.dryRun) {
      await doc.reloadPages(pageNumbersToReload: [req.pageIndex + 1]);
    }
    return r;
  }

  /// Nesne düzeyi değişiklik (Faz 59): taşı/ölçekle, sil, sıra, renk, şekil ve
  /// görsel ekleme. Reddedilirse [PdfEditBridgeRefused]; belge değişmez.
  static Future<void> mutate(PdfDocument doc, PdfMutation m) async {
    final err = await doc.computeOnIdleDocument(_mutate, await _withPixels(m));
    if (err != null) throw PdfEditBridgeRefused(err);
    await doc.reloadPages(pageNumbersToReload: [m.pageIndex + 1]);
  }

  /// Görsel ekleme işlemlerine piksel verisini yükler: JPEG olduğu gibi
  /// gömülür, öbür biçimler (saydamlık dahil) BGRA'ya çözülür.
  static Future<PdfMutation> _withPixels(PdfMutation m) async {
    if (!m.actions.any((a) => a.kind == 'image' && a.jpeg == null && a.bgra == null)) {
      return m;
    }
    final out = <PdfMutAction>[];
    for (final a in m.actions) {
      if (a.kind != 'image' || a.jpeg != null || a.bgra != null) {
        out.add(a);
        continue;
      }
      final Uint8List bytes;
      try {
        bytes = await File(a.file).readAsBytes();
      } on FileSystemException {
        throw const PdfEditBridgeRefused('Görsel dosyası okunamadı.');
      }
      if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        out.add(a.withPixels(jpeg: bytes));
        continue;
      }
      final decoded = await Isolate.run(() {
        final im = img.decodeImage(bytes);
        if (im == null) return null;
        final rgba = im.convert(numChannels: 4);
        return (
          rgba.width,
          rgba.height,
          rgba.getBytes(order: img.ChannelOrder.bgra)
        );
      });
      if (decoded == null) {
        throw const PdfEditBridgeRefused('Görsel çözülemedi.');
      }
      out.add(a.withPixels(
          bgra: decoded.$3, width: decoded.$1, height: decoded.$2));
    }
    return PdfMutation(m.pageIndex, out);
  }

  /// Bir görsel nesnesinin pikselleri (BGRA) — kırpma/dışa aktarma.
  static Future<PdfImagePixels?> imagePixels(
          PdfDocument doc, int pageIndex, int objectIndex) =>
      doc.computeOnIdleDocument(_imagePixels, (pageIndex, objectIndex));

  /// Sayfanın açıklamaları (yorumlar, vurgular, çizimler — bağlantı ve form
  /// alanları hariç).
  static Future<List<PdfAnnotInfo>> annotations(
          PdfDocument doc, int pageIndex) =>
      doc.computeOnIdleDocument(_annotations, pageIndex);

  /// Açıklama ekler/siler/günceller (gerçek PDF nesnesi — başka okuyucularda
  /// da görünür ve düzenlenir).
  static Future<void> annotate(PdfDocument doc, PdfAnnotChange change) async {
    final err = await doc.computeOnIdleDocument(_annotate, change);
    if (err != null) throw PdfEditBridgeRefused(err);
    await doc.reloadPages(pageNumbersToReload: [change.pageIndex + 1]);
  }

  /// Sayfayı döndürür ([quarterTurns] 0–3; negatif = yalnız oku); önceki
  /// dönüşü verir (-1 = olmadı).
  static Future<int> rotatePage(
      PdfDocument doc, int pageIndex, int quarterTurns) async {
    final before =
        await doc.computeOnIdleDocument(_rotatePage, (pageIndex, quarterTurns));
    if (before >= 0 && quarterTurns >= 0) {
      await doc.reloadPages(pageNumbersToReload: [pageIndex + 1]);
    }
    return before;
  }

  /// İşaretli içerik (BDC/MCID — etiketli PDF yapısı) taşıyan nesnelerin
  /// sırası. `GenerateContent`'in işaretleri koruyup korumadığını ölçmek için
  /// (karar kapısı).
  static Future<List<int>> markedObjects(PdfDocument doc, int pageIndex) =>
      doc.computeOnIdleDocument(_markedObjects, pageIndex);

  /// Sayfanın **anlık görüntüsü** (Faz 54 / 1): sayfa — içerik akışı + kaynak
  /// sözlüğü — geçici bir PDFium belgesine kopyalanır (tüm belge kopyası YOK).
  /// Dönen tutamaç [restorePage] ve [releaseSnapshot] içindir; 0 = alınamadı.
  static Future<int> snapshotPage(PdfDocument doc, int pageIndex) =>
      doc.computeOnIdleDocument(_snapTake, pageIndex);

  /// [snapshot]'taki sayfayı [pageIndex]'e geri koyar: kopya aynı sıraya
  /// eklenir, eski sayfa silinir, yalnız o sayfanın önbelleği düşer (PK2).
  /// Geri konamazsa canlı belgeye dokunulmaz ve false döner.
  ///
  /// **Bedel:** geri konan sayfa belgede YENİ bir nesnedir; eski sayfaya
  /// nesne numarasıyla bakan yer imleri/bağlantılar kayıtta boşa düşerdi →
  /// oturum böyle bir geri almadan sonra kaydı canlı belgeden değil, özgünün
  /// üstünde komutları yeniden oynatarak üretir ([PdfEditSession.needsReplay]).
  static Future<bool> restorePage(
      PdfDocument doc, int pageIndex, int snapshot) async {
    if (snapshot == 0) return false;
    final ok =
        await doc.computeOnIdleDocument(_snapRestore, (pageIndex, snapshot));
    if (ok) await doc.reloadPages(pageNumbersToReload: [pageIndex + 1]);
    return ok;
  }

  /// Anlık görüntünün geçici belgesini kapatır.
  static Future<void> releaseSnapshot(PdfDocument doc, int snapshot) async {
    if (snapshot == 0) return;
    await doc.computeOnIdleDocument(_snapRelease, snapshot);
  }

  /// Artımlı kayıt baytları (özgün baytlar başta aynen durur). [original]
  /// verilirse (belgenin açıldığı baytlar) PDFium'un eki kırpılır: yalnız
  /// gerçekten değişen nesneler kalır ([PdfIncrementalTrim], PK1 koşulu 2).
  static Future<Uint8List> saveIncremental(PdfDocument doc,
      {Uint8List? original}) async {
    final out = await doc.encodePdf(incremental: true);
    return original == null ? out : PdfIncrementalTrim.trim(original, out);
  }
}

int _snapTake(pdfium_bindings.PDFium p, int docAddr, int pageIndex) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final temp = p.FPDF_CreateNewDocument();
  if (temp == nullptr) return 0;
  final ok = using((arena) {
    final idx = arena<Int>()..value = pageIndex;
    return p.FPDF_ImportPagesByIndex(temp, doc, idx, 1, 0) != 0;
  });
  if (!ok) {
    p.FPDF_CloseDocument(temp);
    return 0;
  }
  return temp.address;
}

bool _snapRestore(pdfium_bindings.PDFium p, int docAddr, (int, int) m) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final snap = pdfium_bindings.FPDF_DOCUMENT.fromAddress(m.$2);
  final count = p.FPDF_GetPageCount(doc);
  if (m.$1 < 0 || m.$1 >= count) return false;
  final ok = using((arena) {
    final idx = arena<Int>()..value = 0;
    return p.FPDF_ImportPagesByIndex(doc, snap, idx, 1, m.$1) != 0;
  });
  // Kopya eklenemediyse eski sayfa yerinde: hiçbir şey değişmedi.
  if (!ok || p.FPDF_GetPageCount(doc) != count + 1) return false;
  p.FPDFPage_Delete(doc, m.$1 + 1);
  return true;
}

bool _snapRelease(pdfium_bindings.PDFium p, int docAddr, int snapshot) {
  p.FPDF_CloseDocument(pdfium_bindings.FPDF_DOCUMENT.fromAddress(snapshot));
  return true;
}

// ── İşçi izolatında koşan işlevler (gönderilebilir: üst düzey) ────────────

PdfPageContent _readObjects(
    pdfium_bindings.PDFium p, int docAddr, int pageIndex) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final page = p.FPDF_LoadPage(doc, pageIndex);
  if (page == nullptr) return const PdfPageContent([], [], 0, 0);
  final tp = p.FPDFText_LoadPage(page);
  try {
    return using((arena) {
      // Karakterler nesnesine göre (yazım sırası = metin sayfası sırası).
      final chars = <int, List<PdfObjChar>>{};
      if (tp != nullptr) {
        final ox = arena<Double>(), oy = arena<Double>();
        final count = p.FPDFText_CountChars(tp);
        for (var c = 0; c < count; c++) {
          final obj = p.FPDFText_GetTextObject(tp, c);
          if (obj == nullptr) continue;
          p.FPDFText_GetCharOrigin(tp, c, ox, oy);
          (chars[obj.address] ??= []).add(
              PdfObjChar(p.FPDFText_GetUnicode(tp, c), ox.value, oy.value, c));
        }
      }
      final out = <PdfTextObjectInfo>[];
      final items = <PdfPageItem>[];
      final n = p.FPDFPage_CountObjects(page);
      for (var i = 0; i < n; i++) {
        final obj = p.FPDFPage_GetObject(page, i);
        if (p.FPDFPageObj_GetType(obj) != _fpdfPageObjText) {
          items.add(_item(p, arena, obj, i));
          continue;
        }
        out.add(_info(p, arena, obj, tp, i, chars[obj.address] ?? const []));
      }
      return PdfPageContent(
          out, items, p.FPDF_GetPageWidthF(page), p.FPDF_GetPageHeightF(page));
    });
  } finally {
    if (tp != nullptr) p.FPDFText_ClosePage(tp);
    p.FPDF_ClosePage(page);
  }
}

int _argb(int r, int g, int b, int a) =>
    (a & 0xFF) << 24 | (r & 0xFF) << 16 | (g & 0xFF) << 8 | (b & 0xFF);

PdfPageItem _item(pdfium_bindings.PDFium p, Arena arena,
    pdfium_bindings.FPDF_PAGEOBJECT obj, int index) {
  final l = arena<Float>(), b = arena<Float>(), r = arena<Float>(),
      t = arena<Float>();
  p.FPDFPageObj_GetBounds(obj, l, b, r, t);
  final m = arena<pdfium_bindings.FS_MATRIX>();
  p.FPDFPageObj_GetMatrix(obj, m);
  final type = p.FPDFPageObj_GetType(obj);
  var stroke = false, filled = false, straight = false;
  var fill = 0, strokeColor = 0, segments = 0, pw = 0, ph = 0;
  var strokeWidth = 0.0;
  if (type == 2) {
    final mode = arena<Int>(), st = arena<Int>();
    if (p.FPDFPath_GetDrawMode(obj, mode, st) != 0) {
      stroke = st.value != 0;
      filled = mode.value != 0;
    }
    final cr = arena<UnsignedInt>(), cg = arena<UnsignedInt>(),
        cb = arena<UnsignedInt>(), ca = arena<UnsignedInt>();
    if (p.FPDFPageObj_GetFillColor(obj, cr, cg, cb, ca) != 0) {
      fill = _argb(cr.value, cg.value, cb.value, ca.value);
    }
    if (p.FPDFPageObj_GetStrokeColor(obj, cr, cg, cb, ca) != 0) {
      strokeColor = _argb(cr.value, cg.value, cb.value, ca.value);
    }
    final w = arena<Float>();
    if (p.FPDFPageObj_GetStrokeWidth(obj, w) != 0) strokeWidth = w.value;
    segments = p.FPDFPath_CountSegments(obj);
    straight = segments > 0 && segments <= 8;
    for (var i = 0; straight && i < segments; i++) {
      // 2 = FPDF_SEGMENT_BEZIERTO
      if (p.FPDFPathSegment_GetType(p.FPDFPath_GetPathSegment(obj, i)) == 2) {
        straight = false;
      }
    }
  } else if (type == 3) {
    final w = arena<UnsignedInt>(), h = arena<UnsignedInt>();
    if (p.FPDFImageObj_GetImagePixelSize(obj, w, h) != 0) {
      pw = w.value;
      ph = h.value;
    }
  }
  var mark = '';
  if (type == 2 && p.FPDFPageObj_CountMarks(obj) > 0) {
    final len = arena<UnsignedLong>();
    final buf = arena<Uint16>(32);
    if (p.FPDFPageObjMark_GetName(
                p.FPDFPageObj_GetMark(obj, 0), buf.cast(), 64, len) !=
            0 &&
        len.value >= 2) {
      mark = String.fromCharCodes(buf.asTypedList(len.value ~/ 2 - 1));
    }
  }
  return PdfPageItem(
    index: index,
    type: type,
    mark: mark,
    left: l.value,
    bottom: b.value,
    right: r.value,
    top: t.value,
    matrix: [m.ref.a, m.ref.b, m.ref.c, m.ref.d, m.ref.e, m.ref.f],
    stroke: stroke,
    filled: filled,
    straight: straight,
    fill: fill,
    strokeColor: strokeColor,
    segments: segments,
    strokeWidth: strokeWidth,
    pixelWidth: pw,
    pixelHeight: ph,
  );
}

String _fontName(pdfium_bindings.PDFium p, Arena arena,
    pdfium_bindings.FPDF_FONT font) {
  if (font == nullptr) return '';
  final len = p.FPDFFont_GetBaseFontName(font, nullptr, 0);
  if (len <= 1) return '';
  final buf = arena<Char>(len);
  p.FPDFFont_GetBaseFontName(font, buf, len);
  // Bozuk belgede ad geçersiz UTF-8 olabilir (bulanık test bulgusu): çökme
  // yerine yer tutucu karakterle çözülür.
  final bytes = buf.cast<Uint8>().asTypedList(len);
  final end = bytes.indexOf(0);
  return utf8.decode(end < 0 ? bytes : bytes.sublist(0, end),
      allowMalformed: true);
}

PdfTextObjectInfo _info(pdfium_bindings.PDFium p, Arena arena,
    pdfium_bindings.FPDF_PAGEOBJECT obj, pdfium_bindings.FPDF_TEXTPAGE tp,
    int index, List<PdfObjChar> chars) {
  final l = arena<Float>(), b = arena<Float>(), r = arena<Float>(),
      t = arena<Float>();
  p.FPDFPageObj_GetBounds(obj, l, b, r, t);
  final size = arena<Float>();
  p.FPDFTextObj_GetFontSize(obj, size);
  final m = arena<pdfium_bindings.FS_MATRIX>();
  p.FPDFPageObj_GetMatrix(obj, m);
  var text = '';
  if (tp != nullptr) {
    final len = p.FPDFTextObj_GetText(obj, tp, nullptr, 0);
    if (len > 2) {
      final buf = arena<Uint16>(len ~/ 2 + 1);
      p.FPDFTextObj_GetText(obj, tp, buf.cast(), len);
      text = String.fromCharCodes(buf.asTypedList(len ~/ 2 - 1));
    }
  }
  final font = p.FPDFTextObj_GetFont(obj);
  final fontName = _fontName(p, arena, font);
  final quad = arena<pdfium_bindings.FS_QUADPOINTSF>();
  final hasQuad = p.FPDFPageObj_GetRotatedBounds(obj, quad) != 0;
  final cr = arena<UnsignedInt>(), cg = arena<UnsignedInt>(),
      cb = arena<UnsignedInt>(), ca = arena<UnsignedInt>();
  final hasFill = p.FPDFPageObj_GetFillColor(obj, cr, cg, cb, ca) != 0;
  return PdfTextObjectInfo(
    index: index,
    text: text,
    left: l.value,
    bottom: b.value,
    right: r.value,
    top: t.value,
    tfSize: size.value,
    fontName: fontName,
    matrix: [m.ref.a, m.ref.b, m.ref.c, m.ref.d, m.ref.e, m.ref.f],
    renderMode: p.FPDFTextObj_GetTextRenderMode(obj).value,
    fill: hasFill
        ? _argb(cr.value, cg.value, cb.value, ca.value)
        : 0xFF000000,
    fontFlags: font == nullptr ? 0 : p.FPDFFont_GetFlags(font),
    weight: font == nullptr ? 400 : p.FPDFFont_GetWeight(font),
    embedded: font != nullptr && p.FPDFFont_GetIsEmbedded(font) == 1,
    quad: hasQuad
        ? [
            quad.ref.x1, quad.ref.y1, quad.ref.x2, quad.ref.y2, //
            quad.ref.x3, quad.ref.y3, quad.ref.x4, quad.ref.y4,
          ]
        : null,
    chars: chars,
  );
}

List<int> _markedObjects(
    pdfium_bindings.PDFium p, int docAddr, int pageIndex) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final page = p.FPDF_LoadPage(doc, pageIndex);
  if (page == nullptr) return const [];
  try {
    final n = p.FPDFPage_CountObjects(page);
    return [
      for (var i = 0; i < n; i++)
        if (p.FPDFPageObj_CountMarks(p.FPDFPage_GetObject(page, i)) > 0) i,
    ];
  } finally {
    p.FPDF_ClosePage(page);
  }
}

List<int> _charObjects(pdfium_bindings.PDFium p, int docAddr, int pageIndex) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final page = p.FPDF_LoadPage(doc, pageIndex);
  if (page == nullptr) return const [];
  final tp = p.FPDFText_LoadPage(page);
  try {
    final index = <int, int>{};
    final n = p.FPDFPage_CountObjects(page);
    for (var i = 0; i < n; i++) {
      index[p.FPDFPage_GetObject(page, i).address] = i;
    }
    final count = p.FPDFText_CountChars(tp);
    return [
      for (var c = 0; c < count; c++)
        index[p.FPDFText_GetTextObject(tp, c).address] ?? -1,
    ];
  } finally {
    if (tp != nullptr) p.FPDFText_ClosePage(tp);
    p.FPDF_ClosePage(page);
  }
}

typedef _Char = (int, double, double, double, double); // kod, köken x/y, kutu sol/sağ

/// Metin sayfasındaki karakterler, nesnesine göre (üretilmiş boşluk hariç).
Map<int, List<_Char>> _charsByObject(pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_PAGE page, Arena arena, Set<int> skip) {
  final out = <int, List<_Char>>{};
  final tp = p.FPDFText_LoadPage(page);
  if (tp == nullptr) return out;
  final ox = arena<Double>(), oy = arena<Double>();
  final bl = arena<Double>(), br = arena<Double>(), bb = arena<Double>(),
      bt = arena<Double>();
  try {
    final n = p.FPDFText_CountChars(tp);
    for (var i = 0; i < n; i++) {
      final obj = p.FPDFText_GetTextObject(tp, i);
      if (obj == nullptr || skip.contains(obj.address)) continue;
      p.FPDFText_GetCharOrigin(tp, i, ox, oy);
      p.FPDFText_GetCharBox(tp, i, bl, br, bb, bt);
      (out[obj.address] ??= []).add((
        p.FPDFText_GetUnicode(tp, i),
        ox.value,
        oy.value,
        bl.value,
        br.value
      ));
    }
  } finally {
    p.FPDFText_ClosePage(tp);
  }
  return out;
}

/// [before]'daki nesnelerden, üretilmiş akış YENİDEN AYRIŞTIRILINCA ([after])
/// karakter kökenleri kayanlar → nesne → kayma. Bütün karakterler aynı
/// miktarda kaydıysa (katı kayma: baştaki `TJ` aralığı, önceki `Tc`) değer
/// (dx, dy); içeride de kaydıysa (`Tw`/`Tc`) null = sözcüklere bölünmeli.
/// Eşleme metin + yakın konumla; eşi bulunamayan da null (bölme denemesi
/// kendi denetimleriyle güvenli).
Map<int, (double, double)?> _drifted(
    Map<int, List<_Char>> before, Map<int, List<_Char>> after) {
  String key(List<_Char> l) => String.fromCharCodes([for (final c in l) c.$1]);
  final pool = <String, List<List<_Char>>>{};
  for (final l in after.values) {
    (pool[key(l)] ??= []).add(l);
  }
  final out = <int, (double, double)?>{};
  for (final e in before.entries) {
    final a = e.value;
    List<_Char>? best;
    var bestD = double.infinity;
    for (final c in pool[key(a)] ?? const <List<_Char>>[]) {
      final d = (c.first.$2 - a.first.$2).abs() + (c.first.$3 - a.first.$3).abs();
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    if (best == null || bestD > 5) {
      out[e.key] = null;
      continue;
    }
    final dx = a.first.$2 - best.first.$2, dy = a.first.$3 - best.first.$3;
    var moved = dx.abs() > 0.005 || dy.abs() > 0.005;
    var rigid = true;
    for (var k = 0; k < a.length; k++) {
      final ex = a[k].$2 - best[k].$2, ey = a[k].$3 - best[k].$3;
      if (ex.abs() > 0.005 || ey.abs() > 0.005) moved = true;
      if ((ex - dx).abs() > 0.002 || (ey - dy).abs() > 0.002) rigid = false;
    }
    if (moved) out[e.key] = rigid ? (dx, dy) : null;
  }
  return out;
}

/// **Aralık sabitleme** (Faz 54 / 0, PK1 koşulu 1).
///
/// KÖK NEDEN (Faz 52): `FPDFPage_GenerateContent` kirli içerik akışını nesne
/// modelinden yeniden üretirken metni `Tm … Tf <…> Tj` olarak yazar; `Tw`
/// (sözcük aralığı), `Tc` ve `TJ` aralıklarını YAZMAZ. Düzenlenen blokla aynı
/// akıştaki DOKUNULMAMIŞ satırlar (ReportLab `-0.09 Tw`) bu yüzden kayıyordu.
///
/// Çözüm (iki adım): [_driftTargets] PROVA sayfasında üretilen akışı bağımsız
/// bir tutamaçla yeniden ayrıştırıp kayan dokunulmamış nesneleri bulur;
/// [_pins] her birini katı kaymadaysa yerine taşır (glif kodlarına dokunmadan),
/// içeride kaydıysa sözcüklerine böler (her sözcük gerçek kökeninde ayrı
/// nesne, sözcük içinde de kaydıysa harf harf; işaretli içerik/MCID
/// taşınır). Bölme ancak her parçanın genişliği
/// özgün karakter kutularıyla tutarsa yapılır; kırpmalı/döndürülmüş nesne ya
/// da tutmayan parça (harf birleştirmeli yazı, sözcük içi `Tc`) → false:
/// düzenleme REDDEDİLİR (sessiz kayma yok, PK7).

/// Kayan dokunulmamış nesneler, DİZİNLERİYLE (düzenleme sonrası, sabitleme
/// öncesi sayfa sırası — canlı sayfada da aynısı) → katı kayma ya da null.
Map<int, (double, double)?> _driftTargets(pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_DOCUMENT doc, int pageIndex,
    pdfium_bindings.FPDF_PAGE page, Arena arena, Set<int> skip) {
  final chars = _charsByObject(p, page, arena, skip);
  if (chars.isEmpty) return const {};
  final fresh = p.FPDF_LoadPage(doc, pageIndex);
  if (fresh == nullptr) return const {};
  final Map<int, (double, double)?> drifted;
  try {
    drifted = _drifted(chars, _charsByObject(p, fresh, arena, const {}));
  } finally {
    p.FPDF_ClosePage(fresh);
  }
  final out = <int, (double, double)?>{};
  for (var i = 0; i < p.FPDFPage_CountObjects(page); i++) {
    final a = p.FPDFPage_GetObject(page, i).address;
    if (drifted.containsKey(a)) out[i] = drifted[a];
  }
  return out;
}

/// [targets]'ı sabitler ([apply] false: yalnız yapılabilir mi diye dener,
/// sayfaya dokunmaz). Yapılamıyorsa false ve sayfa değişmez.
bool _pins(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_DOCUMENT doc,
    pdfium_bindings.FPDF_PAGE page, Arena arena, Set<int> skip,
    Map<int, (double, double)?> targets,
    {required bool apply}) {
  if (targets.isEmpty) return true;
  final chars = _charsByObject(p, page, arena, skip);
  final l = arena<Float>(), b = arena<Float>(), r = arena<Float>(),
      t = arena<Float>();
  final size = arena<Float>();
  final m = arena<pdfium_bindings.FS_MATRIX>();
  final cr = arena<UnsignedInt>(), cg = arena<UnsignedInt>(),
      cb = arena<UnsignedInt>(), ca = arena<UnsignedInt>();

  // 1) Plan: her kayan nesne için ya kayma ya parçalar; biri olmazsa hiçbir
  //    şeye dokunmadan false.
  final plan = <(int, pdfium_bindings.FPDF_PAGEOBJECT, (double, double)?,
      List<pdfium_bindings.FPDF_PAGEOBJECT>)>[];
  bool fail() {
    for (final e in plan) {
      for (final o in e.$4) {
        p.FPDFPageObj_Destroy(o);
      }
    }
    return false;
  }

  for (final i in targets.keys.toList()..sort((a, b) => b.compareTo(a))) {
    final obj = p.FPDFPage_GetObject(page, i);
    final list = chars[obj.address];
    if (obj == nullptr || list == null || list.isEmpty) return fail();
    final shift = targets[i];
    if (shift != null) {
      plan.add((i, obj, shift, const []));
      continue;
    }
    if (p.FPDFPageObj_GetType(obj) != _fpdfPageObjText) return fail();
    final clip = p.FPDFPageObj_GetClipPath(obj);
    // Boş kırpma (yol sayısı ≤ 0) kırpma değildir; gerçek kırpmalı nesne
    // parçalanamaz (kırpma yolu yeni nesneye verilemiyor).
    if (clip != nullptr && p.FPDFClipPath_CountPaths(clip) > 0) return fail();
    final font = p.FPDFTextObj_GetFont(obj);
    if (font == nullptr) return fail();
    p.FPDFTextObj_GetFontSize(obj, size);
    p.FPDFPageObj_GetMatrix(obj, m);
    final mat = (m.ref.a, m.ref.b, m.ref.c, m.ref.d);
    if (mat.$2.abs() > 1e-6 || mat.$3.abs() > 1e-6) return fail(); // döndürülmüş

    pdfium_bindings.FPDF_PAGEOBJECT make(String s, double x, double y) {
      final o = p.FPDFPageObj_CreateTextObj(doc, font, size.value);
      p.FPDFText_SetText(o, s.toNativeUtf16(allocator: arena).cast());
      final mm = arena<pdfium_bindings.FS_MATRIX>();
      mm.ref
        ..a = mat.$1
        ..b = mat.$2
        ..c = mat.$3
        ..d = mat.$4
        ..e = x
        ..f = y;
      p.FPDFPageObj_SetMatrix(o, mm);
      return o;
    }

    // Sözcüklere böl: her parça gerçek kökeninde; genişliği özgün karakter
    // kutularıyla tutmalı (glif eşleşmesi / sözcük içi aralık denetimi).
    final pieces = <pdfium_bindings.FPDF_PAGEOBJECT>[];
    plan.add((i, obj, null, pieces));
    var k = 0;
    while (k < list.length) {
      if (list[k].$1 == 0x20) {
        k++;
        continue;
      }
      final st = k;
      while (k < list.length && list[k].$1 != 0x20) {
        k++;
      }
      // Parça kendi karakter kutularıyla tutuyor mu?
      bool fits(List<_Char> run) {
        final o = make(String.fromCharCodes([for (final c in run) c.$1]),
            run.first.$2, run.first.$3);
        p.FPDFPageObj_GetBounds(o, l, b, r, t);
        if ((l.value - run.first.$4).abs() > 0.02 ||
            (r.value - run.last.$5).abs() > 0.02) {
          p.FPDFPageObj_Destroy(o);
          return false;
        }
        pieces.add(o);
        return true;
      }

      // Önce sözcük; sözcük içinde de aralık varsa (Word tablo sayıları:
      // `Tc`) harf harf. Harf birleştirmeli yazıda (Arapça) harf tek başına
      // başka glif olur → tutmaz → ret.
      final word = list.sublist(st, k);
      if (!fits(word)) {
        for (final c in word) {
          if (!fits([c])) return fail();
        }
      }
    }
    if (pieces.isEmpty) return fail();
  }
  if (!apply) {
    fail(); // prova: parçaları at
    return true;
  }

  // 2) Uygula (azalan sırada: ekleme/çıkarma yalnız sonraki dizinleri kaydırır).
  for (final (i, obj, shift, pieces) in plan) {
    if (shift != null) {
      // Katı kayma: glif kodlarına dokunmadan yalnız konum düzeltilir.
      p.FPDFPageObj_Transform(obj, 1, 0, 0, 1, shift.$1, shift.$2);
      continue;
    }
    final hasFill = p.FPDFPageObj_GetFillColor(obj, cr, cg, cb, ca) != 0;
    final fill = (cr.value, cg.value, cb.value, ca.value);
    final hasStroke = p.FPDFPageObj_GetStrokeColor(obj, cr, cg, cb, ca) != 0;
    final stroke = (cr.value, cg.value, cb.value, ca.value);
    final mode = p.FPDFTextObj_GetTextRenderMode(obj);
    for (var j = 0; j < pieces.length; j++) {
      final o = pieces[j];
      if (hasFill) {
        p.FPDFPageObj_SetFillColor(o, fill.$1, fill.$2, fill.$3, fill.$4);
      }
      if (hasStroke) {
        p.FPDFPageObj_SetStrokeColor(
            o, stroke.$1, stroke.$2, stroke.$3, stroke.$4);
      }
      p.FPDFTextObj_SetTextRenderMode(o, mode);
      _copyMarks(p, doc, arena, obj, o);
      p.FPDFPage_InsertObjectAtIndex(page, o, i + 1 + j);
    }
    p.FPDFPage_RemoveObject(page, obj);
    p.FPDFPageObj_Destroy(obj);
  }
  return true;
}

/// İşaretli içerik (etiketli PDF: /Span, /P + MCID) parçalara taşınır; tam
/// sayı ve dize parametreleri kopyalanır.
void _copyMarks(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_DOCUMENT doc,
    Arena arena, pdfium_bindings.FPDF_PAGEOBJECT from,
    pdfium_bindings.FPDF_PAGEOBJECT to) {
  final len = arena<UnsignedLong>();
  final buf = arena<Uint16>(256);
  String read(int Function(Pointer<Uint16>, int, Pointer<UnsignedLong>) f) {
    if (f(buf, 512, len) == 0 || len.value < 2) return '';
    return String.fromCharCodes(buf.asTypedList(len.value ~/ 2 - 1));
  }

  for (var i = 0; i < p.FPDFPageObj_CountMarks(from); i++) {
    final mark = p.FPDFPageObj_GetMark(from, i);
    final name =
        read((b, n, o) => p.FPDFPageObjMark_GetName(mark, b.cast(), n, o));
    if (name.isEmpty) continue;
    final dst =
        p.FPDFPageObj_AddMark(to, name.toNativeUtf8(allocator: arena).cast());
    for (var k = 0; k < p.FPDFPageObjMark_CountParams(mark); k++) {
      final key = read(
          (b, n, o) => p.FPDFPageObjMark_GetParamKey(mark, k, b.cast(), n, o));
      if (key.isEmpty) continue;
      final ckey = key.toNativeUtf8(allocator: arena).cast<Char>();
      final type = p.FPDFPageObjMark_GetParamValueType(mark, ckey);
      if (type == 2) {
        final v = arena<Int>();
        if (p.FPDFPageObjMark_GetParamIntValue(mark, ckey, v) != 0) {
          p.FPDFPageObjMark_SetIntParam(doc, to, dst, ckey, v.value);
        }
      } else if (type == 3) {
        final v = read((b, n, o) =>
            p.FPDFPageObjMark_GetParamStringValue(mark, ckey, b.cast(), n, o));
        p.FPDFPageObjMark_SetStringParam(
            doc, to, dst, ckey, v.toNativeUtf8(allocator: arena).cast());
      }
    }
  }
}
