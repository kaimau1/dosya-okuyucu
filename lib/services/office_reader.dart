import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Office Open XML (docx/pptx) dosyalarından düz metin çıkarır.
/// xlsx için `excel` paketi kullanılır (bkz. file_service).
class OfficeReader {
  /// .docx -> paragraf metni
  static String extractDocxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = _fileByName(archive, 'word/document.xml');
    if (doc == null) return '';
    final xml = XmlDocument.parse(utf8.decode(doc, allowMalformed: true));
    final buffer = StringBuffer();
    for (final para in xml.findAllElements('w:p')) {
      final texts = para.findAllElements('w:t').map((e) => e.innerText);
      final line = texts.join();
      buffer.writeln(line);
    }
    return buffer.toString().trimRight();
  }

  /// .pptx -> her slaytın metni (slayt başlıklarıyla)
  static String extractPptxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final slideFiles = archive.files
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => _slideIndex(a.name).compareTo(_slideIndex(b.name)));

    final buffer = StringBuffer();
    var i = 1;
    for (final f in slideFiles) {
      final content = f.content as List<int>;
      final xml = XmlDocument.parse(utf8.decode(content, allowMalformed: true));
      final texts = xml.findAllElements('a:t').map((e) => e.innerText);
      buffer.writeln('— Slayt $i —');
      buffer.writeln(texts.join('\n'));
      buffer.writeln();
      i++;
    }
    return buffer.toString().trimRight();
  }

  static List<int>? _fileByName(Archive archive, String name) {
    for (final f in archive.files) {
      if (f.name == name) return f.content as List<int>;
    }
    return null;
  }

  static int _slideIndex(String name) {
    final match = RegExp(r'slide(\d+)\.xml').firstMatch(name);
    return match == null ? 0 : int.parse(match.group(1)!);
  }
}
