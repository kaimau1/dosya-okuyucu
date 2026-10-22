import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/pip.dart';
import '../../services/fm/playback_positions.dart';
import '../../services/fm/subtitles.dart';
import '../../services/fm/subtitle_delays.dart';
import '../../services/fm/video_playback.dart';
import '../../widgets/mini_player_bar.dart';
import 'entry_actions.dart';
import '../../core/snack.dart';

part 'media_player/actions.dart';
part 'media_player/views.dart';

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

  /// **Ekranı doldur** (kırparak) — 20:9 telefonda 16:9 filmin siyah
  /// şeritlerini kaldırır. Varsayılan kapalı: kırpma bir tercihtir, kimsenin
  /// görüntüsü habersiz kesilmemeli.
  bool _zoomFill = false;

  /// Son dokunuşun zamanı — ikinci dokunuşu (sarma) elle ölçmek için.
  DateTime? _lastTapAt;

  /// Dikey kaydırmayla ayarlanan ses; gösterge görünürken dolu.
  double? _volumeHint;
  Timer? _volumeTimer;

  /// Oynatıcının o anki sesi (0-1). `VideoPlayerValue.volume` başlangıçta 1.
  double _volume = 1;

  /// Servis her durum değişiminde haber veriyor; ekran o an yeniden çizilir.
  void _onService() {
    if (!mounted) return;
    setState(() {});
    _p.armAutoPip(true);
    if (_p.playing) _scheduleHide();
    _maybeShowResumeNote();
    // Yeni dosyaya geçildiyse altyazılar da yenilenmeli.
    if (_subtitlesFor != _p.current) {
      _subtitlesFor = _p.current;
      unawaited(_loadSubtitles());
    }
  }

  /// "Kaldığın yerden devam" bildirimini hangi dosya için gösterdiğimiz.
  String? _resumeNoticeFor;

  /// **Devam bildirimi** (kullanıcı isteği 2026-09-03, premium oynatıcı).
  ///
  /// Sessizce ortadan başlamak kullanıcıyı şaşırtır ("video bozuk mu?");
  /// bir cümle + tek dokunuşluk "baştan başlat" hem haber veriyor hem geri
  /// dönüş yolu bırakıyor.
  void _maybeShowResumeNote() {
    final at = _p.resumedFrom;
    final path = _p.current;
    if (at == null || path.isEmpty || _resumeNoticeFor == path) return;
    _resumeNoticeFor = path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSnack(
        context,
        context.t('mp.resumed_at', {'time': _fmt(at)}),
        action: SnackBarAction(
          label: context.t('mp.restart'),
          onPressed: () {
            PlaybackPositions.clear(path);
            unawaited(_p.seek(Duration.zero));
          },
        ),
      );
    });
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
    Pip.active.addListener(_onPip);
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
    Pip.active.removeListener(_onPip);
    _p.armAutoPip(false);
    _hideTimer?.cancel();
    _volumeTimer?.cancel();
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

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _onPip() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final value = c?.value;
    // Küçük pencerede (PiP) yalnız görüntü: düğmeler orada okunmaz,
    // dokunuşları sistem kendi denetimleriyle karşılıyor.
    if (Pip.active.value && c != null && value!.isInitialized) {
      return ColoredBox(
        color: AppColors.mediaSurface,
        child: Center(
          child: AspectRatio(
              aspectRatio: value.aspectRatio, child: VideoPlayer(c)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.mediaSurface,
      // ÖNEMLİ: üst bar Scaffold'un `appBar` slotuna verilmez. Verilseydi
      // kontroller açılıp kapandıkça body'nin yüksekliği değişir, ortalanmış
      // video her dokunuşta küçülüp kayardı. Bar da alt kontroller gibi
      // Stack'te videonun üstünde yüzer → görüntü hiç oynamaz.
      body: GestureDetector(
        // Videonun yanındaki siyah boşluklarda da dokunma çalışsın diye
        // opaque: varsayılan `deferToChild` ile yalnız görüntünün kendisi
        // dokunmayı yakalıyordu.
        behavior: HitTestBehavior.opaque,
        // **Çift dokunuş = sarma** (kullanıcı isteği 2026-09-03, premium
        // oynatıcı): solda 10 sn geri, sağda 10 sn ileri, ortada dokunuş
        // yine kontrolleri açıp kapatıyor.
        //
        // **`onDoubleTap` KULLANILMIYOR — bilinçli.** Aynı ağaçta bir çift
        // dokunuş tanıyıcısı varken TEK dokunuş, çift dokunuş süresi
        // (~300 ms) dolana kadar BEKLETİLİR: kontroller geç açılıyor ve
        // altındaki oynat/duraklat düğmesi bile gecikiyordu (iki widget
        // testi bunu yakaladı). Onun yerine ikinci dokunuş elle ölçülüyor —
        // her dokunuş anında iş görüyor. İki dokunuş kontrolleri iki kez
        // çevirdiği için görüntü de yerinde kalıyor (aç-kapa = değişmedi).
        onTapUp: _handleTap,
        // Sağa/sola kaydırma: çalma listesinde önceki/sonraki dosya.
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -250) _skip(1);
          if (v > 250) _skip(-1);
        },
        // **Dikey kaydırma = ses** (oynatıcının kendi sesi; sistem sesi bir
        // eklenti ister ve tek bir kaydırma için derleme zincirini oynatmak
        // yasak — bkz. HAFIZA). Gösterge kaydırma boyunca ekranda.
        onVerticalDragUpdate: _isAudio ? null : _handleVolumeDrag,
        onVerticalDragEnd: (_) => _hideVolumeSoon(),
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
            if (_volumeHint != null)
              Positioned(
                left: 0,
                right: 0,
                top: 80,
                child: IgnorePointer(child: _volumeBadge()),
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


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
