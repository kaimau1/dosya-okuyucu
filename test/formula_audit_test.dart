import 'package:dosya_okuyucu/services/formula_audit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 10 — öncül/ardıl ve hedef ara.
void main() {
  test('öncüller: hücre, aralık, mutlak; işlev adı ve metin sayılmaz', () {
    final p = FormulaAudit.precedents(r'=SUM(A1:B3)+$C$5*LOG10(D2)&"E9"');
    expect(p, [
      const AuditRef(0, 0, 2, 1),
      const AuditRef(4, 2, 4, 2),
      const AuditRef(1, 3, 1, 3),
    ]);
  });

  test('başka sayfa başvurusu atlanır; düz değer öncülsüz', () {
    expect(FormulaAudit.precedents("=Sayfa2!A1+'Veri 2'!B2:B4+A3"),
        [const AuditRef(2, 0, 2, 0)]);
    expect(FormulaAudit.precedents('A1'), isEmpty);
  });

  test('ardıllar: hücreye doğrudan başvuran formüller', () {
    final grid = [
      ['5', '=A1*2', '=SUM(A1:A3)'],
      ['', '=B1+1', 'metin A1'],
    ];
    expect(FormulaAudit.dependents(grid, 0, 0), [(0, 1), (0, 2)]);
    expect(FormulaAudit.dependents(grid, 0, 1), [(1, 1)]);
  });

  test('hedef ara: doğrusal ve doğrusal olmayan', () {
    final lin = GoalSeek.solve((x) => 3 * x + 4, 19);
    expect(lin.converged, isTrue);
    expect(lin.x, closeTo(5, 1e-6));
    final sq = GoalSeek.solve((x) => x * x, 2, start: 1);
    expect(sq.converged, isTrue);
    expect(sq.x.abs(), closeTo(1.41421356, 1e-5));
  });

  test('hedef ara: ulaşılamayan hedef yakınsamaz', () {
    final r = GoalSeek.solve((x) => x * x + 1, 0, start: 1, maxIter: 50);
    expect(r.converged, isFalse);
  });
}
