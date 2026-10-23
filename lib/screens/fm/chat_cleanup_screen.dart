import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/chat_junk.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/media_library.dart';
import '../../services/fm/open_history.dart';
import 'chat_junk_bucket_screen.dart';
import 'similar_screen.dart';
import '../../core/safe_insets.dart';
import 'smart_cleanup_screen.dart';

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
  static const _jobId = ChatJunkLive.jobId;

  /// Kullanıcının seçtiği "küçük görüntü" eşiği. Değişince tarama tekrarlanır
  /// — eşik tahminin can alıcı parçası ve sabit bir sayı dayatmak yanlış olurdu.
  int _tinyBytes = defaultTinyBytes;

  @override
  void initState() {
    super.initState();
    ChatJunkLive.ensure();
    // Ekran kapalıyken (ör. kova ekranından, panodan) silinenler de düşsün.
    ChatJunkLive.prune();
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
      name: strings.t('cj.job_name'),
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
        handle.report(detail: ChatJunkLive.summary(report, strings));
        ChatJunkLive.ensure();
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
            icon: const Icon(AppIcons.refresh),
            onPressed: _loading ? null : _scan,
          ),
        ],
      ),
      body: ListView(
        padding: withNavInset(
            context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl)),
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
          _smartCard(),
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
        trailing: const Icon(AppIcons.chevron),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatJunkBucketScreen(bucket: bucket),
        )),
      ),
    );
  }

  /// Kovaların ulaşamadığı yığın: aynı anın birden çok karesi.
  /// İçeriğe bakan akıllı analiz (selamlaşma görselleri, yazılı mem, bulanık).
  Widget _smartCard() => Card(
        child: ListTile(
          key: const ValueKey('cj-smart'),
          leading: const Icon(AppIcons.ai),
          title: Text(context.t('sa.title')),
          subtitle: Text(context.t('sa.card_sub')),
          trailing: const Icon(AppIcons.chevron),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SmartCleanupScreen())),
        ),
      );

  Widget _similarCard() => Card(
        child: ListTile(
          leading: const Icon(AppIcons.burstMode),
          title: Text(context.t('cj.similar_title')),
          subtitle: Text(context.t('cj.similar_body')),
          trailing: const Icon(AppIcons.chevron),
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
        ChatJunkKind.duplicate => AppIcons.copyAll,
        ChatJunkKind.sticker => AppIcons.emojiEmotions,
        ChatJunkKind.gif => AppIcons.gifBox,
        ChatJunkKind.profilePhoto => AppIcons.accountCircle,
        ChatJunkKind.tiny => AppIcons.photoSizeSelectSmall,
        ChatJunkKind.sent => AppIcons.send,
        ChatJunkKind.stale => AppIcons.historyToggleOff,
      };
}

/// Sohbet temizliği sonucunu **canlı** tutar: dosya silinince/taşınınca
/// kovalar, sayılar ve pano şeridindeki "N dosya · X MB geri kazanılabilir"
/// satırı kendiliğinden güncellenir (yenile'ye basmadan).
///
/// Süreç başına tek dinleyici; ekran kapalıyken de çalışır (şerit panoda).
/// Var olma denetimi arka izlekte ([FsScan.pruneMissing]); art arda gelen
/// sinyaller tek tura iner.
abstract final class ChatJunkLive {
  static const jobId = 'chat_junk_scan';
  static bool _listening = false;
  static bool _busy = false;
  static bool _again = false;

  static void ensure() {
    if (_listening) return;
    _listening = true;
    FsEvents.version.addListener(prune);
  }

  static String summary(ChatJunkReport report, AppStrings strings) =>
      report.junkFiles == 0
          ? strings.t('cj.step_clean')
          : strings.t('cj.step_summary', {
              'n': report.junkFiles,
              'size': FsPaths.humanSize(report.junkBytes),
            });

  static Future<void> prune() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        final job = JobQueue.instance.find(jobId);
        final report = job?.result;
        if (job == null ||
            job.status.isActive ||
            report is! ChatJunkReport ||
            report.junkFiles == 0) {
          return;
        }
        final all = report.junkEntries;
        final alive = await FsScan.pruneMissing(all.values.toList());
        if (alive.length == all.length) continue;
        final keep = {for (final e in alive) e.path};
        // Tarama arada yenilendiyse eski sonucu yeninin üstüne yazma.
        if (!identical(job.result, report)) continue;
        final next = report.keepOnly(keep.contains);
        job.result = next;
        job.detail = summary(next, AppStrings.current);
        JobQueue.instance.refreshFinished(job);
      } while (_again);
    } catch (_) {
      // Bilinçli: canlı budama bir kolaylık; başarısızsa "Yeniden tara" var.
    } finally {
      _busy = false;
    }
  }
}

/// Sohbet temizliği ekranını açar (pano kutusu ve iş hedefi buradan geçer).
Future<void> openChatCleanupScreen(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatCleanupScreen()),
    );
