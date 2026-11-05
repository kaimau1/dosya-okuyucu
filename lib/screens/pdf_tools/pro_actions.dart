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
}
