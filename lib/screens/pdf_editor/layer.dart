part of '../pdf_editor_screen.dart';

/// Faz 31 (2026-10-30): Office editörleriyle aynı kabuk (şerit + klavye üstü
/// çubuk), paragrafın kendi kutusunda düzenleme, kaydedilene kadar nesne
/// olarak yaşayan yazı/imza/görsel ve sayfa üstünde form doldurma.
extension _PdfEditorScreenLayerPart on _PdfEditorScreenState {
  // ── Kabuk ─────────────────────────────────────────────────────────────────

  /// Alt şerit: sekmeler = kipler (Metin · Görsel · İmzala · Form · Filigran ·
  /// Sayfa), altında o kipin işleri.
  Widget _ribbon() {
    final editBar = _editBar();
    if (editBar != null) return editBar;
    final busy = _busy;
    final scanned = _scannedPages.contains(_page) && _scannedLines.isNotEmpty;
    return OfficeRibbon(
      compact: true,
      selectedTab: _EditMode.values.indexOf(_mode),
      onTabChanged: (i) => _setMode(_EditMode.values[i]),
      tabs: [
        RibbonTab(context.t('pe.mode_text'), [
          RibbonChip(
            key: const ValueKey('pe-add-text'),
            icon: _placingText ? AppIcons.close : AppIcons.postAdd,
            label: context.t(_placingText ? 'common.cancel' : 'pe.add_text'),
            tooltip: context.t('pe.add_text'),
            onTap: busy
                ? null
                : () => _partSetState(() => _placingText = !_placingText),
          ),
          if (scanned) ...[
            RibbonChip(
              icon: AppIcons.organize,
              label: context.t('pe.fix_page'),
              tooltip: context.t('pe.fix_page'),
              onTap: busy ? null : () => _fixScannedPage(withAi: false),
            ),
            RibbonChip(
              icon: AppIcons.ai,
              label: context.t('pe.fix_page_ai'),
              tooltip: context.t('pe.fix_page_ai'),
              onTap: busy ? null : () => _fixScannedPage(withAi: true),
            ),
          ],
        ]),
        RibbonTab(context.t('pe.mode_image'), [
          RibbonChip(
            icon: AppIcons.addPhoto,
            label: context.t('pe.add_image'),
            tooltip: context.t('pe.add_image'),
            onTap: busy ? null : _addImage,
          ),
        ]),
        RibbonTab(context.t('pe.mode_sign'), [
          RibbonChip(
            key: const ValueKey('pe-add-signature'),
            icon: AppIcons.gesture,
            label: context.t('pe.add_signature'),
            tooltip: context.t('pe.add_signature'),
            onTap: busy ? null : () => _addSignature(),
          ),
          RibbonChip(
            icon: AppIcons.shortText,
            label: context.t('pe.add_initials'),
            tooltip: context.t('pe.add_initials'),
            onTap: busy ? null : () => _addSignature(initials: true),
          ),
          RibbonChip(
            icon: AppIcons.draw,
            label: context.t('pe.redraw_signature'),
            tooltip: context.t('pe.redraw_signature'),
            onTap: busy ? null : () => _addSignature(redraw: true),
          ),
        ]),
        RibbonTab(context.t('pe.mode_form'), [
          RibbonChip(
            icon: AppIcons.keyboardArrowLeft,
            label: context.t('pe.field_prev'),
            tooltip: context.t('pe.field_prev'),
            onTap: _formFields?.isNotEmpty == true ? () => _stepField(-1) : null,
          ),
          RibbonChip(
            icon: AppIcons.keyboardArrowRight,
            label: context.t('pe.field_next'),
            tooltip: context.t('pe.field_next'),
            onTap: _formFields?.isNotEmpty == true ? () => _stepField(1) : null,
          ),
        ]),
        RibbonTab(context.t('pe.mode_watermark'), const []),
        RibbonTab(context.t('pe.mode_page'), [
          RibbonChip(
            icon: AppIcons.rotate90DegreesCcw,
            label: context.t('pe.rot_left'),
            tooltip: context.t('pe.rot_left'),
            onTap: busy ? null : () => _rotate(-1),
          ),
          RibbonChip(
            icon: AppIcons.rotate,
            label: context.t('pe.rot_right'),
            tooltip: context.t('pe.rot_right'),
            onTap: busy ? null : () => _rotate(1),
          ),
        ]),
      ],
    );
  }

