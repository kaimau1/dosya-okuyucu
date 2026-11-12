import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/section_header.dart';
import 'browser_screen.dart';
import 'job_navigation.dart';
import 'op_history_screen.dart';
import '../../core/snack.dart';
import '../../core/safe_insets.dart';
import '../../widgets/live_progress.dart';
import '../../widgets/embedded_toolbar.dart';
import 'operations_screen.dart';

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
  /// İşlemler merkezinin sekmesi olarak mı açıldı? (Üstte sekmeli başlık
  /// varken kendi geri oklu çubuğunu çizmez — bkz. [EmbeddedToolbar].)
  final bool embedded;

  const JobsScreen({super.key, this.embedded = false});

  List<Widget> _actions(BuildContext context) => [
        // Geri alınabilir taşıma/kopyalama geçmişi (eski "Son işlemler"
        // kutusu, 2026-10-21'de Geçmiş > İşlemler'e katıldı).
        IconButton(
          tooltip: context.t('oph.title'),
          icon: const Icon(AppIcons.undo),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const OpHistoryScreen())),
        ),
        AnimatedBuilder(
          animation: JobQueue.instance,
          builder: (context, _) => JobQueue.instance.finishedJobs.isEmpty
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: JobQueue.instance.clearFinished,
                  child: Text(context.t('fm.clear_finished')),
                ),
        ),
      ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: embedded
            ? EmbeddedToolbar(actions: _actions(context))
            : AppBar(
                title: Text(context.t('jb.title')),
                actions: _actions(context),
              ),
        body: AnimatedBuilder(
          animation: JobQueue.instance,
          builder: (context, _) {
            final jobs = JobQueue.instance.jobs;
            final active = [
              for (final j in jobs)
                if (j.status.isActive) j,
            ];
            final finished = [
              for (final j in jobs)
                if (!j.status.isActive) j,
            ];
            return ListView(
              padding: withNavInset(
                  context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl)),
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
                  ),
                // Süren/sıradaki işler tam genişlik kart (ilerleme çubuğu,
                // Durdur); biten işler 2 sütunlu ızgara (2026-11-04,
                // kullanıcı: *"biten işler grid kart olarak 2 kolonlu"*).
                if (active.isNotEmpty && finished.isNotEmpty)
                  SectionHeader(context.t('ops.active'),
                      count: '${active.length}',
                      padding: const EdgeInsets.only(bottom: Gap.sm)),
                for (final job in active) _JobCard(job: job),
                if (finished.isNotEmpty) ...[
                  SectionHeader(context.t('ops.finished'),
                      count: '${finished.length}',
                      padding: EdgeInsets.only(
                          top: active.isEmpty ? 0 : Gap.md, bottom: Gap.sm)),
                  _FinishedGrid(jobs: finished),
                ],
              ],
            );
          },
        ),
      );
}

