import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xml/xml.dart';

/// Faz 9 / Y1 — Word'e resim ekleme (satır içi) ve silme.
void main() {
  Uint8List png(int w, int h) {
    final im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(30, 120, 200));
    return Uint8List.fromList(img.encodePng(im));
  }

  Map<String, List<int>> unzip(Uint8List b) => {
        for (final f in ZipDecoder().decodeBytes(b).files)
          if (f.isFile) f.name: f.content as List<int>,
      };

  DocxEditor twoParas() {
    final e = DocxEditor.parse(Uint8List.fromList(BlankDocs.blankDocx()));
    e.setRuns(0, [const RunSeg('Birinci', false, false, false)]);
    final p = e.addParagraphAfter(e.paragraphs.first);
    e.setRuns(e.paragraphs.indexOf(p), [const RunSeg('İkinci', false, false, false)]);
    return e;
  }

  test('resim paketin her katmanına doğru bağlanır', () {
    final e = twoParas();
    final para = e.insertImageAfter(e.paragraphs.first, png(200, 100),
        ext: 'png', widthPx: 200, heightPx: 100);
    expect(e.paragraphs.indexOf(para), 1);
    final files = unzip(e.save());

    expect(files.keys, contains('word/media/fkimage1.png'));
    final rels = utf8.decode(files['word/_rels/document.xml.rels']!);
    final rid = RegExp(r'Id="(rId\d+)"[^>]*Target="media/fkimage1.png"')
            .firstMatch(rels)?[1] ??
        RegExp(r'Target="media/fkimage1.png"[^>]*Id="(rId\d+)"')
            .firstMatch(rels)![1];
    expect(utf8.decode(files['[Content_Types].xml']!),
        contains('Extension="png"'));
    final doc = utf8.decode(files['word/document.xml']!);
    expect(() => XmlDocument.parse(doc), returnsNormally);
    expect(doc, contains('r:embed="$rid"'));
    // 200 px × 9525 = 1 905 000 EMU
    expect(doc, contains('cx="1905000"'));

    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs.map((p) => p.text), ['Birinci', '', 'İkinci']);
    expect(again.imageCount(1), 1);
  });

  test('geniş fotoğraf sayfa genişliğine sığdırılır, oran korunur', () {
    final e = twoParas()
      ..insertImageAfter(null, png(40, 30), ext: 'jpg', widthPx: 4000, heightPx: 3000);
    final doc = utf8.decode(unzip(e.save())['word/document.xml']!);
    expect(doc, contains('cx="${DocxEditor.maxImageWidthEmu}"'));
    expect(doc, contains('cy="4320000"'));
  });

  test('resim silinir, paragraf ve metin kalır', () {
    final e = twoParas();
    e.insertImageAfter(e.paragraphs.first, png(10, 10),
        ext: 'png', widthPx: 10, heightPx: 10);
    expect(e.removeImages(1), 1);
    final again = DocxEditor.parse(e.save());
    expect(again.imageCount(1), 0);
    expect(again.paragraphs.first.text, 'Birinci');
  });

  test('liste + resim aynı kaydetmede: ilişkiler birlikte yazılır', () {
    final e = twoParas()..setListStyle(0, 'bullet');
    e.insertImageAfter(e.paragraphs.first, png(10, 10),
        ext: 'png', widthPx: 10, heightPx: 10);
    final rels = utf8.decode(unzip(e.save())['word/_rels/document.xml.rels']!);
    expect(rels, contains('numbering.xml'));
    expect(rels, contains('media/fkimage1.png'));
  });
}
