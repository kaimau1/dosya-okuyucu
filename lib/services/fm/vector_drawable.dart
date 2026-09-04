import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'apk_resources.dart';

/// **Android VectorDrawable çizici** — ikili XML'deki vektör simgeyi piksele
/// çevirir.
///
/// ## Niye yazıldı (kullanıcı 2026-09-03)
/// *"hâlâ eski apklarda simgeler görülmüyor, yenisinde görülmüş."*
///
/// 2026-09-03'te simge arama doğru yola oturmuştu (manifest → `resources.arsc`
/// → dosya yolu) ama bir kapı kapalı kaldı: uyarlanabilir simgenin ön planı
/// bir **vektör çizim** olduğunda (`res/…/ic_launcher_foreground.xml`)
/// birleştirme "çizemiyorum" deyip vazgeçiyordu. O noktada geriye yalnız eski
/// sezgiseller kalıyor ve onlar da ya hiçbir şey ya da zemin katmanını
/// buluyordu — kullanıcının listede gördüğü BOŞ KARE tam olarak buydu.
/// Uygulama simgelerinin büyük çoğunluğu (Android Studio'nun ürettiği her
/// varsayılan simge dahil) vektör ön planlıdır, yani bu kapı kapalıyken
/// "bazı APK'ların simgesi yok" kalıcıydı.
///
/// ## Kapsam — bilerek dar, ama simgeye yeten kadar
/// * `<vector>` görüş alanı (viewport) + genel saydamlık (`alpha`),
/// * `<group>` dönüşümleri (öteleme, ölçek, döndürme, eksen noktası),
/// * `<path>`: `pathData`, `fillColor`, `fillAlpha`, `fillType` (evenOdd),
///   `strokeColor`, `strokeWidth`, `strokeAlpha`,
/// * yol komutlarının tamamı: M/L/H/V/C/S/Q/T/A/Z (küçük harf = bağıl).
///
/// **Yok:** kırpma yolları (`<clip-path>`, simgelerde neredeyse hiç yok),
/// degradeler tam anlamıyla (ortalama renkle yaklaşılıyor — düz renk bir
/// simge, hiç simge olmamasından iyidir), çizgi uçları/birleşimleri tam
/// geometrisiyle (yuvarlak kabul ediliyor).
///
/// ## Nasıl çiziliyor
/// Kendi tarayıcı (scanline) doldurucumuz var: `dart:ui` yolu bir izolatta
/// (simge çıkarma `compute` içinde koşuyor) çizim yapamaz, `path_drawing`
/// gibi bir paket eklemek de tek bir simge için derleme zincirini oynatmak
/// olurdu (HAFIZA'daki yasak). Kenar yumuşatma **üst örnekleme** ile:
/// hedefin üç katı çizilip kutu süzgeciyle küçültülüyor.
abstract final class VectorDrawable {
  /// İkili XML **vektör çizim mi**? (Kök eleman `<vector>`.)
  static bool isVector(List<AxmlNode> tree) =>
      tree.isNotEmpty && tree.first.name == 'vector';

  /// Ağacı çizilebilir bir görüntüye çevirir; `<vector>` değilse null.
  ///
  /// [resolveColor] bir kaynak göndermesini (`@color/primary`) ARGB'ye
  /// çevirir — kaynak tablosu olmayan testlerde null geçilebilir.
  static VectorImage? parse(
    List<AxmlNode> tree, {
    int? Function(int resId)? resolveColor,
  }) {
    if (!isVector(tree)) return null;
    final root = tree.first;
    final vw = _number(root, 'viewportWidth') ?? 24;
    final vh = _number(root, 'viewportHeight') ?? 24;
    if (vw <= 0 || vh <= 0) return null;
    final alpha = (_number(root, 'alpha') ?? 1).clamp(0.0, 1.0);
    final shapes = <VectorShape>[];
    _walk(root, _Matrix.identity, shapes, resolveColor, alpha);
    if (shapes.isEmpty) return null;
    return VectorImage(
        viewportWidth: vw, viewportHeight: vh, shapes: shapes);
  }

