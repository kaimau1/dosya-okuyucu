/// **İki PDF karşılaştırma** — Faz 39 madde 4.
///
/// * **Metin farkı:** sayfa sayfa satır düzeyinde LCS; değişen satır
///   çiftleri sözcük düzeyinde yeniden karşılaştırılır (eklenen/silinen
///   sözcükler ayrı işaretlenir). Bellek tavanı: satır×satır > 4M hücre ise
///   sayfa "tümü değişti" sayılır (isteğe bağlı iş, izolatta).
/// * **Görsel fark:** iki sayfa aynı genişlikte gri çizilir
///   ([PdfRaster.renderGray]); parlaklık farkı eşiği aşan pikseller kırmızı
///   boyanmış bir PNG ve oran olarak döner.
library;

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as imglib;
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum DiffKind { same, added, removed }

class DiffPiece {
  final DiffKind kind;
  final String text;
  const DiffPiece(this.kind, this.text);

  @override
  String toString() => '${kind.name}:$text';
}

/// Bir sayfanın metin farkı: satırlar, her biri parçalardan.
class PageTextDiff {
  /// 1-tabanlı sayfa (A'daki; B'de fazla sayfa varsa B'nin numarası).
  final int page;
  final List<List<DiffPiece>> lines;
  const PageTextDiff(this.page, this.lines);

  bool get changed =>
      lines.any((l) => l.any((p) => p.kind != DiffKind.same));

  int get addedWords => _count(DiffKind.added);
  int get removedWords => _count(DiffKind.removed);

  int _count(DiffKind k) => lines.fold(
      0,
      (s, l) =>
          s +
          l
              .where((p) => p.kind == k)
              .fold(0, (t, p) => t + _words(p.text)));

  static int _words(String s) =>
      s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;
}

class PageVisualDiff {
  final int page;

  /// Farklı piksel oranı 0..1.
  final double ratio;

  /// Fark görüntüsü (B soluk, farklar kırmızı) PNG.
  final Uint8List png;
  const PageVisualDiff(this.page, this.ratio, this.png);
}

abstract final class PdfCompare {
  static const _maxCells = 4000000;

