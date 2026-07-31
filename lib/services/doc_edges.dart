import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// **Belgenin kâğıt kenarlarını otomatik bulma.**
///
/// Kullanıcı isteği 2026-07-30: *"belge tara kısmı daha gelişmeli, daha iyi
/// taranmalı, kenarlar vs çok daha iyi algılanıp sayfa düzeltilmeli"*.
///
/// ## Neden gerekliydi
/// Köşe ayarlama ekranı (`ScanEditScreen`) açıldığında dörtgen **görselin
/// tamamı** olarak başlıyordu: ML Kit kenarı kaçırdığında kullanıcı dört köşeyi
/// de tek tek elle sürüklemek zorundaydı. Artık ekran açılır açılmaz kâğıdın
/// kenarları aranıyor; bulunursa dörtgen oraya oturuyor, kullanıcıya yalnız
/// (gerekirse) ince ayar kalıyor.
///
/// ## Yöntem — Hough doğru dönüşümü
/// Köşe değil **kenar doğrusu** aranıyor. Sebep: kâğıdın köşesi çoğu fotoğrafta
/// gölgede kalır ya da kadraj dışına taşar, oysa kenarları uzun ve düzdür.
/// Dört doğru bulunup kesiştirilince köşe, görünmese bile hesaplanabiliyor.
///
/// 1. Görsel ~420 piksele küçültülür. Hız için değil **doğruluk** için de:
///    o ölçekte metin satırları bulanıklaşıp yok olur, geriye kâğıdın kendi
///    kenarları kalır. Tam çözünürlükte en güçlü doğrular çoğu zaman metin
///    satırları oluyordu.
/// 2. Gri tonlama + kutu bulanıklaştırma (gürültü, kâğıt dokusu).
/// 3. Sobel eğim büyüklüğü; eşik **Otsu** ile seçilir (sabit eşik, karanlık
///    fotoğrafta hiçbir kenar bulamıyor, aydınlıkta her şeyi kenar sanıyordu;
///    sabit bir yüzdelik de işe yaramıyor çünkü kenar piksellerinin ORANI
///    görselden görsele değişiyor — temiz bir çekimde binde birkaç, dokulu bir
///    masada yüzde onlar).
/// 4. Hough birikimi (θ 1° adım, ρ 2 piksel adım) → yerel maksimumlar.
/// 5. Doğrular yataya/dikeye ayrılır; her gruptan **en güçlü olan ve ondan
///    yeterince uzaktaki en güçlü** doğru seçilir (bkz. `_pickPair` — "en
///    dıştakini al" ölçüldü ve çuvalladı).
/// 6. Kesişimler köşe olur ve akla yatkınlık denetiminden geçer.
///
/// Bulunamazsa `null` döner — **uydurma yapmıyoruz**, çağıran görselin tamamına
/// düşer. Yanlış bir dörtgen, dörtgen olmamasından kötüdür: kullanıcı kâğıdın
/// yarısını kırpılmış bulur.
///
/// Saf Dart (`image` paketi) → izolatta koşar ve **birim testi yazılabilir**.
abstract final class DocEdges {
  /// Çözümleme çözünürlüğü (uzun kenar).
  static const analysisSize = 420;

  /// Eğim büyüklüğü eşiğinin alt sınırı: bunun altındaki "kenar" gürültüdür.
  static const minEdgeStrength = 16;

  /// Bulunan dörtgen: sol-üst, sağ-üst, sağ-alt, sol-alt — **özgün görselin
  /// piksel koordinatında** (çözümleme ölçeği geri çarpılır).
  ///
  /// [bytes] herhangi bir kodlanmış görsel (JPEG/PNG).
  static List<({double x, double y})>? detect(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return detectInImage(decoded);
  }

