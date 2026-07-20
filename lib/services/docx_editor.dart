import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Düzenlenebilir bir Word paragrafı (orijinal XML düğümüne bağlı).
class DocxParagraph {
  String text;
  final bool heading;
  final int level;
  final XmlElement _element;

  DocxParagraph(this.text, this.heading, this.level, this._element);
}

/// .docx dosyasını paragraf bazında düzenler ve orijinal biçimi koruyarak kaydeder.
///
/// Metin, paragraf içindeki ilk `<w:t>` düğümüne yazılır; paragraf stilleri (pPr)
/// ve ilk çalıştırmanın (run) biçimi (rPr) korunur.
class DocxEditor {
  final Archive _archive;
  final XmlDocument _doc;
  final List<DocxParagraph> paragraphs;

  DocxEditor._(this._archive, this._doc, this.paragraphs);

  static DocxEditor parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw const FormatException('document.xml bulunamadı'),
    );
    final xml = XmlDocument.parse(
      utf8.decode(docFile.content as List<int>, allowMalformed: true),
    );

    final paras = <DocxParagraph>[];
    for (final p in xml.findAllElements('w:p')) {
      final text =
          p.findAllElements('w:t').map((e) => e.innerText).join();
      final styleVal = p
          .findAllElements('w:pStyle')
          .map((e) => e.getAttribute('w:val') ?? '')
          .firstWhere((_) => true, orElse: () => '');
      final isHeading = styleVal.toLowerCase().contains('heading') ||
          styleVal.toLowerCase().contains('title');
      final level = _levelFromStyle(styleVal);
      paras.add(DocxParagraph(text, isHeading, level, p));
    }
    return DocxEditor._(archive, xml, paras);
  }

  static int _levelFromStyle(String style) {
    if (style.toLowerCase().contains('title')) return 0;
    final m = RegExp(r'(\d+)').firstMatch(style);
    if (m == null) return 1;
    final v = int.parse(m.group(1)!);
    return v < 1 ? 1 : (v > 6 ? 6 : v);
  }

  /// Paragraf metinlerini geri yazıp yeni .docx byte'larını üretir.
  Uint8List save() {
    for (final para in paragraphs) {
      final tNodes = para._element.findAllElements('w:t').toList();
      if (tNodes.isEmpty) {
        // Metin düğümü yoksa, ilk run'a ekle; run yoksa oluştur.
        final runs = para._element.findElements('w:r').toList();
        final XmlElement run =
            runs.isNotEmpty ? runs.first : _appendRun(para._element);
        final t = XmlElement(XmlName('w:t'));
        t.setAttribute('xml:space', 'preserve');
        t.children.add(XmlText(para.text));
        run.children.add(t);
      } else {
        tNodes.first
          ..setAttribute('xml:space', 'preserve')
          ..children.clear();
        tNodes.first.children.add(XmlText(para.text));
        for (final extra in tNodes.skip(1)) {
          extra.children.clear();
        }
      }
    }

    final newXml = _doc.toXmlString();
    final out = Archive();
    for (final f in _archive.files) {
      if (f.name == 'word/document.xml') {
        final data = utf8.encode(newXml);
        out.addFile(ArchiveFile(f.name, data.length, data));
      } else {
        out.addFile(f);
      }
    }
    final List<int>? encoded = ZipEncoder().encode(out);
    return Uint8List.fromList(encoded ?? const <int>[]);
  }

  XmlElement _appendRun(XmlElement paragraph) {
    final run = XmlElement(XmlName('w:r'));
    paragraph.children.add(run);
    return run;
  }
}
