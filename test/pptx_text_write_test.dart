import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 20 / SL1 — slayt metni yazımı: `\n` → `a:br`, `a:t`'siz paragrafa
/// yazılan metin kaydedilir, el değmemiş paragrafın karışık biçimi korunur.
PptxEditor _deck() => PptxEditor.parse(
    PptxWriter.build(const [SlideDraft('Başlık', ['bir', 'iki'])]));

PptxParagraph _para(PptxEditor e, String text) =>
    e.slides.first.paragraphs.firstWhere((p) => p.text == text);

void main() {
  test('çok satırlı metin a:br ile yazılır ve geri okunur', () {
    final e = _deck();
    final slide = e.slides.first;
    e.updateParagraph(slide, _para(e, 'bir'), 'satır 1\nsatır 2');
    final back = PptxEditor.parse(e.save());
    final p = back.slides.first.paragraphs
        .firstWhere((p) => p.text.startsWith('satır 1'));
    expect(p.text, 'satır 1\nsatır 2');
    expect(p.element.findElements('a:br'), hasLength(1));
    expect(p.element.findAllElements('a:t').map((t) => t.innerText),
        isNot(contains(contains('\n'))));
  });

  test('a:t\'si olmayan (boş) paragrafa yazılan metin kaydedilir', () {
    final e = _deck();
    final slide = e.slides.first;
    final para = _para(e, 'iki');
    para.element.children.removeWhere(
        (n) => n is XmlElement && n.name.qualified == 'a:r');
    para.text = '';
    // Okuyucu bu paragrafı boş görür; kullanıcı yazar.
    e.updateParagraph(slide, para, 'yeni yazı');
    final back = PptxEditor.parse(e.save());
    expect(back.slides.first.paragraphs.map((p) => p.text),
        contains('yeni yazı'));
  });

  test('el değmemiş paragrafın ikinci run\'ı kayıtta boşaltılmaz', () {
    final e = _deck();
    final para = _para(e, 'bir');
    final run = para.element.findElements('a:r').first;
    final second = run.copy();
    second.findAllElements('a:t').first.children
      ..clear()
      ..add(XmlText(' kalın'));
    para.element.children.insert(para.element.children.indexOf(run) + 1,
        second);
    final reparsed = PptxEditor.parse(e.save());
    // İlk kayıt bu paragrafı ilk okumadaki "bir" metniyle bilir; ikinci run
    // XML'de durmalı (eski kod her kayıtta onu boşaltıyordu).
    final p = reparsed.slides.first.paragraphs
        .firstWhere((p) => p.text.startsWith('bir'));
    expect(p.text, 'bir kalın');
    expect(p.element.findAllElements('a:t').map((t) => t.innerText),
        ['bir', ' kalın']);
  });
}
