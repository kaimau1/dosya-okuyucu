import 'package:dosya_okuyucu/widgets/fm/fm_file_image.dart';
import 'package:flutter_test/flutter_test.dart';

/// **G7.7 görsel bellek bombası** (2026-11-12): yalnız genişlik sınırı
/// 1000×1.000.000'luk bir görselde 4 GB bitmap ederdi; piksel tavanı iki
/// kenarı aynı oranla küçültür.
void main() {
  test('olağan görsel dokunulmaz', () {
    final s = fmPixelCap(3072, 2304);
    expect((s.width, s.height), (3072, 2304));
    final tall = fmPixelCap(1080, 20000);
    expect((tall.width, tall.height), (1080, 20000));
  });

  test('100 MP+ görsel tavana iner, en-boy korunur', () {
    final s = fmPixelCap(1000, 1000000);
    expect(s.width! * s.height!, lessThanOrEqualTo(fmMaxDecodePixels));
    expect(s.height! / s.width!, closeTo(1000, 10));

    final sq = fmPixelCap(20000, 20000);
    expect(sq.width! * sq.height!, lessThanOrEqualTo(fmMaxDecodePixels));
    expect(sq.width, sq.height);
  });

  test('bozuk ölçü güvenli', () {
    final s = fmPixelCap(0, 5);
    expect((s.width, s.height), (null, null));
  });
}
