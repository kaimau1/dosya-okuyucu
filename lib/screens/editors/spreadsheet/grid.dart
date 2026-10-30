part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenGridPart on _SpreadsheetEditorScreenState {
  Widget _grid(ScrollPhysics? physics) {
    final sheet = _sheet;
    if (sheet == null) return Center(child: Text(context.t('excel.no_sheet')));

    final engine = _engineFor(sheet);
    final ctx = _RenderContext(
      sheet: sheet,
      engine: engine,
      zoom: _zoom,
      condCache: _condCache,
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

      // Görünen sütun penceresi (yatay sanallaştırma).
      final maxIndex = math.max(0, cols.length - 1);
      final first = _firstCol.clamp(0, maxIndex).toInt();
      final last = _lastCol.clamp(first, maxIndex).toInt();
      final window = cols.isEmpty ? const <int>[] : cols.indices.sublist(first, last + 1);
      final padLeft = cols.isEmpty ? 0.0 : cols.startAt(first);
      final padRight = cols.isEmpty
          ? 0.0
          : cols.total - (cols.startAt(last) + cols.sizeAt(last));
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
        color: Paper.docSurface(context),
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
                              for (final c in frozenCols) _colHeader(sheet, c),
                            ],
                          ),
                        ),
                        for (final r in frozenRows)
                          SizedBox(
                            height: sheet.rowHeight(r) * _zoom,
                            child: Row(
                              children: [
                                _rowHeader(sheet, r),
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
                        child: Column(
                          children: [
                            SizedBox(
                              height: headerH,
                              child: Row(children: [
                                SizedBox(width: padLeft),
                                for (final c in window) _colHeader(sheet, c),
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
                        // Alt boşluk İKİ listede de aynı olmalı; yoksa en altta
                        // satır başlıkları hücrelerden kayıyor.
                        padding: EdgeInsets.only(bottom: bottomInset),
                        itemCount: rows.length,
                        itemExtentBuilder: (i, _) => rows.sizeAt(i),
                        itemBuilder: (_, i) {
                          final r = rows.indices[i];
                          return Row(children: [
                            _rowHeader(sheet, r),
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
                              ListView.builder(
                                controller: _vBody,
                                physics: physics,
                                padding: EdgeInsets.only(bottom: bottomInset),
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
  Widget _resizeGripFor({int? col, int? row}) {
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
            },
      onHorizontalDragUpdate: !isCol
          ? null
          : (d) {
              if (_resizeCol == null) return;
              // Piksel → karakter: Excel'in sütun birimi ~7 px'lik "0" genişliği.
              _resizeStart =
                  (_resizeStart + d.delta.dx / (7 * _zoom)).clamp(0.0, 255.0);
              sheet.setColWidthChars(col, _resizeStart);
              _session.changed();
              _gridVersion++;
              _partSetState(() {});
            },
      onHorizontalDragEnd: !isCol ? null : (_) => _partSetState(() => _resizeCol = null),
      onHorizontalDragCancel: !isCol ? null : () => _partSetState(() => _resizeCol = null),
      onVerticalDragStart: isCol
          ? null
          : (_) {
              _endEdit();
              _resizeRow = row;
              _resizeStart = sheet.layout.rowHeightPt(row!);
            },
      onVerticalDragUpdate: isCol
          ? null
          : (d) {
              if (_resizeRow == null) return;
              // Piksel → punto: 1 pt ≈ 4/3 px.
              _resizeStart =
                  (_resizeStart + d.delta.dy * 0.75 / _zoom).clamp(0.0, 409.0);
              sheet.setRowHeightPt(row!, _resizeStart);
              _session.changed();
              _gridVersion++;
              _partSetState(() {});
            },
      onVerticalDragEnd: isCol ? null : (_) => _partSetState(() => _resizeRow = null),
      onVerticalDragCancel: isCol ? null : () => _partSetState(() => _resizeRow = null),
      child: Align(
        alignment: isCol ? Alignment.centerRight : Alignment.bottomCenter,
        child: Container(
          width: isCol ? 2 : double.infinity,
          height: isCol ? double.infinity : 2,
          margin: EdgeInsets.only(right: isCol ? 1 : 0, bottom: isCol ? 0 : 1),
          color: (isCol ? _resizeCol == col : _resizeRow == row)
              ? OfficeColors.excel
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
