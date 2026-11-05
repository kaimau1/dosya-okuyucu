/// **Formül denetimi** — Faz 36 madde 10: öncüller (formülün başvurduğu
/// aralıklar), ardıllar (hücreye başvuran formüller) ve "Ne-olursa / Hedef
/// ara" çözücüsü. Saf + testli; UI `spreadsheet/pro_audit.dart`.
library;

/// Aynı sayfadaki bir başvuru (0 tabanlı, kapsayıcı).
class AuditRef {
  final int r1, c1, r2, c2;
  const AuditRef(this.r1, this.c1, this.r2, this.c2);
  bool contains(int r, int c) => r >= r1 && r <= r2 && c >= c1 && c <= c2;
  bool get isCell => r1 == r2 && c1 == c2;

  @override
  bool operator ==(Object other) =>
      other is AuditRef &&
      other.r1 == r1 &&
      other.c1 == c1 &&
      other.r2 == r2 &&
      other.c2 == c2;
  @override
  int get hashCode => Object.hash(r1, c1, r2, c2);
  @override
  String toString() => 'AuditRef($r1,$c1:$r2,$c2)';
}

abstract final class FormulaAudit {
  /// `Sayfa!A1`, `'Sayfa 2'!A1:B3`, `$A$1`, `A1:B10`. İşlev adı (`LOG10(`)
  /// başvuru sayılmaz.
  static final _ref = RegExp(
    r"(?<![A-Za-z0-9_.$])((?:'[^']+'|[A-Za-z_À-￿][\w.À-￿]*)!)?"
    r'\$?([A-Za-z]{1,3})\$?(\d{1,7})(?::\$?([A-Za-z]{1,3})\$?(\d{1,7}))?'
    r'(?![A-Za-z0-9_(])',
  );

  static int _col(String letters) {
    var n = 0;
    for (final u in letters.toUpperCase().codeUnits) {
      n = n * 26 + (u - 64);
    }
    return n - 1;
  }

  /// Formülün AYNI sayfadaki öncülleri (başka sayfaya başvurular atlanır).
  static List<AuditRef> precedents(String formula) {
    if (!formula.startsWith('=')) return const [];
    // Tırnaklı metinler başvuru içermez.
    final body = formula.replaceAllMapped(
        RegExp(r'"[^"]*"'), (m) => ' ' * m[0]!.length);
    final out = <AuditRef>[];
    for (final m in _ref.allMatches(body)) {
      if (m[1] != null) continue;
      final r1 = int.parse(m[3]!) - 1, c1 = _col(m[2]!);
      final r2 = m[5] == null ? r1 : int.parse(m[5]!) - 1;
      final c2 = m[4] == null ? c1 : _col(m[4]!);
      if (r1 < 0 || r2 < 0 || c1 < 0 || c2 < 0) continue;
      final ref = AuditRef(r1 < r2 ? r1 : r2, c1 < c2 ? c1 : c2,
          r1 < r2 ? r2 : r1, c1 < c2 ? c2 : c1);
      if (!out.contains(ref)) out.add(ref);
    }
    return out;
  }

  /// (r,c)'ye doğrudan başvuran formül hücreleri (satır, sütun).
  static List<(int, int)> dependents(List<List<String>> grid, int r, int c) {
    final out = <(int, int)>[];
    for (var y = 0; y < grid.length; y++) {
      final row = grid[y];
      for (var x = 0; x < row.length; x++) {
        final raw = row[x];
        if (raw.length < 2 || !raw.startsWith('=')) continue;
        if (precedents(raw).any((p) => p.contains(r, c))) out.add((y, x));
      }
    }
    return out;
  }
}

/// Hedef ara sonucu.
class GoalSeekResult {
  final double x;
  final double value;
  final bool converged;
  final int iterations;
  const GoalSeekResult(this.x, this.value, this.converged, this.iterations);
}

abstract final class GoalSeek {
  /// `f(x) = target` için x arar: kiriş (secant) yöntemi, işaret değişimi
  /// yakalanınca ikiye bölme ile güvenceye alınır. [f] hata/NaN dönerse
  /// o nokta geçersiz sayılır.
  static GoalSeekResult solve(
    double Function(double x) f,
    double target, {
    double start = 0,
    int maxIter = 100,
    double tolerance = 1e-7,
  }) {
    double g(double x) => f(x) - target;
    var x0 = start;
    var x1 = start == 0 ? 1.0 : start * 1.1;
    var y0 = g(x0), y1 = g(x1);
    double? lo, hi; // y(lo) < 0 < y(hi) olacak biçimde braket
    void bracket(double x, double y) {
      if (y.isNaN) return;
      if (y < 0) lo = x;
      if (y > 0) hi = x;
    }

    bracket(x0, y0);
    bracket(x1, y1);
    for (var i = 1; i <= maxIter; i++) {
      if (y1.isFinite && y1.abs() <= tolerance * (1 + target.abs())) {
        return GoalSeekResult(x1, y1 + target, true, i);
      }
      double next;
      final denom = y1 - y0;
      if (lo != null && hi != null) {
        next = (lo! + hi!) / 2;
        if (denom != 0 && denom.isFinite) {
          final s = x1 - y1 * (x1 - x0) / denom;
          final a = lo! < hi! ? lo! : hi!, b = lo! < hi! ? hi! : lo!;
          if (s > a && s < b) next = s;
        }
      } else if (denom != 0 && denom.isFinite && y1.isFinite) {
        next = x1 - y1 * (x1 - x0) / denom;
      } else {
        next = x1 == 0 ? 1 : x1 * 2;
      }
      if (!next.isFinite) break;
      x0 = x1;
      y0 = y1;
      x1 = next;
      y1 = g(x1);
      bracket(x1, y1);
    }
    return GoalSeekResult(x1, y1 + target,
        y1.isFinite && y1.abs() <= 1e-4 * (1 + target.abs()), maxIter);
  }
}
