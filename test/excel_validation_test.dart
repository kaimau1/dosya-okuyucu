import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/xlsx/validation_check.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/xlsx_fixture.dart';

/// B10 m.3 — veri doğrulama: aralıktan / tanımlı addan / başka sayfadan
/// (`x14` uzantısı) liste, başvurulu sınır, özel formül (göreli kayma),
/// uyarı türleri (Durdur/Uyarı/Bilgi), gizli açılır ok ve okuma → yazma
/// gidiş-dönüşünde özniteliklerin korunması.

const _x14 = 'http://schemas.microsoft.com/office/spreadsheetml/2009/9/main';
const _xm = 'http://schemas.microsoft.com/office/excel/2006/main';

const _rules = '<dataValidations count="5">'
    '<dataValidation type="list" errorStyle="warning" allowBlank="1" '
    'showInputMessage="1" showErrorMessage="1" errorTitle="Dikkat" '
    'error="Listeden seçin" promptTitle="Meyve" prompt="Bir meyve seçin" '
    'sqref="A2:A10"><formula1>Meyveler</formula1></dataValidation>'
    '<dataValidation type="whole" operator="lessThanOrEqual" '
    'showErrorMessage="1" error="En çok D1" sqref="B2:B10">'
    '<formula1>\$D\$1</formula1></dataValidation>'
    '<dataValidation type="custom" errorStyle="information" '
    'showErrorMessage="1" sqref="C2:C10"><formula1>LEN(C2)&lt;=3</formula1>'
    '</dataValidation>'
    '<dataValidation type="list" showDropDown="1" showErrorMessage="1" '
    'sqref="E2"><formula1>"Evet,Hayır"</formula1></dataValidation>'
    '<dataValidation type="decimal" sqref="F2"><formula1>0</formula1>'
    '<formula2>1</formula2></dataValidation>'
    '</dataValidations>';

const _ext = '<extLst><ext uri="{CCE6A557-97BC-4b89-ADB6-D9C93CAAB3DF}" '
    'xmlns:x14="$_x14"><x14:dataValidations count="1" xmlns:xm="$_xm">'
    '<x14:dataValidation type="list" allowBlank="1" showErrorMessage="1">'
    '<x14:formula1><xm:f>Liste!\$A\$1:\$A\$4</xm:f></x14:formula1>'
    '<xm:sqref>G2:G5</xm:sqref></x14:dataValidation>'
    '</x14:dataValidations></ext></extLst>';

