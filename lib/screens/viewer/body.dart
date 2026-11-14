part of '../viewer_screen.dart';

/// Geniş ekrandaki sayfa küçük resimleri şeridinin genişliği (dp).
const double _kSidePanelWidth = 148;

extension _ViewerScreenBodyPart on _ViewerScreenState {
  Widget _buildBody(LoadedDoc doc) {
    switch (doc.kind) {
      case DocKind.pdf:
        // Önceki oturumun özgün baytları geri yazılıyor: bitmeden belge
        // açılırsa kaydedilmemiş düzenleme özgün sanılırdı. Bekleyiş de
        // dönen çember değil aynı nötr kâğıt (Ferrari H10.2).
        // Kaldığın yer henüz okunmadı (soğuk açılış, milisaniyeler).
        // Düz zemin yerine nötr kâğıt (Ferrari H1.1) — kapak, sayfa belli
        // olunca alttaki köprüde gelir.
        if (_waitingRestore || !_resumeReady) {
          return PdfOpenBridge(
              path: doc.path,
              visible: true,
              useCover: false,
              topInset: ReadingChrome.insetsOf(context).top);
        }
        // Ctrl/Cmd+C: seçili metni panoya kopyalar (masaüstü alışkanlığı —
        // Chrome'un PDF görüntüleyicisiyle aynı). Focus çevresi klavye
        // olayını alabilmek için; arama kutusu gibi alanlar açılınca odağı
        // onlar devralır, kısayol da doğal olarak onlara akar.
        // Builder: okuma kipinin çubuk ölçüleri ([ReadingChrome]) kabuğun
        // İÇİNDEN okunur — ekranın kendi bağlamı kabuğun dışında kalıyor.
        return Builder(builder: (context) {
        final chrome = ReadingChrome.insetsOf(context);
        return _withPdfSidePanel(CallbackShortcuts(
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
                  child: Listener(
                    // Otomatik kaydırma parmak ekrandayken bekler (Faz 48).
                    // Sayfa sayfa kipinde kaydırma = sayfa çevir (H3.5).
                    onPointerDown: (e) {
                      _holdAutoScroll(true);
                      _pagedPointerDown(e);
                    },
                    onPointerUp: (e) {
                      _holdAutoScroll(false);
                      _pagedPointerUp(e);
                    },
                    onPointerCancel: (_) {
                      _holdAutoScroll(false);
                      _pagedPointerCancel();
                    },
                    child: _nightFilter(
                    child: PdfViewer.file(
                      doc.path,
                      key: _pdfViewerKey,
                      controller: _pdfController,
                      initialPageNumber: _pdfPage,
                      passwordProvider: _askPdfPassword,
                      params: PdfViewerParams(
                        // **2/4 sütunda en küçük yakınlık** (kullanıcı
                        // 2026-10-30: *"2 sütun 4 sütun seçildiğinde sayfa
                        // yine tek sütun gibi görünüyor, zoom out yapınca
                        // düzeliyor"*). KÖK NEDEN: pdfrx varsayılanı
                        // (`useAlternativeFitScaleAsMinScale`) en küçük ölçeği
                        // "güncel sayfayı sığdır / ekranı kapla"nın küçüğüne
                        // kenetliyor; 4 sütunluk düzeni genişliğine sığdırmak
                        // bunun ALTINDA kaldığı için `_fitPdfWidth` sessizce
                        // tek sayfa ölçeğine kırpılıyordu. Çok sütunda sınır
                        // gevşer; tek sütunda eski davranış.
                        sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
                          useAlternativeFitScaleAsMinScale: _pdfColumns == 1,
                          minScale: _pdfColumns == 1 ? 0.1 : 0.05,
                          // Tablette çok yakın açılıyordu + yakınlık
                          // hatırlanmıyordu (2026-11-13) → [PdfZoomMemory].
                          calculateInitialZoom:
                              _pdfColumns == 1 ? _pdfInitialZoom : null,
                        ),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        // Sürükleyerek seçim sürerken pan kapalı: parmak/fare
                        // seçimi büyütür, sayfa kaymaz (Chrome davranışı).
                        // InteractiveViewer bu bayrağı HER olayda okuduğu için jest
                        // ortasında kapatmak da işler; belge yeniden YÜKLENMEZ
                        // (pdfrx yalnız documentRef değişiminde yükler).
                        // Düzenleme kipinde çizim aracı açıkken de kapalı:
                        // tek parmak çizer, iki parmak yakınlaştırır.
                        // Sayfa sayfa kipinde (yakın değilken) kaydırma yok:
                        // parmak sayfa çevirir (H3.5).
                        panEnabled: !_pdfSelecting &&
                            !(_pro?.drawing ?? false) &&
                            !_pagedLocked,
                        // Kaydırma kilidi (Faz 39): yalnız dikey eksen,
                        // iki parmak yakınlaştırma kapalı.
                        panAxis: _pdfScrollLock
                            ? PanAxis.vertical
                            : PanAxis.free,
                        scaleEnabled: !_pdfScrollLock,
                        // pdfrx 2.x'in KENDİ metin seçimi varsayılan olarak
                        // açık (1.3.5'te kapalıydı): bizim katmanımızın
                        // ([PdfSelectLayer]) altına ikinci bir jest katmanı,
                        // her dokunuşta tüm sayfaların metnini tarayan bir
                        // isabet testi ve ikinci bir uzun basış seçimi
                        // ekliyordu. Seçim bizde → kapalı (2026-11-03 kasma).
                        textSelectionParams: kPdfOwnSelectionOff,
                        // Çok sütunlu dizilim (uzun belge). 1 sütunda pdfrx'in kendi
                        // düzeni kullanılır — gereksiz yere devralmıyoruz.
                        //
                        // Okuma kipi (2026-10-28): çubuklar belgenin üstünde
                        // kayan katman; belgenin başına/sonuna çubuk boyu
                        // kadar pay eklenir ki ilk sayfanın üstü çubuğun
                        // altında kalmasın. Pay SABİT — görünüm boyu hiç
                        // değişmez (pdfrx boy değişince sayfa başına
                        // atlıyordu, HAFIZA 2026-10-23 (14)).
                        layoutPages: (pages, params) => _insetPdfLayout(
                          _pdfColumns == 1
                              // Kenar boşluğu kırpma (H3.4) yalnız tek sütunda.
                              ? (_pdfCrop == null
                                  ? _plainPdfLayout(pages, params)
                                  : PdfMarginCropper.layout(
                                      pages, params.margin, _pdfCrop!))
                              : _pdfColumns == kPdfBookLayout
                                  ? _layoutPdfBook(pages, params)
                                  : _layoutPdfColumns(pages, params),
                          context,
                          chrome,
                        ),
                        // Bitmap ölçeği pdfrx 2.12'nin kendisinde (basamaklı
                        // `getPageRenderingScale` 2.x'te fazladan çizim
                        // tetikliyordu — Faz 48.4 ölçümü). Önbellek tavanı
                        // cihaz profilinden.
                        maxImageBytesCachedOnMemory:
                            DeviceProfile.budget.pdfImageCacheBytes,
                        // Güncel sayfa: sayfalar ekrana sığınca rozet geri
                        // kalıyordu (bkz. [currentPdfPage]).
                        calculateCurrentPageNumber: _currentPdfPage,
                        // Kullanıcı kendisi kaydırmaya başladı: "gidilen sayfa"
                        // tercihi artık geçerli değil.
                        onInteractionEnd: (_) => _recordPdfZoom(),
                        onInteractionStart: (_) {
                          _pdfJumpTarget = null;
                          if (_pdfPinch) _partSetState(() => _pdfPinch = false);
                        },
                        // **Kaydırma "birazcık gidip duruyordu"** (2026-10-29
                        // kullanıcı bulgusu): pdfrx'in varsayılan fırlatma
                        // sürtünmesi (1,35e-5) 3000 px/sn'lik bir fırlatmayı
                        // ~270 px'te durduruyor; Android listeleri ~1300 px
                        // götürür. Kaydırmada [kPdfPanFriction]. AMA aynı
                        // katsayı ×200 yakınlaştırma ataletine de giriyor
                        // (≥ 1/200 olunca yakınlık fırlar) → iki parmaklı
                        // jestte varsayılana dönülür. Bu parametre belgeyi
                        // yeniden yüklemez/düzeni değiştirmez.
                        interactionEndFrictionCoefficient:
                            _pdfPinch ? kPdfPinchFriction : kPdfPanFriction,
                        onInteractionUpdate: (d) {
                          if (d.pointerCount >= 2 && !_pdfPinch) {
                            _partSetState(() => _pdfPinch = true);
                          }
                        },
                        // Arama eşleşmelerini sayfada vurgula: metin katmanı
                        // (pdfrx, Faz 1) + taranmış sayfaların OCR eşleşmeleri
                        // (Faz 2) — renkler aynı, kullanıcı fark görmez.
                        // Kâğıt temasında gölge yerine ince sayfa çerçevesi
                        // (2026-11-02, A7.7; bkz. PdfPageFrame).
                        pageDropShadow: PdfPageFrame.of(context).shadowOrDefault,
                        pagePaintCallbacks: [
                          PdfPageFrame.of(context).paint,
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
                        // Çift dokunma yakınlaştırır (Ferrari H3.1).
                        onGeneralTap: _onPdfGeneralTap,
                        // pdfium'un ham yığın izli mavi ekranı yerine anlaşılır
                        // kart (2026-09-27: 0 bayt kalan PDF bulgusu).
                        errorBannerBuilder: _pdfErrorBanner,
                        // Açılamayan belgede köprü hata yüzünü örtmesin.
                        onDocumentLoadFinished: (_, ok) {
                          // pdfrx bunu ilk sayfanın bitmap'i önbelleğe
                          // girince çağırır (H0.3).
                          if (ok) PdfProPerf.openMark('ilk_sayfa');
                          if (!ok && mounted && !_pdfOpened) {
                            _partSetState(() => _pdfOpened = true);
                          }
                        },
                        // Köprüler: iç hedef → o sayfaya git, dış adres → onay + tarayıcı.
                        linkHandlerParams: PdfLinkHandlerParams(
                          onLinkTap: _onPdfLink,
                          linkColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15),
                        ),
                        onViewerReady: (document, controller) {
                          // Belge arkamızdan yeniden yüklendiyse oturum eski
                          // belgeye bağlıdır: bırakılır (çökme kaydı kalır).
                          if (_pro != null && _pro!.document != document) {
                            unawaited(_closePro(keepRecovery: true));
                          }
                          _pdfDoc = document;
                          PdfProPerf.openMark('belge');
                          _pdfPasswordTried = false;
                          // Her (yeniden) yüklemede yeni arayıcı: eskisi önceki
                          // belgenin olaylarına bağlı kalırdı.
                          _pdfSearcher
                            ?..removeListener(_onPdfSearch)
                            ..dispose();
                          _pdfSearcher = PdfTextSearcher(controller)
                            ..addListener(_onPdfSearch);
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
                          // Açılış köprüsü: ilk sayfaya çizim payı, sonra solar.
                          _markPdfOpened();
                          // Sayfa sayfa kipi: açılışta sayfa ekrana sığar.
                          if (_pdfPaged) _fitPagedSoon();
                          // Açılışta sayfa sayısı bir an görünsün (H3.7).
                          _pokePageBadge();
                          unawaited(_proCheckRecovery());
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
                            if (_pdfSidePanel) _followSidePanel(page);
                          }
                        },
                        pageOverlaysBuilder: (context, pageRect, page) => [
                          ?_bookmarkRibbon(page, pageRect),
                          // Düzenleme kipi (Faz 54): seçim katmanının yerine
                          // blok katmanı — aynı ekran, aynı yakınlaştırma.
                          if (_pro != null)
                            PdfProBlockLayer(
                              page: page,
                              pageSize: pageRect.size,
                              controller: _pro!,
                              events: _proEvents,
                              zoom: () => _pdfController.currentZoom,
                            )
                          else
                          PdfSelectLayer(
                              page: page,
                              pageSize: pageRect.size,
                              // Tek etkin seçim: seçim hangi sayfadaysa öbür
                              // sayfaların katmanları kendi vurgusunu bırakır.
                              activeSelectionPage:
                                  _pdfSelection.isEmpty ? 0 : _pdfSelPage,
                              onSelected:
                                  (t, rects, pageNo, _, _) {
                                if (mounted) {
                                  _partSetState(() {
                                    // Yeni seçim: çubuk vurgu kipinden çıkar.
                                    _lastMark = null;
                                    if (t != _pdfSelection) {
                                      _pdfSelExpanded = false;
                                      _pdfSelBarTop = false;
                                    }
                                    _pdfSelection = t;
                                    _pdfSelRects = rects;
                                    _pdfSelPage = t.isEmpty ? 0 : pageNo;
                                  });
                                  // PS5 (cihaz turu): seçim TUTAMAÇLA
                                  // uzatılınca "parmak kalktı" olayı gelmiyor
                                  // → seçim durulunca çubuğun yerine yine
                                  // karar verilir (sürükleme boyunca değil).
                                  _pdfSelRevealTimer?.cancel();
                                  if (t.trim().isNotEmpty && !_pdfSelecting) {
                                    _pdfSelRevealTimer =
                                        Timer(Motion.long, () {
                                      if (mounted) {
                                        _revealAboveBar(
                                            _pdfSelPage, _pdfSelRects,
                                            barHeight:
                                                _pdfSelExpanded ? 420 : 190);
                                      }
                                    });
                                  }
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
                              // Çift dokunuş burada yakınlaştırır (H3.1).
                              doubleTapSelectsWord: false,
                            ),
                        ],
                      ),
                    ),
                  )),
                ),
                // Açılış köprüsü (Ferrari H1.1): belge gelene kadar kapak /
                // kâğıt; görüntüleyicinin ÜSTÜNDE, boyunu değiştirmez.
                Positioned.fill(
                  child: _nightFilter(
                    child: PdfOpenBridge(
                      key: const ValueKey('pdf-bridge'),
                      path: doc.path,
                      visible: !_pdfOpened,
                      useCover: _pdfPage <= 1,
                      // Son kapanıştaki sayfa görüntüsü (H1.4) kapağın önünde.
                      page: _pdfPage,
                      topInset: chrome.top,
                    ),
                  ),
                ),
                // Seçim çubuğu açıkken rozet gizli: çubuğun altından yarım
                // görünüyordu ("1 / 1 · sayfaya git" kartın altına sıkışmıştı).
                // Ferrari H3.7: rozet yalnız kaydırırken görünür, durunca
                // [Motion.badgeLinger] sonra solar (sayfaya git ⋮ menüsünde
                // ve kaydırma tutamacında da var).
                if (_pageCount > 0 && !_pdfBarShown)
                  ReadingFloat(
                    child: Center(
                      child: ExcludeSemantics(
                        excluding: !_pageBadgeOn,
                        child: IgnorePointer(
                          ignoring: !_pageBadgeOn,
                          child: AnimatedOpacity(
                            key: const ValueKey('pdf-page-badge-fade'),
                            opacity: _pageBadgeOn ? 1 : 0,
                            duration: Motion.of(context, Motion.medium),
                            curve: Motion.standard,
                            // Rozet İngilizce/Arapça arayüzde de çevrilmeli —
                            // eskiden "— sayfaya git" kısmı koda gömülü
                            // Türkçeydi.
                            child: _pageBadge(),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_resumeNotePage case final page?)
                  PdfResumeNote(
                    page: page,
                    top: ReadingChrome.insetsOf(context).top + 8,
                    onRestart: _restartFromFirstPage,
                    onDismiss: () {
                      if (mounted) _partSetState(() => _resumeNotePage = null);
                    },
                  ),
                if (_pdfSelection.trim().isNotEmpty && !_pdfSelBarTop)
                  ReadingFloat(
                    start: 8,
                    end: 8,
                    child: Center(child: _selectionBar()),
                  ),
                // PS5: kaydırarak açılamayan seçimde (sayfa sonu, uzun seçim)
                // çubuk seçimin ÜSTÜNE, ekranın tepesine geçer.
                if (_pdfSelection.trim().isNotEmpty && _pdfSelBarTop)
                  PositionedDirectional(
                    start: 8,
                    end: 8,
                    top: ReadingChrome.insetsOf(context).top + 8,
                    child: Center(child: _selectionBar()),
                  ),
              ],
            ),
          ),
        ));
        });

      case DocKind.image:
        return Container(
          color: AppColors.pageInk,
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
                  child: Image(
                    // Bellek/pil: tam çözünürlük yerine ekranın gerektirdiği
                    // kadar piksel (bkz. core/image_budget.dart). 12 MP'lik
                    // bir fotoğraf tam açıldığında 48 MB bitmap ediyordu.
                    // G7.7: FmFileImage ayrıca piksel tavanı uygular (uzun/dar
                    // 100 MP+ görsel yalnız genişlikle sınırlanamıyordu).
                    image: FmFileImage(doc.path, cacheWidth: _imgDecodeWidth),
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Text(
                      context.t('vw.image_failed'),
                      style: const TextStyle(color: AppColors.onMedia),
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
        final editorBase = _TextEditor(
          controller: _textController!,
          focusNode: _textFocus,
          editable: doc.isEditableText,
          fontSize: _fontSize,
          fontFamily: _fontFamily,
          lineNumbers: _lineNumbers,
          wrapLines: _wrapLines,
          scroll: _textScroll,
          formatters: _codeFormatters,
          undo: _undoCtl,
          lineHeight: _lineHeight,
          onChanged: () {
            if (!_dirty) _partSetState(() => _dirty = true);
          },
        );
        // Kod / Markdown araçları (Faz 30): yalnız düz metin dosyasında;
        // klavye üstü çubuk metin alanına odaklanınca görünür.
        final Widget editor = !_isCodeDoc
            ? editorBase
            : ListenableBuilder(
                listenable: Listenable.merge([_textFocus, _undoCtl]),
                builder: (context, _) => LayoutBuilder(builder: (context, box) {
                  final preview = _isMarkdown && _mdPreview;
                  // Geniş ekranda (tablet / yatay) önizleme editörün YANINDA
                  // açılır ve yazdıkça güncellenir (Faz 30 kalanı); telefonda
                  // Düzenle | Önizle arasında geçilir.
                  final split = preview && box.maxWidth >= _mdSplitMinWidth;
                  final showBar = doc.isEditableText &&
                      _textFocus.hasFocus &&
                      (!preview || split);
                  final Widget body;
                  if (split) {
                    body = Row(
                      key: const ValueKey('md-split'),
                      children: [
                        Expanded(child: editorBase),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _textController!,
                            builder: (_, _, _) => _markdownPreview(),
                          ),
                        ),
                      ],
                    );
                  } else {
                    body = preview ? _markdownPreview() : editorBase;
                  }
                  return Stack(
                    children: [
                      Positioned.fill(child: body),
                      if (showBar)
                        ReadingFloat(gap: 0, child: _codeAccessoryBar()),
                    ],
                  );
                }),
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
                Icon(AppIcons.insertDriveFile,
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

  /// pdfrx'in kendi tek sütun düzeninin aynısı (paketteki özel; okuma
  /// kipi payı eklenebilsin diye burada).
  static PdfPageLayout _plainPdfLayout(
      List<PdfPage> pages, PdfViewerParams params) {
    final width =
        pages.fold(0.0, (w, p) => math.max(w, p.width)) + params.margin * 2;
    final rects = <Rect>[];
    var y = params.margin;
    for (final page in pages) {
      rects.add(
          Rect.fromLTWH((width - page.width) / 2, y, page.width, page.height));
      y += page.height + params.margin;
    }
    return PdfPageLayout(pageLayouts: rects, documentSize: Size(width, y));
  }

  /// Belgenin başına ve sonuna okuma kipi çubuklarının boyu kadar pay.
  ///
  /// Pay belge biriminde (pt): sığdırılmış yakınlıkta ekrandaki dp karşılığı
  /// tam çubuk boyu olsun diye `belge genişliği / görünüm genişliği` ile
  /// çevrilir. Aynı girdide aynı düzen döner (pdfrx düzeni her karede
  /// eşitlikle karşılaştırıyor — farklı çıksa sayfa başına atlardı).
  PdfPageLayout _insetPdfLayout(
      PdfPageLayout base, BuildContext context, EdgeInsets chrome) {
    if (chrome.top == 0 && chrome.bottom == 0) return base;
    var viewW = MediaQuery.sizeOf(context).width;
    if (_pdfDoc != null && _pdfSidePanel && viewW >= 840) {
      viewW -= _kSidePanelWidth + 1; // yan küçük resimler + ayraç
    }
    if (viewW <= 0) return base;
    final k = base.documentSize.width / viewW;
    final top = (chrome.top * k).roundToDouble();
    final bottom = (chrome.bottom * k).roundToDouble();
    return PdfPageLayout(
      pageLayouts: [for (final r in base.pageLayouts) r.translate(0, top)],
      documentSize: Size(base.documentSize.width,
          base.documentSize.height + top + bottom),
    );
  }

  /// **Geniş ekranda sayfa küçük resimleri** (Faz 18 / G17): ≥ 840 dp'de
  /// solda dikey şerit; dokunuş o sayfaya gider, güncel sayfa vurgulu.
  /// Telefonda belge tam genişlik (değişmedi). Ferrari H1.3 (2026-11-14):
  /// varsayılan KAPALI, üst çubuktaki düğmeyle açılır ([_pdfSidePanel]).
  /// Ekran yan şeride yetecek kadar geniş mi (≥ 840 dp)?
  bool get _wideForSidePanel => MediaQuery.sizeOf(context).width >= 840;

  Widget _withPdfSidePanel(Widget viewer) {
    final doc = _pdfDoc;
    if (doc == null || !_pdfSidePanel || !_wideForSidePanel) return viewer;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('pdf-side-panel'),
          width: _kSidePanelWidth,
          child: ListView.builder(
            controller: _sidePanelScroll,
            padding: const EdgeInsets.all(Gap.sm),
            itemCount: doc.pages.length,
            itemBuilder: (context, i) {
              final page = i + 1;
              final current = page == _pdfPage;
              return Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: InkWell(
                  onTap: () => _goToPdfPage(page, doc.pages.length),
                  child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: current
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: current ? 2 : 1,
                          ),
                        ),
                        child: AspectRatio(
                          aspectRatio: doc.pages[i].width /
                              (doc.pages[i].height == 0
                                  ? 1
                                  : doc.pages[i].height),
                          // Gecikmeli: küçük resimler ana sayfalarla aynı
                          // çizim sırasını paylaşır (bkz. [_DeferredPdfThumb]).
                          child: _DeferredPdfThumb(
                              key: ValueKey('pdf-thumb-$page'),
                              document: doc,
                              pageNumber: page),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('$page',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: viewer),
      ],
    );
  }
}
