part of '../viewer_screen.dart';

/// Kaydın sonucu: özgünün üstüne yazıldı · kopyaya geçildi (ekran kapandı) ·
/// olmadı.
enum _ProSaved { overwritten, copied, failed }

/// **PDF Pro düzenleme kipi** (Faz 54, PK2 + PK3): düzenleme görüntüleyicinin
/// bir kipidir — ekran, belge, yakınlaştırma ve kaydırma değişmez; çalışma
/// kopyası yoktur. Gizli bayrak `pdf_pro_engine` açıkken "Düzenle" buraya
/// gelir; kapalıyken eski `PdfEditorScreen` açılır.
extension _ViewerScreenPdfProEditPart on _ViewerScreenState {
  Future<bool> _proEnabled() async {
    if (const bool.fromEnvironment('PDF_PRO_ENGINE')) return true;
    final prefs = await SharedPreferences.getInstance();
    // Faz 57'den beri varsayılan AÇIK (PK1 koşulları + külliyat hedefleri
    // tuttu). Kapatmak için tercih false yapılır; eski düzenleyici ayrıca
    // ⋮ → "Eski düzenleyici" ile her zaman açılabilir.
    return prefs.getBool('pdf_pro_engine') ?? true;
  }

  /// Düzenleme kipine girer. false = bayrak kapalı (çağıran eski yola gider);
  /// true = bu yol üstlendi (kipe girildi ya da kullanıcı vazgeçti).
  Future<bool> _enterProEdit({int? page, PdfEditSelection? selection}) async {
    if (_pro != null) return true;
    if (!await _proEnabled()) return false;
    final doc = _pdfDoc;
    if (doc == null || !mounted) return true;
    // Şifreli belge (Faz 54 / 5): izin bayrakları düzenlemeyi yasaklıyorsa
    // sessizce düzenlenmez — açık uyarı + sahip parolası.
    if (!_proOwnerOk &&
        PdfEditAccessCheck.of(doc) == PdfEditAccess.ownerPasswordNeeded) {
      if (!await showPdfLockedSheet(context) || !mounted) return true;
      final wrong = context.t('pse.owner_wrong');
      final password = await askArchivePassword(
        context,
        title: context.t('pse.owner_title'),
        body: context.t('pse.owner_body'),
      );
      if (password == null) return true;
      final ok = await PdfEditAccessCheck.isOwnerPasswordForFile(
          widget.doc.path, password);
      if (!ok) {
        _snack(wrong);
        return true;
      }
      _proOwnerOk = true;
    }
    // Sorular sürerken belge yeniden yüklenmiş ya da ekran kapanmış olabilir.
    if (!mounted || _pdfDoc != doc || _pro != null) return true;
    final pro = PdfProEditController(
      document: doc,
      path: widget.doc.path,
      password: () => _pdfPassword,
    )..addListener(_onProChanged);
    _clearPdfSelection();
    _readingBars.pinned = true;
    _partSetState(() => _pro = pro);
    // Okumada seçilen aralık → düzenlemede AYNI aralık seçili açılır (PS1).
    if (selection != null && page != null && page > 0) {
      unawaited(_proOpenSelection(pro, page - 1, selection));
    } else {
      _snack(context.t('pse.hint_tap'));
    }
    return true;
  }

  /// Oturumu kapatır ve okuma kipine döner. Bu oturumda özgünün üstüne
  /// kaydedildiyse belge diskten yeniden okunur: bellekteki belge açılış
  /// baytlarına dayanır, sıradaki oturum diskteki dosyayla aynı tabandan
  /// başlamalı.
  Future<void> _closePro({bool keepRecovery = false, bool reload = true}) async {
    final pro = _pro;
    if (pro == null) return;
    pro.removeListener(_onProChanged);
    _pro = null;
    _readingBars.pinned = _findOpen;
    if (mounted) _partSetState(() {});
    final saved = pro.savedOverOriginal;
    await pro.close(keepRecovery: keepRecovery);
    pro.dispose();
    if (reload && saved && !keepRecovery && mounted) await _reloadPdf();
  }