  static void _walk(
    AxmlNode node,
    _Matrix parent,
    List<VectorShape> out,
    int? Function(int resId)? resolveColor,
    double alpha,
  ) {
    for (final child in node.children) {
      switch (child.name) {
        case 'group':
          _walk(child, parent.multiply(_groupMatrix(child)), out, resolveColor,
              alpha);
        case 'path':
          final shape = _path(child, parent, resolveColor, alpha);
          if (shape != null) out.add(shape);
        default:
          // `<clip-path>`, `<aapt:attr>` ve bilinmeyenler: içlerinde yol
          // olabilir (degrade tanımları böyle geliyor) — yine de geziliyor.
          _walk(child, parent, out, resolveColor, alpha);
      }
    }
  }

  /// `<group>` dönüşümü — **Android'in uyguladığı sırayla**.
  ///
  /// `-eksen → ölçek → döndür → eksen + öteleme`. Sıra değişirse eksen
  /// noktası olan simgeler (saat ibresi, ok) kayar.
  static _Matrix _groupMatrix(AxmlNode node) {
    final px = _number(node, 'pivotX') ?? 0;
    final py = _number(node, 'pivotY') ?? 0;
    final sx = _number(node, 'scaleX') ?? 1;
    final sy = _number(node, 'scaleY') ?? 1;
    final rot = _number(node, 'rotation') ?? 0;
    final tx = _number(node, 'translateX') ?? 0;
    final ty = _number(node, 'translateY') ?? 0;
    var m = _Matrix.translate(-px, -py);
    m = _Matrix.scale(sx, sy).multiply(m);
    if (rot != 0) m = _Matrix.rotate(rot * math.pi / 180).multiply(m);
    return _Matrix.translate(px + tx, py + ty).multiply(m);
  }

  static VectorShape? _path(
    AxmlNode node,
    _Matrix matrix,
    int? Function(int resId)? resolveColor,
    double alpha,
  ) {
    final data = _string(node, 'pathData');
    if (data == null || data.trim().isEmpty) return null;
    final polys = PathData.flatten(data);
    if (polys.isEmpty) return null;
    final transformed = [
      for (final poly in polys)
        [for (final p in poly) matrix.apply(p)],
    ];
    final fill = _color(node, 'fillColor', resolveColor) ??
        _gradientColor(node, 'fillColor', resolveColor);
    final stroke = _color(node, 'strokeColor', resolveColor);
    final fillAlpha = (_number(node, 'fillAlpha') ?? 1).clamp(0.0, 1.0);
    final strokeAlpha = (_number(node, 'strokeAlpha') ?? 1).clamp(0.0, 1.0);
    final strokeWidth = _number(node, 'strokeWidth') ?? 0;
    final evenOdd = (_string(node, 'fillType') ?? '').toLowerCase() == 'evenodd';
    if (fill == null && stroke == null) return null;
    return VectorShape(
      polygons: transformed,
      fillColor: fill == null ? null : _withAlpha(fill, fillAlpha * alpha),
      strokeColor:
          stroke == null ? null : _withAlpha(stroke, strokeAlpha * alpha),
      strokeWidth: strokeWidth * matrix.averageScale,
      evenOdd: evenOdd,
    );
  }

  static int _withAlpha(int argb, double factor) {
    final a = (((argb >> 24) & 0xFF) * factor).round().clamp(0, 255);
    return (a << 24) | (argb & 0x00FFFFFF);
  }

