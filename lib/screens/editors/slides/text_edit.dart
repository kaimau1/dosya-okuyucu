part of '../slides_editor_screen.dart';

/// Office'in standart yazı renkleri (PowerPoint "Tema renkleri" satırının
/// sade karşılığı) — siyah, koyu gri, kırmızı, turuncu, sarı, yeşil, mavi,
/// lacivert, mor, beyaz.
const _textPalette = <int>[
  0xFF000000, 0xFF595959, 0xFFC00000, 0xFFFF0000, 0xFFFFC000, //
  0xFF00B050, 0xFF0070C0, 0xFF002060, 0xFF7030A0, 0xFFFFFFFF,
];

/// Faz 28 — seç / düzenle, kutuya yakınlaşan editör, biçim çubukları,
/// şekil işlemleri ve destenin geri al geçmişi.
extension _SlidesEditorScreenTextEditPart on _SlidesEditorScreenState {
  // ── Geri al (deste düzeyi) ───────────────────────────────────────────────

  /// Yapısal ya da onaylanmış bir değişikliği geri alınabilir yapar: önce /
  /// sonra anlık görüntüsü geçmişe girer. [op] false dönerse (yapılamadı)
  /// geçmişe bir şey yazılmaz.
  bool _mutate(String label, bool Function() op) {
    final editor = _editor;
    if (editor == null) return false;
    final before = editor.snapshot();
    if (!op()) return false;
    final after = editor.snapshot();
    _history.record(CallbackEdit(label, () => editor.restore(after),
        () => editor.restore(before)));
    _session.changed();
    if (mounted) _partSetState(() {});
    return true;
  }

  void _undoDeck() {
    if (_textCtrl != null) {
      _textCtrl!.undo();
      return;
    }
    // Anahatta bekleyen yazı önce adım olur (geri al onu geri alsın).
    _flushOutline();
    if (_history.undo() == null) return;
    _selShape = null;
    _selSlide = null;
    _session.changed();
    _partSetState(() {});
  }

  void _redoDeck() {
    if (_textCtrl != null) {
      _textCtrl!.redo();
      return;
    }
    _flushOutline();
    if (_history.redo() == null) return;
    _selShape = null;
    _selSlide = null;
    _session.changed();
    _partSetState(() {});
  }

  // ── Seçim ───────────────────────────────────────────────────────────────

  void _selectShape(PptxSlide slide, ShapeVM shape) {
    if (_textCtrl != null) _commitEdit();
    _partSetState(() {
      _selSlide = slide;
      _selShape = shape;
    });
  }

  void _clearSelection() => _partSetState(() {
        _selSlide = null;
        _selShape = null;
      });

  String _promptFor(String type) => context.t(switch (type) {
        'title' || 'ctrTitle' => 'sl.prompt_title',
        'subTitle' => 'sl.prompt_subtitle',
        _ => 'sl.prompt_body',
      });

  /// [old]'un güncel çizim modelindeki karşılığı: aynı şekil düğümü ya da
  /// (tablo hücresi gibi düğümsüz kutuda) aynı paragraf düğümü.
  ShapeVM? _resolveShape(PptxSlide slide, ShapeVM old) {
    final el = old.element;
    final paras = {
      for (final p in old.paragraphs)
        if (p.source != null) p.source!,
    };
    for (final s in slide.view?.shapes ?? const <ShapeVM>[]) {
      if (el != null && identical(s.element, el)) return s;
      if (el == null && s.paragraphs.any((p) => paras.contains(p.source))) {
        return s;
      }
    }
    return null;
  }

  /// Seçim yeniden çizimden sonra aynı XML düğümüne bağlı yeni şekle taşınır.
  ShapeVM? _reselect(PptxSlide slide, ShapeVM? old) {
    final el = old?.element;
    if (el == null) return null;
    for (final s in slide.view?.shapes ?? const <ShapeVM>[]) {
      if (identical(s.element, el)) return s;
    }
    return null;
  }

  // ── Metin düzenleme ─────────────────────────────────────────────────────

  /// Düzenlenebilir mi: slayt XML'ine bağlı metni var ya da metin alabilen
  /// bir slayt şekli (`p:sp`; görsel değil).
  static bool _canEditText(ShapeVM shape) =>
      shape.paragraphs.any((p) => p.source != null) ||
      (shape.element?.name.qualified == 'p:sp' && shape.image == null);

