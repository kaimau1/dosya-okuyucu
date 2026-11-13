part of 'pdf_edit_bridge.dart';

/// **PDF Pro yazıcısı** (Faz 56–57): bir bloğun metnini PDFium nesneleriyle
/// yeniden dizer — sarma, hizalama, karakter düzeyi biçim, **glif bazlı
/// yedek** (PK5) ve imleç haritası.
///
/// Kurallar:
/// - Her karakter önce kendi kaynağının yazı tipiyle, olmazsa aynı ailenin
///   sayfadaki öteki alt kümeleriyle (Word, Türkçe harfleri ikinci fonta
///   böler), o da olmazsa yalnız O karakter yedek fontla yazılır. Paragrafın
///   tamamı sessizce başka fonta geçmez.
/// - Değişmeyen karakterler kendi biçimini korur (kalın sözcük kalın kalır):
///   çağıran her karakterin biçim kaynağını (özgün nesne) söyler.
/// - Bir karakterin yazılabilirliği ölçülür: geri okunuyor mu, ilerleme
///   genişliği > 0 mı, glifi `.notdef` mi. Tofu ve üst üste binen harf yok.
/// - Prova + sabitleme ([_driftTargets], [_pins]) aynen: dokunulmamış
///   satırlar kaymaz, güvenle yapılamıyorsa canlı belgeye dokunulmaz.

const _markUnderline = 'DOul', _markStrike = 'DOst', _markHighlight = 'DOhl';

/// Font başına karakter ilerleme genişliği (1 punto için; -1 = yazılamaz).
/// İşçi izolatında yaşar; anahtar belgeye + fonta özgüdür.
final Map<String, Map<int, double>> _advCache = {};

String _fontKey(pdfium_bindings.PDFium p, Arena arena, int docKey,
    pdfium_bindings.FPDF_FONT font) {
  final len = arena<Size>();
  p.FPDFFont_GetFontData(font, nullptr, 0, len);
  return '$docKey|${_fontName(p, arena, font)}|${len.value}|'
      '${p.FPDFFont_GetFlags(font)}|${p.FPDFFont_GetWeight(font)}';
}

bool _isWs(int c) => c == 0x20 || c == 0xA0 || c == 0x09;

/// [codes]'un [font]'la yazılabilirliğini ve ilerleme genişliğini ölçer,
/// [cache]'e yazar. Ölçüm sayfaya geçici nesneler koyup metin sayfasından
/// geri okuyarak yapılır (PDFium'un kendi kodlama + genişlik yolu); nesneler
/// kaldırılır, akış üretilmez.
void _probe(
    pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_DOCUMENT doc,
    pdfium_bindings.FPDF_PAGE page,
    Arena arena,
    pdfium_bindings.FPDF_FONT font,
    Map<int, double> cache,
    Iterable<int> codes) {
  const size = 20.0;
  final todo = [
    for (final c in codes.toSet())
      if (!cache.containsKey(c)) c
  ];
  if (todo.isEmpty) return;
  // Boşluk ölçümü için çapa: bu fontla yazılabildiği bilinen bir harf.
  var anchor = -1;
  if (todo.any(_isWs)) {
    final solid = [for (final c in todo) if (!_isWs(c)) c];
    // ponytail: çapa adayları sabit; hiçbiri yoksa boşluk glifsiz aralık olur.
    _probe(p, doc, page, arena, font, cache,
        [...solid, 0x61, 0x6E, 0x30, 0x41]);
    anchor = cache.entries
        .firstWhere((e) => e.value > 0 && !_isWs(e.key),
            orElse: () => const MapEntry(-1, 0.0))
        .key;
    todo.removeWhere((c) => !_isWs(c));
  }
  // `.notdef` imzası: olmayan bir karakterin glif yolu ve genişliği.
  final w = arena<Float>();
  var notdefSegs = -1;
  var notdefW = -1.0;
  final nd = p.FPDFFont_GetGlyphPath(font, 0xFFFE, size);
  if (nd != nullptr) {
    notdefSegs = p.FPDFGlyphPath_CountGlyphSegments(nd);
    if (p.FPDFFont_GetGlyphWidth(font, 0xFFFE, size, w) != 0) notdefW = w.value;
  }
  final ox = arena<Double>(), oy = arena<Double>();
  final mm = arena<pdfium_bindings.FS_MATRIX>();
  const batch = 160;
  for (var from = 0; from < todo.length; from += batch) {
    final part = todo.sublist(from, math.min(todo.length, from + batch));
    final objs = <int, int>{}; // adres → kod
    final made = <pdfium_bindings.FPDF_PAGEOBJECT>[];
    for (var i = 0; i < part.length; i++) {
      // Boşluk tek başına metin sayfasında görünmez: bilinen bir harfin
      // arasında yazılır ("a a"), ilerleme iki harfin köken farkından.
      // KÖK NEDEN (dekont, 2026-11-13): `FPDFFont_GetGlyphWidth` eşlenemeyen
      // karakterde CID 0'ın genişliğini (DW = 1 em) döndürür; DevExpress alt
      // kümesinde U+0020 yoktur → sözcük araları 1 em açılıyordu.
      final ws = _isWs(part[i]);
      if (ws && anchor < 0) {
        cache[part[i]] = -1;
        continue;
      }
      final o = p.FPDFPageObj_CreateTextObj(doc, font, size);
      if (o == nullptr) {
        cache[part[i]] = -1;
        continue;
      }
      final s = String.fromCharCodes(
          ws ? [anchor, part[i], anchor] : [part[i], part[i]]);
      p.FPDFText_SetText(o, s.toNativeUtf16(allocator: arena).cast());
      // Sayfanın dışında, birbirine değmeyen bir ızgarada.
      mm.ref
        ..a = 1
        ..b = 0
        ..c = 0
        ..d = 1
        ..e = -4000.0 + (i % 16) * 120
        ..f = -4000.0 - (i ~/ 16) * 60;
      p.FPDFPageObj_SetMatrix(o, mm);
      p.FPDFPage_InsertObject(page, o);
      objs[o.address] = part[i];
      made.add(o);
    }
    final got = <int, List<(int, double)>>{};
    final tp = p.FPDFText_LoadPage(page);
    if (tp != nullptr) {
      final n = p.FPDFText_CountChars(tp);
      for (var i = 0; i < n; i++) {
        final obj = p.FPDFText_GetTextObject(tp, i);
        if (obj == nullptr || !objs.containsKey(obj.address)) continue;
        p.FPDFText_GetCharOrigin(tp, i, ox, oy);
        (got[obj.address] ??= []).add((p.FPDFText_GetUnicode(tp, i), ox.value));
      }
      p.FPDFText_ClosePage(tp);
    }
    for (final e in objs.entries) {
      final code = e.value;
      final g = got[e.key];
      var adv = -1.0;
      if (_isWs(code)) {
        // Ortadaki karakter boşluk olarak geri okunmalı (eşlenemeyen kod
        // boşluk diye okunmaz → glifsiz aralık yoluna düşer).
        if (g != null &&
            g.length == 3 &&
            g[0].$1 == anchor &&
            _isWs(g[1].$1) &&
            g[2].$1 == anchor) {
          adv = (g[2].$2 - g[0].$2) / size - cache[anchor]!;
          if (adv <= 1e-6) adv = -1;
        }
        cache[code] = adv;
        continue;
      }
      if (g != null && g.length == 2 && g[0].$1 == code && g[1].$1 == code) {
        adv = (g[1].$2 - g[0].$2) / size;
        if (adv <= 1e-6) adv = -1;
      }
      if (adv > 0) {
        final gp = p.FPDFFont_GetGlyphPath(font, code, size);
        if (gp != nullptr) {
          final segs = p.FPDFGlyphPath_CountGlyphSegments(gp);
          if (segs <= 0) {
            adv = -1; // alt kümede boşaltılmış glif
          } else if (notdefSegs > 0 && segs == notdefSegs) {
            if (p.FPDFFont_GetGlyphWidth(font, code, size, w) != 0 &&
                (w.value - notdefW).abs() < 1e-3) {
              adv = -1; // `.notdef`
            }
          }
        }
      }
      cache[code] = adv;
    }
    for (final o in made) {
      p.FPDFPage_RemoveObject(page, o);
      p.FPDFPageObj_Destroy(o);
    }
  }
}

