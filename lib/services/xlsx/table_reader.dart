/// Dosyadaki Excel tabloları (`xl/tables/tableN.xml`, ListObject) — Faz 36
/// madde 5: yapısal başvuruların (`Tablo1[Tutar]`) çözülmesi için ad, sayfa,
/// aralık ve sütun adları. Salt okuma; yazma `XlsxTableWriter`da.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../xlsx_reader.dart' show XlsxRange;
import '../office_zip_guard.dart';

class XlsxFileTable {
  final String name;
  final String sheetName;
  final XlsxRange range;
  final List<String> columns;
  final int headerRows;
  final int totalsRows;
  const XlsxFileTable({
    required this.name,
    required this.sheetName,
    required this.range,
    required this.columns,
    this.headerRows = 1,
    this.totalsRows = 0,
  });
}

abstract final class XlsxTableReader {
  static List<XlsxFileTable> read(Uint8List xlsx) {
    try {
      return _read(xlsx);
    } catch (_) {
      return const []; // bozuk tablo parçası açılışı engellemesin
    }
  }

  static List<XlsxFileTable> _read(Uint8List xlsx) {
    final files = <String, ArchiveFile>{
      for (final f in OfficeZipGuard.decode(xlsx).files)
        if (f.isFile) f.name: f,
    };
    if (!files.keys.any((n) => n.startsWith('xl/tables/'))) return const [];
    XmlDocument? doc(String name) {
      final f = files[name];
      if (f == null) return null;
      return XmlDocument.parse(
          utf8.decode(f.content as List<int>, allowMalformed: true));
    }

    String resolve(String base, String target) {
      if (target.startsWith('/')) return target.substring(1);
      final parts = base.split('/')..removeLast();
      for (final seg in target.split('/')) {
        if (seg == '..') {
          if (parts.isNotEmpty) parts.removeLast();
        } else if (seg != '.') {
          parts.add(seg);
        }
      }
      return parts.join('/');
    }

    Map<String, String> rels(String part) {
      final i = part.lastIndexOf('/');
      final path = '${part.substring(0, i)}/_rels/${part.substring(i + 1)}.rels';
      final d = doc(path);
      if (d == null) return const {};
      return {
        for (final r in d.rootElement.childElements)
          if (r.getAttribute('Id') != null && r.getAttribute('Target') != null)
            r.getAttribute('Id')!: resolve(part, r.getAttribute('Target')!),
      };
    }

    final wb = doc('xl/workbook.xml');
    if (wb == null) return const [];
    final wbRels = rels('xl/workbook.xml');
    final out = <XlsxFileTable>[];
    for (final sh in wb.descendants.whereType<XmlElement>()) {
      if (sh.name.local != 'sheet') continue;
      final name = sh.getAttribute('name');
      final rid = sh.attributes
          .where((a) => a.name.local == 'id')
          .map((a) => a.value)
          .firstOrNull;
      final part = rid == null ? null : wbRels[rid];
      if (name == null || part == null) continue;
      final sheetRels = rels(part);
      final sheetDoc = doc(part);
      if (sheetDoc == null) continue;
      for (final tp in sheetDoc.descendants.whereType<XmlElement>()) {
        if (tp.name.local != 'tablePart') continue;
        final id = tp.attributes
            .where((a) => a.name.local == 'id')
            .map((a) => a.value)
            .firstOrNull;
        final target = id == null ? null : sheetRels[id];
        final t = target == null ? null : doc(target);
        if (t == null) continue;
        final root = t.rootElement;
        final range = XlsxRange.parse(root.getAttribute('ref'));
        final tName = root.getAttribute('displayName') ?? root.getAttribute('name');
        if (range == null || tName == null) continue;
        out.add(XlsxFileTable(
          name: tName,
          sheetName: name,
          range: range,
          columns: [
            for (final c in root.descendants.whereType<XmlElement>())
              if (c.name.local == 'tableColumn') c.getAttribute('name') ?? '',
          ],
          headerRows: int.tryParse(root.getAttribute('headerRowCount') ?? '') ?? 1,
          totalsRows: int.tryParse(root.getAttribute('totalsRowCount') ?? '') ?? 0,
        ));
      }
    }
    return out;
  }
}
