part of '../word_mobile_editor_screen.dart';

/// **Faz 37 — Word pro araçları.** Araçlar sekmesindeki her düğme
/// [_WordMobileEditorScreenState._onPro] kapısından geçer. Yapısal işlemler
/// (stil tanımı, bölüm, tablo ızgarası, denklem, şekil …) paket düzeyinde
/// izolatta koşar ([DocxPro.run]); sonuç yeniden ayrıştırılıp editöre bağlanır,
/// önceki bayt [_proUndo]'ya girer (üst çubuktaki ↶ onu da geri alır).
extension _WordProPart on _WordMobileEditorScreenState {
  static const flagKey = 'word_pro_v1';

  Future<void> _loadProFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final on = prefs.getBool(flagKey) ?? true;
      if (on != _proOn && mounted) _setState(() => _proOn = on);
    } catch (_) {
      // En iyi çaba: ayar okunamazsa varsayılan (açık) kalır.
    }
  }

  void _setState(VoidCallback f) {
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(f);
    }
  }

  /// Paket işlemini uygular. [keepPara]: işlem sonrası imlecin konacağı
  /// paragraf (null → işlem öncesi imleç).
  Future<bool> _proApply(DocxOp op, {int? keepPara, String? doneKey}) async {
    final doc = _doc;
    final c = _ctrl;
    if (doc == null || c == null || _proBusy) return false;
    final caret = keepPara ?? c.extent.para;
    _setState(() => _proBusy = true);
    final done = doneKey == null ? null : context.t(doneKey);
    final failed = context.t('wp.failed');
    try {
      final before = await doc.saveAsync();
      final after = await DocxPro.run(before, op);
      final parsed = WordMobileEditorScreen.parseInIsolate
          ? await compute(_WordMobileEditorScreenState._parse, after)
          : _WordMobileEditorScreenState._parse(after);
      if (!mounted) return false;
      _proUndo.add(before);
      if (_proUndo.length > 5) _proUndo.removeAt(0);
      _setState(() {
        _attach(parsed);
        _proBusy = false;
      });
      _session.changed();
      _placeCaret(caret);
      if (done != null && mounted) showSnack(context, done);
      return true;
    } catch (e) {
      _setState(() => _proBusy = false);
      if (mounted) {
        showSnack(context, failed.replaceAll('{error}', userErrorText(e)));
      }
      return false;
    }
  }

  void _placeCaret(int i) {
    final c = _ctrl;
    if (c == null || c.paras.isEmpty) return;
    final at = i.clamp(0, c.paras.length - 1);
    c.select(DocPos(at, 0), DocPos(at, 0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_viewKey.currentState?.revealParagraph(at));
    });
  }

  Future<void> _proUndoLast() async {
    if (_proUndo.isEmpty || _proBusy) return;
    final caret = _ctrl?.extent.para ?? 0;
    final bytes = _proUndo.removeLast();
    final parsed = WordMobileEditorScreen.parseInIsolate
        ? await compute(_WordMobileEditorScreenState._parse, bytes)
        : _WordMobileEditorScreenState._parse(bytes);
    if (!mounted) return;
    _setState(() => _attach(parsed));
    _session.changed();
    _placeCaret(caret);
  }

  Future<void> _onPro(String id) async {
    final c = _ctrl;
    if (c == null || _proBusy) return;
    switch (id) {
      case 'style_update':
        await _proApply(DocxStyleOps.updateStyleFromParagraph(c.extent.para),
            doneKey: 'wp.style_updated');
      case 'theme':
        await _pickTheme();
      case 'page_setup':
        await _pageSetup();
      case 'print_preview':
        await _printPreview();
      case 'equation':
        await _equation();
      case 'compare':
        await _compareWith();
      case 'combine':
        await _combineWith();
      case 'review_bar':
        await _openReview();
      case 'password':
        await _passwordMenu();
      case 'export':
        await _export();
      case 'para_border':
        final v = await _choose('wp.para_border', const [
          ('box', 'wp.bdr_box'),
          ('top', 'wp.bdr_top'),
          ('bottom', 'wp.bdr_bottom'),
          ('shade', 'wp.bdr_shade'),
          ('none', 'wp.bdr_none'),
        ]);
        if (v != null) await _proApply(DocxInsertPro.paraBorder(c.extent.para, v));
      case 'textbox':
        final t = await showWordTextSheet(context,
            title: context.t('wp.textbox'),
            label: context.t('wp.textbox_text'),
            action: context.t('common.insert'),
            fieldKey: const ValueKey('word-textbox-field'));
        if (t != null && t.trim().isNotEmpty && mounted) {
          await _proApply(DocxInsertPro.textBox(c.extent.para, t.trim()),
              keepPara: c.extent.para + 1);
        }
      case 'shape':
        final v = await _choose('wp.shape', [
          for (final g in kDocxShapes) (g, 'wp.shape_$g'),
        ]);
        if (v != null) {
          await _proApply(DocxInsertPro.shape(c.extent.para, v),
              keepPara: c.extent.para + 1);
        }
      case 'img_wrap':
        await _imageWrap();
      case 'cover':
        await _cover();
      case 'section_break':
        final v = await _choose('wp.section_break', const [
          ('nextPage', 'wp.sb_next'),
          ('continuous', 'wp.sb_cont'),
          ('evenPage', 'wp.sb_even'),
          ('oddPage', 'wp.sb_odd'),
        ]);
        if (v != null) {
          await _proApply(DocxLayoutOps.sectionBreak(c.extent.para, v),
              doneKey: 'wp.sb_done');
        }
      case 'field':
        await _field();
      case 'cross_ref':
        await _crossRef();
      case 'bibliography':
        await _cite();
      case 'reader':
        final doc = _doc;
        if (doc == null) return;
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WordReaderScreen(
                doc: doc, title: widget.name, startPara: c.extent.para)));
      case 'outline':
        await _outline();
      case 'thumbnails':
        await _thumbnails();
      case 'stats':
        await _stats();
      case 'dictate':
        await _dictate();
      case 'ai_inline':
        await _aiInline();
      case 'ai_proof':
        await _aiProof();
      case 'tbl_merge':
        final dir = await _choose('wp.tbl_merge', const [
          ('right', 'wp.tbl_merge_right'),
          ('down', 'wp.tbl_merge_down'),
        ]);
        if (dir == null) return;
        await _tableOp(dir == 'right'
            ? DocxTableTools.mergeRight(c.extent.para)
            : DocxTableTools.mergeDown(c.extent.para));
      case 'tbl_split':
        await _tableOp(DocxTableTools.split(c.extent.para));
      case 'tbl_borders':
        final v = await _choose('wp.tbl_borders', const [
          ('all', 'wp.tbl_b_all'),
          ('outer', 'wp.tbl_b_outer'),
          ('inner', 'wp.tbl_b_inner'),
          ('none', 'wp.tbl_b_none'),
        ]);
        if (v != null) await _tableOp(DocxTableTools.borders(c.extent.para, v));
      case 'tbl_autofit':
        final v = await _choose('wp.tbl_autofit', const [
          ('content', 'wp.tbl_fit_content'),
          ('window', 'wp.tbl_fit_window'),
          ('fixed', 'wp.tbl_fit_fixed'),
        ]);
        if (v != null) await _tableOp(DocxTableTools.autofit(c.extent.para, v));
      case 'tbl_sort':
        final v = await _choose('wp.tbl_sort', const [
          ('asc_h', 'wp.tbl_sort_asc_h'),
          ('desc_h', 'wp.tbl_sort_desc_h'),
          ('asc', 'wp.tbl_sort_asc'),
          ('desc', 'wp.tbl_sort_desc'),
        ]);
        if (v != null) {
          await _tableOp(DocxTableTools.sort(c.extent.para,
              descending: v.startsWith('desc'), header: v.endsWith('_h')));
        }
    }
  }

  /// Tek seçimli levha: (değer, etiket anahtarı) listesi.
  Future<String?> _choose(String titleKey, List<(String, String)> items) =>
      showAppSheet<String>(
        context,
        title: context.t(titleKey),
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, k) in items)
              ListTile(
                key: ValueKey('word-choose-$v'),
                title: Text(ctx.t(k)),
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      );

  // ── Madde 1: stil + tema ─────────────────────────────────────────────────

  Future<void> _pickTheme() async {
    final doc = _doc;
    if (doc == null) return;
    final bytes = await doc.saveAsync();
    final (_, body) = await DocxPro.query(bytes, DocxStyleOps.themeFonts);
    if (!mounted) return;
    final set = await showAppSheet<DocxStyleSet>(
      context,
      title: context.t('wp.theme'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in kDocxStyleSets)
            ListTile(
              key: ValueKey('word-theme-${s.id}'),
              title: Text(ctx.t('wp.theme_${s.id}'),
                  style: TextStyle(
                      fontFamily: renderFamilyFor(s.headingFont),
                      fontWeight: FontWeight.w600)),
              subtitle: Text('${s.headingFont} · ${s.bodyFont} · ${s.bodyPt.round()} pt',
                  style: TextStyle(fontFamily: renderFamilyFor(s.bodyFont))),
              trailing: body == s.bodyFont ? const Icon(AppIcons.check) : null,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (set == null || !mounted) return;
    await _proApply(DocxStyleOps.applyStyleSet(set), doneKey: 'wp.theme_applied');
  }

  // ── Madde 2: sayfa düzeni + baskı önizleme ───────────────────────────────

  Future<void> _pageSetup() async {
    final doc = _doc;
    final c = _ctrl;
    if (doc == null || c == null) return;
    final bytes = await doc.saveAsync();
    final spec = await DocxPro.query(bytes, DocxLayoutOps.read);
    if (!mounted) return;
    final r = await showAppSheet<(String, DocxPageSpec)>(
      context,
      title: context.t('wp.page_setup'),
      builder: (_) => _PageSetupSheet(spec: spec),
    );
    if (r == null || !mounted) return;
    switch (r.$1) {
      case 'break':
        c.insertPageBreak();
      case 'preview':
        await _proApply(DocxLayoutOps.apply(r.$2));
        await _printPreview();
      default:
        await _proApply(DocxLayoutOps.apply(r.$2), doneKey: 'wp.page_applied');
    }
  }

  /// Yazdırma önizlemesi: kendi PDF çizicimiz (gömülü yazı tipleri) →
  /// sistemin yazdırma ekranı (önizleme + yazıcı/PDF kaydı).
  Future<void> _printPreview() async {
    final pdf = await _renderPdf();
    if (pdf == null || !mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => pdf, name: widget.name);
  }

  Future<Uint8List?> _renderPdf() async {
    final doc = _doc;
    if (doc == null) return null;
    final failed = context.t('wp.failed');
    _setState(() => _proBusy = true);
    try {
      final bytes = await doc.saveAsync();
      final fonts = await DocxPdfFonts.load();
      return await DocxPdf.renderInBackground(bytes, fonts: fonts);
    } catch (e) {
      if (mounted) {
        showSnack(context, failed.replaceAll('{error}', userErrorText(e)));
      }
      return null;
    } finally {
      _setState(() => _proBusy = false);
    }
  }

  // ── Madde 3: denklem + tablo ─────────────────────────────────────────────

  Future<void> _tableOp(DocxOp op) async {
    final c = _ctrl;
    if (c == null) return;
    if (!c.inTable) {
      showSnack(context, context.t('wp.tbl_err_no_table'));
      return;
    }
    final msgs = {
      for (final k in const ['no_table', 'no_neighbor', 'shape', 'not_merged', 'merged'])
        k: context.t('wp.tbl_err_$k'),
    };
    final doc = _doc!;
    // Tablo hatası işlemden önce denetlenir (yanlış yere yazılmasın).
    final bytes = await doc.saveAsync();
    try {
      await DocxPro.run(bytes, op);
    } on DocxTableException catch (e) {
      if (mounted) showSnack(context, msgs[e.code] ?? e.code);
      return;
    } catch (_) {
      // Ön deneme yalnız tablo hatası içindir; başka hata _proApply'da
      // kullanıcıya gösterilir.
    }
    if (mounted) await _proApply(op);
  }

  Future<void> _equation() async {
    final doc = _doc;
    final c = _ctrl;
    if (doc == null || c == null) return;
    final i = c.extent.para;
    final bytes = await doc.saveAsync();
    final existing = await DocxPro.query(bytes, _readMath(i));
    if (!mounted) return;
    final latex = await showAppSheet<String>(
      context,
      title: context.t(existing.isEmpty ? 'wp.equation' : 'wp.equation_edit'),
      builder: (_) => _EquationSheet(initial: existing.firstOrNull ?? ''),
    );
    if (latex == null || latex.trim().isEmpty || !mounted) return;
    await _proApply(
        existing.isEmpty
            ? DocxMathOps.insert(i, latex.trim())
            : DocxMathOps.replace(i, 0, latex.trim()),
        keepPara: existing.isEmpty ? i + 1 : i);
  }

  static List<String> Function(DocxPackage) _readMath(int i) =>
      (pkg) => DocxMathOps.read(pkg, i);

  // ── Madde 5: karşılaştır, birleştir, gözden geçirme, parola ──────────────

  Future<Uint8List?> _pickDocx() async {
    final hook = WordMobileEditorScreen.pickDocxForTest;
    if (hook != null) return hook();
    final picked = await AppFilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['docx'],
      withData: true,
    );
    return picked?.files.single.bytes;
  }

  Future<void> _compareWith() async {
    final older = await _pickDocx();
    if (older == null || !mounted) return;
    if (OfficeCrypto.isEncrypted(older)) {
      showSnack(context, context.t('wp.compare_encrypted'));
      return;
    }
    final ok = await _proApply(DocxCompare.compare(older),
        keepPara: 0, doneKey: 'wp.compare_done');
    if (ok) await _openReview();
  }

  Future<void> _combineWith() async {
    final c = _ctrl;
    final other = await _pickDocx();
    if (other == null || c == null || !mounted) return;
    if (OfficeCrypto.isEncrypted(other)) {
      showSnack(context, context.t('wp.compare_encrypted'));
      return;
    }
    await _proApply(DocxCompare.append(other, c.extent.para),
        keepPara: c.extent.para + 1, doneKey: 'wp.combine_done');
  }

  Future<void> _openReview({int keep = 0}) async {
    final doc = _doc;
    if (doc == null) return;
    final bytes = await doc.saveAsync();
    final items = await DocxPro.query(bytes, DocxReviewTools.items);
    if (!mounted) return;
    if (items.isEmpty) {
      _setState(() => _review = null);
      showSnack(context, context.t('wp.review_none'));
      return;
    }
    _setState(() {
      _review = items;
      _reviewAt = keep.clamp(0, items.length - 1).toInt();
    });
    _placeCaret(items[_reviewAt].para);
  }

  void _reviewGo(int d) {
    final r = _review;
    if (r == null || r.isEmpty) return;
    _setState(() => _reviewAt = (_reviewAt + d) % r.length);
    _placeCaret(r[_reviewAt].para);
  }

  Future<void> _reviewResolve(bool accept) async {
    final r = _review;
    if (r == null) return;
    final item = r[_reviewAt];
    final ok = await _proApply(DocxReviewTools.resolve(item.para, accept: accept),
        keepPara: item.para);
    if (ok) await _openReview(keep: _reviewAt);
  }

  Widget _reviewBar() {
    final r = _review!;
    final item = r[_reviewAt.clamp(0, r.length - 1)];
    final scheme = Theme.of(context).colorScheme;
    final tracked = item.kind != 'comment';
    return Material(
      key: const ValueKey('word-review-bar'),
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_reviewAt + 1}/${r.length} · ${context.t('wp.review_${item.kind}')}'
                  '${item.author.isEmpty ? '' : ' · ${item.author}'}',
                  style: context.type.small.copyWith(color: scheme.primary),
                ),
                Text(item.text, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
              key: const ValueKey('word-review-prev'),
              tooltip: context.t('wp.review_prev'),
              icon: const Icon(AppIcons.keyboardArrowUp),
              onPressed: () => _reviewGo(-1)),
          IconButton(
              key: const ValueKey('word-review-next'),
              tooltip: context.t('wp.review_next'),
              icon: const Icon(AppIcons.keyboardArrowDown),
              onPressed: () => _reviewGo(1)),
          if (tracked) ...[
            IconButton(
                key: const ValueKey('word-review-accept'),
                tooltip: context.t('word.track_accept'),
                icon: const Icon(AppIcons.check),
                onPressed: _proBusy ? null : () => _reviewResolve(true)),
            IconButton(
                key: const ValueKey('word-review-reject'),
                tooltip: context.t('word.track_reject'),
                icon: const Icon(AppIcons.removeCircleOutline),
                onPressed: _proBusy ? null : () => _reviewResolve(false)),
          ] else
            IconButton(
                key: const ValueKey('word-review-open'),
                tooltip: context.t('word.comments'),
                icon: const Icon(AppIcons.comment),
                onPressed: () => _comments(focus: item.commentId)),
          IconButton(
              tooltip: context.t('common.close'),
              icon: const Icon(AppIcons.close),
              onPressed: () => _setState(() => _review = null)),
        ]),
      ),
    );
  }

  /// Parolalı belgeyi açar: en çok 5 deneme; vazgeçilirse null.
  Future<Uint8List?> _unlock(Uint8List bytes) async {
    String? hint;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!mounted) return null;
      final pw = await showAppSheet<String>(
        context,
        title: context.t('wp.password_open'),
        builder: (_) => _WordPasswordSheet(error: hint),
      );
      if (pw == null) {
        _error = AppStrings.current.t('xp.password_cancelled');
        return null;
      }
      try {
        final plain = await OfficeCrypto.decryptInBackground(bytes, pw);
        _filePassword = pw;
        return plain;
      } on OfficeCryptoException catch (e) {
        if (e.code != 'wrong_password') {
          _error = AppStrings.current.t('wp.password_unsupported');
          return null;
        }
        hint = AppStrings.current.t('xp.password_wrong');
      }
    }
    _error = AppStrings.current.t('xp.password_wrong');
    return null;
  }

  Future<void> _passwordMenu() async {
    final has = _filePassword != null;
    final v = await _choose('wp.password', [
      ('set', has ? 'wp.password_change' : 'xp.password_set'),
      if (has) ('remove', 'xp.password_remove'),
    ]);
    if (v == null || !mounted) return;
    if (v == 'remove') {
      _setState(() => _filePassword = null);
      _session.changed();
      showSnack(context, context.t('xp.password_removed'));
      return;
    }
    final pw = await showAppSheet<String>(
      context,
      title: context.t('xp.password_set'),
      builder: (_) => const _WordPasswordSheet(confirm: true),
    );
    if (pw == null || pw.isEmpty || !mounted) return;
    _setState(() => _filePassword = pw);
    _session.changed();
    showSnack(context, context.t('xp.password_set_done'));
  }

  // ── Madde 6: sesle yazma + satır içi AI ──────────────────────────────────

  String get _speechLang => switch (AppStrings.of(context).language) {
        AppLanguage.en => 'en-US',
        AppLanguage.ar => 'ar',
        _ => 'tr-TR',
      };

  Future<void> _dictate() async {
    final c = _ctrl;
    if (c == null) return;
    final unavailable = context.t('wp.dictate_unavailable');
    try {
      final text = await Dictation.listen(
          lang: _speechLang, prompt: context.t('wp.dictate_prompt'));
      if (text == null || !mounted) return;
      // Sözcük arası boşluk: imleç bir harfin hemen ardındaysa.
      final p = c.paras[c.extent.para];
      final before = c.extent.offset > 0 ? p.text[c.extent.offset - 1] : ' ';
      c.replaceSelection(before.trim().isEmpty ? text : ' $text');
    } on DictationUnavailable {
      if (mounted) showSnack(context, unavailable);
    } catch (e) {
      if (mounted) showSnack(context, userErrorText(e));
    }
  }

  /// Seçim (yoksa imleç paragrafı) üzerinde AI görevi; önizleme → onay.
  Future<void> _aiInline() async {
    final c = _ctrl;
    if (c == null) return;
    if (c.collapsed) {
      final i = c.extent.para;
      c.select(DocPos(i, 0), DocPos(i, c.paras[i].length));
    }
    final text = c.selectedText();
    if (text.trim().isEmpty) {
      showSnack(context, context.t('wp.ai_empty'));
      return;
    }
    final r = await showAppSheet<(String, String)>(
      context,
      title: context.t('wp.ai_inline'),
      builder: (_) => _AiInlineSheet(text: text),
    );
    if (r == null || !mounted) return;
    if (r.$1 == 'below') {
      final e = c.end;
      c.select(DocPos(e.para, c.paras[e.para].length),
          DocPos(e.para, c.paras[e.para].length));
      c.insertText('\n${r.$2}');
    } else {
      c.replaceSelection(r.$2);
    }
  }

  // ── Madde 7 + 11: dışa aktarım ───────────────────────────────────────────

  String get _baseName {
    final n = widget.name;
    final dot = n.lastIndexOf('.');
    return dot > 0 ? n.substring(0, dot) : n;
  }

  Future<void> _export() async {
    final fmt = await _choose('wp.export', _exportFormats);
    if (fmt == null || !mounted) return;
    await _exportFormat(fmt);
  }

  /// Faz 40 / 7: tek "Paylaş / Dışa aktar" sayfası — biçimler (PDF, DOCX,
  /// ODT, RTF, MD, TXT) üstte, gönderme yolları altta.
  Future<void> _shareExport() => showShareExportSheet(context, entries: [
        for (final (id, label) in _exportFormats)
          ShareExportEntry(
            id: id,
            icon: id == 'pdf' ? AppIcons.pdf : AppIcons.newWord,
            label: context.t(label),
            run: () => _exportFormat(id),
          ),
        ShareExportEntry.nearby(context, path: widget.path,
            beforeSend: () async {
          if (_session.isDirty) await _session.saveNow();
        }),
      ]);

  Future<void> _exportFormat(String fmt) async {
    final bytes = await _exportBytes(fmt);
    if (bytes == null || !mounted) return;
    final ext = fmt == 'docx_fonts' ? 'docx' : fmt;
    final name = '$_baseName.$ext';
    final how = await _choose('wp.export', const [
      ('save', 'wp.export_save'),
      ('share', 'common.share'),
    ]);
    if (how == null || !mounted) return;
    if (how == 'share') {
      final f = File('${Directory.systemTemp.path}/$name');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)], text: name);
    } else {
      await runDownloadAction(context, () => SaveToDownloads.saveBytes(name, bytes));
    }
  }

  /// Dışa aktarım biçimleri (kimlik, etiket).
  List<(String, String)> get _exportFormats => const [
        ('pdf', 'wp.export_pdf'),
        ('docx_fonts', 'wp.export_docx_fonts'),
        ('odt', 'wp.export_odt'),
        ('rtf', 'wp.export_rtf'),
        ('md', 'wp.export_md'),
        ('txt', 'wp.export_txt'),
      ];

  Future<Uint8List?> _exportBytes(String fmt) async {
    final doc = _doc;
    if (doc == null) return null;
    if (fmt == 'pdf') return _renderPdf();
    final failed = context.t('wp.failed');
    _setState(() => _proBusy = true);
    try {
      final bytes = await doc.saveAsync();
      switch (fmt) {
        case 'docx_fonts':
          final fonts = await DocxPdfFonts.load();
          return await DocxPro.run(bytes, DocxFonts.embed(fonts.files));
        default:
          return await DocxExportFormats.inBackground(bytes, fmt);
      }
    } catch (e) {
      if (mounted) showSnack(context, failed.replaceAll('{error}', userErrorText(e)));
      return null;
    } finally {
      _setState(() => _proBusy = false);
    }
  }

  // ── Madde 8: gezinti ağacı, küçük resimler, sayaç ────────────────────────

  /// Sayfa tahmini (artımlı; yalnız değişen paragraflar ölçülür).
  List<int> _layoutPages() {
    final c = _ctrl!;
    final ps = c.pageSetup;
    // pgSz yönlü yazılır (yatayda w uzun kenar).
    final wPt = ps.width / 20 - (ps.left + ps.right) / 20;
    final hPt = ps.height / 20 - (ps.top + ps.bottom) / 20;
    final g = DocxPageGeometry(wPt.clamp(100, 2000).toDouble(), hPt.clamp(100, 3000).toDouble());
    if (_paginator.geometry.widthPt != g.widthPt || _paginator.geometry.heightPt != g.heightPt) {
      _paginator = DocxPaginator(g);
    }
    return _paginator.layout(c.paras);
  }

  Future<void> _outline() async {
    final c = _ctrl;
    if (c == null) return;
    final hs = c.headings();
    if (hs.isEmpty) {
      showSnack(context, context.t('word.no_headings'));
      return;
    }
    final pages = _layoutPages();
    final caret = c.extent.para;
    var current = -1;
    for (var k = 0; k < hs.length; k++) {
      if (hs[k].$1 <= caret) current = k;
    }
    final i = await showAppSheet<int>(
      context,
      title: context.t('wp.outline'),
      builder: (_) => _OutlineTree(headings: hs, pages: pages, current: current),
    );
    if (i == null || !mounted) return;
    c.goToParagraph(i);
    await _viewKey.currentState?.revealParagraph(i);
  }

  Future<void> _thumbnails() async {
    final pdf = await _renderPdf();
    if (pdf == null || !mounted) return;
    _layoutPages();
    final page = await showAppSheet<int>(
      context,
      title: context.t('wp.thumbnails'),
      builder: (_) => _ThumbGrid(pdf: pdf),
    );
    if (page == null || !mounted) return;
    final i = _paginator.firstParaOf(page);
    _ctrl?.goToParagraph(i);
    await _viewKey.currentState?.revealParagraph(i);
  }

  Future<void> _stats() async {
    final c = _ctrl;
    if (c == null) return;
    _layoutPages();
    final selected = !c.collapsed;
    final st = DocxStats.of(c.paras, pages: _paginator.pageCount);
    String dur(Duration d) => d.inMinutes < 1
        ? context.t('wp.stats_under_min')
        : context.t('wp.stats_min', {'n': d.inMinutes});
    final rows = [
      ('word.count_words', '${st.words}'),
      ('word.count_chars', '${st.chars}'),
      ('word.count_chars_ns', '${st.charsNoSpace}'),
      ('word.count_paras', '${st.paragraphs}'),
      ('wp.stats_pages', '~${st.pages}'),
      ('wp.stats_headings', '${st.headings}'),
      ('wp.stats_reading', dur(st.reading)),
      ('wp.stats_speaking', dur(st.speaking)),
      if (selected)
        ('wp.stats_selection', '${RegExp(r'\S*[\p{L}\p{N}]\S*', unicode: true).allMatches(c.selectedText()).length}'),
    ];
    await showAppSheet<void>(
      context,
      title: context.t('wp.stats'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (k, v) in rows)
            ListTile(
              dense: true,
              title: Text(ctx.t(k)),
              trailing: Text(v, style: Theme.of(ctx).textTheme.titleMedium),
            ),
        ],
      ),
    );
  }

  // ── Madde 9: yerleşim öğeleri ────────────────────────────────────────────

  /// İmlece işaret yazıp paket işlemini koşturur; başarısızsa işaret geri
  /// alınır.
  Future<void> _atCaret(DocxOp op) async {
    final c = _ctrl;
    if (c == null) return;
    final caret = c.extent.para;
    c.replaceSelection(kDocxMarker);
    final ok = await _proApply(op, keepPara: caret);
    if (!ok && mounted) c.undo();
  }

  Future<void> _imageWrap() async {
    final doc = _doc;
    final c = _ctrl;
    if (doc == null || c == null) return;
    final i = c.extent.para;
    final cur = await DocxPro.query(await doc.saveAsync(), _wrapQuery(i));
    if (!mounted) return;
    final v = await showAppSheet<String>(
      context,
      title: context.t('wp.img_wrap'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in kDocxWrapModes)
            ListTile(
              key: ValueKey('word-choose-$m'),
              title: Text(ctx.t('wp.wrap_$m')),
              trailing: m == cur ? const Icon(AppIcons.check) : null,
              onTap: () => Navigator.pop(ctx, m),
            ),
        ],
      ),
    );
    if (v != null && v != cur) await _proApply(DocxInsertPro.imageWrap(i, v));
  }

  static String? Function(DocxPackage) _wrapQuery(int i) =>
      (pkg) => DocxInsertPro.wrapOf(pkg, i);

  Future<void> _cover() async {
    final now = DateTime.now();
    final r = await showAppSheet<List<String>>(
      context,
      title: context.t('wp.cover'),
      builder: (_) => _FormSheet(fields: [
        ('title', context.t('wp.cover_title'), ''),
        ('subtitle', context.t('wp.cover_subtitle'), ''),
        ('author', context.t('wp.cover_author'), ''),
        ('date', context.t('wp.cover_date'),
            '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}'),
      ]),
    );
    if (r == null || r.first.trim().isEmpty || !mounted) return;
    await _proApply(DocxInsertPro.cover(r[0].trim(), r[1].trim(), r[2].trim(), r[3].trim()),
        keepPara: 0, doneKey: 'wp.cover_done');
  }

  Future<void> _field() async {
    final v = await _choose('wp.field', [
      for (final k in kDocxFieldCodes.keys) (k, 'wp.field_$k'),
    ]);
    if (v == null || !mounted) return;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final result = switch (v) {
      'date' => '${two(now.day)}.${two(now.month)}.${now.year}',
      'time' => '${two(now.hour)}:${two(now.minute)}',
      'page' => '1',
      'numpages' => '${_paginator.pageCount}',
      'filename' => widget.name,
      _ => '',
    };
    await _atCaret(DocxInsertPro.field(kDocxFieldCodes[v]!, result));
  }

  Future<void> _crossRef() async {
    final c = _ctrl;
    if (c == null) return;
    final hs = c.headings();
    if (hs.isEmpty) {
      showSnack(context, context.t('word.no_headings'));
      return;
    }
    final target = await showAppSheet<int>(
      context,
      title: context.t('wp.cross_ref'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, level, text) in hs)
            ListTile(
              key: ValueKey('word-xref-$i'),
              contentPadding: EdgeInsetsDirectional.only(
                  start: 16.0 + (level - 1).clamp(0, 4) * 16, end: 16),
              title: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(ctx, i),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final kind = await _choose('wp.cross_ref', const [
      ('text', 'wp.xref_text'),
      ('page', 'wp.xref_page'),
      ('above', 'wp.xref_above'),
    ]);
    if (kind == null || !mounted) return;
    final pages = _layoutPages();
    final heading = hs.firstWhere((h) => h.$1 == target).$3;
    final result = switch (kind) {
      'page' => '${target < pages.length ? pages[target] + 1 : 1}',
      'above' => context.t(target < c.extent.para ? 'wp.xref_is_above' : 'wp.xref_is_below'),
      _ => heading,
    };
    await _atCaret(DocxInsertPro.crossRef(target, kind, result: result));
  }

  Future<void> _cite() async {
    final r = await showAppSheet<List<String>>(
      context,
      title: context.t('wp.bibliography'),
      builder: (_) => _FormSheet(fields: [
        ('author', context.t('wp.src_author'), ''),
        ('year', context.t('wp.src_year'), ''),
        ('title', context.t('wp.src_title'), ''),
        ('publisher', context.t('wp.src_publisher'), ''),
      ]),
    );
    if (r == null || r[0].trim().isEmpty || r[2].trim().isEmpty || !mounted) return;
    final heading = context.t('wp.bibliography');
    await _atCaret(DocxInsertPro.cite(
        DocxSource(r[0].trim(), r[1].trim(), r[2].trim(), r[3].trim()),
        heading: heading));
  }

  // ── Madde 10: AI yazım denetimi (kullanıcı onaylı) ───────────────────────

  Future<void> _aiProof() async {
    final c = _ctrl;
    if (c == null) return;
    final scope = await _choose('wp.ai_proof', const [
      ('para', 'wp.proof_para'),
      ('doc', 'wp.proof_doc'),
    ]);
    if (scope == null || !mounted) return;
    final from = scope == 'doc' ? 0 : c.start.para;
    final to = scope == 'doc' ? c.paras.length - 1 : c.end.para;
    final chunks = proofChunks([
      for (var i = from; i <= to; i++)
        if (!c.paras[i].opaque) (i, c.paras[i].text.replaceAll(kDocxAtom, ' ')),
    ]);
    if (chunks.isEmpty) {
      showSnack(context, context.t('wp.ai_empty'));
      return;
    }
    await showAppSheet<void>(
      context,
      title: context.t('wp.ai_proof'),
      builder: (_) => _ProofSheet(
        chunks: chunks,
        language: switch (AppStrings.of(context).language) {
          AppLanguage.en => 'English',
          AppLanguage.ar => 'Arabic',
          _ => 'Türkçe',
        },
        apply: _applyFix,
      ),
    );
  }

  /// Öneriyi uygular: paragrafta ilk geçişi değiştirir (geri alınabilir).
  bool _applyFix(int para, String wrong, String right) {
    final c = _ctrl;
    if (c == null || para >= c.paras.length) return false;
    final k = c.paras[para].text.indexOf(wrong);
    if (k < 0) return false;
    c.select(DocPos(para, k), DocPos(para, k + wrong.length));
    c.replaceSelection(right);
    return true;
  }
}

