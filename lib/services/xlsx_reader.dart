import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../core/excel_format.dart';

/// .xlsx dosyasının **görünüm** tarafını ham OOXML'den okur.
///
/// *Niye kendi okuyucumuz:* `excel` paketi (4.0.6) hücre hizalamasını hiç
/// okumuyor, sayı biçim kodunu vermiyor, tarihleri kendi kafasına göre metne
/// çeviriyor, dondurulmuş bölme/koşullu biçim/kenarlık/tema rengi gibi
/// Excel'in görüntüsünü belirleyen her şeyi atıyor. Sadakati %100'e çıkarmanın
/// tek yolu sayfayı Excel'in yazdığı gibi okumak: `xl/styles.xml`,
/// `xl/theme/theme1.xml`, `xl/worksheets/sheetN.xml`, `xl/sharedStrings.xml`.
///
/// Yazma tarafı `excel` paketinde KALIR (xlsx_editor.dart) — burada yalnız
/// okuma var, dosya bozma riski yok.
class XlsxReader {
  /// Bir sayfada en çok bu kadar sütun/satır çözümlenir (bozuk dosyada
  /// 16384×1048576 hücrelik boş ızgara belleği doldurmasın).
  static const int maxColumns = 1024;
  static const int maxRows = 200000;

  static XlsxWorkbook read(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, List<int>>{};
    for (final f in archive.files) {
      if (f.isFile) files[f.name] = f.content as List<int>;
    }

    XmlDocument? doc(String name) {
      final data = files[name];
      if (data == null) return null;
      try {
        return XmlDocument.parse(utf8.decode(data, allowMalformed: true));
      } catch (_) {
        return null;
      }
    }

    final theme = _readTheme(doc('xl/theme/theme1.xml'));
    final shared = _readSharedStrings(doc('xl/sharedStrings.xml'));
    final styles = _readStyles(doc('xl/styles.xml'), theme);

    final wb = doc('xl/workbook.xml');
    final rels = doc('xl/_rels/workbook.xml.rels');
    final relTarget = <String, String>{};
    if (rels != null) {
      for (final r in rels.rootElement.childElements) {
        final id = r.getAttribute('Id');
        final tgt = r.getAttribute('Target');
        if (id != null && tgt != null) relTarget[id] = tgt;
      }
    }

    var date1904 = false;
    if (wb != null) {
      for (final pr in wb.findAllElements('workbookPr')) {
        final d = pr.getAttribute('date1904') ?? pr.getAttribute('dateCompatibility');
        if (d == '1' || d == 'true') date1904 = true;
      }
    }

    final sheets = <XlsxSheetLayout>[];
    if (wb != null) {
      for (final s in wb.findAllElements('sheet')) {
        final name = s.getAttribute('name');
        if (name == null) continue;
        final rid = s.getAttribute('r:id') ?? s.getAttribute('id');
        final state = s.getAttribute('state');
        var target = rid == null ? null : relTarget[rid];
        target = _normalizeTarget(target);
        final ws = target == null ? null : doc(target);
        final layout = _readSheet(ws, name, shared, styles);
        layout.hidden = state == 'hidden' || state == 'veryHidden';
        sheets.add(layout);
      }
    }
    if (sheets.isEmpty) {
      // workbook.xml okunamadıysa: sheet1'i doğrudan dene.
      final ws = doc('xl/worksheets/sheet1.xml');
      if (ws != null) {
        sheets.add(_readSheet(ws, 'Sayfa1', shared, styles));
      }
    }

    return XlsxWorkbook(
      sheets: sheets,
      styles: styles,
      theme: theme,
      date1904: date1904,
    );
  }

  static String? _normalizeTarget(String? target) {
    if (target == null) return null;
    if (target.startsWith('/')) return target.substring(1);
    if (target.startsWith('xl/')) return target;
    return 'xl/${target.replaceFirst('./', '')}';
  }

  // ── tema renkleri ─────────────────────────────────────────────────────────

  static List<int> _readTheme(XmlDocument? doc) {
    // clrScheme sırası: dk1, lt1, dk2, lt2, accent1..6, hlink, folHlink.
    // Excel'in `theme="n"` indeksi ise: 0=lt1, 1=dk1, 2=lt2, 3=dk2, 4..9=accent,
    // 10=hlink, 11=folHlink → ilk iki çift YER DEĞİŞTİRİR.
    final fallback = <int>[
      0xFFFFFFFF, 0xFF000000, 0xFFE7E6E6, 0xFF44546A, //
      0xFF4472C4, 0xFFED7D31, 0xFFA5A5A5, 0xFFFFC000, //
      0xFF5B9BD5, 0xFF70AD47, 0xFF0563C1, 0xFF954F72,
    ];
    if (doc == null) return fallback;
    final scheme = doc.findAllElements('a:clrScheme').firstOrNull ??
        doc.findAllElements('clrScheme').firstOrNull;
    if (scheme == null) return fallback;
    final ordered = <int>[];
    for (final child in scheme.childElements) {
      int? argb;
      for (final c in child.childElements) {
        final local = c.name.local;
        if (local == 'srgbClr') {
          argb = _hexToArgb(c.getAttribute('val'));
        } else if (local == 'sysClr') {
          argb = _hexToArgb(c.getAttribute('lastClr')) ??
              (c.getAttribute('val') == 'windowText'
                  ? 0xFF000000
                  : 0xFFFFFFFF);
        }
      }
      ordered.add(argb ?? 0xFF000000);
    }
    if (ordered.length < 4) return fallback;
    final out = List<int>.from(ordered);
    // dk1/lt1 ve dk2/lt2 sırasını Excel indeksine çevir.
    final t0 = out[0];
    out[0] = out[1];
    out[1] = t0;
    final t2 = out[2];
    out[2] = out[3];
    out[3] = t2;
    while (out.length < 12) {
      out.add(0xFF000000);
    }
    return out;
  }

  // ── paylaşılan dizeler ────────────────────────────────────────────────────

