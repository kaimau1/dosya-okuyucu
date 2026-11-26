part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenGridPart on _SpreadsheetEditorScreenState {
  (List<int>, double, double) _colSlice(
      SheetAxisMetrics cols, (int, int) win) {
    if (cols.isEmpty) return (const <int>[], 0.0, 0.0);
    final maxIndex = cols.length - 1;
    final first = win.$1.clamp(0, maxIndex).toInt();
    var last = win.$2.clamp(first, maxIndex).toInt();
    if (first == 0 && last == 0 && cols.length > 1 && _viewportW > 0) {
      last = math.min(maxIndex, cols.firstAt(_viewportW) + 2);
    }
    final window = cols.indices.sublist(first, last + 1);
    final padLeft = cols.startAt(first);
    final padRight = cols.total - (cols.startAt(last) + cols.sizeAt(last));
    return (window, padLeft, padRight);
  }

  Widget _grid(ScrollPhysics? physics) {
    final sheet = _sheet;
    if (sheet == null) return Center(child: Text(context.t('excel.no_sheet')));

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final divider = theme.dividerColor;
    final docSurface = Paper.docSurface(context);
    final engine = _engineFor(sheet);
    final ctx = _RenderContext(
      sheet: sheet,
      engine: engine,
      zoom: _zoom,
      condCache: _condCache,
      onSurface: scheme.onSurface,
      surfaceContainerHighest: scheme.surfaceContainerHighest,
      outlineHalf: scheme.outline.withValues(alpha: 0.5),
      docSurface: docSurface,
      dividerColor: divider,
      gridColor: divider.withValues(alpha: 0.55),
      filterRange: _filterRange(sheet),
      refs: _formulaRefColors(),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final headerW = _SpreadsheetEditorScreenState._rowHeaderW * _zoom;
      final headerH = _SpreadsheetEditorScreenState._headerH * _zoom;

      // Dondurulmuş bölme ekrana sığdırılır; sığmayan satır/sütunlar
      // kaydırılan bölgeye bırakılır (içerik erişilebilir kalır).
      final wantCols = _frozenColsWanted(sheet);
      final wantRows = _frozenRowsWanted(sheet);
      _frozenColsFit = fitFrozen(
        count: wantCols,
        sizeOf: (c) => sheet.colWidth(c) * _zoom,
        budget: _SpreadsheetEditorScreenState._paneBudget(constraints.maxWidth, headerW),
      );
      _frozenRowsFit = fitFrozen(
        count: wantRows,
        sizeOf: (r) => sheet.rowHeight(r) * _zoom,
        budget: _SpreadsheetEditorScreenState._paneBudget(constraints.maxHeight, headerH),
      );
      _paneTrimmed = _frozenColsFit < wantCols || _frozenRowsFit < wantRows;
      if (_paneTrimmed && !_paneNoticeShown) {
        _paneNoticeShown = true;
        final message = context.t('excel.panes_trimmed');
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _snack(message));
      }

      _refreshMetrics(sheet);
      final rows = _rowMetrics;
      final cols = _colMetrics;
      final frozenRows = _frozenRowList(sheet);
      final frozenCols = _frozenColList(sheet);

      final leftW = math.min(
        headerW + frozenCols.fold<double>(0, (a, c) => a + sheet.colWidth(c) * _zoom),
        math.max(headerW, constraints.maxWidth - 48),
      );
      final topH = headerH +
          frozenRows.fold<double>(0, (a, r) => a + sheet.rowHeight(r) * _zoom);
      _viewportW = math.max(0.0, constraints.maxWidth - leftW);
      _viewportH = math.max(0.0, constraints.maxHeight - topH);

      // Pencere boyutu/zoom değiştiyse sütun penceresini kare sonunda senkronla.
      if (!cols.isEmpty) {
        final off = _hBody.hasClients ? _hBody.offset : 0.0;
        final needFirst = cols.firstAt(off);
        final needLast = cols.firstAt(off + _viewportW);
        final (cf, cl) = _colWindow.value;
        if (needFirst < cf || needLast > cl || cl >= cols.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateColWindow(force: true);
          });
        }
      }
      final bottomInset = MediaQuery.paddingOf(context).bottom;

      // **Sayfa yönü belgeden gelir, arayüz dilinden DEĞİL** (Excel de böyle:
      // Arapça Excel'de soldan sağa bir tablo yine soldan sağa açılır). Bu
      // yüzden yön her iki durumda da AÇIKÇA yazılır — Arapça arayüzde
      // sarmalayıcı olmasa soldan sağa sayfalar da ters çizilirdi.
      //
      // `Row`/`SingleChildScrollView` yönü kendiliğinden uygular: sütunlar
      // sağdan sola dizilir, yatay kaydırma sağ kenardan başlar. Kaydırma
      // konumu (`_hBody.offset`) her iki yönde de BAŞLANGIÇTAN ölçüldüğü için
      // sanallaştırma (`cols.startAt`) ve `_ensureVisible` matematiği aynen
      // geçerli kalır.
      return Stack(
        key: _overlayKey,
        children: [
          // Hücreye dokunma TEK tanıyıcıyla (Faz 26b / K23): dokunulan hücre
          // `SheetCellPos` işaretinden bulunur. Başlıkların ve tutamakların
          // kendi tanıyıcıları içte olduğu için arenayı onlar kazanır.
          Positioned.fill(child: Builder(builder: (tapContext) => GestureDetector(
            onTapUp: (d) {
              final pos = _cellAtGlobal(tapContext, d.globalPosition,
                  clamp: false);
              if (pos != null) _select(pos.$1, pos.$2);
            },
            child: Container(
        // Izgaranın zemini BEYAZ: kağıt teması uygulamanın kabuğuna ait,
        // belgenin içine değil (2026-08-07 kullanıcı isteği).
        color: docSurface,
        child: Directionality(
        textDirection:
            sheet.rightToLeft ? TextDirection.rtl : TextDirection.ltr,
        child: Scrollbar(
        controller: _hBody,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: Column(
          children: [
            // ── üst şerit: köşe + sütun başlıkları + donmuş satırlar ──
            SizedBox(
              height: topH,
              child: Row(
                children: [
                  SizedBox(
                    width: leftW,
                    child: Column(
                      children: [
                        SizedBox(
                          height: headerH,
                          child: Row(
                            children: [
                              _cornerCell(),
                              for (final c in frozenCols) _colHeader(ctx, c),
                            ],
                          ),
                        ),
                        for (final r in frozenRows)
                          SizedBox(
                            height: sheet.rowHeight(r) * _zoom,
                            child: Row(
                              children: [
                                _rowHeader(ctx, r),
                                ..._rowCells(ctx, r, frozenCols),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _hTop,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: cols.total,
                        child: ValueListenableBuilder<(int, int)>(
                          valueListenable: _colWindow,
                          builder: (context, win, _) {
                            final (window, padLeft, padRight) =
                                _colSlice(cols, win);
                            return Column(
                              children: [
                                SizedBox(
                                  height: headerH,
                                  child: Row(children: [
                                    SizedBox(width: padLeft),
                                    for (final c in window) _colHeader(ctx, c),
                                    SizedBox(width: padRight),
                                  ]),
                                ),
                                for (final r in frozenRows)
                                  SizedBox(
                                    height: sheet.rowHeight(r) * _zoom,
                                    child: Row(children: [
                                      SizedBox(width: padLeft),
                                      ..._rowCells(ctx, r, window),
                                      SizedBox(width: padRight),
                                    ]),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── gövde: satır başlıkları + donmuş sütunlar + hücreler ──
            Expanded(
              child: Scrollbar(
                controller: _vBody,
                notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                child: Row(
                  children: [
                    SizedBox(
                      width: leftW,
                      child: ListView.builder(
                        controller: _vLeft,
                        physics: const NeverScrollableScrollPhysics(),
                        addAutomaticKeepAlives: false,
                        // Alt boşluk İKİ listede de aynı olmalı; yoksa en altta
                        // satır başlıkları hücrelerden kayıyor.
                        padding: EdgeInsets.only(bottom: bottomInset),
                        itemCount: rows.length,
                        itemExtentBuilder: (i, _) => rows.sizeAt(i),
                        itemBuilder: (_, i) {
                          final r = rows.indices[i];
                          if (frozenCols.isEmpty) return _rowHeader(ctx, r);
                          return Row(children: [
                            _rowHeader(ctx, r),
                            ..._rowCells(ctx, r, frozenCols),
                          ]);
                        },
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _hBody,
                        physics: physics,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: cols.total,
                          child: _withCharts(
                            _dragSelectArea(
                              ValueListenableBuilder<(int, int)>(
                                valueListenable: _colWindow,
                                builder: (context, win, _) {
                                  final (window, padLeft, padRight) =
                                      _colSlice(cols, win);
                                  return ListView.builder(
                                    controller: _vBody,
                                    physics: physics,
                                    addAutomaticKeepAlives: false,
                                    padding:
                                        EdgeInsets.only(bottom: bottomInset),
                                    itemCount: rows.length,
                                    itemExtentBuilder: (i, _) => rows.sizeAt(i),
                                    itemBuilder: (_, i) {
                                      final r = rows.indices[i];
                                      return Row(children: [
                                        SizedBox(width: padLeft),
                                        ..._rowCells(ctx, r, window),
                                        SizedBox(width: padRight),
                                      ]);
                                    },
                                  );
                                },
                              ),
                            ),
                            rows,
                            cols,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
      )))),
          if (_editing) _floatingEditor(constraints),
          // Kaydırınca sabit başlığın altında ince gölge (Faz 36 madde 7):
          // yalnız kaydırma eşiği geçilince boyanır, her pikselde tetiklenmez.
          Positioned(
            top: topH,
            left: 0,
            right: 0,
            height: 6,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _scrolledDown,
                  builder: (context, down, _) => down
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [AppColors.shadow, AppColors.none],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          if (_resizePreviewSize != null &&
              (_resizeCol != null || _resizeRow != null))
            Positioned(
              top: topH + 8,
              left: leftW + 8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      _resizeCol != null
                          ? '${XlsxRange.colName(_resizeCol!)}: ${_resizePreviewSize!.toStringAsFixed(1)}'
                          : '${_resizeRow! + 1}: ${_resizePreviewSize!.toStringAsFixed(1)} pt',
                      style: context.type.small.copyWith(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ..._selectionHandles(),
        ],
      );
    });
  }

  /// Basılı tut + kaydır = aralık seçimi (Excel'in seçim tutamacının mobil
  /// karşılığı). Hücrelerin kendi uzun basışı YOKTUR — olsaydı jest arenasını
  /// çocuk kazanır, sürükleme hiç başlamazdı.
  Widget _dragSelectArea(Widget child) => Builder(
        builder: (areaContext) => Semantics(
          label: context.t('excel.grid_label'),
          child: GestureDetector(
          key: _gridAreaKey,
          onLongPressStart: (d) {
            final pos = _cellAtGlobal(areaContext, d.globalPosition);
            if (pos == null) return;
            _longPressMoved = false;
            if (_pointInsertable()) {
              // İşaret kipi: uzun bas + sürükle = aralık başvurusu.
              _pointAnchor = pos;
              _insertPointRef(pos.$1, pos.$2);
              return;
            }
            _pointAnchor = null;
            _endEdit();
            _partSetState(() {
              _anchorRow = pos.$1;
              _anchorCol = pos.$2;
              _selRow = pos.$1;
              _selCol = pos.$2;
            });
            _syncField();
          },
          onLongPressMoveUpdate: (d) {
            final pos = _cellAtGlobal(areaContext, d.globalPosition);
            if (pos == null) return;
            final anchor = _pointAnchor;
            if (anchor != null) {
              _insertPointRef(anchor.$1, anchor.$2, pos.$1, pos.$2);
              return;
            }
            if (pos.$1 == _selRow && pos.$2 == _selCol) return;
            _longPressMoved = true;
            _partSetState(() {
              _selRow = pos.$1;
              _selCol = pos.$2;
            });
          },
          // Uzun basıp SÜRÜKLEMEDEN bırakmak → bağlam menüsü (madde 9).
          onLongPressEnd: (_) {
            if (_pointAnchor != null) {
              _pointAnchor = null;
              return;
            }
            if (!_longPressMoved) _showCellMenu();
          },
          child: child,
        ),
        ),
      );

  /// Ekran koordinatındaki hücreyi bulur (MetaData işaretleriyle, ölçüm yok).
  /// [clamp]: sürüklemede parmak alanın dışına çıksa da kenardaki hücre
  /// bulunsun; dokunuşta kapalı (alan dışı = hücre yok).
  (int, int)? _cellAtGlobal(BuildContext areaContext, Offset globalPos,
      {bool clamp = true}) {
    final box = areaContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    var local = box.globalToLocal(globalPos);
    if (clamp) {
      local = Offset(
        local.dx.clamp(0.5, box.size.width - 0.5),
        local.dy.clamp(0.5, box.size.height - 0.5),
      );
    } else if (!(Offset.zero & box.size).contains(local)) {
      return null;
    }
    final result = BoxHitTestResult();
    box.hitTest(result, position: local);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData) {
        final meta = target.metaData;
        if (meta is SheetCellPos) return (meta.row, meta.col);
      }
    }
    return null;
  }

  Widget _cornerCell() {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.t('ks.select_all'),
      button: true,
      child: GestureDetector(
      onTap: () {
        final sheet = _sheet;
        if (sheet == null) return;
        // Seçim KULLANILAN alanla sınırlı: ızgara boş satır/sütunlarla
        // doldurulmuş olsa da "tümünü seç" veri dışına taşmaz.
        _partSetState(() {
          _anchorRow = 0;
          _anchorCol = 0;
          _selRow = math.max(0, sheet.maxRows - 1);
          _selCol = math.max(0, sheet.maxCols - 1);
        });
      },
      child: Container(
        width: _SpreadsheetEditorScreenState._rowHeaderW * _zoom,
        height: _SpreadsheetEditorScreenState._headerH * _zoom,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
    ),
    );
  }

  /// Sütun genişliğini/satır yüksekliğini **sürükleyerek** değiştirir.
  ///
  /// Kullanıcı 2026-08-17: *"sütun genişliği ayarlama çok zor, satır yüksekliği
  /// ayarlama çok zor"*. Eskiden tek yol başlığa uzun basıp açılan kaydırıcılı
  /// diyalogdu: hem keşfedilemiyordu hem de sonucu ancak "Uygula"dan sonra
  /// görülüyordu. Artık Excel'deki gibi kenar sürükleniyor ve genişlik ANINDA
  /// büyüyor. Diyalog kalıyor (uzun basış) — sayısal kesinlik isteyen için.
  ///
  /// [_SpreadsheetEditorScreenState._resizeGrip] genişliğindeki tutamak `Positioned` ile başlığın sağ/alt
  /// kenarına yaslanır; `HitTestBehavior.opaque` sayesinde sürükleme jesti
  /// altındaki "sütunu seç" dokunuşunu yutar.
  Widget _resizeGripFor({int? col, int? row, Color? idleColor}) {
    final sheet = _sheet;
    if (sheet == null) return const SizedBox.shrink();
    final isCol = col != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Yatay/dikey ayrı tanıyıcı: sütun tutamağı YALNIZ yatay sürüklemeyi
      // üstlenir, dikey kaydırma ızgaraya geçer (ve tersi).
      onHorizontalDragStart: !isCol
          ? null
          : (_) {
              _endEdit();
              _resizeCol = col;
              _resizeStart = sheet.layout.colWidthChars(col);
              _resizePreviewSize = _resizeStart;
              _partSetState(() {});
            },
      onHorizontalDragUpdate: !isCol
          ? null
          : (d) {
              if (_resizeCol == null) return;
              // Piksel → karakter: Excel'in sütun birimi ~7 px'lik "0" genişliği.
              _resizePreviewSize =
                  ((_resizePreviewSize ?? _resizeStart) +
                          d.delta.dx / (7 * _zoom))
                      .clamp(0.0, 255.0);
              _partSetState(() {});
            },
      onHorizontalDragEnd: !isCol ? null : (_) => _endResize(sheet),
      onHorizontalDragCancel: !isCol ? null : _cancelResize,
      onVerticalDragStart: isCol
          ? null
          : (_) {
              _endEdit();
              _resizeRow = row;
              _resizeStart = sheet.layout.rowHeightPt(row!);
              _resizePreviewSize = _resizeStart;
              _partSetState(() {});
            },
      onVerticalDragUpdate: isCol
          ? null
          : (d) {
              if (_resizeRow == null) return;
              // Piksel → punto: 1 pt ≈ 4/3 px.
              _resizePreviewSize =
                  ((_resizePreviewSize ?? _resizeStart) +
                          d.delta.dy * 0.75 / _zoom)
                      .clamp(0.0, 409.0);
              _partSetState(() {});
            },
      onVerticalDragEnd: isCol ? null : (_) => _endResize(sheet),
      onVerticalDragCancel: isCol ? null : _cancelResize,
      child: Align(
        alignment: isCol ? Alignment.centerRight : Alignment.bottomCenter,
        child: Container(
          width: isCol ? 2 : double.infinity,
          height: isCol ? double.infinity : 2,
          margin: EdgeInsets.only(right: isCol ? 1 : 0, bottom: isCol ? 0 : 1),
          color: (isCol ? _resizeCol == col : _resizeRow == row)
              ? OfficeColors.excel
              : (idleColor ??
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  void _endResize(XlsxSheet sheet) {
    final col = _resizeCol;
    final row = _resizeRow;
    final next = _resizePreviewSize;
    final prev = _resizeStart;
    _resizeCol = null;
    _resizeRow = null;
    _resizePreviewSize = null;
    if (col != null && next != null && (next - prev).abs() > 0.01) {
      sheet.setColWidthChars(col, next);
      _recordStep(
        'excel.column_width',
        () => sheet.setColWidthChars(col, next),
        () => sheet.setColWidthChars(col, prev),
      );
      _session.changed();
      _gridVersion++;
      _autoFitVersion++;
    } else if (row != null && next != null && (next - prev).abs() > 0.01) {
      sheet.setRowHeightPt(row, next);
      _recordStep(
        'excel.row_height',
        () => sheet.setRowHeightPt(row, next),
        () => sheet.setRowHeightPt(row, prev),
      );
      _session.changed();
      _gridVersion++;
      _autoFitVersion++;
    }
    _partSetState(() {});
  }

  void _cancelResize() {
    _partSetState(() {
      _resizeCol = null;
      _resizeRow = null;
      _resizePreviewSize = null;
    });
  }
}
