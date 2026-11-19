import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile_editor_screen.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/docx_synth.dart';

/// B9 m.8 — büyük belge açılışı, "ilk sayfa önce": belgenin yalnız başı
/// (üst düzey blok sınırında) çözümlenir; sayfa yapısı (gövde `w:sectPr`)
/// korunur, blok (tablo, içerik denetimi) asla ortadan bölünmez; kısa
/// belgede kesme yok. Baş modeli kaydedilemez (belgenin geri kalanı
/// silinirdi).

const _ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
const _sect = '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr>';

String _xml(String body, {bool sect = true}) =>
    '<?xml version="1.0"?><w:document $_ns><w:body>$body'
    '${sect ? _sect : ''}</w:body></w:document>';

String _p(String t) => '<w:p><w:pPr><w:jc w:val="left"/></w:pPr>'
    '<w:r><w:t>$t</w:t></w:r></w:p>';

String _tbl(int rows) => '<w:tbl><w:tblPr/><w:tblGrid/>'
    '${List.filled(rows, '<w:tr><w:tc><w:tcPr/>${_p('hücre')}</w:tc></w:tr>').join()}'
    '</w:tbl>';

List<String> _blocks(String xml) => [
      for (final p in XmlDocument.parse(xml)
          .findAllElements('w:body')
          .first
          .childElements)
        p.name.local,
    ];

void main() {
  group('docxHeadXml', () {
    test('ilk N blok + gövde sectPr; XML geçerli', () {
      final body = List.generate(10, (i) => _p('P$i')).join();
      final h = docxHeadXml(_xml(body), 3, 100)!;
      expect(_blocks(h), ['p', 'p', 'p', 'sectPr']);
      expect(h, contains('P2'));
      expect(h, isNot(contains('P3')));
      expect(h, contains('w:pgSz'));
    });

    test('kısa belge → null (kesme yok)', () {
      final body = List.generate(3, (i) => _p('P$i')).join();
      expect(docxHeadXml(_xml(body), 3, 100), isNull);
      expect(docxHeadXml(_xml(body), 10, 100), isNull);
    });

    test('tablo ve içerik denetimi ortadan bölünmez; iç paragraflar sayılır',
        () {
      final sdt = '<w:sdt><w:sdtPr><w:alias w:val="K"/></w:sdtPr>'
          '<w:sdtContent>${_p('s1')}${_p('s2')}</w:sdtContent></w:sdt>';
      final body = _p('a') + _tbl(5) + sdt + _p('b') + _p('c');
      // 2. blok (tablo) 6. paragrafı kapatır → paragraf sınırı 4'te dur.
      final h = docxHeadXml(_xml(body), 50, 4)!;
      expect(_blocks(h), ['p', 'tbl', 'sectPr']);
      expect('hücre'.allMatches(h), hasLength(5));
      final h2 = docxHeadXml(_xml(body), 3, 100)!;
      expect(_blocks(h2), ['p', 'tbl', 'sdt', 'sectPr']);
      expect(h2, contains('s2'));
    });

    test('kendinden kapanan <w:p/>, paragraf düzeyi bölüm sonu', () {
      const inner = '<w:p><w:pPr><w:sectPr><w:pgSz w:w="1"/></w:sectPr>'
          '</w:pPr></w:p>';
      final body = '<w:p/>$inner${_p('x')}${_p('y')}';
      final h = docxHeadXml(_xml(body), 2, 100)!;
      expect(_blocks(h), ['p', 'p', 'sectPr']);
      // Gövde sectPr'si yoksa paragraf içindeki alınmaz; XML yine geçerli.
      final h2 = docxHeadXml(_xml(body, sect: false), 2, 100)!;
      expect(_blocks(h2), ['p', 'p']);
    });
  });

  group('DocxDocument.parseHead', () {
    final bytes = synthDocx(List.generate(300, (i) => synthP('Satır $i')).join());

    test('baş = tam modelin ilk paragrafları; kaydedilmez', () {
      final full = DocxDocument.parse(bytes);
      final head = DocxDocument.parseHead(bytes);
      expect(head.headOnly, isTrue);
      expect(full.headOnly, isFalse);
      expect(head.paras.length, lessThanOrEqualTo(kDocxHeadBlocks));
      for (var i = 0; i < head.paras.length; i++) {
        expect(head.paras[i].text, full.paras[i].text);
      }
      expect(head.save, throwsStateError);
    });

    test('kısa belgede tam model (kaydedilebilir)', () {
      final small = synthDocx(synthP('Tek'));
      final head = DocxDocument.parseHead(small);
      expect(head.headOnly, isFalse);
      expect(head.paras.single.text, 'Tek');
      expect(head.save(), isNotEmpty);
    });
  });

  testWidgets('açılış önizlemesi salt okunur: dokunuş imleç kurmaz',
      (t) async {
    final c = DocxEditController(DocxDocument.parseHead(
        synthDocx(List.generate(200, (i) => synthP('Satır $i')).join())));
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: DocxLoadingPreview(head: c))));
    expect(find.textContaining('Satır 0', findRichText: true), findsOneWidget);
    await t.tap(find.textContaining('Satır 0', findRichText: true));
    await t.pump(const Duration(milliseconds: 400));
    expect(c.attached, isFalse);
    expect(c.extent.para, 0);
  });
}
