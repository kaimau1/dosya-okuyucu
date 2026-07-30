/// Dosya listelerinin **yerleşim düzeni**.
///
/// Bilinçli olarak saf Dart (Flutter importu yok) — sütun sayısı, ikon boyu ve
/// en-boy oranı hesapları birim testiyle sabitlenebilsin diye.
///
/// *Niye eski `fmGrid` (bool) yetmedi:* kullanıcı "3 sütun, 2 sütun, 4 sütun,
/// tek sıra gibi çok daha geniş seçenekler olmalı" dedi. İki durumlu bir
/// anahtar bunu ifade edemiyordu; sütun sayısı artık düzenin bir parçası.
library;

enum FmLayout {
  /// Tek sıra, ad + boyut/tarih (klasik dosya yöneticisi listesi).
  list,

  /// Tek sıra ama daha yüksek satır: büyük önizleme + ad + ayrıntı satırı.
  detail,

  /// 2 sütun ızgara (en büyük kareler).
  grid2,

  /// 3 sütun ızgara — varsayılan.
  grid3,

  /// 4 sütun ızgara.
  grid4,

  /// 5 sütun ızgara (en yoğun).
  grid5,
}

extension FmLayoutInfo on FmLayout {
  /// Izgara sütun sayısı; liste düzenlerinde 1.
  int get columns => switch (this) {
        FmLayout.list || FmLayout.detail => 1,
        FmLayout.grid2 => 2,
        FmLayout.grid3 => 3,
        FmLayout.grid4 => 4,
        FmLayout.grid5 => 5,
      };

  bool get isGrid => columns > 1;

  /// Çeviri anahtarı — arayüzde bunun karşılığı gösterilir
  /// (`context.t(layout.labelKey)`). [label] Türkçe kalır: saf Dart olan bu
  /// dosya `AppStrings`'i tanımaz ve etiket testlerde/günlüklerde kullanılır.
  String get labelKey => switch (this) {
        FmLayout.list => 'enum.layout_list',
        FmLayout.detail => 'enum.layout_detail',
        FmLayout.grid2 => 'enum.layout_grid2',
        FmLayout.grid3 => 'enum.layout_grid3',
        FmLayout.grid4 => 'enum.layout_grid4',
        FmLayout.grid5 => 'enum.layout_grid5',
      };

  String get descriptionKey => switch (this) {
        FmLayout.list => 'enum.layout_list_desc',
        FmLayout.detail => 'enum.layout_detail_desc',
        FmLayout.grid2 => 'enum.layout_grid2_desc',
        FmLayout.grid3 => 'enum.layout_grid3_desc',
        FmLayout.grid4 => 'enum.layout_grid4_desc',
        FmLayout.grid5 => 'enum.layout_grid5_desc',
      };

  String get label => switch (this) {
        FmLayout.list => 'Liste',
        FmLayout.detail => 'Büyük liste',
        FmLayout.grid2 => '2 sütun',
        FmLayout.grid3 => '3 sütun',
        FmLayout.grid4 => '4 sütun',
        FmLayout.grid5 => '5 sütun',
      };

  String get description => switch (this) {
        FmLayout.list => 'Tek sıra · ad, boyut ve tarih',
        FmLayout.detail => 'Tek sıra · büyük önizleme',
        FmLayout.grid2 => 'En büyük kareler',
        FmLayout.grid3 => 'Dengeli — varsayılan',
        FmLayout.grid4 => 'Daha çok dosya sığar',
        FmLayout.grid5 => 'En yoğun görünüm',
      };

  /// Izgara hücresindeki ikon/önizleme boyu (dp).
  ///
  /// Kullanıcı isteği: "yine 3 sütun olsun ama simgeler daha büyük olsun".
  /// Bu yüzden hücre genişliğinin neredeyse tamamı ikona ayrılır; ad iki
  /// satırda altına yazılır.
  double iconSizeFor(double cellWidth) {
    if (!isGrid) return this == FmLayout.detail ? 56 : 44;
    // Hücre kenarındaki iç boşluk (2×4) düşülür; kalanın tamamı ikondur.
    final usable = cellWidth - 8;
    return usable.clamp(48.0, 160.0);
  }

  /// Izgara hücresinin en-boy oranı: ikon karesi + ad şeridi (~34 dp).
  ///
  /// Hücre bu orana göre YÜKSEKLİK alır; ikonun kendisi hücrenin gerçek
  /// yüksekliğinden ölçülür (bkz. `FmEntryGridTile`) — böylece büyük yazı
  /// tipi ölçeğinde taşma yerine ikon küçülür.
  double aspectFor(double cellWidth) {
    if (!isGrid) return 1;
    final icon = iconSizeFor(cellWidth);
    return cellWidth / (icon + 34);
  }

  static FmLayout byName(String? name, {FmLayout fallback = FmLayout.list}) {
    for (final l in FmLayout.values) {
      if (l.name == name) return l;
    }
    return fallback;
  }
}
