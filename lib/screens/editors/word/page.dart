part of '../word_editor_screen.dart';

extension _WordEditorScreenPagePart on _WordEditorScreenState {
  /// Yedek düz metin editörü: paragraf bazlı biçim (B/I/U, hizalama) +
  /// paragraf ekle/sil — canlı düzenlemede olmayan yapısal işlemler burada.
  Widget _buildPage(DocxEditor editor) {
    return Column(
      children: [
        _plainFormatBar(),
        Expanded(
          child: SingleChildScrollView(
            // Alt sistem çubuğu + FAB için nefes payı (edge-to-edge çakışmasın).
            padding: EdgeInsets.fromLTRB(
                12, 20, 12, MediaQuery.paddingOf(context).bottom + 88),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 820),
                decoration: BoxDecoration(
                  // Belgenin sayfası beyaz (bkz. Paper.docSurface): kağıt
                  // dokusu uygulamanın kabuğuna ait, belgenin içine değil.
                  color: Paper.docSurface(context),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shade.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(56, 64, 56, 64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final para in editor.paragraphs) _paragraphField(para),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addParagraph(null),
                        icon: const Icon(AppIcons.add, size: 18),
                        label: Text(context.t('word.add_paragraph')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Kalın/italik/altı çizili + hizalama + paragraf ekle/sil araç çubuğu.
  /// Seçili paragraf ([_sel]) üzerinde çalışır (yedek editör modu).
  Widget _plainFormatBar() {
    final scheme = Theme.of(context).colorScheme;
    final sel = _sel;
    final enabled = sel != null;

    Widget toggle(IconData icon, String tip, bool active, VoidCallback onTap) =>
        IconButton(
          tooltip: tip,
          isSelected: active,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          style: active
              ? IconButton.styleFrom(backgroundColor: scheme.primaryContainer)
              : null,
          icon: Icon(icon),
          onPressed: enabled ? onTap : null,
        );

    void setAlign(String a) {
      final p = _sel;
      if (p == null) return;
      _partSetState(() {
        p.align = a;
        _dirty = true;
      });
    }

    void toggleBool(void Function(DocxParagraph p) apply) {
      final p = _sel;
      if (p == null) return;
      _partSetState(() {
        apply(p);
        _dirty = true;
      });
    }

    // Madde/numara listesi: gerçek numbering.xml riskli (bkz. HAFIZA) → düz
    // metin öneki (`• ` / `N. `). Numara, üstteki ardışık numaralı paragraflara
    // göre sıralanır.
    void applyList({required bool numbered}) {
      final p = _sel;
      final ed = _editor;
      if (p == null || ed == null) return;
      _partSetState(() {
        if (numbered) {
          if (hasNumber(p.text)) {
            p.text = stripListPrefix(p.text);
          } else {
            final idx = ed.paragraphs.indexOf(p);
            var n = 1;
            for (var i = idx - 1; i >= 0; i--) {
              if (hasNumber(ed.paragraphs[i].text)) {
                n++;
              } else {
                break;
              }
            }
            p.text = toggleNumber(p.text, n);
          }
        } else {
          p.text = toggleBullet(p.text);
        }
        _dirty = true;
      });
    }

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            toggle(OfficeIcons.bold, context.t('common.bold'),
                sel?.bold ?? false, () => toggleBool((p) => p.bold = !p.bold)),
            toggle(
                OfficeIcons.italic,
                context.t('common.italic'),
                sel?.italic ?? false,
                () => toggleBool((p) => p.italic = !p.italic)),
            toggle(
                OfficeIcons.underline,
                context.t('common.underline'),
                sel?.underline ?? false,
                () => toggleBool((p) => p.underline = !p.underline)),
            _sep(scheme),
            toggle(OfficeIcons.alignLeft, context.t('common.align_left'),
                sel?.align == 'left', () => setAlign('left')),
            toggle(OfficeIcons.alignCenter, context.t('common.align_center'),
                sel?.align == 'center', () => setAlign('center')),
            toggle(OfficeIcons.alignRight, context.t('common.align_right'),
                sel?.align == 'right', () => setAlign('right')),
            toggle(OfficeIcons.alignJustify, context.t('common.align_justify'),
                sel?.align == 'both', () => setAlign('both')),
            _sep(scheme),
            toggle(
                OfficeIcons.bullets,
                context.t('word.bullet_list'),
                sel != null && hasBullet(sel.text),
                () => applyList(numbered: false)),
            toggle(
                OfficeIcons.numbering,
                context.t('word.numbered_list'),
                sel != null && hasNumber(sel.text),
                () => applyList(numbered: true)),
            _sep(scheme),
            IconButton(
              tooltip: context.t('word.add_paragraph_below'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(AppIcons.playlistAdd),
              onPressed: enabled ? () => _addParagraph(sel) : null,
            ),
            IconButton(
              tooltip: context.t('word.delete_paragraph'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(OfficeIcons.deleteCells),
              onPressed: enabled ? () => _deleteParagraph(sel) : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Araç çubuğu bölümleri arası dikey ayraç (sabit boyut → layout güvenli).
  Widget _sep(ColorScheme scheme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(width: 1, height: 22, color: scheme.outlineVariant),
      );

  void _addParagraph(DocxParagraph? after) {
    final editor = _editor;
    if (editor == null) return;
    final para = editor.addParagraphAfter(after);
    final slot = editor.slotOf(para);
    _undo.record(CallbackUndoStep(
      'word.undo_add_paragraph',
      () => editor.restoreParagraph(para, slot),
      () => editor.deleteParagraph(para),
    ));
    _partSetState(() {
      _sel = para;
      _dirty = true;
    });
  }

  void _deleteParagraph(DocxParagraph para) {
    final editor = _editor;
    if (editor == null) return;
    // Konum silmeden ÖNCE alınır: geri alırken paragraf sona değil KENDİ
    // yerine dönmeli (başlık altındaki madde başka yere düşerse belge bozulur).
    final slot = editor.slotOf(para);
    editor.deleteParagraph(para);
    _undo.record(CallbackUndoStep(
      'word.undo_delete_paragraph',
      () => editor.deleteParagraph(para),
      () => editor.restoreParagraph(para, slot),
    ));
    _partSetState(() {
      if (identical(_sel, para)) _sel = null;
      _dirty = true;
    });
  }

  void _undoStep() {
    final step = _undo.undo();
    if (step == null) return;
    _afterHistory(step.label, undone: true);
  }

  void _redoStep() {
    final step = _undo.redo();
    if (step == null) return;
    _afterHistory(step.label, undone: false);
  }

  void _afterHistory(String label, {required bool undone}) {
    final paras = _editor?.paragraphs ?? const <DocxParagraph>[];
    if (_sel != null && !paras.any((p) => identical(p, _sel))) _sel = null;
    _partSetState(() => _dirty = true);
    _snack(context
        .t(undone ? 'word.undone' : 'word.redone', {'what': context.t(label)}));
  }

  Widget _paragraphField(DocxParagraph para) {
    final theme = Theme.of(context);
    final selected = identical(_sel, para);
    double baseSize;
    FontWeight baseWeight;
    if (para.heading) {
      baseSize = para.level == 0
          ? 26.0
          : para.level == 1
              ? 22.0
              : 18.0;
      baseWeight = FontWeight.bold;
    } else {
      baseSize = 15;
      baseWeight = FontWeight.normal;
    }
    final style = TextStyle(
      fontSize: baseSize,
      fontWeight: para.bold ? FontWeight.bold : baseWeight,
      fontStyle: para.italic ? FontStyle.italic : FontStyle.normal,
      decoration:
          para.underline ? TextDecoration.underline : TextDecoration.none,
      color: theme.colorScheme.onSurface,
      height: para.heading ? 1.3 : 1.5,
    );

    // Paragrafın kendi yönü (`w:pPr/w:bidi`). Arapça/İbranice belgede metin
    // sağdan başlar; karışık (Arapça + Latin) satırlarda kelime sırası da
    // taban yöne göre çözülür — yön verilmezse aynı satır GÖRÜNÜR biçimde
    // yanlış sıralanır. Seçim şeridi ve iç boşluk da yönle birlikte döner
    // (`BorderDirectional`/`EdgeInsetsDirectional`).
    return Directionality(
      textDirection: para.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        margin: EdgeInsets.only(bottom: para.heading ? 10 : 6),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: TextFormField(
          key: ObjectKey(para),
          initialValue: para.text,
          onTap: () {
            if (!identical(_sel, para)) _partSetState(() => _sel = para);
          },
          onChanged: (v) {
            para.text = v;
            if (!_dirty) _partSetState(() => _dirty = true);
          },
          style: style,
          textAlign: _textAlign(para),
          maxLines: null,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  /// Paragrafın ekrandaki hizalaması.
  ///
  /// Dosyada hizalama YAZMIYORSA (`hasExplicitAlign == false`) `TextAlign.start`
  /// kullanılır: soldan sağa paragrafta sol, sağdan solada sağ. Eskiden koşulsuz
  /// `TextAlign.left` dönüyordu — Arapça belgede her paragraf sola yapışıyordu.
  /// Dosyada AÇIKÇA yazan `left`/`right` ise mutlaktır (Word de aynalamaz).
  TextAlign _textAlign(DocxParagraph p) => switch (p.align) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'both' => TextAlign.justify,
        _ => p.hasExplicitAlign ? TextAlign.left : TextAlign.start,
      };
}
