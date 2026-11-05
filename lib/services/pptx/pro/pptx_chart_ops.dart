import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../xlsx_writer.dart';
import 'pptx_package.dart';

/// Grafik türü (`c:barChart@barDir` col/bar, `c:lineChart`, `c:pieChart`).
enum SlideChartKind { column, bar, line, pie }

/// Grafik verisi: kategoriler × seriler (+ başlık).
class SlideChartData {
  final SlideChartKind kind;
  final String title;
  final List<String> categories;
  final List<(String, List<double>)> series;
  const SlideChartData(this.kind, this.categories, this.series, {this.title = ''});

  static const sample = SlideChartData(
    SlideChartKind.column,
    ['1. Çeyrek', '2. Çeyrek', '3. Çeyrek', '4. Çeyrek'],
    [
      ('Seri 1', [4.3, 2.5, 3.5, 4.5]),
      ('Seri 2', [2.4, 4.4, 1.8, 2.8]),
    ],
  );
}

/// **Faz 38 / madde 3 — slayt içi grafik ekle/düzenle (tablo verisinden) ve
/// SmartArt → düzenlenebilir şekil grubu.** Grafik parçası (`c:chartSpace`)
/// önbellekli değerlerle yazılır, verisi gömülü bir çalışma kitabında da
/// durur (PowerPoint'te "Verileri düzenle" çalışır).
abstract final class PptxChartOps {
  static const _chartCt =
      'application/vnd.openxmlformats-officedocument.drawingml.chart+xml';
  static const _xlsxCt =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const _dgmUri = 'http://schemas.openxmlformats.org/drawingml/2006/diagram';
  static const _chartUri = 'http://schemas.openxmlformats.org/drawingml/2006/chart';

  // ── Sayı ayrıştırma (TR/EN) ───────────────────────────────────────────────

  /// "1.234,5" / "1,234.5" / "%12" / "12 TL" → sayı; değilse null.
  static double? parseNumber(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[%\s₺$€£]|TL'), '');
    if (s.isEmpty) return null;
    final comma = s.lastIndexOf(','), dot = s.lastIndexOf('.');
    if (comma >= 0 && dot >= 0) {
      s = comma > dot
          ? s.replaceAll('.', '').replaceAll(',', '.')
          : s.replaceAll(',', '');
    } else if (comma >= 0) {
      // Tek virgül + ≠3 hane → ondalık; "1,234" → binlik.
      final tail = s.length - comma - 1;
      s = s.split(',').length == 2 && tail != 3
          ? s.replaceAll(',', '.')
          : s.replaceAll(',', '');
    }
    return double.tryParse(s);
  }

  // ── Tablo ────────────────────────────────────────────────────────────────

  static List<List<String>>? tableCells(PptxPackage pkg, int slide, int shapeId) {
    final d = pkg.xml(pkg.slidePart(slide));
    final f = d == null ? null : PptxPackage.shapeById(d, shapeId);
    final tbl = f?.findAllElements('a:tbl').firstOrNull;
    if (tbl == null) return null;
    return [
      for (final tr in tbl.findElements('a:tr'))
        [
          for (final tc in tr.findElements('a:tc'))
            tc.findAllElements('a:t').map((t) => t.innerText).join(),
        ],
    ];
  }

  /// Tablo → grafik verisi: ilk satır seri adları, ilk sütun kategoriler.
  /// İlk satır sayıysa başlık yok sayılır ("Seri n").
  static SlideChartData? fromTable(PptxPackage pkg, int slide, int shapeId) {
    final rows = tableCells(pkg, slide, shapeId);
    if (rows == null || rows.isEmpty || rows.first.length < 2) return null;
    final header = rows.first;
    final headerIsData = header.skip(1).every((c) => parseNumber(c) != null);
    final body = headerIsData ? rows : rows.skip(1).toList();
    if (body.isEmpty) return null;
    final cols = header.length;
    final series = <(String, List<double>)>[];
    for (var c = 1; c < cols; c++) {
      final vals = [
        for (final r in body) c < r.length ? parseNumber(r[c]) ?? 0.0 : 0.0,
      ];
      series.add((headerIsData ? 'Seri $c' : header[c], vals));
    }
    return SlideChartData(
      SlideChartKind.column,
      [for (final r in body) r.isEmpty ? '' : r.first],
      series,
    );
  }

