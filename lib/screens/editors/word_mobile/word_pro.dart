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
    } catch (_) {}
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
    }
  }

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
}
