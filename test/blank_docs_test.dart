import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boş .docx geçerli, ayrıştırılabilir ve düzenlenebilir', () {
    final bytes = Uint8List.fromList(BlankDocs.blankDocx());
    final e = DocxEditor.parse(bytes);
    expect(e.paragraphs, isNotEmpty); // en az bir boş paragraf

    e.paragraphs.first.text = 'Merhaba dünya';
    final again = DocxEditor.parse(e.save());
    expect(again.paragraphs.first.text, 'Merhaba dünya');
  });

  test('boş .docx SAYFA ÖLÇÜSÜ taşır (yoksa sayfa çizilmez, yazılamaz)', () {
    // 2026-08-17: paket `<w:sectPr/>` yazıyordu — sayfa boyu/kenar boşluğu yok.
    // Word kendi varsayılanıyla açıyor ama sayfa görünümünü çizen gömülü motor
    // ölçüyü BELGEDEN okuyor: ölçü yoksa sayfa hiç çizilmiyor, dokunulacak
    // paragraf olmadığı için yeni belgeye yazı yazılamıyordu.
    final zip = ZipDecoder().decodeBytes(BlankDocs.blankDocx());
    final names = zip.files.map((f) => f.name).toSet();
    expect(names, contains('word/styles.xml'));
    expect(names, contains('word/_rels/document.xml.rels'));

    final doc = utf8.decode(
        zip.files.firstWhere((f) => f.name == 'word/document.xml').content
            as List<int>);
    expect(doc, contains('<w:pgSz'));
    expect(doc, contains('<w:pgMar'));
    expect(doc, isNot(contains('<w:sectPr/>')));
  });

  test('boş .xlsx geçerli, ayrıştırılabilir ve düzenlenebilir', () {
    final bytes = Uint8List.fromList(BlankDocs.blankXlsx());
    final e = XlsxEditor.parse(bytes);
    expect(e.sheets, isNotEmpty);

    final name = e.sheets.first.name;
    e.setCell(name, 0, 0, 'A1 değeri');
    final again = XlsxEditor.parse(e.save());
    expect(again.sheets.first.rows[0][0], 'A1 değeri');
  });
}
