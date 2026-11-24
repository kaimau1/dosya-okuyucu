part of '../viewer_screen.dart';

extension _ViewerScreenShellMenusPart on _ViewerScreenState {
  Widget _buildShell(LoadedDoc doc) {
    return OfficeShell(
      kind: doc.kind,
      title: doc.name,
      dirty: _dirty || _hasUnsaved || (_pro?.session.dirty ?? false),
      tabBar: _findOpen ? _findBar() : null,
      // **Okuma kipi her belgede** (2026-10-28). 2026-10-23'te PDF'te
      // kapatılmıştı: çubuklar çekilirken gövde her karede büyüyor, pdfrx
      // görünüm boyu değişince sayfa başına atlıyordu ("zorla kaydırılıyor").
      // Artık çubuklar gövdenin ÜSTÜNDE kayan katman — gövde boyu sabit
      // (bkz. `OfficeShell`). Arama açıkken çubuklar sabit durur.
      readingBars: _readingBars,
      tapShowsBars: _tapShowsBars,
      // Tam ekranda sistem çubukları zaten gizli (H3.6).
      hideStatusBar: _isPdf && _hideStatusBar && !_fullscreen,
      hideBottomBar: _pdfBarShown && _pro == null,
      hideKindPrefix: _pro != null,
      subtitle: _pro != null
          ? _proStatus(_pro!)
          : _isPdf && _pageCount > 0
              ? context.t('shell.pages', {'n': _pageCount})
              : null,
      // 2026-09-23 tasarım turu: üst çubukta en çok üç simge + "daha fazla".
      // Sayfa düzeni (1/2/4 sütun), görsel yakınlaştırma ve üç ayrı yazı
      // düğmesi (küçült/büyüt/yazı tipi) buradan kalktı: sütunlar ve
      // yakınlaştırma "Daha fazla" sayfasının Görünüm grubunda, yazı ayarları
      // tek bir "Aa" düğmesinin açtığı okuma ayarları sayfasında.
      actions: _pro != null ? _proActions(_pro!) : _viewerTopActions(doc),
      // Konuşma çubuğu belgenin ALTINA eklenmez, üstünde yüzer: eklenince
      // gövdenin boyu değişir, PDF sayfa başına atlardı.
      body: _ttsTotal == 0 && _pro == null
          ? _buildBody(doc)
          : Stack(
              children: [
                Positioned.fill(child: _buildBody(doc)),
                if (_ttsTotal != 0) ReadingFloat(gap: 0, child: _speechBar()),
                // Düzenleme kipi: bağlamsal çubuk / biçim çubuğu gövdenin
                // üstünde yüzer (gövde boyu değişmez — PS4).
                if (_pro != null) ..._proOverlays(_pro!),
              ],
            ),
      // Düzenleme kipinde klavye görüntüleyiciyi küçültmez (PS4).
      resizeForKeyboard: _pro == null,
      // Etiketli eylem çubuğu — artık her belge türünde (2026-07-28 kullanıcı
      // isteği: "alttaki araç çubuğu güzel, diğer word txt gibi şeylerde de
      // olsun"). Ayrıntı: `widgets/doc_action_bar.dart`.
      bottomBar: _editingText
          ? null
          : _pro != null
              ? _proToolBar(_pro!)
              : _actionBar(doc),
      // Dairesel FAB: geniş etiketli (.extended) hâli belgenin sağ alt köşesini
      // kapatıyordu; etiket tooltip'e taşındı.
      // Metin seçiliyken ve yerinde düzenlemede AI düğmesi GİZLİ: seçim/
      // düzenleme çubuğunun sağ ucunun üstüne biniyordu ve "Uygula"ya basan
      // parmak aslında AI sohbetini açıyordu (kullanıcı 2026-09-24:
      // "uygulaya basmak işlevsiz"). Çubukta zaten "AI ile düzelt" var.
      // AI artık YÜZEN düğme değil, alt çubukta bir eylem (2026-11-14,
      // kullanıcı: *"AI düğmesi ile sayfa sayısı üst üste biniyor, AI
      // düğmesini alt panele al"*). Bkz. [_actionBar].
    );
  }

