part of '../formula_engine.dart';

/// Kalıcı hesap durumu (Faz 26, 2026-10-23): değer önbelleği + bağımlılık
/// grafiği. Ekran bunu bir kez kurar ve her çizimde aynı nesneyi motora
/// verir; eskiden motor her `build`de sıfırdan kuruluyor, görünen her formül
/// (ve zincirleme bağımlıları) her karede yeniden hesaplanıyordu.
///
/// Bağımlılıklar hesap SIRASINDA kaydedilir: formülün okuduğu her başvuru/
/// aralık (`KAYDIR`/`DOLAYLI`nın ürettiği dahil) formül anahtarına bağlanır.
/// Hücre değişince yalnız ona (doğrudan ya da zincirle) bakan formüller
/// geçersiz olur; bir sonraki istekte tembelce yeniden hesaplanır.
/// Uçucu işlevler (`BUGÜN`, `ŞİMDİ`, `S_SAYI_ÜRET`, `RASTGELEARADA`,
/// `DOLAYLI`, `KAYDIR`) her değişiklikte geçersiz sayılır.
class CalcState {
  final Map<String, Object> _cache = {};

  /// Formül anahtarı → hesapta okuduğu aralıklar.
  final Map<String, List<_Dep>> _deps = {};

  /// Formül anahtarı → (sayfa, satır, sütun).
  final Map<String, (String, int, int)> _where = {};

  /// Tek hücre bağımlılıkları: sayfa → hücre anahtarı → kayıtlar.
  final Map<String, Map<int, Set<_Dep>>> _byCell = {};

  /// Dar aralıklar (≤ [_wideCols] sütun): sayfa → sütun → kayıtlar.
  final Map<String, Map<int, Set<_Dep>>> _byCol = {};

  /// Geniş aralıklar: sayfa → kayıtlar (doğrusal taranır; seyrek).
  final Map<String, Set<_Dep>> _wide = {};

  final Set<String> _volatile = {};

  /// Hesaplanmakta olan formüllerin bağımlılık toplayıcıları (iç içe).
  final List<List<_Dep>> _collect = [];

  static const _wideCols = 64;

  /// Formül hesap sayacı (kıyas/kabul testleri: "yalnız bağımlılar").
  int evaluations = 0;

  /// Önbellekteki hesaplanmış formül sayısı.
  int get cachedCount => _cache.length;

  /// Her şeyi unutur (yapısal değişiklik).
  void reset() {
    _cache.clear();
    _deps.clear();
    _where.clear();
    _byCell.clear();
    _byCol.clear();
    _wide.clear();
    _volatile.clear();
    _collect.clear();
  }

  void _note(String sheet, int r1, int c1, int r2, int c2) {
    if (_collect.isEmpty) return;
    _collect.last.add(_Dep(sheet, r1, c1, r2, c2));
  }

  void _register(String key, String sheet, int r, int c, List<_Dep> deps,
      bool volatile) {
    _unregister(key);
    _where[key] = (sheet, r, c);
    for (final d in deps) {
      d.formula = key;
      if (d.r1 == d.r2 && d.c1 == d.c2) {
        (_byCell[d.sheet] ??= {})
            .putIfAbsent(_cellIndex(d.r1, d.c1), () => <_Dep>{})
            .add(d);
      } else if (d.c2 - d.c1 < _wideCols) {
        final cols = _byCol[d.sheet] ??= {};
        for (var c = d.c1; c <= d.c2; c++) {
          cols.putIfAbsent(c, () => <_Dep>{}).add(d);
        }
      } else {
        (_wide[d.sheet] ??= <_Dep>{}).add(d);
      }
    }
    _deps[key] = deps;
    if (volatile) _volatile.add(key);
  }

  void _unregister(String key) {
    final old = _deps.remove(key);
    _volatile.remove(key);
    if (old == null) return;
    for (final d in old) {
      if (d.r1 == d.r2 && d.c1 == d.c2) {
        _byCell[d.sheet]?[_cellIndex(d.r1, d.c1)]?.remove(d);
      } else if (d.c2 - d.c1 < _wideCols) {
        final cols = _byCol[d.sheet];
        if (cols == null) continue;
        for (var c = d.c1; c <= d.c2; c++) {
          cols[c]?.remove(d);
        }
      } else {
        _wide[d.sheet]?.remove(d);
      }
    }
  }

