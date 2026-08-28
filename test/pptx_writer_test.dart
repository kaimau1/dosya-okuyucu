import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:dosya_okuyucu/services/text_to_slides.dart';

void main() {
  group('PDF/metin → gerçek .pptx', () {
    test('ürettiğimiz deste KENDİ okuyucumuzda açılıyor (gidiş-dönüş)', () {
      // Asıl kanıt bu: dosya yalnız "zip olarak açılıyor" değil, tam
      // okuyucumuzun beklediği master → layout → slide zincirine sahip.
      final bytes = PptxWriter.build(const [
        SlideDraft('Birinci başlık', ['madde bir', 'madde iki']),
        SlideDraft('İkinci başlık', ['tek madde']),
      ]);

      final editor = PptxEditor.parse(bytes);
      expect(editor.slides.length, 2);

      final all = editor.slides
          .expand((s) => s.paragraphs.map((p) => p.text))
          .toList();
      expect(all, contains('Birinci başlık'));
      expect(all, contains('madde bir'));
      expect(all, contains('madde iki'));
      expect(all, contains('İkinci başlık'));
      expect(all, contains('tek madde'));
    });

    test('slaytlar ÇİZİLEBİLİR bir görünüm üretiyor', () {
      final bytes =
          PptxWriter.build(const [SlideDraft('Başlık', ['bir', 'iki'])]);
      final editor = PptxEditor.parse(bytes);

      final view = editor.slides.single.view;
      expect(view, isNotNull, reason: 'görünüm yoksa slayt boş çizilir');
      // 16:9 — PowerPoint varsayılanı 960 × 540 punto.
      expect(view!.widthPt, closeTo(960, 0.5));
      expect(view.heightPt, closeTo(540, 0.5));
      // Başlık + gövde kutusu.
      expect(view.shapes.where((s) => s.hasText).length, 2);
    });

    test('paket zorunlu parçaların HEPSİNİ içeriyor', () {
      // Eksik bir layout/theme ilişkisi PowerPoint'te "onarılması gerekiyor"
      // uyarısı çıkarır; bizim okuyucumuz hoşgörülü olduğu için bu ancak
      // kullanıcının masaüstünde fark edilirdi.
      final archive =
          ZipDecoder().decodeBytes(PptxWriter.build(const [SlideDraft('a', [])]));
      final names = archive.files.map((f) => f.name).toSet();
      expect(
        names,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'ppt/presentation.xml',
          'ppt/_rels/presentation.xml.rels',
          'ppt/theme/theme1.xml',
          'ppt/slideMasters/slideMaster1.xml',
          'ppt/slideMasters/_rels/slideMaster1.xml.rels',
          'ppt/slideLayouts/slideLayout1.xml',
          'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
          'ppt/slides/slide1.xml',
          'ppt/slides/_rels/slide1.xml.rels',
        ]),
      );
    });

    test('her parça GEÇERLİ XML ve slayt kimlikleri 256+', () {
      final archive = ZipDecoder()
          .decodeBytes(PptxWriter.build(const [SlideDraft('a', []), SlideDraft('b', [])]));
      for (final file in archive.files) {
        expect(
          () => XmlDocument.parse(String.fromCharCodes(file.content as List<int>)),
          returnsNormally,
          reason: '${file.name} bozuk XML',
        );
      }
      final pres = XmlDocument.parse(String.fromCharCodes(
          archive.files.firstWhere((f) => f.name == 'ppt/presentation.xml').content
              as List<int>));
      final ids = pres
          .findAllElements('p:sldId')
          .map((e) => int.parse(e.getAttribute('id')!));
      // ECMA-376: 256 alt sınır. Küçük değer dosyayı geçersiz yapar.
      expect(ids.every((id) => id >= 256), isTrue);
    });

    test('XML kaçışı: & ve < içeren metin dosyayı BOZMUYOR', () {
      // PDF metninde "Ar-Ge & Tasarım <2026>" gibi diziler geçer; kaçırılmazsa
      // sunum hiç açılmaz.
      final bytes = PptxWriter.build(
          const [SlideDraft('Ar-Ge & Tasarım', ['<2026> "hedef"'])]);
      final editor = PptxEditor.parse(bytes);
      final all =
          editor.slides.expand((s) => s.paragraphs.map((p) => p.text)).toList();
      expect(all, contains('Ar-Ge & Tasarım'));
      expect(all, contains('<2026> "hedef"'));
    });

    test('konuşmacı notu yazılıyor ve KENDİ okuyucumuz geri okuyor', () {
      final bytes = PptxWriter.build(const [
        SlideDraft('Başlık', ['madde'], notes: 'Burada şunu anlat.'),
        SlideDraft('Notsuz', ['madde']),
      ]);
      final editor = PptxEditor.parse(bytes);
      expect(editor.notesOf(editor.slides[0]).trim(), 'Burada şunu anlat.');
      expect(editor.notesOf(editor.slides[1]).trim(), '');

      // Notsuz slayt için notesSlide parçası HİÇ yazılmamalı (paket şişmesin).
      final names = ZipDecoder()
          .decodeBytes(bytes)
          .files
          .map((f) => f.name)
          .toSet();
      expect(names, contains('ppt/notesSlides/notesSlide1.xml'));
      expect(names, isNot(contains('ppt/notesSlides/notesSlide2.xml')));
      expect(names, contains('ppt/notesMasters/notesMaster1.xml'));
    });

    test('not YOKSA not parçaları hiç eklenmez', () {
      final names = ZipDecoder()
          .decodeBytes(PptxWriter.build(const [SlideDraft('a', ['b'])]))
          .files
          .map((f) => f.name)
          .toSet();
      expect(names.any((n) => n.contains('notes')), isFalse);
    });

    test('boş liste bile GEÇERLİ sunum üretir', () {
      // Sıfır slaytlı bir sunum PowerPoint'te geçersizdir.
      final editor = PptxEditor.parse(PptxWriter.build(const []));
      expect(editor.slides.length, 1);
    });
  });

  group('metni slaytlara bölme', () {
    test('açık ayraç varsa ONA uyulur', () {
      final slides = TextToSlides.split('Başlık A\nmadde\n---\nBaşlık B\nmadde2');
      expect(slides.length, 2);
      expect(slides[0].title, 'Başlık A');
      expect(slides[1].title, 'Başlık B');
    });

    test('ayraç yoksa boş satır blok sınırıdır', () {
      final slides = TextToSlides.split(
        'Giriş\nbirinci madde\nikinci madde\n\nSonuç\nson madde',
      );
      expect(slides.length, 2);
      expect(slides[0].title, 'Giriş');
      expect(slides[0].bullets, ['birinci madde', 'ikinci madde']);
      expect(slides[1].title, 'Sonuç');
    });

    test('tek satırlık uzun paragraf ÖNCEKİ slayta madde olur', () {
      // Yoksa her cümle için bir slayt açılır ve yüzlerce slayt çıkar.
      const long = 'Bu cümle yetmiş karakterden uzun olduğu için başlık '
          'sayılmaz ve bir öncekine madde olarak eklenmelidir.';
      final slides = TextToSlides.split('Konu\nilk madde\n\n$long');
      expect(slides.length, 1);
      expect(slides.single.bullets, ['ilk madde', long]);
    });

    test('altı maddeden sonrası AYNI başlıkla yeni slayta taşar', () {
      final bullets = List.generate(8, (i) => 'madde $i').join('\n');
      final slides = TextToSlides.split('Uzun konu\n$bullets');
      expect(slides.length, 2);
      expect(slides[0].bullets.length, TextToSlides.maxBullets);
      expect(slides[1].bullets.length, 2);
      // Devam slaytı başlığı tekrar eder — yoksa hangi konu sürüyor kaybolur.
      expect(slides[1].title, 'Uzun konu');
    });

    test('cümleyle başlayan blok başlıksız kalır (uydurma başlık yazılmaz)', () {
      final slides = TextToSlides.split(
          'Bu bir cümledir ve nokta ile biter, dolayısıyla başlık değildir.');
      expect(slides.single.title, '');
      expect(slides.single.bullets.length, 1);
    });

    test('boş metin slayt üretmez', () {
      expect(TextToSlides.split('   \n\n  '), isEmpty);
    });
  });
}
