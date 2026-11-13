part of 'pdf_edit_bridge.dart';

// ── Nesne işlemleri (Faz 59) ─────────────────────────────────────────────
//
// Yazıcıyla aynı güvence: önce sayfanın geçici kopyasında PROVA (akış üretilir,
// yeniden ayrıştırılır, dokunulmamış metin kayıyorsa sabitlenebilir mi diye
// bakılır), sonra canlı belgede aynı işlem + sabitleme, tek `GenerateContent`.

int _jpegBlock(Pointer<Void> param, int position, Pointer<UnsignedChar> buf,
    int size) {
  buf
      .cast<Uint8>()
      .asTypedList(size)
      .setAll(0, (param.cast<Uint8>() + position).asTypedList(size));
  return 1;
}

/// null = başarılı; değilse ret nedeni.
String? _mutate(pdfium_bindings.PDFium p, int docAddr, PdfMutation m) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final temp = p.FPDF_CreateNewDocument();
  if (temp == nullptr) return 'Düzenleme için bellek ayrılamadı.';
  final Map<int, (double, double)?> plan;
  try {
    final r = using((arena) {
      final idx = arena<Int>()..value = m.pageIndex;
      if (p.FPDF_ImportPagesByIndex(temp, doc, idx, 1, 0) == 0) {
        return ('Sayfa kopyalanamadı.', null);
      }
      return _mutateOn(p, temp, 0, m, null);
    });
    if (r.$1 != null) return r.$1;
    plan = r.$2!;
  } finally {
    p.FPDF_CloseDocument(temp);
  }
  return _mutateOn(p, doc, m.pageIndex, m, plan).$1;
}

