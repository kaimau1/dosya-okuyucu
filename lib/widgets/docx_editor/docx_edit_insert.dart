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
