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
    _updateColWindow(force: true);
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
      _cellField.text != _displayAt(_selRow, _selCol);

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
    final showCommit = pending || _editing;
    return Container(
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsetsDirectional.fromSTEB(6, 2, 2, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ad Kutusu: dokununca "Hücreye git".
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
                    context.type.small.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 20,
            child: VerticalDivider(
              width: 6,
              thickness: 1,
              color: scheme.outlineVariant,
            ),
          ),
          Tooltip(
            message: context.t('excel.fx_library'),
            child: InkWell(
              key: const ValueKey('xl-bar-fx'),
              onTap: _editor == null ? null : _showFunctionLibrary,
              borderRadius: BorderRadius.circular(Radii.control),
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                child: Text(
                  'fx',
                  style: context.type.small.copyWith(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: _editor == null
                        ? scheme.onSurface.withValues(alpha: 0.38)
                        : scheme.primary,
                  ),
                ),
              ),
            ),
          ),
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
              style: context.type.body,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: context.t('excel.cell_content'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
            ),
          ),
          // Veri doğrulama listesi olan hücrede Excel'deki açılır ok.
          if (_hasValidationList())
            IconButton(
              key: const ValueKey('validation-bar-arrow'),
              tooltip: context.t('excel.pick_from_list'),
              icon: const Icon(AppIcons.arrowDropDownCircle, size: 20),
              padding: EdgeInsets.zero,
              onPressed: _pickFromValidation,
            ),
          // ✗ / ✓ yazma sırasında ya da onaylanmamış giriş varken.
          if (showCommit) ...[
            IconButton(
              tooltip: context.t('common.cancel'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(AppIcons.close),
              onPressed: _cancelEdit,
            ),
            IconButton(
              tooltip: context.t('common.apply'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              color: OfficeColors.excel,
              icon: const Icon(AppIcons.check),
              onPressed: () {
                _editing = false;
                _applyCell(_cellField.text);
                _keypadPanel.close();
                _barFocus.unfocus();
                _cellFocus.unfocus();
              },
            ),
          ],
          // Hata açıklaması (Faz 36): hücre #DEĞER! vb. gösteriyorsa "neden?".
          if (!pending && _errorKeyHere() != null)
            IconButton(
              key: const ValueKey('xl-error-why'),
              tooltip: context.t('xp.err_why'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(AppIcons.help),
              onPressed: () => _snack(context.t(_errorKeyHere()!)),
            ),
          IconButton(
            tooltip: context.t(_ribbonOpen ? 'excel.ribbon_hide' : 'excel.ribbon_show'),
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(
                _ribbonOpen ? AppIcons.expandLess : AppIcons.expandMore),
            onPressed: () => _partSetState(() => _ribbonOpen = !_ribbonOpen),
          ),
        ],
      ),
    );
  }

  /// Seçili hücrede veri doğrulama giriş iletisi varsa kompakt, kapatılabilir
  /// ipucu kartı.
  Widget _validationPromptBanner() {
    final v = _sheet?.validationAt(_selRow, _selCol);
    if (v == null || !v.showInputMessage) return const SizedBox.shrink();
    if (_dismissedPromptCell == (_selRow, _selCol)) {
      return const SizedBox.shrink();
    }
    final title = v.promptTitle?.trim() ?? '';
    final body = v.prompt?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('xl-validation-prompt'),
      width: double.infinity,
      color: scheme.secondaryContainer.withValues(alpha: 0.65),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
      child: Row(
        children: [
          Icon(AppIcons.info, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: context.type.small
                    .copyWith(color: scheme.onSecondaryContainer),
                children: [
                  if (title.isNotEmpty)
                    TextSpan(
                      text: body.isEmpty ? title : '$title: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (body.isNotEmpty) TextSpan(text: body),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: const ValueKey('xl-validation-prompt-close'),
            tooltip: context.t('common.close'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            iconSize: 16,
            icon: Icon(AppIcons.close, color: scheme.onSecondaryContainer),
            onPressed: () => _partSetState(
                () => _dismissedPromptCell = (_selRow, _selCol)),
          ),
        ],
      ),
    );
  }

  /// Seçili hücre bir formül hatası gösteriyorsa açıklama anahtarı.
  String? _errorKeyHere() {
    final sheet = _sheet;
    if (sheet == null) return null;
    final raw = sheet.rawAt(_selRow, _selCol);
    if (!raw.startsWith('=') && !raw.startsWith('#')) return null;
    return formulaErrorKey(_engineFor(sheet).displayValue(_selRow, _selCol));
  }

  /// Seçili hücrenin veri doğrulama listesi (yoksa boş). Aralıktan/başka
  /// sayfadan gelen liste burada çözülür — yalnız ok açılınca çağrılır.
  List<String> _validationOptions() {
    final v = _sheet?.validationAt(_selRow, _selCol);
    if (v == null || v.type != 'list') return const [];
    return _validationCheck()?.options(v, _selRow, _selCol) ?? const [];
  }

  /// Seçili hücrede açılır ok var mı — ucuz denetim (çizimde çağrılır;
  /// aralıklı liste burada ÇÖZÜLMEZ). Dosyada ok gizliyse yok.
  bool _hasValidationList() {
    final v = _sheet?.validationAt(_selRow, _selCol);
    if (v == null || v.type != 'list' || v.hideDropDown) return false;
    return v.options?.isNotEmpty ?? v.isRefList;
  }

  /// Formül yazarken **işlev adı önerileri**.
  ///
  /// Motor 100'ün üzerinde işlev biliyordu ama kullanıcı adını ezberlemek
  /// zorundaydı. Öneriler imlecin solundaki YARIM SÖZCÜKTEN
  /// üretilir: `=TOP` → TOPLA, `=DÜŞ` → DÜŞEYARA. Ayrı bir "işlev sihirbazı"
  /// ekranı yerine satır içi öneri seçildi — telefonda ekran değiştirmeden,
  /// yazma ritmini bozmadan çalışıyor.
  Widget _formulaSuggestions() {
    final names = _currentCompletions();
    final completion = _textCompletion();
    if (names.isEmpty && completion != null) {
      // Metin otomatik tamamlama (madde 10): sütunda yazılmış değer.
      final scheme = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        color: scheme.surfaceContainerHigh,
        padding: const EdgeInsetsDirectional.only(start: 68, end: 8, bottom: 4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ActionChip(
            key: const ValueKey('text-completion'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(AppIcons.keyboardArrowRight, size: 16),
            label: Text(completion, style: context.type.small),
            onPressed: () {
              _cellField.value = TextEditingValue(
                  text: completion,
                  selection: TextSelection.collapsed(offset: completion.length));
              _partSetState(() {});
            },
          ),
        ),
      );
    }
    if (names.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsetsDirectional.only(start: 68, end: 8, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final name in names)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  labelStyle: context.type.small,
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
    final result = _engineFor(sheet).preview(_toModel(text).raw, _selRow, _selCol);
    if (result.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsetsDirectional.fromSTEB(70, 0, 12, 4),
      child: Text(
        '= $result',
        style: context.type.small.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
