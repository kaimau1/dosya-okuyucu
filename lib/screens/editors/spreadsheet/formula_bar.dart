part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenFormulaBarPart on _SpreadsheetEditorScreenState {
  /// Pinch odağındaki içerik yerinde kalsın.
  void _fixScroll(double f, Offset focal) {
    if (_hBody.hasClients) {
      // Kaydırma konumu her iki yönde de BAŞLANGIÇTAN ölçülür; `focal.dx` ise
      // daima ekranın SOLUNDAN. Sağdan sola sayfada odağın başlangıca uzaklığı
      // bu yüzden aynalanmalı, yoksa pinch odağın simetriği etrafında zoomlar.
      final dx = (_sheet?.rightToLeft ?? false) && _viewportW > 0
          ? _viewportW - focal.dx
          : focal.dx;
      _hBody.jumpTo(((_hBody.offset + dx) * f - dx)
          .clamp(0.0, _hBody.position.maxScrollExtent));
    }
    if (_vBody.hasClients) {
      _vBody.jumpTo(((_vBody.offset + focal.dy) * f - focal.dy)
          .clamp(0.0, _vBody.position.maxScrollExtent));
    }
    _updateColWindow();
    // Şeritteki zoom yüzdesi ölçekle birlikte yenilensin (rozet pinch'te
    // görünür, düğmeyle zoomda görünmez — kullanıcının tek göstergesi bu).
    if (mounted) _partSetState(() {});
  }

  /// Seçim adresi (tek hücre ya da aralık) — "Ad Kutusu".
  String get _selectionLabel => _hasRange
      ? '${XlsxRange.colName(math.min(_anchorCol, _selCol))}'
          '${math.min(_anchorRow, _selRow) + 1}:'
          '${XlsxRange.colName(math.max(_anchorCol, _selCol))}'
          '${math.max(_anchorRow, _selRow) + 1}'
      : '${XlsxRange.colName(_selCol)}${_selRow + 1}';

  /// Alandaki metin hücrenin değerinden farklı mı (onaylanmamış giriş var mı)?
  bool get _hasPendingInput =>
      _cellField.text != _valueAt(_selRow, _selCol);

  /// **Formül çubuğu** — tek satır, sıkışık.
  ///
  /// Kullanıcı 2026-08-17: *"yazarken çıkan mavi alan gereksiz ve çok dar"* +
  /// *"üst bilgi alanı çok kalabalık"*. Değişenler:
  /// * Çerçeveli (`OutlineInputBorder`) kutu gitti — odaklanınca çevresinde
  ///   beliren mavi hat kadar yer kaplayan ikinci bir çerçeveydi. Yerine
  ///   yüzey tonunda, çerçevesiz bir alan geldi.
  /// * Yükseklik 50 → 38 dp; ✓ ve ✗ **yalnız onaylanmamış giriş varken**
  ///   çıkar (Excel de böyle yapar), yer boşuna durmaz.
  /// * Yazarken alan **büyür** (en çok 3 satır): uzun bir hücre metnini tek
  ///   satırlık bir yarıkta düzenlemek imkânsızdı.
  /// * Şeridi açıp kapatan çift yönlü ok sağda: ızgaraya 68 dp daha yer.
  Widget _cellBar() {
    final scheme = Theme.of(context).colorScheme;
    final pending = _hasPendingInput;
    return Container(
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ad Kutusu: dokununca "Hücreye git" (Excel'de de yazılabilir bir
          // alandır; telefonda diyalog daha güvenli).
          InkWell(
            onTap: _editor == null ? null : _showGoTo,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Container(
              width: 62,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Text(
                _selectionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _cellField,
              focusNode: _barFocus,
              onSubmitted: (_) {
                final sheet = _sheet;
                if (sheet == null) {
                  _applyCell(_cellField.text);
                  return;
                }
                _commitAndMoveDown(_rowCount(sheet));
              },
              onChanged: (_) => _partSetState(() {}),
              textInputAction: TextInputAction.done,
              minLines: 1,
              maxLines: pending ? 3 : 1,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: context.t('excel.cell_content'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
            ),
          ),
          // Veri doğrulama listesi olan hücrede Excel'deki açılır ok.
          if (_validationOptions().isNotEmpty)
            PopupMenuButton<String>(
              tooltip: context.t('excel.pick_from_list'),
              icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20),
              padding: EdgeInsets.zero,
              onSelected: (v) {
                _cellField.text = v;
                _applyCell(v);
              },
              itemBuilder: (_) => [
                for (final o in _validationOptions())
                  PopupMenuItem(value: o, child: Text(o)),
              ],
            ),
          // ✗ / ✓ yalnız onaylanmamış giriş varken. (Kaydetmek için ✓'e basmak
          // ZORUNLU DEĞİL — başka hücreye geçmek de yazar, bkz. `_endEdit`.)
          if (pending) ...[
            IconButton(
              tooltip: context.t('common.cancel'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(Icons.close),
              onPressed: () {
                _editing = false;
                _syncField();
                _partSetState(() {});
              },
            ),
            IconButton(
              tooltip: context.t('common.apply'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              color: OfficeColors.excel,
              icon: const Icon(Icons.check),
              onPressed: () {
                _editing = false;
                _applyCell(_cellField.text);
              },
            ),
          ],
          IconButton(
            tooltip: context.t(_ribbonOpen ? 'excel.ribbon_hide' : 'excel.ribbon_show'),
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(
                _ribbonOpen ? Icons.expand_less : Icons.expand_more),
            onPressed: () => _partSetState(() => _ribbonOpen = !_ribbonOpen),
          ),
        ],
      ),
    );
  }

  /// Seçili hücrenin veri doğrulama listesi (yoksa boş).
  List<String> _validationOptions() =>
      _sheet?.validationAt(_selRow, _selCol)?.options ?? const [];

  /// Formül yazarken **işlev adı önerileri**.
  ///
  /// Motor 100'ün üzerinde işlev biliyordu ama kullanıcı adını ezberlemek
  /// zorundaydı (KALANLAR maddesi). Öneriler imlecin solundaki YARIM SÖZCÜKTEN
  /// üretilir: `=TOP` → TOPLA, `=DÜŞ` → DÜŞEYARA. Ayrı bir "işlev sihirbazı"
  /// ekranı yerine satır içi öneri seçildi — telefonda ekran değiştirmeden,
  /// yazma ritmini bozmadan çalışıyor.
  Widget _formulaSuggestions() {
    final names = _currentCompletions();
    if (names.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.only(left: 68, right: 8, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final name in names)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 12),
                  label: Text(name),
                  onPressed: () => _completeFunction(name),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// İmlecin solundaki yarım işlev adı (yoksa boş).
  ///
  /// Yalnız formülde ve **harf** dizisi üzerinde çalışır: `=A1+` sonrası
  /// başvuru yazılıyor olabilir, oraya işlev önermek yanıltıcı olurdu.
  (int, String) _functionPrefixAt() {
    final text = _cellField.text;
    if (!text.startsWith('=')) return (-1, '');
    final sel = _cellField.selection;
    final caret = sel.isValid ? sel.baseOffset : text.length;
    var start = caret.clamp(0, text.length);
    while (start > 1 && _SpreadsheetEditorScreenState._isNameChar(text.codeUnitAt(start - 1))) {
      start--;
    }
    final word = text.substring(start, caret.clamp(0, text.length));
    return word.isEmpty ? (-1, '') : (start, word);
  }

  List<String> _currentCompletions() {
    final (start, word) = _functionPrefixAt();
    if (start < 0 || word.length < 2) return const [];
    // Zaten tam bir işlev adı yazıldıysa öneri göstermeye gerek yok.
    final hits = FormulaEngine.completionsFor(word);
    if (hits.length == 1 && hits.first.length == word.length) return const [];
    return hits;
  }

  /// Yarım adı seçilen işlevle tamamlar ve imleci parantezin içine koyar.
  void _completeFunction(String name) {
    final (start, word) = _functionPrefixAt();
    if (start < 0) return;
    final text = _cellField.text;
    final end = start + word.length;
    final inserted = '$name(';
    final next = text.replaceRange(start, end, inserted);
    _cellField.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    _partSetState(() {});
  }

  Widget _formulaPreview() {
    final sheet = _sheet;
    final text = _cellField.text;
    if (sheet == null || !text.startsWith('=') || text.length < 2) {
      return const SizedBox.shrink();
    }
    final result = _engineFor(sheet).preview(text, _selRow, _selCol);
    if (result.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(70, 0, 12, 4),
      child: Text(
        '= $result',
        style: TextStyle(
          fontSize: 12,
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
