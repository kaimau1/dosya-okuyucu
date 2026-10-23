part of '../word_editor_screen.dart';

extension _WordEditorScreenActionsPart on _WordEditorScreenState {
  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      _editor = DocxEditor.parse(bytes);
      _viewBytes = _editor!.viewBytes();
    } catch (e) {
      _error = userErrorText(e);
    }
    if (mounted) _partSetState(() {});
    // Ekran açılmayı BEKLEMEZ: kaynak damgası + taslak araması arkada.
    if (_editor != null) {
      unawaited(_session.captureSource());
      unawaited(lookForDraft(widget.path));
    }
  }

  /// Taslaktan geri yükleme: belge taslağın baytlarıyla yeniden kurulur ve
  /// kirli sayılır (kaydedilene kadar dosya değişmez).
  Future<void> _restoreDraft(Uint8List bytes) async {
    _undo.clear();
    _partSetState(() {
      _editor = DocxEditor.parse(bytes);
      _viewBytes = _editor!.viewBytes();
      _editing = false;
    });
    _session.changed();
  }

  /// [EditSession]'ın yazma işi: zip izolatta, yazım güvenli.
  Future<void> _writeFile() async {
    final editor = _editor;
    if (editor == null) return;
    final bytes = await editor.saveAsync();
    await SafeWrite.bytes(widget.path, bytes);
    // "Yaptıklarım" defteri (istek 2026-08-07): düzenlenen belge orada
    // görünsün. Beklenmez — kaydetmenin hızını defter yavaşlatmamalı.
    unawaited(ActivityLog.add(ActivityKind.documentEdit, widget.path));
  }

  Future<void> _save() async {
    if (_editor == null) return;
    // Hata metni await'ten önce çevrilir (asenkron boşluktan sonra `context`
    // kullanılamaz).
    final saveFailed = context.t('word.save_failed');
    final ok = await _session.saveNow();
    // Canlı görünüm DOM'da zaten güncel — yeniden çizim yok, imleç kaybolmaz.
    if (!mounted) return;
    if (ok) {
      showSnack(context, context.t('common.saved_hint'));
      _partSetState(() {});
    } else {
      _snack(saveFailed.replaceAll(
          '{error}', userErrorText(_session.coordinator.lastError ?? '')));
    }
  }

  /// Editörün o anki içeriğini İndirilenler'e yazar (bkz. [SaveToDownloads]).
  Future<void> _download() async {
    final editor = _editor;
    if (editor == null) return;
    await runDownloadAction(
        context, () => SaveToDownloads.saveBytes(widget.name, editor.save()));
  }

  Future<void> _export() async {
    final editor = _editor;
    if (editor == null) return;
    final f = File('${Directory.systemTemp.path}/${widget.name}');
    await f.writeAsBytes(editor.save());
    await Share.shareXFiles([XFile(f.path)], text: widget.name);
  }

  void _snack(String m) {
    if (!mounted) return;
    showSnack(context, m);
  }

  /// Mobil akış ↔ sayfa görünümü. Kalıcı değil: belge her açılışta Word'deki
  /// gibi SAYFA görünümüyle gelir (2026-07-28 kullanıcı kararı).
  void _toggleFlow() {
    final on = !_flow;
    _viewKey.currentState?.setFlow(on);
    _partSetState(() => _flow = on);
  }

  void _toggleEdit() {
    final on = !_editing;
    _readingBars.show();
    final view = _viewKey.currentState;
    // Yazı okunur boyutta düzenlenir (W6): sayfa görünümü ~0,5 ölçekte
    // (11 pt ≈ 5–6 px) — düzenlerken mobil akışa geçilir, çıkışta dönülür.
    if (on && !_flow && !_plainMode) {
      view?.setFlow(true);
      _flowForEdit = true;
      _flow = true;
    } else if (!on && _flowForEdit) {
      view?.setFlow(false);
      _flowForEdit = false;
      _flow = false;
    }
    if (!on) _panel.close();
    view?.setEditing(on, spellcheck: EditPrefs.wordSpellcheck);
    _partSetState(() => _editing = on);
  }

  /// Eşleme sigortası: işaretli paragraf sayısı bizimkiyle uyuşmuyorsa
  /// canlı düzenleme yanlış paragrafa yazabilir → kapat, yedek editöre yönlendir.
  void _onParagraphCount(int webCount) {
    final ours = _editor?.paragraphs.length ?? -1;
    if (webCount == ours) return;
    _disableLive(webCount, ours);
  }

  void _disableLive(int web, int ours) {
    _viewKey.currentState?.setEditing(false);
    _partSetState(() => _editing = false);
    _snack(context.t('word.live_edit_unsafe', {'web': web, 'ours': ours}));
  }

  /// Canlı görünümden gelen düzenleme (parçalar, Enter / geri silme ile
  /// böl–birleştir, geri al). Model ile görünüm ayrışırsa sigorta.
  void _onLive(Map data) {
    final editor = _editor;
    if (editor == null) return;
    if (!editor.applyLiveMessage(data)) {
      _disableLive(-1, editor.paragraphs.length);
      return;
    }
    _session.changed();
  }

  bool get _liveEditing => _editing && !_plainMode;
  bool get _canUndo => _liveEditing ? _viewCanUndo : _undo.canUndo;
  bool get _canRedo => _liveEditing ? _viewCanRedo : _undo.canRedo;

  void _undoAny() =>
      _liveEditing ? _viewKey.currentState?.undo() : _undoStep();
  void _redoAny() =>
      _liveEditing ? _viewKey.currentState?.redo() : _redoStep();

  /// Canlı görünümdeki hizalama düğmesinden gelir; kaydetmede `w:jc` yazılır.
  void _onAlignChanged(int i, String align) {
    final paras = _editor?.paragraphs;
    if (paras == null || i < 0 || i >= paras.length) return;
    paras[i].align = align;
    _session.changed();
  }

  void _onSelection(DocxSelection sel) {
    if (sel.bold == _selB &&
        sel.italic == _selI &&
        sel.underline == _selU &&
        sel.strike == _selS &&
        sel.align == _selAlign &&
        sel.list == _selList &&
        sel.font == _selFont &&
        sel.sizePt == _selSize) {
      return;
    }
    _partSetState(() {
      _selB = sel.bold;
      _selI = sel.italic;
      _selU = sel.underline;
      _selS = sel.strike;
      _selAlign = sel.align;
      _selList = sel.list;
      _selFont = sel.font;
      _selSize = sel.sizePt;
    });
  }

  /// Seçili metni AI'a yeniden yazdırır ve sonucu **yerine** koyar.
  ///
  /// Bu, kağıt teması devir notundaki "Word'de seçili paragrafı AI ile yeniden
  /// yaz" maddesiydi; o gün yapılamamasının nedeni seçimin WebView tarafında
  /// kalması ve Flutter'a gelmemesiydi. Köprü (`sendSelectionText` /
  /// `replaceSelectionText`) o engeli kaldırdı.
  void _rewriteSelection() => _withSelection((text) async {
        final result = await showAiRewriteSheet(context, text);
        if (result == null || result.isEmpty || !mounted) return;
        if (!_editing) {
          // Yazabilmek için düzenleme açık olmalı; kullanıcıyı geri
          // göndermek yerine kendimiz açıyoruz.
          _toggleEdit();
        }
        _viewKey.currentState?.replaceSelectionText(result);
        _session.changed();
      });

  /// Seçili metni çevirir — sayfanın üstünde açılan kartta, dil
  /// kendiliğinden bulunur (bkz. [QuickTranslateSheet]); belgeye yazılmaz.
  void _translateSelection() => _withSelection((text) {
        QuickTranslateSheet.show(context, text, title: widget.name);
      });

  /// Canlı görünümden gelen madde/numara işareti; kaydetmede `w:numPr` olur.
  void _onListStyle(int i, String kind) {
    _editor?.setListStyle(i, kind);
    _session.changed();
  }

  /// Seçili metin geldi — bekleyen işi (AI / çeviri) çalıştır.
  void _onSelectionText(String text) {
    final job = _pendingSelection;
    _pendingSelection = null;
    if (job == null) return;
    if (text.trim().isEmpty) {
      _snack(context.t('word.select_text_first'));
      return;
    }
    job(text);
  }

  /// Seçili metni ister; gelince [then] çalışır.
  void _withSelection(void Function(String text) then) {
    _pendingSelection = then;
    _viewKey.currentState?.requestSelectionText();
  }

  void _toggleFind() {
    _partSetState(() {
      _finding = !_finding;
      if (!_finding) {
        _replacing = false;
        _hitCount = 0;
        _hitIndex = -1;
        _findCtrl.clear();
      }
    });
  }

  void _runFind(String query) {
    _hitIndex = -1;
    _viewKey.currentState?.findAll(query);
  }

  void _onFindCount(int hits) {
    _partSetState(() {
      _hitCount = hits;
      _hitIndex = hits > 0 ? 0 : -1;
    });
    if (hits > 0) _viewKey.currentState?.findGo(0);
  }

  void _stepHit(int delta) {
    if (_hitCount == 0) return;
    final next = (_hitIndex + delta) % _hitCount;
    _partSetState(() => _hitIndex = next < 0 ? next + _hitCount : next);
    _viewKey.currentState?.findGo(_hitIndex);
  }

  /// Etkin eşleşmeyi değiştirir. Değiştirmek metnin uzunluğunu değiştirdiği
  /// için eşleşme listesi ARTIK GEÇERSİZ → arama yeniden koşturulur.
  void _replaceCurrent() {
    if (_hitIndex < 0 || !_editing) {
      _snack(context.t('word.replace_needs_edit'));
      return;
    }
    _viewKey.currentState?.replaceHit(_hitIndex, _replaceCtrl.text);
    _runFind(_findCtrl.text);
  }

  void _replaceAll() {
    if (!_editing) {
      _snack(context.t('word.replace_needs_edit'));
      return;
    }
    _viewKey.currentState?.replaceAll(_findCtrl.text, _replaceCtrl.text);
  }

  void _onReplaced(int count) {
    _snack(context.t('excel.replaced_count', {'n': count}));
    _partSetState(() {
      _hitCount = 0;
      _hitIndex = -1;
    });
    _session.changed();
  }

  /// "Sayfaya git" — canlı görünümdeki sayfa rozetine dokununca.
  Future<void> _showGoToPage() async {
    final total = _pageCount;
    if (total <= 0) return;
    final ctrl = TextEditingController(text: '$_page');
    ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('word.goto_page')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: ctx.t('word.goto_page_hint', {'total': total})),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text(ctx.t('common.go')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null) {
      _viewKey.currentState?.goToPage(value.clamp(1, total));
    }
  }

  /// **Resim ekle** (Faz 9 / Y1): galeriden/dosyadan seçilen resim imlecin
  /// bulunduğu paragrafın ALTINA satır içi eklenir. Yapısal bir değişiklik
  /// olduğu için belge yeniden çizilir ve düzenleme kaldığı yerden sürer.
  Future<void> _insertImage() async {
    final editor = _editor;
    if (editor == null) return;
    final at = await _viewKey.currentState?.caretParagraph() ?? -1;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif'],
      withData: true,
    );
    final file = picked?.files.single;
    final data = file?.bytes;
    if (file == null || data == null || !mounted) return;
    final size = await _imageSize(data);
    final ext = (file.extension ?? 'png').toLowerCase();
    final view = _viewKey.currentState;
    if (_liveEditing && view != null) {
      // Yeniden çizim yok (W9): resim ada olarak imlece konur; imleç ve geri
      // al korunur.
      try {
        final id = editor.imageIsland(data,
            ext: ext, widthPx: size.$1, heightPx: size.$2);
        final mime = ext == 'jpg' ? 'jpeg' : ext;
        final w = size.$1 <= 0 ? 400.0 : size.$1.toDouble();
        final placed = await view.insertImageIsland(
            id, 'data:image/$mime;base64,${base64Encode(data)}',
            w > 624 ? 624 : w);
        if (placed >= 0) return;
      } catch (e) {
        if (mounted) showUserError(context, e);
        return;
      }
    }
    try {
      editor.insertImageAfter(
        at >= 0 && at < editor.paragraphs.length ? editor.paragraphs[at] : null,
        data,
        ext: ext,
        widthPx: size.$1,
        heightPx: size.$2,
      );
    } catch (e) {
      if (mounted) showUserError(context, e);
      return;
    }
    _rerender();
  }

  /// İmlecin bulunduğu paragraftaki resimleri siler.
  Future<void> _deleteImage() async {
    final editor = _editor;
    if (editor == null) return;
    if (_liveEditing && _viewKey.currentState != null) {
      final n = await _viewKey.currentState!.deleteImagesAtCaret();
      if (!mounted) return;
      if (n == 0) _snack(context.t('word.no_image_here'));
      return;
    }
    final at = await _viewKey.currentState?.caretParagraph() ?? -1;
    if (!mounted) return;
    if (at < 0 || editor.imageCount(at) == 0) {
      _snack(context.t('word.no_image_here'));
      return;
    }
    editor.removeImages(at);
    _rerender();
  }

  /// Model → bayt → yeniden çizim; düzenleme açıksa çizim bitince yeniden
  /// açılır (`onStatus`).
  void _rerender() {
    final editor = _editor;
    if (editor == null) return;
    final bytes = editor.save();
    // Geri alma adımları ESKİ modelin paragraflarına bağlı; yeni modelde
    // anlamsızlar (yanlış paragrafa dokunurlardı).
    _undo.clear();
    _session.changed();
    _partSetState(() {
      _editor = DocxEditor.parse(bytes);
      _viewBytes = _editor!.viewBytes();
      _resumeEditing = _editing;
      _editing = false;
    });
  }

  /// Resmin piksel ölçüsü (çözülemezse 0 → servis varsayılanı kullanır).
  Future<(int, int)> _imageSize(Uint8List data) async {
    try {
      final codec = await instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      final size = (frame.image.width, frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      // Bilinçli en iyi çaba: ölçü bilinmezse makul varsayılan.
      return (0, 0);
    }
  }
}