(String?, Map<int, (double, double)?>?) _mutateOn(
    pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_DOCUMENT doc,
    int pageIndex,
    PdfMutation m,
    Map<int, (double, double)?>? plan) {
  final page = p.FPDF_LoadPage(doc, pageIndex);
  if (page == nullptr) return ('Sayfa açılamadı.', null);
  try {
    return using((arena) {
      final count = p.FPDFPage_CountObjects(page);
      // Dizinler işlem ÖNCESİ sayfaya göredir: önce hepsi tutamaca çevrilir.
      final handles = <int, pdfium_bindings.FPDF_PAGEOBJECT>{};
      for (final a in m.actions) {
        for (final i in a.objects) {
          if (i < 0 || i >= count) {
            return ('Nesne bulunamadı (sayfa değişmiş olabilir).', null);
          }
          handles[i] = p.FPDFPage_GetObject(page, i);
        }
      }
      final created = <pdfium_bindings.FPDF_PAGEOBJECT>[];
      final removed = <pdfium_bindings.FPDF_PAGEOBJECT>[];
      var flatten = false;
      void color(pdfium_bindings.FPDF_PAGEOBJECT o, int argb, bool stroke) {
        final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
        final a = (argb >> 24) & 0xFF;
        if (stroke) {
          p.FPDFPageObj_SetStrokeColor(o, r, g, b, a);
        } else {
          p.FPDFPageObj_SetFillColor(o, r, g, b, a);
        }
      }

      for (final a in m.actions) {
        switch (a.kind) {
          case 'transform':
            for (final i in a.objects) {
              p.FPDFPageObj_Transform(handles[i]!, a.matrix[0], a.matrix[1],
                  a.matrix[2], a.matrix[3], a.matrix[4], a.matrix[5]);
            }
          case 'delete':
            for (final i in a.objects) {
              final o = handles[i]!;
              if (removed.any((x) => x.address == o.address)) continue;
              p.FPDFPage_RemoveObject(page, o);
              removed.add(o);
            }
          case 'order':
            final o = handles[a.objects.first]!;
            p.FPDFPage_RemoveObject(page, o);
            if (a.to < 0) {
              p.FPDFPage_InsertObject(page, o);
            } else {
              p.FPDFPage_InsertObjectAtIndex(page, o, a.to);
            }
          case 'style':
            for (final i in a.objects) {
              final o = handles[i]!;
              if (a.fill != 0) color(o, a.fill, false);
              if (a.stroke != 0) color(o, a.stroke, true);
              if (a.strokeWidth > 0) {
                p.FPDFPageObj_SetStrokeWidth(o, a.strokeWidth);
              }
            }
          case 'shape':
            final o = _shape(p, a);
            if (o == nullptr) return ('Şekil oluşturulamadı.', null);
            if (a.stroke != 0) color(o, a.stroke, true);
            if (a.fill != 0) color(o, a.fill, false);
            p.FPDFPageObj_SetStrokeWidth(o, a.strokeWidth <= 0 ? 1 : a.strokeWidth);
            p.FPDFPath_SetDrawMode(
                o, a.fill != 0 ? 1 : 0, a.stroke != 0 ? 1 : 0);
            // Silgi bizim şeklimizi tanısın (sayfanın kendi çizimine dokunmaz).
            p.FPDFPageObj_AddMark(
                o, pdfShapeMark.toNativeUtf8(allocator: arena).cast());
            p.FPDFPage_InsertObject(page, o);
            created.add(o);
          case 'image':
            final o = _image(p, doc, arena, a);
            if (o == nullptr) return ('Görsel eklenemedi.', null);
            final mm = arena<pdfium_bindings.FS_MATRIX>();
            mm.ref
              ..a = a.matrix[0]
              ..b = a.matrix[1]
              ..c = a.matrix[2]
              ..d = a.matrix[3]
              ..e = a.matrix[4]
              ..f = a.matrix[5];
            p.FPDFPageObj_SetMatrix(o, mm);
            p.FPDFPage_InsertObject(page, o);
            created.add(o);
          case 'redact':
            final err = _redact(p, doc, page, arena, a.matrix, created, removed);
            if (err != null) return (err, null);
          case 'flatten':
            flatten = true;
          default:
            return ('Bilinmeyen işlem.', null);
        }
      }
      final skip = {for (final o in created) o.address};
      if (plan == null) {
        p.FPDFPage_GenerateContent(page);
        final targets = _driftTargets(p, doc, pageIndex, page, arena, skip);
        for (final o in removed) {
          p.FPDFPageObj_Destroy(o);
        }
        if (!_pins(p, doc, page, arena, skip, targets, apply: false)) {
          return (
            'Bu düzenleme yakındaki satırların yerini kaydırırdı; '
                'sayfa olduğu gibi bırakıldı.',
            null
          );
        }
        return (null, targets);
      }
      if (!_pins(p, doc, page, arena, skip, plan, apply: true)) {
        return ('Sayfa provadakinden farklı; düzenleme yapılmadı.', null);
      }
      p.FPDFPage_GenerateContent(page);
      for (final o in removed) {
        p.FPDFPageObj_Destroy(o);
      }
      // 0 = FLAT_NORMALDISPLAY; 0 = FLATTEN_FAIL.
      if (flatten && p.FPDFPage_Flatten(page, 0) == 0) {
        return ('Açıklamalar içeriğe gömülemedi.', null);
      }
      return (null, null);
    });
  } finally {
    p.FPDF_ClosePage(page);
  }
}

pdfium_bindings.FPDF_PAGEOBJECT _shape(
    pdfium_bindings.PDFium p, PdfMutAction a) {
  final l = math.min(a.x0, a.x1), r = math.max(a.x0, a.x1);
  final b = math.min(a.y0, a.y1), t = math.max(a.y0, a.y1);
  switch (a.shape) {
    case PdfShapeKind.rect:
      return p.FPDFPageObj_CreateNewRect(l, b, r - l, t - b);
    case PdfShapeKind.ellipse:
      // Dört Bézier yayı (k = 0,5523).
      final cx = (l + r) / 2, cy = (b + t) / 2;
      final rx = (r - l) / 2, ry = (t - b) / 2;
      const k = 0.5522847498;
      final o = p.FPDFPageObj_CreateNewPath(cx + rx, cy);
      p.FPDFPath_BezierTo(o, cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry);
      p.FPDFPath_BezierTo(o, cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy);
      p.FPDFPath_BezierTo(o, cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry);
      p.FPDFPath_BezierTo(o, cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy);
      p.FPDFPath_Close(o);
      return o;
    case PdfShapeKind.line:
    case PdfShapeKind.arrow:
      final o = p.FPDFPageObj_CreateNewPath(a.x0, a.y0);
      p.FPDFPath_LineTo(o, a.x1, a.y1);
      if (a.shape == PdfShapeKind.arrow) {
        final ang = math.atan2(a.y1 - a.y0, a.x1 - a.x0);
        final len = math.max(6.0, a.strokeWidth * 5);
        for (final d in const [2.6, -2.6]) {
          p.FPDFPath_MoveTo(o, a.x1, a.y1);
          p.FPDFPath_LineTo(o, a.x1 + len * math.cos(ang + d),
              a.y1 + len * math.sin(ang + d));
        }
      }
      return o;
  }
}

