import 'package:dosya_okuyucu/services/sheet_edit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 9 / Y2 — köşegen doldurma (önce satırlar, sonra sütunlar).
void main() {
  // A1=1  B1=10
  // A2=2  B2=20
  final grid = {
    const CellRef(0, 0): '1',
    const CellRef(0, 1): '10',
    const CellRef(1, 0): '2',
    const CellRef(1, 1): '20',
  };
  String rawAt(int r, int c) => grid[CellRef(r, c)] ?? '';
  const src = CellRange(0, 0, 1, 1);

  test('tek eksen (aşağı) eski davranışla aynı', () {
    final v = fillDiagonal(src, 3, 1, rawAt);
    expect(v[const CellRef(2, 0)], '3');
    expect(v[const CellRef(3, 0)], '4');
    expect(v[const CellRef(3, 1)], '40');
    expect(v.keys.every((k) => k.col <= 1), isTrue);
  });

  test('köşegen: aşağı + sağa, köşe hücreleri de dolar', () {
    final v = fillDiagonal(src, 2, 2, rawAt);
    // Satır uzantısı: A3=3, B3=30
    expect(v[const CellRef(2, 0)], '3');
    expect(v[const CellRef(2, 1)], '30');
    // Sütun uzantısı (satır serisi 1→10 adımı 9): C1=19, C2=38, C3=57
    expect(v[const CellRef(0, 2)], '19');
    expect(v[const CellRef(1, 2)], '38');
    expect(v[const CellRef(2, 2)], '57');
  });

  test('köşegen yukarı-sola', () {
    final grid2 = {
      const CellRef(5, 5): 'Ocak',
    };
    final v = fillDiagonal(const CellRange(5, 5, 5, 5), 3, 3,
        (r, c) => grid2[CellRef(r, c)] ?? '');
    // 3×3'lük alanın tamamı yazılır (kaynak hariç 8 hücre).
    expect(v.length, 8);
    expect(v.containsKey(const CellRef(3, 3)), isTrue);
  });
}
