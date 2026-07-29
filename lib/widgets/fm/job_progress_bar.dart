import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/fm/job_queue.dart';

/// Süren işleri gösteren **kalıcı şerit** — her sekmenin altında, gezinme
/// çubuğunun üstünde durur.
///
/// Niye burada: iş kuyruğunun tek anlamı "başlat ve başka işe geç"; ilerleme
/// yalnız işi başlattığın ekranda görünürse kullanıcı o ekranda beklemek
/// zorunda kalır. Şerit uygulamanın her yerinde görünür, dokununca ayrıntı
/// açılır, sağdaki düğme iptal eder.
class JobProgressBar extends StatelessWidget {
  const JobProgressBar({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: JobQueue.instance,
        builder: (context, _) {
          final queue = JobQueue.instance;
          final job = queue.currentJob;
          if (job == null) return const SizedBox.shrink();
          final theme = Theme.of(context);
          final queued = queue.activeJobs.length - 1;
          return Material(
            color: theme.colorScheme.surfaceContainerHigh,
            child: InkWell(
              onTap: () => showJobsSheet(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: job.progress, minHeight: 3),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.xs, Gap.xs),
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
                        TextButton(
                          onPressed: () => queue.cancel(job.id),
                          child: const Text('İptal'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

/// İş listesi sayfası: süren + sırada bekleyen + biten işler.
Future<void> showJobsSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _JobsSheet(),
    );

class _JobsSheet extends StatelessWidget {
  const _JobsSheet();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: JobQueue.instance,
        builder: (context, _) {
          final queue = JobQueue.instance;
          final jobs = queue.jobs;
          final theme = Theme.of(context);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.sm, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('İşlemler',
                              style: theme.textTheme.titleMedium),
                        ),
                        if (jobs.any((j) => !j.status.isActive))
                          TextButton(
                            onPressed: queue.clearFinished,
                            child: const Text('Bitenleri temizle'),
                          ),
                      ],
                    ),
                  ),
                  // Dürüst sınır kullanıcının gözünün önünde: "arka planda
                  // çalışıyor" sözü ne kadarını kapsıyor?
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    child: Text(
                      'İşler uygulama arka plandayken de sürer ve ilerleme '
                      'bildirimde görünür. Uygulamayı görev listesinden '
                      'tamamen kapatırsan iş durur.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const Divider(height: Gap.md),
                  if (jobs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(Gap.lg),
                      child: Text('Süren bir işlem yok.'),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: jobs.length,
                        itemBuilder: (context, i) => _row(context, jobs[i]),
                      ),
                    ),
                  const SizedBox(height: Gap.sm),
                ],
              ),
            ),
          );
        },
      );

  Widget _row(BuildContext context, FmJob job) {
    final theme = Theme.of(context);
    final subtitle = switch (job.status) {
      JobStatus.failed => job.error ?? 'Bir hata oluştu.',
      JobStatus.cancelled => 'İptal edildi.',
      _ => job.detail.isEmpty ? job.status.label : job.detail,
    };
    return ListTile(
      leading: Icon(switch (job.status) {
        JobStatus.running => Icons.autorenew,
        JobStatus.queued => Icons.schedule,
        JobStatus.done => Icons.check_circle_outline,
        JobStatus.failed => Icons.error_outline,
        JobStatus.cancelled => Icons.block,
      },
          color: job.status == JobStatus.failed
              ? theme.colorScheme.error
              : null),
      title: Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (job.status == JobStatus.running)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: LinearProgressIndicator(value: job.progress),
            ),
        ],
      ),
      trailing: job.status.isActive
          ? IconButton(
              tooltip: 'İptal',
              icon: const Icon(Icons.close),
              onPressed: () => JobQueue.instance.cancel(job.id),
            )
          : null,
    );
  }
}
