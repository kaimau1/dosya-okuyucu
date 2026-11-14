import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dosya_okuyucu/services/fm/pdf_zoom_memory.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_margin_crop.dart';

/// Ferrari H3.4 — kenar boşluğu kırpma: içerik sınırı, birleştirme, düzen,
/// belge başına tercih.
void main() {
  /// [w]×[h] beyaz çizim; ([l],[t])–([r],[b]) aralığı siyah (içerik).
  Uint8List page(int w, int h, int l, int t, int r, int b) {
    final px = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
    for (var y = t; y <= b; y++) {
      for (var x = l; x <= r; x++) {
        final i = (y * w + x) * 4;
        px[i] = 0;
        px[i + 1] = 0;
        px[i + 2] = 0;
      }
    }
    return px;
  }

  test('içerik sınırı kenar paylarına çevrilir', () {
    final m = PdfMarginCropper.marginsOf(page(100, 200, 10, 20, 89, 179), 100, 200)!;
    expect(m.left, closeTo(0.10, 1e-9));
    expect(m.right, closeTo(0.10, 1e-9));
    expect(m.top, closeTo(0.10, 1e-9));
    expect(m.bottom, closeTo(0.10, 1e-9));
  });

  test('boş sayfa ve tek leke içerik sayılmaz', () {
    final blank = Uint8List(50 * 50 * 4)..fillRange(0, 50 * 50 * 4, 255);
    expect(PdfMarginCropper.marginsOf(blank, 50, 50), isNull);
    final speck = page(50, 50, 25, 25, 25, 25);
    expect(PdfMarginCropper.marginsOf(speck, 50, 50), isNull);
  });

  test('birleştirme: en dar pay, eksi emniyet payı; taşan kapak sayılmaz', () {
    const cover = PdfMarginCrop(0, 0, 0, 0);
    const a = PdfMarginCrop(0.12, 0.08, 0.10, 0.08);
    const b = PdfMarginCrop(0.10, 0.06, 0.14, 0.10);
    final c = PdfMarginCropper.combine([cover, a, b])!;
    expect(c.left, closeTo(0.10 - PdfMarginCropper.pad, 1e-9));
    expect(c.right, closeTo(0.10 - PdfMarginCropper.pad, 1e-9));
    expect(PdfMarginCropper.combine([cover]), isNull);
    expect(
        PdfMarginCropper.combine(const [PdfMarginCrop(0.02, 0.1, 0.02, 0.1)]),
        isNull,
        reason: 'yatayda kırpacak boşluk yok');
  });

  test('düzen: sayfa boşlukları belge sınırının dışına taşar', () {
    const crop = PdfMarginCrop(0.1, 0, 0.1, 0);
    final pages = [_Page(600, 800), _Page(600, 800)];
    final l = PdfMarginCropper.layout(pages, 8, crop);
    expect(l.documentSize.width, closeTo(480 + 16, 1e-9));
    // İçerik (sayfanın %10–%90'ı) belgenin 8–488 aralığında.
    final r = l.pageLayouts.first;
    expect(r.left + 60, closeTo(8, 1e-9));
    expect(r.width, 600);
    expect(l.pageLayouts[1].top, closeTo(8 + 800 + 8, 1e-9));
  });

  test('paylar listeye gidip gelir, bozuk liste reddedilir', () {
    const c = PdfMarginCrop(0.1, 0.05, 0.12, 0.07);
    expect(PdfMarginCrop.fromList(c.toList()), c);
    expect(PdfMarginCrop.fromList(const [0.1, 0.1]), isNull);
    expect(PdfMarginCrop.fromList(const [0.6, 0, 0, 0]), isNull);
    expect(PdfMarginCrop.fromList(null), isNull);
  });

  test('tercih belge başına saklanır ve yeniden yüklenir', () async {
    SharedPreferences.setMockInitialValues({});
    PdfZoomMemory.debugReset();
    await PdfZoomMemory.ensureLoaded();
    await PdfZoomMemory.recordCrop('/a.pdf', const [0.1, 0, 0.1, 0]);
    expect(PdfZoomMemory.cropOf('/b.pdf'), isNull);
    PdfZoomMemory.debugReset();
    await PdfZoomMemory.ensureLoaded();
    expect(PdfZoomMemory.cropOf('/a.pdf'), [0.1, 0, 0.1, 0]);
    await PdfZoomMemory.recordCrop('/a.pdf', null);
    expect(PdfZoomMemory.cropOf('/a.pdf'), isNull);
  });
}

class _Page implements PdfPage {
  _Page(this.width, this.height);

  @override
  final double width;

  @override
  final double height;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}
