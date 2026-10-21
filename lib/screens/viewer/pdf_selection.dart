part of '../viewer_screen.dart';

extension _ViewerScreenPdfSelectionPart on _ViewerScreenState {
  /// Kalem ekranı; özgün dosyanın üzerine yazıldıysa görüntüleyici tazelenir.
  Future<void> _openInk() async {
    if (!await _confirmLeavePending() || !mounted) return;
    final overwritten = await PdfInkScreen.open(
      context,
      widget.doc.path,
      initialPage: _livePdfPage() ?? _pdfPage,
    );
    if (overwritten == true && mounted) await _reloadPdf();
  }

  /// Tek PDF düzenleme ekranı: metin (paragraf), görsel, filigran ve sayfa.
  Future<void> _openPdfEditor() async {
    // Editör ÖZGÜN dosyanın kopyası üzerinde çalışır; bekleyen düzenlemeler
    // önce kaydedilmezse sessizce kaybolurdu.
    if (!await _confirmLeavePending() || !mounted) return;
    final saved = await PdfEditorScreen.open(
      context,
      path: widget.doc.path,
      initialPage: _livePdfPage() ?? _pdfPage,
    );
    if (saved && mounted) {
      _partSetState(() => _pdfText = '');
      await _reloadPdf();
    }
  }

