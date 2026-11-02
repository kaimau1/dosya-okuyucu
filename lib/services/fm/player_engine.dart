import 'package:video_player/video_player.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    show VideoPlayerPlatform;

/// **Oynatma motoru** — ExoPlayer (varsayılan) ↔ mpv (VLC benzeri).
///
/// Kullanıcı isteği 2026-11-02: *"vlc gibi … açılamayan kodekleri çözme"*.
/// ExoPlayer cihazın kod çözücülerine bağlı: MKV'deki AC3/E-AC3/DTS/TrueHD
/// ses, eski AVI/WMV/FLV/RMVB görüntüsü çoğu telefonda çözülemiyor. mpv
/// (`media_kit`, içinde FFmpeg) bunların hepsini yazılımla çözüyor.
///
/// ## Neden ikisi birden (yalnız mpv değil)
/// ExoPlayer donanım kod çözücüyü doğrudan kullanıyor, PiP/medya oturumu
/// onunla yıllardır cihazda sınanmış durumda. mpv yalnız GEREKİNCE devreye
/// giriyor ([VideoPlayback] → [needsMpv]); kullanıcı menüden de seçebiliyor.
///
/// ## Neden `VideoPlayerPlatform.instance` değiştiriliyor
/// `video_player_media_kit`, mpv'yi `video_player`ın bir platform uygulaması
/// olarak bağlıyor: ekran, mini çubuk, PiP ve altyazı katmanı HİÇ değişmeden
/// iki motorla da çalışıyor. Bedeli: `video_player` her çağrıda o anki
/// örneği kullanıyor ve örnek değişince yenisinin `init()`i çağrılıp onun
/// TÜM oynatıcıları kapatılıyor. Bu yüzden motor değiştirmeden ÖNCE açık
/// denetleyiciler kapatılmalı ([VideoPlayback] eskisini önce bırakıyor, ses
/// oynatıcısı [switchTo]'dan önce durduruluyor).
abstract final class PlayerEngine {
  static VideoPlayerPlatform? _exo;
  static VideoPlayerPlatform? _mpv;

  /// Şu an mpv mi kullanılıyor?
  static bool get isMpv =>
      _mpv != null && identical(VideoPlayerPlatform.instance, _mpv);

  /// Motoru seçer. mpv ilk istendiğinde yüklenir (libmpv ~20 MB: açılışta
  /// yüklemek her kullanıcının açılışını yavaşlatırdı).
  static void switchTo({required bool mpv}) {
    if (mpv == isMpv) return;
    _exo ??= VideoPlayerPlatform.instance;
    if (mpv) {
      if (_mpv == null) {
        VideoPlayerMediaKit.ensureInitialized(android: true);
        _mpv = VideoPlayerPlatform.instance;
      }
      VideoPlayerPlatform.instance = _mpv!;
    } else {
      VideoPlayerPlatform.instance = _exo!;
    }
  }

  /// Yazılımla bile ExoPlayer'da sorun çıkaran kaplar: bunlar baştan mpv'de
  /// açılır (ExoPlayer kimini hiç tanımıyor, kimini sessiz oynatıyor).
  static const mpvFirst = {
    'avi', 'wmv', 'asf', 'flv', 'rm', 'rmvb', 'vob', 'divx', 'xvid', //
    'ogv', 'm2ts', 'mts', 'mpg', 'mpeg', 'dv', 'f4v',
  };

  /// ExoPlayer'da açılmış bir dosya mpv'ye mi geçmeli?
  ///
  /// - Ses parçası var ama HİÇBİRİ seçilemedi → kod çözücü yok (AC3/DTS):
  ///   ExoPlayer hata vermeden SESSİZ oynatıyor; tek ipucu bu.
  /// - Görüntü bekleniyor ama boyut sıfır → görüntü kod çözücüsü yok.
  static bool needsMpv({
    required List<VideoAudioTrack> audioTracks,
    required bool expectVideo,
    required bool hasPicture,
  }) {
    if (audioTracks.isNotEmpty && !audioTracks.any((t) => t.isSelected)) {
      return true;
    }
    return expectVideo && !hasPicture;
  }
}
