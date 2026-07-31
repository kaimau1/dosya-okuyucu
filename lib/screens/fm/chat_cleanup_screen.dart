import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/chat_junk.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/media_library.dart';
import '../../services/fm/open_history.dart';
import 'chat_junk_bucket_screen.dart';
import 'similar_screen.dart';

/// **Sohbet medyası temizliği** — "WhatsApp'tan 10 bin fotoğraf var, %90'ı
/// gereksiz" sorusunun karşılığı (kullanıcı 2026-07-31).
///
/// Yaklaşım `services/fm/chat_junk.dart`ın başında anlatılıyor: 10 bin kararı
/// birkaç karara indirmek. Ekran taramayı iş kuyruğuna verir (arka planda
/// sürer, ekran kapansa da kaybolmaz), sonucu kovalar hâlinde gösterir ve
/// kova içine girip toplu silmeye götürür.
///
/// Kovalar bittiğinde iş bitmiyor: geri kalanın büyük kısmı "aynı anın 5
/// karesi" oluyor ve onu ancak görüntüyü çözen bir tarama bulabilir. Ekranın
/// altında **Benzer görüntüler** taramasına (WhatsApp kapsamıyla) bir kapı var.
class ChatCleanupScreen extends StatefulWidget {
  const ChatCleanupScreen({super.key});

  @override
  State<ChatCleanupScreen> createState() => _ChatCleanupScreenState();
}

class _ChatCleanupScreenState extends State<ChatCleanupScreen> {
  static const _jobId = 'chat_junk_scan';

  /// Kullanıcının seçtiği "küçük görüntü" eşiği. Değişince tarama tekrarlanır
  /// — eşik tahminin can alıcı parçası ve sabit bir sayı dayatmak yanlış olurdu.
  int _tinyBytes = defaultTinyBytes;

