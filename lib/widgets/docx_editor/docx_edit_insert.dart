part of 'docx_edit_controller.dart';

/// Faz 24 — Ekle / Düzen / Bul-Değiştir işlemleri. Hepsi tek geri al adımı.
extension DocxEditInsert on DocxEditController {
  // ── Ekle ────────────────────────────────────────────────────────────────

  /// İmlece sayfa sonu koyar.
  void insertPageBreak() {
    if (!collapsed) deleteSelection(notify: false);
    final i = extent.para;
    final p = paras[i];
    if (p.opaque) return;
    _record(typing: false);
    doc.paras[i] = doc.insertAtom(p, extent.offset, doc.newPageBreakAtom(),
        _typingStyle(i, extent.offset));
    base = extent = DocPos(i, extent.offset + 1);
    _afterInsert();
  }

  /// Bağlantı ekler: seçili metin varsa onu etiket yapar.
  void insertLink(String text, String url) {
    final label = text.isEmpty ? url : text;
    if (!collapsed) deleteSelection(notify: false);
    final i = extent.para;
    final p = paras[i];
    if (p.opaque || url.trim().isEmpty) return;
    _record(typing: false);
    doc.paras[i] = doc.insertAtom(p, extent.offset,
        doc.newLinkAtom(label, url.trim()), _typingStyle(i, extent.offset));
    base = extent = DocPos(i, extent.offset + 1);
    _afterInsert();
  }

  /// İmlecin paragrafından sonra [rows]×[cols] tablo ekler; imleç ilk
  /// hücreye gider. Hücre içindeyken tablonun ardına eklenir.
  bool insertTable(int rows, int cols) {
    final i = extent.para;
    _record(typing: false);
    final first = doc.insertTable(i, rows, cols);
    if (first < 0) return false;
    base = extent = DocPos(first, 0);
    structure++;
    _afterInsert();
    return true;
  }

  void _afterInsert() {
    composing = TextRange.empty;
    _pending = null;
    toolbar = false;
    _changed(notify: true);
    _syncIme();
  }

  // ── Düzen ───────────────────────────────────────────────────────────────

  DocxPageSetup get pageSetup => doc.pageSetup();

  void _layout(void Function() edit) {
    _record(typing: false);
    edit();
    _changed(notify: true);
  }

  void setMargins(String preset) => _layout(() => doc.setMarginPreset(preset));
  void setLandscape(bool v) => _layout(() => doc.setLandscape(v));
  void setPaper(String key) => _layout(() => doc.setPaperSize(key));
  void setColumns(int n) => _layout(() => doc.setColumns(n));

  // ── Tablo (bağlamsal sekme) ─────────────────────────────────────────────

  /// İmleç bir tablo hücresinde mi.
  bool get inTable => doc.tableAt(extent.para) != null;

  bool get tableHeader {
    final t = doc.tableAt(extent.para);
    return t != null && doc.tableHeaderRow(t);
  }

  bool get tableBanded {
    final t = doc.tableAt(extent.para);
    return t != null && doc.tableBandedRows(t);
  }

  int? get cellShade => doc.cellShade(extent.para);

  void _tableOp(int Function(int at) op) {
    if (!inTable) return;
    _record(typing: false);
    final i = op(extent.para);
    if (i < 0) return;
    base = extent = DocPos(i.clamp(0, paras.length - 1), 0);
    structure++;
    _afterInsert();
  }

  void tableRow({required bool below}) =>
      _tableOp((i) => doc.insertTableRow(i, below: below));
  void tableColumn({required bool right}) =>
      _tableOp((i) => doc.insertTableColumn(i, right: right));
  void deleteTableRow() => _tableOp(doc.deleteTableRow);
  void deleteTableColumn() => _tableOp(doc.deleteTableColumn);
  void deleteWholeTable() => _tableOp(doc.deleteTable);

  void setTableHeader(bool on) {
    final t = doc.tableAt(extent.para);
    if (t == null) return;
    doc.trackTableLook(t);
    _layout(() => doc.setTableHeaderRow(t, on));
  }

  void setTableBanded(bool on) {
    final t = doc.tableAt(extent.para);
    if (t == null) return;
    doc.trackTableLook(t);
    _layout(() => doc.setTableBandedRows(t, on));
  }

  void setCellShade(int? rgb) {
    if (!inTable) return;
    final at = extent.para;
    doc.trackCellProps(at);
    _layout(() => doc.setCellShade(at, rgb));
  }

  // ── Gözden Geçir ────────────────────────────────────────────────────────

  int get trackedChanges => doc.trackedChangeCount();

  /// İzlenen değişiklikleri çözer. Geri alınamaz: geçmiş sıfırlanır.
  void resolveTracked({required bool accept}) {
    doc.resolveTrackedChanges(accept: accept);
    _history.clear();
    composing = TextRange.empty;
    _pending = null;
    base = extent = DocPos(extent.para.clamp(0, paras.length - 1), 0);
    structure++;
    _changed(notify: true);
    _syncIme();
  }

  // ── Üst / alt bilgi ─────────────────────────────────────────────────────

  DocxHeaderFooter headerFooter({required bool header}) =>
      doc.headerFooter(header: header);

  /// Parçaya yazar (geri alınamaz). Zengin içerikte false.
  bool setHeaderFooter(
      {required bool header, required String text, required bool pageNumber}) {
    final ok = doc.setHeaderFooter(
        header: header, text: text.trim(), pageNumber: pageNumber);
    if (ok) _changed(notify: true);
    return ok;
  }

  // ── Bul / Değiştir ──────────────────────────────────────────────────────

  /// [query]'nin tüm eşleşmeleri (belge sırasıyla), paragraf başına.
  List<(DocPos, DocPos)> findMatches(String query,
      {bool matchCase = false, bool wholeWord = false}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final out = <(DocPos, DocPos)>[];
    for (var i = 0; i < paras.length; i++) {
      final p = paras[i];
      if (p.opaque || p.text.isEmpty) continue;
      for (final h in TextReplace.matches(p.text, q,
          matchCase: matchCase, wholeWord: wholeWord)) {
        out.add((DocPos(i, h), DocPos(i, h + q.length)));
      }
    }
    return out;
  }

  /// Tümünü değiştirir (TEK geri al adımı); değişen sayıyı döndürür.
  int replaceAllMatches(String query, String replacement,
      {bool matchCase = false, bool wholeWord = false}) {
    final q = query.trim();
    if (q.isEmpty) return 0;
    var count = 0;
    var recorded = false;
    for (var i = 0; i < paras.length; i++) {
      var p = paras[i];
      if (p.opaque || p.text.isEmpty) continue;
      final hits = TextReplace.matches(p.text, q,
          matchCase: matchCase, wholeWord: wholeWord);
      if (hits.isEmpty) continue;
      if (!recorded) {
        _record(typing: false);
        recorded = true;
      }
      for (final h in hits.reversed) {
        p = p.replace(h, h + q.length, replacement, p.styles[h].detached());
        count++;
      }
      doc.paras[i] = p;
    }
    if (count > 0) {
      composing = TextRange.empty;
      base = extent = DocPos(extent.para.clamp(0, paras.length - 1), 0);
      _changed(notify: true);
    }
    return count;
  }
}
