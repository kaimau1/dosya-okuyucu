part of '../ai_hub_screen.dart';

// ── durum çubuğu: başlat / ilerleme / duraklat ──────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiProgress>(
      valueListenable: AiAnalyzer.progress,
      builder: (context, progress, _) {
        return ValueListenableBuilder<int>(
          valueListenable: AiIndex.revision,
          builder: (context, _, __) => _buildBody(context, progress),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AiProgress progress) {
    final state = context.watch<AppState>();
    final faint = Paper.faint(context);
    final excluded = state.aiScope.excludedFolders.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.isBusy
                          ? '${progress.done}/${progress.total}'
                          : context.t('aih.analyzed', {'n': AiIndex.count}),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      progress.message.isNotEmpty
                          ? progress.message
                          : (progress.isBusy
                              ? progress.currentName
                              : context
                                  .t('aih.scope_summary', {'n': excluded})),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.small.copyWith(color: faint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              if (progress.isBusy) ...[
                IconButton(
                  tooltip: context.t(progress.phase == AiRunPhase.paused
                      ? 'aih.resume'
                      : 'aih.pause'),
                  icon: Icon(progress.phase == AiRunPhase.paused
                      ? AppIcons.play
                      : AppIcons.pause),
                  onPressed: () => progress.phase == AiRunPhase.paused
                      ? AiAnalyzer.resume()
                      : AiAnalyzer.pause(),
                ),
                IconButton(
                  tooltip: context.t('aih.stop'),
                  icon: const Icon(AppIcons.stop),
                  onPressed: AiAnalyzer.cancel,
                ),
              ] else
                FilledButton.icon(
                  icon: const Icon(AppIcons.ai),
                  label: Text(context
                      .t(AiIndex.count == 0 ? 'aih.start' : 'aih.continue')),
                  onPressed: () => _start(context, reanalyze: false),
                ),
            ],
          ),
          if (progress.isBusy)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: LinearProgressIndicator(
                value: progress.total == 0 ? null : progress.fraction,
              ),
            ),
          if (!progress.isBusy && !state.hasApiKey)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text(
                context.t('aih.no_key_note'),
                style: context.type.caption.copyWith(color: faint),
              ),
            ),
          if (!progress.isBusy && AiIndex.count > 0)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => _start(context, reanalyze: true),
                child: Text(context.t('aih.reanalyze')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, {required bool reanalyze}) async {
    final state = context.read<AppState>();
    // Analiz uzun sürer ve ekran kapanabilir; state okumaları burada bitiyor.
    await AiAnalyzer.start(
      scope: state.aiScopeRules,
      credentials: state.aiCredentials,
      reanalyze: reanalyze,
    );
  }
}

// ── sekme 1: analiz ─────────────────────────────────────────────────────────

/// **Analiz sekmesi** — "AI ile dosya analizi"nin bulunur hâli.
///
/// Kullanıcı hatası (2026-08-25): *"ai kısmında ai ile dosya analizini bulmak
/// çok zor"*. Doğruydu: başlatma düğmesi [_StatusBar]'ın sağ ucunda, sekme
/// çubuğunun bile üstünde duran küçük bir düğmeydi ve ekranın geri kalanı
/// analiz koşmadan boş görünüyordu.
///
/// Bu sekme üç soruyu sırayla cevaplar: **ne işe yarar**, **ne kadarı bitti**,
/// **nasıl başlatılır**. Kapsam ayarı da burada — "hangi klasörler okunuyor"
/// sorusu analizi başlatmadan önce sorulan bir soru, ayarların derinlerinde
/// değil.
class _AnalysisTab extends StatelessWidget {
  /// Özet kutucuklarından ilgili sekmeye geçiş (1 sohbet, 2 etiketler,
  /// 3 öneriler, 4 rapor).
  final ValueChanged<int> onOpenTab;

