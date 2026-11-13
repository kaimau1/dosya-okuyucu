part of '../viewer_screen.dart';

/// **PDF Pro düzenleme kipi — araçlar** (Faz 55–65): yerinde yazma, biçim
/// çubuğu, bağlamsal yongalar, nesne ve işaretleme araçları, bul-değiştir,
/// yorum paneli. Kipin kendisi (giriş/çıkış/kayıt) `pdf_pro_edit.dart`'ta.
extension _ViewerScreenPdfProToolsPart on _ViewerScreenState {
  PdfProLayerEvents get _proEvents => PdfProLayerEvents(
        onEdit: _proBegin,
        onLocked: _proLocked,
        onBlockMenu: _proBlockMenu,
        onCommit: _proDone,
        onRefused: _proRefused,
        onNote: _proAddNote,
        onAnnotTap: _proAnnotTap,
        onTextBox: _proTextBox,
      );

  void _proRefused(Object e) {
    if (!mounted) return;
    _snack(e is PdfEditBridgeRefused && e.glyph
        ? context.t('pse.refused_glyph')
        : context.t('pse.refused'));
  }

  /// Bloğu yerinde yazmaya açar (imleç dokunulan harfte).
  Future<void> _proBegin(int pageIndex, PdfTextBlock block,
      {int? offset, (int, int)? selection}) async {
    final pro = _pro;
    if (pro == null || pro.busy || pro.live != null) return;
    final refused = context.t('pse.refused');
    final ok = await pro.beginEdit(pageIndex, block,
        offset: offset, selection: selection);
    if (!mounted || _pro != pro) return;
    if (!ok) {
      _snack(refused);
      return;
    }
    _proFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _proRevealCaret());
  }

  /// Yazmayı uygular (✓, dışarı dokunuş). Yazılamayan hâl varsa yazma sürer.
  Future<void> _proDone() async {
    final pro = _pro;
    final live = pro?.live;
    if (pro == null || live == null || pro.busy) return;
    final refusedGlyph = context.t('pse.refused_glyph');
    final refused = context.t('pse.refused');
    final label = live.block == null
        ? 'pse.step_textbox'
        : live.text.trim().isEmpty
            ? 'pse.step_delete'
            : 'pse.step_paragraph';
    final ok = await pro.commitEdit(label: label);
    if (!mounted) return;
    if (!ok) {
      _snack(pro.live?.glyphError ?? false ? refusedGlyph : refused);
      return;
    }
    _proFocus.unfocus();
    _pdfText = '';
  }

  /// Yazmayı bırakır (✕, Esc, geri tuşu).
  Future<void> _proCancel() async {
    final pro = _pro;
    if (pro == null || pro.live == null) return;
    await pro.cancelEdit();
    if (mounted) _proFocus.unfocus();
  }

  /// İmleç satırı klavyenin + biçim çubuğunun üstünde kalsın (yakınlaştırma
  /// değişmez; yalnız kaydırılır — etkileşim §4).
  void _proRevealCaret() {
    final live = _pro?.live;
    if (live == null || !mounted) return;
    try {
      final off = live.selEnd;
      final (x0, y0, x1, y1) = live.map.caret(off);
      final rect = _pdfController.calcRectForRectInsidePage(
        pageNumber: live.pageIndex + 1,
        rect: PdfRect(math.min(x0, x1) - 1, math.max(y0, y1),
            math.max(x0, x1) + 1, math.min(y0, y1)),
      );
      final zoom =
          _pdfController.currentZoom <= 0 ? 1.0 : _pdfController.currentZoom;
      final visible = _pdfController.visibleRect;
      final media = MediaQuery.of(context);
      final below =
          (media.viewInsets.bottom + PdfEditTokens.formatBar + 96) / zoom;
      final above = (media.padding.top + PdfEditTokens.topBar + 16) / zoom;
      var shift = 0.0;
      if (rect.bottom > visible.bottom - below) {
        shift = rect.bottom - (visible.bottom - below);
      } else if (rect.top < visible.top + above) {
        shift = rect.top - (visible.top + above);
      }
      if (shift.abs() < 2 / zoom) return;
      _pdfController.goTo(
          _pdfController.value.clone()
            ..leftTranslateByDouble(0, -shift * zoom, 0, 1),
          duration: Motion.short);
    } catch (_) {
      // Görüntüleyici henüz hazır değilse sessizce atla.
    }
  }

  /// Kilitli blok (PK7): neden + seçenekler.
  Future<void> _proLocked(int pageIndex, PdfTextBlock block) async {
    final pro = _pro;
    if (pro == null) return;
    final pick = await showPdfLockedBlockSheet(context, lock: block.lock);
    if (pick == null || !mounted || _pro != pro) return;
    if (pick == 'line') {
      pro.mode = PdfBlockMode.line;
    } else {
      await _proTextBox(pageIndex, block.left, block.top + block.size * 0.4);
    }
  }

  Future<void> _proTextBox(int pageIndex, double x, double y) async {
    final pro = _pro;
    if (pro == null || pro.busy || pro.live != null) return;
    pro.armTextBox = false;
    final refused = context.t('pse.refused');
    final ok = await pro.beginTextBox(pageIndex, x, y);
    if (!mounted || _pro != pro) return;
    if (!ok) {
      _snack(refused);
      return;
    }
    _proFocus.requestFocus();
  }

  /// Uzun basış: blok bağlam menüsü.
  Future<void> _proBlockMenu(int pageIndex, PdfTextBlock block) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    AppHaptics.selection();
    final pick = await showAppActionSheet<String>(
      context,
      groups: [
        AppActionGroup(actions: [
          if (block.editable)
            AppAction(
                value: 'edit',
                icon: AppIcons.edit,
                label: context.t('common.edit')),
          AppAction(
              value: 'copy', icon: AppIcons.copy, label: context.t('pse.copy')),
          if (block.editable) ...[
            AppAction(
                value: 'dup',
                icon: AppIcons.copyAll,
                label: context.t('pse.duplicate')),
            AppAction(
                value: 'del',
                icon: AppIcons.delete,
                label: context.t('common.delete')),
            AppAction(
                value: 'delup',
                icon: AppIcons.arrowUp,
                label: context.t('pse.delete_pull')),
          ],
          AppAction(
              value: 'mode',
              icon: AppIcons.lines,
              label: context.t(pro.mode == PdfBlockMode.paragraph
                  ? 'pse.mode_line'
                  : 'pse.mode_paragraph')),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    await _proBlockAction(pick, pageIndex, block);
  }

  Future<void> _proBlockAction(
      String action, int pageIndex, PdfTextBlock block) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final copied = context.t('pse.copied');
    try {
      switch (action) {
        case 'edit':
          await _proBegin(pageIndex, block);
        case 'copy':
          await pro.copyBlock(pageIndex, block);
          // Dışarıya düz metin (Faz 58 / 5).
          await Clipboard.setData(ClipboardData(text: block.text));
          _snack(copied);
        case 'dup':
          await pro.duplicateBlock(pageIndex, block, label: 'pse.step_duplicate');
        case 'del':
          await pro.deleteBlock(pageIndex, block, label: 'pse.step_delete');
        case 'delup':
          await pro.deleteBlock(pageIndex, block,
              pullUp: true, label: 'pse.step_delete');
        case 'mode':
          pro.mode = pro.mode == PdfBlockMode.paragraph
              ? PdfBlockMode.line
              : PdfBlockMode.paragraph;
        case 'bullets':
          await pro.toggleList(pageIndex, block,
              numbered: false, label: 'pse.step_list');
        case 'numbers':
          await pro.toggleList(pageIndex, block,
              numbered: true, label: 'pse.step_list');
        case 'left' || 'center' || 'right' || 'justify':
          await pro.reshape(pageIndex, block,
              align: PdfBlockAlign.values.byName(action),
              label: 'pse.step_format');
        case 'bigger' || 'smaller':
          await pro.reshape(pageIndex, block,
              size: (block.size + (action == 'bigger' ? 1 : -1))
                  .roundToDouble()
                  .clamp(4, 144)
                  .toDouble(),
              label: 'pse.step_format');
        case 'split':
          if (block.lines.length > 1) {
            pro.splitSelected(block.lines.length ~/ 2);
          }
        case 'merge':
          pro.mergeSelectedWithNext();
        case 'stylecopy':
          pro.styleClip = (
            size: block.size,
            color: block.lines.first.objects.first.fill,
            align: block.align
          );
          _snack(copied);
        case 'stylepaste':
          final s = pro.styleClip;
          if (s != null) {
            await pro.reshape(pageIndex, block,
                size: s.size,
                color: s.color,
                align: s.align,
                label: 'pse.step_format');
          }
        case 'color':
          final c = await showPdfColorSheet(context,
              title: context.t('pse.fmt_color'), colors: PdfProSwatches.text);
          if (c != null && _pro == pro) {
            await pro.reshape(pageIndex, block,
                color: c, label: 'pse.step_format');
          }
      }
      _pdfText = '';
    } catch (e) {
      _proRefused(e);
    }
  }

  /// Kopyalanan bloğu görünen sayfaya yapıştırır (sayfalar arası taşıma).
  Future<void> _proPaste() async {
    final pro = _pro;
    if (pro == null || pro.busy || pro.clip == null) return;
    final page = (_livePdfPage() ?? _pdfPage) - 1;
    final doc = _pdfDoc;
    if (doc == null || page < 0 || page >= doc.pages.length) return;
    try {
      // Görünen alanın üst-ortası (sayfa uzayı).
      final p = doc.pages[page];
      await pro.pasteBlock(page, 56, p.height * 0.5, label: 'pse.step_paste');
    } catch (e) {
      _proRefused(e);
    }
  }

  // ── görsel / nesne ───────────────────────────────────────────────────────
  Future<void> _proInsertImage({PdfPageItem? replace}) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final unreadable = context.t('pe.image_unreadable');
    final picked =
        await AppFilePicker.pickFiles(type: FileType.image, withData: true);
    final data = picked?.files.single.bytes;
    if (data == null || !mounted || _pro != pro) return;
    final im = await PdfProImages.prepare(data);
    if (!mounted || _pro != pro) return;
    if (im == null) {
      _snack(unreadable);
      return;
    }
    final page = replace == null
        ? (_livePdfPage() ?? _pdfPage) - 1
        : (pro.selectedPage ?? 0);
    final doc = _pdfDoc;
    if (doc == null || page < 0 || page >= doc.pages.length) return;
    final p = doc.pages[page];
    final List<double> m;
    if (replace != null) {
      m = replace.matrix;
    } else {
      // Sayfanın ortasına, genişliğin en çok yarısı.
      final w = math.min(p.width * 0.5, im.width.toDouble());
      final h = w * im.height / im.width;
      m = [w, 0, 0, h, (p.width - w) / 2, (p.height - h) / 2];
    }
    try {
      await pro.mutate(page, [
        if (replace != null) PdfMutAction.delete([replace.index]),
        PdfMutAction.image(im.path, m),
      ], label: replace == null ? 'pse.step_image' : 'pse.step_image_replace');
    } catch (e) {
      _proRefused(e);
    }
  }

  Future<void> _proItemAction(String action) async {
    final pro = _pro;
    final item = pro?.selectedItem;
    final page = pro?.selectedPage;
    if (pro == null || item == null || page == null || pro.busy) return;
    final saved = context.t('pse.image_exported');
    final failed = context.t('pse.refused');
    try {
      switch (action) {
        case 'delete':
          await pro.mutate(page, [PdfMutAction.delete([item.index])],
              label: 'pse.step_delete');
        case 'front':
          await pro.mutate(page, [PdfMutAction.order(item.index, -1)],
              label: 'pse.step_order');
        case 'back':
          await pro.mutate(page, [PdfMutAction.order(item.index, 0)],
              label: 'pse.step_order');
        case 'rotate':
          // Merkez etrafında 90° (saat yönünün tersine).
          final cx = (item.left + item.right) / 2;
          final cy = (item.bottom + item.top) / 2;
          await pro.mutate(page, [
            PdfMutAction.transform([item.index], [0, 1, -1, 0, cx + cy, cy - cx]),
          ], label: 'pse.step_rotate');
        case 'replace':
          await _proInsertImage(replace: item);
        case 'color':
          final c = await showPdfColorSheet(context,
              title: context.t('pse.fmt_color'), colors: PdfProSwatches.text);
          if (c != null && _pro == pro) {
            await pro.mutate(page, [
              PdfMutAction.style([item.index],
                  stroke: item.stroke ? c : 0, fill: item.filled ? c : 0),
            ], label: 'pse.step_format');
          }
        case 'export':
          final px = await PdfEditBridge.imagePixels(pro.document, page, item.index);
          if (px == null) {
            _snack(failed);
            return;
          }
          final png = await PdfProImages.png(px);
          final docs = await DocsHome.resolve();
          final target = p.join(docs.path,
              '${p.basenameWithoutExtension(widget.doc.path)}_gorsel_${DateTime.now().millisecondsSinceEpoch}.png');
          await File(target).writeAsBytes(png, flush: true);
          _snack(saved.replaceAll('{name}', p.basename(target)));
        case 'crop':
          await _proCropImage(page, item);
      }
    } catch (e) {
      _proRefused(e);
    }
  }

  /// Görseli kırpar: kenarlardan yüzde olarak (tutamaçlı levha), pikseller
  /// yeniden yazılır — sayfadaki yeri kırpılan orana göre küçülür.
  Future<void> _proCropImage(int page, PdfPageItem item) async {
    final pro = _pro;
    if (pro == null) return;
    final failed = context.t('pse.refused');
    final px = await PdfEditBridge.imagePixels(pro.document, page, item.index);
    if (!mounted || _pro != pro) return;
    if (px == null) {
      _snack(failed);
      return;
    }
    final crop = await showPdfCropSheet(context);
    if (crop == null || !mounted || _pro != pro) return;
    final (l, t, r, b) = crop;
    final x = (px.width * l).round(), y = (px.height * t).round();
    final w = (px.width * (1 - l - r)).round();
    final h = (px.height * (1 - t - b)).round();
    if (w < 2 || h < 2) return;
    final png = await PdfProImages.png(px, left: x, top: y, width: w, height: h);
    final im = await PdfProImages.prepare(png);
    if (im == null || !mounted || _pro != pro) return;
    // Yerleşim: özgün matrisin birim karesinde kırpılan dikdörtgen.
    final m = item.matrix;
    final sx = 1 - l - r, sy = 1 - t - b;
    final nm = [
      m[0] * sx, m[1] * sx, m[2] * sy, m[3] * sy, //
      m[4] + m[0] * l + m[2] * b, m[5] + m[1] * l + m[3] * b,
    ];
    try {
      await pro.mutate(page, [
        PdfMutAction.delete([item.index]),
        PdfMutAction.image(im.path, nm),
      ], label: 'pse.step_crop');
    } catch (e) {
      _proRefused(e);
    }
  }

  // ── işaretleme ───────────────────────────────────────────────────────────
  Future<void> _proAddNote(int pageIndex, double x, double y) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final text = await showAppPrompt(context,
        title: context.t('pse.mk_note'), multiline: true);
    if (text == null || text.trim().isEmpty || !mounted || _pro != pro) return;
    try {
      await pro.annotate(
          PdfAnnotChange.add(pageIndex, PdfAnnotType.text,
              rect: [x - 10, y - 10, x + 10, y + 10],
              color: pro.markupColor | 0xFF000000,
              contents: text.trim()),
          label: 'pse.step_note',
          detail: text.trim());
    } catch (e) {
      _proRefused(e);
    }
  }

  Future<void> _proAnnotTap(int pageIndex, PdfAnnotInfo annot) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final pick = await showAppActionSheet<String>(
      context,
      title: pdfAnnotTypeLabel(context, annot.subtype),
      subtitle: annot.contents.isEmpty ? null : annot.contents,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'note',
              icon: AppIcons.editNote,
              label: context.t('pse.comment_edit')),
          AppAction(
              value: 'color',
              icon: AppIcons.palette,
              label: context.t('pse.fmt_color')),
          AppAction(
              value: 'delete',
              icon: AppIcons.delete,
              label: context.t('common.delete')),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    try {
      switch (pick) {
        case 'note':
          final text = await showAppPrompt(context,
              title: context.t('pse.comment_edit'),
              initial: annot.contents,
              multiline: true);
          if (text != null && _pro == pro) {
            await pro.annotate(
                PdfAnnotChange.update(pageIndex, annot.index, contents: text),
                label: 'pse.step_note');
          }
        case 'color':
          final c = await showPdfColorSheet(context,
              title: context.t('pse.fmt_color'), colors: PdfProSwatches.marker);
          if (c != null && _pro == pro) {
            await pro.annotate(
                PdfAnnotChange.update(pageIndex, annot.index,
                    color: c | 0xFF000000),
                label: 'pse.step_markup');
          }
        case 'delete':
          await pro.annotate(PdfAnnotChange.remove(pageIndex, annot.index),
              label: 'pse.step_markup_remove');
      }
    } catch (e) {
      _proRefused(e);
    }
  }

  Future<void> _proMarkupColor() async {
    final pro = _pro;
    if (pro == null) return;
    final ink = pro.markup == PdfMarkupKind.ink ||
        pro.markup.index >= PdfMarkupKind.rect.index;
    final c = await showPdfColorSheet(context,
        title: context.t('pse.fmt_color'),
        colors: ink ? PdfProSwatches.text : PdfProSwatches.marker,
        selected: pro.markupColor);
    if (c != null && _pro == pro) pro.setMarkupColor(c);
  }

  Future<void> _proComments() async {
    final pro = _pro;
    if (pro == null) return;
    await showPdfCommentsSheet(context, controller: pro, onGoTo: (a) {
      if (_pdfCount > 0) _goToPdfPage(a.pageIndex + 1, _pdfCount);
      pro
        ..tool = PdfProTool.markup
        ..selectAnnot(a.pageIndex, a);
    });
  }

  Future<void> _proFlatten() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final page = (_livePdfPage() ?? _pdfPage) - 1;
    final ok = await showAppConfirm(context,
        title: context.t('pse.flatten'),
        message: context.t('pse.flatten_q'),
        confirmLabel: context.t('pse.flatten'));
    if (!ok || !mounted || _pro != pro) return;
    try {
      await pro.mutate(page, const [PdfMutAction.flatten()],
          label: 'pse.step_flatten');
    } catch (e) {
      _proRefused(e);
    }
  }

  /// Kişisel verileri bul → önizle → onayla → karart (Faz 64 / 2).
  Future<void> _proSensitive() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final done = context.t('pse.kvkk_done');
    final hits = await showPdfSensitiveSheet(context, controller: pro);
    if (hits == null || hits.isEmpty || !mounted || _pro != pro) return;
    final ok = await showAppConfirm(context,
        title: context.t('pse.mk_redact'),
        message: context.t('pse.redact_q'),
        confirmLabel: context.t('pse.mk_redact'));
    if (!ok || !mounted || _pro != pro) return;
    try {
      final n = await pro.redact(hits, label: 'pse.step_redact');
      _pdfText = '';
      _snack(done.replaceAll('{n}', '$n'));
    } catch (e) {
      _proRefused(e);
    }
  }

  Future<void> _proFindReplace() async {
    final pro = _pro;
    if (pro == null) return;
    await showPdfFindReplaceSheet(context, controller: pro, onGoTo: (h) {
      if (_pdfCount > 0) _goToPdfPage(h.pageIndex + 1, _pdfCount);
      pro
        ..tool = PdfProTool.text
        ..select(h.pageIndex, h.block);
    });
    _pdfText = '';
  }

  Future<void> _proPickTextColor({required bool highlight}) async {
    final pro = _pro;
    if (pro == null || pro.live == null) return;
    final c = await showPdfColorSheet(context,
        title: context.t(highlight ? 'pse.fmt_highlight' : 'pse.fmt_color'),
        colors: highlight ? PdfProSwatches.marker : PdfProSwatches.text);
    if (c == null || _pro != pro || pro.live == null) return;
    pro.liveStyle((a, b) => highlight
        ? PdfStyleSpan(a, b, highlight: c)
        : PdfStyleSpan(a, b, color: c | 0xFF000000));
    _proFocus.requestFocus();
  }

  // ── AI (Faz 65) ──────────────────────────────────────────────────────────
  /// Seçili paragrafı AI ile yerinde yeniden yazar: sonuç önce öneri olarak
  /// gösterilir (eski ↔ yeni), kabul = tek geri alınabilir adım. Blok seçili
  /// değilse belge geneli AI düzenlemeye yönlendirir.
  Future<void> _proAi() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final block = pro.selected;
    final page = pro.selectedPage;
    if (block == null || page == null || !block.editable) {
      final whole = await showAppConfirm(context,
          title: context.t('pse.tool_ai'),
          message: context.t('pse.ai_pick_block'),
          confirmLabel: context.t('pse.ai_whole'));
      if (whole && mounted) await _aiEditPdf();
      return;
    }
    final pick = await showAppActionSheet<PdfAiMode>(
      context,
      title: context.t('pse.tool_ai'),
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: PdfAiMode.rewrite,
              icon: AppIcons.autoFixNormal,
              label: context.t('pse.ai_rewrite')),
          AppAction(
              value: PdfAiMode.shorten,
              icon: AppIcons.shortText,
              label: context.t('pse.ai_shorten')),
          AppAction(
              value: PdfAiMode.formal,
              icon: AppIcons.badge,
              label: context.t('pse.ai_formal')),
          AppAction(
              value: PdfAiMode.grammar,
              icon: AppIcons.spellcheck,
              label: context.t('pse.ai_grammar')),
          AppAction(
              value: PdfAiMode.translate,
              icon: AppIcons.translate,
              label: context.t('pse.ai_translate')),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    String? language;
    if (pick == PdfAiMode.translate) {
      language = await showAppActionSheet<String>(
        context,
        title: context.t('pse.ai_translate'),
        groups: [
          AppActionGroup(actions: [
            for (final l in const ['Türkçe', 'English', 'العربية', 'Deutsch', 'Français'])
              AppAction(value: l, icon: AppIcons.translate, label: l),
          ]),
        ],
      );
      if (language == null || !mounted || _pro != pro) return;
    }
    if (!await ensureAiKey(context) || !mounted || _pro != pro) return;
    final failed = context.t('pse.ai_failed');
    final same = context.t('pse.ai_same');
    final gemini = context.read<AppState>().gemini;
    final original = block.text;
    String? suggestion;
    try {
      _snack(context.t('pse.ai_working'));
      suggestion =
          await PdfAiRewrite.run(gemini, original, pick, language: language);
    } catch (e) {
      _snack(failed.replaceAll('{error}', userErrorText(e)));
      return;
    }
    if (!mounted || _pro != pro) return;
    if (suggestion == null || suggestion.trim() == original.trim()) {
      _snack(same);
      return;
    }
    final accept = await showPdfSuggestionSheet(context,
        before: original, after: suggestion);
    if (accept != true || !mounted || _pro != pro) return;
    try {
      await pro.replace(page, block, suggestion, label: 'pse.step_ai');
      _pdfText = '';
    } catch (e) {
      _proRefused(e);
    }
  }

  // ── çubuklar ─────────────────────────────────────────────────────────────
  /// Alt araç çubuğu (etkileşim §5): Metin · Görsel · İşaretle · İmza · Form ·
  /// Sayfalar · Daha fazla. Okuma kipindeki çubukla aynı yükseklikte — gövde
  /// payı değişmez.
  Widget _proToolBar(PdfProEditController pro) {
    DocAction tool(PdfProTool t, IconData icon, String key) => DocAction(
        icon, context.t(key), pro.busy ? null : () => pro.tool = t,
        active: pro.tool == t);
    return DocActionBar([
      tool(PdfProTool.text, AppIcons.textFields, 'pse.tool_text'),
      tool(PdfProTool.image, AppIcons.image, 'pse.tool_image'),
      tool(PdfProTool.markup, AppIcons.highlighter, 'pse.tool_markup'),
      DocAction(AppIcons.draw, context.t('pse.tool_sign'),
          pro.busy ? null : _signPdf),
      DocAction(AppIcons.formView, context.t('pse.tool_form'),
          pro.busy ? null : _fillPdfForm),
      DocAction(AppIcons.thumbnails, context.t('pse.tool_pages'),
          pro.busy ? null : _proPages),
      DocAction(AppIcons.moreHoriz, context.t('pse.tool_more'),
          pro.busy ? null : _proMore),
    ]);
  }

  /// Sayfalar: görünen sayfayı döndür (geri alınabilir) ya da sayfa
  /// stüdyosuna (sırala/ekle/sil/böl/birleştir) geç.
  Future<void> _proPages() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final pick = await showAppActionSheet<String>(
      context,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'rotate',
              icon: AppIcons.rotateRight,
              label: context.t('pse.page_rotate')),
          AppAction(
              value: 'studio',
              icon: AppIcons.thumbnails,
              label: context.t('pse.page_studio'),
              hint: context.t('pse.page_studio_hint')),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    if (pick == 'studio') {
      await _openPdfTools();
      return;
    }
    final page = (_livePdfPage() ?? _pdfPage) - 1;
    try {
      await pro.rotatePage(page, label: 'pse.step_rotate');
    } catch (e) {
      _proRefused(e);
    }
  }

  List<PdfProChip> _proChips(PdfProEditController pro) {
    String t(String k) => context.t(k);
    final block = pro.selected;
    final page = pro.selectedPage;
    switch (pro.tool) {
      case PdfProTool.text:
        if (block != null && page != null) {
          PdfProChip act(IconData i, String label, String a,
                  {bool danger = false, Key? key}) =>
              PdfProChip(i, label, () => _proBlockAction(a, page, block),
                  danger: danger, tapKey: key);
          if (!block.editable) {
            return [
              act(AppIcons.copy, t('pse.copy'), 'copy'),
              PdfProChip(AppIcons.info, t('pse.locked_why'),
                  () => _proLocked(page, block)),
            ];
          }
          return [
            // Sık kullanılanlar başta: yaz, sil, kopyala, boyut, renk.
            act(AppIcons.edit, t('common.edit'), 'edit',
                key: const ValueKey('pse-chip-edit')),
            act(AppIcons.delete, t('common.delete'), 'del',
                danger: true, key: const ValueKey('pse-chip-delete')),
            act(AppIcons.copy, t('pse.copy'), 'copy'),
            act(AppIcons.copyAll, t('pse.duplicate'), 'dup'),
            act(AppIcons.textIncrease, t('pse.fmt_larger'), 'bigger'),
            act(AppIcons.textDecrease, t('pse.fmt_smaller'), 'smaller'),
            act(AppIcons.formatColorText, t('pse.fmt_color'), 'color'),
            act(AppIcons.formatAlignLeft, t('pse.al_left'), 'left'),
            act(AppIcons.formatAlignCenter, t('pse.al_center'), 'center'),
            act(AppIcons.formatAlignRight, t('pse.al_right'), 'right'),
            act(AppIcons.formatAlignJustify, t('pse.al_justify'), 'justify'),
            act(AppIcons.formatListBulleted, t('pse.list_bullets'), 'bullets'),
            act(AppIcons.formatListNumbered, t('pse.list_numbers'), 'numbers'),
            act(AppIcons.formatPaint, t('pse.style_copy'), 'stylecopy'),
            if (pro.styleClip != null)
              act(AppIcons.style, t('pse.style_paste'), 'stylepaste'),
            if (block.lines.length > 1)
              act(AppIcons.split, t('pse.block_split'), 'split'),
            act(AppIcons.join, t('pse.block_merge'), 'merge'),
          ];
        }
        // Metin yok (taranmış sayfa): OCR ve metin kutusu önerilir (§9).
        final shown = (_livePdfPage() ?? _pdfPage) - 1;
        final scanned = pro.blocksOf(shown)?.isEmpty ?? false;
        return [
          if (scanned)
            PdfProChip(AppIcons.ocr, t('pse.ocr_run'),
                () => _runOcr(onlyPage: shown + 1),
                tapKey: const ValueKey('pse-chip-ocr')),
          PdfProChip(AppIcons.textFields, t('pse.textbox_add'),
              () => pro.armTextBox = !pro.armTextBox,
              active: pro.armTextBox,
              tapKey: const ValueKey('pse-chip-textbox')),
          PdfProChip(
              AppIcons.lines,
              t(pro.mode == PdfBlockMode.paragraph
                  ? 'pse.mode_line'
                  : 'pse.mode_paragraph'),
              () => pro.mode = pro.mode == PdfBlockMode.paragraph
                  ? PdfBlockMode.line
                  : PdfBlockMode.paragraph,
              active: pro.mode == PdfBlockMode.line,
              tapKey: const ValueKey('pse-chip-mode')),
          PdfProChip(AppIcons.findReplace, t('pse.find_title'), _proFindReplace,
              tapKey: const ValueKey('pse-chip-find')),
          if (pro.clip != null)
            PdfProChip(AppIcons.paste, t('pse.paste'), _proPaste),
        ];
      case PdfProTool.image:
        final item = pro.selectedItem;
        if (item != null) {
          return [
            if (item.isImage) ...[
              PdfProChip(AppIcons.image, t('pse.img_replace'),
                  () => _proItemAction('replace')),
              PdfProChip(
                  AppIcons.crop, t('pse.img_crop'), () => _proItemAction('crop')),
              PdfProChip(AppIcons.download, t('pse.img_export'),
                  () => _proItemAction('export')),
            ] else
              PdfProChip(AppIcons.palette, t('pse.fmt_color'),
                  () => _proItemAction('color')),
            PdfProChip(AppIcons.rotateRight, t('pse.img_rotate'),
                () => _proItemAction('rotate')),
            PdfProChip(AppIcons.flipToFront, t('pse.img_front'),
                () => _proItemAction('front')),
            PdfProChip(AppIcons.flipToBack, t('pse.img_back'),
                () => _proItemAction('back')),
            PdfProChip(AppIcons.delete, t('common.delete'),
                () => _proItemAction('delete'),
                danger: true),
          ];
        }
        return [
          PdfProChip(AppIcons.addPhoto, t('pse.img_add'), _proInsertImage,
              tapKey: const ValueKey('pse-chip-image')),
        ];
      case PdfProTool.markup:
        PdfProChip kind(PdfMarkupKind k, IconData i, String key) =>
            PdfProChip(i, t(key), () => pro.markup = k,
                active: pro.markup == k, tapKey: ValueKey('pse-mk-${k.name}'));
        return [
          kind(PdfMarkupKind.highlight, AppIcons.highlighter, 'pse.mk_highlight'),
          kind(PdfMarkupKind.underline, AppIcons.formatUnderlined,
              'pse.mk_underline'),
          kind(PdfMarkupKind.strikeout, AppIcons.strikethroughS,
              'pse.mk_strikeout'),
          kind(PdfMarkupKind.squiggly, AppIcons.gesture, 'pse.mk_squiggly'),
          kind(PdfMarkupKind.note, AppIcons.addComment, 'pse.mk_note'),
          kind(PdfMarkupKind.ink, AppIcons.draw, 'pse.mk_ink'),
          kind(PdfMarkupKind.rect, AppIcons.rectTool, 'pse.mk_rect'),
          kind(PdfMarkupKind.ellipse, AppIcons.ellipseTool, 'pse.mk_ellipse'),
          kind(PdfMarkupKind.line, AppIcons.lineTool, 'pse.mk_line'),
          kind(PdfMarkupKind.arrow, AppIcons.arrowTool, 'pse.mk_arrow'),
          kind(PdfMarkupKind.eraser, AppIcons.eraser, 'pse.mk_eraser'),
          kind(PdfMarkupKind.redact, AppIcons.pdfRedact, 'pse.mk_redact'),
          PdfProChip(AppIcons.shield, t('pse.kvkk_title'), _proSensitive,
              tapKey: const ValueKey('pse-chip-kvkk')),
          PdfProChip(AppIcons.palette, t('pse.fmt_color'), _proMarkupColor),
          PdfProChip(AppIcons.comment, t('pse.comments'), _proComments,
              tapKey: const ValueKey('pse-chip-comments')),
          PdfProChip(AppIcons.pdfFlatten, t('pse.flatten'), _proFlatten),
        ];
      default:
        return const [];
    }
  }

  PdfProFormatLabels get _proFormatLabels => PdfProFormatLabels(
        done: context.t('pse.done'),
        cancel: context.t('common.cancel'),
        bold: context.t('pse.fmt_bold'),
        italic: context.t('pse.fmt_italic'),
        underline: context.t('pse.fmt_underline'),
        strike: context.t('pse.fmt_strike'),
        color: context.t('pse.fmt_color'),
        highlight: context.t('pse.fmt_highlight'),
        align: context.t('pse.fmt_align'),
        smaller: context.t('pse.fmt_smaller'),
        larger: context.t('pse.fmt_larger'),
        selectAll: context.t('pse.select_all'),
        copy: context.t('pse.copy'),
        cut: context.t('pse.cut'),
        paste: context.t('pse.paste'),
        docFont: context.t('pse.font_doc'),
        fallbackFont: context.t('pse.font_fallback'),
        glyphError: context.t('pse.refused_glyph'),
        error: context.t('pse.refused'),
        size: context.t('pse.fmt_size'),
      );

  /// Düzenleme kipinin gövde üstü katmanları: bağlamsal çubuk, yazarken
  /// klavye üstü biçim çubuğu ve gizli giriş alanı. Hepsi gövdenin ÜSTÜNDE
  /// yüzer; gövde boyu değişmez (PS4).
  List<Widget> _proOverlays(PdfProEditController pro) {
    final live = pro.live;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (live != null) {
      final bar = PdfProFormatBar(
        controller: pro,
        labels: _proFormatLabels,
        input: _proInput,
        onDone: _proDone,
        onCancel: _proCancel,
        onPickColor: () => _proPickTextColor(highlight: false),
        onPickHighlight: () => _proPickTextColor(highlight: true),
      );
      return [
        PositionedDirectional(
          start: 0,
          top: 0,
          child: PdfProTextInput(
            controller: pro,
            input: _proInput,
            focusNode: _proFocus,
            onEscape: _proCancel,
            onUndo: _proUndo,
            onRedo: _proRedo,
          ),
        ),
        if (inset > 0)
          PositionedDirectional(start: 0, end: 0, bottom: inset, child: bar)
        else
          ReadingFloat(gap: 0, child: bar),
      ];
    }
    final chips = _proChips(pro);
    return [
      if (chips.isNotEmpty)
        ReadingFloat(
          gap: 0,
          child: PdfProContextBar(
              chips: chips, label: context.t('pse.context_bar')),
        ),
    ];
  }
}
