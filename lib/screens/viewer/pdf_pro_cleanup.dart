part of '../viewer_screen.dart';

/// Eski `PdfEditorScreen`'den taşınan iki belge düzeyi iş (2026-11-28, B4
/// emekliliği): yinelenen damga/filigran öğelerini seçerek silme ve taranmış
/// sayfayı düzeltme / düzenlenebilir yapma. İkisi de dosyanın BAYTLARI
/// üzerinde çalışır (PDF araçlarıyla aynı düzen): önce düzenleme kipinden
/// çıkılır (kaydedilmemiş iş sorulur), sonuç eski ekrandaki gibi "üstüne yaz /
/// kopya" sorusuyla kaydedilir.
// ponytail: bellekteki oturuma işlenmiyor (geri al yığını yok); geri dönüş
// sürüm geçmişinden ya da kopyadan. Oturuma işlemek gerekirse PdfMutAction'a çevrilir.
extension _ViewerScreenPdfProCleanupPart on _ViewerScreenState {
  /// ⋮ → Filigran: her sayfada yinelenen öğeleri listeler, seçilenleri siler.
  Future<void> _proBackground() async {
    if (!await _confirmLeavePending() || !mounted) return;
    final path = widget.doc.path;
    final busy = context.t('pe.busy_background');
    final failed = context.t('pe.background_failed');
    _snack(busy);
    final List<int> bytes;
    final List<PdfBackgroundEntry> items;
    try {
      bytes = await File(path).readAsBytes();
      items = await PdfPageEdit.backgroundItemsInBackground(bytes);
    } on PdfPageRefused catch (e) {
      _snack(e.message);
      return;
    } catch (e) {
      _snack(failed.replaceAll('{error}', userErrorText(e)));
      return;
    }
    if (!mounted) return;
    final picked = await _pickBackground(items);
    if (picked == null || picked.isEmpty || !mounted) return;
    final opFailed = context.t('pe.op_failed');
    final List<int> out;
    try {
      out = await PdfPageEdit.removeBackgroundInBackground(bytes, picked);
    } catch (e) {
      _snack(opFailed.replaceAll('{error}', userErrorText(e)));
      return;
    }
    if (!mounted) return;
    await _saveFileEdit(out, context.t('pe.items_removed'));
  }

  /// Aday listesi + onay kutuları (eski "Arka plan" paneli). null = vazgeçildi.
  Future<Set<int>?> _pickBackground(List<PdfBackgroundEntry> items) {
    final picked = <int>{};
    return showAppSheet<Set<int>>(
      context,
      title: context.t('pe.mode_watermark'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
              child: Text(ctx.t(items.isEmpty
                  ? 'pe.no_background'
                  : 'pe.hint_background')),
            ),
            for (final item in items)
              CheckboxListTile(
                dense: true,
                value: picked.contains(item.index),
                onChanged: (on) => setSheet(() {
                  if (on == true) {
                    picked.add(item.index);
                  } else {
                    picked.remove(item.index);
                  }
                }),
                secondary:
                    Icon(item.isImage ? AppIcons.image : AppIcons.title),
                title: Text(item.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(item.detail),
              ),
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: FilledButton.icon(
                  key: const ValueKey('pse-bg-remove'),
                  onPressed: picked.isEmpty
                      ? null
                      : () => Navigator.of(ctx).pop({...picked}),
                  icon: const Icon(AppIcons.layersClear),
                  label: Text(
                      ctx.t('pe.remove_picked', {'n': picked.length})),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Taranmış sayfanın ([pageIndex]) OCR satırlarını bir geçişte onarır:
  /// [withAi] false → cihaz içi kurallar ([ScanTextFix]), true → Gemini
  /// ([ScanAiFix]); yalnız DEĞİŞEN satırlar yeniden yazılır. [keepText] →
  /// "Bu sayfayı düzenlenebilir yap": metin değişmeden tüm satırlar örneklenen
  /// kâğıt/mürekkep rengiyle gerçek metne çevrilir; sonra her satır bu
  /// düzenleyicide yerinde yazılır (eski "OCR satırına dokun" yolunun yerine).
  Future<void> _proFixScanned(int pageIndex,
      {bool withAi = false, bool keepText = false}) async {
    if (!PdfOcrText.isSupported) return;
    GeminiService? gemini;
    if (withAi) {
      final state = context.read<AppState>();
      if (!await ensureAiKey(context) || !mounted) return;
      gemini = state.gemini;
    }
    if (!await _confirmLeavePending() || !mounted) return;
    final path = widget.doc.path;
    final password = _pdfPassword;
    final opFailed = context.t('pe.op_failed');
    final nothing = context.t('pe.fix_nothing');
    _snack(context.t(keepText
        ? 'pe.busy_make_editable'
        : (withAi ? 'pe.busy_fix_ai' : 'pe.busy_fix')));
    PdfDocument? doc;
    final List<int> out;
    final int n;
    try {
      doc = await PdfDocument.openFile(path,
          passwordProvider: password == null ? null : () => password);
      if (pageIndex < 0 || pageIndex >= doc.pages.length) return;
      final page = doc.pages[pageIndex];
      final ocr = await PdfOcrText.forPage(page);
      final lines = [
        for (final f in ocr?.fragments ?? const <PdfPageTextFragment>[])
          if (f.text.trim().isNotEmpty) f,
      ];
      final originals = [for (final f in lines) f.text.trim()];
      final fixed = keepText
          ? originals
          : withAi
              ? await ScanAiFix.polish(gemini!, originals)
              : ScanTextFix.lines(originals);
      final edits = <ScannedEdit>[];
      for (var i = 0; i < originals.length && i < fixed.length; i++) {
        if (!keepText && fixed[i].trim() == originals[i].trim()) continue;
        final box = lines[i].bounds;
        final c = await PdfScannedRetype.sampleFromPage(page, box);
        edits.add(ScannedEdit(box, fixed[i],
            background: c?.background, ink: c?.ink));
      }
      n = edits.length;
      if (n == 0) {
        _snack(nothing);
        return;
      }
      out = await PdfScannedRetype.applyMany(
          bytes: await File(path).readAsBytes(),
          pageIndex: pageIndex,
          edits: edits);
    } catch (e) {
      _snack(opFailed.replaceAll('{error}', userErrorText(e)));
      return;
    } finally {
      await doc?.dispose();
    }
    // Sayfa değişecek: OCR bellek önbelleği bayat.
    PdfOcrText.invalidateMemory();
    if (!mounted) return;
    await _saveFileEdit(
        out, context.t(keepText ? 'pe.make_editable_done' : 'pe.fix_done',
            {'n': n}));
  }

  /// Bayt düzeyindeki sonucu eski düzenleyicinin sorusuyla kaydeder (üstüne
  /// yaz / kopya / klasör). Üstüne yazıldıysa görüntü tazelenir; kopyaysa
  /// kopya açılır.
  Future<void> _saveFileEdit(List<int> bytes, String done) async {
    final outcome = await savePdfWithChoice(
      context,
      originalPath: widget.doc.path,
      bytes: bytes,
      note: '$done\n${context.t('pe.save_note')}',
      activityDetail: context.t('ps.act_edited'),
    );
    if (outcome == null || !mounted) return;
    if (outcome.overwritten) {
      _partSetState(() => _pdfText = '');
      await _reloadPdf();
      return;
    }
    Navigator.of(context).pop();
    await openSavedPdf(outcome.path);
  }
}
