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
          style: const TextStyle(
            color: AppColors.onMedia,
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: AppColors.mediaSurface, blurRadius: 3),
              Shadow(color: AppColors.mediaSurface, blurRadius: 6),
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
            ? Icons.closed_caption_off_rounded
            : Icons.closed_caption_rounded),
        onSelected: (value) async {
          switch (value) {
            case '_off':
              await _selectSubtitle(null);
            case '_pick':
              await _pickSubtitle();
            case '_later':
              _partSetState(() => _subtitleOffsetMs -= 500);
              SubtitleDelays.set(_current, _subtitleOffsetMs);
            case '_sooner':
              _partSetState(() => _subtitleOffsetMs += 500);
              SubtitleDelays.set(_current, _subtitleOffsetMs);
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
          actions: [
            if (!_isAudio) ...[
              // **A-B tekrar** — aynı yeri defalarca izlemek (dil, gitar,
              // spor) elle geri sarmakla yapılıyordu.
              IconButton(
                tooltip: context.t(switch (_p.loopStage) {
                  0 => 'mp.loop_mark_a',
                  1 => 'mp.loop_mark_b',
                  _ => 'mp.loop_off',
                }),
                icon: Icon(
                  _p.loopStage == 0 ? Icons.repeat_rounded : Icons.repeat_on_rounded,
                  color: _p.loopStage == 0 ? null : Colors.amberAccent,
                ),
                onPressed: () {
                  _p.markLoopPoint();
                  _toast(context.t(switch (_p.loopStage) {
                    1 => 'mp.loop_a_set',
                    2 => 'mp.loop_on',
                    _ => 'mp.loop_cleared',
                  }));
                  _scheduleHide();
                },
              ),
              IconButton(
                tooltip: context.t('mp.float_window'),
                icon: const Icon(Icons.picture_in_picture_alt_rounded),
                onPressed: _popOut,
              ),
              IconButton(
                tooltip: context.t(_zoomFill ? 'mp.zoom_fit' : 'mp.zoom_fill'),
                icon: Icon(_zoomFill ? Icons.fit_screen_rounded : Icons.crop_free_rounded),
                onPressed: () => _partSetState(() => _zoomFill = !_zoomFill),
              ),
            ],
            if (!_isAudio) _subtitleMenu(),
            PopupMenuButton<double>(
              tooltip: context.t('mp.play_speed'),
              icon: const Icon(Icons.speed_rounded),
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
              icon: const Icon(AppIcons.openWith),
              onPressed: () => EntryOpener.openExternally(context, _current),
            ),
            // İzlerken "bunu Önemli'ye taşıyayım" demek için oynatıcıyı
            // kapatıp dosyayı listede aramak gerekmesin (istek 2026-07-29:
            // "her türlü dosyada bu olmalı").
            IconButton(
              tooltip: context.t('mp.file_ops'),
              icon: const Icon(AppIcons.more),
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
                style: const TextStyle(color: AppColors.onMedia, fontSize: 18),
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
          Gap.md, Gap.sm, Gap.md, MediaQuery.paddingOf(context).bottom + Gap.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.mediaSurface.withValues(alpha: 0.75),
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
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: _index > 0 ? () => _skip(-1) : null,
                  ),
                  IconButton(
                    tooltip: context.t('mp.back10'),
                    color: AppColors.onMedia,
                    icon: const Icon(Icons.replay_10_rounded),
                    onPressed: () => _seekBy(-10),
                  ),
                  IconButton(
                    tooltip: context.t(value.isPlaying ? 'mp.pause' : 'mp.play'),
                    iconSize: 48,
                    color: AppColors.onMedia,
                    icon: Icon(value.isPlaying
                        ? Icons.pause_circle_rounded
                        : Icons.play_circle_rounded),
                    onPressed: _togglePlay,
                  ),
                  IconButton(
                    tooltip: context.t('mp.forward10'),
                    color: AppColors.onMedia,
                    icon: const Icon(Icons.forward_10_rounded),
                    onPressed: () => _seekBy(10),
                  ),
                  IconButton(
                    tooltip: context.t('common.next'),
                    color: AppColors.onMedia,
                    icon: const Icon(Icons.skip_next_rounded),
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
                        _landscape ? Icons.fullscreen_exit_rounded : AppIcons.fullscreen),
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
