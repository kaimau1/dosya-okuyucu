part of '../viewer_screen.dart';

/// `_pdfColumns` için "kitap (çift sayfa)" dizilimi değeri (1/2/4 sütun
/// yanında). Kapak tek başına sağda, sonra karşılıklı sayfalar (Faz 39).
const kPdfBookLayout = 3;

/// Kâğıt tonu: hafif sıcak (sepya) — beyaz kâğıdın göz alıcılığını kırar,
/// siyah yazıyı koyu kahveye çeker. Belge İÇERİĞİ filtresi (tasarım rengi
/// değil); gece kipindeki ters çevirme matrisiyle aynı yaklaşım.
const _sepiaFilter = ColorFilter.matrix(<double>[
  0.393 * 0.6 + 0.4, 0.769 * 0.6, 0.189 * 0.6, 0, 0, //
  0.349 * 0.6, 0.686 * 0.6 + 0.4, 0.168 * 0.6, 0, 0, //
  0.272 * 0.6, 0.534 * 0.6, 0.131 * 0.6 + 0.4, 0, 0, //
  0, 0, 0, 1, 0, //
]);

extension _ViewerScreenPdfReadingProPart on _ViewerScreenState {
  /// **Kitap görünümü:** kapak sağda tek, ardından (2,3), (4,5)… karşılıklı;
  /// çift sayfanın arasında boşluk yok (açık kitap).
  PdfPageLayout _layoutPdfBook(List<PdfPage> pages, PdfViewerParams params) {
    final margin = params.margin;
    var colWidth = 0.0;
    for (final page in pages) {
      colWidth = math.max(colWidth, page.width);
    }
    final layouts = List<Rect>.filled(pages.length, Rect.zero);
    var y = margin;
    var i = 0;
    while (i < pages.length) {
      // Kapak: yalnız sağ yarı. Sonra çiftler: sol (çift numara) + sağ.
      final row = i == 0 ? [i] : [i, if (i + 1 < pages.length) i + 1];
      var rowHeight = 0.0;
      for (var k = 0; k < row.length; k++) {
        final page = pages[row[k]];
        final rightSide = i == 0 || k == 1;
        final colLeft = margin + (rightSide ? colWidth : 0);
        // Sayfa sırtına (ortaya) yaslanır.
        final x = rightSide ? colLeft : colLeft + colWidth - page.width;
        layouts[row[k]] = Rect.fromLTWH(x, y, page.width, page.height);
        rowHeight = math.max(rowHeight, page.height);
      }
      y += rowHeight + margin;
      i += row.length;
    }
    return PdfPageLayout(
      pageLayouts: layouts,
      documentSize: Size(margin * 2 + colWidth * 2, y),
    );
  }

  /// Bir arama sonucuna gider (ileri/geri düğmeleri ve sonuç listesi ortak).
  void _goToFindEntry(({bool ocr, int index, int page}) e) {
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
  }

  /// **Sonuç listesi** (Faz 39 madde 10): tüm eşleşmeler sayfa sırasıyla,
  /// metin katmanındakiler bağlam parçasıyla; taranmış (OCR) sayfadakiler
  /// işaretli. Dokununca oraya gider.
  Future<void> _showFindResults() async {
    final entries = _findEntries;
    if (entries.isEmpty) return;
    final searcher = _pdfSearcher;
    String snippet(({bool ocr, int index, int page}) e) {
      if (e.ocr || searcher == null || e.index >= searcher.matches.length) {
        return '';
      }
      final text = searcher.matches[e.index].fragments
          .map((f) => f.text)
          .join()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return text.length > 120 ? '${text.substring(0, 120)}…' : text;
    }

    final picked = await showAppSheet<({bool ocr, int index, int page})>(
      context,
      title: context.t('pp.find_results', {'n': entries.length}),
      scrollable: false,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: entries.length,
          itemExtent: 64,
          itemBuilder: (ctx, i) {
            final e = entries[i];
            final s = snippet(e);
            return ListTile(
              dense: true,
              leading: Text('${e.page}', style: ctx.type.caption),
              title: Text(
                s.isEmpty ? ctx.t('pp.find_ocr_hit') : s,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              selected: e == _findEntry,
              onTap: () => Navigator.pop(ctx, e),
            );
          },
        ),
      ),
    );
    if (picked != null && mounted) _goToFindEntry(picked);
  }

  /// **Vurgu/not kitapçığı** (Faz 39 madde 6/10): belgedeki tüm işaretleme
  /// ve notlar tek Markdown dosyasında, paylaşılır.
  Future<void> _exportNotesBooklet() async {
    // Ekranda bekleyen (henüz yazılmamış) vurgular önce dosyaya.
    if (!await _flushPendingMarks() || !mounted) return;
    try {
      final bytes = await _fileService.readBytes(widget.doc.path);
      final items = await PdfNotes.collectInBackground(bytes);
      if (!mounted) return;
      if (items.isEmpty) {
        _snack(context.t('pp.notes_empty'));
        return;
      }
      final md = PdfNotes.toMarkdown(
        items,
        title: widget.doc.name,
        labels: {
          for (final k in PdfNoteKind.values) k: context.t('pp.note_${k.name}'),
        },
        pageLabel: (n) => context.t('pp.compare_page', {'n': n}),
      );
      final shareText = context.t('pp.notes_count', {'n': items.length});
      final path = await ConversionService().writeToTemp(
          '${p.basenameWithoutExtension(widget.doc.name)}-notlar.md',
          utf8.encode(md));
      await Share.shareXFiles([XFile(path)], text: shareText);
    } catch (e) {
      if (mounted) _snack(userErrorText(e));
    }
  }
}
