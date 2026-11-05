/// **Boş durum çizimleri** (Faz 40 / madde 2, 2026-11-05).
///
/// Boş liste yüzü ([FmEmptyState]) eskiden yalnız renkli bir daire içinde
/// simgeydi; artık arkada küçük, sade bir sahne var (kâğıt destesi, klasör,
/// büyüteç, süpürge parıltısı). Sahne **tek `CustomPainter`** — resim dosyası
/// yok (APK bütçesi), `saveLayer`/blur/gölge yok (anayasa §5), renkler
/// temadan (koyu/AMOLED/kâğıt aileleri kendiliğinden uyar), animasyon yok
/// (boşta 0 kare). Simge sahnenin önünde kalır: anlam yine simgeden gelir,
/// çizim yalnız "burası bitmiş, boş bir yer" duygusunu verir.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_icons.dart';

/// Sahne türü.
enum EmptyArtKind {
  /// Kâğıt destesi (belge yok, geçmiş boş) — varsayılan.
  document,

  /// Açık klasör (klasör boş).
  folder,

  /// Büyüteç (arama/süzgeç sonucu yok).
  search,

  /// Parıltı (temizlik bitti, kopya yok, çöp boş).
  clean;

  /// Simgeden sahne: çağıranlar ayrıca bir şey söylemesin diye bilinen
  /// simgeler eşlenir, gerisi kâğıt destesi.
  static EmptyArtKind forIcon(IconData icon) {
    if (icon == AppIcons.emptyFolder ||
        icon == AppIcons.folderOff ||
        icon == AppIcons.folder) {
      return folder;
    }
    if (icon == AppIcons.noMatch ||
        icon == AppIcons.searchOff ||
        icon == AppIcons.search) {
      return search;
    }
    if (icon == AppIcons.cleanEmpty ||
        icon == AppIcons.verified ||
        icon == AppIcons.delete) {
      return clean;
    }
    return document;
  }
}

/// Simgenin arkasındaki sahne (120 × 96 dp).
class EmptyArt extends StatelessWidget {
  static const Size size = Size(120, 96);

  final EmptyArtKind kind;
  final IconData icon;

  const EmptyArt({super.key, required this.kind, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: size,
        child: CustomPaint(
          painter: EmptyArtPainter(
            kind: kind,
            paper: scheme.surfaceContainerHigh,
            edge: scheme.outlineVariant,
            accent: scheme.primary,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Icon(icon, size: 34, color: scheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyArtPainter extends CustomPainter {
  final EmptyArtKind kind;
  final Color paper;
  final Color edge;
  final Color accent;

  const EmptyArtPainter({
    required this.kind,
    required this.paper,
    required this.edge,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2 + 4);
    final glow = Paint()..color = accent.withValues(alpha: 0.10);
    final fill = Paint()..color = paper;
    final line = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final dot = Paint()..color = accent.withValues(alpha: 0.35);

    // Arka hale: tüm sahnelerde aynı — gözü ortaya toplar.
    canvas.drawCircle(c, h * 0.42, glow);

    switch (kind) {
      case EmptyArtKind.document:
        // Üç kâğıt: arkadakiler hafif döndürülmüş.
        for (final (dx, angle) in const [(-10.0, -0.16), (10.0, 0.14)]) {
          canvas.save();
          canvas.translate(c.dx + dx, c.dy);
          canvas.rotate(angle);
          final r = RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 44, height: 56),
              const Radius.circular(6));
          canvas.drawRRect(r, fill);
          canvas.drawRRect(r, line);
          canvas.restore();
        }
        final front = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 48, height: 60),
            const Radius.circular(6));
        canvas.drawRRect(front, fill);
        canvas.drawRRect(front, line);
      case EmptyArtKind.folder:
        final body = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c.translate(0, 4), width: 76, height: 50),
            const Radius.circular(8));
        final tab = RRect.fromRectAndRadius(
            Rect.fromLTWH(c.dx - 38, c.dy - 30, 30, 14),
            const Radius.circular(5));
        canvas.drawRRect(tab, fill);
        canvas.drawRRect(tab, line);
        canvas.drawRRect(body, fill);
        canvas.drawRRect(body, line);
      case EmptyArtKind.search:
        final card = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c.translate(-6, 0), width: 56, height: 56),
            const Radius.circular(10));
        canvas.drawRRect(card, fill);
        canvas.drawRRect(card, line);
        // Büyüteç sapı kartın sağ altından taşar.
        final handle = Paint()
          ..color = edge
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c.translate(18, 18), c.translate(32, 32), handle);
      case EmptyArtKind.clean:
        final card = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 60, height: 52),
            const Radius.circular(12));
        canvas.drawRRect(card, fill);
        canvas.drawRRect(card, line);
        // Parıltılar: dört köşeli yıldızlar.
        for (final (p, r) in [
          (c.translate(-40, -26), 6.0),
          (c.translate(42, -20), 4.5),
          (c.translate(36, 28), 3.5),
        ]) {
          _sparkle(canvas, p, r, dot);
        }
    }

    // Dağınık küçük noktalar — sahne "boş" ama ölü değil.
    for (final (dx, dy, r) in const [
      (-50.0, 18.0, 2.5),
      (52.0, 6.0, 2.0),
      (-30.0, -38.0, 1.8),
    ]) {
      canvas.drawCircle(c.translate(dx, dy), r, dot);
    }
  }

  static void _sparkle(Canvas canvas, Offset p, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final len = i.isEven ? r : r * 0.35;
      final pt = p + Offset(math.cos(a) * len, math.sin(a) * len);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(EmptyArtPainter old) =>
      old.kind != kind ||
      old.paper != paper ||
      old.edge != edge ||
      old.accent != accent;
}
