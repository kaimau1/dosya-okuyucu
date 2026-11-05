import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf/pdf_form.dart';
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
