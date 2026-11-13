/// PDF Pro **metin anlama** (Faz 55): PDFium metin nesnelerinden satır, blok
/// (paragraf), hizalama, liste, üst/alt bilgi ve imleç haritası kurma.
///
/// Saf Dart — PDFium'a dokunmaz; [PdfEditBridge.textObjects]'in verdiği
/// nesnelerle çalışır, test edilebilir.
///
/// **Çerçeve:** her blok kendi yazı yönünde çözülür. Sayfa koordinatı blok
/// açısı kadar geri döndürülür ("çerçeve"): çerçevede metin +x yönünde akar,
/// satırlar −y yönünde dizilir. Böylece 90/180/270 ve açılı metin de dik
/// metinle AYNI kurallarla satır ve paragrafa gruplanır.
library;

import 'dart:math' as math;

/// Bloğun türü (bilgi amaçlı; düzenleme kuralları [PdfBlockLock]'ta).
enum PdfBlockKind { paragraph, heading, listItem, header, footer, pageNumber }

enum PdfBlockAlign { left, center, right, justify }

/// Bloğun düzenlenememe nedeni (PK7 — sessiz geri düşüş yok).
enum PdfBlockLock {
  none,

  /// Sağdan sola yazı (Arapça/İbranice): harf birleştirme yazıcıda yok.
  rtl,

  /// Görünmez metin (taranmış sayfanın OCR katmanı) — Faz 62 yolu.
  invisible,
}

/// Blok birimi: paragraf (varsayılan, PK4) ya da satır (PDFelement kipi).
enum PdfBlockMode { paragraph, line }

/// Bir nesnenin tek karakteri (sayfa uzayı). [index] = PDFium metin sayfası
/// karakter sırası (pdfrx `fullText` sırasıyla aynı) — seçim eşlemesi için.
class PdfObjChar {
  final int code;
  final double x, y;
  final int index;
  const PdfObjChar(this.code, this.x, this.y, this.index);
}

/// Sayfadaki bir metin nesnesi (PDF sayfa uzayı, y yukarı).
class PdfTextObjectInfo {
  /// Sayfadaki nesne sırası (`FPDFPage_GetObject` dizini).
  final int index;
  final String text;
  final double left, bottom, right, top;

  /// `Tf` puntosu (ekrandaki boy için [visualSize]).
  final double tfSize;
  final String fontName;

  /// Nesne matrisi `[a, b, c, d, e, f]` (e, f = taban çizgisi başlangıcı).
  final List<double> matrix;
  final int renderMode;

  /// Dolgu rengi (ARGB).
  final int fill;

  /// PDF font tanımlayıcı bayrakları (Tablo 123) ve ağırlığı.
  final int fontFlags, weight;
  final bool embedded;

  /// Döndürülmüş sınır dörtgeni (8 sayı: x1,y1 … x4,y4) — yoksa kutu kullanılır.
  final List<double>? quad;

  /// Karakterler (yazım sırasıyla); testte boş olabilir.
  final List<PdfObjChar> chars;

  const PdfTextObjectInfo({
    required this.index,
    required this.text,
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
    required this.tfSize,
    required this.fontName,
    required this.matrix,
    required this.renderMode,
    this.fill = 0xFF000000,
    this.fontFlags = 0,
    this.weight = 400,
    this.embedded = true,
    this.quad,
    this.chars = const [],
  });

  /// Ekranda görünen punto (Tf × matris ölçeği).
  double get visualSize =>
      tfSize * math.sqrt(matrix[2] * matrix[2] + matrix[3] * matrix[3]);
  double get baseline => matrix[5];

  /// Yazı yönü (radyan, saat yönünün tersine); yatık (eğik) matris açı sayılmaz.
  double get angle {
    final a = matrix[0], b = matrix[1];
    if (b.abs() < 1e-3 && a > 0) return 0;
    return math.atan2(b, a);
  }

  bool get rotated => angle.abs() > 1e-3;

  /// Görünmez metin (işleme kipi 3 ya da 7): OCR katmanı.
  bool get invisible => renderMode == 3 || renderMode == 7;

  /// Alt küme öneki ("ABCDEF+") atılmış yazı tipi adı.
  String get family => pdfFontFamily(fontName);

  bool get bold =>
      weight >= 600 ||
      (fontFlags & 0x40000) != 0 ||
      RegExp(r'bold|black|heavy|semibold|demi', caseSensitive: false)
          .hasMatch(fontName);
  bool get italic =>
      (fontFlags & 0x40) != 0 ||
      RegExp(r'italic|oblique', caseSensitive: false).hasMatch(fontName);
}

/// Sayfadaki metin dışı içerik nesnesi (yol, görsel, gölgeleme, form).
class PdfPageItem {
  /// Sayfadaki nesne sırası (`FPDFPage_GetObject` dizini).
  final int index;

  /// PDFium nesne türü: 2 yol · 3 görsel · 4 gölgeleme · 5 form.
  final int type;
  final double left, bottom, right, top;
  final List<double> matrix;

  /// Yol: kontur/dolgu çiziliyor mu, renkleri (ARGB), kontur kalınlığı,
  /// parça sayısı ve yalnız düz parçalardan mı oluştuğu.
  final bool stroke, filled, straight;
  final int fill, strokeColor, segments;
  final double strokeWidth;

  /// Görsel: piksel boyutu.
  final int pixelWidth, pixelHeight;

  /// İşaretli içerik adı (bizim süs çizgilerimiz: `DOul`, `DOst`, `DOhl`).
  final String mark;

  const PdfPageItem({
    required this.index,
    required this.type,
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
    this.matrix = const [1, 0, 0, 1, 0, 0],
    this.stroke = false,
    this.filled = false,
    this.straight = false,
    this.fill = 0,
    this.strokeColor = 0,
    this.segments = 0,
    this.strokeWidth = 0,
    this.pixelWidth = 0,
    this.pixelHeight = 0,
    this.mark = '',
  });