  /// Bir renk özniteliği: doğrudan değer ya da kaynak göndermesi.
  static int? _color(
    AxmlNode node,
    String name,
    int? Function(int resId)? resolveColor,
  ) {
    final attr = node.element.byName[name];
    if (attr == null) return null;
    if (attr.type >= _colorFirst && attr.type <= _colorLast) return attr.data;
    if (attr.isReference) return resolveColor?.call(attr.data);
    // `#RRGGBB` metni (nadiren düz dizge olarak gelir).
    final text = attr.string;
    if (text != null && text.startsWith('#')) return _parseHexColor(text);
    return null;
  }

  /// Degradeli dolgunun **yaklaşık** rengi: durakların ortalaması.
  ///
  /// Degradeyi tam çizmek (doğrusal + radyal + açısal, durak konumları) tek
  /// bir liste simgesi için çok iş; ortalama renk simgeyi TANINIR kılıyor ve
  /// alternatif "hiç simge yok"tu.
  static int? _gradientColor(
    AxmlNode node,
    String name,
    int? Function(int resId)? resolveColor,
  ) {
    for (final attr in node.children) {
      if (attr.name != 'aapt:attr' && attr.name != 'attr') continue;
      final target = attr.element.byName['name']?.string ?? '';
      if (!target.endsWith(name)) continue;
      final colors = <int>[];
      for (final gradient in attr.descendants('gradient')) {
        for (final key in const ['startColor', 'centerColor', 'endColor']) {
          final c = _color(gradient, key, resolveColor);
          if (c != null) colors.add(c);
        }
        for (final item in gradient.descendants('item')) {
          final c = _color(item, 'color', resolveColor);
          if (c != null) colors.add(c);
        }
      }
      if (colors.isEmpty) continue;
      var a = 0, r = 0, g = 0, b = 0;
      for (final c in colors) {
        a += (c >> 24) & 0xFF;
        r += (c >> 16) & 0xFF;
        g += (c >> 8) & 0xFF;
        b += c & 0xFF;
      }
      final n = colors.length;
      return ((a ~/ n) << 24) | ((r ~/ n) << 16) | ((g ~/ n) << 8) | (b ~/ n);
    }
    return null;
  }

  static int? _parseHexColor(String text) {
    var hex = text.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    return int.tryParse(hex, radix: 16);
  }

  static const _colorFirst = 0x1c;
  static const _colorLast = 0x1f;

  static String? _string(AxmlNode node, String name) =>
      node.element.byName[name]?.string;

  /// Sayısal öznitelik: kayan nokta, tam sayı, ölçü ya da metin.
  static double? _number(AxmlNode node, String name) {
    final attr = node.element.byName[name];
    if (attr == null) return null;
    return attr.asDouble;
  }

  /// Görüntüyü [size]×[size] piksellik bir PNG görüntüsüne çizer.
  ///
  /// [supersample] kenar yumuşatma katsayısı: 3 kat çizip küçültmek, 192 px
  /// bir simgede gözle "keskin" görünüyor ve maliyeti milisaniyeler.
  static img.Image rasterize(
    VectorImage image, {
    int size = 192,
    int supersample = 3,
  }) {
    final side = size * supersample;
    final canvas = img.Image(width: side, height: side, numChannels: 4);
    final sx = side / image.viewportWidth;
    final sy = side / image.viewportHeight;
    for (final shape in image.shapes) {
      final scaled = [
        for (final poly in shape.polygons)
          [for (final p in poly) VecPoint(p.x * sx, p.y * sy)],
      ];
      final fill = shape.fillColor;
      if (fill != null && (fill >> 24) != 0) {
        _fillPolygons(canvas, scaled, fill, shape.evenOdd);
      }
      final stroke = shape.strokeColor;
      if (stroke != null && (stroke >> 24) != 0 && shape.strokeWidth > 0) {
        final w = shape.strokeWidth * (sx + sy) / 2;
        for (final piece in _strokePieces(scaled, w)) {
          _fillPolygons(canvas, [piece], stroke, false);
        }
      }
    }
    return supersample == 1 ? canvas : _downsample(canvas, size, supersample);
  }

