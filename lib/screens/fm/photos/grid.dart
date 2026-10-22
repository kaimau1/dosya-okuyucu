part of '../photos_screen.dart';

extension _PhotosScreenGridPart on _PhotosScreenState {
  /// Boş durum: ne olduğunu ve (süzgeç varsa) nasıl çıkılacağını söyler.
  Widget _emptyState() {
    final theme = Theme.of(context);
    final filtered = _query.trim().isNotEmpty || _filter.isActive;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loadingAll)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(
                filtered
                    ? Icons.filter_alt_off_rounded
                    : Icons.photo_library_rounded,
                size: 56,
                color: muted.withValues(alpha: 0.6),
              ),
            const SizedBox(height: Gap.md),
            Text(
              context.t(_loadingAll
                  ? 'ph.loading'
                  : (filtered ? 'ph.no_match' : 'ph.empty')),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            if (!_loadingAll) ...[
              const SizedBox(height: Gap.xs),
              Text(
                context.t(filtered ? 'ph.no_match_hint' : 'ph.empty_hint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            if (_filter.isActive && !_loadingAll) ...[
              const SizedBox(height: Gap.md),
              FilledButton.tonalIcon(
                onPressed: () => _partSetState(() => _filter =
                    FmFilter(hideDuplicates: _filter.hideDuplicates)),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: Text(context.t('ph.clear_filters')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Planın [i]. satırı: grup başlığı ya da bir sıra hücre. Her satır
  /// yakınlaştırma geçişinin ölçeğini dinler (bkz. [_ZoomRow]).
  Widget _row(PhotoGridPlan plan, int i, List<_Section> sections,
      List<FsEntry> visible, double cell) {
    final segments = plan.rowSegments[i];
    final Widget child;
    if (segments != null &&
        segments.length == 1 &&
        segments.first.span == plan.columns) {
      final section = sections[segments.first.section];
      child = _SectionHeader(
        title: section.title,
        count: section.files.length,
        selecting: _selecting,
        allSelected: section.files.every((e) => _selected.contains(e.path)),
        onToggle: () => _toggleSection(section),
      );
    } else if (segments != null) {
      // Satırı paylaşan gruplar: her etiket KENDİ hücrelerinin tam üstünde
      // (sütun konumu ve genişliği hücrelerle birebir aynı hesaplanır).
      child = Stack(
        children: [
          for (final seg in segments)
            Positioned(
              left: seg.column * (cell + _PhotosScreenState._spacing),
              width: seg.span * cell + (seg.span - 1) * _PhotosScreenState._spacing,
              top: 0,
              bottom: 0,
              child: _PackedLabel(
                // Tek hücrelik yerde kısa etiket ("23 Eyl"); iki ve üstünde
                // tam başlık sığar.
                title: seg.span >= 2
                    ? sections[seg.section].title
                    : sections[seg.section].shortTitle,
                selecting: _selecting,
                allSelected: sections[seg.section]
                    .files
                    .every((e) => _selected.contains(e.path)),
                onToggle: () => _toggleSection(sections[seg.section]),
              ),
            ),
        ],
      );
    } else {
      final first = plan.rowFlatStart[i];
      final count = plan.rowCellCount[i];
      child = Padding(
        padding: const EdgeInsets.only(bottom: _PhotosScreenState._spacing),
        // `Expanded` + `Row.spacing`: genişlik SATIRIN kendisinden bölünür.
        // Hücre genişliğini elle yazmak (cell) kayan nokta artığı yüzünden
        // "RenderFlex overflowed by 0.0001 pixels" riski taşırdı.
        child: Row(
          spacing: _PhotosScreenState._spacing,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < plan.columns; c++)
              Expanded(
                child: SizedBox(
                  height: cell,
                  // Son satır eksik kalabilir: boş yer tutucu, yoksa kalan
                  // hücreler genişleyip ızgara bozulurdu.
                  child: c < count && first + c < visible.length
                      ? _tileAt(visible[first + c], first + c, cell, visible)
                      : null,
                ),
              ),
          ],
        ),
      );
    }
    return _ZoomRow(
      scale: _zoomScale,
      focal: () => _zoomFocal,
      viewportTop: () =>
          _appBarExtent +
          plan.rowOffset[i] -
          (_scroll.hasClients ? _scroll.offset : 0),
      child: child,
    );
  }

  /// Tek hücre.
  Widget _tileAt(FsEntry e, int flatIndex, double cell, List<FsEntry> visible) {
    return DragSelectItem(
      index: flatIndex,
      child: _PhotoTile(
        entry: e,
        size: cell,
        selected: _selected.contains(e.path),
        selecting: _selecting,
        // Yalnız GÖRSELLER galeride büyüyerek açılır (videonun oynatıcısı
        // ayrı bir ekran, orada eşleşen kahraman yok).
        heroTag: e.category == FmCategory.image ? fmMediaHeroTag(e.path) : null,
        // **Tek dokunuş ANINDA** açar (2026-09-26). Eskiden hücrede çift
        // dokunuş dinleyicisi (eylem sayfası) vardı; Flutter tek dokunuşu çift
        // dokunuş süresi (~300 ms) dolana kadar BEKLETİYOR — her fotoğraf
        // açılışı bu yüzden gecikiyordu (aynı tuzak: HAFIZA 2026-09-03 I).
        // Tek dosyanın eylemleri uzun basış → alt çubuktan ve görüntüleyicinin
        // "Diğer işlemler" menüsünden erişilebilir.
        onTap: () {
          if (_selecting) {
            _toggle(e);
          } else {
            _open(e, visible);
          }
        },
      ),
    );
  }

  /// Ekranın üstündeki (başlık kaybolmuşsa durum çubuğunun hemen altındaki)
  /// satırın adı: tarihe göre sıralıysa "Eylül 2025", ada göre ilk harf,
  /// boyuta göre boyut.
  String? _labelFor(double offset) {
    final plan = _plan;
    final sections = _lastSections;
    if (plan == null || plan.rowCount == 0 || sections.isEmpty) return null;
    final visible = _visibleCache ?? const <FsEntry>[];
    final listY = offset + _topPadding + 12 - _appBarExtent;
    final row = plan.rowAt(math.max(0, listY));
    final segs = plan.rowSegments[row];
    final FsEntry e;
    if (segs != null) {
      final s = segs.first.section;
      if (s >= sections.length || sections[s].files.isEmpty) return null;
      e = sections[s].files.first;
    } else {
      final index = plan.rowFlatStart[row];
      if (index < 0 || index >= visible.length) return null;
      e = visible[index];
    }
    return switch (_sort) {
      FmSort.date => photoMonthYearTitle(e.modifiedMs),
      FmSort.size => FsPaths.humanSize(e.sizeBytes),
      _ => e.name.isEmpty ? null : e.name.characters.first.toUpperCase(),
    };
  }

  /// Her yılın ilk grubunun ofseti (tutamaç sürüklenirken kenarda yazar).
  List<FmScrollTick> _yearTicks() {
    final plan = _plan;
    if (plan == null) return const [];
    final cached = _ticksCache;
    if (cached != null && identical(_ticksPlan, plan)) return cached;
    final sections = _lastSections;
    final ticks = <FmScrollTick>[];
    int? lastYear;
    for (var s = 0; s < sections.length && s < plan.sectionStarts.length; s++) {
      final files = sections[s].files;
      if (files.isEmpty) continue;
      final year = DateTime.fromMillisecondsSinceEpoch(files.first.modifiedMs).year;
      if (year == lastYear) continue;
      lastYear = year;
      ticks.add(FmScrollTick(_appBarExtent + plan.sectionOffset(s), '$year'));
    }
    _ticksCache = ticks;
    _ticksPlan = plan;
    return ticks;
  }

  double _touchDistance() {
    final pts = _touches.values.toList(growable: false);
    return (pts[0] - pts[1]).distance;
  }

  Offset _touchFocal() {
    final pts = _touches.values.toList(growable: false);
    return (pts[0] + pts[1]) / 2;
  }

  void _pointerDown(PointerDownEvent e) {
    _touches[e.pointer] = e.localPosition;
    if (_touches.length == 2) {
      // Kaydırma kilidi devreye girsin (physics değişir).
      _partSetState(() => _pinchBase = _touchDistance());
    }
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.localPosition;
    final base = _pinchBase;
    if (base == null || base <= 0 || _touches.length != 2) return;
    final ratio = _touchDistance() / base;
    // Eşikler bilinçli olarak simetrik değil: parmakları açmak (yaklaşmak)
    // sıkıştırmaktan daha geniş bir harekettir.
    if (ratio > 1.22) {
      _stepZoom(-1, _touchFocal());
    } else if (ratio < 0.84) {
      _stepZoom(1, _touchFocal());
    }
  }

  void _pointerEnd(int pointer) {
    _touches.remove(pointer);
    if (_pinchBase != null && _touches.length < 2) {
      _partSetState(() => _pinchBase = null);
    }
  }

  /// Yakınlaştırma merdiveninde bir basamak ilerler ([dir] -1: yaklaş, +1:
  /// uzaklaş) ve **parmağın altındaki fotoğrafı yerinde tutar**.
  ///
  /// Yeni düzenin satır planı çizimden ÖNCE burada kurulur ve kaydırma ofseti
  /// hemen ona göre ayarlanır: ayar bir sonraki kareye kalsaydı bir kare
  /// boyunca yeni düzen eski ofsette görünür, ızgara titrerdi. Aynı sebeple
  /// ayar `setFmPhotoView` ile yapılır (önce bildirir, sonra diske yazar).
  void _stepZoom(int dir, Offset focal) {
    // Aynı pinch içinde bir sonraki basamak için parmakların yeniden
    // açılması/kapanması gerekir.
    _pinchBase = _touchDistance();
    final appState = context.read<AppState>();
    final cur = nearestPhotoZoomStep(
        appState.fmPhotoLayout.columns, appState.fmPhotoGroup.name);
    final next = cur + dir;
    if (next < 0 || next >= photoZoomLadder.length || _gridWidth <= 0) return;
    final step = photoZoomLadder[next];
    final newLayout = FmLayout.values.firstWhere(
        (l) => l.isGrid && l.columns == step.columns,
        orElse: () => appState.fmPhotoLayout);
    final newGroup = PhotoGroupLabel.byName(step.group);

    final oldPlan = _plan;
    final oldCell = _cell;
    int? anchor;
    var within = 0.0;
    if (oldPlan != null && _scroll.hasClients && oldPlan.rowCount > 0) {
      final listY = _scroll.offset + focal.dy - _appBarExtent;
      if (listY >= 0) {
        anchor = oldPlan.indexAt(listY, focal.dx, _gridWidth);
        final top = anchor == null ? null : oldPlan.offsetOfIndex(anchor);
        if (top != null) {
          within = ((listY - top) / oldPlan.rowExtent).clamp(0.0, 1.0);
        }
      }
    }

    final visible = _visible;
    final newSections = _sections(visible, _timelineMode ? newGroup : null);
    final newCell = _cellFor(step.columns, _gridWidth);
    final newPlan = _planFor(newSections, step.columns, newCell + _PhotosScreenState._spacing);
    appState.setFmPhotoView(newLayout, newGroup);

    if (anchor != null && _scroll.hasClients) {
      final rowTop = newPlan.offsetOfIndex(anchor);
      if (rowTop != null) {
        final pos = _scroll.position;
        final maxExtent = math.max(
            0.0,
            _appBarExtent +
                newPlan.extent +
                _PhotosScreenState._bottomSpacer +
                MediaQuery.paddingOf(context).bottom -
                pos.viewportDimension);
        final target = (_appBarExtent +
                rowTop +
                within * newPlan.rowExtent -
                focal.dy)
            .clamp(0.0, maxExtent);
        _scroll.jumpTo(target);
      }
    }

    // Geçiş: yeni düzen önce eski hücre boyunda çizilir, sonra yerine oturur.
    if (oldCell > 0 && newCell > 0) {
      _zoomFocal = focal;
      _zoomFrom = oldCell / newCell;
      _zoomScale.value = _zoomFrom;
      _zoomAnim.forward(from: 0);
    }
    HapticFeedback.selectionClick();
  }
}
