part of '../viewer_screen.dart';

extension _ViewerScreenFindReplacePart on _ViewerScreenState {
  void _toggleFind() {
    _partSetState(() {
      _findOpen = !_findOpen;
      if (!_findOpen) {
        _findCtl.clear();
        _matchStarts = const [];
        _matchEnds = const [];
        _matchPos = -1;
        _pdfSearcher?.resetTextSearch();
        _ocrSearch?.reset();
        _findEntry = null;
      }
    });
    // Arama açıkken okuma kipi çubukları sabit (arama çubuğu kaybolmasın).
    _readingBars.pinned = _findOpen;
  }

  void _runFind(String query) {
    final q = query.trim();
    if (_isPdf) {
      _findEntry = null;
      // pdfrx arayıcısı: sayfa sayfa bulur, vurgular, ilk eşleşmeye kaydırır.
      if (q.isEmpty) {
        _pdfSearcher?.resetTextSearch();
        _ocrSearch?.reset();
      } else {
        // Paketin `caseInsensitive`i yerel-duyarsız (İ/ı kaçıyordu); harf
        // biçimlerini kendimiz kapsayıp eşleştirmeyi duyarlı koşturuyoruz.
        _pdfSearcher?.startTextSearch(turkishSearchPattern(q),
            caseInsensitive: false);
        // Taranmış sayfalar: aynı desen OCR metninde aranır. Kullanıcının
        // baktığı sayfadan başlar — ilk sonuçlar gözün önünden gelir.
        final doc = _pdfDoc;
        if (doc != null) {
          _ocrSearch?.start(doc, turkishSearchPattern(q), fromPage: _pdfPage);
        }
      }
      return;
    }
    final text = _textController?.text ?? '';
    // Türkçe-duyarlı arama (İ/I/ı/i doğru eşlenir); büyük/küçük, tam sözcük
    // ve düzenli ifade seçenekleri (Faz 30).
    List<int> starts;
    List<int> ends = const [];
    var bad = false;
    if (_findRegex) {
      final spans = TextReplace.regexMatches(text, query,
          matchCase: _findCase, wholeWord: _findWord);
      bad = spans == null;
      starts = [for (final s in spans ?? const <(int, int)>[]) s.$1];
      ends = [for (final s in spans ?? const <(int, int)>[]) s.$2];
    } else if (_findCase || _findWord) {
      starts = TextReplace.matches(text, q,
          matchCase: _findCase, wholeWord: _findWord);
    } else {
      starts = findAll(text, q);
    }
    _partSetState(() {
      _matchStarts = starts;
      _matchEnds = ends;
      _findRegexBad = bad;
      _matchLen = q.length;
      _matchPos = starts.isEmpty ? -1 : 0;
    });
    // Yazarken odağı çalma (arama kutusunda kal); sadece seçimi ayarla.
    if (_matchPos >= 0) _selectMatch(focus: false);
  }

  void _jumpMatch(int delta) {
    if (_isPdf) {
      final entries = _findEntries;
      if (entries.isEmpty) return;
      var i = _findEntry == null ? -1 : entries.indexOf(_findEntry!);
      if (i == -1) {
        i = delta > 0 ? 0 : entries.length - 1;
      } else {
        i = (i + delta) % entries.length;
        if (i < 0) i += entries.length;
      }
      final e = entries[i];
      _partSetState(() => _findEntry = e);
      if (e.ocr) {
        final o = _ocrSearch!;
        o.currentIndex = e.index; // vurgu turuncuya döner
        final m = o.matches[e.index];
        _pdfJumpTarget = m.pageNumber;
        _pdfController.goToRectInsidePage(
            pageNumber: m.pageNumber, rect: m.bounds);
      } else {
        _ocrSearch?.currentIndex = -1;
        _pdfJumpTarget = e.page;
        _pdfSearcher?.goToMatchOfIndex(e.index);
      }
      return;
    }
    if (_matchStarts.isEmpty) return;
    _partSetState(() {
      _matchPos = (_matchPos + delta) % _matchStarts.length;
      if (_matchPos < 0) _matchPos += _matchStarts.length;
    });
    _selectMatch(focus: true); // ileri/geri: belgeye kaydır
  }