  static List<({double x, double y})>? detectInImage(img.Image decoded) {
    final longEdge = math.max(decoded.width, decoded.height);
    if (longEdge < 32) return null;
    final scale = longEdge > analysisSize ? analysisSize / longEdge : 1.0;
    final small = scale < 1.0
        ? img.copyResize(decoded,
            width: math.max(2, (decoded.width * scale).round()),
            height: math.max(2, (decoded.height * scale).round()),
            interpolation: img.Interpolation.average)
        : decoded;

    final w = small.width;
    final h = small.height;
    final gray = _luminance(small);
    final blurred = boxBlur(gray, w, h, 2);
    final magnitude = sobelMagnitude(blurred, w, h);
    // Tamamen düz bir yüzeyde (kâğıt masaya değil de aynı renk bir zemine
    // konmuşsa) ortada kenar YOKTUR; gürültüyü kenar sanmayalım.
    var peak = 0;
    for (final v in magnitude) {
      if (v > peak) peak = v;
    }
    if (peak < 24) return null;
    // Eşik İNCELTİLMEMİŞ büyüklükten okunur: inceltme piksellerin çoğunu
    // sıfırlıyor ve Otsu'yu aşağı çekerdi.
    final threshold = math.max(minEdgeStrength, otsuThreshold(magnitude));

    final quad = _quadFromHough(sobelThinned(blurred, w, h), w, h, threshold);
    if (quad == null) return null;

    // Çözümleme ölçeğinden özgün piksellere geri dön.
    final back = scale < 1.0 ? 1 / scale : 1.0;
    return [
      for (final c in quad)
        (
          x: (c.x * back).clamp(0.0, decoded.width.toDouble()),
          y: (c.y * back).clamp(0.0, decoded.height.toDouble()),
        )
    ];
  }

  // ── saf yardımcılar (birim testli) ────────────────────────────────────────

  /// Gri tonlama (Rec. 601 parlaklık).
  static Uint8List _luminance(img.Image image) {
    final rgb = image.getBytes(order: img.ChannelOrder.rgb);
    final out = Uint8List(image.width * image.height);
    for (var i = 0, j = 0; i < out.length; i++, j += 3) {
      out[i] = (rgb[j] * 0.299 + rgb[j + 1] * 0.587 + rgb[j + 2] * 0.114)
          .round()
          .clamp(0, 255);
    }
    return out;
  }

  /// Yarıçapı [radius] olan kutu bulanıklaştırma — **ayrık** (önce yatay,
  /// sonra dikey) ve kayan toplamlı: yarıçaptan bağımsız O(piksel).
  static Uint8List boxBlur(Uint8List src, int w, int h, int radius) {
    if (radius <= 0) return Uint8List.fromList(src);
    final tmp = Uint8List(src.length);
    final out = Uint8List(src.length);
    final window = radius * 2 + 1;

    for (var y = 0; y < h; y++) {
      final row = y * w;
      var sum = 0;
      for (var i = -radius; i <= radius; i++) {
        sum += src[row + i.clamp(0, w - 1)];
      }
      for (var x = 0; x < w; x++) {
        tmp[row + x] = sum ~/ window;
        sum -= src[row + (x - radius).clamp(0, w - 1)];
        sum += src[row + (x + radius + 1).clamp(0, w - 1)];
      }
    }
    for (var x = 0; x < w; x++) {
      var sum = 0;
      for (var i = -radius; i <= radius; i++) {
        sum += tmp[i.clamp(0, h - 1) * w + x];
      }
      for (var y = 0; y < h; y++) {
        out[y * w + x] = sum ~/ window;
        sum -= tmp[(y - radius).clamp(0, h - 1) * w + x];
        sum += tmp[(y + radius + 1).clamp(0, h - 1) * w + x];
      }
    }
    return out;
  }

  /// Sobel eğim büyüklüğü (|Gx| + |Gy|, 0..255'e kırpılır).
  static Uint8List sobelMagnitude(Uint8List gray, int w, int h) =>
      _sobel(gray, w, h, thin: false);

