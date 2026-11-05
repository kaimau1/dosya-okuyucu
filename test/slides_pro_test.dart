import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pptx/pro/pptx_chart_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_master_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_package.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_templates.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
