/// Fotoğraf zaman ekseninin **satır planı**: hangi satır başlık, hangi satır
/// ızgara, her satır kaydırma ekseninde nerede başlıyor.
///
/// Saf Dart (Flutter importu yok) — ofset hesabı birim testiyle sabitlenir.
///
/// ## Niye ayrı bir plan (2026-09-26 galeri turu)
/// Ekran artık TEK bir `SliverVariedExtentList` ile çiziliyor: her satırın
/// yüksekliği önceden bilindiği için liste bir ofsete **doğrudan** atlayabilir
/// (hızlı kaydırma tutamacı 5000 fotoğrafın ortasına tek karede iner; bilinmeyen
/// yükseklikli `SliverList` aradaki her satırı kurarak yürümek zorundaydı).
/// Aynı plan üç işe daha yarıyor:
/// * kaydırma tutamacının balonu ("Eylül 2025") — ofsetten satıra, satırdan
///   gruba;
/// * yıl işaretleri — her yılın ilk satırının ofseti;
/// * iki parmakla yakınlaştırmada **parmağın altındaki fotoğrafı yerinde
///   tutmak** — ofsetten düz indekse, sütun sayısı değişince indeksten yeni
///   ofsete.
///
/// ## Küçük grupların paylaştığı satırlar ([packSmall])
/// Kullanıcının Videolar ekran görüntüsünde her gün 1-2 video vardı: her gün
/// kendi başlığı + yarı boş bir satır demekti, ekranın yarısı beyazdı. Google
/// Foto'daki gibi bir satırı dolduramayan ardışık gruplar AYNI satırı
/// paylaşır; her birinin kısa etiketi kendi hücrelerinin üstünde durur
/// ("Bugün | Dün | 23 Eyl"). Satırı dolduran grup eskisi gibi tam genişlik
/// başlık alır. Düz indeksler yine ardışık: paylaşılan satırdaki gruplar
/// sıradaki gruplardır, arada boşluk yok (sürükleyerek seçim kopmaz).
library;

/// Başlık satırındaki bir grubun etiketi: hangi sütunda başlıyor, kaç sütun
/// kaplıyor. Tam genişlik başlıkta tek parça vardır (`column` 0, `span` =
/// sütun sayısı).
class PhotoHeaderSegment {
  final int section;
  final int column;
  final int span;
  const PhotoHeaderSegment(this.section, this.column, this.span);

  @override
  bool operator ==(Object other) =>
      other is PhotoHeaderSegment &&
      other.section == section &&
      other.column == column &&
      other.span == span;

  @override
  int get hashCode => Object.hash(section, column, span);

  @override
  String toString() => 'Seg($section@$column×$span)';
}

class PhotoGridPlan {
  /// Sütun sayısı.
  final int columns;

  /// Başlık satırının yüksekliği.
  final double headerExtent;

  /// Izgara satırının yüksekliği (hücre + alt boşluk).
  final double rowExtent;

  /// Her grubun düz listedeki ilk indeksi ve eleman sayısı.
  final List<int> sectionStarts;
  final List<int> sectionSizes;

  /// Başlık satırlarında grup etiketleri; ızgara satırlarında null.
  final List<List<PhotoHeaderSegment>?> rowSegments;

  /// Izgara satırının ilk düz indeksi ve hücre sayısı (başlıkta -1 / 0).
  final List<int> rowFlatStart;
  final List<int> rowCellCount;

  /// Satırın liste başından ofseti (artan).
  final List<double> rowOffset;

  /// Her grubun başlığının bulunduğu satır.
  final List<int> sectionHeaderRow;

  /// Izgara satırlarının numaraları (düz indeksle ikili arama için, artan).
  final List<int> _gridRows;

  /// Listenin toplam yüksekliği.
  final double extent;

  PhotoGridPlan._(
    this.columns,
    this.headerExtent,
    this.rowExtent,
    this.sectionStarts,
    this.sectionSizes,
    this.rowSegments,
    this.rowFlatStart,
    this.rowCellCount,
    this.rowOffset,
    this.sectionHeaderRow,
    this._gridRows,
    this.extent,
  );

  /// [sectionSizes] gruplardaki eleman sayıları (sırayla). Gruplar düz
  /// listede ardışıktır: ilk grubun indeksi 0'dan başlar.
  factory PhotoGridPlan.build({
    required List<int> sectionSizes,
    required int columns,
    required double headerExtent,
    required double rowExtent,
    bool packSmall = false,
  }) {
    assert(columns > 0);
    final starts = <int>[];
    final segments = <List<PhotoHeaderSegment>?>[];
    final flatStart = <int>[];
    final cellCount = <int>[];
    final offsets = <double>[];
    final headerRow = List<int>.filled(sectionSizes.length, 0);
    final gridRows = <int>[];
    var offset = 0.0;

    void header(List<PhotoHeaderSegment> segs) {
      for (final seg in segs) {
        headerRow[seg.section] = offsets.length;
      }
      segments.add(List.unmodifiable(segs));
      flatStart.add(-1);
      cellCount.add(0);
      offsets.add(offset);
      offset += headerExtent;
    }

    void grid(int first, int count) {
      gridRows.add(offsets.length);
      segments.add(null);
      flatStart.add(first);
      cellCount.add(count);
      offsets.add(offset);
      offset += rowExtent;
    }

    // Paylaşılan satırda bekleyen gruplar.
    var packed = <PhotoHeaderSegment>[];
    var packedUsed = 0;
    var packedFirst = 0;
    void flush() {
      if (packed.isEmpty) return;
      header(packed);
      grid(packedFirst, packedUsed);
      packed = <PhotoHeaderSegment>[];
      packedUsed = 0;
    }

    var start = 0;
    for (var s = 0; s < sectionSizes.length; s++) {
      starts.add(start);
      final n = sectionSizes[s];
      if (packSmall && n > 0 && n < columns) {
        if (packedUsed + n > columns) flush();
        if (packed.isEmpty) packedFirst = start;
        packed.add(PhotoHeaderSegment(s, packedUsed, n));
        packedUsed += n;
      } else {
        flush();
        header([PhotoHeaderSegment(s, 0, columns)]);
        for (var i = 0; i < n; i += columns) {
          grid(start + i, n - i < columns ? n - i : columns);
        }
      }
      start += n;
    }
    flush();

    return PhotoGridPlan._(
      columns,
      headerExtent,
      rowExtent,
      List.unmodifiable(starts),
      List.unmodifiable(sectionSizes),
      List.unmodifiable(segments),
      List.unmodifiable(flatStart),
      List.unmodifiable(cellCount),
      List.unmodifiable(offsets),
      List.unmodifiable(headerRow),
      List.unmodifiable(gridRows),
      offset,
    );
  }

