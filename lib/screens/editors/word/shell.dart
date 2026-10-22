part of '../word_editor_screen.dart';

extension _WordEditorScreenShellPart on _WordEditorScreenState {
  Widget _buildShell(DocxEditor? editor, Uint8List? bytes) {
    return OfficeShell(
      kind: DocKind.word,
      title: widget.name,
      dirty: _dirty,
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
          onPressed: !_undo.canUndo ? null : _undoStep,
        ),
        IconButton(
          tooltip: context.t('word.redo'),
          icon: const Icon(AppIcons.redo),
          onPressed: !_undo.canRedo ? null : _redoStep,
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
              case 'page':
                if (_dirty) await _save();
                _partSetState(() => _plainMode = false);
                break;
            }
          },
          itemBuilder: (_) => [
            _plainMode
                ? PopupMenuItem(
                    value: 'page', child: Text(context.t('word.page_view')))
                : PopupMenuItem(
                    value: 'plain', child: Text(context.t('word.text_editor'))),
          ],
        ),
      ],
      tabBar: _editing ? _formatBar() : null,
      // Etiketli eylem çubuğu (2026-07-28 kullanıcı isteği — PDF'teki gibi).
      // Düzenleme sırasında gizli: o sırada klavye + biçim çubuğu zaten
      // ekranın yarısını alıyor.
      bottomBar: _editing
          ? null
          : DocActionBar([
              if (!_plainMode)
                DocAction(AppIcons.edit, context.t('common.edit'),
                    editor == null ? null : _toggleEdit),
              if (!_plainMode)
                DocAction(
                  _flow ? Icons.description_rounded : Icons.smartphone_rounded,
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
                  Icons.auto_fix_high_rounded,
                  context.t('word.rewrite_selection'),
                  editor == null ? null : _rewriteSelection,
                ),
              if (!_plainMode)
                DocAction(
                  Icons.g_translate_rounded,
                  context.t('word.translate_selection'),
                  editor == null ? null : _translateSelection,
                ),
            ]),
      body: _error != null
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
                          onEdited: _onEdited,
                          onSelection: _onSelection,
                          onAlign: _onAlignChanged,
                          onListStyle: _onListStyle,
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
                              _viewKey.currentState?.setEditing(true);
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
                        if (_pageCount > 0 && !_editing)
                          Positioned(
                            left: 0,
                            right: 0,
                            // Zoom düğmeleriyle aynı sistem çubuğu payı
                            // (bkz. DocxView'daki not) — rozet de aynı şeritte.
                            bottom: 12 + MediaQuery.paddingOf(context).bottom,
                            child: Center(child: _pageBadge()),
                          ),
                        if (_finding)
                          Positioned(
                              top: 0, left: 0, right: 0, child: _findBar()),
                      ],
                    ),
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
      icon: Icons.unfold_more_rounded,
      onTap: _showGoToPage,
    );
  }

  /// M365 mobil tarzı biçim çubuğu: yazı tipi/punto + B / I / U + bitti.
  /// Word'ün biçim şeridi. Simgeler ve düzen **Excel/Slayt ile ortak**
  /// (`OfficeRibbon` + `OfficeIcons`, 2026-08-07): aynı iş üç uygulamada da
  /// aynı simge. (2026-09-23: üst çubuk artık nötr — `onBrand` kalktı.)
  PreferredSizeWidget _formatBar() {
    Widget btn(String cmd, IconData icon, bool active, String tip) =>
        RibbonButton(icon, tip,
            active: active, onTap: () => _viewKey.currentState?.format(cmd));

    return PreferredSize(
      preferredSize: Size.fromHeight(OfficeRibbon.heightFor(1)),
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
            const RibbonSep(),
            btn('justifyLeft', OfficeIcons.alignLeft, false,
                context.t('common.align_left')),
            btn('justifyCenter', OfficeIcons.alignCenter, false,
                context.t('common.align_center')),
            btn('justifyRight', OfficeIcons.alignRight, false,
                context.t('common.align_right')),
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
            RibbonButton(Icons.add_photo_alternate_rounded,
                context.t('word.insert_image'),
                onTap: _insertImage),
            RibbonButton(Icons.hide_image_rounded,
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
              const Icon(Icons.format_color_reset_rounded, size: 20),
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
                icon: const Icon(Icons.find_replace_rounded),
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
                        icon: Icons.find_replace_rounded,
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