/// Biten işler iki sütunda; satırdaki iki kart AYNI yükseklikte (kısa olan
/// uzun olanınkine uzar — ızgara tırtıklı görünmesin). Sabit hücre yüksekliği
/// yok: büyük yazı ölçeğinde metin taşmasın diye satır içeriğe göre büyür.
class _FinishedGrid extends StatelessWidget {
  final List<FmJob> jobs;
  const _FinishedGrid({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 720 ? 3 : 2;
    final rows = <List<FmJob>>[
      for (var i = 0; i < jobs.length; i += columns)
        jobs.sublist(i, i + columns > jobs.length ? jobs.length : i + columns),
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: Gap.sm),
                    Expanded(
                      child: i < row.length
                          ? _FinishedJobTile(job: row[i])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Biten işin küçük kartı: durum simgesi, başlık, özet, ürettiği ilk dosya ve
/// süre. Dokununca işin ilgili yerine gider (ya da sürdürülebiliyorsa sürdürür).
class _FinishedJobTile extends StatelessWidget {
  final FmJob job;
  const _FinishedJobTile({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = _JobCard(job: job);
    final resumable = card.resumable;
    final destination = jobHasDestination(job);
    final elapsed = job.elapsed;
    final outputs = job.outputs;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: resumable
            ? () => card._resume(context, job)
            : (destination
                ? () => openJobTarget(context, job, fallbackToJobs: false)
                : null),
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: (card._color(scheme) ?? scheme.onSurfaceVariant)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(card._icon,
                        size: 18, color: card._color(scheme)),
                  ),
                  const Spacer(),
                  if (destination && !resumable)
                    Icon(AppIcons.chevron,
                        size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(job.shownTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(card.subtitle(context),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
              if (outputs.isNotEmpty) ...[
                const SizedBox(height: Gap.xs),
                Text(context.t('jb.outputs', {'n': outputs.length}),
                    style: theme.textTheme.labelSmall),
                InkWell(
                  onTap: () => EntryOpener.open(context, outputs.first,
                      siblings: outputs),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(p.basename(outputs.first),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.primary)),
                  ),
                ),
              ],
              const Spacer(),
              if (elapsed != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: MonoText(context.t('jb.took', {
                    'status': context.t(job.status.labelKey),
                    'time': humanDuration(elapsed),
                  })),
                ),
              if (resumable)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: FilledButton.tonal(
                    onPressed: () => card._resume(context, job),
                    child: Text(context.t('jb.resume')),
                  ),
                )
              else if (outputs.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4)),
                    onPressed: () => Navigator.of(context).push(
                      browserRoute(
                          BrowserScreen(path: p.dirname(outputs.first))),
                    ),
                    icon: const Icon(AppIcons.emptyFolder, size: 16),
                    label: Text(context.t('jb.open_folder'),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek işin kartı: durum, ilerleme, süre, özet ve ürettiği dosyalar.
class _JobCard extends StatelessWidget {
  final FmJob job;
  const _JobCard({required this.job});

  /// Yarıda kalan/başarısız iş devam ettirilebilir mi?
  bool get resumable =>
      JobRecipes.canResume(job) &&
      (job.status == JobStatus.interrupted ||
          job.status == JobStatus.failed ||
          job.status == JobStatus.cancelled);

  String subtitle(BuildContext context) => switch (job.status) {
        JobStatus.failed => job.error ?? context.t('job.error_generic'),
        JobStatus.cancelled => job.detail.isEmpty
            ? context.t('jb.cancelled')
            : context.t('jb.cancelled_detail', {'detail': job.detail}),
        JobStatus.interrupted => job.detail.isEmpty
            ? context.t('jb.interrupted')
            : context.t('jb.interrupted_detail', {'detail': job.detail}),
        _ => job.detail.isEmpty ? context.t(job.status.labelKey) : job.detail,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // İptalde de `detail` GÖSTERİLİR: durdurulan iş yarıda ne yaptığını oraya
    // yazıyor ("12,4 MB kazanıldı · 4 özgün çöp kutusunda · durduruldu (4/10)")
    // ve kullanıcının bunu öğrenmesinin tek yolu bu satır.
    final sub = subtitle(context);
    final elapsed = job.elapsed;
    // Kullanıcı isteği 2026-07-31: *"bir işlemin üzerine tıklayınca ilgili yere
    // götürsün"*. Eskiden kartın kendisi ölü bir kutuydu; yalnız çıktı dosyası
    // listesi tıklanabiliyordu, tarama işlerinde (kopya/benzer/yer aç) ise
    // sonuca dönmenin hiçbir yolu yoktu — kullanıcı ekranı elle arıyordu.
    final destination = jobHasDestination(job);
    // Yarıda kalan/başarısız iş DEVAM ETTİRİLEBİLİYORSA karta dokunmak onu
    // yeniden başlatır (kullanıcı 2026-08-07: *"yarım kaldığında 'dokunun
    // devam etsin' çalışmıyor"* — kart "yeniden başlatmak için dokunun"
    // diyordu ama dokunuş yalnız klasöre gidiyordu).
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: InkWell(
        onTap: resumable
            ? () => _resume(context, job)
            : (destination
                ? () => openJobTarget(context, job, fallbackToJobs: false)
                : null),
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
                  child: Text(job.shownTitle, style: theme.textTheme.titleSmall),
                ),
                if (job.status.isActive)
                  TextButton(
                    onPressed: () => JobQueue.instance.cancel(job.id),
                    child: Text(context.t('common.stop')),
                  )
                // Görünür düğme: "karta dokun" bilgisini yalnız alt yazıya
                // gömmek, dokunulabileceğini fark ettirmiyordu.
                else if (resumable)
                  FilledButton.tonal(
                    onPressed: () => _resume(context, job),
                    child: Text(context.t('jb.resume')),
                  )
                // Ok yalnız GİDİLECEK bir yer varken: her karta ok koymak,
                // dokununca hiçbir şey olmayan kartlarda yalan olurdu.
                else if (destination)
                  Icon(AppIcons.chevron,
                      size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(sub, style: theme.textTheme.bodySmall),
            if (job.status == JobStatus.running) ...[
              const SizedBox(height: Gap.sm),
              LiveProgress(
                label: job.title,
                progress: job.progress,
                child: LinearProgressIndicator(value: job.progress),
              ),
              // "%42 · ~2 dk kaldı" — geçen süre aşağıdaki satırda.
              if (job.progress != null || job.remaining != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: Text(
                    [
                      if (job.progress != null)
                        '%${(job.progress! * 100).floor()}',
                      if (job.remaining != null)
                        context.t('job.eta',
                            {'time': roughDuration(job.remaining!)}),
                    ].join(' · '),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            // Dosya sayacı ve süre KENDİ satırında: ikisi de `detail`in
            // içinde, uzun özet metninin arasında kayboluyordu.
            if (elapsed != null || job.total > 1)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Row(
                  children: [
                    if (job.total > 1)
                      MonoText(
                        context.t('jobs.files_progress',
                            {'done': job.done, 'total': job.total}),
                      ),
                    const Spacer(),
                    if (elapsed != null)
                      MonoText(
                        job.status.isActive
                            ? context.t('jb.running_for',
                                {'time': humanDuration(elapsed)})
                            : context.t('jb.took', {
                                'status': context.t(job.status.labelKey),
                                'time': humanDuration(elapsed),
                              }),
                      ),
                  ],
                ),
              ),
            if (job.outputs.isNotEmpty) _outputs(context),
          ],
        ),
        ),
      ),
    );
  }

  /// İşi yeniden kuyruğa koyar ve sonucu SÖYLER: sessizce hiçbir şey olmaması,
  /// düzeltmeye çalıştığımız şikâyetin ta kendisiydi.
  void _resume(BuildContext context, FmJob job) {
    final resumed = JobQueue.instance.resume(job.id);
    showSnack(context, context.t(
          resumed == null ? 'jb.resume_failed' : 'jb.resume_started'));
  }

  IconData get _icon => switch (job.status) {
        JobStatus.running => AppIcons.autorenew,
        JobStatus.queued => AppIcons.schedule,
        JobStatus.done => AppIcons.checkCircle,
        JobStatus.failed => AppIcons.error,
        JobStatus.cancelled => AppIcons.unreadable,
        JobStatus.interrupted => AppIcons.powerSettingsNew,
      };

  Color? _color(ColorScheme scheme) => switch (job.status) {
        JobStatus.failed => scheme.error,
        JobStatus.done => Paper.ok,
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
                browserRoute(BrowserScreen(path: dir)),
              ),
              icon: const Icon(AppIcons.emptyFolder, size: 18),
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
            subtitle: _OutputSubtitle(path),
            // Dosya listede DURUYOR ama diskte olmayabilir (kullanıcı silmiş,
            // taşımış olabilir) — `EntryOpener` bu durumu kendisi bildiriyor.
            onTap: () => EntryOpener.open(context, path, siblings: outputs),
          ),
        if (outputs.length > _maxListed)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Text(
                context.t('count.more_files',
                    {'n': outputs.length - _maxListed}),
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
}

/// İşlemler ekranını açar (alt şerit ve pano kutusu bunu çağırır).
///
/// 2026-11-04: İşlemler artık sekmeli merkez ([OperationsScreen]) — ilk sekme
/// bu liste.
Future<void> openJobsScreen(BuildContext context) =>
    OperationsScreen.open(context);

/// "12,4 MB · Camera" — boyut diskten ARKA PLANDA okunur (çıktı gerçekten
/// orada mı?); okunana dek yalnız klasör adı görünür.
class _OutputSubtitle extends StatefulWidget {
  const _OutputSubtitle(this.path);

  final String path;

  @override
  State<_OutputSubtitle> createState() => _OutputSubtitleState();
}

class _OutputSubtitleState extends State<_OutputSubtitle> {
  String? _text;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final folder = p.basename(p.dirname(widget.path));
    String text;
    try {
      final file = File(widget.path);
      text = await file.exists()
          ? '${FsPaths.humanSize(await file.length())} · $folder'
          : AppStrings.current.t('jb.file_missing', {'folder': folder});
    } catch (_) {
      text = folder;
    }
    if (mounted) setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) =>
      MonoText(_text ?? p.basename(p.dirname(widget.path)));
}