  int get rowCount => rowOffset.length;

  bool isHeader(int row) => rowSegments[row] != null;

  double extentOf(int row) => isHeader(row) ? headerExtent : rowExtent;

  /// [offset]'i (liste başından) kapsayan satır. Sınır dışı değerler ilk/son
  /// satıra kırpılır; plan boşsa -1.
  int rowAt(double offset) {
    if (rowOffset.isEmpty) return -1;
    if (offset <= 0) return 0;
    var lo = 0;
    var hi = rowOffset.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (rowOffset[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Düz [index]'in ait olduğu grup (dizin dışındaysa -1).
  int sectionOfIndex(int index) {
    if (index < 0 || sectionStarts.isEmpty) return -1;
    var lo = 0;
    var hi = sectionStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (sectionStarts[mid] <= index) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return index < sectionStarts[lo] + sectionSizes[lo] ? lo : -1;
  }

  /// [offset]'teki grup (plan boşsa -1). Başlık satırında ilk etiketin grubu,
  /// ızgara satırında ilk hücrenin grubu.
  int sectionAt(double offset) {
    final row = rowAt(offset);
    if (row < 0) return -1;
    final segs = rowSegments[row];
    if (segs != null) return segs.first.section;
    return sectionOfIndex(rowFlatStart[row]);
  }

  /// Düz [index]'i içeren ızgara satırı (yoksa -1).
  int gridRowOfIndex(int index) {
    if (index < 0 || _gridRows.isEmpty) return -1;
    var lo = 0;
    var hi = _gridRows.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (rowFlatStart[_gridRows[mid]] <= index) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final row = _gridRows[lo];
    final first = rowFlatStart[row];
    return index >= first && index < first + rowCellCount[row] ? row : -1;
  }

  /// Düz [index]'i içeren ızgara satırının ofseti. Dizin dışındaysa null.
  double? offsetOfIndex(int index) {
    final row = gridRowOfIndex(index);
    return row < 0 ? null : rowOffset[row];
  }

  /// [offset] ve yatay konumda ([x], genişlik [width]) duran elemanın düz
  /// indeksi. Başlığa denk gelirse altındaki ızgara satırı alınır; satırın
  /// boş hücresine denk gelirse satırın son elemanı.
  int? indexAt(double offset, double x, double width) {
    if (rowOffset.isEmpty) return null;
    var row = rowAt(offset);
    if (isHeader(row)) {
      if (row + 1 >= rowCount || isHeader(row + 1)) return null;
      row++;
    }
    final count = rowCellCount[row];
    if (count <= 0) return null;
    final col = width <= 0
        ? 0
        : (x / (width / columns)).floor().clamp(0, columns - 1);
    return rowFlatStart[row] + (col < count ? col : count - 1);
  }

  /// Grubun başlık satırının ofseti.
  double sectionOffset(int section) => rowOffset[sectionHeaderRow[section]];
}

/// Zaman ekseninin **yakınlaştırma basamakları** (Google Foto'daki iki parmak
/// jesti): yaklaştıkça hücre büyür, uzaklaştıkça küçülür ve gruplama
/// kabalaşır (gün → ay → yıl). Sütun sayısı ve gruplama BİRLİKTE değişir —
/// 5 sütunda her güne ayrı başlık, başlıktan çok fotoğraf göstermeyi
/// engelliyordu.
class PhotoZoomStep {
  final int columns;

  /// `PhotoGroup` adıyla (saf Dart, enum bağımlılığı olmasın diye ad).
  final String group;

  const PhotoZoomStep(this.columns, this.group);
}

const photoZoomLadder = <PhotoZoomStep>[
  PhotoZoomStep(2, 'day'),
  PhotoZoomStep(3, 'day'),
  PhotoZoomStep(4, 'day'),
  PhotoZoomStep(5, 'month'),
  PhotoZoomStep(5, 'year'),
];

/// Şu anki (sütun, gruplama) durumuna en yakın basamak. Kullanıcı ayarlardan
/// merdivende olmayan bir bileşim seçmiş olabilir (ör. 2 sütun · yıl): önce
/// sütun sayısı, eşitlikte gruplama eşleşmesi aranır.
int nearestPhotoZoomStep(int columns, String group) {
  var best = 0;
  var bestScore = 1 << 30;
  for (var i = 0; i < photoZoomLadder.length; i++) {
    final step = photoZoomLadder[i];
    final score = (step.columns - columns).abs() * 10 +
        (step.group == group ? 0 : 1);
    if (score < bestScore) {
      best = i;
      bestScore = score;
    }
  }
  return best;
}