  static List<XlsxSharedString> _readSharedStrings(XmlDocument? doc) {
    final out = <XlsxSharedString>[];
    if (doc == null) return out;
    for (final si in doc.rootElement.childElements) {
      if (si.name.local != 'si') continue;
      final runs = <XlsxRichRun>[];
      final sb = StringBuffer();
      for (final child in si.childElements) {
        if (child.name.local == 't') {
          sb.write(child.innerText);
        } else if (child.name.local == 'r') {
          final text = child.childElements
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join();
          sb.write(text);
          final rPr = child.childElements
              .where((e) => e.name.local == 'rPr')
              .firstOrNull;
          runs.add(XlsxRichRun(
            text: text,
            bold: rPr?.childElements.any((e) => e.name.local == 'b') ?? false,
            italic: rPr?.childElements.any((e) => e.name.local == 'i') ?? false,
            underline:
                rPr?.childElements.any((e) => e.name.local == 'u') ?? false,
            strike:
                rPr?.childElements.any((e) => e.name.local == 'strike') ?? false,
          ));
        }
      }
      out.add(XlsxSharedString(sb.toString(), runs.length > 1 ? runs : null));
    }
    return out;
  }

  // ── styles.xml ────────────────────────────────────────────────────────────

  static XlsxStyles _readStyles(XmlDocument? doc, List<int> theme) {
    final numFmts = <int, String>{...builtinNumberFormats};
    final fonts = <XlsxFont>[];
    final fills = <XlsxFill>[];
    final borders = <XlsxBorder>[];
    final formats = <XlsxFormat>[];
    final dxfs = <XlsxDxf>[];

    if (doc == null) {
      return XlsxStyles(
        numFmts: numFmts,
        formats: [XlsxFormat.fallback()],
        dxfs: dxfs,
        theme: theme,
      );
    }

    for (final nf in doc.findAllElements('numFmt')) {
      final id = int.tryParse(nf.getAttribute('numFmtId') ?? '');
      final code = nf.getAttribute('formatCode');
      if (id != null && code != null) numFmts[id] = code;
    }

    final fontsEl = doc.findAllElements('fonts').firstOrNull;
    if (fontsEl != null) {
      for (final f in fontsEl.childElements.where((e) => e.name.local == 'font')) {
        fonts.add(_readFont(f, theme));
      }
    }

    final fillsEl = doc.findAllElements('fills').firstOrNull;
    if (fillsEl != null) {
      for (final f in fillsEl.childElements.where((e) => e.name.local == 'fill')) {
        fills.add(_readFill(f, theme));
      }
    }

    final bordersEl = doc.findAllElements('borders').firstOrNull;
    if (bordersEl != null) {
      for (final b
          in bordersEl.childElements.where((e) => e.name.local == 'border')) {
        borders.add(_readBorder(b, theme));
      }
    }

    // cellStyleXfs: cellXfs'in miras aldığı adlandırılmış stiller.
    final styleXfs = <XlsxFormat>[];
    final styleXfsEl = doc.findAllElements('cellStyleXfs').firstOrNull;
    if (styleXfsEl != null) {
      for (final xf in styleXfsEl.childElements.where((e) => e.name.local == 'xf')) {
        styleXfs.add(_readXf(xf, numFmts, fonts, fills, borders, null));
      }
    }

    final cellXfsEl = doc.findAllElements('cellXfs').firstOrNull;
    if (cellXfsEl != null) {
      for (final xf in cellXfsEl.childElements.where((e) => e.name.local == 'xf')) {
        XlsxFormat? base;
        final xfId = int.tryParse(xf.getAttribute('xfId') ?? '');
        if (xfId != null && xfId >= 0 && xfId < styleXfs.length) {
          base = styleXfs[xfId];
        }
        formats.add(_readXf(xf, numFmts, fonts, fills, borders, base));
      }
    }
    if (formats.isEmpty) formats.add(XlsxFormat.fallback());

    final dxfsEl = doc.findAllElements('dxfs').firstOrNull;
    if (dxfsEl != null) {
      for (final d in dxfsEl.childElements.where((e) => e.name.local == 'dxf')) {
        final fontEl =
            d.childElements.where((e) => e.name.local == 'font').firstOrNull;
        final fillEl =
            d.childElements.where((e) => e.name.local == 'fill').firstOrNull;
        dxfs.add(XlsxDxf(
          font: fontEl == null ? null : _readFont(fontEl, theme),
          fill: fillEl == null ? null : _readFill(fillEl, theme),
        ));
      }
    }

    return XlsxStyles(
      numFmts: numFmts,
      formats: formats,
      dxfs: dxfs,
      theme: theme,
    );
  }

  static XlsxFont _readFont(XmlElement f, List<int> theme) {
    String? name;
    double? size;
    var bold = false, italic = false, strike = false;
    String? underline;
    int? color;
    for (final c in f.childElements) {
      switch (c.name.local) {
        case 'name':
        case 'rFont':
          name = c.getAttribute('val');
        case 'sz':
          size = double.tryParse(c.getAttribute('val') ?? '');
        case 'b':
          bold = _boolAttr(c);
        case 'i':
          italic = _boolAttr(c);
        case 'strike':
          strike = _boolAttr(c);
        case 'u':
          underline = c.getAttribute('val') ?? 'single';
        case 'color':
          color = _readColor(c, theme);
      }
    }
    return XlsxFont(
      name: name,
      size: size,
      bold: bold,
      italic: italic,
      underline: underline,
      strike: strike,
      colorArgb: color,
    );
  }

