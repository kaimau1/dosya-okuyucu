import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/edit/ink_logic.dart'
    show cutNormalizedStroke, normalizedStrokeHit;
import '../pdf_tools.dart' show stampTransform;

/// Kalem ekranının ([PdfInkScreen]) sayfaya bıraktığı iz.
///
/// Konumlar **görünen sayfaya oranla 0..1** (sol-üst orijin, `/Rotate`
/// uygulanmış hâl): ekran boyutu, yakınlaştırma ve PDF'in punto ölçüsü
/// bilinmeden saklanabilsin. Kalınlık ve yazı boyu da sayfa GENİŞLİĞİNE
/// oranla — yakınlaştırınca kalem kalınlaşmasın, kaydedince de ekranda
/// görüldüğü kalınlıkta çıksın.
sealed class PdfMark {
  const PdfMark(this.page);

  /// 0 tabanlı sayfa sırası.
  final int page;
}

/// Kalem ya da fosforlu kalem darbesi.
class InkMark extends PdfMark {
  const InkMark(
    super.page, {
    required this.points,
    required this.colorArgb,
    required this.widthFraction,
    this.highlighter = false,
  });

  final List<Offset> points;
  final int colorArgb;

  /// Çizgi kalınlığı / sayfa genişliği.
  final double widthFraction;

  /// Yarı saydam, altındaki yazıyı örtmeyen iz (çarpım karışımı).
  final bool highlighter;

  InkMark withPoints(List<Offset> points) => InkMark(page,
      points: points,
      colorArgb: colorArgb,
      widthFraction: widthFraction,
      highlighter: highlighter);
}

/// Sayfaya yazılan metin (form alanı olmayan PDF'e de yazabilmek için).
class TextMark extends PdfMark {
  const TextMark(
    super.page, {
    required this.position,
    required this.text,
    required this.fontFraction,
    required this.colorArgb,
  });

  /// Metin kutusunun sol-üst köşesi (0..1).
  final Offset position;
  final String text;

  /// Yazı boyu / sayfa genişliği.
  final double fontFraction;
  final int colorArgb;

  TextMark copyWith({Offset? position, String? text, double? fontFraction}) =>
      TextMark(page,
          position: position ?? this.position,
          text: text ?? this.text,
          fontFraction: fontFraction ?? this.fontFraction,
          colorArgb: colorArgb);
}

/// Fosforlu kalemin saydamlığı — ekranda ve PDF'te aynı.
const double kHighlighterOpacity = 0.35;

/// Silgi: [page] sayfasında [point] çevresindeki ([radius], sayfa genişliği
/// oranı) izleri çıkarır. [aspect] = sayfa genişliği / yüksekliği; oranlar
/// iki eksende farklı ölçekte olduğu için mesafe ondan geçerek ölçülür.
///
/// Darbe varsayılan olarak **bütün** silinir — elle işaretlemede beklenen
/// davranış, geri al da tek adımda getirir. [partial] (kalem tepsisinin
/// "alan silgisi", B20) yalnız değilen yeri keser; kalan parçalar ayrı darbe
/// olur. Saf fonksiyon — birim testli.
List<PdfMark> eraseMarksAt(
  List<PdfMark> marks, {
  required int page,
  required Offset point,
  required double radius,
  required double aspect,
  bool partial = false,
}) {
  final out = <PdfMark>[];
  for (final m in marks) {
    if (m is! InkMark || m.page != page) {
      out.add(m); // metin dokunarak seçilip siliniyor (ekranda)
      continue;
    }
    final r = radius + m.widthFraction / 2;
    if (!partial) {
      if (!normalizedStrokeHit(m.points, point, r, aspect)) out.add(m);
      continue;
    }
    final pieces = cutNormalizedStroke(m.points, point, r, aspect);
    if (pieces == null) {
      out.add(m);
    } else {
      for (final piece in pieces) {
        out.add(m.withPoints(piece));
      }
    }
  }
  return out;
}

