import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'doc_edges.dart' show DocEdges;
import 'scan_page_ops.dart' show ScanPageOps;

/// Taranan sayfaya uygulanacak **belge filtresi**.
enum ScanFilter {
  /// Tarayıcıdan geldiği gibi — hiç dokunulmaz.
  original,

  /// **Varsayılan.** Renk korunur, gölge/eşitsiz ışık giderilir, yazı
  /// keskinleştirilir. Fotoğraflı/renkli mühürlü belgelerde doğru seçim.
  auto,

  /// Gri tonlama + aynı düzeltmeler. Metin belgelerinde en okunaklısı ve
  /// dosyayı belirgin küçültür.
  gray,

  /// Saf siyah-beyaz (uyarlamalı eşikleme) — masaüstü tarayıcı görünümü.
  /// Fotoğrafları mahveder, düz metinde en net sonuç.
  blackWhite,
}

extension ScanFilterLabel on ScanFilter {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey` deseni).
  String get labelKey => switch (this) {
        ScanFilter.original => 'scan.filter_original',
        ScanFilter.auto => 'scan.filter_auto',
        ScanFilter.gray => 'scan.filter_gray',
        ScanFilter.blackWhite => 'scan.filter_bw',
      };

  /// Önizleme kartının altına sığan kısa ad.
  String get shortLabelKey => switch (this) {
        ScanFilter.original => 'scan.short_original',
        ScanFilter.auto => 'scan.short_auto',
        ScanFilter.gray => 'scan.short_gray',
        ScanFilter.blackWhite => 'scan.short_bw',
      };
}

/// İzolata geçen istek (tek argüman kuralı).
class ScanEnhanceRequest {
  final String sourcePath;
  final String targetPath;
  final ScanFilter filter;

  const ScanEnhanceRequest({
    required this.sourcePath,
    required this.targetPath,
    required this.filter,
  });
}

/// Filtre önizlemesi isteği (izolat — tek argüman kuralı).
class ScanPreviewRequest {
  final String sourcePath;
  final int longEdge;
  const ScanPreviewRequest(this.sourcePath, {this.longEdge = 420});
}

/// **Taranan sayfayı okunur hâle getirme.**
///
/// Kullanıcı isteği 2026-07-30: *"yazılar netleştirilmeli"*. Telefonla çekilen
/// bir sayfada asıl sorun çözünürlük değil **ışık**: sayfanın bir yanı parlak,
/// öbür yanı gölgede kalıyor; kontrastı topluca artırmak (klasik "kontrast"
/// düğmesi) gölgeli yanı büsbütün karartıyor.
///
/// ## Boru hattı
/// 1. **Aydınlatma düzeltme (bölme).** Sayfanın "zemini" büyük yarıçaplı bir
///    bulanıklaştırmayla kestirilir ve her piksel kendi yerel zeminine bölünür.
///    Gölge, vinyet ve eşitsiz lamba ışığı böyle kalkıyor — tek bir eşik ya da
///    tek bir kontrast eğrisiyle **mümkün değil**, çünkü sorun geneli değil
///    yereli ilgilendiriyor.
/// 2. **Yüzdelikli kontrast gerdirme.** Siyah/beyaz uçlar %2–%98 yüzdeliklere
///    oturtulur; tek bir toz zerresi ya da parlama ölçeği bozmasın diye uçlar
///    değil yüzdelikler kullanılıyor.
/// 3. **Keskinleştirme maskesi.** Bulanık kopya çıkarılıp fark geri eklenir —
///    harf kenarları toparlanır. Ölçü ölçülü (0,8): fazlası gürültüyü ve JPEG
///    bozulmalarını da keskinleştirip "kirli" bir sayfa üretiyor.
/// 4. (Yalnız [ScanFilter.blackWhite]) **Uyarlamalı eşikleme**: her piksel
///    kendi komşuluğunun ortalamasıyla kıyaslanır. Tek genel eşik, gölgeli
///    köşeyi komple siyah yapıyordu.
///
/// Saf `image` paketi (platform kodu yok) → izolatta koşar, birim testlenir.
abstract final class ScanEnhance {
  /// Zemin kestirimi için bulanıklaştırma yarıçapı — görselin kısa kenarının
  /// oranı. Harf kalınlığından çok daha büyük olmalı (yoksa harfin kendisi
  /// zemin sanılıp silinir), sayfadan küçük olmalı (yoksa gölgeyi göremez).
  static const backgroundRadiusRatio = 0.06;

  /// Keskinleştirme miktarı.
  static const sharpenAmount = 0.8;

  /// Çıktı JPEG kalitesi. 92: gözle kayıp yok, dosya makul.
  static const jpegQuality = 92;

  /// Sayfanın uzun kenarı için üst sınır (piksel). 2480 px ≈ A4 @ 300 dpi —
  /// masaüstü tarayıcıların "yüksek kalite" ayarı. 12MP telefon kamerası
  /// ~4000 px sayfa üretir: fazlası OCR'a da baskıya da bir şey katmaz ama
  /// PDF'i sayfa başına birkaç MB şişirir ve filtreleri yavaşlatır. Küçültme
  /// filtre borusunun EN BAŞINDA yapılır (2026-08-05, "mükemmel tarama" turu);
  /// [ScanFilter.original] seçilirse dosyaya hiç dokunulmadığı için o yol
  /// bilerek tam çözünürlük kalır.
  static const maxLongEdge = 2480;

  /// [request]'i uygular ve **hedef dosyanın yolunu** döndürür.
  /// `compute` ile izolatta çağrılmak üzere tek argümanlı.
  static String runRequest(ScanEnhanceRequest request) {
    final bytes = File(request.sourcePath).readAsBytesSync();
    final out = applyToBytes(bytes, request.filter);
    File(request.targetPath).writeAsBytesSync(out, flush: true);
    return request.targetPath;
  }

  /// Kodlanmış görsele filtre uygular, **JPEG** baytları döndürür.
  static Uint8List applyToBytes(Uint8List bytes, ScanFilter filter) {
    if (filter == ScanFilter.original) return bytes;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    return img.encodeJpg(applyToImage(decoded, filter), quality: jpegQuality);
  }

  static img.Image applyToImage(img.Image source, ScanFilter filter) {
    final longEdge = math.max(source.width, source.height);
    if (longEdge > maxLongEdge) {
      final ratio = maxLongEdge / longEdge;
      source = img.copyResize(
        source,
        width: (source.width * ratio).round(),
        height: (source.height * ratio).round(),
        interpolation: img.Interpolation.average,
      );
    }
    final w = source.width;
    final h = source.height;
    if (w < 8 || h < 8) return source;
    final radius =
        math.max(4, (math.min(w, h) * backgroundRadiusRatio).round());

    final rgb = source.getBytes(order: img.ChannelOrder.rgb);
    final gray = Uint8List(w * h);
    for (var i = 0, j = 0; i < gray.length; i++, j += 3) {
      gray[i] = (rgb[j] * 0.299 + rgb[j + 1] * 0.587 + rgb[j + 2] * 0.114)
          .round()
          .clamp(0, 255);
    }

    // 0: RESİM BÖLGELERİ (2026-10-18). Kullanıcı: *"belge tarandıktan ve
    // onaylandıktan sonra arka planda yapılan iyileştirmeler resmin
    // patlamasına ve bozulmasına sebep oluyor"*. Kök neden: aşağıdaki
    // aydınlatma düzeltmesi her pikseli KENDİ çevresinin ortalamasına bölüyor.
    // Kâğıtta bu gölgeyi siler; bir FOTOĞRAFIN içinde ise "çevrenin
    // ortalaması" fotoğrafın kendisidir → fotoğraf beyaza yakın düz bir lekeye
    // döner, renkli modda da oran ×4'e çıkıp kanallar 255'e dayanıyordu
    // (renkler patlıyordu). Artık resim bölgeleri bulunup düzeltmenin DIŞINDA
    // tutuluyor: fotoğraf olduğu gibi kalır, yalnız kâğıt+yazı netleşir.
    final picture = pictureMask(gray, w, h, rgb: rgb);

    // 1-3: gri kanal üstünde tüm düzeltmeler.
    var corrected = flattenIllumination(gray, w, h, radius);
    corrected = stretchContrast(corrected);
    corrected = sharpen(corrected, w, h, sharpenAmount);

    if (filter == ScanFilter.blackWhite) {
      final bw = adaptiveThreshold(corrected, w, h,
          radius: math.max(6, (math.min(w, h) * 0.02).round()), bias: 10);
      // Resim bölgesi eşiklenmez, GRİ kalır (masaüstü tarayıcıların "karma"
      // modu): eşiklenmiş fotoğraf siyah-beyaz karıncalanmaya dönüyordu.
      return _grayToImage(blend(bw, gray, picture), w, h);
    }
    final kept = blend(corrected, gray, picture);
    if (filter == ScanFilter.gray) return _grayToImage(kept, w, h);

    // Renkli mod: düzeltme **parlaklık** üzerinden uygulanıp renge geri
    // taşınır. Üç kanalı ayrı ayrı düzeltmek renkleri kaydırıyordu (mavi
    // kalemle atılan imza morarıyordu).
    final out = Uint8List(rgb.length);
    for (var i = 0, j = 0; i < gray.length; i++, j += 3) {
      final before = gray[i];
      final after = kept[i];
      // Kaynak zaten siyahsa oran patlamasın diye +1'li bölme.
      final ratio = (after + 1) / (before + 1);
      // Parlaklık TAM düzeltilir, rengin parlaklıktan sapması ise en çok
      // [maxChromaGain] kat büyür. Eskiden üç kanal düpedüz oranla
      // çarpılıyordu: gölgedeki renkli bir alanda oran ×3-4'e çıkınca
      // kanallar 255'e dayanıp renk "patlıyordu". Koyulaşan (oran < 1)
      // mürekkepte sonuç eskisiyle birebir aynı (k = oran).
      final k = ratio < maxChromaGain ? ratio : maxChromaGain;
      for (var c = 0; c < 3; c++) {
        final v = (after + (rgb[j + c] - before) * k).round();
        out[j + c] = v < 0 ? 0 : (v > 255 ? 255 : v);
      }
    }
    return img.Image.fromBytes(
        width: w, height: h, bytes: out.buffer, numChannels: 3);
  }

  /// Renkli modda rengin (parlaklıktan sapmanın) en çok kaç kat büyüyebileceği.
  static const maxChromaGain = 1.6;

  /// [enhanced] ile [original] arasında [mask]'e göre karışım: maske 0 →
  /// düzeltilmiş, 255 → özgün.
  static Uint8List blend(
      Uint8List enhanced, Uint8List original, Uint8List mask) {
    final out = Uint8List(enhanced.length);
    for (var i = 0; i < out.length; i++) {
      final m = mask[i];
      out[i] = m == 0
          ? enhanced[i]
          : (m == 255
              ? original[i]
              : (enhanced[i] * (255 - m) + original[i] * m) ~/ 255);
    }
    return out;
  }

  // ── resim (fotoğraf/çizim) bölgeleri ─────────────────────────────────────

  /// Sayfadaki **resim bölgelerinin** maskesi (piksel başına 0 = kâğıt/yazı,
  /// 255 = resim; arada yumuşak geçiş).
  ///
  /// Sayfa küçük bloklara bölünür. Yazılı kâğıdın bir bloğu İKİ TEPELİDİR:
  /// piksellerin çoğu bloğun kendi kâğıt tonuna yakındır (gölgede de olsa),
  /// kalanı belirgin koyu mürekkeptir; arada ara ton azdır. Fotoğraf bloğu
  /// ise ara tonlarla doludur. Ayrıca kâğıttan belirgin koyu ve RENKLİ düz
  /// bir alan (gökyüzü, renkli kutu) ve çok koyu düz alan (koyu fotoğraf
  /// zemini) da resim sayılır — bunlar düz olduğu için ara ton ölçüsü
  /// yakalamaz ama bölmeyle beyaza döner.
  ///
  /// Sonra temizlik: tek başına kalan blok (yazı kümesi gürültüsü) atılır;
  /// derli toplu bir resim bölgesi dış dikdörtgenine tamamlanır (fotoğraflar
  /// dikdörtgendir; içindeki düz gök/duvar parçası da korunur) ve bir blok
  /// genişletilir. **Yanılgı yönü bilinçli:** emin olunamayan alan resim
  /// sayılır — düzeltilmeyen bir köşe gölgesi, beyaza dönmüş bir fotoğraftan
  /// çok daha az kötüdür.
  static Uint8List pictureMask(Uint8List gray, int w, int h, {Uint8List? rgb}) {
    final mask = Uint8List(w * h);
    if (w < 16 || h < 16) return mask;
    final block = math.max(6, (math.min(w, h) / 48).round());
    final gw = (w + block - 1) ~/ block;
    final gh = (h + block - 1) ~/ block;
    final paperLevel = DocEdges.quantile(gray, 0.9);
    // Sayfanın en açık onda biri bile koyuysa ortada kâğıt yok (koyu bir
    // fotoğraf, gece çekimi): bütün sayfa resimdir, hiçbir yerine dokunulmaz.
    if (paperLevel < 110) {
      mask.fillRange(0, mask.length, 255);
      return mask;
    }

    final grid = Uint8List(gw * gh);
    final hist = Int32List(256);
    // Büyük blokta her piksele bakmak gereksiz: ikişer atlanır.
    final step = block >= 12 ? 2 : 1;
    for (var by = 0; by < gh; by++) {
      for (var bx = 0; bx < gw; bx++) {
        hist.fillRange(0, 256, 0);
        final x0 = bx * block, y0 = by * block;
        final x1 = math.min(w, x0 + block), y1 = math.min(h, y0 + block);
        var n = 0;
        var chroma = 0;
        for (var y = y0; y < y1; y += step) {
          final row = y * w;
          for (var x = x0; x < x1; x += step) {
            final i = row + x;
            hist[gray[i]]++;
            n++;
            if (rgb != null) {
              final j = i * 3;
              final r = rgb[j], g = rgb[j + 1], b = rgb[j + 2];
              final hi = r > g ? (r > b ? r : b) : (g > b ? g : b);
              final lo = r < g ? (r < b ? r : b) : (g < b ? g : b);
              chroma += hi - lo;
            }
          }
        }
        if (n == 0) continue;
        // Bloğun kendi kâğıt tonu: %85'lik dilim.
        var seen = 0, local = 255;
        final target = (n * 0.85).ceil();
        for (var v = 0; v < 256; v++) {
          seen += hist[v];
          if (seen >= target) {
            local = v;
            break;
          }
        }
        final tolerance = math.max(10, (local * 0.1).round());
        final inkBelow = (local * 0.55).round();
        var nearPaper = 0, ink = 0;
        for (var v = 0; v < 256; v++) {
          final c = hist[v];
          if (c == 0) continue;
          if ((v - local).abs() <= tolerance) {
            nearPaper += c;
          } else if (v < inkBelow) {
            ink += c;
          }
        }
        final mid = (n - nearPaper - ink) / n;
        final meanChroma = rgb == null ? 0 : chroma / n;
        final darkColored = meanChroma > 38 && local < paperLevel * 0.85;
        // Çok koyu VE yazısız düz alan (koyu fotoğraf zemini): bölme onu
        // beyaza çevirirdi. Yazılı bir blok ne kadar gölgede olursa olsun
        // mürekkep taşır — derin gölgedeki satırlar düzeltilmeye devam eder.
        final veryDark = local < paperLevel * 0.30 && ink < n * 0.05;
        if (mid > 0.33 || darkColored || veryDark) {
          grid[by * gw + bx] = 1;
        }
      }
    }

    _cleanPictureGrid(grid, gw, gh);

    // Blok ızgarasından piksele yumuşak geçiş: ızgara 0/255 olarak bir blok
    // yarıçapıyla bulanıklaştırılıp çift doğrusal büyütülür.
    final soft = Uint8List(gw * gh);
    for (var i = 0; i < soft.length; i++) {
      soft[i] = grid[i] == 0 ? 0 : 255;
    }
    final blurred = DocEdges.boxBlur(soft, gw, gh, 1);
    for (var i = 0; i < blurred.length; i++) {
      // Resim bloğunun kendisi tam korunur; bulanıklık yalnız DIŞA taşar.
      if (grid[i] != 0) blurred[i] = 255;
    }
    for (var y = 0; y < h; y++) {
      final gy = (y + 0.5) / block - 0.5;
      final iy = gy.floor();
      final fy = gy - iy;
      final y0 = iy.clamp(0, gh - 1), y1 = (iy + 1).clamp(0, gh - 1);
      for (var x = 0; x < w; x++) {
        final gx = (x + 0.5) / block - 0.5;
        final ix = gx.floor();
        final fx = gx - ix;
        final x0 = ix.clamp(0, gw - 1), x1 = (ix + 1).clamp(0, gw - 1);
        final top = blurred[y0 * gw + x0] +
            (blurred[y0 * gw + x1] - blurred[y0 * gw + x0]) * fx;
        final bottom = blurred[y1 * gw + x0] +
            (blurred[y1 * gw + x1] - blurred[y1 * gw + x0]) * fx;
        mask[y * w + x] = (top + (bottom - top) * fy).round().clamp(0, 255);
      }
    }
    return mask;
  }

  /// Maskenin resim sayılan oranı (0..1) — "sayfanın ne kadarı resim".
  static double pictureShare(Uint8List mask) {
    if (mask.isEmpty) return 0;
    var sum = 0;
    for (final v in mask) {
      sum += v;
    }
    return sum / (mask.length * 255);
  }

  /// Blok ızgarasını temizler (yerinde): tek kalan bloğu atar, derli toplu
  /// bölgeyi dış dikdörtgenine tamamlar, bir blok genişletir.
  static void _cleanPictureGrid(Uint8List grid, int gw, int gh) {
    // 1) Komşusuz blok gürültüdür (koyu bir başlık harfi, mühür köşesi).
    final keep = Uint8List(grid.length);
    for (var y = 0; y < gh; y++) {
      for (var x = 0; x < gw; x++) {
        if (grid[y * gw + x] == 0) continue;
        var neighbours = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) continue;
            if (grid[ny * gw + nx] != 0) neighbours++;
          }
        }
        if (neighbours >= 2) keep[y * gw + x] = 1;
      }
    }

    // 2) Bağlı bölgeler: derli topluysa (dış dikdörtgeninin en az %35'i)
    // dikdörtgene tamamlanır.
    final filled = Uint8List.fromList(keep);
    final seen = Uint8List(grid.length);
    final stack = <int>[];
    for (var start = 0; start < keep.length; start++) {
      if (keep[start] == 0 || seen[start] != 0) continue;
      var size = 0;
      var minX = gw, minY = gh, maxX = -1, maxY = -1;
      stack
        ..clear()
        ..add(start);
      seen[start] = 1;
      while (stack.isNotEmpty) {
        final i = stack.removeLast();
        size++;
        final x = i % gw, y = i ~/ gw;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        for (final d in const [-1, 1]) {
          final nx = x + d;
          if (nx >= 0 && nx < gw) {
            final j = y * gw + nx;
            if (keep[j] != 0 && seen[j] == 0) {
              seen[j] = 1;
              stack.add(j);
            }
          }
          final ny = y + d;
          if (ny >= 0 && ny < gh) {
            final j = ny * gw + x;
            if (keep[j] != 0 && seen[j] == 0) {
              seen[j] = 1;
              stack.add(j);
            }
          }
        }
      }
      final area = (maxX - minX + 1) * (maxY - minY + 1);
      if (size >= 4 && size >= area * 0.35) {
        for (var y = minY; y <= maxY; y++) {
          filled.fillRange(y * gw + minX, y * gw + maxX + 1, 1);
        }
      }
    }

    // 3) Bir blok genişlet: fotoğrafın kenar pikselleri blok sınırına denk
    // gelmez, yarım kalan kenar bloğu da korunsun.
    for (var y = 0; y < gh; y++) {
      for (var x = 0; x < gw; x++) {
        var on = 0;
        for (var dy = -1; dy <= 1 && on == 0; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) continue;
            if (filled[ny * gw + nx] != 0) {
              on = 1;
              break;
            }
          }
        }
        grid[y * gw + x] = on;
      }
    }
  }

  // ── önizleme ─────────────────────────────────────────────────────────────

  /// Filtre seçim levhası için KÜÇÜK önizlemeler (her filtre için JPEG).
  /// Tek izolat çağrısında: görsel bir kez çözülür, küçültülür, her filtre
  /// küçük kopyaya uygulanır. Maske ölçüye göreli olduğu için küçük kopyada
  /// da aynı bölgeleri korur.
  static Map<ScanFilter, Uint8List> previews(ScanPreviewRequest request) {
    final bytes = File(request.sourcePath).readAsBytesSync();
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      image = null;
    }
    if (image == null) return const {};
    if (image.exif.imageIfd.hasOrientation &&
        image.exif.imageIfd.orientation != 1) {
      image = img.bakeOrientation(image);
    }
    final long = math.max(image.width, image.height);
    if (long > request.longEdge) {
      final ratio = request.longEdge / long;
      image = img.copyResize(image,
          width: (image.width * ratio).round(),
          height: (image.height * ratio).round(),
          interpolation: img.Interpolation.average);
    }
    return {
      for (final filter in ScanFilter.values)
        filter: img.encodeJpg(
            filter == ScanFilter.original ? image : applyToImage(image, filter),
            quality: 82),
    };
  }

  static img.Image _grayToImage(Uint8List gray, int w, int h) {
    final rgb = Uint8List(gray.length * 3);
    for (var i = 0, j = 0; i < gray.length; i++, j += 3) {
      rgb[j] = rgb[j + 1] = rgb[j + 2] = gray[i];
    }
    return img.Image.fromBytes(
        width: w, height: h, bytes: rgb.buffer, numChannels: 3);
  }

  // ── saf adımlar (birim testli) ───────────────────────────────────────────

  /// Aydınlatma düzeltme: her piksel yerel zeminine bölünür (gölge giderme).
  ///
  /// `out = 255 * piksel / zemin`. Zemin karanlıksa (gerçekten siyah bir alan)
  /// bölme patlar; alt sınır 32 ile korunuyor.
  static Uint8List flattenIllumination(
      Uint8List gray, int w, int h, int radius) {
    final background = DocEdges.boxBlur(gray, w, h, radius);
    final out = Uint8List(gray.length);
    for (var i = 0; i < gray.length; i++) {
      final bg = background[i] < 32 ? 32 : background[i];
      final value = (gray[i] * 255) ~/ bg;
      out[i] = value > 255 ? 255 : value;
    }
    return out;
  }

  /// %2–%98 yüzdeliklerine göre kontrast gerdirme.
  static Uint8List stretchContrast(Uint8List gray,
      {double low = 0.02, double high = 0.98}) {
    final lo = DocEdges.quantile(gray, low);
    final hi = DocEdges.quantile(gray, high);
    // Neredeyse tek renk bir görselde gerdirme gürültüyü şişirir; dokunma.
    if (hi - lo < 16) return gray;
    final out = Uint8List(gray.length);
    final span = (hi - lo).toDouble();
    for (var i = 0; i < gray.length; i++) {
      final v = ((gray[i] - lo) * 255 / span).round();
      out[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
    }
    return out;
  }

  /// Keskinleştirme maskesi: `out = piksel + amount · (piksel − bulanık)`.
  static Uint8List sharpen(Uint8List gray, int w, int h, double amount) {
    final blur = DocEdges.boxBlur(gray, w, h, 1);
    final out = Uint8List(gray.length);
    for (var i = 0; i < gray.length; i++) {
      final v = (gray[i] + amount * (gray[i] - blur[i])).round();
      out[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
    }
    return out;
  }

  /// Uyarlamalı eşikleme (yerel ortalama − [bias]).
  ///
  /// Yerel ortalamadan **belirgin biçimde** koyu olan piksel siyah olur.
  /// [bias] olmadan düz beyaz bir alanda gürültü rastgele siyahlanıyordu
  /// (ortalamanın bir tık altındaki her piksel).
  static Uint8List adaptiveThreshold(Uint8List gray, int w, int h,
      {required int radius, int bias = 10}) {
    final mean = DocEdges.boxBlur(gray, w, h, radius);
    final out = Uint8List(gray.length);
    for (var i = 0; i < gray.length; i++) {
      out[i] = gray[i] < mean[i] - bias ? 0 : 255;
    }
    return out;
  }

  /// Sonuç için benzersiz geçici dosya yolu (aynı yola yazmak Flutter'ın
  /// görsel önbelleğini eski kareyle bırakırdı).
  static Future<String> tempTarget(String sourcePath, ScanFilter filter) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final name = '${ScanPageOps.shortBase(sourcePath)}'
        '_${filter.name}_$stamp.jpg';
    return p.join(dir.path, name);
  }
}