/// Bir nesneden okunan biçim (font + ölçü + renk).
class _Src {
  final pdfium_bindings.FPDF_FONT font;
  final double tfSize, a, b, c, d;
  final bool hasFill, bold, italic;
  final int r, g, bl, al, mode;
  final String family;
  _Src(this.font, this.tfSize, this.a, this.b, this.c, this.d, this.hasFill,
      this.r, this.g, this.bl, this.al, this.mode, this.bold, this.italic,
      this.family);
  double get hScale => math.sqrt(a * a + b * b);
  double get vScale => math.sqrt(c * c + d * d);
}

bool _fontBold(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_FONT f,
        String name) =>
    p.FPDFFont_GetWeight(f) >= 600 ||
    (p.FPDFFont_GetFlags(f) & 0x40000) != 0 ||
    RegExp(r'bold|black|heavy|semibold|demi', caseSensitive: false)
        .hasMatch(name);

bool _fontItalic(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_FONT f,
        String name) =>
    (p.FPDFFont_GetFlags(f) & 0x40) != 0 ||
    RegExp(r'italic|oblique', caseSensitive: false).hasMatch(name);

/// Yazılacak tek karakter.
class _Ch {
  final int code;
  final _Src? src; // null = yedek font
  bool bold, italic, underline = false, strike = false;
  double size; // görünen punto
  int color; // ARGB
  int? highlight;
  // Seçilen font ve ölçüler.
  pdfium_bindings.FPDF_FONT font = nullptr;
  int fbKey = -1; // ≥ 0: yedek font anahtarı
  double adv = 0; // çerçeve birimi
  bool gap = false; // glifsiz boşluk
  _Ch(this.code, this.src, this.bold, this.italic, this.size, this.color);
}

class _Line {
  final int start, end; // [start, end) karakter aralığı (satır sonu boşluğu hariç)
  final bool hard; // '\n' ile bitti
  double x = 0, width = 0, gapExtra = 0;
  _Line(this.start, this.end, this.hard);
}

String _squashText(String s) => s.replaceAll(
    RegExp(r'[\s\u0000-\u001f ￾￿]'), '');

