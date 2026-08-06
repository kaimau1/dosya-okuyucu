import 'dart:convert';

import 'package:dosya_okuyucu/services/pdf/pdf_syntax.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Aranabilir taranmış PDF tanıma** (kullanıcı bulgusu 2026-08-06): tarama
/// "aranabilir" yapıldığında sayfaya görünmez OCR metni gömülüyor; düzenleyici
/// sayfayı "metinli" sayıp taranmış sayfa araçlarını (Metni düzelt / Metni AI
/// ile düzelt) HİÇ göstermiyordu. Ayırt eden işaret `3 Tr`.
void main() {
  List<int> content(String s) => utf8.encode(s);

  test('3 Tr → görünmez metin', () {
    expect(hasInvisibleText(content('BT /F1 12 Tf 3 Tr (Rapor) Tj ET')), isTrue);
  });

  test('7 Tr (yalnız kırpma) da görünmez sayılır', () {
    expect(hasInvisibleText(content('BT /F1 12 Tf 7 Tr (x) Tj ET')), isTrue);
  });

  test('0 Tr → normal metin, görünmez DEĞİL', () {
    expect(
      hasInvisibleText(content('BT /F1 12 Tf 0 Tr (Rapor) Tj ET')),
      isFalse,
    );
  });

  test('Tr hiç yoksa görünmez değil (varsayılan 0)', () {
    expect(hasInvisibleText(content('BT /F1 12 Tf (Rapor) Tj ET')), isFalse);
  });

  test('metin dizesinin İÇİNDEKİ "3 Tr" operatör sanılmaz', () {
    // Tarayıcı dizeleri operatör olarak ayrıştırmamalı — yoksa içinde "3 Tr"
    // geçen sıradan bir belge taranmış sanılırdı.
    expect(
      hasInvisibleText(content('BT /F1 12 Tf (madde 3 Tr olsun) Tj ET')),
      isFalse,
    );
  });
}
