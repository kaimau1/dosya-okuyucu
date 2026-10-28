import 'dart:io';
import 'dart:ui' show Color;

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 29 — slayt nesneleri: çerçeve, metin kutusu, şekil, dolgu, arka plan,
/// geçiş, düzenden yeni slayt (gidiş-dönüş).
PptxEditor _open() =>
    PptxEditor.parse(File('test/fixtures/office/sunum.pptx').readAsBytesSync());

String _slideXml(PptxEditor e, int i) =>
    ZipDecoder()
        .decodeBytes(e.save())
        .files
        .where((f) => f.name == e.slides[i].fileName)
        .map((f) => String.fromCharCodes(f.content as List<int>))
        .first;

void main() {
  test('metin kutusu ekle → kimlik benzersiz, çerçeve taşınır/boyutlanır/döner', () {
    final e = _open();
    final s = e.slides.first;
    final before = s.view!.shapes.length;
    expect(e.addTextBox(s, 'Merhaba'), isNotNull);
    expect(s.view!.shapes.length, before + 1);
    final shape = s.view!.shapes.last;
    expect(shape.paragraphs.map((p) => p.plainText).join(), 'Merhaba');
    expect(shape.hasText, isTrue);
    expect(e.setShapeFrame(s, shape, x: 100, y: 50, w: 300, h: 80, rotationDeg: 15),
        isTrue);
    final moved = s.view!.shapes.last;
    expect((moved.x, moved.y, moved.w, moved.h), (100, 50, 300, 80));
    expect(moved.rotationDeg, closeTo(15, 0.01));
    final ids = XmlDocument.parse(_slideXml(e, 0))
        .findAllElements('p:cNvPr')
        .map((x) => x.getAttribute('id'))
        .toList();
    expect(ids.toSet().length, ids.length);
    // Kaydet → yeniden aç: aynı yerde.
    final again = PptxEditor.parse(e.save());
    final back = again.slides.first.view!.shapes.last;
    expect((back.x, back.y, back.w, back.h), (100, 50, 300, 80));
  });

  test('şekil ekle + dolgu + arka plan + geçiş', () {
    final e = _open();
    final s = e.slides.first;
    for (final k in kPptxShapeKinds) {
      expect(e.addShape(s, k), isNotNull, reason: k);
    }
    final sp = s.view!.shapes.firstWhere((x) => x.preset == 'ellipse');
    expect(e.setShapeFill(s, sp, const Color(0xFFFF0000)), isTrue);
    expect(s.view!.shapes.firstWhere((x) => x.preset == 'ellipse').fill,
        const Color(0xFFFF0000));
    expect(e.setSlideBackground(s, const Color(0xFF112233)), isTrue);
    expect(s.view!.background, const Color(0xFF112233));
    expect(e.transitionOf(s), PptxTransition.none);
    e.setTransition(s, PptxTransition.push);
    expect(e.transitionOf(s), PptxTransition.push);
    final again = PptxEditor.parse(e.save());
    expect(again.transitionOf(again.slides.first), PptxTransition.push);
    // bg ilk çocuk, transition cSld'den sonra.
    final root = XmlDocument.parse(_slideXml(e, 0)).rootElement;
    expect(root.childElements.first.name.local, 'cSld');
    expect(root.findAllElements('p:bg').first.parent!.childElements.first.name.local, 'bg');
    e.setTransition(s, PptxTransition.none);
    expect(e.transitionOf(s), PptxTransition.none);
  });

  test('düzenden yeni slayt: yer tutucular, sıralama, kayıt', () {
    final e = _open();
    final layouts = e.layouts();
    expect(layouts, isNotEmpty);
    final n = e.slides.length;
    final ns = e.addSlideFromLayout(layouts.first, after: e.slides.first)!;
    expect(e.slides.length, n + 1);
    expect(e.slides[1], same(ns));
    final again = PptxEditor.parse(e.save());
    expect(again.slides.length, n + 1);
    final shapes = again.slides[1].view?.shapes ?? const [];
    expect(shapes.every((x) => x.isPlaceholder), isTrue);
  });
}
