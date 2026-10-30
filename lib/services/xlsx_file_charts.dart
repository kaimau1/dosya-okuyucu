import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'pptx_render.dart';

/// Dosyada ZATEN bulunan bir grafik (Faz 27 kalanı: "dosyadaki grafiklerin
/// ızgarada çizimi"). Konum hücre cinsinden (0 tabanlı, `to` dahil değil
/// gibi okunur: `xdr:to` grafiğin bittiği hücre).
class XlsxFileChart {
  final String sheetName;
  final int fromRow, fromCol, toRow, toCol;
  final ChartVM chart;
  final String title;
  const XlsxFileChart({
    required this.sheetName,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    required this.chart,
    this.title = '',
  });
}

/// `.xlsx` paketindeki grafikleri okur: çalışma kitabı → sayfa → çizim
/// (`xdr:twoCellAnchor` / `xdr:oneCellAnchor`) → grafik parçası.
///
/// Değerler grafiğin kendi ÖNBELLEĞİNDEN (`c:numCache` / `c:strCache`)
/// gelir — Excel'in son kaydında gördüğü değerler. Grafik salt çizilir;
/// dosyada olduğu gibi kalır (kaydetme özgün paketi korur).
abstract final class XlsxFileCharts {
  static List<XlsxFileChart> read(Uint8List bytes) {
    if (bytes.isEmpty) return const [];
    try {
      return _read(ZipDecoder().decodeBytes(bytes));
    } catch (_) {
      // Bilinçli: grafik okunamazsa ızgara grafiksiz açılır.
      return const [];
    }
  }

  static XmlDocument? _xml(Archive a, String name) {
    final f = a.findFile(name);
    if (f == null) return null;
    try {
      return XmlDocument.parse(
          utf8.decode(f.content as List<int>, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  /// `<dir>/_rels/<file>.rels` → kimlik → hedef yol (paket köküne göre).
  static Map<String, (String, String)> _rels(Archive a, String part) {
    final dir = p.posix.dirname(part);
    final doc =
        _xml(a, p.posix.join(dir, '_rels', '${p.posix.basename(part)}.rels'));
    if (doc == null) return const {};
    return {
      for (final r in doc.findAllElements('Relationship'))
        if (r.getAttribute('Id') != null && r.getAttribute('Target') != null)
          r.getAttribute('Id')!: (
            p.posix.normalize(r.getAttribute('Target')!.startsWith('/')
                ? r.getAttribute('Target')!.substring(1)
                : p.posix.join(dir, r.getAttribute('Target')!)),
            r.getAttribute('Type') ?? '',
          ),
    };
  }

  static String? _attr(XmlElement e, String local) {
    for (final a in e.attributes) {
      if (a.name.local == local) return a.value;
    }
    return null;
  }

  static XmlElement? _child(XmlElement? e, String local) {
    if (e == null) return null;
    for (final c in e.childElements) {
      if (c.name.local == local) return c;
    }
    return null;
  }

  static int _int(XmlElement? e, String local) =>
      int.tryParse(_child(e, local)?.innerText.trim() ?? '') ?? 0;

  static List<XlsxFileChart> _read(Archive a) {
    const wbPath = 'xl/workbook.xml';
    final wb = _xml(a, wbPath);
    if (wb == null) return const [];
    final wbRels = _rels(a, wbPath);
    final render = PptxRender(a);
    final out = <XlsxFileChart>[];
    for (final sheet in wb.findAllElements('sheet', namespace: '*')) {
      final name = sheet.getAttribute('name');
      final rid = _attr(sheet, 'id');
      final sheetPath = rid == null ? null : wbRels[rid]?.$1;
      if (name == null || sheetPath == null) continue;
      final sheetRels = _rels(a, sheetPath);
      for (final (drawingPath, type) in sheetRels.values) {
        if (!type.endsWith('/drawing')) continue;
        final drawing = _xml(a, drawingPath);
        if (drawing == null) continue;
        final dRels = _rels(a, drawingPath);
        for (final anchor in drawing.rootElement.childElements) {
          final kind = anchor.name.local;
          if (kind != 'twoCellAnchor' && kind != 'oneCellAnchor') continue;
          XmlElement? chartRef;
          for (final e in anchor.descendants.whereType<XmlElement>()) {
            if (e.name.local == 'chart') {
              chartRef = e;
              break;
            }
          }
          final cid = chartRef == null ? null : _attr(chartRef, 'id');
          final chartPath = cid == null ? null : dRels[cid]?.$1;
          if (chartPath == null) continue;
          final vm = render.chartPart(chartPath);
          if (vm == null) continue;
          final from = _child(anchor, 'from');
          final fromCol = _int(from, 'col'), fromRow = _int(from, 'row');
          int toCol, toRow;
          if (kind == 'twoCellAnchor') {
            final to = _child(anchor, 'to');
            toCol = _int(to, 'col');
            toRow = _int(to, 'row');
          } else {
            // Tek hücreye bağlı: boyut EMU'dan (varsayılan sütun ≈ 64 px,
            // satır ≈ 20 px; 1 px = 9525 EMU) yaklaşık hücre sayısına.
            final ext = _child(anchor, 'ext');
            final cx = int.tryParse(ext?.getAttribute('cx') ?? '') ?? 0;
            final cy = int.tryParse(ext?.getAttribute('cy') ?? '') ?? 0;
            toCol = fromCol + (cx / (64 * 9525)).ceil().clamp(2, 40);
            toRow = fromRow + (cy / (20 * 9525)).ceil().clamp(4, 80);
          }
          if (toCol <= fromCol) toCol = fromCol + 6;
          if (toRow <= fromRow) toRow = fromRow + 12;
          final chartDoc = _xml(a, chartPath);
          var title = '';
          final titleEl = chartDoc?.findAllElements('c:title').firstOrNull;
          if (titleEl != null) {
            title = titleEl
                .findAllElements('a:t')
                .map((t) => t.innerText)
                .join()
                .trim();
          }
          out.add(XlsxFileChart(
            sheetName: name,
            fromRow: fromRow,
            fromCol: fromCol,
            toRow: toRow,
            toCol: toCol,
            chart: vm,
            title: title,
          ));
        }
      }
    }
    return out;
  }
}
