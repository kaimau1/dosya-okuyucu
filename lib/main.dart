import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Kenardan kenara çizim: içerik sistem çubuklarının altına uzanır,
  // çakışmaları ekranlardaki SafeArea/padding çözer.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await _enableHighRefreshRate();
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
      home: const HomeScreen(),
    );
  }
}