  // ── Grafik parçası ───────────────────────────────────────────────────────

  static String _strCache(List<String> v) => '<c:strCache><c:ptCount val="${v.length}"/>'
      '${[for (var i = 0; i < v.length; i++) '<c:pt idx="$i"><c:v>${PptxPackage.esc(v[i])}</c:v></c:pt>'].join()}'
      '</c:strCache>';

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _numCache(List<double> v) => '<c:numCache><c:formatCode>General</c:formatCode>'
      '<c:ptCount val="${v.length}"/>'
      '${[for (var i = 0; i < v.length; i++) '<c:pt idx="$i"><c:v>${_num(v[i])}</c:v></c:pt>'].join()}'
      '</c:numCache>';

  static String _col(int i) {
    var n = i + 1, s = '';
    while (n > 0) {
      final r = (n - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  static String _ser(SlideChartData d, int i) {
    final (name, vals) = d.series[i];
    final col = _col(i + 1);
    final n = d.categories.length;
    final pie = d.kind == SlideChartKind.pie;
    final fill = pie
        ? ''
        : d.kind == SlideChartKind.line
            ? '<c:spPr><a:ln w="28575"><a:solidFill><a:schemeClr val="accent${i % 6 + 1}"/></a:solidFill></a:ln></c:spPr><c:marker><c:symbol val="none"/></c:marker>'
            : '<c:spPr><a:solidFill><a:schemeClr val="accent${i % 6 + 1}"/></a:solidFill></c:spPr>';
    final dPts = pie
        ? [
            for (var k = 0; k < n; k++)
              '<c:dPt><c:idx val="$k"/><c:bubble3D val="0"/><c:spPr><a:solidFill><a:schemeClr val="accent${k % 6 + 1}"/></a:solidFill></c:spPr></c:dPt>'
          ].join()
        : '';
    return '<c:ser><c:idx val="$i"/><c:order val="$i"/>'
        '<c:tx><c:strRef><c:f>Sheet1!\$$col\$1</c:f>${_strCache([name])}</c:strRef></c:tx>'
        '$fill$dPts'
        '<c:cat><c:strRef><c:f>Sheet1!\$A\$2:\$A\$${n + 1}</c:f>${_strCache(d.categories)}</c:strRef></c:cat>'
        '<c:val><c:numRef><c:f>Sheet1!\$$col\$2:\$$col\$${n + 1}</c:f>${_numCache([
      for (var k = 0; k < n; k++) k < vals.length ? vals[k] : 0.0
    ])}</c:numRef></c:val>'
        '${d.kind == SlideChartKind.line ? '<c:smooth val="0"/>' : ''}'
        '</c:ser>';
  }

