import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path/path.dart' as p;

import 'docs_home.dart';

/// Sıfırdan boş Office/metin belgeleri üretir (gerçek bir Office programı gibi
/// "Yeni" oluşturabilmek için). Üretilen dosyalar geçerli OOXML olduğundan hem
/// bizim editörlerimizde hem Word/Excel'de açılır.
class BlankDocs {
  /// Yeni boş belgeyi belgeler dizinine yazıp yolunu döndürür.
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
        throw ArgumentError('bilinmeyen tür: $kind');
    }
    final path = p.join(dir.path, name);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Ana bellekte `Documents/Dosya Okuyucu` (bkz. [DocsHome]); yazılamazsa
  /// uygulamanın kendi belgeler klasörü.
  static Future<Directory> _targetDir() => DocsHome.resolve();

  static String _stamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  /// Boş ama geçerli .xlsx (excel paketi üretir; tek sayfa).
  static List<int> blankXlsx() {
    final excel = xls.Excel.createExcel();
    return excel.encode() ?? const <int>[];
  }

  /// Boş ama geçerli .docx (tek boş paragraf). Minimal OOXML paket.
  ///
  /// **SAYFA ÖLÇÜSÜ ZORUNLU (2026-08-17 hatası).** Paket eskiden `<w:sectPr/>`
  /// yazıyordu: bölümün sayfa boyu (`w:pgSz`) ve kenar boşluğu (`w:pgMar`) yok
  /// demek. Word bu belgeyi kendi varsayılanıyla açıyor ama sayfa görünümünü
  /// çizen gömülü motor (docx-preview) ölçüyü BELGEDEN okuyor: ölçü yoksa
  /// sayfa çizilmiyor, ekran WebView'ın zemin rengiyle boş kalıyor ve
  /// dokunulacak bir paragraf olmadığı için **yazı yazılamıyor** (kullanıcı
  /// ekran görüntüsü: "yeni word belgesinde düzenle ekranında yazı
  /// yazılmıyor"). Ayrıca `<p>` sayısı 0 çıkıp Flutter tarafındaki eşleme
  /// sigortası (`_onParagraphCount`) canlı düzenlemeyi kapatıyordu.
  ///
  /// Ölçüler A4: 11906 × 16838 twip (210 × 297 mm), kenar boşlukları 1 inç
  /// (1440 twip) — Word'ün "Boş belge" şablonuyla aynı.
  ///
  /// `styles.xml` de eklendi: varsayılan yazı tipi/punto (Calibri 11pt)
  /// belgede yazmazsa motor tarayıcı varsayılanına (Times 16px) düşüyor ve
  /// yeni belge Word'dekinden farklı görünüyordu.
  static List<int> blankDocx() {
    const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '</Types>';
    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';
    // document.xml'in kendi ilişki dosyası: stiller buradan bağlanır.
    const docRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>';
    const styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults>'
        '<w:rPrDefault><w:rPr>'
        '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>'
        '<w:sz w:val="22"/><w:szCs w:val="22"/>' // 11 pt (yarım punto)
        '</w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr>'
        '<w:spacing w:after="160" w:line="259" w:lineRule="auto"/>'
        '</w:pPr></w:pPrDefault>'
        '</w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/><w:qFormat/>'
        '</w:style>'
        '</w:styles>';
    const document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>'
        '<w:p><w:r><w:t xml:space="preserve"></w:t></w:r></w:p>'
        '<w:sectPr>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" '
        'w:header="708" w:footer="708" w:gutter="0"/>'
        '<w:cols w:space="708"/>'
        '<w:docGrid w:linePitch="360"/>'
        '</w:sectPr>'
        '</w:body>'
        '</w:document>';
    return _zip({
      '[Content_Types].xml': contentTypes,
      '_rels/.rels': rels,
      'word/_rels/document.xml.rels': docRels,
      'word/document.xml': document,
      'word/styles.xml': styles,
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
