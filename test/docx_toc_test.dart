import 'dart:typed_data';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_insert_pro.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_paginator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/docx_synth.dart';

/// B9 m.2 — İçindekiler oluştur/güncelle: Başlık 1–3 → `w:sdt` içinde
/// `TOC \o "1-3" \h` alanı, `_Toc` yer imleri, köprü + PAGEREF sayfa no;
/// ikinci kez = yerinde güncelleme (tek denetim, yer imi çoğalmaz).

String _h(int level, String text) => synthP(text,
    pPr: '<w:pStyle w:val="Heading$level"/><w:outlineLvl w:val="${level - 1}"/>');

final _base = synthDocx([
  synthP('Önsöz metni'),
  _h(1, 'Giriş'),
  synthP('Gövde'),
  _h(2, 'Alt bölüm'),
  _h(3, 'Ayrıntı'),
  _h(4, 'Dördüncü düzey'),
].join());

/// Ekranın yaptığı gibi: editör modelinden girdiler (sayfa tahmini ile).
List<DocxTocEntry> _entries(Uint8List b) {
  final d = DocxDocument.parse(b);
  final pages = DocxPaginator().layout(d.paras);
  return [
    for (var i = 0; i < d.paras.length; i++)
      if (!d.paras[i].opaque &&
          d.paras[i].look.headingLevel >= 1 &&
          d.paras[i].look.headingLevel <= 3 &&
          wordTocText(d.paras[i]).isNotEmpty)
        (
          para: i,
          level: d.paras[i].look.headingLevel,
          text: wordTocText(d.paras[i]),
          page: pages[i] + 1,
        ),
  ];
}

Uint8List _toc(Uint8List b, {int at = 0}) {
  final pkg = DocxPackage.open(b);
  DocxInsertPro.toc(_entries(b), at: at)(pkg);
  return pkg.save();
}

XmlDocument _xml(List<int> b) => XmlDocument.parse(synthPart(b, 'word/document.xml'));

Iterable<XmlElement> _all(XmlDocument x, String q) => x.findAllElements(q);

void main() {
  test('oluştur: denetim + TOC alanı + köprülü girdiler + yer imleri', () {
    final out = _toc(_base);
    final x = _xml(out);
    final body = x.findAllElements('w:body').first;
    expect(body.childElements.first.name.qualified, 'w:sdt');
    expect(_all(x, 'w:docPartGallery').single.getAttribute('w:val'), 'Table of Contents');
    final instr = _all(x, 'w:instrText').map((e) => e.innerText.trim()).toList();
    expect(instr.first, r'TOC \o "1-3" \h \z \u');
    final links = _all(x, 'w:hyperlink').toList();
    expect(links.map((l) => l.findAllElements('w:t').first.innerText),
        ['Giriş', 'Alt bölüm', 'Ayrıntı']);
    // Her köprünün hedefi başlıktaki yer imi; PAGEREF aynı ada.
    final marks = {
      for (final b in _all(x, 'w:bookmarkStart'))
        b.getAttribute('w:name')!: (b.parent as XmlElement).innerText,
    };
    for (final l in links) {
      final name = l.getAttribute('w:anchor')!;
      expect(name, startsWith('_Toc'));
      expect(marks[name], l.findAllElements('w:t').first.innerText);
      expect(instr, contains('PAGEREF $name \\h'));
    }
    // Alan dengeli: begin sayısı = end sayısı.
    final chars = _all(x, 'w:fldChar').map((e) => e.getAttribute('w:fldCharType')).toList();
    expect(chars.where((c) => c == 'begin').length, chars.where((c) => c == 'end').length);
    // Sağa yaslı noktalı sekme; stiller kuruldu.
    expect(_all(x, 'w:tab').any((t) => t.getAttribute('w:leader') == 'dot'), isTrue);
    final st = synthPart(out, 'word/styles.xml');
    for (final id in ['TOCHeading', 'TOC1', 'TOC2', 'TOC3']) {
      expect(st, contains('w:styleId="$id"'));
    }
  });

  test('editörde: başlık listelenmez, girdiler okunur, kayıt kayıpsız', () {
    final out = _toc(_base);
    final d = DocxDocument.parse(out);
    // TOC başlığı (anahat dışı) başlık sayılmaz → tekrar İçindekiler'e girmez.
    expect(_entries(out).map((e) => e.text), ['Giriş', 'Alt bölüm', 'Ayrıntı']);
    final shown = d.paras.map(wordTocText).join(' | ');
    expect(shown, contains('Giriş'));
    expect(shown, contains('Alt bölüm'));
    expect(synthPart(d.save(), 'word/document.xml'), synthPart(out, 'word/document.xml'));
  });

  test('güncelle: yerinde, tek denetim, yeni başlık eklenir, yer imi çoğalmaz', () {
    final once = _toc(_base);
    // Belge sonuna yeni başlık (paket düzeyinde).
    final pkg = DocxPackage.open(once);
    pkg.insertAfterPara(pkg.modelParagraphs().length - 1, [
      XmlDocument.parse('<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
              '<w:pPr><w:pStyle w:val="Heading1"/><w:outlineLvl w:val="0"/></w:pPr>'
              '<w:r><w:t>Sonuç</w:t></w:r></w:p>')
          .rootElement
          .copy(),
    ]);
    final grown = pkg.save();
    final twice = _toc(grown, at: 3);
    final x = _xml(twice);
    expect(_all(x, 'w:sdt').length, 1);
    expect(_all(x, 'w:hyperlink').map((l) => l.findAllElements('w:t').first.innerText),
        ['Giriş', 'Alt bölüm', 'Ayrıntı', 'Sonuç']);
    final giris = _all(x, 'w:p').firstWhere(
        (p) => p.parentElement?.name.local == 'body' && p.innerText == 'Giriş');
    expect(giris.findElements('w:bookmarkStart').length, 1);
    // Denetim yerinde kaldı (gövdenin başında).
    expect(x.findAllElements('w:body').first.childElements.first.name.local, 'sdt');
  });

  test('denetimsiz eski TOC alanı yerinde güncellenir', () {
    const old = '<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:instrText xml:space="preserve"> TOC \\o "1-3" </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Eski girdi</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Eski ikinci</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>';
    final b = synthDocx(old + _h(1, 'Giriş') + _h(2, 'Alt bölüm'));
    final x = _xml(_toc(b));
    expect(_all(x, 'w:sdt'), isEmpty);
    expect(x.innerText, isNot(contains('Eski')));
    expect(_all(x, 'w:hyperlink').length, 2);
    final chars = _all(x, 'w:fldChar').map((e) => e.getAttribute('w:fldCharType')).toList();
    expect(chars.where((c) => c == 'begin').length, chars.where((c) => c == 'end').length);
  });

  test('imleç paragrafının önüne konur', () {
    final x = _xml(_toc(_base, at: 2));
    final kids = x.findAllElements('w:body').first.childElements.toList();
    expect(kids[0].innerText, 'Önsöz metni');
    expect(kids[1].innerText, 'Giriş');
    expect(kids[2].name.local, 'sdt');
  });
}
