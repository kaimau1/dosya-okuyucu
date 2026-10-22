part of '../media_player_screen.dart';

extension _MediaPlayerScreenActionsPart on _MediaPlayerScreenState {
  /// Şu anki dosyanın altyazılarını bulur ve birini seçer.
  ///
  /// Otomatik seçim **arayüz diline** göre: Türkçe arayüzde `Film.tr.srt`
  /// varsa o açılır. Yoksa ilk altyazı — tek altyazısı olan bir filmde
  /// kullanıcının menüyü açması gerekmesin.
  Future<void> _loadSubtitles() async {
    if (_isAudio) {
      if (mounted) {
        _partSetState(() {
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
    _partSetState(() {
      _subtitles = found;
      // Gecikme dosya BAŞINA hatırlanıyor (2026-09-06): bir dizinin altyazısı
      // kaymışsa her bölümde kaymış olur; kullanıcı her açılışta aynı beş
      // dokunuşu tekrarlıyordu.
      _subtitleOffsetMs = SubtitleDelays.forPath(path);
    });
    if (found.isEmpty) {
      _partSetState(() {
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
        _partSetState(() {
          _subtitlePath = null;
          _cues = const [];
        });
      }
      return;
    }
    final cues = await Subtitles.load(subPath);
    if (!mounted || (forPath != null && forPath != _current)) return;
    _partSetState(() {
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
    _partSetState(() {
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
    _partSetState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
    if (_isAudio) return;
    final width = MediaQuery.sizeOf(context).width;
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
    final height = MediaQuery.sizeOf(context).height;
    final next = (_volume - details.delta.dy / (height * 0.6)).clamp(0.0, 1.0);
    _volume = next;
    unawaited(c.setVolume(next));
    _volumeTimer?.cancel();
    _partSetState(() => _volumeHint = next);
  }

  /// Göstergeyi kısa süre sonra gizler (kaydırma bitti).
  void _hideVolumeSoon() {
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _partSetState(() => _volumeHint = null);
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

  /// **Küçük pencere (PiP)** — video uygulamadan çıkınca da sürsün.
  /// Eski yüzen pencere gibi izin istemez (Faz 10).
  Future<void> _popOut() async {
    if (!await _p.enterPip() && mounted) _toast(context.t('mp.float_failed'));
  }

  Future<void> _setSpeed(double speed) => _p.setSpeed(speed);

  void _toggleLandscape() {
    _landscape = !_landscape;
    SystemChrome.setPreferredOrientations(_landscape
        ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
        _landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    _partSetState(() {});
  }

  /// Video oynarken kontroller 3 sn sonra kaybolur (sesde hep açık kalır).
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_isAudio) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        _partSetState(() => _controlsVisible = false);
      }
    });
  }
}
