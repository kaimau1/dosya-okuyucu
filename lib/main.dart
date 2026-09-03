import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/display_mode.dart';
import 'core/l10n/app_language.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme.dart';
import 'screens/fm/job_navigation.dart';
import 'screens/fm/jobs_screen.dart';
import 'screens/fm/remote/ftp_server_screen.dart';
import 'screens/fm/resize_actions.dart';
import 'screens/fm/pick_file_screen.dart';
import 'screens/home_screen.dart';
import 'services/fm/file_tags.dart';
import 'services/fm/fm_env.dart';
import 'services/fm/job_notifications.dart';
import 'services/fm/job_queue.dart';
import 'services/fm/job_store.dart';
import 'screens/fm/audio_player_screen.dart';
import 'services/fm/audio_playback.dart';
import 'services/fm/media_session.dart';
import 'services/fm/notification_hub.dart';
import 'services/fm/video_playback.dart';
import 'widgets/mini_player_bar.dart';
import 'screens/fm/media_player_screen.dart';
import 'services/fm/remote/ftp_service.dart';
import 'services/fm/open_history.dart';
import 'services/fm/path_side_index.dart';
import 'services/crash_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // **Hata yakalayıcı EN BAŞTA** (2026-08-28): bundan sonraki her satır —
  // seçici kipi dahil — kapsam içinde olsun. Uygulama mağazadan değil GitHub
  // Releases'ten dağıtıldığı için kullanıcının telefonundaki bir çökmeyi
  // öğrenmenin başka yolu yoktu; kayıt cihazda kalır, kullanıcı Ayarlar >
  // Hata kayıtları'ndan görüp isterse paylaşır (bkz. services/crash_log.dart).
  CrashLog.install();
  // Kenardan kenara çizim: içerik sistem çubuklarının altına uzanır,
  // çakışmaları ekranlardaki SafeArea/padding çözer.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // **Seçici kipi** (başka bir uygulama bizden dosya istedi — `PickerActivity`).
  // Ayrı ve KISA bir açılış: iş kuyruğu, bildirim köprüsü, yarım kalan işlerin
  // geri yüklenmesi burada çalıştırılmaz. Çağıran uygulama beklerken saniyeler
  // süren bir açılış yaşatmak bir yana, seçici kipinde arka planda dosya
  // taşıyan bir kuyruğu diriltmek istenmeyen bir yan etki olurdu.
  if (WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
      pickerRoute) {
    final pickerState = AppState();
    await pickerState.init();
    runApp(
      ChangeNotifierProvider<AppState>.value(
        value: pickerState,
        child: const DosyaOkuyucuApp(picker: true),
      ),
    );
    return;
  }
  // Uzun işlerin (yer aç, kopya/benzer arama, boyut düşürme) sistem bildirimi
  // köprüsü. Bildirim izni verilmezse ya da eklenti kurulamazsa sessizce
  // geçilir — işler yine çalışır, yalnız bildirim görünmez.
  final jobNotifications = JobNotifications();
  // Bildirime dokunulunca **ilgili yere** gidilir (istek 2026-07-31).
  // Gezinme kökten yapılır: bildirim uygulamanın hangi ekranında olursa olsun
  // gelebilir ve o anki `context` bilinmiyor.
  final hub = NotificationHub.instance;
  hub.onTap = _openFromNotification;
  // Bildirimdeki düğmeler (müzik duraklat/sonraki/kapat) ekran AÇMADAN iş
  // yapar; dokunmakla aynı kancaya bağlanamaz.
  hub.onAction = (actionId, _) =>
      unawaited(AudioPlayback.instance.handleAction(actionId));
  // **Medya oturumu** (bildirimdeki sürüklenebilir çubuk, kilit ekranı,
  // kulaklık düğmeleri). Eylem, oturumu en son süren çalara gider: tek oturum
  // var ve ses ile video onu paylaşıyor.
  MediaSession.onAction = (action, value) {
    if (MediaSession.owner == 'video') {
      unawaited(VideoPlayback.instance.handleAction(action, value));
    } else {
      unawaited(AudioPlayback.instance.handleAction(action, value));
    }
  };
  MediaSession.onOpen = _openFromNotification;
  MediaSession.install();
  // Uygulama medya bildirimine dokunularak açıldıysa doğrudan o dosyaya git.
  unawaited(MediaSession.takePayload().then((payload) {
    if (payload == null || payload.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openFromNotification(payload));
  }));
  unawaited(hub.init().then((_) {
    // Süreç öldürülüp yeniden açıldıysa "Ağdan erişim açık" diyen bir bildirim
    // asılı kalmış olabilir — paylaşım o bildirimle birlikte ölmüştü.
    unawaited(FtpService.instance.clearStaleNotification());
    // Uygulama bildirime dokunularak AÇILDIYSA yanıt `onTap`tan önce
    // gelmiş olabilir; ilk kareden sonra tüketilir (Navigator o an hazır).
    final pending = hub.takePendingPayload();
    if (pending == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openFromNotification(pending));
  }));
  JobQueue.instance.reporter = jobNotifications;
  // Dosya taşınınca/adı değişince YOL ANAHTARLI yan kayıtlar da taşınmalı:
  // etiketler ve açılma geçmişi dosyayı yolundan tanıyor. Bu kanca bağlı
  // olmazsa kullanıcı bizim uygulamamızla taşıdığı dosyanın etiketini
  // kaybeder (etiket sayfasında ona bunun KORUNACAĞI yazılı).
  // Kanca dosya işlemleri katmanının saf `dart:io` kalması için burada
  // bağlanıyor (bkz. path_side_index.dart).
  PathSideIndex.register((from, to) async {
    await FileTags.movePath(from, to);
    await OpenHistory.movePath(from, to);
  });
  // İş listesi artık diske yazılıyor (kullanıcı hatası 2026-07-31: "uygulamayı
  // alta alıp geri aldığımda diğer tüm işlemler kayboluyor"). Kanca hemen
  // takılır; okuma ilk kareyi BEKLETMEZ (bkz. [_restoreJobs]).
  JobQueue.instance.store = JobStore();
  // Yarıda kalan işlerin nasıl yeniden kurulacağı KAYITLI olmalı — kullanıcı
  // "Devam et" dediğinde tarifin türünü çalıştıracak üretici bulunamazsa
  // düğme yine ölü kalırdı (bkz. JobRecipes).
  registerResizeJobRunner();
  unawaited(_restoreJobs());
  final appState = AppState();
  await appState.init();
  // Tazeleme hızı tercihi AYARLARDAN okunur → `init()` sonrasında uygulanır.
  // (Eskiden koşulsuz "en yüksek" isteniyordu; artık kullanıcı pil için
  // 60 Hz'de kalmayı seçebiliyor — bkz. AppState.highRefreshRate.)
  unawaited(applyRefreshRate(appState.highRefreshRate));
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const DosyaOkuyucuApp(),
    ),
  );
}

