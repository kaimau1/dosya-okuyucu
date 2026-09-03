import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import 'audio_tags.dart';
import 'fm_env.dart';
import 'notification_hub.dart';

/// Tekrar kipi (kapalı / tek parça / liste).
enum RepeatMode { off, one, all }

/// **Arka planda çalan ses servisi.**
///
/// Kullanıcı isteği 2026-09-02: *"müziklerde, ses dosyalarında arka planda
/// oynat seçeneği olmalı, müzik programları gibi."*
///
/// **Kök neden:** oynatıcı bütün durumu EKRANIN state'inde tutuyordu ve
/// `dispose`ta `player.dispose()` çağırıyordu — ekrandan çıkan kullanıcı
/// müziği de kapatmış oluyordu. Durum artık burada; ekran yalnız bir
/// görüntüleyici.
///
/// **Süreç neden hayatta kalıyor:** Android (özellikle MIUI) ön planda
/// olmayan süreci donduruyor. Uygulamada indirme kuyruğu için zaten bir ön
/// plan servisi var (`NotificationHub.holdService`); çalarken onu tutuyoruz.
/// Böylece **yeni bağımlılık gerekmedi** ve kalıcı bildirim de o servisin
/// bildirimi oluyor: kullanıcı ne çaldığını görüyor, duraklatıp
/// geçebiliyor.
class AudioPlayback extends ChangeNotifier {
  AudioPlayback._();

  static final AudioPlayback instance = AudioPlayback._();

  /// Test kancası: bildirim/ön plan servisi kurulmasın.
  @visibleForTesting
  static bool notificationsEnabled = true;

  /// Test kancası: ses donanımına ve diske DOKUNMA.
  ///
  /// `flutter_test`te platform kanalı yok (oynatma çağrısı 30 sn askıda
  /// kalıyor) ve sahte saat zonunda gerçek dosya okuması hiç tamamlanmıyor
  /// (bkz. HAFIZA 2026-07-25 §F). Sıra/tekrar/karışık mantığı bu bayrakla
  /// donanımsız sınanıyor — asıl hatanın saklandığı yer orası.
  @visibleForTesting
  static bool engineEnabled = true;

  /// **Oynatıcı GEÇ kuruluyor.** `AudioPlayer()` kurucusu platform kanalına
  /// dokunuyor; testte (kanal yokken) bu bile `MissingPluginException`
  /// fırlatıyordu ve servise dokunan her test düşüyordu. Artık ilk çalma
  /// isteğinde kuruluyor.
  AudioPlayer? _engine;
  final _subs = <StreamSubscription<dynamic>>[];

  AudioPlayer get _player {
    final existing = _engine;
    if (existing != null) return existing;
    final created = AudioPlayer();
    _engine = created;
    _subs.addAll([
      created.onPositionChanged.listen((d) {
        if (_dragging) return;
        position = d;
        notifyListeners();
      }),
      created.onDurationChanged.listen((d) {
        duration = d;
        notifyListeners();
      }),
      created.onPlayerStateChanged.listen((s) {
        playing = s == PlayerState.playing;
        unawaited(_refreshNotification());
        notifyListeners();
      }),
      created.onPlayerComplete.listen((_) => unawaited(onComplete())),
    ]);
    return created;
  }

  List<String> playlist = const [];
  int index = 0;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  double speed = 1.0;
  RepeatMode repeat = RepeatMode.off;
  bool shuffle = false;
  String? error;
  AudioTags tags = AudioTags.empty;

  /// Kullanıcı çubuğu sürüklerken konum güncellemesi ekrana yansımasın.
  bool _dragging = false;

  bool get hasTrack => playlist.isNotEmpty;

  /// Çalan dosyanın yolu; hiç yoksa boş.
  String get current => playlist.isEmpty ? '' : playlist[index];

  /// Ekranda gösterilecek ad: etiketten başlık, yoksa dosya adı.
  String get title => tags.title.isNotEmpty
      ? tags.title
      : (current.isEmpty ? '' : p.basenameWithoutExtension(current));

  void setDragging(bool value) => _dragging = value;

