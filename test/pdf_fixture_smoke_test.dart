import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pdf_form.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_text_stamp.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pdf_edit_helper.dart';
import 'support/pdf_fixtures.dart';

/// **PDF duman testleri** (Faz 8): örnek setin HER belgesi için
/// aç → düzenle → kaydet → yeniden aç → içerik doğrula.
///
/// "Yeniden aç" iki bağımsız okuyucuyla yapılır: bizim ayrıştırıcımız
/// (`PdfPageEdit.outline` — düzenleyicinin gördüğü) ve Syncfusion'ın metin
/// çıkarıcısı (başka bir uygulamanın göreceğine yakın). İkisi de yeni metni
/// görmeli, eskisini görmemeli.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String outlineText(List<int> pdf, [int page = 0]) => PdfPageEdit.outline(
        pdf,
        page,
      ).paragraphs.map((p) => p.text).join('\n');

  group('metinli belge', () {
    test('paragraf değişir, sayfa sayısı ve diğer satır korunur', () {
      final pdf = PdfFixtures.textual();
      expect(outlineText(pdf), contains('Genel Rapor 2026'));

      final out = replaceInParagraph(pdf, oldText: '2026', newText: '2027');

      expect(outlineText(out), contains('Genel Rapor 2027'));
      expect(outlineText(out), contains('Toplam tutar 1500 TL'));
      expect(extractText(out), contains('2027'));
      expect(extractText(out), isNot(contains('2026')));
      expect(pageCountOf(out), 1);
      // Özgün baytlar dosyanın başında aynen durur (artımlı güncelleme).
      expect(out.sublist(0, pdf.length), pdf);
    });
  });

  group('Türkçe karakterli belge (/ToUnicode yok, /Differences + AGL)', () {
    test('okuma: glif adlarından doğru harfler', () {
      expect(outlineText(PdfFixtures.turkish()),
          contains('İstanbul Şube Müdürlüğü'));
    });

    test('düzenleme: Türkçe harf yazılır, yeniden açınca aynı okunur', () {
      final out = replaceInParagraph(PdfFixtures.turkish(),
          oldText: 'Şube', newText: 'Bölge');
      expect(outlineText(out), contains('İstanbul Bölge Müdürlüğü'));
      expect(outlineText(out), contains('Ağaç ışık çiçek'));
    });
  });

  group('taranmış belge (metin katmanı yok)', () {
    test('paragraf motoru boş döner → "sayfaya yazı ekle" yedeği çalışır',
        () async {
      final pdf = PdfFixtures.scanned();
      expect(PdfPageEdit.outline(pdf, 0).paragraphs, isEmpty);

      final out = await PdfTextStamp.add(
          bytes: pdf, pageIndex: 0, x: 60, y: 80, text: 'Ek not: onaylandı');

      expect(extractText(out), contains('Ek not: onaylandı'));
      expect(pageCountOf(out), 1);
    });

    test('boş yazı belgeyi değiştirmez', () async {
      final pdf = PdfFixtures.scanned();
      final out = await PdfTextStamp.add(
          bytes: pdf, pageIndex: 0, x: 10, y: 10, text: '   ');
      expect(out, same(pdf));
    });
  });

  group('parolalı belge', () {
    test('parola kaldırılınca düzenlenir, kaydedilen belge parolasız açılır',
        () async {
      final locked = await PdfFixtures.passwordProtected('1234');
      expect(() => PdfPageEdit.outline(locked, 0),
          throwsA(isA<PdfPageRefused>()));

      final open =
          await PdfTools.removePassword(locked, currentPassword: '1234');
      final out = replaceInParagraph(open, oldText: '1500', newText: '1750');

      expect(extractText(out), contains('1750'));
      expect(extractText(out), isNot(contains('1500')));
    });
  });

  group('formlu belge', () {
    test('alanlar doldurulur, Türkçe değer yeniden açınca okunur', () async {
      final pdf = await PdfFixtures.form();
      final fields = PdfFormFiller.readSync(pdf);
      expect(fields.map((f) => f.name), containsAll(['ad', 'sehir', 'onay']));

      final out = PdfFormFiller.fillSync(
          pdf, {'ad': 'Ayşe', 'sehir': 'İzmir', 'onay': 'true'},
          fontData: File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync());

      final again = {
        for (final f in PdfFormFiller.readSync(out)) f.name: f.value,
      };
      expect(again['ad'], 'Ayşe');
      expect(again['sehir'], 'İzmir');
      expect(again['onay'], 'true');
    });
  });

  group('döndürülmüş sayfa', () {
    for (final degrees in [90, 180, 270]) {
      test('/Rotate $degrees: paragraf düzenlenir', () {
        final out = replaceInParagraph(PdfFixtures.rotated(degrees),
            oldText: 'Yatay', newText: 'Dikey');
        expect(outlineText(out), contains('Dikey sayfa metni'));
      });

      test('/Rotate $degrees: yazı ekle görünen köşeye düşer', () async {
        final pdf = PdfFixtures.rotated(degrees);
        final out = await PdfTextStamp.add(
            bytes: pdf, pageIndex: 0, x: 30, y: 30, text: 'Not');
        expect(extractText(out), contains('Not'));
      });
    }

    test('görünen → ham nokta dönüşümü (dört açı)', () {
      // Ham sayfa 400×600; görünen sayfada sol-üstten (10, 20).
      const v = Offset(10, 20);
      expect(PdfTextStamp.viewToRaw(0, 400, 600, v), const Offset(10, 20));
      // 90°: görünen sol-üst köşe, hamın SOL-ALT köşesidir.
      expect(PdfTextStamp.viewToRaw(1, 400, 600, v), const Offset(20, 590));
      expect(PdfTextStamp.viewToRaw(2, 400, 600, v), const Offset(390, 580));
      expect(PdfTextStamp.viewToRaw(3, 400, 600, v), const Offset(380, 10));
    });
  });

  group('CropBox kaydırılmış sayfa', () {
    test('ölçü CropBox\'tan okunur, paragraf düzenlenir', () {
      final pdf = PdfFixtures.cropped();
      final outline = PdfPageEdit.outline(pdf, 0);
      expect(outline.pageWidth, 320);
      expect(outline.pageHeight, 500);

      final out =
          replaceInParagraph(pdf, oldText: 'Kirpilmis', newText: 'Kesilmis');
      expect(outlineText(out), contains('Kesilmis sayfa'));
    });

    test('yazı ekle GÖRÜNEN sayfanın köşesine göre konumlanır', () async {
      // Ölçülen (Faz 8): Syncfusion'ın çizim kökeni CropBox'ın sol-üst
      // köşesi mi, MediaBox'ınki mi? Eklenen yazının ham koordinatı bizim
      // ayrıştırıcımızla okunur ve beklenen yere bakılır.
      final pdf = PdfFixtures.cropped();
      final out = await PdfTextStamp.add(
          bytes: pdf, pageIndex: 0, x: 20, y: 30, text: 'Damga', size: 10);
      final text = extractText(out);
      expect(text, contains('Damga'));
      final lines = extractTextLines(out);
      final stamp = lines.firstWhere((l) => l.text.contains('Damga'));
      // Görünen sayfada sol kenardan 20 nokta (±2 — glif yan boşluğu).
      expect(stamp.bounds.left, closeTo(20, 2));
      expect(stamp.bounds.top, closeTo(30, 4));
      // Bağımsız ikinci ölçüm (bizim ayrıştırıcı, HAM y-yukarı uzay):
      // CropBox [40 60 360 560] → görünen (20, 30) = ham (60, ~530).
      // Yani Syncfusion'ın çizim kökeni CropBox'ın sol-üst köşesi; kaydırma
      // eklemeye gerek YOK (KALANLAR'daki "doğrulanmadı" maddesi kapandı).
      final p = PdfPageEdit.outline(out, 0)
          .paragraphs
          .firstWhere((p) => p.text.contains('Damga'));
      expect(p.left, closeTo(60, 1));
      expect(p.top, closeTo(530, 3));
    });

    test('/Rotate 90: eklenen yazı ekranda soldan sağa okunur', () async {
      // Ham 400×600, saat yönünde 90° gösterilir. Görünen (20, 30) noktası
      // ham y-yukarı uzayda (≈30, 20)'dir ve yazı ham +y yönünde (ekranda
      // sağa) ilerlemelidir.
      final out = await PdfTextStamp.add(
          bytes: PdfFixtures.rotated(90),
          pageIndex: 0,
          x: 20,
          y: 30,
          text: 'Damga',
          size: 10);
      final p = PdfPageEdit.outline(out, 0)
          .paragraphs
          .firstWhere((p) => p.text.contains('Damga'));
      expect(p.bottom, closeTo(20, 1));
      expect(p.top - p.bottom, greaterThan(p.right - p.left));
    });
  });

  group('uzun belge (320 sayfa)', () {
    test('300. sayfa düzenlenir, diğer sayfalar ve sayı korunur', () {
      final pdf = PdfFixtures.long();
      expect(pageCountOf(pdf), 320);

      final out = replaceInParagraph(pdf,
          pageIndex: 299, oldText: 'Sayfa 300', newText: 'Bolum 300');

      expect(pageCountOf(out), 320);
      expect(outlineText(out, 299), contains('Bolum 300 metni'));
      expect(outlineText(out, 298), contains('Sayfa 299 metni'));
      expect(outlineText(out, 0), contains('Sayfa 1 metni'));
    });
  });
}
