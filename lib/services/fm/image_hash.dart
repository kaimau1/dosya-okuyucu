/// **Algısal görsel parmak izi** (dHash) ve benzerlik gruplama.
///
/// Bilinçli olarak **saf Dart** (Flutter/dart:ui importu YOK): eşik davranışı,
/// gruplamanın geçişliliği ve büyük listelerdeki aday üretimi birim testiyle
/// sabitlensin diye. Görüntü çözme işi ayrı dosyada
/// (`media_fingerprint.dart`).
///
/// ## Niye dHash
/// Kullanıcı isteği (2026-07-29): *"video ve fotoğraflarda ai ile aynı
/// resimleri tespit"*. Var olan `DuplicateFinder` yalnız **birebir** aynı
/// dosyayı bulur (bayt bayt); WhatsApp'ın yeniden sıkıştırdığı, boyutu
/// değişmiş ya da hafifçe kırpılmış "aynı" görselde tek bayt bile tutmaz.
/// dHash görüntüyü 9x8 gri ızgaraya indirip **komşu piksel farklarının
/// işaretini** yazar: parlaklık/sıkıştırma/ölçek değişse de bit dizisi büyük
/// ölçüde aynı kalır, bit farkı (Hamming uzaklığı) benzerliğin ölçüsü olur.
/// Ortalamaya dayanan aHash tek renkli görsellerde çöker, dHash çökmez.
library;

import 'dart:math' as math;

/// Izgara genişliği: 8 fark üretmek için 9 sütun gerekir.
const int hashGridWidth = 9;
const int hashGridHeight = 8;

/// Gri tonlu ızgaradan 64-bit dHash üretir.
///
/// [gray] uzunluğu [width]*[height] olmalıdır (satır satır, 0-255).
/// Her satırda komşu iki piksel karşılaştırılır → 8x8 = 64 bit.
int dHashFromGray(
  List<int> gray, {
  int width = hashGridWidth,
  int height = hashGridHeight,
}) {
  if (gray.length < width * height) {
    throw ArgumentError('gray uzunluğu ${width * height} olmalı, '
        '${gray.length} geldi');
  }
  var hash = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width - 1; x++) {
      final left = gray[y * width + x];
      final right = gray[y * width + x + 1];
      hash = (hash << 1) | (left > right ? 1 : 0);
    }
  }
  return hash;
}

/// RGBA baytlarını gri tonlamaya çevirir (insan gözünün ağırlıkları).
List<int> grayFromRgba(List<int> rgba, int pixelCount) {
  final out = List<int>.filled(pixelCount, 0);
  for (var i = 0; i < pixelCount; i++) {
    final o = i * 4;
    if (o + 2 >= rgba.length) break;
    // 0.299 R + 0.587 G + 0.114 B — tam sayı aritmetiğiyle (hızlı ve kararlı).
    out[i] = (rgba[o] * 299 + rgba[o + 1] * 587 + rgba[o + 2] * 114) ~/ 1000;
  }
  return out;
}

/// İki parmak izi arasındaki bit farkı (0 = birebir aynı görünüm).
int hamming(int a, int b) {
  var x = a ^ b;
  var count = 0;
  while (x != 0) {
    // x & (x-1) en sağdaki 1 bitini siler → küme sayısı kadar döner.
    x &= x - 1;
    count++;
  }
  return count;
}

/// Benzerlik duyarlılığı — arayüzdeki üç kademe.
enum SimilarityLevel { strict, normal, loose }

extension SimilarityLevelInfo on SimilarityLevel {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        SimilarityLevel.strict => 'enum.sim_strict',
        SimilarityLevel.normal => 'enum.sim_normal',
        SimilarityLevel.loose => 'enum.sim_loose',
      };

  String get descriptionKey => switch (this) {
        SimilarityLevel.strict => 'enum.sim_strict_desc',
        SimilarityLevel.normal => 'enum.sim_normal_desc',
        SimilarityLevel.loose => 'enum.sim_loose_desc',
      };

  String get label => switch (this) {
        SimilarityLevel.strict => 'Çok sıkı',
        SimilarityLevel.normal => 'Normal',
        SimilarityLevel.loose => 'Gevşek',
      };

  String get description => switch (this) {
        SimilarityLevel.strict =>
          'Neredeyse birebir aynı görüntüler (yeniden sıkıştırılmış kopyalar).',
        SimilarityLevel.normal =>
          'Aynı görüntünün boyutu/kalitesi değişmiş ya da hafif kırpılmış hâlleri.',
        SimilarityLevel.loose =>
          'Aynı sahnenin arka arkaya çekilmiş kareleri de eşleşir; yanlış eşleşme olabilir.',
      };

  /// İzin verilen en büyük bit farkı.
  int get maxDistance => switch (this) {
        SimilarityLevel.strict => 2,
        SimilarityLevel.normal => 6,
        SimilarityLevel.loose => 10,
      };
}