/// Önceki oturumun iş listesini geri yükler.
///
/// **Açılışı bloklamaz:** kayıt dosyasının yolu `FmEnv.appSupportDir`e bağlı ve
/// `FmEnv.ensureInit()` depolama birimlerini de tarıyor; bunu ilk karenin
/// önüne koymak uygulamayı yavaş açardı. Liste geç gelse de sorun değil —
/// İşlemler ekranı ve alt şerit kuyruğu dinliyor, geldiğinde kendiliğinden
/// dolar. Bu arada başlatılan yeni işlerin kimliği korunur:
/// [JobQueue.restore] zaten listede olan kimliği atlar.
Future<void> _restoreJobs() async {
  try {
    await FmEnv.ensureInit();
    JobQueue.instance.restore(await JobStore.load());
  } catch (_) {
    // Kalıcılık bir güvence ağı; okunamıyorsa uygulama yine çalışır.
  }
}

/// Uygulamanın kök gezinme anahtarı — `context`i olmayan yerlerden (sistem
/// bildirimi) ekran açmak için tek yol.
final navigatorKey = GlobalKey<NavigatorState>();

/// Bildirimin yükünü ekrana çevirir. Yük ya bir iş kimliği ya da "Ağdan
/// erişim"in sahiplik kimliği ([FtpService.owner]).
///
/// İş kuyrukta yoksa (uygulama yeniden başlamış, kuyruk bellekte) İşlemler
/// ekranı açılır — boş bir dokunuştansa listeye götürmek daha iyi.
void _openFromNotification(String payload) {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  if (payload == FtpService.owner) {
    unawaited(Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FtpServerScreen())));
    return;
  }
  // **Müzik bildirimi ÇALAN PARÇAYA götürür** (kullanıcı 2026-09-02:
  // *"üzerine tıklayınca müzik dosyasına değil işlemler sayfasına gidiyor"*).
  // Yük tanınmayınca akış "iş bildirimi" varsayıp işlemler ekranını açıyordu.
  if (payload.startsWith('audio:')) {
    final path = payload.substring(6);
    if (path.isNotEmpty) {
      unawaited(Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AudioPlayerScreen(
          path: path,
          playlist: AudioPlayback.instance.playlist,
        ),
      )));
    }
    return;
  }
  // Video bildirimi de kendi oynatıcısına götürür (aynı gerekçe).
  if (payload.startsWith('video:')) {
    final path = payload.substring(6);
    if (path.isNotEmpty) {
      unawaited(Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MediaPlayerScreen(
          path: path,
          playlist: VideoPlayback.instance.playlist,
        ),
      )));
    }
    return;
  }
  final job = JobQueue.instance.find(payload);
  if (job == null) {
    unawaited(openJobsScreen(context));
    return;
  }
  unawaited(openJobTarget(context, job));
}