Uint8List _book() {
  final base = xlsxFrom(
    {'A1': 'Meyve', 'D1': 10},
    sheet: 'Veri',
    extraSheets: [
      XlsxWriteSheet(name: 'Liste', cells: {
        0: {0: const XlsxWriteCell(text: 'Elma')},
        1: {0: const XlsxWriteCell(text: 'Armut')},
        2: {0: const XlsxWriteCell(text: 'Elma')},
      }),
    ],
  );
  final src = ZipDecoder().decodeBytes(base);
  final out = Archive();
  for (final f in src.files) {
    var bytes = f.content as List<int>;
    if (f.name == 'xl/worksheets/sheet1.xml') {
      final xml = utf8
          .decode(bytes)
          .replaceFirst('</sheetData>', '</sheetData>$_rules')
          .replaceFirst('</worksheet>', '$_ext</worksheet>');
      bytes = utf8.encode(xml);
    } else if (f.name == 'xl/workbook.xml') {
      final xml = utf8.decode(bytes).replaceFirst('</workbook>',
          '<definedNames><definedName name="Meyveler">Liste!\$A\$1:\$A\$4'
              '</definedName></definedNames></workbook>');
      bytes = utf8.encode(xml);
    }
    out.addFile(ArchiveFile(f.name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(out));
}

String _sheetXml(Uint8List bytes) {
  for (final f in ZipDecoder().decodeBytes(bytes).files) {
    if (f.name == 'xl/worksheets/sheet1.xml') {
      return utf8.decode(f.content as List<int>);
    }
  }
  throw StateError('sheet1 yok');
}

XlsxValidationCheck _check(XlsxEditor ed) {
  final s = ed.sheets.first;
  return XlsxValidationCheck(FormulaEngine(s.rows,
      sheetName: s.name, sheets: {for (final x in ed.sheets) x.name: x.rows}));
}

void main() {
  test('okuma: ana + x14 kuralları, bütün öznitelikler, tanımlı ad', () {
    final s = XlsxEditor.parse(_book()).sheets.first;
    expect(s.layout.validations, hasLength(6));
    final a = s.validationAt(2, 0)!;
    expect(a.isRefList, isTrue);
    expect(a.formula1, 'Meyveler');
    expect(a.listRef, r'Liste!$A$1:$A$4');
    expect(a.errorStyle, 'warning');
    expect(a.errorTitle, 'Dikkat');
    expect(a.promptTitle, 'Meyve');
    expect(a.prompt, 'Bir meyve seçin');
    expect(a.showInputMessage, isTrue);
    final g = s.validationAt(3, 6)!;
    expect(g.fromExt, isTrue);
    expect(g.formula1, r'Liste!$A$1:$A$4');
    final e = s.validationAt(1, 4)!;
    expect(e.hideDropDown, isTrue);
    expect(e.options, ['Evet', 'Hayır']);
    expect(s.validationAt(1, 5)!.showErrorMessage, isFalse);
    expect(s.validationAt(1, 7), isNull);
  });

  test('liste seçenekleri: tanımlı ad, başka sayfa, satır içi (tekrarsız)', () {
    final ed = XlsxEditor.parse(_book());
    final s = ed.sheets.first;
    final ck = _check(ed);
    expect(ck.options(s.validationAt(2, 0)!, 2, 0), ['Elma', 'Armut']);
    expect(ck.options(s.validationAt(4, 6)!, 4, 6), ['Elma', 'Armut']);
    expect(ck.options(s.validationAt(1, 4)!, 1, 4), ['Evet', 'Hayır']);
  });

  test('denetim: uyarı türleri, başvurulu sınır, göreli özel formül', () {
    final ed = XlsxEditor.parse(_book());
    final s = ed.sheets.first;
    final ck = _check(ed);
    XlsxValidationResult at(int r, int c, String v) =>
        ck.check(s.validationAt(r, c)!, r, c, v);
    // Liste (Uyarı türü): büyük/küçük harf duyarsız.
    expect(at(2, 0, 'armut'), XlsxValidationResult.ok);
    expect(at(2, 0, 'Kiraz'), XlsxValidationResult.warning);
    expect(at(3, 6, 'Kiraz'), XlsxValidationResult.stop);
    // Tam sayı ≤ $D$1 (=10): sınır hücreden okunur.
    expect(at(4, 1, '7'), XlsxValidationResult.ok);
    expect(at(4, 1, '11'), XlsxValidationResult.stop);
    // Özel formül C2'ye göre yazılı; C5'te LEN(C5) denetlenir (Bilgi türü).
    expect(at(4, 2, 'abc'), XlsxValidationResult.ok);
    expect(at(4, 2, 'abcd'), XlsxValidationResult.information);
    // showErrorMessage yok: Excel uyarmaz.
    expect(s.validationAt(1, 5)!.accepts('5'), isFalse);
    expect(at(1, 5, '5'), XlsxValidationResult.ok);
    // Boş giriş allowBlank'e göre; formül girişi Excel'e bırakılır.
    expect(at(2, 0, ''), XlsxValidationResult.ok);
    expect(at(4, 1, '=D1*5'), XlsxValidationResult.ok);
  });

  test('gidiş-dönüş: kural yeniden yazılınca öznitelikler korunur', () {
    final ed = XlsxEditor.parse(_book());
    final s = ed.sheets.first;
    final a = s.validationAt(2, 0)!;
    // Aynı kuralı yeniden kur (sil + yaz yolu).
    ed.addValidation(s.name, a.ranges.first, a);
    ed.addValidation(
        s.name,
        const XlsxRange(1, 7, 1, 7),
        const XlsxDataValidation(
            type: 'custom',
            ranges: [XlsxRange(1, 7, 1, 7)],
            formula1: 'ISNUMBER(H2)',
            errorStyle: 'warning'));
    final out = ed.save();
    final xml = _sheetXml(out);
    expect(xml, contains('errorStyle="warning"'));
    final again = XlsxEditor.parse(out).sheets.first;
    expect(again.layout.validations, hasLength(7));
    final a2 = again.validationAt(5, 0)!;
    expect(a2.formula1, 'Meyveler');
    expect(a2.listRef, r'Liste!$A$1:$A$4');
    expect(a2.errorStyle, 'warning');
    expect(a2.errorTitle, 'Dikkat');
    expect(a2.error, 'Listeden seçin');
    expect(a2.prompt, 'Bir meyve seçin');
    expect(a2.showInputMessage, isTrue);
    expect(a2.allowBlank, isTrue);
    final h = again.validationAt(1, 7)!;
    expect(h.type, 'custom');
    expect(h.formula1, 'ISNUMBER(H2)');
    expect(h.errorStyle, 'warning');
    // Dokunulmayan kurallar olduğu gibi.
    expect(again.validationAt(4, 1)!.operator, 'lessThanOrEqual');
    expect(again.validationAt(1, 4)!.hideDropDown, isTrue);
    expect(again.validationAt(3, 6)!.fromExt, isTrue);
    // Gizli ok + tırnak kaçışı yazımda da korunur.
    final ed2 = XlsxEditor.parse(out);
    final e = ed2.sheets.first.validationAt(1, 4)!;
    ed2.addValidation(ed2.sheets.first.name, e.ranges.first, e);
    final e2 = XlsxEditor.parse(ed2.save()).sheets.first.validationAt(1, 4)!;
    expect(e2.hideDropDown, isTrue);
    expect(e2.options, ['Evet', 'Hayır']);
  });

  test('x14 kuralı temizlenince uzantıdan da silinir', () {
    final ed = XlsxEditor.parse(_book());
    final s = ed.sheets.first;
    ed.clearValidations(s.name, const XlsxRange(0, 6, 20, 6));
    final out = ed.save();
    final xml = _sheetXml(out);
    expect(xml, isNot(contains('x14:dataValidation')));
    final again = XlsxEditor.parse(out).sheets.first;
    expect(again.validationAt(3, 6), isNull);
    expect(again.layout.validations, hasLength(5));
  });

  test('satır ekleme işleci, ikinci sınırı ve uyarıyı korur', () {
    final ed = XlsxEditor.parse(_book());
    final s = ed.sheets.first;
    ed.insertRow(s.name, 0);
    final b = s.validationAt(5, 1)!;
    expect(b.ranges.first.r1, 2);
    expect(b.operator, 'lessThanOrEqual');
    expect(b.error, 'En çok D1');
    expect(b.formula1, r'$D$2');
    final f = s.validationAt(2, 5)!;
    expect(f.formula2, '1');
    expect(f.showErrorMessage, isFalse);
    expect(s.validationAt(3, 0)!.errorStyle, 'warning');
  });
}
