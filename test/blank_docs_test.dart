import 'dart:typed_data';

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
