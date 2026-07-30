import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:excel/excel.dart';
import 'package:flutter/painting.dart' show TextAlign;

import '../core/excel_format.dart';
import 'xlsx_reader.dart';
import 'xlsx_save_patch.dart';

// Görünüm modelinin tamamı (aralık, kenarlık, hizalama, koşullu biçim…)
// ekranlara buradan açılır — ad çakışması yok.
export 'xlsx_reader.dart';

/// Bir hücrenin Excel'deki görünümü.
///
/// Değerler `styles.xml`den BİZİM okuyucumuzla gelir (excel paketi hizalama,
/// kenarlık, tema rengi ve sayı biçimi vermiyor — bkz. xlsx_reader.dart).
class XlsxCellStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final double? fontSize;
  final String? fontFamily;
  final Color? fontColor;
  final Color? background;
  final XlsxHAlign hAlign;
  final XlsxVAlign vAlign;
  final bool wrap;
  final int indent;
  final int rotation;
  final XlsxBorder border;
  final String numFmtCode;

  const XlsxCellStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize,
    this.fontFamily,
    this.fontColor,
    this.background,
    this.hAlign = XlsxHAlign.general,
    this.vAlign = XlsxVAlign.bottom,
    this.wrap = false,
    this.indent = 0,
    this.rotation = 0,
    this.border = const XlsxBorder(),
    this.numFmtCode = 'General',
  });

  /// Excel kuralı: açık hizalama yoksa SAYI sağa, metin sola yaslanır.
  /// Hücrenin yatay hizalaması.
  ///
  /// `general` (dosyada açık hizalama YOK) Excel'de sayfanın yönüne göre
  /// aynalanır: soldan sağa sayfada metin sola / sayı sağa, **sağdan sola
  /// sayfada metin sağa / sayı sola**. Açık `left`/`right` ise dosyada
  /// yazdığı gibi mutlaktır — Excel de onları aynalamaz.
  TextAlign alignFor(bool numeric, {bool rightToLeft = false}) =>
      switch (hAlign) {
        XlsxHAlign.left => TextAlign.left,
        XlsxHAlign.center => TextAlign.center,
        XlsxHAlign.right => TextAlign.right,
        XlsxHAlign.justify => TextAlign.justify,
        XlsxHAlign.general => numeric
            ? (rightToLeft ? TextAlign.left : TextAlign.right)
            : (rightToLeft ? TextAlign.right : TextAlign.left),
      };

  /// Araç çubuğu düğmelerinin durumu için (açık hizalama).
  TextAlign get align => alignFor(false);

  XlsxCellStyle copyWith({
    bool? bold,
    bool? italic,
    XlsxHAlign? hAlign,
    Color? background,
  }) =>
      XlsxCellStyle(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline,
        strike: strike,
        fontSize: fontSize,
        fontFamily: fontFamily,
        fontColor: fontColor,
        background: background ?? this.background,
        hAlign: hAlign ?? this.hAlign,
        vAlign: vAlign,
        wrap: wrap,
        indent: indent,
        rotation: rotation,
        border: border,
        numFmtCode: numFmtCode,
      );
}

/// Birleştirilmiş hücre aralığı (0 tabanlı, uçlar dahil).
class XlsxMerge {
  final int rowStart, colStart, rowEnd, colEnd;
  const XlsxMerge(this.rowStart, this.colStart, this.rowEnd, this.colEnd);
  bool covers(int r, int c) =>
      r >= rowStart && r <= rowEnd && c >= colStart && c <= colEnd;
  bool isAnchor(int r, int c) => r == rowStart && c == colStart;
}

/// Ekranda gösterilecek tek hücrelik sonuç.
class XlsxCellView {
  final String text;

  /// Sayı biçimindeki `[Red]` gibi renk etiketi (yazı rengini EZER).
  final Color? formatColor;
  final bool numeric;
  const XlsxCellView(this.text, {this.formatColor, this.numeric = false});
}

class XlsxSheet {
  final String name;

  /// Ham hücre metinleri — formül motorunun ve CSV dışa aktarımının girdisi.
  /// Sayılar burada HAM durur (`1234.5`), biçim yalnız gösterimde uygulanır;
  /// yoksa `=A1*2` gibi formüller "₺1.234,50"yi sayı sanıp bozulurdu.
  final List<List<String>> rows;

