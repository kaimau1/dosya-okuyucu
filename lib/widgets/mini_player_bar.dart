import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../core/app_navigator.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../screens/fm/audio_player_screen.dart';
import '../screens/fm/media_player_screen.dart';
import '../services/fm/audio_playback.dart';
import '../services/fm/video_playback.dart';

/// **Ekran altı mini oynatma çubuğu** (kullanıcı isteği 2026-09-03:
/// *"çalarken uygulama ekran altında oynatma çubuğu görülsün"*).
///
/// Spotify/YouTube Music'teki çubuğun karşılığı: çalan ses ya da video
/// uygulamanın HANGİ ekranında olursa olsun altta duruyor — kapak, ad,
/// oynat/duraklat, kapat ve ince bir ilerleme çizgisi. Dokununca tam
/// oynatıcıya götürüyor.
///
/// **Niye `MaterialApp.builder`da:** çubuk tek bir ekranın değil uygulamanın
/// parçası; her ekrana tek tek eklemek hem yüz yerde tekrar hem de "eklemeyi
/// unutulan ekran" demekti. Gezinti ağacının DIŞINDA durduğu için ekranlar
/// arası geçişte de yerinden oynamıyor.
///
/// **İçeriği örtmez:** çubuk `Column`da içeriğin ALTINA konuyor ve alt sistem
/// çubuğunun payını kendisi üstleniyor (içerikten `removeBottom` ile
/// düşürülür) — üstüne binen bir katman olsaydı listelerin son satırı ve
/// yüzen düğmeler onun altında kalırdı.
class MiniPlayerBar extends StatefulWidget {
  const MiniPlayerBar({super.key});

  /// Tam oynatıcı ekrandayken çubuk gizlenir (aynı şeyin iki kopyası).
  ///
  /// Sayaç, çünkü iki oynatıcı ekranı üst üste açılabiliyor (ses çalarken
  /// video açmak gibi); `bool` olsaydı içteki kapanınca dıştaki hâlâ
  /// açıkken çubuk geri gelirdi.
  static final ValueNotifier<int> hidden = ValueNotifier<int>(0);

  /// Bir oynatıcı ekranı açıldı — çubuğu gizle. Dönen işlev geri alır.
  static VoidCallback hide() {
    hidden.value = hidden.value + 1;
    var released = false;
    return () {
      if (released) return;
      released = true;
      hidden.value = hidden.value - 1;
    };
  }

  /// Uygulamanın içeriğini çubukla birlikte sarar (bkz. `main.dart`).
  static Widget wrap(Widget child) => _MiniPlayerHost(child: child);

  @override
  State<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

/// **TUZAK — bildirim bir YAPI turunun ortasında gelebilir** (2026-09-04).
///
/// Tam oynatıcı ekranları açılırken `initState`te `MiniPlayerBar.hide()`
/// çağırıyor; bu da `hidden` bildiricisini değiştiriyor. O ekran bir yapı
/// (build) turunda kurulduğu için dinleyici doğrudan `setState` çağırınca
/// Flutter *"setState() or markNeedsBuild() called during build"* diye
/// patlıyordu — yani çalarken tam oynatıcıyı açmak hata üretiyordu.
///
/// Çözüm: yapı/yerleşim turunun ortasındaysak yeniden çizim KAREDEN SONRAYA
/// bırakılıyor. Öteki hâllerde (kullanıcı duraklattı, parça bitti) davranış
/// aynı: anında.
void _rebuildSafely(State<StatefulWidget> state) {
  if (!state.mounted) return;
  // ignore: invalid_use_of_protected_member
  void rebuild() => state.setState(() {});
  if (SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (state.mounted) rebuild();
    });
    return;
  }
  rebuild();
}

/// İçerik + çubuk. Çubuk yokken içerik hiç sarılmaz (fazladan bir `Column`
/// bile her ekranın yerleşimini yeniden ölçmek demek).
class _MiniPlayerHost extends StatefulWidget {
  final Widget child;

  const _MiniPlayerHost({required this.child});

  @override
  State<_MiniPlayerHost> createState() => _MiniPlayerHostState();
}

class _MiniPlayerHostState extends State<_MiniPlayerHost> {
  final AudioPlayback _audio = AudioPlayback.instance;
  final VideoPlayback _video = VideoPlayback.instance;

  @override
  void initState() {
    super.initState();
    _audio.addListener(_onChange);
    _video.addListener(_onChange);
    MiniPlayerBar.hidden.addListener(_onChange);
  }

  @override
  void dispose() {
    _audio.removeListener(_onChange);
    _video.removeListener(_onChange);
    MiniPlayerBar.hidden.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => _rebuildSafely(this);

  bool get _visible {
    if (MiniPlayerBar.hidden.value > 0) return false;
    // Klavye açıkken çubuk, yazılan alanın üstüne oturup ekranı daraltırdı.
    if (MediaQuery.of(context).viewInsets.bottom > 0) return false;
    // **Video ekran üstündeki yüzen penceredeyse çubuk gizli** (2026-09-03):
    // çubuktaki "oynat" ikinci bir oynatıcıyı başlatır ve iki ses üst üste
    // binerdi — kullanıcının duyacağı ilk hata bu olurdu.
    if (_video.floatingActive && !_audio.hasTrack) return false;
    return _video.hasVideo || _audio.hasTrack;
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    return Column(
      children: [
        Expanded(
          // Alt sistem çubuğunun payını artık ÇUBUK üstleniyor; içerik onu
          // bir kez daha bırakırsa ekranın altında boş bir şerit kalırdı.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: widget.child,
          ),
        ),
        const MiniPlayerBar(),
      ],
    );
  }
}