  /// Sobel + **inceltme** (eğim yönünde maksimum olmayanı bastırma, Canny'nin
  /// ikinci adımı): kalın kenar bandı 1 piksele iner.
  ///
  /// BU ADIM ŞART (ölçüldü): bulanıklaştırma ve küçültme yüzünden kâğıdın
  /// kenarı 5-6 piksellik bir banda yayılıyor. Hough'da o bandı **çapraz**
  /// kesen doğrular da yüzlerce oy topluyor ("hayalet" kenarlar) ve 4°'lik
  /// bir hayalet, gerçek kenardan daha dışta çıkıp dörtgeni yamultuyordu
  /// (kâğıdın sol kenarı üstte 46, altta 70 piksele oturuyordu). Band tek
  /// piksele inince hayaletin toplayacağı oy kalmıyor.
  static Uint8List sobelThinned(Uint8List gray, int w, int h) =>
      _sobel(gray, w, h, thin: true);

  static Uint8List _sobel(Uint8List gray, int w, int h, {required bool thin}) {
    final out = Uint8List(w * h);
    final mag = thin ? Uint8List(w * h) : out;
    final dirs = thin ? Uint8List(w * h) : null;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final tl = gray[i - w - 1], t = gray[i - w], tr = gray[i - w + 1];
        final l = gray[i - 1], r = gray[i + 1];
        final bl = gray[i + w - 1], b = gray[i + w], br = gray[i + w + 1];
        final gx = (tr + 2 * r + br) - (tl + 2 * l + bl);
        final gy = (bl + 2 * b + br) - (tl + 2 * t + tr);
        final m = (gx.abs() + gy.abs()) >> 2;
        mag[i] = m > 255 ? 255 : m;
        if (dirs != null) dirs[i] = _direction(gx, gy);
      }
    }
    if (!thin) return out;
    // Eğim yönündeki iki komşudan biri daha güçlüyse bu piksel kenarın
    // tepesi değil, yamacıdır → bastırılır.
    const offsets = <int, ({int dx, int dy})>{
      0: (dx: 1, dy: 0), // yatay eğim → dikey kenar
      1: (dx: 1, dy: 1),
      2: (dx: 0, dy: 1),
      3: (dx: 1, dy: -1),
    };
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final m = mag[i];
        if (m == 0) continue;
        final step = offsets[dirs![i]]!;
        final a = mag[i + step.dy * w + step.dx];
        final b = mag[i - step.dy * w - step.dx];
        if (m >= a && m >= b) out[i] = m;
      }
    }
    return out;
  }

  /// Eğim yönünü dört kovaya indirger (0: →, 1: ↘, 2: ↓, 3: ↗).
  static int _direction(int gx, int gy) {
    final ax = gx.abs();
    final ay = gy.abs();
    // tan(22,5°) ≈ 0,414 ve tan(67,5°) ≈ 2,414 — tamsayı kalsın diye
    // 0,414 ≈ 41/99 yerine karşılaştırma çarpımla yapılıyor.
    if (ay * 100 < ax * 41) return 0;
    if (ax * 100 < ay * 41) return 2;
    return (gx > 0) == (gy > 0) ? 1 : 3;
  }

  /// **Otsu eşiği**: sınıflar-arası varyansı en büyüten kesim.
  ///
  /// Parametresiz olması burada belirleyici: kenar piksellerinin oranı
  /// görselden görsele on kat değişiyor, o yüzden "en güçlü %8" gibi sabit bir
  /// yüzdelik temiz bir çekimde eşiği SIFIRA indiriyordu (piksellerin %99'u
  /// sıfır eğimli olduğu için). Otsu dağılımın kendisine bakıyor.
  static int otsuThreshold(Uint8List values) {
    final hist = List<int>.filled(256, 0);
    for (final v in values) {
      hist[v]++;
    }
    final total = values.length;
    if (total == 0) return 0;
    var sum = 0.0;
    for (var v = 0; v < 256; v++) {
      sum += v * hist[v];
    }
    var weightLow = 0;
    var sumLow = 0.0;
    var best = 0.0;
    var threshold = 0;
    for (var v = 0; v < 256; v++) {
      weightLow += hist[v];
      if (weightLow == 0) continue;
      final weightHigh = total - weightLow;
      if (weightHigh == 0) break;
      sumLow += v * hist[v];
      final meanLow = sumLow / weightLow;
      final meanHigh = (sum - sumLow) / weightHigh;
      final between =
          weightLow * weightHigh * (meanLow - meanHigh) * (meanLow - meanHigh);
      if (between > best) {
        best = between;
        threshold = v;
      }
    }
    return threshold;
  }

  /// [q] yüzdeliğindeki değer (0..1). Histogram üstünden → O(n).
  static int quantile(Uint8List values, double q) {
    final hist = List<int>.filled(256, 0);
    for (final v in values) {
      hist[v]++;
    }
    final target = (values.length * q).round();
    var seen = 0;
    for (var v = 0; v < 256; v++) {
      seen += hist[v];
      if (seen >= target) return v;
    }
    return 255;
  }

  // ── Hough ────────────────────────────────────────────────────────────────

  // θ adımı 1°: 2° denendi ve YETMEDİ. Gerçek açı iki bin arasına düşünce
  // (ör. 7°, binler 6° ve 8°) 1°'lik hata 250 piksellik bir kenarda ~4 piksel
  // dikey kayma demek; oylar üç ρ kutusuna bölünüyor ve kenar eşiği geçemiyor.
  // 1°'de hata en çok 0,5° → oylar bitişik iki kutuda kalıyor; ayrıca aşağıda
  // tepe puanı üç komşu ρ kutusunun TOPLAMI olarak okunuyor.
  static const _thetaStep = 1; // derece
  static const _thetaBins = 180 ~/ _thetaStep;
  static const _rhoStep = 2.0; // piksel

  /// Eleme sonrası tutulan en çok tepe sayısı ve "aynı kenar" toleransları.
  static const _maxPeaks = 40;
  static const _peakThetaGap = 6; // derece
  static const _peakRhoGap = 14.0; // piksel


  static List<({double x, double y})>? _quadFromHough(
      Uint8List magnitude, int w, int h, int threshold) {
    final diagonal = math.sqrt(w * w + h * h);
    final rhoBins = (2 * diagonal / _rhoStep).ceil() + 1;
    final acc = Int32List(_thetaBins * rhoBins);

    final cos = Float64List(_thetaBins);
    final sin = Float64List(_thetaBins);
    for (var t = 0; t < _thetaBins; t++) {
      final radians = t * _thetaStep * math.pi / 180.0;
      cos[t] = math.cos(radians);
      sin[t] = math.sin(radians);
    }

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        if (magnitude[y * w + x] < threshold) continue;
        for (var t = 0; t < _thetaBins; t++) {
          final rho = x * cos[t] + y * sin[t];
          final bin = ((rho + diagonal) / _rhoStep).round();
          if (bin >= 0 && bin < rhoBins) acc[t * rhoBins + bin]++;
        }
      }
    }

    // Tepe noktaları: yerel maksimum + en az bir alt sınır oy.
    // Alt sınır GÖRSEL ÖLÇÜSÜNE bağlı: kâğıdın kenarı en az kısa kenarın
    // üçte biri kadar uzun olmalı, yoksa bir tablo çizgisini kenar sanarız.
    final minVotes = math.max(20, (math.min(w, h) * 0.33).round());
    final peaks = <({int theta, double rho, int votes})>[];
    for (var t = 0; t < _thetaBins; t++) {
      final row = t * rhoBins;
      for (var b = 2; b < rhoBins - 2; b++) {
        // Puan = ÜÇ komşu ρ kutusunun toplamı. Tek kutuya bakmak, açısı bin
        // ortasına denk gelmeyen (yani neredeyse her gerçek) kenarı bölünmüş
        // oyları yüzünden eliyordu.
        final score = acc[row + b - 1] + acc[row + b] + acc[row + b + 1];
        if (score < minVotes) continue;
        final before = acc[row + b - 2] + acc[row + b - 1] + acc[row + b];
        final after = acc[row + b] + acc[row + b + 1] + acc[row + b + 2];
        if (score < before || score < after) continue;
        peaks.add((theta: t, rho: b * _rhoStep - diagonal, votes: score));
      }
    }
    if (peaks.length < 4) return null;

    // ── Tepe eleme (bastırma) ────────────────────────────────────────────────
    // BU ADIM OLMADAN ÇALIŞMIYOR (ölçüldü: sentetik bir sayfada 4300 tepe).
    // Aşağıda her yönün "en dıştaki" doğrusu seçiliyor; eleme yapılmazsa o
    // "en dış", eşiği kıl payı geçmiş rastgele bir çapraz oluyor ve dörtgen
    // ya saçmalıyor ya da akla yatkınlık denetimine takılıp null dönüyordu.
    //
    // Üç süzgeç: (a) en güçlü tepenin belli bir oranının altındakiler düşer,
    // (b) birbirine çok yakın (aynı kenarın kopyası) tepeler tekleşir,
    // (c) en fazla [_maxPeaks] tane tutulur.
    peaks.sort((a, b) => b.votes.compareTo(a.votes));
    final voteFloor = (peaks.first.votes * 0.30).round();
    final kept = <({int theta, double rho, int votes})>[];
    for (final p in peaks) {
      if (p.votes < voteFloor) break;
      if (kept.length >= _maxPeaks) break;
      var duplicate = false;
      for (final k in kept) {
        // θ farkı **dairesel**: 0° ile 179° aynı doğrultu (ρ'ları ters işaretli).
        final dt = (p.theta - k.theta).abs();
        final circular = math.min(dt, _thetaBins - dt);
        if (circular <= _peakThetaGap &&
            (p.rho.abs() - k.rho.abs()).abs() <= _peakRhoGap) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate) kept.add(p);
    }
    if (kept.length < 4) return null;

    // θ ≈ 90° → **yatay** doğru (normali dikey), θ ≈ 0/180 → **dikey** doğru.
    // ±35° pay: elde tutulan telefonla çekilen sayfa bu kadar eğik olabilir.
    const slack = 35 ~/ _thetaStep;
    const vertical = 90 ~/ _thetaStep;
    final horizontals = [
      for (final p in kept)
        if ((p.theta - vertical).abs() <= slack) p
    ];
    final verticals = [
      for (final p in kept)
        if (p.theta <= slack || p.theta >= _thetaBins - slack) p
    ];
    if (horizontals.length < 2 || verticals.length < 2) return null;

    // Doğrunun görselin ORTA ekseninden geçtiği yer: "en üstteki"/"en soldaki"
    // kıyaslaması bu değere göre yapılıyor. ρ'ya göre sıralamak eğik
    // doğrularda yanıltıcı olurdu.
    double yAt(({int theta, double rho, int votes}) p) {
      final s = sin[p.theta];
      if (s.abs() < 1e-6) return double.nan;
      return (p.rho - (w / 2) * cos[p.theta]) / s;
    }

    double xAt(({int theta, double rho, int votes}) p) {
      final c = cos[p.theta];
      if (c.abs() < 1e-6) return double.nan;
      return (p.rho - (h / 2) * sin[p.theta]) / c;
    }

    // Kâğıdın kenarı, görselin orta eksenini KADRAJ İÇİNDE (biraz payla)
    // keser. Bunu yapmayan bir doğru sayfanın kenarı olamaz.
    final tops = [
      for (final p in horizontals)
        if (yAt(p) > -h * 0.1 && yAt(p) < h * 1.1) p
    ];
    final sides = [
      for (final p in verticals)
        if (xAt(p) > -w * 0.1 && xAt(p) < w * 1.1) p
    ];

    // **"En dıştaki" DEĞİL, "en güçlü iki uzak doğru".**
    //
    // En dıştakini seçmek ölçüldü ve çuvalladı: kalın kenar bandını çapraz
    // kesen zayıf bir doğru (4°, gerçeğin üçte biri kadar oy) bandın hemen
    // dışına düşüp "en soldaki" oluyor ve dörtgeni yamultuyordu — kâğıdın sol
    // kenarı üstte 46, altta 70 piksele oturuyordu. Oysa kâğıdın gerçek iki
    // kenarı, oy sıralamasında açık ara önde ve birbirinden UZAK olan çifttir.
    // Bu ölçüt hem hayaleti kendiliğinden eliyor (gerçeğe çok yakın) hem de
    // "kâğıt kadrajın belirgin bir bölümünü kaplar" koşulunu içeriyor.
    final pairH = _pickPair(tops, yAt, h * 0.35);
    final pairV = _pickPair(sides, xAt, w * 0.35);
    if (pairH == null || pairV == null) return null;
    final top = pairH.$1;
    final bottom = pairH.$2;
    final left = pairV.$1;
    final right = pairV.$2;

    final corners = <({double x, double y})>[];
    for (final pair in [
      (top, left),
      (top, right),
      (bottom, right),
      (bottom, left),
    ]) {
      final point = intersect(
        cos[pair.$1.theta], sin[pair.$1.theta], pair.$1.rho, //
        cos[pair.$2.theta], sin[pair.$2.theta], pair.$2.rho,
      );
      if (point == null) return null;
      corners.add(point);
    }

    // Köşeler kadrajın MAKUL ölçüde içinde olmalı. Biraz taşma normal (kâğıdın
    // köşesi kadraj dışında kalmış olabilir) ama çok taşan kesişim, neredeyse
    // paralel iki doğrunun ürettiği anlamsız noktadır.
    for (final c in corners) {
      if (c.x < -w * 0.25 ||
          c.x > w * 1.25 ||
          c.y < -h * 0.25 ||
          c.y > h * 1.25) {
        return null;
      }
    }
    if (polygonArea(corners) < w * h * 0.2) return null;
    return corners;
  }

  /// En güçlü doğruyu, sonra ondan **en az [minSeparation]** uzaktaki en güçlü
  /// doğruyu seçer; ikisini konuma göre (küçük, büyük) sıralı döndürür.
  ///
  /// [positionOf] doğrunun görselin orta ekseniyle kesiştiği yer.
  static (
    ({int theta, double rho, int votes}),
    ({int theta, double rho, int votes})
  )? _pickPair(
    List<({int theta, double rho, int votes})> lines,
    double Function(({int theta, double rho, int votes})) positionOf,
    double minSeparation,
  ) {
    if (lines.length < 2) return null;
    final sorted = [...lines]..sort((a, b) => b.votes.compareTo(a.votes));
    final first = sorted.first;
    final anchor = positionOf(first);
    for (final candidate in sorted.skip(1)) {
      if ((positionOf(candidate) - anchor).abs() < minSeparation) continue;
      return positionOf(candidate) < anchor
          ? (candidate, first)
          : (first, candidate);
    }
    return null;
  }

  /// İki doğrunun (ρ = x·cosθ + y·sinθ) kesişimi; paralellerde null.
  static ({double x, double y})? intersect(double c1, double s1, double r1,
      double c2, double s2, double r2) {
    final det = c1 * s2 - c2 * s1;
    if (det.abs() < 1e-9) return null;
    return (
      x: (r1 * s2 - r2 * s1) / det,
      y: (c1 * r2 - c2 * r1) / det,
    );
  }

  /// Ayakkabı bağı formülü (mutlak alan).
  static double polygonArea(List<({double x, double y})> points) {
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum.abs() / 2;
  }
}
