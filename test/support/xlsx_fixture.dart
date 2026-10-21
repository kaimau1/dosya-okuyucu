import 'dart:typed_data';

import 'package:dosya_okuyucu/services/xlsx_writer.dart';

/// Test için .xlsx üretir (Faz 7: `excel` paketi çıktı — fikstürler kendi
/// yazıcımızla kurulur). [cells] `A1` → değer (String / num / bool).
Uint8List xlsxFrom(
  Map<String, Object?> cells, {
  String sheet = 'Sheet1',
  Map<String, XlsxWriteStyle> styles = const {},
  Map<int, double> colWidths = const {},
  List<XlsxWriteMerge> merges = const [],
  List<XlsxWriteSheet> extraSheets = const [],
}) {
  final styleList = <XlsxWriteStyle>[];
  final out = <int, Map<int, XlsxWriteCell>>{};
  final refs = {...cells.keys, ...styles.keys};
  for (final ref in refs) {
    final (r, c) = cellRef(ref);
    var styleIndex = 0;
    final st = styles[ref];
    if (st != null) {
      var i = styleList.indexOf(st);
      if (i < 0) {
        styleList.add(st);
        i = styleList.length - 1;
      }
      styleIndex = i + 1;
    }
    final v = cells[ref];
    final cell = switch (v) {
      null => XlsxWriteCell.blank(style: styleIndex),
      final String s => XlsxWriteCell(text: s, style: styleIndex),
      final num n => XlsxWriteCell(number: n.toDouble(), style: styleIndex),
      final bool b => XlsxWriteCell(boolean: b, style: styleIndex),
      _ => XlsxWriteCell(text: '$v', style: styleIndex),
    };
    (out[r] ??= {})[c] = cell;
  }
  return XlsxWriter.build([
    XlsxWriteSheet(
        name: sheet, cells: out, colWidths: {...colWidths}, merges: [...merges]),
    ...extraSheets,
  ], styles: styleList);
}

/// `B3` → (2, 1).
(int, int) cellRef(String ref) {
  final m = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(ref)!;
  var col = 0;
  for (final ch in m[1]!.codeUnits) {
    col = col * 26 + (ch - 64);
  }
  return (int.parse(m[2]!) - 1, col - 1);
}