class _MiniPlayerBarState extends State<MiniPlayerBar> {
  AudioPlayback get _audio => AudioPlayback.instance;
  VideoPlayback get _video => VideoPlayback.instance;

  /// **Çubuk servisleri KENDİSİ dinliyor.** Sarmalayıcı (`_MiniPlayerHost`)
  /// yalnız görünürlüğü yönetiyor ve `const MiniPlayerBar()` her seferinde
  /// AYNI widget nesnesi olduğu için Flutter alt ağacı yeniden çizmiyordu:
  /// duraklatınca düğme oynat simgesine dönmüyordu.
  @override
  void initState() {
    super.initState();
    _audio.addListener(_onChange);
    _video.addListener(_onChange);
  }

  @override
  void dispose() {
    _audio.removeListener(_onChange);
    _video.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => _rebuildSafely(this);

  /// Video çalıyorsa çubuk onu gösterir: kullanıcı en son onu açmıştır.
  bool get _isVideo => _video.hasVideo;

  String get _title => _isVideo ? _video.title : _audio.title;

  String get _subtitle {
    if (_isVideo) {
      final dir = p.dirname(_video.current);
      return dir.isEmpty ? '' : p.basename(dir);
    }
    final tags = _audio.tags;
    return tags.subtitle.isEmpty
        ? p.basename(_audio.current)
        : tags.subtitle;
  }

  bool get _playing => _isVideo ? _video.playing : _audio.playing;

  Future<void> _toggle() =>
      _isVideo ? _video.toggle() : _audio.toggle();

  Future<void> _close() => _isVideo ? _video.close() : _audio.stop();

  /// **TUZAK — çubuğun kendi `context`inde Navigator YOK** (kullanıcı
  /// çökmesi 2026-09-04: `Null check operator used on a null value`,
  /// `Navigator.of` → `_MiniPlayerBarState._openFull`).
  ///
  /// Çubuk bilinçli olarak `MaterialApp.builder` içinde duruyor (bkz. sınıf
  /// açıklaması), yani gezinti ağacının **DIŞINDA**. `Navigator.of(context)`
  /// yukarı doğru arar, hiçbir `Navigator` bulamaz ve `!` ile çöker —
  /// çubuğa her dokunuşta uygulama kapanıyordu.
  ///
  /// Çözüm: uygulamanın kök `navigatorKey`i (zaten `main.dart`ta var ve
  /// `MaterialApp`a veriliyor). Anahtar bağlı değilse (test, seçici kipi)
  /// sessizce hiçbir şey yapılmıyor — çökmek yerine dokunuş boşa gider.
  void _openFull() {
    final path = _isVideo ? _video.current : _audio.current;
    if (path.isEmpty) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final playlist = _isVideo ? _video.playlist : _audio.playlist;
    unawaited(nav.push(MaterialPageRoute(
      builder: (_) => _isVideo
          ? MediaPlayerScreen(path: path, playlist: playlist)
          : AudioPlayerScreen(path: path, playlist: playlist),
    )));
  }

  Widget _art(ColorScheme scheme) {
    final cover = _isVideo ? null : _audio.tags.cover;
    if (cover != null && cover.isNotEmpty) {
      return Image.memory(
        cover,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _artFallback(scheme),
      );
    }
    return _artFallback(scheme);
  }

  Widget _artFallback(ColorScheme scheme) => Container(
        width: 44,
        height: 44,
        color: scheme.primaryContainer,
        child: Icon(
          _isVideo ? Icons.movie_outlined : Icons.music_note,
          size: 22,
          color: scheme.onPrimaryContainer,
        ),
      );

  /// İnce ilerleme çizgisi. Video için denetleyicinin kendi
  /// `ValueListenable`ı dinleniyor (konum saniyede iki kez değişiyor ve
  /// yeniden çizilen alan yalnız bu çizgi olsun).
  Widget _progress(ColorScheme scheme) {
    if (_isVideo) {
      final c = _video.controller;
      if (c == null) return const SizedBox(height: 2);
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (_, live, __) =>
            _progressLine(scheme, live.position, live.duration),
      );
    }
    return _progressLine(scheme, _audio.position, _audio.duration);
  }

  Widget _progressLine(ColorScheme scheme, Duration position, Duration total) {
    final value = total.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return LinearProgressIndicator(
      value: value,
      minHeight: 2,
      backgroundColor: scheme.surfaceContainerHighest,
      color: scheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = _title;
    if (title.isEmpty && _subtitle.isEmpty) return const SizedBox.shrink();
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _progress(scheme),
            InkWell(
              onTap: _openFull,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.sm, 6, Gap.xs, 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.control),
                      child: _art(scheme),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    // **TUZAK — burada `tooltip:` KULLANILAMAZ** (2026-09-04).
                    // `Tooltip` gösterilirken bir `Overlay` ister; çubuk
                    // `MaterialApp.builder`da, yani Navigator'ın (ve onun
                    // Overlay'inin) DIŞINDA duruyor. Uzun basınca hata
                    // veriyordu. Erişilebilirlik için `Semantics` etiketi
                    // aynı işi görüyor ve Overlay istemiyor.
                    Semantics(
                      label: context.t(_playing ? 'mp.pause' : 'mp.play'),
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          size: 30,
                        ),
                        onPressed: () => unawaited(_toggle()),
                      ),
                    ),
                    Semantics(
                      label: context.t('common.close'),
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => unawaited(_close()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