PdfTypesetResult _typeset(
    pdfium_bindings.PDFium p, int docAddr, PdfTypesetRequest m,
    [int attempt = 0]) {
  if (_rtl.hasMatch(m.oldText) || _rtl.hasMatch(m.text)) {
    return const PdfTypesetResult(
        error: 'Sağdan sola yazılan metin henüz düzenlenemiyor.');
  }
  final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(docAddr);
  final temp = p.FPDF_CreateNewDocument();
  if (temp == nullptr) {
    return const PdfTypesetResult(error: 'Düzenleme için bellek ayrılamadı.');
  }
  Map<int, (double, double)?>? plan;
  try {
    final r = using((arena) {
      final idx = arena<Int>()..value = m.pageIndex;
      if (p.FPDF_ImportPagesByIndex(temp, doc, idx, 1, 0) == 0) {
        return (const PdfTypesetResult(error: 'Sayfa kopyalanamadı.'), null);
      }
      return _typesetOn(p, temp, 0, docAddr, m, null);
    });
    if (r.$1.error == _retry) {
      // Prova bir harfin o fontla gerçekte yazılamadığını gösterdi (ölçüm
      // önbelleği düzeltildi): temiz bir kopyada yeniden.
      plan = null;
    } else {
      if (!r.$1.ok || m.dryRun) return r.$1;
      plan = r.$2!;
    }
  } finally {
    p.FPDF_CloseDocument(temp);
  }
  if (plan == null) {
    return attempt < 4
        ? _typeset(p, docAddr, m, attempt + 1)
        : const PdfTypesetResult(
            error: 'Yazdığınız karakterlerden biri belgenin yazı tipinde yok.',
            glyph: true);
  }
  return _typesetOn(p, doc, m.pageIndex, docAddr, m, plan).$1;
}

const _retry = '\u0000retry';

/// Yerinde yazmada özgün nesnelerin taşındığı uzaklık (sayfa dışı).
const _hideShift = 60000.0;

/// Üretilen akış YENİDEN AYRIŞTIRILINCA yazdığımız karakterler aynı yerde
/// aynı Unicode ile okunuyor mu? Okunmayanlar: nesne adresi → kodlar.
///
/// KÖK NEDEN: bazı alt küme fontlar (Dart `pdf` paketi) özgün fontun `cmap`
/// tablosunu taşır ama glifleri sıkıştırılmıştır; PDFium bellekte "I" yazıp
/// "I" okur, kaydedilen akışta ise o kod başka glife ("M") denk gelir.
Map<int, Set<int>> _freshMismatch(
    pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_DOCUMENT doc,
    int pageIndex,
    pdfium_bindings.FPDF_PAGE page,
    Arena arena,
    Set<int> created) {
  final out = <int, Set<int>>{};
  final ox = arena<Double>(), oy = arena<Double>();
  final fresh = p.FPDF_LoadPage(doc, pageIndex);
  if (fresh == nullptr) return out;
  final seen = <(int, int), List<int>>{};
  final ftp = p.FPDFText_LoadPage(fresh);
  if (ftp != nullptr) {
    final n = p.FPDFText_CountChars(ftp);
    for (var i = 0; i < n; i++) {
      if (p.FPDFText_GetTextObject(ftp, i) == nullptr) continue;
      p.FPDFText_GetCharOrigin(ftp, i, ox, oy);
      (seen[((ox.value * 20).round(), (oy.value * 20).round())] ??= [])
          .add(p.FPDFText_GetUnicode(ftp, i));
    }
    p.FPDFText_ClosePage(ftp);
  }
  p.FPDF_ClosePage(fresh);
  final tp = p.FPDFText_LoadPage(page);
  if (tp == nullptr) return out;
  final n = p.FPDFText_CountChars(tp);
  for (var i = 0; i < n; i++) {
    final obj = p.FPDFText_GetTextObject(tp, i);
    if (obj == nullptr || !created.contains(obj.address)) continue;
    final code = p.FPDFText_GetUnicode(tp, i);
    if (_isWs(code)) continue;
    p.FPDFText_GetCharOrigin(tp, i, ox, oy);
    final kx = (ox.value * 20).round(), ky = (oy.value * 20).round();
    var found = false;
    for (var dx = -1; dx <= 1 && !found; dx++) {
      for (var dy = -1; dy <= 1 && !found; dy++) {
        found = seen[(kx + dx, ky + dy)]?.contains(code) ?? false;
      }
    }
    if (!found) (out[obj.address] ??= {}).add(code);
  }
  p.FPDFText_ClosePage(tp);
  return out;
}

