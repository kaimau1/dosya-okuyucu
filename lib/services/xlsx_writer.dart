import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// **Sıfırdan .xlsx üreten yazıcı.**
///
/// *Niye gerekli:* eski `.xls` (BIFF) dosyaları uygulamada SALT-OKUNUR bir
/// listede gösteriliyordu — zoom yok, şerit yok, düzenleme yok. Aynı dosyayı
/// gerçek Excel ızgarasına sokmanın en kısa yolu onu okuduktan sonra **geçerli
/// bir .xlsx'e çevirmek**: ondan sonrası zaten çalışıyor (`XlsxEditor.parse`
/// → `xlsx_reader` sadakati + düzenleme + kaydetme).
///
/// *Niye `excel` paketiyle değil:* paketin yazma API'si hücre genişliği,
/// dondurulmuş bölme, birleşik hücre ve sayı biçimini ya hiç yazmıyor ya da
/// kendi kafasına göre yazıyor (bkz. `xlsx_save_patch.dart` — aynı eksikler
/// için orada da yama var). Burada üretilen XML'i baştan sona biz
/// belirlediğimiz için çevrimde bilgi kaybı olmuyor.
///
/// Üretilen paket ECMA-376'nın en küçük geçerli hâlidir: `[Content_Types].xml`,
/// `_rels/.rels`, `xl/workbook.xml` (+rels), `xl/styles.xml`,
/// `xl/sharedStrings.xml`, `xl/worksheets/sheetN.xml`.
class XlsxWriter {
  /// Çalışma kitabını zip baytlarına çevirir.
  static Uint8List build(
    List<XlsxWriteSheet> sheets, {
    List<XlsxWriteStyle> styles = const [],
    bool date1904 = false,
  }) {
    final list = sheets.isEmpty
        ? [XlsxWriteSheet(name: 'Sayfa1')]
        : sheets;

    // Paylaşılan metin tablosu: aynı metin bir kez yazılır (Excel'in kendi
    // düzeni; dosya da küçülür).
    final shared = <String, int>{};
    for (final s in list) {
      for (final row in s.cells.values) {
        for (final cell in row.values) {
          final t = cell.text;
          if (t != null && t.isNotEmpty) {
            shared.putIfAbsent(t, () => shared.length);
          }
        }
      }
    }

    final archive = Archive();
    void add(String name, String xml) {
      final data = utf8.encode(xml);
      archive.addFile(ArchiveFile(name, data.length, data));
    }

    add('[Content_Types].xml', _contentTypes(list.length));
    add('_rels/.rels', _rootRels());
    add('xl/workbook.xml', _workbook(list, date1904));
    add('xl/_rels/workbook.xml.rels', _workbookRels(list.length));
    add('xl/styles.xml', _styles(styles));
    add('xl/sharedStrings.xml', _sharedStrings(shared));
    for (var i = 0; i < list.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(list[i], shared));
    }

