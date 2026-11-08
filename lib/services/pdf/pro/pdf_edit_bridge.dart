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

import 'pdf_incremental_trim.dart';
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

final _rtl = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');

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
    // Sağdan sola yazı (Arapça/İbranice): köprü soldan sağa, harf
    // birleştirmesiz yazar → görünüşte bozuk ama geri okumada "doğru" çıkan
    // metin. Sessiz bozulma yerine açık ret (PK7); RTL Faz 55 + 57'de.
    if (_rtl.hasMatch(block.text) || _rtl.hasMatch(newText)) {
      throw const PdfEditBridgeRefused(
          'Sağdan sola yazılan metin henüz düzenlenemiyor.');
    }
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

  /// Artımlı kayıt baytları (özgün baytlar başta aynen durur). [original]
  /// verilirse (belgenin açıldığı baytlar) PDFium'un eki kırpılır: yalnız
  /// gerçekten değişen nesneler kalır ([PdfIncrementalTrim], PK1 koşulu 2).
  static Future<Uint8List> saveIncremental(PdfDocument doc,
      {Uint8List? original}) async {
    final out = await doc.encodePdf(incremental: true);
    return original == null ? out : PdfIncrementalTrim.trim(original, out);
  }
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
    tfSize: size.value,
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
///
/// Önce **prova** (Faz 54 / 0): sayfa geçici bir belgeye kopyalanır, düzenleme
/// orada yapılır, akış üretilip yeniden ayrıştırılır ve dokunulmamış
/// satırlarda kayma varsa sabitleme planı çıkarılır. Prova geçmezse canlı
/// belgeye HİÇ dokunulmaz (PDFium'da üretilmiş akışı geri almanın yolu yok —
/// geri alma ancak böyle kusursuz). Geçerse canlıda aynı düzenleme + plan,
/// tek `GenerateContent`.
(String, bool)? _replace(
    pdfium_bindings.PDFium p, int docAddr, _ReplaceMsg m) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final temp = p.FPDF_CreateNewDocument();
  if (temp == nullptr) return ('Düzenleme için bellek ayrılamadı.', false);
  final Map<int, (double, double)?> plan;
  try {
    final r = using((arena) {
      final idx = arena<Int>()..value = m.pageIndex;
      if (p.FPDF_ImportPagesByIndex(temp, doc, idx, 1, 0) == 0) {
        return (('Sayfa kopyalanamadı.', false), null);
      }
      return _attempt(p, temp, 0, m, null);
    });
    if (r.$1 != null) return r.$1;
    plan = r.$2!;
  } finally {
    p.FPDF_CloseDocument(temp);
  }
  return _attempt(p, doc, m.pageIndex, m, plan).$1;
}

/// [plan] null = prova (akışı üretir, sabitleme planını döndürür); değilse
/// canlı uygulama.
((String, bool)?, Map<int, (double, double)?>?) _attempt(
    pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_DOCUMENT doc,
    int pageIndex,
    _ReplaceMsg m,
    Map<int, (double, double)?>? plan) {
  final page = p.FPDF_LoadPage(doc, pageIndex);
  if (page == nullptr) return (('Sayfa açılamadı.', false), null);
  try {
    return using((arena) {
      final objs = [
        for (final i in m.objectIndexes) p.FPDFPage_GetObject(page, i)
      ];
      if (objs.isEmpty || objs.any((o) => o == nullptr)) {
        return (('Blok bulunamadı (sayfa değişmiş olabilir).', false), null);
      }
      final tpl = objs.first;
      final font = p.FPDFTextObj_GetFont(tpl);
      if (font == nullptr) {
        return (('Bloğun yazı tipi okunamadı.', false), null);
      }
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
          (
            'Metin bloğa sığmıyor: ${lines.length - m.maxLines} satır fazla.',
            false
          ),
          null
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
      // Doğrulama (akış üretilmeden, bellekteki nesnelerden): PDFium yeni
      // nesnelerden aynı metni geri okuyor mu?
      final skip = {for (final o in created) o.address};
      void rollback() {
        for (final o in created) {
          p.FPDFPage_RemoveObject(page, o);
          p.FPDFPageObj_Destroy(o);
        }
        for (var k = 0; k < order.length; k++) {
          p.FPDFPage_InsertObjectAtIndex(
              page, objs[m.objectIndexes.indexOf(order[k])], order[k]);
        }
      }

      if (!_readsBack(p, page, created, m.text)) {
        rollback();
        return (
          ('Yazdığınız karakterlerden biri belgenin yazı tipinde yok.', true),
          null
        );
      }
      if (plan == null) {
        // Prova: üret, yeniden ayrıştır, kaymaları sabitlenebilir mi dene.
        p.FPDFPage_GenerateContent(page);
        final targets = _driftTargets(p, doc, pageIndex, page, arena, skip);
        for (final o in objs) {
          p.FPDFPageObj_Destroy(o);
        }
        if (!_pins(p, doc, page, arena, skip, targets, apply: false)) {
          return (
            (
              'Bu düzenleme yakındaki satırların yerini kaydırırdı; '
                  'sayfa olduğu gibi bırakıldı.',
              false
            ),
            null
          );
        }
        return (null, targets);
      }
      if (!_pins(p, doc, page, arena, skip, plan, apply: true)) {
        rollback(); // prova geçti, canlı tutmadı: hiçbir şey yazılmadan dön
        return (('Sayfa provadakinden farklı; düzenleme yapılmadı.', false), null);
      }
      p.FPDFPage_GenerateContent(page);
      for (final o in objs) {
        p.FPDFPageObj_Destroy(o);
      }
      return (null, null);
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