  /// Düzenleme kipinden çıkar; kaydedilmemiş değişiklik varsa sorar.
  /// true = okuma kipine dönüldü.
  Future<bool> _exitProEdit() async {
    final pro = _pro;
    if (pro == null) return true;
    if (pro.busy) return false;
    // Geri tuşu sırası (etkileşim §8): önce yazma, sonra seçim, sonra kip.
    if (pro.live != null) {
      await _proDone();
      return false;
    }
    if (pro.selectedBlock != null ||
        pro.selectedItem != null ||
        pro.selectedAnnot != null ||
        pro.markup != PdfMarkupKind.none) {
      pro
        ..markup = pro.markup
        ..clearSelection();
      return false;
    }
    if (pro.session.dirty) {
      final choice = await showUnsavedChanges(context);
      if (!mounted || _pro != pro) return false;
      switch (choice) {
        case UnsavedChoice.cancel:
          return false;
        case UnsavedChoice.save:
          // Kopyaya düşüldüyse ekran zaten kapandı: çağıran devam etmesin.
          if (await _proSave() != _ProSaved.overwritten) return false;
        case UnsavedChoice.discard:
          final reverted = await pro.revert();
          await _closePro(reload: false);
          // Kayıtlı hâle yığından dönülemedi: diskteki dosya yeniden okunur.
          if ((!reverted || pro.savedOverOriginal) && mounted) {
            await _reloadPdf();
          }
          return true;
      }
    }
    await _closePro();
    return true;
  }

  String _proStatus(PdfProEditController pro) {
    if (pro.session.dirty) {
      return context.t('pse.unsaved_n', {'n': pro.session.pendingCount});
    }
    return pro.savedOverOriginal
        ? context.t('pse.saved')
        : context.t('pse.editing');
  }

  String _proStepName(PdfEditStep step) {
    final name = context.t(step.label);
    return step.detail.isEmpty
        ? name
        : context.t('pse.step_detail', {'name': name, 'detail': step.detail});
  }

  /// Üst çubuk (etkileşim §5): geri al · yinele · Kaydet (dolgulu) · ⋮.
  List<Widget> _proActions(PdfProEditController pro) {
    final undo = pro.session.undoStep, redo = pro.session.redoStep;
    return [
      IconButton(
        key: const ValueKey('pse-undo'),
        tooltip: undo == null
            ? context.t('common.undo')
            : context.t('pse.undo_named', {'name': _proStepName(undo)}),
        icon: const Icon(AppIcons.undo),
        onPressed: pro.busy || undo == null ? null : _proUndo,
      ),
      IconButton(
        key: const ValueKey('pse-redo'),
        tooltip: redo == null
            ? context.t('common.redo')
            : context.t('pse.redo_named', {'name': _proStepName(redo)}),
        icon: const Icon(AppIcons.redo),
        onPressed: pro.busy || redo == null ? null : _proRedo,
      ),
      Padding(
        padding: const EdgeInsetsDirectional.only(start: Gap.xs),
        child: FilledButton(
          key: const ValueKey('pse-save'),
          onPressed: pro.busy || !pro.session.dirty ? null : _proSave,
          child: Text(context.t('common.save')),
        ),
      ),
      IconButton(
        key: const ValueKey('pse-more'),
        tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
        icon: const Icon(AppIcons.more),
        onPressed: pro.busy ? null : _proMore,
      ),
    ];
  }

