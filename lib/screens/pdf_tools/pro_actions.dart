part of '../pdf_tools_screen.dart';

/// **Faz 39 — PDF pro araçları.** Tek menü girdisi ("Pro araçlar…") bir
/// levha açar; her araç [_PdfToolsScreenState._apply] kapısından geçer
/// (geri alma, iz, izolat). Ağır işlerin hepsi `…InBackground`.
extension _PdfToolsProPart on _PdfToolsScreenState {
  Future<void> _openProTools() async {
    if (_bytes == null || _busy) return;
    final id = await showAppSheet<String>(
      context,
      title: context.t('pp.title'),
      builder: (_) => const _ProToolsSheet(),
    );
    if (id == null || !mounted) return;
    await switch (id) {
      'dsign' => _digitalSign(),
      'dsign_list' => _showSignatures(),
      'redact' => _redact(),
      'to_xlsx' => _exportTables(),
      'to_docx' => _exportDocx(),
      'pdfa' => _exportPdfA(),
      'compare' => _compare(),
      'permissions' => _permissions(),
      'outline' => _editOutline(),
      'stamp' => _stamp(),
      'numbering' => _numbering(),
      'compress_hard' => _compressHard(),
      'reorder' => _reorderPages(),
      'blank' => _findBlankPages(),
      'crop' => _cropPages(),
      'fit_a4' => _fitA4(),
      'form_create' => _createForm(),
      'form_profile' => showAutofillProfileSheet(context),
      _ => Future<void>.value(),
    };
  }

  /// Türkçe glifli yazı tipi (görünür imza/damga). Okunamazsa `null` →
  /// standart font.
  Future<List<int>?> _unicodeFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Carlito-Bold.ttf');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ── 1. Dijital imza ──────────────────────────────────────────────────────

