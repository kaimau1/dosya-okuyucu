part of '../xlsx_editor.dart';

/// Faz 27 (kalan) — veri doğrulama oluşturma, sekme rengi / gizleme /
/// çoğaltma, hücre notları, süzgeç oluşturma. Hepsi modele uygulanır ve
/// kaydette yamalarla dosyaya yazılır; ekran her birini tek geri al adımı
/// olarak kaydeder (ters işlemler de burada).
extension XlsxSheetOps on XlsxEditor {
  // ── veri doğrulama ──────────────────────────────────────────────────────

  /// [range]'e kural ekler (önce o aralıktaki eski kuralları temizler).
  void addValidation(String sheetName, XlsxRange range, XlsxDataValidation v) {
    final s = _modelSheet(sheetName);
    if (s == null) return;
    clearValidations(sheetName, range);
    s.layout.validations.add(v);
    s.validationWrites.add(XlsxValidationWrite.from(v));
  }

  /// [range]'e değen kuralları kaldırır (bütün olarak — Excel de "tümünü
  /// temizle"de kuralın aralığını böler; biz sadeleştirip kaldırıyoruz).
  /// Kaldırılanlar döner (geri al için).
  List<XlsxDataValidation> clearValidations(String sheetName, XlsxRange range) {
    final s = _modelSheet(sheetName);
    if (s == null) return const [];
    bool hits(XlsxDataValidation v) => v.ranges.any((x) =>
        x.r1 <= range.r2 && x.r2 >= range.r1 && x.c1 <= range.c2 && x.c2 >= range.c1);
    final gone = [for (final v in s.layout.validations) if (hits(v)) v];
    if (gone.isEmpty) return gone;
    s.layout.validations.removeWhere(hits);
    // Bu oturumda eklenmiş olanlar yazım listesinden de çıkar; dosyadan
    // gelenler için temizleme izi bırakılır.
    final fresh = {for (final v in gone) XlsxValidationWrite.sqrefOf(v.ranges)};
    s.validationWrites.removeWhere((w) => fresh.contains(w.sqref));
    s.validationClears.add(range.ref);
    return gone;
  }

  /// Geri al: kaldırılan kuralları geri koyar.
  void restoreValidations(String sheetName, XlsxRange range,
      List<XlsxDataValidation> previous) {
    final s = _modelSheet(sheetName);
    if (s == null) return;
    clearValidations(sheetName, range);
    for (final v in previous) {
      s.layout.validations.add(v);
      s.validationWrites.add(XlsxValidationWrite.from(v));
    }
  }

  // ── süzgeç ──────────────────────────────────────────────────────────────

  /// Otomatik süzgeç aralığını kurar (null = kaldır). Kaldırınca süzgecin
  /// gizlediği satırlar geri gelir. Önceki aralık döner.
  String? setAutoFilter(String sheetName, String? ref) {
    final s = _modelSheet(sheetName);
    if (s == null) return null;
    final before = s.layout.autoFilterRef;
    s.layout.autoFilterRef = ref;
    s.autoFilterEdited = true;
    if (ref == null) {
      for (final rows in s.filterHidden.values) {
        s.layout.hiddenRows.removeAll(rows);
      }
      s.filterHidden.clear();
    }
    return before;
  }

  // ── sekmeler ────────────────────────────────────────────────────────────

  void setTabColor(String sheetName, int? argb) {
    final s = _modelSheet(sheetName);
    if (s == null) return;
    s.layout.tabColorArgb = argb;
    s.tabColorEdited = true;
  }

  /// Sayfayı gizler/gösterir. Görünür son sayfa gizlenemez.
  bool setSheetHidden(String sheetName, bool hidden) {
    final s = _modelSheet(sheetName);
    if (s == null) return false;
    if (hidden && sheets.where((x) => !x.layout.hidden).length <= 1) {
      return false;
    }
    s.layout.hidden = hidden;
    return true;
  }