  final Sheet _sheet;
  final XlsxSheetLayout layout;
  final XlsxStyles styles;
  final bool date1904;

  /// Uygulama içinde değiştirilen hücre biçimleri (dosyadaki paylaşımlı stil
  /// nesnesini bozmamak için ayrı tutulur).
  final Map<int, XlsxCellStyle> _overrides = {};

  /// styleIndex → çözümlenmiş görünüm (her karede yeniden hesaplanmasın).
  final Map<int, XlsxCellStyle> _styleCache = {};

  late final List<XlsxMerge> merges = [
    for (final m in layout.merges) XlsxMerge(m.r1, m.c1, m.r2, m.c2),
  ];

  XlsxSheet({
    required this.name,
    required this.rows,
    required Sheet sheet,
    required this.layout,
    required this.styles,
    this.date1904 = false,
  }) : _sheet = sheet;

  Sheet get excelSheet => _sheet;

  int get maxCols {
    final fromCells = layout.colCount;
    final fromRows = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return fromCells > fromRows ? fromCells : fromRows;
  }

  int get maxRows => rows.length > layout.rowCount ? rows.length : layout.rowCount;

  int get frozenRows => layout.frozenRows;
  int get frozenCols => layout.frozenCols;
  bool get showGridLines => layout.showGridLines;
  bool get isHiddenRow0 => false;

  /// Sayfa sağdan sola mı çiziliyor (Excel: *Sayfa Düzeni → Sayfayı Sağdan
  /// Sola*). Arapça/İbranice tabloların ayrılmaz parçası: A sütunu SAĞDA
  /// başlar. Dosyadan okunur (`<sheetView rightToLeft="1"/>`) ve
  /// [XlsxSavePatch] ile geri yazılır.
  ///
  /// **Arayüz dilinden bağımsız:** yön belgenin özelliğidir. Arapça arayüzde
  /// açılan soldan sağa bir tablo yine soldan sağa çizilir — Excel de böyle
  /// davranır.
  bool get rightToLeft => layout.rightToLeft;

  void setRightToLeft(bool value) => layout.rightToLeft = value;

  /// Bu hücreyi kapsayan birleştirme (yoksa null).
  XlsxMerge? mergeAt(int r, int c) {
    for (final m in merges) {
      if (m.covers(r, c)) return m;
    }
    return null;
  }

  bool isRowHidden(int r) => layout.hiddenRows.contains(r);
  bool isColHidden(int c) => layout.hiddenCols.contains(c);

  // ── ölçüler ───────────────────────────────────────────────────────────────

  /// Excel sütun genişliği "karakter" birimindedir; ekran pikseline çevrilir.
  /// Excel'in kendi formülü: piksel = round(genişlik * 7) + 5 (Calibri 11).
  double colWidth(int c) {
    if (layout.hiddenCols.contains(c)) return 0;
    final chars = layout.colWidthChars(c);
    return (chars * 7.0 + 5).clamp(6.0, 500.0);
  }

  /// Satır yüksekliği puntodur; 1 pt ≈ 1.333 px.
  double rowHeight(int r) {
    if (layout.hiddenRows.contains(r)) return 0;
    final pt = layout.rowHeightPt(r);
    return (pt * 1.34).clamp(8.0, 409.0);
  }

  /// Sütun genişliğini karakter biriminde ayarlar (Excel'in kendi birimi,
  /// varsayılan 8.43). 0 = gizle. Hem görünüm modeline hem `excel` paketinin
  /// haritasına yazılır — ikincisi olmadan kaydetmede kaybolurdu.
  void setColWidthChars(int c, double chars) {
    if (c < 0 || c >= 16384) return;
    final v = chars.clamp(0.0, 255.0).toDouble();
    layout.colWidths[c] = v;
    // Gizli sütunda `colWidth` 0 döndüğü için yeni genişlik görünmezdi.
    if (v <= 0) {
      layout.hiddenCols.add(c);
    } else {
      layout.hiddenCols.remove(c);
    }
    _sheet.setColumnWidth(c, v);
  }

