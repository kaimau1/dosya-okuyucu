import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'fm/file_ops.dart';
import 'fm/fs_events.dart';
import 'fm/safe_write.dart';

/// **Görsel düzenleyici** (Faz 10, N7; Faz 32 "2.0"): kırp · döndür/çevir ·
/// serbest açı · ayarlar (11) · filtreler (10) · işaretle (kalem, vurgulayıcı,
/// şekiller, taşınabilir yazı, bulanıklaştır/pikselleştir).
///
/// ## Tek çizim yolu
/// Önizleme ile kaydedilen dosya AYNI [paintEdits] fonksiyonundan çıkar:
/// ekranda ne görülüyorsa dosyaya o yazılır. Çizim Flutter tuvalinde
/// yapıldığı için yazı işaretleri Türkçe karakterleri sistem yazı tipiyle
/// doğru çizer (`image` paketinin bitmap yazı tipinde ş/ğ/ı yok).
/// Faz 32 (IM1): önizleme ekran boyunda bir **vekil** görüntüyle çizilir
/// ([previewProxy]); bütün ölçüler kutuya oranlı olduğundan vekil ile tam
/// çözünürlük aynı sonucu verir — tam çözünürlük yalnız kaydederken.
///
/// ## Koordinatlar
/// Kırpma dikdörtgeni ve işaretler **yönlendirilmiş görselin** (döndürme +
/// çevirme sonrası) 0..1 normalleştirilmiş uzayında tutulur: döndürünce
/// işaretler fotoğrafla birlikte döner ([rotated]/[flipped] dönüştürür),
/// kırpmayı değiştirmek işaretleri kaydırmaz.
class ImageEdits {
  const ImageEdits({
    this.quarterTurns = 0,
    this.flipH = false,
    this.angle = 0,
    this.crop = const Rect.fromLTWH(0, 0, 1, 1),
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.exposure = 0,
    this.temperature = 0,
    this.tint = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.vibrance = 0,
    this.sharpness = 0,
    this.vignette = 0,
    this.filter = '',
    this.filterStrength = 1,
    this.marks = const [],
    this.scale = 1,
  });

  /// Saat yönünde 90° adım sayısı (0..3).
  final int quarterTurns;
  final bool flipH;

  /// Serbest düzeltme açısı (derece, −45..45). Görsel kutuyu boşluksuz
  /// dolduracak kadar büyütülerek döner; kırpma/işaretler etkilenmez.
  final double angle;

  /// Yönlendirilmiş görselde 0..1 kırpma dikdörtgeni.
  final Rect crop;

  /// −1..1; 0 = değişmez. Keskinlik ve vinyet 0..1.
  final double brightness, contrast, saturation, exposure, temperature, tint,
      highlights, shadows, vibrance, sharpness, vignette;

  /// [imageFilters] anahtarı; '' = filtre yok. Şiddet 0..1.
  final String filter;
  final double filterStrength;
  final List<ImageMark> marks;

  /// Çıktı ölçeği (Faz 14b — düzenleyicide "Boyut" sekmesi): kırpılmış
  /// bölgenin piksel ölçüsü bununla çarpılır. 1 = olduğu gibi. Kırp → boyut
  /// → kaydet tek akış: ayrı bir boyutlandırma işi gerekmez.
  final double scale;

  bool get isIdentity =>
      quarterTurns == 0 &&
      !flipH &&
      angle == 0 &&
      crop == const Rect.fromLTWH(0, 0, 1, 1) &&
      !hasColor &&
      sharpness == 0 &&
      vignette == 0 &&
      marks.isEmpty &&
      scale == 1;

  bool get hasColor =>
      brightness != 0 ||
      contrast != 0 ||
      saturation != 0 ||
      exposure != 0 ||
      temperature != 0 ||
      tint != 0 ||
      highlights != 0 ||
      shadows != 0 ||
      vibrance != 0 ||
      (filter.isNotEmpty && filterStrength > 0);