/// İzleri PDF'e **kalıcı** olarak (sayfa içeriğine vektör) yazar.
///
/// Niye açıklama (annotation) değil de içerik: her görüntüleyicide aynı
/// görünür, yazdırılınca çıkar ve formu gönderen kişinin karşı tarafta
/// "işaretler görünmüyor" sorunu yaşamaz. Geri almak için özgün dosya
/// kopya olarak saklanabilir (kaydetme penceresi).
///
/// [fontBytes] metin izleri için gömülecek TrueType font (Türkçe harfler
/// için şart — bkz. `PdfTools.replaceText`). Metin izi yoksa gerekmez.
Future<List<int>> applyPdfMarks(
  List<int> bytes,
  List<PdfMark> marks, {
  List<int>? fontBytes,
  String? password,
}) =>
    Isolate.run(() async {
      final doc = PdfDocument(inputBytes: bytes, password: password);
      try {
        final byPage = <int, List<PdfMark>>{};
        for (final m in marks) {
          if (m.page < 0 || m.page >= doc.pages.count) continue;
          (byPage[m.page] ??= []).add(m);
        }
        for (final entry in byPage.entries) {
          final page = doc.pages[entry.key];
          final turns = page.rotation.index;
          final raw = page.size;
          // Görünen (döndürülmüş) ölçü: kullanıcı sayfayı böyle gördü.
          final visible = turns.isOdd ? Size(raw.height, raw.width) : raw;
          final t = stampTransform(raw, turns);
          final g = page.graphics;
          final state = g.save();
          try {
            if (t.angle != 0) {
              g.translateTransform(t.translate.dx, t.translate.dy);
              g.rotateTransform(t.angle);
            }
            for (final m in entry.value) {
              switch (m) {
                case InkMark():
                  _drawInk(g, m, visible);
                case TextMark():
                  if (fontBytes != null) _drawText(g, m, visible, fontBytes);
              }
            }
          } finally {
            g.restore(state);
          }
        }
        return await doc.save();
      } finally {
        doc.dispose();
      }
    });

PdfColor _color(int argb) =>
    PdfColor((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

void _drawInk(PdfGraphics g, InkMark m, Size visible) {
  if (m.points.isEmpty) return;
  final width = math.max(0.3, m.widthFraction * visible.width);
  final pts = [
    for (final p in m.points)
      Offset(p.dx * visible.width, p.dy * visible.height),
  ];
  final state = g.save();
  try {
    if (m.highlighter) {
      g.setTransparency(kHighlighterOpacity, mode: PdfBlendMode.multiply);
    }
    if (pts.length == 1) {
      // Tek dokunuş: nokta.
      final r = width / 2;
      g.drawEllipse(
        Rect.fromCircle(center: pts.first, radius: r),
        brush: PdfSolidBrush(_color(m.colorArgb)),
      );
      return;
    }
    final pen = PdfPen(
      _color(m.colorArgb),
      width: width,
      lineCap: m.highlighter ? PdfLineCap.square : PdfLineCap.round,
      lineJoin: PdfLineJoin.round,
    );
    // Segment segment `addLine`: `addPolygon` şekli kapatırdı (bkz.
    // `PdfTools.stampStrokes`). Tek yol = tek çizim; fosforluda üst üste
    // binen segmentler koyulaşmaz.
    final path = PdfPath()..startFigure();
    for (var i = 0; i + 1 < pts.length; i++) {
      path.addLine(pts[i], pts[i + 1]);
    }
    g.drawPath(path, pen: pen);
  } finally {
    g.restore(state);
  }
}

void _drawText(PdfGraphics g, TextMark m, Size visible, List<int> fontBytes) {
  if (m.text.trim().isEmpty) return;
  final size = math.max(4.0, m.fontFraction * visible.width);
  final x = m.position.dx * visible.width;
  final y = m.position.dy * visible.height;
  g.drawString(
    m.text,
    PdfTrueTypeFont(fontBytes, size),
    brush: PdfSolidBrush(_color(m.colorArgb)),
    bounds: Rect.fromLTWH(
      x,
      y,
      math.max(1, visible.width - x),
      math.max(1, visible.height - y),
    ),
  );
}