  static XlsxFill _readFill(XmlElement f, List<int> theme) {
    final pf =
        f.childElements.where((e) => e.name.local == 'patternFill').firstOrNull;
    if (pf == null) {
      final gf = f.childElements
          .where((e) => e.name.local == 'gradientFill')
          .firstOrNull;
      if (gf != null) {
        // Gradyan dolgu: ilk durağın rengiyle düz yaklaşıklanır.
        final stop = gf.childElements
            .where((e) => e.name.local == 'stop')
            .firstOrNull;
        final c = stop?.childElements
            .where((e) => e.name.local == 'color')
            .firstOrNull;
        return XlsxFill(
            pattern: 'solid', fgArgb: c == null ? null : _readColor(c, theme));
      }
      return const XlsxFill(pattern: 'none');
    }
    int? fg, bg;
    for (final c in pf.childElements) {
      if (c.name.local == 'fgColor') fg = _readColor(c, theme);
      if (c.name.local == 'bgColor') bg = _readColor(c, theme);
    }
    // Koşullu biçim (dxf) dolgularında Excel `patternType` YAZMAZ, yalnız
    // `bgColor` verir → desensiz ama renkli dolgu demektir.
    final pattern =
        pf.getAttribute('patternType') ?? ((fg ?? bg) != null ? 'solid' : 'none');
    return XlsxFill(pattern: pattern, fgArgb: fg, bgArgb: bg);
  }

  static XlsxBorder _readBorder(XmlElement b, List<int> theme) {
    XlsxBorderSide side(String name) {
      final el = b.childElements.where((e) => e.name.local == name).firstOrNull;
      if (el == null) return const XlsxBorderSide('none', null);
      final style = el.getAttribute('style') ?? 'none';
      final c =
          el.childElements.where((e) => e.name.local == 'color').firstOrNull;
      return XlsxBorderSide(style, c == null ? null : _readColor(c, theme));
    }

    return XlsxBorder(
      left: side('left'),
      right: side('right'),
      top: side('top'),
      bottom: side('bottom'),
    );
  }

  static XlsxFormat _readXf(
    XmlElement xf,
    Map<int, String> numFmts,
    List<XlsxFont> fonts,
    List<XlsxFill> fills,
    List<XlsxBorder> borders,
    XlsxFormat? base,
  ) {
    int idx(String attr) => int.tryParse(xf.getAttribute(attr) ?? '') ?? 0;

    // NOT: `applyFont/applyFill/applyBorder` bayrakları BİLEREK yok sayılır.
    // Birçok üretici (bizim yazma tarafımız dahil) bayrağı yazmadan ya da 0
    // yazarak stil kimliği veriyor; bayrağa uyulursa kalın/renkli hücreler
    // düz görünür. Yaygın okuyucular (openpyxl, LibreOffice) da kimliği
    // doğrudan kullanır.
    final numFmtId = idx('numFmtId');
    final fontId = idx('fontId');
    final fillId = idx('fillId');
    final borderId = idx('borderId');
    final font = fontId < fonts.length
        ? fonts[fontId]
        : (base?.font ?? (fonts.isNotEmpty ? fonts[0] : const XlsxFont()));
    final fill = fillId < fills.length
        ? fills[fillId]
        : (base?.fill ?? const XlsxFill(pattern: 'none'));
    final border = borderId < borders.length
        ? borders[borderId]
        : (base?.border ?? const XlsxBorder());

    final alignEl =
        xf.childElements.where((e) => e.name.local == 'alignment').firstOrNull;
    final align = alignEl == null
        ? (base?.align ?? const XlsxAlign())
        : XlsxAlign(
            horizontal: _hAlign(alignEl.getAttribute('horizontal')),
            vertical: _vAlign(alignEl.getAttribute('vertical')),
            wrapText: alignEl.getAttribute('wrapText') == '1' ||
                alignEl.getAttribute('wrapText') == 'true',
            indent: int.tryParse(alignEl.getAttribute('indent') ?? '') ?? 0,
            textRotation:
                int.tryParse(alignEl.getAttribute('textRotation') ?? '') ?? 0,
            shrinkToFit: alignEl.getAttribute('shrinkToFit') == '1',
          );

    return XlsxFormat(
      numFmtId: numFmtId,
      numFmtCode: numFmts[numFmtId] ?? 'General',
      font: font,
      fill: fill,
      border: border,
      align: align,
      quotePrefix: xf.getAttribute('quotePrefix') == '1',
    );
  }

  static XlsxHAlign _hAlign(String? v) => switch (v) {
        'left' => XlsxHAlign.left,
        'center' => XlsxHAlign.center,
        'centerContinuous' => XlsxHAlign.center,
        'right' => XlsxHAlign.right,
        'fill' => XlsxHAlign.left,
        'justify' => XlsxHAlign.justify,
        'distributed' => XlsxHAlign.justify,
        _ => XlsxHAlign.general,
      };

  static XlsxVAlign _vAlign(String? v) => switch (v) {
        'top' => XlsxVAlign.top,
        'center' => XlsxVAlign.center,
        'justify' => XlsxVAlign.center,
        'distributed' => XlsxVAlign.center,
        _ => XlsxVAlign.bottom, // Excel varsayılanı ALTA yaslıdır
      };

  static bool _boolAttr(XmlElement e) {
    final v = e.getAttribute('val');
    return v == null || v == '1' || v == 'true';
  }

  // ── renk çözümleme ────────────────────────────────────────────────────────

  static int? _readColor(XmlElement c, List<int> theme) {
    if (c.getAttribute('auto') == '1') return null;
    final rgb = c.getAttribute('rgb');
    if (rgb != null) return _applyTint(_hexToArgb(rgb), c.getAttribute('tint'));
    final themeIdx = int.tryParse(c.getAttribute('theme') ?? '');
    if (themeIdx != null) {
      final base =
          (themeIdx >= 0 && themeIdx < theme.length) ? theme[themeIdx] : null;
      return _applyTint(base, c.getAttribute('tint'));
    }
    final indexed = int.tryParse(c.getAttribute('indexed') ?? '');
    if (indexed != null) {
      if (indexed == 64 || indexed == 65) return null; // sistem ön/arka plan
      if (indexed >= 0 && indexed < _indexedPalette.length) {
        return _applyTint(_indexedPalette[indexed], c.getAttribute('tint'));
      }
    }
    return null;
  }

