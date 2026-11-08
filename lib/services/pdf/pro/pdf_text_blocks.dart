/// PDF Pro (Faz 52): PDFium metin nesnelerinden satır ve blok (paragraf) kurma.
///
/// Saf Dart — PDFium'a dokunmaz; [PdfEditBridge.textObjects]'in verdiği
/// nesnelerle çalışır, test edilebilir. Faz 55 (metin anlama) bunun yerine
/// geçecek; burada karar kapısı (PK1) için yeterli, basit kurallar var.
library;

import 'dart:math' as math;

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
  });

  /// Ekranda görünen punto (Tf × matris ölçeği).
  double get visualSize =>
      tfSize * math.sqrt(matrix[2] * matrix[2] + matrix[3] * matrix[3]);
  double get baseline => matrix[5];
  bool get rotated => matrix[1].abs() > 1e-3 || matrix[2].abs() > 1e-3;
}

class PdfTextLine {
  final List<PdfTextObjectInfo> objects;
  PdfTextLine(this.objects);

  double get left => objects.map((o) => o.left).reduce(math.min);
  double get right => objects.map((o) => o.right).reduce(math.max);
  double get top => objects.map((o) => o.top).reduce(math.max);
  double get bottom => objects.map((o) => o.bottom).reduce(math.min);
  double get baseline => objects.first.baseline;
  double get size => objects.first.visualSize;

  /// Nesneler soldan sağa; aralarında boşluk yoksa ve yatay boşluk yeterince
  /// büyükse bir boşluk eklenir.
  String get text {
    final b = StringBuffer();
    for (var i = 0; i < objects.length; i++) {
      final o = objects[i];
      if (i > 0) {
        final prev = objects[i - 1];
        final gap = o.left - prev.right;
        final s = b.toString();
        if (gap > size * 0.15 &&
            !s.endsWith(' ') &&
            !o.text.startsWith(' ')) {
          b.write(' ');
        }
      }
      b.write(o.text);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class PdfTextBlock {
  final List<PdfTextLine> lines;
  PdfTextBlock(this.lines);

  double get left => lines.map((l) => l.left).reduce(math.min);
  double get right => lines.map((l) => l.right).reduce(math.max);
  double get top => lines.map((l) => l.top).reduce(math.max);
  double get bottom => lines.map((l) => l.bottom).reduce(math.min);
  String get text => lines.map((l) => l.text).join(' ');
  List<int> get objectIndexes =>
      [for (final l in lines) for (final o in l.objects) o.index];
}

/// Nesneleri satırlara, satırları bloklara gruplar. Döndürülmüş metin kendi
/// bloğudur (yeniden dizilmez). Boş metinli nesneler atlanır.
List<PdfTextBlock> groupTextBlocks(List<PdfTextObjectInfo> objects) {
  final upright = <PdfTextObjectInfo>[];
  final blocks = <PdfTextBlock>[];
  for (final o in objects) {
    if (o.text.trim().isEmpty) continue;
    if (o.rotated) {
      blocks.add(PdfTextBlock([PdfTextLine([o])]));
    } else {
      upright.add(o);
    }
  }
  // 1) Satırlar: aynı taban çizgisi (± %35 punto), aynı punto sınıfı, yatayda
  //    bitişik (araya sütun boşluğu girmemiş).
  upright.sort((a, b) {
    final d = b.baseline.compareTo(a.baseline);
    return d != 0 ? d : a.left.compareTo(b.left);
  });
  final lines = <PdfTextLine>[];
  for (final o in upright) {
    PdfTextLine? hit;
    for (final l in lines.reversed) {
      if ((l.baseline - o.baseline).abs() > l.size * 0.35) {
        if (l.baseline - o.baseline > l.size) break; // sıralı: daha yukarıdakiler
        continue;
      }
      final gap = o.left - l.right;
      if (gap > -l.size * 0.5 && gap < l.size * 2.5) {
        hit = l;
        break;
      }
    }
    if (hit != null) {
      hit.objects.add(o);
      hit.objects.sort((a, b) => a.left.compareTo(b.left));
    } else {
      lines.add(PdfTextLine([o]));
    }
  }
  // 2) Bloklar: alt alta, satır aralığı ≤ 1,7 punto, punto farkı ≤ %20,
  //    yatayda örtüşen satırlar (sütunlar karışmaz).
  lines.sort((a, b) => b.baseline.compareTo(a.baseline));
  final open = <PdfTextBlock>[];
  for (final l in lines) {
    PdfTextBlock? hit;
    for (final b in open) {
      final last = b.lines.last;
      final dy = last.baseline - l.baseline;
      final overlap =
          math.min(last.right, l.right) - math.max(last.left, l.left);
      if (dy > 0 &&
          dy <= last.size * 1.7 &&
          (l.size - last.size).abs() <= last.size * 0.2 &&
          overlap > 0) {
        hit = b;
        break;
      }
    }
    if (hit != null) {
      hit.lines.add(l);
    } else {
      final b = PdfTextBlock([l]);
      open.add(b);
      blocks.add(b);
    }
  }
  return blocks;
}
