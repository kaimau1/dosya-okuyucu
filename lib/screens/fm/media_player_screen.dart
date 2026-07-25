import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';

/// Uygulama içi **video ve ses** oynatıcı.
///
/// Tek ekran ikisini de oynatır: ses dosyasında görüntü katmanı yoktur
/// (`size` boş gelir), onun yerine kapak alanı + dosya adı gösterilir.
/// Oynatma motoru ExoPlayer/Media3 (`video_player`), yani cihazın kendi
/// codec'leri kullanılır — mp4/mkv/webm/mp3/m4a/flac… hepsi sistemin
/// desteklediği ölçüde çalar.
///
/// **Çalma listesi:** aynı klasördeki diğer medya dosyaları verilir; sağa/sola
/// kaydırma ve ileri/geri düğmeleri arasında gezinir, dosya bitince sıradakine
/// geçer.
class MediaPlayerScreen extends StatefulWidget {
  final String path;

  /// Aynı klasördeki medya dosyaları (bu dosya da içinde). Boşsa tek dosya.
  final List<String> playlist;

  const MediaPlayerScreen({
    super.key,
    required this.path,
    this.playlist = const [],
  });

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  VideoPlayerController? _controller;
  late List<String> _playlist;
  late int _index;
  bool _loading = true;
  String? _error;
  bool _controlsVisible = true;
  bool _landscape = false;
  double _speed = 1.0;
  Timer? _hideTimer;

  String get _current => _playlist[_index];
  bool get _isAudio =>
      FsEntry.categoryForExtension(p.extension(_current).replaceFirst('.', ''))
          == FmCategory.audio;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist.isEmpty ? [widget.path] : widget.playlist;
    _index = _playlist.indexOf(widget.path);
    if (_index < 0) {
      _playlist = [widget.path, ..._playlist];
      _index = 0;
    }
    _load();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    // Ekranı serbest bırak (tam ekranda yatay kilitlemiş olabiliriz).
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final old = _controller;
    old?.removeListener(_onTick);

    final controller = VideoPlayerController.file(File(_current));
    try {
      await controller.initialize();
      await controller.setPlaybackSpeed(_speed);
      await controller.play();
    } catch (e) {
      await controller.dispose();
      await old?.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _loading = false;
        _error = 'Bu dosya oynatılamadı. Cihaz bu codec’i desteklemiyor '
            'olabilir — “Başka uygulamayla aç”ı deneyin.\n\n$e';
      });
      return;
    }
    await old?.dispose();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onTick);
    setState(() {
      _controller = controller;
      _loading = false;
    });
    _scheduleHide();
  }

  /// Konum çubuğunu güncelle + dosya bitince sıradakine geç.
  void _onTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    final v = c.value;
    if (v.position >= v.duration &&
        v.duration > Duration.zero &&
        !v.isPlaying) {
      if (_index < _playlist.length - 1) {
        _skip(1);
        return;
      }
    }
    setState(() {});
  }

  void _skip(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _playlist.length) return;
    setState(() => _index = next);
    _load();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
    _scheduleHide();
    setState(() {});
  }

  void _seekBy(int seconds) {
    final c = _controller;
    if (c == null) return;
    final target = c.value.position + Duration(seconds: seconds);
    c.seekTo(target < Duration.zero ? Duration.zero : target);
    _scheduleHide();
  }

  Future<void> _setSpeed(double speed) async {
    _speed = speed;
    await _controller?.setPlaybackSpeed(speed);
    if (mounted) setState(() {});
  }

  void _toggleLandscape() {
    _landscape = !_landscape;
    SystemChrome.setPreferredOrientations(_landscape
        ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
        _landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    setState(() {});
  }

  /// Video oynarken kontroller 3 sn sonra kaybolur (sesde hep açık kalır).
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_isAudio) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final value = c?.value;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _controlsVisible
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              title: Text(p.basename(_current),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                if (_playlist.length > 1)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: Gap.sm),
                      child: Text('${_index + 1}/${_playlist.length}',
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                PopupMenuButton<double>(
                  tooltip: 'Oynatma hızı',
                  icon: const Icon(Icons.speed),
                  onSelected: _setSpeed,
                  itemBuilder: (_) => [
                    for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                      PopupMenuItem(
                        value: s,
                        child: Text('${s}x${s == _speed ? '  ✓' : ''}'),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: 'Başka uygulamayla aç',
                  icon: const Icon(Icons.apps),
                  onPressed: () =>
                      EntryOpener.openExternally(context, _current),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () {
          setState(() => _controlsVisible = !_controlsVisible);
          if (_controlsVisible) _scheduleHide();
        },
        // Sağa/sola kaydırma: çalma listesinde önceki/sonraki dosya.
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -250) _skip(1);
          if (v > 250) _skip(-1);
        },
        child: Stack(
          children: [
            Positioned.fill(child: _surface(c, value)),
            if (_controlsVisible && c != null && value != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _controls(c, value),
              ),
          ],
        ),
      ),
    );
  }

  Widget _surface(VideoPlayerController? c, VideoPlayerValue? value) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: Gap.md),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: Gap.md),
              FilledButton.tonalIcon(
                onPressed: () => EntryOpener.openExternally(context, _current),
                icon: const Icon(Icons.apps),
                label: const Text('Başka uygulamayla aç'),
              ),
            ],
          ),
        ),
      );
    }
    if (c == null || value == null) return const SizedBox.shrink();

    if (_isAudio || value.size.width == 0 || value.size.height == 0) {
      // Ses dosyası: görüntü yok → kapak alanı.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.sheet),
              ),
              child: const Icon(Icons.music_note,
                  size: 72, color: Colors.white70),
            ),
            const SizedBox(height: Gap.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Text(
                p.basenameWithoutExtension(_current),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }

  Widget _controls(VideoPlayerController c, VideoPlayerValue value) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          Gap.md, Gap.sm, Gap.md, MediaQuery.of(context).padding.bottom + Gap.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(_fmt(value.position),
                  style: const TextStyle(color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: value.position.inMilliseconds
                      .clamp(0, value.duration.inMilliseconds)
                      .toDouble(),
                  max: value.duration.inMilliseconds.toDouble().clamp(1, 1e9),
                  onChanged: (v) =>
                      c.seekTo(Duration(milliseconds: v.round())),
                  onChangeEnd: (_) => _scheduleHide(),
                ),
              ),
              Text(_fmt(value.duration),
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Önceki',
                color: Colors.white,
                icon: const Icon(Icons.skip_previous),
                onPressed: _index > 0 ? () => _skip(-1) : null,
              ),
              IconButton(
                tooltip: '10 sn geri',
                color: Colors.white,
                icon: const Icon(Icons.replay_10),
                onPressed: () => _seekBy(-10),
              ),
              IconButton(
                iconSize: 48,
                color: Colors.white,
                icon: Icon(
                    value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                onPressed: _togglePlay,
              ),
              IconButton(
                tooltip: '10 sn ileri',
                color: Colors.white,
                icon: const Icon(Icons.forward_10),
                onPressed: () => _seekBy(10),
              ),
              IconButton(
                tooltip: 'Sonraki',
                color: Colors.white,
                icon: const Icon(Icons.skip_next),
                onPressed:
                    _index < _playlist.length - 1 ? () => _skip(1) : null,
              ),
              if (!_isAudio)
                IconButton(
                  tooltip: _landscape ? 'Dikey' : 'Tam ekran (yatay)',
                  color: Colors.white,
                  icon: Icon(
                      _landscape ? Icons.fullscreen_exit : Icons.fullscreen),
                  onPressed: _toggleLandscape,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
