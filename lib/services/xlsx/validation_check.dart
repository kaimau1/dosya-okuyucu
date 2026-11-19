/// **Veri doğrulama denetimi** (B10 m.3) — kuralın formüle bağlı kısımları:
/// aralıktan/addan/başka sayfadan gelen liste seçenekleri, başvurulu sınırlar
/// (`=$D$1`), özel formül (`=EMETİNSE(A1)` gibi). Sabit kurallar
/// [XlsxDataValidation.accepts]te kalır; burası formül motorunu ister.
///
/// Excel kuralı: formüldeki göreli başvurular kural aralığının SOL-ÜST
/// hücresine göredir; başka hücrede denetlerken aynı uzaklık kadar kayar.
library;

import '../formula_engine.dart';
import '../sheet_edit.dart' show shiftFormula;
import '../xlsx_reader.dart' show XlsxDataValidation, XlsxRange;

/// Girişin kurala göre sonucu — Excel'in üç uyarı türü.
enum XlsxValidationResult {
  /// Kurala uyuyor (ya da Excel uyarı göstermiyor).
  ok,

  /// "Durdur": giriş yazılmaz.
  stop,

  /// "Uyarı": kullanıcıya sorulur, isterse yazılır.
  warning,

  /// "Bilgi": yazılır, bilgi verilir.
  information,
}

class XlsxValidationCheck {
  /// Okuma motoru (görünen değerler). Ekranın kalıcı hesap durumlu motoru
  /// verilir; özel formül için ondan geçici kopya kurulur.
  final FormulaEngine engine;

  XlsxValidationCheck(this.engine);

  /// Liste seçeneklerinin üst sınırı (dev aralık açılır levhayı kilitlemesin).
  static const maxOptions = 1000;

  /// Hücrenin liste seçenekleri: satır içi (`"Evet,Hayır"`) ya da aralık /
  /// tanımlı ad / başka sayfa (`Liste!$A$1:$A$9`, `$B:$B`). Çözülemeyen
  /// kaynakta (DOLAYLI, KAYDIR…) boş.
  List<String> options(XlsxDataValidation v, int r, int c) {
    if (v.type != 'list') return const [];
    final inline = v.options;
    if (inline != null) return inline;
    var f = (v.listRef ?? v.formula1 ?? '').trim();
    if (f.startsWith('=')) f = f.substring(1);
    if (f.isEmpty) return const [];
    if (v.listRef == null) {
      final a = v.ranges.first;
      f = shiftFormula(f, r - a.r1, c - a.c1);
    }
    String? sheet;
    var ref = f;
    final bang = f.lastIndexOf('!');
    if (bang > 0) {
      sheet = f.substring(0, bang);
      ref = f.substring(bang + 1);
      if (sheet.length >= 2 && sheet.startsWith("'") && sheet.endsWith("'")) {
        sheet = sheet.substring(1, sheet.length - 1).replaceAll("''", "'");
      }
    }
    final reader = _engineFor(sheet);
    if (reader == null) return const [];
    final range = XlsxRange.parse(ref) ?? _wholeColumns(ref, reader.grid.length);
    if (range == null) return const [];
    final out = <String>[];
    final seen = <String>{};
    final lastRow = range.r2 < reader.grid.length ? range.r2 : reader.grid.length - 1;
    for (var rr = range.r1; rr <= lastRow; rr++) {
      for (var cc = range.c1; cc <= range.c2; cc++) {
        final s = reader.displayValue(rr, cc).trim();
        if (s.isEmpty || !seen.add(s)) continue;
        out.add(s);
        if (out.length >= maxOptions) return out;
      }
    }
    return out;
  }

  /// [raw] (hücreye yazılacak model metni) kurala uyuyor mu.
  bool accepts(XlsxDataValidation v, int r, int c, String raw) {
    final t = raw.trim();
    if (t.isEmpty) return v.allowBlank;
    if (t.startsWith('=')) return true; // formül: sonucu Excel'e bırakılır
    switch (v.type) {
      case 'list':
        if (v.options != null) return v.accepts(raw);
        final opts = options(v, r, c);
        if (opts.isEmpty) return true; // kaynak çözülemedi
        final lv = t.toLowerCase();
        return opts.any((o) => o.toLowerCase() == lv);
      case 'custom':
        return _custom(v, r, c, raw);
      case 'whole' || 'decimal' || 'date' || 'time' || 'textLength':
        final f1 = _bound(v, v.formula1, r, c);
        final f2 = _bound(v, v.formula2, r, c);
        return v.copyWith(formula1: f1, formula2: f2).accepts(raw);
      default:
        return v.accepts(raw);
    }
  }

