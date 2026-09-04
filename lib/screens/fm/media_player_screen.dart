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
import '../../services/fm/floating_video.dart';
import '../../services/fm/playback_positions.dart';
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

  /// Ekrana dokunuş: kontrolleri çevirir; kenarda HIZLI ikinci dokunuş sarar.
  void _handleTap(TapUpDetails details) {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
    if (_isAudio) return;
    final width = MediaQuery.of(context).size.width;
    final side = width <= 0 ? 0.5 : details.localPosition.dx / width;
    final now = DateTime.now();
    final previous = _lastTapAt;
    _lastTapAt = now;
    if (previous == null ||
        now.difference(previous) > const Duration(milliseconds: 320)) {
      return;
    }
    // İkinci dokunuş: ortada değilse sar. (Ortası ayrıldı — parmağın nereye
    // düştüğüne göre yanlış iş yapmak en can sıkıcısı.)
    _lastTapAt = null;
    if (side < 0.4) {
      _seekBy(-10);
    } else if (side > 0.6) {
      _seekBy(10);
    }
  }

  /// Dikey kaydırma sesi değiştirir (yukarı = yüksek).
  void _handleVolumeDrag(DragUpdateDetails details) {
    final c = _controller;
    if (c == null) return;
    final height = MediaQuery.of(context).size.height;
    final next = (_volume - details.delta.dy / (height * 0.6)).clamp(0.0, 1.0);
    _volume = next;
    unawaited(c.setVolume(next));
    _volumeTimer?.cancel();
    setState(() => _volumeHint = next);
  }

  /// Göstergeyi kısa süre sonra gizler (kaydırma bitti).
  void _hideVolumeSoon() {
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeHint = null);
    });
  }

  Widget _volumeBadge() {
    final value = _volumeHint ?? 1;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(Radii.sheet),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value == 0
                  ? Icons.volume_off
                  : (value < 0.5 ? Icons.volume_down : Icons.volume_up),
              color: Colors.white,
            ),
            const SizedBox(width: Gap.sm),
            SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Text('${(value * 100).round()}%',
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// **Ekran üstüne al** — video başka uygulamaların üstünde sürsün.
  ///
  /// İzin yoksa kullanıcı ayara yönlendiriliyor: "olmadı" deyip bırakmak,
  /// kullanıcının elinde yapacak bir şey bırakmamak demek olurdu.
  Future<void> _popOut() async {
    if (!await FloatingVideo.hasPermission()) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('mp.float_window')),
          content: Text(ctx.t('mp.float_permission')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.t('common.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('common.open'))),
          ],
        ),
      );
      if (go != true) return;
      await FloatingVideo.requestPermission();
      return;
    }
    final ok = await _p.popOut();
    if (!mounted) return;
    if (!ok) {
      _toast(context.t('mp.float_failed'));
      return;
    }
    // Pencere açıldı: tam ekran oynatıcıdan çık, kullanıcı istediği
    // uygulamaya geçebilsin.
    Navigator.of(context).maybePop();
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
            if (!_isAudio) ...[
              IconButton(
                tooltip: context.t('mp.float_window'),
                icon: const Icon(Icons.picture_in_picture_alt),
                onPressed: _popOut,
              ),
              IconButton(
                tooltip: context.t(_zoomFill ? 'mp.zoom_fit' : 'mp.zoom_fill'),
                icon: Icon(_zoomFill ? Icons.fit_screen : Icons.crop_free),
                onPressed: () => setState(() => _zoomFill = !_zoomFill),
              ),
            ],
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

    // **Yakınlaştırma (en-boy doldurma):** telefonun ekranı 20:9, filmlerin
    // çoğu 16:9 — üstte altta siyah şerit kalıyor. `cover` görüntüyü ekrana
    // yayıyor (kenarlardan kırparak). Seçim kullanıcıda: iki kip arasında
    // üst çubuktaki düğme geçiş yaptırıyor.
    if (_zoomFill) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: value.size.width,
            height: value.size.height,
            child: VideoPlayer(c),
          ),
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
