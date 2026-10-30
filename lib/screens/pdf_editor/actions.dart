part of '../pdf_editor_screen.dart';

extension _PdfEditorScreenActionsPart on _PdfEditorScreenState {
  Future<void> _prepare() async {
    try {
      final dir = await Directory.systemTemp.createTemp('pdf_editor');
      final work = p.join(dir.path, p.basename(widget.path));
      // `copy`: dosya Dart belleğine alınmadan kopyalanır (2026-09-23).
      await File(widget.path).copy(work);
      // Belge bir kez okunur ve oturum boyunca BELLEKTE kalır (Faz 31 / PD4:
      // sayfa değişiminde tüm PDF'i diskten yeniden okuma kalktı).
      final bytes = await File(work).readAsBytes();
      if (!mounted) return;
      _partSetState(() {
        _workDir = dir;
        _workPath = work;
        _history = PdfEditHistory(bytes, PdfOverlayLayer.empty);
        _ready = true;
      });
      await _loadOutline();
    } catch (e) {
      if (mounted) {
        _partSetState(() => _error = _str.t('pe.prepare_failed', {'error': userErrorText(e)}));
      }
    }
  }

  Future<List<int>> _workBytes() async => _history!.bytes;

  /// Açık sayfanın düzenlenebilir öğelerini yükler.
  Future<void> _loadOutline() async {
    final path = _workPath;
    if (path == null) return;
    // İç içe çağrı (uygula → senkron → anahat): dıştaki iş meşgul bayrağını
    // ve notunu tutar; burada erken bırakılırsa "bitti" sanılıp dokunuşlar
    // yarım belgeye giderdi.
    final owner = !_busy;
    final page = _page;
    if (owner) _setBusy(_str.t('pe.busy_reading', {'page': page}));
    try {
      final outline =
          await PdfPageEdit.outlineInBackground(await _workBytes(), _page - 1);
      if (!mounted) return;
      _partSetState(() {
        _outline = outline;
        _selectedObject = null;
        _error = null;
        _outlineError = null;
        // Taranmış aday iki türlü olur: (1) hiç metin yok, (2) metin VAR ama
        // görünmez — "aranabilir PDF"in OCR katmanı (kullanıcı bulgusu
        // 2026-08-06: aranabilir tarattığı belgede düzeltme çubuğu hiç
        // çıkmıyordu, çünkü sayfa metinli sayılıyordu). Sınıf YAPIŞKAN.
        if (outline.paragraphs.isEmpty || outline.scanned) {
          _scannedPages.add(_page);
        }
      });
    } on PdfPageRefused catch (e) {
      if (mounted) {
        _partSetState(() {
          _outline = PdfPageOutline.empty;
          _outlineError = e.message;
        });
      }
      _snack(e.message);
    } catch (e) {
      if (mounted) {
        _partSetState(() {
          _outline = PdfPageOutline.empty;
          _outlineError = userErrorText(e);
        });
      }
      _snack(_str.t('pe.outline_failed', {'error': userErrorText(e)}));
    } finally {
      if (owner) _setBusy(null);
    }
  }

  /// Meşgul bayrağı + ne yapıldığı (ipucu şeridinde dönen çark ve cümle).
  /// Kullanıcı 2026-10-30: *"bir tuşa basınca bir şey olmuyor, aslında
  /// yükleniyormuş, birkaç saniye sonra bir şey oluyor"* — 3 piksellik çubuk
  /// fark edilmiyordu; artık her bekleme ne olduğunu söylüyor.
  void _setBusy(String? note) {
    if (!mounted) return;
    _partSetState(() {
      _busy = note != null;
      _busyNote = note;
    });
  }