  /// Excel'in göstereceği uyarı (`showErrorMessage` kapalıysa hiç).
  XlsxValidationResult check(XlsxDataValidation v, int r, int c, String raw) {
    if (accepts(v, r, c, raw) || !v.showErrorMessage) {
      return XlsxValidationResult.ok;
    }
    return switch (v.errorStyle) {
      'warning' => XlsxValidationResult.warning,
      'information' => XlsxValidationResult.information,
      _ => XlsxValidationResult.stop,
    };
  }

  /// Başvurulu/formüllü sınır (`$D$1`, `BUGÜN()`) → sayı metni. Sabit sayı
  /// ve tırnaklı tarih olduğu gibi kalır.
  String? _bound(XlsxDataValidation v, String? f, int r, int c) {
    if (f == null) return null;
    var t = f.trim();
    if (t.isEmpty || double.tryParse(t) != null || t.startsWith('"')) return f;
    if (t.startsWith('=')) t = t.substring(1);
    final a = v.ranges.first;
    final out = engine.preview('=${shiftFormula(t, r - a.r1, c - a.c1)}', r, c);
    return double.tryParse(out) != null ? out : f;
  }

  /// Özel formül: hücreye [raw] yazılmış gibi hesaplanır; DOĞRU ya da sıfır
  /// olmayan sayı = geçerli (Excel: hata ve YANLIŞ geçersiz).
  bool _custom(XlsxDataValidation v, int r, int c, String raw) {
    var f = (v.formula1 ?? '').trim();
    if (f.startsWith('=')) f = f.substring(1);
    if (f.isEmpty) return true;
    final a = v.ranges.first;
    f = shiftFormula(f, r - a.r1, c - a.c1);
    // Izgaranın sığ kopyası: yalnız değişen satır kopyalanır.
    final grid = List<List<String>>.of(engine.grid);
    while (grid.length <= r) {
      grid.add(<String>[]);
    }
    final row = List<String>.of(grid[r]);
    while (row.length <= c) {
      row.add('');
    }
    row[c] = raw;
    grid[r] = row;
    final sheets = <String, List<List<String>>>{
      ...?engine.sheets,
      engine.sheetName: grid,
    };
    final probe = FormulaEngine(grid,
        sheets: sheets,
        sheetName: engine.sheetName,
        tables: engine.tables.values.toList());
    final out = probe.preview('=$f', r, c);
    if (out == 'DOĞRU' || out == 'TRUE') return true;
    final n = double.tryParse(out);
    return n != null && n != 0;
  }

  /// [sheet] adlı sayfanın okuma motoru (boş = bu sayfa; büyük/küçük harf
  /// duyarsız). Sayfa yoksa null.
  FormulaEngine? _engineFor(String? sheet) {
    if (sheet == null || sheet.isEmpty || sheet == engine.sheetName) {
      return engine;
    }
    final all = engine.sheets;
    if (all == null) return null;
    for (final e in all.entries) {
      if (e.key.toLowerCase() != sheet.toLowerCase()) continue;
      return FormulaEngine(e.value,
          sheets: all,
          sheetName: e.key,
          state: engine.state,
          tables: engine.tables.values.toList());
    }
    return null;
  }

  /// `$A:$B` gibi tam sütun başvurusu (dolu satırlarla sınırlı).
  static XlsxRange? _wholeColumns(String ref, int rows) {
    final m = RegExp(r'^\$?([A-Za-z]{1,3}):\$?([A-Za-z]{1,3})$').firstMatch(ref.trim());
    if (m == null || rows == 0) return null;
    final a = XlsxRange.cellRef('${m[1]}1'), b = XlsxRange.cellRef('${m[2]}1');
    if (a == null || b == null) return null;
    return XlsxRange(0, a.$2, rows - 1, b.$2);
  }
}