  static int? _hexToArgb(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    return int.tryParse(h, radix: 16);
  }

  /// `tint` renk tonu: negatifse koyulaştırır, pozitifse açar.
  /// (Excel bunu HSL parlaklığı üzerinden yapar; kanal başına doğrusal
  /// yaklaşıklama gözle ayırt edilemeyecek kadar yakın sonuç verir.)
  static int? _applyTint(int? argb, String? tintAttr) {
    if (argb == null) return null;
    final tint = double.tryParse(tintAttr ?? '');
    if (tint == null || tint == 0) return argb;
    int channel(int shift) {
      final v = (argb >> shift) & 0xFF;
      final nv = tint < 0 ? v * (1 + tint) : v * (1 - tint) + 255 * tint;
      return nv.round().clamp(0, 255);
    }

    return (argb & 0xFF000000) |
        (channel(16) << 16) |
        (channel(8) << 8) |
        channel(0);
  }

  // ── sayfa ─────────────────────────────────────────────────────────────────

  static XlsxSheetLayout _readSheet(XmlDocument? ws, String name,
      List<XlsxSharedString> shared, XlsxStyles styles) {
    final layout = XlsxSheetLayout(name: name);
    if (ws == null) return layout;
    final root = ws.rootElement;

    for (final el in root.childElements) {
      switch (el.name.local) {
        case 'sheetPr':
          final tab =
              el.childElements.where((e) => e.name.local == 'tabColor').firstOrNull;
          if (tab != null) layout.tabColorArgb = _readColor(tab, styles.theme);
        case 'sheetFormatPr':
          layout.defaultColWidthChars =
              double.tryParse(el.getAttribute('defaultColWidth') ?? '') ??
                  layout.defaultColWidthChars;
          layout.defaultRowHeightPt =
              double.tryParse(el.getAttribute('defaultRowHeight') ?? '') ??
                  layout.defaultRowHeightPt;
        case 'sheetViews':
          _readSheetView(el, layout);
        case 'cols':
          _readCols(el, layout);
        case 'sheetData':
          _readSheetData(el, layout, shared, styles);
        case 'mergeCells':
          for (final mc in el.childElements) {
            final ref = mc.getAttribute('ref');
            final range = XlsxRange.parse(ref);
            if (range != null) layout.merges.add(range);
          }
        case 'conditionalFormatting':
          _readCondFormat(el, layout, styles.theme);
        case 'hyperlinks':
          for (final h in el.childElements) {
            final ref = h.getAttribute('ref');
            final rc = XlsxRange.cellRef(ref?.split(':').first);
            if (rc != null) {
              layout.hyperlinks[cellKey(rc.$1, rc.$2)] =
                  h.getAttribute('display') ?? h.getAttribute('location') ?? '';
            }
          }
        case 'dataValidations':
          for (final dv in el.childElements) {
            final v = _readValidation(dv);
            if (v != null) layout.validations.add(v);
          }
        case 'autoFilter':
          layout.autoFilterRef = el.getAttribute('ref');
      }
    }
    return layout;
  }

  static void _readSheetView(XmlElement el, XlsxSheetLayout layout) {
    final view = el.childElements
        .where((e) => e.name.local == 'sheetView')
        .firstOrNull;
    if (view == null) return;
    final grid = view.getAttribute('showGridLines');
    layout.showGridLines = !(grid == '0' || grid == 'false');
    final zoom = int.tryParse(view.getAttribute('zoomScale') ?? '');
    if (zoom != null && zoom > 0) layout.zoomScale = zoom / 100.0;
    final rtl = view.getAttribute('rightToLeft');
    layout.rightToLeft = rtl == '1' || rtl == 'true';
    final pane =
        view.childElements.where((e) => e.name.local == 'pane').firstOrNull;
    if (pane == null) return;
    final state = pane.getAttribute('state');
    if (state != 'frozen' && state != 'frozenSplit') return;
    layout.frozenCols =
        (double.tryParse(pane.getAttribute('xSplit') ?? '') ?? 0).round();
    layout.frozenRows =
        (double.tryParse(pane.getAttribute('ySplit') ?? '') ?? 0).round();
  }

  static void _readCols(XmlElement el, XlsxSheetLayout layout) {
    for (final col in el.childElements) {
      if (col.name.local != 'col') continue;
      final min = int.tryParse(col.getAttribute('min') ?? '') ?? 1;
      final max = int.tryParse(col.getAttribute('max') ?? '') ?? min;
      final width = double.tryParse(col.getAttribute('width') ?? '');
      final hidden = col.getAttribute('hidden') == '1' ||
          col.getAttribute('hidden') == 'true';
      final styleIdx = int.tryParse(col.getAttribute('style') ?? '');
      final upper = max.clamp(1, maxColumns);
      for (var c = min; c <= upper; c++) {
        if (width != null) layout.colWidths[c - 1] = width;
        if (hidden) layout.hiddenCols.add(c - 1);
        if (styleIdx != null) layout.colStyles[c - 1] = styleIdx;
      }
    }
  }