  static String chartXml(SlideChartData d, {String? workbookRid}) {
    final sers = [for (var i = 0; i < d.series.length; i++) _ser(d, i)].join();
    const ax = '<c:axId val="50010001"/><c:axId val="50010002"/>';
    final plot = switch (d.kind) {
      SlideChartKind.pie =>
        '<c:pieChart><c:varyColors val="1"/>$sers<c:firstSliceAng val="0"/></c:pieChart>',
      SlideChartKind.line =>
        '<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>$sers<c:marker val="1"/>$ax</c:lineChart>',
      _ =>
        '<c:barChart><c:barDir val="${d.kind == SlideChartKind.bar ? 'bar' : 'col'}"/>'
            '<c:grouping val="clustered"/><c:varyColors val="0"/>$sers<c:gapWidth val="150"/>$ax</c:barChart>',
    };
    final bar = d.kind == SlideChartKind.bar;
    final axes = d.kind == SlideChartKind.pie
        ? ''
        : '<c:catAx><c:axId val="50010001"/><c:scaling><c:orientation val="minMax"/></c:scaling>'
            '<c:delete val="0"/><c:axPos val="${bar ? 'l' : 'b'}"/><c:numFmt formatCode="General" sourceLinked="1"/>'
            '<c:tickLblPos val="nextTo"/><c:crossAx val="50010002"/><c:crosses val="autoZero"/>'
            '<c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/></c:catAx>'
            '<c:valAx><c:axId val="50010002"/><c:scaling><c:orientation val="minMax"/></c:scaling>'
            '<c:delete val="0"/><c:axPos val="${bar ? 'b' : 'l'}"/><c:majorGridlines/>'
            '<c:numFmt formatCode="General" sourceLinked="1"/><c:tickLblPos val="nextTo"/>'
            '<c:crossAx val="50010001"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx>';
    final title = d.title.trim().isEmpty
        ? '<c:autoTitleDeleted val="1"/>'
        : '<c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>${PptxPackage.esc(d.title.trim())}</a:t></a:r></a:p></c:rich></c:tx>'
            '<c:overlay val="0"/></c:title><c:autoTitleDeleted val="0"/>';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<c:chartSpace xmlns:c="${PptxPackage.nsC}" xmlns:a="${PptxPackage.nsA}" xmlns:r="${PptxPackage.nsR}">'
        '<c:roundedCorners val="0"/><c:chart>$title<c:plotArea><c:layout/>$plot$axes</c:plotArea>'
        '<c:legend><c:legendPos val="${d.kind == SlideChartKind.pie ? 'r' : 'b'}"/><c:overlay val="0"/></c:legend>'
        '<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart>'
        '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1400"/></a:pPr><a:endParaRPr lang="tr-TR"/></a:p></c:txPr>'
        '${workbookRid == null ? '' : '<c:externalData r:id="$workbookRid"><c:autoUpdate val="0"/></c:externalData>'}'
        '</c:chartSpace>';
  }

  static Uint8List _workbook(SlideChartData d) {
    final cells = <int, Map<int, XlsxWriteCell>>{
      0: {
        0: const XlsxWriteCell(text: ''),
        for (var i = 0; i < d.series.length; i++)
          i + 1: XlsxWriteCell(text: d.series[i].$1),
      },
      for (var r = 0; r < d.categories.length; r++)
        r + 1: {
          0: XlsxWriteCell(text: d.categories[r]),
          for (var i = 0; i < d.series.length; i++)
            i + 1: XlsxWriteCell(
                number: r < d.series[i].$2.length ? d.series[i].$2[r] : 0),
        },
    };
    return XlsxWriter.build([XlsxWriteSheet(name: 'Sheet1', cells: cells)]);
  }

  /// Grafik parçası + gömülü çalışma kitabı yazar; grafik parça adı.
  static String _writeChart(PptxPackage pkg, SlideChartData d, {String? part}) {
    final chart = part ?? pkg.freeName('ppt/charts/chart', 'xml');
    // Eski gömülü kitap varsa yerinde değişir; yoksa yenisi.
    String? wbRid;
    for (final r in pkg.rels(chart)) {
      if (r.type.endsWith('/package') && !r.external) {
        pkg.putBytes(r.target, _workbook(d));
        wbRid = r.id;
      }
    }
    if (wbRid == null) {
      final wb = pkg.freeName('ppt/embeddings/Microsoft_Excel_Worksheet', 'xlsx');
      pkg.putBytes(wb, _workbook(d));
      pkg.ensureDefault('xlsx', _xlsxCt);
      // İlişki dosyası, grafik yazılmadan da kurulabilir.
      wbRid = pkg.addRel(chart, 'package', wb);
    }
    pkg.putXml(chart, chartXml(d, workbookRid: wbRid));
    pkg.addOverride(chart, _chartCt);
    return chart;
  }

