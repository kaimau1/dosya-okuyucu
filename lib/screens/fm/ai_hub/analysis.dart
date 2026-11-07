part of '../ai_hub_screen.dart';

// ── ortak: analizi başlat ───────────────────────────────────────────────────

Future<void> _startAnalysis(BuildContext context,
    {required bool reanalyze}) async {
  final state = context.read<AppState>();
  // Analiz uzun sürer ve ekran kapanabilir; state okumaları burada bitiyor.
  await AiAnalyzer.start(
    scope: state.aiScopeRules,
    credentials: state.aiCredentials,
    reanalyze: reanalyze,
  );
}

// ── ince ilerleme şeridi (Analiz dışındaki sekmeler) ────────────────────────

class _ProgressStrip extends StatelessWidget {
  final AiProgress progress;
  const _ProgressStrip({required this.progress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final faint = Paper.faint(context);
    final paused = progress.phase == AiRunPhase.paused;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, Gap.xs, Gap.xs, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(progress.auto ? AppIcons.autorenew : AppIcons.ai,
                    size: 18, color: scheme.primary),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    '${context.t(progress.auto ? 'aih2.auto_running' : 'aih.analysis_running')}'
                    ' · ${progress.done}/${progress.total}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.small.copyWith(
                        color: faint, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.t(paused ? 'aih.resume' : 'aih.pause'),
                  icon: Icon(paused ? AppIcons.play : AppIcons.pause, size: 20),
                  onPressed: paused ? AiAnalyzer.resume : AiAnalyzer.pause,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.t('aih.stop'),
                  icon: const Icon(AppIcons.stop, size: 20),
                  onPressed: AiAnalyzer.cancel,
                ),
              ],
            ),
            LinearProgressIndicator(
              minHeight: 3,
              value: progress.total == 0 ? null : progress.fraction,
            ),
          ],
        ),
      ),
    );
  }
}

// ── sekme 1: analiz ─────────────────────────────────────────────────────────

/// **Analiz sekmesi** — üç soruyu sırayla cevaplar: **şu an ne oluyor**
/// (durum kartı), **ne yapar / neye dokunmaz** (üç maddelik açıklama) ve
/// **nasıl ayarlanır** (otomatik analiz anahtarı, kapsam, yeniden analiz).
class _AnalysisTab extends StatelessWidget {
  /// Özet kutucuklarından ilgili sekmeye geçiş (2 türler, 3 öneriler,
  /// 4 rapor).
  final ValueChanged<int> onOpenTab;

