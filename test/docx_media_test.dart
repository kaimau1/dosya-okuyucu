import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 24 kalanı — resim (ekle, oran kilitli boyut, alternatif metin,
/// değiştir), yorumlar (ekle, yanıtla, çözüldü, sil + budama), dipnot, yatay
/// çizgi: gidiş-dönüş + geri al + LibreOffice açılabilirliği.
const _fixture = 'test/fixtures/office/stiller_basliklar.docx';
final _png = File('test/fixtures/media/transparent.png').readAsBytesSync();

String? _part(Uint8List bytes, String name) {
  for (final f in ZipDecoder().decodeBytes(bytes).files) {
    if (f.name == name) return utf8.decode(f.content as List<int>);
  }
  return null;
}

bool _has(Uint8List bytes, String name) =>
    ZipDecoder().decodeBytes(bytes).files.any((f) => f.name == name);

DocxEditController _open([Uint8List? b]) => DocxEditController(
    DocxDocument.parse(b ?? File(_fixture).readAsBytesSync()));

void _expectOpensInLibreOffice(Uint8List bytes, {String? text}) {
  final which = Process.runSync('which', ['soffice']);
  if (which.exitCode != 0) return;
  final dir = Directory.systemTemp.createTempSync('docx_media');
  try {
    final f = File('${dir.path}/t.docx')..writeAsBytesSync(bytes);
    final r = Process.runSync('soffice', [
      '--headless',
      '--convert-to',
      'txt:Text',
      '--outdir',
      dir.path,
      f.path
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final txt = File('${dir.path}/t.txt');
    expect(txt.existsSync(), isTrue);
    if (text != null) expect(txt.readAsStringSync(), contains(text));
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  group('resim', () {
    test('ekle → kaydet: medya parçası, ilişki, içerik türü, ölçü', () {
      final c = _open();
      c.select(const DocPos(0, 0), const DocPos(0, 0));
      c.insertImage(_png, 'png', pixelWidth: 400, pixelHeight: 200);
      expect(c.selectedImage, isNotNull, reason: 'eklenen resim seçili kalır');
      final out = c.doc.save();
      expect(_has(out, 'word/media/image1.png') || _has(out, 'word/media/image2.png'),
          isTrue);
      final rels = _part(out, 'word/_rels/document.xml.rels')!;
      expect(rels, contains('relationships/image'));
      expect(_part(out, '[Content_Types].xml')!, contains('Extension="png"'));
      final docXml = XmlDocument.parse(_part(out, 'word/document.xml')!);
      final ours = docXml
          .findAllElements('wp:inline')
          .firstWhere((e) => (e.findElements('wp:docPr').first.getAttribute('name') ?? '').startsWith('Resim '));
      final ext = ours.findElements('wp:extent').first;
      expect(ext.getAttribute('cx'), '${(300 * 12700).round()}'); // 400 px = 300 pt
      expect(ext.getAttribute('cy'), '${(150 * 12700).round()}');
      final again = DocxDocument.parse(out);
      final img = again.paras[0].atoms
          .whereType<DocxAtom>()
          .where((a) => a.kind == DocxAtomKind.image)
          .toList();
      expect(img, hasLength(1));
      expect(img.single.image, isNotNull, reason: 'resim baytları okunur');
      expect(img.single.widthPt, closeTo(300, 0.01));
      _expectOpensInLibreOffice(out);
    });

    test('oran kilitli boyut + alternatif metin + geri al', () {
      final c = _open();
      c.select(const DocPos(0, 0), const DocPos(0, 0));
      c.insertImage(_png, 'png', pixelWidth: 400, pixelHeight: 200);
      c.resizeImage(144);
      expect(c.selectedImage!.widthPt, 144);
      expect(c.selectedImage!.heightPt, 72);
      c.setImageAlt('Satış grafiği');
      expect(c.imageAlt, 'Satış grafiği');
      final out = c.doc.save();
      final x = XmlDocument.parse(_part(out, 'word/document.xml')!);
      final ours = x.findAllElements('wp:inline').firstWhere((e) =>
          e.findElements('wp:docPr').first.getAttribute('descr') == 'Satış grafiği');
      expect(ours.findAllElements('a:ext').first.getAttribute('cx'),
          '${144 * 12700}');
      expect(ours.findElements('wp:extent').first.getAttribute('cy'),
          '${72 * 12700}');
      c.undo(); // alt metin
      c.undo(); // boyut
      expect(c.selectedImage!.widthPt, 300);
    });

    test('değiştir: genişlik korunur, yükseklik yeni oranla', () {
      final c = _open();
      c.select(const DocPos(0, 0), const DocPos(0, 0));
      c.insertImage(_png, 'png', pixelWidth: 400, pixelHeight: 200);
      c.replaceImage(_png, 'png', pixelWidth: 100, pixelHeight: 100);
      expect(c.selectedImage!.widthPt, 300);
      expect(c.selectedImage!.heightPt, 300);
      final out = c.doc.save();
      _expectOpensInLibreOffice(out);
    });

    test('sil: resim seçiliyken deleteSelection atomu kaldırır', () {
      final c = _open();
      c.select(const DocPos(0, 0), const DocPos(0, 0));
      c.insertImage(_png, 'png', pixelWidth: 40, pixelHeight: 40);
      expect(c.paras[0].atoms.whereType<DocxAtom>(), isNotEmpty);
      c.deleteSelection();
      expect(c.paras[0].atoms.whereType<DocxAtom>()
          .where((a) => a.kind == DocxAtomKind.image), isEmpty);
    });
  });

  group('yorumlar', () {
    test('ekle → comments.xml + aralık + başvuru; yeniden açınca listede', () {
      final c = _open();
      final p = c.paras.indexWhere((p) => p.text.length > 5);
      c.select(DocPos(p, 0), DocPos(p, 5));
      expect(c.addComment('Buna bak', 'Ayşe Yılmaz'), isTrue);
      final out = c.doc.save();
      final cx = _part(out, 'word/comments.xml')!;
      expect(cx, contains('Buna bak'));
      expect(cx, contains('w:author="Ayşe Yılmaz"'));
      expect(cx, contains('w:initials="AY"'));
      final d = _part(out, 'word/document.xml')!;
      expect(d, contains('commentRangeStart'));
      expect(d, contains('commentRangeEnd'));
      expect(d, contains('commentReference'));
      expect(_part(out, 'word/_rels/document.xml.rels')!,
          contains('relationships/comments'));
      expect(_part(out, '[Content_Types].xml')!, contains('/word/comments.xml'));
      final again = _open(out);
      expect(again.comments.single.text, 'Buna bak');
      _expectOpensInLibreOffice(out);
    });

    test('yanıtla + çözüldü → commentsExtended; sil → budanır', () {
      final c = _open();
      final p = c.paras.indexWhere((p) => p.text.length > 5);
      c.select(DocPos(p, 0), DocPos(p, 3));
      c.addComment('Soru', 'A');
      final id = c.comments.single.id;
      expect(c.replyComment(id, 'Cevap', 'B'), isTrue);
      c.setCommentDone(id, true);
      var out = c.doc.save();
      final ext = _part(out, 'word/commentsExtended.xml')!;
      expect(ext, contains('paraIdParent'));
      expect(ext, contains('w15:done="1"'));
      final again = _open(out);
      final list = again.comments;
      expect(list, hasLength(2));
      final root = list.firstWhere((x) => x.parentId == null);
      expect(root.done, isTrue);
      expect(list.firstWhere((x) => x.parentId != null).text, 'Cevap');
      _expectOpensInLibreOffice(out);

      // Silme: yanıtla birlikte gider; kayıtta parçada kalmaz.
      again.deleteComment(root.id);
      expect(again.comments, isEmpty);
      out = again.doc.save();
      expect(_part(out, 'word/comments.xml')!, isNot(contains('Soru')));
      expect(_part(out, 'word/comments.xml')!, isNot(contains('Cevap')));
      expect(_part(out, 'word/document.xml')!, isNot(contains('commentReference')));
    });

    test('sil → geri al: yorum geri gelir ve kaydedilir', () {
      final c = _open();
      final p = c.paras.indexWhere((p) => p.text.length > 5);
      c.select(DocPos(p, 0), DocPos(p, 3));
      c.addComment('Kalsın', 'A');
      final id = c.comments.single.id;
      c.deleteComment(id);
      expect(c.comments, isEmpty);
      c.undo();
      expect(c.comments.single.text, 'Kalsın');
      final out = c.doc.save();
      expect(_part(out, 'word/comments.xml')!, contains('Kalsın'));
    });
  });

  group('dipnot ve yatay çizgi', () {
    test('dipnot ekle → footnotes.xml (ayırıcılarla) + başvuru; metin düzenle', () {
      final c = _open();
      final p = c.paras.indexWhere((p) => p.text.length > 5);
      c.select(DocPos(p, 4), DocPos(p, 4));
      c.insertFootnote('Kaynak: TÜİK');
      final out = c.doc.save();
      final fx = _part(out, 'word/footnotes.xml')!;
      expect(fx, contains('w:type="separator"'));
      expect(fx, contains('Kaynak: TÜİK'));
      expect(_part(out, 'word/document.xml')!, contains('footnoteReference'));
      final again = _open(out);
      final note = again.paras
          .expand((p) => p.atoms)
          .whereType<DocxAtom>()
          .firstWhere((a) => a.kind == DocxAtomKind.note);
      expect(again.footnoteText(note.display), 'Kaynak: TÜİK');
      expect(again.setFootnoteText(note.display, 'Kaynak: TCMB'), isTrue);
      final out2 = again.doc.save();
      expect(_part(out2, 'word/footnotes.xml')!, contains('Kaynak: TCMB'));
      _expectOpensInLibreOffice(out2);
    });

    test('yatay çizgi: alt kenarlıklı paragraf + imleç ardında', () {
      final c = _open();
      c.select(const DocPos(0, 0), const DocPos(0, 0));
      final n = c.paras.length;
      c.insertHorizontalRule();
      expect(c.paras.length, greaterThan(n));
      expect(c.paras[1].look.borderBottom, isTrue);
      expect(c.extent.para, 2);
      final out = c.doc.save();
      expect(_part(out, 'word/document.xml')!, contains('<w:pBdr><w:bottom'));
      final again = DocxDocument.parse(out);
      expect(again.paras.any((p) => p.look.borderBottom), isTrue);
      _expectOpensInLibreOffice(out);
    });
  });
}
