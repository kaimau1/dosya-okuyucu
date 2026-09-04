import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../services/fm/audio_playback.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/audio_tags.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/mini_player_bar.dart';
import 'entry_actions.dart';

/// Çalma sırası davranışı.

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
  /// **Durum artık ekranda DEĞİL** (kullanıcı isteği 2026-09-02: *"arka
  /// planda oynat seçeneği olmalı, müzik programları gibi"*). Ekran yalnız
  /// servisi izliyor; çıkınca müzik devam ediyor.
  AudioPlayback get _p => AudioPlayback.instance;

  bool _dragging = false;

  /// Sürüklerken çubuğun takip ettiği geçici konum.
  Duration _dragPosition = Duration.zero;

  /// Tam oynatıcı açıkken ekran altı mini çubuk gizlenir.
  VoidCallback? _unhideBar;

  @override
  void initState() {
    super.initState();
    _unhideBar = MiniPlayerBar.hide();
    _p.addListener(_onChange);
    // Aynı dosya zaten çalıyorsa baştan başlatma: kullanıcı bildirimden
    // ekrana döndüğünde parça sıfırlanmamalı.
    if (_p.current != widget.path) {
      unawaited(_p.open(widget.path, list: widget.playlist));
    }
  }

  @override
  void dispose() {
    _unhideBar?.call();
    _p.removeListener(_onChange);
    // **Oynatıcı KAPATILMIYOR.** Eskiden burada `player.dispose()` vardı ve
    // ekrandan çıkan kullanıcı müziği de kapatmış oluyordu.
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Duration get _position => _dragging ? _dragPosition : _p.position;
  Duration get _duration => _p.duration;
  bool get _playing => _p.playing;
  double get _speed => _p.speed;
  RepeatMode get _repeat => _p.repeat;
  bool get _shuffle => _p.shuffle;
  String? get _error => _p.error;
  AudioTags get _tags => _p.tags;
  List<String> get _playlist => _p.playlist;
  int get _index => _p.index;
  String get _current => _p.current;

  /// Kapak yoksa (ya da açılamazsa) gösterilen nota kutusu.
  Widget _coverFallback(ColorScheme scheme) => Container(
        color: scheme.primaryContainer,
        child:
            Icon(Icons.music_note, size: 84, color: scheme.onPrimaryContainer),
      );

  void _skipTo(int index) => unawaited(_p.skipTo(index));

  Future<void> _toggle() => _p.toggle();

  Future<void> _seekBy(int seconds) => _p.seekBy(seconds);

  Future<void> _setSpeed(double speed) => _p.setSpeed(speed);

  /// Uyku zamanlayıcısının geri sayımı (`12:30`).
  static String _fmtSleep(Duration d) => _fmt(d);

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
        title: Text(context.t('mp.now_playing')),
        // Kurulu zamanlayıcı geri sayımı başlıkta: menüyü açmadan görünsün.
        bottom: _p.sleepRemaining == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    context.t('mp.sleep_active',
                        {'time': _fmtSleep(_p.sleepRemaining!)}),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
        actions: [
          PopupMenuButton<double>(
            tooltip: context.t('mp.speed'),
            icon: const Icon(Icons.speed),
            onSelected: _setSpeed,
            itemBuilder: (_) => [
              for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                PopupMenuItem(
                    value: s, child: Text('${s}x${s == _speed ? '  ✓' : ''}')),
            ],
          ),
          // **Uyku zamanlayıcısı** (kullanıcı isteği 2026-09-03, premium):
          // gece dinlerken uyuyan telefon sabaha kadar çalmasın. Kurulu
          // zamanlayıcı simgede ve alt yazıda görünür — "kapattım mı?" diye
          // düşünmek zorunda kalınmasın.
          PopupMenuButton<int>(
            tooltip: context.t('mp.sleep_timer'),
            icon: Icon(_p.sleepRemaining == null
                ? Icons.bedtime_outlined
                : Icons.bedtime),
            onSelected: (minutes) => setState(() => _p.setSleepTimer(
                minutes <= 0 ? null : Duration(minutes: minutes))),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 0,
                child: Text('${context.t('mp.sleep_off')}'
                    '${_p.sleepRemaining == null ? '  ✓' : ''}'),
              ),
              for (final m in const [15, 30, 45, 60, 90])
                PopupMenuItem(
                  value: m,
                  child: Text(context.t('mp.sleep_minutes', {'n': '$m'})),
                ),
            ],
          ),
          IconButton(
            tooltip: context.t('mp.open_with'),
            icon: const Icon(Icons.apps),
            onPressed: () => EntryOpener.openExternally(context, _current),
          ),
          // Dinlerken dosyayı taşımak/kopyalamak için ekranı terk etmek
          // gerekmesin (istek 2026-07-29: "her türlü dosyada bu olmalı").
          IconButton(
            tooltip: context.t('mp.file_ops'),
            icon: const Icon(Icons.more_vert),
            onPressed: () => showEntryActions(
              context,
              FsEntry.fromEntity(File(_current)),
            ),
          ),
        ],
      ),
      // **Alt denetimler sistem çubuğunun ALTINDA kalıyordu** (kullanıcı
      // ekran görüntüsü 2026-09-02: "son açılanlardan açınca düğmeler
      // telefonun düğmelerinin altında kalıyor"). Ana ekrandan açılınca alt
      // gezinme çubuğu payı veriyordu ve sorun görünmüyordu; doğrudan
      // açılışta hiçbir pay yoktu. `SafeArea` payı ekranın kendisine koyuyor.
      body: SafeArea(
        top: false,
        child: GestureDetector(
          // Sağa/sola kaydırma: önceki/sonraki parça.
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -250) _skipTo(_index + 1);
            if (v > 250) _skipTo(_index - 1);
          },
          child: Column(
            children: [
              const SizedBox(height: Gap.lg),
              // **Kapak resmi** dosyanın kendi etiketinden (ID3 `APIC` / MP4
              // `covr`). Yoksa eski nota simgesi — kutu ölçüsü DEĞİŞMEZ, yoksa
              // kapak geldiğinde bütün ekran zıplardı.
              SizedBox(
                width: 160,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sheet),
                  child: _tags.cover != null
                      ? Image.memory(
                          _tags.cover!,
                          fit: BoxFit.cover,
                          // Kapaklar 1500 piksele kadar çıkabiliyor; 160 dp'lik
                          // kutuya tam çözünürlükte açmak boşuna bellek
                          // (bkz. core/image_budget.dart dersi).
                          cacheWidth: 480,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => _coverFallback(scheme),
                        )
                      : _coverFallback(scheme),
                ),
              ),
              const SizedBox(height: Gap.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: Text(
                  // Etikette parça adı varsa o gösterilir: "03 - track.mp3"
                  // yerine gerçek ad.
                  _tags.title.isNotEmpty
                      ? _tags.title
                      : p.basenameWithoutExtension(_current),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (_tags.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: Text(
                    _tags.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
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
                        onChangeStart: (_) {
                          // Sürüklerken servis konumu ekrana yansımasın, yoksa
                          // parmak çubuğu çekerken çubuk geri zıplar.
                          _dragging = true;
                          _p.setDragging(true);
                        },
                        onChanged: (v) => setState(() =>
                            _dragPosition = Duration(milliseconds: v.round())),
                        onChangeEnd: (v) async {
                          _dragging = false;
                          _p.setDragging(false);
                          await _p.seek(Duration(milliseconds: v.round()));
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
                    tooltip: context.t('mp.shuffle'),
                    isSelected: _shuffle,
                    icon: const Icon(Icons.shuffle),
                    selectedIcon: Icon(Icons.shuffle, color: scheme.primary),
                    onPressed: () => _p.setShuffle(!_shuffle),
                  ),
                  IconButton(
                    tooltip: context.t('common.previous'),
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _index > 0 ? () => _skipTo(_index - 1) : null,
                  ),
                  IconButton(
                    tooltip: context.t('mp.back10'),
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => _seekBy(-10),
                  ),
                  IconButton(
                    iconSize: 56,
                    icon:
                        Icon(_playing ? Icons.pause_circle : Icons.play_circle),
                    color: scheme.primary,
                    onPressed: _toggle,
                  ),
                  IconButton(
                    tooltip: context.t('mp.forward10'),
                    icon: const Icon(Icons.forward_10),
                    onPressed: () => _seekBy(10),
                  ),
                  IconButton(
                    tooltip: context.t('common.next'),
                    icon: const Icon(Icons.skip_next),
                    onPressed: _index < _playlist.length - 1
                        ? () => _skipTo(_index + 1)
                        : null,
                  ),
                  IconButton(
                    tooltip: switch (_repeat) {
                      RepeatMode.off => context.t('mp.repeat_off'),
                      RepeatMode.one => context.t('mp.repeat_one'),
                      RepeatMode.all => context.t('mp.repeat_all'),
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
                    onPressed: () => _p.setRepeat(switch (_repeat) {
                      RepeatMode.off => RepeatMode.all,
                      RepeatMode.all => RepeatMode.one,
                      RepeatMode.one => RepeatMode.off,
                    }),
                  ),
                ],
              ),
              if (_playlist.length > 1) _playlistView(),
              const SizedBox(height: Gap.sm),
            ],
          ),
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
              leading:
                  Icon(active ? Icons.equalizer : Icons.music_note, size: 20),
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