  const _AnalysisTab({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiProgress>(
      valueListenable: AiAnalyzer.progress,
      builder: (context, progress, _) => ValueListenableBuilder<int>(
        valueListenable: AiIndex.revision,
        builder: (context, _, __) => _body(context, progress),
      ),
    );
  }

  Widget _body(BuildContext context, AiProgress progress) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    final state = context.watch<AppState>();
    return ListView(
      padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
      children: [
        // Ne işe yaradığı ÖNCE gelir: kullanıcı düğmeye basmadan önce ne
        // olacağını bilmeli (dosyaları okuyacağız, token harcayacağız).
        // Vurgu renginden yumuşak bir degrade: ekranın "kahraman" kartı.
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card + 4),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.16),
                theme.colorScheme.tertiary.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.18)),
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
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(Radii.control),
                    ),
                    child: Icon(AppIcons.ai,
                        size: 24, color: theme.colorScheme.onPrimary),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(context.t('aih.analysis_what'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(context.t('aih.analysis_body'),
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  Icon(
                      state.hasApiKey
                          ? AppIcons.cloudDone
                          : AppIcons.offlineBolt,
                      size: 16,
                      color: faint),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                        context.t(state.hasApiKey
                            ? 'aih.mode_cloud'
                            : 'aih.mode_local'),
                        style: context.type.small.copyWith(color: faint)),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(context.t('aih.analysis_manual'),
                  style: context.type.small.copyWith(color: faint)),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),

        // Sayaç: kaç dosya analiz edildi / şu an ne oluyor.
        Text(
          progress.isBusy
              ? '${context.t('aih.analysis_running')} · '
                  '${progress.done}/${progress.total}'
              : context.t('aih.analyzed', {'n': AiIndex.count}),
          style: theme.textTheme.titleLarge,
        ),
        if (progress.isBusy) ...[
          const SizedBox(height: Gap.sm),
          LinearProgressIndicator(
            value: progress.total == 0 ? null : progress.fraction,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            progress.message.isNotEmpty
                ? progress.message
                : progress.currentName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.type.small.copyWith(color: faint),
          ),
        ],
        const SizedBox(height: Gap.md),

        // Asıl düğme: tam genişlik, 56 dp. "Bulunması zor" şikâyetinin cevabı
        // burada — ekranın ortasında, adı üstünde yazan tek eylem.
        if (progress.isBusy)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(progress.phase == AiRunPhase.paused
                      ? AppIcons.play
                      : AppIcons.pause),
                  label: Text(context.t(progress.phase == AiRunPhase.paused
                      ? 'aih.resume'
                      : 'aih.pause')),
                  onPressed: () => progress.phase == AiRunPhase.paused
                      ? AiAnalyzer.resume()
                      : AiAnalyzer.pause(),
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
          )
        else
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              icon: const Icon(AppIcons.ai),
              label: Text(
                  context.t(AiIndex.count == 0 ? 'aih.start' : 'aih.continue')),
              onPressed: () => _start(context, reanalyze: false),
            ),
          ),
        if (!progress.isBusy && AiIndex.count > 0) ...[
          const SizedBox(height: Gap.sm),
          TextButton(
            onPressed: () => _start(context, reanalyze: true),
            child: Text(context.t('aih.reanalyze')),
          ),
        ],
        if (!progress.isBusy && !state.hasApiKey) ...[
          const SizedBox(height: Gap.sm),
          Text(context.t('aih.no_key_note'),
              style: context.type.small.copyWith(color: faint)),
        ],
        const SizedBox(height: Gap.md),

        // **Özet kutucukları** — analiz bittikten sonra "ee, ne buldu?"
        // sorusunun cevabı bu sekmede de görünsün; dokununca ilgili sekme.
        // Analiz SÜRERKEN çizilmez: ilerleme her dosyada tetikleniyor ve
        // kovalar tüm dizini dolaşıyor — binlerce kaydı saniyede onlarca kez
        // saymaya değmez; sonuç analiz bitince görünür.
        if (AiIndex.count > 0 && !progress.isBusy) ...[
          _AnalysisStats(onOpenTab: onOpenTab),
          const SizedBox(height: Gap.md),
        ],

        // Kapsam: "hangi klasörler okunuyor" — başlatmadan önce sorulan soru.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.tune),
          title: Text(context.t('aih.analysis_scope')),
          subtitle: Text(context.t('aih.scope_summary',
              {'n': state.aiScope.excludedFolders.length})),
          onTap: () => openSettingsCategory(context, 'ai'),
        ),
      ],
    );
  }

  Future<void> _start(BuildContext context, {required bool reanalyze}) async {
    final state = context.read<AppState>();
    // Analiz uzun sürer ve ekran kapanabilir; state okumaları burada bitiyor.
    await AiAnalyzer.start(
      scope: state.aiScopeRules,
      credentials: state.aiCredentials,
      reanalyze: reanalyze,
    );
  }
}
