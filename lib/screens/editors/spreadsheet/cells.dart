part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenCellsPart on _SpreadsheetEditorScreenState {
  /// [cols] bu bölgede çizilen sütunlar — birleşik hücre genişliği YALNIZ bu
  /// bölgedeki sütunları toplar. (Dondurulmuş bölmede A1:C1 birleşmesi tüm
  /// genişliğiyle çizilirse sol bölme taşar; Excel de bölme sınırında keser.)
  Widget _cell(
    _RenderContext ctx,
    int r,
    int c,
    List<int> cols, {
    Map<int, XlsxCellView>? views,
    SheetSpillPlan spill = SheetSpillPlan.empty,
  }) {
    final sheet = ctx.sheet;
    final merge = sheet.mergeAt(r, c);
    var width = sheet.colWidth(c) * _zoom;
    // Yükseklik DAİMA kendi satırının yüksekliğidir: satırlar tembel listede
    // sabit uzantıyla çizilir, daha yüksek bir çocuk komşu satıra taşardı.
    // Dikey birleşmede içerik üst satırda görünür, altlar boş kalır.
    final height = sheet.rowHeight(r) * _zoom;
    var hideContent = false;

    if (merge != null) {
      if (merge.colStart == c) {
        width = 0;
        for (var k = merge.colStart; k <= merge.colEnd; k++) {
          if (!cols.contains(k)) continue;
          width += sheet.colWidth(k) * _zoom;
        }
        if (width <= 0) width = sheet.colWidth(c) * _zoom;
      }
      if (!merge.isAnchor(r, c)) hideContent = true;
    }

    final selected = _inSelection(r, c);
    final isCursor = r == _selRow && c == _selCol;
    // Doldurma tutamağı seçimin SAĞ ALT köşesinde durur (Excel'deki gibi).
    final range = _range;
    final showHandle =
        !_editing && r == range.bottom && c == range.right && !hideContent;

    final spillHere = spill.spillAt(c);
    // Aralığın TEK dış çerçevesi (X8) ve formül başvurularının renkli
    // çerçeveleri (X7): kenar bit maskesi.
    var rangeEdges = 0;
    if (_hasRange && range.contains(r, c)) {
      if (r == range.top) rangeEdges |= SheetCell.edgeTop;
      if (r == range.bottom) rangeEdges |= SheetCell.edgeBottom;
      if (c == range.left) rangeEdges |= SheetCell.edgeLeft;
      if (c == range.right) rangeEdges |= SheetCell.edgeRight;
    }
    var refEdges = 0;
    Color? refColor;
    for (final (ref, color) in ctx.refs) {
      if (!ref.contains(r, c)) continue;
      refColor = color;
      if (r == ref.r1) refEdges |= SheetCell.edgeTop;
      if (r == ref.r2) refEdges |= SheetCell.edgeBottom;
      if (c == ref.c1) refEdges |= SheetCell.edgeLeft;
      if (c == ref.c2) refEdges |= SheetCell.edgeRight;
      break;
    }
    final GlobalKey? key = isCursor
        ? _cursorKey
        : null;
    final cell = SheetCell(
      key: key,
      row: r,
      col: c,
      width: width,
      height: height,
      zoom: _zoom,
      style: sheet.styleAt(r, c),
      view: hideContent
          ? const XlsxCellView('')
          : (views?[c] ?? sheet.viewAt(r, c, ctx.engine.displayValue(r, c))),
      cond: hideContent ? null : ctx.condFor(r, c),
      selected: selected,
      cursor: isCursor,
      // Düzenleme hücrenin İÇİNDE değil, üstündeki yüzer editörde.
      editing: false,
      rangeEdges: rangeEdges,
      refEdges: refEdges,
      refColor: refColor,
      spillLeft: spillHere.left * _zoom,
      spillRight: spillHere.right * _zoom,
      // Sarkan metnin ALTINDAKİ hücre kendi ızgara çizgisini çizmez: çizerse
      // harflerin ortasından geçen bir kıl çizgi kalırdı (Excel de gizler).
      showGridLines: sheet.showGridLines && !spill.isCovered(c),
      controller: _cellField,
      onTap: () => _select(r, c),
      onSubmitted: () => _commitAndMoveDown(_rowCount(sheet)),
      onEditingComplete: _endEdit,
    );
    // Hücre notu (Excel'in "Açıklama"sı): sağ ÜST köşede küçük kırmızı üçgen,
    // dokununca metni gösterir. Excel'in kendi işareti de budur.
    final note = hideContent ? null : sheet.commentAt(r, c);
    // Seçim tutamaklarının yeri: aralığın sol-üst ve sağ-alt hücreleri.
    final tl = r == range.top && c == range.left;
    final br = r == range.bottom && c == range.right;
    final listArrow = isCursor && !_editing && _validationOptions().isNotEmpty;
    if (!showHandle && note == null && !tl && !br && !listArrow) return cell;
    return SizedBox(
      key: tl && !isCursor ? _tlKey : (br && !isCursor && !tl ? _brKey : null),
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: cell),
          // İmleç hücresi de köşe olabilir: anahtarı kendi katmanında.
          if (isCursor && tl)
            Positioned.fill(child: IgnorePointer(child: SizedBox(key: _tlKey))),
          if (isCursor && br && !tl)
            Positioned.fill(child: IgnorePointer(child: SizedBox(key: _brKey))),
          if (isCursor && br && tl)
            Positioned.fill(child: IgnorePointer(child: SizedBox(key: _brKey))),
          if (listArrow)
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                key: const ValueKey('validation-arrow'),
                onTap: _pickFromValidation,
                child: Container(
                  width: 22,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(AppIcons.arrowDropDown, size: 18),
                ),
              ),
            ),
          if (note != null)
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => _showComment(r, c, note),
                child: CustomPaint(
                  size: Size(6 * _zoom, 6 * _zoom),
                  painter: const _NoteMarkPainter(),
                ),
              ),
            ),
          if (showHandle)
            Positioned(right: 0, bottom: 0, child: _fillHandle()),
        ],
      ),
    );
  }

  /// Excel'in doldurma tutamağı: seçimin sağ alt köşesindeki küçük kare.
  ///
  /// **Neden `RawGestureDetector` + [ImmediateMultiDragGestureRecognizer]:**
  /// tutamak kaydırılabilir ızgaranın İÇİNDE duruyor. Sıradan bir
  /// `GestureDetector` sürüklemeyi kaydırma tanıyıcısıyla arenada paylaşır ve
  /// çoğu zaman kaydırma kazanır — tutamak sürüklenmez, sayfa kayar. Anında
  /// kabul eden tanıyıcı (Flutter'ın kendi sürükle-bırak listelerinde
  /// kullandığı yöntem) pointer'ı hemen üstlenir.
  Widget _fillHandle() {
    final scheme = Theme.of(context).colorScheme;
    return RawGestureDetector(
      key: SpreadsheetEditorScreen.fillHandleKey,
      behavior: HitTestBehavior.opaque,
      gestures: {
        ImmediateMultiDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                ImmediateMultiDragGestureRecognizer>(
          ImmediateMultiDragGestureRecognizer.new,
          (r) => r.onStart = (_) => _FillDrag(
                onMove: _onFillMove,
                onDone: _onFillEnd,
              ),
        ),
        // Çift dokunuş: masaüstü Excel'deki "tutamağa çift tıkla" — komşu
        // sütun nereye kadar doluysa oraya kadar doldurur. Sürükleme
        // tanıyıcısıyla çakışmaz: biri sürüklemeyi, öteki dokunuşu üstlenir.
        DoubleTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
          DoubleTapGestureRecognizer.new,
          (r) => r.onDoubleTap = _fillDownToNeighbour,
        ),
      },
      child: SizedBox(
        // Görünen kare küçük, dokunma alanı parmağa göre büyük.
        width: 22,
        height: 22,
        child: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: scheme.primary,
              border: Border.all(color: scheme.onPrimary, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  /// Hücre notunu gösterir.
  void _showComment(int r, int c, XlsxComment note) {
    _endEdit();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${XlsxRange.colName(c)}${r + 1}'
            '${note.author.isEmpty ? '' : ' · ${note.author}'}'),
        content: SingleChildScrollView(child: Text(note.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.close')),
          ),
        ],
      ),
    );
  }

  /// Tutamağa çift dokunuş: seçimi **komşu sütunun bittiği yere kadar**
  /// aşağı doldurur. Excel'in en çok kullanılan kısayollarından biri — formülü
  /// bin satır sürüklemeye gerek kalmıyor.
  ///
  /// Sınırı komşu sütun belirler: önce SOLDAKİ (Excel'in kuralı), o boşsa
  /// sağdaki. İkisi de boşsa yapacak bir şey yok — nereye kadar dolduracağını
  /// bilemeyiz ve tahmin etmek binlerce boş satır yazmak olurdu.
  void _fillDownToNeighbour() {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final src = _range;
    final lastRow = math.max(0, sheet.maxRows - 1);

    int runEnd(int col) {
      if (col < 0) return src.bottom;
      var r = src.bottom + 1;
      while (r <= lastRow && sheet.rawAt(r, col).isNotEmpty) {
        r++;
      }
      return r - 1;
    }

    var target = runEnd(src.left - 1);
    if (target <= src.bottom) target = runEnd(src.right + 1);
    if (target <= src.bottom) {
      _snack(context.t('excel.fill_no_neighbour'));
      return;
    }
    _applyFill(target, src.right);
  }

  void _onFillMove(Offset global) {
    final ctx = _gridAreaKey.currentContext;
    if (ctx == null) return;
    final pos = _cellAtGlobal(ctx, global);
    if (pos == null) return;
    if (pos.$1 == _fillToRow && pos.$2 == _fillToCol) return;
    _partSetState(() {
      _fillToRow = pos.$1;
      _fillToCol = pos.$2;
    });
  }

  void _onFillEnd({required bool apply}) {
    final row = _fillToRow;
    final col = _fillToCol;
    _partSetState(() {
      _fillToRow = null;
      _fillToCol = null;
    });
    if (apply && row != null && col != null) _applyFill(row, col);
  }
}