  Future<void> _digitalSign() async {
    final existing = await PdfDigitalSign.loadIdentity();
    if (!mounted) return;
    final opts = await showAppSheet<_DSignOptions>(
      context,
      title: context.t('pp.dsign'),
      builder: (_) => _DigitalSignSheet(
          initialName: existing?.name ?? '', hasIdentity: existing != null),
    );
    if (opts == null || !mounted) return;
    if (opts.exportCertificate) {
      if (existing == null) return;
      final path = await PdfDigitalSign.exportCertificate(existing);
      await Share.shareXFiles([XFile(path)]);
      return;
    }
    final pages = await _pageCount();
    final request = DigitalSignRequest(
      pageIndex: opts.lastPage ? pages - 1 : 0,
      bounds: null,
      visible: opts.visible,
      signerName: opts.name,
      reason: opts.reason,
      location: opts.location,
      signedAt: DateTime.now(),
      fontBytes: await _unicodeFont(),
    );
    final pw = _password;
    final before = _bytes;
    final label = _str.t('pp.dsign_working');
    if (opts.pfx) {
      final res = await AppFilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pfx', 'p12'],
      );
      final path = res?.files.single.path;
      if (path == null || !mounted) return;
      final pfx = await File(path).readAsBytes();
      final pass = await _askPassword(
          _str.t('pp.dsign_pfx'), _str.t('pp.dsign_pfx_password'));
      if (pass == null || !mounted) return;
      await _apply(
        label,
        (b) => PdfDigitalSign.signWithPfxInBackground(b,
            pfx: pfx, pfxPassword: pass, request: request, password: pw),
      );
    } else {
      var identity = existing;
      if (identity == null || identity.name != opts.name) {
        _partSetState(() => _busyLabel = '${_str.t('pp.dsign_creating')}…');
        try {
          identity = await PdfDigitalSign.createIdentityInBackground(opts.name);
          await PdfDigitalSign.saveIdentity(identity);
        } catch (e) {
          if (mounted) {
            _snackError(_str.t('pt.op_failed',
                {'label': label, 'error': userErrorText(e)}));
          }
          return;
        } finally {
          if (mounted) _partSetState(() => _busyLabel = '');
        }
        if (!mounted) return;
      }
      final id = identity;
      await _apply(
        label,
        (b) => PdfDigitalSign.signWithIdentityInBackground(b,
            identity: id, request: request, password: pw),
      );
    }
    if (mounted && !identical(before, _bytes)) _snack(_str.t('pp.dsign_done'));
  }

  Future<void> _showSignatures() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final pw = _password;
    final list = await Isolate.run(
        () => PdfDigitalSign.signatures(bytes, password: pw));
    if (!mounted) return;
    await showAppSheet<void>(
      context,
      title: context.t('pp.dsign_list'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (list.isEmpty)
            ListTile(title: Text(ctx.t('pp.dsign_none'))),
          for (final s in list)
            ListTile(
              leading: Icon(s.signed ? AppIcons.pdfSignCert : AppIcons.draw),
              title: Text(s.name),
              subtitle: Text(ctx.t(
                  s.signed ? 'pp.dsign_signed' : 'pp.dsign_empty_field')),
            ),
        ],
      ),
    );
  }

  // ── 2. Kalıcı karartma ───────────────────────────────────────────────────

  Future<void> _redact() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final pw = _password;
    final terms = await showAppPrompt(
      context,
      title: context.t('pp.redact'),
      label: context.t('pp.redact_terms_hint'),
      confirmLabel: context.t('pp.redact_find'),
    );
    if (!mounted) return;
    var initial = const <int, List<Rect>>{};
    if (terms != null) {
      _partSetState(() => _busyLabel = '${_str.t('pp.redact_searching')}…');
      try {
        initial = await PdfRedact.findTextInBackground(
            bytes, terms.split(','), password: pw);
      } catch (_) {
        initial = const {};
      } finally {
        if (mounted) _partSetState(() => _busyLabel = '');
      }
      if (!mounted) return;
      if (initial.isEmpty) _snack(_str.t('pp.redact_no_match'));
    }
    final marks = await PdfRegionScreen.open(
      context,
      bytes: bytes,
      mode: PdfRegionMode.redact,
      password: pw,
      initial: initial,
      title: context.t('pp.redact'),
    );
    if (marks == null || marks.isEmpty || !mounted) return;
    final ok = await showAppConfirm(
      context,
      title: context.t('pp.redact'),
      message: context.t('pp.redact_confirm', {
        'n': marks.values.fold<int>(0, (s, l) => s + l.length),
        'pages': marks.length,
      }),
      confirmLabel: context.t('pp.redact_apply'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final font = await _unicodeFont();
    final before = _bytes;
    final pages = marks.keys.toList()..sort();
    await _apply(_str.t('pp.redact'), (b) async {
      final rasters = await PdfRaster.renderJpegs(b, pages,
          password: pw, dpi: 150, quality: 85, blackout: marks);
      return PdfRedact.applyInBackground(
        b,
        rects: marks,
        rasters: [for (final r in rasters) RedactedRaster(r.index, r.jpeg)],
        fontBytes: font,
        password: pw,
      );
    });
    if (!mounted || identical(before, _bytes)) return;
    // Yeni belge sıfırdan yazıldı: parola taşınmaz.
    _partSetState(() => _password = null);
    _snack(_str.t('pp.redact_done'));
  }

  // ── 3. Excel / Word / PDF-A ──────────────────────────────────────────────

  /// Çıktıyı özgünün yanına (yazılamazsa Belgeler'e) benzersiz adla yazar,
  /// "Paylaş" eylemli şerit gösterir.
  Future<void> _saveSibling(List<int> data, String suffix, String ext) async {
    final base = '${p.basenameWithoutExtension(widget.path)}$suffix';
    String path;
    try {
      path = LegacyConvert.uniquePath(File(widget.path).parent.path, base, ext);
      await File(path).writeAsBytes(data, flush: true);
    } on FileSystemException {
      final dir = await DocsHome.resolve();
      path = LegacyConvert.uniquePath(dir.path, base, ext);
      await File(path).writeAsBytes(data, flush: true);
    }
    if (!mounted) return;
    showSnack(
      context,
      _str.t('pp.saved_as', {'name': p.basename(path)}),
      action: SnackBarAction(
        label: _str.t('common.share'),
        onPressed: () => unawaited(Share.shareXFiles([XFile(path)])),
      ),
    );
  }

  /// Dosya üreten (belgeyi değiştirmeyen) iş: meşgul şeridi + hata şeridi.
  Future<void> _produce(String label, Future<void> Function() job) async {
    if (_busy) return;
    _partSetState(() => _busyLabel = '$label…');
    try {
      await job();
    } catch (e) {
      if (mounted) {
        _snackError(
            _str.t('pt.op_failed', {'label': label, 'error': userErrorText(e)}));
      }
    } finally {
      if (mounted) _partSetState(() => _busyLabel = '');
    }
  }

  List<int>? _selectedOrNull() =>
      _selected.isEmpty ? null : (_selected.toList()..sort());

  Future<void> _exportTables() async {
    final bytes = _bytes!;
    final pw = _password;
    final pages = _selectedOrNull();
    final prefix = _str.t('pp.sheet_prefix');
    await _produce(_str.t('pp.to_xlsx'), () async {
      final xlsx = await PdfExportPro.tablesToXlsxInBackground(bytes,
          password: pw, pages: pages, sheetPrefix: prefix);
      await _saveSibling(xlsx, '', 'xlsx');
    });
  }

  Future<void> _exportDocx() async {
    final bytes = _bytes!;
    final pw = _password;
    await _produce(_str.t('pp.to_docx'), () async {
      final docx =
          await PdfExportPro.toLayoutDocxInBackground(bytes, password: pw);
      await _saveSibling(docx, '', 'docx');
    });
  }

  /// PDF/A-2b: şablon kipi (metin/vektör korunur) ya da görüntü kipi (tam
  /// gömülü; kaynağın gömülmeyen yazı tipleri sorun olmaz).
  Future<void> _exportPdfA() async {
    final mode = await showAppSheet<bool>(
      context,
      title: context.t('pp.pdfa'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.pdfArchive),
            title: Text(ctx.t('pp.pdfa_vector')),
            subtitle: Text(ctx.t('pp.pdfa_vector_sub')),
            onTap: () => Navigator.pop(ctx, false),
          ),
          ListTile(
            leading: const Icon(AppIcons.image),
            title: Text(ctx.t('pp.pdfa_image')),
            subtitle: Text(ctx.t('pp.pdfa_image_sub')),
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    final bytes = _bytes!;
    final pw = _password;
    final total = await _pageCount();
    if (mode && total > _rasterPageLimit) {
      _snack(_str.t('pp.too_many_pages', {'n': _rasterPageLimit}));
      return;
    }
    final font = await _unicodeFont();
    await _produce(_str.t('pp.pdfa'), () async {
      final rasters = mode
          ? await PdfRaster.renderJpegs(
              bytes, List<int>.generate(total, (i) => i),
              password: pw, dpi: 150, quality: 82)
          : const <RasterPage>[];
      final out = await PdfRedact.applyInBackground(
        bytes,
        rects: const {},
        rasters: [for (final r in rasters) RedactedRaster(r.index, r.jpeg)],
        fontBytes: font,
        password: pw,
        conformance: PdfConformanceLevel.a2b,
      );
      await _saveSibling(out, '-PDFA', 'pdf');
    });
  }

  /// Sayfaları görüntüye çeviren işlerde tek seferde en çok sayfa: her
  /// sayfa ~0,2–0,5 MB JPEG bellekte bekler (500 sayfa = yüzlerce MB).
  static const _rasterPageLimit = 150;

  // ── 4. İki PDF karşılaştırma ─────────────────────────────────────────────

  Future<void> _compare() async {
    final a = _bytes!;
    final res = await AppFilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    final b = await File(path).readAsBytes();
    String? pwB;
    try {
      await PdfTools.pageCount(b);
    } catch (_) {
      pwB = await _askPassword(
          _str.t('pt.locked_title'), _str.t('pt.enter_password'));
      if (pwB == null) return;
      try {
        await PdfTools.pageCount(b, password: pwB);
      } catch (e) {
        if (mounted) _snackError(userErrorText(e));
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PdfCompareScreen(
        a: a,
        b: b,
        nameA: p.basename(widget.path),
        nameB: p.basename(path),
        passwordA: _password,
        passwordB: pwB,
      ),
    ));
  }

  // ── 5. İzinler / yer imleri / damga / numara ─────────────────────────────

  Future<void> _permissions() async {
    final bytes = _bytes!;
    final pw = _password;
    Set<PdfAllow> current;
    try {
      current = await Isolate.run(
          () => PdfDocPro.readPermissions(bytes, password: pw));
    } catch (_) {
      current = PdfAllow.values.toSet();
    }
    if (!mounted) return;
    final opts = await showAppSheet<_PermOptions>(
      context,
      title: context.t('pp.permissions'),
      builder: (_) => _PermissionsSheet(initial: current),
    );
    if (opts == null || !mounted) return;
    final before = _bytes;
    await _apply(
      _str.t('pp.permissions'),
      (b) => PdfDocPro.setPermissionsInBackground(b,
          ownerPassword: opts.owner,
          userPassword: opts.user,
          allow: opts.allow,
          currentPassword: pw),
    );
    if (!mounted || identical(before, _bytes)) return;
    // Sahip parolası belgeyi her zaman açar: sonraki işlemler onunla.
    _partSetState(() => _password = opts.owner);
    _snack(_str.t('pp.permissions_done'));
  }

  Future<void> _editOutline() async {
    final bytes = _bytes!;
    final pw = _password;
    final total = await _pageCount();
    final items = await PdfDocPro.readOutlineInBackground(bytes, password: pw);
    if (!mounted) return;
    final edited = await Navigator.of(context).push<List<PdfOutlineItem>>(
      MaterialPageRoute(
        builder: (_) => _OutlineEditor(
          items: items,
          pageCount: total,
          suggestPage: _selected.isEmpty ? 0 : (_selected.toList()..sort()).first,
        ),
      ),
    );
    if (edited == null || !mounted) return;
    if (listEquals(edited, items)) return;
    await _apply(_str.t('pp.outline'),
        (b) => PdfDocPro.writeOutlineInBackground(b, edited, password: pw));
  }

  Future<void> _stamp() async {
    final opts = await showAppSheet<_StampOptions>(
      context,
      title: context.t('pp.stamp'),
      builder: (_) => _StampSheet(hasSelection: _selected.isNotEmpty),
    );
    if (opts == null || !mounted) return;
    final pw = _password;
    final font = await _unicodeFont();
    final pages = opts.selectedOnly ? _selectedOrNull() : null;
    if (opts.watermark) {
      await _apply(
        _str.t('pt.op_watermark'),
        (b) => PdfTools.addWatermarkInBackground(b,
            text: opts.text, password: pw, fontBytes: font),
      );
      return;
    }
    await _apply(
      _str.t('pp.stamp'),
      (b) => PdfDocPro.addStampInBackground(b,
          text: opts.text,
          colorArgb: opts.color,
          place: opts.place,
          subline: opts.subline,
          pages: pages,
          fontBytes: font,
          password: pw),
    );
  }

  Future<void> _numbering() async {
    final opts = await showAppSheet<_NumberingOptions>(
      context,
      title: context.t('pp.numbering'),
      builder: (_) => const _NumberingSheet(),
    );
    if (opts == null || !mounted) return;
    final pw = _password;
    final font = await _unicodeFont();
    final word = _str.t('pp.page_word');
    await _apply(
      _str.t('pp.numbering'),
      (b) => PdfDocPro.addNumberingInBackground(b,
          style: opts.style,
          place: opts.place,
          startAt: opts.startAt,
          skipFirstPage: opts.skipFirst,
          prefix: opts.prefix,
          digits: opts.digits,
          pageWord: word,
          fontBytes: font,
          password: pw),
    );
  }

  // ── 7. Agresif sıkıştırma (A7.4) ─────────────────────────────────────────

  Future<void> _compressHard() async {
    final opts = await showAppSheet<_HardCompressOptions>(
      context,
      title: context.t('pp.compress_hard'),
      builder: (_) => const _HardCompressSheet(),
    );
    if (opts == null || !mounted) return;
    final pw = _password;
    final before = _bytes!.length;
    final total = await _pageCount();
    final font = opts.keepText ? await _unicodeFont() : null;
    final prev = _bytes;
    await _apply(_str.t('pp.compress_hard'), (b) async {
      // Parça parça: bellekte aynı anda en çok [_hardChunk] sayfanın JPEG'i.
      final parts = <List<int>>[];
      for (var start = 0; start < total; start += _hardChunk) {
        final pages = [
          for (var i = start; i < math.min(total, start + _hardChunk); i++) i,
        ];
        final rasters = await PdfRaster.renderJpegs(b, pages,
            password: pw,
            dpi: opts.dpi.toDouble(),
            quality: opts.quality,
            grayscale: opts.grayscale);
        parts.add(await PdfRedact.applyInBackground(
          b,
          rects: const {},
          rasters: [for (final r in rasters) RedactedRaster(r.index, r.jpeg)],
          fontBytes: font,
          password: pw,
          keepText: opts.keepText,
          onlyPages: pages,
        ));
      }
      if (parts.length == 1) return parts.single;
      return PdfTools.mergeInBackground(parts);
    });
    if (!mounted || identical(prev, _bytes)) return;
    _partSetState(() => _password = null);
    final after = _bytes!.length;
    _snack(after < before
        ? _str.t('pt.size_change', {'before': _kb(before), 'after': _kb(after)})
        : _str.t('pp.compress_hard_bigger', {'size': _kb(after)}));
  }

  static const _hardChunk = 40;

  // ── 8. Sayfa ızgarası işlemleri ──────────────────────────────────────────

  Future<void> _reorderPages() async {
    final bytes = _bytes!;
    final order =
        await PdfReorderScreen.open(context, bytes: bytes, password: _password);
    if (order == null || !mounted) return;
    if (!await _confirmAnnotationLoss(_str.t('pp.reorder')) || !mounted) return;
    final pw = _password;
    await _apply(_str.t('pp.reorder'),
        (b) => PdfTools.selectPagesInBackground(b, order, password: pw));
  }

  /// Boş sayfaları bulur (küçük gri çizim), seçer ve silmeyi önerir.
  Future<void> _findBlankPages() async {
    final bytes = _bytes!;
    final pw = _password;
    List<int> blanks = const [];
    await _produce(_str.t('pp.blank_finding'), () async {
      final gray = await PdfRaster.renderGray(bytes, password: pw, widthPx: 96);
      final shapes = [for (final g in gray) (w: g.width, h: g.height, luma: g.luma)];
      blanks = await Isolate.run(() => [
            for (var i = 0; i < shapes.length; i++)
              if (PdfPagePro.isBlank(shapes[i].w, shapes[i].h, shapes[i].luma)) i,
          ]);
    });
    if (!mounted) return;
    if (blanks.isEmpty) {
      _snack(_str.t('pp.blank_none'));
      return;
    }
    _selection.value = blanks.toSet();
    final total = await _pageCount();
    if (!mounted) return;
    if (blanks.length >= total) {
      _snack(_str.t('pp.blank_all'));
      return;
    }
    final ok = await showAppConfirm(
      context,
      title: context.t('pp.blank'),
      message: context.t('pp.blank_found', {
        'n': blanks.length,
        'pages': blanks.map((i) => i + 1).join(', '),
      }),
      confirmLabel: context.t('common.delete'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final del = List<int>.of(blanks);
    await _apply(_str.t('pp.blank'),
        (b) => PdfTools.deletePagesInBackground(b, del, password: pw));
  }

  Future<void> _cropPages() async {
    final bytes = _bytes!;
    final pw = _password;
    final pages = _selectedOrNull();
    final marks = await PdfRegionScreen.open(
      context,
      bytes: bytes,
      mode: PdfRegionMode.crop,
      password: pw,
      title: context.t('pp.crop'),
    );
    if (marks == null || marks.isEmpty || !mounted) return;
    final rect = marks.values.first.first;
    if (!await _confirmAnnotationLoss(_str.t('pp.crop')) || !mounted) return;
    await _apply(_str.t('pp.crop'),
        (b) => PdfPagePro.cropInBackground(b, rect, pages: pages, password: pw));
  }

  Future<void> _fitA4() async {
    if (!await _confirmAnnotationLoss(_str.t('pp.fit_a4')) || !mounted) return;
    final pw = _password;
    final pages = _selectedOrNull();
    await _apply(_str.t('pp.fit_a4'),
        (b) => PdfPagePro.resizeInBackground(b, pages: pages, password: pw));
  }

  // ── 9. Form oluşturma ────────────────────────────────────────────────────

  Future<void> _createForm() async {
    final kind = await showAppSheet<NewFieldKind>(
      context,
      title: context.t('pp.form_create'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final k in NewFieldKind.values)
            ListTile(
              leading: Icon(switch (k) {
                NewFieldKind.text => AppIcons.pdfTextField,
                NewFieldKind.checkbox => AppIcons.pdfCheckBox,
                NewFieldKind.signature => AppIcons.draw,
              }),
              title: Text(ctx.t('pp.field_${k.name}')),
              onTap: () => Navigator.pop(ctx, k),
            ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    final pw = _password;
    final marks = await PdfRegionScreen.open(
      context,
      bytes: _bytes!,
      mode: PdfRegionMode.field,
      password: pw,
      title: context.t('pp.field_${kind.name}'),
    );
    if (marks == null || marks.isEmpty || !mounted) return;
    final base = _str.t('pp.field_${kind.name}');
    var n = 0;
    final fields = <NewFormField>[
      for (final e in marks.entries)
        for (final r in e.value) NewFormField(e.key, r, kind, '$base${++n}'),
    ];
    final font = await _unicodeFont();
    await _apply(
      _str.t('pp.form_create'),
      (b) => PdfFormPro.addFieldsInBackground(b, fields,
          fontBytes: font, password: pw),
    );
  }
}