  static void _readSheetData(XmlElement el, XlsxSheetLayout layout,
      List<XlsxSharedString> shared, XlsxStyles styles) {
    // Paylaşılan formüller (`<f t="shared" si="0" ref="B2:B9">…`): Excel
    // aşağı doğru kopyalanan formülü YALNIZ İLK hücreye yazar, kalanlarda
    // sadece `si` vardır. Bunları çözmezsek o hücrelerde formül yok sayılır
    // (formül çubuğu boş, düzenleme sonrası yeniden hesap yapılmaz).
    final sharedFormulas = <String, _SharedFormula>{};
    for (final row in el.childElements) {
      if (row.name.local != 'row') continue;
      final rIdx = (int.tryParse(row.getAttribute('r') ?? '') ?? 0) - 1;
      if (rIdx < 0 || rIdx >= maxRows) continue;
      final ht = double.tryParse(row.getAttribute('ht') ?? '');
      if (ht != null) layout.rowHeights[rIdx] = ht;
      if (row.getAttribute('hidden') == '1' ||
          row.getAttribute('hidden') == 'true') {
        layout.hiddenRows.add(rIdx);
      }
      final rowStyle = int.tryParse(row.getAttribute('s') ?? '');
      if (rowStyle != null &&
          (row.getAttribute('customFormat') == '1' ||
              row.getAttribute('customFormat') == 'true')) {
        layout.rowStyles[rIdx] = rowStyle;
      }
      if (rIdx > layout.maxRow) layout.maxRow = rIdx;

      for (final c in row.childElements) {
        if (c.name.local != 'c') continue;
        final ref = c.getAttribute('r');
        var col = -1;
        var rr = rIdx;
        if (ref != null) {
          final parsed = XlsxRange.cellRef(ref);
          if (parsed != null) {
            rr = parsed.$1;
            col = parsed.$2;
          }
        }
        if (col < 0 || col >= maxColumns) continue;
        final cell = _readCell(c, rr, col, shared, sharedFormulas);
        if (cell == null) continue;
        layout.cells[cellKey(rr, col)] = cell;
        if (col > layout.maxCol) layout.maxCol = col;
        if (rr > layout.maxRow) layout.maxRow = rr;
      }
    }
  }

  static XlsxCell? _readCell(XmlElement c, int row, int col,
      List<XlsxSharedString> shared,
      [Map<String, _SharedFormula>? sharedFormulas]) {
    final styleIndex = int.tryParse(c.getAttribute('s') ?? '') ?? 0;
    final type = c.getAttribute('t') ?? 'n';
    String? formula;
    String? vText;
    String? inlineText;
    List<XlsxRichRun>? runs;

    for (final child in c.childElements) {
      switch (child.name.local) {
        case 'f':
          formula = child.innerText;
          final si = child.getAttribute('si');
          if (si != null && sharedFormulas != null) {
            if (formula.isNotEmpty) {
              // Paylaşılan formülün ANA hücresi.
              sharedFormulas[si] = _SharedFormula(formula, row, col);
            } else {
              // Takipçi hücre: ana formül göreli başvurular kaydırılarak
              // kopyalanır (Excel'in dosyada yapmadığı işi biz yapıyoruz).
              final master = sharedFormulas[si];
              if (master != null) {
                formula = shiftFormulaRefs(
                    master.formula, row - master.row, col - master.col);
              }
            }
          }
        case 'v':
          vText = child.innerText;
        case 'is':
          final sb = StringBuffer();
          for (final e in child.descendantElements) {
            if (e.name.local == 't') sb.write(e.innerText);
          }
          inlineText = sb.toString();
      }
    }

    if (formula == null &&
        vText == null &&
        inlineText == null &&
        styleIndex == 0) {
      return null; // tamamen boş hücre — modele girmesin
    }

    double? number;
    String? text;
    bool? boolean;
    String? error;

    switch (type) {
      case 's':
        final i = int.tryParse(vText ?? '');
        if (i != null && i >= 0 && i < shared.length) {
          text = shared[i].text;
          runs = shared[i].runs;
        } else {
          text = '';
        }
      case 'inlineStr':
        text = inlineText ?? '';
      case 'str':
        text = vText ?? '';
      case 'b':
        boolean = vText == '1' || vText == 'true';
      case 'e':
        error = vText ?? '#HATA!';
      case 'd':
        text = vText ?? '';
      default:
        number = double.tryParse(vText ?? '');
        if (number == null && vText != null && vText.isNotEmpty) {
          text = vText;
        }
    }

    return XlsxCell(
      row: row,
      col: col,
      styleIndex: styleIndex,
      number: number,
      text: text,
      boolean: boolean,
      error: error,
      formula: formula,
      runs: runs,
    );
  }

  /// Bir formüldeki **göreli** hücre başvurularını [dr] satır / [dc] sütun
  /// kaydırır (`$` ile sabitlenmişler oynamaz). Paylaşılan formülleri
  /// (`t="shared"`) açmak için gerekir; Excel'in "aşağı çekince kayan
  /// başvuru" davranışının aynısı.
  ///
  /// Dize sabitleri (`"A1"`), tırnaklı sayfa adları (`'Bir Ad'!`), fonksiyon
  /// adları (`LOG10(`) ve sayılar (`2e5`) kaydırılmaz.
  static String shiftFormulaRefs(String src, int dr, int dc) {
    if (dr == 0 && dc == 0) return src;
    final out = StringBuffer();
    var i = 0;
    while (i < src.length) {
      final ch = src[i];
      // Dize sabiti
      if (ch == '"') {
        final start = i++;
        while (i < src.length) {
          if (src[i] == '"') {
            if (i + 1 < src.length && src[i + 1] == '"') {
              i += 2;
              continue;
            }
            i++;
            break;
          }
          i++;
        }
        out.write(src.substring(start, i));
        continue;
      }
      // Tırnaklı sayfa adı
      if (ch == "'") {
        final start = i++;
        while (i < src.length && src[i] != "'") {
          i++;
        }
        if (i < src.length) i++;
        out.write(src.substring(start, i));
        continue;
      }
      // Sayı (2e5 içindeki "e5" başvuru sanılmasın)
      if (_isDigitChar(ch)) {
        final start = i;
        while (i < src.length && (_isDigitChar(src[i]) || src[i] == '.')) {
          i++;
        }
        if (i < src.length && (src[i] == 'e' || src[i] == 'E')) {
          final save = i;
          i++;
          if (i < src.length && (src[i] == '+' || src[i] == '-')) i++;
          if (i < src.length && _isDigitChar(src[i])) {
            while (i < src.length && _isDigitChar(src[i])) {
              i++;
            }
          } else {
            i = save;
          }
        }
        out.write(src.substring(start, i));
        continue;
      }
      // Ad / başvuru
      if (_isLetterChar(ch) || ch == r'$' || ch == '_') {
        final start = i;
        while (i < src.length &&
            (_isLetterChar(src[i]) ||
                _isDigitChar(src[i]) ||
                src[i] == r'$' ||
                src[i] == '_' ||
                src[i] == '.')) {
          i++;
        }
        final token = src.substring(start, i);
        final isCall = i < src.length && src[i] == '(';
        out.write(isCall ? token : _shiftRef(token, dr, dc));
        continue;
      }
      out.write(ch);
      i++;
    }
    return out.toString();
  }

