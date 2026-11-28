import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/video_trim.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/video_transcode.dart';
import '../../widgets/fm/video_trim_timeline.dart';

/// **Sesi kes** (2026-11-14, kullanıcı: *"ses dosyalarında aynı video gibi
/// kesme olmalı ve ses oynatılıyorsa canlı olarak o andan kısa
/// oynatılmalı"*).
///
/// Video kesmedeki şerit ([VideoTrimTimeline]) karesiz kullanılır. Tutamaç
/// sürüklenirken o andan kısa bir parça ([_snippet]) çalınır; bırakınca
/// önceden çalıyorsa oradan sürer, çalmıyorsa durur. Kaydet: iş kuyruğunda
/// yerel kırpma (Media3) → `<ad>_kesit.m4a`, asıl dosya değişmez.
class AudioTrimScreen extends StatefulWidget {
  final String path;

  const AudioTrimScreen({super.key, required this.path});

  static Future<void> open(BuildContext context, String path) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AudioTrimScreen(path: path),
      ));

  @override
  State<AudioTrimScreen> createState() => _AudioTrimScreenState();
}

class _AudioTrimScreenState extends State<AudioTrimScreen> {
  VideoPlayerController? _player;
  AppLifecycleListener? _life;
  bool _failed = false;
  int _durationMs = 0;
  TrimRange _range = const TrimRange(0, 0);
  int _positionMs = 0;

  /// Sürükleme başladığında çalıyor muydu (bırakınca sürsün mü).
  bool? _wasPlaying;
  Timer? _snippetStop;
  Timer? _seekDebounce;

