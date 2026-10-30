part of '../viewer_screen.dart';

extension _ViewerScreenShellMenusPart on _ViewerScreenState {
  Widget _buildShell(LoadedDoc doc, bool hasApiKey) {
    return OfficeShell(
      kind: doc.kind,
      title: doc.name,
      dirty: _dirty || _hasUnsaved,
      tabBar: _findOpen ? _findBar() : null,
      // **Okuma kipi her belgede** (2026-10-28). 2026-10-23'te PDF'te
      // kapatılmıştı: çubuklar çekilirken gövde her karede büyüyor, pdfrx
      // görünüm boyu değişince sayfa başına atlıyordu ("zorla kaydırılıyor").
      // Artık çubuklar gövdenin ÜSTÜNDE kayan katman — gövde boyu sabit
      // (bkz. `OfficeShell`). Arama açıkken çubuklar sabit durur.
      readingBars: _readingBars,
      subtitle: _isPdf && _pageCount > 0
          ? context.t('shell.pages', {'n': _pageCount})
          : null,
      // 2026-09-23 tasarım turu: üst çubukta en çok üç simge + "daha fazla".
      // Sayfa düzeni (1/2/4 sütun), görsel yakınlaştırma ve üç ayrı yazı
      // düğmesi (küçült/büyüt/yazı tipi) buradan kalktı: sütunlar ve
      // yakınlaştırma "Daha fazla" sayfasının Görünüm grubunda, yazı ayarları
      // tek bir "Aa" düğmesinin açtığı okuma ayarları sayfasında.
      actions: [
        if (doc.kind == DocKind.pdf) ...[
          IconButton(
            tooltip: context.t('vw.toc'),
            icon: const Icon(AppIcons.toc),
            onPressed: _showOutline,
          ),
          if (_hasUnsaved)
            IconButton(
              tooltip: context.t('vw.save_edits'),
              icon: const Icon(AppIcons.save),
              onPressed: _savePendingPdf,
            ),
        ],
        if (_isMarkdown)
          IconButton(
            key: const ValueKey('md-preview-toggle'),
            tooltip: _mdPreview ? context.t('md.edit') : context.t('md.preview'),
            icon: Icon(_mdPreview ? AppIcons.edit : AppIcons.hidden),
            onPressed: () => _partSetState(() => _mdPreview = !_mdPreview),
          ),
        if (_textController != null || doc.kind == DocKind.pdf)
          IconButton(
            tooltip: context.t('vw.find_in_doc_short'),
            isSelected: _findOpen,
            icon: Icon(_findOpen ? AppIcons.searchOff : AppIcons.search),
            onPressed: _toggleFind,
          ),
        if (doc.kind == DocKind.image)
          IconButton(
            tooltip: context.t('vw.rotate'),
            icon: const Icon(AppIcons.rotateRight),
            onPressed: () =>
                _partSetState(() => _imgQuarterTurns = (_imgQuarterTurns + 1) % 4),
          ),
        if (_textController != null || doc.kind == DocKind.pdf)
          IconButton(
            tooltip: context.t('vw.reading_settings'),
            icon: const Icon(AppIcons.textFormat),
            onPressed: doc.kind == DocKind.pdf
                ? _showPdfReadingSettings
                : _showReadingSettings,
          ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
          icon: const Icon(AppIcons.more),
          onPressed: () => _showMore(doc),
        ),
      ],
      // Konuşma çubuğu belgenin ALTINA eklenmez, üstünde yüzer: eklenince
      // gövdenin boyu değişir, PDF sayfa başına atlardı.
      body: _ttsTotal == 0
          ? _buildBody(doc)
          : Stack(
              children: [
                Positioned.fill(child: _buildBody(doc)),
                ReadingFloat(gap: 0, child: _speechBar()),
              ],
            ),
      // Etiketli eylem çubuğu — artık her belge türünde (2026-07-28 kullanıcı
      // isteği: "alttaki araç çubuğu güzel, diğer word txt gibi şeylerde de
      // olsun"). Ayrıntı: `widgets/doc_action_bar.dart`.
      bottomBar: _actionBar(doc),
      // Dairesel FAB: geniş etiketli (.extended) hâli belgenin sağ alt köşesini
      // kapatıyordu; etiket tooltip'e taşındı.
      // Metin seçiliyken ve yerinde düzenlemede AI düğmesi GİZLİ: seçim/
      // düzenleme çubuğunun sağ ucunun üstüne biniyordu ve "Uygula"ya basan
      // parmak aslında AI sohbetini açıyordu (kullanıcı 2026-09-24:
      // "uygulaya basmak işlevsiz"). Çubukta zaten "AI ile düzelt" var.
      fab: _pdfBarShown
          ? null
          : DocAiButton(
              kind: doc.kind,
              onPressed: _openChat,
              tooltip:
                  hasApiKey ? context.t('common.ai') : context.t('aikey.button_off'),
            ),
    );
  }

