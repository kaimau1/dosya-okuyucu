part of '../ai_hub_screen.dart';

/// Sekmenin en üstündeki tek satırlık "bu sekme ne" açıklaması.
///
/// Kullanıcı (2026-11-07): *"ne yapıyor hiç anlaşılmıyor"* — sekmeler
/// açıklamasız listelerdi; özellikle "Etiketler"in dosyaları bir yere
/// taşıdığı sanılıyordu (oysa yalnız bir görünüm).
class _TabIntro extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;

  const _TabIntro({required this.icon, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    final faint = Paper.faint(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, Gap.sm, Gap.md, 0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: faint),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(text, style: context.type.small.copyWith(color: faint)),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Gap.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ── sekme 3: türler ─────────────────────────────────────────────────────────

class _TypesTab extends StatefulWidget {
  const _TypesTab();

  @override
  State<_TypesTab> createState() => _TypesTabState();
}

class _TypesTabState extends State<_TypesTab>
    with AutomaticKeepAliveClientMixin {
  /// null = hepsi; [_important] = yalnız önemli; diğerleri kanonik tür.
  String? _filter;
  static const _important = '\u0000important';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final all = AiBuckets.of(AiBucket.all);
        if (all.isEmpty) {
          return _EmptyHint(
            icon: AppIcons.labelOutline,
            title: context.t('aih.tags_empty'),
            body: context.t('aih.tags_empty_sub'),
          );
        }
        final counts = AiBuckets.typeCounts(all);
        final importantCount =
            AiBuckets.of(AiBucket.important, source: all).length;
        // Yeniden analizden sonra seçili tür artık yoksa süzgeç düşer.
        if (_filter != null &&
            _filter != _important &&
            !counts.any((e) => e.key == _filter)) {
          _filter = null;
        }
        final records = switch (_filter) {
          null => all,
          _important => AiBuckets.of(AiBucket.important, source: all),
          final type =>
            AiBuckets.of(AiBucket.docType, docType: type, source: all),
        };

        Widget chip(String? value, String label) => Padding(
              padding: const EdgeInsetsDirectional.only(end: Gap.xs),
              child: ChoiceChip(
                label: Text(label),
                selected: _filter == value,
                onSelected: (_) => setState(() => _filter = value),
              ),
            );

        return Column(
          children: [
            _TabIntro(
              icon: AppIcons.info,
              text: context.t('aih2.types_intro'),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md, vertical: Gap.xs + 2),
                children: [
                  chip(null, '${context.t('aih2.all')} (${all.length})'),
                  if (importantCount > 0)
                    chip(_important,
                        '${context.t('aih.filter_important')} ($importantCount)'),
                  for (final entry in counts)
                    chip(entry.key,
                        '${AiBuckets.label(entry.key)} (${entry.value})'),
                ],
              ),
            ),
            Expanded(child: AiFileList(records: records)),
          ],
        );
      },
    );
  }
}

// ── sekme 4: öneriler ───────────────────────────────────────────────────────