/// Sayfa düzeni levhası: kâğıt, yön, kenar boşlukları (cm), cilt payı,
/// sütun, farklı ilk sayfa. Döner: ('apply' | 'preview' | 'break', değerler).
class _PageSetupSheet extends StatefulWidget {
  final DocxPageSpec spec;
  const _PageSetupSheet({required this.spec});

  @override
  State<_PageSetupSheet> createState() => _PageSetupSheetState();
}

class _PageSetupSheetState extends State<_PageSetupSheet> {
  late DocxPageSpec _s = widget.spec;
  late final _fields = {
    'top': TextEditingController(text: _cm(_s.top)),
    'bottom': TextEditingController(text: _cm(_s.bottom)),
    'left': TextEditingController(text: _cm(_s.left)),
    'right': TextEditingController(text: _cm(_s.right)),
    'gutter': TextEditingController(text: _cm(_s.gutter)),
  };

  static String _cm(int tw) =>
      DocxPageSpec.twipToCm(tw).toStringAsFixed(2).replaceAll(RegExp(r'0$'), '');

  @override
  void dispose() {
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  String get _paper {
    final short = _s.width < _s.height ? _s.width : _s.height;
    final long = _s.width < _s.height ? _s.height : _s.width;
    for (final e in kDocxPaperSizes.entries) {
      if ((e.value.$1 - short).abs() <= 40 && (e.value.$2 - long).abs() <= 40) {
        return e.key;
      }
    }
    return 'custom';
  }

  DocxPageSpec _collect() {
    int f(String k, int def) {
      final v = double.tryParse(_fields[k]!.text.replaceAll(',', '.'));
      if (v == null || v < 0 || v > 20) return def;
      return DocxPageSpec.cmToTwip(v);
    }

    return _s.copyWith(
      top: f('top', _s.top),
      bottom: f('bottom', _s.bottom),
      left: f('left', _s.left),
      right: f('right', _s.right),
      gutter: f('gutter', _s.gutter),
    );
  }

  Widget _field(String k) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: TextField(
            key: ValueKey('word-ps-$k'),
            controller: _fields[k],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: context.t('wp.margin_$k'), suffixText: 'cm',
                isDense: true),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final paper = _paper;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(context.t('word.paper_size'))),
            DropdownButton<String>(
              key: const ValueKey('word-ps-paper'),
              value: paper,
              onChanged: (k) {
                final v = kDocxPaperSizes[k];
                if (v == null) return;
                setState(() => _s = _s.copyWith(width: v.$1, height: v.$2));
              },
              items: [
                for (final k in kDocxPaperSizes.keys)
                  DropdownMenuItem(value: k, child: Text(k.toUpperCase())),
                if (paper == 'custom')
                  DropdownMenuItem(
                      value: 'custom', child: Text(context.t('wp.custom'))),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            key: const ValueKey('word-ps-orient'),
            segments: [
              ButtonSegment(value: false, label: Text(context.t('word.portrait'))),
              ButtonSegment(value: true, label: Text(context.t('word.landscape'))),
            ],
            selected: {_s.landscape},
            onSelectionChanged: (v) =>
                setState(() => _s = _s.copyWith(landscape: v.first)),
          ),
          const SizedBox(height: 12),
          Text(context.t('word.margins'), style: context.type.small),
          Row(children: [_field('top'), _field('bottom')]),
          Row(children: [_field('left'), _field('right')]),
          Row(children: [_field('gutter'), const Spacer()]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(context.t('word.columns'))),
            SegmentedButton<int>(
              key: const ValueKey('word-ps-cols'),
              segments: [
                for (final n in const [1, 2, 3])
                  ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {_s.columns.clamp(1, 3)},
              onSelectionChanged: (v) =>
                  setState(() => _s = _s.copyWith(columns: v.first)),
            ),
          ]),
          SwitchListTile(
            key: const ValueKey('word-ps-title'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('wp.title_page')),
            value: _s.titlePage,
            onChanged: (v) => setState(() => _s = _s.copyWith(titlePage: v)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('word-ps-break'),
                icon: const Icon(AppIcons.wrapText),
                label: Text(context.t('word.insert_break')),
                onPressed: () => Navigator.pop(context, ('break', _s)),
              ),
              OutlinedButton.icon(
                key: const ValueKey('word-ps-preview'),
                icon: const Icon(AppIcons.print),
                label: Text(context.t('wp.print_preview')),
                onPressed: () => Navigator.pop(context, ('preview', _collect())),
              ),
              FilledButton(
                key: const ValueKey('word-ps-apply'),
                onPressed: () => Navigator.pop(context, ('apply', _collect())),
                child: Text(context.t('common.apply')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Denklem levhası: LaTeX girişi + hızlı simgeler.
class _EquationSheet extends StatefulWidget {
  final String initial;
  const _EquationSheet({required this.initial});

  @override
  State<_EquationSheet> createState() => _EquationSheetState();
}

class _EquationSheetState extends State<_EquationSheet> {
  late final _t = TextEditingController(text: widget.initial);

  static const _snippets = [
    (r'\frac{a}{b}', 'a/b'),
    (r'x^{2}', 'x²'),
    (r'x_{i}', 'xᵢ'),
    (r'\sqrt{x}', '√x'),
    (r'\sum_{i=1}^{n} ', '∑'),
    (r'\int_{a}^{b} ', '∫'),
    (r'\left( \right)', '( )'),
    (r'\pi', 'π'),
    (r'\alpha', 'α'),
    (r'\theta', 'θ'),
    (r'\infty', '∞'),
    (r'\pm', '±'),
    (r'\times', '×'),
    (r'\leq', '≤'),
    (r'\geq', '≥'),
    (r'\neq', '≠'),
  ];

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _insert(String snippet) {
    final sel = _t.selection;
    final text = _t.text;
    final at = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final out = text.replaceRange(at, end, snippet);
    _t.value = TextEditingValue(
        text: out,
        selection: TextSelection.collapsed(offset: at + snippet.length));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('word-eq-field'),
            controller: _t,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            style: context.type.body.copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: context.t('wp.equation_latex'),
              hintText: r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (snip, label) in _snippets)
                ActionChip(
                  label: Text(label),
                  onPressed: () => _insert(snip),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('word-eq-ok'),
              onPressed: () => Navigator.pop(context, _t.text),
              child: Text(context.t(widget.initial.isEmpty ? 'common.insert' : 'common.apply')),
            ),
          ),
        ],
      ),
    );
  }
}