/// Parmak izlerini benzerlik kümelerine böler; her küme **girdi indeksleri**
/// listesidir. Tek elemanlı kümeler dönmez (benzeri olmayan dosya ilgi çekmez).
///
/// [maxDistance] eşiği aşmayan çiftler aynı kümeye girer ve birleştirme
/// **geçişlidir** (A~B, B~C ise A, B, C tek gruptur): kullanıcı "şu üç fotoğraf
/// aynı" der, ikili ilişkilerle uğraşmak istemez.
///
/// ## Hız
/// - Liste [exactLimit]'ten küçükse tüm çiftler karşılaştırılır (kesin sonuç).
///   6000 dosya = ~18 milyon bit sayımı, saniyenin altında.
/// - Daha büyük listelerde 8 x 8-bit **blok indeksi** ile aday üretilir:
///   Hamming uzaklığı 7'yi aşmayan iki parmak izi, güvercin yuvası ilkesince
///   en az bir blokta birebir aynı olmak zorundadır. Böylece 100 bin dosyada
///   kare karmaşıklığa düşülmez.
/// - **Dürüst sınır:** [exactLimit] üstünde ve eşik 8'in üstündeyse (yalnız
///   "Gevşek" kademesi) bazı uzak çiftler kaçabilir. Pratikte bir galeride
///   6000'den az benzer aday olduğu için bu yol nadiren işler.
List<List<int>> groupSimilar(
  List<int> hashes, {
  int maxDistance = 6,
  int exactLimit = 6000,
}) {
  final n = hashes.length;
  if (n < 2) return const [];

  final parent = List<int>.generate(n, (i) => i);
  int find(int x) {
    var root = x;
    while (parent[root] != root) {
      root = parent[root];
    }
    // Yol sıkıştırma: derin zincirler tekrar tekrar yürünmesin.
    var cur = x;
    while (parent[cur] != root) {
      final next = parent[cur];
      parent[cur] = root;
      cur = next;
    }
    return root;
  }

  void union(int a, int b) {
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) parent[rb] = ra;
  }

  if (n <= exactLimit) {
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if (hamming(hashes[i], hashes[j]) <= maxDistance) union(i, j);
      }
    }
  } else {
    // 8 blok x 8 bit. Anahtar: (blok no, blok değeri).
    final buckets = <int, List<int>>{};
    for (var i = 0; i < n; i++) {
      final h = hashes[i];
      for (var b = 0; b < 8; b++) {
        final value = (h >> (b * 8)) & 0xFF;
        (buckets[(b << 8) | value] ??= []).add(i);
      }
    }
    for (final bucket in buckets.values) {
      // Aynı kovada binlerce girdi olabilir (ör. bomboş/siyah kareler);
      // kova içi karşılaştırma yine kare ama kova küçük olduğu için toplam iş
      // düşer. Aşırı büyük kovalar (tek renkli görseller) atlanmaz — onlar
      // gerçekten birbirinin benzeri.
      for (var x = 0; x < bucket.length; x++) {
        for (var y = x + 1; y < bucket.length; y++) {
          final i = bucket[x];
          final j = bucket[y];
          if (find(i) == find(j)) continue;
          if (hamming(hashes[i], hashes[j]) <= maxDistance) union(i, j);
        }
      }
    }
  }

  final byRoot = <int, List<int>>{};
  for (var i = 0; i < n; i++) {
    (byRoot[find(i)] ??= []).add(i);
  }
  final groups = byRoot.values.where((g) => g.length > 1).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return groups;
}

/// **Netlik ölçüsü** (Ayıkla 2, 2026-11-19): gri ızgarada Laplace süzgecinin
/// varyansı. Bulanık karede komşu pikseller birbirine yakın → yanıt düşük;
/// net karede kenarlar keskin → yüksek. Yalnız AYNI sahnenin karelerini
/// sıralamak için anlamlı (benzer kare grubu), mutlak eşik değildir.
/// [gray] satır satır [width]x[height].
double laplacianVariance(List<int> gray, int width, int height) {
  if (width < 3 || height < 3 || gray.length < width * height) return 0;
  var sum = 0.0;
  var sumSq = 0.0;
  var n = 0;
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final i = y * width + x;
      final v = gray[i - width] +
          gray[i + width] +
          gray[i - 1] +
          gray[i + 1] -
          4 * gray[i];
      sum += v;
      sumSq += v * v;
      n++;
    }
  }
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

/// Netliği kaba kademeye çevirir (her kademe ≈ %15): sıralamada küçük ölçüm
/// gürültüsü boyut/tarih eşitlik kuralını ezmesin, karşılaştırma geçişli
/// kalsın. Ölçülemeyen (null/≤ 0) en alt kademe.
int sharpnessTier(double? sharpness) {
  if (sharpness == null || sharpness <= 1) return 0;
  // ponytail: log tabanı 1.15 — gruplar küçük, kademe kaba; gerekirse AI puanı (Decisions score) eklenir.
  return 1 + (math.log(sharpness) / math.log(1.15)).floor();
}