  static int _cellIndex(int r, int c) => r * 16384 + c;

  /// (sheet, r, c) hücresine bakan formül anahtarları.
  Iterable<String> _dependentsOf(String sheet, int r, int c) sync* {
    final single = _byCell[sheet]?[_cellIndex(r, c)];
    if (single != null) {
      for (final d in single) {
        yield d.formula;
      }
    }
    final col = _byCol[sheet]?[c];
    if (col != null) {
      for (final d in col) {
        if (r >= d.r1 && r <= d.r2) yield d.formula;
      }
    }
    final wide = _wide[sheet];
    if (wide != null) {
      for (final d in wide) {
        if (r >= d.r1 && r <= d.r2 && c >= d.c1 && c <= d.c2) yield d.formula;
      }
    }
  }

  /// [sheet]!(r,c) değişti: hücrenin kendisi ve ona bağlı her formül
  /// (zincirle) geçersiz. Dönen değer: geçersiz kılınan formül sayısı.
  int invalidate(String sheet, int r, int c) {
    var count = 0;
    final queue = <(String, int, int)>[(sheet, r, c)];
    final seen = <String>{};
    while (queue.isNotEmpty) {
      final (s, rr, cc) = queue.removeLast();
      final self = FormulaEngine._key(s, rr, cc);
      if (!seen.add(self)) continue;
      if (_cache.remove(self) != null) count++;
      for (final f in _dependentsOf(s, rr, cc).toList()) {
        final at = _where[f];
        if (at != null && !seen.contains(f)) queue.add(at);
      }
      _unregister(self);
      _where.remove(self);
    }
    return count;
  }

  /// Uçucu formülleri (ve bağımlılarını) geçersiz kılar.
  void invalidateVolatile() {
    for (final k in _volatile.toList()) {
      final at = _where[k];
      if (at != null) invalidate(at.$1, at.$2, at.$3);
    }
  }

  static const _volatileNames = {
    'TODAY', 'NOW', 'RAND', 'RANDBETWEEN', 'INDIRECT', 'OFFSET', 'CELL', 'INFO',
  };
  static final Map<String, bool> _volatileMemo = {};
  static final _callRe = RegExp(r'([A-Za-zÇĞİÖŞÜçğıöşü_][A-Za-z0-9ÇĞİÖŞÜçğıöşü_.]*)\s*\(');

  static bool _isVolatile(String formula) {
    final hit = _volatileMemo[formula];
    if (hit != null) return hit;
    var v = false;
    for (final m in _callRe.allMatches(formula)) {
      if (_volatileNames.contains(_Parser._canonical(m.group(1)!))) {
        v = true;
        break;
      }
    }
    if (_volatileMemo.length > 4096) _volatileMemo.clear();
    return _volatileMemo[formula] = v;
  }

  // ── isolate'te ilk hesap ────────────────────────────────────────────────

  /// Ağır ilk hesap için: sayfaları satır sırasıyla (zincirler sığ kalsın)
  /// hesaplar. [sheets] sırası önemli değildir.
  void warmUp(Map<String, List<List<String>>> sheets) {
    for (final e in sheets.entries) {
      final eng = FormulaEngine(e.value, sheets: sheets, sheetName: e.key, state: this);
      final g = e.value;
      for (var r = 0; r < g.length; r++) {
        final row = g[r];
        for (var c = 0; c < row.length; c++) {
          final v = row[c];
          if (v.length > 1 && v.startsWith('=')) eng.displayValue(r, c);
        }
      }
    }
  }

  /// Formül sayısı (ilk hesabı isolate'e alma eşiği için).
  static int formulaCount(Map<String, List<List<String>>> sheets) {
    var n = 0;
    for (final g in sheets.values) {
      for (final row in g) {
        for (final v in row) {
          if (v.length > 1 && v.codeUnitAt(0) == 0x3D) n++;
        }
      }
    }
    return n;
  }

  /// Bu sayıdan çok formülde ilk hesap isolate'te yapılır (ekran bu arada
  /// görünen hücreleri tembelce hesaplar).
  static const isolateThreshold = 5000;
}

/// Bir formülün okuduğu aralık (bağımlılık kaydı).
class _Dep {
  final String sheet;
  final int r1, c1, r2, c2;
  String formula = '';
  _Dep(this.sheet, this.r1, this.c1, this.r2, this.c2);
}