/// Gizli girişli parola levhası; [confirm] → ikinci alan, eşleşme denetimi.
class _WordPasswordSheet extends StatefulWidget {
  final String? error;
  final bool confirm;
  const _WordPasswordSheet({this.error, this.confirm = false});

  @override
  State<_WordPasswordSheet> createState() => _WordPasswordSheetState();
}

class _WordPasswordSheetState extends State<_WordPasswordSheet> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _err;

  @override
  void initState() {
    super.initState();
    _err = widget.error;
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _ok() {
    if (_a.text.isEmpty) return;
    if (widget.confirm && _a.text != _b.text) {
      setState(() => _err = context.t('xp.password_mismatch'));
      return;
    }
    Navigator.pop(context, _a.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('word-pw-field'),
            controller: _a,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: context.t('xp.password')),
            onSubmitted: (_) => widget.confirm ? null : _ok(),
          ),
          if (widget.confirm)
            TextField(
              key: const ValueKey('word-pw-again'),
              controller: _b,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: context.t('xp.password_again')),
              onSubmitted: (_) => _ok(),
            ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_err!,
                  style: context.type.small
                      .copyWith(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('word-pw-ok'),
              onPressed: _ok,
              child: Text(context.t('common.ok')),
            ),
          ),
        ],
      ),
    );
  }
}


