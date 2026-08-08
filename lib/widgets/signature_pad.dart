import '../core/l10n/app_strings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parmakla çizilmiş imza — noktalar **0..1 aralığında normalize** tutulur
/// (kendi sınır kutusuna göre). Böylece imza her boyutta bozulmadan basılır ve
/// saklanması birkaç yüz bayt sürer; resim dosyası yönetmeye gerek kalmaz.
class Signature {
  const Signature(this.strokes, this.aspect);

  /// Her biri bir kalem darbesi; noktalar 0..1.
  final List<List<Offset>> strokes;

  /// Genişlik / yükseklik — yerleştirirken imzanın oranı korunsun diye.
  final double aspect;

  static const _prefsKey = 'signature_strokes_v1';

  /// Ekranda çizilmiş ham noktaları sınır kutusuna göre normalize eder.
  /// Tek nokta/çizgi gibi dejenere hâllerde bölme sıfıra düşmesin diye taban var.
  factory Signature.fromRaw(List<List<Offset>> raw) {
    final points = [for (final s in raw) ...s];
    if (points.isEmpty) return const Signature([], 1);
    var minX = points.first.dx, maxX = points.first.dx;
    var minY = points.first.dy, maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final w = (maxX - minX).abs() < 1 ? 1.0 : maxX - minX;
    final h = (maxY - minY).abs() < 1 ? 1.0 : maxY - minY;
    return Signature(
      [
        for (final s in raw)
          if (s.length >= 2)
            [for (final p in s) Offset((p.dx - minX) / w, (p.dy - minY) / h)],
      ],
      w / h,
    );
  }

  bool get isEmpty => strokes.isEmpty;

  String toJson() => jsonEncode({
        'aspect': aspect,
        'strokes': [
          for (final s in strokes) [for (final p in s) [p.dx, p.dy]],
        ],
      });

  static Signature? fromJson(String source) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      final strokes = [
        for (final s in map['strokes'] as List)
          [
            for (final p in s as List)
              Offset((p as List)[0] * 1.0, p[1] * 1.0),
          ],
      ];
      if (strokes.isEmpty) return null;
      return Signature(strokes, (map['aspect'] as num).toDouble());
    } catch (_) {
      return null; // bozuk kayıt: imza yokmuş gibi davran, çökme
    }
  }

  /// Kayıtlı imzayı okur (yoksa null). Kullanıcı her seferinde yeniden çizmesin.
  static Future<Signature?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    return raw == null ? null : fromJson(raw);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, toJson());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

/// İmza çizme penceresi. Kullanıcı çizip onaylarsa [Signature] döner.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key});

  static Future<Signature?> show(BuildContext context) =>
      showDialog<Signature>(
        context: context,
        builder: (_) => const SignaturePad(),
      );

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _strokes = <List<Offset>>[];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(context.t('sp.draw')),
      content: SizedBox(
        width: 400,
        height: 200,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onPanStart: (d) =>
                setState(() => _strokes.add([d.localPosition])),
            onPanUpdate: (d) => setState(() {
              if (_strokes.isEmpty) _strokes.add([]);
              _strokes.last.add(d.localPosition);
            }),
            child: CustomPaint(
              painter: _StrokePainter(_strokes),
              size: Size.infinite,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _strokes.isEmpty ? null : () => setState(_strokes.clear),
          child: Text(context.t('common.clear')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _strokes.isEmpty
              ? null
              : () {
                  final sig = Signature.fromRaw(_strokes);
                  if (sig.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                  sig.save();
                  Navigator.pop(context, sig);
                },
          child: Text(context.t('common.ok')),
        ),
      ],
    );
  }
}

/// Ham (ekran koordinatlı) darbeleri çizer — imza panosu için.
class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      canvas.drawPath(
        Path()
          ..moveTo(stroke.first.dx, stroke.first.dy)
          ..addPolygon(stroke, false),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}

/// Normalize edilmiş (0..1) imzayı verilen kutuya çizer — yerleştirme
/// önizlemesi ile PDF'e basılan şey aynı noktalardan gelir.
class SignaturePainter extends CustomPainter {
  const SignaturePainter(this.signature, {this.color = Colors.black});

  final Signature signature;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in signature.strokes) {
      if (stroke.length < 2) continue;
      final points = [
        for (final p in stroke) Offset(p.dx * size.width, p.dy * size.height),
      ];
      canvas.drawPath(
        Path()
          ..moveTo(points.first.dx, points.first.dy)
          ..addPolygon(points, false),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SignaturePainter old) => old.signature != signature;
}