  /// Sayfa → satırlar (Syncfusion metin çıkarıcı).
  static List<List<String>> pageLines(List<int> bytes, {String? password}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final extractor = PdfTextExtractor(doc);
      return [
        for (var i = 0; i < doc.pages.count; i++)
          [
            for (final l in extractor.extractTextLines(
                startPageIndex: i, endPageIndex: i))
              if (l.text.trim().isNotEmpty)
                l.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          ],
      ];
    } finally {
      doc.dispose();
    }
  }

  static List<PageTextDiff> compareText(List<int> a, List<int> b,
      {String? passwordA, String? passwordB}) {
    final pa = pageLines(a, password: passwordA);
    final pb = pageLines(b, password: passwordB);
    final n = math.max(pa.length, pb.length);
    return [
      for (var i = 0; i < n; i++)
        PageTextDiff(
          i + 1,
          diffLines(i < pa.length ? pa[i] : const [],
              i < pb.length ? pb[i] : const []),
        ),
    ];
  }

  static Future<List<PageTextDiff>> compareTextInBackground(
          List<int> a, List<int> b, {String? passwordA, String? passwordB}) =>
      Isolate.run(() =>
          compareText(a, b, passwordA: passwordA, passwordB: passwordB));

  /// Saf: satır farkı; ardışık silinen+eklenen satır çiftleri sözcük farkına
  /// iner.
  static List<List<DiffPiece>> diffLines(List<String> a, List<String> b) {
    final ops = _lcs(a, b);
    final out = <List<DiffPiece>>[];
    var i = 0;
    while (i < ops.length) {
      final op = ops[i];
      if (op.kind == DiffKind.same) {
        out.add([DiffPiece(DiffKind.same, op.text)]);
        i++;
        continue;
      }
      // Değişen blok: silinenler + eklenenler.
      final removed = <String>[], added = <String>[];
      while (i < ops.length && ops[i].kind != DiffKind.same) {
        (ops[i].kind == DiffKind.removed ? removed : added).add(ops[i].text);
        i++;
      }
      final pairs = math.min(removed.length, added.length);
      for (var k = 0; k < pairs; k++) {
        out.add(diffWords(removed[k], added[k]));
      }
      for (final r in removed.skip(pairs)) {
        out.add([DiffPiece(DiffKind.removed, r)]);
      }
      for (final a2 in added.skip(pairs)) {
        out.add([DiffPiece(DiffKind.added, a2)]);
      }
    }
    return out;
  }

  /// Saf: iki satırın sözcük farkı (komşu aynı türler birleşir).
  static List<DiffPiece> diffWords(String a, String b) {
    final wa = a.split(' '), wb = b.split(' ');
    final ops = _lcs(wa, wb);
    final out = <DiffPiece>[];
    for (final op in ops) {
      if (out.isNotEmpty && out.last.kind == op.kind) {
        out[out.length - 1] = DiffPiece(op.kind, '${out.last.text} ${op.text}');
      } else {
        out.add(op);
      }
    }
    return out;
  }

  /// LCS tabanlı düzenleme dizisi (silinenler eklenenlerden önce).
  static List<DiffPiece> _lcs(List<String> a, List<String> b) {
    final n = a.length, m = b.length;
    if (n == 0) return [for (final s in b) DiffPiece(DiffKind.added, s)];
    if (m == 0) return [for (final s in a) DiffPiece(DiffKind.removed, s)];
    if ((n + 1) * (m + 1) > _maxCells) {
      return [
        for (final s in a) DiffPiece(DiffKind.removed, s),
        for (final s in b) DiffPiece(DiffKind.added, s),
      ];
    }
    final w = m + 1;
    final t = Uint32List((n + 1) * w);
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        t[i * w + j] = a[i] == b[j]
            ? t[(i + 1) * w + j + 1] + 1
            : math.max(t[(i + 1) * w + j], t[i * w + j + 1]);
      }
    }
    final out = <DiffPiece>[];
    var i = 0, j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        out.add(DiffPiece(DiffKind.same, a[i]));
        i++;
        j++;
      } else if (t[(i + 1) * w + j] >= t[i * w + j + 1]) {
        out.add(DiffPiece(DiffKind.removed, a[i++]));
      } else {
        out.add(DiffPiece(DiffKind.added, b[j++]));
      }
    }
    while (i < n) {
      out.add(DiffPiece(DiffKind.removed, a[i++]));
    }
    while (j < m) {
      out.add(DiffPiece(DiffKind.added, b[j++]));
    }
    return out;
  }

  /// Saf: iki gri sayfanın farkı. Yükseklik farklıysa uzun olanın taşan
  /// kısmı tümden "farklı" sayılır.
  static PageVisualDiff visualDiff(
    int page,
    ({int w, int h, Uint8List luma}) a,
    ({int w, int h, Uint8List luma}) b, {
    int threshold = 48,
  }) {
    final w = math.min(a.w, b.w);
    final h = math.max(a.h, b.h);
    final img = imglib.Image(width: w, height: h);
    var diff = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final inA = y < a.h, inB = y < b.h;
        final la = inA ? a.luma[y * a.w + x] : 255;
        final lb = inB ? b.luma[y * b.w + x] : 255;
        final different = inA != inB || (la - lb).abs() > threshold;
        if (different) {
          diff++;
          img.setPixelRgb(x, y, 220, 40, 40);
        } else {
          // B'nin soluk kopyası: bağlam görünsün, farklar öne çıksın.
          final v = 255 - ((255 - lb) * 0.35).round();
          img.setPixelRgb(x, y, v, v, v);
        }
      }
    }
    return PageVisualDiff(
        page, w * h == 0 ? 0 : diff / (w * h), imglib.encodePng(img));
  }
}
