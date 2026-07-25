import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';

/// Çalma sırası davranışı.
enum RepeatMode { off, one, all }

/// Müzik çalar: klasördeki ses dosyalarını çalar, sıradakine geçer,
/// tekrar/karışık destekler.
///
/// **Niye ayrı motor (audioplayers), video oynatıcıdan farklı:** `video_player`
/// bir görüntü yüzeyine bağlıdır; ekran kapanınca/uygulama arkaya alınınca
/// çalma durur ve çalar işlevleri (tekrar, karışık, hız) yoktur. audioplayers
/// native çalıcıyı doğrudan sürer → **ekran kapansa da müzik devam eder** ve
/// manifest'e servis/etkinlik eklemeyi gerektirmez (bildirim/kilit ekranı
/// kontrolleri için ileride audio_service gerekir — bkz. KALANLAR).
class AudioPlayerScreen extends StatefulWidget {
  final String path;

  /// Aynı klasördeki ses dosyaları (bu dosya da içinde).
  final List<String> playlist;

  const AudioPlayerScreen({
    super.key,
    required this.path,
    this.playlist = const [],
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];

  late List<String> _playlist;
  late int _index;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _dragging = false;
  double _speed = 1.0;
  RepeatMode _repeat = RepeatMode.off;
  bool _shuffle = false;
  String? _error;

  String get _current => _playlist[_index];

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist.isEmpty ? [widget.path] : [...widget.playlist];
    _index = _playlist.indexOf(widget.path);
    if (_index < 0) {
      _playlist.insert(0, widget.path);
      _index = 0;
    }

    _subs.addAll([
      _player.onPositionChanged.listen((d) {
        if (!_dragging && mounted) setState(() => _position = d);
      }),
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      }),
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _playing = s == PlayerState.playing);
      }),
      _player.onPlayerComplete.listen((_) => _onComplete()),
    ]);

    _play(_current);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(String path) async {
    setState(() {
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
      await _player.setPlaybackRate(_speed);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Bu ses dosyası çalınamadı: $e');
      }
    }
  }

  void _onComplete() {
    if (_repeat == RepeatMode.one) {
      _play(_current);
      return;
    }
    if (_shuffle && _playlist.length > 1) {
      final rnd = Random(DateTime.now().microsecondsSinceEpoch);
      var next = _index;
      while (next == _index) {
        next = rnd.nextInt(_playlist.length);
      }
      _skipTo(next);
      return;
    }
    if (_index < _playlist.length - 1) {
      _skipTo(_index + 1);
    } else if (_repeat == RepeatMode.all) {
      _skipTo(0);
    }
  }

  void _skipTo(int index) {
    if (index < 0 || index >= _playlist.length) return;
    setState(() => _index = index);
    _play(_current);
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _seekBy(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> _setSpeed(double speed) async {
    _speed = speed;
    await _player.setPlaybackRate(speed);
    if (mounted) setState(() {});
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çalıyor'),
        actions: [
          PopupMenuButton<double>(
            tooltip: 'Hız',
            icon: const Icon(Icons.speed),
            onSelected: _setSpeed,
            itemBuilder: (_) => [
              for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                PopupMenuItem(
                    value: s, child: Text('${s}x${s == _speed ? '  ✓' : ''}')),
            ],
          ),
          IconButton(
            tooltip: 'Başka uygulamayla aç',
            icon: const Icon(Icons.apps),
            onPressed: () => EntryOpener.openExternally(context, _current),
          ),
        ],
      ),
      body: GestureDetector(
        // Sağa/sola kaydırma: önceki/sonraki parça.
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250) _skipTo(_index + 1);
          if (v > 250) _skipTo(_index - 1);
        },
        child: Column(
          children: [
            const SizedBox(height: Gap.lg),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.sheet),
              ),
              child: Icon(Icons.music_note,
                  size: 84, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: Gap.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Text(
                p.basenameWithoutExtension(_current),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              _playlist.length > 1
                  ? '${_index + 1}/${_playlist.length} · ${p.basename(p.dirname(_current))}'
                  : p.basename(p.dirname(_current)),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error)),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Row(
                children: [
                  Text(_fmt(_position), style: theme.textTheme.bodySmall),
                  Expanded(
                    child: Slider(
                      value: _position.inMilliseconds
                          .clamp(0, max(_duration.inMilliseconds, 1))
                          .toDouble(),
                      max: max(_duration.inMilliseconds, 1).toDouble(),
                      onChangeStart: (_) => _dragging = true,
                      onChanged: (v) => setState(
                          () => _position = Duration(milliseconds: v.round())),
                      onChangeEnd: (v) async {
                        _dragging = false;
                        await _player.seek(Duration(milliseconds: v.round()));
                      },
                    ),
                  ),
                  Text(_fmt(_duration), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Karışık',
                  isSelected: _shuffle,
                  icon: const Icon(Icons.shuffle),
                  selectedIcon: Icon(Icons.shuffle, color: scheme.primary),
                  onPressed: () => setState(() => _shuffle = !_shuffle),
                ),
                IconButton(
                  tooltip: 'Önceki',
                  icon: const Icon(Icons.skip_previous),
                  onPressed: _index > 0 ? () => _skipTo(_index - 1) : null,
                ),
                IconButton(
                  tooltip: '10 sn geri',
                  icon: const Icon(Icons.replay_10),
                  onPressed: () => _seekBy(-10),
                ),
                IconButton(
                  iconSize: 56,
                  icon: Icon(
                      _playing ? Icons.pause_circle : Icons.play_circle),
                  color: scheme.primary,
                  onPressed: _toggle,
                ),
                IconButton(
                  tooltip: '10 sn ileri',
                  icon: const Icon(Icons.forward_10),
                  onPressed: () => _seekBy(10),
                ),
                IconButton(
                  tooltip: 'Sonraki',
                  icon: const Icon(Icons.skip_next),
                  onPressed: _index < _playlist.length - 1
                      ? () => _skipTo(_index + 1)
                      : null,
                ),
                IconButton(
                  tooltip: switch (_repeat) {
                    RepeatMode.off => 'Tekrar: kapalı',
                    RepeatMode.one => 'Tekrar: bu parça',
                    RepeatMode.all => 'Tekrar: tümü',
                  },
                  isSelected: _repeat != RepeatMode.off,
                  icon: Icon(_repeat == RepeatMode.one
                      ? Icons.repeat_one
                      : Icons.repeat),
                  selectedIcon: Icon(
                    _repeat == RepeatMode.one
                        ? Icons.repeat_one
                        : Icons.repeat,
                    color: scheme.primary,
                  ),
                  onPressed: () => setState(() {
                    _repeat = switch (_repeat) {
                      RepeatMode.off => RepeatMode.all,
                      RepeatMode.all => RepeatMode.one,
                      RepeatMode.one => RepeatMode.off,
                    };
                  }),
                ),
              ],
            ),
            if (_playlist.length > 1) _playlistView(),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  /// Sıradaki parçalar (dokununca o parçaya atlar).
  Widget _playlistView() => SizedBox(
        height: 132,
        child: ListView.builder(
          itemCount: _playlist.length,
          itemBuilder: (context, i) {
            final path = _playlist[i];
            final active = i == _index;
            return ListTile(
              dense: true,
              selected: active,
              leading: Icon(active ? Icons.equalizer : Icons.music_note,
                  size: 20),
              title: Text(p.basenameWithoutExtension(path),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(
                FsPaths.humanSize(_sizeOf(path)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () => _skipTo(i),
            );
          },
        ),
      );

  int _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }
}