(PdfTypesetResult, Map<int, (double, double)?>?) _typesetOn(
    pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_DOCUMENT doc,
    int pageIndex,
    int docKey,
    PdfTypesetRequest m,
    Map<int, (double, double)?>? plan) {
  (PdfTypesetResult, Map<int, (double, double)?>?) fail(String msg,
          {bool glyph = false}) =>
      (PdfTypesetResult(error: msg, glyph: glyph), null);
  final page = p.FPDF_LoadPage(doc, pageIndex);
  if (page == nullptr) return fail('Sayfa açılamadı.');
  final loaded = <pdfium_bindings.FPDF_FONT>[];
  try {
    return using((arena) {
      final count = p.FPDFPage_CountObjects(page);
      // ── kaldırılacak nesneler + eski metin doğrulaması ─────────────────
      final removeObjs = <pdfium_bindings.FPDF_PAGEOBJECT>[];
      for (final i in m.remove) {
        if (i < 0 || i >= count) {
          return fail('Blok bulunamadı (sayfa değişmiş olabilir).');
        }
        removeObjs.add(p.FPDFPage_GetObject(page, i));
      }
      if (removeObjs.any((o) => o == nullptr)) {
        return fail('Blok bulunamadı (sayfa değişmiş olabilir).');
      }
      // Yerinde yazma: gizlenecek + izlenecek nesneler (biçim kaynakları).
      final keepObjs = <pdfium_bindings.FPDF_PAGEOBJECT>[];
      for (final i in [...m.hide, ...m.track]) {
        if (i < 0 || i >= count) {
          return fail('Blok bulunamadı (sayfa değişmiş olabilir).');
        }
        keepObjs.add(p.FPDFPage_GetObject(page, i));
      }
      if (m.oldText.isNotEmpty) {
        final tp = p.FPDFText_LoadPage(page);
        final sb = StringBuffer();
        if (tp != nullptr) {
          for (final o in removeObjs) {
            if (p.FPDFPageObj_GetType(o) != _fpdfPageObjText) continue;
            final len = p.FPDFTextObj_GetText(o, tp, nullptr, 0);
            if (len > 2) {
              final buf = arena<Uint16>(len ~/ 2 + 1);
              p.FPDFTextObj_GetText(o, tp, buf.cast(), len);
              sb.write(String.fromCharCodes(buf.asTypedList(len ~/ 2 - 1)));
            }
          }
          p.FPDFText_ClosePage(tp);
        }
        if (_squashText(sb.toString()) != _squashText(m.oldText)) {
          return fail('Blok bulunamadı (sayfa değişmiş olabilir).');
        }
      }

      // ── biçim kaynakları ───────────────────────────────────────────────
      final srcCache = <int, _Src?>{};
      final sizeP = arena<Float>();
      final mat = arena<pdfium_bindings.FS_MATRIX>();
      final cr = arena<UnsignedInt>(), cg = arena<UnsignedInt>(),
          cb = arena<UnsignedInt>(), ca = arena<UnsignedInt>();
      _Src? srcOf(int index) => srcCache.putIfAbsent(index, () {
            if (index < 0 || index >= count) return null;
            final o = p.FPDFPage_GetObject(page, index);
            if (o == nullptr || p.FPDFPageObj_GetType(o) != _fpdfPageObjText) {
              return null;
            }
            final font = p.FPDFTextObj_GetFont(o);
            if (font == nullptr) return null;
            p.FPDFTextObj_GetFontSize(o, sizeP);
            p.FPDFPageObj_GetMatrix(o, mat);
            final hasFill = p.FPDFPageObj_GetFillColor(o, cr, cg, cb, ca) != 0;
            final name = _fontName(p, arena, font);
            return _Src(
                font,
                sizeP.value,
                mat.ref.a,
                mat.ref.b,
                mat.ref.c,
                mat.ref.d,
                hasFill,
                cr.value,
                cg.value,
                cb.value,
                ca.value,
                p.FPDFTextObj_GetTextRenderMode(o).value,
                _fontBold(p, font, name),
                _fontItalic(p, font, name),
                pdfFontAlias(pdfFontFamily(name)));
          });

      // ── karakterler ───────────────────────────────────────────────────
      final codes = m.text.runes.toList();
      final chars = <_Ch>[];
      var ri = 0, left = m.styleRuns.length >= 2 ? m.styleRuns[1] : 0;
      for (final code in codes) {
        while (left <= 0 && ri + 2 < m.styleRuns.length) {
          ri += 2;
          left = m.styleRuns[ri + 1];
        }
        final src = m.styleRuns.isEmpty ? null : srcOf(m.styleRuns[ri]);
        left--;
        final size = m.size ?? (src == null ? 12.0 : src.tfSize * src.vScale);
        final color = m.color ??
            (src == null || !src.hasFill
                ? 0xFF000000
                : _argb(src.r, src.g, src.bl, src.al));
        chars.add(_Ch(code, src, src?.bold ?? false, src?.italic ?? false,
            size, color));
      }
      for (final s in m.spans) {
        for (var i = math.max(0, s.start);
            i < s.end && i < chars.length;
            i++) {
          final c = chars[i];
          if (s.bold != null) c.bold = s.bold!;
          if (s.italic != null) c.italic = s.italic!;
          if (s.underline != null) c.underline = s.underline!;
          if (s.strike != null) c.strike = s.strike!;
          if (s.size != null) c.size = s.size!;
          if (s.color != null) c.color = s.color!;
          if (s.highlight != null) c.highlight = s.highlight;
        }
      }
      // Baskın aile (yedek aile eşlemesi için).
      final famCount = <String, int>{};
      for (final c in chars) {
        final f = c.src?.family;
        if (f != null) famCount[f] = (famCount[f] ?? 0) + 1;
      }
      var family = famCount.isEmpty
          ? ''
          : famCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

      // ── sayfadaki kardeş fontlar: (aile, kalın, italik) → fontlar ──────
      final siblings = <(String, bool, bool), List<pdfium_bindings.FPDF_FONT>>{};
      final seenFonts = <int>{};
      for (var i = 0; i < count; i++) {
        final o = p.FPDFPage_GetObject(page, i);
        if (p.FPDFPageObj_GetType(o) != _fpdfPageObjText) continue;
        final f = p.FPDFTextObj_GetFont(o);
        if (f == nullptr || !seenFonts.add(f.address)) continue;
        final name = _fontName(p, arena, f);
        final fam = pdfFontAlias(pdfFontFamily(name));
        if (family.isEmpty) family = fam;
        (siblings[(fam, _fontBold(p, f, name), _fontItalic(p, f, name))] ??= [])
            .add(f);
      }

      // ── yedek fontlar (bu belgeye yüklenir) ────────────────────────────
      final fbFonts = <int, pdfium_bindings.FPDF_FONT>{};
      pdfium_bindings.FPDF_FONT? fallbackFont(int key) {
        final hit = fbFonts[key];
        if (hit != null) return hit;
        final bytes = m.fallback[key];
        if (bytes == null) return null;
        final buf = arena<Uint8>(bytes.length);
        buf.asTypedList(bytes.length).setAll(0, bytes);
        // 2 = FPDF_FONT_TRUETYPE, cid = 1 (Identity-H + ToUnicode).
        final f = p.FPDFText_LoadFont(doc, buf, bytes.length, 2, 1);
        if (f == nullptr) return null;
        loaded.add(f);
        return fbFonts[key] = f;
      }

      Map<int, double> cacheOf(pdfium_bindings.FPDF_FONT f, {int? fbKey}) {
        if (_advCache.length > 600) _advCache.clear();
        final key = fbKey == null
            ? _fontKey(p, arena, docKey, f)
            : 'fb|$docKey|$fbKey|${m.fallback[fbKey]!.length}|'
                '${_bytesHash(m.fallback[fbKey]!)}';
        return _advCache[key] ??= {};
      }

      // ── her karaktere font seç ─────────────────────────────────────────
      final need = <int, Set<int>>{};
      var glyphMissing = false;
      var fallbackChars = 0;
      // Biçim grubu → karakter dizinleri.
      final groups = <(int, bool, bool), List<int>>{};
      for (var i = 0; i < chars.length; i++) {
        final c = chars[i];
        if (c.code == 0x0A) continue;
        (groups[(c.src?.font.address ?? 0, c.bold, c.italic)] ??= []).add(i);
      }
      for (final e in groups.entries) {
        final first = chars[e.value.first];
        final src = first.src;
        final bold = e.key.$2, italic = e.key.$3;
        final cands = <pdfium_bindings.FPDF_FONT>[];
        if (src != null && src.bold == bold && src.italic == italic) {
          cands.add(src.font);
        }
        final fam = src?.family ?? family;
        for (final f in siblings[(fam, bold, italic)] ?? const []) {
          if (!cands.any((x) => x.address == f.address)) cands.add(f);
        }
        var pending = e.value;
        for (final f in cands) {
          if (pending.isEmpty) break;
          final cache = cacheOf(f);
          _probe(p, doc, page, arena, f, cache,
              [for (final i in pending) chars[i].code]);
          final rest = <int>[];
          for (final i in pending) {
            final adv = cache[chars[i].code] ?? -1;
            if (adv > 0) {
              chars[i].font = f;
            } else {
              rest.add(i);
            }
          }
          pending = rest;
        }
        // Boşluk hiçbir fontta yoksa glifsiz aralık olarak bırakılır.
        final solid = <int>[];
        for (final i in pending) {
          if (_isWs(chars[i].code)) {
            chars[i].gap = true;
          } else {
            solid.add(i);
          }
        }
        pending = solid;
        if (pending.isEmpty) continue;
        final key = (bold ? 1 : 0) | (italic ? 2 : 0);
        final fb = fallbackFont(key);
        final known = m.fallbackCodes[key] ?? const <int>[];
        final fresh = [
          for (final i in pending)
            if (!known.contains(chars[i].code)) chars[i].code
        ];
        if (fb == null || fresh.isNotEmpty) {
          // Yedek alt kümesi bu harfleri taşımıyor: çağıran genişletir.
          (need[key] ??= {}).addAll([for (final i in pending) chars[i].code]);
          continue;
        }
        final cache = cacheOf(fb, fbKey: key);
        _probe(p, doc, page, arena, fb, cache,
            [for (final i in pending) chars[i].code]);
        for (final i in pending) {
          if ((cache[chars[i].code] ?? -1) > 0) {
            chars[i]
              ..font = fb
              ..fbKey = key;
            fallbackChars++;
          } else {
            glyphMissing = true;
          }
        }
      }
      if (need.isNotEmpty) {
        return (
          PdfTypesetResult(need: {
            for (final e in need.entries) e.key: e.value.toList()..sort()
          }, family: family),
          null
        );
      }
      if (glyphMissing) {
        return fail('Yazdığınız karakterlerden biri kullanılabilir yazı '
            'tiplerinde yok.', glyph: true);
      }
      // ── ilerleme genişlikleri ──────────────────────────────────────────
      double tfOf(_Ch c) {
        final s = c.src;
        if (s == null || c.fbKey >= 0 && s.vScale <= 0) return c.size;
        return c.size / (s.vScale <= 0 ? 1 : s.vScale);
      }

      double hOf(_Ch c) => c.src == null ? 1 : c.src!.hScale;
      for (final c in chars) {
        if (c.code == 0x0A) continue;
        if (c.gap) {
          c.adv = c.size * 0.26;
          continue;
        }
        final cache =
            c.fbKey >= 0 ? cacheOf(c.font, fbKey: c.fbKey) : cacheOf(c.font);
        c.adv = (cache[c.code] ?? 0) * tfOf(c) * hOf(c);
      }

      // ── satırlara böl ──────────────────────────────────────────────────
      final leftEdge = math.min(m.firstX, m.bodyX);
      final maxSize = chars.isEmpty
          ? (m.size ?? 12.0)
          : chars.map((c) => c.size).reduce(math.max);
      final rightEdge = leftEdge + m.width + maxSize * 0.35;
      double lineX(int i) => i == 0 ? m.firstX : m.bodyX;
      final lines = <_Line>[];
      var i = 0;
      final n = chars.length;
      while (i <= n) {
        final avail = rightEdge - lineX(lines.length);
        var w = 0.0;
        var j = i;
        var lastBreak = -1; // boşluğun dizini
        var hard = false;
        while (j < n) {
          final c = chars[j];
          if (c.code == 0x0A) {
            hard = true;
            break;
          }
          if (_isWs(c.code)) {
            lastBreak = j;
          } else if (w + c.adv > avail && j > i) {
            break;
          }
          w += c.adv;
          j++;
        }
        var end = j, next = j;
        if (j < n && !hard) {
          if (lastBreak > i) {
            end = lastBreak;
            next = lastBreak + 1;
          }
          // Satır başına boşluk taşınmaz.
          while (next < n && _isWs(chars[next].code)) {
            next++;
          }
        } else if (hard) {
          next = j + 1;
        }
        lines.add(_Line(i, end, hard));
        if (j >= n && !hard) break;
        i = next;
        if (i >= n && hard) {
          lines.add(_Line(n, n, false));
          break;
        }
      }
      if (lines.isEmpty) lines.add(_Line(0, 0, false));
      final overflow =
          m.maxLines > 0 && lines.length > m.maxLines ? lines.length - m.maxLines : 0;

      // Hizalama.
      for (var li = 0; li < lines.length; li++) {
        final l = lines[li];
        var w = 0.0;
        var spaces = 0;
        var e = l.end;
        while (e > l.start && _isWs(chars[e - 1].code)) {
          e--; // sondaki boşluk genişliğe katılmaz
        }
        for (var k = l.start; k < e; k++) {
          w += chars[k].adv;
          if (_isWs(chars[k].code)) spaces++;
        }
        final x0 = lineX(li);
        final avail = leftEdge + m.width - x0;
        l.width = w;
        final last = li == lines.length - 1 || l.hard;
        switch (m.align) {
          case PdfBlockAlign.left:
            l.x = x0;
          case PdfBlockAlign.center:
            l.x = x0 + (avail - w) / 2;
          case PdfBlockAlign.right:
            l.x = x0 + avail - w;
          case PdfBlockAlign.justify:
            l.x = x0;
            final extra = avail - w;
            if (!last && spaces > 0 && extra > 0 && extra / spaces < maxSize * 1.2) {
              l.gapExtra = extra / spaces;
            }
        }
      }

      // ── imleç haritası ─────────────────────────────────────────────────
      final xs = List<double>.filled(n, 0), xe = List<double>.filled(n, 0);
      final lineOfChar = List<int>.filled(n, 0);
      final bases = <double>[], sizes = <double>[], starts = <double>[];
      for (var li = 0; li < lines.length; li++) {
        final l = lines[li];
        var x = l.x;
        var size = 0.0;
        for (var k = l.start; k < l.end; k++) {
          xs[k] = x;
          x += chars[k].adv + (_isWs(chars[k].code) ? l.gapExtra : 0);
          xe[k] = x;
          lineOfChar[k] = li;
          size = math.max(size, chars[k].size);
        }
        // Satır sonunda yutulan boşluklar / '\n': satırın ucunda durur.
        final stop = li + 1 < lines.length ? lines[li + 1].start : n;
        for (var k = l.end; k < stop; k++) {
          xs[k] = x;
          xe[k] = x;
          lineOfChar[k] = li;
        }
        bases.add(m.base - li * m.leading);
        sizes.add(size == 0
            ? (li > 0 ? sizes[li - 1] : (chars.isEmpty ? maxSize : chars.first.size))
            : size);
        starts.add(l.x);
      }
      final map = PdfBlockTextMap(
        text: m.text,
        angle: m.angle,
        xs: xs,
        xe: xe,
        line: lineOfChar,
        obj: List<int>.filled(n, -1),
        chr: List<int>.filled(n, -1),
        bases: bases,
        sizes: sizes,
        starts: starts,
      );
      if (overflow > 0) {
        return (
          PdfTypesetResult(
              error: 'Metin bloğa sığmıyor: $overflow satır fazla.',
              overflow: overflow,
              map: map,
              family: family,
              lineCount: lines.length),
          null
        );
      }
      if (m.dryRun) {
        return (
          PdfTypesetResult(
              map: map,
              family: family,
              lineCount: lines.length,
              fallbackChars: fallbackChars),
          null
        );
      }

      // ── yaz ────────────────────────────────────────────────────────────
      final cosA = math.cos(m.angle), sinA = math.sin(m.angle);
      double pageX(double fx, double fy) => fx * cosA - fy * sinA;
      double pageY(double fx, double fy) => fx * sinA + fy * cosA;

      final order = [...m.remove]..sort();
      for (final idx in order.reversed) {
        p.FPDFPage_RemoveObject(page, p.FPDFPage_GetObject(page, idx));
      }
      // Gizlenenler sayfanın çok dışına taşınır (görünmez, ama fontu ve
      // biçimi sonraki tuşlar için yaşar).
      for (var k = 0; k < m.hide.length; k++) {
        p.FPDFPageObj_Transform(keepObjs[k], 1, 0, 0, 1, _hideShift, _hideShift);
      }
      final created = <pdfium_bindings.FPDF_PAGEOBJECT>[];
      final textObjs = <pdfium_bindings.FPDF_PAGEOBJECT>[];
      final runCache = <int, Map<int, double>>{}; // nesne → fontun ölçüm önbelleği
      void rollback() {
        for (final o in created) {
          p.FPDFPage_RemoveObject(page, o);
          p.FPDFPageObj_Destroy(o);
        }
        for (var k = 0; k < order.length; k++) {
          p.FPDFPage_InsertObjectAtIndex(
              page, removeObjs[m.remove.indexOf(order[k])], order[k]);
        }
        for (var k = 0; k < m.hide.length; k++) {
          p.FPDFPageObj_Transform(
              keepObjs[k], 1, 0, 0, 1, -_hideShift, -_hideShift);
        }
      }

      bool sameRun(_Ch a, _Ch b) =>
          !a.gap &&
          !b.gap &&
          a.font.address == b.font.address &&
          a.fbKey == b.fbKey &&
          identical(a.src, b.src) &&
          a.size == b.size &&
          a.color == b.color &&
          a.bold == b.bold &&
          a.italic == b.italic;

      void rect(double x0, double x1, double y0, double y1, int argb,
          String mark, {bool front = true}) {
        final o = p.FPDFPageObj_CreateNewRect(0, 0, x1 - x0, y1 - y0);
        if (o == nullptr) return;
        p.FPDFPageObj_SetFillColor(o, (argb >> 16) & 0xFF, (argb >> 8) & 0xFF,
            argb & 0xFF, (argb >> 24) & 0xFF);
        p.FPDFPath_SetDrawMode(o, 1, 0); // FPDF_FILLMODE_ALTERNATE, kontursuz
        p.FPDFPageObj_Transform(
            o, cosA, sinA, -sinA, cosA, pageX(x0, y0), pageY(x0, y0));
        p.FPDFPageObj_AddMark(o, mark.toNativeUtf8(allocator: arena).cast());
        p.FPDFPage_InsertObject(page, o);
        created.add(o);
      }

      // Vurgu önce (metnin altında kalsın).
      for (var li = 0; li < lines.length; li++) {
        final l = lines[li];
        var k = l.start;
        while (k < l.end) {
          final h = chars[k].highlight;
          if (h == null) {
            k++;
            continue;
          }
          final st = k;
          while (k < l.end && chars[k].highlight == h) {
            k++;
          }
          rect(xs[st], xe[k - 1], bases[li] - sizes[li] * 0.22,
              bases[li] + sizes[li] * 0.82, h, _markHighlight);
        }
      }
      for (var li = 0; li < lines.length; li++) {
        final l = lines[li];
        var k = l.start;
        while (k < l.end) {
          // Koşu: aynı biçim; iki yana yaslıda her boşlukta kesilir.
          final st = k;
          final c0 = chars[st];
          k++;
          while (k < l.end &&
              sameRun(c0, chars[k]) &&
              !(l.gapExtra > 0 && _isWs(chars[k - 1].code))) {
            k++;
          }
          if (c0.gap) continue;
          final s = String.fromCharCodes([for (var q = st; q < k; q++) chars[q].code]);
          if (s.trim().isEmpty && l.gapExtra > 0) continue;
          final tf = tfOf(c0);
          final o = p.FPDFPageObj_CreateTextObj(doc, c0.font, tf);
          if (o == nullptr) {
            rollback();
            return fail('Metin nesnesi oluşturulamadı.');
          }
          p.FPDFText_SetText(o, s.toNativeUtf16(allocator: arena).cast());
          final src = c0.src;
          var (a, b, c, d) = src == null
              ? (cosA, sinA, -sinA, cosA)
              : (src.a, src.b, src.c, src.d);
          final syn = c0.fbKey >= 0 ? (m.synth[c0.fbKey] ?? 0) : 0;
          if (syn & 2 != 0) {
            c += a * 0.2;
            d += b * 0.2;
          }
          final mm = arena<pdfium_bindings.FS_MATRIX>();
          mm.ref
            ..a = a
            ..b = b
            ..c = c
            ..d = d
            ..e = pageX(xs[st], bases[li])
            ..f = pageY(xs[st], bases[li]);
          p.FPDFPageObj_SetMatrix(o, mm);
          final col = c0.color;
          p.FPDFPageObj_SetFillColor(o, (col >> 16) & 0xFF, (col >> 8) & 0xFF,
              col & 0xFF, (col >> 24) & 0xFF);
          if (syn & 1 != 0) {
            p.FPDFPageObj_SetStrokeColor(o, (col >> 16) & 0xFF,
                (col >> 8) & 0xFF, col & 0xFF, (col >> 24) & 0xFF);
            p.FPDFPageObj_SetStrokeWidth(o, tf * 0.03);
            p.FPDFTextObj_SetTextRenderMode(
                o, pdfium_bindings.FPDF_TEXT_RENDERMODE.fromValue(2));
          } else if (src != null && c0.fbKey < 0) {
            p.FPDFTextObj_SetTextRenderMode(
                o, pdfium_bindings.FPDF_TEXT_RENDERMODE.fromValue(src.mode));
          }
          p.FPDFPage_InsertObject(page, o);
          created.add(o);
          textObjs.add(o);
          runCache[o.address] = c0.fbKey >= 0
              ? cacheOf(c0.font, fbKey: c0.fbKey)
              : cacheOf(c0.font);
        }
        // Alt/üst çizgi.
        for (final (flag, mark) in [(true, _markUnderline), (false, _markStrike)]) {
          var q = l.start;
          while (q < l.end) {
            final on = flag ? chars[q].underline : chars[q].strike;
            if (!on) {
              q++;
              continue;
            }
            final st = q;
            final col = chars[q].color;
            while (q < l.end &&
                (flag ? chars[q].underline : chars[q].strike) &&
                chars[q].color == col) {
              q++;
            }
            final sz = sizes[li];
            final y = flag ? bases[li] - sz * 0.12 : bases[li] + sz * 0.26;
            rect(xs[st], xe[q - 1], y, y + math.max(0.4, sz * 0.055), col, mark);
          }
        }
      }

      // Doğrulama: PDFium yeni nesnelerden aynı metni geri okuyor mu?
      if (!_readsBackSquashed(p, page, textObjs, m.text)) {
        rollback();
        return fail('Yazdığınız karakterlerden biri belgenin yazı tipinde yok.',
            glyph: true);
      }
      final mine = {for (final o in created) o.address};
      final skip = {...mine, for (final o in keepObjs) o.address};
      (List<int>, List<int>) indexes() {
        final out = <int>[];
        final at = <int, int>{};
        final total = p.FPDFPage_CountObjects(page);
        for (var k = 0; k < total; k++) {
          final a = p.FPDFPage_GetObject(page, k).address;
          if (mine.contains(a)) out.add(k);
          at[a] = k;
        }
        return (out, [for (final o in keepObjs) at[o.address] ?? -1]);
      }

      if (plan == null) {
        p.FPDFPage_GenerateContent(page);
        final bad = _freshMismatch(p, doc, pageIndex, page, arena,
            {for (final o in textObjs) o.address});
        if (bad.isNotEmpty) {
          for (final e in bad.entries) {
            for (final code in e.value) {
              runCache[e.key]?[code] = -1;
            }
          }
          for (final o in removeObjs) {
            p.FPDFPageObj_Destroy(o);
          }
          return fail(_retry);
        }
        final targets = _driftTargets(p, doc, pageIndex, page, arena, skip);
        for (final o in removeObjs) {
          p.FPDFPageObj_Destroy(o);
        }
        if (!_pins(p, doc, page, arena, skip, targets, apply: false)) {
          return fail('Bu düzenleme yakındaki satırların yerini kaydırırdı; '
              'sayfa olduğu gibi bırakıldı.');
        }
        return (
          PdfTypesetResult(
              map: map,
              family: family,
              lineCount: lines.length,
              fallbackChars: fallbackChars),
          targets
        );
      }
      if (!_pins(p, doc, page, arena, skip, plan, apply: true)) {
        rollback();
        return fail('Sayfa provadakinden farklı; düzenleme yapılmadı.');
      }
      p.FPDFPage_GenerateContent(page);
      for (final o in removeObjs) {
        p.FPDFPageObj_Destroy(o);
      }
      final (createdAt, trackedAt) = indexes();
      return (
        PdfTypesetResult(
            map: map,
            family: family,
            created: createdAt,
            tracked: trackedAt,
            lineCount: lines.length,
            fallbackChars: fallbackChars),
        null
      );
    });
  } finally {
    for (final f in loaded) {
      p.FPDFFont_Close(f);
    }
    p.FPDF_ClosePage(page);
  }
}

