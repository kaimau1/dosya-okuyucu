import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'pptx_render.dart';

/// Bir slayttaki düzenlenebilir paragraf (a:p) — orijinal XML düğümüne bağlı.
class PptxParagraph {
  String text;
  final XmlElement element; // <a:p>
  PptxParagraph(this.text, this.element);
}

class PptxSlide {
  final int index;
  final List<PptxParagraph> paragraphs;
  final XmlDocument doc;
  final String fileName;

  /// Slaytın çizilebilir görünümü (tasarım + biçimli metin).
  SlideVM? view;

  PptxSlide(this.index, this.paragraphs, this.doc, this.fileName, this.view);

  /// Çizim modelindeki `<a:p>` düğümünü düzenlenebilir paragrafa bağlar.
  PptxParagraph? paragraphOf(XmlElement? element) {
    if (element == null) return null;
    for (final p in paragraphs) {
      if (identical(p.element, element)) return p;
    }
    return null;
  }
}

/// .pptx dosyasını metin bazında düzenler; orijinal tasarımı (arka plan, düzen,
/// biçim) tamamen korur — yalnızca `<a:t>` metin düğümleri güncellenir.
class PptxEditor {
  final Archive _archive;
  final PptxRender _render;
  final List<PptxSlide> slides;

  PptxEditor._(this._archive, this._render, this.slides);

  static PptxEditor parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final render = PptxRender(archive);
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
      SlideVM? view;
      try {
        view = render.slide(f.name, doc);
      } catch (_) {
        view = null; // çizilemezse metin listesine düşülür
      }
      slides.add(PptxSlide(slideNo, paras, doc, f.name, view));
      slideNo++;
    }
    return PptxEditor._(archive, render, slides);
  }

  static int _idx(String name) {
    final m = RegExp(r'slide(\d+)\.xml').firstMatch(name);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  /// Paragraf metnini günceller, XML'e yazar ve slaytın görünümünü tazeler.
  void updateParagraph(PptxSlide slide, PptxParagraph para, String text) {
    para.text = text;
    _writeText(para);
    try {
      slide.view = _render.slide(slide.fileName, slide.doc);
    } catch (_) {
      // görünüm tazelenemezse eski çizim kalır
    }
  }

  /// Metni ilk `<a:t>` düğümüne yazar, kalan run'ları boşaltır (biçim korunur).
  void _writeText(PptxParagraph para) {
    final tNodes = para.element.findAllElements('a:t').toList();
    if (tNodes.isEmpty) return;
    tNodes.first.children
      ..clear()
      ..add(XmlText(para.text));
    for (final extra in tNodes.skip(1)) {
      extra.children.clear();
    }
  }

  /// Düzenlenmiş metinleri geri yazıp yeni .pptx byte'larını üretir.
  Uint8List save() {
    final updatedXml = <String, String>{};
    for (final slide in slides) {
      for (final para in slide.paragraphs) {
        _writeText(para);
      }
      updatedXml[slide.fileName] = slide.doc.toXmlString();
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
