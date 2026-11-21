import 'package:dosya_okuyucu/services/sheet_edit.dart';
import 'package:flutter_test/flutter_test.dart';

/// B10 m.4 (2026-11-19) — doldurma tutamağı: tarih/saat biçimli sayılar,
/// ay adımı ve biçimin taşınması.
void main() {
  group('fillKindOf', () {
    test('tarih / saat / düz sayı', () {
      expect(fillKindOf('dd.mm.yyyy'), FillValueKind.date);
      expect(fillKindOf('d mmm'), FillValueKind.date);
      expect(fillKindOf('hh:mm'), FillValueKind.time);
      expect(fillKindOf('mm:ss'), FillValueKind.time);
      expect(fillKindOf('General'), FillValueKind.plain);
      expect(fillKindOf(''), FillValueKind.plain);
      expect(fillKindOf('0.00%'), FillValueKind.plain);
      expect(fillKindOf('#,##0.00;[Red]-#,##0.00'), FillValueKind.plain);
    });
  });

  group('FillSeries.extend + tür', () {
    test('tarih biçimli tek hücre +1 gün (düz sayı kopyalanır)', () {
      expect(FillSeries.extend(['46345'], 2, kind: FillValueKind.date),
          ['46346', '46347']);
      expect(FillSeries.extend(['46345'], 2), ['46345', '46345']);
      // Saat kesri korunur.
      expect(FillSeries.extend(['46345.5'], 1, kind: FillValueKind.date),
          ['46346.5']);
    });

    test('saat biçimli tek hücre +1 saat', () {
      expect(FillSeries.extend(['0.5'], 2, kind: FillValueKind.time),
          ['0.541666667', '0.583333333']);
    });

    test('aynı gün numaralı tarihler AY adımıyla ilerler', () {
      // 15 Ocak, 15 Şubat 2026 → 15 Mart, 15 Nisan (gün farkı sabit değil).
      expect(
          FillSeries.extend(['46037', '46068'], 2, kind: FillValueKind.date),
          ['46096', '46127']);
      // Gün farkı sabitse (haftalık) sayı dalı.
      expect(
          FillSeries.extend(['46345', '46352'], 1, kind: FillValueKind.date),
          ['46359']);
      // Geriye: 15 Şubat, 15 Mart'tan yukarı → 15 Ocak.
      expect(
          FillSeries.extend(['46068', '46096'], 1,
              backwards: true, kind: FillValueKind.date),
          ['46037']);
    });

    test('ISO metin tarihte ay adımı, ay sonu kırpılır', () {
      expect(FillSeries.extend(['2026-01-31', '2026-03-31'], 2),
          ['2026-05-31', '2026-07-31']);
      expect(FillSeries.extend(['2025-11-30', '2025-12-30'], 2),
          ['2026-01-30', '2026-02-28']);
    });

    test('ay/gün adı ve formül eski davranışta', () {
      expect(FillSeries.extend(['Pzt', 'Sal'], 2), ['Çar', 'Per']);
      expect(FillSeries.extend(['Ocak'], 1), ['Şubat']);
      expect(FillSeries.extend(['=A1+B1'], 2), ['=A2+B2', '=A3+B3']);
      expect(FillSeries.extend(['1', '2'], 2), ['3', '4']);
    });
  });

  group('fillDiagonal + kindAt', () {
    test('tarih biçimli hücre gün gün ilerler', () {
      final v = fillDiagonal(const CellRange(0, 0, 0, 0), 2, 0,
          (r, c) => r == 0 && c == 0 ? '46345' : '',
          kindAt: (r, c) => FillValueKind.date);
      expect(v[const CellRef(1, 0)], '46346');
      expect(v[const CellRef(2, 0)], '46347');
    });

    test('karışık türde kaynak düz sayı sayılır', () {
      final grid = {const CellRef(0, 0): '5', const CellRef(1, 0): '7'};
      final v = fillDiagonal(const CellRange(0, 0, 1, 0), 2, 0,
          (r, c) => grid[CellRef(r, c)] ?? '',
          kindAt: (r, c) => r == 0 ? FillValueKind.date : FillValueKind.plain);
      expect(v[const CellRef(2, 0)], '9');
    });
  });

  group('fillFormatSources', () {
    test('aşağı: desen döngüsel', () {
      final m = fillFormatSources(const CellRange(0, 0, 1, 0), 4, 0);
      expect(m, {
        const CellRef(2, 0): const CellRef(0, 0),
        const CellRef(3, 0): const CellRef(1, 0),
        const CellRef(4, 0): const CellRef(0, 0),
      });
    });

    test('yukarı ve köşegen', () {
      final up = fillFormatSources(const CellRange(2, 0, 3, 0), 0, 0);
      expect(up, {
        const CellRef(0, 0): const CellRef(2, 0),
        const CellRef(1, 0): const CellRef(3, 0),
      });
      final diag = fillFormatSources(const CellRange(0, 0, 0, 0), 1, 1);
      expect(diag.length, 3);
      expect(diag[const CellRef(1, 1)], const CellRef(0, 0));
    });
  });
}