  /// Ayar adı → değer (düzenleyicinin tek kaydırıcısı bunun üstünden).
  double adjust(String key) => switch (key) {
        'brightness' => brightness,
        'contrast' => contrast,
        'saturation' => saturation,
        'exposure' => exposure,
        'temperature' => temperature,
        'tint' => tint,
        'highlights' => highlights,
        'shadows' => shadows,
        'vibrance' => vibrance,
        'sharpness' => sharpness,
        'vignette' => vignette,
        _ => 0,
      };

  ImageEdits withAdjust(String key, double v) => switch (key) {
        'brightness' => copyWith(brightness: v),
        'contrast' => copyWith(contrast: v),
        'saturation' => copyWith(saturation: v),
        'exposure' => copyWith(exposure: v),
        'temperature' => copyWith(temperature: v),
        'tint' => copyWith(tint: v),
        'highlights' => copyWith(highlights: v),
        'shadows' => copyWith(shadows: v),
        'vibrance' => copyWith(vibrance: v),
        'sharpness' => copyWith(sharpness: v),
        'vignette' => copyWith(vignette: v),
        _ => this,
      };

  ImageEdits copyWith({
    int? quarterTurns,
    bool? flipH,
    double? angle,
    Rect? crop,
    double? brightness,
    double? contrast,
    double? saturation,
    double? exposure,
    double? temperature,
    double? tint,
    double? highlights,
    double? shadows,
    double? vibrance,
    double? sharpness,
    double? vignette,
    String? filter,
    double? filterStrength,
    List<ImageMark>? marks,
    double? scale,
  }) =>
      ImageEdits(
        quarterTurns: quarterTurns ?? this.quarterTurns,
        flipH: flipH ?? this.flipH,
        angle: angle ?? this.angle,
        crop: crop ?? this.crop,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        exposure: exposure ?? this.exposure,
        temperature: temperature ?? this.temperature,
        tint: tint ?? this.tint,
        highlights: highlights ?? this.highlights,
        shadows: shadows ?? this.shadows,
        vibrance: vibrance ?? this.vibrance,
        sharpness: sharpness ?? this.sharpness,
        vignette: vignette ?? this.vignette,
        filter: filter ?? this.filter,
        filterStrength: filterStrength ?? this.filterStrength,
        marks: marks ?? this.marks,
        scale: scale ?? this.scale,
      );

  /// Saat yönünde 90° daha: kırpma ve işaretler de döner.
  ImageEdits rotated() => copyWith(
        // Çizimde çevirme döndürmeden SONRA uygulanıyor (F·Rᵠ); ekranda
        // saat yönü döndürme R·F·Rᵠ = F·Rᵠ⁻¹ → çevrilmişken adım tersine.
        quarterTurns: (quarterTurns + (flipH ? 3 : 1)) % 4,
        crop: _mapRect(crop, _rot),
        marks: [for (final m in marks) m.mapped(_rot, turn: math.pi / 2)],
      );

  /// Yatay çevir. Serbest açı aynada ters döner.
  ImageEdits flipped() => copyWith(
        flipH: !flipH,
        angle: -angle,
        crop: _mapRect(crop, _flip),
        marks: [for (final m in marks) m.mapped(_flip, mirror: true)],
      );

  /// Dikey çevir = yatay çevir + 180° (ayrı alan gerekmez).
  ImageEdits flippedV() => flipped().rotated().rotated();

  static Offset _rot(Offset o) => Offset(1 - o.dy, o.dx);
  static Offset _flip(Offset o) => Offset(1 - o.dx, o.dy);
  static Rect _mapRect(Rect r, Offset Function(Offset) f) =>
      Rect.fromPoints(f(r.topLeft), f(r.bottomRight));
}

enum MarkKind { pen, highlighter, arrow, line, rect, ellipse, text, blur, pixelate }