  /// Geçerli eşleşmeyi metin alanında seçer; [focus] ise oraya kaydırır.
  void _selectMatch({required bool focus}) {
    final ctl = _textController;
    if (ctl == null || _matchPos < 0 || _matchPos >= _matchStarts.length) {
      return;
    }
    final start = _matchStarts[_matchPos];
    final end = _matchEnds.length == _matchStarts.length
        ? _matchEnds[_matchPos]
        : start + _matchLen;
    ctl.selection = TextSelection(
      baseOffset: start,
      extentOffset: end.clamp(0, ctl.text.length),
    );
    if (focus) _textFocus.requestFocus();
  }

  /// Taranmış sayfa arama eşleşmelerini boyar. Renkler pdfrx'in
  /// varsayılanlarıyla birebir (sarı/turuncu, %50 saydam) — kullanıcı hangi
  /// eşleşmenin hangi motordan geldiğini AYIRT EDEMEMELİ.
  void _paintOcrSearchMatches(Canvas canvas, Rect pageRect, PdfPage page) {
    final o = _ocrSearch;
    if (o == null || o.matches.isEmpty) return;
    final normal = Paint()..color = AppColors.findMatch;
    final active = Paint()..color = AppColors.findActive;
    for (var i = 0; i < o.matches.length; i++) {
      final m = o.matches[i];
      if (m.pageNumber != page.pageNumber) continue;
      final paint = i == o.currentIndex ? active : normal;
      for (final r in m.rects) {
        canvas.drawRect(
          r
              .toRect(page: page, scaledPageSize: pageRect.size)
              .translate(pageRect.left, pageRect.top),
          paint,
        );
      }
    }
  }

