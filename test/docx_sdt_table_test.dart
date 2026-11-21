import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/docx_synth.dart';

/// B9 — satır/hücre düzeyi içerik denetimi (`w:tbl` > `w:sdt` > `w:tr`,
/// `w:tr` > `w:sdt` > `w:tc`). Kanıt: bu satır/hücreler hiç okunmuyordu
/// (tabloda görünmez, aranamaz). Şimdi okunur, yazılır, kap korunur.

String _tc(String t) => '<w:tc><w:p><w:r><w:t>$t</w:t></w:r></w:p></w:tc>';

String _sdt(String inner, {String pr = ''}) =>
    '<w:sdt><w:sdtPr><w:tag w:val="t"/>$pr</w:sdtPr>'
    '<w:sdtContent>$inner</w:sdtContent></w:sdt>';

final _table = '<w:tbl><w:tblGrid><w:gridCol w:w="2000"/><w:gridCol w:w="2000"/>'
    '</w:tblGrid>'
    '<w:tr>${_tc('A1')}${_tc('B1')}</w:tr>'
    '${_sdt('<w:tr>${_tc('A2')}${_tc('B2')}</w:tr>')}'
    '<w:tr>${_tc('A3')}${_sdt(_tc('B3'))}</w:tr>'
    '${_sdt('<w:tr>${_tc('A4')}${_tc('B4')}</w:tr>', pr: '<w:lock w:val="contentLocked"/>')}'
    '</w:tbl>';

String _doc(List<int> b) => synthPart(b, 'word/document.xml');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = synthDocx(synthP('Önce') + _table + synthP('Sonra'));

  test('denetimli satır ve hücre okunur, satır/sütun numarası doğru', () {
    final d = DocxDocument.parse(bytes);
    expect(d.paras.map((p) => p.text),
        ['Önce', 'A1', 'B1', 'A2', 'B2', 'A3', 'B3', 'A4', 'B4', 'Sonra']);
    final b3 = d.paras[6].cell!;
    expect((b3.row, b3.col), (2, 1));
    expect(d.paras[3].cell!.row, 1);
    expect(d.paras[3].opaque, isFalse);
    // Kilitli denetimin satırı biçimiyle okunur ama düzenlenmez.
    expect(d.paras[7].opaque, isTrue);
  });

  test('el değmemiş kayıt aynı; denetimli hücre yazılınca kap kalır', () {
    final d = DocxDocument.parse(bytes);
    expect(_doc(d.save()), _doc(bytes));
    final p = d.paras[6];
    d.paras[6] = p.replace(0, 2, 'Yeni', p.typingStyleAt(0));
    final out = d.save();
    final x = XmlDocument.parse(_doc(out));
    expect(x.findAllElements('w:sdt'), hasLength(3));
    final back = DocxDocument.parse(out);
    expect(back.paras[6].text, 'Yeni');
    expect(back.paras[6].cell!.col, 1);
  });

  test('yapı işlemi (satır ekle) denetimli tabloyu bozmaz', () {
    final d = DocxDocument.parse(bytes);
    final at = d.insertTableRow(5, below: false);
    expect(at, greaterThan(0));
    final back = DocxDocument.parse(d.save());
    expect(back.paras.where((p) => p.cell != null).map((p) => p.text).toList(),
        ['A1', 'B1', 'A2', 'B2', '', '', 'A3', 'B3', 'A4', 'B4']);
  });
}
