import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../screens/fm/job_navigation.dart';
import '../../screens/fm/jobs_screen.dart';
import '../../services/fm/job_queue.dart';

/// Süren işi ve **son sonucu** gösteren kalıcı şerit — her sekmenin altında,
/// gezinme çubuğunun üstünde durur.
///
/// Niye burada: iş kuyruğunun tek anlamı "başlat ve başka işe geç"; ilerleme
/// yalnız işi başlattığın ekranda görünürse kullanıcı o ekranda beklemek
/// zorunda kalır. Şerit uygulamanın her yerinde görünür, dokununca İşlemler
/// ekranı açılır, sağdaki düğme iptal eder.
///
/// **İş bitince şerit kaybolmuyor** (kullanıcı hatası 2026-07-30: *"başlatıldı
/// mı oldu başarısız mı oldu göremiyorum"*): sonuç satırı — başarılı/başarısız
/// simgesi ve özet ("18,2 MB kazanıldı · Kaydedildi: Camera") — kullanıcı
/// kapatana kadar durur. Kapatılan sonuç kaybolmuyor, İşlemler ekranında kalıyor.
class JobProgressBar extends StatelessWidget {
  const JobProgressBar({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: JobQueue.instance,
        builder: (context, _) {
          final queue = JobQueue.instance;
          final running = queue.currentJob;
          if (running != null) return _RunningBar(job: running);
          final finished = queue.lastFinished;
          if (finished != null) return _ResultBar(job: finished);
          return const SizedBox.shrink();
        },
      );
}

/// İşin adı, ayrıntı satırı ("720×1280 · %42 · ~2 dk kaldı · donanım
/// kodlayıcı") ve iptal düğmesi.
class _RunningBar extends StatelessWidget {
  final FmJob job;
  const _RunningBar({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queued = JobQueue.instance.activeJobs.length - 1;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        // Şeride dokunmak **işin olduğu yere** götürür (istek 2026-07-31);
        // hedefi olmayan işte İşlemler ekranına düşer. Listeye gitmek isteyen
        // için sağdaki liste düğmesi duruyor.
        onTap: () => openJobTarget(context, job),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: job.progress, minHeight: 3),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.xs, Gap.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          queued > 0
                              ? '${job.title} (+$queued sırada)'
                              : job.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                        if (job.detail.isNotEmpty)
                          Text(
                            job.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('jb.title'),
                    icon: const Icon(Icons.list_alt, size: 20),
                    onPressed: () => openJobsScreen(context),
                  ),
                  TextButton(
                    onPressed: () => JobQueue.instance.cancel(job.id),
                    child: Text(context.t('jp.cancel')),
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

/// Biten işin sonuç satırı: durum simgesi + özet + (varsa) "Aç" + kapatma.
class _ResultBar extends StatelessWidget {
  final FmJob job;
  const _ResultBar({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failed = job.status == JobStatus.failed;
    final summary = switch (job.status) {
      JobStatus.failed => job.error ?? context.t('job.error_generic'),
      JobStatus.cancelled =>
        job.detail.isEmpty
            ? context.t('jb.cancelled')
            : context.t('jb.cancelled_detail', {'detail': job.detail}),
      _ => job.detail.isEmpty ? job.status.label : job.detail,
    };
    return Material(
      color: failed
          ? scheme.errorContainer
          : scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => openJobTarget(context, job),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.xs, Gap.xs),
          child: Row(
            children: [
              Icon(
                switch (job.status) {
                  JobStatus.failed => Icons.error_outline,
                  JobStatus.cancelled => Icons.block,
                  _ => Icons.check_circle,
                },
                size: 20,
                color: failed ? scheme.onErrorContainer : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge),
                    Text(summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              // "Göster" artık gerçekten sonuca götürüyor: üretilen dosyayı
              // (ya da tarama sonucunu) açar, arada İşlemler ekranı yok.
              if (jobHasDestination(job))
                TextButton(
                  onPressed: () => openJobTarget(context, job),
                  child: Text(context.t('jp.show')),
                ),
              IconButton(
                tooltip: 'Kapat',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => JobQueue.instance.dismiss(job.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