  /// "A1"/"$B\$2" başvurusunu kaydırır; başvuru değilse olduğu gibi döner.
  static String _shiftRef(String token, int dr, int dc) {
    final m = RegExp(r'^(\$?)([A-Za-z]{1,3})(\$?)(\d{1,7})$').firstMatch(token);
    if (m == null) return token;
    final colAbs = m.group(1) == r'$';
    final rowAbs = m.group(3) == r'$';
    var col = 0;
    for (final u in m.group(2)!.toUpperCase().codeUnits) {
      if (u < 65 || u > 90) return token;
      col = col * 26 + (u - 64);
    }
    var rowNum = int.parse(m.group(4)!);
    if (!colAbs) col += dc;
    if (!rowAbs) rowNum += dr;
    if (col < 1 || rowNum < 1) return '#REF!';
    return '${colAbs ? '\$' : ''}${XlsxRange.colName(col - 1)}'
        '${rowAbs ? '\$' : ''}$rowNum';
  }

  static bool _isDigitChar(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  static bool _isLetterChar(String c) {
    final u = c.codeUnitAt(0);
    if ((u >= 65 && u <= 90) || (u >= 97 && u <= 122)) return true;
    return u > 127; // Türkçe harfli tanımlı adlar
  }

  static void _readCondFormat(
      XmlElement el, XlsxSheetLayout layout, List<int> theme) {
    final sqref = el.getAttribute('sqref') ?? '';
    final ranges = <XlsxRange>[];
    for (final part in sqref.split(RegExp(r'\s+'))) {
      final r = XlsxRange.parse(part);
      if (r != null) ranges.add(r);
    }
    if (ranges.isEmpty) return;
    for (final rule in el.childElements) {
      if (rule.name.local != 'cfRule') continue;
      final type = rule.getAttribute('type') ?? '';
      final formulas = rule.childElements
          .where((e) => e.name.local == 'formula')
          .map((e) => e.innerText)
          .toList();
      final dxfId = int.tryParse(rule.getAttribute('dxfId') ?? '');
      List<int>? scaleColors;
      List<double>? scaleValues;
      int? barColor;
      final cs =
          rule.childElements.where((e) => e.name.local == 'colorScale').firstOrNull;
      if (cs != null) {
        scaleColors = [
          for (final c in cs.childElements.where((e) => e.name.local == 'color'))
            _readColor(c, theme) ?? 0xFFFFFFFF,
        ];
        scaleValues = [
          for (final v in cs.childElements.where((e) => e.name.local == 'cfvo'))
            double.tryParse(v.getAttribute('val') ?? '') ?? double.nan,
        ];
      }
      final db =
          rule.childElements.where((e) => e.name.local == 'dataBar').firstOrNull;
      if (db != null) {
        final c =
            db.childElements.where((e) => e.name.local == 'color').firstOrNull;
        barColor =
            c == null ? 0xFF638EC6 : (_readColor(c, theme) ?? 0xFF638EC6);
      }
      layout.condFormats.add(XlsxCondRule(
        ranges: ranges,
        type: type,
        operator: rule.getAttribute('operator'),
        text: rule.getAttribute('text'),
        formulas: formulas,
        priority: int.tryParse(rule.getAttribute('priority') ?? '') ?? 0,
        dxfId: dxfId,
        scaleColors: scaleColors,
        scaleValues: scaleValues,
        barColorArgb: barColor,
      ));
    }
  }

  static XlsxDataValidation? _readValidation(XmlElement dv) {
    final type = dv.getAttribute('type');
    if (type == null) return null;
    final sqref = dv.getAttribute('sqref') ?? '';
    final ranges = <XlsxRange>[];
    for (final part in sqref.split(RegExp(r'\s+'))) {
      final r = XlsxRange.parse(part);
      if (r != null) ranges.add(r);
    }
    if (ranges.isEmpty) return null;
    final f1 = dv.childElements
        .where((e) => e.name.local == 'formula1')
        .map((e) => e.innerText)
        .firstOrNull;
    List<String>? options;
    if (type == 'list' && f1 != null) {
      final trimmed = f1.trim();
      if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
        options = trimmed
            .substring(1, trimmed.length - 1)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return XlsxDataValidation(
      type: type,
      ranges: ranges,
      formula1: f1,
      options: options,
      promptTitle: dv.getAttribute('promptTitle'),
      prompt: dv.getAttribute('prompt'),
    );
  }

  /// Excel'in klasik 56 renkli indeksli paleti (indexed="n").
  static const List<int> _indexedPalette = [
    0xFF000000, 0xFFFFFFFF, 0xFFFF0000, 0xFF00FF00, 0xFF0000FF, 0xFFFFFF00,
    0xFFFF00FF, 0xFF00FFFF, 0xFF000000, 0xFFFFFFFF, 0xFFFF0000, 0xFF00FF00,
    0xFF0000FF, 0xFFFFFF00, 0xFFFF00FF, 0xFF00FFFF, 0xFF800000, 0xFF008000,
    0xFF000080, 0xFF808000, 0xFF800080, 0xFF008080, 0xFFC0C0C0, 0xFF808080,
    0xFF9999FF, 0xFF993366, 0xFFFFFFCC, 0xFFCCFFFF, 0xFF660066, 0xFFFF8080,
    0xFF0066CC, 0xFFCCCCFF, 0xFF000080, 0xFFFF00FF, 0xFFFFFF00, 0xFF00FFFF,
    0xFF800080, 0xFF800000, 0xFF008080, 0xFF0000FF, 0xFF00CCFF, 0xFFCCFFFF,
    0xFFCCFFCC, 0xFFFFFF99, 0xFF99CCFF, 0xFFFF99CC, 0xFFCC99FF, 0xFFFFCC99,
    0xFF3366FF, 0xFF33CCCC, 0xFF99CC00, 0xFFFFCC00, 0xFFFF9900, 0xFFFF6600,
    0xFF666699, 0xFF969696, 0xFF003366, 0xFF339966, 0xFF003300, 0xFF333300,
    0xFF993300, 0xFF993366, 0xFF333399, 0xFF333333,
  ];
}

/// Hücre anahtarı (satır, sütun) → tek int. 16384 = Excel'in sütun sınırı.
int cellKey(int r, int c) => r * 16384 + c;

// ───────────────────────────────────────────────────────────────── modeller

/// Paylaşılan formülün ana hücresi (`<f t="shared" si="…" ref="…">`).
class _SharedFormula {
  final String formula;
  final int row, col;
  const _SharedFormula(this.formula, this.row, this.col);
}

class XlsxWorkbook {
  final List<XlsxSheetLayout> sheets;
  final XlsxStyles styles;
  final List<int> theme;
  final bool date1904;

  XlsxWorkbook({
    required this.sheets,
    required this.styles,
    required this.theme,
    required this.date1904,
  });
}

class XlsxStyles {
  final Map<int, String> numFmts;
  final List<XlsxFormat> formats;
  final List<XlsxDxf> dxfs;
  final List<int> theme;

  XlsxStyles({
    required this.numFmts,
    required this.formats,
    required this.dxfs,
    required this.theme,
  });

  XlsxFormat formatAt(int index) =>
      (index >= 0 && index < formats.length) ? formats[index] : formats.first;
}

class XlsxSharedString {
  final String text;
  final List<XlsxRichRun>? runs;
  const XlsxSharedString(this.text, this.runs);
}

class XlsxRichRun {
  final String text;
  final bool bold, italic, underline, strike;
  const XlsxRichRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });
}

