/// Satır/sütun ekle-silde **başvuru kaydırma** (Faz 25 / X3, 2026-10-23).
///
/// KÖK NEDEN: satır ekleyince `=TOPLA(A1:A10)` aynı kalıyordu (Excel
/// `A1:A11` yapar); silinen hücreye başvuran formül sessizce yanlış hücreyi
/// gösteriyordu (Excel `#BAŞV!` yapar). Birleştirmeler, koşullu biçim,
/// doğrulama, not, köprü ve süzgeç aralıkları da yerinde kalıyordu.
///
/// Kurallar Excel'inkiyle aynı:
/// * yapısal işlem **mutlak** başvuruları da kaydırır (`$A$5` → `$A$6`);
///   kopyala-yapıştır kaydırmasından (`sheet_edit.dart` `shiftFormula`)
///   farkı bu;
/// * aralığın içine eklenen satır aralığı büyütür; silinen satır aralığı
///   daraltır; aralığın tamamı silinirse `#REF!`;
/// * yalnız işlemin yapıldığı sayfaya başvurular değişir: aynı sayfadaki
///   formülde nitelemesiz başvurular, başka sayfalarda `Sayfa!A1` biçimi.
library;

import 'xlsx_reader.dart' show XlsxRange, XlsxReader;

/// Tek yapısal işlem: [rows] ise satır, değilse sütun; [at] 0 tabanlı;
/// [delta] > 0 eklenen, < 0 silinen satır/sütun sayısı.
class SheetShift {
  final bool rows;
  final int at;
  final int delta;
  const SheetShift({required this.rows, required this.at, required this.delta});

  /// Tek koordinat; silindiyse null.
  int? point(int x) {
    if (delta > 0) return x >= at ? x + delta : x;
    final n = -delta;
    if (x < at) return x;
    if (x < at + n) return null;
    return x - n;
  }

  /// Aralık [a, b] (dahil); tamamı silindiyse null.
  (int, int)? span(int a, int b) {
    if (delta > 0) {
      return (a >= at ? a + delta : a, b >= at ? b + delta : b);
    }
    final n = -delta;
    final na = a < at ? a : (a >= at + n ? a - n : at);
    final nb = b < at ? b : (b >= at + n ? b - n : at - 1);
    if (nb < na) return null;
    return (na, nb);
  }

  @override
  String toString() => '${rows ? 'satır' : 'sütun'} $at ${delta > 0 ? '+' : ''}$delta';
}

/// Aralığı kaydırır; tamamı silindiyse null.
XlsxRange? shiftRange(XlsxRange r, SheetShift op) {
  if (op.rows) {
    final s = op.span(r.r1, r.r2);
    return s == null ? null : XlsxRange(s.$1, r.c1, s.$2, r.c2);
  }
  final s = op.span(r.c1, r.c2);
  return s == null ? null : XlsxRange(r.r1, s.$1, r.r2, s.$2);
}

/// `sqref` ("A1:B5 D7") kaydırır; hiçbir parça kalmadıysa null.
String? shiftSqref(String sqref, SheetShift op) {
  final out = <String>[];
  for (final part in sqref.trim().split(RegExp(r'\s+'))) {
    if (part.isEmpty) continue;
    final shifted = _shiftRefText(part, op);
    if (shifted != null) out.add(shifted.replaceAll(r'$', ''));
  }
  return out.isEmpty ? null : out.join(' ');
}

