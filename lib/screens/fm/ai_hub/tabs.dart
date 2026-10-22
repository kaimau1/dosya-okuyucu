part of '../ai_hub_screen.dart';

class _TagsTab extends StatefulWidget {
  const _TagsTab();

  @override
  State<_TagsTab> createState() => _TagsTabState();
}

class _TagsTabState extends State<_TagsTab> with AutomaticKeepAliveClientMixin {
  String? _type;
  bool _onlyImportant = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        if (AiIndex.count == 0) {
          return _EmptyHint(
            icon: Icons.label_outline_rounded,
            title: context.t('aih.tags_empty'),
            body: context.t('aih.tags_empty_sub'),
          );
        }
        final counts = AiBuckets.typeCounts();
        // Yeniden analizden sonra seçili tür artık yoksa süzgeç düşer: çipi
        // görünmeyen bir süzgeç listeyi sebepsizce boşaltırdı.
        if (_type != null && !counts.any((e) => e.key == _type)) {
          _type = null;
        }
        final records = _type != null
            ? AiBuckets.of(AiBucket.docType, docType: _type)
            : AiBuckets.of(_onlyImportant ? AiBucket.important : AiBucket.all);
        final filtered = _onlyImportant
            ? [
                for (final record in records)
                  if (record.importance >= AiImportance.important) record
              ]
            : records;

        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Gap.xs, top: Gap.xs),
                    child: FilterChip(
                      label: Text(context.t('aih.filter_important')),
                      selected: _onlyImportant,
                      onSelected: (v) => setState(() => _onlyImportant = v),
                    ),
                  ),
                  for (final entry in counts)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(end: Gap.xs, top: Gap.xs),
                      child: FilterChip(
                        label: Text(
                            '${AiBuckets.label(entry.key)} (${entry.value})'),
                        selected: _type == entry.key,
                        onSelected: (v) =>
                            setState(() => _type = v ? entry.key : null),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AiFileList(
                records: filtered,
                onChanged: () => setState(() {}),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── sekme 3: öneriler ───────────────────────────────────────────────────────

/// Öneriler sekmesi.
///
/// Uygulama artık **arka planda** koşuyor (`AiApply` → iş kuyruğu): kullanıcı
/// 2026-08-11'de *"analiz sonrası öneriler arka planda yapılmaya devam
/// etmiyor"* dedi — ekran kapanınca ya da uygulama arka plana alınınca iş
/// duruyordu. Artık bildirimde ilerliyor ve buradan çıkılabiliyor.
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
            icon: Icons.auto_fix_high_outlined,
            title: context.t('aih.sug_empty'),
            body: context.t('aih.sug_empty_sub'),
          );
        }
        return Column(
          children: [
            ValueListenableBuilder<AiApplyResult?>(
              valueListenable: AiApply.lastResult,
              builder: (context, result, __) => result == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding:
                          const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
                      child: Text(
                        context.t('aiap.result', {
                          'ok': result.changed,
                          'fail': result.failed,
                        }),
                        style: TextStyle(
                            fontSize: 12, color: Paper.faint(context)),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('aih.sug_hint'),
                      style:
                          TextStyle(fontSize: 12, color: Paper.faint(context)),
                    ),
                  ),
                  FilledButton.icon(
                    icon: const Icon(AppIcons.organize),
                    label: Text(
                        context.t('aih.apply_all', {'n': suggestions.length})),
                    onPressed: () => _applyAll(context, suggestions),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AiFileList(
                records: suggestions,
                showSuggestion: true,
                onApply: (selected) async => _applyAll(context, selected),
              ),
            ),
          ],
        );
      },
    );
  }

  void _applyAll(BuildContext context, List<AiRecord> records) {
    AiApply.start(
      records,
      importantRoot: ImportantScreen.pathIn(FmEnv.primaryRoot),
    );
    showSnack(context, context.t('aiap.started', {'n': records.length}));
  }
}

// ── sekme 4: rapor ──────────────────────────────────────────────────────────

