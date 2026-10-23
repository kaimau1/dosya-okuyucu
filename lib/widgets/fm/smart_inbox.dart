import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../screens/fm/history_screen.dart';
import '../../screens/fm/job_navigation.dart';
import '../../services/fm/job_queue.dart';
import '../live_progress.dart';

/// Panonun hesapladığı **önemli olay** (bellek dolu, çöp şişti, USB takılı…).
///
/// İş kuyruğundan gelmeyen ama kullanıcının bilmesi gereken durum. Kimlik
/// oturum boyunca "kapattım" bilgisini tutar; olay ortadan kalkıp yeniden
/// doğarsa (ör. çöp boşaldı, sonra yine doldu) yeni bir kimlikle gelmesi
/// çağıranın işi (kimliğe eşik yazılır).
class InboxEvent {
  final String id;
  final IconData icon;

  /// Vurgu: uyarı (hata rengi) mı, bilgi (ana renk) mi.
  final bool warning;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback onTap;

  /// Kapatılabilir mi? (Ağdan erişim açıkken satır kapatılamaz — telefon ağa
  /// açık kalıp unutulmasın; eylem düğmesi paylaşımı kapatır.)
  final bool dismissible;

  /// Eylem düğmesi [onTap]'tan farklı bir iş yapıyorsa (ör. "Kapat").
  final VoidCallback? onAction;

  const InboxEvent({
    this.dismissible = true,
    this.onAction,
    required this.id,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.actionLabel,
    this.warning = false,
  });
}

/// **Akıllı bildirim alanı** — panonun en üstü (2026-10-23).
///
/// Kullanıcı: *"yakında bitmiş işler, şu an devam eden işler ve önemli olaylar
/// göz yormadan, çok yer kaplamadan, dikkatli biçimde gösterilmeli; hoş ve
/// sade olmalı, gereksiz bilgi içermemeli"* ve *"kişi uygulamanın
/// bildirimlerini kapatmış olabilir — ana ekranda daha görünür, üstte bir
/// bildirim ve biten işler bölmesi"*.
///
/// Kurallar:
/// - **Boşken HİÇ çizilmez** (boş "bildirim yok" kartı yer israfı).
/// - En çok [maxRows] satır; fazlası "+N · Tümü" ile Geçmiş › İşlemler'e.
/// - Sıra: süren işler → önemli olaylar → bitmiş (kapatılmamış) sonuçlar.
///   Süren iş canlı: halka + "%42 · ~2 dk kaldı", saniyede bir tazelenir.
/// - Bitmiş sonuç kullanıcı kapatana kadar durur ([JobQueue.dismiss]); son
///   [_recent]'ten eski sonuçlar burada gösterilmez (İşlemler'de kalır).
/// - Panodayken alt iş şeridi gizlenir (aynı iş iki yerde görünmesin —
///   bkz. `JobProgressBar.hidden`).
class SmartInbox extends StatefulWidget {
  final List<InboxEvent> events;
  final int maxRows;

  const SmartInbox({super.key, this.events = const [], this.maxRows = 3});

  /// Oturum boyunca kapatılan olay kimlikleri.
  static final Set<String> _dismissedEvents = {};

  @visibleForTesting
  static void resetForTest() => _dismissedEvents.clear();

  @override
  State<SmartInbox> createState() => _SmartInboxState();
}