  /// Tarayıcı (scanline) doldurucu — sarım kuralı seçilebilir.
  static void _fillPolygons(
    img.Image dst,
    List<List<VecPoint>> polygons,
    int argb,
    bool evenOdd,
  ) {
    final edges = <_Edge>[];
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final poly in polygons) {
      if (poly.length < 2) continue;
      for (var i = 0; i < poly.length; i++) {
        final a = poly[i];
        final b = poly[(i + 1) % poly.length];
        if (a.y == b.y) continue; // yatay kenar taramayı kesmez
        edges.add(_Edge(a, b));
        minY = math.min(minY, math.min(a.y, b.y));
        maxY = math.max(maxY, math.max(a.y, b.y));
      }
    }
    if (edges.isEmpty) return;
    final a = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final yStart = math.max(0, minY.floor());
    final yEnd = math.min(dst.height - 1, maxY.ceil());
    final crossings = <_Crossing>[];
    for (var y = yStart; y <= yEnd; y++) {
      final scan = y + 0.5;
      crossings.clear();
      for (final edge in edges) {
        if (scan < edge.yMin || scan >= edge.yMax) continue;
        crossings
            .add(_Crossing(edge.xAt(scan), edge.downward ? 1 : -1));
      }
      if (crossings.length < 2) continue;
      crossings.sort((p, q) => p.x.compareTo(q.x));
      var winding = 0;
      for (var i = 0; i < crossings.length - 1; i++) {
        winding += evenOdd ? 1 : crossings[i].direction;
        final inside = evenOdd ? winding.isOdd : winding != 0;
        if (!inside) continue;
        final x0 = math.max(0, crossings[i].x.round());
        final x1 = math.min(dst.width, crossings[i + 1].x.round());
        for (var x = x0; x < x1; x++) {
          _blend(dst, x, y, r, g, b, a);
        }
      }
    }
  }

  static void _blend(img.Image dst, int x, int y, int r, int g, int b, int a) {
    if (a >= 255) {
      dst.setPixelRgba(x, y, r, g, b, 255);
      return;
    }
    final px = dst.getPixel(x, y);
    final dstA = px.a.toInt();
    final outA = a + dstA * (255 - a) ~/ 255;
    if (outA == 0) {
      dst.setPixelRgba(x, y, 0, 0, 0, 0);
      return;
    }
    int mix(int src, num dstC) =>
        (src * a + dstC.toInt() * dstA * (255 - a) ~/ 255) ~/ outA;
    dst.setPixelRgba(x, y, mix(r, px.r), mix(g, px.g), mix(b, px.b), outA);
  }

  /// Çizgiyi doldurulabilir parçalara böler: her kesit bir dörtgen, her
  /// köşe bir çokgen (yuvarlak birleşim yaklaşımı).
  ///
  /// Parçalar AYRI AYRI dolduruluyor: tek bir çokgen olarak birleştirmek
  /// sarım yönlerini karıştırır ve kesişen çizgilerde delikler bırakırdı.
  static List<List<VecPoint>> _strokePieces(
      List<List<VecPoint>> polygons, double width) {
    final half = width / 2;
    final out = <List<VecPoint>>[];
    for (final poly in polygons) {
      for (var i = 0; i < poly.length - 1; i++) {
        final a = poly[i];
        final b = poly[i + 1];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 1e-9) continue;
        final nx = -dy / len * half;
        final ny = dx / len * half;
        out.add([
          VecPoint(a.x + nx, a.y + ny),
          VecPoint(b.x + nx, b.y + ny),
          VecPoint(b.x - nx, b.y - ny),
          VecPoint(a.x - nx, a.y - ny),
        ]);
      }
      for (final p in poly) {
        out.add(_circle(p, half));
      }
    }
    return out;
  }

  static List<VecPoint> _circle(VecPoint center, double radius) => [
        for (var i = 0; i < 12; i++)
          VecPoint(
            center.x + radius * math.cos(i * math.pi / 6),
            center.y + radius * math.sin(i * math.pi / 6),
          ),
      ];

  /// Kutu süzgeciyle küçültme — **önceden çarpılmış saydamlıkla**.
  ///
  /// Doğrudan ortalama alınırsa saydam piksellerin (siyah) rengi kenarlara
  /// karışır ve simgenin çevresi kirli bir hâle alır.
  static img.Image _downsample(img.Image src, int size, int factor) {
    final out = img.Image(width: size, height: size, numChannels: 4);
    final area = factor * factor;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        var sr = 0, sg = 0, sb = 0, sa = 0;
        for (var dy = 0; dy < factor; dy++) {
          for (var dx = 0; dx < factor; dx++) {
            final p = src.getPixel(x * factor + dx, y * factor + dy);
            final a = p.a.toInt();
            sa += a;
            sr += p.r.toInt() * a;
            sg += p.g.toInt() * a;
            sb += p.b.toInt() * a;
          }
        }
        if (sa == 0) {
          out.setPixelRgba(x, y, 0, 0, 0, 0);
          continue;
        }
        out.setPixelRgba(x, y, sr ~/ sa, sg ~/ sa, sb ~/ sa, sa ~/ area);
      }
    }
    return out;
  }

  /// Ağacı doğrudan PNG baytlarına çevirir (çizilemezse null).
  static Uint8List? toPng(
    List<AxmlNode> tree, {
    int? Function(int resId)? resolveColor,
    int size = 192,
  }) {
    final image = parse(tree, resolveColor: resolveColor);
    if (image == null) return null;
    return Uint8List.fromList(img.encodePng(rasterize(image, size: size)));
  }
}

