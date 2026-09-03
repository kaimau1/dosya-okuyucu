import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/subtitles.dart';
import '../../services/fm/video_playback.dart';
import '../../widgets/mini_player_bar.dart';
import 'entry_actions.dart';
import '../../core/snack.dart';

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
  /// **Oynatıcı artık ekranda DEĞİL** (kullanıcı isteği 2026-09-03: *"hem
  /// bildirim hem ekran altı"*). Ekran yalnız servisi izliyor; çıkınca video
  /// (mini çubukta) devam ediyor — sesin 2026-09-02'de yaşadığı taşınmanın
  /// aynısı.
  VideoPlayback get _p => VideoPlayback.instance;

  VideoPlayerController? get _controller => _p.controller;
  List<String> get _playlist => _p.playlist;
  int get _index => _p.index;
  bool get _loading => _p.loading;
  String? get _error => _p.error;
  double get _speed => _p.speed;

  /// Tam oynatıcı açıkken ekran altı mini çubuk gizlenir.
  VoidCallback? _unhideBar;

  bool _controlsVisible = true;
  bool _landscape = false;
  Timer? _hideTimer;

  /// Servis her durum değişiminde haber veriyor; ekran o an yeniden çizilir.
  void _onService() {
    if (!mounted) return;
    setState(() {});
    if (_p.playing) _scheduleHide();
    // Yeni dosyaya geçildiyse altyazılar da yenilenmeli.
    if (_subtitlesFor != _p.current) {
      _subtitlesFor = _p.current;
      unawaited(_loadSubtitles());
    }
  }

  /// Altyazıları en son hangi dosya için yüklediğimiz.
  String? _subtitlesFor;

  /// Şu anki dosyanın yanında bulunan altyazı dosyaları.
  List<SubtitleTrack> _subtitles = const [];

  /// Seçili altyazı yolu; null = kapalı.
  String? _subtitlePath;

  /// Çözülmüş satırlar (seçili altyazınınki).
  List<SubtitleCue> _cues = const [];

  /// Altyazı gecikmesi (ms). Kaynağı farklı bir sürümden indirilmiş altyazı
  /// sesle tutmayabiliyor; kullanıcı ileri/geri kaydırabilsin.
  int _subtitleOffsetMs = 0;


  /// Ekranı açık tutan kilit ve uygulama yaşam döngüsü (arkaya alınınca
  /// duraklat) artık **serviste**: oynatma ekrandan uzun yaşadığı için
  /// kararları da onun vermesi gerekiyor (bkz. [VideoPlayback]).

  String get _current => _p.current;
  bool get _isAudio =>
      FsEntry.categoryForExtension(p.extension(_current).replaceFirst('.', ''))
          == FmCategory.audio;

  @override
  void initState() {
    super.initState();
    _unhideBar = MiniPlayerBar.hide();
    _p.addListener(_onService);
    _subtitlesFor = widget.path;
    // Aynı dosya zaten açıksa baştan başlatma: kullanıcı mini çubuktan ya da
    // bildirimden ekrana döndüğünde video sıfırlanmamalı.
    if (_p.current != widget.path || _p.controller == null) {
      unawaited(_p.open(widget.path, list: widget.playlist));
    }
    unawaited(_loadSubtitles());
  }

  @override
  void dispose() {
    _unhideBar?.call();
    _p.removeListener(_onService);
    _hideTimer?.cancel();
    // **Oynatıcı KAPATILMIYOR** — ekran altı mini çubuk onu sürdürüyor.
    // Ekranı serbest bırak (tam ekranda yatay kilitlemiş olabiliriz).
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Altyazı ────────────────────────────────────────────────────────────
  //
  // Video motorunun (`setClosedCaptionFile`) yerine kendi katmanımızı
  // çiziyoruz. Sebep: gecikme ayarı (`_subtitleOffsetMs`) ve punto denetimi
  // motorun API'sinde yok, oysa indirilen altyazının sesle tutmaması en sık
  // karşılaşılan sorun. Zamanlama işini zaten biz yapıyorsak, çizimi de
  // yapmak ek maliyet değil.

  /// Şu anki dosyanın altyazılarını bulur ve birini seçer.
  ///
  /// Otomatik seçim **arayüz diline** göre: Türkçe arayüzde `Film.tr.srt`
  /// varsa o açılır. Yoksa ilk altyazı — tek altyazısı olan bir filmde
  /// kullanıcının menüyü açması gerekmesin.
  Future<void> _loadSubtitles() async {
    if (_isAudio) {
      if (mounted) {
        setState(() {
          _subtitles = const [];
          _subtitlePath = null;
          _cues = const [];
        });
      }
      return;
    }
    final path = _current;
    final found = Subtitles.findFor(path);
    if (!mounted || path != _current) return;
    setState(() {
      _subtitles = found;
      _subtitleOffsetMs = 0;
    });
    if (found.isEmpty) {
      setState(() {
        _subtitlePath = null;
        _cues = const [];
      });
      return;
    }
    // `code` 'tr' | 'en' | 'ar' (sistem dilinde 'system' → hiçbir etiketle
    // eşleşmez ve ilk altyazıya düşülür, doğru davranış).
    final code = AppStrings.current.language.name;
    final preferred = found.firstWhere(
      (t) => t.label.toLowerCase().startsWith(code),
      orElse: () => found.first,
    );
    await _selectSubtitle(preferred.path, forPath: path);
  }

  /// [subPath] altyazısını yükler (null = kapat). [forPath] verilirse, o video
  /// hâlâ açık değilse sonuç yok sayılır (çalma listesinde hızlı geçiş).
  Future<void> _selectSubtitle(String? subPath, {String? forPath}) async {
    if (subPath == null) {
      if (mounted) {
        setState(() {
          _subtitlePath = null;
          _cues = const [];
        });
      }
      return;
    }
    final cues = await Subtitles.load(subPath);
    if (!mounted || (forPath != null && forPath != _current)) return;
    setState(() {
      _subtitlePath = subPath;
      _cues = cues;
    });
    if (cues.isEmpty) {
      _toast(context.t('mp.sub_unreadable'));
    }
  }

  /// Kullanıcının seçtiği bir altyazı dosyasını ekler ve açar.
  Future<void> _pickSubtitle() async {
    final result = await FilePicker.platform.pickFiles(
      // `FileType.custom` + uzantı süzgeci: kullanıcı seçicide film klasörünü
      // açtığında yüzlerce medya dosyası arasında altyazıyı aramasın.
      type: FileType.custom,
      allowedExtensions: Subtitles.extensions.toList(),
    );
    final files = result?.files ?? const [];
    final picked = files.isEmpty ? null : files.first.path;
    if (picked == null || !mounted) return;
    setState(() {
      if (!_subtitles.any((t) => t.path == picked)) {
        _subtitles = [
          ..._subtitles,
          SubtitleTrack(path: picked, label: p.basename(picked)),
        ];
      }
    });
    await _selectSubtitle(picked);
  }

  void _toast(String message) {
    if (!mounted) return;
    showSnack(context, message);
  }

  /// [position] anında ekranda olması gereken metin (yoksa boş).
  ///
  /// İkili arama: bir filmde 2000 satır olabiliyor ve bu, konum her
  /// güncellendiğinde (saniyede iki kez) çalışıyor.
  String captionAt(Duration position) {
    if (_cues.isEmpty) return '';
    final t = position - Duration(milliseconds: _subtitleOffsetMs);
    var lo = 0;
    var hi = _cues.length - 1;
    var found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_cues[mid].start <= t) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (found < 0) return '';
    // Üst üste binen satırlar (ASS'te sık): başlangıcı geçmiş ama bitişi
    // gelmemiş komşulara da bakılır. Sekiz geriye bakmak pratikte yeter ve
    // aramayı sabit maliyette tutar.
    final lines = <String>[];
    for (var i = found; i >= 0 && i > found - 8; i--) {
      final c = _cues[i];
      if (c.start <= t && c.end >= t) lines.add(c.text);
    }
    return lines.reversed.join('\n');
  }

  /// Sıradaki/önceki dosya, oynat/duraklat, sarma ve hız — hepsi **serviste**
  /// (`VideoPlayback`). Ekran yalnız düğmeyi basıyor: aynı işlemler mini
  /// çubuktan ve bildirimden de geliyor, tek bir yerde olmaları şart.
  void _skip(int delta) => unawaited(_p.skip(delta));

  void _togglePlay() {
    unawaited(_p.toggle());
    _scheduleHide();
  }

  void _seekBy(int seconds) {
    unawaited(_p.seekBy(seconds));
    _scheduleHide();
  }

  Future<void> _setSpeed(double speed) => _p.setSpeed(speed);

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
            // Altyazı katmanı: konum saniyede iki kez değişiyor, yeniden
            // çizilen alan BURAYA hapsediliyor (bkz. [_onTick] notu).
            // Kontroller açıkken yukarı kaçar ki alttaki çubuk metni örtmesin.
            if (c != null && _cues.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: _controlsVisible ? 140 : 32,
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (_, live, __) => _captionLayer(live.position),
                ),
              ),
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

  /// Altyazı metni. Zemin yerine **kontur** kullanılıyor: siyah şerit açık
  /// sahnelerde görüntünün beşte birini kapatıyordu, kontur her zeminde okunur
  /// ve görüntüyü örtmez.
  Widget _captionLayer(Duration position) {
    final text = captionAt(position);
    if (text.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 3),
              Shadow(color: Colors.black, blurRadius: 6),
            ],
          ),
        ),
      ),
    );
  }

  /// Altyazı menüsü: kapat · bulunan dosyalar · gecikme · dosyadan seç.
  Widget _subtitleMenu() => PopupMenuButton<String>(
        tooltip: context.t('mp.subtitles'),
        icon: Icon(_subtitlePath == null
            ? Icons.closed_caption_off_outlined
            : Icons.closed_caption),
        onSelected: (value) async {
          switch (value) {
            case '_off':
              await _selectSubtitle(null);
            case '_pick':
              await _pickSubtitle();
            case '_later':
              setState(() => _subtitleOffsetMs -= 500);
            case '_sooner':
              setState(() => _subtitleOffsetMs += 500);
            default:
              await _selectSubtitle(value);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: '_off',
            child: Text('${context.t('mp.sub_off')}'
                '${_subtitlePath == null ? '  ✓' : ''}'),
          ),
          for (final track in _subtitles)
            PopupMenuItem(
              value: track.path,
              child: Text('${track.label}'
                  '${_subtitlePath == track.path ? '  ✓' : ''}'),
            ),
          const PopupMenuDivider(),
          if (_subtitlePath != null) ...[
            // Gecikme: altyazı sesin GERİSİNDEyse "+", ilerideyse "−".
            PopupMenuItem(
              value: '_sooner',
              child: Text(context.t('mp.sub_earlier')),
            ),
            PopupMenuItem(
              value: '_later',
              child: Text(context.t('mp.sub_later')),
            ),
            PopupMenuItem(
              enabled: false,
              child: Text(context.t('mp.sub_offset',
                  {'v': (_subtitleOffsetMs / 1000).toStringAsFixed(1)})),
            ),
          ],
          PopupMenuItem(
            value: '_pick',
            child: Text(context.t('mp.sub_pick')),
          ),
        ],
      );

  /// Videonun üstünde yüzen başlık çubuğu (Scaffold slotu değil — bkz. build).
  ///
  /// **Dosya adı** (kullanıcı 2026-08-29, işaretli ekran görüntüsü: *"video ve
  /// görsellerde dosya adı zor görülüyor"*):
  /// - Rengi [OverlayBar.title]'dan gelir — `foregroundColor: Colors.white`
  ///   başlığı beyaz YAPMIYORDU (kök neden orada yazılı).
  /// - Perde koyulaştı ve aşağı uzatıldı: yarı saydam siyahın altında kalan
  ///   parlak bir video karesi adı yutuyordu.
  /// - Ad artık iki satıra kadar sarabiliyor ve altında süre/sıra bilgisi var;
  ///   "AHBS_Egitim_Videosu_1080.mp4" tek satıra sığmıyordu, üstelik dört
  ///   eylem simgesi başlığa kalan yeri iyice daraltıyordu.
  Widget _topBar() {
    final position = _playlist.length > 1
        ? '${_index + 1}/${_playlist.length} · ${p.extension(_current).replaceFirst('.', '').toUpperCase()}'
        : p.extension(_current).replaceFirst('.', '').toUpperCase();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.88),
            Colors.black.withValues(alpha: 0.45),
            Colors.transparent,
          ],
          stops: const [0, 0.65, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          // Temanın çubuk altı cetveli burada YANLIŞ: videonun üstünde yüzen
          // saydam bir çubuğu ikiye bölen açık gri bir çizgi çiziyordu.
          shape: const Border(),
          foregroundColor: Colors.white,
          titleSpacing: 0,
          toolbarHeight: 64,
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.basename(_current),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OverlayBar.title(context),
              ),
              if (position.isNotEmpty)
                Text(position, style: OverlayBar.subtitle(context)),
            ],
          ),
          actions: [
            if (!_isAudio) _subtitleMenu(),
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
                    tooltip: context.t('mp.back10'),
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
                    tooltip: context.t('mp.forward10'),
                    color: Colors.white,
                    icon: const Icon(Icons.forward_10),
                    onPressed: () => _seekBy(10),
                  ),
                  IconButton(
                    tooltip: context.t('common.next'),
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
                    tooltip: context.t(_landscape ? 'mp.portrait' : 'mp.fullscreen'),
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
