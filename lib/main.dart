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
import 'screens/home_screen.dart';
import 'services/fm/file_tags.dart';
import 'services/fm/job_notifications.dart';
import 'services/fm/job_queue.dart';
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
  unawaited(jobNotifications.init());
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
  final appState = AppState();
  await appState.init();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const DosyaOkuyucuApp(),
    ),
  );
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appState.themeMode,
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