class _SmartInboxState extends State<SmartInbox> {
  static const _recent = Duration(hours: 24);
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    JobQueue.instance.addListener(_onQueue);
    _syncClock();
  }

  @override
  void dispose() {
    JobQueue.instance.removeListener(_onQueue);
    _clock?.cancel();
    super.dispose();
  }

  void _onQueue() {
    if (!mounted) return;
    _syncClock();
    setState(() {});
  }

  /// Saat yalnız süren iş varken işler ("takıldı mı?" sorusu kalmasın diye
  /// kalan süre saniyede bir yazılır); boşta pil yemez.
  void _syncClock() {
    final active = JobQueue.instance.hasActive;
    if (active && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!active) {
      _clock?.cancel();
      _clock = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = JobQueue.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    final running = queue.activeJobs;
    final finished = [
      for (final j in queue.finishedJobs)
        if (!j.dismissed &&
            (j.finishedAtMs == 0 ||
                now - j.finishedAtMs < _recent.inMilliseconds))
          j,
    ];
    final events = [
      for (final e in widget.events)
        if (!SmartInbox._dismissedEvents.contains(e.id)) e,
    ];
    final rows = <Widget>[
      for (final j in running) _JobRow(job: j),
      for (final e in events)
        _EventRow(
          event: e,
          onDismiss: () =>
              setState(() => SmartInbox._dismissedEvents.add(e.id)),
        ),
      for (final j in finished) _JobRow(job: j),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final shown = rows.take(widget.maxRows).toList();
    final hidden = rows.length - shown.length;
    final scheme = Theme.of(context).colorScheme;
    final radius = context.fmCardRadius;
    return Padding(
      key: const ValueKey('smart-inbox'),
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    indent: Gap.md + 32,
                    color: scheme.outlineVariant.withValues(alpha: 0.6)),
              shown[i],
            ],
            if (hidden > 0 || finished.length > 1)
              _Footer(
                hidden: hidden,
                onClear: finished.isEmpty
                    ? null
                    : () {
                        for (final j in finished) {
                          queue.dismiss(j.id);
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }
}

/// Ortak satır iskeleti: 28 dp simge kabı · başlık + tek satır ayrıntı · sağ
/// eylem. Tüm satırlar aynı boyda (tek tip görünüm).
class _Row extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final List<Widget> trailing;
  final VoidCallback onTap;

  const _Row({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleColor,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              Gap.md, Gap.xs + 2, Gap.xs, Gap.xs + 2),
          child: Row(
            children: [
              SizedBox.square(dimension: 28, child: Center(child: leading)),
              const SizedBox(width: Gap.sm + 4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtitleColor ?? Paper.faint(context),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                  ],
                ),
              ),
              ...trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  final FmJob job;
  const _JobRow({required this.job});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (job.status.isActive) {
      final status = job.statusLine;
      final line = [
        if (job.detail.isNotEmpty) job.detail,
        if (status.isNotEmpty) status,
      ].join(' · ');
      return _Row(
        leading: LiveProgress(
          label: job.title,
          progress: job.progress,
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              value: job.progress,
              strokeWidth: 2.5,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ),
        title: job.title,
        subtitle: line.isEmpty ? context.t('inbox.running') : line,
        subtitleColor: scheme.primary,
        onTap: () => openJobTarget(context, job),
        trailing: [
          TextButton(
            onPressed: job.cancelRequested
                ? null
                : () => JobQueue.instance.cancel(job.id),
            child: Text(context
                .t(job.cancelRequested ? 'jp.cancelling' : 'jp.cancel')),
          ),
        ],
      );
    }
    final failed = job.status == JobStatus.failed;
    final summary = switch (job.status) {
      JobStatus.failed => job.error ?? context.t('job.error_generic'),
      JobStatus.cancelled => job.detail.isEmpty
          ? context.t('jb.cancelled')
          : context.t('jb.cancelled_detail', {'detail': job.detail}),
      _ => job.detail.isEmpty ? context.t(job.status.labelKey) : job.detail,
    };
    final when = job.finishedAtMs == 0
        ? ''
        : _ago(context, DateTime.now().millisecondsSinceEpoch - job.finishedAtMs);
    return _Row(
      leading: Icon(
        switch (job.status) {
          JobStatus.failed => AppIcons.error,
          JobStatus.cancelled => AppIcons.unreadable,
          _ => AppIcons.checkCircle,
        },
        size: 22,
        color: failed ? scheme.error : Paper.success(context),
      ),
      title: job.shownTitle,
      subtitle: when.isEmpty ? summary : '$summary · $when',
      subtitleColor: failed ? scheme.error : null,
      onTap: () => openJobTarget(context, job),
      trailing: [
        if (jobHasDestination(job))
          TextButton(
            onPressed: () => openJobTarget(context, job),
            child: Text(context.t('jp.show')),
          ),
        IconButton(
          tooltip: context.t('common.close'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(AppIcons.close, size: 18),
          onPressed: () => JobQueue.instance.dismiss(job.id),
        ),
      ],
    );
  }

  /// "şimdi" / "5 dk önce" / "3 sa önce" — saat yazmaktan kısa ve göz yormaz.
  static String _ago(BuildContext context, int ms) {
    final m = ms ~/ 60000;
    if (m < 1) return context.t('inbox.just_now');
    if (m < 60) return context.t('inbox.min_ago', {'n': m});
    return context.t('inbox.hour_ago', {'n': m ~/ 60});
  }
}

class _EventRow extends StatelessWidget {
  final InboxEvent event;
  final VoidCallback onDismiss;
  const _EventRow({required this.event, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = event.warning ? scheme.error : scheme.primary;
    return _Row(
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(event.icon, size: 16, color: color),
      ),
      title: event.title,
      subtitle: event.subtitle,
      onTap: event.onTap,
      trailing: [
        if (event.actionLabel != null)
          TextButton(
              onPressed: event.onAction ?? event.onTap,
              child: Text(event.actionLabel!)),
        if (event.dismissible)
          IconButton(
            tooltip: context.t('common.close'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(AppIcons.close, size: 18),
            onPressed: onDismiss,
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final int hidden;
  final VoidCallback? onClear;
  const _Footer({required this.hidden, this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: Gap.sm, end: Gap.xs),
        child: Row(
          children: [
            if (onClear != null)
              TextButton(
                key: const ValueKey('inbox-clear'),
                onPressed: onClear,
                child: Text(context.t('inbox.clear_done')),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => HistoryScreen.open(context, HistorySection.jobs),
              child: Text(hidden > 0
                  ? context.t('inbox.more', {'n': hidden})
                  : context.t('inbox.all')),
            ),
          ],
        ),
      ),
    );
  }
}