  /// Slayta grafik ekler ([emu]: x, y, cx, cy; null → ortada 2/3).
  static PptxOp insert(int slide, SlideChartData d, {List<int>? emu}) => (pkg) {
        final part = pkg.slidePart(slide);
        final doc = pkg.edit(part)!;
        final tree = PptxPackage.spTree(doc)!;
        final chart = _writeChart(pkg, d);
        final rid = pkg.addRel(part, 'chart', chart);
        final (w, h) = pkg.slideSize();
        final r = emu ?? [w ~/ 6, h ~/ 5, w * 2 ~/ 3, h * 3 ~/ 5];
        final id = PptxPackage.nextShapeId(doc);
        tree.children.add(PptxPackage.frag('<p:graphicFrame><p:nvGraphicFramePr>'
            '<p:cNvPr id="$id" name="Grafik $id"/><p:cNvGraphicFramePr><a:graphicFrameLocks noGrp="1"/></p:cNvGraphicFramePr><p:nvPr/>'
            '</p:nvGraphicFramePr><p:xfrm><a:off x="${r[0]}" y="${r[1]}"/><a:ext cx="${r[2]}" cy="${r[3]}"/></p:xfrm>'
            '<a:graphic><a:graphicData uri="$_chartUri"><c:chart xmlns:c="${PptxPackage.nsC}" r:id="$rid"/></a:graphicData></a:graphic>'
            '</p:graphicFrame>'));
      };

  /// Tablodan grafik: tablonun yanına (altına sığmıyorsa üstüne) ekler.
  static PptxOp insertFromTable(int slide, int tableId, SlideChartKind kind) =>
      (pkg) {
        final d = fromTable(pkg, slide, tableId);
        if (d == null) throw StateError('table');
        insert(slide, SlideChartData(kind, d.categories, d.series))(pkg);
      };

  static String? _chartPartOf(PptxPackage pkg, String slide, int shapeId) {
    final d = pkg.xml(slide);
    final f = d == null ? null : PptxPackage.shapeById(d, shapeId);
    final rid = f?.findAllElements('c:chart').firstOrNull?.getAttribute('r:id');
    return rid == null ? null : pkg.relTarget(slide, rid);
  }

  /// Var olan grafiğin verisi (önbellekten).
  static SlideChartData? read(PptxPackage pkg, int slide, int shapeId) {
    final part = _chartPartOf(pkg, pkg.slidePart(slide), shapeId);
    final d = part == null ? null : pkg.xml(part);
    final plot = d?.findAllElements('c:plotArea').firstOrNull;
    if (plot == null) return null;
    XmlElement? node;
    var kind = SlideChartKind.column;
    for (final e in plot.childElements) {
      switch (e.name.local) {
        case 'barChart' || 'bar3DChart':
          node = e;
          kind = e.getElement('c:barDir')?.getAttribute('val') == 'bar'
              ? SlideChartKind.bar
              : SlideChartKind.column;
        case 'lineChart' || 'line3DChart' || 'areaChart':
          node = e;
          kind = SlideChartKind.line;
        case 'pieChart' || 'pie3DChart' || 'doughnutChart':
          node = e;
          kind = SlideChartKind.pie;
      }
      if (node != null) break;
    }
    if (node == null) return null;
    List<String> pts(XmlElement? cache) {
      if (cache == null) return const [];
      final n = int.tryParse(cache.getElement('c:ptCount')?.getAttribute('val') ?? '') ?? 0;
      final out = List.filled(n, '');
      for (final p in cache.findElements('c:pt')) {
        final i = int.tryParse(p.getAttribute('idx') ?? '') ?? -1;
        if (i >= 0 && i < n) out[i] = p.getElement('c:v')?.innerText ?? '';
      }
      return out;
    }

    var cats = <String>[];
    final series = <(String, List<double>)>[];
    for (final s in node.findElements('c:ser')) {
      final name = s.getElement('c:tx')?.findAllElements('c:v').firstOrNull?.innerText ??
          'Seri ${series.length + 1}';
      final cat = s.getElement('c:cat');
      if (cats.isEmpty && cat != null) {
        cats = pts(cat.findAllElements('c:strCache').firstOrNull ??
            cat.findAllElements('c:numCache').firstOrNull);
      }
      final vals = pts(s.getElement('c:val')?.findAllElements('c:numCache').firstOrNull);
      series.add((name, [for (final v in vals) double.tryParse(v) ?? 0]));
    }
    final title = d!
        .findAllElements('c:title')
        .firstOrNull
        ?.findAllElements('a:t')
        .map((t) => t.innerText)
        .join() ?? '';
    if (cats.isEmpty && series.isNotEmpty) {
      cats = [for (var i = 0; i < series.first.$2.length; i++) '${i + 1}'];
    }
    return SlideChartData(kind, cats, series, title: title);
  }