/// `PickerActivity`nin Flutter'a verdiği başlangıç yolu. Tek yerde tanımlı:
/// Kotlin tarafındaki değerle birebir aynı olmalı (bkz. ci/PickerActivity.kt).
const pickerRoute = '/picker';

class DosyaOkuyucuApp extends StatelessWidget {
  /// Seçici kipinde mi açıldı? (Ana ekran yerine dosya seçme ekranı.)
  final bool picker;

  const DosyaOkuyucuApp({super.key, this.picker = false});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp(
      title: 'Dosya Okuyucu',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        bodyFont: appState.uiFont,
        skin: appState.appSkin,
        background: appState.background,
      ),
      darkTheme: AppTheme.dark(
        bodyFont: appState.uiFont,
        skin: appState.appSkin,
        background: appState.background,
      ),
      // "Gece (OLED)" ailesinin açık karşılığı yok: seçiliyken sistem açık
      // modda olsa da koyu kalır, yoksa kullanıcı OLED temayı seçtiği hâlde
      // gündüz beyaz ekran görürdü.
      themeMode:
          appState.appSkin.forcesDark ? ThemeMode.dark : appState.themeMode,
      // **Yazı boyutu her telefonda AYNI** (kullanıcı isteği 2026-08-07):
      // Android'in "Yazı tipi boyutu" ayarı normalde her uygulamayı büyütür;
      // aynı ekran bir telefonda ferah, ötekinde taşmış görünüyordu. Sistem
      // ölçeği burada YOK SAYILIYOR ve yerine uygulamanın kendi ölçeği
      // konuyor — büyütmek isteyen Ayarlar > Görünüm'den büyütür.
      //
      // (Bilinçli ödün: sistemden büyük yazı seçmiş kullanıcı bizim
      // ekranlarımızda bunu görmez; bu yüzden uygulama içi ölçek 1,4'e kadar
      // çıkıyor ve Ayarlar'ın en üstünde duruyor.)
      builder: (context, child) => MediaQuery(
        // `copyWith(textScaler:)` sistemden gelen ölçeğin YERİNE geçer —
        // ayrıca `withNoTextScaling` sarmaya gerek yok.
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(appState.uiTextScale),
        ),
        // **Ekran altı mini oynatma çubuğu**: çalan ses/video hangi ekranda
        // olursak olalım altta görünür (kullanıcı isteği 2026-09-03).
        // Seçici kipinde YOK: başka bir uygulama bizden dosya isterken
        // ekranın altına oynatıcı koymak yersiz olurdu.
        child: picker
            ? (child ?? const SizedBox.shrink())
            : MiniPlayerBar.wrap(child ?? const SizedBox.shrink()),
      ),
      // Dil: seçim `system` ise `locale` null bırakılır — Flutter cihazın
      // dilini `supportedLocales` ile eşleştirir, tutmazsa listenin İLKİNE
      // (Türkçe) düşer. Arapça seçilince `GlobalWidgetsLocalizations`
      // yönü rtl'e çevirdiği için ayrıca `Directionality` sarmaya gerek yok.
      locale: appState.language.locale,
      supportedLocales: AppLanguageInfo.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: picker ? const PickFileScreen() : const HomeScreen(),
    );
  }
}
