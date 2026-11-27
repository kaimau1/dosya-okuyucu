import 'dart:ui' show Offset, PointerDeviceKind;

import 'package:dosya_okuyucu/core/edit/ink_logic.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_markup.dart';
import 'package:flutter/gestures.dart' show kSecondaryStylusButton;
import 'package:flutter_test/flutter_test.dart';

/// Ortak kalem mantığı (B20): anlık kalem ⇄ silgi geçişi, kalemin silgi ucu,
/// silgi isabeti ve alan silgisinin kesimi.
void main() {
  setUp(() {
    PenTrayMemory.lastPen = PenTrayTool.pen;
    PenTrayMemory.eraserMode = EraserMode.stroke;
  });

  test('anlık geçiş: kalem → silgi → SON kalem', () {
    PenTrayMemory.note(PenTrayTool.highlighter);
    expect(PenTrayMemory.swap(PenTrayTool.highlighter), PenTrayTool.eraser);
    PenTrayMemory.note(PenTrayTool.eraser);
    expect(PenTrayMemory.lastPen, PenTrayTool.highlighter);
    expect(PenTrayMemory.swap(PenTrayTool.eraser), PenTrayTool.highlighter);
    // Tepsi dışı araçtan (yazı/kaydır) silgiye.
    expect(PenTrayMemory.swap(null), PenTrayTool.eraser);
  });

  test('kalemin yan düğmesi ya da ters ucu silgidir, parmak değil', () {
    expect(isStylusEraser(PointerDeviceKind.invertedStylus, 0), isTrue);
    expect(isStylusEraser(PointerDeviceKind.stylus, kSecondaryStylusButton),
        isTrue);
    expect(isStylusEraser(PointerDeviceKind.stylus, 1), isFalse);
    expect(isStylusEraser(PointerDeviceKind.touch, kSecondaryStylusButton),
        isFalse);
    expect(isStylusEraser(null, 0), isFalse);
  });

  test('silgi isabeti iki nokta ARASINDAKİ gövdeye de bakar', () {
    const line = [Offset(0, 0), Offset(100, 0)];
    expect(strokeHit(line, const Offset(50, 5), 6), isTrue);
    expect(strokeHit(line, const Offset(50, 10), 6), isFalse);
    expect(strokeHit(const [Offset(3, 3)], const Offset(0, 0), 5), isTrue);
  });

  test('alan silgisi çizgiyi değdiği yerden ikiye böler', () {
    const line = [Offset(0, 0), Offset(100, 0)];
    final pieces = cutStroke(line, const Offset(50, 0), 10)!;
    expect(pieces, hasLength(2));
    expect(pieces[0].first, const Offset(0, 0));
    expect(pieces[0].last.dx, closeTo(40, 1e-9));
    expect(pieces[1].first.dx, closeTo(60, 1e-9));
    expect(pieces[1].last, const Offset(100, 0));
    // Değmeyen çizgi: null (aynen kalır); tamamen içerdeki: hiç parça yok.
    expect(cutStroke(line, const Offset(50, 30), 10), isNull);
    expect(cutStroke(const [Offset(0, 0), Offset(2, 0)], Offset.zero, 10),
        isEmpty);
    // Ucundan silmek tek parça bırakır.
    expect(cutStroke(line, const Offset(100, 0), 10), hasLength(1));
  });

  test('PDF alan silgisi darbeyi keser, bütün silgi siler', () {
    const m = InkMark(0,
        points: [Offset(0.1, 0.5), Offset(0.9, 0.5)],
        colorArgb: 0xFF000000,
        widthFraction: 0.002);
    final whole = eraseMarksAt(const [m],
        page: 0, point: const Offset(0.5, 0.5), radius: 0.02, aspect: 1);
    expect(whole, isEmpty);
    final cut = eraseMarksAt(const [m],
        page: 0,
        point: const Offset(0.5, 0.5),
        radius: 0.02,
        aspect: 1,
        partial: true);
    expect(cut, hasLength(2));
    expect((cut.first as InkMark).colorArgb, 0xFF000000);
  });
}