/// Çizilmeye hazır vektör: görüş alanı + şekiller.
class VectorImage {
  final double viewportWidth;
  final double viewportHeight;
  final List<VectorShape> shapes;

  const VectorImage({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.shapes,
  });
}

/// Tek bir `<path>`: düzleştirilmiş çokgenler + renkleri.
class VectorShape {
  /// Yolun alt parçaları (her biri kapalı sayılır — dolgu için).
  final List<List<VecPoint>> polygons;

  final int? fillColor;
  final int? strokeColor;
  final double strokeWidth;

  /// `fillType="evenOdd"` — delikli simgelerde (halka) şart.
  final bool evenOdd;

  const VectorShape({
    required this.polygons,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 0,
    this.evenOdd = false,
  });
}

/// **SVG yol verisi çözümleyici + düzleştirici.**
///
/// Eğriler doğru parçalarına bölünüyor: dolduracağımız şey zaten çokgen ve
/// 192 px'lik bir simgede 16 parça gözle eğri görünüyor.
abstract final class PathData {
  /// [data] yolunu alt yollara böler; her alt yol nokta dizisidir.
  static List<List<VecPoint>> flatten(String data, {int curveSegments = 16}) {
    final tokens = _tokenize(data);
    final out = <List<VecPoint>>[];
    var current = <VecPoint>[];
    var cursor = const VecPoint(0, 0);
    var start = const VecPoint(0, 0);
    VecPoint? lastControl;
    var lastCommand = '';

    void closeCurrent() {
      if (current.length > 1) out.add(current);
      current = <VecPoint>[];
    }

    for (final token in tokens) {
      final cmd = token.command;
      final args = token.args;
      final relative = cmd.toLowerCase() == cmd;
      var upper = cmd.toUpperCase();
      if (upper == 'Z') {
        if (current.isNotEmpty) {
          current.add(start);
          closeCurrent();
          current = [start];
        }
        cursor = start;
        lastControl = null;
        lastCommand = 'Z';
        continue;
      }
      var i = 0;
      // **Bir komut birden çok argüman kümesi taşıyabilir** ("L1,2 3,4") ve
      // "M" den sonraki fazlalık kümeler örtük "L" sayılır (SVG kuralı).
      var first = true;
      while (i + _argCount(upper) <= args.length) {
        switch (upper) {
          case 'M':
            final p = _resolve(args[i], args[i + 1], cursor, relative);
            i += 2;
            if (first) {
              closeCurrent();
              current = [p];
              start = p;
            } else {
              current.add(p);
            }
            cursor = p;
            lastControl = null;
            if (first) upper = 'L'; // sonraki kümeler çizgi
          case 'L':
            final p = _resolve(args[i], args[i + 1], cursor, relative);
            i += 2;
            current.add(p);
            cursor = p;
            lastControl = null;
          case 'H':
            final x = relative ? cursor.x + args[i] : args[i];
            i += 1;
            cursor = VecPoint(x, cursor.y);
            current.add(cursor);
            lastControl = null;
          case 'V':
            final y = relative ? cursor.y + args[i] : args[i];
            i += 1;
            cursor = VecPoint(cursor.x, y);
            current.add(cursor);
            lastControl = null;
          case 'C':
            final c1 = _resolve(args[i], args[i + 1], cursor, relative);
            final c2 = _resolve(args[i + 2], args[i + 3], cursor, relative);
            final end = _resolve(args[i + 4], args[i + 5], cursor, relative);
            i += 6;
            _cubic(current, cursor, c1, c2, end, curveSegments);
            cursor = end;
            lastControl = c2;
          case 'S':
            final reflect = (lastCommand == 'C' || lastCommand == 'S') &&
                lastControl != null;
            final c1 = reflect
                ? VecPoint(2 * cursor.x - lastControl.x,
                    2 * cursor.y - lastControl.y)
                : cursor;
            final c2 = _resolve(args[i], args[i + 1], cursor, relative);
            final end = _resolve(args[i + 2], args[i + 3], cursor, relative);
            i += 4;
            _cubic(current, cursor, c1, c2, end, curveSegments);
            cursor = end;
            lastControl = c2;
          case 'Q':
            final c = _resolve(args[i], args[i + 1], cursor, relative);
            final end = _resolve(args[i + 2], args[i + 3], cursor, relative);
            i += 4;
            _quadratic(current, cursor, c, end, curveSegments);
            cursor = end;
            lastControl = c;
          case 'T':
            final reflect = (lastCommand == 'Q' || lastCommand == 'T') &&
                lastControl != null;
            final c = reflect
                ? VecPoint(2 * cursor.x - lastControl.x,
                    2 * cursor.y - lastControl.y)
                : cursor;
            final end = _resolve(args[i], args[i + 1], cursor, relative);
            i += 2;
            _quadratic(current, cursor, c, end, curveSegments);
            cursor = end;
            lastControl = c;
          case 'A':
            final rx = args[i].abs();
            final ry = args[i + 1].abs();
            final rotation = args[i + 2] * math.pi / 180;
            final largeArc = args[i + 3] != 0;
            final sweep = args[i + 4] != 0;
            final end = _resolve(args[i + 5], args[i + 6], cursor, relative);
            i += 7;
            _arc(current, cursor, end, rx, ry, rotation, largeArc, sweep);
            cursor = end;
            lastControl = null;
          default:
            i = args.length; // tanınmayan komut: kümeyi tüket
        }
        first = false;
        lastCommand = upper == 'L' && cmd.toUpperCase() == 'M' ? 'M' : upper;
      }
    }
    closeCurrent();
    return out;
  }

