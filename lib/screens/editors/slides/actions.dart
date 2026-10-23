part of '../slides_editor_screen.dart';

extension _SlidesEditorScreenActionsPart on _SlidesEditorScreenState {
  /// Pinch odağındaki içerik yerinde kalsın: (ofset+odak)*çarpan-odak.
  void _fixScroll(double f, Offset focal) {
    if (_hCtrl.hasClients) {
      _hCtrl.jumpTo(((_hCtrl.offset + focal.dx) * f - focal.dx)
          .clamp(0.0, _hCtrl.position.maxScrollExtent));
    }
    if (_vCtrl.hasClients) {
      _vCtrl.jumpTo(((_vCtrl.offset + focal.dy) * f - focal.dy)
          .clamp(0.0, _vCtrl.position.maxScrollExtent));
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      // Faz 28 / SL7: ayrıştırma + bütün slaytların çizim modeli ayrı
      // izolatta (50 slaytlık destede UI izleği donmasın). İzolat
      // kurulamazsa ana izlekte.
      if (SlidesEditorScreen.parseInIsolate) {
        try {
          // `compute` + statik işlev: kapanış ekranın durumunu yakalayıp
          // izolata taşımaya çalışmasın.
          _editor = await compute(PptxEditor.parse, bytes);
        } catch (_) {
          _editor = PptxEditor.parse(bytes);
        }
      } else {
        _editor = PptxEditor.parse(bytes);
      }
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

  /// [EditSession]'ın yazma işi — zip izolatta (Faz 20 / ED3).
  Future<void> _writeFile() async {
    final editor = _editor;
    if (editor == null) return;
    _flushOutline();
    final bytes = await editor.saveAsync();
    await SafeWrite.bytes(widget.path, bytes);
    unawaited(ActivityLog.add(ActivityKind.documentEdit, widget.path));
  }

  /// Taslaktan geri yükleme (Faz 20).
  Future<void> _restoreDraft(Uint8List bytes) async {
    _history.clear();
    _partSetState(() {
      _commitEdit();
      _selShape = null;
      _editor = PptxEditor.parse(bytes);
    });
    _session.changed();
  }

  Future<void> _save() async {
    if (_editor == null) return;
    // Açık metin düzenlemesi ve anahattaki bekleyen yazı önce XML'e.
    if (_textCtrl != null) _partSetState(_commitEdit);
    _flushOutline();
    final ok = await _session.saveNow();
    if (!mounted) return;
    if (ok) {
      showSnack(context, context.t('common.saved_hint'));
      _partSetState(() {});
    } else {
      _snack(AppStrings.current.t('common.save_failed',
          {'error': userErrorText(_session.coordinator.lastError ?? '')}));
    }
  }

  /// Editörün o anki içeriğini İndirilenler'e yazar (bkz. [SaveToDownloads]).
  Future<void> _download() async {
    final editor = _editor;
    if (editor == null) return;
    _flushOutline();
    await runDownloadAction(context,
        () async => SaveToDownloads.saveBytes(widget.name, await editor.saveAsync()));
  }

  Future<void> _export() async {
    final editor = _editor;
    if (editor == null) return;
    _flushOutline();
    final f = File('${Directory.systemTemp.path}/${widget.name}');
    await f.writeAsBytes(await editor.saveAsync());
    await Share.shareXFiles([XFile(f.path)], text: widget.name);
  }

  /// Slaytların **ekranda göründüğü hâlini** PDF'e basar.
  ///
  /// Her slayt önce PNG'e alınıyor, sonra üstüne görünmez metin katmanı
  /// yazılıyor — gerekçesi `SlidesPdf` ve `SlideSnapshot` başlarında.
  /// Görüntü ve metin kutuları AYNI [_pdfPixelRatio] ile ölçekleniyor; ikisi
  /// ayrışırsa seçim kutuları yazının yanına düşer.
  Future<void> _exportPdf() async {
    final editor = _editor;
    if (editor == null || editor.slides.isEmpty) return;

    final progress = ValueNotifier<String>('');
    // Pencere KİMLİĞİYLE kapatılır (bkz. `core/busy_dialog.dart`). Eskiden
    // kapatma `Navigator.pop` idi: pencere ortada değilse (kullanıcı geri
    // tuşuna bastı) o `pop` arkadaki SAYFAYI kapatıyordu.
    final busy = showBusyDialog(
      context,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator()),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, v, __) => Text(v),
              ),
            ),
          ],
        ),
      ),
    );
    void close() => busy.close();

    final dir = await Directory.systemTemp.createTemp('slayt-pdf');
    try {
      final paths = <String>[];
      final linesPerPage = <List<OcrLine>>[];
      SlideVM? firstView;

      for (var i = 0; i < editor.slides.length; i++) {
        final view = editor.slides[i].view;
        if (view == null) continue; // çizilemeyen slayt sessizce atlanır
        if (!mounted) return;
        progress.value = context.t(
          'sl.pdf_progress',
          {'n': i + 1, 'total': editor.slides.length},
        );

        final png =
            await SlideSnapshot.toPng(context, view, pixelRatio: _pdfPixelRatio);
        if (png == null) return; // ekran kapandı — vazgeçildi

        final file = File('${dir.path}/slayt-${i.toString().padLeft(4, '0')}.png');
        await file.writeAsBytes(png);
        paths.add(file.path);
        linesPerPage.add(SlidesPdf.textLines(view, pixelRatio: _pdfPixelRatio));
        firstView ??= view;
      }

      if (paths.isEmpty || firstView == null) return;

      // Sayfa boyu = slaydın kendi boyu. A4'e sığdırmak 16:9 bir sunumu
      // kâğıdın ortasında bant hâline getirirdi; PowerPoint de slayt boyunda basar.
      final bytes = await ConversionService().imagesToPdf(
        paths,
        ocrLinesPerPage: linesPerPage,
        uniformPage: PdfPageFormat(firstView.widthPt, firstView.heightPt),
      );
      final out = File('${dir.path}/${_stem(widget.name)}.pdf');
      await out.writeAsBytes(bytes);

      close();
      if (!mounted) return;
      await Share.shareXFiles([XFile(out.path)],
          text: context.t('sl.pdf_share'));
    } catch (e) {
      close();
      _snack(AppStrings.current.t('sl.pdf_failed', {'error': userErrorText(e)}));
    } finally {
      close();
      progress.dispose();
      // Geçici PNG'ler destede onlarca MB tutabilir; paylaşım PDF'i okuduktan
      // sonra silmek yerine burada silmek dosyayı da götürürdü, o yüzden
      // PNG'ler gidiyor, PDF sistemin geçici klasöründe kalıyor.
      for (final p in Directory(dir.path).listSync()) {
        if (p.path.endsWith('.png')) {
          try {
            p.deleteSync();
          } catch (_) {
            // silinemedi — işletim sistemi geçici klasörü zaten toplar
          }
        }
      }
    }
  }

  /// Dosya adının uzantısız kökü.
  String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  void _snack(String m) {
    if (!mounted) return;
    showSnack(context, m);
  }

  int get _slideCount => _editor?.slides.length ?? 0;

  /// Bir slayt kartının listedeki toplam yüksekliği (başlık şeridi + kart +
  /// alt boşluk). `_buildSlides`/`_slideCard` yerleşimiyle BİREBİR aynı
  /// formül — ikisi ayrışırsa "slayta git" yanlış yere atlar.
  double _slideExtent(int i) {
    final cardW = _baseW * _zoom;
    final slide = _editor!.slides[i];
    final view = slide.view;
    final aspect = view == null ? 16 / 9 : view.widthPt / view.heightPt;
    final cardH = aspect <= 0 ? cardW * 9 / 16 : cardW / aspect;
    return 40 * _zoom + cardH + _notesHeight(slide) * _zoom + 20 * _zoom;
  }

  /// Konuşmacı notu şeridinin zoom UYGULANMAMIŞ yüksekliği (not yoksa 0).
  /// `_notesStrip` ile birebir aynı formül — ikisi ayrışırsa "slayta git"
  /// notlu destelerde kayar.
  double _notesHeight(PptxSlide slide) {
    final editor = _editor;
    if (editor == null) return 0;
    if (editor.notesOf(slide).trim().isEmpty) return 0;
    return 58;
  }

  /// **Notlar levhası** (2026-10-22, kullanıcı: *"sunumlarda açıklama ve
  /// notlar bölümünü düzgünce görme"*). Şerit kanvasla birlikte ölçekleniyor
  /// ve tek satırda kesiliyordu — uzun not okunamıyordu. Levha notu normal
  /// punto, kaydırılabilir ve seçilebilir gösterir; notlu slaytlar arasında
  /// ileri/geri gezilir, metin kopyalanır.
  Future<void> _showNotes(PptxSlide start) async {
    final editor = _editor;
    if (editor == null) return;
    final withNotes = [
      for (final s in editor.slides)
        if (editor.notesOf(s).trim().isNotEmpty) s,
    ];
    if (withNotes.isEmpty) return;
    var i = withNotes.indexOf(start).clamp(0, withNotes.length - 1);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final slide = withNotes[i];
          final text = editor.notesOf(slide);
          final theme = Theme.of(ctx);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            builder: (ctx, scroll) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ctx.t('sl.notes_title', {'n': slide.index}),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: ctx.t('common.copy'),
                        icon: const Icon(AppIcons.copy),
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: text)),
                      ),
                      // Faz 28 / madde 8: not artık yazılabilir.
                      IconButton(
                        key: const ValueKey('notes-edit-open'),
                        tooltip: ctx.t('sl.notes_edit'),
                        icon: const Icon(AppIcons.edit),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editNotes(slide);
                        },
                      ),
                      IconButton(
                        key: const ValueKey('notes-prev'),
                        tooltip: ctx.t('sl.notes_prev'),
                        icon: const Icon(AppIcons.arrowUp),
                        onPressed: i == 0 ? null : () => setSheet(() => i--),
                      ),
                      IconButton(
                        key: const ValueKey('notes-next'),
                        tooltip: ctx.t('sl.notes_next'),
                        icon: const Icon(AppIcons.arrowDown),
                        onPressed: i >= withNotes.length - 1
                            ? null
                            : () => setSheet(() => i++),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      text,
                      key: const ValueKey('notes-text'),
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// [i]. slaydın (0 tabanlı) liste içindeki kaydırma konumu.
  double _slideOffset(int i) {
    var offset = 8 * _zoom; // ListView'ın üst dolgusu
    for (var j = 0; j < i; j++) {
      offset += _slideExtent(j);
    }
    return offset;
  }

  /// Kaydırma konumundan "kaçıncı slayttayız". Ekranın üstünden bir tutam
  /// aşağısı (60 px) ölçüt: iki slaydın sınırı tam tepedeyken kullanıcı
  /// gözüyle ALTTAKİ slayda bakıyordur.
  void _onScroll() {
    if (!_vCtrl.hasClients || _baseW <= 0 || _slideCount == 0) return;
    final target = _vCtrl.offset + 60;
    var at = 8 * _zoom;
    var index = 0;
    for (var i = 0; i < _slideCount; i++) {
      at += _slideExtent(i);
      if (at > target) {
        index = i;
        break;
      }
      index = i;
    }
    final next = index + 1;
    if (next != _currentSlide) _partSetState(() => _currentSlide = next);
  }

  /// [number] 1 tabanlı slayt numarasına kaydırır.
  Future<void> _goToSlide(int number) async {
    if (!_vCtrl.hasClients || _slideCount == 0) return;
    final index = (number - 1).clamp(0, _slideCount - 1);
    final target = _slideOffset(index)
        .clamp(0.0, _vCtrl.position.maxScrollExtent);
    await Motion.scrollTo(context, _vCtrl, target);
    if (mounted) _partSetState(() => _currentSlide = index + 1);
  }

  Future<void> _showGoToSlide() async {
    final total = _slideCount;
    if (total == 0) return;
    final ctrl = TextEditingController(text: '$_currentSlide');
    // Metin SEÇİLİ açılır: kullanıcı numarayı silmeden üstüne yazabilsin.
    ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('sl.goto')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(labelText: ctx.t('sl.goto_hint', {'total': total})),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text(ctx.t('common.go')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null) await _goToSlide(value);
  }

  /// Slaytların düz metni — arama ve AI özeti aynı kaynağı kullanır.
  /// Slayt numarası metne yazılır: özet "3. slaytta…" diyebilsin, arama
  /// sonucu hangi slaytta olduğunu gösterebilsin.
  List<String> _slideTexts() => [
        for (final slide in _editor?.slides ?? const <PptxSlide>[])
          slide.paragraphs.map((p) => p.text).join('\n'),
      ];

  void _toggleFind() {
    _partSetState(() {
      _finding = !_finding;
      if (!_finding) {
        _findCtrl.clear();
        _hits = const [];
        _hitIndex = -1;
        _hitLimit = false;
      }
    });
  }

  void _runSearch(String query) {
    final result = searchSections(_slideTexts(), query);
    _partSetState(() {
      _hits = result.hits;
      _hitLimit = result.hitLimit;
      _hitIndex = _hits.isEmpty ? -1 : 0;
    });
    if (_hits.isNotEmpty) _goToSlide(_hits.first.section + 1);
  }

  void _stepHit(int delta) {
    if (_hits.isEmpty) return;
    final next = (_hitIndex + delta) % _hits.length;
    _partSetState(() => _hitIndex = next < 0 ? _hits.length - 1 : next);
    _goToSlide(_hits[_hitIndex].section + 1);
  }

  /// AI özeti — slayt numaralı düz metinle (bkz. [_slideTexts]).
  Future<void> _summarize() async {
    final texts = _slideTexts();
    final buffer = StringBuffer();
    for (var i = 0; i < texts.length; i++) {
      if (texts[i].trim().isEmpty) continue;
      buffer.writeln(
          context.t('sl.slide_of', {'n': i + 1, 'total': texts.length}));
      buffer.writeln(texts[i].trim());
      buffer.writeln();
    }
    await AiSummaryFlow.run(context, buffer.toString(), title: widget.name);
  }
}