pdfium_bindings.FPDF_PAGEOBJECT _image(pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_DOCUMENT doc, Arena arena, PdfMutAction a) {
  final o = p.FPDFPageObj_NewImageObj(doc);
  if (o == nullptr) return nullptr;
  final jpeg = a.jpeg, bgra = a.bgra;
  if (jpeg != null) {
    final buf = arena<Uint8>(jpeg.length);
    buf.asTypedList(jpeg.length).setAll(0, jpeg);
    final fa = arena<pdfium_bindings.FPDF_FILEACCESS>();
    fa.ref
      ..m_FileLen = jpeg.length
      ..m_GetBlock = Pointer.fromFunction<
          Int Function(Pointer<Void>, UnsignedLong, Pointer<UnsignedChar>,
              UnsignedLong)>(_jpegBlock, 0)
      ..m_Param = buf.cast();
    if (p.FPDFImageObj_LoadJpegFileInline(nullptr, 0, o, fa) != 0) return o;
  } else if (bgra != null && a.pixelWidth > 0 && a.pixelHeight > 0) {
    final buf = arena<Uint8>(bgra.length);
    buf.asTypedList(bgra.length).setAll(0, bgra);
    // 4 = FPDFBitmap_BGRA
    final bmp = p.FPDFBitmap_CreateEx(
        a.pixelWidth, a.pixelHeight, 4, buf.cast(), a.pixelWidth * 4);
    if (bmp != nullptr) {
      final ok = p.FPDFImageObj_SetBitmap(nullptr, 0, o, bmp) != 0;
      p.FPDFBitmap_Destroy(bmp);
      if (ok) return o;
    }
  }
  p.FPDFPageObj_Destroy(o);
  return nullptr;
}

/// Görsel nesnesinin pikselleri (BGRA) — kırpma/dışa aktarma için.
PdfImagePixels? _imagePixels(
    pdfium_bindings.PDFium p, int docAddr, (int, int) m) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final page = p.FPDF_LoadPage(doc, m.$1);
  if (page == nullptr) return null;
  try {
    final obj = p.FPDFPage_GetObject(page, m.$2);
    if (obj == nullptr || p.FPDFPageObj_GetType(obj) != 3) return null;
    final bmp = p.FPDFImageObj_GetBitmap(obj);
    if (bmp == nullptr) return null;
    try {
      return _bitmapPixels(p, bmp);
    } finally {
      p.FPDFBitmap_Destroy(bmp);
    }
  } finally {
    p.FPDF_ClosePage(page);
  }
}

/// PDFium bit eşlemini BGRA'ya çevirir (çok büyükse null).
PdfImagePixels? _bitmapPixels(
    pdfium_bindings.PDFium p, pdfium_bindings.FPDF_BITMAP bmp) {
  final w = p.FPDFBitmap_GetWidth(bmp), h = p.FPDFBitmap_GetHeight(bmp);
  final stride = p.FPDFBitmap_GetStride(bmp);
  final fmt = p.FPDFBitmap_GetFormat(bmp);
  final src = p.FPDFBitmap_GetBuffer(bmp).cast<Uint8>();
  if (w <= 0 || h <= 0 || src == nullptr || w * h > 40000000) return null;
  final out = Uint8List(w * h * 4);
  final data = src.asTypedList(stride * h);
  for (var y = 0; y < h; y++) {
    final row = y * stride, dst = y * w * 4;
    for (var x = 0; x < w; x++) {
      switch (fmt) {
        case 1: // Gray
          final v = data[row + x];
          out[dst + x * 4] = v;
          out[dst + x * 4 + 1] = v;
          out[dst + x * 4 + 2] = v;
          out[dst + x * 4 + 3] = 255;
        case 2: // BGR
          out[dst + x * 4] = data[row + x * 3];
          out[dst + x * 4 + 1] = data[row + x * 3 + 1];
          out[dst + x * 4 + 2] = data[row + x * 3 + 2];
          out[dst + x * 4 + 3] = 255;
        case 3: // BGRx
          out[dst + x * 4] = data[row + x * 4];
          out[dst + x * 4 + 1] = data[row + x * 4 + 1];
          out[dst + x * 4 + 2] = data[row + x * 4 + 2];
          out[dst + x * 4 + 3] = 255;
        default: // BGRA
          out[dst + x * 4] = data[row + x * 4];
          out[dst + x * 4 + 1] = data[row + x * 4 + 1];
          out[dst + x * 4 + 2] = data[row + x * 4 + 2];
          out[dst + x * 4 + 3] = data[row + x * 4 + 3];
      }
    }
  }
  return PdfImagePixels(w, h, out);
}

