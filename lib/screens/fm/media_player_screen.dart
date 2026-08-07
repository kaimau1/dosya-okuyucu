import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import 'entry_actions.dart';

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

class _MediaPlayerScreenState extends State<MediaPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  late List<String> _playlist;
  late int _index;
  bool _loading = true;
  String? _error;
  bool _controlsVisible = true;
  bool _landscape = false;
  double _speed = 1.0;
  Timer? _hideTimer;

  /// Uygulama arkaya alındığı için mi duraklattık? (Kullanıcı duraklattıysa
  /// dönüşte kendiliğinden başlamamalı.)
  bool _pausedByLifecycle = false;

  /// Son bilinen oynatma durumu — yalnız DEĞİŞİMİNDE ekran yeniden çizilir.
  bool _wasPlaying = false;

  String get _current => _playlist[_index];
  bool get _isAudio =>
      FsEntry.categoryForExtension(p.extension(_current).replaceFirst('.', ''))
          == FmCategory.audio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    // Ekranı serbest bırak (tam ekranda yatay kilitlemiş olabiliriz).
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// **PİL — uygulama arkaya alınınca video DURUR.**
  ///
  /// Sınıfın başındaki not "arkaya alınınca çalma durur" diyordu; Android'de
  /// bu DOĞRU DEĞİL: `video_player` ExoPlayer'ı sürer ve ekran kapalıyken bile
  /// kareleri çözmeye devam eder (görüntü kimseye gösterilmeden). Bir saatlik
  /// filmde bu, telefonu cebe koyduktan sonra da süren tam güçte video kod
  /// çözme demek — uygulamanın en pahalı pil kaçağı buydu.
  ///
  /// Ses oynatıcı (`AudioPlayerScreen`) bilerek DIŞARIDA: müziğin arka planda
  /// sürmesi istenen davranış, video için değil.
  ///
  /// `inactive` kasten yok sayılıyor: bildirim gölgesini aşağı çekmek ya da
  /// izin penceresi de o durumu üretir, orada duraklatmak izlemeyi bölerdi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final c = _controller;
    if (c == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (c.value.isPlaying) {
          _pausedByLifecycle = true;
          unawaited(c.pause());
        }
      case AppLifecycleState.resumed:
        if (_pausedByLifecycle) {
          _pausedByLifecycle = false;
          unawaited(c.play());
        }
      case AppLifecycleState.inactive:
        break;
    }
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
        _error = AppStrings.current.t('mp.video_failed', {'error': e});
      });
      return;
    }
    await old?.dispose();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onTick);
    _wasPlaying = controller.value.isPlaying;
    _pausedByLifecycle = false;
    setState(() {
      _controller = controller;
      _loading = false;
    });
    _scheduleHide();
  }

  /// Dosya bitince sıradakine geç.
  ///
  /// **Burada `setState` YOK (2026-08-07 pil/başarım denetimi).** Eskiden her
  /// konum güncellemesinde (saniyede iki kez, denetleyici böyle yayınlar) TÜM
  /// ekran yeniden kuruluyordu: üst çubuk, degradeler, açılır menüler ve
  /// videonun bulunduğu ağaç. Konum çubuğu artık kendi
  /// `ValueListenableBuilder`ında tazeleniyor (bkz. [build]) → yeniden çizilen
  /// alan ekranın tamamı değil, yalnız alt kontroller.
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
    // Oynat/duraklat DEĞİŞİMİ kontrollerin gizlenme zamanlayıcısını ve
    // (kontroller kapalıysa) ekranın kalanını ilgilendirir — nadir olay.
    if (v.isPlaying != _wasPlaying) {
      _wasPlaying = v.isPlaying;
      if (v.isPlaying) _scheduleHide();
      setState(() {});
    }
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
      // ÖNEMLİ: üst bar Scaffold'un `appBar` slotuna verilmez. Verilseydi
      // kontroller açılıp kapandıkça body'nin yüksekliği değişir, ortalanmış
      // video her dokunuşta küçülüp kayardı. Bar da alt kontroller gibi
      // Stack'te videonun üstünde yüzer → görüntü hiç oynamaz.
      body: GestureDetector(
        // Videonun yanındaki siyah boşluklarda da dokunma çalışsın diye
        // opaque: varsayılan `deferToChild` ile yalnız görüntünün kendisi
        // dokunmayı yakalıyordu.
        behavior: HitTestBehavior.opaque,
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
            if (_controlsVisible)
              Positioned(left: 0, right: 0, top: 0, child: _topBar()),
            if (_controlsVisible && c != null && value != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                // Konum çubuğu saniyede iki kez değişir; yeniden çizilen
                // alanı BURAYA hapsediyoruz (bkz. [_onTick]).
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (_, live, __) => _controls(c, live),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Videonun üstünde yüzen başlık çubuğu (Scaffold slotu değil — bkz. build).
  Widget _topBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
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
              tooltip: context.t('mp.play_speed'),
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
              tooltip: context.t('mp.open_with'),
              icon: const Icon(Icons.apps),
              onPressed: () => EntryOpener.openExternally(context, _current),
            ),
            // İzlerken "bunu Önemli'ye taşıyayım" demek için oynatıcıyı
            // kapatıp dosyayı listede aramak gerekmesin (istek 2026-07-29:
            // "her türlü dosyada bu olmalı").
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
                label: Text(context.t('mp.open_with')),
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
                  // clamp'ın karışık int/double argümanı `num` döndürür →
                  // Slider'ın double alanına atanamaz; sonda toDouble() şart.
                  max: value.duration.inMilliseconds
                      .clamp(1, 1 << 40)
                      .toDouble(),
                  onChanged: (v) =>
                      c.seekTo(Duration(milliseconds: v.round())),
                  onChangeEnd: (_) => _scheduleHide(),
                ),
              ),
              Text(_fmt(value.duration),
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          // OYNATMA DÜĞMELERİ GERÇEKTEN ORTADA (kullanıcı hatası 2026-07-30:
          // "video kısmında alt durdur tuşu vs ortalı değil").
          //
          // Eskiden tam ekran düğmesi aynı `Row`un 6. öğesiydi: `center`
          // hizalaması ALTI öğeyi ortalıyordu, yani beş oynatma düğmesi
          // sağdaki tam ekran kadar SOLA kayıyordu ve büyük duraklat düğmesi
          // ekranın ortasına denk gelmiyordu. Çözüm: tam ekran düğmesi
          // yerleşimden çıkarılıp üste bindiriliyor — beşli grup artık
          // ekranın tam ortasında, tam ekran düğmesi de kenarda.
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: context.t('common.previous'),
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
                    icon: Icon(value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle),
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
                ],
              ),
              if (!_isAudio)
                // `AlignmentDirectional`: Arapça (sağdan sola) arayüzde düğme
                // kendiliğinden sol kenara geçer.
                PositionedDirectional(
                  end: 0,
                  child: IconButton(
                    tooltip: _landscape ? 'Dikey' : 'Tam ekran (yatay)',
                    color: Colors.white,
                    icon: Icon(
                        _landscape ? Icons.fullscreen_exit : Icons.fullscreen),
                    onPressed: _toggleLandscape,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
