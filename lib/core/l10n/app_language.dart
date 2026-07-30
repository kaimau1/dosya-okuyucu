import 'package:flutter/widgets.dart';

/// Uygulama dili. `system` = cihazın dili (desteklemediğimiz bir dilse
/// Türkçe'ye düşer, bkz. [AppLanguageInfo.resolve]).
///
/// Diller **kendi dillerinde** listelenir ([nativeLabel]): İngilizce bilmeyen
/// bir kullanıcı "Arabic" yazısını okuyamaz ama "العربية"yi tanır.
enum AppLanguage { system, tr, en, ar }

extension AppLanguageInfo on AppLanguage {
  /// Kalıcı kayıtta ve `Locale` üretiminde kullanılan kod.
  String get code => switch (this) {
        AppLanguage.system => 'system',
        AppLanguage.tr => 'tr',
        AppLanguage.en => 'en',
        AppLanguage.ar => 'ar',
      };

  /// Dilin kendi adı (seçim listesinde bu yazılır).
  String get nativeLabel => switch (this) {
        AppLanguage.system => 'Sistem',
        AppLanguage.tr => 'Türkçe',
        AppLanguage.en => 'English',
        AppLanguage.ar => 'العربية',
      };

  /// `MaterialApp.locale` değeri; `system` için null (Flutter cihaz dilini
  /// kendi seçer, desteklemediğimizde `supportedLocales`in ilkine düşer).
  Locale? get locale => this == AppLanguage.system ? null : Locale(code);

  /// Yazı yönü — Arapça sağdan sola.
  TextDirection get direction =>
      this == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr;

  static AppLanguage byCode(String? code) => switch (code) {
        'tr' => AppLanguage.tr,
        'en' => AppLanguage.en,
        'ar' => AppLanguage.ar,
        _ => AppLanguage.system,
      };

  /// `system` seçiliyken cihaz dilinden gerçek dili çözer.
  /// Desteklenmeyen dil → Türkçe (uygulamanın ana dili).
  static AppLanguage resolve(AppLanguage selected, Locale deviceLocale) {
    if (selected != AppLanguage.system) return selected;
    return switch (deviceLocale.languageCode) {
      'en' => AppLanguage.en,
      'ar' => AppLanguage.ar,
      _ => AppLanguage.tr,
    };
  }

  /// Uygulamanın desteklediği diller (system hariç) — `supportedLocales`.
  static const List<Locale> supportedLocales = [
    Locale('tr'),
    Locale('en'),
    Locale('ar'),
  ];
}
