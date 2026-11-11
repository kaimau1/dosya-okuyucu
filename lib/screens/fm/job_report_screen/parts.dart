part of '../job_report_screen.dart';

/// [_JobReportScreenState]'in çizim yardımcıları (A4.1 bölmesi, davranış aynı).
extension _JobReportScreenStateParts on _JobReportScreenState {
  /// Düz cümleyle "ne oldu, şimdi ne yapmalıyım".
  Widget _summary(
      BuildContext context, List<MapEntry<String, List<JobChange>>> groups) {
    final changes = _job.changes;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tags = changes.where((c) => c.kind == 'tag').toList();
    final applied = changes.where((c) => c.applied).length;
    final rejected = changes.where((c) => c.rejected).length;
    final pending = changes.where((c) => c.pending).length;
    final files = {for (final c in changes) c.path}.length;
    final total = changes.length;
    final String headline;
    final String status;
    if (tags.isNotEmpty) {
      headline = context.t('jr.headline_tags',
          {'files': files, 'groups': groups.length, 'n': tags.length});
      status = applied == 0 && rejected == 0
          ? context.t('jr.status_none')
          : pending == 0 && applied > 0
              ? context.t('jr.status_all', {'n': applied, 'x': rejected})
              : context.t('jr.status_some',
                  {'n': applied, 'p': pending, 'x': rejected});
    } else {
      headline = context.t('jr.headline', {'files': files, 'n': total});
      status = context.t('jr.summary', {
        'groups': groups.length,
        'files': files,
        'applied': applied,
        'pending': pending,
      });
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.ai, color: scheme.primary),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(headline,
                        key: const ValueKey('jr-headline'),
                        style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(status,
                  key: const ValueKey('jr-status'),
                  style: theme.textTheme.bodyMedium),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Gap.xs),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : applied / total,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: Gap.md),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    if (pending > 0)
                      FilledButton.icon(
                        key: const ValueKey('jr-apply-all'),
                        onPressed: _busy
                            ? null
                            : () => _setApplied(changes, true),
                        icon: const Icon(AppIcons.check, size: 18),
                        label: Text(context.t('jr.apply_all', {'n': pending})),
                      ),
                    if (applied > 0)
                      OutlinedButton.icon(
                        key: const ValueKey('jr-undo-all'),
                        onPressed: _busy
                            ? null
                            : () => _setApplied(changes, false),
                        icon: const Icon(AppIcons.undo, size: 18),
                        label: Text(context.t('jr.undo_all')),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(context.t('jr.hint'),
                    style: context.type.small
                        .copyWith(color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Görünüm seçici + etiket çipleri.
  Widget _controls(
      BuildContext context, List<MapEntry<String, List<JobChange>>> groups) {
    final tagGroups =
        groups.where((g) => g.value.first.kind == 'tag').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          child: SegmentedButton<_View>(
            segments: [
              ButtonSegment(
                  value: _View.tags,
                  icon: const Icon(AppIcons.labelOutline),
                  label: Text(context.t('jr.by_tag'),
                      key: const ValueKey('jr-view-tags'))),
              ButtonSegment(
                  value: _View.files,
                  icon: const Icon(AppIcons.layoutGrid),
                  label: Text(context.t('jr.by_file'),
                      key: const ValueKey('jr-view-files'))),
            ],
            selected: {_view},
            onSelectionChanged: (s) => _update(() => _view = s.first),
          ),
        ),
        if (_view == _View.tags && tagGroups.length > 1)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md, vertical: Gap.sm),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: Gap.sm),
                  child: ChoiceChip(
                    label: Text(context.t('jr.all_tags')),
                    selected: _only == null,
                    onSelected: (_) => _update(() => _only = null),
                  ),
                ),
                for (final g in tagGroups)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Gap.sm),
                    child: ChoiceChip(
                      key: ValueKey('jr-chip-${g.value.first.value}'),
                      label: Text(
                          '#${g.value.first.value}  ${g.value.length}'),
                      selected: _only == g.value.first.value,
                      onSelected: (on) => _update(
                          () => _only = on ? g.value.first.value : null),
                    ),
                  ),
              ],
            ),
          )
        else
          const SizedBox(height: Gap.sm),
      ],
    );
  }

  // ── Etikete göre ──────────────────────────────────────────────────────────

  List<Widget> _groupSlivers(BuildContext context, List<JobChange> list) {
    final first = list.first;
    final value = first.value;
    final isTag = first.kind == 'tag';
    final width = MediaQuery.sizeOf(context).width;
    final cols = ((width - 2 * Gap.md) / 104).floor().clamp(3, 12);
    final collapsedCount = cols * 2;
    final expanded = _only == value || _expanded.contains(value);
    final shown = expanded ? list.length : list.length.clamp(0, collapsedCount);
    return [
      SliverToBoxAdapter(child: _groupHeader(context, list)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: Gap.xs,
            crossAxisSpacing: Gap.xs,
          ),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _tile(ctx, list[i], list, isTag),
            childCount: shown,
          ),
        ),
      ),
      if (shown < list.length)
        SliverToBoxAdapter(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: Gap.sm),
              child: TextButton.icon(
                key: ValueKey('jr-more-$value'),
                onPressed: () => _update(() => _expanded.add(value)),
                icon: const Icon(AppIcons.expandMore),
                label: Text(context.t('jr.show_all', {'n': list.length})),
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: Gap.md)),
    ];
  }

  Widget _groupHeader(BuildContext context, List<JobChange> list) {
    final first = list.first;
    final value = first.value;
    final isTag = first.kind == 'tag';
    final applied = list.where((c) => c.applied).length;
    final rejected = list.where((c) => c.rejected).length;
    final pending = list.length - applied - rejected;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parts = <String>[
      context.t('jr.n_files', {'n': list.length}),
      if (applied > 0) context.t('jr.n_applied', {'n': applied}),
      if (pending > 0) context.t('jr.n_pending', {'n': pending}),
      if (rejected > 0) context.t('jr.n_rejected', {'n': rejected}),
    ];
    return Padding(
      key: ValueKey('jr-group-${first.kind}-$value'),
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, Gap.sm, Gap.xs, Gap.sm),
      child: Row(
        children: [
          Icon(
            isTag
                ? (applied > 0 ? AppIcons.tag : AppIcons.labelOutline)
                : first.kind == 'delete' || first.kind == 'trash'
                    ? AppIcons.delete
                    : AppIcons.edit,
            color: applied > 0 ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isTag
                        ? '#$value'
                        : (first.kind == 'move' || first.kind == 'copy')
                            ? context.t('jr.kind_${first.kind}', {'dir': value})
                            : const {'rename', 'trash', 'delete', 'create'}
                                    .contains(first.kind)
                                ? context.t('jr.kind_${first.kind}')
                                : value,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(parts.join(' · '),
                    style: context.type.small
                        .copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (isTag && pending > 0)
            TextButton(
              key: ValueKey('jr-apply-$value'),
              onPressed: _busy ? null : () => _setApplied(list, true),
              child: Text(context.t('jr.apply_n', {'n': pending})),
            )
          else if (isTag && applied > 0)
            TextButton(
              key: ValueKey('jr-undo-$value'),
              onPressed: _busy ? null : () => _setApplied(list, false),
              child: Text(context.t('common.undo')),
            ),
          PopupMenuButton<String>(
            key: ValueKey('jr-menu-$value'),
            enabled: !_busy,
            onSelected: (a) {
              switch (a) {
                case 'apply':
                  _setApplied(list, true);
                case 'undo':
                  _setApplied(list, false);
                case 'rename':
                  _renameTag(value, list);
                case 'remove':
                  _removeGroup(value, list);
                case 'move':
                  _moveGroup(list);
                case 'unmove':
                  _undoMove(list);
                case 'unrename':
                  _undoRename(list);
                case 'untrash':
                  _untrash(list);
                case 'trashnew':
                  _trashCreated(list);
              }
            },
            itemBuilder: (ctx) => [
              if (isTag && pending > 0)
                PopupMenuItem(value: 'apply', child: Text(ctx.t('jr.apply'))),
              if (isTag && applied > 0)
                PopupMenuItem(value: 'undo', child: Text(ctx.t('common.undo'))),
              if (isTag)
                PopupMenuItem(
                    value: 'rename', child: Text(ctx.t('jr.rename_tag'))),
              if (isTag)
                PopupMenuItem(
                    value: 'remove', child: Text(ctx.t('jr.remove_tag'))),
              if (first.kind == 'move')
                PopupMenuItem(
                    value: 'unmove', child: Text(ctx.t('jr.undo_move'))),
              if (first.kind == 'rename')
                PopupMenuItem(
                    key: const ValueKey('jr-unrename'),
                    value: 'unrename',
                    child: Text(ctx.t('jr.undo_rename'))),
              if (first.kind == 'trash')
                PopupMenuItem(
                    key: const ValueKey('jr-untrash'),
                    value: 'untrash',
                    child: Text(ctx.t('jr.untrash'))),
              if (first.kind == 'create')
                PopupMenuItem(
                    key: const ValueKey('jr-trashnew'),
                    value: 'trashnew',
                    child: Text(ctx.t('jr.trash_created'))),
              // Kalıcı silinen dosya artık yok — taşınacak bir şey kalmadı.
              if (first.kind != 'delete')
                PopupMenuItem(
                    value: 'move', child: Text(ctx.t('jr.move_files'))),
            ],
          ),
        ],
      ),
    );
  }

  /// Izgara hücresi: küçük resim + durum rozeti.
  Widget _tile(
      BuildContext context, JobChange c, List<JobChange> group, bool isTag) {
    final entry = _entry(c.path);
    final scheme = Theme.of(context).colorScheme;
    final name = p.basename(c.path);
    final media = entry != null &&
        (entry.category == FmCategory.image ||
            entry.category == FmCategory.video);
    final state = c.applied
        ? context.t('jr.state_applied')
        : c.rejected
            ? context.t('jr.state_rejected')
            : context.t('jr.state_pending');
    return Semantics(
      button: true,
      label: '$name, $state',
      excludeSemantics: true,
      child: Material(
        key: ValueKey('jr-tile-${c.value}-${c.path}'),
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Gap.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isTag ? () => _toggle(c) : () => _open(c, group),
          onLongPress: () => _fileMenu(c, group),
          child: LayoutBuilder(builder: (ctx, box) {
            final side = box.maxWidth;
            final Widget thumb;
            if (entry == null) {
              thumb = Center(
                child: Icon(AppIcons.brokenImage,
                    color: scheme.outline, size: side * 0.35),
              );
            } else if (media) {
              thumb = FmEntryIcon(
                entry: entry,
                size: side,
                radius: 0,
                thumbnails: widget.thumbnails,
              );
            } else {
              thumb = Padding(
                padding: const EdgeInsets.all(Gap.xs),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: FmEntryIcon(
                          entry: entry,
                          size: side * 0.5,
                          thumbnails: widget.thumbnails,
                        ),
                      ),
                    ),
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.type.micro),
                  ],
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                AnimatedOpacity(
                  opacity: c.rejected ? 0.3 : 1,
                  duration: Motion.short,
                  child: thumb,
                ),
                if (isTag)
                  PositionedDirectional(
                    top: Gap.xs,
                    end: Gap.xs,
                    child: _StateBadge(change: c),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Dosyaya göre ──────────────────────────────────────────────────────────

  Widget _fileSliver(BuildContext context) {
    final byFile = <String, List<JobChange>>{};
    for (final c in _job.changes) {
      (byFile[c.path] ??= []).add(c);
    }
    final files = byFile.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _fileRow(ctx, files[i].key, files[i].value),
        childCount: files.length,
      ),
    );
  }

  Widget _fileRow(BuildContext context, String path, List<JobChange> list) {
    final entry = _entry(path);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('jr-file-$path'),
      onTap: () => _open(list.first, list),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Gap.sm),
              child: SizedBox(
                width: 72,
                height: 72,
                child: entry == null
                    ? ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(AppIcons.brokenImage, color: scheme.outline))
                    : FmEntryIcon(
                        entry: entry,
                        size: 72,
                        radius: 0,
                        thumbnails: widget.thumbnails),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.basename(path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge),
                  Text(
                      entry == null
                          ? context.t('jr.missing')
                          : p.basename(p.dirname(path)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.small
                          .copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: Gap.xs),
                  Wrap(
                    spacing: Gap.xs,
                    runSpacing: Gap.xs,
                    children: [
                      for (final c in list)
                        if (c.kind == 'tag')
                          FilterChip(
                            key: ValueKey('jr-fchip-${c.value}-$path'),
                            visualDensity: VisualDensity.compact,
                            label: Text('#${c.value}',
                                style: c.rejected
                                    ? const TextStyle(
                                        decoration: TextDecoration.lineThrough)
                                    : null),
                            avatar: c.pending
                                ? Icon(AppIcons.ai,
                                    size: 16, color: scheme.primary)
                                : null,
                            selected: c.applied,
                            tooltip: c.applied
                                ? context.t('jr.state_applied')
                                : c.rejected
                                    ? context.t('jr.state_rejected')
                                    : context.t('jr.state_pending'),
                            onSelected: _busy
                                ? null
                                : (_) => _toggle(c, applyNow: true),
                          )
                        else
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(c.value),
                          ),
                    ],
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

/// Hücrenin köşesindeki durum: ✓ uygulandı (dolu) · ✓ öneri (boş halka) ·
/// ✕ çıkarıldı.
class _StateBadge extends StatelessWidget {
  final JobChange change;
  const _StateBadge({required this.change});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final applied = change.applied;
    final rejected = change.rejected;
    final bg = applied
        ? scheme.primary
        : rejected
            ? scheme.error
            : scheme.surface.withValues(alpha: 0.85);
    final fg = applied
        ? scheme.onPrimary
        : rejected
            ? scheme.onError
            : scheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
            color: applied || rejected ? bg : scheme.primary, width: 1.5),
        boxShadow: [
          BoxShadow(blurRadius: 3, color: scheme.shadow.withValues(alpha: 0.35)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(rejected ? AppIcons.close : AppIcons.check,
            size: 16, color: fg),
      ),
    );
  }
}
