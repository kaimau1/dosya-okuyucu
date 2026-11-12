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
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: name));
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
