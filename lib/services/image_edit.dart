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

/// **Temel görsel düzenleyici** (Faz 10, N7): kırp · döndür/çevir ·
/// parlaklık/kontrast/doygunluk · işaretle (kalem, ok, yazı).
///
/// ## Tek çizim yolu
/// Önizleme ile kaydedilen dosya AYNI [paintEdits] fonksiyonundan çıkar:
/// ekranda ne görülüyorsa dosyaya o yazılır. Çizim Flutter tuvalinde
/// yapıldığı için yazı işaretleri Türkçe karakterleri sistem yazı tipiyle
/// doğru çizer (`image` paketinin bitmap yazı tipinde ş/ğ/ı yok).
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
    this.crop = const Rect.fromLTWH(0, 0, 1, 1),
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.marks = const [],
  });

  /// Saat yönünde 90° adım sayısı (0..3).
  final int quarterTurns;
  final bool flipH;

  /// Yönlendirilmiş görselde 0..1 kırpma dikdörtgeni.
  final Rect crop;

  /// −1..1; 0 = değişmez.
  final double brightness, contrast, saturation;
  final List<ImageMark> marks;

  bool get isIdentity =>
      quarterTurns == 0 &&
      !flipH &&
      crop == const Rect.fromLTWH(0, 0, 1, 1) &&
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      marks.isEmpty;

  bool get hasColor => brightness != 0 || contrast != 0 || saturation != 0;

  ImageEdits copyWith({
    int? quarterTurns,
    bool? flipH,
    Rect? crop,
    double? brightness,
    double? contrast,
    double? saturation,
    List<ImageMark>? marks,
  }) =>
      ImageEdits(
        quarterTurns: quarterTurns ?? this.quarterTurns,
        flipH: flipH ?? this.flipH,
        crop: crop ?? this.crop,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        marks: marks ?? this.marks,
      );

  /// Saat yönünde 90° daha: kırpma ve işaretler de döner.
  ImageEdits rotated() => copyWith(
        // Çizimde çevirme döndürmeden SONRA uygulanıyor (F·Rᵠ); ekranda
        // saat yönü döndürme R·F·Rᵠ = F·Rᵠ⁻¹ → çevrilmişken adım tersine.
        quarterTurns: (quarterTurns + (flipH ? 3 : 1)) % 4,
        crop: _mapRect(crop, _rot),
        marks: [for (final m in marks) m.mapped(_rot)],
      );

  /// Yatay çevir.
  ImageEdits flipped() => copyWith(
        flipH: !flipH,
        crop: _mapRect(crop, _flip),
        marks: [for (final m in marks) m.mapped(_flip)],
      );

  static Offset _rot(Offset o) => Offset(1 - o.dy, o.dx);
  static Offset _flip(Offset o) => Offset(1 - o.dx, o.dy);
  static Rect _mapRect(Rect r, Offset Function(Offset) f) =>
      Rect.fromPoints(f(r.topLeft), f(r.bottomRight));
}

enum MarkKind { pen, arrow, text }

/// Bir işaret: kalem çizgisi, ok (ilk→son nokta) ya da yazı (ilk nokta).
/// Kalınlık/yazı boyu görselin kısa kenarına oranla tutulur — 12 MP
/// fotoğrafta da küçük resimde de aynı görünür.
class ImageMark {
  const ImageMark({
    required this.kind,
    required this.points,
    required this.color,
    this.size = 0.012,
    this.text = '',
  });

  final MarkKind kind;
  final List<Offset> points;
  final Color color;
  final double size;
  final String text;

  ImageMark mapped(Offset Function(Offset) f) => ImageMark(
        kind: kind,
        points: [for (final o in points) f(o)],
        color: color,
        size: size,
        text: text,
      );

  ImageMark withPoint(Offset o) => ImageMark(
        kind: kind,
        points: kind == MarkKind.arrow && points.length > 1
            ? [points.first, o]
            : [...points, o],
        color: color,
        size: size,
        text: text,
      );
}

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

/// Yönlendirilmiş (döndürülmüş) görsel boyutu.
Size orientedSize(ui.Image src, ImageEdits e) => e.quarterTurns.isOdd
    ? Size(src.height.toDouble(), src.width.toDouble())
    : Size(src.width.toDouble(), src.height.toDouble());

/// [src]'yi düzenlemelerle [box] içine çizer. [box] YÖNLENDİRİLMİŞ görselin
/// tamamının tuvaldeki yeri; kırpma dışı kısım çağıranın kırpmasıdır
/// (önizlemede kırpma kipinde bilerek görünür kalır).
void paintEdits(Canvas canvas, ui.Image src, ImageEdits e, Rect box) {
  final paint = Paint()..filterQuality = FilterQuality.medium;
  if (e.hasColor) {
    paint.colorFilter =
        ColorFilter.matrix(colorMatrix(e.brightness, e.contrast, e.saturation));
  }
  final w = src.width.toDouble(), h = src.height.toDouble();
  final sx = box.width / (e.quarterTurns.isOdd ? h : w);
  canvas.save();
  canvas.translate(box.center.dx, box.center.dy);
  if (e.flipH) canvas.scale(-1, 1);
  canvas.rotate(e.quarterTurns * math.pi / 2);
  canvas.drawImageRect(
    src,
    Rect.fromLTWH(0, 0, w, h),
    Rect.fromCenter(center: Offset.zero, width: w * sx, height: h * sx),
    paint,
  );
  canvas.restore();
  paintMarks(canvas, e.marks, box);
}

void paintMarks(Canvas canvas, List<ImageMark> marks, Rect box) {
  final unit = box.shortestSide;
  Offset at(Offset n) => box.topLeft + Offset(n.dx * box.width, n.dy * box.height);
  for (final m in marks) {
    if (m.points.isEmpty) continue;
    final stroke = Paint()
      ..color = m.color
      ..strokeWidth = m.size * unit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (m.kind) {
      case MarkKind.pen:
        final path = Path()..moveTo(at(m.points.first).dx, at(m.points.first).dy);
        for (final o in m.points.skip(1)) {
          path.lineTo(at(o).dx, at(o).dy);
        }
        if (m.points.length == 1) {
          canvas.drawPoints(ui.PointMode.points, [at(m.points.first)], stroke);
        }
        canvas.drawPath(path, stroke);
      case MarkKind.arrow:
        if (m.points.length < 2) continue;
        final a = at(m.points.first), b = at(m.points.last);
        canvas.drawLine(a, b, stroke);
        final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
        final head = stroke.strokeWidth * 4;
        for (final d in [math.pi * 0.8, -math.pi * 0.8]) {
          canvas.drawLine(
              b, b + Offset(math.cos(ang + d), math.sin(ang + d)) * head, stroke);
        }
      case MarkKind.text:
        final tp = TextPainter(
          text: TextSpan(
            text: m.text,
            style: TextStyle(
              color: m.color,
              fontSize: m.size * 5 * unit,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 3, color: Color(0x88000000))],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: box.width);
        tp.paint(canvas, at(m.points.first));
    }
  }
}

/// Düzenlenmiş görseli tam çözünürlükte üretir (kırpılmış).
Future<ui.Image> renderEdits(ui.Image src, ImageEdits e) async {
  final full = orientedSize(src, e);
  final c = e.crop;
  final out = Size((c.width * full.width).roundToDouble().clamp(1, 1e5),
      (c.height * full.height).roundToDouble().clamp(1, 1e5));
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