  /// Grafiğin verisini/türünü yeniler (grafik parçası yeniden yazılır).
  static PptxOp update(int slide, int shapeId, SlideChartData d) => (pkg) {
        final part = _chartPartOf(pkg, pkg.slidePart(slide), shapeId);
        if (part == null) throw StateError('chart');
        _writeChart(pkg, d, part: part);
      };

  // ── SmartArt ─────────────────────────────────────────────────────────────

  /// Slayttaki SmartArt çerçevelerinin şekil kimlikleri.
  static List<int> smartArts(PptxPackage pkg, int slide) {
    final d = pkg.xml(pkg.slidePart(slide));
    if (d == null) return const [];
    return [
      for (final g in d.findAllElements('a:graphicData'))
        if (g.getAttribute('uri') == _dgmUri)
          if (g.parentElement?.parentElement
                  ?.findAllElements('p:cNvPr')
                  .firstOrNull
                  ?.getAttribute('id')
              case final id?)
            int.tryParse(id) ?? 0,
    ];
  }

  /// Slayttaki tabloların şekil kimlikleri.
  static List<int> tables(PptxPackage pkg, int slide) {
    final d = pkg.xml(pkg.slidePart(slide));
    if (d == null) return const [];
    return [
      for (final f in d.findAllElements('p:graphicFrame'))
        if (f.findAllElements('a:tbl').isNotEmpty)
          int.tryParse(f.findAllElements('p:cNvPr').first.getAttribute('id') ?? '') ?? 0,
    ];
  }

  static String? _drawingOf(PptxPackage pkg, String slide, XmlElement frame) {
    final relIds = frame.findAllElements('dgm:relIds').firstOrNull;
    final dm = relIds?.getAttribute('r:dm');
    final data = dm == null ? null : pkg.relTarget(slide, dm);
    final ext = data == null
        ? null
        : pkg.xml(data)?.findAllElements('dsp:dataModelExt').firstOrNull;
    final rid = ext?.getAttribute('relId');
    if (rid != null) {
      final t = pkg.relTarget(slide, rid);
      if (t != null) return t;
    }
    final drawings = [
      for (final r in pkg.rels(slide))
        if (r.type.endsWith('/diagramDrawing')) r.target,
    ];
    return drawings.length == 1 ? drawings.single : null;
  }