/// Bir işaret: çizgi (kalem/vurgulayıcı/bulanıklaştır/pikselleştir fırçası),
/// iki noktalı şekil (ok, çizgi, dikdörtgen, elips — ilk→son nokta) ya da
/// yazı (ilk nokta = yazının ORTASI). Kalınlık/yazı boyu görselin kısa
/// kenarına oranla tutulur — 12 MP fotoğrafta da vekil görüntüde de aynı.
class ImageMark {
  const ImageMark({
    required this.kind,
    required this.points,
    required this.color,
    this.size = 0.012,
    this.text = '',
    this.opacity = 1,
    this.rotation = 0,
    this.font = 'sans',
    this.background = false,
  });

  final MarkKind kind;
  final List<Offset> points;
  final Color color;
  final double size;
  final String text;
  final double opacity;

  /// Yazı nesnesinin dönüşü (radyan, ortası çevresinde).
  final double rotation;

  /// 'sans' · 'serif' · 'mono'.
  final String font;

  /// Yazının arkasında okunurluk kutusu.
  final bool background;

  bool get isShape =>
      kind == MarkKind.arrow ||
      kind == MarkKind.line ||
      kind == MarkKind.rect ||
      kind == MarkKind.ellipse;

  ImageMark copyWith({
    List<Offset>? points,
    Color? color,
    double? size,
    String? text,
    double? opacity,
    double? rotation,
    String? font,
    bool? background,
  }) =>
      ImageMark(
        kind: kind,
        points: points ?? this.points,
        color: color ?? this.color,
        size: size ?? this.size,
        text: text ?? this.text,
        opacity: opacity ?? this.opacity,
        rotation: rotation ?? this.rotation,
        font: font ?? this.font,
        background: background ?? this.background,
      );

  ImageMark mapped(Offset Function(Offset) f,
          {double turn = 0, bool mirror = false}) =>
      copyWith(
        points: [for (final o in points) f(o)],
        rotation: (mirror ? -rotation : rotation) + turn,
      );

  ImageMark withPoint(Offset o) => copyWith(
        points: isShape && points.length > 1
            ? [points.first, o]
            : [...points, o],
      );

  ImageMark shifted(Offset d) =>
      copyWith(points: [for (final o in points) o + d]);
}

// ── renk ────────────────────────────────────────────────────────────────────

const _identity = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// 4×5 renk matrisi bileşimi: önce [b], sonra [a].
List<double> _mul(List<double> a, List<double> b) => [
      for (var i = 0; i < 4; i++)
        for (var j = 0; j < 5; j++)
          a[i * 5] * b[j] +
              a[i * 5 + 1] * b[5 + j] +
              a[i * 5 + 2] * b[10 + j] +
              a[i * 5 + 3] * b[15 + j] +
              (j == 4 ? a[i * 5 + 4] : 0),
    ];

List<double> _gain(double r, double g, double b, [double off = 0]) => [
      r, 0, 0, 0, off, //
      0, g, 0, 0, off,
      0, 0, b, 0, off,
      0, 0, 0, 1, 0,
    ];

/// Parlaklık/kontrast/doygunluk → 5×4 renk matrisi (ColorFilter.matrix).
/// Sıra: doygunluk → kontrast (128 çevresinde) → parlaklık (±%50 kaydırma).
List<double> colorMatrix(double brightness, double contrast, double saturation) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final s = 1 + saturation;
  final k = 1 + contrast; // 0..2
  final off = 128 * (1 - k) + brightness * 127.5;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  return [
    k * (sr + s), k * sg, k * sb, 0, off, //
    k * sr, k * (sg + s), k * sb, 0, off,
    k * sr, k * sg, k * (sb + s), 0, off,
    0, 0, 0, 1, 0,
  ];
}