  List<Widget> _viewerTopActions(LoadedDoc doc) {
    final scheme = Theme.of(context).colorScheme;
    ButtonStyle style({bool accent = false}) => IconButton.styleFrom(
          backgroundColor: accent
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh.withValues(alpha: 0.72),
          foregroundColor: accent ? scheme.primary : scheme.onSurface,
          shape: const CircleBorder(),
          side: accent
              ? BorderSide(color: scheme.primary.withValues(alpha: 0.36))
              : BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.45)),
          visualDensity: VisualDensity.compact,
        );
    Widget btn({
      Key? key,
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
      bool accent = false,
      bool? isSelected,
    }) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 2),
          child: IconButton(
            key: key,
            tooltip: tooltip,
            isSelected: isSelected,
            icon: Icon(icon, size: 20),
            style: style(accent: accent),
            onPressed: onPressed,
          ),
        );
    return [
      if (doc.kind == DocKind.pdf) ...[
        if (_hasUnsaved)
          btn(
            tooltip: context.t('vw.save_edits'),
            icon: AppIcons.save,
            accent: true,
            onPressed: _savePendingPdf,
          )
        else if (_pdfIsForm)
          btn(
            key: const ValueKey('pdf-form-action'),
            tooltip: context.t('vw.fill_form'),
            icon: AppIcons.assignment,
            accent: true,
            onPressed: _fillPdfForm,
          )
        else
          btn(
            tooltip: context.t('vw.toc'),
            icon: AppIcons.toc,
            onPressed: _showOutline,
          ),
        if (_wideForSidePanel)
          btn(
            key: const ValueKey('pdf-side-toggle'),
            tooltip: context.t('vw.side_panel'),
            isSelected: _pdfSidePanel,
            accent: _pdfSidePanel,
            icon: AppIcons.thumbnails,
            onPressed: _toggleSidePanel,
          ),
      ],
      if (_isMarkdown)
        btn(
          key: const ValueKey('md-preview-toggle'),
          tooltip: _mdPreview ? context.t('md.edit') : context.t('md.preview'),
          icon: _mdPreview ? AppIcons.edit : AppIcons.hidden,
          accent: _mdPreview,
          onPressed: () => _partSetState(() => _mdPreview = !_mdPreview),
        ),
      if (_textController != null || doc.kind == DocKind.pdf)
        btn(
          tooltip: context.t('vw.find_in_doc_short'),
          isSelected: _findOpen,
          accent: _findOpen,
          icon: _findOpen ? AppIcons.searchOff : AppIcons.search,
          onPressed: _toggleFind,
        ),
      if (doc.kind == DocKind.image)
        btn(
          tooltip: context.t('vw.rotate'),
          icon: AppIcons.rotateRight,
          onPressed: () =>
              _partSetState(() => _imgQuarterTurns = (_imgQuarterTurns + 1) % 4),
        ),
      if (_textController != null || doc.kind == DocKind.pdf)
        btn(
          tooltip: context.t('vw.reading_settings'),
          icon: doc.kind == DocKind.pdf ? AppIcons.tune : AppIcons.textFormat,
          onPressed: doc.kind == DocKind.pdf
              ? _showPdfReadingSettings
              : _showReadingSettings,
        ),
      IconButton(
        tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
        icon: const Icon(AppIcons.more, size: 20),
        style: style(),
        onPressed: () => _showMore(doc),
      ),
    ];
  }

  /// PDF'in üstünde seçim çubuğu açık mı?
  bool get _pdfBarShown =>
      widget.doc.kind == DocKind.pdf && _pdfSelection.trim().isNotEmpty;

  /// **⋮ — ortak dosya levhası** (2026-11-15, kullanıcı: *"sağ üstteki 3
  /// noktaya tıkladım, belgeyi silmek istiyordum, bulamadım… bu kadar iç içe
  /// menü çok fazla"*). Eskiden ⋮ ayrı bir "Daha fazla" ızgarası açıyordu;
  /// taşı/kopyala/SİL onun içindeki "Dosya işlemleri"nin İÇİNDEYDİ (üç kat).
  /// Artık bütün türlerde aynı levha: üstte ortak dosya işleri (Sil dahil),
  /// altında bu türün işleri ayrı renkte. Görünüm ayarları (satır numarası,
  /// kaydırma, gece) "Aa"da; Paylaş, Çevir ve Düzenle alt çubukta.
  void _showMore(LoadedDoc doc) {
    // Metin gibi davranan belgeler: satır kavramı olanlar.
    final isTextLike = doc.kind == DocKind.text ||
        doc.kind == DocKind.word ||
        doc.kind == DocKind.slides;
    final isPdf = doc.kind == DocKind.pdf;
    final isImage = doc.kind == DocKind.image;
    EntryExtraAction act(IconData icon, String key, VoidCallback? onTap,
            {bool? checked}) =>
        EntryExtraAction(
            icon: icon, label: context.t(key), onTap: onTap, checked: checked);
    unawaited(showViewerMenu(context, doc.path, groups: [
      if (isPdf)
        EntryExtraGroup(context.t('dm.page'), [
          // "Sayfaya git" ayrıca arama çubuğunda ve sayfa rozetinde.
          act(AppIcons.numbers, 'vw.goto_page', _askGoToPage),
          if (_pdfIsForm || _hasUnsaved)
            act(AppIcons.toc, 'vw.toc', () => unawaited(_showOutline())),
          act(AppIcons.important, 'pn.star', () => _toggleBookmark(_pdfPage),
              checked: PdfBookmarks.isMarked(widget.doc.path, _pdfPage,
                  size: _docSize)),
          act(AppIcons.rotateLeft, 'vw.rotate_left',
              _pdfBusy ? null : () => _rotateCurrentPage(-1)),
          act(AppIcons.rotateRight, 'vw.rotate_right',
              _pdfBusy ? null : () => _rotateCurrentPage(1)),
        ]),
      if (isImage)
        EntryExtraGroup(context.t('dm.image'), [
          act(AppIcons.zoomIn, 'vw.zoom_in', () => _zoomImg(1.4)),
          act(AppIcons.zoomOut, 'vw.zoom_out', () => _zoomImg(1 / 1.4)),
        ]),
      if (isTextLike)
        EntryExtraGroup(context.t('dm.text'), [
          // **Satıra git** (2026-09-06): uzun kayıt/kod dosyasında "347.
          // satır" demenin tek yolu.
          act(AppIcons.lowPriority, 'vw.goto_line',
              () => unawaited(_askGoToLine())),
          // Satır numarası / kaydırma "Aa"da; Aa'sı olmayan türde burada.
          if (_textController == null) ...[
            act(AppIcons.formatListNumbered, 'vw.line_numbers',
                () => _partSetState(() => _lineNumbers = !_lineNumbers),
                checked: _lineNumbers),
            act(AppIcons.wrapText, 'vw.wrap_on',
                () => _partSetState(() => _wrapLines = !_wrapLines),
                checked: _wrapLines),
          ],
          // **JSON/XML biçimlendirme**: API cevabı, yedek dökümü tek satır.
          if (PrettyFormat.supports(p.extension(doc.path)))
            act(AppIcons.dataObject, 'vw.prettify', _prettify),
          if (_hasText) act(AppIcons.analytics, 'vw.word_count', _showStats),
        ]),
      EntryExtraGroup(context.t('dm.listen'), [
        if (_ttsTotal == 0) act(AppIcons.voice, 'vw.speak', _toggleSpeech),
        // Sesli kitap (2026-10-22): başlıklı bölüm dosyaları, kaydedilir.
        if (canMakeAudiobook(doc.path))
          act(AppIcons.audiobook, 'ab.make', () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AudiobookScreen(path: doc.path)));
          }),
        if (VoiceNote.enabled)
          act(AppIcons.micNone, 'vn.title', () => unawaited(_voiceNote(doc))),
      ]),
      EntryExtraGroup(context.t('dm.convert'), [
        // PDF'te "PDF'e dönüştür" YOK: yazısını alıp yeni bir PDF yapıyordu,
        // taranmış belgede boş sayfa çıkıyordu. Görselde alt çubukta.
        if (!isImage && !isPdf) act(AppIcons.pdf, 'vw.to_pdf', _exportPdf),
        if (isPdf) act(AppIcons.ocr, 'vw.ocr', _runOcr),
        act(AppIcons.slideshow, 'vw.to_slides', _exportSlides),
        if (_hasText && !isTextLike)
          act(AppIcons.analytics, 'vw.word_count', _showStats),
        // Alt çubukta İndir varken Çevir buraya iner (en çok 5 eylem).
        if (showDownloadAction(doc.path))
          act(AppIcons.translate, 'common.translate', _translateDocument),
        if (!isImage) act(AppIcons.print, 'vw.print', _print),
      ]),
    ]));
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
                            onChanged: AppHaptics.slider(_fontSize, (v) => apply(() => _fontSize = v)),
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
                  Material(
                    // Material (Container değil): satırların dokunma dalgası zeminin
                    // altında kalmasın.
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
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
                        // Satır aralığı (Faz 30 kalanı): düz metin ve
                        // kod düzenleyicide; numara şeridi de aynı aralıkla.
                        if (widget.doc.isEditableText)
                          ListTile(
                            leading: const Icon(AppIcons.formatLineSpacing),
                            title: Text(context.t('code.line_spacing')),
                            trailing: SegmentedButton<double>(
                              key: const ValueKey('code-line-spacing'),
                              showSelectedIcon: false,
                              segments: [
                                for (final h in const [1.2, 1.5, 1.8])
                                  ButtonSegment(
                                      value: h,
                                      label: Text(h.toStringAsFixed(1))),
                              ],
                              selected: {_lineHeight},
                              onSelectionChanged: (v) =>
                                  apply(() => _lineHeight = v.first),
                            ),
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
        DocAction(AppIcons.editNote, context.t('common.edit'), _openPdfEditor,
            primary: true),
      ],
      if (isImage) ...[
        DocAction(AppIcons.ocr, context.t('vw.ocr_short'), _runOcr,
            primary: true),
        DocAction(AppIcons.pdf, context.t('vw.to_pdf'), _exportPdf),
      ],
      if (doc.isEditableText) ...[
        DocAction(AppIcons.edit, context.t('common.edit'),
            _textFocus.requestFocus,
            primary: true),
        DocAction(
            AppIcons.save, context.t('common.save'), _dirty ? _save : null),
      ],
      if (!showDownloadAction(widget.doc.path))
        DocAction(AppIcons.translate, context.t('common.translate'),
            _translateDocument),
      DocAction(AppIcons.share, context.t('common.share'), _share),
      if (showDownloadAction(widget.doc.path))
        DocAction(AppIcons.download, context.t('common.download'), _download),
    ]);
  }

  /// **PDF okuma ve görünüm ayarları**: görsel düzen kartları, gece/sepya,
  /// kenar kırpma, otomatik kaydırma ve ekran tercihleri.
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
                padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 8),
                child: Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
          Widget iconBadge(IconData icon, {bool active = false}) => Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: active ? scheme.primary : scheme.onSurfaceVariant,
                ),
              );
          Widget sectionCard(List<Widget> rows) => Material(
                color: scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.58),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 64,
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      rows[i],
                    ],
                  ],
                ),
              );

          final layouts = [
            (1, AppIcons.layoutDetail, context.t('vw.one_column')),
            (2, AppIcons.viewColumn, context.t('vw.two_columns')),
            (4, AppIcons.layoutGrid, context.t('vw.four_columns')),
            (kPdfBookLayout, AppIcons.pdfBook, context.t('pp.book_view')),
          ];

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(AppIcons.tune,
                            size: 20, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.t('vw.reading_settings'),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // E-kitap akış görünümü kartı
                  Material(
                    color: scheme.primaryContainer.withValues(alpha: 0.75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _pdfDoc == null
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              ReaderScreen.open(this.context,
                                  document: _pdfDoc!, title: widget.doc.name);
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(AppIcons.chromeReaderMode,
                                  size: 20, color: scheme.onPrimary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.t('reader.open'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            Icon(AppIcons.chevron,
                                color: scheme.onPrimaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── 1 · Görünüm ve düzen ──
                  label(context.t('pdf.sec_look')),
                  Row(
                    children: [
                      for (var i = 0; i < layouts.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: () {
                            final (val, ico, txt) = layouts[i];
                            final on = _pdfColumns == val;
                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  _setPdfColumns(val);
                                  setSheet(() {});
                                },
                                child: AnimatedContainer(
                                  duration: Motion.of(context, Motion.short),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: on
                                        ? scheme.primaryContainer
                                        : scheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: on
                                          ? scheme.primary
                                          : scheme.outlineVariant
                                              .withValues(alpha: 0.6),
                                      width: on ? 1.7 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        ico,
                                        size: 21,
                                        color: on
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        txt,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: on
                                              ? scheme.onPrimaryContainer
                                              : scheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  sectionCard([
                    SwitchListTile(
                      secondary: iconBadge(AppIcons.dark, active: _pdfNight),
                      title: Text(context.t('vw.night_on')),
                      value: _pdfNight,
                      onChanged: (v) => apply(() => _pdfNight = v),
                    ),
                    if (_isPdf)
                      SwitchListTile(
                        secondary:
                            iconBadge(AppIcons.pdfSepia, active: _pdfSepia),
                        title: Text(context.t('pp.sepia')),
                        subtitle: Text(context.t('pp.sepia_hint')),
                        value: _pdfSepia,
                        onChanged: _pdfNight
                            ? null
                            : (v) => apply(() => _pdfSepia = v),
                      ),
                    if (_isPdf)
                      SwitchListTile(
                        key: const ValueKey('pdf-paged'),
                        secondary:
                            iconBadge(AppIcons.pdfFitPage, active: _pdfPaged),
                        title: Text(context.t('pp.paged')),
                        subtitle: Text(context.t(_pdfColumns == 1
                            ? 'pp.paged_hint'
                            : 'pp.crop_one_column')),
                        value: _pdfPaged,
                        onChanged: _pdfColumns != 1
                            ? null
                            : (v) {
                                _setPdfPaged(v);
                                setSheet(() {});
                              },
                      ),
                    if (_isPdf)
                      SwitchListTile(
                        key: const ValueKey('pdf-margin-crop'),
                        secondary: iconBadge(AppIcons.cropFree,
                            active: _pdfCrop != null),
                        title: Text(context.t('pp.crop_margins')),
                        subtitle: Text(context.t(_pdfColumns == 1
                            ? 'pp.crop_margins_hint'
                            : 'pp.crop_one_column')),
                        value: _pdfCrop != null,
                        onChanged: _pdfColumns != 1 ||
                                _pdfCropBusy ||
                                _pdfDoc == null
                            ? null
                            : (v) {
                                final sheet = context;
                                unawaited(_setMarginCrop(v).then((_) {
                                  if (sheet.mounted) setSheet(() {});
                                }));
                                setSheet(() {});
                              },
                      ),
                  ]),
                  // ── 2 · Okuma konforu ──
                  if (_isPdf) ...[
                    label(context.t('pdf.sec_comfort')),
                    sectionCard([
                      SwitchListTile(
                        secondary: iconBadge(AppIcons.pdfPanLock,
                            active: _pdfScrollLock),
                        title: Text(context.t('pp.scroll_lock')),
                        subtitle: Text(context.t('pp.scroll_lock_hint')),
                        value: _pdfScrollLock,
                        onChanged: (v) => apply(() => _pdfScrollLock = v),
                      ),
                      SwitchListTile(
                        key: const ValueKey('pdf-keep-awake'),
                        secondary: iconBadge(AppIcons.lightMode,
                            active: _keepAwake),
                        title: Text(context.t('pp.keep_awake')),
                        subtitle: Text(context.t('pp.keep_awake_hint')),
                        value: _keepAwake,
                        onChanged: (v) {
                          _setKeepAwake(v);
                          setSheet(() {});
                        },
                      ),
                      SwitchListTile(
                        key: const ValueKey('pdf-volume-keys'),
                        secondary: iconBadge(AppIcons.volumeUp,
                            active: _volumeKeys),
                        title: Text(context.t('pp.volume_keys')),
                        subtitle: Text(context.t('pp.volume_keys_hint')),
                        value: _volumeKeys,
                        onChanged: (v) {
                          _setVolumeKeys(v);
                          setSheet(() {});
                        },
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            leading: iconBadge(AppIcons.autoScroll,
                                active: _autoScroll > 0),
                            title: Text(context.t('pp.auto_scroll')),
                            subtitle: Text(context.t('pp.auto_scroll_hint')),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: SegmentedButton<int>(
                              key: const ValueKey('pdf-auto-scroll'),
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                    value: 0,
                                    label: Text(context.t('pp.as_off'))),
                                ButtonSegment(
                                    value: 1,
                                    label: Text(context.t('pp.as_slow'))),
                                ButtonSegment(
                                    value: 2,
                                    label: Text(context.t('pp.as_mid'))),
                                ButtonSegment(
                                    value: 3,
                                    label: Text(context.t('pp.as_fast'))),
                              ],
                              selected: {_autoScroll},
                              onSelectionChanged: (v) {
                                _setAutoScroll(v.first);
                                setSheet(() {});
                                if (v.first > 0) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      ListTile(
                        leading: iconBadge(AppIcons.pdfNotes),
                        title: Text(context.t('pp.notes_booklet')),
                        subtitle: Text(context.t('pp.notes_booklet_sub')),
                        trailing: Icon(AppIcons.chevron,
                            color: scheme.onSurfaceVariant),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_exportNotesBooklet());
                        },
                      ),
                    ]),
                  ],
                  // ── 3 · Ekran ve kayıt ──
                  label(context.t('pdf.sec_screen')),
                  sectionCard([
                    SwitchListTile(
                      secondary: iconBadge(AppIcons.bookmarkOutline,
                          active: app.resumePosition),
                      title: Text(context.t('pdfm.resume')),
                      value: app.resumePosition,
                      onChanged: (v) async {
                        await app.setResumePosition(v);
                        setSheet(() {});
                      },
                    ),
                    if (_isPdf)
                      SwitchListTile(
                        key: const ValueKey('pdf-hide-status'),
                        secondary: iconBadge(AppIcons.fitScreen,
                            active: _hideStatusBar),
                        title: Text(context.t('pp.hide_status')),
                        subtitle: Text(context.t('pp.hide_status_hint')),
                        value: _hideStatusBar,
                        onChanged: _fullscreen
                            ? null
                            : (v) {
                                _setHideStatusBar(v);
                                setSheet(() {});
                              },
                      ),
                    SwitchListTile(
                      key: const ValueKey('reading-fullscreen'),
                      secondary: iconBadge(AppIcons.fullscreen,
                          active: _fullscreen),
                      title: Text(context.t('vw.fullscreen')),
                      subtitle: Text(context.t('vw.fullscreen_hint')),
                      value: _fullscreen,
                      onChanged: (v) {
                        _setFullscreen(v);
                        setSheet(() {});
                      },
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
