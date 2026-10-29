import 'dart:math' as math;

import 'package:dosya_okuyucu/services/pdf/pdf_fling.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// PDF fırlatma sürtünmesi: kaydırma Android'deki kadar uzağa gitmeli,
/// yakınlaştırma ataleti (katsayı ×200) sürtünme olarak kalmalı.
void main() {
  test('3000 px/sn fırlatma en az ~1000 px gider (eskisi ~270)', () {
    final pan = FrictionSimulation(kPdfPanFriction, 0, 3000).finalX;
    final old = FrictionSimulation(0.0000135, 0, 3000).finalX;
    expect(pan, greaterThan(1000));
    expect(pan, lessThan(1600));
    expect(old, lessThan(300));
  });

  test('pinch katsayısı ×200 < 1 (yakınlık parmak kalkınca fırlamaz)', () {
    expect(kPdfPinchFriction * 200, lessThan(1));
    expect(math.log(kPdfPinchFriction * 200), lessThan(0));
  });
}