  @override
  void initState() {
    super.initState();
    JobQueue.instance.addListener(_onQueue);
    final job = JobQueue.instance.find(_jobId);
    final hasResult = job?.result is ChatJunkReport;
    if (job == null || (!hasResult && !job.status.isActive)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
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

  bool get _loading => _job?.status.isActive ?? false;

  ChatJunkReport get _report {
    final result = _job?.result;
    return result is ChatJunkReport ? result : ChatJunkReport.empty;
  }

  void _scan() {
    // Kuyruk işi ekran kapansa da sürer → metinler ŞİMDİ çözülür.
    final strings = AppStrings.of(context);
    final tiny = _tinyBytes;
    JobQueue.instance.enqueue(
      id: _jobId,
      title: strings.t('cj.job_title'),
      target: const FmJobTarget(FmJobTargetKind.chatCleanup),
      run: (handle) async {
        handle.report(detail: strings.t('cj.step_listing'));
        // Tüm dosyalar (kategori süzgeci YOK): sohbet klasöründe belge ve ses
        // de var ve "gönderdiklerim" kovası onları da kapsıyor.
        final all = await MediaLibrary.categoryFiles(null);
        handle.throwIfCancelled();

        final media = [
          for (final e in all)
            if (!e.isDir && isChatMediaPath(e.path)) e,
        ];
        handle.report(
            total: media.length,
            done: media.length,
            detail: strings.t('cj.step_found', {'n': media.length}));
        if (media.isEmpty) {
          handle.result = ChatJunkReport.empty;
          handle.report(detail: strings.t('cj.step_none'));
          return;
        }

        // Kopya taraması YALNIZ sohbet klasörlerinde: tüm depolamayı bayt bayt
        // karşılaştırmak dakikalar sürüyor, buradaki soru "WhatsApp yığını".
        handle.report(detail: strings.t('cj.step_duplicates'));
        final groups = await DuplicateFinder.scanPaths(media);
        handle.throwIfCancelled();

        handle.report(detail: strings.t('cj.step_sorting'));
        await OpenHistory.ensureLoaded();
        final report = classifyChatJunk(
          entries: media,
          nowMs: DateTime.now().millisecondsSinceEpoch,
          duplicateGroups: [for (final g in groups) g.files],
          tinyBytes: tiny,
          wasOpened: (path) => OpenHistory.forPath(path) != null,
        );
        handle.result = report;
        handle.report(
          detail: report.junkFiles == 0
              ? strings.t('cj.step_clean')
              : strings.t('cj.step_summary', {
                  'n': report.junkFiles,
                  'size': FsPaths.humanSize(report.junkBytes),
                }),
        );
      },
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('cj.title')),
        actions: [
          IconButton(
            tooltip: context.t('cj.rescan'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _scan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
        children: [
          if (_loading) ...[
            LinearProgressIndicator(value: _job?.progress),
            const SizedBox(height: Gap.sm),
            Text(_job?.detail ?? context.t('cj.step_listing'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Gap.md),
          ],
          _summary(report),
          const SizedBox(height: Gap.md),
          _tinyThresholdRow(),
          const SizedBox(height: Gap.md),
          if (!_loading && report.buckets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xl),
              child: Center(
                child: Text(
                  report.scannedFiles == 0
                      ? context.t('cj.empty_no_media')
                      : context.t('cj.empty_clean'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          for (final bucket in report.buckets) _bucketCard(bucket),
          const SizedBox(height: Gap.md),
          _similarCard(),
        ],
      ),
    );
  }

  /// "10 binin 8.900'ü (%89) · 6,2 GB" — kullanıcının iddiasının ölçülmüş hâli.
  Widget _summary(ChatJunkReport report) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('cj.scanned', {
                'n': report.scannedFiles,
                'size': FsPaths.humanSize(report.scannedBytes),
              }),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              report.junkFiles == 0
                  ? context.t('cj.summary_none')
                  : context.t('cj.summary', {
                      'n': report.junkFiles,
                      'percent': report.junkPercent,
                      'size': FsPaths.humanSize(report.junkBytes),
                    }),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.xs),
            // Dürüst sınır ekranda: "gereksiz" bir tahmin, karar kullanıcının.
            Text(context.t('cj.disclaimer'),
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _tinyThresholdRow() => Row(
        children: [
          Expanded(
            child: Text(context.t('cj.tiny_threshold'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
          DropdownButton<int>(
            value: _tinyBytes,
            onChanged: _loading
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _tinyBytes = v);
                    _scan();
                  },
            items: [
              for (final bytes in tinyBytesChoices)
                DropdownMenuItem(
                    value: bytes, child: Text(FsPaths.humanSize(bytes))),
            ],
          ),
        ],
      );

  Widget _bucketCard(ChatJunkBucket bucket) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ListTile(
        leading: Icon(_iconFor(bucket.kind)),
        title: Text(context.t(bucket.kind.labelKey)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.t('count.files', {'n': bucket.count})} · '
                '${FsPaths.humanSize(bucket.bytes)}'),
            Text(context.t(bucket.kind.reasonKey),
                style: theme.textTheme.bodySmall),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatJunkBucketScreen(bucket: bucket),
        )),
      ),
    );
  }

  /// Kovaların ulaşamadığı yığın: aynı anın birden çok karesi.
  Widget _similarCard() => Card(
        child: ListTile(
          leading: const Icon(Icons.burst_mode_outlined),
          title: Text(context.t('cj.similar_title')),
          subtitle: Text(context.t('cj.similar_body')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SimilarScreen(
              scopeId: 'chat',
              title: context.t('cj.similar_title'),
              loadAll: () async {
                final all = await MediaLibrary.categoryFiles(null);
                return [
                  for (final e in all)
                    if (!e.isDir && isChatMediaPath(e.path)) e,
                ];
              },
            ),
          )),
        ),
      );

  IconData _iconFor(ChatJunkKind kind) => switch (kind) {
        ChatJunkKind.duplicate => Icons.copy_all_outlined,
        ChatJunkKind.sticker => Icons.emoji_emotions_outlined,
        ChatJunkKind.gif => Icons.gif_box_outlined,
        ChatJunkKind.profilePhoto => Icons.account_circle_outlined,
        ChatJunkKind.tiny => Icons.photo_size_select_small_outlined,
        ChatJunkKind.sent => Icons.send_outlined,
        ChatJunkKind.stale => Icons.history_toggle_off,
      };
}

/// Sohbet temizliği ekranını açar (pano kutusu ve iş hedefi buradan geçer).
Future<void> openChatCleanupScreen(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatCleanupScreen()),
    );