class XlsxFont {
  final String? name;
  final double? size;
  final bool bold, italic, strike;
  final String? underline;
  final int? colorArgb;
  const XlsxFont({
    this.name,
    this.size,
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.underline,
    this.colorArgb,
  });
}

class XlsxFill {
  final String pattern;
  final int? fgArgb;
  final int? bgArgb;
  const XlsxFill({required this.pattern, this.fgArgb, this.bgArgb});

  /// Ekranda çizilecek zemin rengi (desen yoğunluğu alfa ile yaklaşıklanır —
  /// Excel'in gray125 gibi desenleri mobilde nokta nokta çizilmez).
  int? get effectiveArgb {
    switch (pattern) {
      case 'none':
        return null;
      case 'solid':
        return fgArgb ?? bgArgb;
      case 'gray125':
      case 'lightGray':
      case 'lightUp':
      case 'lightDown':
      case 'lightGrid':
      case 'lightTrellis':
      case 'lightHorizontal':
      case 'lightVertical':
        return _blend(fgArgb ?? 0xFF808080, bgArgb ?? 0xFFFFFFFF, 0.25);
      case 'mediumGray':
      case 'gray0625':
        return _blend(fgArgb ?? 0xFF808080, bgArgb ?? 0xFFFFFFFF, 0.5);
      case 'darkGray':
      case 'darkGrid':
      case 'darkTrellis':
      case 'darkHorizontal':
      case 'darkVertical':
      case 'darkUp':
      case 'darkDown':
        return _blend(fgArgb ?? 0xFF808080, bgArgb ?? 0xFFFFFFFF, 0.75);
      default:
        return fgArgb ?? bgArgb;
    }
  }

  static int _blend(int fg, int bg, double t) {
    int ch(int shift) {
      final a = (fg >> shift) & 0xFF;
      final b = (bg >> shift) & 0xFF;
      return (b + (a - b) * t).round().clamp(0, 255);
    }

    return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }
}

class XlsxBorderSide {
  final String style;
  final int? colorArgb;
  const XlsxBorderSide(this.style, this.colorArgb);

  bool get visible => style != 'none' && style.isNotEmpty;

  /// Excel çizgi kalınlıklarının piksel karşılığı.
  double get width => switch (style) {
        'hair' => 0.5,
        'thin' || 'dashed' || 'dotted' || 'dashDot' || 'dashDotDot' => 1,
        'medium' ||
        'mediumDashed' ||
        'mediumDashDot' ||
        'mediumDashDotDot' ||
        'slantDashDot' =>
          2,
        'thick' => 3,
        'double' => 2.5,
        _ => 0,
      };
}

class XlsxBorder {
  final XlsxBorderSide left, right, top, bottom;
  const XlsxBorder({
    this.left = const XlsxBorderSide('none', null),
    this.right = const XlsxBorderSide('none', null),
    this.top = const XlsxBorderSide('none', null),
    this.bottom = const XlsxBorderSide('none', null),
  });

  bool get any => left.visible || right.visible || top.visible || bottom.visible;
}

enum XlsxHAlign { general, left, center, right, justify }

enum XlsxVAlign { top, center, bottom }

class XlsxAlign {
  final XlsxHAlign horizontal;
  final XlsxVAlign vertical;
  final bool wrapText;
  final int indent;
  final int textRotation;
  final bool shrinkToFit;
  const XlsxAlign({
    this.horizontal = XlsxHAlign.general,
    this.vertical = XlsxVAlign.bottom,
    this.wrapText = false,
    this.indent = 0,
    this.textRotation = 0,
    this.shrinkToFit = false,
  });
}

class XlsxFormat {
  final int numFmtId;
  final String numFmtCode;
  final XlsxFont font;
  final XlsxFill fill;
  final XlsxBorder border;
  final XlsxAlign align;
  final bool quotePrefix;

  const XlsxFormat({
    required this.numFmtId,
    required this.numFmtCode,
    required this.font,
    required this.fill,
    required this.border,
    required this.align,
    this.quotePrefix = false,
  });

