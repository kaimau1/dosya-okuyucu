part of '../media_player_screen.dart';

extension _MediaPlayerScreenViewsPart on _MediaPlayerScreenState {
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
          textScaler: MediaQuery.textScalerOf(context).clamp(
              minScaleFactor: _MediaPlayerScreenState._subtitleScale,
              maxScaleFactor: _MediaPlayerScreenState._subtitleScale * 2),
          style: context.type.heading.copyWith(
            color: AppColors.onMedia,
            height: 1.25,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: AppColors.mediaSurface, blurRadius: 3),
              Shadow(color: AppColors.mediaSurface, blurRadius: 6),
            ],
          ),
        ),
      ),
    );
  }

  /// Altyazı menüsü: kapat · bulunan dosyalar · gecikme · dosyadan seç.
  ///
  /// 2026-11-16 (kullanıcı: "altyazı tuşunu menüye al, yerine paylaş koy"):
  /// üst çubukta düğme yok; ⋮ levhasındaki "Altyazı" bu menüyü sağ üstte açar.
  Future<void> _openSubtitleMenu() async {
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top + 56;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(size.width - 8, top, 8, 0),
      items: _subtitleItems(),
    );
    if (value == null || !mounted) return;
    await _onSubtitleChoice(value);
  }

  Future<void> _onSubtitleChoice(String value) async {
      switch (value) {
        case '_off':
          await _selectSubtitle(null);
        case '_pick':
          await _pickSubtitle();
        case '_online':
          await _searchOnline();
        case '_mpv':
          await _p.reopenWithMpv(!_p.usingMpv);
        case final v when v.startsWith('_audio:'):
          await _p.selectAudioTrack(v.substring(7));
        case '_bigger':
          _partSetState(() => _MediaPlayerScreenState._subtitleScale =
              (_MediaPlayerScreenState._subtitleScale + 0.15).clamp(0.6, 2.2));
        case '_smaller':
          _partSetState(() => _MediaPlayerScreenState._subtitleScale =
              (_MediaPlayerScreenState._subtitleScale - 0.15).clamp(0.6, 2.2));
        case '_later':
          _partSetState(() => _subtitleOffsetMs -= 500);
          SubtitleDelays.set(_current, _subtitleOffsetMs);
        case '_sooner':
          _partSetState(() => _subtitleOffsetMs += 500);
          SubtitleDelays.set(_current, _subtitleOffsetMs);
        default:
          await _selectSubtitle(value);
      }
  }

  List<PopupMenuEntry<String>> _subtitleItems() => [
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
            PopupMenuItem(
              value: '_bigger',
              child: Text(context.t('mp.sub_bigger')),
            ),
            PopupMenuItem(
              value: '_smaller',
              child: Text(context.t('mp.sub_smaller')),
            ),
          ],
          if (OpenSubtitles.available)
            PopupMenuItem(
              value: '_online',
              child: Text(context.t('mp.sub_online')),
            ),
          // **Ses + motor** (2026-11-02, "VLC gibi"): ayrı düğme üst çubuğu
          // telefonda taşırıyordu (media_player_layout_test), bu menüde.
          const PopupMenuDivider(),
          for (final (i, t) in _p.audioTracks.indexed)
            PopupMenuItem(
              value: '_audio:${t.id}',
              child: Text('${_trackLabel(i, t)}${t.isSelected ? '  ✓' : ''}'),
            ),
          PopupMenuItem(
            value: '_mpv',
            child: Text(context
                .t(_p.usingMpv ? 'mp.engine_exo' : 'mp.engine_mpv')),
          ),
          PopupMenuItem(
            value: '_pick',
            child: Text(context.t('mp.sub_pick')),
          ),
        ];

  /// "Türkçe · ac3 · 6 kanal" — ExoPlayer'ın verdiği kadarı.
  String _trackLabel(int i, VideoAudioTrack t) => [
        t.label ?? t.language ?? context.t('mp.audio_track_n', {'n': '${i + 1}'}),
        if (t.label != null && t.language != null) t.language!,
        if (t.codec != null) t.codec!.replaceFirst('audio/', ''),
        if (t.channelCount != null) '${t.channelCount}ch',
      ].join(' · ');

  /// Videonun üstünde yüzen başlık çubuğu (Scaffold slotu değil — bkz. build).
  ///
  /// **Dosya adı** (kullanıcı 2026-08-29, işaretli ekran görüntüsü: *"video ve
  /// görsellerde dosya adı zor görülüyor"*):
  /// - Rengi [OverlayBar.title]'dan gelir — `foregroundColor: AppColors.onMedia`
  ///   başlığı beyaz YAPMIYORDU (kök neden orada yazılı).
  /// - Perde koyulaştı ve aşağı uzatıldı: yarı saydam siyahın altında kalan
  ///   parlak bir video karesi adı yutuyordu.
  /// - Ad artık iki satıra kadar sarabiliyor ve altında süre/sıra bilgisi var;
  ///   "AHBS_Egitim_Videosu_1080.mp4" tek satıra sığmıyordu, üstelik dört
  ///   eylem simgesi başlığa kalan yeri iyice daraltıyordu.
  ///
  /// 2026-11-15 (kullanıcı: *"tarihi varsa adının altına yazsın, diğer detay
  /// bilgiler gereksiz"*): alt satır yalnız TARİH ("4 Ekim 2025 · 15:34");
  /// sıra ("105/291") ve uzantı ("MP4") kalktı.
  Widget _topBar() {
    final position = _momentOf(_current) ?? '';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.mediaSurface.withValues(alpha: 0.88),
            AppColors.mediaSurface.withValues(alpha: 0.45),
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
          foregroundColor: AppColors.onMedia,
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
          // Ferrari H11.1 (kullanıcı 2026-11-14: *"üst alanda çok karışık"*):
          // 7 simge yan yana adı "VI 3…" diye eziyordu. Görünürde en sık
          // ikisi (altyazı, hız) + ⋮; seyrek olanlar menüde, metinli.
          actions: [
            IconButton(
              key: const ValueKey('mp-share'),
              tooltip: context.t('common.share'),
              icon: const Icon(AppIcons.share),
              onPressed: () {
                _scheduleHide();
                unawaited(shareEntriesFrom(context, [_current]));
              },
            ),
            // Hız: tutamaçlı çubuk, 0,05 adım (U3 m.2) — ortak levha.
            SpeedButton(
              // Uzun basış 2× geçici — hap kalıcı ayarı gösterir.
              speed: _speedBeforeBoost ?? _speed,
              tooltip: context.t('mp.play_speed'),
              color: AppColors.onMedia,
              onOpen: () {
                _scheduleHide();
                unawaited(showSpeedSheet(context,
                    current: _speed,
                    onChanged: (v) => unawaited(_setSpeed(v))));
              },
              onReset: () {
                _scheduleHide();
                unawaited(_setSpeed(1.0));
              },
            ),
            _moreMenu(),
          ],
        ),
      ),
    );
  }

  /// Üst çubuğun ⋮ düğmesi: doğrudan dosya işlem levhasını açar
  /// (2026-11-14, kullanıcı: *"3 nokta menüsü olmamış, direkt dosya işlem
  /// menüsü açılmalı, tüm butonlar orada olmalı"*). Eskiden ⋮ önce küçük bir
  /// açılır menü, oradan "Dosya işlemleri" → levha: iki dokunuş. Oynatıcıya
  /// özgü işlemler (A-B tekrar, küçük pencere, doldur/sığdır) levhanın en
  /// üstünde "Oynatıcı" bölümünde; "Başka uygulamayla aç" levhada zaten var.
  Widget _moreMenu() => IconButton(
        tooltip: context.t('mp.file_ops'),
        icon: const Icon(AppIcons.more),
        onPressed: () {
          _scheduleHide();
          // İzlerken "bunu Önemli'ye taşıyayım" demek için oynatıcıyı
          // kapatıp dosyayı listede aramak gerekmesin (istek 2026-07-29).
          unawaited(showEntryActions(
            context,
            FsEntry.fromEntity(File(_current)),
            // Dosya zaten açık: "Aç" ve pano gizli (2026-11-15 ortak düzen).
            inViewer: true,
            extrasTitle: context.t('mp.sec_player'),
            extras: [
              if (!_isAudio) ...[
                EntryExtraAction(
                  icon: _subtitlePath == null
                      ? AppIcons.closedCaptionOff
                      : AppIcons.closedCaption,
                  label: context.t('mp.subtitles'),
                  color: _subtitlePath == null ? null : AppHues.amberBright,
                  onTap: () {
                    if (mounted) unawaited(_openSubtitleMenu());
                  },
                ),
                // **A-B tekrar** — aynı yeri defalarca izlemek (dil, gitar,
                // spor) elle geri sarmakla yapılıyordu.
                EntryExtraAction(
                  icon: _p.loopStage == 0 ? AppIcons.repeat : AppIcons.repeatOn,
                  label: context.t(switch (_p.loopStage) {
                    0 => 'mp.loop_mark_a',
                    1 => 'mp.loop_mark_b',
                    _ => 'mp.loop_off',
                  }),
                  color: _p.loopStage == 0 ? null : AppHues.amberBright,
                  onTap: () {
                    if (!mounted) return;
                    _p.markLoopPoint();
                    _toast(context.t(switch (_p.loopStage) {
                      1 => 'mp.loop_a_set',
                      2 => 'mp.loop_on',
                      _ => 'mp.loop_cleared',
                    }));
                    _scheduleHide();
                  },
                ),
                EntryExtraAction(
                  icon: AppIcons.pictureInPictureAlt,
                  label: context.t('mp.float_window'),
                  onTap: () {
                    if (mounted) unawaited(_popOut());
                  },
                ),
                EntryExtraAction(
                  icon: _zoomFill ? AppIcons.fitScreen : AppIcons.cropFree,
                  label:
                      context.t(_zoomFill ? 'mp.zoom_fit' : 'mp.zoom_fill'),
                  onTap: () {
                    if (mounted) _partSetState(() => _zoomFill = !_zoomFill);
                  },
                ),
              ],
            ],
          ));
        },
      );

  Widget _surface(VideoPlayerController? c, VideoPlayerValue? value) {
    if (_loading ||
        (_error == null && !_isAudio &&
            (c == null || value == null || !value.isInitialized))) {
      // Galeriden açılışta küçük resim hücreden büyüyerek gelir (Hero) ve
      // video hazırlanırken ekranda o durur — açılıştaki kısa bekleme
      // animasyonun içinde kalır (kullanıcı 2026-11-15).
      final poster = _posterView();
      if (poster != null) return poster;
      if (!_loading) return const SizedBox.shrink();
      // Kapak bellekte yoksa da büyüme geçişi kurulur: uçan resim ızgara
      // hücresinin kendisidir (2026-11-15).
      return Stack(fit: StackFit.expand, children: [
        if (!_isAudio && _current.isNotEmpty)
          Hero(
            tag: fmMediaHeroTag(_current),
            flightShuttleBuilder: (_, _, direction, from, to) {
              final grid = direction == HeroFlightDirection.push ? from : to;
              return (grid.widget as Hero).child;
            },
            child: const SizedBox.expand(),
          ),
        const Center(child: CircularProgressIndicator()),
      ]);
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.error, color: AppColors.onMediaSoft, size: 48),
              const SizedBox(height: Gap.md),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.onMediaSoft)),
              const SizedBox(height: Gap.md),
              FilledButton.tonalIcon(
                onPressed: () => EntryOpener.openExternally(context, _current),
                icon: const Icon(AppIcons.openWith),
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
                color: AppColors.onMedia.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.sheet),
              ),
              child: const Icon(AppIcons.audio,
                  size: 72, color: AppColors.onMediaSoft),
            ),
            const SizedBox(height: Gap.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Text(
                p.basenameWithoutExtension(_current),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.type.heading.copyWith(color: AppColors.onMedia),
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
    final poster = _posterImage;
    if (_zoomFill) {
      final player = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: RotatedBox(
            quarterTurns: _quarterTurns,
            child: SizedBox(
              width: value.size.width,
              height: value.size.height,
              child: VideoPlayer(c),
            ),
          ),
        ),
      );
      return _heroWrap(poster == null
          ? player
          : Stack(fit: StackFit.expand, children: [
              player,
              _PosterVeil(controller: c, image: poster),
            ]));
    }
    return Center(
      child: _heroWrap(RotatedBox(
        quarterTurns: _quarterTurns,
        child: AspectRatio(
          aspectRatio: value.aspectRatio,
          // Kapak, oynatma ilerleyene (ilk kare gelene) dek üstte: doku
          // ilk karesini çizene kadar siyah yanıp sönmesin.
          child: poster == null
              ? VideoPlayer(c)
              : Stack(fit: StackFit.expand, children: [
                  VideoPlayer(c),
                  _PosterVeil(controller: c, image: poster),
                ]),
        ),
      )),
    );
  }

  /// Galerideki hücreyle eşleşen kahraman (açılış/kapanış geçişi).
  Widget _heroWrap(Widget child) => _isAudio || _current.isEmpty
      ? child
      : Hero(tag: fmMediaHeroTag(_current), child: child);

  /// Video hazırlanırken: kapak resmi, en-boy oranında ortalı.
  Widget? _posterView() {
    final poster = _posterImage;
    if (poster == null || _isAudio) return null;
    final aspect = _posterAspect;
    final img = Image(
      image: poster,
      fit: aspect != null ? BoxFit.cover : BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return Center(
      child: _heroWrap(
        aspect != null ? AspectRatio(aspectRatio: aspect, child: img) : img,
      ),
    );
  }

  /// Sağa / sola çevir düğmeleri (kilidin karşı kenarında, kontrollerle
  /// birlikte görünür). Döndürme yalnız görüntüde — dosya değişmez.
  Widget _rotateButtons() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (key, icon, tip, delta) in [
            ('mp-rotate-right', AppIcons.rotateRight, 'mp.rotate_right', 1),
            ('mp-rotate-left', AppIcons.rotateLeft, 'mp.rotate_left', 3),
          ]) ...[
            Material(
              color: AppColors.mediaSurface.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              child: IconButton(
                key: ValueKey<String>(key),
                tooltip: context.t(tip),
                icon: Icon(icon, color: AppColors.onMedia),
                onPressed: () {
                  _partSetState(
                      () => _quarterTurns = (_quarterTurns + delta) % 4);
                  _scheduleHide();
                },
              ),
            ),
            if (delta == 1) const SizedBox(height: Gap.sm),
          ],
        ],
      );

  /// **Otomatik geçiş** aç/kapa (2026-11-16, kullanıcı: "videolarda oto
  /// geçişi bir butona bağla, sağ alttaki boşluğa koy, aktif pasif olsun").
  /// Açıkken video bitince sıradakine geçer; kapalıyken sonda durur. Ayar
  /// kalıcı ([VideoPlayback.autoNext]).
  Widget _autoNextButton() {
    final on = VideoPlayback.autoNext;
    return Material(
      color: on
          ? AppHues.amberBright.withValues(alpha: 0.85)
          : AppColors.mediaSurface.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: IconButton(
        key: const ValueKey('mp-auto-next'),
        tooltip: context.t('mp.auto_next'),
        isSelected: on,
        icon: Icon(AppIcons.playlistPlay,
            color: on ? AppColors.mediaSurface : AppColors.onMedia),
        onPressed: () {
          final v = !VideoPlayback.autoNext;
          _partSetState(() => VideoPlayback.setAutoNext(v));
          _toast(context.t(v ? 'mp.auto_next_on' : 'mp.auto_next_off'));
          _scheduleHide();
        },
      ),
    );
  }

  Widget _controls(VideoPlayerController c, VideoPlayerValue value) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          Gap.md, Gap.lg, Gap.md, MediaQuery.paddingOf(context).bottom + Gap.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.35, 1.0],
          colors: [
            AppColors.none,
            AppColors.mediaScrim,
            AppColors.mediaSurface.withValues(alpha: 0.88),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(_MediaPlayerScreenState._fmt(value.position),
                  style: const TextStyle(color: AppColors.onMediaSoft)),
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
              Text(_MediaPlayerScreenState._fmt(value.duration),
                  style: const TextStyle(color: AppColors.onMediaSoft)),
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
                    color: AppColors.onMedia,
                    icon: const Icon(AppIcons.skipPrevious),
                    onPressed: _index > 0 ? () => _skip(-1) : null,
                  ),
                  IconButton(
                    tooltip: context.t('mp.back10'),
                    color: AppColors.onMedia,
                    icon: const Icon(AppIcons.replay10),
                    onPressed: () => _seekBy(-10),
                  ),
                  IconButton(
                    tooltip: context.t(value.isPlaying ? 'mp.pause' : 'mp.play'),
                    iconSize: 48,
                    color: AppColors.onMedia,
                    icon: Icon(value.isPlaying
                        ? AppIcons.pauseCircle
                        : AppIcons.playCircle),
                    onPressed: _togglePlay,
                  ),
                  IconButton(
                    tooltip: context.t('mp.forward10'),
                    color: AppColors.onMedia,
                    icon: const Icon(AppIcons.forward10),
                    onPressed: () => _seekBy(10),
                  ),
                  IconButton(
                    tooltip: context.t('common.next'),
                    color: AppColors.onMedia,
                    icon: const Icon(AppIcons.skipNext),
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
                    color: AppColors.onMedia,
                    icon: Icon(
                        _landscape ? AppIcons.fullscreenExit : AppIcons.fullscreen),
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

/// Videonun ilk karesi gelene dek üstte duran kapak. Konum bir kez
/// ilerleyince (ya da oynatma hiç başlamadan 2 sn geçince) kalkar ve
/// dinlemeyi bırakır — kalan oynatma boyunca katman yok.
class _PosterVeil extends StatefulWidget {
  final VideoPlayerController controller;
  final ImageProvider<Object> image;
  const _PosterVeil({required this.controller, required this.image});

  @override
  State<_PosterVeil> createState() => _PosterVeilState();
}

class _PosterVeilState extends State<_PosterVeil> {
  bool _gone = false;
  Timer? _timer;
  Timer? _playTimer;
  late Duration _initialPosition = widget.controller.value.position;

  @override
  void initState() {
    super.initState();
    _initialPosition = widget.controller.value.position;
    widget.controller.addListener(_check);
    _check();
    // Zaman aşımı (animasyon süresi değil): oynatma hiç başlamazsa da kalkar.
    _timer = Timer(const Duration(seconds: 2), _drop);
  }

  @override
  void didUpdateWidget(covariant _PosterVeil oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_check);
      _playTimer?.cancel();
      _playTimer = null;
      _initialPosition = widget.controller.value.position;
      if (!_gone) {
        widget.controller.addListener(_check);
        _check();
      }
    }
  }

  void _check() {
    final v = widget.controller.value;
    if (v.position > _initialPosition) {
      _drop();
      return;
    }
    // Oynarken 250 ms yedek zamanlayıcı: ilk kare gelmesine rağmen konum
    // henüz ilerlemediyse siyah parlama olmadan perdeyi düşür.
    if (v.isPlaying && _playTimer == null) {
      _playTimer = Timer(const Duration(microseconds: 250000), _drop);
    }
  }

  void _drop() {
    if (_gone) return;
    widget.controller.removeListener(_check);
    _timer?.cancel();
    _playTimer?.cancel();
    if (mounted) setState(() => _gone = true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    _timer?.cancel();
    _playTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _gone
      ? const SizedBox.shrink()
      : IgnorePointer(
          child: Image(
            image: widget.image,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        );
}
