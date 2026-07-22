import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Canlı düzenlemeden gelen tek biçimli metin parçası.
typedef RunSeg = (String text, bool bold, bool italic, bool underline);

/// Düzenlenebilir bir Word paragrafı (orijinal XML düğümüne bağlı).
class DocxParagraph {
  String text;
  final bool heading;
  final int level;
  final XmlElement _element;

  /// true ise çalıştırmalar [DocxEditor.setRuns] ile XML'e zaten yazıldı;
  /// [DocxEditor.save] bu paragrafın metnine bir daha dokunmaz.
  bool rich = false;

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

  /// Canlı düzenlemeden gelen paragrafı zengin (B/I/U) çalıştırmalar olarak
  /// XML'e yazar. İlk run'ın `w:rPr`'i şablon alınır → font/boyut/renk korunur;
  /// kalın/italik/altçizgi her segmente göre ayarlanır. Paragraf stilleri (pPr)
  /// yerinde kalır. Köprü/işaretçi gibi run-dışı içerik sadeleşir (ORTA sadakat).
  void setRuns(int index, List<RunSeg> segs) {
    if (index < 0 || index >= paragraphs.length) return;
    final para = paragraphs[index];
    final el = para._element;

    XmlElement? templateRPr;
    for (final r in el.findAllElements('w:r')) {
      final rPr = r.findElements('w:rPr').toList();
      if (rPr.isNotEmpty) templateRPr = rPr.first;
      break; // şablon = İLK run'ın biçimi (varsa)
    }

    el.children.removeWhere(
        (n) => !(n is XmlElement && n.name.qualified == 'w:pPr'));

    for (final (text, bold, italic, underline) in segs) {
      if (text.isEmpty) continue;
      final run = XmlElement(XmlName('w:r'));
      final rPr = templateRPr == null
          ? XmlElement(XmlName('w:rPr'))
          : (templateRPr.copy());
      _setFlag(rPr, 'w:b', bold);
      _setFlag(rPr, 'w:i', italic);
      _setUnderline(rPr, underline);
      run.children.add(rPr);
      final t = XmlElement(XmlName('w:t'));
      t.setAttribute('xml:space', 'preserve');
      t.children.add(XmlText(text));
      run.children.add(t);
      el.children.add(run);
    }

    para.text = segs.map((s) => s.$1).join();
    para.rich = true;
  }

  static void _setFlag(XmlElement rPr, String name, bool on) {
    for (final e in rPr.findElements(name).toList()) {
      rPr.children.remove(e);
    }
    if (on) rPr.children.insert(0, XmlElement(XmlName(name)));
  }

  static void _setUnderline(XmlElement rPr, bool on) {
    for (final e in rPr.findElements('w:u').toList()) {
      rPr.children.remove(e);
    }
    if (on) {
      final u = XmlElement(XmlName('w:u'));
      u.setAttribute('w:val', 'single');
      rPr.children.add(u);
    }
  }

  /// Paragraf metinlerini geri yazıp yeni .docx byte'larını üretir.
  Uint8List save() {
    for (final para in paragraphs) {
      if (para.rich) continue; // çalıştırmalar setRuns ile zaten yazıldı
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