  bool get isPath => type == 2;
  bool get isImage => type == 3;
  double get width => right - left;
  double get height => top - bottom;
}

/// Bir sayfanın içerik nesneleri.
class PdfPageContent {
  final List<PdfTextObjectInfo> texts;
  final List<PdfPageItem> items;
  final double width, height;
  const PdfPageContent(this.texts, this.items, this.width, this.height);

  /// Tablo/çerçeve çizgileri ([groupTextBlocks] için).
  List<PdfRule> get rules => pdfRulesOf(items);

  /// Vektör madde imleri (küçük, kareye yakın yollar) — merkezleri.
  List<(double, double)> get bullets => [
        for (final it in items)
          if (it.isPath &&
              it.width >= 1.5 &&
              it.width <= 8 &&
              it.height >= 1.5 &&
              it.height <= 8 &&
              (it.width - it.height).abs() < 2)
            ((it.left + it.right) / 2, (it.bottom + it.top) / 2),
      ];
}

/// Yatay ya da dikey ince çizgi (tablo kenarı, ayraç). Sayfa uzayı.
class PdfRule {
  final double x0, y0, x1, y1;
  const PdfRule(this.x0, this.y0, this.x1, this.y1);
  bool get vertical => (x1 - x0).abs() < (y1 - y0).abs();
}

/// Yollardan çizgiler: ince dikdörtgen/çizgi tek çizgi, konturlu düz
/// dikdörtgen dört kenar. Dolgulu kutular (vurgu, hücre zemini) çizgi DEĞİL.
List<PdfRule> pdfRulesOf(List<PdfPageItem> items) {
  final out = <PdfRule>[];
  for (final it in items) {
    // Bizim süs çizgilerimiz (alt/üst çizgi, vurgu) tablo çizgisi değildir.
    if (!it.isPath || it.mark.startsWith('DO')) continue;
    final w = it.width, h = it.height;
    if (w <= 2.5 && h >= 4) {
      final x = (it.left + it.right) / 2;
      out.add(PdfRule(x, it.bottom, x, it.top));
    } else if (h <= 2.5 && w >= 4) {
      final y = (it.bottom + it.top) / 2;
      out.add(PdfRule(it.left, y, it.right, y));
    } else if (it.stroke && it.straight && it.segments <= 6 && w > 2.5 && h > 2.5) {
      out
        ..add(PdfRule(it.left, it.bottom, it.left, it.top))
        ..add(PdfRule(it.right, it.bottom, it.right, it.top))
        ..add(PdfRule(it.left, it.bottom, it.right, it.bottom))
        ..add(PdfRule(it.left, it.top, it.right, it.top));
    }
  }
  return out;
}