  /// Kutuyu düzenlemeye açar: kanvas kutuya yakınlaşır, editör kutunun
  /// yerinde açılır, imleç sonda.
  void _beginEdit(PptxSlide slide, ShapeVM shape) {
    if (identical(_editShapeVM, shape)) return;
    if (_textCtrl != null) {
      _commitEdit();
      // Onay slaydı yeniden çizmiş olabilir: dokunulan kutu eski çizim
      // modelinden geliyor — aynı XML'e bağlı yeni şekli bul.
      shape = _resolveShape(slide, shape) ?? shape;
    }
    if (!_canEditText(shape)) return;
    final rich = SlideRichText.fromParagraphs(shape.paragraphs);
    final ctrl = SlideTextController(rich,
        fontScale: shape.fontScale, lnSpcReduction: shape.lnSpcReduction);
    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    // Eski kaydırma denetleyicileri bu karede hâlâ bağlı: bir kare sonra at.
    final oldH = _focusH, oldV = _focusV;
    _focusH = _focusV = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldH?.dispose();
      oldV?.dispose();
    });
    _partSetState(() {
      _selSlide = null;
      _selShape = null;
      _editSlide = slide;
      _editShapeVM = shape;
      _textCtrl = ctrl;
    });
    _zoomAnim.forward(from: Motion.reduced(context) ? 1 : 0);
  }

  /// Açık düzenlemeyi XML'e yazar (değiştiyse geri alınabilir tek adım) ve
  /// düzenlemeyi kapatır. setState çağırmaz — çağıran sarar.
  void _commitEdit() {
    final slide = _editSlide;
    final shape = _editShapeVM;
    final ctrl = _textCtrl;
    final editor = _editor;
    if (slide == null || shape == null || ctrl == null || editor == null) {
      return;
    }
    if (ctrl.model.touched) {
      final before = editor.snapshot();
      // spAutoFit: kutu yazıya göre büyür (PowerPoint gibi; üst kenar sabit).
      final grown = shape.growFit
          ? SlideBoxEditor.fittedHeight(context, shape, ctrl)
          : 0.0;
      if (editor.writeRichText(slide, shape, ctrl.model)) {
        if (grown > shape.h + 0.5) {
          editor.setShapeFrame(slide, shape,
              x: shape.x, y: shape.y, w: shape.w, h: grown);
        }
        final after = editor.snapshot();
        _history.record(CallbackEdit('sl.undo_text',
            () => editor.restore(after), () => editor.restore(before)));
        _session.changed();
      }
    }
    _textFocus.unfocus();
    _panel.close();
    // Denetleyici bu karede hâlâ editörde bağlı olabilir: bir kare sonra at.
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    _textCtrl = null;
    _editSlide = null;
    _editShapeVM = null;
  }

  void _finishEdit() {
    FocusScope.of(context).unfocus();
    _partSetState(_commitEdit);
  }

  /// Kutunun yakınlaşma çarpanı (punto → mantıksal piksel): kutu ekran
  /// genişliğinin ~%90'ı, ama ilk satırın yazısı en az 16 dp (Faz 28 kabul
  /// ölçütü). İkisi çelişirse okunurluk kazanır; kutu yatayda kaydırılır,
  /// imleç görünür kalır.
  static double focusScale(ShapeVM shape, double viewportW, double typingPt) {
    final kFit = 0.9 * viewportW / math.max(1.0, shape.w);
    final pt = math.max(1.0, typingPt * shape.fontScale);
    final kText = 16 / pt;
    return math.max(kFit, kText).clamp(0.2, 12.0).toDouble();
  }

  /// Düzenleme görünümü: yalnız düzenlenen slayt, kutuya yakınlaşmış.
  Widget _focusEditor() {
    final slide = _editSlide!;
    final shape = _editShapeVM!;
    final ctrl = _textCtrl!;
    final view = slide.view!;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final typing = ctrl.model.typingStyleAt(0).size;
      final k1 = focusScale(shape, w, typing);
      final k0 = math.max(0.05, (w - 32) / view.widthPt);
      final margin = w * 0.05;
      _focusScaleNow = k1;
      return AnimatedBuilder(
        animation: _zoomAnim,
        builder: (context, _) {
          final t = Motion.enter.transform(_zoomAnim.value);
          if (t < 1) {
            // Yakınlaşma: slayt listedeki yerinden kutuya doğru büyür.
            final k = k0 + (k1 - k0) * t;
            final left = 16 + ((margin - shape.x * k1) - 16) * t;
            final top = 8 + ((16 - shape.y * k1) - 8) * t;
            return ClipRect(
              child: Stack(children: [
                // Belge koordinatı (slayt her dilde soldan sağa çizilir).
                Positioned.fromRect(
                  rect: Rect.fromLTWH(
                      left, top, view.widthPt * k, view.heightPt * k),
                  child: SlideCanvas(slide: view),
                ),
              ]),
            );
          }
          _focusH ??= ScrollController(initialScrollOffset: shape.x * k1);
          _focusV ??= ScrollController(initialScrollOffset: shape.y * k1);
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: SingleChildScrollView(
              key: const ValueKey('slide-focus-editor'),
              controller: _focusV,
              child: SingleChildScrollView(
                controller: _focusH,
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      margin, 16, margin, math.max(120.0, box.maxHeight * 0.5)),
                  child: SizedBox(
                    width: view.widthPt * k1,
                    height: view.heightPt * k1,
                    child: SlideCanvas(
                      slide: view,
                      editingShape: shape,
                      // Başka kutuya dokunmak onu düzenlemeye açar.
                      onEditShape: (other) => _beginEdit(slide, other),
                      promptFor: _promptFor,
                      editorBuilder: (s) => SlideBoxEditor(
                        shape: s,
                        controller: ctrl,
                        focusNode: _textFocus,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  // ── Biçim çubukları ─────────────────────────────────────────────────────

  TextAlign _nextAlign(TextAlign a) => slideNextAlign(a);

  IconData _alignIcon(TextAlign a) => switch (slideAlignIndex(a)) {
        1 => OfficeIcons.alignCenter,
        2 => OfficeIcons.alignRight,
        3 => OfficeIcons.alignJustify,
        _ => OfficeIcons.alignLeft,
      };

  /// Klavyenin üstündeki tek satır: ↶ · K · T · A · punto −/+ · renk ·
  /// hizalama · • · 1. — sağda Aa ve ⌄ (ortak [KeyboardAccessoryBar]).
  Widget _slideAccessory() {
    final c = _textCtrl;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final st = c.currentStyle;
        final para = c.currentPara;
        return KeyboardAccessoryBar(
          onFormat: _panel.open,
          onHideKeyboard: () => _textFocus.unfocus(),
          items: [
            AccessoryItem(
                icon: OfficeIcons.undo,
                tooltip: context.t('excel.undo'),
                onPressed: c.canUndo ? c.undo : null),
            AccessoryItem(
                key: const ValueKey('sl-acc-bold'),
                icon: OfficeIcons.bold,
                tooltip: context.t('common.bold'),
                selected: c.all((s) => s.isBold),
                onPressed: c.toggleBold),
            AccessoryItem(
                icon: OfficeIcons.italic,
                tooltip: context.t('common.italic'),
                selected: c.all((s) => s.isItalic),
                onPressed: c.toggleItalic),
            AccessoryItem(
                icon: OfficeIcons.underline,
                tooltip: context.t('common.underline'),
                selected: c.all((s) => s.isUnderline),
                onPressed: c.toggleUnderline),
            AccessoryItem(
                icon: OfficeIcons.fontShrink,
                tooltip: context.t('vw.text_smaller'),
                onPressed: () => c.growFont(-2)),
            AccessoryItem(
                text: '${st.size.round()}',
                tooltip: context.t('word.font_size'),
                onPressed: _pickSlideFontSize),
            AccessoryItem(
                icon: OfficeIcons.fontGrow,
                tooltip: context.t('vw.text_bigger'),
                onPressed: () => c.growFont(2)),
            AccessoryItem(
                icon: OfficeIcons.textColor,
                tooltip: context.t('excel.font_color'),
                onPressed: _pickTextColor),
            AccessoryItem(
                icon: _alignIcon(para.effAlign),
                tooltip: context.t('sl.align'),
                onPressed: () =>
                    c.paragraph(align: _nextAlign(para.effAlign))),
            AccessoryItem(
                icon: OfficeIcons.bullets,
                tooltip: context.t('sl.bullets'),
                selected: para.effBullet == 'char',
                onPressed: () => c.toggleBullet('char')),
            AccessoryItem(
                icon: OfficeIcons.numbering,
                tooltip: context.t('sl.numbering'),
                selected: para.effBullet == 'num',
                onPressed: () => c.toggleBullet('num')),
          ],
        );
      },
    );
  }

  /// **Aa** paneli — Yazı sekmesi.
  Widget _fontPanel(BuildContext context) {
    final c = _textCtrl;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final st = c.currentStyle;
        final scheme = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              _toggle(OfficeIcons.bold, context.t('common.bold'),
                  c.all((s) => s.isBold), c.toggleBold),
              _toggle(OfficeIcons.italic, context.t('common.italic'),
                  c.all((s) => s.isItalic), c.toggleItalic),
              _toggle(OfficeIcons.underline, context.t('common.underline'),
                  c.all((s) => s.isUnderline), c.toggleUnderline),
              IconButton.outlined(
                tooltip: context.t('vw.text_smaller'),
                icon: const Icon(OfficeIcons.fontShrink),
                onPressed: () => c.growFont(-2),
              ),
              ActionChip(
                label: Text('${st.size.round()} pt'),
                onPressed: _pickSlideFontSize,
              ),
              IconButton.outlined(
                tooltip: context.t('vw.text_bigger'),
                icon: const Icon(OfficeIcons.fontGrow),
                onPressed: () => c.growFont(2),
              ),
            ]),
            const SizedBox(height: 12),
            Text(context.t('word.font_family'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final f in kDocFonts.take(8))
                ChoiceChip(
                  label: Text(f.name, style: TextStyle(fontFamily: f.render)),
                  selected: st.font == f.name,
                  onSelected: (_) => c.format(font: f.name),
                ),
            ]),
            const SizedBox(height: 12),
            Text(context.t('excel.font_color'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final argb in _textPalette)
                InkWell(
                  onTap: () => c.format(color: Color(argb)),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(argb),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: st.fg.toARGB32() == argb
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: st.fg.toARGB32() == argb ? 3 : 1),
                    ),
                  ),
                ),
            ]),
          ],
        );
      },
    );
  }

  /// **Aa** paneli — Paragraf sekmesi.
  Widget _paragraphPanel(BuildContext context) {
    final c = _textCtrl;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final p = c.currentPara;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in kSlideAligns)
                _toggle(_alignIcon(a), context.t('sl.align'), p.effAlign == a,
                    () => c.paragraph(align: a)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _toggle(OfficeIcons.bullets, context.t('sl.bullets'),
                  p.effBullet == 'char', () => c.toggleBullet('char')),
              _toggle(OfficeIcons.numbering, context.t('sl.numbering'),
                  p.effBullet == 'num', () => c.toggleBullet('num')),
              IconButton.outlined(
                tooltip: context.t('sl.indent_less'),
                icon: const Icon(AppIcons.formatIndentDecrease),
                onPressed: p.effLevel == 0
                    ? null
                    : () => c.paragraph(levelDelta: -1),
              ),
              IconButton.outlined(
                tooltip: context.t('sl.indent_more'),
                icon: const Icon(AppIcons.formatIndentIncrease),
                onPressed: p.effLevel >= 8
                    ? null
                    : () => c.paragraph(levelDelta: 1),
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _toggle(IconData icon, String tip, bool on, VoidCallback onTap) =>
      on
          ? IconButton.filledTonal(
              tooltip: tip, isSelected: true, icon: Icon(icon), onPressed: onTap)
          : IconButton.outlined(
              tooltip: tip, isSelected: false, icon: Icon(icon), onPressed: onTap);

  /// Klavye kapalıyken düzenlemenin tam şeridi (Office şeridi).
  Widget _formatBar() {
    final c = _textCtrl;
    if (c == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: Border(top: BorderSide(color: scheme.outlineVariant)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final st = c.currentStyle;
              final para = c.currentPara;
              return OfficeRibbon(
                tabs: [
                  RibbonTab('', [
                    RibbonButton(OfficeIcons.undo, context.t('excel.undo'),
                        onTap: c.canUndo ? c.undo : null),
                    RibbonButton(OfficeIcons.redo, context.t('excel.redo'),
                        onTap: c.canRedo ? c.redo : null),
                    const RibbonSep(),
                    RibbonButton(OfficeIcons.bold, context.t('common.bold'),
                        active: c.all((s) => s.isBold), onTap: c.toggleBold),
                    RibbonButton(OfficeIcons.italic, context.t('common.italic'),
                        active: c.all((s) => s.isItalic),
                        onTap: c.toggleItalic),
                    RibbonButton(
                        OfficeIcons.underline, context.t('common.underline'),
                        active: c.all((s) => s.isUnderline),
                        onTap: c.toggleUnderline),
                    const RibbonSep(),
                    // Yazı tipi ailesi (2026-08-07 kullanıcı: *"yazı tipi
                    // fontu boyutu seçimi yok"*) — Word/Excel ile aynı liste.
                    RibbonChip(
                      icon: OfficeIcons.fontFamily,
                      label: st.font ??
                          (_firstFont() ?? context.t('word.font_family')),
                      tooltip: context.t('word.font_family'),
                      onTap: _pickSlideFont,
                    ),
                    RibbonButton(
                        OfficeIcons.fontShrink, context.t('vw.text_smaller'),
                        onTap: () => c.growFont(-2)),
                    RibbonChip(
                      icon: OfficeIcons.fontSize,
                      label: '${st.size.round()}',
                      tooltip: context.t('word.font_size'),
                      onTap: _pickSlideFontSize,
                    ),
                    RibbonButton(
                        OfficeIcons.fontGrow, context.t('vw.text_bigger'),
                        onTap: () => c.growFont(2)),
                    RibbonButton(
                        OfficeIcons.textColor, context.t('excel.font_color'),
                        onTap: _pickTextColor),
                    const RibbonSep(),
                    RibbonButton(_alignIcon(para.effAlign), context.t('sl.align'),
                        onTap: () =>
                            c.paragraph(align: _nextAlign(para.effAlign))),
                    RibbonButton(OfficeIcons.bullets, context.t('sl.bullets'),
                        active: para.effBullet == 'char',
                        onTap: () => c.toggleBullet('char')),
                    RibbonButton(OfficeIcons.numbering, context.t('sl.numbering'),
                        active: para.effBullet == 'num',
                        onTap: () => c.toggleBullet('num')),
                    const RibbonSep(),
                    // Seçili metni çevir (Faz 9 / Y4 — Word ve PDF'te vardı).
                    RibbonButton(AppIcons.translate, context.t('common.translate'),
                        onTap: _translateEditing),
                  ]),
                ],
                trailing: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: FilledButton(
                    key: const ValueKey('sl-done'),
                    onPressed: _finishEdit,
                    child: Text(context.t('sl.done')),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Kutudaki ilk run'ın DOSYADAKİ yazı tipi adı (çizim modelindeki ad
  /// gömülü aileye eşlenmiş olur — Arial → Arimo — ve geri dönülemez).
  String? _firstFont() {
    final shape = _editShapeVM;
    final slide = _editSlide;
    if (shape == null || slide == null) return null;
    for (final p in shape.paragraphs) {
      final para = slide.paragraphOf(p.source);
      if (para == null) continue;
      final f = PptxEditor.fontOfParagraph(para);
      if (f != null) return f;
    }
    return null;
  }

  /// Yazı tipi ailesi seçimi. Seçilen ad DOSYAYA yazılır (PowerPoint'te
  /// gerçek Arial görünsün), ekranda gömülü karşılığıyla çizilir.
  Future<void> _pickSlideFont() async {
    final c = _textCtrl;
    if (c == null) return;
    final current = c.currentStyle.font ?? _firstFont();
    final pick = await showAppSheet<String>(
      context,
      title: context.t('word.font_family'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in kDocFonts)
            ListTile(
              title: Text(f.name, style: TextStyle(fontFamily: f.render)),
              trailing: f.name == current ? const Icon(AppIcons.check) : null,
              onTap: () => Navigator.pop(ctx, f.name),
            ),
        ],
      ),
    );
    if (pick == null || !mounted) return;
    _textCtrl?.format(font: pick);
  }

  Future<void> _pickSlideFontSize() async {
    final c = _textCtrl;
    if (c == null) return;
    final now = c.currentStyle.size;
    final pick = await showAppSheet<double>(
      context,
      title: context.t('word.font_size'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in kDocFontSizes)
            ListTile(
              title: Text('${s.round()}'),
              trailing:
                  (s - now).abs() < 0.25 ? const Icon(AppIcons.check) : null,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (pick == null || !mounted) return;
    _textCtrl?.format(sizePt: pick);
  }

  Future<void> _pickTextColor() async {
    final c = _textCtrl;
    if (c == null) return;
    final pick = await showAppSheet<Color>(
      context,
      title: context.t('excel.font_color'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final argb in _textPalette)
              InkWell(
                onTap: () => Navigator.pop(ctx, Color(argb)),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(argb),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Theme.of(ctx).colorScheme.outlineVariant),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    _textCtrl?.format(color: pick);
  }

  /// Düzenlenen kutuda SEÇİLİ metni (seçim yoksa kutunun tamamını) çevirir.
  void _translateEditing() {
    final c = _textCtrl;
    if (c == null) return;
    final text = selectedEditText([c]).replaceAll(kSlideLineBreak, '\n');
    if (text.trim().isEmpty) return;
    QuickTranslateSheet.show(context, text, title: widget.name);
  }

  // ── Seçili şekil çubuğu ──────────────────────────────────────────────────

  /// Seçili şeklin eylemleri (PowerPoint mobilin bağlam çubuğu).
  Widget _shapeBar() {
    final slide = _selSlide!;
    final shape = _selShape!;
    final editor = _editor!;
    final arrange = PptxEditor.canArrange(shape);
    return DocActionBar([
      if (_canEditText(shape))
        DocAction(AppIcons.edit, context.t('sl.edit_text'),
            () => _beginEdit(slide, shape)),
      DocAction(OfficeIcons.cut, context.t('sl.cut'), !arrange
          ? null
          : () {
              _clipShape = editor.shapeXml(shape);
              _mutate('sl.cut', () => editor.deleteShape(slide, shape));
              _clearSelection();
            }),
      DocAction(OfficeIcons.copy, context.t('common.copy'), !arrange
          ? null
          : () {
              _clipShape = editor.shapeXml(shape);
              final text = shape.paragraphs.map((p) => p.plainText).join('\n');
              if (text.trim().isNotEmpty) {
                Clipboard.setData(ClipboardData(text: text));
              }
              _snack(context.t('sl.copied'));
            }),
      if (_clipShape != null)
        DocAction(OfficeIcons.paste, context.t('sl.paste'),
            () => _mutate('sl.paste', () => editor.pasteShape(slide, _clipShape!))),
      DocAction(AppIcons.copyAll, context.t('sl.duplicate_shape'), !arrange
          ? null
          : () {
              _mutate('sl.duplicate_shape',
                  () => editor.duplicateShape(slide, shape));
              _clearSelection();
            }),
      if (shape.element?.name.qualified == 'p:sp')
        DocAction(AppIcons.formatColorFill, context.t('sl.fill'), _openFill),
      if (const {'p:sp', 'p:cxnSp', 'p:pic'}.contains(shape.element?.name.qualified))
        DocAction(AppIcons.borderColor, context.t('sl.line'), _openLine),
      if (shape.element?.name.qualified == 'p:sp')
        DocAction(AppIcons.opacity, context.t('sl.transparency'), _openTransparency),
      DocAction(AppIcons.flipToFront, context.t('sl.bring_front'), !arrange
          ? null
          : () {
              _mutate('sl.bring_front',
                  () => editor.reorderShape(slide, shape, front: true));
              _partSetState(() => _selShape = _reselect(slide, shape));
            }),
      DocAction(AppIcons.flipToBack, context.t('sl.send_back'), !arrange
          ? null
          : () {
              _mutate('sl.send_back',
                  () => editor.reorderShape(slide, shape, front: false));
              _partSetState(() => _selShape = _reselect(slide, shape));
            }),
      DocAction(AppIcons.delete, context.t('common.delete'), !arrange
          ? null
          : () {
              _mutate('sl.delete_shape', () => editor.deleteShape(slide, shape));
              _clearSelection();
            }),
    ]);
  }
}
