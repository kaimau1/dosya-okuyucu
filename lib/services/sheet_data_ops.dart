/// Excel **Veri** araçlarının saf mantığı (Faz 27): yinelenenleri bulma ve
/// metni sütunlara bölme. Ekran yalnız aralığı toplayıp sonucu yazar.
library;

import '../core/text_search.dart';
import 'sheet_edit.dart' show compareCellText;

/// [rows] (seçili aralığın değerleri, satır × sütun) içinde **silinecek**
/// satırların göreli indeksleri: ilk geçen kalır, sonrakiler silinir.
///
/// [cols] karşılaştırılacak göreli sütunlar (boşsa hepsi); [hasHeader] ise ilk
/// satır dokunulmaz. Excel gibi büyük/küçük harf duyarsız (Türkçe katlamalı).
List<int> duplicateRowIndexes(List<List<String>> rows,
    {List<int> cols = const [], bool hasHeader = false}) {
  final seen = <String>{};
  final remove = <int>[];
  for (var i = 0; i < rows.length; i++) {
    if (hasHeader && i == 0) continue;
    final row = rows[i];
    final use = cols.isEmpty ? List.generate(row.length, (k) => k) : cols;
    final key = use
        .map((c) => c < row.length ? turkishFold(row[c]) : '')
        .join('\u0001');
    // Tamamen boş satırlar "yinelenen" sayılmaz (Excel de silmez).
    if (key.replaceAll('\u0001', '').isEmpty) continue;
    if (!seen.add(key)) remove.add(i);
  }
  return remove;
}

/// Metni sütunlara bölme ayracı.
class SplitSpec {
  final bool comma, semicolon, tab, space;
  final String custom;

  /// Art arda ayraçlar tek sayılsın.
  final bool merge;

  const SplitSpec({
    this.comma = false,
    this.semicolon = false,
    this.tab = false,
    this.space = false,
    this.custom = '',
    this.merge = false,
  });

  bool get any => comma || semicolon || tab || space || custom.isNotEmpty;

  Set<String> get delimiters => {
        if (comma) ',',
        if (semicolon) ';',
        if (tab) '\t',
        if (space) ' ',
        if (custom.isNotEmpty) custom,
      };
}

/// [text]'i [spec] ayraçlarından böler; `"…"` içindeki ayraç bölmez
/// (çift tırnak metin niteleyicisi, `""` = tırnak).
List<String> splitText(String text, SplitSpec spec) {
  final ds = spec.delimiters;
  if (ds.isEmpty || text.isEmpty) return [text];
  final out = <String>[];
  final cur = StringBuffer();
  var inQuote = false;
  var i = 0;
  var lastWasDelim = false;
  while (i < text.length) {
    final ch = text[i];
    if (ch == '"') {
      if (inQuote && i + 1 < text.length && text[i + 1] == '"') {
        cur.write('"');
        i += 2;
        continue;
      }
      inQuote = !inQuote;
      i++;
      lastWasDelim = false;
      continue;
    }
    if (!inQuote) {
      String? hit;
      for (final d in ds) {
        if (text.startsWith(d, i) && (hit == null || d.length > hit.length)) {
          hit = d;
        }
      }
      if (hit != null) {
        if (!(spec.merge && lastWasDelim)) {
          out.add(cur.toString());
          cur.clear();
        }
        lastWasDelim = true;
        i += hit.length;
        continue;
      }
    }
    lastWasDelim = false;
    cur.write(ch);
    i++;
  }
  out.add(cur.toString());
  return out;
}

/// Çok düzeyli sıralama anahtarı: sütunun değeri (satır → görünen değer) ve
/// yön.
class SortLevel {
  final String Function(int row) value;
  final bool ascending;
  const SortLevel(this.value, {this.ascending = true});
}

/// [first]..[last] satırlarının yeni sırası (Excel "Özel sıralama"): birinci
/// düzey eşitse ikinciye bakılır; tümü eşitse özgün sıra korunur (kararlı).
List<int> multiSortOrder(int first, int last, List<SortLevel> levels) {
  final rows = [for (var r = first; r <= last; r++) r];
  final keys = [
    for (final l in levels) {for (final r in rows) r: l.value(r)},
  ];
  rows.sort((a, b) {
    for (var i = 0; i < levels.length; i++) {
      final cmp = compareCellText(keys[i][a]!, keys[i][b]!);
      if (cmp != 0) return levels[i].ascending ? cmp : -cmp;
    }
    return a.compareTo(b);
  });
  return rows;
}
