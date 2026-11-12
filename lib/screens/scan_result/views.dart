part of '../scan_result_screen.dart';

extension _ScanResultScreenViewsPart on _ScanResultScreenState {
  /// "Fatura gibi görünüyor → Faturalar klasörüne taşı" önerisi.
  Widget _classBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final guess = _classGuess!;
    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, Gap.xs, Gap.xs, Gap.xs),
        child: Row(
          children: [
            Icon(AppIcons.ai, size: 20, color: scheme.onPrimaryContainer),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                context.t('scr.class_hint', {
                  'type': context.t(guess.type.labelKey),
                  'folder': guess.type.folder,
                }),
                style: context.type.compact.copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _acceptClassFolder,
              child: Text(context.t('scr.class_move')),
            ),
            IconButton(
              tooltip: context.t('common.close'),
              icon: const Icon(AppIcons.close, size: 18),
              onPressed: () => _partSetState(() => _classGuess = null),
            ),
          ],
        ),
      ),
    );
  }

  /// Ad + canlı kayıt durumu. Kullanıcı nereye ve HANGİ ADLA yazıldığını
  /// görmeden "kaydedildi" demek dosyayı aratmak demekti; ada dokunmak adı
  /// değiştirir.
  Widget _titleBlock(BuildContext context) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    final (IconData? icon, Color color, String text) = switch (_saveState) {
      _SaveState.saving => (null, faint, context.t('ss.saving')),
      _SaveState.failed => (
          AppIcons.error,
          theme.colorScheme.error,
          context.t('ss.save_failed')
        ),
      _SaveState.saved => (
          AppIcons.checkCircle,
          Paper.success(context),
          context.t('ss.saved', {'folder': p.basename(_folder)})
        ),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.control),
      onTap: _busy
          ? null
          : (_saveState == _SaveState.failed
              ? () {
                  _dirty = true;
                  unawaited(_save());
                }
              : _rename),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.basenameWithoutExtension(_pdfPath),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon == null)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.6, color: faint),
                  )
                else
                  Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagesView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Bellek: 2480 px'lik sayfa tam çözülürse ~35 MB; ekranın iki katı
    // çözünürlük yakınlaştırmada da net ve belleği yarıya indiriyor.
    final cacheWidth = (width * dpr * 2).round().clamp(600, 2480);
    return Stack(
      children: [
        PageView.builder(
          controller: _pager,
          itemCount: _pages.length,
          onPageChanged: (i) {
            _partSetState(() => _index = i);
            unawaited(_measureVisible());
          },
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Padding(
                // Alt pay sayaç hapına yer bırakır: hap sayfanın üstüne
                // binmesin.
                padding: const EdgeInsets.fromLTRB(
                    Gap.lg, Gap.md, Gap.lg, Gap.xl + Gap.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.page,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shade.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image(
                      image: FmFileImage(_pages[i].display,
                          cacheWidth: cacheWidth),
                      key: ValueKey(_pages[i].display),
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => SizedBox(
                        width: 220,
                        height: 300,
                        child: Center(
                          child: Text(context.t('sr.page_failed'),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Sayfa sayacı + filtre adı: hangi sayfaya, hangi görünümle
        // bakıldığı tek bakışta.
        Positioned(
          left: 0,
          right: 0,
          bottom: Gap.xs,
          child: Center(
            child: Builder(builder: (context) {
              final filtered = _pages.isNotEmpty &&
                  _pages[_index].filter != ScanFilter.original;
              final label = Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                    12, 4, filtered ? 6 : 12, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _pages.isEmpty
                            ? ''
                            : '${_index + 1} / ${_pages.length}'
                                '${filtered ? ' · ${context.t(_pages[_index].filter.labelKey)}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.small.copyWith(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (filtered) ...[
                      const SizedBox(width: 6),
                      Icon(AppIcons.close,
                          size: 16, color: scheme.onInverseSurface),
                    ],
                  ],
                ),
              );
              // Filtre yokken gösterge dokunuşu yutmaz (altındaki sayfa
              // kaydırılabilsin); filtre varken ✕ ile tek dokunuşta kalkar.
              return IgnorePointer(
                ignoring: !filtered,
                child: Material(
                color: scheme.inverseSurface.withValues(alpha: 0.82),
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: filtered
                    ? Tooltip(
                        message: context.t('ss.filter_clear'),
                        child: InkWell(
                          key: const ValueKey('scan-filter-clear'),
                          onTap: _busy ? null : _clearFilter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 36),
                            child: Center(widthFactor: 1, child: label),
                          ),
                        ),
                      )
                    : label,
                ),
              );
            }),
          ),
        ),
        if (_qualityHint != null)
          Positioned(
            left: Gap.md,
            right: Gap.md,
            top: Gap.xs,
            child: _qualityBanner(context, _qualityHint!),
          ),
        if (_work != null)
          Positioned.fill(
            child: ColoredBox(
              color: scheme.surface.withValues(alpha: 0.55),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg, vertical: Gap.md),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4)),
                        const SizedBox(width: Gap.md),
                        Text(_work!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Küçük resim şeridi: dokun = git, basılı tut + sürükle = sıra, "+" =
  /// sayfa ekle.
  /// Önerilen eylem şeridi: "Kimlik içeriyor → Kasaya taşı" ya da
  /// "Fiş → Gider satırı ekle".
  Widget _actionBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vault = _suggestedAction == 'vault';
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, Gap.xs, Gap.xs, Gap.xs),
        child: Row(
          children: [
            Icon(vault ? AppIcons.vault : AppIcons.receiptLong,
                size: 20, color: scheme.onSecondaryContainer),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                context.t(vault ? 'sa.vault_hint' : 'sa.expense_hint'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : (vault ? _moveToVault : _addExpense),
              child: Text(context.t(vault ? 'sa.vault_do' : 'sa.expense_do')),
            ),
            IconButton(
              tooltip: context.t('common.close'),
              icon: const Icon(AppIcons.close, size: 18),
              onPressed: () => _partSetState(() => _actionDismissed = true),
            ),
          ],
        ),
      ),
    );
  }

  /// Görünen sayfanın kalite önerisi (bulanık / karanlık / eğik) — kullanıcı
  /// kapattıysa ya da ölçüm yoksa null.
  String? get _qualityHint {
    if (_pages.isEmpty || _busy) return null;
    final path = _pages[_index].display;
    if (_qualityDismissed.contains(path)) return null;
    return _quality[path]?.hint;
  }

  /// "Sayfa bulanık → Yeniden çek", "Işık az → Feneri açıp yeniden çek",
  /// "Sayfa eğik → Düzleştir" (Faz 35 / madde 5).
  Widget _qualityBanner(BuildContext context, String hint) {
    final scheme = Theme.of(context).colorScheme;
    final path = _pages[_index].display;
    final (icon, text, actionKey, action) = switch (hint) {
      'dark' => (AppIcons.lightbulbOutline, 'sq.dark', 'ss.tool_retake', _retake),
      'skewed' => (AppIcons.straighten, 'sq.skewed', 'sr.straighten', _straighten),
      _ => (AppIcons.warning, 'sq.blurry', 'ss.tool_retake', _retake),
    };
    return Material(
      color: scheme.tertiaryContainer,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.sm, 2, 2, 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onTertiaryContainer),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(context.t(text),
                  style: context.type.small
                      .copyWith(color: scheme.onTertiaryContainer)),
            ),
            TextButton(onPressed: action, child: Text(context.t(actionKey))),
            IconButton(
              tooltip: context.t('common.close'),
              icon: const Icon(AppIcons.close, size: 16),
              onPressed: () =>
                  _partSetState(() => _qualityDismissed.add(path)),
            ),
          ],
        ),
      ),
    );
  }

  /// **Belge türü hapları** (Faz 35 / madde 1): Belge · Kimlik · Kitap · Fiş
  /// · Beyaz tahta · Kartvizit · Fotoğraf. Seçim filtreyi ve sayfa düzenini
  /// ayarlar; kimlik iki yüzü tek A4'te birleştirir, kitap çift sayfayı böler.
  Widget _kindPills(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          children: [
            for (final kind in ScanKind.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Gap.xs),
                child: ChoiceChip(
                  label: Text(context.t(kind.labelKey)),
                  selected: kind == _kind,
                  onSelected: _busy ? null : (_) => _applyKind(kind),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// **Toplu inceleme ızgarası** (Faz 35 / madde 2): tüm sayfalar bir arada;
  /// basılı tutup başka bir sayfanın üstüne bırakmak sırayı değiştirir,
  /// sayfanın menüsü döndür / filtre / kırp / sil, sondaki kutu sayfa ekler.
  /// Hücre boyu sabit (`childAspectRatio`), görseller `cacheWidth`'li.
  Widget _gridView(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = (box.maxWidth / 132).floor().clamp(2, 6);
      return GridView.builder(
        padding: const EdgeInsets.all(Gap.md),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: Gap.md,
          crossAxisSpacing: Gap.md,
          childAspectRatio: 0.7,
        ),
        itemCount: _pages.length + 1,
        itemBuilder: (context, i) {
          if (i == _pages.length) {
            return _GridAddTile(onTap: _busy ? null : _addPages);
          }
          return RepaintBoundary(
            child: _GridPageTile(
              key: ValueKey('${_pages[i].source}#$i'),
              path: _pages[i].display,
              index: i,
              selected: i == _index,
              enabled: !_busy,
              onOpen: () {
                _partSetState(() {
                  _index = i;
                  _grid = false;
                  _resetPager();
                });
              },
              onMove: (from) {
                if (from == i) return;
                _reorder(from, i);
              },
              onAction: (action) => _gridAction(i, action),
            ),
          );
        },
      );
    });
  }

  Widget _thumbStrip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: 92,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm + 4, vertical: Gap.sm + 2),
          itemCount: _pages.length,
          onReorderItem: _busy ? (_, _) {} : _reorder,
          proxyDecorator: (child, _, animation) => AnimatedBuilder(
            animation: animation,
            builder: (_, _) => Transform.scale(
              scale: 1 + 0.08 * Curves.easeOut.transform(animation.value),
              child: Material(
                color: Colors.transparent,
                elevation: 6 * animation.value,
                child: child,
              ),
            ),
          ),
          // **Yazılı, vurgulu "Sayfa ekle" kutusu** (2026-10-18, kullanıcı:
          // *"sayfa ekle daha açıklayıcı olmalı"*). Eskiden yalnız "+" olan
          // 54 dp'lik çerçeveli bir kareydi; ML Kit'te Sonraki'ye erken basan
          // kullanıcı buradan sayfa ekleyebileceğini anlamıyordu.
          footer: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Tooltip(
              message: context.t('scr.add_pages_hint'),
              child: Material(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _busy ? null : _addPages,
                  child: Container(
                    width: 84,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scheme.primary, width: 1.4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.noteAdd,
                            color: scheme.onPrimaryContainer, size: 24),
                        const SizedBox(height: 2),
                        Text(
                          context.t('scr.add_pages'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
            key: ValueKey('${_pages[i].source}#$i'),
            index: i,
            enabled: !_busy,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _Thumb(
                path: _pages[i].display,
                number: i + 1,
                selected: i == _index,
                onTap: () => _goTo(i),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = !_busy && _pages.isNotEmpty;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.sm, Gap.xs, 0),
              child: Row(
                children: [
                  _ToolButton(
                    icon: AppIcons.crop,
                    label: context.t('ss.tool_crop'),
                    onTap: enabled ? _crop : null,
                    highlight: true,
                  ),
                  _ToolButton(
                    icon: AppIcons.rotate,
                    label: context.t('ss.tool_rotate'),
                    onTap: enabled ? _rotate : null,
                  ),
                  _ToolButton(
                    icon: AppIcons.ai,
                    label: context.t('ss.tool_filter'),
                    onTap: enabled ? _filter : null,
                  ),
                  _ToolButton(
                    icon: AppIcons.cameraAlt,
                    label: context.t('ss.tool_retake'),
                    onTap: enabled ? _retake : null,
                  ),
                  _ToolButton(
                    icon: AppIcons.delete,
                    label: context.t('ss.tool_delete'),
                    onTap: enabled ? _delete : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _busy ? null : _share,
                      icon: const Icon(AppIcons.share, size: 20),
                      label: Text(context.t('common.share'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _busy ? null : _saveAndReveal,
                      icon: const Icon(AppIcons.save, size: 20),
                      label: Text(context.t('common.save'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textView() {
    final text = _text;
    if (text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t('scr.no_text_yet'), textAlign: TextAlign.center),
              const SizedBox(height: Gap.md),
              FilledButton.icon(
                onPressed: _busy ? null : _recognize,
                icon: const Icon(AppIcons.ocr),
                label: Text(context.t('vw.ocr_short')),
              ),
            ],
          ),
        ),
      );
    }
    // Sayfa sayfa kart: metin tek yığın değil, sayfa başlıklarıyla ve
    // seçilebilir.
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl),
      children: [
        for (final page in text)
          Card(
            margin: const EdgeInsets.only(bottom: Gap.sm),
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pages.length > 1)
                    Text(
                      context.t('tf.page_header', {'n': page.number}),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  const SizedBox(height: Gap.xs),
                  SelectableText(page.text,
                      style: context.type.body.copyWith(height: 1.45)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _textBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = _text.isNotEmpty;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(Gap.sm + 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: !hasText
                          ? null
                          : () async {
                              final copied = context.t('vw.copied_all');
                              await Clipboard.setData(
                                  ClipboardData(text: _plainText(context)));
                              if (mounted) _snack(copied);
                            },
                      icon: const Icon(AppIcons.clipCopy, size: 20),
                      label: Text(context.t('common.copy'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _busy ? null : _translate,
                      icon: const Icon(AppIcons.translate, size: 20),
                      label: Text(context.t('common.translate'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