  /// Bir komutun tek küme argüman sayısı.
  static int _argCount(String upper) => switch (upper) {
        'M' || 'L' || 'T' => 2,
        'H' || 'V' => 1,
        'C' => 6,
        'S' || 'Q' => 4,
        'A' => 7,
        _ => 1,
      };

  static VecPoint _resolve(double x, double y, VecPoint cursor, bool relative) =>
      relative ? VecPoint(cursor.x + x, cursor.y + y) : VecPoint(x, y);

  static void _cubic(List<VecPoint> out, VecPoint p0, VecPoint p1, VecPoint p2,
      VecPoint p3, int segments) {
    for (var s = 1; s <= segments; s++) {
      final t = s / segments;
      final u = 1 - t;
      final x = u * u * u * p0.x +
          3 * u * u * t * p1.x +
          3 * u * t * t * p2.x +
          t * t * t * p3.x;
      final y = u * u * u * p0.y +
          3 * u * u * t * p1.y +
          3 * u * t * t * p2.y +
          t * t * t * p3.y;
      out.add(VecPoint(x, y));
    }
  }

  static void _quadratic(
      List<VecPoint> out, VecPoint p0, VecPoint c, VecPoint p1, int segments) {
    for (var s = 1; s <= segments; s++) {
      final t = s / segments;
      final u = 1 - t;
      out.add(VecPoint(
        u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
        u * u * p0.y + 2 * u * t * c.y + t * t * p1.y,
      ));
    }
  }