/// Satır içi AI levhası: görev çipleri → önizleme → Değiştir / Altına ekle.
/// İstek sürerken "Vazgeç" yanıtı yok sayar (iptal; anayasa: AI çağrıları
/// iptal edilebilir).
class _AiInlineSheet extends StatefulWidget {
  final String text;
  const _AiInlineSheet({required this.text});

  @override
  State<_AiInlineSheet> createState() => _AiInlineSheetState();
}

class _AiInlineSheetState extends State<_AiInlineSheet> {
  String? _task;
  String? _result;
  String? _error;
  int _gen = 0;
  bool _busy = false;
  String _lang = 'en';

  static const _langs = ['tr', 'en', 'de', 'fr', 'es', 'ar', 'ru'];

  Future<void> _run(String task) async {
    final state = context.read<AppState>();
    if (!state.hasApiKey) {
      setState(() => _error = context.t('aia.need_key'));
      return;
    }
    final instruction = context.t('wp.ai_p_$task',
        {'lang': context.t('wp.lang_$_lang')});
    final gen = ++_gen;
    setState(() {
      _task = task;
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final answer = await state.gemini.chat(history: [
        ChatTurn(fromUser: true, text: DocxAi.prompt(instruction, widget.text)),
      ]);
      if (!mounted || gen != _gen) return;
      setState(() {
        _busy = false;
        _result = DocxAi.clean(answer);
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _busy = false;
        _error = userErrorText(e);
      });
    }
  }

  void _cancel() => setState(() {
        _gen++;
        _busy = false;
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.type.small.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in kWordAiTasks)
                ChoiceChip(
                  key: ValueKey('word-ai-$t'),
                  label: Text(context.t('wp.ai_$t')),
                  selected: _task == t,
                  onSelected: _busy ? null : (_) => _run(t),
                ),
            ],
          ),
          Row(children: [
            Text(context.t('wp.ai_target')),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _lang,
              onChanged: _busy ? null : (v) => setState(() => _lang = v ?? _lang),
              items: [
                for (final l in _langs)
                  DropdownMenuItem(value: l, child: Text(context.t('wp.lang_$l'))),
              ],
            ),
          ]),
          if (_busy)
            Row(children: [
              const Expanded(child: LinearProgressIndicator()),
              TextButton(
                key: const ValueKey('word-ai-cancel'),
                onPressed: _cancel,
                child: Text(context.t('common.cancel')),
              ),
            ]),
          if (_error != null)
            Text(_error!, style: context.type.small.copyWith(color: scheme.error)),
          if (_result != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: SelectableText(_result!,
                    key: const ValueKey('word-ai-result')),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                OutlinedButton(
                  key: const ValueKey('word-ai-below'),
                  onPressed: () => Navigator.pop(context, ('below', _result!)),
                  child: Text(context.t('wp.ai_below')),
                ),
                FilledButton(
                  key: const ValueKey('word-ai-replace'),
                  onPressed: () => Navigator.pop(context, ('replace', _result!)),
                  child: Text(context.t('wp.ai_replace')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


/// Başlık ağacı: alt başlıkları olan düğüm katlanır; imlecin bulunduğu
/// başlık vurgulu; sağda tahmini sayfa.
class _OutlineTree extends StatefulWidget {
  final List<(int, int, String)> headings;
  final List<int> pages;
  final int current;
  const _OutlineTree(
      {required this.headings, required this.pages, required this.current});

  @override
  State<_OutlineTree> createState() => _OutlineTreeState();
}

class _OutlineTreeState extends State<_OutlineTree> {
  final _collapsed = <int>{};

  bool _hasKids(int k) {
    final hs = widget.headings;
    return k + 1 < hs.length && hs[k + 1].$2 > hs[k].$2;
  }

  bool _hidden(int k) {
    final hs = widget.headings;
    var level = hs[k].$2;
    for (var j = k - 1; j >= 0; j--) {
      if (hs[j].$2 < level) {
        if (_collapsed.contains(j)) return true;
        level = hs[j].$2;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hs = widget.headings;
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: hs.length,
        itemBuilder: (_, k) {
          if (_hidden(k)) return const SizedBox.shrink();
          final (i, level, text) = hs[k];
          final kidsHere = _hasKids(k);
          final page = i < widget.pages.length ? widget.pages[i] + 1 : null;
          return ListTile(
            key: ValueKey('word-outline-$i'),
            selected: k == widget.current,
            selectedTileColor: scheme.secondaryContainer,
            contentPadding: EdgeInsetsDirectional.only(
                start: 4.0 + (level - 1).clamp(0, 5) * 18, end: 12),
            leading: kidsHere
                ? IconButton(
                    key: ValueKey('word-outline-fold-$i'),
                    tooltip: context.t('wp.outline_fold'),
                    icon: Icon(_collapsed.contains(k)
                        ? AppIcons.keyboardArrowRight
                        : AppIcons.keyboardArrowDown),
                    onPressed: () => setState(() => _collapsed.contains(k)
                        ? _collapsed.remove(k)
                        : _collapsed.add(k)),
                  )
                : const SizedBox(width: 48),
            title: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: level == 1 ? const TextStyle(fontWeight: FontWeight.w600) : null),
            trailing: page == null ? null : Text('$page', style: context.type.small),
            onTap: () => Navigator.pop(context, i),
          );
        },
      ),
    );
  }
}

/// Sayfa küçük resimleri: PDF sayfaları düşük çözünürlükte, geldikçe
/// (akış); levha kapanınca akış durur. Görsel bütçesi: `cacheWidth`.
class _ThumbGrid extends StatefulWidget {
  final Uint8List pdf;
  const _ThumbGrid({required this.pdf});

  @override
  State<_ThumbGrid> createState() => _ThumbGridState();
}

class _ThumbGridState extends State<_ThumbGrid> {
  final _pages = <Uint8List>[];
  StreamSubscription<dynamic>? _sub;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _sub = Printing.raster(widget.pdf, dpi: 28).asyncMap((r) => r.toPng()).listen(
          (png) {
            if (mounted) setState(() => _pages.add(png));
          },
          onDone: () {
            if (mounted) setState(() => _done = true);
          },
          onError: (_) {
            if (mounted) setState(() => _done = true);
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const tileW = 104.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_done) const LinearProgressIndicator(minHeight: 2),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: tileW + 16,
                  mainAxisExtent: tileW * 1.414 + 28,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8),
              itemCount: _pages.length,
              itemBuilder: (_, i) => RepaintBoundary(
                child: InkWell(
                  key: ValueKey('word-thumb-$i'),
                  onTap: () => Navigator.pop(context, i),
                  child: Column(children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant)),
                        child: Image.memory(_pages[i],
                            cacheWidth: (tileW * dpr).round(),
                            fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${i + 1}', style: context.type.small),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Birkaç metin alanlı form levhası; değerleri sırayla döndürür.
class _FormSheet extends StatefulWidget {
  /// (kimlik, etiket, başlangıç değeri)
  final List<(String, String, String)> fields;
  const _FormSheet({required this.fields});

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  late final _c = [
    for (final f in widget.fields) TextEditingController(text: f.$3),
  ];

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: ValueKey('word-form-${widget.fields[i].$1}'),
                controller: _c[i],
                autofocus: i == 0,
                decoration: InputDecoration(labelText: widget.fields[i].$2),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('word-form-ok'),
              onPressed: () =>
                  Navigator.pop(context, [for (final c in _c) c.text]),
              child: Text(context.t('common.insert')),
            ),
          ),
        ],
      ),
    );
  }
}


