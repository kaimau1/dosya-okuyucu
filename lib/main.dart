import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/l10n/app_language.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme.dart';
import 'screens/fm/job_navigation.dart';
import 'screens/fm/jobs_screen.dart';
import 'screens/fm/resize_actions.dart';
import 'screens/home_screen.dart';
import 'services/fm/file_tags.dart';
import 'services/fm/fm_env.dart';
import 'services/fm/job_notifications.dart';
import 'services/fm/job_queue.dart';
import 'services/fm/job_store.dart';
import 'services/fm/open_history.dart';
import 'services/fm/path_side_index.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Kenardan kenara çizim: içerik sistem çubuklarının altına uzanır,
  // çakışmaları ekranlardaki SafeArea/padding çözer.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await _enableHighRefreshRate();
  // Uzun işlerin (yer aç, kopya/benzer arama, boyut düşürme) sistem bildirimi
  // köprüsü. Bildirim izni verilmezse ya da eklenti kurulamazsa sessizce
  // geçilir — işler yine çalışır, yalnız bildirim görünmez.
  final jobNotifications = JobNotifications();
  // Bildirime dokunulunca işin **ilgili yerine** gidilir (istek 2026-07-31).
  // Gezinme kökten yapılır: bildirim uygulamanın hangi ekranında olursa olsun
  // gelebilir ve o anki `context` bilinmiyor.
  jobNotifications.onTap = (jobId) => _openJobFromNotification(jobId);
  unawaited(jobNotifications.init().then((_) {
    // Uygulama bildirime dokunularak AÇILDIYSA yanıt `onTap`tan önce
    // gelmiş olabilir; ilk kareden sonra tüketilir (Navigator o an hazır).
    final pending = jobNotifications.takePendingJobId();
    if (pending == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openJobFromNotification(pending));
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

/// Bildirimden gelen iş kimliğini ekrana çevirir. İş kuyrukta yoksa (uygulama
/// yeniden başlamış, kuyruk bellekte) İşlemler ekranı açılır — boş bir
/// dokunuştansa listeye götürmek daha iyi.
void _openJobFromNotification(String jobId) {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  final job = JobQueue.instance.find(jobId);
  if (job == null) {
    unawaited(openJobsScreen(context));
    return;
  }
  unawaited(openJobTarget(context, job));
}

/// 120Hz+ ekranlarda Android'in 60Hz kilidini açar.
/// Desteklenmeyen cihaz/ROM'da sessizce geçilir — akış asla bloklanmaz.
Future<void> _enableHighRefreshRate() async {
  if (!Platform.isAndroid) return;
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {
    // eski cihaz veya izin vermeyen ROM; varsayılan tazelemeyle devam
  }
}

class DosyaOkuyucuApp extends StatelessWidget {
  const DosyaOkuyucuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp(
      title: 'Dosya Okuyucu',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(bodyFont: appState.uiFont),
      darkTheme: AppTheme.dark(bodyFont: appState.uiFont),
      themeMode: appState.themeMode,
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
        child: child ?? const SizedBox.shrink(),
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
      home: const HomeScreen(),
    );
  }
}