  /// Seçim sürüklemesinin ekran konumu değişti (null = bitti). Kenara
  /// yaklaşınca 60 Hz'lik zamanlayıcı görüntüyü o yöne iter; sürükleme bitince
  /// zamanlayıcı ölür. Zamanlayıcı işaretçi olaylarından AYRI koşar ki parmak
  /// kenarda hiç kımıldamadan dursa da akış sürsün.
  void _onPdfSelDragAt(Offset? global) {
    _pdfSelDragPos = global;
    if (global == null) {
      _pdfEdgeScrollTimer?.cancel();
      _pdfEdgeScrollTimer = null;
      return;
    }
    _pdfEdgeScrollTimer ??=
        Timer.periodic(const Duration(milliseconds: 16), (_) {
      final pos = _pdfSelDragPos;
      if (pos == null || !mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final delta = edgeAutoScrollDelta(box.globalToLocal(pos), box.size);
      if (delta == Offset.zero) return;
      try {
        // Görüntü matrisi işaretçinin TERS yönüne itilir (alt kenar →
        // içerik yukarı). Ayarlayıcı güvenli aralığa kıstırır.
        _pdfController.value = _pdfController.value.clone()
          ..leftTranslate(-delta.dx, -delta.dy);
      } catch (_) {
        // Görüntüleyici henüz hazır değilse (yarış) itme sessizce atlanır.
      }
    });
  }

  /// Seçim çubuğu — tasarımı ve taşma güvencesi [PdfSelectionBar]'da.
  Widget _selectionBar() {
    final marking = _lastMark != null && _pendingMarks.contains(_lastMark);
    return PdfSelectionBar(
      preview: _ViewerScreenState._shorten(_pdfSelection, 34),
      colors: _highlightColors,
      selectedColor: _highlightColor,
      marking: marking,
      onHighlight: _highlightPdf,
      onPickColor: _recolorLastMark,
      onUndoHighlight: _undoLastMark,
      onDone: _clearPdfSelection,
      onCopy: _copyPdfSelection,
      // Yerinde düzenleme: yalnız bu satırlar değişir, sayfa düzeni korunur
      // (tam belge AI düzenlemesinden farkı bu). OCR seçiminde PDF
      // düzenleyicisine gider — orada OCR satırının üstüne yazılır
      // (2026-08-06: "taranmış belge deyip düzenleme yaptırmıyor").
      onEdit: _pdfSelFromOcr ? _openPdfEditor : _startInlineEdit,
      onTranslate: _translateSelection,
      moreItems: [
        PdfBarMenuItem(
          icon: Icons.format_color_reset_rounded,
          label: context.t('vw.highlight_remove'),
          onTap: _removeHighlight,
        ),
        PdfBarMenuItem(
          icon: Icons.auto_awesome_rounded,
          label: context.t('vw.ask_ai_selection'),
          onTap: _askAiAboutSelection,
        ),
        PdfBarMenuItem(
          icon: Icons.search_rounded,
          label: context.t('vw.find_selection'),
          onTap: _findSelection,
        ),
        PdfBarMenuItem(
          icon: Icons.share_rounded,
          label: context.t('common.share'),
          onTap: () {
            final text = cleanPdfCopyText(_pdfSelection);
            if (text.isNotEmpty) Share.share(text);
          },
        ),
      ],
      highlightLabel: context.t('vw.highlight_hint'),
      copyLabel: context.t('common.copy'),
      editLabel: context.t('common.edit'),
      translateLabel: context.t('common.translate'),
      markedLabel: context.t('vw.highlighted'),
      undoLabel: context.t('common.undo'),
      doneLabel: context.t('common.done'),
      colorTooltip: context.t('vw.highlight_color'),
      moreTooltip: context.t('common.more'),
      onClose: _clearPdfSelection,
      closeTooltip: context.t('common.close'),
    );
  }

  /// Yerinde düzenleme çubuğu — bkz. [PdfEditBar] (niye ekranın altında
  /// olduğu da orada yazılı).
  Widget _editBar() => PdfEditBar(
        busy: _pdfEditBusy,
        onCancel: _cancelInlineEdit,
        onRewrite: _rewriteInlineEdit,
        onApply: _submitInlineEdit,
        onCaretLeft: () => _moveCaret(-1),
        onCaretRight: () => _moveCaret(1),
        onSelectAll: _selectAllInlineEdit,
        cancelLabel: context.t('common.cancel'),
        aiLabel: context.t('vw.ai_fix'),
        applyLabel: context.t('common.apply'),
        caretLeftLabel: context.t('vw.caret_left'),
        caretRightLabel: context.t('vw.caret_right'),
        selectAllLabel: context.t('vw.select_all_text'),
        title: context.t('vw.inline_edit_title'),
      );

  /// İmleci [delta] karakter kaydırır (çubuktaki ◀ ▶).
  ///
  /// Seçim varsa önce **daraltılır**: kullanıcı bir kelimeyi seçmişken sağ oka
  /// bastığında beklenen şey seçimin ucuna gitmek, seçimin silinmesi değil —
  /// masaüstü klavye davranışının aynısı.
  void _moveCaret(int delta) {
    final ctl = _pdfEditCtl;
    if (ctl == null) return;
    final selection = ctl.selection;
    final length = ctl.text.length;
    final int from;
    if (!selection.isValid) {
      from = delta < 0 ? 0 : length;
    } else if (!selection.isCollapsed) {
      from = delta < 0 ? selection.start : selection.end;
      ctl.selection = TextSelection.collapsed(offset: from);
      _focusInlineEdit();
      return;
    } else {
      from = selection.baseOffset;
    }
    ctl.selection =
        TextSelection.collapsed(offset: (from + delta).clamp(0, length));
    _focusInlineEdit();
  }

  /// Kutudaki metnin tamamını seçer — "hepsini silip baştan yaz" en sık
  /// yapılan düzeltme ve minik yazıda üç kez dokunmak zor.
  void _selectAllInlineEdit() {
    final ctl = _pdfEditCtl;
    if (ctl == null) return;
    ctl.selection = TextSelection(baseOffset: 0, extentOffset: ctl.text.length);
    _focusInlineEdit();
  }

  Future<void> _copyPdfSelection() async {
    // Ham seçim değil TEMİZ metin kopyalanır (2026-08-06 kullanıcı bulgusu):
    // pdfium'un satır sonları ve görünmez karakterleri panoya taşınmasın,
    // satırlara bölünmüş "Fizik / Muayene" tek satır "Fizik Muayene" olsun.
    final text = cleanPdfCopyText(_pdfSelection);
    if (text.isEmpty) return;
    final copied = context.t('vw.copied_chars', {'n': text.length});
    await Clipboard.setData(ClipboardData(text: text));
    _snack(copied);
  }

  /// Seçime değen vurguları siler (kullanıcı 2026-08-29: *"vurgu kaldır vb
  /// işlemler yok"*). Seçim vurgunun bir parçasına denk gelse yeter.
  ///
  /// Önce EKRANDA bekleyen vurgulara bakılır (anında, dosyaya dokunmadan);
  /// seçim onlardan birine değmiyorsa dosyadaki vurgular izolatta silinir.
  Future<void> _removeHighlight() async {
    final rects = _pdfSelRects;
    final page = _pdfSelPage;
    if (rects.isEmpty || page < 1) return;
    final hits = _pendingMarks
        .where((m) => m.page == page && m.touches(rects))
        .toList();
    if (hits.isNotEmpty) {
      _partSetState(() {
        _pendingMarks.removeWhere(hits.contains);
        if (hits.contains(_lastMark)) _lastMark = null;
        _pdfSelection = '';
        _pdfSelRects = const [];
      });
      _snack(context.t('vw.highlight_removed', {'n': hits.length}));
      return;
    }
    if (_pdfWriting > 0 || !await _flushPendingMarks()) return;
    try {
      final bytes = await _fileService.readBytes(widget.doc.path);
      final (out, removed) = await PdfAnnotator.removeHighlightsInBackground(
        bytes: bytes,
        pageIndex: page - 1,
        rects: [for (final r in rects) [r.left, r.top, r.right, r.bottom]],
      );
      if (!mounted) return;
      if (removed == 0) {
        // Seçim kalsın: kullanıcı biraz kaydırıp yeniden deneyebilsin.
        _snack(context.t('vw.highlight_none_here'));
        return;
      }
      _partSetState(() {
        _pdfSelection = '';
        _pdfSelRects = const [];
      });
      await _writePending(out);
      if (mounted) {
        _snack(context.t('vw.highlight_removed', {'n': removed}));
      }
    } catch (e) {
      if (mounted) _snack(context.t('vw.highlight_failed', {'error': userErrorText(e)}));
    }
  }

  /// PDF araçları ekranı; kaydedilerek dönülürse dosya değişmiştir → pdfrx
  /// aynı yolu "eşit" saydığı için remount ile yeniden okutulur.
  Future<void> _openPdfTools() async {
    // Bu araçlar ÖZGÜN dosya üzerinde çalışır; bekleyen düzenlemeler önce
    // kaydedilmezse sessizce kaybolurdu.
    if (!await _confirmLeavePending() || !mounted) return;
    final saved = await PdfToolsScreen.open(context, path: widget.doc.path);
    if (saved == true && mounted) {
      _partSetState(() => _pdfText = '');
      await _reloadPdf();
    }
  }

  /// Dosya diskte değiştikten sonra görüntüyü tazeler.
  ///
  /// Eskiden `ValueKey` artırılıp widget yeniden bağlanıyordu; pdfrx belgeleri
  /// statik bir haritada dosya YOLUNA göre önbelleklediği için bu İŞE YARAMIYOR
  /// ve vurgu/imza ekranda hiç görünmüyordu (bkz. [PdfReload]). Şimdi belge
  /// gerçekten yeniden okunuyor ve kullanıcı aynı sayfada kalıyor.
  Future<void> _reloadPdf() async {
    // Eski PdfDocument yeniden yükleme sırasında dispose edilir; elimizdeki
    // referansı hemen bırakıyoruz ki OCR/içindekiler ölü belgeye dokunmasın.
    // Yenisi `onViewerReady` ile geri gelir.
    _pdfDoc = null;
    _pdfSearcher?.resetTextSearch(); // eşleşmeler eski belgeye aitti
    _ocrSearch?.reset();
    _findEntry = null;
    await PdfReload.reloadFile(widget.doc.path);
    if (mounted) _partSetState(() {});
  }

  /// Belgeyi AI'a düzenletir (metin katmanı üzerinden). Üzerine yazıldıysa
  /// görüntü tazelenir.
  Future<void> _aiEditPdf() async {
    if (!await _confirmLeavePending() || !mounted) return;
    await _ensurePdfText();
    if (!mounted) return;
    final overwritten = await PdfAiEditScreen.open(
      context,
      path: widget.doc.path,
      fileName: widget.doc.name,
      sourceText: _documentText,
    );
    if (overwritten == true && mounted) {
      _partSetState(() => _pdfText = '');
      await _reloadPdf();
    }
  }

  /// PDF içindeki bağlantıya dokunulunca. Dış adresler ONAY İSTER: belgedeki
  /// bağlantı metni gerçek hedefi gizleyebilir, kullanıcı tam URL'yi görmeli.
  Future<void> _onPdfLink(PdfLink link) async {
    final linkFailed = context.t('vw.link_failed');
    final linkFailedE = context.t('vw.link_failed_e');
    final dest = link.dest;
    if (dest != null) {
      _pdfJumpTarget = dest.pageNumber;
      await _pdfController.goToDest(dest);
      return;
    }
    final url = link.url;
    if (url == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('vw.link_title')),
        content: Text(context.t('vw.link_body', {'url': url})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.t('common.open'))),
        ],
      ),
    );
    if (go != true) return;
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) _snack(linkFailed);
    } catch (e) {
      _snack(linkFailedE.replaceAll('{error}', userErrorText(e)));
    }
  }

  /// Belge ana hattı (içindekiler). PDF'te yoksa kullanıcıya söylenir.
  Future<void> _showOutline() async {
    final doc = _pdfDoc;
    if (doc == null) return;
    final outline = await doc.loadOutline();
    if (!mounted) return;
    if (outline.isEmpty) {
      _snack(context.t('vw.no_toc'));
      return;
    }
    // ponytail: ağaç yerine girintili düz liste — açılır/kapanır düğüm yönetimi
    // olmadan aynı işi görür; şikayet gelirse ExpansionTile'a geçilir.
    final flat = <(PdfOutlineNode, int)>[];
    void walk(List<PdfOutlineNode> nodes, int depth) {
      for (final n in nodes) {
        flat.add((n, depth));
        walk(n.children, depth + 1);
      }
    }

    walk(outline, 0);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scroll) => ListView.builder(
          controller: scroll,
          itemCount: flat.length,
          itemBuilder: (ctx, i) {
            final (node, depth) = flat[i];
            return ListTile(
              dense: true,
              contentPadding:
                  EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
              title: Text(node.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: node.dest == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _pdfJumpTarget = node.dest!.pageNumber;
                      _pdfController.goToDest(node.dest);
                    },
            );
          },
        ),
      ),
    );
  }

  /// Sesli okumayı başlatır/duraklatır. Metin belgenin kendi metnidir; taranmış
  /// PDF'te önce "Metni tanı (OCR)" gerekir (metin katmanı yoksa okunacak şey
  /// yok — kullanıcıya söylenir).
  Future<void> _toggleSpeech() async {
    final tts = _tts;
    if (tts != null && _ttsPlaying) {
      await tts.pause();
      return;
    }
    if (tts != null && _ttsTotal > 0) {
      await tts.resume();
      return;
    }
    await _ensurePdfText();
    if (!mounted) return;
    final text = _documentText;
    if (text.trim().isEmpty) {
      _snack(_isPdf ? context.t('vw.no_readable_text') : context.t('uix.no_text'));
      return;
    }
    final service = TtsService(prefs: context.read<AppState>().ttsPrefs)
      ..onProgress = (i, total, playing) {
        if (!mounted) return;
        _partSetState(() {
          _ttsIndex = i;
          _ttsTotal = total;
          _ttsPlaying = playing;
        });
      };
    _partSetState(() => _tts = service);
    await service.start(text);
  }

  Future<void> _stopSpeech() async {
    await _tts?.stop();
    if (mounted) _partSetState(() => _ttsTotal = 0);
  }

  /// Sesli okuma çubuğu — okuma sürerken belgenin altında durur.
  Widget _speechBar() {
    // Mini oynatıcı kartı (2026-09-23 tasarım turu): düz renkli bir şerit
    // yerine belgenin üstünde yüzen yuvarlak kart + ilerleme çizgisi — kaçıncı
    // parçada olunduğu sayı okumadan da görülür.
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress =
        _ttsTotal == 0 ? 0.0 : ((_ttsIndex + 1) / _ttsTotal).clamp(0.0, 1.0);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Material(
          color: scheme.surfaceContainerHigh,
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
                child: Row(
                  children: [
                    IconButton.filled(
                      tooltip: context
                          .t(_ttsPlaying ? 'common.pause' : 'common.resume'),
                      icon: Icon(_ttsPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: _toggleSpeech,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.t('vw.speak'),
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            context.t('vw.speak_part',
                                {'n': _ttsIndex + 1, 'total': _ttsTotal}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('tts.voice_settings'),
                      icon: const Icon(Icons.tune),
                      onPressed: () async {
                        await TtsVoiceSheet.show(context);
                        // Okuma sürerken ses değiştirilebilsin: yeni tercih
                        // sonraki parçadan itibaren geçerli olur.
                        if (mounted) {
                          _tts?.prefs = context.read<AppState>().ttsPrefs;
                        }
                      },
                    ),
                    IconButton(
                      tooltip: context.t('common.stop'),
                      icon: const Icon(Icons.stop_rounded),
                      onPressed: _stopSpeech,
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Form doldurma ekranı — belgenin kendi alanları düzenlenir.
  ///
  /// Menüde HER PDF'te duruyor: alan olup olmadığı ancak belge çözümlenince
  /// bilinir ve her açılışta bunu yapmak büyük dosyalarda saniyeler alırdı.
  /// Alan yoksa ekran bunu söyleyip ne yapılabileceğini yazıyor.
  Future<void> _fillPdfForm() async {
    if (!await _confirmLeavePending() || !mounted) return;
    final filled = await PdfFormScreen.open(context, widget.doc.path);
    if (filled == true && mounted) await _reloadPdf();
  }

  /// İmza ekranı; imza basılırsa dosya değişmiştir → görüntüleyici tazelenir.
  Future<void> _signPdf() async {
    if (!await _confirmLeavePending() || !mounted) return;
    final signed = await PdfSignScreen.open(context, widget.doc.path);
    if (signed == true && mounted) await _reloadPdf();
  }
}
