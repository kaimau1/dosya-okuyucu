import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'browser_screen.dart';

/// **İşlemler ekranı** — uzun süren her işin nerede olduğu, başarılı mı
/// olduğu ve **ne ürettiği** tek yerde.
///
/// ## Niye ayrı bir EKRAN (eskiden alt sayfaydı)
/// Kullanıcı hatası 2026-07-30: *"video boyutu düşürürken o işlemler için bir
/// özel sayfa yok, nerede ne oluyor, başlatıldı mı, başarısız mı oldu
/// göremiyorum… ana ekranda takip edebileceğim bir yer, kart, buton gibi bir
/// şey lazım"*. Eski durum bunu gerçekten karşılamıyordu:
/// - alt şerit yalnız **süren** işi gösteriyordu; iş bitince şerit yok oluyor,
///   sonuç (başarılı/başarısız, kaç MB kazanıldı) hiçbir yerde kalmıyordu,
/// - şerit yoksa iş listesine **girilecek kapı da yoktu** (şeride dokunmak
///   gerekiyordu — yani sonuç görülemiyordu),
/// - işin ÜRETTİĞİ dosya hiç yazılmıyordu: küçültülmüş video özgünün yanına
///   kaydediliyor ama kullanıcı onu arıyordu.
///
/// Bu ekran ana ekrandaki **İşlemler** kutusundan ve alt şeritten açılır;
/// süren, sırada bekleyen ve bitmiş işleri (son [JobQueue.historyLimit] iş)
/// süreleriyle listeler, çıktı dosyalarını açar ya da klasörünü gösterir.
class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.t('jb.title')),
          actions: [
            AnimatedBuilder(
              animation: JobQueue.instance,
              builder: (context, _) =>
                  JobQueue.instance.finishedJobs.isEmpty
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: JobQueue.instance.clearFinished,
                          child: const Text('Bitenleri temizle'),
                        ),
            ),
          ],
        ),
        body: AnimatedBuilder(
          animation: JobQueue.instance,
          builder: (context, _) {
            final jobs = JobQueue.instance.jobs;
            return ListView(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
              children: [
                // Dürüst sınır kullanıcının gözünün önünde: "arka planda
                // çalışıyor" sözü ne kadarını kapsıyor?
                Text(
                  context.t('jb.background_note'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Gap.md),
                if (jobs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Gap.xl),
                    child: Center(
                      child: Text(context.t('jb.empty'),
                          textAlign: TextAlign.center),
                    ),
                  )
                else
                  for (final job in jobs) _JobCard(job: job),
              ],
            );
          },
        ),
      );
}

/// Tek işin kartı: durum, ilerleme, süre, özet ve ürettiği dosyalar.
class _JobCard extends StatelessWidget {
  final FmJob job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // İptalde de `detail` GÖSTERİLİR: durdurulan iş yarıda ne yaptığını oraya
    // yazıyor ("12,4 MB kazanıldı · 4 özgün çöp kutusunda · durduruldu (4/10)")
    // ve kullanıcının bunu öğrenmesinin tek yolu bu satır.
    final subtitle = switch (job.status) {
      JobStatus.failed => job.error ?? context.t('job.error_generic'),
      JobStatus.cancelled =>
        job.detail.isEmpty
            ? context.t('jb.cancelled')
            : context.t('jb.cancelled_detail', {'detail': job.detail}),
      _ => job.detail.isEmpty ? job.status.label : job.detail,
    };
    final elapsed = job.elapsed;
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: _color(scheme)),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(job.title, style: theme.textTheme.titleSmall),
                ),
                if (job.status.isActive)
                  TextButton(
                    onPressed: () => JobQueue.instance.cancel(job.id),
                    child: const Text('Durdur'),
                  ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(subtitle, style: theme.textTheme.bodySmall),
            if (job.status == JobStatus.running) ...[
              const SizedBox(height: Gap.sm),
              LinearProgressIndicator(value: job.progress),
            ],
            if (elapsed != null)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  job.status.isActive
                      ? context.t(
                          'jb.running_for', {'time': humanDuration(elapsed)})
                      : context.t('jb.took', {
                          'status': context.t(job.status.labelKey),
                          'time': humanDuration(elapsed),
                        }),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            if (job.outputs.isNotEmpty) _outputs(context),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (job.status) {
        JobStatus.running => Icons.autorenew,
        JobStatus.queued => Icons.schedule,
        JobStatus.done => Icons.check_circle,
        JobStatus.failed => Icons.error_outline,
        JobStatus.cancelled => Icons.block,
      };

  Color? _color(ColorScheme scheme) => switch (job.status) {
        JobStatus.failed => scheme.error,
        JobStatus.done => const Color(0xFF2E7D32),
        _ => scheme.onSurfaceVariant,
      };

  /// İşin ürettiği dosyalar: adı, boyutu, klasörü + **aç** / **klasörü aç**.
  Widget _outputs(BuildContext context) {
    final theme = Theme.of(context);
    final outputs = job.outputs;
    final dir = p.dirname(outputs.first);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: Text(context.t('jb.outputs', {'n': outputs.length}),
                  style: theme.textTheme.labelLarge),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BrowserScreen(path: dir)),
              ),
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(context.t('jb.open_folder')),
            ),
          ],
        ),
        // Uzun listeyi kırp: 200 fotoğrafın adını tek tek dökmek kartı
        // okunamaz yapar; klasör düğmesi hepsine götürüyor.
        for (final path in outputs.take(_maxListed))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            // Simge dosyanın TÜRÜNDEN: boyut düşürme fotoğraf da üretiyor,
            // hepsine film ikonu koymak yanlış bilgi olurdu.
            leading: Icon(FmColors.iconFor(
                FsEntry.categoryForExtension(_extension(path)))),
            title: Text(p.basename(path),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_sizeAndFolder(path),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            // Dosya listede DURUYOR ama diskte olmayabilir (kullanıcı silmiş,
            // taşımış olabilir) — `EntryOpener` bu durumu kendisi bildiriyor.
            onTap: () => EntryOpener.open(context, path, siblings: outputs),
          ),
        if (outputs.length > _maxListed)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Text('… ve ${outputs.length - _maxListed} dosya daha',
                style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }

  static const _maxListed = 12;

  static String _extension(String path) {
    final name = p.basename(path);
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1);
  }

  /// "12,4 MB · Camera" — boyut diskten okunur (çıktı gerçekten orada mı?).
  String _sizeAndFolder(String path) {
    final folder = p.basename(p.dirname(path));
    try {
      final file = File(path);
      if (!file.existsSync()) return 'Dosya bulunamadı · $folder';
      return '${FsPaths.humanSize(file.lengthSync())} · $folder';
    } catch (_) {
      return folder;
    }
  }
}

/// İşlemler ekranını açar (alt şerit ve pano kutusu bunu çağırır).
Future<void> openJobsScreen(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JobsScreen()),
    );