  /// Satır yüksekliğini punto olarak ayarlar (varsayılan 15). 0 = gizle.
  ///
  /// ponytail: TAMAMEN BOŞ bir satırın yüksekliği kaydedilmez — `excel`
  /// paketi `<row>` etiketini yalnız hücresi olan satırlar için yazıyor
  /// (`save_file.dart` `_setRows`). Ekranda doğru görünür, dosyada kaybolur.
  /// Gerekirse çözüm: o satıra boş bir hücre yazmak.
  void setRowHeightPt(int r, double pt) {
    if (r < 0 || r >= 1048576) return;
    final v = pt.clamp(0.0, 409.0).toDouble();
    layout.rowHeights[r] = v;
    if (v <= 0) {
      layout.hiddenRows.add(r);
    } else {
      layout.hiddenRows.remove(r);
    }
    _sheet.setRowHeight(r, v);
  }

  // ── stil ──────────────────────────────────────────────────────────────────

  /// Hücrenin stil indeksi: hücrenin kendi `s`si, yoksa satır, yoksa sütun.
  int styleIndexAt(int r, int c) {
    final cell = layout.cellAt(r, c);
    if (cell != null) return cell.styleIndex;
    return layout.rowStyles[r] ?? layout.colStyles[c] ?? 0;
  }

  XlsxCellStyle? styleAt(int r, int c) {
    final ov = _overrides[cellKey(r, c)];
    if (ov != null) return ov;
    final idx = styleIndexAt(r, c);
    final cached = _styleCache[idx];
    if (cached != null) return cached;
    final built = _buildStyle(styles.formatAt(idx));
    _styleCache[idx] = built;
    return built;
  }

  XlsxCellStyle _buildStyle(XlsxFormat f) => XlsxCellStyle(
        bold: f.font.bold,
        italic: f.font.italic,
        underline: f.font.underline != null && f.font.underline != 'none',
        strike: f.font.strike,
        fontSize: f.font.size,
        fontFamily: f.font.name,
        fontColor: _color(f.font.colorArgb),
        background: _color(f.fill.effectiveArgb),
        hAlign: f.align.horizontal,
        vAlign: f.align.vertical,
        wrap: f.align.wrapText,
        indent: f.align.indent,
        rotation: f.align.textRotation,
        border: f.border,
        numFmtCode: f.numFmtCode,
      );

  /// Tek hücrenin görünümünü uygulama içinde değiştirir (dosyadaki paylaşımlı
  /// stil nesnesi bozulmaz — kaydetmede excel paketi kendi stilini yazar).
  void patchStyle(int r, int c, XlsxCellStyle? style) {
    if (r < 0 || c < 0) return;
    if (style == null) {
      _overrides.remove(cellKey(r, c));
    } else {
      _overrides[cellKey(r, c)] = style;
    }
  }

  // ── değer / gösterim ──────────────────────────────────────────────────────

  String rawAt(int r, int c) {
    if (r < 0 || r >= rows.length) return '';
    final row = rows[r];
    return (c >= 0 && c < row.length) ? row[c] : '';
  }

  bool isNumericAt(int r, int c) {
    final raw = rawAt(r, c);
    if (raw.isEmpty) return false;
    if (raw.startsWith('=')) {
      final cell = layout.cellAt(r, c);
      return cell?.number != null;
    }
    return double.tryParse(raw) != null;
  }

  /// Bu hücrenin sayı biçim kodu.
  String numFmtCode(int r, int c) =>
      styleAt(r, c)?.numFmtCode ?? 'General';

  /// Formül hücresinde Excel'in dosyaya yazdığı SON SONUÇ (önbellek).
  /// Kendi motorumuz hesaplayamazsa buna düşeriz — böylece desteklemediğimiz
  /// bir fonksiyon bile Excel'deki değeriyle görünür.
  String? cachedResultAt(int r, int c) {
    final cell = layout.cellAt(r, c);
    if (cell == null || cell.formula == null) return null;
    if (cell.number != null) return generalNumberRaw(cell.number!);
    if (cell.text != null) return cell.text;
    if (cell.boolean != null) return cell.boolean! ? 'DOĞRU' : 'YANLIŞ';
    if (cell.error != null) return cell.error;
    return null;
  }

