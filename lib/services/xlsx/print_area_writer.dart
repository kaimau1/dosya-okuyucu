/// **Yazdırma alanı yazıcısı** — Faz 36 madde 12: `xl/workbook.xml`
/// `<definedNames>` altında sayfa-yerel `_xlnm.Print_Area` adı. Paketin
/// geri kalanına dokunulmaz.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Sayfa sırası [index] (localSheetId), adı ve aralığı (`A1:D20`; null = sil).
class XlsxPrintAreaSpec {
  final int index;
  final String sheetName;
  final String? ref;
  const XlsxPrintAreaSpec(this.index, this.sheetName, this.ref);
}

abstract final class XlsxPrintAreaWriter {
  static const _name = '_xlnm.Print_Area';

  /// `A1:D20` → `'Sayfa 1'!$A$1:$D$20`.
  static String formula(String sheet, String ref) {
    final q = "'${sheet.replaceAll("'", "''")}'";
    final abs = ref.split(':').map((part) {
      final m = RegExp(r'^\$?([A-Za-z]+)\$?(\d+)$').firstMatch(part);
      return m == null ? part : '\$${m[1]!.toUpperCase()}\$${m[2]}';
    }).join(':');
    return '$q!$abs';
  }

  static Uint8List apply(Uint8List xlsx, List<XlsxPrintAreaSpec> specs) {
    if (specs.isEmpty) return xlsx;
    final archive = ZipDecoder().decodeBytes(xlsx);
    final wbFile =
        archive.files.where((f) => f.name == 'xl/workbook.xml').firstOrNull;
    if (wbFile == null) return xlsx;
    final doc = XmlDocument.parse(
        utf8.decode(wbFile.content as List<int>, allowMalformed: true));
    final root = doc.rootElement;
    final prefix = root.name.prefix;
    XmlName n(String local) => XmlName(local, prefix);
    var names = root.childElements
        .where((e) => e.name.local == 'definedNames')
        .firstOrNull;
    for (final s in specs) {
      final existing = names;
      if (existing != null) {
        for (final dn in existing.childElements.toList()) {
          if (dn.name.local == 'definedName' &&
              dn.getAttribute('name') == _name &&
              dn.getAttribute('localSheetId') == '${s.index}') {
            existing.children.remove(dn);
          }
        }
      }
      final ref = s.ref;
      if (ref == null || ref.isEmpty) continue;
      var target = names;
      if (target == null) {
        target = names = XmlElement(n('definedNames'));
        // Şema sırası: … sheets, functionGroups, externalReferences,
        // definedNames, calcPr …
        const before = {'sheets', 'functionGroups', 'externalReferences'};
        var at = -1;
        for (var i = 0; i < root.children.length; i++) {
          final c = root.children[i];
          if (c is XmlElement && before.contains(c.name.local)) at = i;
        }
        root.children.insert(at + 1, target);
      }
      target.children.add(XmlElement(n('definedName'), [
        XmlAttribute(XmlName('name'), _name),
        XmlAttribute(XmlName('localSheetId'), '${s.index}'),
      ], [
        XmlText(formula(s.sheetName, ref)),
      ]));
    }
    final last = names;
    if (last != null && last.childElements.isEmpty) {
      root.children.remove(last);
    }
    final out = Archive();
    final wbBytes = utf8.encode(doc.toXmlString());
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.name == 'xl/workbook.xml') {
        out.addFile(ArchiveFile(f.name, wbBytes.length, wbBytes));
      } else {
        out.addFile(ArchiveFile(f.name, f.size, f.content));
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(out));
  }
}
