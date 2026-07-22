import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// SÄ±fÄ±rdan boÅŸ Office/metin belgeleri Ã¼retir (gerÃ§ek bir Office programÄ± gibi
/// "Yeni" oluÅŸturabilmek iÃ§in). Ãœretilen dosyalar geÃ§erli OOXML olduÄŸundan hem
/// bizim editÃ¶rlerimizde hem Word/Excel'de aÃ§Ä±lÄ±r.
class BlankDocs {
  /// Yeni boÅŸ belgeyi belgeler dizinine yazÄ±p yolunu dÃ¶ndÃ¼rÃ¼r.
  /// [kind] = 'docx' | 'xlsx' | 'txt'
  static Future<String> create(String kind) async {
    final dir = await _targetDir();
    final ts = _stamp();
    late final String name;
    late final List<int> bytes;
    switch (kind) {
      case 'docx':
        name = 'Yeni Belge $ts.docx';
        bytes = blankDocx();
      case 'xlsx':
        name = 'Yeni Tablo $ts.xlsx';
        bytes = blankXlsx();
      case 'txt':
        name = 'Yeni Metin $ts.txt';
        bytes = const <int>[];
      default:
        throw ArgumentError('bilinmeyen tÃ¼r: $kind');
    }
    final path = p.join(dir.path, name);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  static Future<Directory> _targetDir() async {
    // Belgeler dizini; olmazsa uygulama destek dizinine dÃ¼ÅŸ.
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return await getApplicationSupportDirectory();
    }
  }

  static String _stamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  /// BoÅŸ ama geÃ§erli .xlsx (excel paketi Ã¼retir; tek sayfa).
  static List<int> blankXlsx() {
    final excel = xls.Excel.createExcel();
    return excel.encode() ?? const <int>[];
  }

  /// BoÅŸ ama geÃ§erli .docx (tek boÅŸ paragraf). Minimal OOXML paket.
  static List<int> blankDocx() {
    const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';
    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';
    const document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>'
        '<w:p><w:r><w:t xml:space="preserve"></w:t></w:r></w:p>'
        '<w:sectPr/>'
        '</w:body>'
        '</w:document>';
    return _zip({
      '[Content_Types].xml': contentTypes,
      '_rels/.rels': rels,
      'word/document.xml': document,
    });
  }

  static List<int> _zip(Map<String, String> files) {
    final archive = Archive();
    files.forEach((name, content) {
      final data = utf8.encode(content);
      archive.addFile(ArchiveFile(name, data.length, data));
    });
    return ZipEncoder().encode(archive) ?? const <int>[];
  }
}
