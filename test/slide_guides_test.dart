import 'package:dosya_okuyucu/widgets/slide_frame_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 29b — hizalama kılavuzları: slayt merkezi/kenarları ve diğer
/// şekillerin kenar/merkezlerine yaslanma.
void main() {
  double? gx, gy;
  void guides(double? x, double? y) {
    gx = x;
    gy = y;
  }

  test('slayt merkezine yaslanır (yatay + dikey)', () {
    // Merkez (478, 272) — slayt merkezi (480, 270), eşik 6.
    final r = SlideFrameEditor.snapRect(
        const Rect.fromLTWH(428, 242, 100, 60), 960, 540, const [], 6, guides);
    expect(r.center, const Offset(480, 270));
    expect((gx, gy), (480.0, 270.0));
  });

  test('başka şeklin kenarına yaslanır; uzaktaysa dokunmaz', () {
    const other = Rect.fromLTWH(100, 100, 200, 80); // sağ kenar 300
    final r = SlideFrameEditor.snapRect(
        const Rect.fromLTWH(303, 400, 50, 50), 960, 540, const [other], 6, guides);
    expect(r.left, 300);
    expect(gx, 300);
    expect(gy, isNull);
    final far = SlideFrameEditor.snapRect(
        const Rect.fromLTWH(320, 400, 50, 50), 960, 540, const [other], 6, guides);
    expect(far, const Rect.fromLTWH(320, 400, 50, 50));
    expect((gx, gy), (null, null));
  });
}
