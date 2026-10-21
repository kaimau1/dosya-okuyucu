part of '../pdf_editor_screen.dart';

extension _PdfEditorScreenActionsPart on _PdfEditorScreenState {
  Future<void> _prepare() async {
    try {
      final dir = await Directory.systemTemp.createTemp('pdf_editor');
      final work = p.join(dir.path, p.basename(widget.path));
      // `copy`: dosya Dart belleğine alınmadan kopyalanır (2026-09-23).
      await File(widget.path).copy(work);
      if (!mounted) return;
      _partSetState(() {
        _workDir = dir;
        _workPath = work;
        _ready = true;
      });
      await _loadOutline();
    } catch (e) {
      if (mounted) {
        _partSetState(() => _error = _str.t('pe.prepare_failed', {'error': e}));
      }
    }
  }

  Future<List<int>> _workBytes() => File(_workPath!).readAsBytes();

  /// Açık sayfanın düzenlenebilir öğelerini yükler.
  Future<void> _loadOutline() async {
    final path = _workPath;
    if (path == null) return;
    _partSetState(() => _busy = true);
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
          _outlineError = '$e';
        });
      }
      _snack(_str.t('pe.outline_failed', {'error': e}));
    } finally {
      if (mounted) _partSetState(() => _busy = false);
    }
  }

  Future<void> _loadBackground() async {
    _partSetState(() => _busy = true);
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
      _snack(_str.t('pe.background_failed', {'error': e}));
    } finally {
      if (mounted) _partSetState(() => _busy = false);
    }
  }

  /// Değişikliği çalışma kopyasına yazar, geri alma noktası bırakır ve
  /// görüntüleyiciyi tazeler.
  Future<void> _apply(List<int> bytes, String note) async {
    final path = _workPath!;
    final snapshot = p.join(_workDir!.path, 'undo_${_undo.length}.pdf');
    // Geri alma noktası: her adımda bütün PDF'i belleğe okuyup yazmak yerine
    // çekirdek kopyası (büyük belgede adım başına bir PDF boyu bellek).
    await File(path).copy(snapshot);
    _undo.add(snapshot);

    await File(path).writeAsBytes(bytes, flush: true);
    await PdfReload.reloadFile(path);
    if (!mounted) return;
    _partSetState(() => _dirty = true);
    await _loadOutline();
    if (mounted) _snack(note);
  }

  Future<void> _undoLast() async {
    if (_undo.isEmpty) return;
    final snapshot = _undo.removeLast();
    await File(snapshot).copy(_workPath!);
    await PdfReload.reloadFile(_workPath!);
    if (!mounted) return;
    _partSetState(() => _dirty = _undo.isNotEmpty);
    await _loadOutline();
    if (mounted) _snack(_str.t('pe.undone'));
  }

  Future<void> _editParagraph(int index) async {
    if (index < 0 || index >= _outline.paragraphs.length) return;
    final paragraph = _outline.paragraphs[index];
    final currentSize = paragraphPointSize(paragraph);
    final answer = await _askParagraphText(
      paragraph.text,
      pointSize: currentSize > 0 ? currentSize : null,
    );
    if (answer == null || !mounted) return;
    final newText = answer.text;
    final size = answer.size;
    final sizeChanged =
        size != null && size > 0 && (size - currentSize).abs() > 0.05;
    if (newText.trim() == paragraph.text.trim() && !sizeChanged) return;

    await _run(() async {
      final out = await PdfPageEdit.replaceParagraphInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        paragraphIndex: index,
        newText: newText.trim(),
        pointSize: sizeChanged ? size : null,
      );
      await _apply(out, _str.t('pe.paragraph_updated'));
    });
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
      } catch (_) {}
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

  /// OCR satırına dokunuldu: tanınan metin ön-dolu pencerede düzenlenir,
  /// satır beyaz kapakla örtülüp yeni metin AYNI yere yazılır (bkz.
  /// [PdfScannedRetype]). Boş bırakmak satırı siler.
  Future<void> _editScannedLine(int index) async {
    if (index < 0 || index >= _scannedLines.length) return;
    final line = _scannedLines[index];
    final answer = await _askParagraphText(line.text);
    if (answer == null || !mounted) return;
    final newText = answer.text;
    await _run(() async {
      final out = await PdfScannedRetype.apply(
        bytes: await _workBytes(),
        pageIndex: _page - 1,
        box: line.box,
        newText: newText,
      );
      // Sayfa değişti: OCR bellek önbelleği bayat, kutular yeniden yüklensin.
      PdfOcrText.invalidateMemory();
      _docRev++;
      await _apply(out, _str.t('pe.scanned_updated'));
    });
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
      if (!state.hasApiKey) {
        _longSnack(_str.t('pe.fix_needs_key'));
        return;
      }
      gemini = state.gemini;
    }

    await _run(() async {
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
      final out = await PdfScannedRetype.applyMany(
        bytes: await _workBytes(),
        pageIndex: _page - 1,
        edits: edits,
      );
      // Sayfa değişti: OCR bellek önbelleği bayat, kutular yeniden yüklensin.
      PdfOcrText.invalidateMemory();
      _docRev++;
      await _apply(out, _str.t('pe.fix_done', {'n': edits.length}));
    });
  }

  Future<void> _deleteObject(int index) async {
    final ok =
        await _confirm(_str.t('pe.delete_image'), _str.t('pe.delete_image_body'));
    if (ok != true) return;
    await _run(() async {
      final out = await PdfPageEdit.deleteObjectInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        objectIndex: index,
      );
      await _apply(out, _str.t('pe.image_deleted'));
    });
  }

  Future<void> _moveObject(int index, Rect pageRect) async {
    await _run(() async {
      final out = await PdfPageEdit.transformObjectInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        objectIndex: index,
        left: pageRect.left,
        bottom: pageRect.top < pageRect.bottom ? pageRect.top : pageRect.bottom,
        width: pageRect.width.abs(),
        height: pageRect.height.abs(),
      );
      await _apply(out, _str.t('pe.image_moved'));
    });
  }

  /// Seçili görseli **kendi merkezinde** döndürür / aynalar (kullanıcı
  /// 2026-08-30). Sayfa döndürmeden ayrı: burada yalnız o görsel oynar.
  Future<void> _turnObject(
    int index, {
    int quarterTurns = 0,
    bool flipH = false,
    bool flipV = false,
  }) async {
    await _run(() async {
      final out = await PdfPageEdit.turnObjectInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        objectIndex: index,
        quarterTurns: quarterTurns,
        flipH: flipH,
        flipV: flipV,
      );
      await _apply(
          out,
          _str.t(quarterTurns != 0
              ? 'pe.image_turned'
              : 'pe.image_mirrored'));
    });
  }

  Future<void> _removeBackground() async {
    if (_backgroundPicked.isEmpty) {
      _snack(_str.t('pe.pick_to_remove'));
      return;
    }
    await _run(() async {
      final out = await PdfPageEdit.removeBackgroundInBackground(
          await _workBytes(), {..._backgroundPicked});
      await _apply(out, _str.t('pe.items_removed'));
      await _loadBackground();
    });
  }

  Future<void> _rotate(int quarterTurns) async {
    await _run(() async {
      final out = await PdfTools.rotatePagesInBackground(
        await _workBytes(),
        pageIndexes: [_page - 1],
        quarterTurns: quarterTurns,
      );
      await _apply(out, _str.t('pe.page_rotated'));
    });
  }

  /// Ortak sarmalayıcı: meşgul bayrağı + tek yerde hata mesajı.
  ///
  /// Reddedilme mesajları kullanıcıya doğrudan gösterilebilir biçimde
  /// yazıldı ("metin sığmıyor, 2 satır fazla geliyor" gibi); teknik bir
  /// istisna metnine sarmadan aynen gösteriyoruz.
  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    _partSetState(() => _busy = true);
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
      _longSnack(_str.t('pe.op_failed', {'error': e}));
    } finally {
      if (mounted) _partSetState(() => _busy = false);
    }
  }

  /// Şifre korumasını kaldırıp işlemi bir kez daha dener.
  ///
  /// Koruma yalnız ÇALIŞMA KOPYASINDA kalkar; özgün dosya değişmez ve
  /// kullanıcı kaydetmezse hiçbir iz kalmaz.
  Future<bool> _unlockAndRetry(Future<void> Function() body) async {
    if (!mounted) return false;
    final unlock = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pe.protected_title')),
        content: Text(ctx.t('pe.protected_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('pe.remove_protection'))),
        ],
      ),
    );
    if (unlock != true) return false;

    try {
      final unlocked = await PdfTools.removePasswordInBackground(
        await _workBytes(),
        currentPassword: '',
      );
      await _apply(unlocked, _str.t('pe.protection_removed'));
      await body();
      return true;
    } catch (e) {
      _longSnack(_str.t('pe.unlock_failed', {'error': e}));
      return true; // mesaj verildi; çağıran ikinci kez göstermesin
    }
  }

  Future<bool> _save() async {
    if (!_dirty) return true;
    final bytes = await _workBytes();
    if (!mounted) return false;
    final outcome = await savePdfWithChoice(
      context,
      originalPath: widget.path,
      bytes: bytes,
      note: _str.t('pe.save_note'),
    );
    if (outcome == null) return false;
    if (mounted) _partSetState(() => _dirty = false);
    return true;
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pe.unsaved_title')),
        content: Text(ctx.t('pe.unsaved_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(ctx.t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: Text(ctx.t('pe.discard_leave'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(ctx.t('common.save'))),
        ],
      ),
    );
    if (choice == 'save') return _save();
    return choice == 'discard';
  }
}
