part of '../viewer_screen.dart';

extension _ViewerScreenBodyPart on _ViewerScreenState {
  Widget _buildBody(LoadedDoc doc) {
    switch (doc.kind) {
      case DocKind.pdf:
        // Önceki oturumun özgün baytları geri yazılıyor: bitmeden belge
        // açılırsa kaydedilmemiş düzenleme özgün sanılırdı.
        if (_waitingRestore) {
          return const Center(child: CircularProgressIndicator());
        }
        // Kaldığın yer henüz okunmadı (soğuk açılış, milisaniyeler).
        if (!_resumeReady) {
          return ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest);
        }
        // Ctrl/Cmd+C: seçili metni panoya kopyalar (masaüstü alışkanlığı —
        // Chrome'un PDF görüntüleyicisiyle aynı). Focus çevresi klavye
        // olayını alabilmek için; arama kutusu gibi alanlar açılınca odağı
        // onlar devralır, kısayol da doğal olarak onlara akar.
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyC, control: true):
                _copyPdfSelection,
            const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
                _copyPdfSelection,
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Positioned.fill(
                  // pdfrx (pdfium). Metin seçimi: paketin SelectionArea'sı Android'de
                  // güvenilir çalışmadığı için sayfa üzerine kendi seçim katmanımız
                  // (PdfSelectLayer) biner. Katman DAİMA açıktır ve parmağı ASLA
                  // yutmaz: uzun basış seçer, tek parmak kaydırır, iki parmak
                  // yakınlaştırır. (Eski "sürükleyerek seç" modu kaldırıldı —
                  // açıkken `panEnabled: false` yapıyordu ve kullanıcı sayfayı
                  // kaydıramıyor/yakınlaştıramıyordu; bkz. HAFIZA 2026-07-26.)
                  //
                  // Dosya yolu HİÇ DEĞİŞMEZ (2026-07-26, 9. tur): düzenlemeler
                  // dosyanın kendisine yazılıp [PdfReload] ile tazeleniyor. Yolu
                  // geçici bir çalışma kopyasına çevirmek pdfrx'e belgeyi baştan
                  // yükletiyor ve görüntüleyiciyi kararsızlaştırıyordu ("sayfa
                  // geçemiyorum, zoom yapamıyorum"). Özgün baytlar yedekte duruyor.
                  //
                  // Gece modu: sayfa görüntüsü renk matrisiyle terslenir. Dosyaya
                  // dokunmaz, seçim/arama koordinatlarını da etkilemez (yalnız boya).
                  child: _nightFilter(
                    child: PdfViewer.file(
                      doc.path,
                      controller: _pdfController,
                      initialPageNumber: _pdfPage,
                      params: PdfViewerParams(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        // Sürükleyerek seçim sürerken pan kapalı: parmak/fare
                        // seçimi büyütür, sayfa kaymaz (Chrome davranışı).
                        // InteractiveViewer bu bayrağı HER olayda okuduğu için jest
                        // ortasında kapatmak da işler; belge yeniden YÜKLENMEZ
                        // (pdfrx yalnız documentRef değişiminde yükler).
                        panEnabled: !_pdfSelecting,
                        // Çok sütunlu dizilim (uzun belge). 1 sütunda pdfrx'in kendi
                        // düzeni kullanılır — gereksiz yere devralmıyoruz.
                        layoutPages:
                            _pdfColumns == 1 ? null : _layoutPdfColumns,
                        // Güncel sayfa: sayfalar ekrana sığınca rozet geri
                        // kalıyordu (bkz. [currentPdfPage]).
                        calculateCurrentPageNumber: _currentPdfPage,
                        // Kullanıcı kendisi kaydırmaya başladı: "gidilen sayfa"
                        // tercihi artık geçerli değil.
                        onInteractionStart: (_) => _pdfJumpTarget = null,
                        // Arama eşleşmelerini sayfada vurgula: metin katmanı
                        // (pdfrx, Faz 1) + taranmış sayfaların OCR eşleşmeleri
                        // (Faz 2) — renkler aynı, kullanıcı fark görmez.
                        pagePaintCallbacks: [
                          _paintPendingMarks,
                          if (_pdfSearcher != null)
                            _pdfSearcher!.pageTextMatchPaintCallback,
                          if (_ocrSearch != null) _paintOcrSearchMatches,
                        ],
                        // Sağ kenarda sürüklenebilir kaydırma çubuğu: uzun belgede
                        // sayfa sayfa kaydırmak yerine tutup atlanır, üstünde de
                        // güncel sayfa numarası yazar.
                        viewerOverlayBuilder: (context, size, handleLinkTap) =>
                            [
                          PdfViewerScrollThumb(
                            controller: _pdfController,
                            orientation: ScrollbarOrientation.right,
                            thumbSize: const Size(34, 46),
                            thumbBuilder:
                                (ctx, thumbSize, pageNumber, controller) =>
                                    _scrollThumb(pageNumber),
                          ),
                        ],
                        // pdfium'un ham yığın izli mavi ekranı yerine anlaşılır
                        // kart (2026-09-27: 0 bayt kalan PDF bulgusu).
                        errorBannerBuilder: _pdfErrorBanner,
                        // Köprüler: iç hedef → o sayfaya git, dış adres → onay + tarayıcı.
                        linkHandlerParams: PdfLinkHandlerParams(
                          onLinkTap: _onPdfLink,
                          linkColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15),
                        ),
                        onViewerReady: (document, controller) {
                          _pdfDoc = document;
                          if (mounted) {
                            _partSetState(() => _pdfCount = document.pages.length);
                          }
                          // Metin katmanı açılışta ÇIKARILMAZ (Faz 4, P4): yalnız
                          // AI / çeviri / sesli okuma istenince
                          // (`_ensurePdfText`). Büyük PDF'te açılışı ve pili
                          // yiyordu.
                          // Belge çizildikten SONRA haber ver: açılışta gösterilen
                          // şerit ilk kareyle birlikte kayboluyordu.
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) => _showResumeNotice());
                          if (widget.startInk && !_inkStarted) {
                            _inkStarted = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _openInk();
                            });
                          }
                        },
                        onPageChanged: (page) {
                          if (mounted && page != null) {
                            _partSetState(() => _pdfPage = page);
                            // Kaldığın yerden devam: kayıt kuralları
                            // `ReadingPositions`ta (ilk/son sayfa ve kısa belge
                            // kaydedilmez), yazma gecikmeli.
                            if (context.read<AppState>().resumePosition) {
                              ReadingPositions.record(
                                  widget.doc.path, page, _pageCount,
                                  size: _docSize);
                            }
                          }
                        },
                        pageOverlaysBuilder: (context, pageRect, page) => [
                          if (_bookmarkRibbon(page, pageRect) case final r?) r,
                          PdfSelectLayer(
                              page: page,
                              pageSize: pageRect.size,
                              // Tek etkin seçim: seçim hangi sayfadaysa öbür
                              // sayfaların katmanları kendi vurgusunu bırakır.
                              activeSelectionPage:
                                  _pdfSelection.isEmpty ? 0 : _pdfSelPage,
                              onSelected:
                                  (t, rects, pageNo, _, __) {
                                if (mounted) {
                                  _partSetState(() {
                                    // Yeni seçim: çubuk vurgu kipinden çıkar.
                                    _lastMark = null;
                                    _pdfSelection = t;
                                    _pdfSelRects = rects;
                                    _pdfSelPage = t.isEmpty ? 0 : pageNo;
                                  });
                                }
                              },
                              onSelectingChanged: (s) {
                                if (mounted && _pdfSelecting != s) {
                                  _partSetState(() => _pdfSelecting = s);
                                  // Parmak kalktı: seçilen satır çubuğun
                                  // arkasında kalmasın.
                                  if (!s && _pdfSelection.trim().isNotEmpty) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        _revealAboveBar(
                                            _pdfSelPage, _pdfSelRects);
                                      }
                                    });
                                  }
                                }
                              },
                              onDragAt: _onPdfSelDragAt,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Seçim çubuğu açıkken rozet gizli: çubuğun altından yarım
                // görünüyordu ("1 / 1 · sayfaya git" kartın altına sıkışmıştı).
                if (_pageCount > 0 && !_pdfBarShown)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      // Rozet İngilizce/Arapça arayüzde de çevrilmeli — eskiden
                      // "— sayfaya git" kısmı koda gömülü Türkçeydi.
                      child: _pageBadge(),
                    ),
                  ),
                if (_pdfSelection.trim().isNotEmpty)
                  Positioned(
                    bottom: 16,
                    left: 8,
                    right: 8,
                    child: Center(child: _selectionBar()),
                  ),
              ],
            ),
          ),
        );

      case DocKind.image:
        return Container(
          color: Colors.black,
          child: GestureDetector(
            onDoubleTapDown: (d) => _doubleTapDetails = d,
            onDoubleTap: _handleImgDoubleTap,
            child: InteractiveViewer(
              transformationController: _imgTx,
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: RotatedBox(
                  quarterTurns: _imgQuarterTurns,
                  child: Image.file(
                    File(doc.path),
                    // Bellek/pil: tam çözünürlük yerine ekranın gerektirdiği
                    // kadar piksel (bkz. core/image_budget.dart). 12 MP'lik
                    // bir fotoğraf tam açıldığında 48 MB bitmap ediyordu.
                    cacheWidth: _imgDecodeWidth,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Text(
                      context.t('vw.image_failed'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

      case DocKind.spreadsheet:
        return _SpreadsheetView(table: doc.table ?? const []);

      case DocKind.text when doc.largeText:
        return LargeTextView(
          path: doc.path,
          fontSize: _fontSize,
          fontFamily: _fontFamily,
          lineNumbers: _lineNumbers,
        );

      case DocKind.text:
      case DocKind.word:
      case DocKind.slides:
        final editor = _TextEditor(
          controller: _textController!,
          focusNode: _textFocus,
          editable: doc.isEditableText,
          fontSize: _fontSize,
          fontFamily: _fontFamily,
          lineNumbers: _lineNumbers,
          wrapLines: _wrapLines,
          onChanged: () {
            if (!_dirty) _partSetState(() => _dirty = true);
          },
        );
        // Eski .doc/.ppt: salt okunur rozeti + "dönüştür ve düzenle" (Faz 9).
        final legacy = doc.legacyExt;
        final target = legacy == null ? null : LegacyConvert.targetExt(legacy);
        if (legacy == null || target == null) return editor;
        return Column(
          children: [
            LegacyBanner(
              ext: legacy,
              target: target,
              busy: _legacyBusy,
              onConvert: _convertLegacy,
            ),
            Expanded(child: editor),
          ],
        );

      case DocKind.unknown:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_rounded,
                    size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(
                  doc.plainText.isNotEmpty
                      ? doc.plainText
                      : context.t('vw.no_viewer'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  // Gerçekten sistemin varsayılan uygulamasında açar
                  // (eskiden "paylaş" sayfasını açıyordu — kullanıcı dosyayı
                  // açmak isterken paylaşım listesiyle karşılaşıyordu).
                  onPressed: () =>
                      EntryOpener.openExternally(context, widget.doc.path),
                  icon: const Icon(AppIcons.open),
                  label: Text(context.t('fm.open_with_other')),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _share,
                  icon: const Icon(AppIcons.share),
                  label: Text(context.t('common.share')),
                ),
              ],
            ),
          ),
        );
    }
  }
}