  factory XlsxFormat.fallback() => const XlsxFormat(
        numFmtId: 0,
        numFmtCode: 'General',
        font: XlsxFont(),
        fill: XlsxFill(pattern: 'none'),
        border: XlsxBorder(),
        align: XlsxAlign(),
      );
}

class XlsxDxf {
  final XlsxFont? font;
  final XlsxFill? fill;
  const XlsxDxf({this.font, this.fill});
}

class XlsxCell {
  final int row, col;
  final int styleIndex;
  final double? number;
  final String? text;
  final bool? boolean;
  final String? error;
  final String? formula;
  final List<XlsxRichRun>? runs;

  const XlsxCell({
    required this.row,
    required this.col,
    required this.styleIndex,
    this.number,
    this.text,
    this.boolean,
    this.error,
    this.formula,
    this.runs,
  });

  bool get isEmpty =>
      number == null &&
      (text == null || text!.isEmpty) &&
      boolean == null &&
      error == null &&
      formula == null;

  bool get isNumeric => number != null;
}

/// A1:B3 gibi bir aralık (0 tabanlı, uçlar dahil).
class XlsxRange {
  final int r1, c1, r2, c2;
  const XlsxRange(this.r1, this.c1, this.r2, this.c2);

  bool contains(int r, int c) => r >= r1 && r <= r2 && c >= c1 && c <= c2;
  bool isAnchor(int r, int c) => r == r1 && c == c1;
  int get rowCount => r2 - r1 + 1;
  int get colCount => c2 - c1 + 1;

  static XlsxRange? parse(String? ref) {
    if (ref == null || ref.isEmpty) return null;
    final parts = ref.split(':');
    final a = cellRef(parts.first);
    if (a == null) return null;
    final b = parts.length > 1 ? cellRef(parts[1]) : a;
    if (b == null) return null;
    return XlsxRange(
      a.$1 < b.$1 ? a.$1 : b.$1,
      a.$2 < b.$2 ? a.$2 : b.$2,
      a.$1 > b.$1 ? a.$1 : b.$1,
      a.$2 > b.$2 ? a.$2 : b.$2,
    );
  }

  /// "B3" → (satır 2, sütun 1). `$` işaretleri yok sayılır.
  static (int, int)? cellRef(String? ref) {
    if (ref == null) return null;
    final m = RegExp(r'^\$?([A-Za-z]+)\$?(\d+)$').firstMatch(ref.trim());
    if (m == null) return null;
    var col = 0;
    for (final u in m.group(1)!.toUpperCase().codeUnits) {
      col = col * 26 + (u - 64);
    }
    final row = int.tryParse(m.group(2)!);
    if (row == null || row < 1) return null;
    return (row - 1, col - 1);
  }

  /// 0 → "A", 27 → "AB"
  static String colName(int index) {
    var n = index;
    final buf = <int>[];
    do {
      buf.add(65 + (n % 26));
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return String.fromCharCodes(buf.reversed);
  }
}

class XlsxCondRule {
  final List<XlsxRange> ranges;
  final String type;
  final String? operator;
  final String? text;
  final List<String> formulas;
  final int priority;
  final int? dxfId;
  final List<int>? scaleColors;
  final List<double>? scaleValues;
  final int? barColorArgb;

  const XlsxCondRule({
    required this.ranges,
    required this.type,
    required this.formulas,
    required this.priority,
    this.operator,
    this.text,
    this.dxfId,
    this.scaleColors,
    this.scaleValues,
    this.barColorArgb,
  });

  bool covers(int r, int c) => ranges.any((x) => x.contains(r, c));
}

class XlsxDataValidation {
  final String type;
  final List<XlsxRange> ranges;
  final String? formula1;
  final List<String>? options;
  final String? promptTitle;
  final String? prompt;

  const XlsxDataValidation({
    required this.type,
    required this.ranges,
    this.formula1,
    this.options,
    this.promptTitle,
    this.prompt,
  });

  bool covers(int r, int c) => ranges.any((x) => x.contains(r, c));
}

class XlsxSheetLayout {
  /// Sayfa adı — yeniden adlandırmada modelle birlikte güncellenir.
  String name;
  bool hidden = false;
  int? tabColorArgb;

  /// Excel varsayılanları: sütun 8.43 karakter, satır 15 punto.
  double defaultColWidthChars = 8.43;
  double defaultRowHeightPt = 15;

  final Map<int, double> colWidths = {};
  final Map<int, double> rowHeights = {};
  final Map<int, int> colStyles = {};
  final Map<int, int> rowStyles = {};
  final Set<int> hiddenCols = {};
  final Set<int> hiddenRows = {};
  final List<XlsxRange> merges = [];
  final Map<int, XlsxCell> cells = {};
  final List<XlsxCondRule> condFormats = [];
  final Map<int, String> hyperlinks = {};
  final List<XlsxDataValidation> validations = [];

  int frozenRows = 0;
  int frozenCols = 0;
  bool showGridLines = true;
  bool rightToLeft = false;
  double zoomScale = 1;
  String? autoFilterRef;
  int maxRow = -1;
  int maxCol = -1;

  XlsxSheetLayout({required this.name});

  int get rowCount => maxRow + 1;
  int get colCount => maxCol + 1;

  XlsxCell? cellAt(int r, int c) => cells[cellKey(r, c)];

  /// Sütun genişliği — karakter biriminde (Excel'in kendi birimi).
  double colWidthChars(int c) =>
      colWidths[c] ?? (defaultColWidthChars <= 0 ? 8.43 : defaultColWidthChars);

  /// Satır yüksekliği — punto.
  double rowHeightPt(int r) =>
      rowHeights[r] ?? (defaultRowHeightPt <= 0 ? 15 : defaultRowHeightPt);

  XlsxRange? mergeAt(int r, int c) {
    for (final m in merges) {
      if (m.contains(r, c)) return m;
    }
    return null;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
