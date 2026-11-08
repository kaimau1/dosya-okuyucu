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

import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium_bindings;
import 'package:pdfrx/pdfrx.dart';

import 'pdf_text_blocks.dart';

export 'pdf_text_blocks.dart';

class PdfEditBridgeRefused implements Exception {
  final String message;

  /// Ret nedeni eksik/eşlenemeyen glif mi (glif bazlı yedek gerekir — Faz 56).
  final bool glyph;
  const PdfEditBridgeRefused(this.message, {this.glyph = false});
  @override
  String toString() => message;
}

const _fpdfPageObjText = 1; // FPDF_PAGEOBJ_TEXT

abstract final class PdfEditBridge {
  /// Sayfanın metin nesneleri (sıra, metin, kutu, font, punto, matris).
  static Future<List<PdfTextObjectInfo>> textObjects(
          PdfDocument doc, int pageIndex) =>
      doc.computeOnIdleDocument(_readObjects, pageIndex);

  /// Blokları (paragrafları) kurar — [textObjects] + [groupTextBlocks].
  static Future<List<PdfTextBlock>> blocks(PdfDocument doc, int pageIndex) async =>
      groupTextBlocks(await textObjects(doc, pageIndex));

  /// Karakter → nesne sırası (`FPDFText_GetTextObject`); karakter sırası
  /// pdfrx'in `loadText().fullText` sırasıyla aynıdır. Nesnesi olmayan
  /// (üretilmiş boşluk) karakterde -1.
  static Future<List<int>> charObjects(PdfDocument doc, int pageIndex) =>
      doc.computeOnIdleDocument(_charObjects, pageIndex);

  /// [block]'un metnini [newText] ile değiştirir: eski nesneler kalkar, aynı
  /// font, punto, renk ve matrisle satır satır yeni nesneler yazılır (sola
  /// yaslı sarma, özgün satır aralığı). Satır sayısı artarsa reddeder.
  /// Başarılıysa sayfanın görüntü önbelleği düşürülür (yalnız o sayfa).
  static Future<void> replaceBlock(
    PdfDocument doc,
    int pageIndex,
    PdfTextBlock block,
    String newText,
  ) async {
    final lines = block.lines;
    final baselines = [for (final l in lines) l.baseline];
    final leading = lines.length > 1
        ? (baselines.first - baselines.last) / (lines.length - 1)
        : lines.first.size * 1.2;
    final msg = _ReplaceMsg(
      pageIndex: pageIndex,
      objectIndexes: block.objectIndexes,
      text: newText.replaceAll(RegExp(r'\s+'), ' ').trim(),
      firstX: lines.first.objects.first.matrix[4],
      bodyX: lines.length > 1
          ? lines.skip(1).map((l) => l.objects.first.matrix[4]).reduce(math.min)
          : lines.first.objects.first.matrix[4],
      width: block.right - block.left,
      firstBaseline: baselines.first,
      leading: leading,
      maxLines: lines.length,
    );
    final err = await doc.computeOnIdleDocument(_replace, msg);
    if (err != null) throw PdfEditBridgeRefused(err.$1, glyph: err.$2);
    await doc.reloadPages(pageNumbersToReload: [pageIndex + 1]);
  }

  /// İşaretli içerik (BDC/MCID — etiketli PDF yapısı) taşıyan nesnelerin
  /// sırası. `GenerateContent`'in işaretleri koruyup korumadığını ölçmek için
  /// (karar kapısı).
  static Future<List<int>> markedObjects(PdfDocument doc, int pageIndex) =>
      doc.computeOnIdleDocument(_markedObjects, pageIndex);

  /// Artımlı kayıt baytları (özgün baytlar başta aynen durur).
  static Future<Uint8List> saveIncremental(PdfDocument doc) =>
      doc.encodePdf(incremental: true);
}

class _ReplaceMsg {
  final int pageIndex;
  final List<int> objectIndexes;
  final String text;
  final double firstX, bodyX, width, firstBaseline, leading;
  final int maxLines;
  const _ReplaceMsg({
    required this.pageIndex,
    required this.objectIndexes,
    required this.text,
    required this.firstX,
    required this.bodyX,
    required this.width,
    required this.firstBaseline,
    required this.leading,
    required this.maxLines,
  });
}

// ── İşçi izolatında koşan işlevler (gönderilebilir: üst düzey) ────────────

