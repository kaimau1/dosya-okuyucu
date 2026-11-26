import 'package:flutter/widgets.dart';

/// Uygulama dili. `system` = cihazın dili (desteklemediğimiz bir dilse
/// Türkçe'ye düşer, bkz. [AppLanguageInfo.resolve]).
///
/// Diller **kendi dillerinde** listelenir ([nativeLabel]): İngilizce bilmeyen
/// bir kullanıcı "Arabic" yazısını okuyamaz ama "العربية"yi tanır.
///
/// `id` Endonezce, `ms` Malayca (B17, 2026-11-27): çevirisi eksik anahtar
/// İngilizceye düşer (bkz. `AppStrings.t`). İkisi de soldan sağa; Malezya
/// arayüzü Latin (Rumi) yazıyla — Cavi (Jawi) yalnız içerikte (B16 Arapça OCR).
enum AppLanguage { system, tr, en, ar, id, ms }

extension AppLanguageInfo on AppLanguage {
  /// Kalıcı kayıtta ve `Locale` üretiminde kullanılan kod.
  String get code => switch (this) {
        AppLanguage.system => 'system',
        AppLanguage.tr => 'tr',
        AppLanguage.en => 'en',
        AppLanguage.ar => 'ar',
        AppLanguage.id => 'id',
        AppLanguage.ms => 'ms',
      };

  /// Dilin kendi adı (seçim listesinde bu yazılır).
  String get nativeLabel => switch (this) {
        AppLanguage.system => 'Sistem',
        AppLanguage.tr => 'Türkçe',
        AppLanguage.en => 'English',
        AppLanguage.ar => 'العربية',
        AppLanguage.id => 'Bahasa Indonesia',
        AppLanguage.ms => 'Bahasa Melayu',
      };

  /// `MaterialApp.locale` değeri; `system` için null (Flutter cihaz dilini
  /// kendi seçer, desteklemediğimizde `supportedLocales`in ilkine düşer).
  Locale? get locale => this == AppLanguage.system ? null : Locale(code);

  /// Yazı yönü — Arapça sağdan sola.
  TextDirection get direction =>
      this == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr;

  /// Konuşma tanıma / dikte için yerel ayar (Android `RecognizerIntent`).
  String get speechLocale => switch (this) {
        AppLanguage.en => 'en-US',
        AppLanguage.ar => 'ar',
        AppLanguage.id => 'id-ID',
        AppLanguage.ms => 'ms-MY',
        _ => 'tr-TR',
      };

  static AppLanguage byCode(String? code) => switch (code) {
        'tr' => AppLanguage.tr,
        'en' => AppLanguage.en,
        'ar' => AppLanguage.ar,
        // Eski Android'in Endonezce kodu "in"i Dart `Locale` zaten "id"ye çevirir.
        'id' => AppLanguage.id,
        'ms' => AppLanguage.ms,
        _ => AppLanguage.system,
      };

  /// `system` seçiliyken cihaz dilinden gerçek dili çözer.
  /// Desteklenmeyen dil → Türkçe (uygulamanın ana dili).
  static AppLanguage resolve(AppLanguage selected, Locale deviceLocale) {
    if (selected != AppLanguage.system) return selected;
    final lang = byCode(deviceLocale.languageCode);
    return lang == AppLanguage.system ? AppLanguage.tr : lang;
  }

  /// Uygulamanın desteklediği diller (system hariç) — `supportedLocales`.
  static const List<Locale> supportedLocales = [
    Locale('tr'),
    Locale('en'),
    Locale('ar'),
    Locale('id'),
    Locale('ms'),
  ];
}
