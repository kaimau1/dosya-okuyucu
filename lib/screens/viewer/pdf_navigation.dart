part of '../viewer_screen.dart';

extension _ViewerScreenPdfNavigationPart on _ViewerScreenState {
  /// Görselde veya (taranmış) PDF'te cihaz-içi OCR koşturur; sonucu seçilebilir
  /// bir sayfada gösterir ve AI sohbet bağlamına işler.
  Future<void> _runOcr() async {
    final doc = widget.doc;
    if (doc.kind == DocKind.pdf && _pdfDoc == null) {
      _snack(context.t('vw.pdf_loading'));
      return;
    }
    // Uzun PDF'te OCR dakikalar sürer: pencerede "Sayfa 4 / 30 · %13 · ~3 dk
    // kaldı", 1,5 sn'yi geçince ana ekran şeridinde ve bildirimde de (bkz.
    // `widgets/tracked_busy.dart`). Metinler await'ten önce alınır.
    final str = AppStrings.of(context);
    final busy = showTrackedBusy(
      context,
      title: str.t('vw.ocr_running'),
      name: str.t('vw.ocr_job_name'),
      message: str.t('vw.preparing'),
    );

    String text = '';
    String? error;
    try {
      if (doc.kind == DocKind.image) {
        busy.status(str.t('vw.ocr_running'));
        text = await OcrService.recognizeImageFile(doc.path);
      } else if (doc.kind == DocKind.pdf) {
        text = await OcrService.recognizePdf(
          _pdfDoc!,
          onProgress: (done, total) => busy.status(
            done >= total
                ? str.t('vw.ocr_finishing')
                : str.t('vw.ocr_page', {'n': done + 1, 'total': total}),
            done: done,
            total: total,
          ),
        );
      }
    } catch (e) {
      error = userErrorText(e);
    }
    if (error != null) {
      await busy.failed(error);
    } else {
      await busy.done();
    }
    if (!mounted) return;

    if (error != null) {
      _snack(context.t('vw.ocr_failed', {'error': error}));
      return;
    }
    if (text.isEmpty) {
      _snack(context.t('vw.ocr_none'));
      return;
    }
    _partSetState(() {
      if (doc.kind == DocKind.image) _ocrImageText = text;
      // Taranmış PDF'te metin katmanı boştur → OCR sonucu AI bağlamı olur.
      if (doc.kind == DocKind.pdf && _pdfText.isEmpty) _pdfText = text;
    });
    _showOcrSheet(text);
  }

  void _showOcrSheet(String text) {
    final copiedAll = context.t('vw.copied_all');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(context.t('vw.ocr_text'),
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack(copiedAll);
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(context.t('vw.copy_all')),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: withNavInset(
                      ctx, const EdgeInsets.only(top: 12)),
                  child: SelectableText(text,
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gece modu açıksa çocuğu renk-tersleyen matrisle sarar.
  ///
  /// Matris: R'=255-R, G'=255-G, B'=255-B (alfa aynı). Beyaz kağıt siyah,
  /// siyah yazı beyaz olur — karanlıkta göz yormaz. `Colors.white` yerine
  /// matris kullanılıyor çünkü sayfadaki resim/grafikler de terslenmeli.
  Widget _nightFilter({required Widget child}) {
    if (!_pdfNight) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -1, 0, 0, 0, 255, //
        0, -1, 0, 0, 255, //
        0, 0, -1, 0, 255, //
        0, 0, 0, 1, 0, //
      ]),
      child: child,
    );
  }