  Future<void> _proMore() async {
    final pick = await showAppActionSheet<String>(
      context,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'same',
              icon: AppIcons.copy,
              label: context.t('pse.save_as_same')),
          AppAction(
              value: 'docs',
              icon: AppIcons.folder,
              label: context.t('pse.save_as_docs')),
        ], title: context.t('pse.save_as')),
        AppActionGroup(actions: [
          AppAction(
              value: 'find',
              icon: AppIcons.findReplace,
              label: context.t('pse.find_title')),
          AppAction(
              value: 'comments',
              icon: AppIcons.comment,
              label: context.t('pse.comments')),
          AppAction(
              value: 'ai',
              icon: AppIcons.ai,
              label: context.t('pse.tool_ai')),
          AppAction(
              value: 'legacy',
              icon: AppIcons.editNote,
              label: context.t('pse.tool_legacy'),
              hint: context.t('pse.tool_legacy_hint')),
          AppAction(
              value: 'tools',
              icon: AppIcons.construction,
              label: context.t('pse.tool_all'),
              hint: context.t('pse.tool_all_hint')),
        ]),
        AppActionGroup(actions: [
          AppAction(
              value: 'versions',
              icon: AppIcons.history,
              label: context.t('pse.versions')),
          AppAction(
              value: 'finish',
              icon: AppIcons.check,
              label: context.t('pse.finish')),
        ]),
      ],
    );
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'same':
        await _proSaveAs(documents: false);
      case 'docs':
        await _proSaveAs(documents: true);
      case 'find':
        await _proFindReplace();
      case 'comments':
        await _proComments();
      case 'ai':
        await _proAi();
      case 'legacy':
        await _openPdfEditor(legacy: true);
      case 'tools':
        await _openPdfTools();
      case 'versions':
        await _proVersions();
      case 'finish':
        await _exitProEdit();
    }
  }

  /// Görüntüleyici seçimini bloğa eşler ve o aralık seçili olarak yazmayı
  /// açar. Eşleşme yoksa seçimle en çok örtüşen blok seçilir.
  Future<void> _proOpenSelection(
      PdfProEditController pro, int pageIndex, PdfEditSelection sel) async {
    List<PdfTextBlock>? blocks;
    for (var i = 0; i < 100 && blocks == null; i++) {
      blocks = pro.blocksOf(pageIndex);
      if (blocks == null) {
        await Future<void>.delayed(Motion.short);
        if (!mounted || _pro != pro) return;
      }
    }
    if (blocks == null || blocks.isEmpty) return;
    final hit = bestOverlap(sel.rects, [
      for (final b in blocks) PdfRect(b.left, b.top, b.right, b.bottom),
    ]);
    if (hit == null) return;
    final block = blocks[hit];
    pro.select(pageIndex, hit);
    if (!block.editable) {
      await _proLocked(pageIndex, block);
      return;
    }
    // Seçilen metin blokta geçiyorsa o aralık; yoksa imleç seçimin başında.
    final text = block.map.text;
    String norm(String v) => v.replaceAll(RegExp(r'\s+'), ' ').trim();
    final needle = norm(sel.text);
    final at = needle.isEmpty ? -1 : text.indexOf(needle);
    (int, int)? range;
    int? offset;
    if (at >= 0) {
      range = (pdfRuneIndex(text, at), pdfRuneIndex(text, at + needle.length));
    } else if (sel.rects.isNotEmpty) {
      final r = sel.rects.first;
      offset = block.map.offsetAt(r.left, (r.top + r.bottom) / 2);
    }
    await _proBegin(pageIndex, block, offset: offset, selection: range);
  }

  Future<void> _proUndo() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final failed = context.t('pse.undo_failed');
    if (!await pro.undo()) _snack(failed);
    _pdfText = '';
  }

  Future<void> _proRedo() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final failed = context.t('pse.undo_failed');
    if (!await pro.redo()) _snack(failed);
    _pdfText = '';
  }

  /// Kaydet: özgüne artımlı yaz; yazılamıyorsa kopya Belgeler'e düşer ve
  /// görüntüleyici kopyaya geçer.
  Future<_ProSaved> _proSave() async {
    final pro = _pro;
    if (pro == null || pro.busy) return _ProSaved.failed;
    final saved = context.t('pse.saved');
    final failed = context.t('pse.save_failed');
    try {
      final r = await pro.save();
      if (r.overwritten) {
        _snack(saved);
        return _ProSaved.overwritten;
      }
      if (!mounted) return _ProSaved.copied;
      await _proLeaveToCopy(
          pro,
          r.path,
          context.t('pse.readonly_fallback', {'name': p.basename(r.path)}));
      return _ProSaved.copied;
    } catch (e) {
      _snack(failed.replaceAll('{error}', userErrorText(e)));
      return _ProSaved.failed;
    }
  }

  Future<void> _proSaveAs({required bool documents}) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final failed = context.t('pse.save_failed');
    try {
      final r = await pro.saveAs(documents: documents);
      if (!mounted) return;
      final name = {'name': p.basename(r.path)};
      await _proLeaveToCopy(
          pro,
          r.path,
          r.fellBack
              ? context.t('pse.readonly_fallback', name)
              : context.t('pse.saved_copy', name));
    } catch (e) {
      _snack(failed.replaceAll('{error}', userErrorText(e)));
    }
  }

  /// Kopya kaydedildi: oturum kopyaya geçer — bu ekran kapanır, kopya aynı
  /// sayfada açılır (son dosyalara da düşer; PS3'ün kalıcı çözümü). Özgün
  /// dosyaya dokunulmadı; bellekteki değişiklikler bırakılır.
  Future<void> _proLeaveToCopy(
      PdfProEditController pro, String copy, String message) async {
    final file = File(copy);
    if (_pdfCount > 0 && await file.exists()) {
      final size = await file.length();
      ReadingPositions.record(copy, _livePdfPage() ?? _pdfPage, _pdfCount,
          size: size);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final reverted = await pro.revert();
    await _closePro(reload: false);
    if (!reverted || pro.savedOverOriginal) {
      // Bellekteki belge özgünün kayıtlı hâline döndürülemedi: pdfrx'in yol
      // önbelleğinde değişmiş hâli kalmasın.
      await PdfReload.reloadFile(widget.doc.path);
    }
    if (navigator.mounted) navigator.pop();
    showSnackOn(messenger, message);
    await openSavedPdf(copy);
  }

  /// Sürüm geçmişi (Faz 54 / 3): önceki sürüme dön.
  Future<void> _proVersions() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final versions = await PdfVersionHistory.list(widget.doc.path);
    if (!mounted) return;
    final version = await showPdfVersionsSheet(context, versions: versions);
    if (version == null || !mounted || _pro != pro) return;
    final question = context.t('pse.version_restore_q',
        {'when': pdfVersionWhen(context, version.savedAt)});
    final unsaved = context.t('pse.version_restore_unsaved');
    final ok = await showAppConfirm(
      context,
      title: context.t('pse.version_restore'),
      message: pro.session.dirty ? '$question\n\n$unsaved' : question,
      confirmLabel: context.t('pse.version_restore'),
    );
    if (!ok || !mounted || _pro != pro) return;
    final restored = context.t('pse.version_restored');
    final failed = context.t('pse.version_failed');
    // Belge diskte değişecek: oturum (ve kaydedilmemiş iş) bırakılır.
    await _closePro(reload: false);
    try {
      await PdfVersionHistory.restore(widget.doc.path, version);
      _snack(restored);
    } catch (e) {
      _snack(failed.replaceAll('{error}', userErrorText(e)));
    }
    if (!mounted) return;
    _partSetState(() => _pdfText = '');
    await _reloadPdf();
  }

  /// Çökme kurtarma (Faz 54 / 4): belge açılınca yarıda kalmış oturum varsa
  /// "Kaydedilmemiş düzenlemeleri geri yükle" sorulur.
  Future<void> _proCheckRecovery() async {
    if (_proRecoveryAsked || _pro != null) return;
    _proRecoveryAsked = true;
    if (!await _proEnabled()) return;
    final path = widget.doc.path;
    final entry = await PdfEditRecovery.find(path);
    if (entry == null || !mounted) return;
    final copyOnly = entry.steps == null;
    final done = context.t('pse.recover_done', {'n': entry.count});
    final none = context.t('pse.recover_none');
    final partialText = context.t('pse.recover_partial');
    final choice = await showPdfRecoverSheet(context,
        count: entry.count, copyOnly: copyOnly);
    if (choice == null || !mounted) return; // şimdi değil: kayıt durur
    if (choice == PdfRecoverChoice.discard) {
      await PdfEditRecovery.clear(path);
      return;
    }
    if (copyOnly) {
      if (await _proSaveRecoveredCopy(entry)) await PdfEditRecovery.clear(path);
      return;
    }
    await _enterProEdit();
    final pro = _pro;
    if (pro == null) return; // korumalı belgede vazgeçildi: kayıt durur
    final n = await pro.recover(entry);
    if (n == entry.count) {
      _snack(done);
      return;
    }
    _snack(n == 0
        ? none
        : partialText
            .replaceAll('{n}', '$n')
            .replaceAll('{total}', '${entry.count}'));
    // Oynatılamayan iş kaybolmasın: geçici kayıt kopya olarak kurtarılır.
    await _proSaveRecoveredCopy(entry);
  }

  /// Geçici artımlı kaydı Belgeler'e kopya olarak yazar; true = yazıldı.
  Future<bool> _proSaveRecoveredCopy(PdfEditRecoveryEntry entry) async {
    final snapshot = entry.snapshot;
    if (snapshot == null || !mounted) return false;
    final failed = context.t('pse.save_failed');
    final open = context.t('ps.open');
    final savedCopy = context.t('pse.saved_copy');
    final messenger = ScaffoldMessenger.of(context);
    try {
      final docs = await DocsHome.resolve();
      final target = await PdfSave.copyTargetFor(
          p.join(docs.path, p.basename(widget.doc.path)));
      await snapshot.copy(target);
      showSnackOn(
        messenger,
        savedCopy.replaceAll('{name}', p.basename(target)),
        action: SnackBarAction(
            label: open, onPressed: () => openSavedPdf(target)),
        duration: kSnackAction,
      );
      return true;
    } catch (e) {
      _snack(failed.replaceAll('{error}', userErrorText(e)));
      return false;
    }
  }
}