    final zip = ZipEncoder().encode(archive);
    return Uint8List.fromList(zip ?? const []);
  }

  // ── parçalar ──────────────────────────────────────────────────────────────

  static String _contentTypes(int sheetCount) {
    final sb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
          'content-types">')
      ..write('<Default Extension="rels" ContentType="application/'
          'vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Override PartName="/xl/workbook.xml" ContentType="application/'
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>');
    for (var i = 1; i <= sheetCount; i++) {
      sb.write('<Override PartName="/xl/worksheets/sheet$i.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.'
          'spreadsheetml.worksheet+xml"/>');
    }
    sb
      ..write('<Override PartName="/xl/styles.xml" ContentType="application/'
          'vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>')
      ..write('<Override PartName="/xl/sharedStrings.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.'
          'spreadsheetml.sharedStrings+xml"/>')
      ..write('</Types>');
    return sb.toString();
  }

  static String _rootRels() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
      'relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/officeDocument" Target="xl/'
      'workbook.xml"/>'
      '</Relationships>';

  static String _workbookRels(int sheetCount) {
    final sb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/'
          'package/2006/relationships">');
    for (var i = 1; i <= sheetCount; i++) {
      sb.write('<Relationship Id="rId$i" Type="http://schemas.openxmlformats.'
          'org/officeDocument/2006/relationships/worksheet" '
          'Target="worksheets/sheet$i.xml"/>');
    }
    final styleId = sheetCount + 1;
    final sharedId = sheetCount + 2;
    sb
      ..write('<Relationship Id="rId$styleId" Type="http://schemas.'
          'openxmlformats.org/officeDocument/2006/relationships/styles" '
          'Target="styles.xml"/>')
      ..write('<Relationship Id="rId$sharedId" Type="http://schemas.'
          'openxmlformats.org/officeDocument/2006/relationships/'
          'sharedStrings" Target="sharedStrings.xml"/>')
      ..write('</Relationships>');
    return sb.toString();
  }

  static String _workbook(List<XlsxWriteSheet> sheets, bool date1904) {
    final sb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<workbook xmlns="http://schemas.openxmlformats.org/'
          'spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.'
          'org/officeDocument/2006/relationships">');
    if (date1904) sb.write('<workbookPr date1904="1"/>');
    sb.write('<sheets>');
    for (var i = 0; i < sheets.length; i++) {
      final s = sheets[i];
      sb.write('<sheet name="${_attr(_sheetName(s.name, i))}" '
          'sheetId="${i + 1}"'
          '${s.hidden ? ' state="hidden"' : ''} r:id="rId${i + 1}"/>');
    }
    sb.write('</sheets></workbook>');
    return sb.toString();
  }

  /// Excel'in sayfa adı kuralları: boş olamaz, 31 karakteri geçemez ve
  /// `: \ / ? * [ ]` içeremez. Eski dosyalardan bozuk ad gelebiliyor.
  static String _sheetName(String raw, int index) {
    var name = raw.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
    if (name.length > 31) name = name.substring(0, 31);
    return name.isEmpty ? 'Sayfa${index + 1}' : name;
  }

  static String _sharedStrings(Map<String, int> shared) {
    final entries = shared.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final sb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
          '2006/main" count="${entries.length}" '
          'uniqueCount="${entries.length}">');
    for (final e in entries) {
      // xml:space korunur: baştaki/sondaki boşluk anlamlı olabilir (hizalama
      // için boşlukla doldurulmuş eski tablolar).
      sb.write('<si><t xml:space="preserve">${_text(e.key)}</t></si>');
    }
    sb.write('</sst>');
    return sb.toString();
  }

  static String _styles(List<XlsxWriteStyle> styles) {
    // 0. stil DAİMA varsayılandır: dosyada stili olmayan hücre buna bakar.
    final all = <XlsxWriteStyle>[const XlsxWriteStyle(), ...styles];

    // Sayı biçimleri: yerleşik olmayanlar 164'ten başlayarak numaralanır.
    final numFmtIds = <String, int>{};
    for (final s in all) {
      final code = s.numFmtCode;
      if (code.isEmpty || code == 'General') continue;
      final builtin = _builtinNumFmtId(code);
      numFmtIds.putIfAbsent(code, () => builtin ?? (164 + numFmtIds.length));
    }

    // Yazı tipleri ve dolgular tekilleştirilir (Excel de böyle yazar).
    final fonts = <String, int>{};
    final fills = <String, int>{};
    final fontOf = <int>[];
    final fillOf = <int>[];
    for (final s in all) {
      final fontXml = _fontXml(s);
      fontOf.add(fonts.putIfAbsent(fontXml, () => fonts.length));
      // 0 = dolgu yok, 1 = gray125: Excel bu ikisini AYIRIR, kullanılmasa da
      // dosyada bulunmak zorunda; kendi dolgularımız 2'den başlar.
      final fillXml = s.fillArgb == null ? '' : _fillXml(s.fillArgb!);
      fillOf.add(fillXml.isEmpty ? 0 : fills.putIfAbsent(fillXml, () => fills.length + 2));
    }

    final sb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<styleSheet xmlns="http://schemas.openxmlformats.org/'
          'spreadsheetml/2006/main">');

    if (numFmtIds.isNotEmpty) {
      final custom = numFmtIds.entries.where((e) => e.value >= 164).toList();
      if (custom.isNotEmpty) {
        sb.write('<numFmts count="${custom.length}">');
        for (final e in custom) {
          sb.write('<numFmt numFmtId="${e.value}" '
              'formatCode="${_attr(e.key)}"/>');
        }
        sb.write('</numFmts>');
      }
    }

    final fontList = fonts.keys.toList();
    sb.write('<fonts count="${fontList.length}">');
    for (final f in fontList) {
      sb.write(f);
    }
    sb.write('</fonts>');

    final fillList = fills.keys.toList();
    sb
      ..write('<fills count="${fillList.length + 2}">')
      ..write('<fill><patternFill patternType="none"/></fill>')
      ..write('<fill><patternFill patternType="gray125"/></fill>');
    for (final f in fillList) {
      sb.write(f);
    }
    sb
      ..write('</fills>')
      ..write('<borders count="1"><border><left/><right/><top/><bottom/>'
          '<diagonal/></border></borders>')
      ..write('<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" '
          'borderId="0"/></cellStyleXfs>')
      ..write('<cellXfs count="${all.length}">');
    for (var i = 0; i < all.length; i++) {
      sb.write(_xfXml(all[i], fontOf[i], fillOf[i], numFmtIds));
    }
    sb
      ..write('</cellXfs>')
      ..write('<cellStyles count="1"><cellStyle name="Normal" xfId="0" '
          'builtinId="0"/></cellStyles>')
      ..write('</styleSheet>');
    return sb.toString();
  }

  static String _fontXml(XlsxWriteStyle s) {
    final sb = StringBuffer('<font>');
    if (s.bold) sb.write('<b/>');
    if (s.italic) sb.write('<i/>');
    if (s.strike) sb.write('<strike/>');
    if (s.underline) sb.write('<u/>');
    sb.write('<sz val="${_num(s.fontSize ?? 11)}"/>');
    if (s.fontArgb != null) {
      sb.write('<color rgb="${_argbHex(s.fontArgb!)}"/>');
    }
    sb.write('<name val="${_attr(s.fontName ?? 'Calibri')}"/>');
    sb.write('</font>');
    return sb.toString();
  }

  static String _fillXml(int argb) =>
      '<fill><patternFill patternType="solid">'
      '<fgColor rgb="${_argbHex(argb)}"/>'
      '<bgColor indexed="64"/>'
      '</patternFill></fill>';

  static String _xfXml(
      XlsxWriteStyle s, int fontId, int fillId, Map<String, int> numFmtIds) {
    final numFmtId = numFmtIds[s.numFmtCode] ?? 0;
    final hasAlign = s.hAlign.isNotEmpty || s.vAlign.isNotEmpty || s.wrap ||
        s.indent > 0;
    final sb = StringBuffer('<xf numFmtId="$numFmtId" fontId="$fontId" '
        'fillId="$fillId" borderId="0" xfId="0"');
    if (numFmtId != 0) sb.write(' applyNumberFormat="1"');
    if (fontId != 0) sb.write(' applyFont="1"');
    if (fillId != 0) sb.write(' applyFill="1"');
    if (hasAlign) sb.write(' applyAlignment="1"');
    if (!hasAlign) return '${sb.toString()}/>';
    sb.write('><alignment');
    if (s.hAlign.isNotEmpty) sb.write(' horizontal="${s.hAlign}"');
    if (s.vAlign.isNotEmpty) sb.write(' vertical="${s.vAlign}"');
    if (s.wrap) sb.write(' wrapText="1"');
    if (s.indent > 0) sb.write(' indent="${s.indent}"');
    sb.write('/></xf>');
    return sb.toString();
  }

  static String _sheetXml(XlsxWriteSheet sheet, Map<String, int> shared) {
    final sb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/'
          'spreadsheetml/2006/main">');

    // Görünüm: dondurulmuş bölme (varsa) — eski dosyanın başlık satırı
    // sabit kalsın.
    sb.write('<sheetViews><sheetView workbookViewId="0"'
        '${sheet.rightToLeft ? ' rightToLeft="1"' : ''}'
        '${sheet.showGridLines ? '' : ' showGridLines="0"'}>');
    if (sheet.frozenRows > 0 || sheet.frozenCols > 0) {
      final top = _cellRef(sheet.frozenRows, sheet.frozenCols);
      final pane = sheet.frozenRows > 0 && sheet.frozenCols > 0
          ? 'bottomRight'
          : (sheet.frozenCols > 0 ? 'topRight' : 'bottomLeft');
      sb.write('<pane');
      if (sheet.frozenCols > 0) sb.write(' xSplit="${sheet.frozenCols}"');
      if (sheet.frozenRows > 0) sb.write(' ySplit="${sheet.frozenRows}"');
      sb.write(' topLeftCell="$top" activePane="$pane" state="frozen"/>');
    }
    sb.write('</sheetView></sheetViews>');
    sb.write('<sheetFormatPr defaultRowHeight="15"/>');

    if (sheet.colWidths.isNotEmpty || sheet.hiddenCols.isNotEmpty) {
      final cols = <int>{...sheet.colWidths.keys, ...sheet.hiddenCols}.toList()
        ..sort();
      sb.write('<cols>');
      for (final c in cols) {
        final w = sheet.colWidths[c];
        sb.write('<col min="${c + 1}" max="${c + 1}"');
        if (w != null) sb.write(' width="${_num(w)}" customWidth="1"');
        if (sheet.hiddenCols.contains(c)) sb.write(' hidden="1"');
        sb.write('/>');
      }
      sb.write('</cols>');
    }

    sb.write('<sheetData>');
    final rowNumbers = <int>{...sheet.cells.keys, ...sheet.rowHeights.keys,
      ...sheet.hiddenRows}.toList()..sort();
    for (final r in rowNumbers) {
      final cells = sheet.cells[r];
      final h = sheet.rowHeights[r];
      sb.write('<row r="${r + 1}"');
      if (h != null) sb.write(' ht="${_num(h)}" customHeight="1"');
      if (sheet.hiddenRows.contains(r)) sb.write(' hidden="1"');
      if (cells == null || cells.isEmpty) {
        sb.write('/>');
        continue;
      }
      sb.write('>');
      final cols = cells.keys.toList()..sort();
      for (final c in cols) {
        sb.write(_cellXml(r, c, cells[c]!, shared));
      }
      sb.write('</row>');
    }
    sb.write('</sheetData>');

    if (sheet.merges.isNotEmpty) {
      sb.write('<mergeCells count="${sheet.merges.length}">');
      for (final m in sheet.merges) {
        sb.write('<mergeCell ref="${_cellRef(m.rowStart, m.colStart)}:'
            '${_cellRef(m.rowEnd, m.colEnd)}"/>');
      }
      sb.write('</mergeCells>');
    }

    sb.write('</worksheet>');
    return sb.toString();
  }

  static String _cellXml(
      int r, int c, XlsxWriteCell cell, Map<String, int> shared) {
    final ref = _cellRef(r, c);
    final s = cell.style > 0 ? ' s="${cell.style}"' : '';
    if (cell.number != null) {
      return '<c r="$ref"$s><v>${_num(cell.number!)}</v></c>';
    }
    if (cell.boolean != null) {
      return '<c r="$ref"$s t="b"><v>${cell.boolean! ? 1 : 0}</v></c>';
    }
    if (cell.error != null) {
      return '<c r="$ref"$s t="e"><v>${_text(cell.error!)}</v></c>';
    }
    final text = cell.text;
    if (text == null || text.isEmpty) return '<c r="$ref"$s/>';
    final index = shared[text];
    if (index == null) {
      return '<c r="$ref"$s t="inlineStr"><is><t xml:space="preserve">'
          '${_text(text)}</t></is></c>';
    }
    return '<c r="$ref"$s t="s"><v>$index</v></c>';
  }

  // ── yardımcılar ───────────────────────────────────────────────────────────

  /// 0 tabanlı satır/sütun → `A1` gösterimi.
  static String _cellRef(int r, int c) => '${colName(c)}${r + 1}';

  /// 0 tabanlı sütun indeksi → `A`, `Z`, `AA`…
  static String colName(int index) {
    var n = index;
    final sb = StringBuffer();
    while (true) {
      sb.write(String.fromCharCode(65 + (n % 26)));
      n = n ~/ 26 - 1;
      if (n < 0) break;
    }
    return String.fromCharCodes(sb.toString().codeUnits.reversed);
  }

  /// Yerleşik (0–49) bir sayı biçimi kodunun kimliği — varsa numFmt yazmaya
  /// gerek yok. Karşılaştırma kodun kendisiyle: eski dosyadan gelen kod
  /// yerleşiklerden biriyse Excel'in tanıdığı kimlikle yazılır.
  static int? _builtinNumFmtId(String code) {
    for (final e in _builtinNumFmts.entries) {
      if (e.value == code) return e.key;
    }
    return null;
  }

  /// Yalnız kimlik → kod yönü gereken küçük bir alt küme (yazıcı için yeter;
  /// okuma tarafındaki tam tablo `core/excel_format.dart`de).
  static const Map<int, String> _builtinNumFmts = {
    1: '0',
    2: '0.00',
    3: '#,##0',
    4: '#,##0.00',
    9: '0%',
    10: '0.00%',
    11: '0.00E+00',
    14: 'dd.mm.yyyy',
    15: 'd-mmm-yy',
    16: 'd-mmm',
    17: 'mmm-yy',
    18: 'h:mm AM/PM',
    19: 'h:mm:ss AM/PM',
    20: 'h:mm',
    21: 'h:mm:ss',
    22: 'dd.mm.yyyy h:mm',
    45: 'mm:ss',
    46: '[h]:mm:ss',
    47: 'mm:ss.0',
    49: '@',
  };

  /// Sayıyı XML'e uygun yazar (üstel gösterim ve gereksiz `.0` olmadan).
  static String _num(double v) {
    if (!v.isFinite) return '0';
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toStringAsFixed(0);
    }
    return v.toString();
  }

  static String _argbHex(int argb) =>
      argb.toRadixString(16).padLeft(8, '0').toUpperCase();

  /// Metin düğümü kaçışı. XML'de geçersiz olan denetim karakterleri ATILIR —
  /// eski ikili dosyalarda sık görülür ve Excel dosyayı "onarılamaz" sayar.
  static String _text(String raw) {
    final sb = StringBuffer();
    for (final rune in raw.runes) {
      if (rune == 0x9 || rune == 0xA || rune == 0xD) {
        sb.writeCharCode(rune);
        continue;
      }
      if (rune < 0x20 || (rune >= 0xD800 && rune <= 0xDFFF) ||
          rune == 0xFFFE || rune == 0xFFFF) {
        continue;
      }
      switch (rune) {
        case 0x26:
          sb.write('&amp;');
        case 0x3C:
          sb.write('&lt;');
        case 0x3E:
          sb.write('&gt;');
        default:
          sb.writeCharCode(rune);
      }
    }
    return sb.toString();
  }

  /// Öznitelik kaçışı (tırnak da kaçar).
  static String _attr(String raw) =>
      _text(raw).replaceAll('"', '&quot;').replaceAll("'", '&apos;');
}