/// Ayarların tek matrisi. Vurgu/gölge ve canlılık matris olduğundan
/// **yaklaşıktır** (vurgu: siyah sabit kazanç; gölge: beyaz sabit kaldırma;
/// canlılık: yarım güçte doygunluk) — tek geçişte, her karede ucuz.
List<double> adjustMatrix({
  double brightness = 0,
  double contrast = 0,
  double saturation = 0,
  double exposure = 0,
  double temperature = 0,
  double tint = 0,
  double highlights = 0,
  double shadows = 0,
  double vibrance = 0,
}) {
  var m = _identity;
  if (exposure != 0) {
    final g = math.pow(2, exposure * 1.5).toDouble();
    m = _mul(_gain(g, g, g), m);
  }
  if (temperature != 0 || tint != 0) {
    m = _mul(
        _gain(1 + 0.15 * temperature + 0.05 * tint, 1 - 0.15 * tint,
            1 - 0.15 * temperature + 0.05 * tint),
        m);
  }
  if (highlights != 0) {
    final g = 1 + 0.25 * highlights;
    m = _mul(_gain(g, g, g), m);
  }
  if (shadows != 0) {
    final a = 0.25 * shadows;
    m = _mul(_gain(1 - a, 1 - a, 1 - a, 255 * a), m);
  }
  final sat = saturation + 0.5 * vibrance;
  if (brightness != 0 || contrast != 0 || sat != 0) {
    m = _mul(colorMatrix(brightness, contrast, sat), m);
  }
  return m;
}

/// Hazır filtreler (Faz 32): anahtar → (ad anahtarı, matris).
final Map<String, (String, List<double>)> imageFilters = {
  'vivid': ('ied.f_vivid', adjustMatrix(saturation: 0.4, contrast: 0.12)),
  'warm': ('ied.f_warm', adjustMatrix(temperature: 0.7, saturation: 0.1)),
  'cool': ('ied.f_cool', adjustMatrix(temperature: -0.7)),
  'mono': ('ied.f_mono', adjustMatrix(saturation: -1, contrast: 0.1)),
  'sepia': (
    'ied.f_sepia',
    const [
      0.393, 0.769, 0.189, 0, 0, //
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0, 0, 0, 1, 0,
    ]
  ),
  'fade': (
    'ied.f_fade',
    adjustMatrix(contrast: -0.25, shadows: 0.5, saturation: -0.25)
  ),
  'drama': (
    'ied.f_drama',
    adjustMatrix(contrast: 0.45, saturation: -0.3, exposure: -0.12)
  ),
  'matte': (
    'ied.f_matte',
    adjustMatrix(shadows: 0.35, highlights: -0.15, saturation: -0.1)
  ),
  'retro': (
    'ied.f_retro',
    adjustMatrix(temperature: 0.5, contrast: -0.15, shadows: 0.3, saturation: -0.3)
  ),
  // Belge: gri + güçlü kontrast + kâğıdı beyazlat (taranmış sayfa).
  'document': (
    'ied.f_document',
    adjustMatrix(saturation: -1, contrast: 0.9, brightness: 0.2)
  ),
};

/// [ImageEdits]'in son renk matrisi (ayarlar → filtre, şiddetle karışık).
List<double> editMatrix(ImageEdits e) {
  var m = adjustMatrix(
    brightness: e.brightness,
    contrast: e.contrast,
    saturation: e.saturation,
    exposure: e.exposure,
    temperature: e.temperature,
    tint: e.tint,
    highlights: e.highlights,
    shadows: e.shadows,
    vibrance: e.vibrance,
  );
  final f = imageFilters[e.filter]?.$2;
  if (f != null && e.filterStrength > 0) {
    final s = e.filterStrength.clamp(0.0, 1.0);
    m = _mul([
      for (var i = 0; i < 20; i++) _identity[i] + s * (f[i] - _identity[i])
    ], m);
  }
  return m;
}

// ── çizim ───────────────────────────────────────────────────────────────────

/// Yönlendirilmiş (döndürülmüş) görsel boyutu.
Size orientedSize(ui.Image src, ImageEdits e) => e.quarterTurns.isOdd
    ? Size(src.height.toDouble(), src.width.toDouble())
    : Size(src.width.toDouble(), src.height.toDouble());

