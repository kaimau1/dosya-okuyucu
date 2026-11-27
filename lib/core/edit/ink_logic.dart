import 'dart:math' as math;
import 'dart:ui' show Offset, PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryStylusButton;

/// Kalem tepsisinin üç kalemi (Notlar'daki tepsiyle aynı mantık, B20
/// 2026-11-27, kullanıcı: "kalemle silgi yan yana olmalı; Notlar'daki kalem
/// mantığı birebir alınsın"). Fotoğraf düzenleyici ve PDF kalemi ortak
/// kullanır (`PenTray`); ekranın öteki araçları (yazı, şekil, kaydır…) kendi
/// sıralarında kalır.
enum PenTrayTool { pen, highlighter, eraser }

/// Silgi kipi: bütün çizgiyi mi siler, yalnız değdiği yeri mi.
enum EraserMode { stroke, area }

/// Kalem tepsisinin hafızası: son kullanılan kalem (anlık geçiş geri dönsün
/// diye) ve silgi kipi. Oturum boyunca ekranlar arasında ortak (static) —
/// PDF'te "alan silgisi" seçen fotoğrafta da onu bulur.
abstract final class PenTrayMemory {
  static PenTrayTool lastPen = PenTrayTool.pen;
  static EraserMode eraserMode = EraserMode.stroke;

  /// Bir araç seçildi: kalemse hatırla.
  static void note(PenTrayTool tool) {
    if (tool != PenTrayTool.eraser) lastPen = tool;
  }

  /// **ANLIK GEÇİŞ** (tepsideki ⇄ düğmesi): kalemdeyken silgiye, silgideyken
  /// son kaleme tek dokunuş. Tepsi dışı bir araçtayken ([current] null)
  /// silgiye geçer.
  static PenTrayTool swap(PenTrayTool? current) =>
      current == PenTrayTool.eraser ? lastPen : PenTrayTool.eraser;
}

/// Kalemin yan düğmesi basılı ya da kalem TERS çevrilmiş (silgi ucu): bu
/// çizgi boyunca araç değiştirmeden silgi (Notlar'daki `_tempEraser`).
bool isStylusEraser(PointerDeviceKind? kind, int buttons) =>
    kind == PointerDeviceKind.invertedStylus ||
    (kind == PointerDeviceKind.stylus &&
        buttons & kSecondaryStylusButton != 0);

/// [p] noktasının [a]–[b] doğru parçasına uzaklığı.
double segmentDistance(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2)
      .clamp(0.0, 1.0);
  return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
}

/// Çizgi silgi isabeti: [c] merkezli [r] yarıçaplı daire çizginin GÖVDESİNE
/// değiyor mu (yalnız noktalara değil — seyrek noktalı uzun çizgi de
/// ortasından silinir). Koordinatlar iki eksende aynı birimde olmalı.
bool strokeHit(List<Offset> points, Offset c, double r) {
  if (points.isEmpty) return false;
  if (points.length == 1) return (points.first - c).distance <= r;
  for (var i = 0; i + 1 < points.length; i++) {
    if (segmentDistance(c, points[i], points[i + 1]) <= r) return true;
  }
  return false;
}

/// **ALAN SİLGİSİ:** çizginin dairenin İÇİNDE kalan kısmı atılır, kalan
/// parçalar ayrı çizgi olur. Daire iki noktanın ARASINDAN geçse de (seyrek
/// nokta) kesim tam sınırdan yapılır; özgün noktalar korunur (Notlar
/// 2026-11-13 bulgusu: örneklenmiş listeden kesmek yazı boyunu değiştiriyordu).
/// Değmediyse null — çağıran çizgiyi aynen bırakır. Tek noktadan kısa
/// parçalar atılır.
List<List<Offset>>? cutStroke(List<Offset> points, Offset c, double r) {
  if (points.isEmpty) return null;
  bool inside(Offset p) => (p - c).distance <= r;
  if (points.length == 1) return inside(points.first) ? const [] : null;
  final pieces = <List<Offset>>[];
  var cur = <Offset>[];
  var hit = false;
  var isIn = inside(points.first);
  if (isIn) {
    hit = true;
  } else {
    cur.add(points.first);
  }
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    final d = b - a, f = a - c;
    final qa = d.dx * d.dx + d.dy * d.dy;
    if (qa > 0) {
      final qb = 2 * (f.dx * d.dx + f.dy * d.dy);
      final qc = f.dx * f.dx + f.dy * f.dy - r * r;
      final disc = qb * qb - 4 * qa * qc;
      if (disc > 0) {
        final s = math.sqrt(disc);
        for (final t in [(-qb - s) / (2 * qa), (-qb + s) / (2 * qa)]) {
          if (t <= 0 || t >= 1) continue;
          final q = Offset(a.dx + d.dx * t, a.dy + d.dy * t);
          hit = true;
          if (isIn) {
            cur = [q];
          } else {
            cur.add(q);
            if (cur.length > 1) pieces.add(cur);
            cur = [];
          }
          isIn = !isIn;
        }
      }
    }
    if (isIn) {
      hit = true;
    } else {
      cur.add(b);
    }
  }
  if (!hit) return null;
  if (cur.length > 1) pieces.add(cur);
  return pieces;
}

/// [points] (0..1, x genişliğe y yüksekliğe oranlı) üzerinde [cutStroke];
/// [aspect] = genişlik / yükseklik — y'yi genişlik biriminde ölçer ki silgi
/// iki eksende de aynı boyda olsun.
List<List<Offset>>? cutNormalizedStroke(
  List<Offset> points,
  Offset c,
  double r,
  double aspect,
) {
  Offset to(Offset o) => Offset(o.dx, o.dy / aspect);
  Offset back(Offset o) => Offset(o.dx, o.dy * aspect);
  final pieces = cutStroke([for (final p in points) to(p)], to(c), r);
  return pieces == null
      ? null
      : [
          for (final piece in pieces) [for (final p in piece) back(p)],
        ];
}

/// [strokeHit]in oranlı koordinat hâli (bkz. [cutNormalizedStroke]).
bool normalizedStrokeHit(
  List<Offset> points,
  Offset c,
  double r,
  double aspect,
) {
  Offset to(Offset o) => Offset(o.dx, o.dy / aspect);
  return strokeHit([for (final p in points) to(p)], to(c), r);
}
