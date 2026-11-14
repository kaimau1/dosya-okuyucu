part of '../viewer_screen.dart';

/// **Okuma yardımcıları** (Faz 48, rakip okuyucularda olup bizde olmayan üç
/// şey): okurken ekran açık, ses tuşlarıyla sayfa çevirme, otomatik kaydırma.
/// Üçü de yalnız PDF'te ve yalnız açıkça istenince çalışır — kapalıyken hiçbir
/// dinleyici, kare geri çağrısı ya da kilit yoktur (kasma/pil bedeli sıfır).
extension _ViewerScreenPdfReadingAidsPart on _ViewerScreenState {
  static const _kKeepAwake = 'pdf_keep_awake';
  static const _kVolumeKeys = 'pdf_volume_keys';
  static const _kSidePanel = 'pdf_side_panel';
  static const _kPaged = 'pdf_paged';

  /// Otomatik kaydırma hızları (mantıksal piksel / saniye): kapalı, yavaş,
  /// orta, hızlı.
  static const autoScrollSpeeds = [0.0, 24.0, 48.0, 96.0];

  Future<void> _loadReadingAids() async {
    if (!_isPdf) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (prefs.getBool(_kKeepAwake) ?? false) _setKeepAwake(true, save: false);
      if (prefs.getBool(_kVolumeKeys) ?? false) {
        _setVolumeKeys(true, save: false);
      }
      if (prefs.getBool(_kSidePanel) ?? false) {
        _partSetState(() => _pdfSidePanel = true);
      }
      if (prefs.getBool(_kPaged) ?? false) {
        _partSetState(() => _pdfPaged = true);
        if (_pdfController.isReady) _fitPagedSoon();
      }
    } catch (_) {
      // Tercih okunamadı: ikisi de kapalı başlar (zararsız varsayılan).
    }
  }

  /// Yan küçük resim şeridini aç/kapa (Ferrari H1.3). Görünüm genişliği
  /// değişince pdfrx düzeni yeniden kurar; okunan sayfaya geri oturulur.
  void _toggleSidePanel() {
    final page = _pdfPage;
    _partSetState(() => _pdfSidePanel = !_pdfSidePanel);
    _saveAid(_kSidePanel, _pdfSidePanel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pdfController.isReady) return;
      _pdfJumpTarget = page;
      unawaited(_pdfController.goToPage(pageNumber: page));
      if (_pdfSidePanel) _followSidePanel(page, animate: false);
    });
  }

  /// Şerit açıkken güncel sayfanın küçük resmi görünür kalsın: ekran dışına
  /// düştüyse ortaya kaydırılır. Öğe boyu sayfa oranından hesaplanır
  /// (şerit [ListView.builder] — öğeler kurulmadan konumu bilinmez).
  void _followSidePanel(int page, {bool animate = true}) {
    final doc = _pdfDoc;
    final ctrl = _sidePanelScroll;
    if (doc == null || !ctrl.hasClients || page < 1) return;
    final n = doc.pages.length;
    if (page > n) return;
    const inner = _kSidePanelWidth - 2 * Gap.sm;
    final label = (Theme.of(context).textTheme.labelSmall?.fontSize ?? 11) * 1.5;
    double extent(int i) {
      final pg = doc.pages[i];
      final h = pg.width <= 0 ? inner : inner * pg.height / pg.width;
      return h + 2 + label + Gap.sm;
    }

    var top = Gap.sm;
    for (var i = 0; i < page - 1; i++) {
      top += extent(i);
    }
    final h = extent(page - 1);
    final pos = ctrl.position;
    if (top >= pos.pixels && top + h <= pos.pixels + pos.viewportDimension) {
      return;
    }
    final target = (top - (pos.viewportDimension - h) / 2)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (animate) {
      unawaited(ctrl.animateTo(target,
          duration: Motion.of(context, Motion.medium), curve: Motion.standard));
    } else {
      ctrl.jumpTo(target);
    }
  }

  void _saveAid(String key, bool on) {
    SharedPreferences.getInstance()
        .then((p) => p.setBool(key, on))
        .catchError((_) => false);
  }

  /// Ekran sönmesin. Kilit [ScreenAwake] sayacıyla tutulur; otomatik kaydırma
  /// da kendi başına bir sahip olarak ister (ikisi birbirini bırakmaz).
  void _setKeepAwake(bool on, {bool save = true}) {
    _keepAwakeRelease?.call();
    _keepAwakeRelease = on ? ScreenAwake.request() : null;
    _partSetState(() => _keepAwake = on);
    if (save) _saveAid(_kKeepAwake, on);
  }

  /// Ses kısma = sonraki sayfa, açma = önceki (Moon+/Librera alışkanlığı).
  /// Sunum kumandasının yerel köprüsü (`ci/Slayt.kt`) aynen kullanılır.
  void _setVolumeKeys(bool on, {bool save = true}) {
    unawaited(SlidesNative.volumeKeys(on));
    _volumeSub?.cancel();
    _volumeSub = on
        ? SlidesNative.events.listen((e) {
            if (e.$1 != 'volume' || !_pdfController.isReady) return;
            _turnPdfPage(e.$2 == 'next' ? 1 : -1);
          })
        : null;
    _partSetState(() => _volumeKeys = on);
    if (save) _saveAid(_kVolumeKeys, on);
  }

  void _turnPdfPage(int delta) {
    final total = _pageCount;
    if (total == 0) return;
    final from = _pdfJumpTarget ?? _livePdfPage() ?? _pdfPage;
    final target = (from + delta).clamp(1, total);
    if (target == from) return;
    _pdfJumpTarget = target;
    // Sayfa sayfa kipinde sayfa ekrana sığarak gelir (H3.5).
    if (_pagedActive) {
      unawaited(_showPagedPage(target));
      return;
    }
    _pdfController
        .goToPage(
            pageNumber: target,
            duration: Motion.of(context, Motion.short))
        .catchError((_) {});
  }

  /// Otomatik kaydırma: [autoScrollSpeeds] dizinindeki hız. 0 = kapalı.
  /// Kare geri çağrısı yalnız açıkken kurulur; parmak ekrandayken durur,
  /// kalkınca kaldığı yerden sürer; belgenin sonunda kendiliğinden kapanır.
  void _setAutoScroll(int level) {
    _partSetState(() => _autoScroll = level);
    _autoScrollLast = null;
    _autoScrollAwake?.call();
    _autoScrollAwake =
        level > 0 ? ScreenAwake.request(motion: true) : null;
    if (level > 0) _readingBars.hide();
    _scheduleAutoScroll();
  }

  void _scheduleAutoScroll() {
    if (_autoScroll == 0 || _autoScrollFrame != null) return;
    _autoScrollFrame =
        WidgetsBinding.instance.scheduleFrameCallback(_autoScrollTick);
  }

  void _autoScrollTick(Duration now) {
    _autoScrollFrame = null;
    if (!mounted || _autoScroll == 0) return;
    final last = _autoScrollLast;
    _autoScrollLast = now;
    if (last != null && !_autoScrollHeld && _pdfController.isReady) {
      final dt = (now - last).inMicroseconds / 1e6;
      // Uzun ara (arka plan, takılma) sıçratmasın.
      final dy = autoScrollSpeeds[_autoScroll] * dt.clamp(0.0, 0.05);
      final m = _pdfController.value;
      final t = m.getTranslation();
      _pdfController.value = m.clone()..setTranslationRaw(t.x, t.y - dy, t.z);
      if (_pdfController.value.getTranslation().y >= t.y - 0.01 && dy > 0) {
        _setAutoScroll(0); // belgenin sonu
        return;
      }
    }
    _scheduleAutoScroll();
  }

  /// Görüntüleyicinin [Listener]'ından: parmak ekrandayken kaydırma bekler.
  void _holdAutoScroll(bool held) {
    if (_autoScroll == 0) return;
    _autoScrollHeld = held;
    _autoScrollLast = null;
  }

  void _disposeReadingAids() {
    _keepAwakeRelease?.call();
    _autoScrollAwake?.call();
    if (_autoScrollFrame != null) {
      WidgetsBinding.instance.cancelFrameCallbackWithId(_autoScrollFrame!);
    }
    if (_volumeKeys) unawaited(SlidesNative.volumeKeys(false));
    _volumeSub?.cancel();
  }
}
