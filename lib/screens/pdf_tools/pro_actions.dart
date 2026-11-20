part of '../pdf_tools_screen.dart';

/// **Faz 39 — PDF pro araçları.** Tek menü girdisi ("Pro araçlar…") bir
/// levha açar; her araç [_PdfToolsScreenState._apply] kapısından geçer
/// (geri alma, iz, izolat). Ağır işlerin hepsi `…InBackground`.
extension _PdfToolsProPart on _PdfToolsScreenState {
  /// Özellik bayrağı anahtarı (anayasa k.9; geri alma: `false` yaz).
  static const flagKey = 'pdf_pro_v1';

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
      'meta' => _editMeta(),
      'xfdf_out' => _exportXfdf(),
      'xfdf_in' => _importXfdf(),
      'stamp' => _stamp(),
      'numbering' => _numbering(),
      'compress_hard' => _compressHard(),
      'ocr_layer' => _ocrLayer(),
      'reorder' => _reorderPages(),
      'blank' => _findBlankPages(),
      'crop' => _cropPages(),
      'fit_a4' => _fitA4(),
      'form_create' => _createForm(),
      'notes' => _exportNotes(),
      'images_to_pdf' => _imagesToPdf(),
      'pdf_to_images' => _pdfToImages(),
      'web_to_pdf' => _webToPdf(),
      'office_to_pdf' => _officeToPdf(),
      'signatures' => _manageSignatures(),
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
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
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
        onPressed: () => unawaited(SharePlus.instance.share(ShareParams(files: [XFile(path)]))),
      ),
    );
  }

  /// Dosya üreten (belgeyi değiştirmeyen) iş: meşgul şeridi + hata şeridi.
  ///
  /// `_apply` gibi `TrackedTask`'a (İşlemler kuyruğu, `JobQueue`) bağlı:
  /// 1,5 sn'yi geçen iş şeritte/bildirimde görünür.
  Future<void> _produce(String label, Future<void> Function() job) async {
    if (_busy) return;
    _partSetState(() => _busyLabel = '$label…');
    final task = TrackedTask(
      title: '$label…',
      name: _str.t('pt.job_name', {'label': label}),
    )..report(detail: p.basename(widget.path));
    bool watched() => TrackedTask.userWatching;
    try {
      await job();
      await task.complete(quiet: watched());
    } catch (e) {
      await task.fail(e, quiet: watched());
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

  /// PDF/A-2b — her sayfa görüntü + görünmez (gömülü TrueType) metin.
  /// Şablon (vektör) kipi YOK: Syncfusion PDF/A belgesine yüklü sayfa
  /// şablonu çizemiyor (boş işaretçi, `pdf_export_pro_test`); görüntü kipi
  /// kaynağın gömülmemiş yazı tiplerinden de etkilenmez.
  Future<void> _exportPdfA() async {
    final total = await _pageCount();
    if (!mounted) return;
    if (total > _rasterPageLimit) {
      _snack(_str.t('pp.too_many_pages', {'n': _rasterPageLimit}));
      return;
    }
    final ok = await showAppConfirm(
      context,
      title: context.t('pp.pdfa'),
      message: context.t('pp.pdfa_image_sub'),
      confirmLabel: context.t('common.save'),
    );
    if (!ok || !mounted) return;
    final bytes = _bytes!;
    final pw = _password;
    final font = await _unicodeFont();
    await _produce(_str.t('pp.pdfa'), () async {
      final rasters = await PdfRaster.renderJpegs(
          bytes, List<int>.generate(total, (i) => i),
          password: pw, dpi: 150, quality: 82);
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

  // ── B4/P21 meta veri · P17 XFDF ─────────────────────────────────────────

  Future<void> _editMeta() async {
    final bytes = _bytes!;
    final pw = _password;
    final PdfMeta current;
    try {
      current = await PdfDocPro.readMetaInBackground(bytes, password: pw);
    } catch (_) {
      _snack(_str.t('pp.meta_failed'));
      return;
    }
    if (!mounted) return;
    final edited = await showAppSheet<PdfMeta>(
      context,
      title: context.t('pp.meta'),
      builder: (_) => _MetaSheet(initial: current),
    );
    if (edited == null || edited == current || !mounted) return;
    await _apply(_str.t('pp.meta'),
        (b) => PdfDocPro.writeMetaInBackground(b, edited, password: pw));
  }

  Future<void> _exportXfdf() async {
    final bytes = _bytes!;
    final pw = _password;
    await _produce(_str.t('pp.xfdf_out'), () async {
      final data = await PdfDocPro.exportXfdfInBackground(bytes, password: pw);
      if (data == null) {
        _snack(_str.t('pp.notes_empty'));
        return;
      }
      await _saveSibling(data, '-aciklamalar', 'xfdf');
    });
  }

  Future<void> _importXfdf() async {
    final res = await AppFilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xfdf'],
    );
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    final xfdf = await File(path).readAsBytes();
    if (!mounted) return;
    final pw = _password;
    await _apply(_str.t('pp.xfdf_in'),
        (b) => PdfDocPro.importXfdfInBackground(b, xfdf, password: pw));
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

  // ── P19. Aranabilir PDF (OCR görünmez katman) ────────────────────────────

  Future<void> _ocrLayer() async {
    final pw = _password;
    final label = _str.t('pp.ocr_layer');
    var lines = <int, List<({String text, Rect rect})>>{};
    await _produce(label, () async {
      lines = await _ocrLines(_bytes!, pw);
      if (lines.isEmpty) _snack(_str.t('pp.ocr_layer_none'));
    });
    if (lines.isEmpty || !mounted) return;
    final font = await _unicodeFont();
    final prev = _bytes;
    await _apply(
      label,
      (b) => PdfTools.addTextLayerInBackground(b, lines,
          fontBytes: font, password: pw),
    );
    if (!mounted || identical(prev, _bytes)) return;
    _snack(_str.t('pp.ocr_layer_done', {'n': lines.length}));
  }

  /// Metin katmanı OLMAYAN (taranmış) sayfaların OCR satırları, görünen
  /// sayfa koordinatında (sol-üst). Doğal metinli sayfaya OCR yazılmaz (PK7).
  Future<Map<int, List<({String text, Rect rect})>>> _ocrLines(
      Uint8List bytes, String? pw) async {
    final out = <int, List<({String text, Rect rect})>>{};
    final doc = await PdfDocument.openData(bytes,
        passwordProvider: pw == null ? null : () async => pw);
    try {
      for (var i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        if (page.rotation != PdfPageRotation.none) continue;
        final own = await page.loadText();
        if (pdfHasTextLayer(own?.fullText ?? '')) continue;
        final ocr = await PdfOcrText.forPage(page);
        if (ocr == null) continue;
        final rows = [
          for (final f in ocr.fragments)
            (
              text: ocr.fullText.substring(f.index, f.index + f.length),
              // PDF uzayı (y yukarı) → görünen sayfa (sol-üst).
              rect: Rect.fromLTRB(f.bounds.left, page.height - f.bounds.top,
                  f.bounds.right, page.height - f.bounds.bottom),
            ),
        ];
        if (rows.isNotEmpty) out[i] = rows;
      }
    } finally {
      await doc.dispose();
    }
    return out;
  }

  // ── 8. Sayfa ızgarası işlemleri ──────────────────────────────────────────

  /// Sayfa stüdyosu (B4/P20): yalnız sil/döndür yerinde çalışır, açıklamalar
  /// kalır; sıralama/çoğaltma kopyalar → önce kayıp uyarısı.
  Future<void> _reorderPages() async {
    final bytes = _bytes!;
    final res = await PdfPageStudioScreen.open(context,
        bytes: bytes, password: _password);
    if (res == null || !mounted) return;
    final plan = res.plan;
    final extra = res.extra;
    final pw = _password;
    if (res.newFiles.isNotEmpty) {
      // Çıkar/böl: belge değişmez, her parça yanına yeni PDF.
      final parts = res.newFiles;
      await _produce(_str.t('pp.studio'), () async {
        for (var k = 0; k < parts.length; k++) {
          final out = await PdfTools.applyPageStudioInBackground(
              bytes, parts[k],
              password: pw, extra: extra);
          await _saveSibling(
              out, parts.length == 1 ? '-sayfalar' : '-bolum${k + 1}', 'pdf');
        }
      });
      return;
    }
    final keeps = PdfTools.studioKeepsAnnotations(
        [for (final (i, _) in plan) i],
        pageCount: res.pageCount);
    if (!keeps && (!await _confirmAnnotationLoss(_str.t('pp.studio')) ||
        !mounted)) {
      return;
    }
    await _apply(_str.t('pp.studio'),
        (b) => PdfTools.applyPageStudioInBackground(b, plan,
            password: pw, extra: extra));
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
    final kind = await showAppSheet<Object>(
      context,
      title: context.t('pp.form_create'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.search),
            title: Text(ctx.t('pp.field_detect')),
            subtitle: Text(ctx.t('pp.field_detect_sub')),
            onTap: () => Navigator.pop(ctx, 'detect'),
          ),
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
    if (kind == 'detect') return _detectFields();
    if (kind is! NewFieldKind || !mounted) return;
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

  /// P18: düz PDF'teki `____` / `.....` / `☐` yerlerini bulur, kullanıcı
  /// işaretleme ekranında gözden geçirir (dokun = sil, sürükle = ekle),
  /// onaylayınca doldurulabilir alan olur.
  Future<void> _detectFields() async {
    final bytes = _bytes!;
    final pw = _password;
    final label = _str.t('pp.field_detect');
    var found = const <NewFormField>[];
    await _produce(label, () async {
      found = await PdfFormPro.detectFieldsInBackground(bytes,
          password: pw, shapes: await _shapeFields(bytes, pw));
      if (found.isEmpty) _snack(_str.t('pp.field_detect_none'));
    });
    if (found.isEmpty || !mounted) return;
    final initial = <int, List<Rect>>{};
    for (final f in found) {
      (initial[f.page] ??= []).add(f.bounds);
    }
    final marks = await PdfRegionScreen.open(
      context,
      bytes: bytes,
      mode: PdfRegionMode.field,
      password: pw,
      initial: initial,
      title: label,
    );
    if (marks == null || marks.isEmpty || !mounted) return;
    final base = _str.t('pp.field_text');
    var n = 0;
    final fields = <NewFormField>[];
    for (final e in marks.entries) {
      for (final r in e.value) {
        final hit =
            found.where((f) => f.page == e.key && f.bounds == r).firstOrNull;
        final name = hit == null || hit.name.isEmpty ? '$base${++n}' : hit.name;
        fields.add(
            NewFormField(e.key, r, hit?.kind ?? NewFieldKind.text, name));
      }
    }
    final font = await _unicodeFont();
    await _apply(
      _str.t('pp.form_create'),
      (b) => PdfFormPro.addFieldsInBackground(b, fields,
          fontBytes: font, password: pw),
    );
  }

  /// Çizilmiş çizgi/kutu adayları (PDFium yol nesneleri; ilk 300 sayfa).
  /// Okunamazsa boş — metin sezgisi yine çalışır.
  Future<List<NewFormField>> _shapeFields(Uint8List bytes, String? pw) async {
    final out = <NewFormField>[];
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openData(bytes,
          passwordProvider: pw == null ? null : () async => pw);
      final n = math.min(doc.pages.length, 300);
      for (var i = 0; i < n; i++) {
        if (doc.pages[i].rotation != PdfPageRotation.none) continue;
        out.addAll(
            PdfFormPro.fieldsFromShapes(i, await PdfEditBridge.content(doc, i)));
      }
    } catch (_) {
      // Metin sezgisi yeter.
    } finally {
      await doc?.dispose();
    }
    return out;
  }

  // ── 10. Not özeti ────────────────────────────────────────────────────────

  Future<void> _exportNotes() async {
    final bytes = _bytes!;
    final pw = _password;
    await _produce(_str.t('pp.notes_booklet'), () async {
      final items = await PdfNotes.collectInBackground(bytes, password: pw);
      if (items.isEmpty) {
        _snack(_str.t('pp.notes_empty'));
        return;
      }
      final md = PdfNotes.toMarkdown(
        items,
        title: p.basename(widget.path),
        labels: {
          for (final k in PdfNoteKind.values) k: _str.t('pp.note_${k.name}'),
        },
        pageLabel: (n) => _str.t('pp.compare_page', {'n': n}),
      );
      await _saveSibling(utf8.encode(md), '-notlar', 'md');
    });
  }

  // ── 11. Dönüştürmeler ────────────────────────────────────────────────────

  /// Yeni üretilen (bu PDF'ten bağımsız) dosyayı Belgeler klasörüne yazar.
  Future<void> _saveToDocs(List<int> data, String base, String ext) async {
    final dir = await DocsHome.resolve();
    final path = LegacyConvert.uniquePath(dir.path, base, ext);
    await File(path).writeAsBytes(data, flush: true);
    if (!mounted) return;
    showSnack(
      context,
      _str.t('pp.saved_as', {'name': p.basename(path)}),
      action: SnackBarAction(
        label: _str.t('common.share'),
        onPressed: () => unawaited(SharePlus.instance.share(ShareParams(files: [XFile(path)]))),
      ),
    );
  }

  Future<void> _imagesToPdf() async {
    final res = await AppFilePicker.pickFiles(
        type: FileType.image, allowMultiple: true);
    final paths = [
      for (final f in res?.files ?? const <PickedFile>[])
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty || !mounted) return;
    final a4 = await showAppConfirm(
      context,
      title: context.t('pp.images_to_pdf'),
      message: context.t('pp.images_a4_q', {'n': paths.length}),
      confirmLabel: context.t('pp.images_a4'),
    );
    if (!mounted) return;
    await _produce(_str.t('pp.images_to_pdf'), () async {
      final pdf = await _conversion.imagesToPdf(paths,
          uniformPage: a4 ? PdfPageFormat.a4 : null);
      await _saveToDocs(pdf, p.basenameWithoutExtension(paths.first), 'pdf');
    });
  }

  /// Tüm sayfalar JPEG olarak bir klasöre (paylaşım sınırı olan
  /// "Görsel olarak dışa aktar"ın toplu karşılığı); parça parça çizilir.
  Future<void> _pdfToImages() async {
    final bytes = _bytes!;
    final pw = _password;
    final pages = _selectedOrNull() ?? List<int>.generate(await _pageCount(), (i) => i);
    if (!mounted) return;
    await _produce(_str.t('pp.pdf_to_images'), () async {
      final root = await DocsHome.resolve();
      final stem = p.basenameWithoutExtension(widget.path);
      var dir = Directory(p.join(root.path, '$stem-sayfalar'));
      for (var n = 2; await dir.exists(); n++) {
        dir = Directory(p.join(root.path, '$stem-sayfalar ($n)'));
      }
      await dir.create(recursive: true);
      for (var start = 0; start < pages.length; start += _hardChunk) {
        final chunk = pages.sublist(start, math.min(pages.length, start + _hardChunk));
        final rasters = await PdfRaster.renderJpegs(bytes, chunk,
            password: pw, dpi: 150, quality: 88);
        for (final r in rasters) {
          await File(p.join(dir.path, '$stem-${r.index + 1}.jpg'))
              .writeAsBytes(r.jpeg, flush: true);
        }
        if (mounted) {
          _partSetState(() => _busyLabel =
              '${_str.t('pp.pdf_to_images')} ${math.min(pages.length, start + _hardChunk)}/${pages.length}…');
        }
      }
      _snack(_str.t('pp.images_saved', {'n': pages.length, 'dir': p.basename(dir.path)}));
    });
  }

  Future<void> _webToPdf() async {
    final url = await showAppPrompt(
      context,
      title: context.t('pp.web_to_pdf'),
      label: context.t('pp.web_url'),
      initial: 'https://',
    );
    if (url == null || !mounted) return;
    final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _snack(_str.t('pp.web_bad_url'));
      return;
    }
    await _produce(_str.t('pp.web_to_pdf'), () async {
      final res = await http.get(uri).timeout(const Duration(seconds: 25));
      if (res.statusCode >= 400) {
        throw PdfToolsException('HTTP ${res.statusCode}');
      }
      final pdf = await Printing
          // Kullanımdan kalkmış ama Android'de çalışan TEK HTML→PDF yolu
          // (WebView yazdırma; yeni bağımlılık yok). printing yükseltilip
          // kaldırılırsa: WebView + `PrintManager` köprüsü (HAFIZA Faz 39).
          // ignore: deprecated_member_use
          .convertHtml(
        html: res.body,
        baseUrl: uri.toString(),
        format: PdfPageFormat.a4,
      );
      final host = uri.host.replaceAll(RegExp(r'[^\w.-]+'), '_');
      await _saveToDocs(pdf, host.isEmpty ? 'web' : host, 'pdf');
    });
  }

  Future<void> _officeToPdf() async {
    final res = await AppFilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'xlsx', 'pptx'],
    );
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    await _produce(_str.t('pp.office_to_pdf'), () async {
      final bytes = await File(path).readAsBytes();
      final ext = p.extension(path);
      final title = p.basenameWithoutExtension(path);
      final html = await Isolate.run(
          () => OfficeHtml.fromBytes(bytes, ext, title: title));
      final landscape = ext.toLowerCase() != '.docx';
      final pdf = await Printing
          // Kullanımdan kalkmış ama Android'de çalışan TEK HTML→PDF yolu
          // (WebView yazdırma; yeni bağımlılık yok). printing yükseltilip
          // kaldırılırsa: WebView + `PrintManager` köprüsü (HAFIZA Faz 39).
          // ignore: deprecated_member_use
          .convertHtml(
        html: html,
        format: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      );
      await _saveToDocs(pdf, title, 'pdf');
    });
  }

  // ── 12. İmza yönetimi ────────────────────────────────────────────────────

  Future<void> _manageSignatures() async {
    final action = await showAppSheet<_SigAction>(
      context,
      title: context.t('pp.signatures'),
      builder: (_) => _SignaturesSheet(hasSelection: _selected.isNotEmpty),
    );
    if (action == null || !mounted) return;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${two(now.day)}.${two(now.month)}.${now.year}';
    final pw = _password;
    final font = await _unicodeFont();
    final pages = action.selectedOnly ? _selectedOrNull() : null;
    switch (action.kind) {
      case _SigActionKind.initialAll:
        final initials = await Signature.load(initials: true);
        if (!mounted) return;
        if (initials == null) {
          _snack(_str.t('pp.initials_missing'));
          return;
        }
        await _apply(
          _str.t('pp.initial_all'),
          (b) => PdfDocPro.initialPagesInBackground(b,
              strokes: initials.strokes,
              aspect: initials.aspect,
              place: action.place,
              dateText: action.withDate ? date : null,
              pages: pages,
              fontBytes: font,
              password: pw),
        );
      case _SigActionKind.dateStamp:
        await _apply(
          _str.t('pp.date_stamp'),
          (b) => PdfDocPro.addStampInBackground(b,
              text: date,
              colorArgb: PdfDocPro.stampColor(PdfStampKind.custom),
              place: action.place,
              pages: pages,
              fontBytes: font,
              password: pw),
        );
      case _SigActionKind.stamp:
        await _stamp();
      case _SigActionKind.signHere:
        if (_dirty) {
          _snack(_str.t('pp.save_first'));
          return;
        }
        if (!mounted) return;
        final signed = await PdfSignScreen.open(context, widget.path);
        if (signed == true && mounted) await _load();
    }
  }
}
