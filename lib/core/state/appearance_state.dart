import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../skin.dart';
import '../theme.dart';

/// Kök `MaterialApp`in izlediği **tek** durum: tema, dil, yazı tipi, ölçek
/// (Faz 3, 2026-10-21 — FAZ_PLANI P3).
///
/// Eskiden kök `context.watch<AppState>()` ile kuruluyordu; her dosya açılışı
/// (`addRecent`), pano değişimi, uzak bağlantı kaydı iki `ThemeData`yı baştan
/// üretip tüm ağacı yeniden kuruyordu. Değerlerin sahibi ve kalıcılığı yine
/// `AppState` (prefs anahtarları değişmedi); bu sınıf yalnız onların
/// görünüme dair kopyasını taşır ve **yalnız gerçekten değişince** bildirir.
class AppearanceState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppSkin _skin = AppSkin.paper;
  String _background = 'default';
  AppLanguage _language = AppLanguage.system;
  String _uiFont = AppTheme.uiFontDefault;
  double _uiTextScale = 1.0;

  ThemeMode get themeMode => _themeMode;
  AppSkin get skin => _skin;
  String get background => _background;
  AppLanguage get language => _language;
  String get uiFont => _uiFont;
  double get uiTextScale => _uiTextScale;

  /// `AppState` her görünüm ayarı değişiminde çağırır. Hiçbir değer
  /// değişmediyse dinleyiciler uyandırılmaz.
  void apply({
    required ThemeMode themeMode,
    required AppSkin skin,
    required String background,
    required AppLanguage language,
    required String uiFont,
    required double uiTextScale,
  }) {
    if (themeMode == _themeMode &&
        skin == _skin &&
        background == _background &&
        language == _language &&
        uiFont == _uiFont &&
        uiTextScale == _uiTextScale) {
      return;
    }
    _themeMode = themeMode;
    _skin = skin;
    _background = background;
    _language = language;
    _uiFont = uiFont;
    _uiTextScale = uiTextScale;
    notifyListeners();
  }
}

/// Son açılan belgeler listesinin değişim bildiricisi (Faz 3).
///
/// Her dosya açılışında liste güncelleniyor; bunun `AppState`i (ve onu
/// izleyen 60+ yeri) uyandırması gereksizdi. Listeyi gösteren bir ekran
/// bunu izler; `AppState.recents` okumaları aynen sürer.
class RecentsState extends ChangeNotifier {
  void changed() => notifyListeners();
}
