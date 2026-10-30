part of '../pdf_editor_screen.dart';

extension _PdfEditorScreenViewsPart on _PdfEditorScreenState {
  Widget _body() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _hintBar(),
        Expanded(
          child: Stack(
            children: [
              PdfViewer.file(
                _workPath!,
                controller: _controller,
                params: PdfViewerParams(
                  // Görüntüleyiciyle aynı fırlatma (bkz. [kPdfPanFriction]).
                  interactionEndFrictionCoefficient:
                      _pinch ? kPdfPinchFriction : kPdfPanFriction,
                  onInteractionStart: (_) {
                    if (_pinch) _partSetState(() => _pinch = false);
                  },
                  onInteractionUpdate: (d) {
                    if (d.pointerCount >= 2 && !_pinch) {
                      _partSetState(() => _pinch = true);
                    }
                  },
                  onPageChanged: (page) {
                    if (page == null || page == _page) return;
                    _partSetState(() => _page = page);
                    _loadOutline();
                  },
                  onViewerReady: (doc, _) {
                    if (mounted) {
                      _partSetState(() => _pageCount = doc.pages.length);
                    }
                  },
                  pageOverlaysBuilder: (context, pageRect, page) => [
                    if (page.pageNumber == _page)
                      Builder(builder: (_) {
                        // Katman ölçeği: düzenleme eylemleri (yakınlaşma,
                        // yeni nesnenin yeri) bunu okur; build'de yalnız
                        // alan güncellenir, setState yok.
                        _pageScale = pageRect.width / page.width;
                        _pageViewSize = Size(page.width, page.height);
                        return const SizedBox.shrink();
                      }),
                    if (page.pageNumber == _page &&
                        _inlineIndex == null &&
                        (_mode == _EditMode.text || _mode == _EditMode.image))
                      PdfEditOverlay(
                        page: page,
                        pageSize: pageRect.size,
                        outline: _outline,
                        textMode: _mode == _EditMode.text,
                        selectedObject: _selectedObject,
                        onParagraphTap: _editParagraph,
                        onObjectTap: (i) => _partSetState(() =>
                            _selectedObject = _selectedObject == i ? null : i),
                        onObjectChanged: _moveObject,
                      ),
                    // Taranmış sayfa: OCR satır kutuları da düzenlenebilir
                    // (2026-08-06 — "taranmış belge deyip düzenleme
                    // yaptırmıyor"). Kutu listesi bu sayfa+sürüm için
                    // yüklenmemişse boş çizilir, yükleme arkada tetiklenir.
                    //
                    // **2026-08-07 — daha müsade:** artık yalnız "taranmış"
                    // sınıfı yeterli değil. Metin katmanı olan ama İÇİNDE
                    // taranmış blok taşıyan sayfalar (üstte gerçek başlık,
                    // altta fotokopi tablo) da OCR kutusu alır — sayfada
                    // görsel varsa tanıma çalıştırılır. Paragrafla örtüşen
                    // satırlar zaten eleniyor (`_withoutParagraphOverlaps`),
                    // yani gerçek metnin üstüne ikinci kutu binmez.
                    if (page.pageNumber == _page &&
                        _mode == _EditMode.text &&
                        _inlineIndex == null &&
                        _ocrEditable &&
                        PdfOcrText.isSupported)
                      Builder(builder: (context) {
                        _maybeLoadScanned(page);
                        final fresh =
                            _scannedKey == '$_docRev#${page.pageNumber}';
                        return PdfScannedOverlay(
                          page: page,
                          pageSize: pageRect.size,
                          lines: fresh ? _scannedLines : const [],
                          onLineTap: _editScannedLine,
                        );
                      }),
                    // "Sayfaya yazı ekle" (Faz 8, K12 yedeği): yerleştirme
                    // kipinde sayfanın tamamı tek dokunuş alanıdır; en ÜSTTE
                    // durur ki paragraf/OCR kutuları dokunuşu yutmasın.
                    // Form alanları sayfanın üstünde (Faz 31 / PD5).
                    if (_mode == _EditMode.form)
                      ..._formLayer(page, pageRect.size),
                    // Paragrafın kendi kutusunda düzenleme (Faz 31 / PD1).
                    if (page.pageNumber == _page && _inlineIndex != null)
                      ..._inlineLayer(page, pageRect.size),
                    // Kaydedilene kadar nesne olan yazı/imza/görseller.
                    ..._pendingLayer(page, pageRect.size),
                    if (page.pageNumber == _page &&
                        _mode == _EditMode.text &&
                        _placingText)
                      SizedBox.expand(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => _placePendingText(
                              page, pageRect.size, d.localPosition),
                          child: ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_mode == _EditMode.image && _selectedObject != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _objectToolbar(),
                ),
              // Seçili bekleyen nesnenin bağlam çubuğu (yazı: düzenle, punto,
              // kalın, renk; hepsi: sil).
              if (_selectedPending != null &&
                  _editingPending == null &&
                  _layer.byId(_selectedPending) != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _pendingToolbar(),
                ),
            ],
          ),
        ),
        if (_mode == _EditMode.background)
          SizedBox(height: 240, child: _backgroundPanel()),
      ],
    );
  }

