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
                        //
                        // Okuma kipi (2026-10-28): çubuklar belgenin üstünde
                        // kayan katman; belgenin başına/sonuna çubuk boyu
                        // kadar pay eklenir ki ilk sayfanın üstü çubuğun
                        // altında kalmasın. Pay SABİT — görünüm boyu hiç
                        // değişmez (pdfrx boy değişince sayfa başına
                        // atlıyordu, HAFIZA 2026-10-23 (14)).
                        layoutPages: (pages, params) => _insetPdfLayout(
                          _pdfColumns == 1
                              ? _plainPdfLayout(pages, params)
                              : _layoutPdfColumns(pages, params),
                          context,
                          chrome,
                        ),
                        // **Yakınlaştırmada titreme** (2026-10-28): bkz.
                        // [_pdfRenderScale] — sayfa bitmap'i yakınlığa göre
                        // basamaklı keskinleşir, jest sürerken değişmez.
                        getPageRenderingScale: _pdfRenderScale,
                        // Güncel sayfa: sayfalar ekrana sığınca rozet geri
                        // kalıyordu (bkz. [currentPdfPage]).
                        calculateCurrentPageNumber: _currentPdfPage,
                        // Kullanıcı kendisi kaydırmaya başladı: "gidilen sayfa"
                        // tercihi artık geçerli değil.
                        onInteractionStart: (_) {
                          _pdfJumpTarget = null;
                          _pdfInteracting = true;
                        },
                        onInteractionEnd: (_) => _pdfInteracting = false,
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
                  ReadingFloat(
                    child: Center(
                      // Rozet İngilizce/Arapça arayüzde de çevrilmeli — eskiden
                      // "— sayfaya git" kısmı koda gömülü Türkçeydi.
                      child: _pageBadge(),
                    ),
                  ),
                if (_pdfSelection.trim().isNotEmpty)
                  ReadingFloat(
                    start: 8,
                    end: 8,
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
                  child: Image.file(
                    File(doc.path),
                    // Bellek/pil: tam çözünürlük yerine ekranın gerektirdiği
                    // kadar piksel (bkz. core/image_budget.dart). 12 MP'lik
                    // bir fotoğraf tam açıldığında 48 MB bitmap ediyordu.
                    cacheWidth: _imgDecodeWidth,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Text(
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
    if (_pdfDoc != null && viewW >= 840) viewW -= 149; // yan küçük resimler
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

  /// **Yakınlaştırırken titreme/bozulma** (kullanıcı 2026-10-28: *"zoom
  /// yaparken anlık görüntü değişmesi, bozulması, titremesi oluyor"*).
  ///
  /// KÖK NEDEN (pdfrx 1.3.5): sayfanın tam bitmap'i SABİT bir ölçekte
  /// (200 dpi) çiziliyor; daha yakında pdfrx görünen parçayı ayrıca keskin
  /// çizip üstüne yapıştırıyor ve bu "kısmi" görüntüyü her jest karesinde
  /// iptal edip 50 ms sonra yeniden istiyor. Parmak hareket ettikçe keskin
  /// dikdörtgen eski yerinde kalıyor, kenarında bulanık zemin görünüyor,
  /// yenisi gelince görüntü "atlıyor"; eşiğin altına inince de keskinlik
  /// birden kayboluyor.
  ///
  /// Çözüm: tam sayfa bitmap'inin ölçeği yakınlığa göre **basamaklı**
  /// yükselir (×1,5 adımlar, sayfa başına ~12 MP tavan) — kısmi yamaya ancak
  /// tavanın ötesinde gerek kalır. Jest SÜRERKEN ölçek değişmez (yeniden
  /// çizim yok, titreme yok); parmak kalkınca bir kez keskinleşir. Geri
  /// uzaklaşınca ölçek ancak yarıdan fazla düşünce iner (gidip gelmesin).
  double? _pdfRenderScale(BuildContext context, PdfPage page,
      PdfViewerController controller, double estimated) {
    var current = _pdfBaseScale ?? estimated;
    if (!_pdfInteracting && controller.isReady) {
      final need =
          MediaQuery.devicePixelRatioOf(context) * controller.currentZoom;
      var step = estimated;
      while (step < need) {
        step *= 1.5;
      }
      if (step > current || step < current / 2.3) current = step;
      _pdfBaseScale = current;
    }
    final area = page.width * page.height;
    final cap = area <= 0 ? current : math.sqrt(12e6 / area);
    return math.max(estimated, math.min(current, cap));
  }

  /// **Geniş ekranda sayfa küçük resimleri** (Faz 18 / G17): ≥ 840 dp'de
  /// solda dikey şerit; dokunuş o sayfaya gider, güncel sayfa vurgulu.
  /// Telefonda belge tam genişlik (değişmedi).
  Widget _withPdfSidePanel(Widget viewer) {
    final doc = _pdfDoc;
    if (doc == null || MediaQuery.sizeOf(context).width < 840) return viewer;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('pdf-side-panel'),
          width: 148,
          child: ListView.builder(
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
                          child: PdfPageView(
                              document: doc, pageNumber: page, maximumDpi: 48),
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