/// Formül metnindeki (başında `=` olmadan) [targetSheet]'e başvuruları
/// kaydırır. [currentSheet] formülün bulunduğu sayfa: nitelemesiz
/// başvurular ona aittir.
String shiftFormulaStructural(String formula, SheetShift op,
    {required String currentSheet, required String targetSheet}) {
  final s = formula;
  final out = StringBuffer();
  final sameSheet = _eqSheet(currentSheet, targetSheet);
  var i = 0;
  while (i < s.length) {
    final ch = s[i];
    if (ch == '"') {
      final end = _quoted(s, i, '"');
      out.write(s.substring(i, end));
      i = end;
      continue;
    }
    String? sheet;
    var refStart = i;
    if (ch == "'") {
      final end = _quoted(s, i, "'");
      if (end < s.length && s[end] == '!') {
        sheet = s.substring(i + 1, end - 1).replaceAll("''", "'");
        refStart = end + 1;
      } else {
        out.write(s.substring(i, end));
        i = end;
        continue;
      }
    } else if (_isNameStart(ch) && (i == 0 || !_isNameChar(s[i - 1]))) {
      // Sayfa adı mı (Ad!), işlev mi (Ad(), başvuru mu?
      var j = i;
      while (j < s.length && _isNameChar(s[j])) {
        j++;
      }
      if (j < s.length && s[j] == '!') {
        sheet = s.substring(i, j);
        refStart = j + 1;
      }
    }
    if (refStart > s.length) break;
    final m = _refAt(s, refStart);
    final prefixOk = refStart == 0 ||
        sheet != null ||
        !_isNameChar(s[refStart - 1]) && s[refStart - 1] != '!';
    if (m != null && prefixOk) {
      final applies = sheet == null ? sameSheet : _eqSheet(sheet, targetSheet);
      out.write(s.substring(i, refStart));
      if (applies) {
        out.write(_shiftRefText(m, op) ?? '#REF!');
      } else {
        out.write(m);
      }
      i = refStart + m.length;
      continue;
    }
    // Başvuru değil: adı ya da karakteri olduğu gibi yaz.
    if (_isNameStart(ch) || _isDigit(ch)) {
      var j = i;
      while (j < s.length && (_isNameChar(s[j]) || s[j] == '.')) {
        j++;
      }
      out.write(s.substring(i, j));
      i = j;
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

bool _eqSheet(String a, String b) => a.toLowerCase() == b.toLowerCase();

int _quoted(String s, int start, String q) {
  var i = start + 1;
  while (i < s.length) {
    if (s[i] == q) {
      if (i + 1 < s.length && s[i + 1] == q) {
        i += 2;
        continue;
      }
      return i + 1;
    }
    i++;
  }
  return s.length;
}

bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

bool _isNameStart(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95 || u > 127 ||
      c == r'$';
}

bool _isNameChar(String c) => _isNameStart(c) || _isDigit(c);

final _cellRe = RegExp(r'\$?[A-Za-z]{1,3}\$?\d{1,7}');
final _rangeRe = RegExp(r'(\$?[A-Za-z]{1,3}\$?\d{1,7})(:(\$?[A-Za-z]{1,3}\$?\d{1,7}))?');
final _colsRe = RegExp(r'\$?[A-Za-z]{1,3}:\$?[A-Za-z]{1,3}');
final _rowsRe = RegExp(r'\$?\d{1,7}:\$?\d{1,7}');

/// [at]'te bir başvuru (hücre, aralık, sütun/satır aralığı) varsa metni.
String? _refAt(String s, int at) {
  bool endOk(int end) =>
      end >= s.length ||
      !(_isNameChar(s[end]) || s[end] == '(' || s[end] == '!' || s[end] == '.');
  for (final re in [_rangeRe, _colsRe, _rowsRe]) {
    final m = re.matchAsPrefix(s, at);
    if (m != null && m.end > at && endOk(m.end)) {
      final t = m.group(0)!;
      if (re == _rangeRe && !_cellRe.hasMatch(t)) continue;
      return t;
    }
  }
  return null;
}

/// Başvuru metnini kaydırır; silindiyse null. `$` işaretleri korunur.
String? _shiftRefText(String ref, SheetShift op) {
  final parts = ref.split(':');
  if (parts.length == 2 && _colsRe.hasMatch(ref) && !RegExp(r'\d').hasMatch(ref)) {
    // A:C — satır işlemi dokunmaz.
    if (op.rows) return ref;
    final a = _col(parts[0]), b = _col(parts[1]);
    final sp = op.span(a.$2, b.$2);
    if (sp == null) return null;
    return '${a.$1 ? r'$' : ''}${XlsxRange.colName(sp.$1)}:'
        '${b.$1 ? r'$' : ''}${XlsxRange.colName(sp.$2)}';
  }
  if (parts.length == 2 && RegExp(r'^\$?\d+$').hasMatch(parts[0]) &&
      RegExp(r'^\$?\d+$').hasMatch(parts[1])) {
    if (!op.rows) return ref;
    final a = _rowNum(parts[0]), b = _rowNum(parts[1]);
    final sp = op.span(a.$2, b.$2);
    if (sp == null) return null;
    return '${a.$1 ? r'$' : ''}${sp.$1 + 1}:${b.$1 ? r'$' : ''}${sp.$2 + 1}';
  }
  final a = _cell(parts[0]);
  if (a == null) return ref;
  if (parts.length == 1) {
    final p = op.point(op.rows ? a.row : a.col);
    if (p == null) return null;
    return op.rows ? a.withRow(p) : a.withCol(p);
  }
  final b = _cell(parts[1]);
  if (b == null) return ref;
  final x1 = op.rows ? a.row : a.col, x2 = op.rows ? b.row : b.col;
  final lo = x1 <= x2 ? x1 : x2, hi = x1 <= x2 ? x2 : x1;
  final sp = op.span(lo, hi);
  if (sp == null) return null;
  final na = x1 <= x2 ? sp.$1 : sp.$2, nb = x1 <= x2 ? sp.$2 : sp.$1;
  return op.rows
      ? '${a.withRow(na)}:${b.withRow(nb)}'
      : '${a.withCol(na)}:${b.withCol(nb)}';
}

(bool, int) _col(String t) {
  final abs = t.startsWith(r'$');
  var c = 0;
  for (final u in t.replaceAll(r'$', '').toUpperCase().codeUnits) {
    c = c * 26 + (u - 64);
  }
  return (abs, c - 1);
}

(bool, int) _rowNum(String t) =>
    (t.startsWith(r'$'), int.parse(t.replaceAll(r'$', '')) - 1);

class _Cell {
  final bool colAbs, rowAbs;
  final int row, col;
  const _Cell(this.colAbs, this.col, this.rowAbs, this.row);

  String withRow(int r) =>
      '${colAbs ? r'$' : ''}${XlsxRange.colName(col)}${rowAbs ? r'$' : ''}${r + 1}';
  String withCol(int c) =>
      '${colAbs ? r'$' : ''}${XlsxRange.colName(c)}${rowAbs ? r'$' : ''}${row + 1}';
}

_Cell? _cell(String t) {
  final m = RegExp(r'^(\$?)([A-Za-z]{1,3})(\$?)(\d{1,7})$').firstMatch(t);
  if (m == null) return null;
  var c = 0;
  for (final u in m.group(2)!.toUpperCase().codeUnits) {
    c = c * 26 + (u - 64);
  }
  return _Cell(m.group(1) == r'$', c - 1, m.group(3) == r'$',
      int.parse(m.group(4)!) - 1);
}

/// Koşullu biçim / doğrulama formülü: göreli başvurular aralığın sol-üst
/// hücresine (çapa) GÖRELİDİR — formül çapada yaşıyor gibi kaydırılır.
/// Çapa silindiyse (aralık daraldı) formül önce yeni çapanın eski konumuna
/// taşınır (yalnız göreli kısım), sonra kaydırılır — Excel'in sonucu.
String shiftAnchoredFormula(String formula, int anchorRow, int anchorCol,
    SheetShift op, String sheet) {
  var f = formula;
  final x = op.rows ? anchorRow : anchorCol;
  if (op.delta < 0 && op.point(x) == null) {
    final k = op.at - op.delta - x; // ilk kalan satır/sütuna uzaklık
    f = op.rows
        ? XlsxReader.shiftFormulaRefs(f, k, 0)
        : XlsxReader.shiftFormulaRefs(f, 0, k);
  }
  return shiftFormulaStructural(f, op, currentSheet: sheet, targetSheet: sheet);
}

/// `sqref`in çapası (ilk aralığın sol-üstü), 0 tabanlı.
(int, int)? sqrefAnchor(String sqref) {
  final first = sqref.trim().split(RegExp(r'\s+')).first.split(':').first;
  return XlsxRange.cellRef(first);
}
