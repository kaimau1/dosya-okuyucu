import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 5 — yapısal başvuru (Tablo1[Sütun], [@Sütun], [#Veri]…).
void main() {
  const table = FormulaTable(
    name: 'Tablo1',
    sheet: 'S',
    top: 0,
    left: 0,
    bottom: 3,
    right: 2,
    columns: ['Ürün', 'Adet', 'Fiyat'],
  );
  List<List<String>> grid() => [
        ['Ürün', 'Adet', 'Fiyat', ''],
        ['Kalem', '2', '5', '=[@Adet]*[@Fiyat]'],
        ['Defter', '3', '10', '=Tablo1[@Adet]*2'],
        ['Silgi', '1', '4', ''],
        ['=SUM(Tablo1[Adet])', '=COUNTA(Tablo1[#Data])', '=SUM(Tablo1[[Adet]:[Fiyat]])', '=Tablo1[[#Headers],[Fiyat]]'],
      ];

  FormulaEngine engine() =>
      FormulaEngine(grid(), sheetName: 'S', tables: const [table]);

  test('sütun, veri gövdesi, sütun aralığı, başlık', () {
    final e = engine();
    expect(e.displayValue(4, 0), '6');
    expect(e.displayValue(4, 1), '9');
    expect(e.displayValue(4, 2), '25');
    expect(e.displayValue(4, 3), 'Fiyat');
  });

  test('[@Sütun] bu satır — tablo adıyla da adsız da', () {
    // Formül tablo DIŞINDA (D sütunu) ama satır içinde: tablosuz [@] #BAŞV!.
    final e = engine();
    expect(e.displayValue(1, 3), '#BAŞV!');
    final wide = FormulaEngine(grid(),
        sheetName: 'S',
        tables: const [
          FormulaTable(
              name: 'Tablo1',
              sheet: 'S',
              top: 0,
              left: 0,
              bottom: 3,
              right: 3,
              columns: ['Ürün', 'Adet', 'Fiyat', 'Tutar']),
        ]);
    expect(wide.displayValue(1, 3), '10');
    expect(wide.displayValue(2, 3), '6');
  });

  test('bilinmeyen sütun #BAŞV!', () {
    final e = FormulaEngine([
      ['=SUM(Tablo1[Yok])'],
    ], sheetName: 'S', tables: const [table]);
    expect(e.displayValue(0, 0), '#BAŞV!');
  });
}