  /// Klavyenin hemen üstündeki çubuk — ne düzenleniyorsa onun işleri.
  Widget? _accessory() => _editBar();

  /// Düzenleme sürerken şerit yerine de bu çubuk durur (klavye inince
  /// kullanıcı "Bitti"yi kaybetmesin).
  Widget? _editBar() {
    if (_inlineIndex != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _inlineStatus(),
          KeyboardAccessoryBar(
            onHideKeyboard: () => _inlineFocus.unfocus(),
            items: [
              AccessoryItem(
                key: const ValueKey('inline-done'),
                icon: AppIcons.check,
                tooltip: context.t('common.done'),
                onPressed: _busy ? null : _commitInline,
              ),
              AccessoryItem(
                icon: AppIcons.close,
                tooltip: context.t('common.cancel'),
                onPressed: _cancelInline,
              ),
              AccessoryItem(
                icon: AppIcons.textDecrease,
                tooltip: context.t('pe.font_smaller'),
                onPressed: () => _nudgeInlineSize(-0.5),
              ),
              AccessoryItem(
                icon: AppIcons.textIncrease,
                tooltip: context.t('pe.font_bigger'),
                onPressed: () => _nudgeInlineSize(0.5),
              ),
              AccessoryItem(
                key: const ValueKey('inline-overwrite'),
                text: context.t('pe.overwrite'),
                tooltip: context.t('pe.overwrite_help'),
                onPressed: _busy ? null : _overwriteInline,
              ),
              AccessoryItem(
                icon: AppIcons.editNote,
                tooltip: context.t('pe.in_dialog'),
                onPressed: () {
                  final i = _inlineIndex!;
                  _cancelInline();
                  _editParagraphInDialog(i);
                },
              ),
            ],
          ),
        ],
      );
    }
    final editing = _layer.byId(_editingPending);
    if (editing != null) {
      return KeyboardAccessoryBar(
        onHideKeyboard: () => _pendingFocus.unfocus(),
        items: [
          AccessoryItem(
            key: const ValueKey('pending-done'),
            icon: AppIcons.check,
            tooltip: context.t('common.done'),
            onPressed: _finishPendingText,
          ),
          ..._textStyleItems(editing),
        ],
      );
    }
    if (_activeField != null) {
      return KeyboardAccessoryBar(
        onHideKeyboard: () => _fieldFocus.unfocus(),
        items: [
          AccessoryItem(
            icon: AppIcons.keyboardArrowLeft,
            tooltip: context.t('pe.field_prev'),
            onPressed: () => _stepField(-1),
          ),
          AccessoryItem(
            icon: AppIcons.keyboardArrowRight,
            tooltip: context.t('pe.field_next'),
            onPressed: () => _stepField(1),
          ),
          AccessoryItem(
            key: const ValueKey('field-done'),
            icon: AppIcons.check,
            tooltip: context.t('common.done'),
            onPressed: () => _commitField(close: true),
          ),
        ],
      );
    }
    return null;
  }

  /// Satır içi durum: ret gerekçesi + "Üstüne yaz" önerisi, ya da "sığıyor".
  Widget _inlineStatus() {
    final scheme = Theme.of(context).colorScheme;
    final refusal = _inlineRefusal;
    if (refusal == null && !_inlineChecking && !_inlineFits) {
      return const SizedBox.shrink();
    }
    final error = refusal != null;
    return Material(
      key: const ValueKey('inline-status'),
      color: error ? scheme.errorContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
        child: Row(
          children: [
            if (_inlineChecking)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(error ? AppIcons.info : AppIcons.check,
                  size: 16,
                  color: error ? scheme.onErrorContainer : scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                refusal ??
                    context.t(_inlineChecking
                        ? 'pe.inline_checking'
                        : 'pe.inline_fits'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.type.compact.copyWith(
                    color: error ? scheme.onErrorContainer : null),
              ),
            ),
            if (error)
              TextButton(
                onPressed: _busy ? null : _overwriteInline,
                child: Text(context.t('pe.overwrite')),
              ),
          ],
        ),
      ),
    );
  }

  void _setMode(_EditMode mode) {
    _closeEditors();
    _partSetState(() {
      _mode = mode;
      _selectedObject = null;
      _selectedPending = null;
      _placingText = false;
    });
    if (mode == _EditMode.background && _background.isEmpty) {
      _loadBackground();
    }
    if (mode == _EditMode.form && _formFields == null) _loadForm();
  }

  /// Açık düzenleme alanlarını kapatır (yerinde paragraf vazgeçilir; yazı
  /// nesnesi ve form alanı yazılanı korur).
  void _closeEditors() {
    if (_inlineIndex != null) _cancelInline();
    if (_editingPending != null) _finishPendingText();
    if (_activeField != null) _commitField(close: true);
  }

  // ── Yerinde paragraf düzenleme ────────────────────────────────────────────

  /// Paragrafa dokunuldu: kendi kutusunda düzenleme açılır ve ekran ona
  /// yakınlaşır (yazı okunur boya gelsin).
  void _editParagraph(int index) {
    if (index < 0 || index >= _outline.paragraphs.length || _busy) return;
    _closeEditors();
    final paragraph = _outline.paragraphs[index];
    _inlineCtrl?.dispose();
    final ctrl = TextEditingController(text: paragraph.text);
    ctrl.addListener(_scheduleInlineCheck);
    _partSetState(() {
      _inlineIndex = index;
      _inlineCtrl = ctrl;
      _inlineSize = null;
      _inlineRefusal = null;
      _inlineFits = false;
      _inlineChecking = false;
    });
    _zoomToParagraph(index);
  }

  /// Paragrafı görünür ve okunur boyda gösterir: hedef, ekranda ~18 px yazı.
  void _zoomToParagraph(int index) {
    // Klavye açılıp görünüm küçüldükten SONRA (yoksa paragraf klavyenin
    // altında kalır).
    Future.delayed(Motion.long, () {
      if (!mounted || _inlineIndex != index) return;
      try {
        final par = _outline.paragraphs[index];
        final pt = paragraphPointSize(par);
        final onScreen = (pt > 0 ? pt : 11) * _pageScale;
        final zoom = (18 / onScreen).clamp(1.0, 4.0);
        final rect = _controller.calcRectForRectInsidePage(
          pageNumber: _page,
          rect: PdfRect(par.left, par.top, par.right, par.bottom),
        );
        _controller.goTo(_controller.calcMatrixForRect(rect,
            zoomMax: math.max(zoom, _controller.currentZoom), margin: 16));
      } catch (_) {
        // Görüntüleyici hazır değilse yakınlaşma kritik değil.
      }
    });
  }

  List<Widget> _inlineLayer(PdfPage page, Size pageSize) {
    final index = _inlineIndex!;
    final ctrl = _inlineCtrl;
    if (index >= _outline.paragraphs.length || ctrl == null) return const [];
    final par = _outline.paragraphs[index];
    final rect = PdfRect(par.left, par.top, par.right, par.bottom)
        .toRect(page: page, scaledPageSize: pageSize);
    final scale = pageSize.width / page.width;
    final pt = _inlineSize ?? paragraphPointSize(par);
    return [
      PdfInlineParagraphEditor(
        rect: rect,
        controller: ctrl,
        focusNode: _inlineFocus,
        pointSize: (pt > 0 ? pt : 11) * scale,
        refused: _inlineRefusal != null,
      ),
    ];
  }

  void _nudgeInlineSize(double delta) {
    final index = _inlineIndex;
    if (index == null) return;
    final current =
        _inlineSize ?? paragraphPointSize(_outline.paragraphs[index]);
    _partSetState(() => _inlineSize =
        ((current + delta).clamp(2.0, 200.0) * 10).roundToDouble() / 10);
    _scheduleInlineCheck();
  }

  /// Her duraklamada (300 ms) yeniden dizgi arka planda denenir: ret varsa
  /// gerekçe hemen satır içinde görünür, kullanıcı "Bitti"ye basıp beklemez.
  void _scheduleInlineCheck() {
    _inlineTimer?.cancel();
    _inlineTimer = Timer(Motion.long, _checkInline);
  }

  Future<void> _checkInline() async {
    final index = _inlineIndex;
    final ctrl = _inlineCtrl;
    if (index == null || ctrl == null || !mounted) return;
    final seq = ++_inlineSeq;
    final text = ctrl.text.trim();
    final size = _inlineSize;
    _partSetState(() => _inlineChecking = true);
    String? refusal;
    var fits = false;
    try {
      await PdfPageEdit.replaceParagraphInBackground(
        _history!.bytes,
        pageIndex: _page - 1,
        paragraphIndex: index,
        newText: text,
        pointSize: size,
      );
      fits = true;
    } on PdfParagraphRefused catch (e) {
      refusal = e.message;
    } on PdfPageRefused catch (e) {
      // "Metin değişmedi" ret değil — kullanıcı daha bir şey yazmadı.
      if (text != _outline.paragraphs[index].text.trim() || size != null) {
        refusal = e.message;
      }
    } catch (e) {
      refusal = userErrorText(e);
    }
    if (!mounted || seq != _inlineSeq || _inlineIndex != index) return;
    _partSetState(() {
      _inlineChecking = false;
      _inlineRefusal = refusal;
      _inlineFits = fits;
    });
  }

  void _cancelInline() {
    _inlineTimer?.cancel();
    _inlineSeq++;
    final ctrl = _inlineCtrl;
    _partSetState(() {
      _inlineIndex = null;
      _inlineCtrl = null;
      _inlineRefusal = null;
      _inlineFits = false;
      _inlineChecking = false;
    });
    // Alan ağaçtan çıktıktan sonra bırakılır.
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl?.dispose());
  }

  /// "Bitti": paragraf motoruyla yeniden dizilir. Reddedilirse alan AÇIK
  /// kalır ve gerekçe + "Üstüne yaz" satır içinde gösterilir.
  Future<void> _commitInline() async {
    final index = _inlineIndex;
    final ctrl = _inlineCtrl;
    if (index == null || ctrl == null || _busy) return;
    final paragraph = _outline.paragraphs[index];
    final text = ctrl.text.trim();
    final size = _inlineSize;
    final sizeChanged = size != null &&
        (size - paragraphPointSize(paragraph)).abs() > 0.05;
    if (text == paragraph.text.trim() && !sizeChanged) {
      _cancelInline();
      return;
    }
    if (text.isEmpty) {
      _partSetState(() => _inlineRefusal = _str.t('pe.inline_empty'));
      return;
    }
    final pageIndex = _page - 1;
    _inlineTimer?.cancel();
    _partSetState(() => _busy = true);
    try {
      await _history!.applyOp(
          _str.t('pe.paragraph_updated'),
          (b) => PdfPageEdit.replaceParagraphInBackground(
                b,
                pageIndex: pageIndex,
                paragraphIndex: index,
                newText: text,
                pointSize: sizeChanged ? size : null,
              ));
      _cancelInline();
      await _syncDocument();
      _snack(_str.t('pe.paragraph_updated'));
    } on PdfParagraphRefused catch (e) {
      if (mounted) _partSetState(() => _inlineRefusal = e.message);
    } on PdfPageRefused catch (e) {
      if (mounted) _partSetState(() => _inlineRefusal = e.message);
    } catch (e) {
      if (mounted) _partSetState(() => _inlineRefusal = userErrorText(e));
    } finally {
      if (mounted) _partSetState(() => _busy = false);
    }
  }

  /// "Üstüne yaz": paragrafın kutusu beyazla örtülür, yeni metin aynı yere
  /// gömülü yazı tipiyle yazılır (motorun reddettiği durumların yolu).
  Future<void> _overwriteInline() async {
    final index = _inlineIndex;
    final ctrl = _inlineCtrl;
    if (index == null || ctrl == null || _busy) return;
    final par = _outline.paragraphs[index];
    final text = ctrl.text;
    final measured = paragraphPointSize(par);
    final size = _inlineSize ?? (measured > 0 ? measured : 11);
    final pageIndex = _page - 1;
    _inlineTimer?.cancel();
    _partSetState(() => _busy = true);
    try {
      await _history!.applyOp(
          _str.t('pe.overwritten'),
          (b) async {
            // Önce eski metin akıştan çıkarılır (arama/kopyalama yeni metni
            // bulsun); dengesiz akışta yalnız beyaz kapak kalır.
            var base = b;
            try {
              base = await PdfPageEdit.eraseParagraphTextInBackground(b,
                  pageIndex: pageIndex, paragraphIndex: index);
            } catch (_) {
              // Bilinçli: çıkarılamazsa kapak yine örter.
            }
            return PdfOverwrite.apply(
                bytes: base,
                pageIndex: pageIndex,
                left: par.left,
                bottom: par.bottom,
                right: par.right,
                top: par.top,
                text: text,
                pointSize: size,
              );
          });
      _cancelInline();
      await _syncDocument();
      _snack(_str.t('pe.overwritten'));
    } catch (e) {
      if (mounted) _partSetState(() => _inlineRefusal = userErrorText(e));
    } finally {
      if (mounted) _partSetState(() => _busy = false);
    }
  }

  // ── Bekleyen nesneler ─────────────────────────────────────────────────────

  List<Widget> _pendingLayer(PdfPage page, Size pageSize) {
    final objects = [
      for (final o in _layer.objects)
        if (o.pageIndex == page.pageNumber - 1) o
    ];
    if (objects.isEmpty) return const [];
    final interactive = _inlineIndex == null &&
        !_placingText &&
        (_mode == _EditMode.text ||
            _mode == _EditMode.image ||
            _mode == _EditMode.sign);
    return [
      IgnorePointer(
        ignoring: !interactive,
        child: PdfPendingObjectLayer(
          objects: objects,
          scale: pageSize.width / page.width,
          selectedId: _selectedPending,
          editingId: _editingPending,
          editingController: _pendingCtrl,
          editingFocus: _pendingFocus,
          onSelect: (id) => _partSetState(() {
            if (_editingPending != null) _finishPendingText();
            _selectedPending = id;
            _selectedObject = null;
          }),
          onChanged: (o) => _setLayer(
              _str.t('pe.object_moved'), _layer.withObject(o)),
          onEdit: _startPendingText,
        ),
      ),
    ];
  }

  void _setLayer(String label, PdfOverlayLayer next) {
    _partSetState(() => _history!.setLayer(label, next));
  }

  /// "Yazı ekle": dokunulan yere bekleyen bir yazı nesnesi konur ve hemen
  /// yerinde yazılmaya başlanır.
  void _placePendingText(PdfPage page, Size pageSize, Offset local) {
    if (pageSize.width <= 0 || pageSize.height <= 0) return;
    final x = local.dx * page.width / pageSize.width;
    final y = local.dy * page.height / pageSize.height;
    const size = 12.0;
    final width = math.max(80.0, math.min(240.0, page.width - x - 8));
    final o = PdfPendingObject(
      id: _nextObjectId++,
      kind: PdfPendingKind.text,
      pageIndex: page.pageNumber - 1,
      box: Rect.fromLTWH(x, y, width, size * 1.2),
    );
    _partSetState(() {
      _placingText = false;
      _history!.setLayer(_str.t('pe.text_added'), _layer.withObject(o));
      _selectedPending = o.id;
    });
    _startPendingText(o.id);
  }

  void _startPendingText(int id) {
    final o = _layer.byId(id);
    if (o == null || o.kind != PdfPendingKind.text) return;
    _pendingCtrl?.dispose();
    _partSetState(() {
      _selectedPending = id;
      _editingPending = id;
      _pendingCtrl = TextEditingController(text: o.text);
    });
  }

  /// Yazı nesnesinin düzenlenmesi bitti: metin değiştiyse adım olur, boş
  /// kaldıysa nesne kalkar.
  void _finishPendingText() {
    final id = _editingPending;
    final ctrl = _pendingCtrl;
    final o = _layer.byId(id);
    _partSetState(() {
      _editingPending = null;
      _pendingCtrl = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl?.dispose());
    if (o == null || ctrl == null) return;
    final text = ctrl.text.trimRight();
    if (text.trim().isEmpty) {
      _partSetState(() => _selectedPending = null);
      _setLayer(_str.t('pe.object_deleted'), _layer.without(o.id));
      return;
    }
    if (text == o.text) return;
    _setLayer(_str.t('pe.text_edited'), _layer.withObject(_fitText(o.copyWith(text: text))));
  }

  /// Yazı kutusunu metne göre boyutlar: yeni yazıda tek satır genişliği
  /// (sayfa kenarına kadar), yüksekliği sarılmış metin.
  PdfPendingObject _fitText(PdfPendingObject o) {
    final maxW = math.max(40.0, _pageViewSize.width - o.box.left - 8);
    final natural = PdfPendingObjectView.measureWidth(o) + 2;
    final w = math.min(math.max(o.box.width, natural), maxW);
    final h = PdfPendingObjectView.measureText(o, w);
    return o.copyWith(box: Rect.fromLTWH(o.box.left, o.box.top, w, h));
  }

  static const _inkColors = [0xFF191919, 0xFFC50F1F, 0xFF185ABD, 0xFF107C41];

  List<AccessoryItem> _textStyleItems(PdfPendingObject o) => [
        AccessoryItem(
          icon: AppIcons.textDecrease,
          tooltip: context.t('pe.font_smaller'),
          onPressed: () => _restyle(o, size: o.fontSize - 1),
        ),
        AccessoryItem(
          icon: AppIcons.textIncrease,
          tooltip: context.t('pe.font_bigger'),
          onPressed: () => _restyle(o, size: o.fontSize + 1),
        ),
        AccessoryItem(
          icon: AppIcons.formatBold,
          tooltip: context.t('pe.bold'),
          selected: o.bold,
          onPressed: () => _restyle(o, bold: !o.bold),
        ),
        AccessoryItem(
          icon: AppIcons.formatColorText,
          tooltip: context.t('pe.text_color'),
          onPressed: () {
            final i = _inkColors.indexOf(o.colorArgb);
            _restyle(o, color: _inkColors[(i + 1) % _inkColors.length]);
          },
        ),
      ];

  void _restyle(PdfPendingObject o,
      {double? size, bool? bold, int? color}) {
    final current = _layer.byId(o.id) ?? o;
    final text = _editingPending == o.id ? _pendingCtrl?.text : null;
    final next = _fitText(current.copyWith(
      text: text,
      pointSize: size?.clamp(4.0, 144.0).toDouble(),
      bold: bold,
      colorArgb: color,
    ));
    _setLayer(_str.t('pe.text_edited'), _layer.withObject(next));
  }

  /// Seçili bekleyen nesnenin bağlam çubuğu.
  Widget _pendingToolbar() {
    final o = _layer.byId(_selectedPending)!;
    final isText = o.kind == PdfPendingKind.text;
    Widget button(AccessoryItem it) => IconButton(
          key: it.key,
          tooltip: it.tooltip,
          isSelected: it.selected,
          onPressed: it.onPressed,
          icon: Icon(it.icon),
          visualDensity: VisualDensity.compact,
        );
    return Card(
      key: const ValueKey('pending-toolbar'),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (isText) ...[
                button(AccessoryItem(
                  key: const ValueKey('pending-edit'),
                  icon: AppIcons.edit,
                  tooltip: context.t('common.edit'),
                  onPressed: () => _startPendingText(o.id),
                )),
                for (final it in _textStyleItems(o)) button(it),
              ],
              button(AccessoryItem(
                key: const ValueKey('pending-delete'),
                icon: AppIcons.delete,
                tooltip: context.t('common.delete'),
                onPressed: () {
                  _partSetState(() => _selectedPending = null);
                  _setLayer(_str.t('pe.object_deleted'), _layer.without(o.id));
                },
              )),
              button(AccessoryItem(
                icon: AppIcons.close,
                tooltip: context.t('pe.clear_selection'),
                onPressed: () => _partSetState(() => _selectedPending = null),
              )),
            ],
          ),
        ),
      ),
    );
  }

  /// Sayfanın ortasına, [aspect] oranlı, sayfa eninin [fraction]'ı kadar kutu.
  Rect _centerBox(double aspect, double fraction) {
    final view = _pageViewSize.isEmpty ? const Size(595, 842) : _pageViewSize;
    final w = view.width * fraction;
    final h = w / (aspect <= 0 ? 1 : aspect);
    return Rect.fromLTWH(
        (view.width - w) / 2, (view.height - h) / 2, w, h);
  }

  /// İmza / baş harf: kayıtlı olan varsa o, yoksa (ya da [redraw]) çizilir;
  /// sayfaya taşınır-boyutlanır nesne olarak konur.
  Future<void> _addSignature({bool initials = false, bool redraw = false}) async {
    _closeEditors();
    var sig = redraw ? null : await Signature.load(initials: initials);
    if (!mounted) return;
    sig ??= await SignaturePad.show(context, initials: initials);
    if (sig == null || sig.isEmpty || !mounted) return;
    final o = PdfPendingObject(
      id: _nextObjectId++,
      kind: PdfPendingKind.signature,
      pageIndex: _page - 1,
      box: _centerBox(sig.aspect, initials ? 0.12 : 0.32),
      strokes: sig.strokes,
      colorArgb: 0xFF000000,
    );
    _partSetState(() {
      _history!.setLayer(_str.t('pe.signature_added'), _layer.withObject(o));
      _selectedPending = o.id;
    });
  }

  /// Görsel ekle (galeriden/dosyadan): oranı korunarak sayfanın ortasına.
  Future<void> _addImage() async {
    _closeEditors();
    final picked = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    final data = picked?.files.single.bytes;
    if (data == null || !mounted) return;
    double aspect = 1;
    try {
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      aspect = frame.image.width / frame.image.height;
      frame.image.dispose();
    } catch (_) {
      _snack(_str.t('pe.image_unreadable'));
      return;
    }
    if (!mounted) return;
    final o = PdfPendingObject(
      id: _nextObjectId++,
      kind: PdfPendingKind.image,
      pageIndex: _page - 1,
      box: _centerBox(aspect, 0.5),
      image: data,
    );
    _partSetState(() {
      _history!.setLayer(_str.t('pe.image_added'), _layer.withObject(o));
      _selectedPending = o.id;
    });
  }

  // ── Sayfa üstünde form ────────────────────────────────────────────────────

  Future<void> _loadForm() async {
    try {
      final fields = await PdfFormFiller.read(_history!.bytes);
      if (mounted) _partSetState(() => _formFields = fields);
    } catch (e) {
      if (mounted) _partSetState(() => _formFields = const []);
      _snack(_str.t('pe.op_failed', {'error': userErrorText(e)}));
    }
  }

  List<Widget> _formLayer(PdfPage page, Size pageSize) {
    final fields = [
      for (final f in _formFields ?? const <PdfFormFieldInfo>[])
        if (f.page == page.pageNumber && f.bounds != null) f
    ];
    // Döndürülmüş sayfada alan kutuları ham uzayda; liste ekranı yedek.
    if (fields.isEmpty || page.rotation != PdfPageRotation.none) {
      return const [];
    }
    return [
      PdfFormOverlay(
        fields: fields,
        scale: pageSize.width / page.width,
        values: _layer.formValues,
        activeName: _activeField,
        activeController: _fieldCtrl,
        activeFocus: _fieldFocus,
        onTapField: _tapField,
      ),
    ];
  }

  Future<void> _tapField(PdfFormFieldInfo f) async {
    if (_activeField != null) _commitField(close: true);
    if (f.readOnly) {
      _snack(_str.t(f.kind == PdfFormFieldKind.signature
          ? 'pe.form_signature'
          : 'pe.form_locked'));
      return;
    }
    final current = _layer.formValues[f.name] ?? f.value;
    switch (f.kind) {
      case PdfFormFieldKind.text:
        _fieldCtrl?.dispose();
        _partSetState(() {
          _activeField = f.name;
          _fieldCtrl = TextEditingController(text: current);
        });
      case PdfFormFieldKind.checkbox:
        _setLayer(_str.t('pe.form_filled'),
            _layer.withFormValue(f.name, current == 'true' ? 'false' : 'true'));
      case PdfFormFieldKind.radio:
      case PdfFormFieldKind.combo:
      case PdfFormFieldKind.list:
        final choice = await showAppSheet<String>(
          context,
          title: f.label,
          builder: (ctx) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final o in f.options)
                  ListTile(
                    title: Text(o),
                    trailing: o == current ? const Icon(AppIcons.check) : null,
                    onTap: () => Navigator.pop(ctx, o),
                  ),
              ],
            ),
        );
        if (choice != null && choice != current && mounted) {
          _setLayer(_str.t('pe.form_filled'), _layer.withFormValue(f.name, choice));
        }
      default:
        _snack(_str.t('pe.form_locked'));
    }
  }

  /// Açık metin alanının değerini katmana yazar.
  void _commitField({bool close = false}) {
    final name = _activeField;
    final ctrl = _fieldCtrl;
    if (name == null || ctrl == null) return;
    final field = _formFields?.where((f) => f.name == name).firstOrNull;
    final before = _layer.formValues[name] ?? field?.value ?? '';
    if (ctrl.text != before) {
      _setLayer(_str.t('pe.form_filled'), _layer.withFormValue(name, ctrl.text));
    }
    if (close) {
      _partSetState(() {
        _activeField = null;
        _fieldCtrl = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    }
  }

  /// ‹ › — bir önceki/sonraki doldurulabilir METİN alanı (sayfa sırasıyla);
  /// başka sayfadaysa oraya gidilir.
  void _stepField(int dir) {
    final fields = [
      for (final f in _formFields ?? const <PdfFormFieldInfo>[])
        if (f.kind == PdfFormFieldKind.text && !f.readOnly && f.bounds != null)
          f
    ]..sort((a, b) {
        final p = a.page.compareTo(b.page);
        if (p != 0) return p;
        final t = a.bounds!.top.compareTo(b.bounds!.top);
        return t != 0 ? t : a.bounds!.left.compareTo(b.bounds!.left);
      });
    if (fields.isEmpty) return;
    final at = fields.indexWhere((f) => f.name == _activeField);
    final next = at < 0
        ? (dir > 0 ? 0 : fields.length - 1)
        : (at + dir) % fields.length;
    final target = fields[next < 0 ? fields.length - 1 : next];
    _commitField(close: true);
    if (target.page != _page && target.page > 0) {
      _controller.goToPage(pageNumber: target.page);
    }
    _tapField(target);
  }
}
