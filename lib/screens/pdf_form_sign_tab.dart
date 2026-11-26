part of 'pdf_form_screen.dart';

/// **Serbest imza / baş harf / tarih damgası yerleştirme sekmesi**
/// (Faz 61 m.4 & m.6: eski `PdfSignScreen` bu yüzeye taşınıp emekli edildi).
///
/// Koordinat sözleşmesi: kullanıcı sayfayı `/Rotate` uygulanmış hâliyle görür
/// (`PdfPage.width/height`) ve öğeleri 0..1 oranla konumlandırır; ham sayfa
/// dönüşümünü `PdfTools.stampStrokes/stampText/stampImage` yapar.
extension _PdfFormSignTabPart on _PdfFormScreenState {
  _PlacedStamp? get _activeStamp {
    for (final s in _placed) {
      if (s.id == _activeStampId && s.page == _signPage) return s;
    }
    for (final s in _placed) {
      if (s.page == _signPage) return s;
    }
    return null;
  }

  Future<void> _addPlacedSignature({required bool initials}) async {
    final sig = await SignaturePad.show(context, initials: initials);
    if (sig == null || !mounted) return;
    _partSetState(() {
      final st = _PlacedStamp(
        id: _nextStampId++,
        page: _signPage,
        signature: sig,
        pos: Offset(initials ? 0.72 : 0.52, 0.76),
        widthFraction: initials ? 0.16 : 0.34,
      );
      _placed.add(st);
      _activeStampId = st.id;
    });
  }

  void _addDateStamp() {
    final text = _PdfFormScreenState._formatDate(DateTime.now());
    _partSetState(() {
      final st = _PlacedStamp(
        id: _nextStampId++,
        page: _signPage,
        signature: Signature.typed(text),
        pos: const Offset(0.58, 0.84),
        widthFraction: 0.24,
        isDateStamp: true,
      );
      _placed.add(st);
      _activeStampId = st.id;
    });
  }

  void _removeStamp(int id) {
    _partSetState(() {
      _placed.removeWhere((s) => s.id == id);
      if (_activeStampId == id) _activeStampId = null;
    });
  }

  Widget _buildSignTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _activeStamp;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Gap.md, vertical: Gap.xs),
          child: Row(
            children: [
              ActionChip(
                key: const ValueKey('pf-sign-add-sig'),
                avatar: const Icon(AppIcons.draw, size: 18),
                label: Text(context.t('pf.add_signature')),
                onPressed:
                    _busy ? null : () => _addPlacedSignature(initials: false),
              ),
              const SizedBox(width: Gap.xs),
              ActionChip(
                key: const ValueKey('pf-sign-add-initials'),
                avatar: const Icon(AppIcons.gesture, size: 18),
                label: Text(context.t('pf.add_initials')),
                onPressed:
                    _busy ? null : () => _addPlacedSignature(initials: true),
              ),
              const SizedBox(width: Gap.xs),
              ActionChip(
                key: const ValueKey('pf-sign-add-date'),
                avatar: const Icon(AppIcons.calendarMonth, size: 18),
                label: Text(context.t('pf.add_date_stamp')),
                onPressed: _busy ? null : _addDateStamp,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Gap.md),
          child: Text(
            context.t(_placed.isEmpty
                ? 'pf.sign_empty_hint'
                : 'pf.sign_drag_hint'),
            style: context.type.small.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Expanded(
          child: PdfDocumentViewBuilder.file(
            widget.path,
            builder: (context, document) {
              final pages = document?.pages;
              if (pages == null || pages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final safePage = _signPage.clamp(0, pages.length - 1);
              final page = pages[safePage];
              _pageSizes[safePage] = Size(page.width, page.height);
              return _signPageCanvas(context, document!, page, safePage);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                Gap.sm, Gap.xs, Gap.md, Gap.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: context.t('sg.prev_page'),
                      icon: const Icon(AppIcons.chevronLeft),
                      onPressed: _signPage <= 0
                          ? null
                          : () => _partSetState(() => _signPage -= 1),
                    ),
                    Text('${_signPage + 1} / $_pageCount'),
                    IconButton(
                      tooltip: context.t('mp.next_page'),
                      icon: const Icon(AppIcons.chevron),
                      onPressed: _signPage >= _pageCount - 1
                          ? null
                          : () => _partSetState(() => _signPage += 1),
                    ),
                    const SizedBox(width: Gap.xs),
                    const Icon(AppIcons.photoSizeSelectSmall, size: 18),
                    Expanded(
                      child: Slider(
                        value: (active?.widthFraction ?? 0.34).clamp(0.08, 0.8),
                        min: 0.08,
                        max: 0.8,
                        onChanged: active == null
                            ? null
                            : (v) =>
                                _partSetState(() => active.widthFraction = v),
                      ),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('pf-sign-save'),
                      onPressed: (_busy || !_dirty) ? null : _save,
                      icon: const Icon(AppIcons.check, size: 18),
                      label: Text(context.t('pf.save_all')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _signPageCanvas(
    BuildContext context,
    PdfDocument document,
    PdfPage page,
    int pageIndex,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final pageStamps = [
      for (final s in _placed)
        if (s.page == pageIndex) s,
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final scale = math.min(
          box.maxWidth / page.width,
          box.maxHeight / page.height,
        );
        final fitted = Size(page.width * scale, page.height * scale);
        return Center(
          child: SizedBox(
            width: fitted.width,
            height: fitted.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PdfPageView(
                    document: document,
                    pageNumber: pageIndex + 1,
                    decoration: const BoxDecoration(color: AppColors.page),
                  ),
                ),
                for (final st in pageStamps)
                  _placedOverlay(context, st, fitted, scheme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placedOverlay(
    BuildContext context,
    _PlacedStamp st,
    Size fitted,
    ColorScheme scheme,
  ) {
    final w = st.widthFraction * fitted.width;
    final h = math.max(24.0, w / st.signature.aspect);
    final selected = _activeStamp?.id == st.id;
    return Positioned(
      left: (st.pos.dx * fitted.width).clamp(0.0, math.max(0.0, fitted.width - w)),
      top: (st.pos.dy * fitted.height).clamp(0.0, math.max(0.0, fitted.height - h)),
      width: w,
      height: h,
      child: GestureDetector(
        onTap: () => _partSetState(() => _activeStampId = st.id),
        onPanStart: (_) => _partSetState(() => _activeStampId = st.id),
        onPanUpdate: (d) => _partSetState(() {
          final nx = st.pos.dx + d.delta.dx / fitted.width;
          final ny = st.pos.dy + d.delta.dy / fitted.height;
          st.pos = Offset(
            nx.clamp(0.0, math.max(0.0, 1 - w / fitted.width)),
            ny.clamp(0.0, math.max(0.0, 1 - h / fitted.height)),
          );
        }),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: st.isDateStamp
                    ? Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            st.signature.text ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.pageInk),
                          ),
                        ),
                      )
                    : SignaturePreview(signature: st.signature),
              ),
              if (selected)
                PositionedDirectional(
                  top: -10,
                  end: -10,
                  child: GestureDetector(
                    onTap: () => _removeStamp(st.id),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(AppIcons.close,
                            size: 14, color: scheme.onErrorContainer),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
