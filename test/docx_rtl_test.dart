import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _docx(String body) {
  final doc =
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$body</w:body></w:document>';
  final archive = Archive();
  final data = utf8.encode(doc);
  archive.addFile(ArchiveFile('word/document.xml', data.length, data));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  group('paragraf yönü (w:pPr/w:bidi)', () {
    test('bidi olan paragraf sağdan sola, olmayan soldan sağa', () {
      final e = DocxEditor.parse(_docx(
        '<w:p><w:pPr><w:bidi/></w:pPr><w:r><w:t>مرحبا</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Merhaba</w:t></w:r></w:p>',
      ));
      expect(e.paragraphs[0].rtl, isTrue);
      expect(e.paragraphs[1].rtl, isFalse);
    });

    test('w:bidi w:val="0" KAPALI sayılır', () {
      final e = DocxEditor.parse(_docx(
        '<w:p><w:pPr><w:bidi w:val="0"/></w:pPr><w:r><w:t>x</w:t></w:r></w:p>',
      ));
      expect(e.paragraphs.single.rtl, isFalse);
    });

    test('bölüm sonu taşıyan paragraf, BÖLÜMÜN yönünü kendine almaz', () {
      // `w:p > w:pPr > w:sectPr > w:bidi` bölümün yönüdür. Paragrafın kendi
      // yönü sanılırsa soldan sağa bir paragraf sırf bölüm sonunu taşıdığı
      // için sağa yaslanırdı.
      final e = DocxEditor.parse(_docx(
        '<w:p><w:pPr><w:sectPr><w:bidi/></w:sectPr></w:pPr>'
        '<w:r><w:t>Soldan sağa</w:t></w:r></w:p>',
      ));
      expect(e.paragraphs.single.rtl, isFalse);
    });

    test('yön save sonrası KORUNUR (yazma yolu paragrafa dokunmuyor)', () {
      final e = DocxEditor.parse(_docx(
        '<w:p><w:pPr><w:bidi/></w:pPr><w:r><w:t>مرحبا</w:t></w:r></w:p>',
      ));
      e.paragraphs.single.text = 'أهلا';
      final again = DocxEditor.parse(e.save());
      expect(again.paragraphs.single.text, 'أهلا');
      expect(again.paragraphs.single.rtl, isTrue);
    });
  });

  group('belge yönü (w:sectPr/w:bidi)', () {
    test('bölüm bidi ise belge sağdan sola', () {
      final e = DocxEditor.parse(_docx(
        '<w:p><w:r><w:t>x</w:t></w:r></w:p><w:sectPr><w:bidi/></w:sectPr>',
      ));
      expect(e.rightToLeft, isTrue);
    });

    test('bölüm işareti yoksa paragraf ÇOĞUNLUĞUNA bakılır', () {
      // Word'ün Arapça şablonlarında w:bidi her paragrafta durur ama
      // sectPr'de bulunmayabilir.
      final rtlMajority = DocxEditor.parse(_docx(
        '<w:p><w:pPr><w:bidi/></w:pPr><w:r><w:t>مرحبا</w:t></w:r></w:p>'
        '<w:p><w:pPr><w:bidi/></w:pPr><w:r><w:t>أهلا</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Merhaba</w:t></w:r></w:p>',
      ));
      expect(rtlMajority.rightToLeft, isTrue);

      final ltrMajority = DocxEditor.parse(_docx(
        '<w:p><w:pPr><w:bidi/></w:pPr><w:r><w:t>مرحبا</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Merhaba</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Selam</w:t></w:r></w:p>',
      ));
      expect(ltrMajority.rightToLeft, isFalse);
    });

    test('BOŞ paragraflar çoğunluğu bozmaz', () {
      // Word belgeleri metinsiz paragraflarla doludur; sayıya katılsalardı
      // Arapça bir belge "çoğunluk soldan sağa" görünürdü.
      final e = DocxEditor.parse(_docx(
        '<w:p><w:pPr><w:bidi/></w:pPr><w:r><w:t>مرحبا</w:t></w:r></w:p>'
        '<w:p/><w:p/><w:p><w:r><w:t>   </w:t></w:r></w:p>',
      ));
      expect(e.rightToLeft, isTrue);
    });

    test('metinsiz belgede yön soldan sağa (varsayılan)', () {
      expect(DocxEditor.parse(_docx('<w:p/>')).rightToLeft, isFalse);
    });
  });

  group('hizalama', () {
    test('açık w:jc ile varsayılan ayırt edilir', () {
      final e = DocxEditor.parse(_docx(
        '<w:p><w:pPr><w:jc w:val="left"/></w:pPr><w:r><w:t>a</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>b</w:t></w:r></w:p>',
      ));
      // İkisinin de `align`i 'left'; ayrım YALNIZ hasExplicitAlign'da.
      // Sağdan sola bir paragrafta yazılmamış hizalamanın karşılığı SAĞDIR.
      expect(e.paragraphs[0].align, 'left');
      expect(e.paragraphs[0].hasExplicitAlign, isTrue);
      expect(e.paragraphs[1].align, 'left');
      expect(e.paragraphs[1].hasExplicitAlign, isFalse);
    });
  });
}