/// Paragrafları ~3000 harflik parçalara toplar (tek istek = tek parça).
List<List<(int, String)>> proofChunks(List<(int, String)> paras, {int limit = 3000}) {
  final out = <List<(int, String)>>[];
  var cur = <(int, String)>[];
  var size = 0;
  for (final p in paras) {
    if (p.$2.trim().isEmpty) continue;
    if (size + p.$2.length > limit && cur.isNotEmpty) {
      out.add(cur);
      cur = [];
      size = 0;
    }
    cur.add(p);
    size += p.$2.length;
  }
  if (cur.isNotEmpty) out.add(cur);
  return out;
}

/// AI yazım denetimi levhası: parçalar sırayla gönderilir; her öneri
/// "Uygula / Atla" (belgeye kendiliğinden yazılmaz); "Durdur" iptal eder.
class _ProofSheet extends StatefulWidget {
  final List<List<(int, String)>> chunks;
  final String language;
  final bool Function(int para, String wrong, String right) apply;
  const _ProofSheet(
      {required this.chunks, required this.language, required this.apply});

  @override
  State<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends State<_ProofSheet> {
  final _items = <(int, ProofSuggestion)>[];
  int _done = 0;
  bool _stopped = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _stopped = true;
    super.dispose();
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    if (!state.hasApiKey) {
      setState(() => _error = context.t('aia.need_key'));
      return;
    }
    for (final chunk in widget.chunks) {
      if (_stopped || !mounted) return;
      final text = chunk.map((p) => p.$2).join('\n');
      try {
        final answer = await state.gemini.chat(history: [
          ChatTurn(fromUser: true, text: DocxAi.proofPrompt(text, widget.language)),
        ]);
        if (_stopped || !mounted) return;
        final found = DocxAi.parseProof(answer, text);
        setState(() {
          for (final s in found) {
            final p = chunk.firstWhere((x) => x.$2.contains(s.wrong), orElse: () => chunk.first);
            _items.add((p.$1, s));
          }
          _done++;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = userErrorText(e);
          _done = widget.chunks.length;
        });
        return;
      }
    }
  }