/// Öneriler sekmesi — **yalnız onayla**.
///
/// Eskiden başlıkta büyük bir "Tümünü uygula (N)" düğmesi vardı ve tek
/// dokunuş, onaysız, yüzlerce dosyayı Önemli Dosyalar'a taşıyordu. Artık
/// düğme "Gözden geçir" der ve önce ne olacağını sayılarla gösteren levhayı
/// açar (bkz. [confirmApplyAiSuggestions]); satır menüsünde "yalnız bunu
/// uygula" ve "yok say" var.
class _SuggestionsTab extends StatelessWidget {
  const _SuggestionsTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final suggestions = AiBuckets.of(AiBucket.suggestions);
        if (suggestions.isEmpty) {
          return _EmptyHint(
            icon: AppIcons.organize,
            title: context.t('aih.sug_empty'),
            body: context.t('aih.sug_empty_sub'),
          );
        }
        return Column(
          children: [
            _TabIntro(
              icon: AppIcons.shield,
              text: context.t('aih2.sug_intro'),
            ),
            ValueListenableBuilder<AiApplyResult?>(
              valueListenable: AiApply.lastResult,
              builder: (context, result, __) => result == null
                  ? const SizedBox.shrink()
                  : _TabIntro(
                      icon: AppIcons.checkCircle,
                      text: context.t('aiap.result', {
                        'ok': result.changed,
                        'fail': result.failed,
                      }),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('aih-review-all'),
                  icon: const Icon(AppIcons.organize),
                  label: Text(context
                      .t('aih2.review_all', {'n': suggestions.length})),
                  onPressed: () =>
                      confirmApplyAiSuggestions(context, suggestions),
                ),
              ),
            ),
            Expanded(
              child: AiFileList(
                records: suggestions,
                showSuggestion: true,
                onApply: (selected) =>
                    confirmApplyAiSuggestions(context, selected),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── sekme 5: rapor ──────────────────────────────────────────────────────────

/// **Rapor** — analizin özeti; her sayı dokununca o dosyaların listesini açar.
class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final analyzed = AiBuckets.of(AiBucket.all);
        if (analyzed.isEmpty) {
          return _EmptyHint(
            icon: AppIcons.insights,
            title: context.t('aih.report_empty'),
            body: context.t('aih.report_empty_sub'),
          );
        }

        final important = AiBuckets.of(AiBucket.important, source: analyzed);
        final disposable = AiBuckets.of(AiBucket.disposable, source: analyzed);
        final lowValue = AiBuckets.of(AiBucket.lowValue, source: analyzed);
        final suggestions =
            AiBuckets.of(AiBucket.suggestions, source: analyzed);
        final types = AiBuckets.typeCounts(analyzed);

        return ListView(
          padding: withNavInset(
              context, const EdgeInsets.fromLTRB(0, Gap.sm, 0, Gap.xl)),
          children: [
            if (disposable.isNotEmpty)
              _ActionCard(
                icon: AppIcons.cleanEmpty,
                title: context.t('aih.card_junk_title', {
                  'n': disposable.length,
                  'size': FsPaths.humanSize(AiBuckets.totalBytes(disposable)),
                }),
                body: context.t('aih.card_junk_body'),
                actionLabel: context.t('aih.card_junk_action'),
                onAction: () => _openBucket(
                    context, AiBucket.disposable, context.t('aih.report_junk')),
              ),
            _Section(
              title: context.t('aih2.report_summary'),
              children: [
                _ReportRow(
                  icon: AppIcons.insertDriveFile,
                  label: context.t('aih.report_analyzed'),
                  value: '${analyzed.length}',
                  sub: FsPaths.humanSize(AiBuckets.totalBytes(analyzed)),
                  onTap: () => _openBucket(
                      context, AiBucket.all, context.t('aih.report_analyzed')),
                ),
                _ReportRow(
                  icon: AppIcons.starOutline,
                  label: context.t('aih.report_important'),
                  value: '${important.length}',
                  onTap: () => _openBucket(context, AiBucket.important,
                      context.t('aih.report_important')),
                ),
                _ReportRow(
                  icon: AppIcons.delete,
                  label: context.t('aih.report_junk'),
                  value: '${disposable.length}',
                  sub: FsPaths.humanSize(AiBuckets.totalBytes(disposable)),
                  onTap: () => _openBucket(context, AiBucket.disposable,
                      context.t('aih.report_junk')),
                ),
                _ReportRow(
                  icon: AppIcons.inbox,
                  label: context.t('aih.report_low'),
                  value: '${lowValue.length}',
                  sub: FsPaths.humanSize(AiBuckets.totalBytes(lowValue)),
                  onTap: () => _openBucket(
                      context, AiBucket.lowValue, context.t('aih.report_low')),
                ),
                _ReportRow(
                  icon: AppIcons.organize,
                  label: context.t('aih.report_suggestions'),
                  value: '${suggestions.length}',
                  onTap: () => _openBucket(context, AiBucket.suggestions,
                      context.t('aih.tab_suggestions')),
                ),
              ],
            ),
            _Section(
              title: context.t('aih.report_types'),
              children: [
                for (final entry in types.take(15))
                  _ReportRow(
                    icon: AppIcons.labelOutline,
                    label: AiBuckets.label(entry.key),
                    value: '${entry.value}',
                    onTap: () => _openBucket(
                      context,
                      AiBucket.docType,
                      AiBuckets.label(entry.key),
                      docType: entry.key,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  static void _openBucket(
    BuildContext context,
    AiBucket bucket,
    String title, {
    String? docType,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          AiFilesScreen(bucket: bucket, title: title, docType: docType),
    ));
  }
}

/// Başlıklı kart bölümü (Rapor).
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
                start: Gap.xs, bottom: Gap.xs),
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Analiz sekmesindeki özet kutucukları: önemli · çöp adayı · öneri ·
/// türler. Her biri ilgili sekmeyi açar.
class _AnalysisStats extends StatelessWidget {
  final ValueChanged<int> onOpenTab;
  const _AnalysisStats({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final analyzed = AiBuckets.of(AiBucket.all);
    final important = AiBuckets.of(AiBucket.important, source: analyzed);
    final disposable = AiBuckets.of(AiBucket.disposable, source: analyzed);
    final suggestions = AiBuckets.of(AiBucket.suggestions, source: analyzed);
    final tiles = [
      _StatTile(
        icon: AppIcons.star,
        color: AppHues.honey,
        value: '${important.length}',
        label: context.t('aih.report_important'),
        onTap: () => onOpenTab(2),
      ),
      _StatTile(
        icon: AppIcons.organize,
        color: AppHues.purple,
        value: '${suggestions.length}',
        label: context.t('aih.report_suggestions'),
        onTap: () => onOpenTab(3),
      ),
      _StatTile(
        icon: AppIcons.deleteSweep,
        color: AppHues.red,
        value: '${disposable.length}',
        label: context.t('aih.report_junk'),
        onTap: () => onOpenTab(4),
      ),
      _StatTile(
        icon: AppIcons.labelOutline,
        color: AppHues.sea,
        value: '${AiBuckets.typeCounts(analyzed).length}',
        label: context.t('aih.tab_tags'),
        onTap: () => onOpenTab(2),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        // Dar telefonda 2×2, genişte tek sıra.
        final perRow = c.maxWidth >= 560 ? 4 : 2;
        final w = (c.maxWidth - Gap.sm * (perRow - 1)) / perRow;
        return Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final t in tiles) SizedBox(width: w, child: t),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm + 4),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        maxLines: 1,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Paper.faint(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Üstte duran "şunu yapabilirsin" kartı.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xs),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: context.type.small
                          .copyWith(color: Paper.faint(context))),
                  const SizedBox(height: Gap.xs),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.tonal(
                      onPressed: onAction,
                      child: Text(actionLabel),
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

class _ReportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final VoidCallback? onTap;

  const _ReportRow({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        subtitle: sub == null
            ? null
            : Text(sub!,
                style:
                    context.type.small.copyWith(color: Paper.faint(context))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style:
                    context.type.heading.copyWith(fontWeight: FontWeight.w600)),
            if (onTap != null) const Icon(AppIcons.chevron),
          ],
        ),
        onTap: onTap,
      );
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final faint = Paper.faint(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: faint),
            const SizedBox(height: Gap.md),
            Text(title, textAlign: TextAlign.center),
            if (body.isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              Text(
                body,
                textAlign: TextAlign.center,
                style: context.type.small.copyWith(color: faint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
