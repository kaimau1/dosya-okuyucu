import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show TextAlign;

import '../core/excel_format.dart';
import 'xlsx_package.dart';
import 'xlsx_reader.dart';
import 'xlsx_save_patch.dart';
import 'xlsx_chart.dart';
import 'sheet_structure.dart';
import 'calc_log.dart';
import '../core/app_colors.dart';
import '../core/edit/save_coordinator.dart';

// Görünüm modelinin tamamı (aralık, kenarlık, hizalama, koşullu biçim…)
// ekranlara buradan açılır — ad çakışması yok.
export 'xlsx_reader.dart';
export 'xlsx_chart.dart';
export 'sheet_structure.dart' show SheetShift;

part 'xlsx/structure_edit.dart';

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

  /// [clearBackground] / [clearFontColor]: `null` "dokunma" demek olduğu için
  /// rengi KALDIRMAK ayrı bir bayrak ister (Excel'de "dolgu yok" geçerli bir
  /// seçim; `background: null` ile ifade edilemezdi).
  XlsxCellStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? wrap,
    XlsxHAlign? hAlign,
    Color? background,
    bool clearBackground = false,
    Color? fontColor,
    bool clearFontColor = false,
    XlsxBorder? border,
    String? numFmtCode,
    double? fontSize,
    String? fontFamily,
  }) =>
      XlsxCellStyle(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        strike: strike,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        fontColor: clearFontColor ? null : (fontColor ?? this.fontColor),
        background: clearBackground ? null : (background ?? this.background),
        hAlign: hAlign ?? this.hAlign,
        vAlign: vAlign,
        wrap: wrap ?? this.wrap,
        indent: indent,
        rotation: rotation,
        border: border ?? this.border,
        numFmtCode: numFmtCode ?? this.numFmtCode,
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
  /// Sayfa adı. Yeniden adlandırma bunu YERİNDE değiştirir: sayfanın oturum
  /// içi düzenlemeleri (biçim örtmeleri, sayı biçimleri, yapıştırılan biçim
  /// izleri) yeni bir nesne kurulsa kaybolurdu.
  String name;

  /// Ham hücre metinleri — formül motorunun ve CSV dışa aktarımının girdisi.
  /// Sayılar burada HAM durur (`1234.5`), biçim yalnız gösterimde uygulanır;
  /// yoksa `=A1*2` gibi formüller "₺1.234,50"yi sayı sanıp bozulurdu.
  final List<List<String>> rows;

  final XlsxSheetLayout layout;
  final XlsxStyles styles;
  final bool date1904;

  /// Uygulama içinde değiştirilen hücre biçimleri (dosyadaki paylaşımlı stil
  /// nesnesini bozmamak için ayrı tutulur).
  final Map<int, XlsxCellStyle> _overrides = {};

  /// styleIndex → çözümlenmiş görünüm (her karede yeniden hesaplanmasın).
  final Map<int, XlsxCellStyle> _styleCache = {};

  /// **İçeriğe göre hesaplanmış** satır yükseklikleri (punto) — yalnız dosyada
  /// açık yüksekliği OLMAYAN satırlar için. Excel dosyayı açarken bu hesabı
  /// kendisi yapar; biz yapmayınca çok satırlı hücreler tek satıra kırpılıyordu
  /// (kullanıcı ekran görüntüsü 2026-08-07). Ekran doldurur (ölçüm `TextPainter`
  /// ister), dosyaya YAZILMAZ: bu bizim gösterimimiz, kullanıcının verisi değil.
  final Map<int, double> autoRowHeights = {};

  late final List<XlsxMerge> merges = [
    for (final m in layout.merges) XlsxMerge(m.r1, m.c1, m.r2, m.c2),
  ];

  XlsxSheet({
    required this.name,
    required this.rows,
    required this.layout,
    required this.styles,
    this.date1904 = false,
  });

  int get maxCols {
    final fromCells = layout.colCount;
    // Her `build`de bütün satırları taramak 10 bin satırda kare başına
    // milisaniyeler yakıyordu (Faz 26): satır sayısı + yazım sayacıyla önbellek.
    final memo = _maxColsMemo;
    if (memo != null && memo.$1 == rows.length && memo.$2 == _writes) {
      return fromCells > memo.$3 ? fromCells : memo.$3;
    }
    final fromRows = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    _maxColsMemo = (rows.length, _writes, fromRows);
    return fromCells > fromRows ? fromCells : fromRows;
  }

  (int, int, int)? _maxColsMemo;

  /// Model yazım sayacı: hücre/sütun yazımı ve yapısal işlemlerde artar;
  /// [maxCols], [mergeAt] ve [condRuleAt] dizinleri bununla geçersiz olur.
  int _writes = 0;
  void _touched() {
    _writes++;
    _mergeIndex = null;
    _condIndex = null;
  }

  // ── O(1)'e yakın aramalar (Faz 26) ────────────────────────────────────────
  // Eskiden her hücre çiziminde birleştirme ve koşullu biçim listeleri baştan
  // sona taranıyordu (binlerce birleştirmeli sayfada hücre × birleştirme).

  /// Satır → o satırı kapsayan birleştirmeler (çok uzun olanlar `-1`de).
  Map<int, List<XlsxMerge>>? _mergeIndex;
  int _mergeIndexLen = -1;

  /// Sütun → o sütunu kapsayan kurallar (çok geniş olanlar `-1`de).
  Map<int, List<XlsxCondRule>>? _condIndex;
  int _condIndexLen = -1;

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
    if (merges.isEmpty) return null;
    var index = _mergeIndex;
    if (index == null || _mergeIndexLen != merges.length) {
      index = {};
      for (final m in merges) {
        if (m.rowEnd - m.rowStart > 4096) {
          (index[-1] ??= []).add(m);
          continue;
        }
        for (var row = m.rowStart; row <= m.rowEnd; row++) {
          (index[row] ??= []).add(m);
        }
      }
      _mergeIndex = index;
      _mergeIndexLen = merges.length;
    }
    for (final m in index[r] ?? const <XlsxMerge>[]) {
      if (m.covers(r, c)) return m;
    }
    for (final m in index[-1] ?? const <XlsxMerge>[]) {
      if (m.covers(r, c)) return m;
    }
    return null;
  }

  /// Yeni birleşme. Kesişen eski birleşmeler önce çözülür — Excel de üst üste
  /// binen iki birleşmeye izin vermez, dosya "onarılamaz" olurdu.
  void addMerge(XlsxMerge m) {
    merges.removeWhere((o) =>
        o.rowStart <= m.rowEnd &&
        o.rowEnd >= m.rowStart &&
        o.colStart <= m.colEnd &&
        o.colEnd >= m.colStart);
    merges.add(m);
    _touched();
  }

  void removeMerge(XlsxMerge m) {
    merges.remove(m);
    _touched();
  }

  /// Otomatik süzgeçle **gizlenen** satırlar, sütun başına. Kullanıcının elle
  /// gizlediği satırlardan ayrı tutulur: süzgeci kaldırmak yalnız süzgecin
  /// gizlediklerini geri getirmeli.
  final Map<int, Set<int>> filterHidden = {};

  bool isColFiltered(int c) => (filterHidden[c] ?? const {}).isNotEmpty;

  /// Hücrenin notu (Excel'de "Açıklama") — yoksa null.
  XlsxComment? commentAt(int r, int c) => layout.comments[cellKey(r, c)];

  /// Bu oturumda eklenen koşullu biçimlendirme kuralları (kaydetmede yazılır).
  final List<XlsxCondRuleWrite> condRuleEdits = [];

  /// Bu oturumdaki satır/sütun ekle-sil işlemleri, sırayla (Faz 25 / X3):
  /// kaydetmede özgün XML'deki koşullu biçim, doğrulama, köprü ve notlar
  /// aynı kaydırmayı görür.
  final List<SheetShift> structuralOps = [];

  /// Koşullu biçimlendirme kuralı ekler: ekranda ANINDA uygulanır, kaydetmede
  /// `<cfRule>` + `<dxf>` olarak yazılır.
  ///
  /// **`dxfId` indeksi iki tarafta da aynı olmak zorunda:** ekrandaki çizim
  /// `styles.dxfs[dxfId]`e bakıyor, dosyadaki kural da `styles.xml`deki aynı
  /// sıraya. Bu yüzden ikisine de SONA, aynı sırayla ekleniyor.
  XlsxCondRule addCondRule({
    required XlsxRange range,
    required String type,
    String? operator,
    List<String> formulas = const [],
    String? text,
    int? fillArgb,
    int? fontArgb,
  }) {
    final dxfId = styles.dxfs.length;
    styles.dxfs.add(XlsxDxf(
      fill: fillArgb == null
          ? null
          : XlsxFill(pattern: 'solid', fgArgb: fillArgb),
      font: fontArgb == null ? null : XlsxFont(colorArgb: fontArgb),
    ));
    final rule = XlsxCondRule(
      ranges: [range],
      type: type,
      operator: operator,
      text: text,
      formulas: formulas,
      // Yeni kural en yüksek öncelikli (Excel de yeniyi listenin başına koyar).
      priority: 1,
      dxfId: dxfId,
    );
    layout.condFormats.insert(0, rule);
    _touched();
    condRuleEdits.add(XlsxCondRuleWrite(
      sqref: _rangeRef(range),
      type: type,
      operator: operator,
      formulas: formulas,
      text: text,
      fillArgb: fillArgb,
      fontArgb: fontArgb,
    ));
    return rule;
  }

  /// `XlsxRange` → "A1:D20".
  static String _rangeRef(XlsxRange r) =>
      '${XlsxRange.colName(r.c1)}${r.r1 + 1}:'
      '${XlsxRange.colName(r.c2)}${r.r2 + 1}';

  /// Eklenen bir kuralı geri alır (yalnız bu oturumda eklenenler).
  void removeCondRule(XlsxCondRule rule) {
    final at = layout.condFormats.indexOf(rule);
    if (at < 0) return;
    layout.condFormats.removeAt(at);
    _touched();
    final dxfId = rule.dxfId;
    if (dxfId != null && dxfId == styles.dxfs.length - 1) {
      // Yalnız SON dxf sökülebilir; ortadakini silmek kalan kuralların
      // indekslerini kaydırırdı.
      styles.dxfs.removeLast();
      if (condRuleEdits.isNotEmpty) condRuleEdits.removeLast();
    }
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
  ///
  /// Sıra: dosyanın verdiği yükseklik → içerikten hesaplanan otomatik
  /// yükseklik ([autoRowHeights]) → varsayılan. Dosyadaki değer her zaman
  /// kazanır; kullanıcının ölçüsü tahminimizden önce gelir.
  double rowHeight(int r) {
    if (layout.hiddenRows.contains(r)) return 0;
    final pt = layout.rowHeights[r] ??
        autoRowHeights[r] ??
        (layout.defaultRowHeightPt <= 0 ? 15 : layout.defaultRowHeightPt);
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
  }

  /// Satır yüksekliğini punto olarak ayarlar (varsayılan 15). 0 = gizle.
  ///
  /// Boş satırın yüksekliği de kaydedilir: `XlsxPackageWriter` yüksekliği
  /// ya da gizliliği olan her satır için `<row>` yazar.
  void setRowHeightPt(int r, double pt) {
    if (r < 0 || r >= 1048576) return;
    final v = pt.clamp(0.0, 409.0).toDouble();
    layout.rowHeights[r] = v;
    if (v <= 0) {
      layout.hiddenRows.add(r);
    } else {
      layout.hiddenRows.remove(r);
    }
  }

  // ── stil ──────────────────────────────────────────────────────────────────

  /// Hücrenin stil indeksi: hücrenin kendi `s`si, yoksa satır, yoksa sütun.
  int styleIndexAt(int r, int c) {
    final cell = layout.cellAt(r, c);
    if (cell != null) return cell.styleIndex;
    return layout.rowStyles[r] ?? layout.colStyles[c] ?? 0;
  }

  /// Yeni yazılan bir hücrenin görünümünü **komşusundan** devralması için
  /// örnek hücre (yoksa null).
  ///
  /// Niye gerekli (kullanıcı 2026-08-17: *"çerçeveler gibi şeyler as te olduğu
  /// gibi kayboluyor siliniyor biz düzenleme yapınca"*, *"yazı fontu tipi
  /// tutmuyor kolona ve satıra göre otomatik aynı olmalı"*): dosyadaki bir
  /// tablonun boş bir hücresine yazınca [XlsxEditor.setCell] o hücre için
  /// `styleIndex: 0` (varsayılan) bir kayıt kuruyordu. Sonuç: kenarlıklar
  /// silinmiş, yazı tipi sütunun geri kalanından farklı görünüyordu — hem
  /// ekranda hem kaydedilen dosyada.
  ///
  /// Excel'in davranışı: yeni hücre **sütunun/satırın** biçimini alır. Sıra:
  /// 1. Aynı sütunda YUKARIDAKİ en yakın hücre (tablonun gövdesi),
  /// 2. aynı sütunda AŞAĞIDAKİ en yakın hücre (başlığın altına yazma),
  /// 3. aynı satırda SOLDAKİ en yakın hücre (satırı sağa uzatma).
  ///
  /// Tarama [_inheritScan] hücreyle sınırlı: 100 bin satırlık bir dosyada her
  /// yazımda tüm sütunu gezmek yazmayı gözle görülür yavaşlatırdı.
  static const int _inheritScan = 64;

  (int, int)? inheritTemplateAt(int r, int c) {
    for (var d = 1; d <= _inheritScan; d++) {
      final up = r - d;
      if (up >= 0 && layout.cells.containsKey(cellKey(up, c))) return (up, c);
    }
    for (var d = 1; d <= _inheritScan; d++) {
      final down = r + d;
      if (layout.cells.containsKey(cellKey(down, c))) return (down, c);
    }
    for (var d = 1; d <= _inheritScan; d++) {
      final left = c - d;
      if (left >= 0 && layout.cells.containsKey(cellKey(r, left))) {
        return (r, left);
      }
    }
    return null;
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
  /// Uygulama içinde verilmiş biçim örtmesi (dosyadaki stil DEĞİL).
  /// Geri alma bunu yakalayıp geri koyar.
  XlsxCellStyle? overrideAt(int r, int c) => _overrides[cellKey(r, c)];

  /// Kullanıcının bu oturumda verdiği sayı biçimleri — kaydetmede
  /// [XlsxSavePatch] `styles.xml`e yazar (paket bunu yapamıyor, bkz. orada).
  final Map<(int, int), String> numberFormatEdits = {};

  /// Bu oturumda verilen görünüm değişiklikleri (dolgu/yazı rengi, kalın,
  /// kenarlık, metin kaydırma) — kaydetmede [XlsxSavePatch] yazar.
  final Map<(int, int), XlsxStyleEdit> styleEdits = {};

  /// Biçim yapıştırma izleri: hedef hücre → kaynak hücre.
  final Map<(int, int), (int, int)> styleCopies = {};

  /// Bir hücreye görünüm değişikliği kaydeder (öncekiyle birleşerek).
  void recordStyleEdit(int r, int c, XlsxStyleEdit edit) {
    if (r < 0 || c < 0 || edit.isEmpty) return;
    final key = (r, c);
    final existing = styleEdits[key];
    styleEdits[key] = existing == null ? edit : existing.merge(edit);
    // Açık bir biçim değişikliği, o hücreye daha önce YAPIŞTIRILMIŞ biçimin
    // üstüne biner; ikisi de kalır (yama önce kopyayı, sonra bunu uygular).
  }

  /// Hücreye sayı biçimi verir: ekranda ANINDA uygulanır (biçim örtmesi) ve
  /// kaydetmede dosyaya yazılır.
  void setNumberFormat(int r, int c, String formatCode) {
    if (r < 0 || c < 0) return;
    final current = styleAt(r, c) ?? const XlsxCellStyle();
    patchStyle(r, c, current.copyWith(numFmtCode: formatCode));
    numberFormatEdits[(r, c)] = formatCode;
  }

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
    final all = layout.condFormats;
    if (all.isEmpty) return null;
    var index = _condIndex;
    if (index == null || _condIndexLen != all.length) {
      index = {};
      for (final rule in all) {
        final cols = <int>{};
        var wide = false;
        for (final range in rule.ranges) {
          if (range.c2 - range.c1 > 256) {
            wide = true;
            break;
          }
          for (var col = range.c1; col <= range.c2; col++) {
            cols.add(col);
          }
        }
        if (wide) {
          (index[-1] ??= []).add(rule);
        } else {
          for (final col in cols) {
            (index[col] ??= []).add(rule);
          }
        }
      }
      _condIndex = index;
      _condIndexLen = all.length;
    }
    XlsxCondRule? best;
    for (final list in [index[c], index[-1]]) {
      if (list == null) continue;
      for (final rule in list) {
        if (!rule.covers(r, c)) continue;
        if (best == null || rule.priority < best.priority) best = rule;
      }
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
/// Bir satırın/sütunun geri alma için yakalanmış içeriği.
///
/// [sizePt] satırda punto (yükseklik), sütunda karakter (genişlik) —
/// `XlsxSheetLayout` ikisini de tek tipte tuttuğu için tek alan yeter.
class SheetLineSnapshot {
  final List<String> values;

  /// İndeks → hücre kaydı (biçim indeksi, sayı/metin/formül).
  final Map<int, XlsxCell> cells;

  /// İndeks → uygulama içi biçim örtmesi.
  final Map<int, XlsxCellStyle> overrides;

  final double? sizePt;
  final bool hidden;

  const SheetLineSnapshot({
    required this.values,
    required this.cells,
    required this.overrides,
    this.sizePt,
    this.hidden = false,
  });
}

class XlsxEditor {
  /// Özgün dosya baytları — kaydetme bunun ÜSTÜNE yazar ([XlsxPackageWriter]):
  /// grafikler, resimler, notlar, tema ve stiller dokunulmadan taşınır.
  final Uint8List _source;
  final List<XlsxSheet> sheets;
  final XlsxWorkbook workbook;

  XlsxEditor._(this._source, this.sheets, this.workbook);

  /// Bir sayfası okuma sınırında kesildi mi (Faz 26b). Kesik kitap
  /// kaydedilmez: yazıcı `sheetData`yı modelden baştan kurduğu için okunmayan
  /// satır/sütunlar dosyadan silinirdi.
  bool get truncated => sheets.any((s) => s.layout.truncated);

  /// Kalıcı formül motoru için değişiklik günlüğü (Faz 26) — bkz. [CalcLog].
  final CalcLog calcLog = CalcLog();

  /// Bu oturumda eklenen grafikler (Faz 9 / Y2). Kaydetme her seferinde
  /// özgün paketin üstüne kurulduğu için liste MODEL durumudur: kaydetmeden
  /// önce geri alınabilir, iki kez kaydetmek grafiği iki kez eklemez.
  final List<XlsxChartSpec> charts = [];

  /// Grafik ekler (sayfa adı modeldeki adla eşleşmeli).
  void addChart(XlsxChartSpec spec) => charts.add(spec);

  /// Boş bir çalışma kitabı (tek sayfa).
  factory XlsxEditor.blank({String sheetName = 'Sayfa1'}) {
    final wb = XlsxWorkbook(
      sheets: [XlsxSheetLayout(name: sheetName)],
      styles: XlsxStyles(
          numFmts: const {},
          formats: [XlsxFormat.fallback()],
          dxfs: const [],
          theme: const []),
      theme: const [],
      date1904: false,
    );
    return XlsxEditor._(Uint8List(0), _buildSheets(wb), wb);
  }

  /// Dosyayı KENDİ okuyucumuzla açar (Faz 7: `excel` paketi çıktı).
  ///
  /// Okuyucu çözemezse istisna yükselir — eskiden paket reddedince
  /// `XlsxCompat` onarımıyla yeniden deneniyordu; o onarım yalnız paketin
  /// sayı biçimi kimliği takıntısı içindi, bizim okuyucumuzda o kısıt yok.
  static XlsxEditor parse(Uint8List bytes) {
    final wb = XlsxReader.read(bytes);
    if (wb.sheets.isEmpty) {
      throw const FormatException('xlsx: sayfa bulunamadı');
    }
    return XlsxEditor._(bytes, _buildSheets(wb), wb);
  }

  static List<XlsxSheet> _buildSheets(XlsxWorkbook wb) => [
        for (final l in wb.sheets)
          XlsxSheet(
            name: l.name,
            rows: _rowsFrom(l),
            layout: l,
            styles: wb.styles,
            date1904: wb.date1904,
          ),
      ];

  /// Ham hücre metinleri: sayı → `1234.5`, formül → `=SUM(A1:A3)`,
  /// metin → olduğu gibi. (Gösterim biçimi UYGULANMAZ, bkz. XlsxSheet.rows.)
  static List<List<String>> _rowsFrom(XlsxSheetLayout layout) {
    final rows = <List<String>>[];
    for (var r = 0; r <= layout.maxRow; r++) {
      var last = -1;
      for (var c = layout.maxCol; c >= 0; c--) {
        final cell = layout.cells[cellKey(r, c)];
        if (cell != null && !cell.isEmpty) {
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


  XlsxSheet? _modelSheet(String name) {
    for (final s in sheets) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Bir hücreyi günceller (ham değer + görünüm modeli).
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
    if (row[colIndex] != value) calcLog.cell(sheet.name, rowIndex, colIndex);
    row[colIndex] = value;
    sheet._touched();

    // Görünüm modeli de güncellensin (biçim/hizalama hücrenin kendi stilinden
    // gelmeye devam eder — yalnız değer değişir).
    final layout = sheet.layout;
    final key = cellKey(rowIndex, colIndex);
    final old = layout.cells[key];
    final number = double.tryParse(value);
    // Hücre kaydı YOKSA görünüm komşudan devralınır — yoksa tablonun boş bir
    // gözüne yazmak kenarlığı ve yazı tipini siliyordu (bkz.
    // [XlsxSheet.inheritTemplateAt]). `styleCopies` izi kaydetmede de aynı
    // biçimi yazar (bkz. `XlsxSavePatch._applyStyleCopies`); açık bir biçim
    // yapıştırması bu izin ÜSTÜNE yazar, sıra korunur.
    var styleIndex = old?.styleIndex ?? 0;
    if (old == null) {
      final template = sheet.inheritTemplateAt(rowIndex, colIndex);
      if (template != null) {
        styleIndex = sheet.styleIndexAt(template.$1, template.$2);
        if (styleIndex != 0) {
          sheet.styleCopies[(rowIndex, colIndex)] = template;
        }
      } else {
        styleIndex = layout.rowStyles[rowIndex] ?? layout.colStyles[colIndex] ?? 0;
      }
    }
    layout.cells[key] = XlsxCell(
      row: rowIndex,
      col: colIndex,
      styleIndex: styleIndex,
      number: (value.startsWith('=') || number == null) ? null : number,
      text: (value.startsWith('=') || number != null) ? null : value,
      // Mantıksal hücre DOĞRU/YANLIŞ kalırsa kaydetmede yine `t="b"` yazılır.
      boolean: old?.boolean != null &&
              (value == 'DOĞRU' || value == 'YANLIŞ')
          ? value == 'DOĞRU'
          : null,
      formula: value.length > 1 && value.startsWith('=')
          ? value.substring(1)
          : null,
    );
    if (rowIndex > layout.maxRow) layout.maxRow = rowIndex;
    if (colIndex > layout.maxCol) layout.maxCol = colIndex;

  }

  // ── anlık görüntü (geri alma) ─────────────────────────────────────────────

  /// Bir satırın ya da sütunun **tam** içeriği: değerler, hücre kayıtları
  /// (biçim indeksi dahil), uygulama içi biçim örtmeleri, ölçü ve gizlilik.
  ///
  /// Silme işlemini geri alabilmek için gerekir: `deleteRow`un tersi yalnız
  /// `insertRow` değildir — silinen satırın İÇERİĞİ de geri konmalıdır.
  SheetLineSnapshot captureRow(String sheetName, int rowIndex, {int? width}) {
    final sheet = _modelSheet(sheetName);
    if (sheet == null || rowIndex < 0) {
      return const SheetLineSnapshot(values: [], cells: {}, overrides: {});
    }
    width ??= sheet.maxCols;
    return SheetLineSnapshot(
      values: [for (var c = 0; c < width; c++) sheet.rawAt(rowIndex, c)],
      cells: {
        for (var c = 0; c < width; c++)
          if (sheet.layout.cells[cellKey(rowIndex, c)] != null)
            c: sheet.layout.cells[cellKey(rowIndex, c)]!,
      },
      overrides: {
        for (var c = 0; c < width; c++)
          if (sheet.overrideAt(rowIndex, c) != null)
            c: sheet.overrideAt(rowIndex, c)!,
      },
      sizePt: sheet.layout.rowHeights[rowIndex],
      hidden: sheet.layout.hiddenRows.contains(rowIndex),
    );
  }

  SheetLineSnapshot captureColumn(String sheetName, int colIndex) {
    final sheet = _modelSheet(sheetName);
    if (sheet == null || colIndex < 0) {
      return const SheetLineSnapshot(values: [], cells: {}, overrides: {});
    }
    final height = sheet.maxRows;
    return SheetLineSnapshot(
      values: [for (var r = 0; r < height; r++) sheet.rawAt(r, colIndex)],
      cells: {
        for (var r = 0; r < height; r++)
          if (sheet.layout.cells[cellKey(r, colIndex)] != null)
            r: sheet.layout.cells[cellKey(r, colIndex)]!,
      },
      overrides: {
        for (var r = 0; r < height; r++)
          if (sheet.overrideAt(r, colIndex) != null)
            r: sheet.overrideAt(r, colIndex)!,
      },
      sizePt: sheet.layout.colWidths[colIndex],
      hidden: sheet.layout.hiddenCols.contains(colIndex),
    );
  }

  /// [captureRow] ile alınmış içeriği [rowIndex]'e geri yazar.
  /// Satırın kendisi çağırandan ÖNCE `insertRow` ile açılmış olmalıdır.
  void restoreRow(String sheetName, int rowIndex, SheetLineSnapshot snap) {
    final sheet = _modelSheet(sheetName);
    if (sheet == null) return;
    for (var c = 0; c < snap.values.length; c++) {
      setCell(sheetName, rowIndex, c, snap.values[c]);
    }
    // `setCell` hücre kaydını yeniden kurar ve biçim indeksini SIFIRLAR
    // (yeni açılan satırda eski kayıt yok); özgün kaydı üstüne yazmak şart,
    // yoksa geri alınan satır biçimsiz geri gelirdi.
    snap.cells.forEach((c, cell) {
      sheet.layout.cells[cellKey(rowIndex, c)] = cell;
    });
    snap.overrides.forEach((c, style) => sheet.patchStyle(rowIndex, c, style));
    if (snap.sizePt != null) sheet.layout.rowHeights[rowIndex] = snap.sizePt!;
    if (snap.hidden) sheet.layout.hiddenRows.add(rowIndex);
  }

  /// [captureColumn] ile alınmış içeriği [colIndex]'e geri yazar.
  void restoreColumn(String sheetName, int colIndex, SheetLineSnapshot snap) {
    final sheet = _modelSheet(sheetName);
    if (sheet == null) return;
    for (var r = 0; r < snap.values.length; r++) {
      setCell(sheetName, r, colIndex, snap.values[r]);
    }
    snap.cells.forEach((r, cell) {
      sheet.layout.cells[cellKey(r, colIndex)] = cell;
    });
    snap.overrides.forEach((r, style) => sheet.patchStyle(r, colIndex, style));
    if (snap.sizePt != null) sheet.layout.colWidths[colIndex] = snap.sizePt!;
    if (snap.hidden) sheet.layout.hiddenCols.add(colIndex);
  }

  // ── yapısal işlemler ──────────────────────────────────────────────────────
  // Model (ham değerler + hücre kayıtları + ölçüler) kaydırılır; kaydetme
  // modeli baştan yazdığı için başka bir kopya tutulmaz.

  void insertRow(String sheetName, int rowIndex) {
    final model = _modelSheet(sheetName);
    if (model == null) return;
    final at = rowIndex.clamp(0, model.rows.length);
    model.rows.insert(at, <String>[]);
    _shiftLayoutRows(model.layout, at, 1);
    _applyStructural(model, SheetShift(rows: true, at: at, delta: 1));
  }

  void deleteRow(String sheetName, int rowIndex) {
    final model = _modelSheet(sheetName);
    if (model == null) return;
    if (rowIndex < 0 || rowIndex >= model.rows.length) return;
    model.rows.removeAt(rowIndex);
    _shiftLayoutRows(model.layout, rowIndex, -1);
    _applyStructural(model, SheetShift(rows: true, at: rowIndex, delta: -1));
  }

  void insertColumn(String sheetName, int colIndex) {
    final model = _modelSheet(sheetName);
    if (model == null) return;
    final at = colIndex.clamp(0, model.maxCols);
    for (final row in model.rows) {
      if (at <= row.length) row.insert(at, '');
    }
    model._touched();
    _shiftLayoutCols(model.layout, at, 1);
    _applyStructural(model, SheetShift(rows: false, at: at, delta: 1));
  }

  void deleteColumn(String sheetName, int colIndex) {
    final model = _modelSheet(sheetName);
    if (model == null) return;
    if (colIndex < 0 || colIndex >= model.maxCols) return;
    for (final row in model.rows) {
      if (colIndex < row.length) row.removeAt(colIndex);
    }
    model._touched();
    _shiftLayoutCols(model.layout, colIndex, -1);
    _applyStructural(model, SheetShift(rows: false, at: colIndex, delta: -1));
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
      // Silmede silinen satırın kaydı düşer — yoksa bir ÜSTTEKİ satıra
      // yazılır (Faz 20 / X2).
      if (_inDeleted(r, at, delta)) return;
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
      if (_inDeleted(c, at, delta)) return;
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

  /// Silme ([delta] < 0) sırasında [k] silinen aralıkta mı (`at … at-delta-1`).
  static bool _inDeleted(int k, int at, int delta) =>
      delta < 0 && k >= at && k < at - delta;

  static void _shiftKeys<T>(Map<int, T> map, int at, int delta) {
    final copy = <int, T>{};
    map.forEach((k, v) {
      if (k < at) {
        copy[k] = v;
      } else if (_inDeleted(k, at, delta)) {
        // silinen satır/sütunun kaydı düşer
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
      } else if (_inDeleted(k, at, delta)) {
        continue;
      } else if (k + delta >= 0) {
        copy.add(k + delta);
      }
    }
    set
      ..clear()
      ..addAll(copy);
  }

  /// Seçili hücrenin yazı biçimini değiştirir. Verilmeyen alanlar korunur.
  void setCellStyle(String sheetName, int r, int c,
      {bool? bold, bool? italic, TextAlign? align}) {
    final model = _modelSheet(sheetName);
    if (model == null || r < 0 || c < 0) return;
    XlsxHAlign? modelAlign;
    String? fileAlign;
    if (align != null) {
      modelAlign = switch (align) {
        TextAlign.center => XlsxHAlign.center,
        TextAlign.right => XlsxHAlign.right,
        _ => XlsxHAlign.left,
      };
      fileAlign = modelAlign.name;
    }
    final current = model.styleAt(r, c) ?? const XlsxCellStyle();
    model.patchStyle(
      r,
      c,
      current.copyWith(bold: bold, italic: italic, hAlign: modelAlign),
    );
    model.recordStyleEdit(
        r, c, XlsxStyleEdit(bold: bold, italic: italic, hAlign: fileAlign));
  }

  /// Hücrenin **dolgu rengi**. [color] null ise dolgu kaldırılır.
  ///
  /// Ekranda anında görünür (biçim örtmesi) ve kaydetmede `styles.xml`e
  /// yazılır. `excel` paketinin renk API'si bilinçli olarak KULLANILMIYOR:
  /// tek bir `ExcelColor` sabit paleti var, kullanıcının seçtiği serbest
  /// rengi en yakın sabite yuvarlıyor.
  void setCellFill(String sheetName, int r, int c, Color? color) {
    final model = _modelSheet(sheetName);
    if (model == null || r < 0 || c < 0) return;
    final current = model.styleAt(r, c) ?? const XlsxCellStyle();
    model.patchStyle(
      r,
      c,
      current.copyWith(background: color, clearBackground: color == null),
    );
    model.recordStyleEdit(
      r,
      c,
      XlsxStyleEdit(
        fillArgb: color == null ? XlsxStyleEdit.noFill : _argbOf(color),
      ),
    );
  }

  /// Hücrenin **yazı rengi**. [color] null ise dosyadaki varsayılana döner.
  void setFontColor(String sheetName, int r, int c, Color? color) {
    final model = _modelSheet(sheetName);
    if (model == null || r < 0 || c < 0) return;
    final current = model.styleAt(r, c) ?? const XlsxCellStyle();
    model.patchStyle(
      r,
      c,
      current.copyWith(fontColor: color, clearFontColor: color == null),
    );
    // "Otomatik" (null) siyaha yazılır: `<color>` etiketini SİLMEK dosyadaki
    // taban yazı tipinin rengini geri getirmez, çünkü taban zaten klonlanıyor.
    model.recordStyleEdit(
      r,
      c,
      XlsxStyleEdit(fontArgb: _argbOf(color ?? AppColors.pageInk)),
    );
  }

  /// Hücrenin **yazı puntosu**. `null` verilirse dosyadaki taban punto kalır.
  void setFontSize(String sheetName, int r, int c, double? size) {
    final model = _modelSheet(sheetName);
    if (model == null || r < 0 || c < 0) return;
    final current = model.styleAt(r, c) ?? const XlsxCellStyle();
    final value = size ?? current.fontSize ?? 11;
    model.patchStyle(r, c, current.copyWith(fontSize: value));
    model.recordStyleEdit(r, c, XlsxStyleEdit(fontSize: value));
  }

  /// Hücrenin **yazı tipi ailesi** (Arial, Calibri…).
  void setFontFamily(String sheetName, int r, int c, String? family) {
    final model = _modelSheet(sheetName);
    if (model == null || r < 0 || c < 0 || family == null || family.isEmpty) {
      return;
    }
    final current = model.styleAt(r, c) ?? const XlsxCellStyle();
    model.patchStyle(r, c, current.copyWith(fontFamily: family));
    model.recordStyleEdit(r, c, XlsxStyleEdit(fontName: family));
  }

  /// Hücrede **metin kaydırma**.
  void setWrapText(String sheetName, int r, int c, bool wrap) {
    final model = _modelSheet(sheetName);
    if (model == null || r < 0 || c < 0) return;
    final current = model.styleAt(r, c) ?? const XlsxCellStyle();
    model.patchStyle(r, c, current.copyWith(wrap: wrap));
    model.recordStyleEdit(r, c, XlsxStyleEdit(wrap: wrap));
  }

  /// Hücrenin kenarlığı. [sides] kenar adı → Excel çizgi biçimi (`thin`,
  /// `medium`, `thick`, `double`); değer `null` ise o kenar silinir.
  void setCellBorder(
      String sheetName, int r, int c, Map<String, String?> sides) {
    final model = _modelSheet(sheetName);
    if (model == null || r < 0 || c < 0 || sides.isEmpty) return;
    final current = model.styleAt(r, c) ?? const XlsxCellStyle();
    XlsxBorderSide sideOf(String name, XlsxBorderSide fallback) =>
        sides.containsKey(name)
            ? XlsxBorderSide(sides[name] ?? 'none', null)
            : fallback;
    model.patchStyle(
      r,
      c,
      current.copyWith(
        border: XlsxBorder(
          left: sideOf('left', current.border.left),
          right: sideOf('right', current.border.right),
          top: sideOf('top', current.border.top),
          bottom: sideOf('bottom', current.border.bottom),
        ),
      ),
    );
    model.recordStyleEdit(r, c, XlsxStyleEdit(borders: sides));
  }

  /// **Biçim yapıştırma**: kaynak hücrenin görünümünü hedefe taşır.
  /// Değer taşınmaz — onu `paste` yapar.
  void copyCellFormat(String sheetName, int sr, int sc, int dr, int dc) {
    final model = _modelSheet(sheetName);
    if (model == null || sr < 0 || sc < 0 || dr < 0 || dc < 0) return;
    if (sr == dr && sc == dc) return;
    model.patchStyle(dr, dc, model.styleAt(sr, sc));
    model.styleCopies[(dr, dc)] = (sr, sc);
    // Kaynağın kendi oturum-içi düzenlemeleri de taşınır: yamada kopyalanan
    // `s` indeksi kaynağın DOSYADAKİ hâlidir, bu turda verilen dolgu/renk
    // ondan sonra geliyor.
    final srcEdit = model.styleEdits[(sr, sc)];
    if (srcEdit != null) model.styleEdits[(dr, dc)] = srcEdit;
    final srcFmt = model.numberFormatEdits[(sr, sc)];
    if (srcFmt != null) model.numberFormatEdits[(dr, dc)] = srcFmt;
  }

  // ── sayfa yönetimi ────────────────────────────────────────────────────

  /// Kitapta bu ad kullanılıyor mu (büyük/küçük harf duyarsız — Excel de
  /// "Sayfa1" ile "sayfa1"i aynı sayar).
  bool hasSheet(String name) {
    final want = name.trim().toLowerCase();
    return sheets.any((s) => s.name.toLowerCase() == want);
  }

  /// Yeni boş sayfa ekler; model listesinin SONUNA gelir. Ad boşsa ya da
  /// kullanılıyorsa hiçbir şey yapmaz ve null döner.
  XlsxSheet? addSheet(String name) {
    final clean = name.trim();
    if (clean.isEmpty || hasSheet(clean)) return null;
    final sheet = XlsxSheet(
      name: clean,
      rows: <List<String>>[],
      layout: XlsxSheetLayout(name: clean),
      styles: workbook.styles,
      date1904: workbook.date1904,
    );
    sheets.add(sheet);
    calcLog.bulk();
    return sheet;
  }

  /// Sayfayı siler. **Son sayfa silinemez** — sayfasız bir çalışma kitabı
  /// geçersiz.
  bool deleteSheet(String name) {
    if (sheets.length <= 1) return false;
    final model = _modelSheet(name);
    if (model == null) return false;
    sheets.remove(model);
    calcLog.bulk();
    return true;
  }

  /// Sayfayı yeniden adlandırır. Model nesnesinin KENDİSİ korunur — bu
  /// oturumda verilen biçimler (örtmeler, sayı biçimleri, yapıştırılan biçim
  /// izleri) ona bağlı. Dosyadaki parça aynı kalır, yalnız `workbook.xml`deki
  /// ad değişir.
  bool renameSheet(String oldName, String newName) {
    final clean = newName.trim();
    final model = _modelSheet(oldName);
    if (model == null || clean.isEmpty || oldName == clean) return false;
    if (hasSheet(clean)) return false;
    model.name = clean;
    model.layout.name = clean;
    calcLog.bulk();
    // Eklenen grafiklerin sayfa adı da (formül başvuruları adla yazılır).
    for (var i = 0; i < charts.length; i++) {
      final c = charts[i];
      if (c.sheetName != oldName) continue;
      charts[i] = XlsxChartSpec(
        sheetName: clean,
        kind: c.kind,
        title: c.title,
        top: c.top,
        left: c.left,
        bottom: c.bottom,
        right: c.right,
        hasCategoryColumn: c.hasCategoryColumn,
        categories: c.categories,
        series: c.series,
        anchorRow: c.anchorRow,
        anchorCol: c.anchorCol,
      );
    }
    return true;
  }

  /// Sayfayı [to] sırasına taşır (Faz 9 / Y2: sayfa taşıma). Dosyada
  /// `workbook.xml`in `<sheets>` sırası ve yerel adların `localSheetId`si
  /// buna göre yeniden yazılır.
  bool moveSheet(String name, int to) {
    final model = _modelSheet(name);
    if (model == null) return false;
    final from = sheets.indexOf(model);
    final target = to.clamp(0, sheets.length - 1);
    if (from == target) return false;
    sheets
      ..removeAt(from)
      ..insert(target, model);
    calcLog.bulk();
    return true;
  }

  /// Hücre aralığını **birleştirir** (kaydetmede `<mergeCells>`).
  void mergeCells(String sheetName, int r1, int c1, int r2, int c2) {
    if (r1 == r2 && c1 == c2) return;
    _modelSheet(sheetName)?.addMerge(XlsxMerge(r1, c1, r2, c2));
  }

  /// Verilen hücreyi kapsayan birleşmeyi **çözer**.
  void unmergeAt(String sheetName, int r, int c) {
    final model = _modelSheet(sheetName);
    final merge = model?.mergeAt(r, c);
    if (model == null || merge == null) return;
    model.removeMerge(merge);
  }

  static int _argbOf(Color c) =>
      ((c.a * 255).round() << 24) |
      ((c.r * 255).round() << 16) |
      ((c.g * 255).round() << 8) |
      (c.b * 255).round();

  /// Kaydetmenin girdisi: o anki model, paket yazıcısının ve yamaların
  /// beklediği biçimde. Saf veri — izolata kopyalanabilir.
  _XlsxSaveJob _saveJob() {
    // Önce değerler ve yapı (özgün paket korunarak), sonra görünüm
    // düzenlemeleri, dondurulmuş bölme, sayfa yönü, ızgara çizgisi, süzgeç
    // (XML yaması — `styles.xml` yalnız değişen biçimler için genişler).
    final sheetsOut = [
      for (final s in sheets)
        XlsxPackageSheet(
          name: s.name,
          partPath: s.layout.partPath,
          rows: s.rows,
          layout: s.layout,
          merges: [
            for (final m in s.merges)
              XlsxRange(m.rowStart, m.colStart, m.rowEnd, m.colEnd),
          ],
          hidden: s.layout.hidden,
          shifts: List.of(s.structuralOps),
        ),
    ];
    final patches = [
      for (final s in sheets)
        XlsxSheetPatch(
          name: s.name,
          rightToLeft: s.rightToLeft,
          hiddenRows: s.layout.hiddenRows,
          hiddenCols: s.layout.hiddenCols,
          frozenRows: s.layout.frozenRows,
          frozenCols: s.layout.frozenCols,
          showGridLines: s.layout.showGridLines,
          autoFilterRef: s.layout.autoFilterRef,
          // Yalnız HİÇ HÜCRESİ OLMAYAN satırlar: paket `<row>`u yalnız
          // hücresi olan satır için yazıyor, o yüzden ayırıcı boş satırların
          // özel yüksekliği kaydetmede kayboluyordu.
          rowHeightsPt: {
            for (final e in s.layout.rowHeights.entries)
              if (e.value > 0 && _isEmptyRow(s, e.key)) e.key: e.value,
          },
          numberFormats: s.numberFormatEdits,
          styleEdits: s.styleEdits,
          styleCopies: s.styleCopies,
          condRules: s.condRuleEdits,
        ),
    ];
    return _XlsxSaveJob(_source, sheetsOut, patches, [
      for (final c in charts)
        if (hasSheet(c.sheetName)) c,
    ]);
  }

  /// Dosyayı UI izleğinde üretir (testler, küçük dosyalar, dışa aktarım).
  Uint8List save() {
    _guardTruncated();
    return _runSave(_saveJob());
  }

  void _guardTruncated() {
    if (truncated) throw const XlsxTruncatedException();
  }

  /// Dosyayı ayrı izolatta üretir (Faz 20 / ED3): paket yazımı, yamalar ve
  /// zip sıkıştırma UI izleğini dondurmaz. Model gönderim anında kopyalanır;
  /// kayıt sürerken yapılan düzenleme bir sonraki kayda kalır.
  Future<Uint8List> saveAsync() async {
    _guardTruncated();
    return SaveIsolate.run<_XlsxSaveJob, Uint8List>(_runSave, _saveJob());
  }

  static Uint8List _runSave(_XlsxSaveJob job) {
    // Önce değerler ve yapı (özgün paket korunarak), sonra görünüm
    // düzenlemeleri, dondurulmuş bölme, sayfa yönü, ızgara çizgisi, süzgeç
    // (XML yaması — `styles.xml` yalnız değişen biçimler için genişler).
    final bytes = XlsxPackageWriter.write(job.source, job.sheets);
    final patched = XlsxSavePatch.apply(bytes, job.patches);
    // Grafikler en son: sayfa XML'ine `<drawing>` ekler, öncekiler onu
    // korur ama yazmaz.
    return XlsxChartWriter.apply(patched, job.charts);
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

/// Okuma sınırında kesilmiş kitabı kaydetme girişimi (veri kaybı olurdu).
class XlsxTruncatedException implements Exception {
  const XlsxTruncatedException();

  @override
  String toString() => 'xlsx: sayfa okuma sınırında kesildi; kaydetme kapalı';
}

/// [XlsxEditor.saveAsync]'in izolata giden girdisi.
class _XlsxSaveJob {
  final Uint8List source;
  final List<XlsxPackageSheet> sheets;
  final List<XlsxSheetPatch> patches;
  final List<XlsxChartSpec> charts;
  const _XlsxSaveJob(this.source, this.sheets, this.patches, this.charts);
}