  /// Belge içi arama çubuğu (app bar altında).
  PreferredSizeWidget _findBar() {
    final int count;
    final String label;
    if (_isPdf) {
      // Birleşik sayaç: metin katmanı + OCR (taranmış sayfa) eşleşmeleri.
      final entries = _findEntries;
      final busy = (_pdfSearcher?.isSearching ?? false) ||
          (_ocrSearch?.isSearching ?? false);
      count = entries.length;
      if (count > 0) {
        final pos = _findEntry == null ? -1 : entries.indexOf(_findEntry!);
        final head = pos >= 0 ? '${pos + 1}/$count' : '$count';
        // OCR hâlâ sayfa tarıyorsa üç nokta: sayı büyümeye devam edebilir.
        label = busy ? '$head…' : head;
      } else if (busy) {
        label = context.t('vw.searching');
      } else {
        label = _findCtl.text.trim().isEmpty ? '' : context.t('find.none');
      }
    } else {
      count = _matchStarts.length;
      label = count == 0
          ? (_findCtl.text.trim().isEmpty ? '' : context.t('find.none'))
          : '${_matchPos + 1}/$count';
    }
    // Değiştirme satırı YALNIZ düzenlenebilir metinde: PDF'te ve salt-okunur
    // belgede "değiştir" düğmesi sunmak, basılınca hiçbir şey yapmayan bir
    // düğme olurdu.
    final canReplace = !_isPdf && (widget.doc.isEditableText);
    final options = !_isPdf && _textController != null;
    return PreferredSize(
      preferredSize: Size.fromHeight(
          (_replaceOpen && canReplace ? 108 : 56) + (options ? 44 : 0)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        DocFindBar(
          controller: _findCtl,
          hint: context.t('vw.find_in_doc'),
          countLabel: label,
          onChanged: _runFind,
          onSubmitted: (_) => _jumpMatch(1),
          onPrev: count == 0 ? null : () => _jumpMatch(-1),
          onNext: count == 0 ? null : () => _jumpMatch(1),
          leading: [
            if (canReplace)
              IconButton(
                tooltip: context.t('vw.show_replace'),
                visualDensity: VisualDensity.compact,
                isSelected: _replaceOpen,
                icon: Icon(_replaceOpen
                    ? AppIcons.findReplace
                    : AppIcons.findReplace),
                onPressed: () => _partSetState(() => _replaceOpen = !_replaceOpen),
              ),
            // "Sayfaya git" arama çubuğunun içinde (2026-07-26 kullanıcı
            // isteği): aramayla aynı "belgede gezinme" kutusunda.
            if (_isPdf)
              IconButton(
                tooltip: context.t('vw.goto_page_short'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(AppIcons.numbers),
                onPressed: _askGoToPage,
              ),
          ],
        ),
        if (options) _findOptionsRow(),
        if (_replaceOpen && canReplace)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: _replaceRow(count),
          ),
      ]),
    );
  }

  /// Arama çubuğunun altındaki **değiştirme** satırı.
  ///
  /// İki düğme, iki farklı iş: "Değiştir" o an seçili eşleşmeyi (kullanıcı
  /// tek tek bakarak ilerlemek isteyebilir), "Tümünü değiştir" hepsini.
  /// İkincisi kaç değişiklik yaptığını SÖYLER — sessizce dönen bir metin,
  /// hiçbir şeyin değişmediği durumu gizlerdi.
  Widget _replaceRow(int count) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replaceCtl,
              textInputAction: TextInputAction.done,
              decoration: DocFindBar.decoration(
                context,
                hint: context.t('vw.replace_with'),
                icon: AppIcons.edit,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: count == 0 ? null : _replaceCurrent,
            child: Text(context.t('vw.replace_one')),
          ),
          TextButton(
            onPressed: count == 0 ? null : _replaceAll,
            child: Text(context.t('vw.replace_all')),
          ),
        ],
      ),
    );
  }

  /// Seçili eşleşmeyi değiştirir ve aramayı tazeler.
  void _replaceCurrent() {
    final ctl = _textController;
    if (ctl == null || _matchPos < 0 || _matchPos >= _matchStarts.length) {
      return;
    }
    final start = _matchStarts[_matchPos];
    final wanted = _matchPos; // değişimden sonra aynı sıradaki eşleşmeye dön
    final isRx = _matchEnds.length == _matchStarts.length;
    final len = isRx ? _matchEnds[_matchPos] - start : _matchLen;
    var repl = _replaceCtl.text;
    if (isRx) {
      final m = RegExp(_findCtl.text, caseSensitive: _findCase, unicode: true)
          .matchAsPrefix(ctl.text, start);
      if (m != null) repl = TextReplace.expandGroups(repl, m);
    }
    ctl.text = TextReplace.replaceAt(ctl.text, start, len, repl);
    _partSetState(() => _dirty = true);
    _runFind(_findCtl.text);
    if (_matchStarts.isNotEmpty) {
      _partSetState(() => _matchPos = wanted.clamp(0, _matchStarts.length - 1));
      _selectMatch(focus: false);
    }
  }

  /// Tüm eşleşmeleri değiştirir.
  void _replaceAll() {
    final ctl = _textController;
    if (ctl == null) return;
    // Tümünü değiştir TEK atamadır → tek geri al adımı.
    final result = _findRegex
        ? TextReplace.regexReplaceAll(ctl.text, _findCtl.text, _replaceCtl.text,
            matchCase: _findCase, wholeWord: _findWord)
        : TextReplace.replaceAll(ctl.text, _findCtl.text.trim(), _replaceCtl.text,
            matchCase: _findCase, wholeWord: _findWord);
    if (result.count == 0) {
      _snack(context.t('vw.replace_none'));
      return;
    }
    ctl.text = result.text;
    _partSetState(() => _dirty = true);
    _runFind(_findCtl.text);
    _snack(context.t('vw.replaced', {'n': result.count}));
  }

  /// **JSON/XML biçimlendirme.** Metin düzenleyicide değişiyor; dosya ancak
  /// kullanıcı kaydederse değişir. Çözümlenemeyen dosyada metne DOKUNULMAZ —
  /// bozuk bir JSON'u "düzeltmeye" çalışmak veri kaybı olurdu.
  void _prettify() {
    final ctl = _textController;
    if (ctl == null) return;
    final formatted =
        PrettyFormat.pretty(ctl.text, p.extension(widget.doc.path));
    if (formatted == ctl.text) {
      _snack(context.t('vw.prettify_failed'));
      return;
    }
    ctl.text = formatted;
    _partSetState(() => _dirty = true);
    _snack(context.t('vw.prettify_done'));
  }

  /// **Satıra git** — uzun bir kayıt/kod dosyasında "347. satır" demek
  /// mümkün olmalı. Eskiden tek yol parmakla kaydırmaktı.
  Future<void> _askGoToLine() async {
    final ctl = _textController;
    if (ctl == null) return;
    final total = LineEndings.toLf(ctl.text).split('\n').length;
    final controller = TextEditingController();
    final line = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('vw.goto_line')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: ctx.t('vw.line_number', {'max': total}),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: Text(ctx.t('common.ok')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (line == null || line < 1) return;
    // Satır başlangıcının karakter indeksi: n-1 satır sonu geçilir.
    final text = ctl.text;
    var offset = 0;
    for (var i = 1; i < line; i++) {
      final next = text.indexOf('\n', offset);
      if (next == -1) {
        offset = text.length;
        break;
      }
      offset = next + 1;
    }
    ctl.selection = TextSelection.collapsed(offset: offset);
    _textFocus.requestFocus();
  }
}
