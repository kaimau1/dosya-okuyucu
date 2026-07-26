import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show BlendMode, Offset, Paint, Rect;

/// Dörtgen → dikdörtgen **perspektif düzeltme** (belge tarayıcıda köşe ayarı).
///
/// Neden kendi kodumuz: projede görüntü işleme paketi yok (`image` paketi
/// bağımlılık şişkinliği + saf Dart yeniden örnekleme yavaş). Bunun yerine
/// dönüşümü GPU'ya yaptırıyoruz: hedef dikdörtgeni bir ÜÇGEN AĞINA bölüp
/// her köşeye kaynak görseldeki karşılığını doku koordinatı olarak veriyoruz
/// (`Canvas.drawVertices` + `ImageShader`). Her küçük üçgen içinde dönüşüm
/// afin olarak yaklaşıklanır; ağ sıklaştıkça hata gözle görülmez olur.
///
/// Matematik ([solveHomography]) saf ve test edilebilir; çizim ayrı.
class Perspective {
  const Perspective._();

  /// Ağ sıklığı (kenar başına kare). 24 → 1152 üçgen: telefonda anlık, hata
  /// tipik bir A4 taramasında piksel altı.
  static const int meshSteps = 24;

  /// [image]'in [corners] dörtgenini (görsel piksel koordinatında, sıra:
  /// sol-üst, sağ-üst, sağ-alt, sol-alt) düz bir dikdörtgene açar ve **PNG**
  /// baytlarını döndürür.
  ///
  /// Hedef boyut dörtgenin kenar uzunluklarından türetilir (karşılıklı
  /// kenarların ortalaması) → belge ne uzar ne sıkışır.
  static Future<Uint8List> warpToPng(
    ui.Image image,
    List<Offset> corners,
  ) async {
    if (corners.length != 4) {
      throw ArgumentError('4 köşe gerekli (sol-üst, sağ-üst, sağ-alt, sol-alt)');
    }
    final size = targetSize(corners);
    final width = size.width.round().clamp(16, 8000);
    final height = size.height.round().clamp(16, 8000);

    // Hedef (0,0)-(w,h) dikdörtgeninden KAYNAK dörtgene giden dönüşüm: doku
    // koordinatlarını hedef köşelerinden okuyacağız.
    final h = solveHomography(
      const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)],
      corners,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
        recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    const n = meshSteps;
    final positions = <Offset>[];
    final texCoords = <Offset>[];

    // Köşe noktalarını önceden hesapla (her üçgende yeniden hesaplamayalım).
    final grid = List.generate(
      n + 1,
      (j) => List.generate(n + 1, (i) {
        final u = i / n;
        final v = j / n;
        return (
          pos: Offset(u * width, v * height),
          tex: applyHomography(h, Offset(u, v)),
        );
      }),
    );

    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final a = grid[j][i];
        final b = grid[j][i + 1];
        final c = grid[j + 1][i + 1];
        final d = grid[j + 1][i];
        positions.addAll([a.pos, b.pos, c.pos, a.pos, c.pos, d.pos]);
        texCoords.addAll([a.tex, b.tex, c.tex, a.tex, c.tex, d.tex]);
      }
    }

    final paint = Paint()
      ..shader = ui.ImageShader(
        image,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Matrix4Identity.storage,
      )
      ..isAntiAlias = true
      ..filterQuality = ui.FilterQuality.high;

    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: texCoords,
      ),
      BlendMode.srcOver,
      paint,
    );

    final picture = recorder.endRecording();
    try {
      final out = await picture.toImage(width, height);
      try {
        final data = await out.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('Görsel kodlanamadı');
        return data.buffer.asUint8List();
      } finally {
        out.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// Dörtgenin açılmış hâlinin boyutu: karşılıklı kenar uzunluklarının ortalaması.
  static ui.Size targetSize(List<Offset> c) {
    double len(Offset a, Offset b) => (a - b).distance;
    final top = len(c[0], c[1]);
    final bottom = len(c[3], c[2]);
    final left = len(c[0], c[3]);
    final right = len(c[1], c[2]);
    return ui.Size(
      math.max((top + bottom) / 2, 16),
      math.max((left + right) / 2, 16),
    );
  }
}

/// 4 nokta çiftinden **homografi** katsayıları (a,b,c,d,e,f,g,h).
///
/// Eşleme: `u = (a·x + b·y + c) / (g·x + h·y + 1)`,
/// `v = (d·x + e·y + f) / (g·x + h·y + 1)`.
///
/// [from] ve [to] dörder nokta (aynı sırada). Dejenere (üç noktası aynı doğruda)
/// dörtgende çözüm bulunamazsa [StateError] atar.
List<double> solveHomography(List<Offset> from, List<Offset> to) {
  if (from.length != 4 || to.length != 4) {
    throw ArgumentError('4 nokta çifti gerekli');
  }
  // 8 bilinmeyen, 8 denklem: her nokta çifti iki satır verir.
  final a = List.generate(8, (_) => List<double>.filled(9, 0));
  for (var i = 0; i < 4; i++) {
    final x = from[i].dx, y = from[i].dy;
    final u = to[i].dx, v = to[i].dy;
    a[i * 2] = [x, y, 1, 0, 0, 0, -x * u, -y * u, u];
    a[i * 2 + 1] = [0, 0, 0, x, y, 1, -x * v, -y * v, v];
  }
  return _gaussSolve(a);
}

/// [h] katsayılarıyla bir noktayı dönüştürür.
Offset applyHomography(List<double> h, Offset p) {
  final denom = h[6] * p.dx + h[7] * p.dy + 1;
  // Sıfıra bölmeyi engelle: dejenere dörtgende sonsuza giden nokta olabilir.
  final d = denom.abs() < 1e-12 ? 1e-12 : denom;
  return Offset(
    (h[0] * p.dx + h[1] * p.dy + h[2]) / d,
    (h[3] * p.dx + h[4] * p.dy + h[5]) / d,
  );
}

/// Kısmi pivotlamalı Gauss eliminasyonu (8×9 genişletilmiş matris).
List<double> _gaussSolve(List<List<double>> m) {
  const n = 8;
  for (var col = 0; col < n; col++) {
    var pivot = col;
    for (var r = col + 1; r < n; r++) {
      if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
    }
    if (m[pivot][col].abs() < 1e-12) {
      throw StateError('Dörtgen dejenere (köşeler aynı doğruda)');
    }
    final tmp = m[col];
    m[col] = m[pivot];
    m[pivot] = tmp;

    final p = m[col][col];
    for (var k = col; k <= n; k++) {
      m[col][k] /= p;
    }
    for (var r = 0; r < n; r++) {
      if (r == col) continue;
      final factor = m[r][col];
      if (factor == 0) continue;
      for (var k = col; k <= n; k++) {
        m[r][k] -= factor * m[col][k];
      }
    }
  }
  return [for (var r = 0; r < n; r++) m[r][n]];
}

/// `ImageShader` birim matrisi — doku koordinatları görsel PİKSEL uzayında
/// okunur (dönüşümü biz doku koordinatlarına yazdığımız için shader'ın kendi
/// matrisi kimlik olmalı).
class Matrix4Identity {
  static final Float64List storage = Float64List.fromList(<double>[
    1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 1, //
  ]);
}