// ── Gerçek karartma (Faz 64 / 1) ─────────────────────────────────────────
//
// Sızıntı 0 hedefi: bölgeye DEĞEN her karakter metinden çıkar. Kalan
// karakterler özgün konumlarında yeniden yazılır; yeri doğrulanamayan nesne
// TAMAMEN kaldırılır (az karartmak yerine fazla karartmak). Görselde yalnız
// bölgenin pikselleri siyaha boyanır; döndürülmüş görsel bütünüyle kalkar.

const _markRedact = 'DOrd';

/// İşaretleme aracının çizdiği şekil (dikdörtgen, elips, çizgi, ok) — Silgi
/// yalnız bunları siler. `DO` önekli DEĞİL: Görsel aracı da seçebilsin.
const pdfShapeMark = 'PPsh';

/// null = başarılı. [created] ve [removed] çağıranın listelerine eklenir.
String? _redact(
    pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_DOCUMENT doc,
    pdfium_bindings.FPDF_PAGE page,
    Arena arena,
    List<double> flat,
    List<pdfium_bindings.FPDF_PAGEOBJECT> created,
    List<pdfium_bindings.FPDF_PAGEOBJECT> removed) {
  final rects = <(double, double, double, double)>[];
  for (var i = 0; i + 3 < flat.length; i += 4) {
    rects.add((
      math.min(flat[i], flat[i + 2]),
      math.min(flat[i + 1], flat[i + 3]),
      math.max(flat[i], flat[i + 2]),
      math.max(flat[i + 1], flat[i + 3])
    ));
  }
  if (rects.isEmpty) return 'Karartılacak alan yok.';
  bool touches(double l, double b, double r, double t) => rects.any(
      (q) => l < q.$3 && r > q.$1 && b < q.$4 && t > q.$2);
  bool inside(double l, double b, double r, double t) => rects.any((q) =>
      l >= q.$1 - 0.5 && r <= q.$3 + 0.5 && b >= q.$2 - 0.5 && t <= q.$4 + 0.5);

  // Karakterler nesnesine göre: kod, köken, kutu.
  final chars = <int, List<(int, double, double, double, double, double, double)>>{};
  final tp = p.FPDFText_LoadPage(page);
  if (tp != nullptr) {
    final ox = arena<Double>(), oy = arena<Double>();
    final bl = arena<Double>(), br = arena<Double>(), bb = arena<Double>(),
        bt = arena<Double>();
    final n = p.FPDFText_CountChars(tp);
    for (var i = 0; i < n; i++) {
      final obj = p.FPDFText_GetTextObject(tp, i);
      if (obj == nullptr) continue;
      p.FPDFText_GetCharOrigin(tp, i, ox, oy);
      p.FPDFText_GetCharBox(tp, i, bl, br, bb, bt);
      (chars[obj.address] ??= []).add((
        p.FPDFText_GetUnicode(tp, i),
        ox.value,
        oy.value,
        bl.value,
        br.value,
        bb.value,
        bt.value
      ));
    }
    p.FPDFText_ClosePage(tp);
  }

  final l = arena<Float>(), b = arena<Float>(), r = arena<Float>(),
      t = arena<Float>();
  final size = arena<Float>();
  final m = arena<pdfium_bindings.FS_MATRIX>();
  final cr = arena<UnsignedInt>(), cg = arena<UnsignedInt>(),
      cb = arena<UnsignedInt>(), ca = arena<UnsignedInt>();
  // Sondan başa: çıkarma/ekleme yalnız sonraki dizinleri kaydırır.
  for (var i = p.FPDFPage_CountObjects(page) - 1; i >= 0; i--) {
    final obj = p.FPDFPage_GetObject(page, i);
    if (obj == nullptr || created.any((o) => o.address == obj.address)) continue;
    p.FPDFPageObj_GetBounds(obj, l, b, r, t);
    if (!touches(l.value, b.value, r.value, t.value)) continue;
    void drop() {
      p.FPDFPage_RemoveObject(page, obj);
      removed.add(obj);
    }

    final type = p.FPDFPageObj_GetType(obj);
    if (type == _fpdfPageObjText) {
      final list = chars[obj.address] ?? const [];
      final keep = [
        for (final c in list)
          // Kutusu olmayan (boşluk) karakter, kökeni bölgedeyse gider.
          !(c.$5 > c.$4
              ? touches(c.$4, c.$6, c.$5, c.$7)
              : touches(c.$2 - 0.1, c.$3 - 0.1, c.$2 + 0.1, c.$3 + 0.1))
      ];
      if (list.isEmpty || !keep.contains(true)) {
        drop();
        continue;
      }
      if (!keep.contains(false)) continue; // kutu değdi ama hiçbir harf değmedi
      final font = p.FPDFTextObj_GetFont(obj);
      p.FPDFTextObj_GetFontSize(obj, size);
      p.FPDFPageObj_GetMatrix(obj, m);
      final mat = (m.ref.a, m.ref.b, m.ref.c, m.ref.d);
      final clip = p.FPDFPageObj_GetClipPath(obj);
      if (font == nullptr ||
          mat.$2.abs() > 1e-6 ||
          mat.$3.abs() > 1e-6 ||
          (clip != nullptr && p.FPDFClipPath_CountPaths(clip) > 0)) {
        drop(); // döndürülmüş/kırpmalı: güvenle bölünemez → tamamı gider
        continue;
      }
      final hasFill = p.FPDFPageObj_GetFillColor(obj, cr, cg, cb, ca) != 0;
      final fill = (cr.value, cg.value, cb.value, ca.value);
      final mode = p.FPDFTextObj_GetTextRenderMode(obj);
      final pieces = <pdfium_bindings.FPDF_PAGEOBJECT>[];
      bool fits(int from, int to) {
        final o = p.FPDFPageObj_CreateTextObj(doc, font, size.value);
        final s = String.fromCharCodes([for (var k = from; k < to; k++) list[k].$1]);
        p.FPDFText_SetText(o, s.toNativeUtf16(allocator: arena).cast());
        final mm = arena<pdfium_bindings.FS_MATRIX>();
        mm.ref
          ..a = mat.$1
          ..b = mat.$2
          ..c = mat.$3
          ..d = mat.$4
          ..e = list[from].$2
          ..f = list[from].$3;
        p.FPDFPageObj_SetMatrix(o, mm);
        p.FPDFPageObj_GetBounds(o, l, b, r, t);
        if ((l.value - list[from].$4).abs() > 0.05 ||
            (r.value - list[to - 1].$5).abs() > 0.05) {
          p.FPDFPageObj_Destroy(o);
          return false;
        }
        if (hasFill) {
          p.FPDFPageObj_SetFillColor(o, fill.$1, fill.$2, fill.$3, fill.$4);
        }
        p.FPDFTextObj_SetTextRenderMode(o, mode);
        pieces.add(o);
        return true;
      }

      var ok = true;
      var k = 0;
      while (ok && k < list.length) {
        if (!keep[k] || list[k].$1 == 0x20) {
          k++;
          continue;
        }
        final st = k;
        while (k < list.length && keep[k] && list[k].$1 != 0x20) {
          k++;
        }
        if (!fits(st, k)) {
          for (var q = st; ok && q < k; q++) {
            ok = fits(q, q + 1);
          }
        }
      }
      if (!ok) {
        for (final o in pieces) {
          p.FPDFPageObj_Destroy(o);
        }
        drop(); // yeri doğrulanamadı: nesnenin tamamı kaldırılır
        continue;
      }
      for (var j = 0; j < pieces.length; j++) {
        _copyMarks(p, doc, arena, obj, pieces[j]);
        p.FPDFPage_InsertObjectAtIndex(page, pieces[j], i + 1 + j);
        created.add(pieces[j]);
      }
      drop();
    } else if (type == 3) {
      if (inside(l.value, b.value, r.value, t.value)) {
        drop();
        continue;
      }
      p.FPDFPageObj_GetMatrix(obj, m);
      final (a, bb2, c, d, e, f) =
          (m.ref.a, m.ref.b, m.ref.c, m.ref.d, m.ref.e, m.ref.f);
      PdfImagePixels? px;
      if (bb2.abs() < 1e-6 && c.abs() < 1e-6 && a > 0 && d > 0) {
        final bmp = p.FPDFImageObj_GetBitmap(obj);
        if (bmp != nullptr) {
          px = _bitmapPixels(p, bmp);
          p.FPDFBitmap_Destroy(bmp);
        }
      }
      if (px == null) {
        drop(); // döndürülmüş ya da okunamayan görsel: tamamı gider
        continue;
      }
      final data = px.bgra;
      for (final q in rects) {
        final x0 = (((q.$1 - e) / a) * px.width).floor().clamp(0, px.width);
        final x1 = (((q.$3 - e) / a) * px.width).ceil().clamp(0, px.width);
        final y0 = ((1 - (q.$4 - f) / d) * px.height).floor().clamp(0, px.height);
        final y1 = ((1 - (q.$2 - f) / d) * px.height).ceil().clamp(0, px.height);
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            final at = (y * px.width + x) * 4;
            data[at] = 0;
            data[at + 1] = 0;
            data[at + 2] = 0;
            data[at + 3] = 255;
          }
        }
      }
      final no = p.FPDFPageObj_NewImageObj(doc);
      final buf = arena<Uint8>(data.length);
      buf.asTypedList(data.length).setAll(0, data);
      final nb = p.FPDFBitmap_CreateEx(px.width, px.height, 4, buf.cast(), px.width * 4);
      final ok = no != nullptr &&
          nb != nullptr &&
          p.FPDFImageObj_SetBitmap(nullptr, 0, no, nb) != 0;
      if (nb != nullptr) p.FPDFBitmap_Destroy(nb);
      if (!ok) {
        if (no != nullptr) p.FPDFPageObj_Destroy(no);
        drop();
        continue;
      }
      p.FPDFPageObj_SetMatrix(no, m);
      p.FPDFPage_InsertObjectAtIndex(page, no, i + 1);
      created.add(no);
      drop();
    } else {
      // Yol / gölgeleme / form: bölgenin içindeyse kaldırılır; taşan kısmı
      // siyah kutunun altında kalır.
      if (inside(l.value, b.value, r.value, t.value)) drop();
    }
  }
  // Bölgeye değen açıklamalar ve form alanları (değerleri sızmasın).
  final ar = arena<pdfium_bindings.FS_RECTF>();
  for (var i = p.FPDFPage_GetAnnotCount(page) - 1; i >= 0; i--) {
    final a = p.FPDFPage_GetAnnot(page, i);
    if (a == nullptr) continue;
    final hit = p.FPDFAnnot_GetRect(a, ar) != 0 &&
        touches(math.min(ar.ref.left, ar.ref.right),
            math.min(ar.ref.bottom, ar.ref.top),
            math.max(ar.ref.left, ar.ref.right),
            math.max(ar.ref.bottom, ar.ref.top));
    p.FPDFPage_CloseAnnot(a);
    if (hit) p.FPDFPage_RemoveAnnot(page, i);
  }
  for (final q in rects) {
    final o = p.FPDFPageObj_CreateNewRect(q.$1, q.$2, q.$3 - q.$1, q.$4 - q.$2);
    if (o == nullptr) return 'Karartma kutusu çizilemedi.';
    p.FPDFPageObj_SetFillColor(o, 0, 0, 0, 255);
    p.FPDFPath_SetDrawMode(o, 1, 0);
    p.FPDFPageObj_AddMark(o, _markRedact.toNativeUtf8(allocator: arena).cast());
    p.FPDFPage_InsertObject(page, o);
    created.add(o);
  }
  return null;
}