/// Serbest açıyla dönen görselin [w]×[h] kutuyu boşluksuz örtme çarpanı.
double coverScale(double w, double h, double degrees) {
  if (degrees == 0) return 1;
  final t = degrees.abs() * math.pi / 180;
  final c = math.cos(t), s = math.sin(t);
  return math.max((w * c + h * s) / w, (w * s + h * c) / h);
}

/// [img]'yi düzenlemenin geometrisiyle [box]'a çizer. Hedef ölçü kutudan
/// gelir, görselin pikselinden değil: vekil, mozaik ve tam çözünürlük aynı
/// yere düşer.
void _drawOriented(
    Canvas canvas, ui.Image img, ImageEdits e, Rect box, Paint paint) {
  final w = e.quarterTurns.isOdd ? box.height : box.width;
  final h = e.quarterTurns.isOdd ? box.width : box.height;
  canvas.save();
  canvas.translate(box.center.dx, box.center.dy);
  if (e.angle != 0) {
    canvas.rotate(e.angle * math.pi / 180);
    final k = coverScale(box.width, box.height, e.angle);
    canvas.scale(k, k);
  }
  if (e.flipH) canvas.scale(-1, 1);
  canvas.rotate(e.quarterTurns * math.pi / 2);
  canvas.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    Rect.fromCenter(center: Offset.zero, width: w, height: h),
    paint,
  );
  canvas.restore();
}

Paint _imagePaint(ImageEdits e) {
  final paint = Paint()..filterQuality = FilterQuality.medium;
  if (e.hasColor) paint.colorFilter = ColorFilter.matrix(editMatrix(e));
  return paint;
}

/// [src]'yi düzenlemelerle [box] içine çizer. [box] YÖNLENDİRİLMİŞ görselin
/// tamamının tuvaldeki yeri; kırpma dışı kısım çağıranın kırpmasıdır
/// (önizlemede kırpma kipinde bilerek görünür kalır).
void paintEdits(Canvas canvas, ui.Image src, ImageEdits e, Rect box) {
  canvas.save();
  if (e.angle != 0) canvas.clipRect(box);
  _drawOriented(canvas, src, e, box, _imagePaint(e));
  canvas.restore();
  if (e.vignette > 0) {
    // Vinyet kırpılmış sonucun ortasına göre — ne kaydedilirse o.
    final r = Rect.fromLTRB(
      box.left + e.crop.left * box.width,
      box.top + e.crop.top * box.height,
      box.left + e.crop.right * box.width,
      box.top + e.crop.bottom * box.height,
    );
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          r.center,
          r.longestSide * 0.72,
          [
            const Color.fromRGBO(0, 0, 0, 0),
            Color.fromRGBO(0, 0, 0, 0.8 * e.vignette.clamp(0.0, 1.0)),
          ],
          const [0.45, 1],
        ),
    );
  }
  paintMarks(canvas, e.marks, box, src: src, edits: e);
}

final _mosaics = Expando<ui.Image>('mosaic');

