import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

import 'app_language.dart';

part 'strings/1_fm_settings.dart';
part 'strings/2_vw_fm.dart';
part 'strings/3_excel_drive.dart';
part 'strings/4_fmset_excel.dart';
part 'strings/5_ph_rs.dart';
part 'strings/6_sdu_cj.dart';
part 'strings/7_set_vault.dart';
part 'strings/8_enum_aih.dart';
part 'strings/9_perf_err.dart';
part 'strings/10_list_office.dart';
part 'strings/11_media.dart';
part 'strings/12_ux.dart';
part 'strings/13_smart.dart';

/// Uygulama metinleri — Türkçe / İngilizce / Arapça.
///
/// **Neden kod tablosu, neden `.arb` + `gen_l10n` değil:** üretilen kod CI'da
/// ek bir adım (`flutter gen-l10n`) ister ve çıktısı depoya girmezse derleme
/// kırılır. Burada tablo düz Dart; `flutter analyze`/`test` dışında araç yok.
///
/// **Kayıp çeviri İMKÂNSIZ:** her anahtarın karşılığı üç alanlı bir kayıt
/// (`tr`, `en`, `ar`). Bir dili unutmak yazım hatası değil, **derleme hatası**
/// olur — üç ayrı `Map` tutulsaydı eksik anahtar ancak çalışma anında
/// (kullanıcının ekranında) fark edilirdi.
///
/// Değişken yerleştirme: metinde `{ad}`, çağrıda `{'ad': değer}`.
class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  /// En yakın [Localizations]tan okur. Yoksa (test kısayolları, `Localizations`
  /// kurulmadan çizilen ekranlar) Türkçe'ye düşer — metinsiz ekran çizmektense
  /// uygulamanın ana dilini göstermek doğru.
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(AppLanguage.tr);

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// **Bağlamsız** yerler için son yüklenen dil (bildirimler, arka plandaki
  /// iş kuyruğu, `dart:io` katmanı). Delegate her `load`ta günceller.
  ///
  /// Arayüzde bunu KULLANMA: `context.t(...)` ekranın kendi `Localizations`ına
  /// bakar ve önizleme/test içinde ayrı bir dil kurulabilir; bu statik ise
  /// uygulama genelinde tektir.
  static AppStrings current = const AppStrings(AppLanguage.tr);

  /// Anahtarın bu dildeki karşılığı. Anahtar tabloda yoksa anahtarın kendisi
  /// döner (ekranda gözle görülür bir iz bırakır; sessizce boş kalmaz).
  String t(String key, [Map<String, Object?>? vars]) {
    final entry = _table[key];
    if (entry == null) {
      assert(false, 'çevrilmemiş anahtar: $key');
      return key;
    }
    var text = switch (language) {
      AppLanguage.en => entry.$2,
      AppLanguage.ar => entry.$3,
      _ => entry.$1,
    };
    if (vars != null) {
      vars.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    }
    return text;
  }

  /// Bir anahtarın **üç dildeki** karşılığı.
  ///
  /// Ayar araması için var (2026-08-29): arayüz Türkçe'yken "thumbnail" yazan
  /// kullanıcı da ayarı bulabilsin. Anahtar yoksa boş liste — çağıran arama
  /// yaparken bunu sessizce atlar (arama kırılmamalı).
  static List<String> variants(String key) {
    final entry = _table[key];
    if (entry == null) return const [];
    return [entry.$1, entry.$2, entry.$3];
  }

  /// Tablodaki tüm anahtarlar (test ve denetim için).
  static Iterable<String> get keys => _table.keys;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const {'tr', 'en', 'ar'}.contains(locale.languageCode);

  /// **`SynchronousFuture` şart:** tablo koddadır, yüklenecek bir şey yok.
  /// `async` bir gövde `Localizations`ı bir kare bekletir ve o karede ekran
  /// BOŞ çizilir — dil değiştirmede gözle görülür bir çakma olurdu.
  @override
  Future<AppStrings> load(Locale locale) {
    final strings = AppStrings(AppLanguageInfo.byCode(locale.languageCode));
    AppStrings.current = strings;
    return SynchronousFuture(strings);
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

/// Kısayol: `context.t('common.save')`.
extension AppStringsX on BuildContext {
  String t(String key, [Map<String, Object?>? vars]) =>
      AppStrings.of(this).t(key, vars);

  /// Seçili dil (ekranın kendi yönünü ayarlaması gerekenler için).
  AppLanguage get language => AppStrings.of(this).language;
}

/// Anahtar → (Türkçe, English, العربية).
const Map<String, (String, String, String)> _table = {
  ..._t1,
  ..._t2,
  ..._t3,
  ..._t4,
  ..._t5,
  ..._t6,
  ..._t7,
  ..._t8,
  ..._t9,
  ..._t10,
  ..._t11,
  ..._t12,
  ..._t13,
};