int _bytesHash(Uint8List b) {
  var h = 0x811c9dc5;
  final step = math.max(1, b.length ~/ 512);
  for (var i = 0; i < b.length; i += step) {
    h = ((h ^ b[i]) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

bool _readsBackSquashed(pdfium_bindings.PDFium p,
    pdfium_bindings.FPDF_PAGE page,
    List<pdfium_bindings.FPDF_PAGEOBJECT> created, String text) {
  final tp = p.FPDFText_LoadPage(page);
  if (tp == nullptr) return false;
  try {
    final mine = {for (final o in created) o.address};
    final per = <int, StringBuffer>{};
    final n = p.FPDFText_CountChars(tp);
    for (var i = 0; i < n; i++) {
      final obj = p.FPDFText_GetTextObject(tp, i);
      if (obj == nullptr || !mine.contains(obj.address)) continue;
      (per[obj.address] ??= StringBuffer())
          .writeCharCode(p.FPDFText_GetUnicode(tp, i));
    }
    // Nesneler yazım sırasıyla (metin sayfası sırası sayfa düzenine göre
    // değişebilir).
    final b = StringBuffer();
    for (final o in created) {
      b.write(per[o.address] ?? '');
    }
    return _squashText(b.toString()) == _squashText(text);
  } finally {
    p.FPDFText_ClosePage(tp);
  }
}

/// Yalnız test: yedek font turu olmadan ham yazım.
@visibleForTesting
PdfTypesetResult debugTypeset(
        pdfium_bindings.PDFium p, int docAddr, PdfTypesetRequest m) =>
    _typesetEntry(p, docAddr, m);

PdfTypesetResult _typesetEntry(
        pdfium_bindings.PDFium p, int docAddr, PdfTypesetRequest m) =>
    _typeset(p, docAddr, m);