/// Yazılacak hücre. Yalnız bir değer alanı doludur.
class XlsxWriteCell {
  final String? text;
  final double? number;
  final bool? boolean;

  /// `#DIV/0!` gibi hata değeri.
  final String? error;

  /// `cellXfs` indeksi (0 = varsayılan).
  final int style;

  const XlsxWriteCell({
    this.text,
    this.number,
    this.boolean,
    this.error,
    this.style = 0,
  });

  const XlsxWriteCell.blank({this.style = 0})
      : text = null,
        number = null,
        boolean = null,
        error = null;
}

/// Birleştirilmiş aralık (0 tabanlı, uçlar dahil).
class XlsxWriteMerge {
  final int rowStart, colStart, rowEnd, colEnd;
  const XlsxWriteMerge(
      this.rowStart, this.colStart, this.rowEnd, this.colEnd);
}

/// Yazılacak hücre görünümü. Eşitlik alan alan tanımlıdır: aynı görünüm
/// dosyada tek bir `xf` olarak yazılsın.
class XlsxWriteStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final double? fontSize;
  final String? fontName;
  final int? fontArgb;
  final int? fillArgb;

  /// Sayı biçimi kodu (`General`, `0.00`, `dd.mm.yyyy`…).
  final String numFmtCode;

  /// `left` / `center` / `right` / `justify` — boş ise Excel'in genel kuralı.
  final String hAlign;

  /// `top` / `center` / `bottom`.
  final String vAlign;

  final bool wrap;
  final int indent;

  const XlsxWriteStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize,
    this.fontName,
    this.fontArgb,
    this.fillArgb,
    this.numFmtCode = 'General',
    this.hAlign = '',
    this.vAlign = '',
    this.wrap = false,
    this.indent = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is XlsxWriteStyle &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike &&
      other.fontSize == fontSize &&
      other.fontName == fontName &&
      other.fontArgb == fontArgb &&
      other.fillArgb == fillArgb &&
      other.numFmtCode == numFmtCode &&
      other.hAlign == hAlign &&
      other.vAlign == vAlign &&
      other.wrap == wrap &&
      other.indent == indent;

  @override
  int get hashCode => Object.hash(bold, italic, underline, strike, fontSize,
      fontName, fontArgb, fillArgb, numFmtCode, hAlign, vAlign, wrap, indent);
}

