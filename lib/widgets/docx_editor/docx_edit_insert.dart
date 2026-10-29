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

  // ── resim ───────────────────────────────────────────────────────────────

  /// Seçim tam olarak tek bir resim mi (resim tutamakları + Resim sekmesi).
  DocxAtom? get selectedImage {
    final s = start, e = end;
    if (s.para != e.para || e.offset != s.offset + 1) return null;
    final p = paras[s.para];
    if (p.opaque || s.offset >= p.length) return null;
    final a = p.atoms[s.offset];
    return a?.kind == DocxAtomKind.image ? a : null;
  }

  /// [i]. paragrafın [k]. karakterindeki atomu seçer (resme dokunuş).
  void selectAtom(int i, int k) {
    if (i >= paras.length || paras[i].opaque) return;
    composing = TextRange.empty;
    select(DocPos(i, k), DocPos(i, k + 1));
  }

  /// İmlece resim koyar; resim seçili kalır (tutamaklar görünsün).
  void insertImage(Uint8List bytes, String ext,
      {required int pixelWidth, required int pixelHeight}) {
    if (!collapsed) deleteSelection(notify: false);
    final i = extent.para;
    final p = paras[i];
    if (p.opaque) return;
    _record(typing: false);
    final atom = doc.newImageAtom(bytes, ext,
        pixelWidth: pixelWidth, pixelHeight: pixelHeight);
    final at = extent.offset;
    doc.paras[i] = doc.insertAtom(p, at, atom, _typingStyle(i, at));
    base = DocPos(i, at);
    extent = DocPos(i, at + 1);
    _afterInsert();
  }

  void _swapImage(DocxAtom Function(DocxAtom a) change) {
    final a = selectedImage;
    if (a == null) return;
    final s = start;
    _record(typing: false);
    final p = paras[s.para];
    final at = [...p.atoms]..[s.offset] = change(a);
    doc.paras[s.para] = p.copyWith(atoms: at);
    _changed(notify: true);
  }

  /// Oran kilitli boyutlandırma (punto).
  void resizeImage(double widthPt) =>
      _swapImage((a) => doc.resizedImage(a, widthPt));

  String get imageAlt {
    final a = selectedImage;
    return a == null ? '' : doc.imageAlt(a);
  }

  void setImageAlt(String alt) =>
      _swapImage((a) => doc.withImageAlt(a, alt.trim()));

  void replaceImage(Uint8List bytes, String ext,
          {required int pixelWidth, required int pixelHeight}) =>
      _swapImage((a) => doc.replacedImage(a, bytes, ext,
          pixelWidth: pixelWidth, pixelHeight: pixelHeight));

  /// Resmin satır hizası = paragraf hizası.
  void alignImage(String align) {
    if (selectedImage == null) return;
    final i = start.para;
    _record(typing: false);
    doc.paras[i] = doc.setAlign(paras[i], align);
    _changed(notify: true);
  }

  // ── yatay çizgi, tarih, dipnot ──────────────────────────────────────────

  /// İmlecin paragrafından sonra yatay çizgi; imleç çizginin ardındaki
  /// paragrafa (yoksa yeni boş paragrafa) geçer.
  void insertHorizontalRule() {
    final i = extent.para;
    final p = paras[i];
    if (p.opaque) return;
    _record(typing: false);
    final rule = doc.horizontalRulePara(p);
    doc.paras.insert(i + 1, rule);
    final next = i + 2;
    if (next >= paras.length ||
        !identical(paras[next].container, p.container) ||
        paras[next].opaque) {
      final (left, right) = p.split(p.length);
      doc.paras[i] = left;
      doc.paras.insert(next, right);
    }
    base = extent = DocPos(next, 0);
    structure++;
    _afterInsert();
  }

  /// İmlece dipnot başvurusu koyar (metni dipnot parçasına yazılır).
  void insertFootnote(String text) {
    if (!collapsed) {
      final e = end;
      base = extent = e;
    }
    final i = extent.para;
    final p = paras[i];
    if (p.opaque) return;
    _record(typing: false);
    doc.paras[i] = doc.insertAtom(
        p, extent.offset, doc.newFootnoteAtom(text), _typingStyle(i, extent.offset));
    base = extent = DocPos(i, extent.offset + 1);
    _afterInsert();
  }

  String? footnoteText(String id) => doc.footnoteText(id);

  /// Dipnot metni (geri alınamaz; parçaya yazılır).
  bool setFootnoteText(String id, String text) {
    final ok = doc.setFootnoteText(id, text);
    if (ok) _changed(notify: true);
    return ok;
  }

  // ── yorumlar ────────────────────────────────────────────────────────────

  List<DocxComment> get comments => doc.comments();

  /// Seçime (yoksa imlecin kelimesine) yorum ekler.
  bool addComment(String text, String author) {
    if (text.trim().isEmpty) return false;
    if (collapsed) selectWord(extent);
    final s = start, e = end;
    final i = s.para;
    final p = paras[i];
    if (p.opaque) return false;
    final to = s.para == e.para ? e.offset : p.length;
    _record(typing: false);
    doc.paras[i] = doc.addComment(p, s.offset, to, text.trim(), author);
    base = extent = DocPos(i, to + 1);
    _afterInsert();
    return true;
  }

  bool replyComment(String parentId, String text, String author) {
    if (text.trim().isEmpty) return false;
    _record(typing: false);
    final r = doc.replyComment(parentId, text.trim(), author);
    if (r == null) return false;
    doc.paras[r.$1] = r.$2;
    _afterInsert();
    return true;
  }

  void setCommentDone(String id, bool done) {
    if (doc.setCommentDone(id, done)) _changed(notify: true);
  }

  void deleteComment(String id) {
    _record(typing: false);
    final changed = doc.deleteComment(id);
    if (changed.isEmpty) return;
    final i = extent.para;
    base = extent = DocPos(i, extent.offset.clamp(0, paras[i].length));
    _afterInsert();
  }

  /// Yorumun bulunduğu paragraf (gezinti için; yoksa -1).
  int commentPara(String id) => paras.indexWhere((p) => p.atoms
      .any((a) => a?.kind == DocxAtomKind.comment && a!.display == id));

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
