import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// G7.4 artığı (2026-11-14): makrolu dosya kaydedilince makro (vbaProject.bin)
/// KORUNUR — kaydetme özgün paketin dokunulmayan parçalarını baytı baytına
/// taşır; makro hiçbir zaman çalıştırılmaz (VBA yorumlayıcısı yok).
void main() {
  final vba = List<int>.generate(64, (i) => i);

  Uint8List withVba(List<int> pkg, String name) {
    final a = ZipDecoder().decodeBytes(pkg);
    final out = Archive();
    for (final f in a.files) {
      out.addFile(f);
    }
    out.addFile(ArchiveFile(name, vba.length, vba));
    return Uint8List.fromList(ZipEncoder().encode(out));
  }

  List<int>? entry(Uint8List bytes, String name) => ZipDecoder()
      .decodeBytes(bytes)
      .files
      .where((f) => f.name == name)
      .firstOrNull
      ?.content as List<int>?;

  test('Word: düzenleyip kaydedince makro korunur', () {
    final e = DocxEditor.parse(
        withVba(BlankDocs.blankDocx(), 'word/vbaProject.bin'));
    e.paragraphs.first.text = 'değişti';
    expect(entry(e.save(), 'word/vbaProject.bin'), vba);
  });

  test('Excel: düzenleyip kaydedince makro korunur', () {
    final e =
        XlsxEditor.parse(withVba(BlankDocs.blankXlsx(), 'xl/vbaProject.bin'));
    e.setCell(e.sheets.first.name, 0, 0, 'değişti');
    expect(entry(e.save(), 'xl/vbaProject.bin'), vba);
  });
}