  /// Bir dosyayı (ve varsa listesini) çalmaya başlar.
  Future<void> open(String path, {List<String> list = const []}) async {
    final next = list.isEmpty ? [path] : [...list];
    var at = next.indexOf(path);
    if (at < 0) {
      next.insert(0, path);
      at = 0;
    }
    playlist = next;
    index = at;
    await _play(current);
  }

  /// Android medya sunucusu ölürse (`MEDIA_ERROR_SERVER_DIED`) oynatıcı
  /// nesnesi ARTIK KULLANILAMAZ; yenisini kurmak gerekiyor. Hata kaydı
  /// 2026-09-02: bu olduğunda çalma sessizce ölüyordu.
  Future<void> _recreateEngine() async {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    try {
      await _engine?.dispose();
    } catch (_) {}
    _engine = null;
  }

  Future<void> _play(String path) async {
    error = null;
    position = Duration.zero;
    duration = Duration.zero;
    tags = AudioTags.empty;
    notifyListeners();
    // Etiket okuma çalmayı BEKLETMEZ (yavaş kartta hissedilir): ses hemen
    // başlar, kapak ve sanatçı sonradan yerine oturur.
    if (!engineEnabled) return;
    unawaited(_loadTags(path));
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
      await _player.setPlaybackRate(speed);
    } catch (e) {
      // Medya sunucusu öldüyse oynatıcıyı yenileyip BİR KEZ daha dene.
      if ('$e'.contains('SERVER_DIED')) {
        await _recreateEngine();
        try {
          await _player.play(DeviceFileSource(path));
          await _player.setPlaybackRate(speed);
          return;
        } catch (_) {
          // ikinci deneme de olmadı — aşağıdaki mesaja düş
        }
      }
      error = AppStrings.current.t('mp.audio_failed', {'error': e});
      notifyListeners();
    }
  }

  Future<void> _loadTags(String path) async {
    final read = await AudioTagReader.read(path);
    if (path != current) return; // kullanıcı parçayı değiştirdi
    tags = read;
    unawaited(_refreshNotification());
    notifyListeners();
  }

  /// Parça bitti — tekrar/karışık kipine göre sıradakine geç.
  @visibleForTesting
  Future<void> onComplete() async {
    if (repeat == RepeatMode.one) return _play(current);
    if (shuffle && playlist.length > 1) {
      final rnd = Random(DateTime.now().microsecondsSinceEpoch);
      var next = index;
      while (next == index) {
        next = rnd.nextInt(playlist.length);
      }
      return skipTo(next);
    }
    if (index < playlist.length - 1) return skipTo(index + 1);
    if (repeat == RepeatMode.all) return skipTo(0);
    // Liste bitti: çalma durdu, bildirimi ve servisi bırak.
    await stop();
  }

  Future<void> skipTo(int at) async {
    if (at < 0 || at >= playlist.length) return;
    index = at;
    notifyListeners();
    await _play(current);
  }

  Future<void> next() => skipTo(index + 1);

  Future<void> previous() async {
    // Parçanın başındaysak öncekine geç; değilse başa sar (müzik
    // uygulamalarının alıştırdığı davranış).
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    await skipTo(index - 1);
  }

  Future<void> toggle() async {
    if (!engineEnabled) {
      playing = !playing;
      notifyListeners();
      return;
    }
    if (playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> seek(Duration target) async {
    position = target < Duration.zero ? Duration.zero : target;
    if (!engineEnabled) {
      notifyListeners();
      return;
    }
    await _player.seek(position);
  }

  Future<void> seekBy(int seconds) =>
      seek(position + Duration(seconds: seconds));

  Future<void> setSpeed(double value) async {
    speed = value;
    if (engineEnabled) await _player.setPlaybackRate(value);
    notifyListeners();
  }

  void setRepeat(RepeatMode mode) {
    repeat = mode;
    notifyListeners();
  }

  void setShuffle(bool value) {
    shuffle = value;
    notifyListeners();
  }

  /// Çalmayı bitirir ve bildirimi/servisi bırakır.
  Future<void> stop() async {
    if (engineEnabled && _engine != null) await _player.stop();
    playing = false;
    playlist = const [];
    position = Duration.zero;
    duration = Duration.zero;
    tags = AudioTags.empty;
    await _clearNotification();
    notifyListeners();
  }

  // ── Bildirim ve ön plan servisi ─────────────────────────────────────────

  static const _notificationId = 91001;
  static const _owner = 'audio';
  static const _channelId = 'audio_playback';

  bool _held = false;

  /// Bildirim eylemleri (`NotificationHub.onAction` buraya yönlendiriyor).
  static const actionToggle = 'audio_toggle';
  static const actionNext = 'audio_next';
  static const actionStop = 'audio_stop';

  /// Bildirimdeki düğmeye basıldı.
  Future<void> handleAction(String actionId) async {
    switch (actionId) {
      case actionToggle:
        await toggle();
      case actionNext:
        await next();
      case actionStop:
        await stop();
    }
  }

  Future<void> _refreshNotification() async {
    if (!notificationsEnabled) return;
    if (!hasTrack) return _clearNotification();
    final hub = NotificationHub.instance;
    if (!hub.ready) return;
    final str = AppStrings.current;
    try {
      // **Medya biçimli bildirim** (kullanıcı 2026-09-02: *"premium
      // uygulamalardaki gibi oynat/durdur düğmesi olmalı, örneğin YouTube"*).
      // `MediaStyleInformation` bildirime medya görünümünü veriyor: kapak
      // solda büyük, düğmeler daraltılmış görünümde de duruyor. Eskiden düz
      // bildirimdi ve MIUI daraltılmışken düğmeleri hiç göstermiyordu.
      final cover = await _coverFile();
      final details = AndroidNotificationDetails(
        _channelId,
        str.t('mp.channel_name'),
        channelDescription: str.t('mp.channel_desc'),
        importance: Importance.low,
        priority: Priority.low,
        ongoing: playing,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: false,
        largeIcon: cover == null ? null : FilePathAndroidBitmap(cover),
        // Daraltılmış görünümde İLK İKİ düğme (duraklat, sonraki) görünür.
        styleInformation: const MediaStyleInformation(
          htmlFormatContent: false,
          htmlFormatTitle: false,
        ),
        actions: [
          AndroidNotificationAction(
            actionToggle,
            playing ? str.t('mp.pause') : str.t('mp.play'),
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            actionNext,
            str.t('mp.next'),
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            actionStop,
            str.t('common.close'),
            cancelNotification: false,
          ),
        ],
      );
      final body = tags.subtitle.isEmpty
          ? p.basename(current)
          : tags.subtitle;
      // **Ön plan servisi ancak ÇALARKEN tutulur.** Duraklatılmış bir
      // oynatıcı için süreci ayakta tutmak pil yakar. Servis bildirimi
      // zaten aynı bildirimdir (hub onu kendisi gösteriyor).
      if (playing) {
        _held = true;
        await hub.acquireService(
          _owner,
          FgNotice(
            id: _notificationId,
            title: title,
            body: body,
            details: details,
            payload: 'audio:$current',
          ),
          types: const {
            AndroidServiceForegroundType.foregroundServiceTypeMediaPlayback,
          },
        );
      } else {
        if (_held) {
          _held = false;
          await hub.releaseService(_owner);
        }
        await hub.show(_notificationId, title, body, details,
            payload: 'audio:$current');
      }
    } catch (_) {
      // Bildirim kurulamadı — çalma yine sürüyor, sessizce geçiyoruz.
    }
  }

  /// Kapak resmini bildirimin okuyabileceği bir DOSYAYA yazar.
  ///
  /// Bildirim eklentisi ham bayt kabul etmiyor, dosya yolu istiyor. Tek bir
  /// dosya kullanılıyor ve her parçada üzerine yazılıyor — kapaklar
  /// uygulamanın klasöründe birikmesin.
  Future<String?> _coverFile() async {
    final bytes = tags.cover;
    if (bytes == null || bytes.isEmpty) return null;
    if (FmEnv.appSupportDir.isEmpty) return null;
    try {
      final file = File('${FmEnv.appSupportDir}/audio_cover.jpg');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearNotification() async {
    if (!notificationsEnabled) return;
    try {
      if (_held) {
        _held = false;
        await NotificationHub.instance.releaseService(_owner);
      }
      await NotificationHub.instance.cancel(_notificationId);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_engine?.dispose());
    super.dispose();
  }
}
