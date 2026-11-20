import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf/pdf_form.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_text_blocks.dart';
import 'package:dosya_okuyucu/services/pdf_form_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 madde 9 — otomatik doldurma profili eşlemesi ve form oluşturma.
void main() {
  test('etiket eşleme: Türkçe/İngilizce, camelCase, öncelik', () {
    expect(PdfFormPro.matchKey('Adı Soyadı'), ProfileKey.fullName);
    expect(PdfFormPro.matchKey('SOYADI'), ProfileKey.lastName);
    expect(PdfFormPro.matchKey('Adı'), ProfileKey.firstName);
    expect(PdfFormPro.matchKey('firstName'), ProfileKey.firstName);
    expect(PdfFormPro.matchKey('E-posta adresi'), ProfileKey.email);
    expect(PdfFormPro.matchKey('İkametgâh Adresi'), ProfileKey.address);
    expect(PdfFormPro.matchKey('Cep Tel'), ProfileKey.phone);
    expect(PdfFormPro.matchKey('Posta Kodu'), ProfileKey.postalCode);
    expect(PdfFormPro.matchKey('Tarih'), ProfileKey.date);
    // Doğum tarihi BUGÜN olamaz → eşlenmez.
    expect(PdfFormPro.matchKey('Doğum Tarihi'), isNull);
    expect(PdfFormPro.matchKey('Açıklama'), isNull);
  });

  test('öneri: yalnız boş alanlar; ad soyad parçalardan kurulur', () {
    final s = PdfFormPro.suggest(
      [
        (name: 'f1', label: 'Ad Soyad', value: ''),
        (name: 'f2', label: 'E-posta', value: 'eski@ornek.com'),
        (name: 'f3', label: 'Tarih', value: ''),
      ],
      {ProfileKey.firstName: 'Ayşe', ProfileKey.lastName: 'Yılmaz',
        ProfileKey.email: 'yeni@ornek.com'},
      today: DateTime(2026, 11, 5),
    );
    expect(s, {'f1': 'Ayşe Yılmaz', 'f3': '05.11.2026'});
  });

  test('alan algılama: ____ ve ..... dizileri etiketli metin alanı olur',
      () async {
    final doc = PdfDocument();
    final g = doc.pages.add().graphics;
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    g.drawString('Ad Soyad: ______________', font,
        bounds: const Rect.fromLTWH(40, 40, 400, 20));
    g.drawString('E-posta ..................', font,
        bounds: const Rect.fromLTWH(40, 80, 400, 20));
    g.drawString('Sadece metin. Bitti.', font,
        bounds: const Rect.fromLTWH(40, 120, 400, 20));
    final bytes = await doc.save();
    doc.dispose();

    final found = PdfFormPro.detectFields(bytes);
    expect(found.map((f) => f.kind).toSet(), {NewFieldKind.text});
    expect(found.map((f) => f.name).toList(), ['Ad Soyad', 'E-posta']);
    final first = found.first.bounds;
    expect(first.left, greaterThan(80)); // etiketten sonra başlar
    // Yeni sayfanın 40 pt kenar boşluğu: y=40 çizim → sayfada ≈ 80.
    expect(first.top, inInclusiveRange(70, 100));
    expect(first.width, greaterThan(40));

    // Alan eklenince ikinci taramada aynı yer yeniden önerilmez.
    final withFields = await PdfFormPro.addFields(bytes, found);
    expect(PdfFormPro.detectFields(withFields), isEmpty);
  });

  test('çizgi/kutu sezgisi: boş çizgi, kare ve kutu alan olur; dolu hücre olmaz',
      () {
    PdfTextObjectInfo text(String s, double l, double b, double r, double t) =>
        PdfTextObjectInfo(
            index: 0,
            text: s,
            left: l,
            bottom: b,
            right: r,
            top: t,
            tfSize: 10,
            fontName: 'Helvetica',
            matrix: [1, 0, 0, 1, l, b],
            renderMode: 0);
    PdfPageItem path(double l, double b, double r, double t,
            {bool filled = false}) =>
        PdfPageItem(
            index: 1,
            type: 2,
            left: l,
            bottom: b,
            right: r,
            top: t,
            stroke: !filled,
            filled: filled,
            straight: true,
            fill: filled ? 0xFF000000 : 0);
    final c = PdfPageContent([
      text('Ad Soyad:', 40, 700, 100, 712),
      text('Onay', 60, 650, 90, 660),
      text('Dolu hücre', 50, 560, 120, 572),
    ], [
      path(110, 699, 300, 700), // yazı çizgisi
      path(40, 648, 52, 660), // onay kutusu
      path(40, 590, 300, 630), // boş kutu
      path(40, 550, 300, 580), // içinde metin var → atla
      path(40, 500, 52, 512, filled: true), // siyah kare (madde imi) → atla
      path(0, 0, 595, 1), // sayfa boyu çizgi → atla
    ], 595, 842);
    final f = PdfFormPro.fieldsFromShapes(0, c);
    expect(f.map((x) => x.kind).toList(),
        [NewFieldKind.text, NewFieldKind.checkbox, NewFieldKind.text]);
    expect(f.first.name, 'Ad Soyad');
    expect(f.first.bounds.bottom, closeTo(842 - 699, 0.01));
    expect(f[1].bounds.top, closeTo(842 - 660, 0.01));
  });

  test('form oluşturma: metin, onay, imza alanları okunur', () async {
    final doc = PdfDocument()..pages.add();
    final bytes = await doc.save();
    doc.dispose();
    final out = await PdfFormPro.addFields(bytes, const [
      NewFormField(0, Rect.fromLTWH(50, 50, 200, 20), NewFieldKind.text, 'Ad'),
      NewFormField(0, Rect.fromLTWH(50, 90, 14, 14), NewFieldKind.checkbox, 'Onay'),
      NewFormField(0, Rect.fromLTWH(50, 130, 160, 50), NewFieldKind.signature, 'Imza'),
      NewFormField(0, Rect.fromLTWH(50, 200, 200, 20), NewFieldKind.text, 'Ad'),
    ]);
    final fields = PdfFormFiller.readSync(out);
    final names = fields.map((f) => f.name).toSet();
    expect(names, containsAll(['Ad', 'Onay', 'Ad2']));
    expect(fields.firstWhere((f) => f.name == 'Ad').kind, PdfFormFieldKind.text);
    expect(fields.firstWhere((f) => f.name == 'Onay').kind,
        PdfFormFieldKind.checkbox);
  });
}
