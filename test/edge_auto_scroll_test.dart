import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/pdf/edge_auto_scroll.dart';

/// Kenar oto-kaydırmasının hız eğrisi: ortada ölü bölge, kenara yaklaştıkça
/// doğrusal hızlanma, kenarda tavan hız. Yön işareti "o yöndeki içeriği
/// göster" anlamındadır (görüntüleyici matrisi ters yönde öteler).
void main() {
  const vp = Size(400, 800);

  test('ortada kıpırdamaz (ölü bölge)', () {
    expect(edgeAutoScrollDelta(const Offset(200, 400), vp), Offset.zero);
    expect(edgeAutoScrollDelta(const Offset(60, 700), vp), Offset.zero,
        reason: 'kenar payının hemen içi de ölü bölgedir');
  });

  test('alt kenara yaklaşınca +y, üst kenara yaklaşınca -y', () {
    expect(edgeAutoScrollDelta(const Offset(200, 790), vp).dy, greaterThan(0));
    expect(edgeAutoScrollDelta(const Offset(200, 10), vp).dy, lessThan(0));
    expect(edgeAutoScrollDelta(const Offset(200, 790), vp).dx, 0);
  });

  test('kenara yaklaştıkça hızlanır, tavanı aşmaz', () {
    final yavas = edgeAutoScrollDelta(const Offset(200, 760), vp).dy;
    final hizli = edgeAutoScrollDelta(const Offset(200, 795), vp).dy;
    expect(hizli, greaterThan(yavas));
    expect(edgeAutoScrollDelta(const Offset(200, 5000), vp).dy,
        lessThanOrEqualTo(14), reason: 'görüntü dışına taşan işaretçi de tavanda');
  });

  test('yatay eksen bağımsız çalışır', () {
    final d = edgeAutoScrollDelta(const Offset(395, 400), vp);
    expect(d.dx, greaterThan(0));
    expect(d.dy, 0);
  });

  test('küçücük görüntüde pay daralır, ölü bölge yine kalır', () {
    const tiny = Size(90, 90);
    expect(edgeAutoScrollDelta(const Offset(45, 45), tiny), Offset.zero);
    expect(edgeAutoScrollDelta(const Offset(88, 45), tiny).dx, greaterThan(0));
  });
}
