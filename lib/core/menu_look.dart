/// **Menü görünümü** (2026-11-15, kullanıcı: menüler baştan tasarlansın; iki
/// görünüm olsun, Ayarlar › Görünüm'den seçilsin, varsayılan sekmeli).
///
/// Ad `MenuStyle` değil: Flutter'ın `MenuStyle` sınıfıyla (MenuAnchor)
/// çakışırdı.
enum MenuLook {
  /// Üstte "Aç" + yanında Paylaş/Sil, altında sekme çipleri ve 4 sütunlu
  /// ızgara (varsayılan).
  tabbed,

  /// Tek boy karolar; seyrek işler başlıklı iki sütunlu karolarda.
  bento;

  /// Kayıtlı addan; tanınmayan/eksik ad varsayılana (sekmeli) düşer.
  static MenuLook byName(String? name) => switch (name) {
        'bento' => MenuLook.bento,
        _ => MenuLook.tabbed,
      };

  /// Ayarlar satırındaki çeviri anahtarı.
  String get labelKey => switch (this) {
        MenuLook.tabbed => 'menu.look_tabbed',
        MenuLook.bento => 'menu.look_bento',
      };
}