  /// Eliptik yay (`A`) — uç nokta gösteriminden merkez gösterimine.
  ///
  /// Yay simgelerde sık (yuvarlak köşe, daire dilimi); atlanırsa şeklin bir
  /// parçası düz çizgiye dönüşür ve simge bozulur.
  static void _arc(
    List<VecPoint> out,
    VecPoint from,
    VecPoint to,
    double rx,
    double ry,
    double rotation,
    bool largeArc,
    bool sweep,
  ) {
    if (rx == 0 || ry == 0 || (from.x == to.x && from.y == to.y)) {
      out.add(to);
      return;
    }
    final cosR = math.cos(rotation);
    final sinR = math.sin(rotation);
    final dx2 = (from.x - to.x) / 2;
    final dy2 = (from.y - to.y) / 2;
    final x1 = cosR * dx2 + sinR * dy2;
    final y1 = -sinR * dx2 + cosR * dy2;
    var rxs = rx * rx;
    var rys = ry * ry;
    final x1s = x1 * x1;
    final y1s = y1 * y1;
    // Yarıçaplar küçük kalırsa standart onları büyütmeyi söylüyor.
    final lambda = x1s / rxs + y1s / rys;
    var rxa = rx;
    var rya = ry;
    if (lambda > 1) {
      final scale = math.sqrt(lambda);
      rxa *= scale;
      rya *= scale;
      rxs = rxa * rxa;
      rys = rya * rya;
    }
    final sign = largeArc == sweep ? -1.0 : 1.0;
    var factor = (rxs * rys - rxs * y1s - rys * x1s) /
        (rxs * y1s + rys * x1s);
    if (factor < 0) factor = 0;
    final coef = sign * math.sqrt(factor);
    final cx1 = coef * rxa * y1 / rya;
    final cy1 = -coef * rya * x1 / rxa;
    final cx = cosR * cx1 - sinR * cy1 + (from.x + to.x) / 2;
    final cy = sinR * cx1 + cosR * cy1 + (from.y + to.y) / 2;

    double angle(double ux, double uy, double vx, double vy) {
      final dot = ux * vx + uy * vy;
      final len = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
      var a = math.acos((dot / len).clamp(-1.0, 1.0));
      if (ux * vy - uy * vx < 0) a = -a;
      return a;
    }

    final startAngle =
        angle(1, 0, (x1 - cx1) / rxa, (y1 - cy1) / rya);
    var delta = angle((x1 - cx1) / rxa, (y1 - cy1) / rya,
        (-x1 - cx1) / rxa, (-y1 - cy1) / rya);
    if (!sweep && delta > 0) {
      delta -= 2 * math.pi;
    } else if (sweep && delta < 0) {
      delta += 2 * math.pi;
    }
    final steps = math.max(4, (delta.abs() / 0.2).ceil());
    for (var s = 1; s <= steps; s++) {
      final t = startAngle + delta * s / steps;
      final px = rxa * math.cos(t);
      final py = rya * math.sin(t);
      out.add(VecPoint(
        cosR * px - sinR * py + cx,
        sinR * px + cosR * py + cy,
      ));
    }
  }

