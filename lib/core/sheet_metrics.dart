/// Excel ızgarasının eksen ölçüleri (saf Dart, testli).
///
/// *Niye ayrı dosya:* ızgara hem yatayda hem dikeyde sanallaştırılıyor ve
/// dondurulmuş bölmenin ekrana sığması gerekiyor. Bu iki hesap ekranın
/// içinde yazıldığında yalnız cihazda görünen yerleşim hatalarına yol açtı
/// (bkz. HAFIZA: "sağ kısmı göremiyorum"), burada testlenebilir.
library;

/// Bir eksende (satır ya da sütun) **görünen** dizinlerin ölçüleri.
///
/// `starts` birikimli başlangıç pikselleridir: `starts[i]` = i. görünür
/// dizinin sol/üst kenarı, `starts.last` = toplam uzunluk. Böylece toplam
/// genişlik, kaydırma penceresi ve "hücreyi görünür yap" hesapları her karede
/// baştan toplanmaz (512 sütunluk dosyada kare başına binlerce toplama
/// yapılıyordu).
class SheetAxisMetrics {
  /// Görünür (gizlenmemiş) dizinler, artan sırada.
  final List<int> indices;

  /// `indices.length + 1` uzunluğunda birikimli başlangıçlar.
  final List<double> starts;

  const SheetAxisMetrics(this.indices, this.starts);

  static const SheetAxisMetrics empty = SheetAxisMetrics(<int>[], <double>[0]);

  /// [from] (dahil) ile [to] (hariç) arası dizinlerden gizli olmayanları alır.
  factory SheetAxisMetrics.build({
    required int from,
    required int to,
    required double Function(int index) sizeOf,
    bool Function(int index)? hidden,
  }) {
    final indices = <int>[];
    final starts = <double>[0];
    var acc = 0.0;
    for (var i = from; i < to; i++) {
      if (hidden != null && hidden(i)) continue;
      final size = sizeOf(i);
      if (size <= 0) continue; // gizli/sıfır ölçülü çizilmez
      indices.add(i);
      acc += size;
      starts.add(acc);
    }
    return SheetAxisMetrics(indices, starts);
  }

  int get length => indices.length;
  bool get isEmpty => indices.isEmpty;

  /// Eksenin toplam uzunluğu (piksel).
  double get total => starts.last;

  double startAt(int position) => starts[position];

  double sizeAt(int position) => starts[position + 1] - starts[position];

  /// [offset] pikselinde başlayan ilk görünür konum.
  int firstAt(double offset) {
    if (indices.isEmpty) return 0;
    // starts sıralı → ikili arama (son start <= offset).
    var lo = 0, hi = indices.length - 1, best = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (starts[mid] <= offset) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return best;
  }

  /// [edge] pikseline kadar görünen son konum (bir sütun taşma payı ile).
  int lastAt(double edge) {
    if (indices.isEmpty) return 0;
    var last = firstAt(edge);
    if (last + 1 < indices.length) last++; // payanda: kaydırırken boşluk olmaz
    return last;
  }

  /// Ham dizinin (satır/sütun numarasının) bu eksendeki konumu; yoksa -1.
  int positionOf(int index) {
    var lo = 0, hi = indices.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final v = indices[mid];
      if (v == index) return mid;
      if (v < index) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return -1;
  }
}

/// Dondurulmuş bölmenin **kaç** satır/sütununun ekrana sığdığını söyler.
///
/// Excel masaüstünde bölme pencereden geniş olabilir; telefonda bu, kaydırılan
/// bölgeye YER KALMAMASI demektir (`Expanded` sıfır genişlik alır → kullanıcı
/// sağ tarafı hiç göremez). Sığmayan dondurulmuş sütunlar kaydırılan bölgeye
/// bırakılır: içerik erişilebilir kalır, sabit kısım de ekrana sığar.
///
/// [budget] sabit bölgeye ayrılan piksel; [sizeOf] dizinin piksel ölçüsü
/// (gizli satır/sütun 0 döner ve bütçe yemeden sayılır).
int fitFrozen({
  required int count,
  required double Function(int index) sizeOf,
  required double budget,
}) {
  if (count <= 0 || budget <= 0) return 0;
  var used = 0.0;
  var fit = 0;
  for (var i = 0; i < count; i++) {
    final size = sizeOf(i);
    if (size <= 0) {
      fit = i + 1; // gizli — yer kaplamaz, bölmenin parçası sayılır
      continue;
    }
    if (used + size > budget) break;
    used += size;
    fit = i + 1;
  }
  return fit;
}