/// Pikselleştirme için kısa kenarı 40 blok olan küçük kopya (görsel başına
/// bir kez). Büyütülürken yumuşatılmadan çizilir → bloklar; özgün ayrıntı
/// çıktıya hiç girmez (geri döndürülemez).
ui.Image mosaicOf(ui.Image src) => _mosaics[src] ??= () {
      final k = 40 / math.min(src.width, src.height);
      final w = math.max(1, (src.width * k).round());
      final h = math.max(1, (src.height * k).round());
      final rec = ui.PictureRecorder();
      Canvas(rec).drawImageRect(
        src,
        Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return rec.endRecording().toImageSync(w, h);
    }();

/// Yazı nesnesinin çizicisi (boy kutunun kısa kenarına oranlı).
TextPainter markTextPainter(ImageMark m, double unit) => TextPainter(
      text: TextSpan(
        text: m.text,
        style: TextStyle(
          color: m.color.withValues(alpha: m.color.a * m.opacity),
          fontSize: m.size * 5 * unit,
          fontWeight: FontWeight.w600,
          fontFamily: switch (m.font) {
            'serif' => 'serif',
            'mono' => 'monospace',
            _ => null,
          },
          shadows: m.background
              ? null
              : const [Shadow(blurRadius: 3, color: Color(0x88000000))],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

/// İşaretin ekrandaki (döndürülmemiş) sınır kutusu — seçim ve dokunma için.
/// Yazıda kutu ortası [ImageMark.points] ilk noktasıdır; dönüş ayrıca.
Rect markBounds(ImageMark m, Rect box) {
  final unit = box.shortestSide;
  Offset at(Offset n) => box.topLeft + Offset(n.dx * box.width, n.dy * box.height);
  if (m.points.isEmpty) return Rect.zero;
  if (m.kind == MarkKind.text) {
    final tp = markTextPainter(m, unit);
    final pad = m.background ? tp.height * 0.25 : 0.0;
    return Rect.fromCenter(
        center: at(m.points.first),
        width: tp.width + 2 * pad,
        height: tp.height + 2 * pad);
  }
  var r = Rect.fromPoints(at(m.points.first), at(m.points.first));
  for (final o in m.points) {
    r = r.expandToInclude(Rect.fromPoints(at(o), at(o)));
  }
  final w = m.size * unit * (m.kind == MarkKind.arrow ? 4 : 1);
  return r.inflate(w / 2);
}

/// [local] noktasındaki en üstteki işaretin sırası (yoksa null).
int? hitMark(List<ImageMark> marks, Rect box, Offset local, {double slop = 12}) {
  for (var i = marks.length - 1; i >= 0; i--) {
    final m = marks[i];
    final r = markBounds(m, box).inflate(slop);
    var p = local;
    if (m.rotation != 0 && m.kind == MarkKind.text) {
      final d = local - r.center;
      final c = math.cos(-m.rotation), s = math.sin(-m.rotation);
      p = r.center + Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
    }
    if (r.contains(p)) return i;
  }
  return null;
}

/// Çizgi işaretinin yolu (kalem, vurgulayıcı, fırçalar).
Path _strokePath(ImageMark m, Offset Function(Offset) at) {
  final first = at(m.points.first);
  final path = Path()..moveTo(first.dx, first.dy);
  if (m.points.length == 1) {
    path.lineTo(first.dx + 0.01, first.dy);
  }
  for (final o in m.points.skip(1)) {
    final q = at(o);
    path.lineTo(q.dx, q.dy);
  }
  return path;
}

/// İşaretleri çizer. Bulanıklaştır/pikselleştir fırçası görüntüyü ([src],
/// [edits]) fırça izinin içinde yeniden çizer — onlar olmadan atlanır.
void paintMarks(Canvas canvas, List<ImageMark> marks, Rect box,
    {ui.Image? src, ImageEdits? edits}) {
  final unit = box.shortestSide;
  Offset at(Offset n) => box.topLeft + Offset(n.dx * box.width, n.dy * box.height);
  for (final m in marks) {
    if (m.points.isEmpty) continue;
    final color = m.color.withValues(alpha: m.color.a * m.opacity);
    final stroke = Paint()
      ..color = color
      ..strokeWidth = m.size * unit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (m.kind) {
      case MarkKind.pen:
        canvas.drawPath(_strokePath(m, at), stroke);
      case MarkKind.highlighter:
        // Fosforlu kalem: düz uç, alttaki çizimi örtmeden çoğaltır.
        stroke
          ..strokeCap = StrokeCap.square
          ..blendMode = BlendMode.multiply;
        canvas.drawPath(_strokePath(m, at), stroke);
      case MarkKind.blur:
      case MarkKind.pixelate:
        if (src == null || edits == null) continue;
        canvas.saveLayer(box, Paint());
        canvas.drawPath(
            _strokePath(m, at),
            // Maske: varsayılan opak siyah yeter (yalnız alfa kullanılır).
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = m.size * unit
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round);
        final layer = Paint()..blendMode = BlendMode.srcIn;
        if (m.kind == MarkKind.blur) {
          final sigma = unit * 0.025;
          layer.imageFilter = ui.ImageFilter.blur(
              sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp);
        }
        canvas.saveLayer(box, layer);
        canvas.clipRect(box);
        _drawOriented(
          canvas,
          m.kind == MarkKind.pixelate ? mosaicOf(src) : src,
          edits,
          box,
          _imagePaint(edits)
            ..filterQuality = m.kind == MarkKind.pixelate
                ? FilterQuality.none
                : FilterQuality.medium,
        );
        canvas.restore();
        canvas.restore();
      case MarkKind.arrow:
      case MarkKind.line:
        if (m.points.length < 2) continue;
        final a = at(m.points.first), b = at(m.points.last);
        canvas.drawLine(a, b, stroke);
        if (m.kind == MarkKind.line) continue;
        final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
        final head = stroke.strokeWidth * 4;
        for (final d in [math.pi * 0.8, -math.pi * 0.8]) {
          canvas.drawLine(
              b, b + Offset(math.cos(ang + d), math.sin(ang + d)) * head, stroke);
        }
      case MarkKind.rect:
      case MarkKind.ellipse:
        if (m.points.length < 2) continue;
        final r = Rect.fromPoints(at(m.points.first), at(m.points.last));
        stroke.strokeJoin = StrokeJoin.miter;
        m.kind == MarkKind.rect
            ? canvas.drawRect(r, stroke)
            : canvas.drawOval(r, stroke);
      case MarkKind.text:
        final tp = markTextPainter(m, unit);
        final c = at(m.points.first);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        if (m.rotation != 0) canvas.rotate(m.rotation);
        if (m.background) {
          final pad = tp.height * 0.25;
          final light = m.color.computeLuminance() > 0.5;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: tp.width + 2 * pad,
                  height: tp.height + 2 * pad),
              Radius.circular(pad),
            ),
            Paint()
              ..color = light
                  ? Color.fromRGBO(0, 0, 0, 0.6 * m.opacity)
                  : Color.fromRGBO(255, 255, 255, 0.85 * m.opacity),
          );
        }
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
    }
  }
}

// ── vekil, keskinlik ─────────────────────────────────────────────────────────

/// Önizleme vekili (Faz 32, IM1): uzun kenarı [maxSide]'ı aşan görselin
/// küçültülmüş kopyası; aşmıyorsa null (özgün kullanılır).
Future<ui.Image?> previewProxy(ui.Image src, {int maxSide = 2048}) async {
  final longest = math.max(src.width, src.height);
  if (longest <= maxSide) return null;
  final k = maxSide / longest;
  final w = math.max(1, (src.width * k).round());
  final h = math.max(1, (src.height * k).round());
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(
    src,
    Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  return rec.endRecording().toImage(w, h);
}

/// Keskinleştirilmiş kopya (3×3 keskin olmayan maske, isolate'te). Önizlemede
/// vekile, kayıtta tam çözünürlüğe aynı işlem uygulanır.
Future<ui.Image> sharpened(ui.Image src, double amount) async {
  final raw = (await src.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final out = await compute(
      _sharpen, (raw.buffer.asUint8List(), src.width, src.height, amount));
  final buffer = await ui.ImmutableBuffer.fromUint8List(out);
  final desc = ui.ImageDescriptor.raw(buffer,
      width: src.width,
      height: src.height,
      pixelFormat: ui.PixelFormat.rgba8888);
  final codec = await desc.instantiateCodec();
  return (await codec.getNextFrame()).image;
}

Uint8List _sharpen((Uint8List, int, int, double) a) {
  final (px, w, h, amount) = a;
  final out = Uint8List.fromList(px);
  final k = amount.clamp(0.0, 1.0) * 1.2;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = (y * w + x) * 4;
      for (var c = 0; c < 3; c++) {
        final v = px[i + c];
        final n = px[i - 4 + c] +
            px[i + 4 + c] +
            px[i - w * 4 + c] +
            px[i + w * 4 + c];
        out[i + c] = (v + k * (4 * v - n)).round().clamp(0, 255);
      }
    }
  }
  return out;
}

/// Kırpılmış bölgenin piksel ölçüsü (ölçek uygulanmadan).
Size croppedSize(ui.Image src, ImageEdits e) {
  final full = orientedSize(src, e);
  return Size((e.crop.width * full.width).roundToDouble().clamp(1, 1e5),
      (e.crop.height * full.height).roundToDouble().clamp(1, 1e5));
}

/// Kaydedilecek dosyanın piksel ölçüsü (kırpma + ölçek).
Size outputSize(ui.Image src, ImageEdits e) {
  final c = croppedSize(src, e);
  return Size((c.width * e.scale).roundToDouble().clamp(1, 1e5),
      (c.height * e.scale).roundToDouble().clamp(1, 1e5));
}

/// Düzenlenmiş görseli üretir (kırpılmış, [ImageEdits.scale] ölçeğinde).
Future<ui.Image> renderEdits(ui.Image src, ImageEdits e) async {
  if (e.sharpness > 0) {
    final sharp = await sharpened(src, e.sharpness);
    try {
      return await renderEdits(sharp, e.copyWith(sharpness: 0));
    } finally {
      sharp.dispose();
    }
  }
  final full = orientedSize(src, e) * e.scale;
  final c = e.crop;
  final out = outputSize(src, e);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.clipRect(Offset.zero & out);
  paintEdits(
    canvas,
    src,
    e,
    Rect.fromLTWH(-c.left * full.width, -c.top * full.height, full.width,
        full.height),
  );
  return rec.endRecording().toImage(out.width.toInt(), out.height.toInt());
}

/// Düzenleyicinin yazabildiği biçimler; diğerleri (HEIC, WebP…) JPEG kopya.
String editedExtension(String path) {
  final ext = p.extension(path).toLowerCase();
  return ext == '.png' ? '.png' : '.jpg';
}

/// Düzenlemeyi kodlayıp yazar. [overwrite] yalnız biçim değişmiyorsa
/// geçerli; aksi hâlde yanına `ad (1).jpg` gibi yeni dosya. Yazılan yol döner.
Future<String> saveEdited(String path, ui.Image edited,
    {bool overwrite = false}) async {
  final ext = editedExtension(path);
  final sameFormat = p.extension(path).toLowerCase() == ext ||
      (ext == '.jpg' && p.extension(path).toLowerCase() == '.jpeg');
  final target = overwrite && sameFormat
      ? path
      : FileOps.uniquePath(p.setExtension(path, ext));
  final raw = await edited.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = await compute(_encode, (
    raw!.buffer.asUint8List(),
    edited.width,
    edited.height,
    ext == '.png',
  ));
  await SafeWrite.bytes(target, bytes);
  FsEvents.changed();
  return target;
}

Uint8List _encode((Uint8List, int, int, bool) a) {
  final (rgba, w, h, png) = a;
  final im = img.Image.fromBytes(
      width: w, height: h, bytes: rgba.buffer, numChannels: 4);
  return png ? img.encodePng(im) : img.encodeJpg(im, quality: 92);
}

/// Görseli ekranda çizilecek şekilde açar. Çok büyük görseller GPU doku
/// sınırına (8192) indirilir — 48 MP'yi tam açmak ucuz telefonu düşürür.
Future<ui.Image> loadEditableImage(String path) async {
  final bytes = await File(path).readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final desc = await ui.ImageDescriptor.encoded(buffer);
  const maxSide = 8192;
  final longest = math.max(desc.width, desc.height);
  final scale = longest > maxSide ? maxSide / longest : 1.0;
  final codec = await desc.instantiateCodec(
    targetWidth: (desc.width * scale).round(),
    targetHeight: (desc.height * scale).round(),
  );
  return (await codec.getNextFrame()).image;
}