// ── Açıklamalar (Faz 60): gerçek PDF nesneleri (`FPDFAnnot_*`) ───────────

String _annotString(pdfium_bindings.PDFium p, Arena arena,
    pdfium_bindings.FPDF_ANNOTATION annot, String key) {
  final k = key.toNativeUtf8(allocator: arena).cast<Char>();
  final len = p.FPDFAnnot_GetStringValue(annot, k, nullptr, 0);
  if (len <= 2) return '';
  final buf = arena<Uint16>(len ~/ 2 + 1);
  p.FPDFAnnot_GetStringValue(annot, k, buf.cast(), len);
  return String.fromCharCodes(buf.asTypedList(len ~/ 2 - 1));
}

void _setAnnotString(pdfium_bindings.PDFium p, Arena arena,
    pdfium_bindings.FPDF_ANNOTATION annot, String key, String value) {
  p.FPDFAnnot_SetStringValue(
      annot,
      key.toNativeUtf8(allocator: arena).cast(),
      value.toNativeUtf16(allocator: arena).cast());
}

List<PdfAnnotInfo> _annotations(
    pdfium_bindings.PDFium p, int docAddr, int pageIndex) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final page = p.FPDF_LoadPage(doc, pageIndex);
  if (page == nullptr) return const [];
  try {
    return using((arena) {
      final out = <PdfAnnotInfo>[];
      final rect = arena<pdfium_bindings.FS_RECTF>();
      final quad = arena<pdfium_bindings.FS_QUADPOINTSF>();
      final cr = arena<UnsignedInt>(), cg = arena<UnsignedInt>(),
          cb = arena<UnsignedInt>(), ca = arena<UnsignedInt>();
      final n = p.FPDFPage_GetAnnotCount(page);
      for (var i = 0; i < n; i++) {
        final a = p.FPDFPage_GetAnnot(page, i);
        if (a == nullptr) continue;
        try {
          final type = p.FPDFAnnot_GetSubtype(a);
          // Bağlantı (2), açılır pencere (16) ve form alanı (20) yorum değil.
          if (type == 2 || type == 16 || type == 20) continue;
          p.FPDFAnnot_GetRect(a, rect);
          var color = 0;
          if (p.FPDFAnnot_GetColor(
                  a,
                  pdfium_bindings.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
                  cr,
                  cg,
                  cb,
                  ca) !=
              0) {
            color = _argb(cr.value, cg.value, cb.value, ca.value);
          }
          final quads = <List<double>>[];
          final qn = p.FPDFAnnot_CountAttachmentPoints(a);
          for (var q = 0; q < qn; q++) {
            if (p.FPDFAnnot_GetAttachmentPoints(a, q, quad) != 0) {
              quads.add([
                quad.ref.x1, quad.ref.y1, quad.ref.x2, quad.ref.y2, //
                quad.ref.x3, quad.ref.y3, quad.ref.x4, quad.ref.y4,
              ]);
            }
          }
          final ink = <List<double>>[];
          if (type == PdfAnnotType.ink) {
            final paths = p.FPDFAnnot_GetInkListCount(a);
            for (var k = 0; k < paths; k++) {
              final len = p.FPDFAnnot_GetInkListPath(a, k, nullptr, 0);
              if (len <= 0) continue;
              final pts = arena<pdfium_bindings.FS_POINTF>(len);
              p.FPDFAnnot_GetInkListPath(a, k, pts, len);
              ink.add([
                for (var q = 0; q < len; q++) ...[pts[q].x, pts[q].y]
              ]);
            }
          }
          out.add(PdfAnnotInfo(
            pageIndex: pageIndex,
            index: i,
            subtype: type,
            left: rect.ref.left,
            bottom: rect.ref.bottom,
            right: rect.ref.right,
            top: rect.ref.top,
            color: color,
            contents: _annotString(p, arena, a, 'Contents'),
            author: _annotString(p, arena, a, 'T'),
            modified: _annotString(p, arena, a, 'M'),
            state: _annotString(p, arena, a, 'DOState'),
            quads: quads,
            ink: ink,
          ));
        } finally {
          p.FPDFPage_CloseAnnot(a);
        }
      }
      return out;
    });
  } finally {
    p.FPDF_ClosePage(page);
  }
}

