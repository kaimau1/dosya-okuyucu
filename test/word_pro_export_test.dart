import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_fonts.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_layout_ops.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_pdf.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_style_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'word_pro_layout_test.dart' show testFonts;

/// Faz 37 madde 7 — dışa aktarım kalitesi: yazı tipi gömme, bölüm sonu,
/// üst/alt bilgi + sayfa alanı.
Uint8List _fx(String n) =>
    File('test/fixtures/office/$n.docx').readAsBytesSync();

Uint8List _apply(Uint8List b, DocxOp op) {
  final pkg = DocxPackage.open(b);
  op(pkg);
  return pkg.save();
}

int _pages(Uint8List p) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(p)).length;

void main() {
  test('odttf gizleme: GUID anahtarı ters bayt sırası, XOR iki kez = özgün', () {
    final font = Uint8List.fromList(List.generate(64, (i) => i));
    const guid = '{00112233-4455-6677-8899-AABBCCDDEEFF}';
    final o = DocxFonts.obfuscate(font, guid);
    expect(o[0], 0x00 ^ 0xFF);
    expect(o[15], 15 ^ 0x00);
    expect(o[16], 16 ^ 0xFF);
    expect(o.sublist(32), font.sublist(32));
    expect(DocxFonts.obfuscate(o, guid), font);
  });

  test('gömme: fontTable + odttf + settings; Calibri → Carlito', () {
    final out = _apply(_fx('stiller_basliklar'),
        DocxFonts.embed(testFonts().files, seed: 7));
    final pkg = DocxPackage.open(out);
    final ft = pkg.read('word/fontTable.xml')!.rootElement;
    final embeds = ft.descendantElements.where((e) => e.name.local.startsWith('embed')).toList();
    expect(embeds, isNotEmpty);
    for (final e in embeds) {
      final id = e.getAttribute('r:id')!;
      final rels = pkg.read('word/_rels/fontTable.xml.rels')!.rootElement;
      final target = rels.childElements.firstWhere((r) => r.getAttribute('Id') == id).getAttribute('Target')!;
      final odttf = pkg.bytesOf('word/$target')!;
      // Çözülen baş 4 bayt TrueType imzası (00 01 00 00).
      final plain = DocxFonts.obfuscate(Uint8List.fromList(odttf), e.getAttribute('w:fontKey')!);
      expect(plain.sublist(0, 4), [0, 1, 0, 0]);
    }
    expect(kid(pkg.read('word/settings.xml')!.rootElement, 'embedTrueTypeFonts'), isNotNull);
    expect(DocxFonts.usedFonts(pkg).map((f) => f.toLowerCase()), isNot(contains('calibri')));
    expect(DocxDocument.parse(out).paras, isNotEmpty);
  });

  test('PDF: yeni sayfa bölüm sonu yeni sayfa, sürekli bölüm aynı sayfa', () async {
    final b = _fx('stiller_basliklar');
    final base = _pages(await DocxPdf.render(b, fonts: testFonts()));
    final next = _apply(b, DocxLayoutOps.sectionBreak(0, 'nextPage'));
    expect(_pages(await DocxPdf.render(next, fonts: testFonts())), base + 1);
    final cont = _apply(b, DocxLayoutOps.sectionBreak(0, 'continuous'));
    expect(_pages(await DocxPdf.render(cont, fonts: testFonts())), base);
  });

  test('üst/alt bilgi metni + PAGE alanı yer tutucusu', () {
    final pkg = DocxPackage.open(_fx('stiller_basliklar'));
    pkg.putXml('word/footer9.xml', XmlDocument.parse(
        '<w:ftr xmlns:w="$kW"><w:p><w:r><w:t>Sayfa </w:t></w:r>'
        '<w:fldSimple w:instr=" PAGE "><w:r><w:t>1</w:t></w:r></w:fldSimple>'
        '<w:r><w:t> / </w:t></w:r><w:fldSimple w:instr="NUMPAGES"><w:r><w:t>3</w:t></w:r></w:fldSimple></w:p></w:ftr>'));
    final id = pkg.relate(
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer', 'footer9.xml');
    final s = pkg.bodySectPr;
    s.children.removeWhere((n) => n is XmlElement && n.name.local == 'footerReference');
    s.children.insert(0, w('footerReference', attrs: {'type': 'default', 'r:id': id}));
    final t = DocxPdf.headerFooterText(pkg, 'footerReference');
    expect(t, 'Sayfa {p} / {n}');
  });
}