  /// Hücrede **Excel'de göründüğü gibi** metin (+ biçim rengi).
  ///
  /// [computed] formül motorunun verdiği ham sonuçtur (sayılar `.` ondalıklı).
  XlsxCellView viewAt(int r, int c, String computed) {
    final cell = layout.cellAt(r, c);
    if (cell?.error != null && (cell?.formula == null)) {
      return XlsxCellView(localizedExcelError(cell!.error!));
    }
    var value = computed;
    // Motorumuz hesaplayamadıysa Excel'in dosyaya yazdığı SONUCA düşülür:
    // desteklemediğimiz bir fonksiyon (#AD?) bile Excel'deki değeriyle
    // görünür — kullanıcı hesap yerine hata kodu görmemeli.
    if (cell?.formula != null && (value.isEmpty || isExcelErrorText(value))) {
      final cached = cachedResultAt(r, c);
      if (cached != null &&
          cached.isNotEmpty &&
          (!isExcelErrorText(cached) || value.isEmpty)) {
        value = cached;
      }
    }
    if (value.isEmpty) return const XlsxCellView('');
    if (isExcelErrorText(value)) {
      return XlsxCellView(localizedExcelError(value));
    }

    final code = numFmtCode(r, c);
    final fmt = ExcelNumberFormat.parse(code);
    final number = double.tryParse(value);
    if (number == null) {
      // Metin: biçimde metin bölümü varsa uygulanır (`;;;"—"` gibi).
      if (fmt.isGeneral) return XlsxCellView(value);
      final res = fmt.format(value, date1904: date1904);
      return XlsxCellView(res.text, formatColor: _color(res.colorArgb));
    }
    if (fmt.isGeneral) {
      return XlsxCellView(generalNumber(number), numeric: true);
    }
    final res = fmt.format(number, date1904: date1904);
    return XlsxCellView(res.text,
        formatColor: _color(res.colorArgb), numeric: true);
  }

  /// Eski API (testler + CSV): yalnız metin.
  String displayText(int r, int c, String computed) =>
      viewAt(r, c, computed).text;

  /// Bu hücrede geçerli koşullu biçim kuralı (en yüksek öncelikli).
  XlsxCondRule? condRuleAt(int r, int c) {
    XlsxCondRule? best;
    for (final rule in layout.condFormats) {
      if (!rule.covers(r, c)) continue;
      if (best == null || rule.priority < best.priority) best = rule;
    }
    return best;
  }

  XlsxDataValidation? validationAt(int r, int c) {
    for (final v in layout.validations) {
      if (v.covers(r, c)) return v;
    }
    return null;
  }

  static Color? _color(int? argb) => argb == null ? null : Color(argb);
}

/// .xlsx dosyasını hücre bazında düzenler ve kaydeder.
///
/// **Okuma** (görünüm) `XlsxReader` ile ham OOXML'den, **yazma** `excel`
/// paketiyle yapılır. İkisi ayrı tutulur: okuma sadakati paket hatalarına
/// takılmaz, yazma tarafı ise kanıtlanmış paket yolunda kalır.
class XlsxEditor {
  final Excel _excel;
  final List<XlsxSheet> sheets;
  final XlsxWorkbook workbook;

  XlsxEditor._(this._excel, this.sheets, this.workbook);

