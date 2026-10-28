part of '../word_editor_screen.dart';

extension _WordEditorScreenShellPart on _WordEditorScreenState {
  Widget _buildShell(DocxEditor? editor, Uint8List? bytes) {
    return OfficeShell(
      kind: DocKind.word,
      title: widget.name,
      session: _session,
      // Okuma kipi yalnız düzenleme KAPALIYKEN: yazarken çubuk kaybolmamalı.
      readingBars: _editing || _plainMode ? null : _readingBars,
      subtitle:
          _pageCount > 0 ? context.t('shell.pages', {'n': _pageCount}) : null,
      // Üst çubukta yalnız ALTTA KARŞILIĞI OLMAYANLAR kalır (2026-07-28
      // kullanıcı isteği: "bazı işlevler hem altta hem üstte var, gerek yok").
      // İstisna: düzenleme sırasında alt çubuk gizlendiği için Kaydet burada.
      actions: [
        // Geri al / yinele: yapısal işlemler (paragraf ekle/sil) için —
        // paragraf silmenin geri dönüşü yoktu.
        IconButton(
          tooltip: context.t('word.undo'),
          icon: const Icon(AppIcons.undo),
          onPressed: !_canUndo ? null : _undoAny,
        ),
        IconButton(
          tooltip: context.t('word.redo'),
          icon: const Icon(AppIcons.redo),
          onPressed: !_canRedo ? null : _redoAny,
        ),
        // Belge içi arama: slaytta ve Excel'de zaten vardı, Word'de yoktu.
        if (!_plainMode)
          IconButton(
            tooltip: context.t('common.search'),
            isSelected: _finding,
            icon: const Icon(AppIcons.search),
            onPressed: editor == null ? null : _toggleFind,
          ),
        if (_editing)
          IconButton(
            tooltip: context.t('common.save'),
            icon: const Icon(AppIcons.save),
            onPressed: editor == null ? null : _save,
          ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
              case 'plain':
                _partSetState(() {
                  _plainMode = true;
                  _editing = false;
                });
                break;
              case 'pageedit':
                _toggleEdit();
                break;
              case 'lab':
                final ed = _editor;
                if (ed == null) break;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LabWordEditorScreen(
                    title: widget.name,
                    paragraphs: [for (final p in ed.paragraphs) p.text],
                  ),
                ));
                break;
              case 'page':
                if (_dirty) await _save();
                // Yedek editördeki değişiklikler görünüme taşınsın.
                _partSetState(() {
                  _viewBytes = _editor?.viewBytes();
                  _plainMode = false;
                });
                break;
            }
          },
          itemBuilder: (_) => [
            // K19 (b), Faz 23: sayfa görünümü salt okunur önizleme; Word
            // biçimleri Mobil görünümde. WebView'da sayfa üzerinde düzenleme
            // (21a köprüsü) yalnız geliştirici denemesi bayrağıyla yedek.
            if (!_plainMode &&
                !_editing &&
                context.read<AppState>().labWordEditor)
              PopupMenuItem(
                  value: 'pageedit', child: Text(context.t('word.edit_page'))),
            if (context.read<AppState>().labWordEditor)
              PopupMenuItem(value: 'lab', child: Text(context.t('lab.word_open'))),
            _plainMode
                ? PopupMenuItem(
                    value: 'page', child: Text(context.t('word.page_view')))
                : PopupMenuItem(
                    value: 'plain', child: Text(context.t('word.text_editor'))),
          ],
        ),
      ],
      // Biçim çubuğu artık ÜSTTE değil (W7): klavye açıkken klavyenin hemen
      // üstünde tek satır hızlı çubuk, kapalıyken tam şerit — EditorChrome.
      // Etiketli eylem çubuğu (2026-07-28 kullanıcı isteği — PDF'teki gibi).
      // Düzenleme sırasında gizli: o sırada klavye + biçim çubuğu zaten
      // ekranın yarısını alıyor.
      bottomBar: _editing
          ? null
          : DocActionBar([
              if (!_plainMode)
                // Faz 22 (K18 = b-ii): "Düzenle" Mobil görünüm editörünü açar;
                // sayfa üzerinde (WebView) düzenleme Faz 23'ten beri yalnız
                // geliştirici bayrağıyla ⋮ menüsünde (K19 b).
                DocAction(AppIcons.edit, context.t('common.edit'),
                    editor == null ? null : _openMobileEditor),
              if (!_plainMode)
                DocAction(
                  _flow ? AppIcons.newWord : AppIcons.device,
                  context.t(_flow ? 'word.page_layout' : 'word.mobile_flow'),
                  editor == null ? null : _toggleFlow,
                ),
              DocAction(AppIcons.save, context.t('common.save'),
                  editor == null ? null : _save),
              DocAction(AppIcons.share, context.t('common.share'),
                  editor == null ? null : _export),
              // Başka uygulamadan açıldıysa dosya özel önbellekte: doğrudan
              // İndirilenler'e (bkz. [SaveToDownloads]).
              if (showDownloadAction(widget.path))
                DocAction(AppIcons.download, context.t('common.download'),
                    editor == null ? null : _download),
              DocAction(
                AppIcons.translate,
                context.t('common.translate'),
                () => TranslateFlow.run(context, widget.plainText,
                    title: widget.name),
              ),
              // Seçili metin işleri: canlı görünümde seçim WebView tarafında
              // yaşıyor, `sendSelectionText` köprüsüyle alınıyor. Yedek metin
              // editöründe seçim Flutter'da olduğu için bu yol kapalı.
              if (!_plainMode)
                DocAction(
                  AppIcons.organize,
                  context.t('word.rewrite_selection'),
                  editor == null ? null : _rewriteSelection,
                ),
              if (!_plainMode)
                DocAction(
                  AppIcons.gTranslate,
                  context.t('word.translate_selection'),
                  editor == null ? null : _translateSelection,
                ),
            ]),
      body: withDraftBanner(restore: _restoreDraft, _wordChrome(_error != null
          ? Center(
              child: Text(context.t('common.open_failed', {'error': _error})))
          : editor == null || bytes == null
              ? const Center(child: CircularProgressIndicator())
              : _plainMode
                  ? _buildPage(editor)
                  : Stack(
                      children: [
                        // Arama çubuğu sayfanın ÜSTÜNDE yüzer: `tabBar`
                        // yuvası düzenlemedeki biçim çubuğunun, arama ise
                        // düzenleme kapalıyken de gerekli.
                        DocxView(
                          key: _viewKey,
                          bytes: bytes,
                          rightToLeft: editor.rightToLeft,
                          onLive: _onLive,
                          onHistory: (u, r) {
                            if (u == _viewCanUndo && r == _viewCanRedo) return;
                            _partSetState(() {
                              _viewCanUndo = u;
                              _viewCanRedo = r;
                            });
                          },
                          onSelection: _onSelection,
                          onAlign: _onAlignChanged,
                          onListStyle: _onListStyle,
                          onScroll: (dy, top) {
                            if (!_editing) {
                              _readingBars.scrolled(dy, atTop: top);
                            }
                          },
                          onParagraphCount: _onParagraphCount,
                          onFindCount: _onFindCount,
                          onReplacedCount: _onReplaced,
                          onSelectionText: _onSelectionText,
                          onPageCount: (n) {
                            if (n != _pageCount) _partSetState(() => _pageCount = n);
                          },
                          onPage: (n) {
                            if (n != _page) _partSetState(() => _page = n);
                          },
                          onStatus: (ok) {
                            if (!ok && mounted) {
                              _partSetState(() {
                                _plainMode = true;
                                _editing = false;
                              });
                            }
                            // Kullanıcı akışa geçmişken belge yeniden
                            // çizilirse tercihi korunur (JS köprüsü çizimden
                            // önce çağrılamıyor).
                            if (ok && _flow) {
                              _viewKey.currentState?.setFlow(true);
                            }
                            // Resim ekle/sil sonrası yeniden çizim bitti:
                            // düzenleme kaldığı yerden sürer.
                            if (ok && _resumeEditing) {
                              _resumeEditing = false;
                              _viewKey.currentState?.setEditing(true,
                                  spellcheck: EditPrefs.wordSpellcheck);
                              _partSetState(() => _editing = true);
                            }
                          },
                        ),
                        // Sayfa rozeti (2026-08-01 isteği: toplam sayfa sayısı
                        // her belgede görünsün) — dokununca "sayfaya git".
                        // Düzenleme sırasında gizli: klavye+çubuk zaten yer
                        // kapıyor.
                        //
                        // Alt şeridin paylaşımı: SOL = zoom düğmeleri,
                        // ORTA = sayfa rozeti, SAĞ = AI düğmesi (FAB).
                        // Üçü de köşeye yığılırsa üst üste biniyor.
                        //
                        // Okuma kipinde alt çubukla birlikte iner/kalkar
                        // (2026-10-28; zoom düğmeleriyle aynı şerit).
                        if (_pageCount > 0 && !_editing)
                          Builder(
                            builder: (context) =>
                                ReadingChrome.maybeOf(context) == null
                                    ? Positioned(
                                        left: 0,
                                        right: 0,
                                        // Zoom düğmeleriyle aynı sistem çubuğu
                                        // payı (bkz. DocxView'daki not).
                                        bottom: 12 +
                                            MediaQuery.paddingOf(context)
                                                .bottom,
                                        child: Center(child: _pageBadge()),
                                      )
                                    : ReadingFloat(
                                        gap: 12,
                                        child: Center(child: _pageBadge()),
                                      ),
                          ),
                        // Okuma kipinde üst çubuk belgenin üstüne biner:
                        // arama çubuğu onun altında durur.
                        if (_finding)
                          Builder(
                            builder: (context) => Positioned(
                                top: ReadingChrome.insetsOf(context).top,
                                left: 0,
                                right: 0,
                                child: _findBar()),
                          ),
                      ],
                    ))),
      // Klavye/biçim çubuğu varken FAB araya girmesin.
      fab: _editing
          ? null
          : DocAiButton(
              kind: DocKind.word,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(
                  fileContext: widget.plainText,
                  fileName: widget.name,
                ),
              )),
              tooltip: context.t('common.ai'),
            ),
    );
  }

  /// "Sayfa 3 / 12" rozeti — dokununca [_showGoToPage].
  Widget _pageBadge() {
    return DocPill(
      text: context.t('word.page_of', {'n': _page, 'total': _pageCount}),
      icon: AppIcons.unfoldMore,
      onTap: _showGoToPage,
    );
  }

  /// M365 mobil tarzı biçim çubuğu: yazı tipi/punto + B / I / U + bitti.
  /// Word'ün biçim şeridi. Simgeler ve düzen **Excel/Slayt ile ortak**
  /// (`OfficeRibbon` + `OfficeIcons`, 2026-08-07): aynı iş üç uygulamada da
  /// aynı simge. (2026-09-23: üst çubuk artık nötr — `onBrand` kalktı.)
  /// Düzenleme kabuğu (Faz 20 çekirdeği): klavye açık → hızlı çubuk,
  /// kapalı → tam şerit, Aa → klavye yüksekliğinde biçim paneli.
  Widget _wordChrome(Widget body) => EditorChrome(
        editing: _liveEditing,
        body: body,
        panel: _panel,
        accessory: _accessoryBar(),
        ribbon: _formatBar(),
        panelTabs: _panelTabs(),
      );

  void _fmt(String cmd) => _viewKey.currentState?.format(cmd);

  /// Hizalamayı sırayla çevirir: sola → ortala → sağa → iki yana.
  void _cycleAlign() {
    const order = ['left', 'center', 'right', 'both'];
    const cmds = {
      'left': 'justifyLeft',
      'center': 'justifyCenter',
      'right': 'justifyRight',
      'both': 'justifyFull',
    };
    final next = order[(order.indexOf(_selAlign) + 1) % order.length];
    _fmt(cmds[next]!);
  }

  IconData get _alignIcon => switch (_selAlign) {
        'center' => OfficeIcons.alignCenter,
        'right' => OfficeIcons.alignRight,
        'both' => OfficeIcons.alignJustify,
        _ => OfficeIcons.alignLeft,
      };

  Widget _accessoryBar() => KeyboardAccessoryBar(
        onFormat: _panel.open,
        onHideKeyboard: () =>
            SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
        items: [
          AccessoryItem(
              icon: AppIcons.check,
              tooltip: context.t('word.done'),
              onPressed: _toggleEdit),
          AccessoryItem(
              icon: AppIcons.undo,
              tooltip: context.t('word.undo'),
              onPressed: _canUndo ? _undoAny : null),
          AccessoryItem(
              icon: OfficeIcons.bold,
              tooltip: context.t('common.bold'),
              selected: _selB,
              onPressed: () => _fmt('bold')),
          AccessoryItem(
              icon: OfficeIcons.italic,
              tooltip: context.t('common.italic'),
              selected: _selI,
              onPressed: () => _fmt('italic')),
          AccessoryItem(
              icon: OfficeIcons.underline,
              tooltip: context.t('common.underline'),
              selected: _selU,
              onPressed: () => _fmt('underline')),
          AccessoryItem(
              icon: OfficeIcons.bullets,
              tooltip: context.t('word.bullets'),
              selected: _selList == 'bullet',
              onPressed: () => _viewKey.currentState?.setListStyle('bullet')),
          AccessoryItem(
              icon: OfficeIcons.numbering,
              tooltip: context.t('word.numbering'),
              selected: _selList == 'number',
              onPressed: () => _viewKey.currentState?.setListStyle('number')),
          AccessoryItem(
              icon: _alignIcon,
              tooltip: context.t('word.align_cycle'),
              onPressed: _cycleAlign),
          AccessoryItem(
              icon: OfficeIcons.strike,
              tooltip: context.t('common.strike'),
              selected: _selS,
              onPressed: () => _fmt('strikeThrough')),
          AccessoryItem(
              icon: AppIcons.addPhoto,
              tooltip: context.t('word.insert_image'),
              onPressed: _insertImage),
        ],
      );

  /// "Aa" paneli: Yazı (yazı tipi, punto, biçim, renk) · Paragraf
  /// (hizalama, liste).
  List<FormatPanelTab> _panelTabs() => [
        FormatPanelTab(
          label: context.t('edit.tab_text'),
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [_fontMenu(), _sizeMenu()]),
              const SizedBox(height: 12),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final (cmd, icon, on, tip) in [
                  ('bold', OfficeIcons.bold, _selB, 'common.bold'),
                  ('italic', OfficeIcons.italic, _selI, 'common.italic'),
                  ('underline', OfficeIcons.underline, _selU, 'common.underline'),
                  ('strikeThrough', OfficeIcons.strike, _selS, 'common.strike'),
                ])
                  RibbonButton(icon, context.t(tip),
                      active: on, onTap: () => _fmt(cmd)),
              ]),
              const SizedBox(height: 12),
              _swatches(_WordEditorScreenState._textColorPalette,
                  (hex) => _viewKey.currentState?.setTextColor(hex),
                  context.t('word.text_color')),
              const SizedBox(height: 8),
              _swatches(_WordEditorScreenState._highlightPalette,
                  (hex) => _viewKey.currentState?.setHighlight(hex),
                  context.t('word.highlight')),
            ],
          ),
        ),
        FormatPanelTab(
          label: context.t('edit.tab_paragraph'),
          builder: (_) => Wrap(spacing: 4, runSpacing: 4, children: [
            for (final (cmd, icon, v, tip) in [
              ('justifyLeft', OfficeIcons.alignLeft, 'left', 'common.align_left'),
              ('justifyCenter', OfficeIcons.alignCenter, 'center', 'common.align_center'),
              ('justifyRight', OfficeIcons.alignRight, 'right', 'common.align_right'),
              ('justifyFull', OfficeIcons.alignJustify, 'both', 'common.align_justify'),
            ])
              RibbonButton(icon, context.t(tip),
                  active: _selAlign == v, onTap: () => _fmt(cmd)),
            RibbonButton(OfficeIcons.bullets, context.t('word.bullets'),
                active: _selList == 'bullet',
                onTap: () => _viewKey.currentState?.setListStyle('bullet')),
            RibbonButton(OfficeIcons.numbering, context.t('word.numbering'),
                active: _selList == 'number',
                onTap: () => _viewKey.currentState?.setListStyle('number')),
          ]),
        ),
      ];

  /// Renk paleti satırı (panel): dokun = uygula, ⌀ = kaldır.
  Widget _swatches(
      List<String> palette, void Function(String?) onPick, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final hex in palette)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onPick(hex),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(int.parse('FF$hex', radix: 16)),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
          ),
        IconButton(
          tooltip: context.t('excel.color_none'),
          icon: const Icon(AppIcons.formatColorReset),
          onPressed: () => onPick(null),
        ),
      ]),
    );
  }

  Widget _formatBar() {
    Widget btn(String cmd, IconData icon, bool active, String tip) =>
        RibbonButton(icon, tip,
            active: active, onTap: () => _viewKey.currentState?.format(cmd));

    return SizedBox(
      height: OfficeRibbon.heightFor(1),
      child: OfficeRibbon(
        tabs: [
          RibbonTab('', [
            _fontMenu(),
            _sizeMenu(),
            const RibbonSep(),
            btn('bold', OfficeIcons.bold, _selB, context.t('common.bold')),
            btn('italic', OfficeIcons.italic, _selI,
                context.t('common.italic')),
            btn('underline', OfficeIcons.underline, _selU,
                context.t('common.underline')),
            btn('strikeThrough', OfficeIcons.strike, _selS,
                context.t('common.strike')),
            const RibbonSep(),
            btn('justifyLeft', OfficeIcons.alignLeft, _selAlign == 'left',
                context.t('common.align_left')),
            btn('justifyCenter', OfficeIcons.alignCenter, _selAlign == 'center',
                context.t('common.align_center')),
            btn('justifyRight', OfficeIcons.alignRight, _selAlign == 'right',
                context.t('common.align_right')),
            btn('justifyFull', OfficeIcons.alignJustify, _selAlign == 'both',
                context.t('common.align_justify')),
            const RibbonSep(),
            _colorMenu(
              OfficeIcons.textColor,
              context.t('word.text_color'),
              _WordEditorScreenState._textColorPalette,
              (hex) => _viewKey.currentState?.setTextColor(hex),
            ),
            _colorMenu(
              OfficeIcons.highlight,
              context.t('word.highlight'),
              _WordEditorScreenState._highlightPalette,
              (hex) => _viewKey.currentState?.setHighlight(hex),
            ),
            const RibbonSep(),
            _listBtn(OfficeIcons.bullets, context.t('word.bullets'), 'bullet'),
            _listBtn(
                OfficeIcons.numbering, context.t('word.numbering'), 'number'),
            const RibbonSep(),
            // Resim (Faz 9 / Y1): imlecin altına satır içi resim; imleçteki
            // paragrafın resimlerini sil.
            RibbonButton(AppIcons.addPhoto,
                context.t('word.insert_image'),
                onTap: _insertImage),
            RibbonButton(AppIcons.hideImage,
                context.t('word.delete_image'),
                onTap: _deleteImage),
          ]),
        ],
        // "Bitti" kaydırmanın DIŞINDA kalır — dar ekranda düzenlemeden çıkış
        // düğmesi kaybolmamalı.
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _toggleEdit,
            icon: const Icon(AppIcons.check, size: 18),
            label: Text(context.t('word.done')),
          ),
        ),
      ),
    );
  }

  /// Renk seçici (yazı rengi / vurgu). Renkler biçim çubuğunun kendi
  /// paletinden; `null` seçeneği rengi kaldırır.
  Widget _colorMenu(IconData icon, String tip, List<String> palette,
      void Function(String?) onPick) {
    return PopupMenuButton<String>(
      tooltip: tip,
      icon: Icon(icon, size: 20),
      onSelected: (v) => onPick(v == 'none' ? null : v),
      itemBuilder: (_) => [
        for (final hex in palette)
          PopupMenuItem(
            value: hex,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(int.parse('FF$hex', radix: 16)),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 10),
                Text('#$hex'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'none',
          child: Row(
            children: [
              const Icon(AppIcons.formatColorReset, size: 20),
              const SizedBox(width: 10),
              Text(context.t('excel.color_none')),
            ],
          ),
        ),
      ],
    );
  }

  /// Madde işareti / numaralandırma düğmesi. Aynı biçime tekrar basmak
  /// listeyi kaldırır (Word'de olduğu gibi).
  Widget _listBtn(IconData icon, String tip, String kind) => RibbonButton(
        icon,
        tip,
        active: _selList == kind,
        onTap: () => _viewKey.currentState?.setListStyle(kind),
      );

  /// Belge içi bul/değiştir çubuğu — Excel ve slayttakiyle aynı düzen.
  Widget _findBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DocFindBar(
            controller: _findCtrl,
            hint: context.t('common.search'),
            countLabel: _findCtrl.text.isEmpty
                ? ''
                : (_hitCount == 0
                    ? context.t('find.none')
                    : '${_hitIndex + 1}/$_hitCount'),
            onSubmitted: _runFind,
            onChanged: (v) {
              if (v.isEmpty) _onFindCount(0);
            },
            onPrev: _hitCount == 0 ? null : () => _stepHit(-1),
            onNext: _hitCount == 0 ? null : () => _stepHit(1),
            onClose: _toggleFind,
            trailing: [
              IconButton(
                tooltip: context.t('excel.replace'),
                visualDensity: VisualDensity.compact,
                isSelected: _replacing,
                icon: const Icon(AppIcons.findReplace),
                onPressed: () => _partSetState(() => _replacing = !_replacing),
              ),
            ],
          ),
          if (_replacing)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replaceCtrl,
                      decoration: DocFindBar.decoration(
                        context,
                        hint: context.t('excel.replace_with'),
                        icon: AppIcons.findReplace,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _replaceCurrent,
                    child: Text(context.t('excel.replace')),
                  ),
                  TextButton(
                    onPressed: _replaceAll,
                    child: Text(context.t('excel.replace_all')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Yazı tipi seçici. Seçim **paragrafa** uygulanır (bkz. viewer.html:
  /// seçimi span'la sarmak `<p>` eşlemesini bozabiliyor).
  Widget _fontMenu() {
    final current = _WordEditorScreenState._fonts.contains(_selFont) ? _selFont : null;
    return PopupMenuButton<String>(
      tooltip: context.t('word.font_family'),
      onSelected: (v) => _viewKey.currentState?.setFontFamily(v),
      itemBuilder: (_) => [
        for (final f in _WordEditorScreenState._fonts)
          CheckedPopupMenuItem(
            value: f,
            checked: f == current,
            child: Text(f, style: TextStyle(fontFamily: f)),
          ),
      ],
      child: RibbonChip(
        // Bilinmeyen (listede olmayan) bir font geldiyse adı yine gösterilir:
        // "hangi fonttayım" bilgisi seçebilmekten bağımsız olarak değerli.
        label: _selFont.isEmpty ? context.t('word.font_family') : _selFont,
        icon: OfficeIcons.fontFamily,
        tooltip: context.t('word.font_family'),
      ),
    );
  }

  Widget _sizeMenu() {
    final shown = _selSize > 0 ? _selSize : null;
    return PopupMenuButton<double>(
      tooltip: context.t('word.font_size'),
      onSelected: (v) => _viewKey.currentState?.setFontSize(v),
      itemBuilder: (_) => [
        for (final s in _WordEditorScreenState._sizes)
          CheckedPopupMenuItem(
            value: s,
            // Dosyadan gelen punto ara bir değer olabilir (11.5); eşitlik
            // yerine yakınlık aranır, yoksa hiçbiri işaretli görünmezdi.
            checked: shown != null && (shown - s).abs() < 0.25,
            child: Text('${s.round()}'),
          ),
      ],
      child: RibbonChip(
        label: shown == null ? '—' : '${shown.round()}',
        icon: OfficeIcons.fontSize,
        tooltip: context.t('word.font_size'),
      ),
    );
  }
}
