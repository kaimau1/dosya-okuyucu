import 'dart:convert';
import 'dart:ui' show PictureRecorder, Canvas, Size;

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/chartex_reader.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:dosya_okuyucu/widgets/chart_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// B10 m.1 — chartex (şelale / histogram / Pareto / kutu) okuma + çizim.
String _doc(String layout, String data, {String layoutPr = '', String extra = ''}) => '''
<cx:chartSpace xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:cx="http://schemas.microsoft.com/office/drawing/2014/chartex">
<cx:chartData><cx:data id="0">$data</cx:data></cx:chartData>
<cx:chart><cx:title><cx:tx><cx:txData><cx:v>Başlık</cx:v></cx:txData></cx:tx></cx:title>
<cx:plotArea><cx:plotAreaRegion>
<cx:series layoutId="$layout" uniqueId="{1}"><cx:tx><cx:txData><cx:f/><cx:v>Seri A</cx:v></cx:txData></cx:tx><cx:dataId val="0"/><cx:layoutPr>$layoutPr</cx:layoutPr></cx:series>
$extra
</cx:plotAreaRegion></cx:plotArea></cx:chart></cx:chartSpace>''';

String _num(List<String> v) =>
    '<cx:numDim type="val"><cx:lvl ptCount="${v.length}">'
    '${[for (var i = 0; i < v.length; i++) if (v[i].isNotEmpty) '<cx:pt idx="$i">${v[i]}</cx:pt>'].join()}'
    '</cx:lvl></cx:numDim>';

String _str(List<String> v) =>
    '<cx:strDim type="cat"><cx:lvl ptCount="${v.length}">'
    '${[for (var i = 0; i < v.length; i++) '<cx:pt idx="$i">${v[i]}</cx:pt>'].join()}'
    '</cx:lvl></cx:strDim>';

ChartVM? _parse(String xml) {
  final bytes = utf8.encode(xml);
  final a = Archive()..addFile(ArchiveFile('c.xml', bytes.length, bytes));
  return PptxRender(a).chartPart('c.xml');
}

void _paint(ChartVM vm) {
  final r = PictureRecorder();
  ChartPainter(vm).paint(Canvas(r), const Size(320, 200));
  r.endRecording();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('şelale: yüzen çubuk + ara toplam', () {
    final vm = _parse(_doc('waterfall',
        _str(['Açılış', 'Satış', 'Gider', 'Kapanış']) + _num(['100', '50', '-30', '120']),
        layoutPr: '<cx:subtotals><cx:idx val="0"/><cx:idx val="3"/></cx:subtotals>'))!;
    expect(vm.type, ChartType.column);
    expect(vm.grouping, ChartGrouping.stacked);
    expect(vm.categories, ['Açılış', 'Satış', 'Gider', 'Kapanış']);
    expect(vm.series[0].values, [0, 100, 120, 0]); // görünmez taban
    expect(vm.series[1].values, [100, 50, 30, 120]);
    expect(vm.series[0].color.a, 0);
    expect(vm.series[1].pointColors[2], isNot(vm.series[1].pointColors[1]));
    expect(vm.approx, isFalse);
    _paint(vm);
  });

  test('histogram: kutu sayısı ve otomatik genişlik', () {
    final vm = _parse(_doc('clusteredColumn', _num(['1', '2', '2', '3', '9', '10', '']),
        layoutPr: '<cx:binning intervalClosed="r"><cx:binCount val="3"/></cx:binning>'))!;
    expect(vm.series.single.values, [4, 0, 2]); // boş nokta sayılmaz
    expect(vm.categories.first, '[1, 4]');
    expect(vm.categories[1], '(4, 7]');
    final auto = _parse(_doc('clusteredColumn', _num(['1', '2', '3', '4', '5', '6', '7', '8'])))!;
    expect(auto.series.single.values.fold<double>(0, (a, b) => a + b), 8);
    _paint(auto);
  });

  test('Pareto: büyükten küçüğe + birikimli yüzde', () {
    final vm = _parse(_doc('clusteredColumn', _str(['a', 'b', 'c']) + _num(['1', '3', '1']),
        extra: '<cx:series layoutId="paretoLine" ownerIdx="0"><cx:axisId val="2"/></cx:series>'))!;
    expect(vm.categories, ['b', 'a', 'c']);
    expect(vm.series[0].values, [3, 1, 1]);
    expect(vm.series[1].secondary, isTrue);
    expect(vm.series[1].values.last, 100);
    _paint(vm);
  });

  test('kutu-bıyık: QUARTILE.EXC', () {
    expect(ChartExReader.quartiles([1, 2, 3, 4, 5, 6, 7]), (2.0, 4.0, 6.0));
    expect(ChartExReader.quartiles([1, 2, 3, 4], exclusive: false), (1.75, 2.5, 3.25));
    final vm = _parse(_doc('boxWhisker', _num(['1', '2', '3', '4', '5', '6', '7'])))!;
    expect(vm.categories, ['Seri A']);
    expect(vm.series.map((s) => s.values.single), [2, 2, 2]);
    expect(vm.approx, isTrue);
    _paint(vm);
  });

  test('bilinmeyen chartex türü yaklaşık çizilir, başlık okunur', () {
    final xml = _doc('regionMap', _str(['TR']) + _num(['5']));
    final vm = _parse(xml)!;
    expect(vm.approx, isTrue);
    expect(ChartExReader.title(XmlDocument.parse(xml)), 'Başlık');
  });
}