  /// Kullanıcı ne yapacağını bilsin: her modda tek cümlelik yönerge.
  Widget _hintBar() {
    final failure = _outlineError;
    // Çözümleme reddedildiyse "burada bir şey yok" DEMEK yanlış olur: sebebi
    // yazıyoruz (2026-09-04).
    final text = _placingText && _mode == _EditMode.text
        ? context.t('pe.hint_place_text')
        : failure != null &&
                (_mode == _EditMode.text || _mode == _EditMode.image)
            ? context.t('pe.hint_failed', {'error': failure})
            : context.t(switch (_mode) {
                _EditMode.text => _outline.paragraphs.isEmpty
                    ? (_scannedPages.contains(_page) && PdfOcrText.isSupported
                        ? 'pe.hint_text_scanned'
                        : 'pe.hint_text_none')
                    : 'pe.hint_text',
                _EditMode.image => switch (_outline.objects) {
                    [] => 'pe.hint_image_none',
                    // Görselin hepsi kilitliyse "dokunup seçin" demek boşuna bir
                    // davet olurdu.
                    final list when list.every((o) => !o.editable) =>
                      'pe.hint_image_locked',
                    _ => 'pe.hint_image',
                  },
                _EditMode.sign => 'pe.hint_sign',
                _EditMode.form => _formFields == null
                    ? 'pe.hint_form_loading'
                    : _formFields!.isEmpty
                        ? 'pe.hint_form_none'
                        : 'pe.hint_form',
                _EditMode.background => 'pe.hint_background',
                _EditMode.page => 'pe.hint_page',
              });
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(AppIcons.info, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: context.type.compact)),
          if (_pageCount > 0)
            Text('$_page / $_pageCount',
                style:
                    context.type.compact.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Seçili görselin araç çubuğu.
  ///
  /// **İki satır** (kullanıcı 2026-08-30 — *"döndür seçenekleri olmalı, ayna
  /// görüntüsü seçeneği olmalı"*): üstte biçim işleri (sola/sağa döndür,
  /// yatay/dikey ayna) simge düğmeleriyle, altta sil/seçimi bırak. Dört
  /// yeni eylemi eski tek satıra eklemek 320 dp'lik bir ekranda etiketleri
  /// üst üste bindirirdi; simgeler ipuçlarıyla (tooltip) adlandırıldı.
  Widget _objectToolbar() {
    final index = _selectedObject!;
    // Kilitli görselde (paylaşılan çizim bloğu / satır içi görsel) döndürme
    // ve silme düğmeleri çalışmıyordu; basınca reddeden bir mesaj çıkıyordu.
    // Artık hiç GÖSTERİLMİYOR — çalışmayan düğme, olmayan düğmeden kötüdür.
    final locked = index >= 0 &&
        index < _outline.objects.length &&
        !_outline.objects[index].editable;
    if (locked) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.lock, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.t('pe.object_locked'),
                    style: context.type.compact),
              ),
              TextButton(
                onPressed: () => _partSetState(() => _selectedObject = null),
                child: Text(context.t('pe.clear_selection')),
              ),
            ],
          ),
        ),
      );
    }
    Widget turn(IconData icon, String key,
            {int turns = 0, bool h = false, bool v = false}) =>
        IconButton(
          tooltip: context.t(key),
          onPressed: _busy
              ? null
              : () =>
                  _turnObject(index, quarterTurns: turns, flipH: h, flipV: v),
          icon: Icon(icon),
          visualDensity: VisualDensity.compact,
        );
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                turn(AppIcons.rotate90DegreesCcw, 'pe.rot_left', turns: -1),
                turn(AppIcons.rotate, 'pe.rot_right', turns: 1),
                turn(AppIcons.selectInvert, 'pe.mirror_h', h: true),
                turn(AppIcons.flipCameraAndroid, 'pe.mirror_v',
                    v: true),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : () => _deleteObject(index),
                  icon: const Icon(AppIcons.delete),
                  label: Text(context.t('common.delete')),
                ),
                TextButton.icon(
                  onPressed: () => _partSetState(() => _selectedObject = null),
                  icon: const Icon(AppIcons.close),
                  label: Text(context.t('pe.clear_selection')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _backgroundPanel() {
    if (_busy && _background.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_background.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Text(context.t('pe.no_background'), textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _background.length,
            itemBuilder: (_, i) {
              final item = _background[i];
              return CheckboxListTile(
                dense: true,
                value: _backgroundPicked.contains(item.index),
                onChanged: (on) => _partSetState(() {
                  if (on == true) {
                    _backgroundPicked.add(item.index);
                  } else {
                    _backgroundPicked.remove(item.index);
                  }
                }),
                secondary:
                    Icon(item.isImage ? AppIcons.image : AppIcons.title),
                title: Text(item.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(item.detail),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _removeBackground,
              icon: const Icon(AppIcons.layersClear),
              label: Text(context
                  .t('pe.remove_picked', {'n': _backgroundPicked.length})),
            ),
          ),
        ),
      ],
    );
  }

  /// Paragraf düzenleme penceresi.
  ///
  /// Özgün metin ÜSTTE, soluk ve salt okunur duruyor — kullanıcı neyi
  /// değiştirdiğini gözden kaçırmasın (isteğin birebir karşılığı: *"orjinal
  /// arka planda duruyor"*).
  /// Paragraf düzenleme penceresi: metin **ve** punto.
  ///
  /// [pointSize] paragrafın ölçülmüş görünen puntosudur; verilirse kullanıcı
  /// onu da değiştirebilir (kullanıcı isteği 2026-09-01: *"yazı puntosu
  /// tutmadı… ufacık yazdı"*). Verilmezse (taranmış sayfa satırı) yalnız
  /// metin sorulur ve dönen `size` null olur.
  ///
  /// [original] boşsa (sayfaya YENİ yazı — Faz 8 yedeği) "şu anki metin"
  /// kutusu çizilmez ve başlık [titleKey] olur.
  Future<({String text, double? size})?> _askParagraphText(
    String original, {
    double? pointSize,
    String titleKey = 'pe.edit_paragraph',
  }) {
    final controller = TextEditingController(text: original);
    // Punto kutusu: ölçülen değer bir tık yuvarlanır (9.9998 → 10).
    final rounded =
        pointSize == null ? null : (pointSize * 10).roundToDouble() / 10;
    final sizeController = TextEditingController(
        text: rounded == null ? '' : _PdfEditorScreenState._trimZero(rounded));
    return showDialog<({String text, double? size})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t(titleKey)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (original.isNotEmpty) ...[
                Text(ctx.t('pe.current_text'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(original,
                      style: context.type.small.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      )),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 8,
                minLines: 3,
                decoration: InputDecoration(
                  labelText: ctx.t('pe.new_text'),
                  helperText: ctx.t('pe.new_text_help'),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (rounded != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sizeController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: ctx.t('pe.font_size'),
                          helperText: ctx.t('pe.font_size_help'),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: ctx.t('pe.font_smaller'),
                      icon: const Icon(AppIcons.textDecrease),
                      onPressed: () => _nudgeSize(sizeController, -0.5),
                    ),
                    IconButton(
                      tooltip: ctx.t('pe.font_bigger'),
                      icon: const Icon(AppIcons.textIncrease),
                      onPressed: () => _nudgeSize(sizeController, 0.5),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (
              text: controller.text,
              size: rounded == null
                  ? null
                  : double.tryParse(sizeController.text.replaceAll(',', '.')),
            )),
            child: Text(ctx.t('common.apply')),
          ),
        ],
      ),
    ).whenComplete(() {
      controller.dispose();
      sizeController.dispose();
    });
  }

  /// Punto kutusunu [delta] kadar oynatır (± düğmeleri).
  void _nudgeSize(TextEditingController c, double delta) {
    final current = double.tryParse(c.text.replaceAll(',', '.')) ?? 10;
    final next = (current + delta).clamp(2.0, 200.0);
    c.text = _PdfEditorScreenState._trimZero((next * 10).roundToDouble() / 10);
  }

  Future<bool?> _confirm(String title, String message) => showAppConfirm(
      context,
      title: title,
      message: message,
      destructive: true,
  );

  void _snack(String message) {
    if (!mounted) return;
    showSnack(context, message);
  }

  /// Uzun açıklamalar (reddetme gerekçeleri) kaybolmadan okunabilsin.
  void _longSnack(String message) {
    if (!mounted) return;
    showSnackBarReplacing(
        ScaffoldMessenger.of(context),
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
        ));
  }
}