List<PdfTextObjectInfo> _readObjects(
    pdfium_bindings.PDFium p, int docAddr, int pageIndex) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final page = p.FPDF_LoadPage(doc, pageIndex);
  if (page == nullptr) return const [];
  final tp = p.FPDFText_LoadPage(page);
  try {
    return using((arena) {
      final out = <PdfTextObjectInfo>[];
      final n = p.FPDFPage_CountObjects(page);
      for (var i = 0; i < n; i++) {
        final obj = p.FPDFPage_GetObject(page, i);
        if (p.FPDFPageObj_GetType(obj) != _fpdfPageObjText) continue;
        out.add(_info(p, arena, obj, tp, i));
      }
      return out;
    });
  } finally {
    if (tp != nullptr) p.FPDFText_ClosePage(tp);
    p.FPDF_ClosePage(page);
  }
}

PdfTextObjectInfo _info(pdfium_bindings.PDFium p, Arena arena,
    pdfium_bindings.FPDF_PAGEOBJECT obj, pdfium_bindings.FPDF_TEXTPAGE tp,
    int index) {
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
  var fontName = '';
  final font = p.FPDFTextObj_GetFont(obj);
  if (font != nullptr) {
    final len = p.FPDFFont_GetBaseFontName(font, nullptr, 0);
    if (len > 1) {
      final buf = arena<Char>(len);
      p.FPDFFont_GetBaseFontName(font, buf, len);
      fontName = buf.cast<Utf8>().toDartString();
    }
  }
  return PdfTextObjectInfo(
    index: index,
    text: text,
    left: l.value,
    bottom: b.value,
    right: r.value,
    top: t.value,
    fontSize: size.value,
    fontName: fontName,
    matrix: [m.ref.a, m.ref.b, m.ref.c, m.ref.d, m.ref.e, m.ref.f],
    renderMode: p.FPDFTextObj_GetTextRenderMode(obj).value,
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

/// null = başarılı; değilse (neden, glif mi).
(String, bool)? _replace(
    pdfium_bindings.PDFium p, int docAddr, _ReplaceMsg m) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final page = p.FPDF_LoadPage(doc, m.pageIndex);
  if (page == nullptr) return ('Sayfa açılamadı.', false);
  try {
    return using((arena) {
      final objs = [
        for (final i in m.objectIndexes) p.FPDFPage_GetObject(page, i)
      ];
      if (objs.isEmpty || objs.any((o) => o == nullptr)) {
        return ('Blok bulunamadı (sayfa değişmiş olabilir).', false);
      }
      final tpl = objs.first;
      final font = p.FPDFTextObj_GetFont(tpl);
      if (font == nullptr) return ('Bloğun yazı tipi okunamadı.', false);
      final sizeP = arena<Float>();
      p.FPDFTextObj_GetFontSize(tpl, sizeP);
      final size = sizeP.value;
      final mat = arena<pdfium_bindings.FS_MATRIX>();
      p.FPDFPageObj_GetMatrix(tpl, mat);
      final (a, b, c, d) = (mat.ref.a, mat.ref.b, mat.ref.c, mat.ref.d);
      final rr = arena<UnsignedInt>(), gg = arena<UnsignedInt>(),
          bb = arena<UnsignedInt>(), aa = arena<UnsignedInt>();
      final hasFill = p.FPDFPageObj_GetFillColor(tpl, rr, gg, bb, aa) != 0;
      final mode = p.FPDFTextObj_GetTextRenderMode(tpl);

      pdfium_bindings.FPDF_PAGEOBJECT make(String s, double x, double y) {
        final o = p.FPDFPageObj_CreateTextObj(doc, font, size);
        final w = s.toNativeUtf16(allocator: arena);
        p.FPDFText_SetText(o, w.cast());
        final mm = arena<pdfium_bindings.FS_MATRIX>();
        mm.ref
          ..a = a
          ..b = b
          ..c = c
          ..d = d
          ..e = x
          ..f = y;
        p.FPDFPageObj_SetMatrix(o, mm);
        if (hasFill) {
          p.FPDFPageObj_SetFillColor(o, rr.value, gg.value, bb.value, aa.value);
        }
        p.FPDFTextObj_SetTextRenderMode(o, mode);
        return o;
      }

      final l = arena<Float>(), bt = arena<Float>(), r = arena<Float>(),
          t = arena<Float>();
      double measure(String s) {
        if (s.isEmpty) return 0;
        final o = make(s, 0, 0);
        p.FPDFPageObj_GetBounds(o, l, bt, r, t);
        final w = r.value - l.value;
        p.FPDFPageObj_Destroy(o);
        return w;
      }

      // Sarma: sözcük sözcük, ölçüm PDFium'un kendi glif kutularıyla.
      final words = m.text.split(' ');
      final lines = <String>[];
      var cur = '';
      // Tek satırlık blok (başlık, hücre dışı satır) kendi genişliğine değil
      // sayfanın simetrik metin alanına kadar uzayabilir.
      final width = m.maxLines == 1
          ? math.max(m.width, p.FPDF_GetPageWidthF(page) - 2 * m.firstX)
          : m.width;
      final limit = width + size * 0.5; // kutu glif kenarından ölçüldü
      for (final w in words) {
        final cand = cur.isEmpty ? w : '$cur $w';
        if (cur.isNotEmpty && measure(cand) > limit) {
          lines.add(cur);
          cur = w;
        } else {
          cur = cand;
        }
      }
      if (cur.isNotEmpty) lines.add(cur);
      if (lines.length > m.maxLines) {
        return (
          'Metin bloğa sığmıyor: ${lines.length - m.maxLines} satır fazla.',
          false
        );
      }

      // Eski nesneleri sayfadan al (yok etme — doğrulama tutmazsa geri konur).
      final order = [...m.objectIndexes]..sort();
      for (final i in order.reversed) {
        p.FPDFPage_RemoveObject(page, p.FPDFPage_GetObject(page, i));
      }
      final created = <pdfium_bindings.FPDF_PAGEOBJECT>[];
      for (var i = 0; i < lines.length; i++) {
        final o = make(lines[i], i == 0 ? m.firstX : m.bodyX,
            m.firstBaseline - i * m.leading);
        p.FPDFPage_InsertObject(page, o);
        created.add(o);
      }
      p.FPDFPage_GenerateContent(page);

      // Doğrulama: PDFium yeni nesnelerden aynı metni geri okuyor mu?
      final ok = _readsBack(p, page, created, m.text);
      if (ok) {
        for (final o in objs) {
          p.FPDFPageObj_Destroy(o);
        }
        return null;
      }
      for (final o in created) {
        p.FPDFPage_RemoveObject(page, o);
        p.FPDFPageObj_Destroy(o);
      }
      for (var k = 0; k < order.length; k++) {
        p.FPDFPage_InsertObjectAtIndex(
            page, objs[m.objectIndexes.indexOf(order[k])], order[k]);
      }
      p.FPDFPage_GenerateContent(page);
      return (
        'Yazdığınız karakterlerden biri belgenin yazı tipinde yok.',
        true
      );
    });
  } finally {
    p.FPDF_ClosePage(page);
  }
}

bool _readsBack(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_PAGE page,
    List<pdfium_bindings.FPDF_PAGEOBJECT> created, String text) {
  final tp = p.FPDFText_LoadPage(page);
  if (tp == nullptr) return false;
  try {
    final mine = {for (final o in created) o.address};
    final b = StringBuffer();
    final n = p.FPDFText_CountChars(tp);
    var inMine = false;
    for (var i = 0; i < n; i++) {
      final obj = p.FPDFText_GetTextObject(tp, i);
      if (mine.contains(obj.address)) {
        inMine = true;
        b.writeCharCode(p.FPDFText_GetUnicode(tp, i));
      } else if (obj == nullptr && inMine) {
        // PDFium'un geometriden ÜRETTİĞİ boşluk/satır sonu: nesnesi yok.
        b.writeCharCode(p.FPDFText_GetUnicode(tp, i));
      } else {
        inMine = false;
      }
    }
    // Boşluklar da ŞART: fontta boşluk glifi yoksa (ör. Dart `pdf` paketi
    // alt kümeleri) sözcükler bitişik çıkar — sessizce "başarılı" denmez.
    String norm(String s) => s
        .replaceAll(RegExp(r'[\u0000-\u0008\u000e-\u001f￾]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return norm(b.toString()) == norm(text);
  } finally {
    p.FPDFText_ClosePage(tp);
  }
}