  static XlsxEditor parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    XlsxWorkbook wb;
    try {
      wb = XlsxReader.read(bytes);
    } catch (_) {
      wb = XlsxWorkbook(
        sheets: const [],
        styles: XlsxStyles(
            numFmts: const {}, formats: [XlsxFormat.fallback()], dxfs: const [], theme: const []),
        theme: const [],
        date1904: false,
      );
    }
    final sheets = _buildSheets(excel, wb);
    _seedSizes(sheets);
    return XlsxEditor._(excel, sheets, wb);
  }

  /// Ölçüleri `excel` paketinin haritasına aktarır — SADAKAT için şart.
  ///
  /// Paket `<col min="1" max="10" width="20"/>` aralığının YALNIZ `min`ini
  /// okuyor (excel 4.0.6 `parse.dart`), kaydederken de `<cols>`u kendi
  /// haritasından baştan yazıyor (`save_file.dart` `_setColumns`). Sonuç:
  /// tek bir hücre düzenlenip kaydedilince B–J sütunları varsayılan 8.43'e
  /// düşüyordu. Bizim okuyucumuz aralığı doğru açıyor; paketin haritasını
  /// ondan doldurunca kaydetme genişlikleri koruyor.
  static void _seedSizes(List<XlsxSheet> sheets) {
    for (final s in sheets) {
      s.layout.colWidths.forEach(s.excelSheet.setColumnWidth);
      s.layout.rowHeights.forEach(s.excelSheet.setRowHeight);
    }
  }

  static List<XlsxSheet> _buildSheets(Excel excel, XlsxWorkbook wb) {
    final sheets = <XlsxSheet>[];
    for (final entry in excel.tables.entries) {
      XlsxSheetLayout? layout;
      for (final l in wb.sheets) {
        if (l.name == entry.key) {
          layout = l;
          break;
        }
      }
      layout ??= XlsxSheetLayout(name: entry.key);
      sheets.add(XlsxSheet(
        name: entry.key,
        rows: _rowsFrom(layout, entry.value),
        sheet: entry.value,
        layout: layout,
        styles: wb.styles,
        date1904: wb.date1904,
      ));
    }
    // excel paketinin okuyamadığı sayfa varsa (nadir) modelden ekle.
    for (final l in wb.sheets) {
      if (sheets.any((s) => s.name == l.name)) continue;
      final table = excel[l.name];
      sheets.add(XlsxSheet(
        name: l.name,
        rows: _rowsFrom(l, table),
        sheet: table,
        layout: l,
        styles: wb.styles,
        date1904: wb.date1904,
      ));
    }
    return sheets;
  }

  /// Ham hücre metinleri: sayı → `1234.5`, formül → `=SUM(A1:A3)`,
  /// metin → olduğu gibi. (Gösterim biçimi UYGULANMAZ, bkz. XlsxSheet.rows.)
  static List<List<String>> _rowsFrom(XlsxSheetLayout layout, Sheet fallback) {
    if (layout.cells.isEmpty) {
      // Okuyucu bir şey bulamadıysa excel paketinin verisine düş (bozuk dosya).
      return [
        for (final row in fallback.rows) [for (final c in row) _legacyText(c)],
      ];
    }
    final rows = <List<String>>[];
    for (var r = 0; r <= layout.maxRow; r++) {
      var last = -1;
      for (var c = layout.maxCol; c >= 0; c--) {
        if (layout.cells.containsKey(cellKey(r, c))) {
          last = c;
          break;
        }
      }
      if (last < 0) {
        rows.add(<String>[]);
        continue;
      }
      final row = List<String>.filled(last + 1, '', growable: true);
      for (var c = 0; c <= last; c++) {
        final cell = layout.cells[cellKey(r, c)];
        if (cell == null) continue;
        row[c] = _rawText(cell);
      }
      rows.add(row);
    }
    return rows;
  }

  static String _rawText(XlsxCell cell) {
    if (cell.formula != null && cell.formula!.isNotEmpty) {
      return '=${cell.formula}';
    }
    if (cell.error != null) return cell.error!;
    if (cell.boolean != null) return cell.boolean! ? 'DOĞRU' : 'YANLIŞ';
    if (cell.number != null) return generalNumberRaw(cell.number!);
    return cell.text ?? '';
  }

  static String _legacyText(Data? cell) {
    final v = cell?.value;
    return switch (v) {
      null => '',
      TextCellValue() => v.value.toString(),
      IntCellValue() => '${v.value}',
      DoubleCellValue() => generalNumberRaw(v.value),
      BoolCellValue() => v.value ? 'DOĞRU' : 'YANLIŞ',
      DateCellValue() => '${v.year}-${_p2(v.month)}-${_p2(v.day)}',
      TimeCellValue() => '${_p2(v.hour)}:${_p2(v.minute)}',
      DateTimeCellValue() =>
        '${v.year}-${_p2(v.month)}-${_p2(v.day)} ${_p2(v.hour)}:${_p2(v.minute)}',
      FormulaCellValue() => '=${v.formula}',
    };
  }

  static String _p2(int n) => n.toString().padLeft(2, '0');

  XlsxSheet? _modelSheet(String name) {
    for (final s in sheets) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Bir hücreyi günceller (hem görünüm modeli hem excel nesnesi).
  void setCell(String sheetName, int rowIndex, int colIndex, String value) {
    final sheet = _modelSheet(sheetName);
    if (sheet == null) return;
    while (sheet.rows.length <= rowIndex) {
      sheet.rows.add(<String>[]);
    }
    final row = sheet.rows[rowIndex];
    while (row.length <= colIndex) {
      row.add('');
    }
    row[colIndex] = value;

    // Görünüm modeli de güncellensin (biçim/hizalama hücrenin kendi stilinden
    // gelmeye devam eder — yalnız değer değişir).
    final layout = sheet.layout;
    final key = cellKey(rowIndex, colIndex);
    final old = layout.cells[key];
    final number = double.tryParse(value);
    layout.cells[key] = XlsxCell(
      row: rowIndex,
      col: colIndex,
      styleIndex: old?.styleIndex ?? 0,
      number: (value.startsWith('=') || number == null) ? null : number,
      text: (value.startsWith('=') || number != null) ? null : value,
      formula: value.length > 1 && value.startsWith('=')
          ? value.substring(1)
          : null,
    );
    if (rowIndex > layout.maxRow) layout.maxRow = rowIndex;
    if (colIndex > layout.maxCol) layout.maxCol = colIndex;

    _excel.updateCell(
      sheetName,
      CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
      _cellValueFor(value),
    );
  }

  /// Kullanıcının yazdığı metni uygun Excel hücre tipine çevirir.
  static CellValue _cellValueFor(String value) {
    if (value.isEmpty) return TextCellValue('');
    if (value.length > 1 && value.startsWith('=')) {
      return FormulaCellValue(value.substring(1));
    }
    final intVal = int.tryParse(value);
    if (intVal != null && !_looksLikeCode(value)) return IntCellValue(intVal);
    final dbl = double.tryParse(value);
    if (dbl != null && dbl.isFinite && !_looksLikeCode(value)) {
      return DoubleCellValue(dbl);
    }
    return TextCellValue(value);
  }

  /// "007", "0123" gibi baştaki sıfırı önemli olan diziler metin kalır.
  static bool _looksLikeCode(String v) {
    if (v.length > 1 && v.startsWith('0') && !v.startsWith('0.')) return true;
    if (v.length > 15) return true;
    return false;
  }

  // ── yapısal işlemler ──────────────────────────────────────────────────────
  // Hücreler (değer + stil) elle kaydırılır. *Niye:* excel 4.0.6'nın
  // Excel-seviye insertRow/insertColumn'u no-op çıktı (bkz. HAFIZA).

  void insertRow(String sheetName, int rowIndex) {
    final table = _excel.tables[sheetName];
    final model = _modelSheet(sheetName);
    if (table == null || model == null) return;
    final at = rowIndex.clamp(0, model.rows.length);
    final maxR = table.maxRows;
    final maxC = table.maxColumns;
    for (var r = maxR; r > at; r--) {
      for (var c = 0; c < maxC; c++) {
        _copyCell(table, r - 1, c, r, c);
      }
    }
    for (var c = 0; c < maxC; c++) {
      _clearCell(table, at, c);
    }
    model.rows.insert(at, <String>[]);
    _shiftLayoutRows(model.layout, at, 1);
  }

  void deleteRow(String sheetName, int rowIndex) {
    final table = _excel.tables[sheetName];
    final model = _modelSheet(sheetName);
    if (table == null || model == null) return;
    if (rowIndex < 0 || rowIndex >= model.rows.length) return;
    final maxR = table.maxRows;
    final maxC = table.maxColumns;
    for (var r = rowIndex; r < maxR - 1; r++) {
      for (var c = 0; c < maxC; c++) {
        _copyCell(table, r + 1, c, r, c);
      }
    }
    if (maxR > 0) {
      for (var c = 0; c < maxC; c++) {
        _clearCell(table, maxR - 1, c);
      }
    }
    model.rows.removeAt(rowIndex);
    _shiftLayoutRows(model.layout, rowIndex, -1);
  }

  void insertColumn(String sheetName, int colIndex) {
    final table = _excel.tables[sheetName];
    final model = _modelSheet(sheetName);
    if (table == null || model == null) return;
    final at = colIndex.clamp(0, model.maxCols);
    final maxR = table.maxRows;
    final maxC = table.maxColumns;
    for (var c = maxC; c > at; c--) {
      for (var r = 0; r < maxR; r++) {
        _copyCell(table, r, c - 1, r, c);
      }
    }
    for (var r = 0; r < maxR; r++) {
      _clearCell(table, r, at);
    }
    for (final row in model.rows) {
      if (at <= row.length) row.insert(at, '');
    }
    _shiftLayoutCols(model.layout, at, 1);
  }

  void deleteColumn(String sheetName, int colIndex) {
    final table = _excel.tables[sheetName];
    final model = _modelSheet(sheetName);
    if (table == null || model == null) return;
    if (colIndex < 0 || colIndex >= model.maxCols) return;
    final maxR = table.maxRows;
    final maxC = table.maxColumns;
    for (var c = colIndex; c < maxC - 1; c++) {
      for (var r = 0; r < maxR; r++) {
        _copyCell(table, r, c + 1, r, c);
      }
    }
    if (maxC > 0) {
      for (var r = 0; r < maxR; r++) {
        _clearCell(table, r, maxC - 1);
      }
    }
    for (final row in model.rows) {
      if (colIndex < row.length) row.removeAt(colIndex);
    }
    _shiftLayoutCols(model.layout, colIndex, -1);
  }

  /// Satır ekleme/silme sonrası görünüm modelini (hücre stilleri, yükseklikler)
  /// kaydırır — yoksa biçimler bir satır yukarıda/aşağıda kalırdı.
  static void _shiftLayoutRows(XlsxSheetLayout layout, int at, int delta) {
    final cells = <int, XlsxCell>{};
    layout.cells.forEach((key, cell) {
      final r = key ~/ 16384;
      final c = key % 16384;
      if (r < at) {
        cells[key] = cell;
        return;
      }
      final nr = r + delta;
      if (nr < 0) return;
      cells[cellKey(nr, c)] = XlsxCell(
        row: nr,
        col: c,
        styleIndex: cell.styleIndex,
        number: cell.number,
        text: cell.text,
        boolean: cell.boolean,
        error: cell.error,
        formula: cell.formula,
        runs: cell.runs,
      );
    });
    layout.cells
      ..clear()
      ..addAll(cells);
    _shiftKeys(layout.rowHeights, at, delta);
    _shiftKeys(layout.rowStyles, at, delta);
    _shiftSet(layout.hiddenRows, at, delta);
    layout.maxRow += delta;
    if (layout.maxRow < -1) layout.maxRow = -1;
  }

  static void _shiftLayoutCols(XlsxSheetLayout layout, int at, int delta) {
    final cells = <int, XlsxCell>{};
    layout.cells.forEach((key, cell) {
      final r = key ~/ 16384;
      final c = key % 16384;
      if (c < at) {
        cells[key] = cell;
        return;
      }
      final nc = c + delta;
      if (nc < 0) return;
      cells[cellKey(r, nc)] = XlsxCell(
        row: r,
        col: nc,
        styleIndex: cell.styleIndex,
        number: cell.number,
        text: cell.text,
        boolean: cell.boolean,
        error: cell.error,
        formula: cell.formula,
        runs: cell.runs,
      );
    });
    layout.cells
      ..clear()
      ..addAll(cells);
    _shiftKeys(layout.colWidths, at, delta);
    _shiftKeys(layout.colStyles, at, delta);
    _shiftSet(layout.hiddenCols, at, delta);
    layout.maxCol += delta;
    if (layout.maxCol < -1) layout.maxCol = -1;
  }

  static void _shiftKeys<T>(Map<int, T> map, int at, int delta) {
    final copy = <int, T>{};
    map.forEach((k, v) {
      if (k < at) {
        copy[k] = v;
      } else if (k + delta >= 0) {
        copy[k + delta] = v;
      }
    });
    map
      ..clear()
      ..addAll(copy);
  }

  static void _shiftSet(Set<int> set, int at, int delta) {
    final copy = <int>{};
    for (final k in set) {
      if (k < at) {
        copy.add(k);
      } else if (k + delta >= 0) {
        copy.add(k + delta);
      }
    }
    set
      ..clear()
      ..addAll(copy);
  }

  /// Seçili hücrenin yazı biçimini değiştirir. Verilmeyen alanlar korunur.
  /// (Dolgu rengi bilinçli olarak YOK: excel 4.0.6'nın renk yazma API'si bu
  /// ortamda derlenip doğrulanamıyor — kanıtlanmamış API kullanılmaz.)
  void setCellStyle(String sheetName, int r, int c,
      {bool? bold, bool? italic, TextAlign? align}) {
    final table = _excel.tables[sheetName];
    final model = _modelSheet(sheetName);
    if (table == null || model == null || r < 0 || c < 0) return;
    final cell =
        table.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    final base = cell.cellStyle ?? CellStyle();
    HorizontalAlign? ha;
    XlsxHAlign? modelAlign;
    if (align != null) {
      ha = switch (align) {
        TextAlign.center => HorizontalAlign.Center,
        TextAlign.right => HorizontalAlign.Right,
        _ => HorizontalAlign.Left,
      };
      modelAlign = switch (align) {
        TextAlign.center => XlsxHAlign.center,
        TextAlign.right => XlsxHAlign.right,
        _ => XlsxHAlign.left,
      };
    }
    cell.cellStyle = base.copyWith(
      boldVal: bold,
      italicVal: italic,
      horizontalAlignVal: ha,
    );
    final current = model.styleAt(r, c) ?? const XlsxCellStyle();
    model.patchStyle(
      r,
      c,
      current.copyWith(bold: bold, italic: italic, hAlign: modelAlign),
    );
  }

  static void _copyCell(Sheet t, int sr, int sc, int dr, int dc) {
    final src =
        t.cell(CellIndex.indexByColumnRow(columnIndex: sc, rowIndex: sr));
    final dst =
        t.cell(CellIndex.indexByColumnRow(columnIndex: dc, rowIndex: dr));
    dst.value = src.value;
    dst.cellStyle = src.cellStyle;
  }

  static void _clearCell(Sheet t, int r, int c) {
    t.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).value = null;
  }

  Uint8List save() {
    final bytes = _excel.encode();
    if (bytes == null || bytes.isEmpty) return Uint8List(0);
    // `excel` paketinin yazamadıklarını (gizli satır/sütun, boş satır
    // yüksekliği, sayfa yönü) zip üretildikten SONRA XML yamasıyla geri koy.
    return XlsxSavePatch.apply(Uint8List.fromList(bytes), [
      for (final s in sheets)
        XlsxSheetPatch(
          name: s.name,
          rightToLeft: s.rightToLeft,
          hiddenRows: s.layout.hiddenRows,
          hiddenCols: s.layout.hiddenCols,
          // Yalnız HİÇ HÜCRESİ OLMAYAN satırlar: paket `<row>`u yalnız
          // hücresi olan satır için yazıyor, o yüzden ayırıcı boş satırların
          // özel yüksekliği kaydetmede kayboluyordu.
          rowHeightsPt: {
            for (final e in s.layout.rowHeights.entries)
              if (e.value > 0 && _isEmptyRow(s, e.key)) e.key: e.value,
          },
        ),
    ]);
  }

  static bool _isEmptyRow(XlsxSheet sheet, int r) {
    if (r < 0 || r >= sheet.rows.length) return true;
    return sheet.rows[r].every((v) => v.isEmpty);
  }
}

