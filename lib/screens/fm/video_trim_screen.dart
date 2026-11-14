import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
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

/// **Videoyu kes** (Ferrari H8, 2026-11-14 — kullanıcı isteği).
///
/// Örnek: Google Fotoğraflar'ın kesme ekranı. Üstte önizleme (oynat/duraklat,
/// yalnız seçili aralık döner), altta kare şeridi + iki tutamaç
/// ([VideoTrimTimeline]), "Sesi kaldır" anahtarı ve Kaydet. Kaydet işi
/// kuyruğa verir ([startTrimJob]); özgün KORUNUR, çıktı `<ad>_kesit.mp4`.
class VideoTrimScreen extends StatefulWidget {
  const VideoTrimScreen({super.key, required this.path, this.durationMs});

  final String path;

  /// Biliniyorsa süre (önizleme açılamasa da tutamaçlar çalışsın).
  final int? durationMs;

  /// Kes ekranını açar; açık oynatıcı varsa çağıran önce duraklatır.
  static Future<void> open(BuildContext context, String path) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => VideoTrimScreen(path: path),
      ));

  @override
  State<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  VideoPlayerController? _video;
  bool _previewFailed = false;
  int _durationMs = 0;
  TrimRange _range = const TrimRange(0, 0);
  bool _mute = false;
  List<String> _frames = const [];
  Directory? _frameDir;

  @override
  void initState() {
    super.initState();
    final known = widget.durationMs ?? 0;
    if (known > 0) _setDuration(known);
    unawaited(_openPreview());
    unawaited(_loadDuration());
  }

  void _setDuration(int ms) {
    _durationMs = ms;
    _range = TrimRange(0, ms);
  }

  Future<void> _openPreview() async {
    final c = VideoPlayerController.file(File(widget.path));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _previewFailed = true);
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    c.addListener(_onTick);
    setState(() {
      _video = c;
      final ms = c.value.duration.inMilliseconds;
      if (_durationMs <= 0 && ms > 0) _setDuration(ms);
    });
  }

  /// Süre + kare şeridi yerelden (önizleme açılamasa da).
  Future<void> _loadDuration() async {
    if (_durationMs <= 0) {
      final probe = await VideoTranscoder.probe(widget.path);
      if (!mounted) return;
      if (probe != null && probe.durationMs > 0 && _durationMs <= 0) {
        setState(() => _setDuration(probe.durationMs));
      }
    }
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory(p.join(tmp.path, 'video_trim_frames',
          '${widget.path.hashCode.toUnsigned(32)}'));
      _frameDir = dir;
      final frames = await VideoTranscoder.frames(widget.path, dir: dir.path);
      if (mounted) setState(() => _frames = frames);
    } catch (_) {
      // Bilinçli: kare şeridi süs; yoksa düz şerit, tutamaçlar yine çalışır.
    }
  }

  /// Önizleme yalnız seçili aralıkta döner: bitişe gelince başa sarar.
  void _onTick() {
    final c = _video;
    if (c == null || !c.value.isPlaying) return;
    if (c.value.position.inMilliseconds >= _range.endMs) {
      unawaited(c.pause());
      unawaited(c.seekTo(Duration(milliseconds: _range.startMs)));
    }
  }

  void _togglePlay() {
    final c = _video;
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

  void _seek(int ms) {
    final c = _video;
    if (c == null) return;
    if (c.value.isPlaying) unawaited(c.pause());
    unawaited(c.seekTo(Duration(milliseconds: ms)));
  }

  bool get _canSave =>
      _durationMs > 0 && (!_range.isWhole(_durationMs) || _mute);

  void _save() {
    if (!_canSave) return;
    unawaited(_video?.pause());
    AppHaptics.done();
    startTrimJob(context, widget.path, _range, removeAudio: _mute);
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  void dispose() {
    _video
      ?..removeListener(_onTick)
      ..dispose();
    final dir = _frameDir;
    if (dir != null) {
      dir.delete(recursive: true).catchError((Object _) => dir);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.mediaSurface,
      appBar: AppBar(
        backgroundColor: AppColors.mediaSurface,
        foregroundColor: AppColors.onMedia,
        title: Text(context.t('vtr.title')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Gap.sm),
            child: FilledButton(
              key: const ValueKey('trim-save'),
              onPressed: _canSave ? _save : null,
              child: Text(context.t('common.save')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _preview(context)),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md, vertical: Gap.sm),
              child: Text(
                _durationMs <= 0
                    ? ''
                    : _range.isWhole(_durationMs)
                        ? context.t('vtr.whole')
                        : context.t('vtr.range', {
                            'start': formatClock(_range.startMs),
                            'end': formatClock(_range.endMs),
                            'n': trimSeconds(_range),
                          }),
                key: const ValueKey('trim-label'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.onMediaSoft),
              ),
            ),
            if (_durationMs > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                child: VideoTrimTimeline(
                  durationMs: _durationMs,
                  range: _range,
                  frames: _frames,
                  onChanged: (r) => setState(() => _range = r),
                  onSeek: _seek,
                ),
              ),
            SwitchListTile(
              key: const ValueKey('trim-mute'),
              value: _mute,
              onChanged: (v) => setState(() => _mute = v),
              secondary: Icon(_mute ? AppIcons.volumeOff : AppIcons.volumeUp,
                  color: AppColors.onMediaSoft),
              title: Text(context.t('vtr.mute'),
                  style: const TextStyle(color: AppColors.onMedia)),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final c = _video;
    if (c == null) {
      return Center(
        child: _previewFailed
            ? Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Text(context.t('vtr.no_preview'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.onMediaSoft)),
              )
            : const CircularProgressIndicator(),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio <= 0 ? 16 / 9 : c.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayer(c),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (context, v, _) => v.isPlaying
                    ? const SizedBox.shrink()
                    : const Center(
                        child: Icon(AppIcons.playCircle,
                            size: 64, color: AppColors.onMediaSoft),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kesme işini kuyruğa verir: kullanıcı ekranı kapatabilir; ilerleme alt
/// şeritte ve bildirimde, çıktı İşlemler ekranında (Aç / Paylaş).
void startTrimJob(
  BuildContext context,
  String path,
  TrimRange range, {
  bool removeAudio = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final str = AppStrings.of(context);
  final name = p.basename(path);
  final id = 'trim_${Object.hash(path, range.startMs, range.endMs, removeAudio)}';
  final before = JobQueue.instance.find(id);
  final alreadyRunning = before != null && before.status.isActive;
  final job = JobQueue.instance.enqueue(
    id: id,
    title: str.t('vtr.job', {'name': name}),
    name: str.t('vtr.job_name', {'name': name}),
    total: 1,
    run: (handle) async {
      handle.report(
          done: 0,
          total: 1,
          detail: '${formatClock(range.startMs)} – ${formatClock(range.endMs)}');
      final out = await VideoTranscoder.trim(path, range,
          removeAudio: removeAudio, handle: handle);
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