  /// Kısa dinleme parçasının uzunluğu ve arama birleştirme aralığı (ms).
  /// Görsel hareket değil ses süresi → Motion tokenı değil.
  static const _snippetMs = 600;
  static const _seekCoalesceMs = 50;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onPause: () => unawaited(_player?.pause()),
      onHide: () => unawaited(_player?.pause()),
    );
    unawaited(_open());
  }

  Future<void> _open() async {
    final c = VideoPlayerController.file(File(widget.path));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    c.addListener(_onTick);
    setState(() {
      _player = c;
      _durationMs = c.value.duration.inMilliseconds;
      _range = TrimRange(0, _durationMs);
    });
  }

  void _onTick() {
    final c = _player;
    if (c == null || !mounted) return;
    final pos = c.value.position.inMilliseconds;
    // Sürükleme sürerken oynatıcı konumu çizgiyi parmaktan geri çekmesin.
    if (_wasPlaying == null && pos != _positionMs) {
      setState(() => _positionMs = pos);
    }
    // Normal çalmada seçimin sonunda dur, başa sar.
    if (_wasPlaying == null && c.value.isPlaying && pos >= _range.endMs) {
      unawaited(c.pause());
      unawaited(c.seekTo(Duration(milliseconds: _range.startMs)));
    }
  }

  void _togglePlay() {
    final c = _player;
    if (c == null) return;
    AppHaptics.selection();
    if (c.value.isPlaying) {
      unawaited(c.pause());
      return;
    }
    final pos = c.value.position.inMilliseconds;
    if (pos < _range.startMs || pos >= _range.endMs - 100) {
      unawaited(c.seekTo(Duration(milliseconds: _range.startMs)));
    }
    unawaited(c.play());
  }

  /// Tutamaç sürükleniyor: o andan kısa parça çal (canlı dinleme).
  void _seek(int ms) {
    final c = _player;
    _wasPlaying ??= c?.value.isPlaying ?? false;
    setState(() => _positionMs = ms);
    if (c == null) return;
    // Saniyede onlarca konum gelir: 50 ms içinde yalnız sonuncusu aranır.
    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: _seekCoalesceMs), () async {
      if (!mounted || !identical(c, _player)) return;
      await c.seekTo(Duration(milliseconds: ms));
      if (!mounted || !identical(c, _player)) return;
      if (!c.value.isPlaying) unawaited(c.play());
      _snippetStop?.cancel();
      _snippetStop = Timer(const Duration(milliseconds: _snippetMs), () {
        // Hâlâ sürükleniyorsa ve yeni arama gelmediyse kısa parça biter.
        if (mounted && _wasPlaying != null) unawaited(c.pause());
      });
    });
  }

  void _endScrub() {
    final was = _wasPlaying;
    _wasPlaying = null;
    _snippetStop?.cancel();
    _seekDebounce?.cancel();
    final c = _player;
    if (c == null || was == null) return;
    if (was) {
      unawaited(c.play());
    } else {
      unawaited(c.pause());
    }
  }

  bool get _canSave =>
      _durationMs > 0 &&
      _range.lengthMs > 0 &&
      (_range.startMs > 0 || _range.endMs < _durationMs);

  void _save() {
    if (!_canSave) return;
    unawaited(_player?.pause());
    AppHaptics.done();
    startAudioTrimJob(context, widget.path, _range);
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  void dispose() {
    _life?.dispose();
    _snippetStop?.cancel();
    _seekDebounce?.cancel();
    _player
      ?..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = _player;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('atr.title')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Gap.sm),
            child: FilledButton(
              key: const ValueKey('atr-save'),
              onPressed: _canSave ? _save : null,
              child: Text(context.t('common.save')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _failed
            ? Center(child: Text(context.t('atr.failed')))
            : c == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.audio,
                                  size: 72, color: scheme.primary),
                              const SizedBox(height: Gap.md),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: Gap.lg),
                                child: Text(
                                  p.basename(widget.path),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(height: Gap.lg),
                              ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: c,
                                builder: (context, v, _) => IconButton.filled(
                                  key: const ValueKey('atr-play'),
                                  tooltip: v.isPlaying
                                      ? context.t('common.pause')
                                      : context.t('mp.play'),
                                  iconSize: 40,
                                  onPressed: _togglePlay,
                                  icon: Icon(v.isPlaying
                                      ? AppIcons.pause
                                      : AppIcons.play),
                                ),
                              ),
                              const SizedBox(height: Gap.md),
                              Text(context.t('atr.hint'),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md, vertical: Gap.xs),
                        child: Row(
                          children: [
                            Text(formatClock(_positionMs),
                                style: theme.textTheme.bodyMedium),
                            const Spacer(),
                            Text(
                              context.t('atr.result',
                                  {'t': formatClock(_range.lengthMs)}),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (_durationMs > 0)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: Gap.md),
                          child: VideoTrimTimeline(
                            durationMs: _durationMs,
                            range: _range,
                            playheadMs: _positionMs,
                            onChanged: (r) => setState(() => _range = r),
                            onSeek: _seek,
                            onDragEnd: _endScrub,
                          ),
                        ),
                      const SizedBox(height: Gap.lg),
                    ],
                  ),
      ),
    );
  }
}

/// Ses kesme işini kuyruğa verir; çıktı İşlemler ekranında.
void startAudioTrimJob(BuildContext context, String path, TrimRange range) {
  final messenger = ScaffoldMessenger.of(context);
  final str = AppStrings.of(context);
  final name = p.basename(path);
  final id = 'atrim_${Object.hash(path, range)}';
  final before = JobQueue.instance.find(id);
  final alreadyRunning = before != null && before.status.isActive;
  final job = JobQueue.instance.enqueue(
    id: id,
    title: str.t('atr.job', {'name': name}),
    name: str.t('atr.job', {'name': name}),
    total: 1,
    run: (handle) async {
      handle.report(done: 0, total: 1, detail: formatClock(range.lengthMs));
      final out = await VideoTranscoder.trim(path, range,
          audioOnly: true, handle: handle);
      handle.addOutput(out, source: path);
      handle.report(done: 1, total: 1);
      FsEvents.changed([out]);
    },
  );
  showSnackOn(
      messenger,
      str.t(alreadyRunning
          ? 'ra.already_running'
          : job.status == JobStatus.queued && JobQueue.instance.hasActive
              ? 'ra.queued'
              : 'ra.started'));
}