  const _AnalysisTab({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiProgress>(
      valueListenable: AiAnalyzer.progress,
      builder: (context, progress, _) => ValueListenableBuilder<int>(
        valueListenable: AiIndex.revision,
        builder: (context, _, _) => _body(context, progress),
      ),
    );
  }

  Widget _body(BuildContext context, AiProgress progress) {
    final state = context.watch<AppState>();
    final faint = Paper.faint(context);
    return ListView(
      padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
      children: [
        _StatusCard(progress: progress),
        const SizedBox(height: Gap.md),

        // Özet kutucukları — "ne buldu?" (analiz sürerken çizilmez: her
        // dosyada tetiklenir ve tüm dizini dolaşır).
        if (AiIndex.count > 0 && !progress.isBusy) ...[
          _AnalysisStats(onOpenTab: onOpenTab),
          const SizedBox(height: Gap.md),
        ],

        const _HowItWorks(),
        const SizedBox(height: Gap.md),

        // Ayarlar: otomatik analiz burada — kullanıcı analizin kendiliğinden
        // başladığını gördüğü yerde kapatabilmeli.
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const AiAutoNewTile(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(AppIcons.tune),
                title: Text(context.t('aih.analysis_scope')),
                subtitle: Text(context.t('aih.scope_summary',
                    {'n': state.aiScope.excludedFolders.length})),
                trailing: const Icon(AppIcons.chevron),
                onTap: () => openSettingsCategory(context, 'ai'),
              ),
              if (!progress.isBusy && AiIndex.count > 0) ...[
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('aih-reanalyze'),
                  leading: const Icon(AppIcons.refresh),
                  title: Text(context.t('aih.reanalyze')),
                  subtitle: Text(context.t('aih2.reanalyze_sub')),
                  onTap: () async {
                    final ok = await showAppConfirm(
                      context,
                      title: context.t('aih.reanalyze'),
                      message: context.t('aih2.reanalyze_confirm',
                          {'n': AiIndex.count}),
                      confirmLabel: context.t('aih.start'),
                    );
                    if (ok && context.mounted) {
                      await _startAnalysis(context, reanalyze: true);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            Icon(state.hasApiKey ? AppIcons.cloudDone : AppIcons.offlineBolt,
                size: 16, color: faint),
            const SizedBox(width: Gap.xs),
            Expanded(
              child: Text(
                context.t(state.hasApiKey ? 'aih.mode_cloud' : 'aih.mode_local'),
                style: context.type.small.copyWith(color: faint),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Durum kartı: boş · sürüyor (elle / otomatik) · bitti/hata.
class _StatusCard extends StatelessWidget {
  final AiProgress progress;
  const _StatusCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final faint = Paper.faint(context);
    final busy = progress.isBusy;
    final paused = progress.phase == AiRunPhase.paused;
    final error = progress.phase == AiRunPhase.error;
    final none = AiIndex.count == 0;

    final String title;
    final String sub;
    if (busy) {
      title = context.t(paused
          ? 'aih2.paused'
          : progress.auto
              ? 'aih2.auto_running'
              : 'aih.analysis_running');
      sub = progress.auto ? context.t('aih2.auto_running_sub') : '';
    } else if (none) {
      title = context.t('aih2.none_title');
      sub = context.t('aih2.none_sub');
    } else {
      title = context.t('aih.analyzed', {'n': AiIndex.count});
      sub = progress.message.isNotEmpty
          ? progress.message
          : context.t('aih2.done_sub');
    }

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: error
            ? scheme.errorContainer
            : scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.card + 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: error ? scheme.error : scheme.primary,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Icon(
                  error
                      ? AppIcons.warning
                      : busy && progress.auto
                          ? AppIcons.autorenew
                          : AppIcons.ai,
                  size: 24,
                  color: error ? scheme.onError : scheme.onPrimary,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (busy)
                Text('${progress.done}/${progress.total}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(sub,
                style: context.type.small.copyWith(
                    color: error ? scheme.onErrorContainer : faint)),
          ],
          if (busy) ...[
            const SizedBox(height: Gap.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.control),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress.total == 0 ? null : progress.fraction,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              progress.message.isNotEmpty
                  ? progress.message
                  : progress.currentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.small.copyWith(color: faint),
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(paused ? AppIcons.play : AppIcons.pause),
                    label: Text(
                        context.t(paused ? 'aih.resume' : 'aih.pause')),
                    onPressed: paused ? AiAnalyzer.resume : AiAnalyzer.pause,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(AppIcons.stop),
                    label: Text(context.t('aih.stop')),
                    onPressed: AiAnalyzer.cancel,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: Gap.md),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(AppIcons.ai),
                label: Text(context.t(none ? 'aih.start' : 'aih2.analyze_new')),
                onPressed: () => _startAnalysis(context, reanalyze: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Ne yapar, neye DOKUNMAZ" — üç madde. Kullanıcının asıl korkusu (dosyalarım
/// kendi kendine taşınıyor/siliniyor) burada açıkça cevaplanır.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    Widget row(IconData icon, Color color, String titleKey, String bodyKey) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t(titleKey),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(context.t(bodyKey),
                        style: context.type.small.copyWith(color: faint)),
                  ],
                ),
              ),
            ],
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('aih.analysis_what'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Gap.xs),
            row(AppIcons.manageSearch, AppHues.sea, 'aih2.how1_title',
                'aih2.how1_body'),
            row(AppIcons.labelOutline, AppHues.honey, 'aih2.how2_title',
                'aih2.how2_body'),
            row(AppIcons.shield, AppHues.purple, 'aih2.how3_title',
                'aih2.how3_body'),
          ],
        ),
      ),
    );
  }
}
