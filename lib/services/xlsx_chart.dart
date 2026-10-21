import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Eklenebilen grafik türleri (PPTX çizicisinin desteklediklerinin aynısı —
/// önizleme `ChartPainter` ile çizilir).
enum XlsxChartKind { column, bar, line, pie }

/// Eklenecek bir grafik: hangi sayfaya, hangi veriden, nereye.
///
/// Veri **eklendiği andaki** hücrelerden alınır ve dosyaya iki biçimde yazılır:
/// formül başvurusu (`'Sayfa1'!$B$2:$B$5` — Excel değerleri buradan yeniden
/// okur, hücre değişince grafik güncellenir) ve önbellek (`numCache` — Excel
/// açmadan önce, Google E-Tablolar ve önizleyiciler bunu çizer).
class XlsxChartSpec {
  final String sheetName;
  final XlsxChartKind kind;
  final String title;

  /// Veri aralığı (0 tabanlı, uçlar dahil). İlk satır seri adları, ilk sütun
  /// kategoriler ([hasCategoryColumn] ise).
  final int top, left, bottom, right;
  final bool hasCategoryColumn;
  final List<String> categories;
  final List<XlsxChartSeries> series;

  /// Grafiğin sol-üst köşesinin hücresi (0 tabanlı).
  final int anchorRow, anchorCol;

  const XlsxChartSpec({
    required this.sheetName,
    required this.kind,
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
    required this.hasCategoryColumn,
    required this.categories,
    required this.series,
    required this.anchorRow,
    required this.anchorCol,
    this.title = '',
  });

  /// Seçili aralıktan grafik kurar: ilk satır başlık, ilk sütun sayı DEĞİLSE
  /// kategori sütunu. Sayısal hiçbir değer yoksa null (çizilecek bir şey yok).
  ///
  /// [display] hücrenin görünen değeri (formülün sonucu) — grafik formülü
  /// değil sonucunu çizer.
  static XlsxChartSpec? fromRange({
    required String sheetName,
    required XlsxChartKind kind,
    required int top,
    required int left,
    required int bottom,
    required int right,
    required String Function(int row, int col) display,
    String title = '',
  }) {
    if (bottom <= top) return null;
    double? num(String v) =>
        double.tryParse(v.trim().replaceAll(' ', '').replaceAll(',', '.'));
    // İlk sütun kategori mi? Veri satırlarında sayı olmayan bir değer varsa.
    var catCol = false;
    for (var r = top + 1; r <= bottom; r++) {
      final v = display(r, left);
      if (v.trim().isNotEmpty && num(v) == null) {
        catCol = true;
        break;
      }
    }
    if (catCol && right == left) return null;
    final firstData = catCol ? left + 1 : left;
    final categories = [
      for (var r = top + 1; r <= bottom; r++)
        catCol ? display(r, left) : '${r - top}',
    ];
    final series = <XlsxChartSeries>[];
    for (var c = firstData; c <= right; c++) {
      final values = <double?>[
        for (var r = top + 1; r <= bottom; r++) num(display(r, c)),
      ];
      if (values.every((v) => v == null)) continue;
      final name = display(top, c).trim();
      series.add(XlsxChartSeries(name.isEmpty ? 'Seri ${c - firstData + 1}' : name,
          c, values));
    }
    if (series.isEmpty) return null;
    return XlsxChartSpec(
      sheetName: sheetName,
      kind: kind,
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      hasCategoryColumn: catCol,
      categories: categories,
      // Pastada tek seri anlamlıdır (Excel de yalnız ilkini çizer).
      series: kind == XlsxChartKind.pie ? [series.first] : series,
      anchorRow: top,
      anchorCol: right + 2,
      title: title,
    );
  }
}

class XlsxChartSeries {
  final String name;

  /// Serinin sayfadaki sütunu (0 tabanlı).
  final int col;

  /// Değerler (sayı olmayan hücre = null → grafikte boşluk).
  final List<double?> values;
  const XlsxChartSeries(this.name, this.col, this.values);
}

/// Kaydedilmiş `.xlsx` paketine **grafik** ekler (Faz 9 / Y2 — "Excel'de
/// grafik ekleme yok").
///
/// Eklenen parçalar Excel'in kendi ürettiği yapının aynısıdır:
/// `xl/charts/chartN.xml` (DrawingML grafiği) ← `xl/drawings/drawingN.xml`
/// (hücreye bağlı çerçeve, `twoCellAnchor`) ← sayfanın `<drawing r:id>`'si.
/// Sayfada zaten bir çizim varsa (resim/başka grafik) YENİ çizim açılmaz:
/// çerçeve var olan çizime eklenir — bir sayfanın tek `<drawing>`i olabilir.
/// Paketin geri kalanına dokunulmaz.
abstract final class XlsxChartWriter {
  static const _nsRel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _nsPkgRel =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const _relDrawing = '$_nsRel/drawing';
  static const _relChart = '$_nsRel/chart';
  static const _ctDrawing =
      'application/vnd.openxmlformats-officedocument.drawing+xml';
  static const _ctChart =
      'application/vnd.openxmlformats-officedocument.drawingml.chart+xml';

  /// `<drawing>`'den SONRA gelebilecek sayfa öğeleri (ECMA-376 sırası).
  static const _afterDrawing = [
    'legacyDrawing', 'legacyDrawingHF', 'drawingHF', 'picture', 'oleObjects',
    'controls', 'webPublishItems', 'tableParts', 'extLst',
  ];

  static Uint8List apply(Uint8List xlsx, List<XlsxChartSpec> charts) {
    if (charts.isEmpty) return xlsx;
    final files = <String, List<int>>{};
    final order = <String>[];
    for (final f in ZipDecoder().decodeBytes(xlsx).files) {
      if (!f.isFile) continue;
      files[f.name] = f.content as List<int>;
      order.add(f.name);
    }
    String? text(String name) {
      final d = files[name];
      return d == null ? null : utf8.decode(d, allowMalformed: true);
    }

    void put(String name, String value) {
      if (!files.containsKey(name)) order.add(name);
      files[name] = utf8.encode(value);
    }

    final ct = XmlDocument.parse(text('[Content_Types].xml')!);
    var chartSeq = _maxIndex(files.keys, RegExp(r'^xl/charts/chart(\d+)\.xml$'));
    var drawingSeq =
        _maxIndex(files.keys, RegExp(r'^xl/drawings/drawing(\d+)\.xml$'));

    for (final spec in charts) {
      final sheetPart = _sheetPart(text, spec.sheetName);
      if (sheetPart == null) continue;
      final sheetRelsPath = _relsPathOf(sheetPart);
      final sheetRels = _relsDoc(text(sheetRelsPath));
      var sheetXml = text(sheetPart)!;

      // Sayfanın var olan çizimi.
      String? drawingPart;
      final drawingRid = RegExp(r'<(?:\w+:)?drawing\b[^>]*\br:id="([^"]+)"')
          .firstMatch(sheetXml)
          ?.group(1);
      if (drawingRid != null) {
        final target = _targetOf(sheetRels, drawingRid);
        if (target != null) drawingPart = _resolve(sheetPart, target);
      }
      if (drawingPart == null || !files.containsKey(drawingPart)) {
        drawingSeq++;
        drawingPart = 'xl/drawings/drawing$drawingSeq.xml';
        put(drawingPart, _emptyDrawing);
        _addOverride(ct, '/$drawingPart', _ctDrawing);
        final rid = _addRel(sheetRels, _relDrawing,
            '../drawings/drawing$drawingSeq.xml');
        sheetXml = _insertDrawing(sheetXml, rid);
        put(sheetPart, sheetXml);
        put(sheetRelsPath, sheetRels.toXmlString());
      }

      chartSeq++;
      final chartPart = 'xl/charts/chart$chartSeq.xml';
      put(chartPart, chartXml(spec));
      _addOverride(ct, '/$chartPart', _ctChart);

      final drawingRelsPath = _relsPathOf(drawingPart);
      final drawingRels = _relsDoc(text(drawingRelsPath));
      final chartRid =
          _addRel(drawingRels, _relChart, '../charts/chart$chartSeq.xml');
      put(drawingRelsPath, drawingRels.toXmlString());
      put(drawingPart, _appendAnchor(text(drawingPart)!, spec, chartRid));
    }

    put('[Content_Types].xml', ct.toXmlString());
    final out = Archive();
    for (final name in order) {
      final data = files[name];
      if (data == null) continue;
      out.addFile(ArchiveFile(name, data.length, data));
    }
    return Uint8List.fromList(ZipEncoder().encode(out)!);
  }

  // ── paket gezintisi ─────────────────────────────────────────────────────

  static int _maxIndex(Iterable<String> names, RegExp re) {
    var max = 0;
    for (final n in names) {
      final m = re.firstMatch(n);
      if (m != null) {
        final v = int.parse(m[1]!);
        if (v > max) max = v;
      }
    }
    return max;
  }

  /// Sayfa adından parça yolu (`xl/worksheets/sheetN.xml`).
  static String? _sheetPart(String? Function(String) text, String name) {
    final wb = XmlDocument.parse(text('xl/workbook.xml')!);
    final rels = _relsDoc(text('xl/_rels/workbook.xml.rels'));
    for (final el in wb.findAllElements('sheet', namespace: '*')) {
      if (el.getAttribute('name') != name) continue;
      String? rid;
      for (final a in el.attributes) {
        if (a.name.local == 'id' && a.name.prefix != null) rid = a.value;
      }
      final target = rid == null ? null : _targetOf(rels, rid);
      if (target == null) return null;
      return _resolve('xl/workbook.xml', target);
    }
    return null;
  }

  static String _relsPathOf(String part) =>
      '${p.posix.dirname(part)}/_rels/${p.posix.basename(part)}.rels';

  static XmlDocument _relsDoc(String? xml) => XmlDocument.parse(xml ??
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<Relationships xmlns="$_nsPkgRel"/>');

  static String? _targetOf(XmlDocument rels, String id) {
    for (final r in rels.rootElement.childElements) {
      if (r.getAttribute('Id') == id) return r.getAttribute('Target');
    }
    return null;
  }

  /// İlişki hedefini [from] parçasına göre paket yoluna çevirir.
  static String _resolve(String from, String target) {
    if (target.startsWith('/')) return target.substring(1);
    return p.posix.normalize(p.posix.join(p.posix.dirname(from), target));
  }

  static String _addRel(XmlDocument rels, String type, String target) {
    final used = {
      for (final r in rels.rootElement.childElements) r.getAttribute('Id'),
    };
    var n = rels.rootElement.childElements.length + 1;
    while (used.contains('rId$n')) {
      n++;
    }
    rels.rootElement.children.add(XmlElement(XmlName('Relationship'), [
      XmlAttribute(XmlName('Id'), 'rId$n'),
      XmlAttribute(XmlName('Type'), type),
      XmlAttribute(XmlName('Target'), target),
    ]));
    return 'rId$n';
  }

  static void _addOverride(XmlDocument ct, String part, String type) {
    final exists = ct.rootElement.childElements
        .any((e) => e.getAttribute('PartName') == part);
    if (exists) return;
    ct.rootElement.children.add(XmlElement(XmlName('Override'), [
      XmlAttribute(XmlName('PartName'), part),
      XmlAttribute(XmlName('ContentType'), type),
    ]));
  }

  /// Sayfa XML'ine `<drawing r:id>` ekler (doğru sırada; kök `r` ad alanını
  /// tanımlamıyorsa tanımlar).
  static String _insertDrawing(String xml, String rid) {
    final root = RegExp(r'<((?:\w+:)?)worksheet\b[^>]*>').firstMatch(xml);
    final prefix = root?.group(1) ?? '';
    var out = xml;
    if (root != null && !root.group(0)!.contains('xmlns:r=')) {
      final tag = root.group(0)!;
      out = out.replaceFirst(
          tag, '${tag.substring(0, tag.length - 1)} xmlns:r="$_nsRel">');
    }
    final fragment = '<${prefix}drawing r:id="$rid"/>';
    var at = -1;
    for (final n in _afterDrawing) {
      final i = out.indexOf(RegExp('<${RegExp.escape(prefix)}$n\\b'));
      if (i >= 0 && (at < 0 || i < at)) at = i;
    }
    if (at < 0) at = out.lastIndexOf('</${prefix}worksheet>');
    return out.replaceRange(at, at, fragment);
  }

  static const _emptyDrawing =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"></xdr:wsDr>';

  /// Çizime grafiğin çerçevesini (8 sütun × 15 satır) ekler.
  static String _appendAnchor(String drawing, XlsxChartSpec spec, String rid) {
    final root = RegExp(r'<((?:\w+:)?)wsDr\b').firstMatch(drawing);
    final x = root?.group(1) ?? 'xdr:';
    var maxId = 1;
    for (final m in RegExp(r'<(?:\w+:)?cNvPr\b[^>]*\bid="(\d+)"').allMatches(drawing)) {
      final v = int.parse(m[1]!);
      if (v > maxId) maxId = v;
    }
    final id = maxId + 1;
    final name = _esc(spec.title.isEmpty ? 'Grafik ${id - 1}' : spec.title);
    final anchor = '<${x}twoCellAnchor>'
        '<${x}from><${x}col>${spec.anchorCol}</${x}col><${x}colOff>0</${x}colOff>'
        '<${x}row>${spec.anchorRow}</${x}row><${x}rowOff>0</${x}rowOff></${x}from>'
        '<${x}to><${x}col>${spec.anchorCol + 8}</${x}col><${x}colOff>0</${x}colOff>'
        '<${x}row>${spec.anchorRow + 15}</${x}row><${x}rowOff>0</${x}rowOff></${x}to>'
        '<${x}graphicFrame macro="">'
        '<${x}nvGraphicFramePr><${x}cNvPr id="$id" name="$name"/>'
        '<${x}cNvGraphicFramePr/></${x}nvGraphicFramePr>'
        '<${x}xfrm><a:off x="0" y="0" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"/>'
        '<a:ext cx="0" cy="0" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"/></${x}xfrm>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">'
        '<c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" '
        'xmlns:r="$_nsRel" r:id="$rid"/>'
        '</a:graphicData></a:graphic></${x}graphicFrame>'
        '<${x}clientData/></${x}twoCellAnchor>';
    final close = drawing.lastIndexOf('</${x}wsDr>');
    return drawing.replaceRange(close, close, anchor);
  }

  // ── grafik XML'i ────────────────────────────────────────────────────────

  /// `'Sayfa 1'!$B$2:$B$5` biçiminde mutlak başvuru.
  static String ref(String sheet, int r1, int c1, [int? r2, int? c2]) {
    final q = "'${sheet.replaceAll("'", "''")}'";
    final a = '\$${_col(c1)}\$${r1 + 1}';
    if (r2 == null || c2 == null || (r2 == r1 && c2 == c1)) return '$q!$a';
    return '$q!$a:\$${_col(c2)}\$${r2 + 1}';
  }

  static String _col(int c) {
    var n = c + 1;
    final b = StringBuffer();
    while (n > 0) {
      final m = (n - 1) % 26;
      b.write(String.fromCharCode(65 + m));
      n = (n - 1) ~/ 26;
    }
    return b.toString().split('').reversed.join();
  }

  static String chartXml(XlsxChartSpec s) {
    final b = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="$_nsRel">'
        '<c:roundedCorners val="0"/><c:chart>');
    if (s.title.isNotEmpty) {
      b.write('<c:title><c:tx><c:rich><a:bodyPr/><a:p><a:r><a:t>'
          '${_esc(s.title)}</a:t></a:r></a:p></c:rich></c:tx>'
          '<c:overlay val="0"/></c:title><c:autoTitleDeleted val="0"/>');
    } else {
      b.write('<c:autoTitleDeleted val="1"/>');
    }
    b.write('<c:plotArea><c:layout/>');
    switch (s.kind) {
      case XlsxChartKind.column:
      case XlsxChartKind.bar:
        b.write('<c:barChart><c:barDir val="'
            '${s.kind == XlsxChartKind.bar ? 'bar' : 'col'}"/>'
            '<c:grouping val="clustered"/><c:varyColors val="0"/>');
        _series(b, s, line: false);
        b.write('<c:gapWidth val="150"/><c:axId val="5000001"/>'
            '<c:axId val="5000002"/></c:barChart>');
        _axes(b, horizontal: s.kind == XlsxChartKind.bar);
      case XlsxChartKind.line:
        b.write('<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>');
        _series(b, s, line: true);
        b.write('<c:marker val="1"/><c:axId val="5000001"/>'
            '<c:axId val="5000002"/></c:lineChart>');
        _axes(b, horizontal: false);
      case XlsxChartKind.pie:
        b.write('<c:pieChart><c:varyColors val="1"/>');
        _series(b, s, line: false);
        b.write('<c:firstSliceAng val="0"/></c:pieChart>');
    }
    b.write('</c:plotArea>'
        '<c:legend><c:legendPos val="${s.kind == XlsxChartKind.pie ? 'r' : 'b'}"/>'
        '<c:overlay val="0"/></c:legend>'
        '<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/>'
        '</c:chart></c:chartSpace>');
    return b.toString();
  }

  /// Office'in varsayılan renk dizisi. Renk AÇIKÇA yazılır: Excel seri
  /// rengini temadan türetir ama LibreOffice ve bazı görüntüleyiciler
  /// `spPr`siz seriyi DOLGUSUZ çiziyor — ölçüldü (Faz 9: çubuklar ve lejant
  /// işaretleri görünmüyordu).
  static const palette = [
    '4472C4', 'ED7D31', 'A5A5A5', 'FFC000', '5B9BD5', '70AD47',
  ];

  static String _fill(String hex) =>
      '<a:solidFill><a:srgbClr val="$hex"/></a:solidFill>';

  static void _series(StringBuffer b, XlsxChartSpec s, {required bool line}) {
    final r1 = s.top + 1, r2 = s.bottom;
    for (var i = 0; i < s.series.length; i++) {
      final ser = s.series[i];
      final color = palette[i % palette.length];
      b.write('<c:ser><c:idx val="$i"/><c:order val="$i"/>'
          '<c:tx><c:strRef><c:f>${_esc(ref(s.sheetName, s.top, ser.col))}</c:f>'
          '<c:strCache><c:ptCount val="1"/><c:pt idx="0"><c:v>${_esc(ser.name)}'
          '</c:v></c:pt></c:strCache></c:strRef></c:tx>');
      if (line) {
        b.write('<c:spPr><a:ln w="28575" cap="rnd">${_fill(color)}'
            '<a:round/></a:ln></c:spPr>'
            '<c:marker><c:symbol val="circle"/><c:size val="5"/>'
            '<c:spPr>${_fill(color)}</c:spPr></c:marker>');
      } else if (s.kind == XlsxChartKind.pie) {
        b.write('<c:spPr><a:ln><a:solidFill><a:srgbClr val="FFFFFF"/>'
            '</a:solidFill></a:ln></c:spPr>');
        for (var k = 0; k < ser.values.length; k++) {
          b.write('<c:dPt><c:idx val="$k"/><c:bubble3D val="0"/><c:spPr>'
              '${_fill(palette[k % palette.length])}</c:spPr></c:dPt>');
        }
      } else {
        b.write('<c:spPr>${_fill(color)}</c:spPr>'
            '<c:invertIfNegative val="0"/>');
      }
      // Kategoriler: kategori sütunu yoksa sıra numarası önbelleği (başvuru
      // yok — Excel o zaman 1, 2, 3… yazar).
      if (s.hasCategoryColumn) {
        b.write('<c:cat><c:strRef><c:f>'
            '${_esc(ref(s.sheetName, r1, s.left, r2, s.left))}</c:f>'
            '<c:strCache><c:ptCount val="${s.categories.length}"/>');
        for (var k = 0; k < s.categories.length; k++) {
          b.write('<c:pt idx="$k"><c:v>${_esc(s.categories[k])}</c:v></c:pt>');
        }
        b.write('</c:strCache></c:strRef></c:cat>');
      }
      b.write('<c:val><c:numRef><c:f>'
          '${_esc(ref(s.sheetName, r1, ser.col, r2, ser.col))}</c:f>'
          '<c:numCache><c:formatCode>General</c:formatCode>'
          '<c:ptCount val="${ser.values.length}"/>');
      for (var k = 0; k < ser.values.length; k++) {
        final v = ser.values[k];
        if (v == null) continue;
        final t = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
        b.write('<c:pt idx="$k"><c:v>$t</c:v></c:pt>');
      }
      b.write('</c:numCache></c:numRef></c:val>');
      if (line) b.write('<c:smooth val="0"/>');
      b.write('</c:ser>');
    }
  }

  static void _axes(StringBuffer b, {required bool horizontal}) {
    b.write('<c:catAx><c:axId val="5000001"/><c:scaling>'
        '<c:orientation val="minMax"/></c:scaling><c:delete val="0"/>'
        '<c:axPos val="${horizontal ? 'l' : 'b'}"/>'
        '<c:numFmt formatCode="General" sourceLinked="1"/>'
        '<c:tickLblPos val="nextTo"/><c:crossAx val="5000002"/>'
        '<c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/>'
        '<c:lblOffset val="100"/></c:catAx>'
        '<c:valAx><c:axId val="5000002"/><c:scaling>'
        '<c:orientation val="minMax"/></c:scaling><c:delete val="0"/>'
        '<c:axPos val="${horizontal ? 'b' : 'l'}"/><c:majorGridlines/>'
        '<c:numFmt formatCode="General" sourceLinked="1"/>'
        '<c:tickLblPos val="nextTo"/><c:crossAx val="5000001"/>'
        '<c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx>');
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
