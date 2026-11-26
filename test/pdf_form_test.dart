import 'dart:io';

import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf/pdf_form.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **PDF form doldurma.**
///
/// Fixture yok: form PDF'i testin kendisi üretiyor (Syncfusion hem yazıyor hem
/// okuyor). Böylece test hangi alanların hangi değerlerle kurulduğunu bilir ve
/// "doldurdum ama dosyada yok" hatası doğrudan yakalanır.
void main() {
  List<int> buildForm() {
    final doc = PdfDocument();
    final page = doc.pages.add();
    final name =
        PdfTextBoxField(page, 'AdSoyad', const Rect.fromLTWH(0, 0, 200, 20));
    doc.form.fields.add(name);
    final note = PdfTextBoxField(
        page, 'Aciklama', const Rect.fromLTWH(0, 30, 200, 40),
        multiline: true);
    doc.form.fields.add(note);
    final agree =
        PdfCheckBoxField(page, 'Onay', const Rect.fromLTWH(0, 80, 20, 20));
    doc.form.fields.add(agree);
    final city = PdfComboBoxField(
        page, 'Sehir', const Rect.fromLTWH(0, 110, 200, 20));
    city.items.add(PdfListFieldItem('Ankara', 'Ankara'));
    city.items.add(PdfListFieldItem('İstanbul', 'İstanbul'));
    doc.form.fields.add(city);
    final radio = PdfRadioButtonListField(page, 'Plan');
    radio.items.add(PdfRadioButtonListItem(
        value: 'Bireysel', bounds: const Rect.fromLTWH(0, 140, 16, 16)));
    radio.items.add(PdfRadioButtonListItem(
        value: 'Kurumsal', bounds: const Rect.fromLTWH(60, 140, 16, 16)));
    doc.form.fields.add(radio);
    final list = PdfListBoxField(
        page, 'Dil', const Rect.fromLTWH(0, 170, 200, 40));
    list.items.add(PdfListFieldItem('Türkçe', 'Türkçe'));
    list.items.add(PdfListFieldItem('English', 'English'));
    doc.form.fields.add(list);
    final date = PdfTextBoxField(
        page, 'DogumTarihi', const Rect.fromLTWH(0, 220, 200, 20));
    doc.form.fields.add(date);
    final locked = PdfTextBoxField(
        page, 'Kilitli', const Rect.fromLTWH(0, 250, 200, 20));
    locked.text = 'değişmez';
    locked.readOnly = true;
    doc.form.fields.add(locked);
    final bytes = doc.saveSync();
    doc.dispose();
    return bytes;
  }

  test('tüm AcroForm türleri (metin, çok satır, onay, radyo, liste, açılır, tarih) okunur',
      () {
    final fields = PdfFormFiller.readSync(buildForm());
    expect(fields.length, 8);

    final byName = {for (final f in fields) f.name: f};
    expect(byName['AdSoyad']?.kind, PdfFormFieldKind.text);
    expect(byName['AdSoyad']?.multiline, isFalse);
    expect(byName['AdSoyad']?.isDateField, isFalse);
    expect(byName['Aciklama']?.kind, PdfFormFieldKind.text);
    expect(byName['Aciklama']?.multiline, isTrue);
    expect(byName['Onay']?.kind, PdfFormFieldKind.checkbox);
    expect(byName['Onay']?.isChecked, isFalse);
    expect(byName['Sehir']?.kind, PdfFormFieldKind.combo);
    expect(byName['Sehir']?.options, ['Ankara', 'İstanbul']);
    expect(byName['Plan']?.kind, PdfFormFieldKind.radio);
    expect(byName['Plan']?.options, ['Bireysel', 'Kurumsal']);
    expect(byName['Dil']?.kind, PdfFormFieldKind.list);
    expect(byName['Dil']?.options, ['Türkçe', 'English']);
    expect(byName['DogumTarihi']?.kind, PdfFormFieldKind.text);
    expect(byName['DogumTarihi']?.isDateField, isTrue);
    // Salt-okunur alan SÖYLENİR (dokunup bir şey olmaması "bozuk" sanılıyor).
    expect(byName['Kilitli']?.readOnly, isTrue);
    expect(byName['AdSoyad']?.page, 1);
  });

  test('doldurulan tüm tür değerleri dosyaya girer ve geri okunur (Türkçe harfler dahil)',
      () {
    final font = File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync();
    final filled = PdfFormFiller.fillSync(
      buildForm(),
      {
        'AdSoyad': 'Ayşe Gül Çınar',
        'Aciklama': 'İki satır\nikinci satır',
        'Onay': 'true',
        'Sehir': 'İstanbul',
        'Plan': 'Kurumsal',
        'Dil': 'Türkçe',
        'DogumTarihi': '26.11.2026',
      },
      fontData: font,
    );

    final byName = {for (final f in PdfFormFiller.readSync(filled)) f.name: f};
    expect(byName['AdSoyad']?.value, 'Ayşe Gül Çınar');
    expect(byName['Aciklama']?.value, contains('ikinci satır'));
    expect(byName['Onay']?.isChecked, isTrue);
    expect(byName['Sehir']?.value, 'İstanbul');
    expect(byName['Plan']?.value, 'Kurumsal');
    expect(byName['Dil']?.value, 'Türkçe');
    expect(byName['DogumTarihi']?.value, '26.11.2026');
  });

  test('salt-okunur alan doldurulmaz (dosyanın kilidi zorlanmaz)', () {
    final filled = PdfFormFiller.fillSync(buildForm(), {'Kilitli': 'yeni değer'});
    final byName = {for (final f in PdfFormFiller.readSync(filled)) f.name: f};
    expect(byName['Kilitli']?.value, 'değişmez');
  });

  test('listede olmayan seçenek hiçbir şeyi işaretlemez', () {
    final filled = PdfFormFiller.fillSync(buildForm(), {'Sehir': 'Berlin'});
    final byName = {for (final f in PdfFormFiller.readSync(filled)) f.name: f};
    expect(byName['Sehir']?.value, isNot('Berlin'));
  });

  test('Türkçe harf yerleşik yazı tipiyle çizilemez → gömülü font gerekir', () {
    // `İ Ğ Ş ğ ı ş` WinAnsi dışında; `Ç Ö Ü` değil.
    expect(PdfFormFiller.needsUnicodeFont('Ayşe'), isTrue);
    expect(PdfFormFiller.needsUnicodeFont('İstanbul'), isTrue);
    expect(PdfFormFiller.needsUnicodeFont('Çörek Üzüm'), isFalse);
    expect(PdfFormFiller.needsUnicodeFont('Ankara'), isFalse);
  });

  test('gömülü yazı tipiyle Türkçe değer düzleştirilebilir', () {
    // Gömülü font OLMADAN Syncfusion "character is not supported" diye düşer:
    // Türkçe bir formda kaydetme hiç çalışmazdı.
    final font = File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync();
    final filled = PdfFormFiller.fillSync(
      buildForm(),
      {'AdSoyad': 'Ayşe Gül Çınar', 'Sehir': 'İstanbul'},
      flatten: true,
      fontData: font,
    );
    expect(PdfFormFiller.readSync(filled), isEmpty);
    final doc = PdfDocument(inputBytes: filled);
    final text = PdfTextExtractor(doc).extractText();
    doc.dispose();
    expect(text, contains('Ayşe'));
  });

  test('düzleştirme alanları kaldırır (değer sayfada kalır)', () {
    // Latin harfli form: belgenin kendi yazı tipi yetiyor, gömülü font
    // gerekmiyor.
    final doc0 = PdfDocument();
    final page = doc0.pages.add();
    final field =
        PdfTextBoxField(page, 'AdSoyad', const Rect.fromLTWH(0, 0, 200, 20));
    doc0.form.fields.add(field);
    final plainForm = doc0.saveSync();
    doc0.dispose();

    final filled = PdfFormFiller.fillSync(
      plainForm,
      {'AdSoyad': 'Ayse Gul'},
      flatten: true,
    );
    expect(PdfFormFiller.readSync(filled), isEmpty);

    // Değer sayfanın kendi metnine geçmiş olmalı.
    final doc = PdfDocument(inputBytes: filled);
    final text = PdfTextExtractor(doc).extractText();
    doc.dispose();
    expect(text, contains('Ayse Gul'));
  });

  test('gömülü yazı tipi verilmezse Türkçe formda AÇIK hata', () {
    // Sessizce boş/bozuk dosya bırakmaktansa nedenini söylemek doğru.
    expect(
      () => PdfFormFiller.fillSync(
          buildForm(), {'AdSoyad': 'Ayşe'}, flatten: true),
      throwsA(isA<PdfFormException>()),
    );
  });

  test('formu olmayan belgede açık hata (sessiz başarı DEĞİL)', () {
    final doc = PdfDocument();
    doc.pages.add();
    final plain = doc.saveSync();
    doc.dispose();

    expect(PdfFormFiller.readSync(plain), isEmpty);
    expect(() => PdfFormFiller.fillSync(plain, {'a': 'b'}),
        throwsA(isA<PdfFormException>()));
  });
}
