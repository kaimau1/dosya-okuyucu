/// **Özet tablo (pivot)** — Faz 36 madde 1, ilk sürüm: "değer anlık
/// görüntüsü". Kaynak aralık (başlık satırlı) → satır alanı × (isteğe bağlı)
/// sütun alanı, bir değer alanı, toplama işlevi (topla/say/ortalama/en
/// küçük/en büyük), isteğe bağlı süzgeç. Sonuç yeni sayfaya DÜZ DEĞER olarak
/// yazılır (xlsx `pivotCache` yazılmaz — her Excel/LibreOffice okur);
/// "Yenile" aynı ayarla kaynağı yeniden okuyup sayfayı tazeler (ayar oturum
/// içinde, sayfa adına bağlı tutulur).
///
/// Saf + testli; büyük aralıkta (100 bin satır) çağıran izolatta koşturur.
library;

import 'dart:math' as math;

enum PivotAgg { sum, count, average, min, max }

class PivotSpec {
  /// Kaynak aralığın sütun indeksleri (0 = aralığın ilk sütunu).
  final int rowField;
  final int? colField;
  final int valueField;
  final PivotAgg agg;

  /// Süzgeç: alan → izin verilen değerler (boş küme = süzgeç yok).
  final int? filterField;
  final Set<String> filterValues;

  const PivotSpec({
    required this.rowField,
    this.colField,
    required this.valueField,
    this.agg = PivotAgg.sum,
    this.filterField,
    this.filterValues = const {},
  });
}

class PivotResult {
  /// Hücreler (ilk satır başlık); sayılar ham `double` metni değil, [numbers]
  /// eşlemesinde de durur ki yazan sayı hücresi yazsın.
  final List<List<String>> cells;
  final int rowKeys;
  final int colKeys;
  const PivotResult(this.cells, this.rowKeys, this.colKeys);
}

abstract final class Pivot {
  /// "1.234,5" / "1234.5" / "%12" → sayı (Türkçe ve İngilizce ayraçlar).
  static double? number(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[\s₺$€£%]|TL', caseSensitive: false), '');
    if (s.isEmpty || !RegExp(r'^-?[\d.,]+(e-?\d+)?$', caseSensitive: false).hasMatch(s)) {
      return null;
    }
    final dot = s.lastIndexOf('.'), comma = s.lastIndexOf(',');
    if (dot >= 0 && comma >= 0) {
      s = comma > dot
          ? s.replaceAll('.', '').replaceAll(',', '.')
          : s.replaceAll(',', '');
    } else if (comma >= 0) {
      final dec = s.length - comma - 1;
      s = s.indexOf(',') == comma && dec != 3
          ? s.replaceAll(',', '.')
          : s.replaceAll(',', '');
    }
    return double.tryParse(s);
  }

  /// Saf: sayıyı kısa yaz (tam sayı ondalıksız, değilse en çok 6 hane).
  static String format(double v) {
    if (v.isNaN || v.isInfinite) return '#SAYI!';
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toStringAsFixed(0);
    var s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  /// [data] ilk satırı başlık olan aralık. [totalLabel] "Genel Toplam".
  static PivotResult build(
    List<List<String>> data,
    PivotSpec spec, {
    String totalLabel = 'Genel Toplam',
    String blankLabel = '(boş)',
    String? valueHeader,
  }) {
    if (data.isEmpty) return const PivotResult([], 0, 0);
    final header = data.first;
    String cell(List<String> row, int c) =>
        c < row.length ? row[c].trim() : '';
    final rowKeys = <String>[];
    final colKeys = <String>[];
    final seenRow = <String>{}, seenCol = <String>{};
    // (satır, sütun) → biriktirici
    final acc = <String, _Acc>{};
    final rowTot = <String, _Acc>{}, colTot = <String, _Acc>{};
    final grand = _Acc();
    for (final row in data.skip(1)) {
      if (row.every((v) => v.trim().isEmpty)) continue;
      if (spec.filterField != null &&
          spec.filterValues.isNotEmpty &&
          !spec.filterValues.contains(cell(row, spec.filterField!))) {
        continue;
      }
      var rk = cell(row, spec.rowField);
      if (rk.isEmpty) rk = blankLabel;
      var ck = spec.colField == null ? '' : cell(row, spec.colField!);
      if (spec.colField != null && ck.isEmpty) ck = blankLabel;
      if (seenRow.add(rk)) rowKeys.add(rk);
      if (seenCol.add(ck)) colKeys.add(ck);
      final raw = cell(row, spec.valueField);
      final v = number(raw);
      // "Say" boş olmayan HER değeri sayar; diğerleri yalnız sayıları.
      if (spec.agg == PivotAgg.count) {
        if (raw.isEmpty) continue;
      } else if (v == null) {
        continue;
      }
      for (final a in [
        acc.putIfAbsent('$rk\u0000$ck', _Acc.new),
        rowTot.putIfAbsent(rk, _Acc.new),
        colTot.putIfAbsent(ck, _Acc.new),
        grand,
      ]) {
        a.add(v ?? 0);
      }
    }
    int byKey(String a, String b) {
      final na = number(a), nb = number(b);
      if (na != null && nb != null) return na.compareTo(nb);
      return a.toLowerCase().compareTo(b.toLowerCase());
    }

    rowKeys.sort(byKey);
    colKeys.sort(byKey);
    String out(_Acc? a) => a == null || a.n == 0 && spec.agg != PivotAgg.count
        ? ''
        : format(a.value(spec.agg));
    final rowName = cell(header, spec.rowField);
    final cells = <List<String>>[];
    if (spec.colField == null) {
      cells.add([
        rowName,
        valueHeader ?? '${spec.agg.name}: ${cell(header, spec.valueField)}',
      ]);
      for (final rk in rowKeys) {
        cells.add([rk, out(rowTot[rk])]);
      }
      cells.add([totalLabel, out(grand)]);
    } else {
      cells.add([
        '$rowName \\ ${cell(header, spec.colField!)}',
        ...colKeys,
        totalLabel,
      ]);
      for (final rk in rowKeys) {
        cells.add([
          rk,
          for (final ck in colKeys) out(acc['$rk\u0000$ck']),
          out(rowTot[rk]),
        ]);
      }
      cells.add([
        totalLabel,
        for (final ck in colKeys) out(colTot[ck]),
        out(grand),
      ]);
    }
    return PivotResult(cells, rowKeys.length, colKeys.length);
  }

  /// Sütundaki farklı değerler (süzgeç seçimi için), sıralı, en çok [limit].
  static List<String> distinct(List<List<String>> data, int col, {int limit = 500}) {
    final seen = <String>{};
    for (final row in data.skip(1)) {
      final v = col < row.length ? row[col].trim() : '';
      seen.add(v);
      if (seen.length >= limit) break;
    }
    return seen.toList()..sort();
  }
}

class _Acc {
  int n = 0;
  double sum = 0;
  double lo = double.infinity;
  double hi = -double.infinity;

  void add(double v) {
    n++;
    sum += v;
    lo = math.min(lo, v);
    hi = math.max(hi, v);
  }

  double value(PivotAgg agg) => switch (agg) {
        PivotAgg.sum => sum,
        PivotAgg.count => n.toDouble(),
        PivotAgg.average => n == 0 ? 0 : sum / n,
        PivotAgg.min => n == 0 ? 0 : lo,
        PivotAgg.max => n == 0 ? 0 : hi,
      };
}