/// null = başarılı.
String? _annotate(pdfium_bindings.PDFium p, int docAddr, PdfAnnotChange c) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final page = p.FPDF_LoadPage(doc, c.pageIndex);
  if (page == nullptr) return 'Sayfa açılamadı.';
  try {
    return using((arena) {
      void setColor(pdfium_bindings.FPDF_ANNOTATION a, int argb) {
        p.FPDFAnnot_SetColor(
            a,
            pdfium_bindings.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
            (argb >> 16) & 0xFF,
            (argb >> 8) & 0xFF,
            argb & 0xFF,
            (argb >> 24) & 0xFF);
      }

      switch (c.kind) {
        case 'remove':
          if (c.index < 0 || c.index >= p.FPDFPage_GetAnnotCount(page)) {
            return 'Açıklama bulunamadı.';
          }
          return p.FPDFPage_RemoveAnnot(page, c.index) != 0
              ? null
              : 'Açıklama silinemedi.';
        case 'update':
          final a = p.FPDFPage_GetAnnot(page, c.index);
          if (a == nullptr) return 'Açıklama bulunamadı.';
          try {
            if (c.contents != null) {
              _setAnnotString(p, arena, a, 'Contents', c.contents!);
            }
            if (c.state != null) _setAnnotString(p, arena, a, 'DOState', c.state!);
            if (c.color != 0) setColor(a, c.color);
          } finally {
            p.FPDFPage_CloseAnnot(a);
          }
          return null;
        case 'add':
          if (p.FPDFAnnot_IsSupportedSubtype(c.subtype) == 0) {
            return 'Bu açıklama türü desteklenmiyor.';
          }
          final a = p.FPDFPage_CreateAnnot(page, c.subtype);
          if (a == nullptr) return 'Açıklama oluşturulamadı.';
          try {
            final rect = arena<pdfium_bindings.FS_RECTF>();
            rect.ref
              ..left = c.rect[0]
              ..bottom = c.rect[1]
              ..right = c.rect[2]
              ..top = c.rect[3];
            p.FPDFAnnot_SetRect(a, rect);
            for (final q in c.quads) {
              if (q.length != 8) continue;
              final quad = arena<pdfium_bindings.FS_QUADPOINTSF>();
              quad.ref
                ..x1 = q[0]
                ..y1 = q[1]
                ..x2 = q[2]
                ..y2 = q[3]
                ..x3 = q[4]
                ..y3 = q[5]
                ..x4 = q[6]
                ..y4 = q[7];
              p.FPDFAnnot_AppendAttachmentPoints(a, quad);
            }
            for (final path in c.ink) {
              final n = path.length ~/ 2;
              if (n < 2) continue;
              final pts = arena<pdfium_bindings.FS_POINTF>(n);
              for (var i = 0; i < n; i++) {
                pts[i]
                  ..x = path[i * 2]
                  ..y = path[i * 2 + 1];
              }
              p.FPDFAnnot_AddInkStroke(a, pts, n);
            }
            if (c.color != 0) setColor(a, c.color);
            if (c.subtype == PdfAnnotType.ink ||
                c.subtype == PdfAnnotType.square ||
                c.subtype == PdfAnnotType.circle ||
                c.subtype == PdfAnnotType.line) {
              p.FPDFAnnot_SetBorder(a, 0, 0, c.width);
            }
            // 4 = FPDF_ANNOT_FLAG_PRINT
            p.FPDFAnnot_SetFlags(a, 4);
            if (c.contents != null) {
              _setAnnotString(p, arena, a, 'Contents', c.contents!);
            }
            if (c.author != null) _setAnnotString(p, arena, a, 'T', c.author!);
            final now = DateTime.now().toUtc();
            String two(int v) => v.toString().padLeft(2, '0');
            _setAnnotString(
                p,
                arena,
                a,
                'M',
                'D:${now.year}${two(now.month)}${two(now.day)}${two(now.hour)}'
                    '${two(now.minute)}${two(now.second)}Z');
          } finally {
            p.FPDFPage_CloseAnnot(a);
          }
          return null;
      }
      return 'Bilinmeyen işlem.';
    });
  } finally {
    p.FPDF_ClosePage(page);
  }
}

/// Sayfayı döndürür (0–3 = 0/90/180/270°; negatif = yalnız oku). Dönen:
/// önceki dönüş.
int _rotatePage(pdfium_bindings.PDFium p, int docAddr, (int, int) m) {
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final page = p.FPDF_LoadPage(doc, m.$1);
  if (page == nullptr) return -1;
  try {
    final before = p.FPDFPage_GetRotation(page);
    if (m.$2 >= 0) p.FPDFPage_SetRotation(page, m.$2 & 3);
    return before;
  } finally {
    p.FPDF_ClosePage(page);
  }
}