  /// SmartArt'ı (çizilmiş hâli `dsp:drawing`) düzenlenebilir şekil grubuna
  /// çevirir. Çizim parçası yoksa (eski dosya) hata.
  static PptxOp smartArtToShapes(int slide, int shapeId) => (pkg) {
        final part = pkg.slidePart(slide);
        final doc = pkg.edit(part)!;
        final frame = PptxPackage.shapeById(doc, shapeId);
        if (frame == null) throw StateError('smartart');
        final drawing = _drawingOf(pkg, part, frame);
        final dd = drawing == null ? null : pkg.xml(drawing);
        final tree = dd?.findAllElements('dsp:spTree').firstOrNull;
        if (tree == null) throw StateError('smartart-drawing');
        final xf = frame.getElement('p:xfrm');
        final off = xf?.getElement('a:off'), ext = xf?.getElement('a:ext');
        final x = off?.getAttribute('x') ?? '0', y = off?.getAttribute('y') ?? '0';
        final cx = ext?.getAttribute('cx') ?? '0', cy = ext?.getAttribute('cy') ?? '0';
        var next = PptxPackage.nextShapeId(doc);
        final name = frame.findAllElements('p:cNvPr').firstOrNull?.getAttribute('name') ?? 'SmartArt';

        String conv(XmlElement e) {
          final buf = StringBuffer();
          for (final c in e.childElements) {
            switch (c.name.local) {
              case 'sp':
                final id = next++;
                final spPr = c.getElement('dsp:spPr');
                final style = c.getElement('dsp:style');
                final tx = c.getElement('dsp:txBody');
                buf.write('<p:sp><p:nvSpPr><p:cNvPr id="$id" name="${PptxPackage.esc(name)} $id"/>'
                    '<p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
                    '<p:spPr>${spPr?.children.map((n) => n.toXmlString()).join() ?? ''}</p:spPr>'
                    '${style == null ? '' : '<p:style>${style.children.map((n) => n.toXmlString()).join()}</p:style>'}'
                    '${tx == null ? '' : '<p:txBody>${tx.children.map((n) => n.toXmlString()).join()}</p:txBody>'}'
                    '</p:sp>');
              case 'grpSp':
                final id = next++;
                final g = c.getElement('dsp:grpSpPr');
                buf.write('<p:grpSp><p:nvGrpSpPr><p:cNvPr id="$id" name="Grup $id"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
                    '<p:grpSpPr>${g?.children.map((n) => n.toXmlString()).join() ?? ''}</p:grpSpPr>'
                    '${conv(c)}</p:grpSp>');
            }
          }
          return buf.toString();
        }

        final gid = next++;
        final body = conv(tree);
        final grp = XmlDocument.parse(
                '<r xmlns:a="${PptxPackage.nsA}" xmlns:r="${PptxPackage.nsR}" xmlns:p="${PptxPackage.nsP}">'
                '<p:grpSp><p:nvGrpSpPr><p:cNvPr id="$gid" name="${PptxPackage.esc(name)}"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
                '<p:grpSpPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/>'
                '<a:chOff x="0" y="0"/><a:chExt cx="$cx" cy="$cy"/></a:xfrm></p:grpSpPr>'
                '$body</p:grpSp></r>')
            .rootElement
            .childElements
            .first
            .copy();
        // Çizimdeki görsel/köprü başvuruları çizimin ilişkilerindedir →
        // slayta taşınır, kimlikler eşlenir.
        for (final e in grp.descendantElements.toList()) {
          for (final a in ['r:embed', 'r:link', 'r:id']) {
            final v = e.getAttribute(a);
            if (v == null) continue;
            final rel = pkg.rels(drawing!).where((r) => r.id == v).firstOrNull;
            if (rel == null) continue;
            e.setAttribute(a, pkg.addRel(part, rel.type, rel.target, external: rel.external));
          }
        }
        final parent = frame.parent!;
        final at = parent.children.indexOf(frame);
        parent.children
          ..removeAt(at)
          ..insert(at, grp);
      };

  /// Destedeki bütün SmartArt'ları dönüştürür (çizimi olmayanlar atlanır).
  static PptxOp allSmartArtsToShapes() => (pkg) {
        final n = pkg.slideParts().length;
        for (var i = 0; i < n; i++) {
          for (final id in smartArts(pkg, i)) {
            try {
              smartArtToShapes(i, id)(pkg);
            } on StateError {
              // Çizimi olmayan (eski biçim) SmartArt olduğu gibi kalır.
            }
          }
        }
      };

  static int countSmartArts(PptxPackage pkg) {
    var c = 0;
    for (var i = 0; i < pkg.slideParts().length; i++) {
      c += smartArts(pkg, i).length;
    }
    return c;
  }
}
