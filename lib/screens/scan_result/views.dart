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
                style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13),
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
          onPageChanged: (i) => _partSetState(() => _index = i),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.file(
                      File(_pages[i].display),
                      key: ValueKey(_pages[i].display),
                      cacheWidth: cacheWidth,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => SizedBox(
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
          child: IgnorePointer(
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: scheme.inverseSurface.withValues(alpha: 0.82),
                  shape: const StadiumBorder(),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    _pages.isEmpty
                        ? ''
                        : '${_index + 1} / ${_pages.length}'
                            '${_pages[_index].filter == ScanFilter.original ? '' : ' · ${context.t(_pages[_index].filter.labelKey)}'}',
                    style: TextStyle(
                      color: scheme.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
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
          onReorderItem: _busy ? (_, __) {} : _reorder,
          proxyDecorator: (child, _, animation) => AnimatedBuilder(
            animation: animation,
            builder: (_, __) => Transform.scale(
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
                        Icon(Icons.note_add_rounded,
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
                    icon: Icons.crop_rounded,
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
                    icon: Icons.auto_awesome_outlined,
                    label: context.t('ss.tool_filter'),
                    onTap: enabled ? _filter : null,
                  ),
                  _ToolButton(
                    icon: Icons.camera_alt_rounded,
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
                      onPressed: _busy ? null : _openPdf,
                      icon: const Icon(AppIcons.pdf, size: 20),
                      label: Text(context.t('scr.open_pdf'),
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
                      style: const TextStyle(fontSize: 14, height: 1.45)),
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