  /// Sayfayı çoğaltır: değerler, hücre kayıtları (biçim indeksleriyle),
  /// ölçüler, gizli satır/sütunlar, birleştirmeler, bölme, yön ve bu oturumun
  /// biçim düzenlemeleri kopyalanır. Dosyadaki koşullu biçim/doğrulama/çizim
  /// özgün sayfanın XML'inde kalır (kopyaya taşınmaz). Kopya kaynağın hemen
  /// ardına gelir; adı "Ad (2)".
  XlsxSheet? duplicateSheet(String sheetName) {
    final src = _modelSheet(sheetName);
    if (src == null) return null;
    var n = 2;
    String name() => '${src.name} ($n)';
    while (hasSheet(name())) {
      n++;
    }
    final l = src.layout;
    final copy = XlsxSheetLayout(name: name())
      ..tabColorArgb = l.tabColorArgb
      ..defaultColWidthChars = l.defaultColWidthChars
      ..defaultRowHeightPt = l.defaultRowHeightPt
      ..frozenRows = l.frozenRows
      ..frozenCols = l.frozenCols
      ..freezeEdited = l.frozenRows > 0 || l.frozenCols > 0
      ..showGridLines = l.showGridLines
      ..rightToLeft = l.rightToLeft
      ..zoomScale = l.zoomScale
      ..maxRow = l.maxRow
      ..maxCol = l.maxCol;
    copy.colWidths.addAll(l.colWidths);
    copy.rowHeights.addAll(l.rowHeights);
    copy.colStyles.addAll(l.colStyles);
    copy.rowStyles.addAll(l.rowStyles);
    copy.hiddenCols.addAll(l.hiddenCols);
    copy.hiddenRows.addAll(l.hiddenRows);
    copy.merges.addAll(l.merges);
    copy.cells.addAll(l.cells);
    copy.hyperlinks.addAll(l.hyperlinks);
    copy.comments.addAll(l.comments);
    copy.validations.addAll(l.validations);
    final sheet = XlsxSheet(
      name: copy.name,
      rows: [for (final r in src.rows) List<String>.of(r)],
      layout: copy,
      styles: src.styles,
      date1904: src.date1904,
    );
    for (final m in src.merges) {
      if (!sheet.merges.any((x) =>
          x.rowStart == m.rowStart && x.colStart == m.colStart)) {
        sheet.merges.add(m);
      }
    }
    for (var r = 0; r < src.maxRows; r++) {
      for (var c = 0; c < src.maxCols; c++) {
        final ov = src.overrideAt(r, c);
        if (ov != null) sheet.patchStyle(r, c, ov);
      }
    }
    sheet.styleEdits.addAll(src.styleEdits);
    sheet.numberFormatEdits.addAll(src.numberFormatEdits);
    sheet.styleCopies.addAll(src.styleCopies);
    if (src.layout.tabColorArgb != null) sheet.tabColorEdited = true;
    for (final v in l.validations) {
      sheet.validationWrites.add(XlsxValidationWrite.from(v));
    }
    // Notlar kopyaya da yazılır.
    for (final e in l.comments.entries) {
      final (r, c) = (e.key ~/ kCellKeyStride, e.key % kCellKeyStride);
      sheet.noteEdits[(r, c)] = e.value.text;
      sheet.noteAuthor = e.value.author;
    }
    sheets.insert(sheets.indexOf(src) + 1, sheet);
    calcLog.bulk();
    return sheet;
  }

  // ── notlar ──────────────────────────────────────────────────────────────

  XlsxComment? noteAt(String sheetName, int r, int c) =>
      _modelSheet(sheetName)?.layout.comments[cellKey(r, c)];

  /// Hücre notu yazar (boş/null = siler). Önceki not döner (geri al için).
  XlsxComment? setNote(String sheetName, int r, int c, String? text,
      {String author = ''}) {
    final s = _modelSheet(sheetName);
    if (s == null || r < 0 || c < 0) return null;
    final key = cellKey(r, c);
    final before = s.layout.comments[key];
    final t = text?.trim() ?? '';
    if (t.isEmpty) {
      s.layout.comments.remove(key);
      s.noteEdits[(r, c)] = null;
    } else {
      s.layout.comments[key] = XlsxComment(author: author, text: t);
      s.noteEdits[(r, c)] = t;
      if (author.isNotEmpty) s.noteAuthor = author;
    }
    return before;
  }
}

