import 'dart:io';
import 'dart:ui' show Color;

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:dosya_okuyucu/services/pptx_rich_text.dart';
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

  test('slaytı gizle / göster → show="0" yazılır, kayıtta korunur, kaldırılır', () {
    final e = _open();
    final s = e.slides.first;
    expect(e.isHidden(s), isFalse);
    expect(e.setHidden(s, true), isTrue);
    expect(e.isHidden(s), isTrue);
    expect(XmlDocument.parse(_slideXml(e, 0)).rootElement.getAttribute('show'), '0');
    final again = PptxEditor.parse(e.save());
    expect(again.isHidden(again.slides.first), isTrue);
    if (again.slides.length > 1) expect(again.isHidden(again.slides[1]), isFalse);
    // Çoğaltılan gizli slayt da gizli kalır (PowerPoint gibi).
    final copy = again.duplicateSlide(again.slides.first);
    if (copy != null) expect(again.isHidden(copy), isTrue);
    again.setHidden(again.slides.first, false);
    expect(again.isHidden(again.slides.first), isFalse);
    expect(XmlDocument.parse(_slideXml(again, 0)).rootElement.getAttribute('show'),
        isNull);
  });

  test('tablo ekle → hücreler çizilir, düzenlenebilir, kayıtta korunur', () {
    final e = _open();
    final s = e.slides.first;
    final before = s.view!.shapes.length;
    expect(e.addTable(s, 3, 4), isNotNull);
    expect(e.addTable(s, 0, 4), isNull);
    final added = s.view!.shapes.skip(before).toList();
    // Dış çerçeve (seçilip taşınır) + 12 hücre.
    expect(added.where((c) => c.tableFrame), hasLength(1));
    final cells = added.where((c) => !c.tableFrame).toList();
    expect(cells.length, 12);
    expect(cells.every((c) => c.paragraphs.isNotEmpty && c.paragraphs.first.source != null),
        isTrue);
    // Başlık satırı vurgu rengiyle, gövde açık tonla dolu.
    expect(cells.first.fill, isNotNull);
    expect(cells[4].fill, isNotNull);
    expect(cells.first.fill, isNot(cells[4].fill));
    final xml = XmlDocument.parse(_slideXml(e, 0));
    final tbl = xml.findAllElements('a:tbl').single;
    expect(tbl.findAllElements('a:tableStyleId').single.innerText, kPptxDefaultTableStyle);
    expect(tbl.findAllElements('a:gridCol').length, 4);
    expect(tbl.findAllElements('a:tr').length, 3);
    // Şema sırası: a:tc içinde txBody, tcPr'den önce.
    for (final tc in tbl.findAllElements('a:tc')) {
      expect(tc.childElements.map((x) => x.name.qualified).toList(), ['a:txBody', 'a:tcPr']);
    }
    // Hücreye yaz → kaydet → aç.
    final cell = cells[5];
    final rich = SlideRichText.fromParagraphs(cell.paragraphs)..applyText('Hücre');
    expect(e.writeRichText(s, cell, rich), isTrue);
    final again = PptxEditor.parse(e.save());
    expect(again.slides.first.view!.shapes.any((x) => x.hasText &&
        x.paragraphs.map((p) => p.plainText).join() == 'Hücre'), isTrue);
  });

  test('çizgi biçimi + saydamlık', () {
    final e = _open();
    final s = e.slides.first;
    e.addShape(s, 'rect');
    ShapeVM rect() => s.view!.shapes.lastWhere((x) => x.preset == 'rect' && x.element != null);
    expect(e.setShapeLine(s, rect(), color: const Color(0xFF00FF00), widthPt: 3, dashed: true),
        isTrue);
    expect(rect().stroke, const Color(0xFF00FF00));
    expect(rect().strokeWidth, closeTo(3, 0.01));
    expect(rect().dashed, isTrue);
    expect(e.setShapeLine(s, rect()), isTrue); // düz, 1 pt — kesik kalkar
    expect(rect().dashed, isFalse);
    expect(e.setShapeLine(s, rect(), color: null), isTrue);
    expect(rect().stroke, isNull);
    expect(e.shapeTransparency(rect()), 0);
    expect(e.setShapeTransparency(s, rect(), 0.6), isTrue);
    expect(e.shapeTransparency(rect()), closeTo(0.6, 0.001));
    expect(rect().fill!.a, closeTo(0.4, 0.01));
    final again = PptxEditor.parse(e.save());
    final back = again.slides.first.view!.shapes
        .lastWhere((x) => x.preset == 'rect' && x.element != null);
    expect(again.shapeTransparency(back), closeTo(0.6, 0.001));
    expect(e.setShapeTransparency(s, rect(), 0), isTrue);
    expect(rect().fill!.a, 1);
  });

  test('geçiş çizim modeline girer (sunumda oynar)', () {
    final e = _open();
    final s = e.slides.first;
    expect(s.view!.transition, isNull);
    e.setTransition(s, PptxTransition.wipe);
    expect(s.view!.transition, 'wipe');
    e.setTransition(s, PptxTransition.fade);
    expect(s.view!.transition, 'fade');
    e.setTransition(s, PptxTransition.none);
    expect(s.view!.transition, isNull);
  });

  test('sürükle-bırak sıralama sldIdLst\'e yazılır', () {
    final e = _open();
    while (e.slides.length < 3) {
      e.duplicateSlide(e.slides.first);
    }
    final names = e.slides.map((x) => x.fileName).toList();
    expect(e.moveSlideTo(e.slides.first, 2), isTrue);
    expect(e.moveSlideTo(e.slides[2], 2), isFalse);
    expect(e.slides.map((x) => x.fileName).toList(), [names[1], names[2], names[0], ...names.skip(3)]);
    expect(e.slides.map((x) => x.index).toList(), [for (var i = 1; i <= e.slides.length; i++) i]);
    final again = PptxEditor.parse(e.save());
    expect(again.slides.map((x) => x.fileName).toList(), e.slides.map((x) => x.fileName).toList());
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

  /// Faz 29 kalanı: **Düzeni değiştir** — metin korunur, yer tutucular yeni
  /// düzene eşlenir, ilişki yeni düzene bağlanır (PowerPoint'in varsayılan
  /// şablonuyla üretilmiş örnek: 11 düzen).
  test('düzeni değiştir: metin korunur, ilişki yeni düzene, geri dönüş', () {
    final e = PptxEditor.parse(
        File('test/fixtures/office/sunum_duzenler.pptx').readAsBytesSync());
    final layouts = e.layouts();
    expect(layouts.length, greaterThan(5));
    final slide = e.slides.first;
    final before = e.layoutOf(slide);
    final titleOnly = layouts.firstWhere((l) => l.type == 'titleOnly');
    expect(e.changeLayout(slide, titleOnly), isTrue);
    expect(e.layoutOf(slide), titleOnly.part);
    final again = PptxEditor.parse(e.save());
    final xml = again.slides.first.doc.toXmlString();
    expect(xml, contains('Çeyrek sonuçları'));
    expect(xml, contains('Satışlar arttı'),
        reason: 'yeni düzende gövde yok; dolu yer tutucu silinmez');
    // İki Başlık+İçerik'e geri: başlık başlığa, gövde gövdeye eşlenir.
    final twoContent = layouts.firstWhere((l) => l.type == 'twoObj');
    expect(again.changeLayout(again.slides.first, twoContent), isTrue);
    final phs = again.slides.first.doc
        .findAllElements('p:ph')
        .map((p) => p.getAttribute('type') ?? 'body')
        .toList();
    expect(phs.where((t) => t == 'title'), hasLength(1));
    expect(before, isNot(titleOnly.part));
    // Kaydedilen paket yeniden açılır.
    expect(PptxEditor.parse(again.save()).slides, hasLength(1));
  });

  /// Faz 29 kalanı: grup içindeki şekil taşınır (grup dönüşümü tersine);
  /// tablo bütün olarak taşınır/boyutlandırılır (sütun/satır oranla).
  group('grup içi + tablo çerçevesi', () {
    PptxEditor open() => PptxEditor.parse(
        File('test/fixtures/office/sunum_grup_tablo.pptx').readAsBytesSync());

    test('grup içindeki şekil: slayt koordinatı çocuk koordinatına çevrilir',
        () {
      final e = open();
      final slide = e.slides.first;
      final a = slide.view!.shapes.firstWhere(
          (s) => s.paragraphs.any((p) => p.plainText == 'Grup A'));
      // Grup 2× yatay ölçekli, 100 pt sağa kaydırılmış: çizimde x=200, w=200.
      expect(a.x, closeTo(200, 0.01));
      expect(a.w, closeTo(200, 0.01));
      expect(e.setShapeFrame(slide, a, x: 300, y: 150, w: 200, h: 100), isTrue);
      final moved = e.slides.first.view!.shapes.firstWhere(
          (s) => s.paragraphs.any((p) => p.plainText == 'Grup A'));
      expect(moved.x, closeTo(300, 0.01));
      expect(moved.y, closeTo(150, 0.01));
      expect(moved.w, closeTo(200, 0.01));
      final off = a.element!.findAllElements('a:off').first;
      expect(off.getAttribute('x'), '${150 * 12700}');
    });

    test('tablo çerçevesi: taşı + boyutlandır, sütunlar oranla', () {
      final e = open();
      final slide = e.slides.first;
      final frame = slide.view!.shapes.firstWhere((s) => s.tableFrame);
      expect(frame.w, closeTo(200, 0.01));
      expect(e.setShapeFrame(slide, frame,
          x: 50, y: 250, w: 400, h: frame.h * 2), isTrue);
      final again = PptxEditor.parse(e.save());
      final f2 = again.slides.first.view!.shapes.firstWhere((s) => s.tableFrame);
      expect(f2.x, closeTo(50, 0.01));
      expect(f2.w, closeTo(400, 0.5));
      expect(f2.h, closeTo(frame.h * 2, 0.5));
      final cells = again.slides.first.view!.shapes
          .where((s) => s.cellBorder != null)
          .toList();
      expect(cells.first.w, closeTo(200, 0.5), reason: 'iki sütun, oranla');
      expect(cells.first.paragraphs.first.plainText, 'Başlık');
    });
  });
}
