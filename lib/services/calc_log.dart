/// Hesap motorunun değişiklik günlüğü (Faz 26, 2026-10-23).
///
/// Model (`XlsxEditor`) hücre yazdıkça buraya not düşer; ekrandaki kalıcı
/// formül motoru ([CalcState]) her çizimden önce günlüğü boşaltıp YALNIZ
/// değişen hücrelerin bağımlılarını geçersiz kılar. Yapısal işlem (satır/
/// sütun ekle-sil, sayfa ekle/sil/adlandır/taşı, geri alma anlık görüntüsü)
/// konumları topluca kaydırdığından "toplu" sayılır: motor baştan kurulur.
library;

class CalcLog {
  /// Toplu değişiklik sayacı — değiştiyse önbellek tümüyle geçersiz.
  int generation = 0;

  /// Son boşaltmadan beri yazılan hücreler (sayfa adı, satır, sütun).
  final List<(String, int, int)> cells = [];

  /// Bir hücrenin ham metni değişti.
  void cell(String sheet, int r, int c) {
    // Sınırsız büyümesin: çok büyük bir toplu yazım (yapıştırma, sıralama)
    // ayrı ayrı izlemekten pahalıya gelir — baştan kurmak daha ucuz.
    if (cells.length >= 20000) {
      bulk();
      return;
    }
    cells.add((sheet, r, c));
  }

  /// Konumları kaydıran ya da sayfa kümesini değiştiren işlem.
  void bulk() {
    generation++;
    cells.clear();
  }
}
