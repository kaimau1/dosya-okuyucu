part of '../pdf_editor_screen.dart';

extension _PdfEditorScreenObjectsPart on _PdfEditorScreenState {
  // ── Bekleyen nesneler ─────────────────────────────────────────────────────

  List<Widget> _pendingLayer(PdfPage page, Size pageSize) {
    final objects = [
      for (final o in _layer.objects)
        if (o.pageIndex == page.pageNumber - 1) o
    ];
    if (objects.isEmpty) return const [];
    final interactive = !_inlineOpen &&
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
    final picked = await AppFilePicker
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