  /// PDF'in üstünde seçim çubuğu açık mı?
  bool get _pdfBarShown =>
      widget.doc.kind == DocKind.pdf && _pdfSelection.trim().isNotEmpty;

  /// **"Daha fazla" sayfası** — eskiden 15 satırlık düz bir açılır menüydü
  /// (simgesiz, grupsuz; "Gece modu" ile "Gece modunu kapat" gibi aynı
  /// ayarın iki ayrı metni). Artık konusuna göre gruplu, simgeli ızgara;
  /// açık/kapalı ayarlar onay işaretiyle durumunu gösterir.
  void _showMore(LoadedDoc doc) {
    // Metin gibi davranan belgeler: satır kavramı olanlar.
    final isTextLike = doc.kind == DocKind.text ||
        doc.kind == DocKind.word ||
        doc.kind == DocKind.slides;
    final isPdf = doc.kind == DocKind.pdf;
    final isImage = doc.kind == DocKind.image;
    DocMoreSheet.show(
      context,
      header: DocTitle(
        kind: doc.kind,
        title: doc.name,
        subtitle: isPdf && _pageCount > 0
            ? context.t('shell.pages', {'n': _pageCount})
            : null,
      ),
      [
        if (isPdf)
          DocMoreGroup(context.t('dm.view'), [
            // "Sayfaya git" üç yerde birden: burada (etiketli, bulunabilir),
            // arama çubuğunda ve alttaki sayfa rozetine dokununca (2026-07-26:
            // "nerede olduğu anlaşılmıyor, kişiler bulamaz").
            DocMoreItem(AppIcons.numbers, context.t('vw.goto_page'), _askGoToPage),
            // Bu sayfayı yıldızla (2026-09-27) — rozete basılı tutmakla aynı.
            DocMoreItem(
              AppIcons.important,
              context.t('pn.star'),
              () => _toggleBookmark(_pdfPage),
              selected: PdfBookmarks.isMarked(widget.doc.path, _pdfPage,
                  size: _docSize),
            ),
            // Okuma görünümü, gece modu ve sütun düzeni Faz 8'de tek "Aa"
            // levhasında (bkz. [_showPdfReadingSettings]).
          ]),
        if (isPdf)
          DocMoreGroup(context.t('dm.page'), [
            DocMoreItem(AppIcons.rotateLeft, context.t('vw.rotate_left'),
                _pdfBusy ? null : () => _rotateCurrentPage(-1)),
            DocMoreItem(AppIcons.rotateRight, context.t('vw.rotate_right'),
                _pdfBusy ? null : () => _rotateCurrentPage(1)),
          ]),
        // "Düzenle ve imzala" grubu Faz 8'de kalktı: AI düzenleme, imza ve
        // form artık alt çubuktaki TEK "Düzenle" kapısında (bkz.
        // [showPdfEditModes]). Metin tanıma (OCR) düzenleme değil, dönüşüm.
        if (isImage)
          DocMoreGroup(context.t('dm.view'), [
            DocMoreItem(
                AppIcons.zoomIn, context.t('vw.zoom_in'), () => _zoomImg(1.4)),
            DocMoreItem(AppIcons.zoomOut, context.t('vw.zoom_out'),
                () => _zoomImg(1 / 1.4)),
            DocMoreItem(
                AppIcons.rotateRight,
                context.t('vw.rotate'),
                () => _partSetState(
                    () => _imgQuarterTurns = (_imgQuarterTurns + 1) % 4)),
          ]),
        if (isTextLike)
          DocMoreGroup(context.t('dm.text'), [
            // **Satıra git / satır numaraları** (2026-09-06 denetim turu):
            // uzun bir kayıt ya da kod dosyasında "347. satır" demenin bir
            // yolu yoktu; tek çare parmakla kaydırmaktı.
            DocMoreItem(AppIcons.lowPriority, context.t('vw.goto_line'),
                () => unawaited(_askGoToLine())),
            DocMoreItem(
                AppIcons.formatListNumbered,
                context.t('vw.line_numbers'),
                () => _partSetState(() => _lineNumbers = !_lineNumbers),
                selected: _lineNumbers),
            DocMoreItem(AppIcons.wrapText, context.t('vw.wrap_on'),
                () => _partSetState(() => _wrapLines = !_wrapLines),
                selected: _wrapLines),
            // **JSON/XML biçimlendirme**: bu dosyalar gerçek hayatta tek
            // satır geliyor (API cevabı, yedek dökümü).
            if (PrettyFormat.supports(p.extension(doc.path)))
              DocMoreItem(
                  AppIcons.dataObject, context.t('vw.prettify'), _prettify),
            if (_hasText)
              DocMoreItem(AppIcons.analytics, context.t('vw.word_count'),
                  _showStats),
          ]),
        DocMoreGroup(context.t('dm.convert'), [
          if (_ttsTotal == 0)
            DocMoreItem(AppIcons.voice, context.t('vw.speak'),
                _toggleSpeech),
          // Sesli kitap (2026-10-22): başlıklı bölüm dosyaları, kaydedilir.
          if (canMakeAudiobook(doc.path))
            DocMoreItem(AppIcons.audiobook, context.t('ab.make'), () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AudiobookScreen(path: doc.path)));
            }),
          // "Çevir" burada YOK: alt eylem çubuğunda etiketli duruyor
          // (2026-07-31 — "tek butonla" isteği).
          if (!isImage)
            DocMoreItem(AppIcons.pdf, context.t('vw.to_pdf'),
                _exportPdf),
          if (isPdf)
            DocMoreItem(
                AppIcons.ocr, context.t('vw.ocr'), _runOcr),
          DocMoreItem(AppIcons.slideshow, context.t('vw.to_slides'),
              _exportSlides),
          if (_hasText && !isTextLike)
            DocMoreItem(AppIcons.analytics, context.t('vw.word_count'),
                _showStats),
        ]),
        // Belgeyi okurken "bunu Önemli Dosyalar'a taşıyayım" demek için
        // görüntüleyiciyi kapatıp dosyayı listede aramak gerekmesin
        // (2026-07-29: "her türlü dosyada bu olmalı").
        DocMoreGroup(context.t('dm.file'), [
          DocMoreItem(AppIcons.move, context.t('vw.file_ops'),
              _fileActions),
          // Telefonun ana ekranına kısayol (2026-09-27).
          if (Platform.isAndroid)
            DocMoreItem(
              AppIcons.homeShortcut,
              context.t('ea.shortcut'),
              () => addHomeShortcut(
                  context, FsEntry.fromEntity(File(widget.doc.path))),
            ),
        ]),
      ],
    );
  }

  /// **Okuma ayarları ("Aa")** — yazı boyutu, yazı tipi, satır numarası ve
  /// satır kaydırma tek sayfada, ANINDA önizlemeli (Kindle/Apple Books dili).
  ///
  /// Eskiden üst çubukta üç ayrı simge vardı (küçült, büyüt, yazı tipi
  /// menüsü) ve boyutun kaç olduğu hiçbir yerde yazmıyordu.
  void _showReadingSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      // Sayfa açıkken belge görünür kalsın: değişiklik arkada canlı izlenir.
      barrierColor: AppColors.barrierLight,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          void apply(VoidCallback f) {
            _partSetState(f);
            setSheet(() {});
          }

          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          Widget label(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.t('vw.reading_settings'),
                      style: theme.textTheme.titleLarge),
                  label(context.t('vw.text_size')),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: context.t('vw.text_smaller'),
                          icon: const Icon(OfficeIcons.fontShrink),
                          onPressed: _fontSize <= 10
                              ? null
                              : () => apply(() => _fontSize =
                                  (_fontSize - 1).clamp(10.0, 32.0)),
                        ),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 10,
                            max: 32,
                            divisions: 22,
                            label: '${_fontSize.round()}',
                            onChanged: (v) => apply(() => _fontSize = v),
                          ),
                        ),
                        IconButton(
                          tooltip: context.t('vw.text_bigger'),
                          icon: const Icon(OfficeIcons.fontGrow),
                          onPressed: _fontSize >= 32
                              ? null
                              : () => apply(() => _fontSize =
                                  (_fontSize + 1).clamp(10.0, 32.0)),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${_fontSize.round()}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  label(context.t('word.font_family')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in _ViewerScreenState._readerFonts)
                        ChoiceChip(
                          label: Text(
                            f.$2.isEmpty ? context.t('vw.font_default') : f.$1,
                            style: TextStyle(
                                fontFamily: f.$2.isEmpty ? null : f.$2),
                          ),
                          selected: (_fontFamily ?? '') == f.$2,
                          showCheckmark: false,
                          onSelected: (_) => apply(
                              () => _fontFamily = f.$2.isEmpty ? null : f.$2),
                        ),
                    ],
                  ),
                  label(context.t('vw.layout')),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(AppIcons.formatListNumbered),
                          title: Text(context.t('vw.line_numbers')),
                          value: _lineNumbers,
                          onChanged: (v) => apply(() => _lineNumbers = v),
                        ),
                        SwitchListTile(
                          secondary: const Icon(AppIcons.wrapText),
                          title: Text(context.t('vw.wrap_on')),
                          value: _wrapLines,
                          onChanged: (v) => apply(() => _wrapLines = v),
                        ),
                        // Girinti genişliği (Faz 30 kalanı): ⇥ ve
                        // otomatik girinti bu kadar boşluk yazar.
                        if (_isCodeDoc && widget.doc.isEditableText)
                          ListTile(
                            leading: const Icon(AppIcons.formatIndentIncrease),
                            title: Text(context.t('code.tab_width')),
                            trailing: SegmentedButton<int>(
                              key: const ValueKey('code-tab-width'),
                              showSelectedIcon: false,
                              segments: [
                                for (final n in const [2, 4, 8])
                                  ButtonSegment(value: n, label: Text('$n')),
                              ],
                              selected: {_tabWidth},
                              onSelectionChanged: (v) =>
                                  apply(() => _tabWidth = v.first),
                            ),
                          ),
                        SwitchListTile(
                          key: const ValueKey('reading-fullscreen'),
                          secondary: const Icon(AppIcons.fullscreen),
                          title: Text(context.t('vw.fullscreen')),
                          subtitle: Text(context.t('vw.fullscreen_hint')),
                          value: _fullscreen,
                          onChanged: (v) {
                            _setFullscreen(v);
                            setSheet(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Türüne göre dolan eylem çubuğu; ortak son iki düğme **Paylaş · Yazdır**.
  ///
  /// Etiketli, çünkü kullanıcı ne yapacağını ekrandan okuyabilmeli.
  /// "Yazdır" görselde YOK: `_print` metni PDF'e çevirip basar, görselin metni
  /// olmadığı için boş sayfa çıkardı — orada iş "PDF'e dönüştür".
  ///
  /// **Çevir** her türde var (2026-07-31): eskiden yalnız taşma menüsündeydi ve
  /// taranmış belgede önce OCR istiyordu; artık düğme tek başına yetiyor.
  Widget _actionBar(LoadedDoc doc) {
    final isImage = doc.kind == DocKind.image;
    return DocActionBar([
      if (doc.kind == DocKind.pdf) ...[
        // Faz 8 — tek düzenleme kapısı: Metin · Kalem · İmza · Form ·
        // Sayfalar · AI (bkz. [showPdfEditModes]).
        DocAction(AppIcons.editNote, context.t('common.edit'),
            _showPdfEditModes),
        DocAction(AppIcons.construction, context.t('vw.tools'), _openPdfTools),
      ],
      if (isImage) ...[
        DocAction(AppIcons.ocr, context.t('vw.ocr_short'),
            _runOcr),
        DocAction(
            AppIcons.pdf, context.t('vw.to_pdf'), _exportPdf),
      ],
      if (doc.isEditableText) ...[
        DocAction(AppIcons.edit, context.t('common.edit'),
            _textFocus.requestFocus),
        DocAction(AppIcons.save, context.t('common.save'), _save),
      ],
      DocAction(
          AppIcons.translate, context.t('common.translate'), _translateDocument),
      DocAction(AppIcons.share, context.t('common.share'), _share),
      // Başka uygulamadan açılan dosya özel önbellekte duruyor; paylaş
      // dolambacı olmadan İndirilenler'e (bkz. [SaveToDownloads]).
      if (showDownloadAction(widget.doc.path))
        DocAction(
            AppIcons.download, context.t('common.download'), _download),
      if (!isImage)
        DocAction(AppIcons.print, context.t('vw.print'), _print),
    ]);
  }

  /// Alt çubuktaki "Düzenle": kipi sorar, seçilen ekranı açar.
  void _showPdfEditModes() {
    showPdfEditModes(context, (mode) {
      switch (mode) {
        case PdfEditMode.text:
          _openPdfEditor();
        case PdfEditMode.pen:
          _openInk();
        case PdfEditMode.sign:
          _signPdf();
        case PdfEditMode.form:
          _fillPdfForm();
        case PdfEditMode.pages:
          _openPdfTools();
        case PdfEditMode.ai:
          _aiEditPdf();
      }
    });
  }

  /// **PDF'in "Aa" levhası** (Faz 8): okuma görünümü, gece modu, sütun düzeni
  /// ve "kaldığım yerden aç" tek yerde. Eskiden bunlar "Daha fazla"
  /// sayfasının Görünüm grubuna dağılmıştı; metin belgelerindeki "Aa" ile
  /// aynı yerde, aynı simgeyle duruyor.
  void _showPdfReadingSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      barrierColor: AppColors.barrierLight,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          void apply(VoidCallback f) {
            _partSetState(f);
            setSheet(() {});
          }

          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final app = context.read<AppState>();
          Widget label(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.t('vw.reading_settings'),
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  // E-kitap okuma görünümü (2026-08-06): taranmış PDF'te
                  // bile sayfanın METNİ akar.
                  FilledButton.tonalIcon(
                    onPressed: _pdfDoc == null
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            ReaderScreen.open(this.context,
                                document: _pdfDoc!, title: widget.doc.name);
                          },
                    icon: const Icon(AppIcons.chromeReaderMode),
                    label: Text(context.t('reader.open')),
                  ),
                  label(context.t('vw.layout')),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                          value: 1,
                          icon: const Icon(AppIcons.layoutDetail),
                          label: Text(context.t('vw.one_column'))),
                      ButtonSegment(
                          value: 2,
                          icon: const Icon(AppIcons.viewColumn),
                          label: Text(context.t('vw.two_columns'))),
                      ButtonSegment(
                          value: 4,
                          icon: const Icon(AppIcons.layoutGrid),
                          label: Text(context.t('vw.four_columns'))),
                    ],
                    selected: {_pdfColumns},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) {
                      _setPdfColumns(v.first);
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(AppIcons.dark),
                          title: Text(context.t('vw.night_on')),
                          value: _pdfNight,
                          onChanged: (v) => apply(() => _pdfNight = v),
                        ),
                        SwitchListTile(
                          secondary: const Icon(AppIcons.bookmarkOutline),
                          title: Text(context.t('pdfm.resume')),
                          value: app.resumePosition,
                          onChanged: (v) async {
                            await app.setResumePosition(v);
                            setSheet(() {});
                          },
                        ),
                        // Girinti genişliği (Faz 30 kalanı): ⇥ ve
                        // otomatik girinti bu kadar boşluk yazar.
                        if (_isCodeDoc && widget.doc.isEditableText)
                          ListTile(
                            leading: const Icon(AppIcons.formatIndentIncrease),
                            title: Text(context.t('code.tab_width')),
                            trailing: SegmentedButton<int>(
                              key: const ValueKey('code-tab-width'),
                              showSelectedIcon: false,
                              segments: [
                                for (final n in const [2, 4, 8])
                                  ButtonSegment(value: n, label: Text('$n')),
                              ],
                              selected: {_tabWidth},
                              onSelectionChanged: (v) =>
                                  apply(() => _tabWidth = v.first),
                            ),
                          ),
                        SwitchListTile(
                          key: const ValueKey('reading-fullscreen'),
                          secondary: const Icon(AppIcons.fullscreen),
                          title: Text(context.t('vw.fullscreen')),
                          subtitle: Text(context.t('vw.fullscreen_hint')),
                          value: _fullscreen,
                          onChanged: (v) {
                            _setFullscreen(v);
                            setSheet(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
