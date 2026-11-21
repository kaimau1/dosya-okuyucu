/// **Menü görünümü** (2026-11-15, kullanıcı: menüler baştan tasarlansın; iki
/// görünüm olsun, Ayarlar › Görünüm'den seçilsin, varsayılan sekmeli; 2026-11-21 kullanıcı: varsayılan Bento).
///
/// Ad `MenuStyle` değil: Flutter'ın `MenuStyle` sınıfıyla (MenuAnchor)
/// çakışırdı.
enum MenuLook {
  /// Üstte "Aç" + yanında Paylaş/Sil, altında sekme çipleri ve 4 sütunlu
  /// ızgara.
  tabbed,

  /// Tek boy karolar; seyrek işler başlıklı iki sütunlu karolarda (varsayılan).
  bento;

  /// Kayıtlı addan; tanınmayan/eksik ad varsayılana (Bento) düşer.
  static MenuLook byName(String? name) => switch (name) {
        'tabbed' => MenuLook.tabbed,
        _ => MenuLook.bento,
      };

  /// Ayarlar satırındaki çeviri anahtarı.
  String get labelKey => switch (this) {
        MenuLook.tabbed => 'menu.look_tabbed',
        MenuLook.bento => 'menu.look_bento',
      };
}
