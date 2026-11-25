import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/media_library.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/smart_analysis.dart';
import '../../services/ocr_service.dart';
import '../../widgets/motion.dart';
import 'chat_junk_bucket_screen.dart';
import 'trash_screen.dart';

/// Analiz sonucu (iş kuyruğunda tutulur — ekran kapansa da kaybolmaz).
class SmartReport {
  final List<SmartBucket> buckets;
  final int scanned;
  final int trashCount;
  final int trashBytes;
  const SmartReport(this.buckets, this.scanned, this.trashCount, this.trashBytes);
}

/// **Akıllı temizlik analizi** (2026-10-22) — içeriğe bakan tarama:
/// WhatsApp/Telegram görsellerinde selamlaşma ("günaydın", "hayırlı
/// cumalar"), yazılı mem/afiş, bulanık ve karanlık kareler, ekran
/// görüntüleri; belgelerde kopya indirmeler ve bir yıldır açılmamış
/// indirilenler; çöp kutusu özeti. Her kova gözle bakılıp seçilerek silinir
/// (çöp kutusuna gider, geri alınabilir).
class SmartCleanupScreen extends StatefulWidget {
  const SmartCleanupScreen({super.key});

  @override
  State<SmartCleanupScreen> createState() => _SmartCleanupScreenState();
}

class _SmartCleanupScreenState extends State<SmartCleanupScreen> {
  static const _jobId = 'smart_analysis';

  @override
  void initState() {
    super.initState();
    JobQueue.instance.addListener(_onQueue);
  }

  @override
  void dispose() {
    JobQueue.instance.removeListener(_onQueue);
    super.dispose();
  }

  void _onQueue() {
    if (mounted) setState(() {});
  }

  FmJob? get _job => JobQueue.instance.find(_jobId);
  bool get _running => _job?.status.isActive ?? false;
  SmartReport? get _report {
    final r = _job?.result;
    return r is SmartReport ? r : null;
  }

  void _start() {
    final strings = AppStrings.of(context);
    JobQueue.instance.enqueue(
      id: _jobId,
      title: strings.t('sa.job_title'),
      name: strings.t('sa.job_name'),
      target: const FmJobTarget(FmJobTargetKind.chatCleanup),
      run: (handle) async {
        handle.report(detail: strings.t('cj.step_listing'));
        final all = await MediaLibrary.categoryFiles(null);
        handle.throwIfCancelled();
        final buckets = <SmartBucket>[];
        // 1) Sohbet görselleri — içerik analizi.
        final cache = File(p.join(FmEnv.appSupportDir, 'smart_analysis.json'));
        final images = await SmartAnalysis.analyzeChatImages(
          all,
          ocr: OcrService.recognizeImageFile,
          cacheFile: cache,
          isCancelled: () => handle.cancelled,
          onProgress: (done, total) => handle.report(
            done: done,
            total: total,
            detail: strings.t('sa.step_images', {'n': done, 'total': total}),
          ),
        );
        buckets.addAll(images);
        handle.throwIfCancelled();
        // 2) Belgeler.
        handle.report(detail: strings.t('sa.step_docs'));
        final docs = [
          for (final e in all)
            if (!e.isDir && e.category == FmCategory.document) e,
        ];
        final copies = SmartAnalysis.copyNamed(docs);
        if (copies.isNotEmpty) {
          buckets.add(SmartBucket(SmartKind.copyNamed, copies));
        }
        await OpenHistory.ensureLoaded();
        final old = SmartAnalysis.oldUnopened(docs,
            nowMs: DateTime.now().millisecondsSinceEpoch,
            wasOpened: (path) => OpenHistory.forPath(path) != null);
        if (old.isNotEmpty) buckets.add(SmartBucket(SmartKind.oldUnopened, old));
        // 3) Çöp kutusu.
        await FmEnv.ensureInit();
        final trash = await FmEnv.trash.list();
        final trashBytes = trash.fold<int>(0, (a, t) => a + t.sizeBytes);
        buckets.sort((a, b) => b.bytes.compareTo(a.bytes));
        handle.result = SmartReport(buckets, all.length, trash.length, trashBytes);
        final total = buckets.fold<int>(0, (a, b) => a + b.bytes);
        handle.report(
            detail: strings.t('sa.step_done', {
          'n': buckets.fold<int>(0, (a, b) => a + b.files.length),
          'size': FsPaths.humanSize(total),
        }));
      },
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('sa.title'))),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          Text(context.t('sa.intro'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: Gap.md),
          if (_running) ...[
            LinearProgressIndicator(
              value: (_job?.total ?? 0) > 0
                  ? (_job!.done / _job!.total).clamp(0.0, 1.0)
                  : null,
            ),
            const SizedBox(height: Gap.xs),
            Text(_job?.detail ?? '', style: theme.textTheme.bodySmall),
          ] else
            FilledButton.icon(
              key: const ValueKey('sa-start'),
              onPressed: _start,
              icon: const Icon(AppIcons.ai),
              label: Text(context.t(report == null ? 'sa.start' : 'sa.rescan')),
            ),
          const SizedBox(height: Gap.md),
          if (report != null && !_running) ...[
            if (report.buckets.isEmpty)
              FmEmptyState(
                  icon: AppIcons.cleanEmpty, title: context.t('sa.clean')),
            for (final b in report.buckets)
              Card(
                child: ListTile(
                  key: ValueKey('sa-bucket-${b.kind.name}'),
                  leading: Icon(_icon(b.kind), color: theme.colorScheme.primary),
                  title: Text(context.t(b.kind.labelKey)),
                  subtitle: Text(
                      '${context.t('count.files', {'n': b.files.length})} · '
                      '${FsPaths.humanSize(b.bytes)}\n'
                      '${context.t(b.kind.reasonKey)}'),
                  isThreeLine: true,
                  trailing: const Icon(AppIcons.chevron),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatJunkBucketScreen.custom(
                      files: b.files,
                      titleKey: b.kind.labelKey,
                      reasonKey: b.kind.reasonKey,
                    ),
                  )),
                ),
              ),
            if (report.trashCount > 0)
              Card(
                child: ListTile(
                  leading: Icon(AppIcons.delete, color: theme.colorScheme.error),
                  title: Text(context.t('sa.trash_title')),
                  subtitle: Text(context.t('sa.trash_sub', {
                    'n': report.trashCount,
                    'size': FsPaths.humanSize(report.trashBytes),
                  })),
                  trailing: const Icon(AppIcons.chevron),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TrashScreen())),
                ),
              ),
          ],
        ],
      ),
    );
  }

  IconData _icon(SmartKind k) => switch (k) {
        SmartKind.greeting => AppIcons.greeting,
        SmartKind.textHeavy => AppIcons.ocr,
        SmartKind.blurry => AppIcons.blur,
        SmartKind.dark => AppIcons.dark,
        SmartKind.screenshot => AppIcons.screenshot,
        SmartKind.copyNamed => AppIcons.copy,
        SmartKind.oldUnopened => AppIcons.history,
      };
}