/// Yazılacak sayfa.
class XlsxWriteSheet {
  final String name;

  /// satır → (sütun → hücre), 0 tabanlı.
  final Map<int, Map<int, XlsxWriteCell>> cells;

  /// Sütun genişlikleri (Excel karakter birimi).
  final Map<int, double> colWidths;

  /// Satır yükseklikleri (punto).
  final Map<int, double> rowHeights;

  final Set<int> hiddenCols;
  final Set<int> hiddenRows;
  final List<XlsxWriteMerge> merges;
  final int frozenRows;
  final int frozenCols;
  final bool hidden;
  final bool rightToLeft;
  final bool showGridLines;

  XlsxWriteSheet({
    required this.name,
    Map<int, Map<int, XlsxWriteCell>>? cells,
    Map<int, double>? colWidths,
    Map<int, double>? rowHeights,
    Set<int>? hiddenCols,
    Set<int>? hiddenRows,
    List<XlsxWriteMerge>? merges,
    this.frozenRows = 0,
    this.frozenCols = 0,
    this.hidden = false,
    this.rightToLeft = false,
    this.showGridLines = true,
  })  : cells = cells ?? {},
        colWidths = colWidths ?? {},
        rowHeights = rowHeights ?? {},
        hiddenCols = hiddenCols ?? {},
        hiddenRows = hiddenRows ?? {},
        merges = merges ?? [];
}