  void _apply(int k) {
    final (para, s) = _items[k];
    widget.apply(para, s.wrong, s.right);
    setState(() => _items.removeAt(k));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _done < widget.chunks.length && !_stopped && _error == null;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                    child: LinearProgressIndicator(
                        value: (_done + 0.5) / widget.chunks.length)),
                TextButton(
                  key: const ValueKey('word-proof-stop'),
                  onPressed: () => setState(() => _stopped = true),
                  child: Text(context.t('wp.proof_stop')),
                ),
              ]),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: context.type.small.copyWith(color: scheme.error)),
            ),
          if (!busy && _items.isEmpty && _error == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.t('wp.proof_clean'), textAlign: TextAlign.center),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _items.length,
              itemBuilder: (_, k) {
                final s = _items[k].$2;
                return ListTile(
                  key: ValueKey('word-proof-$k'),
                  title: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: s.wrong,
                        style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: scheme.error)),
                    const TextSpan(text: '  →  '),
                    TextSpan(
                        text: s.right,
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                  ])),
                  subtitle: s.reason.isEmpty ? null : Text(s.reason),
                  trailing: Wrap(spacing: 4, children: [
                    IconButton(
                      key: ValueKey('word-proof-skip-$k'),
                      tooltip: context.t('wp.proof_skip'),
                      icon: const Icon(AppIcons.close),
                      onPressed: () => setState(() => _items.removeAt(k)),
                    ),
                    IconButton(
                      key: ValueKey('word-proof-apply-$k'),
                      tooltip: context.t('wp.proof_apply'),
                      icon: const Icon(AppIcons.check),
                      onPressed: () => _apply(k),
                    ),
                  ]),
                );
              },
            ),
          ),
          if (_items.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(
                key: const ValueKey('word-proof-all'),
                onPressed: () {
                  for (final (para, s) in _items) {
                    widget.apply(para, s.wrong, s.right);
                  }
                  setState(_items.clear);
                },
                child: Text(context.t('wp.proof_apply_all', {'n': _items.length})),
              ),
            ),
        ],
      ),
    );
  }
}