  Future<void> _loadBackground() async {
    final owner = !_busy;
    if (owner) _setBusy(_str.t('pe.busy_background'));
    try {
      final items =
          await PdfPageEdit.backgroundItemsInBackground(await _workBytes());
      if (!mounted) return;
      _partSetState(() {
        _background = items;
        _backgroundPicked.clear();
      });
    } on PdfPageRefused catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(_str.t('pe.background_failed', {'error': userErrorText(e)}));
    } finally {
      if (owner) _setBusy(null);
    }
  }

  /// [op]'u işlem listesine ekleyip uygular ve görüntüleyiciyi tazeler.
  ///
  /// Faz 31 / PD4: eskiden her adım tüm dosyanın disk kopyasını
  /// (`undo_N.pdf`) bırakıyordu. Artık adım bir komut; güncel belge bellekte,
  /// disk yalnız görüntüleyicinin okuduğu TEK çalışma dosyası.
  Future<void> _apply(PdfByteOp op, String note) async {
    await _history!.applyOp(note, op);
    await _syncDocument();
    if (mounted) _snack(note);
  }

  /// Bellekteki güncel belgeyi görüntüleyiciye yansıtır.
  Future<void> _syncDocument() async {
    if (_busy) _setBusy(_str.t('pe.busy_refresh'));
    final path = _workPath!;
    await File(path).writeAsBytes(_history!.bytes, flush: true);
    await PdfReload.reloadFile(path);
    if (!mounted) return;
    _partSetState(() => _docRev++);
    await _loadOutline();
  }

  Future<void> _undoLast() async {
    final h = _history;
    if (h == null || !h.canUndo || _busy) return;
    _closeEditors();
    final label = h.undoLabel;
    _setBusy(_str.t('pe.busy_undo', {'what': label ?? ''}));
    try {
      if (await h.undo()) await _syncDocument();
    } finally {
      _setBusy(null);
    }
    if (mounted) _snack(_str.t('pe.undone_what', {'what': label ?? ''}));
  }

  Future<void> _redoLast() async {
    final h = _history;
    if (h == null || !h.canRedo || _busy) return;
    _closeEditors();
    final label = h.redoLabel;
    _setBusy(_str.t('pe.busy_redo', {'what': label ?? ''}));
    try {
      if (await h.redo()) await _syncDocument();
    } catch (e) {
      _longSnack(_str.t('pe.op_failed', {'error': userErrorText(e)}));
    } finally {
      _setBusy(null);
    }
    if (mounted) _snack(_str.t('pe.redone_what', {'what': label ?? ''}));
  }

  /// Bu sayfada OCR ile düzenleme denenmeli mi?
  ///
  /// Taranmış sınıfı **ya da** sayfada görsel olması yeter: gömülü fotokopi
  /// bloğu taşıyan karma sayfalarda kullanıcı "metin var ama düzenletmiyor"
  /// diyordu. Tamamen metin olan sayfalarda (görsel yok) OCR çalıştırılmaz —
  /// gereksiz iş ve zaten paragraf kutuları var.
  bool get _ocrEditable =>
      _scannedPages.contains(_page) || _outline.objects.isNotEmpty;

  /// Taranmış sayfanın OCR satır kutularını (gerekiyorsa) yükler. [page]
  /// pdfrx'in CANLI sayfa nesnesi — overlay kurucusundan gelir; yeniden
  /// yüklemeden sonra da doğru belgeyi gösterir. Yalnız zamanlar: build
  /// sırasında çağrılır ama iş Future'a atıldığı için build'i bozmaz.
  void _maybeLoadScanned(PdfPage page) {
    if (!PdfOcrText.isSupported || _scannedLoading) return;
    final key = '$_docRev#${page.pageNumber}';
    if (_scannedKey == key) return;
    _scannedLoading = true;
    Future(() async {
      var lines = const <ScannedLine>[];
      try {
        final ocr = await PdfOcrText.forPage(page);
        lines = [
          for (final f in ocr?.fragments ?? const <PdfPageTextFragment>[])
            if (f.text.trim().isNotEmpty) ScannedLine(f.text.trim(), f.bounds),
        ];
      } catch (_) {
        // Bilinçli en iyi çaba: OCR yoksa/başarısızsa satır listesi boş kalır ve kullanıcı taranmış sayfa yerine normal düzenlemeyi görür.
      }
      if (!mounted) return;
      _partSetState(() {
        _scannedKey = key;
        _scannedLines = _withoutParagraphOverlaps(lines);
        _scannedLoading = false;
      });
    });
  }

  /// Paragraf kutusuyla örtüşen OCR satırlarını eler: üstüne yazılmış satır
  /// artık GERÇEK metindir ve kutusu paragraf yolundan gelir — aynı yerde iki
  /// kutu (biri bayat) üst üste binmesin.
  List<ScannedLine> _withoutParagraphOverlaps(List<ScannedLine> lines) {
    if (_outline.paragraphs.isEmpty) return lines;
    bool overlaps(ScannedLine s) {
      for (final par in _outline.paragraphs) {
        final w = (s.box.right < par.right ? s.box.right : par.right) -
            (s.box.left > par.left ? s.box.left : par.left);
        final h = (s.box.top < par.top ? s.box.top : par.top) -
            (s.box.bottom > par.bottom ? s.box.bottom : par.bottom);
        if (w > 0 && h > 0 && w * h > 0.5 * s.box.width * s.box.height) {
          return true;
        }
      }
      return false;
    }

    return [
      for (final s in lines)
        if (!overlaps(s)) s
    ];
  }

  /// OCR satırına dokunuldu: tanınan metin **satırın kendi kutusunda**
  /// düzenlenir (paragrafla aynı yerinde alan — 2026-10-30 kullanıcı:
  /// *"metin düzenleme her PDF türünde aynı değil, kimisinde direkt yerinde,
  /// kimisinde açılan bir pencerede"*). Bitti'de satır beyaz kapakla örtülüp
  /// yeni metin AYNI yere yazılır (bkz. [PdfScannedRetype]); boş bırakmak
  /// satırı siler.
  void _editScannedLine(int index) {
    if (index < 0 || index >= _scannedLines.length) return;
    if (_busy) {
      _snack(_str.t('pe.wait_busy', {'what': _busyNote ?? ''}));
      return;
    }
    _closeEditors();
    _openInline(_scannedLines[index].text, scanned: index);
  }

  /// **Sayfayı düzelt** — taranmış sayfanın TÜM satırlarını bir geçişte
  /// onarır (2026-08-06 kullanıcı isteği: *"düzenle ve AI ile düzenle butonu
  /// koyalım, taranan sayfaları ikisi de mükemmelleştirmeye çalışsın"*).
  ///
  /// [withAi] false → cihaz-içi kural tabanlı düzeltme ([ScanTextFix]):
  /// ücretsiz, çevrimdışı, yalnız kesin bildiğini düzeltir.
  /// [withAi] true → Gemini ([ScanAiFix]): bağlama bakarak daha cesur onarır.
  ///
  /// **Yalnız DEĞİŞEN satırlar yeniden yazılır.** Bütün satırları basmak,
  /// hiç hatası olmayan satırların görüntüsünü de gömülü fontla değiştirirdi;
  /// sayfa "tarama" olmaktan çıkar, kutu hataları her satırda görünür olurdu.
  Future<void> _fixScannedPage({required bool withAi}) async {
    if (_scannedLines.isEmpty) return;
    final originals = [for (final l in _scannedLines) l.text];
    GeminiService? gemini;
    if (withAi) {
      final state = context.read<AppState>();
      if (!await ensureAiKey(context) || !mounted) return;
      gemini = state.gemini;
    }

    await _run(note: _str.t(withAi ? 'pe.busy_fix_ai' : 'pe.busy_fix'), () async {
      final fixed = withAi
          ? await ScanAiFix.polish(gemini!, originals)
          : ScanTextFix.lines(originals);
      final edits = <ScannedEdit>[];
      for (var i = 0; i < originals.length && i < fixed.length; i++) {
        if (fixed[i].trim() == originals[i].trim()) continue;
        edits.add(ScannedEdit(_scannedLines[i].box, fixed[i]));
      }
      if (edits.isEmpty) {
        _snack(_str.t('pe.fix_nothing'));
        return;
      }
      final pageIndex = _page - 1;
      await _apply(
          (b) => PdfScannedRetype.applyMany(
                bytes: b,
                pageIndex: pageIndex,
                edits: edits,
              ),
          _str.t('pe.fix_done', {'n': edits.length}));
      // Sayfa değişti: OCR bellek önbelleği bayat, kutular yeniden yüklensin.
      PdfOcrText.invalidateMemory();
    });
  }

  Future<void> _deleteObject(int index) async {
    final ok =
        await _confirm(_str.t('pe.delete_image'), _str.t('pe.delete_image_body'));
    if (ok != true) return;
    final pageIndex = _page - 1;
    await _run(() => _apply(
        (b) => PdfPageEdit.deleteObjectInBackground(
              b,
              pageIndex: pageIndex,
              objectIndex: index,
            ),
        _str.t('pe.image_deleted')), note: _str.t('pe.busy_image'));
  }

  Future<void> _moveObject(int index, Rect pageRect) async {
    final pageIndex = _page - 1;
    await _run(() => _apply(
        (b) => PdfPageEdit.transformObjectInBackground(
              b,
              pageIndex: pageIndex,
              objectIndex: index,
              left: pageRect.left,
              bottom: pageRect.top < pageRect.bottom
                  ? pageRect.top
                  : pageRect.bottom,
              width: pageRect.width.abs(),
              height: pageRect.height.abs(),
            ),
        _str.t('pe.image_moved')), note: _str.t('pe.busy_image'));
  }

  /// Seçili görseli **kendi merkezinde** döndürür / aynalar (kullanıcı
  /// 2026-08-30). Sayfa döndürmeden ayrı: burada yalnız o görsel oynar.
  Future<void> _turnObject(
    int index, {
    int quarterTurns = 0,
    bool flipH = false,
    bool flipV = false,
  }) async {
    final pageIndex = _page - 1;
    await _run(() => _apply(
        (b) => PdfPageEdit.turnObjectInBackground(
              b,
              pageIndex: pageIndex,
              objectIndex: index,
              quarterTurns: quarterTurns,
              flipH: flipH,
              flipV: flipV,
            ),
        _str.t(quarterTurns != 0 ? 'pe.image_turned' : 'pe.image_mirrored')),
        note: _str.t('pe.busy_image'));
  }

  Future<void> _removeBackground() async {
    if (_backgroundPicked.isEmpty) {
      _snack(_str.t('pe.pick_to_remove'));
      return;
    }
    final picked = {..._backgroundPicked};
    await _run(() async {
      await _apply(
          (b) => PdfPageEdit.removeBackgroundInBackground(b, picked),
          _str.t('pe.items_removed'));
      await _loadBackground();
    });
  }

  Future<void> _rotate(int quarterTurns) async {
    final pageIndex = _page - 1;
    await _run(() => _apply(
        (b) => PdfTools.rotatePagesInBackground(
              b,
              pageIndexes: [pageIndex],
              quarterTurns: quarterTurns,
            ),
        _str.t('pe.page_rotated')), note: _str.t('pe.busy_rotate'));
  }

  /// Ortak sarmalayıcı: meşgul bayrağı + tek yerde hata mesajı.
  ///
  /// Reddedilme mesajları kullanıcıya doğrudan gösterilebilir biçimde
  /// yazıldı ("metin sığmıyor, 2 satır fazla geliyor" gibi); teknik bir
  /// istisna metnine sarmadan aynen gösteriyoruz.
  Future<void> _run(Future<void> Function() body, {String? note}) async {
    if (_busy) {
      _snack(_str.t('pe.wait_busy', {'what': _busyNote ?? ''}));
      return;
    }
    _setBusy(note ?? _str.t('pe.busy_working'));
    try {
      await body();
    } on PdfPageRefused catch (e) {
      // İzin kilitli belge: koruma boş parolayla kalkıyorsa düzenleme tam
      // sadakatle çalışır. Kullanıcıya "PDF araçlarına git, parolayı kaldır,
      // geri gel" diye ödev vermek yerine tek soruyla burada hallediyoruz.
      if (e.encrypted && await _unlockAndRetry(body)) return;
      _longSnack(e.message);
    } on PdfParagraphRefused catch (e) {
      _longSnack(e.message);
    } on ScanAiFixRefused catch (e) {
      // Eksik/bozuk AI yanıtı: sebebi kullanıcıya olduğu gibi söyleniyor,
      // "işlem başarısız" gibi bir örtü metnin altına saklanmıyor.
      _longSnack(e.message);
    } on GeminiException catch (e) {
      _longSnack(e.message);
    } catch (e) {
      _longSnack(_str.t('pe.op_failed', {'error': userErrorText(e)}));
    } finally {
      _setBusy(null);
    }
  }

  /// Şifre korumasını kaldırıp işlemi bir kez daha dener.
  ///
  /// Koruma yalnız ÇALIŞMA KOPYASINDA kalkar; özgün dosya değişmez ve
  /// kullanıcı kaydetmezse hiçbir iz kalmaz.
  Future<bool> _unlockAndRetry(Future<void> Function() body) async {
    if (!mounted) return false;
    final unlock = await showAppConfirm(
        context,
        title: context.t('pe.protected_title'),
        message: context.t('pe.protected_body'),
        confirmLabel: context.t('pe.remove_protection'),
        destructive: true,
    );
    if (unlock != true) return false;

    try {
      await _apply(
          (b) => PdfTools.removePasswordInBackground(b, currentPassword: ''),
          _str.t('pe.protection_removed'));
      await body();
      return true;
    } catch (e) {
      _longSnack(_str.t('pe.unlock_failed', {'error': userErrorText(e)}));
      return true; // mesaj verildi; çağıran ikinci kez göstermesin
    }
  }

  Future<bool> _save() async {
    if (!_dirty) return true;
    _closeEditors();
    // Bekleyen nesneler + form değerleri TEK geçişte yazılır (izolatta).
    final List<int> bytes;
    try {
      _setBusy(_str.t('pe.busy_saving'));
      bytes = await PdfPendingWriter.write(_history!.bytes, _layer);
    } catch (e) {
      _longSnack(_str.t('pe.op_failed', {'error': userErrorText(e)}));
      return false;
    } finally {
      _setBusy(null);
    }
    if (!mounted) return false;
    final outcome = await savePdfWithChoice(
      context,
      originalPath: widget.path,
      bytes: bytes,
      note: _str.t('pe.save_note'),
    );
    if (outcome == null) return false;
    if (mounted) _partSetState(() => _history!.markSaved());
    return true;
  }

  /// Altı editörün ortak çıkış sorusu (Faz 20): Kaydet · Kaydetme · İptal.
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    switch (await showUnsavedChanges(context)) {
      case UnsavedChoice.save:
        return _save();
      case UnsavedChoice.discard:
        return true;
      case UnsavedChoice.cancel:
        return false;
    }
  }
}
