import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pptx/pro/pptx_arrange_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_chart_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_deck_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_master_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_media_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_shape_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_show_info.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_package.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_templates.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 38 — slayt pro işlemleri (paket düzeyi). Her işlem sonrası deste
/// `PptxEditor.parse` ile yeniden açılabilmeli (bozuk paket üretmez).
void main() {
  PptxPro.inIsolate = false;
  final deck = PptxWriter.build([
    const SlideDraft('Satış raporu', ['Bütçe', 'Gelir', 'Çeyrek hedefi']),
    const SlideDraft('İkinci', ['A', 'B']),
  ]);

  PptxPackage open(Uint8List b) => PptxPackage.open(b);

  group('madde 1 — ana slayt / tema', () {
    test('tema renk ve yazı tipi okunur, yazılır', () async {
      final t0 = PptxMasterOps.theme(PptxPackage.open(deck))!;
      expect(t0.colors['dk1'], '000000');
      expect(t0.major, 'Calibri Light');
      var b = await PptxPro.run(
          deck, PptxMasterOps.setThemeColors({'accent1': '#12ab34', 'dk1': 'FFFFFF'}));
      b = await PptxPro.run(b, PptxMasterOps.setThemeFonts('Georgia', 'Arial'));
      final t = PptxMasterOps.theme(open(b))!;
      expect(t.colors['accent1'], '12AB34');
      expect(t.colors['dk1'], 'FFFFFF');
      expect((t.major, t.minor), ('Georgia', 'Arial'));
      expect(PptxEditor.parse(b).slides, hasLength(2));
    });

    test('ana slayt punto + arka plan; stil yoksa kurulur', () async {
      final b = await PptxPro.run(deck, (pkg) {
        PptxMasterOps.setMasterTextStyle(titlePt: 40, bodyPt: 22)(pkg);
        PptxMasterOps.setMasterBackground('112233')(pkg);
      });
      final m = PptxMasterOps.masters(open(b)).single;
      expect(m.titlePt, 40);
      expect(m.bodyPt, 22);
      expect(m.background, '112233');
    });

    test('yer tutucu ekle / taşı / sil, yerleşim kopyala + adlandır', () async {
      final layout = PptxMasterOps.masters(open(deck)).single.layouts.single.part;
      var b = await PptxPro.run(deck, PptxMasterOps.addPlaceholder(layout, 'pic'));
      var ph = PptxMasterOps.placeholders(open(b), layout);
      expect(ph.single.type, 'pic');
      b = await PptxPro.run(
          b, PptxMasterOps.setPlaceholderFrame(layout, ph.single.id, 10, 20, 300, 400));
      ph = PptxMasterOps.placeholders(open(b), layout);
      expect((ph.single.x, ph.single.y, ph.single.cx, ph.single.cy), (10, 20, 300, 400));
      b = await PptxPro.run(b, PptxMasterOps.duplicateLayout(layout, 'Benim'));
      final layouts = PptxMasterOps.masters(open(b)).single.layouts;
      expect(layouts, hasLength(2));
      expect(layouts.last.name, 'Benim');
      expect(layouts.last.placeholders.single.type, 'pic');
      b = await PptxPro.run(b, PptxMasterOps.renameLayout(layouts.last.part, 'Yeni ad'));
      b = await PptxPro.run(b, PptxMasterOps.removePlaceholder(layout, ph.single.id));
      expect(PptxMasterOps.placeholders(open(b), layout), isEmpty);
      expect(PptxMasterOps.masters(open(b)).single.layouts.last.name, 'Yeni ad');
      expect(PptxEditor.parse(b).slides, hasLength(2));
    });
  });

  group('madde 2 — şablonlar', () {
    test('8 şablon, uygulanınca tema değişir', () async {
      expect(PptxTemplates.all, hasLength(8));
      final b = await PptxPro.run(deck, PptxTemplates.apply('night'));
      final t = PptxMasterOps.theme(open(b))!;
      expect(t.colors['lt1'], '111827');
      expect(PptxMasterOps.masters(open(b)).single.background, '111827');
    });

    test('tasarım önerisi içeriğe bakar', () {
      expect(
          PptxTemplates.suggest(const [
            SlideDraft('Satış raporu', ['Bütçe', 'Gelir']),
          ]).first,
          'corporate');
      expect(
          PptxTemplates.suggest(const [
            SlideDraft('Ders: hücre', ['Öğrenci ödevi']),
          ]).first,
          'school');
      expect(PptxTemplates.suggest(const []).length, 8);
    });
  });

  group('madde 3 — grafik / SmartArt', () {
    test('sayı ayrıştırma TR/EN', () {
      expect(PptxChartOps.parseNumber('1.234,5'), 1234.5);
      expect(PptxChartOps.parseNumber('1,234.5'), 1234.5);
      expect(PptxChartOps.parseNumber('%12'), 12);
      expect(PptxChartOps.parseNumber('3,5'), 3.5);
      expect(PptxChartOps.parseNumber('abc'), isNull);
    });

    test('grafik ekle → çizilir, okunur, güncellenir', () async {
      var b = await PptxPro.run(deck, PptxChartOps.insert(0, SlideChartData.sample));
      final e = PptxEditor.parse(b);
      final chart = e.slides.first.view!.shapes.firstWhere((s) => s.chart != null);
      expect(chart.chart!.series, hasLength(2));
      final d = PptxChartOps.read(open(b), 0, chart.id)!;
      expect(d.categories, hasLength(4));
      expect(d.series.first.$2.first, 4.3);
      b = await PptxPro.run(
          b,
          PptxChartOps.update(0, chart.id,
              const SlideChartData(SlideChartKind.pie, ['a', 'b'], [('S', [1, 2])], title: 'Pay')));
      final d2 = PptxChartOps.read(open(b), 0, chart.id)!;
      expect(d2.kind, SlideChartKind.pie);
      expect(d2.title, 'Pay');
      expect(d2.series.single.$2, [1, 2]);
      // Gömülü çalışma kitabı yazıldı (PowerPoint'te "Verileri düzenle").
      expect(open(b).names.where((n) => n.endsWith('.xlsx')), hasLength(1));
    });

    test('tablodan grafik', () async {
      var b = await PptxPro.run(deck, (pkg) {
        final d = pkg.edit(pkg.slidePart(1))!;
        PptxPackage.spTree(d)!.children.add(PptxPackage.frag(
            '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="90" name="T"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
            '<p:xfrm><a:off x="0" y="0"/><a:ext cx="100" cy="100"/></p:xfrm><a:graphic>'
            '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table"><a:tbl><a:tblGrid><a:gridCol w="50"/><a:gridCol w="50"/></a:tblGrid>'
            '${[['Ay', 'Satış'], ['Ocak', '1.200'], ['Şubat', '950,5']].map((r) => '<a:tr h="10">${r.map((c) => '<a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>$c</a:t></a:r></a:p></a:txBody></a:tc>').join()}</a:tr>').join()}'
            '</a:tbl></a:graphicData></a:graphic></p:graphicFrame>'));
      });
      expect(PptxChartOps.tables(open(b), 1), [90]);
      final d = PptxChartOps.fromTable(open(b), 1, 90)!;
      expect(d.categories, ['Ocak', 'Şubat']);
      expect(d.series.single, ('Satış', [1200.0, 950.5]));
      b = await PptxPro.run(b, PptxChartOps.insertFromTable(1, 90, SlideChartKind.line));
      expect(PptxEditor.parse(b).slides[1].view!.shapes.where((s) => s.chart != null), hasLength(1));
    });

    test('SmartArt → şekil grubu', () async {
      var b = await PptxPro.run(deck, (pkg) {
        final slide = pkg.slidePart(0);
        pkg.putXml('ppt/diagrams/drawing1.xml',
            '<dsp:drawing xmlns:dsp="http://schemas.microsoft.com/office/drawing/2008/diagram" xmlns:a="${PptxPackage.nsA}">'
            '<dsp:spTree><dsp:nvGrpSpPr><dsp:cNvPr id="0" name=""/><dsp:cNvGrpSpPr/></dsp:nvGrpSpPr><dsp:grpSpPr/>'
            '${['Bir', 'İki', 'Üç'].indexed.map((e) => '<dsp:sp modelId="{${e.$1}}"><dsp:nvSpPr><dsp:cNvPr id="0" name=""/><dsp:cNvSpPr/></dsp:nvSpPr>'
                '<dsp:spPr><a:xfrm><a:off x="${e.$1 * 100}" y="0"/><a:ext cx="90" cy="50"/></a:xfrm><a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom></dsp:spPr>'
                '<dsp:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>${e.$2}</a:t></a:r></a:p></dsp:txBody></dsp:sp>').join()}'
            '</dsp:spTree></dsp:drawing>');
        final drw = pkg.addRel(slide,
            'http://schemas.microsoft.com/office/2007/relationships/diagramDrawing',
            'ppt/diagrams/drawing1.xml');
        pkg.putXml('ppt/diagrams/data1.xml',
            '<dgm:dataModel xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" '
            'xmlns:dsp="http://schemas.microsoft.com/office/drawing/2008/diagram"><dgm:extLst><a:ext xmlns:a="${PptxPackage.nsA}" uri="x">'
            '<dsp:dataModelExt relId="$drw"/></a:ext></dgm:extLst></dgm:dataModel>');
        final dm = pkg.addRel(slide, 'diagramData', 'ppt/diagrams/data1.xml');
        PptxPackage.spTree(pkg.edit(slide)!)!.children.add(PptxPackage.frag(
            '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="77" name="Diyagram"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
            '<p:xfrm><a:off x="1000" y="2000"/><a:ext cx="400" cy="100"/></p:xfrm><a:graphic>'
            '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/diagram">'
            '<dgm:relIds xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" r:dm="$dm" r:lo="" r:qs="" r:cs=""/>'
            '</a:graphicData></a:graphic></p:graphicFrame>'));
      });
      expect(PptxChartOps.countSmartArts(open(b)), 1);
      b = await PptxPro.run(b, PptxChartOps.allSmartArtsToShapes());
      expect(PptxChartOps.countSmartArts(open(b)), 0);
      final e = PptxEditor.parse(b);
      final texts = e.slides.first.view!.shapes
          .expand((s) => s.paragraphs)
          .map((p) => p.plainText)
          .toList();
      expect(texts, containsAll(['Bir', 'İki', 'Üç']));
    });
  });

  group('madde 4 — medya', () {
    test('video + ses eklenir, sunum bilgisinde görünür', () async {
      final media = Uint8List.fromList(List.filled(64, 7));
      var b = await PptxPro.run(deck, PptxMediaOps.insert(0, media, 'mp4'));
      b = await PptxPro.run(b, PptxMediaOps.insert(1, media, 'mp3'));
      final info = PptxShowInfo.read(open(b));
      expect(info, hasLength(2));
      expect(info[0].media.single.video, isTrue);
      expect(info[1].media.single.video, isFalse);
      expect(open(b).bytes(info[0].media.single.part), media);
      final ct = open(b).xml('[Content_Types].xml')!.toXmlString();
      expect(ct, contains('video/mp4'));
      expect(ct, contains('audio/mpeg'));
      // Kapak görseli çizim modelinde resim olarak görünür.
      expect(PptxEditor.parse(b).slides[1].view!.shapes.where((s) => s.image != null),
          isNotEmpty);
    });
  });

  group('madde 6 — katman / hizala / animasyon', () {
    Future<Uint8List> threeBoxes() => PptxPro.run(deck, (pkg) {
          final d = pkg.edit(pkg.slidePart(1))!;
          final tree = PptxPackage.spTree(d)!;
          for (final (id, x) in [(51, 100), (52, 900), (53, 5000)]) {
            tree.children.add(PptxPackage.frag('<p:sp><p:nvSpPr><p:cNvPr id="$id" name="K$id"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
                '<p:spPr><a:xfrm><a:off x="$x" y="${x * 2}"/><a:ext cx="100" cy="100"/></a:xfrm>'
                '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:sp>'));
          }
        });

    test('hizala, dağıt, z sırası, gizle', () async {
      var b = await threeBoxes();
      b = await PptxPro.run(b, PptxArrangeOps.align(1, [51, 52, 53], SlideAlign.top));
      var l = {for (final x in PptxArrangeOps.layers(open(b), 1)) x.id: x};
      expect([l[51]!.frame![1], l[52]!.frame![1], l[53]!.frame![1]], [200, 200, 200]);
      b = await PptxPro.run(b, PptxArrangeOps.distribute(1, [53, 51, 52], horizontal: true));
      l = {for (final x in PptxArrangeOps.layers(open(b), 1)) x.id: x};
      // 100..5100 arası, toplam genişlik 300 → aralık 2350; ortadaki 2550'de.
      expect(l[52]!.frame![0], 2550);
      b = await PptxPro.run(b, PptxArrangeOps.moveLayer(1, 53, 0));
      expect(PptxArrangeOps.layers(open(b), 1).first.id, 53);
      b = await PptxPro.run(b, PptxArrangeOps.setHidden(1, 52, true));
      expect(PptxArrangeOps.layers(open(b), 1).firstWhere((x) => x.id == 52).hidden, isTrue);
      // Gizli şekil çizilmez.
      expect(PptxEditor.parse(b).slides[1].view!.shapes.where((s) => s.id == 52), isEmpty);
    });

    test('animasyon ekle / sırala / sil — çizim modeline yansır', () async {
      var b = await threeBoxes();
      b = await PptxPro.run(b, PptxArrangeOps.addEntrance(1, 51, SlideEntrance.fade));
      b = await PptxPro.run(b, PptxArrangeOps.addEntrance(1, 52, SlideEntrance.zoom));
      var a = PptxArrangeOps.animations(open(b), 1);
      expect([for (final s in a) s.shapeIds.single], [51, 52]);
      expect(a.first.presetId, 10);
      expect(PptxEditor.parse(b).slides[1].view!.steps, hasLength(2));
      b = await PptxPro.run(b, PptxArrangeOps.moveAnimation(1, 1, 0));
      a = PptxArrangeOps.animations(open(b), 1);
      expect([for (final s in a) s.shapeIds.single], [52, 51]);
      final ids = open(b).xml(open(b).slidePart(1))!.findAllElements('p:cTn')
          .map((c) => c.getAttribute('id')).toList();
      expect(ids.toSet().length, ids.length); // kimlikler benzersiz
      b = await PptxPro.run(b, PptxArrangeOps.removeAnimation(1, 0));
      expect(PptxArrangeOps.animations(open(b), 1).single.shapeIds, [51]);
    });
  });

  group('madde 7 — bölüm / özel gösteri', () {
    final four = PptxWriter.build([
      for (var i = 1; i <= 4; i++) SlideDraft('S$i', const []),
    ]);

    test('bölüm ekle, adlandır, taşı, sil; slayt silinince uyar', () async {
      var b = await PptxPro.run(four, PptxDeckOps.addSection(0, 'Giriş'));
      b = await PptxPro.run(b, PptxDeckOps.addSection(2, 'Sonuç'));
      var s = PptxDeckOps.sections(open(b));
      expect([for (final x in s) (x.name, x.start, x.count)], [('Giriş', 0, 2), ('Sonuç', 2, 2)]);
      b = await PptxPro.run(b, PptxDeckOps.addSection(3, 'Ek'));
      s = PptxDeckOps.sections(open(b));
      expect([for (final x in s) x.count], [2, 1, 1]);
      b = await PptxPro.run(b, PptxDeckOps.renameSection(1, 'Bulgular'));
      b = await PptxPro.run(b, PptxDeckOps.moveSection(2, -2)); // Ek en başa
      s = PptxDeckOps.sections(open(b));
      expect([for (final x in s) x.name], ['Ek', 'Giriş', 'Bulgular']);
      // Slayt sırası da değişti: S4 en başta.
      final e = PptxEditor.parse(b);
      expect(e.slides.first.paragraphs.first.text, 'S4');
      b = await PptxPro.run(b, PptxDeckOps.removeSection(0));
      expect(PptxDeckOps.sections(open(b)).first.count, 3);
      // Editörde slayt silinir → kaydederken bölüm üyeliği uyar.
      final e2 = PptxEditor.parse(b);
      e2.deleteSlide(e2.slides.last);
      final total = PptxDeckOps.sections(open(e2.save()))
          .fold<int>(0, (a, x) => a + x.count);
      expect(total, 3);
    });

    test('özel gösteri yaz / oku / sil', () async {
      var b = await PptxPro.run(four, PptxDeckOps.setCustomShow('Kısa', [3, 0]));
      expect(PptxDeckOps.customShows(open(b)).single.slides, [3, 0]);
      b = await PptxPro.run(b, PptxDeckOps.setCustomShow('Kısa', [1]));
      expect(PptxDeckOps.customShows(open(b)).single.slides, [1]);
      b = await PptxPro.run(b, PptxDeckOps.removeCustomShow('Kısa'));
      expect(PptxDeckOps.customShows(open(b)), isEmpty);
      expect(PptxEditor.parse(b).slides, hasLength(4));
    });
  });

  group('madde 8 — şekil araçları', () {
    Future<Uint8List> boxes() => PptxPro.run(deck, (pkg) {
          final d = pkg.edit(pkg.slidePart(1))!;
          final tree = PptxPackage.spTree(d)!;
          for (final (id, x) in [(61, 100000), (62, 3000000)]) {
            tree.children.add(PptxPackage.frag('<p:sp><p:nvSpPr><p:cNvPr id="$id" name="K$id"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
                '<p:spPr><a:xfrm><a:off x="$x" y="100000"/><a:ext cx="500000" cy="500000"/></a:xfrm>'
                '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></p:spPr></p:sp>'));
          }
        });

    test('bağlayıcı, gradyan, gölge, yansıma; deste açılır', () async {
      var b = await boxes();
      b = await PptxPro.run(b, PptxShapeOps.connect(1, 61, 62));
      b = await PptxPro.run(b, PptxShapeOps.setGradient(1, 61, '112233', 'AABBCC'));
      b = await PptxPro.run(b, PptxShapeOps.setShadow(1, 61, true));
      b = await PptxPro.run(b, PptxShapeOps.setReflection(1, 61, true));
      final x = open(b).xml(open(b).slidePart(1))!.toXmlString();
      expect(x, contains('<a:stCxn id="61" idx="3"/>'));
      expect(x, contains('<a:endCxn id="62" idx="1"/>'));
      expect(x, contains('a:gradFill'));
      expect(RegExp('outerShdw.*reflection').hasMatch(x), isTrue); // ECMA sırası
      final v = PptxEditor.parse(b).slides[1].view!;
      expect(v.shapes.firstWhere((s) => s.id == 61).gradient, isNotNull);
      expect(v.shapes.where((s) => s.isLine), isNotEmpty);
    });

    test('köprü/eylem + sayaç sunum bilgisinde', () async {
      var b = await boxes();
      b = await PptxPro.run(b, PptxShapeOps.setLink(1, 61, SlideLinkKind.url, url: 'https://ornek.com'));
      b = await PptxPro.run(b, PptxShapeOps.setLink(1, 62, SlideLinkKind.slide, target: 0));
      b = await PptxPro.run(b, PptxShapeOps.addActionButton(1, 'actionButtonForwardNext'));
      b = await PptxPro.run(b, PptxShapeOps.addCounter(1, 90));
      final info = PptxShowInfo.read(open(b))[1];
      expect(info.links.map((l) => l.kind),
          containsAll([SlideLinkKind.url, SlideLinkKind.slide, SlideLinkKind.next]));
      expect(info.links.firstWhere((l) => l.kind == SlideLinkKind.url).url, 'https://ornek.com');
      expect(info.links.firstWhere((l) => l.kind == SlideLinkKind.slide).slide, 0);
      expect(info.counters.single.seconds, 90);
      b = await PptxPro.run(b, PptxShapeOps.setLink(1, 61, SlideLinkKind.none));
      expect(PptxShowInfo.read(open(b))[1].links.where((l) => l.kind == SlideLinkKind.url), isEmpty);
    });

    test('görsel kırp, şekle kırp, değiştir', () async {
      final png = PptxMediaOps.audioPoster();
      var b = await PptxPro.run(deck, PptxMediaOps.insert(0, Uint8List(8), 'mp3', poster: png));
      final id = PptxMediaOps.mediaOf(open(b), open(b).slidePart(0)).single.shapeId;
      b = await PptxPro.run(b, PptxShapeOps.setCrop(0, id, 0.1, 0, 0.2, 0));
      b = await PptxPro.run(b, PptxShapeOps.cropToShape(0, id, 'ellipse'));
      final pic = PptxEditor.parse(b).slides[0].view!.shapes.firstWhere((s) => s.id == id);
      expect(pic.crop!.left, closeTo(0.1, 1e-6));
      expect(open(b).xml(open(b).slidePart(0))!.toXmlString(), contains('prst="ellipse"'));
      expect(PptxShapeOps.imageOf(open(b), 0, id)!.$2, 'png');
      b = await PptxPro.run(b, PptxShapeOps.replaceImage(0, id, png));
      expect(PptxShapeOps.imageOf(open(b), 0, id)!.$1, png);
    });

    test('tablo biçimi hücrelere yazılır', () async {
      var b = await PptxPro.run(deck, (pkg) {
        final d = pkg.edit(pkg.slidePart(1))!;
        PptxPackage.spTree(d)!.children.add(PptxPackage.frag(
            '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="95" name="T"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
            '<p:xfrm><a:off x="0" y="0"/><a:ext cx="100" cy="100"/></p:xfrm><a:graphic>'
            '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table"><a:tbl><a:tblGrid><a:gridCol w="50"/></a:tblGrid>'
            '<a:tr h="10"><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:rPr/><a:t>Başlık</a:t></a:r></a:p></a:txBody></a:tc></a:tr>'
            '<a:tr h="10"><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:rPr/><a:t>1</a:t></a:r></a:p></a:txBody></a:tc></a:tr>'
            '</a:tbl></a:graphicData></a:graphic></p:graphicFrame>'));
      });
      b = await PptxPro.run(b, PptxShapeOps.applyTableStyle(1, 95, 'green'));
      final x = open(b).xml(open(b).slidePart(1))!.toXmlString();
      expect(x, contains('2E7D32'));
      expect(x, contains('firstRow="1"'));
      expect(PptxEditor.parse(b).slides, hasLength(2));
    });
  });

  group('madde 9 — anlatım', () {
    test('anlatım gömülür: kendiliğinden çalar, süre advTm, tıklama adımı değil', () async {
      final audio = Uint8List.fromList(List.filled(32, 3));
      var b = await PptxPro.run(deck, PptxMediaOps.setNarration(0, audio, 4200));
      var info = PptxShowInfo.read(open(b))[0];
      expect(info.advanceMs, 4200);
      expect(info.media.single.autoplay, isTrue);
      expect(info.media.single.video, isFalse);
      expect(PptxEditor.parse(b).slides[0].view!.steps, isEmpty);
      // Yeniden kayıt öncekini değiştirir (iki ses olmaz).
      b = await PptxPro.run(b, PptxMediaOps.setNarration(0, audio, 3000));
      info = PptxShowInfo.read(open(b))[0];
      expect(info.media, hasLength(1));
      expect(info.advanceMs, 3000);
      final x = open(b).xml(open(b).slidePart(0))!.toXmlString();
      expect('<p:audio>'.allMatches(x), hasLength(1));
      expect(x, contains('playFrom(0.0)'));
    });
  });
}
