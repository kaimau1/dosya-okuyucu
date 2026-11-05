import 'package:dosya_okuyucu/services/xlsx/pivot.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 1 — özet tablo (değer anlık görüntüsü).
const _data = [
  ['Bölge', 'Ürün', 'Tutar'],
  ['Ege', 'Kalem', '10'],
  ['Ege', 'Defter', '1.250,50'],
  ['Marmara', 'Kalem', '5'],
  ['Marmara', 'Kalem', '7'],
  ['', 'Silgi', 'yok'],
];

void main() {
  test('tek boyut: toplam + genel toplam, boş anahtar etiketlenir', () {
    final r = Pivot.build(_data, const PivotSpec(rowField: 0, valueField: 2),
        valueHeader: 'Toplam Tutar');
    expect(r.cells.first, ['Bölge', 'Toplam Tutar']);
    expect(r.cells, contains(['Ege', '1260.5']));
    expect(r.cells, contains(['Marmara', '12']));
    expect(r.cells.last, ['Genel Toplam', '1272.5']);
  });

  test('iki boyut: çapraz tablo ve satır/sütun toplamları', () {
    final r = Pivot.build(
        _data, const PivotSpec(rowField: 0, colField: 1, valueField: 2));
    expect(r.cells.first, ['Bölge \\ Ürün', 'Defter', 'Kalem', 'Silgi', 'Genel Toplam']);
    final ege = r.cells.firstWhere((row) => row.first == 'Ege');
    expect(ege, ['Ege', '1250.5', '10', '', '1260.5']);
  });

  test('say: boş olmayan her değer; ortalama/min/max', () {
    expect(
        Pivot.build(_data,
                const PivotSpec(rowField: 1, valueField: 2, agg: PivotAgg.count))
            .cells,
        contains(['Silgi', '1']));
    expect(
        Pivot.build(_data,
                const PivotSpec(rowField: 0, valueField: 2, agg: PivotAgg.average))
            .cells,
        contains(['Marmara', '6']));
    expect(
        Pivot.build(_data,
                const PivotSpec(rowField: 0, valueField: 2, agg: PivotAgg.max))
            .cells,
        contains(['Ege', '1250.5']));
  });

  test('süzgeç yalnız seçili değerleri alır', () {
    final r = Pivot.build(
        _data,
        const PivotSpec(
            rowField: 0, valueField: 2, filterField: 1, filterValues: {'Kalem'}));
    expect(r.cells, contains(['Ege', '10']));
    expect(r.cells.last, ['Genel Toplam', '22']);
  });

  test('sayı ayrıştırma TR/EN', () {
    expect(Pivot.number('1.234,5'), 1234.5);
    expect(Pivot.number('1,234.5'), 1234.5);
    expect(Pivot.number('12,5'), 12.5);
    expect(Pivot.number('abc'), isNull);
    expect(Pivot.distinct(_data, 1), ['Defter', 'Kalem', 'Silgi']);
  });
}