  /// Komut + sayı dizisi. Sayılar virgül, boşluk ya da işaretle ayrılabilir
  /// ("10-5" iki sayıdır, "1e-3" tek sayı) — bu yüzden elle taranıyor.
  static List<_Token> _tokenize(String data) {
    final out = <_Token>[];
    var i = 0;
    String? command;
    var args = <double>[];
    while (i < data.length) {
      final ch = data[i];
      if (_isCommand(ch)) {
        if (command != null) out.add(_Token(command, args));
        command = ch;
        args = <double>[];
        i++;
        continue;
      }
      if (ch == ',' || ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r') {
        i++;
        continue;
      }
      final start = i;
      if (ch == '-' || ch == '+') i++;
      var seenDot = false;
      while (i < data.length) {
        final c = data[i];
        if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
          i++;
        } else if (c == '.' && !seenDot) {
          seenDot = true;
          i++;
        } else if ((c == 'e' || c == 'E') && i + 1 < data.length) {
          i++;
          if (data[i] == '-' || data[i] == '+') i++;
        } else {
          break;
        }
      }
      if (i == start) {
        i++; // tanınmayan karakter
        continue;
      }
      final value = double.tryParse(data.substring(start, i));
      if (value != null) args.add(value);
    }
    if (command != null) out.add(_Token(command, args));
    return out;
  }

  static bool _isCommand(String ch) =>
      'MmLlHhVvCcSsQqTtAaZz'.contains(ch) && ch.trim().isNotEmpty;
}

class _Token {
  final String command;
  final List<double> args;
  const _Token(this.command, this.args);
}

/// Düzlemde nokta (dışarıya da sızıyor: [VectorShape.polygons]).
class VecPoint {
  final double x;
  final double y;
  const VecPoint(this.x, this.y);
}

/// 2×3 afin dönüşüm.
class _Matrix {
  final double a, b, c, d, e, f;
  const _Matrix(this.a, this.b, this.c, this.d, this.e, this.f);

  static const identity = _Matrix(1, 0, 0, 1, 0, 0);

  static _Matrix translate(double tx, double ty) =>
      _Matrix(1, 0, 0, 1, tx, ty);

  static _Matrix scale(double sx, double sy) => _Matrix(sx, 0, 0, sy, 0, 0);

  static _Matrix rotate(double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return _Matrix(cos, sin, -sin, cos, 0, 0);
  }

  /// `this * other` — önce [other], sonra bu.
  _Matrix multiply(_Matrix o) => _Matrix(
        a * o.a + c * o.b,
        b * o.a + d * o.b,
        a * o.c + c * o.d,
        b * o.c + d * o.d,
        a * o.e + c * o.f + e,
        b * o.e + d * o.f + f,
      );

  VecPoint apply(VecPoint p) =>
      VecPoint(a * p.x + c * p.y + e, b * p.x + d * p.y + f);

  /// Çizgi kalınlığını ölçeklemek için ortalama büyütme katsayısı.
  double get averageScale =>
      (math.sqrt(a * a + b * b) + math.sqrt(c * c + d * d)) / 2;
}

class _Edge {
  final double x0, y0, x1, y1;
  final bool downward;

  _Edge(VecPoint a, VecPoint b)
      : x0 = a.x,
        y0 = a.y,
        x1 = b.x,
        y1 = b.y,
        downward = b.y > a.y;

  double get yMin => y0 < y1 ? y0 : y1;
  double get yMax => y0 < y1 ? y1 : y0;

  double xAt(double y) => x0 + (x1 - x0) * (y - y0) / (y1 - y0);
}

class _Crossing {
  final double x;
  final int direction;
  const _Crossing(this.x, this.direction);
}
