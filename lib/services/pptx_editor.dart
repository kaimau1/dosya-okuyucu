import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Bir slayttaki düzenlenebilir paragraf (a:p) — orijinal XML düğümüne bağlı.
class PptxParagraph {
  String text;
  final XmlElement _element; // <a:p>
  PptxParagraph(this.text, this._element);
}

class PptxSlide {
  final int index;
  final List<PptxParagraph> paragraphs;
  final XmlDocument _doc;
  final String _fileName;
  PptxSlide(this.index, this.paragraphs, this._doc, this._fileName);
}

/// .pptx dosyasını metin bazında düzenler; orijinal tasarımı (arka plan, düzen,
/// biçim) tamamen korur — yalnızca `<a:t>` metin düğümleri güncellenir.
class PptxEditor {
  final Archive _archive;
  final List<PptxSlide> slides;

  PptxEditor._(this._archive, this.slides);

  static PptxEditor parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final slideFiles = archive.files
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => _idx(a.name).compareTo(_idx(b.name)));

    final slides = <PptxSlide>[];
    var slideNo = 1;
    for (final f in slideFiles) {
      final doc = XmlDocument.parse(
        utf8.decode(f.content as List<int>, allowMalformed: true),
      );
      final paras = <PptxParagraph>[];
      for (final p in doc.findAllElements('a:p')) {
        final text = p.findAllElements('a:t').map((e) => e.innerText).join();
        paras.add(PptxParagraph(text, p));
      }
      slides.add(PptxSlide(slideNo, paras, doc, f.name));
      slideNo++;
    }
    return PptxEditor._(archive, slides);
  }

  static int _idx(String name) {
    final m = RegExp(r'slide(\d+)\.xml').firstMatch(name);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  /// Düzenlenmiş metinleri geri yazıp yeni .pptx byte'larını üretir.
  Uint8List save() {
    final updatedXml = <String, String>{};
    for (final slide in slides) {
      for (final para in slide.paragraphs) {
        final tNodes = para._element.findAllElements('a:t').toList();
        if (tNodes.isEmpty) continue;
        tNodes.first.children
          ..clear()
          ..add(XmlText(para.text));
        for (final extra in tNodes.skip(1)) {
          extra.children.clear();
        }
      }
      updatedXml[slide._fileName] = slide._doc.toXmlString();
    }

    final out = Archive();
    for (final f in _archive.files) {
      if (updatedXml.containsKey(f.name)) {
        final data = utf8.encode(updatedXml[f.name]!);
        out.addFile(ArchiveFile(f.name, data.length, data));
      } else {
        out.addFile(f);
      }
    }
    final List<int>? encoded = ZipEncoder().encode(out);
    return Uint8List.fromList(encoded ?? const <int>[]);
  }
}