/// Excel hata değerlerinin İngilizce → Türkçe karşılığı. Dosyada daima
/// İngilizce yazılıdır (`#DIV/0!`), Türkçe Excel ekranda `#SAYI/0!` gösterir.
const Map<String, String> _errorTr = {
  '#DIV/0!': '#SAYI/0!',
  '#VALUE!': '#DEĞER!',
  '#REF!': '#BAŞV!',
  '#NAME?': '#AD?',
  '#N/A': '#YOK',
  '#NUM!': '#SAYI!',
  '#NULL!': '#BOŞ!',
  '#SPILL!': '#TAŞMA!',
  '#CALC!': '#HESAP!',
  '#GETTING_DATA': '#VERİ_ALINIYOR',
};

/// Bu metin bir Excel hata değeri mi? (Motorumuz Türkçe kodları döndürür,
/// dosya İngilizce taşır — iki taraf da tanınmalı.)
bool isExcelErrorText(String s) {
  final t = s.trim();
  if (!t.startsWith('#')) return false;
  return _errorTr.containsKey(t) || _errorTr.containsValue(t) || t == '#DÖNGÜ';
}

/// Hata kodunu Türkçe gösterime çevirir (bilinmiyorsa olduğu gibi döner).
String localizedExcelError(String code) => _errorTr[code.trim()] ?? code;

/// Sayıyı HAM metne çevirir (ondalık ayıraç `.`) — formül motoru ve yeniden
/// çözümleme bunu bekler. Gösterim biçimi ayrı katmanda uygulanır.
String generalNumberRaw(double d) {
  if (d == d.roundToDouble() && d.abs() < 1e15) return d.toStringAsFixed(0);
  var s = d.toString();
  if (s.contains('e')) return s;
  return s;
}

/// Eski API — Excel biçim kodunu bir sayıya uygular, Türkçe gösterimle.
/// Uygulanamıyorsa (General/@) null döner.
String? applyNumberFormat(String code, double value) {
  final fmt = ExcelNumberFormat.parse(code);
  if (fmt.isGeneral) return null;
  final trimmed = code.trim();
  if (trimmed == '@') return null;
  return fmt.format(value).text;
}
