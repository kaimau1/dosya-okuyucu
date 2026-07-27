import 'dart:convert';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pdf_objects.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_xobject.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Sayfa nesneleri (resim/logo/QR) ve filigran temizleme.**
///
/// Kullanıcı isteği (2026-07-27): "pdfler üzerindeki görüntü barkod qr resim
/// simge arma vs ne varsa onlarda düzenlenebilmeli silinebilmeli boyutu
/// değiştirilebilmeli yeri değiştirilebilmeli" + "bazı pdflerde arka plan
/// yazıları oluyor onları kaldırma seçeneği olmalı".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sayfadaki görseller', () {
    // Bir görsel her zaman BİRİM KAREyi doldurur; nereye/ne kadar büyük
    // çizileceğini `cm` matrisi söyler.
    const content = 'q 100 0 0 50 200 400 cm /Im1 Do Q '
        'q 40 0 0 40 20 20 cm /Im2 Do Q';

    List<PdfPageObject> objects() => findPageObjects(
          [latin1.encode(content)],
          imageNames: {'Im1', 'Im2'},
        );

    test('konum ve boyut cm matrisinden okunur', () {
      final list = objects();
      expect(list, hasLength(2));
      expect(list.first.name, 'Im1');
      expect(list.first.left, closeTo(200, 1e-6));
      expect(list.first.bottom, closeTo(400, 1e-6));
      expect(list.first.width, closeTo(100, 1e-6));
      expect(list.first.height, closeTo(50, 1e-6));
      expect(list.first.rotated, isFalse);
    });

    test('görüntü olmayan kaynaklar (form XObject) listelenmez', () {
      // Form XObject'in çizim alanı birim kare DEĞİL kendi /BBox'ı; kutusunu
      // yanlış hesaplar, kullanıcıya yanlış tutamaç gösterirdik.
      final list = findPageObjects([latin1.encode(content)],
          imageNames: {'Im1'});
      expect(list.map((o) => o.name), ['Im1']);
    });

    test('silme yalnız çizimi çıkarır, q/Q dengesi bozulmaz', () {
      final out = latin1.decode(
          deleteObjectDraw(latin1.encode(content), objects().first));
      expect(out, isNot(contains('/Im1 Do')));
      expect(out, contains('/Im2 Do'));
      // Yığın dengesi: q sayısı = Q sayısı.
      expect('q'.allMatches(out).length, 2);
      expect('Q'.allMatches(out).length, 2);
    });

    test('taşıma/boyutlandırma düzeltme cm ekler, sonuç istenen kutudur', () {
      final moved = placeObject(
        latin1.encode(content),
        objects().first,
        left: 50,
        bottom: 100,
        width: 200,
        height: 25,
      );
      final after = findPageObjects([moved], imageNames: {'Im1', 'Im2'});
      expect(after.first.left, closeTo(50, 1e-6));
      expect(after.first.bottom, closeTo(100, 1e-6));
      expect(after.first.width, closeTo(200, 1e-6));
      expect(after.first.height, closeTo(25, 1e-6));
      // İkinci görsel etkilenmemeli (düzeltme q/Q içinde kaldı).
      expect(after.last.left, closeTo(20, 1e-6));
      expect(after.last.width, closeTo(40, 1e-6));
    });
  });

  group('filigran / arka plan', () {
    /// İki sayfalık belge: ikisinde de "KOPYADIR" damgası, ayrıca her
    /// sayfanın kendine ait metni var.
    List<int> buildPdf() {
      final out = BytesBuilder();
      final offsets = <int, int>{};
      void add(int number, String body) {
        offsets[number] = out.length;
        out.add(latin1.encode('$number 0 obj\n$body\nendobj\n'));
      }

      final widths = List.filled(95, '500').join(' ');
      String page(String own) => 'BT /F1 10 Tf 1 0 0 1 50 700 Tm ($own) Tj '
          '1 0 0 1 50 400 Tm (KOPYADIR) Tj ET';

      final first = page('Birinci sayfa');
      final second = page('Ikinci sayfa');

      out.add(latin1.encode('%PDF-1.4\n'));
      add(1, '<< /Type /Catalog /Pages 2 0 R >>');
      add(2, '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>');
      add(
          3,
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 800] '
          '/Resources << /Font << /F1 7 0 R >> >> /Contents 5 0 R >>');
      add(
          4,
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 800] '
          '/Resources << /Font << /F1 7 0 R >> >> /Contents 6 0 R >>');
      add(5, '<< /Length ${first.length} >>\nstream\n$first\nendstream');
      add(6, '<< /Length ${second.length} >>\nstream\n$second\nendstream');
      add(
          7,
          '<< /Type /Font /Subtype /TrueType /BaseFont /Arial '
          '/Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 126 '
          '/Widths [$widths] >>');

      final xrefOffset = out.length;
      final xref = StringBuffer('xref\n0 8\n0000000000 65535 f \n');
      for (var i = 1; i <= 7; i++) {
        xref.write('${offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
      }
      xref
        ..write('trailer\n<< /Size 8 /Root 1 0 R >>\n')
        ..write('startxref\n$xrefOffset\n%%EOF\n');
      out.add(latin1.encode(xref.toString()));
      return out.takeBytes();
    }

    test('her sayfada yinelenen metin aday olarak listelenir', () {
      final items = PdfPageEdit.backgroundItems(buildPdf());
      expect(items.map((i) => i.label), contains('KOPYADIR'));
      final stamp = items.firstWhere((i) => i.label == 'KOPYADIR');
      expect(stamp.pageCount, 2);
      expect(stamp.drawCount, 2);
    });

    test('sayfaya özgü metin aday DEĞİLDİR (gerçek içerik silinmesin)', () {
      final items = PdfPageEdit.backgroundItems(buildPdf());
      expect(items.map((i) => i.label), isNot(contains('Birinci sayfa')));
      expect(items.map((i) => i.label), isNot(contains('Ikinci sayfa')));
    });

    test('kaldırma damgayı her sayfadan siler, içeriğe dokunmaz', () {
      final pdf = buildPdf();
      final items = PdfPageEdit.backgroundItems(pdf);
      final stamp = items.firstWhere((i) => i.label == 'KOPYADIR');

      final out = PdfPageEdit.removeBackground(pdf, {stamp.index});
      final file = PdfFile.parse(out);
      for (var p = 0; p < 2; p++) {
        final text = latin1.decode(
            file.decodeStream(file.pageContents(p).first),
            allowInvalid: true);
        expect(text, isNot(contains('KOPYADIR')));
      }
      final firstPage = latin1.decode(
          file.decodeStream(file.pageContents(0).first),
          allowInvalid: true);
      expect(firstPage, contains('Birinci sayfa'));
    });

    test('özgün baytlar korunur (değişiklik dosyanın SONUNA eklenir)', () {
      final pdf = buildPdf();
      final items = PdfPageEdit.backgroundItems(pdf);
      final stamp = items.firstWhere((i) => i.label == 'KOPYADIR');
      final out = PdfPageEdit.removeBackground(pdf, {stamp.index});
      expect(out.length, greaterThan(pdf.length));
      expect(out.sublist(0, pdf.length), equals(pdf));
    });

    test('seçim boşsa reddedilir', () {
      expect(() => PdfPageEdit.removeBackground(buildPdf(), const {}),
          throwsA(isA<PdfPageRefused>()));
    });
  });
}
