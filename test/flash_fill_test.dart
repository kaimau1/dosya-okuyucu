import 'package:dosya_okuyucu/services/xlsx/flash_fill.dart';
import 'package:flutter_test/flutter_test.dart';

/// B10 m.4 (2026-11-19) — Hızlı doldurma: örnekten desen çıkarma.
void main() {
  final names = [
    ['Ali Yılmaz'],
    ['Ayşe Nur Kaya'],
    ['mehmet demir'],
    ['Zeynep Çelik'],
  ];

  test('ad: ilk sözcük', () {
    expect(FlashFill.infer(names, {0: 'Ali'}),
        {1: 'Ayşe', 2: 'mehmet', 3: 'Zeynep'});
  });

  test('soyad: ikinci adlı satırda da SON sözcük', () {
    expect(FlashFill.infer(names, {0: 'Yılmaz'}),
        {1: 'Kaya', 2: 'demir', 3: 'Çelik'});
  });

  test('yer değiştir + sabit ayraç', () {
    final out = FlashFill.infer(names, {0: 'Yılmaz, Ali'});
    expect(out?[1], 'Kaya, Ayşe');
    expect(out?[3], 'Çelik, Zeynep');
  });

  test('baş harfler', () {
    final out = FlashFill.infer(names, {0: 'A.Y.'});
    expect(out?[1], 'A.K.');
    expect(out?[3], 'Z.Ç.');
  });

  test('ikinci örnek büyük harf dönüşümünü seçtirir', () {
    final out = FlashFill.infer(names, {0: 'Ali', 2: 'Mehmet'});
    expect(out, {1: 'Ayşe', 3: 'Zeynep'});
  });

  test('Türkçe büyük harf: i → İ', () {
    final out = FlashFill.infer([
      ['ali veli'],
      ['zeki şimşek'],
    ], {0: 'VELİ'});
    expect(out, {1: 'ŞİMŞEK'});
  });

  test('iki sütunu birleştir; değer üretemeyen satır yazılmaz', () {
    final out = FlashFill.infer([
      ['Ali', 'Yılmaz'],
      ['Ayşe', 'Kaya'],
      ['Can', ''],
    ], {0: 'Ali Yılmaz'});
    expect(out, {1: 'Ayşe Kaya'});
  });

  test('e-posta kullanıcı adı', () {
    final out = FlashFill.infer([
      ['ali.yilmaz@ornek.com'],
      ['ayse.kaya@ornek.com'],
    ], {0: 'ali'});
    expect(out, {1: 'ayse'});
  });

  test('tutarsız örnekler → null', () {
    expect(FlashFill.infer(names, {0: 'Ali', 1: 'xyz'}), isNull);
  });

  test('örnek yok ya da yalnız sabit tahmini → null', () {
    expect(FlashFill.infer(names, const {}), isNull);
    expect(FlashFill.infer(names, {0: '???'}), isNull);
  });
}
