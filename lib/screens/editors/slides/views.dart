part of '../slides_editor_screen.dart';

extension _SlidesEditorScreenViewsPart on _SlidesEditorScreenState {
  /// "Slayt 3 / 12" rozeti — dokununca [_showGoToSlide].
  Widget _slideBadge(int total) {
    return DocPill(
      tapKey: SlidesEditorScreen.badgeKey,
      text: context.t('sl.slide_of', {'n': _currentSlide, 'total': total}),
      icon: Icons.unfold_more,
      onTap: _showGoToSlide,
    );
  }

  /// Arama çubuğu — Excel'in "Bul"uyla aynı kurgu: yaz, ‹ › ile eşleşmeler
  /// arasında gez, sayaç kaçıncı eşleşmede olduğunu söyler.
  Widget _findBar() {
    final scheme = Theme.of(context).colorScheme;
    final hit = _hitIndex >= 0 && _hitIndex < _hits.length ? _hits[_hitIndex] : null;
    return Material(
      color: scheme.surface,
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DocFindBar(
            controller: _findCtrl,
            hint: context.t('sl.search_hint'),
            countLabel: _findCtrl.text.trim().isEmpty
                ? ''
                : _hits.isEmpty
                    ? context.t('sl.no_match')
                    : context.t('sl.match_pos', {
                        'n': _hitIndex + 1,
                        'total': '${_hits.length}${_hitLimit ? '+' : ''}',
                      }),
            onChanged: _runSearch,
            onSubmitted: (_) => _stepHit(1),
            onPrev: _hits.isEmpty ? null : () => _stepHit(-1),
            onNext: _hits.isEmpty ? null : () => _stepHit(1),
            onClose: _toggleFind,
          ),
          // Eşleşmenin BAĞLAMI: slaytın üstünde vurgulama yapamıyoruz
          // (kanvas biçimli metin çiziyor), o yüzden bulunan yer buradan
          // okunur — yoksa "3/12" sayacı hangi metni bulduğunu söylemezdi.
          if (hit != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.t('sl.slide_of', {
                        'n': hit.section + 1,
                        'total': _slideCount,
                      }),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hit.snippet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlides(PptxEditor editor) {
    if (editor.slides.isEmpty) {
      return Center(child: Text(context.t('sl.none')));
    }
    return LayoutBuilder(builder: (context, box) {
      return PinchZoomArea(
        minZoom: 0.5,
        maxZoom: 3,
        onCommitted: _fixScroll,
        builder: (context, zoom, physics) {
          _zoom = zoom;
          // Kart genişliği ve boşluklar zoom ile DOĞRUSAL ölçeklenir. PinchZoomArea
          // canlı önizlemeyi tek tip (odaktan) GPU dönüşümüyle büyütür; yerleşim de
          // doğrusal olursa parmak kalkınca commit edilen düzen canlı önizlemeyle
          // birebir örtüşür ve "slaytlar zıplıyor" hissi kalkar (bkz. HAFIZA).
          final baseW = math.max(120.0, box.maxWidth - 32);
          // "Slayta git" ve konum rozeti kart yüksekliklerini bu genişlikten
          // hesaplıyor (bkz. _slideExtent) — build dışında da lazım.
          _baseW = baseW;
          final cardW = baseW * _zoom;
          final totalW = math.max(box.maxWidth, cardW + 32 * _zoom);
          return SingleChildScrollView(
            controller: _hCtrl,
            physics: physics,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalW,
              // Kenar boşlukları da zoom ile ölçeklenir — tüm dikey/yatay
              // yerleşim doğrusal kalır (bkz. yukarıdaki doğrusallık notu).
              child: ListView.builder(
                controller: _vCtrl,
                physics: physics,
                padding: EdgeInsets.fromLTRB(16 * _zoom, 8 * _zoom, 16 * _zoom,
                    MediaQuery.paddingOf(context).bottom + 88),
                itemCount: editor.slides.length,
                itemBuilder: (context, i) => Center(
                  child: SizedBox(
                    width: cardW,
                    child: _slideCard(editor.slides[i], i, baseW),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _slideCard(PptxSlide slide, int i, double baseW) {
    final scheme = Theme.of(context).colorScheme;
    final view = slide.view;
    return Padding(
      // Slaytlar arası boşluk da zoom ile ölçeklenir → dikey yerleşim doğrusal
      // kalır, commit'te zıplama olmaz (bkz. _buildSlides).
      padding: EdgeInsets.only(bottom: 20 * _zoom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık şeridi ("Slayt N" + düğmeler) zoom ile birlikte ölçeklenir:
          // sabit yükseklikte kalsaydı yerleşim doğrusal olmaz, pinch bırakılınca
          // slaytlar zıplardı (kalan zoom sorununun kök nedeni). FittedBox,
          // doğal (zoom=1) yerleşimi kurup bütün şeridi oranla büyütür/küçültür.
          SizedBox(
            height: 40 * _zoom,
            child: FittedBox(
              fit: BoxFit.fitHeight,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: baseW,
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Row(
                    children: [
                      // Toplam da yazılır (2026-08-01 kullanıcı isteği):
                      // tek slayda bakarken destenin kaç slayt olduğu
                      // görünmüyordu.
                      Text(
                        context.t('sl.slide_of', {
                          'n': slide.index,
                          'total': _editor?.slides.length ?? 0,
                        }),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: context.t('sl.fullscreen'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.fullscreen, size: 20),
                        onPressed: () => _play(i),
                      ),
                      _slideMenu(slide),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Zoom liste seviyesindeki PinchZoomArea'dan gelir (kart içinde ayrı
          // InteractiveViewer YOK — ikisi birden çift zoom yapardı).
          AspectRatio(
            aspectRatio: view == null ? 16 / 9 : view.widthPt / view.heightPt,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: view == null
                  ? _fallbackText(slide)
                  : SlideCanvas(
                      slide: view,
                      onEditShape: (shape) => _beginEdit(slide, shape),
                      editingShape:
                          identical(_editSlide, slide) ? _editShapeVM : null,
                      editControllers:
                          identical(_editSlide, slide) ? _editCtrls : null,
                    ),
            ),
          ),
          _notesStrip(slide, baseW),
        ],
      ),
    );
  }

  /// Konuşmacı notu şeridi — kanvasın hemen altında, kağıt teması devir
  /// notundaki yerinde. Notu olmayan slaytta hiç yer kaplamaz.
  ///
  /// Şerit de kanvasla aynı zoom oranında ölçeklenir; sabit yükseklikte
  /// kalsaydı dikey yerleşim doğrusallığını bozup pinch bırakılınca slaytları
  /// zıplatırdı (kart başlığındaki aynı ders).
  Widget _notesStrip(PptxSlide slide, double baseW) {
    final editor = _editor;
    if (editor == null) return const SizedBox.shrink();
    final text = editor.notesOf(slide);
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final expanded = _openNotes.contains(slide.fileName);
    // Kapalıyken tek satır, açıkken en çok altı satır (uzun not kartı
    // ezmesin — devamı kaydırılarak okunur).
    final lines = expanded ? 6 : 1;
    final height = _notesHeight(slide);

    return SizedBox(
      height: height * _zoom,
      child: FittedBox(
        fit: BoxFit.fitHeight,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: baseW,
          height: height,
          child: InkWell(
            onTap: () => _partSetState(() {
              expanded
                  ? _openNotes.remove(slide.fileName)
                  : _openNotes.add(slide.fileName);
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                border: Border(
                  left: BorderSide(color: scheme.outlineVariant, width: 3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: lines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Slayt işlemleri menüsü (çoğalt / sil / yukarı-aşağı taşı).
  Widget _slideMenu(PptxSlide slide) {
    final editor = _editor;
    final structural = editor?.canEditStructure ?? false;
    return PopupMenuButton<String>(
      tooltip: context.t('sl.actions'),
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) => _onSlideAction(slide, v),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'dup',
          enabled: structural,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.copy_all_outlined),
            title: Text(context.t('sl.duplicate')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'up',
          enabled: structural && slide.index > 1,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_upward),
            title: Text(context.t('sl.move_up')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'down',
          enabled:
              structural && slide.index < (editor?.slides.length ?? 0),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_downward),
            title: Text(context.t('sl.move_down')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'del',
          enabled: structural && (editor?.slides.length ?? 0) > 1,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline),
            title: Text(context.t('sl.delete')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _onSlideAction(PptxSlide slide, String action) {
    final editor = _editor;
    if (editor == null) return;
    if (!editor.canEditStructure) {
      _snack(context.t('sl.no_structure'));
      return;
    }
    switch (action) {
      case 'dup':
        final added = editor.duplicateSlide(slide);
        if (added != null) {
          _dirty = true;
          _partSetState(() {});
          _snack(context.t('sl.duplicated'));
        }
        break;
      case 'up':
        if (editor.moveSlide(slide, -1)) {
          _dirty = true;
          _partSetState(() {});
        }
        break;
      case 'down':
        if (editor.moveSlide(slide, 1)) {
          _dirty = true;
          _partSetState(() {});
        }
        break;
      case 'del':
        _confirmDeleteSlide(slide);
        break;
    }
  }

  Future<void> _confirmDeleteSlide(PptxSlide slide) async {
    final editor = _editor;
    if (editor == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('sl.delete')),
        content: Text(ctx.t('sl.delete_body', {'n': slide.index})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('common.delete'))),
        ],
      ),
    );
    if (ok == true && editor.deleteSlide(slide)) {
      _dirty = true;
      if (mounted) _partSetState(() {});
    }
  }

  /// Tam ekran sunum modunu [index]. slayttan başlatır.
  void _play(int index) {
    final views = <SlideVM>[];
    var start = 0;
    for (var i = 0; i < (_editor?.slides.length ?? 0); i++) {
      final v = _editor!.slides[i].view;
      if (v == null) continue;
      if (i <= index) start = views.length;
      views.add(v);
    }
    if (views.isEmpty) {
      _snack(context.t('sl.nothing_to_play'));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SlideshowScreen(slides: views, initialIndex: start),
    ));
  }

  /// Çizim yapılamadıysa (bozuk/desteklenmeyen slayt) düz metin listesi.
  Widget _fallbackText(PptxSlide slide) {
    if (slide.paragraphs.isEmpty) {
      return Center(child: Text(context.t('ss.no_text')));
    }
    return SingleChildScrollView(
      padding: withNavInset(context, const EdgeInsets.all(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final para in slide.paragraphs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: TextFormField(
                initialValue: para.text,
                onChanged: (v) {
                  para.text = v;
                  if (!_dirty) _partSetState(() => _dirty = true);
                },
                maxLines: null,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Bir metin kutusunda **yerinde** düzenlemeyi başlatır: kutunun paragrafları
  /// slaytın üstünde TextField olur (popup yok). Önceki düzenleme varsa yazılır.
  /// Denetleyiciler şeklin paragraf sırasıyla hizalıdır (düzenlenemeyen = null).
  void _beginEdit(PptxSlide slide, ShapeVM shape) {
    _commitEdit(); // açık başka kutu varsa değişikliğini yaz
    _editCtrls.clear();
    _editTargets.clear();
    for (final p in shape.paragraphs) {
      final para = p.source == null ? null : slide.paragraphOf(p.source);
      if (para == null) {
        _editCtrls.add(null);
        _editTargets.add(null);
      } else {
        _editCtrls.add(TextEditingController(text: para.text));
        _editTargets.add(para);
      }
    }
    if (!_editTargets.any((t) => t != null)) return; // düzenlenebilir metin yok

    // Başlangıç biçimi: kutudaki ilk çalıştırmadan okunur.
    RunVM? firstRun;
    for (final p in shape.paragraphs) {
      if (p.runs.isNotEmpty) {
        firstRun = p.runs.first;
        break;
      }
    }
    _fBold = firstRun?.bold ?? false;
    _fItalic = firstRun?.italic ?? false;
    _fUnder = firstRun?.underline ?? false;
    _fSize = (firstRun?.sizePt ?? 18.0).clamp(6.0, 96.0).roundToDouble();
    // Yazı tipi XML'den okunur: çizim modelindeki ad gömülü aileye eşlenmiş
    // olur (Arial → Arimo) ve geri dönülemez.
    final firstTarget = _editTargets.firstWhere((t) => t != null, orElse: () => null);
    _fFont = firstTarget == null
        ? ''
        : (PptxEditor.fontOfParagraph(firstTarget) ?? '');
    _tBold = _tItalic = _tUnder = _tSize = _tFont = false;

    _partSetState(() {
      _editSlide = slide;
      _editShapeVM = shape;
    });
  }

  /// Açık düzenlemeyi kalıcılaştırır (metin + dokunulan biçim), slaytı yeniden
  /// çizer ve durumu temizler. Açık düzenleme yoksa hiçbir şey yapmaz.
  /// Not: setState çağırmaz — çağıran sarar (build sırasında da güvenli kullanılır).
  void _commitEdit() {
    final slide = _editSlide;
    final editor = _editor;
    if (slide == null || editor == null) return;
    for (var i = 0; i < _editTargets.length; i++) {
      final t = _editTargets[i];
      final c = _editCtrls[i];
      if (t != null && c != null) editor.updateParagraph(slide, t, c.text);
    }
    if (_tBold || _tItalic || _tUnder || _tSize || _tFont) {
      for (final t in _editTargets) {
        if (t == null) continue;
        editor.formatParagraph(
          slide,
          t,
          bold: _tBold ? _fBold : null,
          italic: _tItalic ? _fItalic : null,
          underline: _tUnder ? _fUnder : null,
          sizePt: _tSize ? _fSize : null,
          fontFamily: _tFont && _fFont.isNotEmpty ? _fFont : null,
        );
      }
    }
    _dirty = true;
    for (final c in _editCtrls) {
      c?.dispose();
    }
    _editCtrls.clear();
    _editTargets.clear();
    _editSlide = null;
    _editShapeVM = null;
  }

  void _finishEdit() {
    FocusScope.of(context).unfocus();
    _partSetState(_commitEdit);
  }

  /// Yazı tipi ailesi seçimi. Seçilen ad DOSYAYA yazılır (PowerPoint'te
  /// gerçek Arial görünsün), ekranda ise gömülü karşılığıyla çizilir.
  Future<void> _pickSlideFont() async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final f in kDocFonts)
              ListTile(
                title: Text(f.name, style: TextStyle(fontFamily: f.render)),
                trailing: f.name == _fFont ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, f.name),
              ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    _partSetState(() {
      _fFont = pick;
      _tFont = true;
    });
  }

  Future<void> _pickSlideFontSize() async {
    final pick = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in kDocFontSizes)
              ListTile(
                title: Text('${s.round()}'),
                trailing: (s - _fSize).abs() < 0.25
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    _partSetState(() {
      _fSize = pick;
      _tSize = true;
    });
  }

  /// Klavyenin üstünde yüzen biçim çubuğu (yerinde düzenleme aktifken).
  Widget _formatBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 0,
      color: scheme.surface,
      shape: Border(top: BorderSide(color: scheme.outlineVariant)),
      // Scaffold.resizeToAvoidBottomInset (varsayılan) body'yi klavyenin üstüne
      // sıkıştırır → çubuk zaten klavyenin hemen üstünde durur; ek viewInsets
      // payı çift sayardı. SafeArea klavye kapalıyken alt çentiği korur.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        // Simgeler Word/Excel ile ORTAK (`OfficeIcons`, 2026-08-07): aynı iş
        // üç uygulamada da aynı simge.
        child: SafeArea(
          top: false,
          child: OfficeRibbon(
            tabs: [
              RibbonTab('', [
                RibbonButton(OfficeIcons.bold, context.t('common.bold'),
                    active: _fBold,
                    onTap: () => _partSetState(() {
                          _fBold = !_fBold;
                          _tBold = true;
                        })),
                RibbonButton(OfficeIcons.italic, context.t('common.italic'),
                    active: _fItalic,
                    onTap: () => _partSetState(() {
                          _fItalic = !_fItalic;
                          _tItalic = true;
                        })),
                RibbonButton(
                    OfficeIcons.underline, context.t('common.underline'),
                    active: _fUnder,
                    onTap: () => _partSetState(() {
                          _fUnder = !_fUnder;
                          _tUnder = true;
                        })),
                const RibbonSep(),
                // Yazı tipi ailesi (2026-08-07 kullanıcı: *"yazı tipi fontu
                // boyutu seçimi yok"*): Word ve Excel'de vardı, slaytta hiç
                // yoktu. Liste üçünde de aynı (`kDocFonts`).
                RibbonChip(
                  icon: OfficeIcons.fontFamily,
                  label: _fFont.isEmpty
                      ? context.t('word.font_family')
                      : _fFont,
                  tooltip: context.t('word.font_family'),
                  onTap: _pickSlideFont,
                ),
                RibbonButton(
                    OfficeIcons.fontShrink, context.t('vw.text_smaller'),
                    onTap: () => _partSetState(() {
                          _fSize = (_fSize - 2).clamp(6.0, 96.0).toDouble();
                          _tSize = true;
                        })),
                RibbonChip(
                  icon: OfficeIcons.fontSize,
                  label: '${_fSize.round()}',
                  tooltip: context.t('word.font_size'),
                  onTap: _pickSlideFontSize,
                ),
                RibbonButton(OfficeIcons.fontGrow, context.t('vw.text_bigger'),
                    onTap: () => _partSetState(() {
                          _fSize = (_fSize + 2).clamp(6.0, 96.0).toDouble();
                          _tSize = true;
                        })),
                const RibbonSep(),
                // Seçili metni çevir (Faz 9 / Y4 — Word ve PDF'te vardı).
                RibbonButton(Icons.translate, context.t('common.translate'),
                    onTap: _translateEditing),
              ]),
            ],
            trailing: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _finishEdit,
                child: Text(context.t('sl.done')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Düzenlenen kutuda SEÇİLİ metni (seçim yoksa kutunun tamamını) çevirir.
  void _translateEditing() {
    final text = selectedEditText(_editCtrls);
    if (text.trim().isEmpty) return;
    QuickTranslateSheet.show(context, text, title: widget.name);
  }
}

/// Kutunun denetleyicilerinden çevrilecek metin: seçimi olan ilk paragrafın
/// seçimi; hiçbirinde seçim yoksa bütün paragraflar (satır satır).
@visibleForTesting
String selectedEditText(List<TextEditingController?> ctrls) {
  for (final c in ctrls) {
    if (c == null) continue;
    final sel = c.selection;
    if (sel.isValid && !sel.isCollapsed) return sel.textInside(c.text);
  }
  return [
    for (final c in ctrls)
      if (c != null) c.text,
  ].join('\n');
}