/// "ABCDEF+Calibri-Bold" → "calibri" (aile; kesim ve alt küme öneki atılır).
String pdfFontFamily(String baseName) {
  var n = baseName;
  final plus = n.indexOf('+');
  if (plus >= 0 && plus <= 7) n = n.substring(plus + 1);
  n = n.toLowerCase();
  final cut = n.indexOf(RegExp(r'[-,]'));
  if (cut > 0) n = n.substring(0, cut);
  return n
      .replaceAll(
          RegExp(r'(bold|italic|oblique|regular|mt|ps|semibold|light|medium)+$'),
          '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Metrik uyumlu aileleri tek ada indirger (Carlito ≡ Calibri …): aynı
/// ailenin alt kümeleri ve bizim gömdüğümüz yedekler "kardeş" sayılır.
String pdfFontAlias(String family) => switch (family) {
      'carlito' => 'calibri',
      'tinos' || 'times' || 'timesnewromanps' || 'liberationserif' =>
        'timesnewroman',
      'arimo' || 'helvetica' || 'liberationsans' || 'arialmt' => 'arial',
      'cousine' || 'couriernew' || 'liberationmono' => 'courier',
      _ => family,
    };

final _rtlRe = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');

/// Liste işareti: madde imi ya da "1." / "a)" / "(2)" / "iv." gibi sayaç.
final _markerRe = RegExp(
    r'^(?:[•◦▪■□●○◆◇‣⁃∙·–—*➢➤✓✔-]|\(?(?:\d{1,3}|[a-zA-Z]|[ivxIVX]{1,4})[.)])(?=\s|$)');

/// Çerçeveye alınmış nesne.
class _Fo {
  final PdfTextObjectInfo o;
  final double l, r, b, t, base, size;
  _Fo(this.o, this.l, this.r, this.b, this.t, this.base, this.size);
}

class _Frame {
  final double angle, c, s;
  _Frame(this.angle)
      : c = math.cos(angle),
        s = math.sin(angle);
  double x(double px, double py) => px * c + py * s;
  double y(double px, double py) => -px * s + py * c;
  double px(double fx, double fy) => fx * c - fy * s;
  double py(double fx, double fy) => fx * s + fy * c;

  _Fo of(PdfTextObjectInfo o) {
    final q = o.quad ??
        [o.left, o.bottom, o.right, o.bottom, o.right, o.top, o.left, o.top];
    var l = double.infinity, r = -double.infinity;
    var b = double.infinity, t = -double.infinity;
    for (var i = 0; i < 8; i += 2) {
      final fx = x(q[i], q[i + 1]), fy = y(q[i], q[i + 1]);
      l = math.min(l, fx);
      r = math.max(r, fx);
      b = math.min(b, fy);
      t = math.max(t, fy);
    }
    final size = o.visualSize <= 0 ? math.max(1.0, t - b) : o.visualSize;
    return _Fo(o, l, r, b, t, y(o.matrix[4], o.matrix[5]), size);
  }
}

class PdfTextLine {
  final List<PdfTextObjectInfo> objects;

  /// Çerçeve (yazı yönü) — açı radyan.
  final double angle;

  PdfTextLine(this.objects, {this.angle = 0}) {
    _measure();
  }

  late double _fl, _fr, _fb, _ft, _base, _size;

  void _measure() {
    final f = _Frame(angle);
    _fl = double.infinity;
    _fr = -double.infinity;
    _fb = double.infinity;
    _ft = -double.infinity;
    _size = 0;
    _base = 0;
    for (final o in objects) {
      final fo = f.of(o);
      _fl = math.min(_fl, fo.l);
      _fr = math.max(_fr, fo.r);
      _fb = math.min(_fb, fo.b);
      _ft = math.max(_ft, fo.t);
      // Satırın tabanı ve puntosu baskın (en büyük) nesneden: üst/alt simge
      // satırı kaydırmaz.
      if (fo.size > _size + 1e-6) {
        _size = fo.size;
        _base = fo.base;
      }
    }
    _text = null;
  }

  void _add(PdfTextObjectInfo o) {
    objects.add(o);
    final f = _Frame(angle);
    objects.sort((a, b) => f.of(a).l.compareTo(f.of(b).l));
    _measure();
  }

  // Sayfa uzayı kutusu.
  double get left => objects.map((o) => o.left).reduce(math.min);
  double get right => objects.map((o) => o.right).reduce(math.max);
  double get top => objects.map((o) => o.top).reduce(math.max);
  double get bottom => objects.map((o) => o.bottom).reduce(math.min);

  /// Çerçevedeki ölçüler (yazı yönünde sol/sağ, taban çizgisi).
  double get frameLeft => _fl;
  double get frameRight => _fr;
  double get frameBase => _base;

  /// İlk nesnenin kalem başlangıcı (çerçeve x) — glif kutusunun değil,
  /// yazımın başladığı nokta.
  double get frameStart {
    final o = objects.first;
    final f = _Frame(angle);
    return f.x(o.matrix[4], o.matrix[5]);
  }

  /// Dik metinde sayfa y'si; döndürülmüşte çerçeve tabanı.
  double get baseline => angle == 0 ? _base : objects.first.baseline;
  double get size => _size;

  bool get bold {
    var b = 0, n = 0;
    for (final o in objects) {
      final w = math.max(1, o.text.trim().length);
      n += w;
      if (o.bold) b += w;
    }
    return n > 0 && b * 2 > n;
  }

  String? _text;

  /// Nesneler soldan sağa; aralarında boşluk yoksa ve yatay boşluk yeterince
  /// büyükse bir boşluk eklenir.
  String get text => _text ??= _LineText.of(this).text;
}

/// Bir satırın metni ve karakter başına çerçeve konumu.
class _LineText {
  final String text;
  final List<double> xs, xe;
  final List<int> obj, chr;
  _LineText(this.text, this.xs, this.xe, this.obj, this.chr);

  static bool _ws(int c) => c == 0x20 || c == 0x09 || c == 0xA0 || c == 0x0A || c == 0x0D;
  static bool _skip(int c) => c < 0x20 && !_ws(c) || c == 0xFFFE || c == 0xFFFF;

  static _LineText of(PdfTextLine line) {
    final f = _Frame(line.angle);
    final codes = <int>[], xs = <double>[], xe = <double>[];
    final obj = <int>[], chr = <int>[];
    void put(int code, double a, double b, int o, int c) {
      if (_ws(code)) {
        if (codes.isEmpty) return;
        if (codes.last == 0x20) {
          xe[xe.length - 1] = math.max(xe.last, b);
          return;
        }
        code = 0x20;
      }
      codes.add(code);
      xs.add(a);
      xe.add(b);
      obj.add(o);
      chr.add(c);
    }

    _Fo? prev;
    for (final o in line.objects) {
      final fo = f.of(o);
      if (prev != null) {
        // Sıkı kutu solu, glifin sol boşluğu kadar sağda: Word'ün böldüğü
        // "ya|pılan" sözcüğü sahte boşluk alıyordu — kalem başı (köken) esas.
        final l = o.chars.isEmpty
            ? fo.l
            : math.min(fo.l, f.x(o.chars.first.x, o.chars.first.y));
        final gap = l - prev.r;
        if (gap > line.size * 0.15 &&
            codes.isNotEmpty &&
            codes.last != 0x20 &&
            !o.text.startsWith(' ')) {
          put(0x20, prev.r, fo.l, prev.o.index, -1);
        }
      }
      if (o.chars.isNotEmpty) {
        final n = o.chars.length;
        for (var i = 0; i < n; i++) {
          final c = o.chars[i];
          if (_skip(c.code)) continue;
          final a = f.x(c.x, c.y);
          var b = i + 1 < n ? f.x(o.chars[i + 1].x, o.chars[i + 1].y) : fo.r;
          if (b < a) b = a;
          put(c.code, a, b, o.index, c.index);
        }
      } else {
        // Karakter verisi yok (test): metni kutuya eşit yay.
        final runes = o.text.runes.toList();
        final w = runes.isEmpty ? 0.0 : (fo.r - fo.l) / runes.length;
        for (var i = 0; i < runes.length; i++) {
          if (_skip(runes[i])) continue;
          put(runes[i], fo.l + i * w, fo.l + (i + 1) * w, o.index, -1);
        }
      }
      prev = fo;
    }
    while (codes.isNotEmpty && codes.last == 0x20) {
      codes.removeLast();
      xs.removeLast();
      xe.removeLast();
      obj.removeLast();
      chr.removeLast();
    }
    return _LineText(String.fromCharCodes(codes), xs, xe, obj, chr);
  }
}

class PdfTextBlock {
  final List<PdfTextLine> lines;
  PdfBlockKind kind;

  PdfTextBlock(this.lines, {this.kind = PdfBlockKind.paragraph});

  double get angle => lines.first.angle;
  double get left => lines.map((l) => l.left).reduce(math.min);
  double get right => lines.map((l) => l.right).reduce(math.max);
  double get top => lines.map((l) => l.top).reduce(math.max);
  double get bottom => lines.map((l) => l.bottom).reduce(math.min);
  String get text => lines.map((l) => l.text).join(' ');
  List<int> get objectIndexes =>
      [for (final l in lines) for (final o in l.objects) o.index];

  double get size => lines.first.size;

  // ── çerçeve geometrisi (yazıcı için) ──────────────────────────────────
  double get frameLeft => lines.map((l) => l.frameLeft).reduce(math.min);
  double get frameRight => lines.map((l) => l.frameRight).reduce(math.max);
  double get frameWidth => frameRight - frameLeft;

  /// İlk satırdan sonraki satırların sol kenarı (asılı/ilk satır girintisi).
  double get bodyLeft => lines.length > 1
      ? lines.skip(1).map((l) => l.frameLeft).reduce(math.min)
      : lines.first.frameLeft;

  /// Satır aralığı (taban çizgileri arası); tek satırda punto × 1,2.
  double get leading => lines.length > 1
      ? (lines.first.frameBase - lines.last.frameBase) / (lines.length - 1)
      : lines.first.size * 1.2;

  bool get rtl => _rtlRe.hasMatch(text);
  bool get invisible => lines.first.objects.first.invisible;

  PdfBlockLock get lock => rtl
      ? PdfBlockLock.rtl
      : invisible
          ? PdfBlockLock.invisible
          : PdfBlockLock.none;
  bool get editable => lock == PdfBlockLock.none;

  /// Liste işareti ("•", "1.") — yoksa null.
  String? get marker => _markerRe.firstMatch(lines.first.text)?.group(0);

  /// Hizalama (satırların sol/sağ kenarlarından).
  PdfBlockAlign get align {
    if (lines.length < 2) return PdfBlockAlign.left;
    final tol = math.max(1.0, size * 0.12);
    final l = frameLeft, r = frameRight;
    final body = lines.sublist(0, lines.length - 1);
    bool lefts(Iterable<PdfTextLine> ls) => ls.skip(1).every(
        (x) => (x.frameLeft - bodyLeft).abs() <= tol);
    final rightsBody = body.every((x) => (x.frameRight - r).abs() <= tol * 2);
    final rightsAll = lines.every((x) => (x.frameRight - r).abs() <= tol);
    final leftsAll = lefts(lines) || lines.length == 2;
    if (leftsAll && rightsBody && lines.length >= 3) return PdfBlockAlign.justify;
    if (leftsAll && lines.every((x) => (x.frameLeft - l).abs() <= size * 3)) {
      if (rightsAll && lines.any((x) => (x.frameLeft - l).abs() > tol)) {
        return PdfBlockAlign.right;
      }
      if (!lines.any((x) => (x.frameLeft - l).abs() > tol)) {
        return PdfBlockAlign.left;
      }
    }
    final mid = (l + r) / 2;
    if (lines.every(
        (x) => ((x.frameLeft + x.frameRight) / 2 - mid).abs() <= tol * 1.5)) {
      return lines.any((x) => (x.frameLeft - l).abs() > tol)
          ? PdfBlockAlign.center
          : PdfBlockAlign.left;
    }
    if (rightsAll) return PdfBlockAlign.right;
    return PdfBlockAlign.left;
  }

  PdfBlockTextMap? _map;

  /// Metin ↔ konum haritası (imleç, seçim, biçim kaynağı).
  PdfBlockTextMap get map => _map ??= PdfBlockTextMap.ofBlock(this);
}

/// Bir bloğun metni ile sayfadaki konumu arasındaki harita: her karakterin
/// çerçevedeki başlangıç/bitiş x'i, satırı ve kaynak nesnesi. Hem özgün
/// bloktan ([PdfBlockTextMap.ofBlock]) hem yazıcının çıktısından kurulur;
/// imleç ve seçim katmanı yalnız bunu bilir.
class PdfBlockTextMap {
  final String text;
  final double angle;

  /// Karakter başına: çerçeve x başlangıç/bitiş, satır sırası, kaynak nesne
  /// (sayfa nesne dizini; yoksa -1), PDFium karakter dizini (yoksa -1).
  final List<double> xs, xe;
  final List<int> line, obj, chr;

  /// Satır başına: çerçeve taban çizgisi, punto ve boşken imlecin x'i.
  final List<double> bases, sizes, starts;

  const PdfBlockTextMap({
    required this.text,
    required this.angle,
    required this.xs,
    required this.xe,
    required this.line,
    required this.obj,
    required this.chr,
    required this.bases,
    required this.sizes,
    required this.starts,
  });

  factory PdfBlockTextMap.ofBlock(PdfTextBlock b) {
    final sb = StringBuffer();
    final xs = <double>[], xe = <double>[];
    final line = <int>[], obj = <int>[], chr = <int>[];
    final bases = <double>[], sizes = <double>[], starts = <double>[];
    for (var i = 0; i < b.lines.length; i++) {
      final l = b.lines[i];
      final t = _LineText.of(l);
      if (i > 0) {
        // Satırları birleştiren boşluk: üst satırın sonunda durur.
        final end = xe.isEmpty ? b.lines[i - 1].frameRight : xe.last;
        sb.write(' ');
        xs.add(end);
        xe.add(end);
        line.add(i - 1);
        obj.add(obj.isEmpty ? -1 : obj.last);
        chr.add(-1);
      }
      sb.write(t.text);
      xs.addAll(t.xs);
      xe.addAll(t.xe);
      obj.addAll(t.obj);
      chr.addAll(t.chr);
      line.addAll(List.filled(t.xs.length, i));
      bases.add(l.frameBase);
      sizes.add(l.size);
      starts.add(l.frameLeft);
    }
    return PdfBlockTextMap(
      text: sb.toString(),
      angle: b.angle,
      xs: xs,
      xe: xe,
      line: line,
      obj: obj,
      chr: chr,
      bases: bases,
      sizes: sizes,
      starts: starts,
    );
  }

  int get length => xs.length;
  int get lineCount => bases.length;

  /// [offset] imlecinin satırı (0 … [length]).
  int lineOf(int offset) {
    if (xs.isEmpty) return 0;
    if (offset >= xs.length) return line.last;
    return line[offset.clamp(0, xs.length - 1)];
  }

  /// İmlecin çerçevedeki x'i.
  double caretX(int offset) {
    if (xs.isEmpty) return starts.isEmpty ? 0 : starts.first;
    if (offset <= 0) return xs.first;
    if (offset >= xs.length) return xe.last;
    // Satır başındaki imleç o satırın ilk karakterinde durur.
    return xs[offset];
  }

  /// İmleç çizgisi (sayfa uzayı): taban üstü/altı iki nokta.
  (double, double, double, double) caret(int offset) {
    final li = lineOf(offset), x = caretX(offset);
    final base = bases.isEmpty ? 0.0 : bases[li];
    final size = sizes.isEmpty ? 12.0 : sizes[li];
    final f = _Frame(angle);
    final y0 = base - size * 0.25, y1 = base + size * 0.9;
    return (f.px(x, y0), f.py(x, y0), f.px(x, y1), f.py(x, y1));
  }

  /// Sayfa noktasına en yakın imleç konumu.
  int offsetAt(double px, double py) {
    if (xs.isEmpty) return 0;
    final f = _Frame(angle);
    final fx = f.x(px, py), fy = f.y(px, py);
    var li = 0;
    var best = double.infinity;
    for (var i = 0; i < bases.length; i++) {
      final mid = bases[i] + sizes[i] * 0.3;
      final d = (mid - fy).abs();
      if (d < best) {
        best = d;
        li = i;
      }
    }
    int? first, last;
    for (var i = 0; i < xs.length; i++) {
      if (line[i] != li) continue;
      first ??= i;
      last = i;
    }
    if (first == null) {
      // Boş satır: önceki satırların sonu.
      var n = 0;
      for (var i = 0; i < xs.length; i++) {
        if (line[i] < li) n = i + 1;
      }
      return n;
    }
    for (var i = first; i <= last!; i++) {
      if (fx < (xs[i] + xe[i]) / 2) return i;
    }
    // Satır sonu: birleştirici boşluğun önü.
    return (xs[last] == xe[last] && text.codeUnitAt(last) == 0x20)
        ? last
        : last + 1;
  }

  /// [start]–[end] seçiminin satır dikdörtgenleri (sayfa uzayı, her biri
  /// dört köşe: sol-alt, sağ-alt, sağ-üst, sol-üst).
  List<List<double>> selection(int start, int end) {
    final out = <List<double>>[];
    if (xs.isEmpty) return out;
    final a = start.clamp(0, xs.length), b = end.clamp(0, xs.length);
    if (a >= b) return out;
    final f = _Frame(angle);
    for (var li = 0; li < bases.length; li++) {
      double? x0, x1;
      for (var i = a; i < b; i++) {
        if (line[i] != li) continue;
        x0 = x0 == null ? xs[i] : math.min(x0, xs[i]);
        x1 = x1 == null ? xe[i] : math.max(x1, xe[i]);
      }
      if (x0 == null || x1 == null || x1 - x0 < 0.01) continue;
      final y0 = bases[li] - sizes[li] * 0.25, y1 = bases[li] + sizes[li] * 0.9;
      out.add([
        f.px(x0, y0), f.py(x0, y0), f.px(x1, y0), f.py(x1, y0), //
        f.px(x1, y1), f.py(x1, y1), f.px(x0, y1), f.py(x0, y1),
      ]);
    }
    return out;
  }

  /// Sözcük sınırları ([offset]'i içeren sözcük).
  (int, int) wordAt(int offset) {
    if (text.isEmpty) return (0, 0);
    var a = offset.clamp(0, text.length), b = a;
    bool w(int i) => text.codeUnitAt(i) != 0x20 && text.codeUnitAt(i) != 0x0A;
    if (a == text.length || !w(a)) {
      if (a > 0 && w(a - 1)) {
        a--;
      } else {
        return (a, a);
      }
    }
    b = a;
    while (a > 0 && w(a - 1)) {
      a--;
    }
    while (b < text.length && w(b)) {
      b++;
    }
    return (a, b);
  }

  /// PDFium karakter aralığının ([from], [to]) bu bloktaki ofset aralığı —
  /// örtüşme yoksa null (görüntüleyici seçimi → blok, PS1).
  (int, int)? rangeOfChars(int from, int to) {
    int? a, b;
    for (var i = 0; i < chr.length; i++) {
      final c = chr[i];
      if (c < 0 || c < from || c >= to) continue;
      a ??= i;
      b = i + 1;
    }
    return a == null ? null : (a, b!);
  }
}

/// Nesneleri satırlara, satırları bloklara gruplar. Boş metinli nesneler
/// atlanır. [mode] satır kipinde her satır kendi bloğudur. [pageHeight]
/// verilirse üst/alt bilgi ve sayfa numarası işaretlenir.
List<PdfTextBlock> groupTextBlocks(
  List<PdfTextObjectInfo> objects, {
  PdfBlockMode mode = PdfBlockMode.paragraph,
  double? pageHeight,
  List<PdfRule> rules = const [],
  List<(double, double)> bullets = const [],
}) {
  // 1) Yazı yönüne (1° adımlı) ve görünürlüğe göre kovalar.
  final buckets = <(int, bool), List<PdfTextObjectInfo>>{};
  for (final o in objects) {
    if (o.text.trim().isEmpty) continue;
    final deg = (o.angle * 180 / math.pi).round();
    (buckets[(deg == -180 ? 180 : deg, o.invisible)] ??= []).add(o);
  }
  final blocks = <PdfTextBlock>[];
  for (final e in buckets.entries) {
    final angle = e.key.$1 * math.pi / 180;
    // Çizgiler yalnız dik metinde kullanılır (çerçeve = sayfa).
    final r = e.key.$1 == 0 ? rules : const <PdfRule>[];
    final lines = _lines(e.value, angle, r);
    if (mode == PdfBlockMode.line) {
      blocks.addAll([for (final l in lines) PdfTextBlock([l])]);
    } else {
      blocks.addAll(
          _paragraphs(lines, r, e.key.$1 == 0 ? bullets : const []));
    }
  }
  // 2) Okuma sırası: yukarıdan aşağı, soldan sağa (sayfa uzayı).
  blocks.sort((a, b) {
    final d = b.top.compareTo(a.top);
    if ((a.top - b.top).abs() > math.min(a.size, b.size) * 0.5) return d;
    return a.left.compareTo(b.left);
  });
  _classify(blocks, pageHeight);
  return blocks;
}

/// [xa]–[xb] arasında, [y0]–[y1] yüksekliğini kesen dikey çizgi var mı?
bool _vRuleBetween(
    List<PdfRule> rules, double xa, double xb, double y0, double y1) {
  final lo = math.min(xa, xb) - 0.5, hi = math.max(xa, xb) + 0.5;
  for (final r in rules) {
    if (!r.vertical) continue;
    if (r.x0 < lo || r.x0 > hi) continue;
    if (math.min(r.y0, r.y1) <= y1 && math.max(r.y0, r.y1) >= y0) return true;
  }
  return false;
}

/// [ya]–[yb] arasında, [x0]–[x1] genişliğiyle örtüşen yatay çizgi var mı?
bool _hRuleBetween(
    List<PdfRule> rules, double ya, double yb, double x0, double x1) {
  final lo = math.min(ya, yb), hi = math.max(ya, yb);
  for (final r in rules) {
    if (r.vertical) continue;
    if (r.y0 <= lo || r.y0 >= hi) continue;
    // Satırların ortak genişliğinin çoğunu kesmeli: bir-iki sözcüğün altı
    // çizgisi paragrafı bölmez.
    final cover = math.min(math.max(r.x0, r.x1), x1) -
        math.max(math.min(r.x0, r.x1), x0);
    if (cover > (x1 - x0) * 0.8) return true;
  }
  return false;
}

List<PdfTextLine> _lines(
    List<PdfTextObjectInfo> objects, double angle, List<PdfRule> rules) {
  final f = _Frame(angle);
  final fos = [for (final o in objects) f.of(o)]
    ..sort((a, b) {
      final d = b.base.compareTo(a.base);
      return d != 0 ? d : a.l.compareTo(b.l);
    });
  final lines = <PdfTextLine>[];
  for (final fo in fos) {
    PdfTextLine? hit;
    var hitGap = double.infinity;
    for (final l in lines.reversed) {
      final big = math.max(l.size, fo.size);
      final similar = math.min(l.size, fo.size) / big > 0.8;
      final dy = (l.frameBase - fo.base).abs();
      // Üst/alt simge: küçük punto, taban en çok 0,7 punto kaymış.
      if (dy > big * (similar ? 0.35 : 0.7)) {
        if (l.frameBase - fo.base > big * 2) break; // sıralı: daha yukarıdakiler
        continue;
      }
      // Yatayda bitişik (araya sütun/hücre boşluğu girmemiş).
      final gap = math.max(fo.l - l.frameRight, l.frameLeft - fo.r);
      if (gap < big * 1.6 && gap.abs() < hitGap) {
        final (xa, xb) =
            fo.l >= l.frameLeft ? (l.frameRight, fo.l) : (fo.r, l.frameLeft);
        if (gap > 0 &&
            _vRuleBetween(rules, xa, xb, fo.base, fo.base + big * 0.6)) {
          continue; // tablo hücresi sınırı
        }
        hit = l;
        hitGap = gap.abs();
      }
    }
    if (hit != null) {
      hit._add(fo.o);
    } else {
      lines.add(PdfTextLine([fo.o], angle: angle));
    }
  }
  // Ortak tabanlı, sonradan bitişik hâle gelen satır parçalarını birleştir
  // (nesneler taban sırasıyla geldiği için ortadaki parça geç gelebilir).
  lines.sort((a, b) {
    final d = b.frameBase.compareTo(a.frameBase);
    return d != 0 ? d : a.frameLeft.compareTo(b.frameLeft);
  });
  for (var i = 0; i < lines.length; i++) {
    for (var j = i + 1; j < lines.length; j++) {
      final a = lines[i], b = lines[j];
      final big = math.max(a.size, b.size);
      if (a.frameBase - b.frameBase > big * 0.35) break;
      if (math.min(a.size, b.size) / big <= 0.8) continue;
      final gap =
          math.max(b.frameLeft - a.frameRight, a.frameLeft - b.frameRight);
      final (xa, xb) = b.frameLeft >= a.frameLeft
          ? (a.frameRight, b.frameLeft)
          : (b.frameRight, a.frameLeft);
      if (gap < big * 1.6 &&
          !(gap > 0 &&
              _vRuleBetween(rules, xa, xb, a.frameBase, a.frameBase + big * 0.6))) {
        for (final o in b.objects) {
          a._add(o);
        }
        lines.removeAt(j);
        j--;
      }
    }
  }
  // Sekme durağı (dekont, 2026-11-13): "Etiket : değer" satırında ":" öteki
  // satırların ":" sütunuyla aynı x'te başlıyorsa satır orada bölünür — yoksa
  // yeniden dizim sütunu kaydırır. Kanıt: yakındaki ≥ 2 satır parçası o x'te
  // BAŞLIYOR (solunda etiketiyle) ve nesnenin önündeki boşluk sözcük arasından büyük.
  // ponytail: bütün satırlarda etiket ":"ye bitişikse (kanıt yok) bölünmez.
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    for (var k = 1; k < l.objects.length; k++) {
      final x = f.of(l.objects[k]).l;
      if (x - f.of(l.objects[k - 1]).r < l.size * 0.4) continue;
      final stops = lines
          .where((o) =>
              !identical(o, l) &&
              (o.frameLeft - x).abs() <= 0.75 &&
              (o.frameBase - l.frameBase).abs() <= l.size * 8 &&
              (o.size - l.size).abs() <= l.size * 0.12 &&
              // Kanıt satırı da bir tablo satırının SAĞ parçası olmalı
              // (solunda etiket var): liste maddesinin asılı devam satırları
              // madde imini metinden ayırmasın (wd_madde, wd_numarali).
              lines.any((m) =>
                  !identical(m, o) &&
                  (m.frameBase - o.frameBase).abs() < o.size * 0.35 &&
                  m.frameRight <= o.frameLeft))
          .length;
      if (stops < 2) continue;
      lines
        ..[i] = PdfTextLine(l.objects.sublist(0, k), angle: angle)
        ..insert(i + 1, PdfTextLine(l.objects.sublist(k), angle: angle));
      break; // sağ parça sıradaki turda yeniden bakılır
    }
  }
  return lines;
}

double _firstWordWidth(PdfTextLine l) {
  final t = _LineText.of(l);
  final sp = t.text.indexOf(' ');
  if (t.xs.isEmpty) return l.size * 2;
  final end = sp < 0 ? t.xe.last : t.xe[sp - 1 < 0 ? 0 : sp - 1];
  return end - t.xs.first;
}

List<PdfTextBlock> _paragraphs(List<PdfTextLine> lines, List<PdfRule> rules,
    List<(double, double)> bullets) {
  // Sütunun sağ kenarı: aynı soldan başlayan YAKIN satırların en sağı.
  // Uzaktaki geniş paragraflar sayılmaz: daraltılmış/taşınmış dar paragraf
  // (cihaz 2026-11-13) her satırda "erken bitti" sayılıp satırlara bölünüyordu.
  double colRight(PdfTextLine l) {
    var r = l.frameRight;
    for (final o in lines) {
      if ((o.frameBase - l.frameBase).abs() < l.size * 3 &&
          (o.frameLeft - l.frameLeft).abs() < l.size * 4 &&
          (o.size - l.size).abs() < l.size * 0.12) {
        r = math.max(r, o.frameRight);
      }
    }
    return r;
  }

  // Vektör madde imi: satırın hemen solunda, satır yüksekliğinde küçük şekil.
  bool bulleted(PdfTextLine l) {
    for (final (x, y) in bullets) {
      final dx = l.frameLeft - x;
      if (dx > 0 &&
          dx < l.size * 2.5 &&
          y > l.frameBase - l.size * 0.1 &&
          y < l.frameBase + l.size * 0.8) {
        return true;
      }
    }
    return false;
  }

  // Tablo satırı (dekont, 2026-11-13): aynı tabanda
  // başka satır parçaları ("etiket | : değer").
  Iterable<PdfTextLine> mates(PdfTextLine l) => lines.where((o) =>
      !identical(o, l) && (o.frameBase - l.frameBase).abs() < l.size * 0.35);
  bool tableRows(PdfTextBlock b, PdfTextLine l) {
    final last = b.lines.last;
    final ml = mates(l).toList(), mb = mates(last).toList();
    // 1) Birleşecek alanın İÇİNDE aynı tabanda başka metin: paragrafın
    //    satırı olamaz ("Etiket : değer" altındaki "Etiket" + yanında değer).
    final x0 = math.min(b.frameLeft, l.frameLeft);
    final x1 = math.max(b.frameRight, l.frameRight);
    if ([...ml, ...mb].any((o) => o.frameLeft < x1 && o.frameRight > x0)) {
      return true;
    }
    // 2) İki satırın da yanında aynı soldan başlayan parça (ızgara) ve satır
    //    aralığı gövde metnine göre geniş: alt alta hücreler.
    // ponytail: sık aralıklı (< 1,45 punto) tablolar eskisi gibi
    // birleşir; gerekirse sütun doluluk ölçüsüyle ayrılır.
    final tol = math.max(1.0, l.size * 0.25);
    return last.frameBase - l.frameBase > l.size * 1.45 &&
        ml.any((x) => mb.any((y) => (x.frameLeft - y.frameLeft).abs() <= tol));
  }

  lines.sort((a, b) {
    final d = b.frameBase.compareTo(a.frameBase);
    return d != 0 ? d : a.frameLeft.compareTo(b.frameLeft);
  });
  final blocks = <PdfTextBlock>[];
  final open = <PdfTextBlock>[];
  for (final l in lines) {
    PdfTextBlock? hit;
    for (final b in open.reversed) {
      if (!bulleted(l) &&
          !tableRows(b, l) &&
          _continues(b, l, colRight(l)) &&
          !_hRuleBetween(rules, b.lines.last.frameBase, l.frameBase + l.size * 0.7,
              math.max(b.lines.last.frameLeft, l.frameLeft),
              math.min(b.lines.last.frameRight, l.frameRight))) {
        hit = b;
        break;
      }
    }
    if (hit != null) {
      hit.lines.add(l);
      hit._map = null;
    } else {
      final b = PdfTextBlock([l]);
      open.add(b);
      blocks.add(b);
    }
  }
  return blocks;
}

/// [l], [b] bloğunun devamı mı (aynı paragrafın sıradaki satırı)?
bool _continues(PdfTextBlock b, PdfTextLine l, double colRight) {
  final last = b.lines.last;
  final size = last.size;
  final dy = last.frameBase - l.frameBase;
  if (dy <= size * 0.3 || dy > size * 1.7) return false;
  if ((l.size - size).abs() > size * 0.12) return false;
  final overlap = math.min(last.frameRight, l.frameRight) -
      math.max(last.frameLeft, l.frameLeft);
  if (overlap <= 0) return false;
  if (last.bold != l.bold) {
    // Kalın başlık → gövde; satır içi vurgu ise satırın tamamı değişmez.
    return false;
  }
  final lt = l.text;
  // Liste maddesi her zaman yeni blok başlatır.
  if (_markerRe.hasMatch(lt)) return false;
  final tol = math.max(1.0, size * 0.25);
  final n = b.lines.length;
  if (n >= 2) {
    // Yerleşik satır aralığından belirgin büyük boşluk = paragraf arası.
    final lead = (b.lines.first.frameBase - last.frameBase) / (n - 1);
    if (dy > lead * 1.25 + 0.5) return false;
    if (dy < lead * 0.75 - 0.5) return false;
  }
  final centered = ((last.frameLeft + last.frameRight) / 2 -
              (l.frameLeft + l.frameRight) / 2)
          .abs() <=
      tol &&
      (last.frameLeft - l.frameLeft).abs() > tol;
  if (centered) return true;
  // Ortalı blok: bütün satırlar aynı merkezde → girinti kuralı işlemez.
  double mid(PdfTextLine x) => (x.frameLeft + x.frameRight) / 2;
  if (n >= 2 &&
      b.lines.every((x) => (mid(x) - mid(l)).abs() <= tol) &&
      b.lines.any((x) => (x.frameLeft - b.lines.first.frameLeft).abs() > tol)) {
    return true;
  }
  // Sağa yaslı blok: bütün satırlar aynı sağ kenarda, sollar değişken.
  if (n >= 2 &&
      b.lines.every((x) => (x.frameRight - l.frameRight).abs() <= tol) &&
      b.lines.any((x) => (x.frameLeft - b.lines.first.frameLeft).abs() > tol)) {
    return true;
  }
  final bodyLeft = n >= 2 ? b.bodyLeft : last.frameLeft;
  final hasMarker = _markerRe.hasMatch(b.lines.first.text);
  // Girintili satır: yerleşik gövdeden içeride başlıyorsa yeni paragrafın
  // ilk satırıdır (tek satırlı blokta: liste maddesinin asılı devamı olabilir).
  if (l.frameLeft > bodyLeft + tol) {
    if (n == 1 && hasMarker) {
      // asılı girinti: devam
    } else if (n == 1 && (l.frameRight - last.frameRight).abs() <= tol) {
      // sağa yaslı iki satır: devam
    } else {
      return false;
    }
  }
  // Önceki satır erken bittiyse (sıradaki satırın ilk sözcüğü sığardı)
  // paragraf orada bitmiştir. Sağ kenar: bloğun en geniş satırı ile bu satır.
  final right = math.max(math.max(b.frameRight, l.frameRight), colRight);
  if (last.frameRight + _firstWordWidth(l) + size * 0.3 < right - tol) {
    // Sağa yaslı / ortalı değilse.
    if ((last.frameRight - l.frameRight).abs() > tol) return false;
  }
  return true;
}

final _pageNoRe = RegExp(
    r'^(?:(?:sayfa|page|s\.|p\.)\s*)?\d{1,4}(?:\s*(?:/|-|of|/\s*)\s*\d{1,4})?$|^[-–—]\s*\d{1,4}\s*[-–—]$',
    caseSensitive: false);

void _classify(List<PdfTextBlock> blocks, double? pageHeight) {
  if (blocks.isEmpty) return;
  // Gövde puntosu: karakter ağırlıklı en yaygın punto.
  final hist = <int, int>{};
  for (final b in blocks) {
    final k = (b.size * 2).round();
    hist[k] = (hist[k] ?? 0) + b.text.length;
  }
  final body = hist.entries.reduce((a, b) => a.value >= b.value ? a : b).key / 2;
  for (final b in blocks) {
    final t = b.text;
    if (pageHeight != null && b.lines.length <= 2 && b.angle == 0) {
      final head = b.bottom > pageHeight * 0.93;
      final foot = b.top < pageHeight * 0.07;
      if (head || foot) {
        b.kind = _pageNoRe.hasMatch(t.trim())
            ? PdfBlockKind.pageNumber
            : head
                ? PdfBlockKind.header
                : PdfBlockKind.footer;
        continue;
      }
    }
    if (b.marker != null) {
      b.kind = PdfBlockKind.listItem;
    } else if (b.lines.length <= 3 &&
        (b.size > body * 1.15 || (b.lines.every((l) => l.bold) && t.length < 120))) {
      b.kind = PdfBlockKind.heading;
    }
  }
}

/// [block]'u [lineIndex] satırından ikiye böler (o satır ikinci bloğun ilk
/// satırı olur). Bölünemiyorsa tek elemanlı liste.
List<PdfTextBlock> splitTextBlock(PdfTextBlock block, int lineIndex) {
  if (lineIndex <= 0 || lineIndex >= block.lines.length) return [block];
  return [
    PdfTextBlock(block.lines.sublist(0, lineIndex), kind: block.kind),
    PdfTextBlock(block.lines.sublist(lineIndex), kind: block.kind),
  ];
}

/// Aynı yazı yönündeki blokları tek blokta birleştirir (satırlar yukarıdan
/// aşağı). Yönler farklıysa null.
PdfTextBlock? mergeTextBlocks(List<PdfTextBlock> blocks) {
  if (blocks.isEmpty) return null;
  final angle = blocks.first.angle;
  if (blocks.any((b) => (b.angle - angle).abs() > 1e-6)) return null;
  final lines = [for (final b in blocks) ...b.lines]
    ..sort((a, b) => b.frameBase.compareTo(a.frameBase));
  return PdfTextBlock(lines, kind: blocks.first.kind);
}

/// Görüntüleyici seçimi → blok (PS1): PDFium karakter aralığıyla en çok
/// örtüşen blok ve blok içi ofset aralığı. Örtüşme yoksa null.
(int, int, int)? blockForCharRange(
    List<PdfTextBlock> blocks, int from, int to) {
  (int, int, int)? best;
  var bestLen = 0;
  for (var i = 0; i < blocks.length; i++) {
    final map = blocks[i].map;
    var n = 0;
    for (final c in map.chr) {
      if (c >= from && c < to) n++;
    }
    if (n > bestLen) {
      final r = map.rangeOfChars(from, to)!;
      bestLen = n;
      best = (i, r.$1, r.$2);
    }
  }
  return best;
}