/// **Rapor** — analizin "ee, şimdi ne olacak?" sorusuna cevabı.
///
/// Kullanıcı (2026-08-11): *"AI analiz ediyor ama ne işe yarıyor, kullanıcı ne
/// yapacak belli değil… rapor menüsünde etkileşim yok."* Eski rapor sayı
/// listesiydi: hiçbir satıra dokunulamıyor, hiçbir sayı bir eyleme
/// bağlanmıyordu. Yeni rapor iki katman:
/// 1. **Eylem kartları** — yapılacak iş varsa en üstte, düğmesiyle birlikte.
/// 2. **Kova satırları** — her sayı tıklanabilir; dokununca o dosyaların
///    listesi (çoklu seçim + toplu işlem) açılır.
class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final all = AiIndex.all();
        final analyzed = [
          for (final record in all)
            if (record.analyzedMs > 0) record
        ];
        if (analyzed.isEmpty) {
          return _EmptyHint(
            icon: Icons.insights_rounded,
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
            // ── Yapılacak işler ──────────────────────────────────────────
            if (suggestions.isNotEmpty)
              _ActionCard(
                icon: AppIcons.organize,
                title:
                    context.t('aih.card_sug_title', {'n': suggestions.length}),
                body: context.t('aih.card_sug_body'),
                actionLabel: context.t('aih.card_sug_action'),
                onAction: () => _openBucket(context, AiBucket.suggestions,
                    context.t('aih.tab_suggestions')),
              ),
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

            const SizedBox(height: Gap.sm),
            // ── Kovalar (hepsi tıklanabilir) ─────────────────────────────
            _ReportRow(
              icon: AppIcons.emptyFolder,
              label: context.t('aih.report_analyzed'),
              value: '${analyzed.length}',
              sub: FsPaths.humanSize(AiBuckets.totalBytes(analyzed)),
              onTap: () => _openBucket(
                  context, AiBucket.all, context.t('aih.report_analyzed')),
            ),
            _ReportRow(
              icon: Icons.star_outline_rounded,
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
              onTap: () => _openBucket(
                  context, AiBucket.disposable, context.t('aih.report_junk')),
            ),
            _ReportRow(
              icon: Icons.inbox_rounded,
              label: context.t('aih.report_low'),
              value: '${lowValue.length}',
              sub: FsPaths.humanSize(AiBuckets.totalBytes(lowValue)),
              onTap: () => _openBucket(
                  context, AiBucket.lowValue, context.t('aih.report_low')),
            ),
            _ReportRow(
              icon: Icons.auto_fix_high_outlined,
              label: context.t('aih.report_suggestions'),
              value: '${suggestions.length}',
              onTap: () => _openBucket(context, AiBucket.suggestions,
                  context.t('aih.tab_suggestions')),
            ),
            const Divider(height: Gap.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Text(context.t('aih.report_types'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final entry in types.take(15))
              ListTile(
                dense: true,
                title: Text(AiBuckets.label(entry.key)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${entry.value}'),
                    const SizedBox(width: Gap.xs),
                    const Icon(AppIcons.chevron, size: 18),
                  ],
                ),
                onTap: () => _openBucket(
                  context,
                  AiBucket.docType,
                  AiBuckets.label(entry.key),
                  docType: entry.key,
                ),
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

/// Analiz sekmesindeki özet kutucukları: önemli · çöp adayı · öneri ·
/// analiz edilen. Her biri ilgili sekmeyi açar.
class _AnalysisStats extends StatelessWidget {
  final ValueChanged<int> onOpenTab;
  const _AnalysisStats({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final analyzed = [
      for (final record in AiIndex.all())
        if (record.analyzedMs > 0) record
    ];
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
        icon: Icons.delete_sweep_rounded,
        color: AppHues.red,
        value: '${disposable.length}',
        label: disposable.isEmpty
            ? context.t('aih.report_junk')
            : '${context.t('aih.report_junk')} · '
                '${FsPaths.humanSize(AiBuckets.totalBytes(disposable))}',
        onTap: () => onOpenTab(4),
      ),
      _StatTile(
        icon: AppIcons.organize,
        color: AppHues.purple,
        value: '${suggestions.length}',
        label: context.t('aih.report_suggestions'),
        onTap: () => onOpenTab(3),
      ),
      _StatTile(
        icon: Icons.forum_rounded,
        color: AppHues.sea,
        value: '${analyzed.length}',
        label: context.t('aih.ask_files'),
        onTap: () => onOpenTab(1),
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
                      style:
                          TextStyle(fontSize: 12, color: Paper.faint(context))),
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
                style: TextStyle(fontSize: 12, color: Paper.faint(context))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                style: TextStyle(fontSize: 12, color: faint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