  /// Sayfaları [_pdfColumns] sütun hâlinde dizer.
  ///
  /// Sütun genişliği belgenin EN GENİŞ sayfasına göre sabittir; farklı boydaki
  /// sayfalar sütun içinde ortalanır. Böylece sütunlar sayfa sayfa kaymaz
  /// (kayan sütun okumayı zorlaştırır ve kaydırma çubuğunu yanıltır).
  PdfPageLayout _layoutPdfColumns(List<PdfPage> pages, PdfViewerParams params) {
    final cols = _pdfColumns;
    final margin = params.margin;
    var colWidth = 0.0;
    for (final page in pages) {
      colWidth = math.max(colWidth, page.width);
    }

    final layouts = <Rect>[];
    var y = margin;
    var rowHeight = 0.0;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final col = i % cols;
      final x = margin + col * (colWidth + margin);
      layouts.add(Rect.fromLTWH(
        x + (colWidth - page.width) / 2,
        y,
        page.width,
        page.height,
      ));
      rowHeight = math.max(rowHeight, page.height);
      if (col == cols - 1 || i == pages.length - 1) {
        y += rowHeight + margin;
        rowHeight = 0;
      }
    }
    return PdfPageLayout(
      pageLayouts: layouts,
      documentSize: Size(margin + cols * (colWidth + margin), y),
    );
  }

  /// Sütun sayısını değiştirir.
  ///
  /// Ayrıca bir "relayout" çağrısı GEREKMİYOR: pdfrx 1.3.x düzeni her build'de
  /// `_updateLayout` içinde yeniden hesaplayıp eskisiyle karşılaştırıyor
  /// (paket belgesindeki `PdfViewerController.relayout` 2.x API'si). setState
  /// yeterli.
  void _setPdfColumns(int cols) {
    if (cols == _pdfColumns) return;
    _partSetState(() => _pdfColumns = cols);
    // Yeni düzen ölçüldükten SONRA genişliğe sığdır.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitPdfWidth());
  }

  /// Belgeyi **genişliğine sığdırır** — çok sütunlu dizilimin can alıcı yarısı.
  ///
  /// KÖK NEDEN (2026-08-07 kullanıcı: *"2 sütun 4 sütun yapınca oto genişlemeli
  /// alan görülsün"*): sütun sayısı değişince pdfrx yakınlaştırma oranını
  /// OLDUĞU GİBİ bırakıyor. 4 sütunluk düzen bir anda dört kat genişliyor ama
  /// ekranda hâlâ tek sütunluk kadarı görünüyor; kullanıcı "hiçbir şey
  /// değişmedi" ya da "sayfalar kayboldu" diyor. Sığdırma, düzenin tamamını
  /// bir bakışta gösterir.
  ///
  /// Dikey konum korunur (üstteki satır neredeyse orada kalır); yalnız ölçek
  /// değişir. Belge hazır değilse sessizce vazgeçilir.
  Future<void> _fitPdfWidth() async {
    try {
      if (!_pdfController.isReady) return;
      final doc = _pdfController.documentSize;
      final view = _pdfController.viewSize;
      if (doc.width <= 0 || view.width <= 0 || view.height <= 0) return;
      final top = _pdfController.visibleRect.top;
      // Görünüm oranıyla aynı oranda bir dikdörtgen istersek sığdırma
      // genişliği belirler (pdfrx en dar kenara göre ölçekler).
      final height = doc.width * view.height / view.width;
      await _pdfController.goToArea(
        rect: Rect.fromLTWH(0, top, doc.width, height),
      );
    } catch (_) {
      // Belge kapanmış/yeniden yükleniyor olabilir — sığdırma kritik değil.
    }
  }

  /// "Sayfaya git": numara yaz ya da kaydırıcıyı sürükle.
  ///
  /// KÖK NEDEN (2026-07-26 kullanıcı bulgusu: *"8 yazıyorum 2'ye gidiyor"*):
  /// kutu güncel sayfa numarasıyla dolu açılıyordu ve metin SEÇİLİ gelmiyordu.
  /// Kullanıcı 8'e basınca yazı "28" oluyor, bu da aralık dışında kaldığı için
  /// `onChanged` hedefi güncellemiyor, "Git" ise kutuyu değil eski hedefi
  /// okuyordu → 2. sayfa. Şimdi (a) metin seçili açılıyor, (b) "Git" doğrudan
  /// kutudaki sayıyı okuyup sınırlara kısıyor.
  Future<void> _askGoToPage() async {
    final count = _pageCount;
    // Sayfa sayısı yoksa belge daha okunuyor demektir. SESSİZCE vazgeçmek
    // "dokunuyorum hiçbir şey olmuyor" diye görünüyordu (2026-08-07).
    if (count <= 0) {
      _snack(context.t('vw.still_loading'));
      return;
    }
    final page = await PdfPageNavigator.show(
      context,
      document: _pdfDoc,
      current: _pdfPage,
      count: count,
      previous: _pageBeforeJump,
      bookmarks: [
        for (final b in PdfBookmarks.of(widget.doc.path, size: _docSize)) b.page
      ],
      onToggleBookmark: _toggleBookmark,
    );
    if (page == null || !mounted) return;
    await _goToPdfPage(page.clamp(1, count), count);
  }

  /// pdfrx'in güncel sayfa tahmini yerine bizimki (bkz. [currentPdfPage]).
  int? _currentPdfPage(
    Rect visibleRect,
    List<Rect> pageRects,
    PdfViewerController controller,
  ) =>
      currentPdfPage(
        visibleRect: visibleRect,
        pageRects: pageRects,
        preferred: _pdfJumpTarget,
      );

  /// pdfrx'in o an bildirdiği sayfa (bağlı değilse null).
  int? _livePdfPage() {
    try {
      return _pdfController.isReady ? _pdfController.pageNumber : null;
    } catch (_) {
      return null;
    }
  }

  /// Sayfaya gitmeyi **doğrulayarak** yapar ve sonucu söyler.
  ///
  /// Niye tek `goToPage` yetmiyor (2026-07-26 kullanıcı bulgusu: *"ne yazarsam
  /// yazayım sadece 1 sayfa ilerliyor"*): pdfrx hedefe 200 ms'lik bir
  /// animasyonla gidiyor ve bu sırada gelen her yeniden yerleşim
  /// (`_updateLayout` → düzen ya da GÖRÜNÜM BOYU değiştiyse `_goToPage(o anki
  /// sayfa)`) atlayışı yarıda kesip bulunulan yere geri çekebiliyor.
  ///
  /// 2026-08-07 turunda üç ayrı "bazen çalışmıyor" nedeni daha çıktı:
  /// 1. **Klavye:** pencere kapanınca yumuşak klavye de kapanıyor ve görünüm
  ///    yeniden boyutlanıyor → pdfrx tam biz atlarken "o anki sayfaya" geri
  ///    çekiyordu. Artık önce yerleşmesi bekleniyor ([_waitViewerSettled]).
  /// 2. **Bağlantısız denetleyici:** dosyada işlem yapıldıysa (vurgu, imza,
  ///    düzenleme…) belge yeniden okunuyor; o aralıkta `goToPage` FIRLATIYOR
  ///    ve hata yakalanmadığı için ekranda hiçbir şey olmuyordu — kullanıcı
  ///    için "düğme ölü". Artık hazır olması bekleniyor, olmazsa söyleniyor.
  /// 3. **Yanlış ölçü:** varış pdfrx'in tahmini sayfa numarasıyla ölçülüyordu;
  ///    yakınlaştırılmış/çok sütunlu görünümde doğru sayfadayken bile
  ///    tutmuyordu (bkz. [arrivedAtPage]). Artık geometriyle ölçülüyor.
  ///
  /// Sonuç her hâlükârda kullanıcıya söyleniyor: başarılıysa nereye gidildiği,
  /// başarısızsa nerede kalındığı. Sessizce yanlış yerde bırakmak, kullanıcının
  /// "çalışmıyor" deyip nedenini bilememesi demekti.
  Future<void> _goToPdfPage(int target, int total) async {
    if (target != _pdfPage) _pageBeforeJump = _pdfPage;
    // Klavye kapanışı + düzen yerleşmesi bitmeden atlamak boşuna: pdfrx
    // görünüm boyu değişince bulunulan sayfaya geri çekiyor.
    final ready = await _waitViewerSettled();
    if (!mounted) return;
    if (!ready) {
      _snack(context.t('vw.still_loading'));
      return;
    }
    var arrived = false;
    for (var attempt = 0; attempt < 3 && !arrived; attempt++) {
      // İlk deneme animasyonlu (kullanıcı nereye gittiğini görsün); yeniden
      // denerken anlık, yoksa iki animasyon birbirini kesiyor.
      if (!await _tryGoToPage(target, animate: attempt == 0)) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
        continue;
      }
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
      arrived = _arrivedAtPdfPage(target);
    }
    if (!mounted) return;
    if (arrived) {
      // Rozet pdfrx'in tahminiyle değil, gerçekten gidilen sayfayla
      // güncellensin — yoksa "8'e gittim ama altta 7 yazıyor" olurdu.
      // Başarı bildirimi YOK (2026-09-27): rozet zaten yeni sayfayı
      // gösteriyor; "2. sayfa (toplam 3239)" şeridi ekranın altını boşuna
      // kapatıyordu.
      if (_pdfPage != target) _partSetState(() => _pdfPage = target);
    } else {
      _snack(context.t('vw.page_jump_failed_total', {
        'target': target,
        'landed': _livePdfPage() ?? _pdfPage,
        'total': total,
      }));
    }
  }

  /// Tek atlayış denemesi. Denetleyici belgeye bağlı değilse (yeniden yükleme
  /// sürüyor) pdfrx null denetimiyle FIRLATIR — bu yakalanmazsa ekranda hiçbir
  /// şey olmuyor ve düğme bozuk sanılıyordu.
  Future<bool> _tryGoToPage(int target, {required bool animate}) async {
    _pdfJumpTarget = target;
    try {
      await _pdfController.goToPage(
        pageNumber: target,
        duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Görüntüleyici atlamaya hazır mı: belge yüklü, düzen ölçülmüş ve **görünüm
  /// boyu oturmuş**.
  ///
  /// Ölçüt "klavye kapandı" DEĞİL, "klavye artık kımıldamıyor": pencere
  /// kapandıktan sonra odak arama kutusuna geri dönerse klavye açık kalır ve
  /// kapanmasını beklemek boşuna 1 saniye eklerdi. Kritik olan, biz atlarken
  /// görünümün yeniden boyutlanmaması (pdfrx bunu görünce bulunulan sayfaya
  /// geri çeker). En çok ~1,2 sn beklenir.
  Future<bool> _waitViewerSettled() async {
    double? previous;
    for (var i = 0; i < 24; i++) {
      if (!mounted) return false;
      final inset = MediaQuery.viewInsetsOf(context).bottom;
      if (inset == previous && _viewerLaidOut()) return true;
      previous = inset;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    // Klavye hiç durulmadıysa da düzen hazırsa yine deneriz.
    return mounted && _viewerLaidOut();
  }

  /// Belge + düzen + görünüm boyu elimizde mi? (Hepsi pdfrx'te `null!`
  /// erişimi; hazır değilken okumak fırlatır.)
  bool _viewerLaidOut() {
    try {
      if (!_pdfController.isReady) return false;
      return _pdfController.layout.pageLayouts.isNotEmpty &&
          _pdfController.viewSize.width > 0;
    } catch (_) {
      return false;
    }
  }

  /// Hedef sayfa gerçekten ekranda mı (geometriyle — bkz. [arrivedAtPage]).
  /// Ölçemezsek pdfrx'in kendi sayfa numarasına düşülür.
  bool _arrivedAtPdfPage(int target) {
    try {
      final layouts = _pdfController.layout.pageLayouts;
      if (target < 1 || target > layouts.length) return false;
      return arrivedAtPage(
        pageRect: layouts[target - 1],
        visibleRect: _pdfController.visibleRect,
      );
    } catch (_) {
      return _livePdfPage() == target;
    }
  }

  /// Kaydırma çubuğunun topuzu.
  ///
  /// 2026-09-27: eskiden sağ üstte büyük, dolu mavi bir sekmeydi ve alttaki
  /// rozetle AYNI numarayı gösteriyordu (kullanıcının ekran görüntülerinde
  /// "5" iki kez). Şimdi ince, yarı saydam bir tutamaç: yakalanabileceği
  /// biçiminden (⇕) belli, numara küçük.
  Widget _scrollThumb(int? pageNumber) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(14),
          right: Radius.circular(4),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.unfold_more_rounded, size: 16, color: scheme.primary),
          Text(
            '${pageNumber ?? _pdfPage}',
            maxLines: 1,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// PDF açılamadığında gösterilen kart.
  ///
  /// Eskiden pdfrx'in varsayılanı çıkıyordu: mavi zeminde
  /// "PdfException: Failed to load PDF document (FPDF_GetLastError=3)" ve
  /// yığın izi. Kullanıcı ne olduğunu, ne yapabileceğini anlamıyordu.
  Widget _pdfErrorBanner(BuildContext context, Object error,
      StackTrace? stackTrace, PdfDocumentRef documentRef) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    var size = -1;
    try {
      size = File(widget.doc.path).lengthSync();
    } catch (_) {
      // Bilinçli: boyut yalnız hata kartındaki teşhis satırı için; okunamazsa "bilinmiyor" (-1) kalır.
    }
    final canRecover = PdfEditJournal.hasStale(widget.doc.path);
    final reason = size == 0
        ? context.t('vw.pdf_error_empty')
        : context.t('vw.pdf_error_broken');
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.broken_image_outlined,
                    size: 32, color: scheme.onErrorContainer),
              ),
              const SizedBox(height: 16),
              Text(context.t('vw.pdf_error_title'),
                  textAlign: TextAlign.center, style: text.titleMedium),
              const SizedBox(height: 8),
              Text(reason,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (canRecover)
                    FilledButton.icon(
                      onPressed: () async {
                        PdfEditJournal.recover(only: widget.doc.path);
                        await _reloadPdf();
                      },
                      icon: const Icon(Icons.restore_rounded),
                      label: Text(context.t('vw.pdf_error_restore')),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _reloadPdf,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.t('common.retry')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        EntryOpener.openExternally(context, widget.doc.path),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(context.t('fm.open_with_other')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(userErrorText(error),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.outline)),
            ],
          ),
        ),
      ),
    );
  }

  /// PDF sayfa rozeti: dokununca sayfa gezgini, uzun basınca yıldızla.
  Widget _pageBadge() {
    return PdfPageChip(
      page: _pdfPage,
      count: _pageCount,
      bookmarked:
          PdfBookmarks.isMarked(widget.doc.path, _pdfPage, size: _docSize),
      onTap: _askGoToPage,
      onLongPress: () => _toggleBookmark(_pdfPage),
    );
  }

  /// Sayfayı yıldızlar / yıldızını kaldırır.
  Future<bool> _toggleBookmark(int page) async {
    HapticFeedback.selectionClick();
    final now =
        await PdfBookmarks.toggle(widget.doc.path, page, size: _docSize);
    if (!mounted) return now;
    _partSetState(() {});
    _snack(context.t(now ? 'pn.starred' : 'pn.unstarred', {'n': page}));
    return now;
  }

  /// Yıldızlı sayfanın sağ üst köşesindeki kurdele.
  Widget? _bookmarkRibbon(PdfPage page, Rect pageRect) {
    if (!PdfBookmarks.isMarked(widget.doc.path, page.pageNumber,
        size: _docSize)) {
      return null;
    }
    final w = (pageRect.width * 0.045).clamp(12.0, 28.0);
    return Positioned(
      top: 0,
      right: w,
      child: IgnorePointer(
        child: Icon(Icons.bookmark_rounded,
            size: w * 1.6,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)),
      ),
    );
  }
}
