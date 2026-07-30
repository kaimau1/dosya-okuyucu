/// Medya dosyaları (video / ses / görsel) neyle açılsın?
///
/// Kullanıcı isteği (2026-07-25): "kişi videoları veya fotoğrafları kendi
/// media player'ından oynatmak isteyebilir; hem ayarlarda hem ilk kez
/// oynatılacağı zaman soralım."
library;

enum MediaOpenWith {
  /// Henüz seçilmedi → ilk açılışta sorulur.
  ask,

  /// Uygulamanın kendi oynatıcısı/galerisi.
  inApp,

  /// Sistemin varsayılan uygulaması (kullanıcının medya oynatıcısı).
  external,
}

extension MediaOpenWithLabel on MediaOpenWith {
  /// Çeviri anahtarı (bkz. `FmLayoutInfo.labelKey`).
  String get labelKey => switch (this) {
        MediaOpenWith.ask => 'enum.open_with_ask',
        MediaOpenWith.inApp => 'enum.open_with_in_app',
        MediaOpenWith.external => 'enum.open_with_external',
      };

  String get descriptionKey => switch (this) {
        MediaOpenWith.ask => 'enum.open_with_ask_desc',
        MediaOpenWith.inApp => 'enum.open_with_in_app_desc',
        MediaOpenWith.external => 'enum.open_with_external_desc',
      };

  String get label => switch (this) {
        MediaOpenWith.ask => 'Her seferinde sor',
        MediaOpenWith.inApp => 'Uygulama içi oynatıcı',
        MediaOpenWith.external => 'Başka uygulama',
      };

  String get description => switch (this) {
        MediaOpenWith.ask =>
          'Video/ses/görsel açarken hangisini kullanacağın sorulur',
        MediaOpenWith.inApp => 'Dosyalar bu uygulamanın oynatıcısında açılır',
        MediaOpenWith.external =>
          'Telefonundaki varsayılan oynatıcı/galeri açılır',
      };

  static MediaOpenWith byName(String? name) {
    for (final v in MediaOpenWith.values) {
      if (v.name == name) return v;
    }
    return MediaOpenWith.ask;
  }
}
