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

  /// **Renkli-canlı** (Faz 35): otomatik + doygunluk artışı — renkli
  /// broşür, harita, çocuk çizimi soluk çıkmasın.
  vivid,

  /// **Gölge-sil** (Faz 35): otomatik + açık zemin tam beyaza çekilir — el
  /// gölgesi, beyaz tahta yansıması ve kâğıt sarılığı kalmaz; mürekkep rengi
  /// korunur.
  shadowless,
}

extension ScanFilterLabel on ScanFilter {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey` deseni).
  String get labelKey => switch (this) {
        ScanFilter.original => 'scan.filter_original',
        ScanFilter.auto => 'scan.filter_auto',
        ScanFilter.gray => 'scan.filter_gray',
        ScanFilter.blackWhite => 'scan.filter_bw',
        ScanFilter.vivid => 'scan.filter_vivid',
        ScanFilter.shadowless => 'scan.filter_shadowless',
      };

  /// Önizleme kartının altına sığan kısa ad.
  String get shortLabelKey => switch (this) {
        ScanFilter.original => 'scan.short_original',
        ScanFilter.auto => 'scan.short_auto',
        ScanFilter.gray => 'scan.short_gray',
        ScanFilter.blackWhite => 'scan.short_bw',
        ScanFilter.vivid => 'scan.short_vivid',
        ScanFilter.shadowless => 'scan.short_shadowless',
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
/// ## Boru hattı (2026-11-12 yeniden yazım)
/// 1. **Kâğıt zemini** kanal başına: küçük hücrelerin %85'lik dilimi +
///    morfolojik kapama (mürekkep zemine karışmaz) → her piksel kendi
///    zeminine bölünür. Gölge, vinyet, lamba sarısı kalkar.
/// 2. **Resim bölgeleri** ([pictureMask]) düzeltmenin dışında tutulur.
/// 3. **Bulanıklığa göre netleştirme** ([sharpenText], `adaptive`).
/// 4. **Ton eğrisi**: kâğıt tam beyaza, mürekkep koyuya; beyaz noktası derin
///    gölgede aşağı çekilir (büyümüş gürültü benek bırakmasın).
/// 5. (Yalnız [ScanFilter.blackWhite]) **Uyarlamalı eşikleme**.
///
/// Saf `image` paketi (platform kodu yok) → izolatta koşar, birim testlenir.
abstract final class ScanEnhance {
  /// Zemin kestirimi için bulanıklaştırma yarıçapı — görselin kısa kenarının
  /// oranı. Harf kalınlığından çok daha büyük olmalı (yoksa harfin kendisi
  /// zemin sanılıp silinir), sayfadan küçük olmalı (yoksa gölgeyi göremez).
  static const backgroundRadiusRatio = 0.06;

  /// Tek geçişli eski keskinleştirme miktarı (yalnız [sharpen] çağıranlar
  /// için; boru hattı artık [sharpenText] kullanır).
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
    final n = w * h;

    final rgb = source.getBytes(order: img.ChannelOrder.rgb);
    final gray = Uint8List(n);
    final hists = [Int32List(256), Int32List(256), Int32List(256)];
    for (var i = 0, j = 0; i < n; i++, j += 3) {
      final r = rgb[j], g = rgb[j + 1], b = rgb[j + 2];
      hists[0][r]++;
      hists[1][g]++;
      hists[2][b]++;
      gray[i] = (r * 0.299 + g * 0.587 + b * 0.114).round().clamp(0, 255);
    }
    final paperLevel = DocEdges.quantile(gray, 0.9);
    // Sayfanın en açık onda biri bile koyuysa ortada kâğıt yok (koyu bir
    // fotoğraf, gece çekimi): hiçbir yerine dokunulmaz.
    if (paperLevel < 110) {
      return filter == ScanFilter.auto ||
              filter == ScanFilter.vivid ||
              filter == ScanFilter.shadowless
          ? source
          : _grayToImage(gray, w, h);
    }
    final paper = [for (final hist in hists) _histQuantile(hist, n, 0.9)];

    // 1) KÂĞIT ZEMİNİ, kanal başına (2026-11-12 yeniden yazım). Eski yol
    // zemini büyük yarıçaplı ORTALAMAYLA kestiriyordu: ortalamaya mürekkep de
    // girdiği için yoğun yazının çevresi kararıyor, sert gölge kenarında hale
    // kalıyordu. Şimdi küçük hücrelerin %85'lik dilimi (mürekkep dışarıda)
    // alınıp morfolojik KAPAMA ile yazı boşlukları doldurulur → zemin yalnız
    // kâğıdın (gölgesiyle birlikte) parlaklığıdır.
    final bg = _PaperBackground.estimate(rgb, 3, w, h);

    // Kâğıt rengi belirgin renkliyse (pembe form, sarı dosya kâğıdı) renk
    // sapması SİLİNMEZ: yalnız parlaklık düzeltilir. Sıradan sarımsı lamba
    // ışığında kanal başına bölme kâğıdı beyaza çeker.
    final hiPaper = paper.reduce(math.max);
    final loPaper = math.max(1, paper.reduce(math.min));
    final perChannel =
        filter == ScanFilter.shadowless || hiPaper / loPaper <= neutralPaperCast;

    final flat = Uint8List(n * 3);
    final flatL = Uint8List(n);
    final fl = Uint8List(n);
    final bgL = Uint8List(n);
    final sampler = _GridSampler(bg, w, h);
    final px = [0, 0, 0];
    for (var y = 0; y < h; y++) {
      sampler.row(y);
      for (var x = 0; x < w; x++) {
        final i = y * w + x, j = i * 3;
        sampler.at(x, px);
        final lum = (px[0] * 299 + px[1] * 587 + px[2] * 114) ~/ 1000;
        bgL[i] = lum;
        final fg = gray[i] * 255 ~/ lum;
        flatL[i] = fg > 255 ? 255 : fg;
        var sum = 0;
        for (var c = 0; c < 3; c++) {
          var v = rgb[j + c] * 255 ~/ (perChannel ? px[c] : lum);
          if (v > 255) v = 255;
          flat[j + c] = v;
          sum += v * (c == 0 ? 299 : (c == 1 ? 587 : 114));
        }
        fl[i] = sum ~/ 1000;
      }
    }

    // 2) RESİM BÖLGELERİ düzeltmenin dışında tutulur (2026-10-18).
    final picture = _pictureMaskFrom(
        DocEdges.boxBlur(flatL, w, h, 1), w, h, bg, paper, paperLevel);

    // 3) Bulanıklığa göre ayarlanan yazı netleştirme (parlaklık üstünde).
    final sharp = sharpenText(fl, w, h, adaptive: true);

    // 4) Ton eğrisi: kâğıt tam beyaza, mürekkep koyuya. Beyaz noktası derin
    // gölgede (büyük kazanç = büyümüş gürültü) biraz aşağı çekilir — yoksa
    // gölgenin olduğu yer benekli gri kalıyordu.
    final hist = Int32List(256);
    var counted = 0;
    for (var i = 0; i < n; i++) {
      if (picture[i] < 128) {
        hist[fl[i]]++;
        counted++;
      }
    }
    final bp =
        counted == 0 ? 12 : _histQuantile(hist, counted, 0.01).clamp(12, 110).toInt();
    final wp0 = filter == ScanFilter.shadowless ? 0.80 : 0.90;
    final wpLut = Int32List(256);
    for (var v = 0; v < 256; v++) {
      final gain = 255 / math.max(1, v);
      final t = ((gain - 1.3) / 1.7).clamp(0.0, 1.0);
      wpLut[v] = ((wp0 - 0.14 * t) * 255).round();
    }
    final curve = Uint8List(256);
    for (var v = 0; v < 256; v++) {
      curve[v] = (255 * math.pow(v / 255, toneGamma)).round().clamp(0, 255);
    }

    if (filter == ScanFilter.gray || filter == ScanFilter.blackWhite) {
      final toned = Uint8List(n);
      for (var i = 0; i < n; i++) {
        final wp = wpLut[bgL[i]];
        final t = (sharp[i] - bp) * 255 ~/ (wp - bp);
        toned[i] = curve[t < 0 ? 0 : (t > 255 ? 255 : t)];
      }
      if (filter == ScanFilter.gray) {
        return _grayToImage(blend(toned, gray, picture), w, h);
      }
      final bw = adaptiveThreshold(toned, w, h,
          radius: math.max(6, (math.min(w, h) * 0.02).round()), bias: 10);
      // Resim bölgesi eşiklenmez, GRİ kalır (masaüstü tarayıcıların "karma"
      // modu): eşiklenmiş fotoğraf siyah-beyaz karıncalanmaya dönüyordu.
      return _grayToImage(blend(bw, gray, picture), w, h);
    }

    final out = Uint8List(n * 3);
    final vivid = filter == ScanFilter.vivid;
    for (var i = 0, j = 0; i < n; i++, j += 3) {
      final m = picture[i];
      if (m == 255) {
        out[j] = rgb[j];
        out[j + 1] = rgb[j + 1];
        out[j + 2] = rgb[j + 2];
        continue;
      }
      final d = sharp[i] - fl[i];
      final span = wpLut[bgL[i]] - bp;
      var r = (flat[j] + d - bp) * 255 ~/ span;
      var g = (flat[j + 1] + d - bp) * 255 ~/ span;
      var b = (flat[j + 2] + d - bp) * 255 ~/ span;
      r = curve[r < 0 ? 0 : (r > 255 ? 255 : r)];
      g = curve[g < 0 ? 0 : (g > 255 ? 255 : g)];
      b = curve[b < 0 ? 0 : (b > 255 ? 255 : b)];
      if (vivid) {
        final l = (r * 299 + g * 587 + b * 114) ~/ 1000;
        r = (l + (r - l) * vividGain).round();
        g = (l + (g - l) * vividGain).round();
        b = (l + (b - l) * vividGain).round();
      }
      if (m != 0) {
        r = (r * (255 - m) + rgb[j] * m) ~/ 255;
        g = (g * (255 - m) + rgb[j + 1] * m) ~/ 255;
        b = (b * (255 - m) + rgb[j + 2] * m) ~/ 255;
      }
      out[j] = r < 0 ? 0 : (r > 255 ? 255 : r);
      out[j + 1] = g < 0 ? 0 : (g > 255 ? 255 : g);
      out[j + 2] = b < 0 ? 0 : (b > 255 ? 255 : b);
    }
    return img.Image.fromBytes(
        width: w, height: h, bytes: out.buffer, numChannels: 3);
  }

  /// Kâğıdın en parlak/en sönük kanalı oranı bunun altındaysa kâğıt "beyaz"
  /// sayılır ve renk sapması (lamba sarısı) silinir.
  static const neutralPaperCast = 1.45;

  /// Ton eğrisinin üssü: > 1 → ara tonlar (soluk/bulanık mürekkep) koyulaşır.
  static const toneGamma = 1.15;

  /// Renkli-canlı filtrede renk sapmasının ek çarpanı (doygunluk artışı).
  static const vividGain = 1.45;

  static int _histQuantile(Int32List hist, int count, double q) {
    final target = (count * q).ceil();
    var seen = 0;
    for (var v = 0; v < 256; v++) {
      seen += hist[v];
      if (seen >= target) return v;
    }
    return 255;
  }

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
  /// **2026-11-12 yeniden yazım** (kullanıcı: *"tarama aşırı kötüleştiriyor"*
  /// — yazının üstünde gri bulanık kutular, gölgenin yerinde benekli leke).
  /// Kök neden: eski ölçü HAM görüntüde "ara ton oranı"na bakıyordu; bulanık
  /// el yazısının kenarları ve gölge geçişi ara tonla doludur → yazı bloğu
  /// "fotoğraf" sanılıp düzeltmenin dışında (karanlık ve bulanık) kalıyordu.
  /// Şimdi ölçü ZEMİNE BÖLÜNMÜŞ görüntüde yapılır: gölgedeki kâğıt da
  /// beyazdır, yazı bloğunun çoğu kâğıttır. Bir blok ancak şu durumlarda
  /// resimdir:
  ///  * kâğıdı az (< %35) VE ara tonu çok (> %40) — dokulu fotoğraf;
  ///  * zemininin rengi sayfanın kâğıt renginden belirgin sapıyor (gökyüzü,
  ///    renkli kutu) — gölge renk ORANINI bozmaz, renkli alan bozar;
  ///  * çok koyu ve yazısız düz alan (koyu fotoğraf zemini).
  ///
  /// Sonra temizlik: tek başına kalan blok atılır; derli toplu bölge dış
  /// dikdörtgenine tamamlanır ve bir blok genişletilir.
  static Uint8List pictureMask(Uint8List gray, int w, int h, {Uint8List? rgb}) {
    if (w < 16 || h < 16) return Uint8List(w * h);
    final paperLevel = DocEdges.quantile(gray, 0.9);
    if (paperLevel < 110) {
      return Uint8List(w * h)..fillRange(0, w * h, 255);
    }
    final _PaperBackground bg;
    final List<int> paper;
    if (rgb == null) {
      bg = _PaperBackground.estimate(gray, 1, w, h);
      paper = [paperLevel, paperLevel, paperLevel];
    } else {
      bg = _PaperBackground.estimate(rgb, 3, w, h);
      final hists = [Int32List(256), Int32List(256), Int32List(256)];
      for (var j = 0; j < rgb.length; j += 3) {
        hists[0][rgb[j]]++;
        hists[1][rgb[j + 1]]++;
        hists[2][rgb[j + 2]]++;
      }
      paper = [for (final hist in hists) _histQuantile(hist, w * h, 0.9)];
    }
    final flatL = Uint8List(w * h);
    final sampler = _GridSampler(bg, w, h);
    final px = [0, 0, 0];
    for (var y = 0; y < h; y++) {
      sampler.row(y);
      for (var x = 0; x < w; x++) {
        sampler.at(x, px);
        final lum = (px[0] * 299 + px[1] * 587 + px[2] * 114) ~/ 1000;
        final v = gray[y * w + x] * 255 ~/ lum;
        flatL[y * w + x] = v > 255 ? 255 : v;
      }
    }
    return _pictureMaskFrom(
        DocEdges.boxBlur(flatL, w, h, 1), w, h, bg, paper, paperLevel);
  }

  /// [flat]: zemine bölünmüş (ve gürültüsü hafifçe yumuşatılmış) parlaklık.
  static Uint8List _pictureMaskFrom(Uint8List flat, int w, int h,
      _PaperBackground bg, List<int> paper, int paperLevel) {
    final mask = Uint8List(w * h);
    if (w < 16 || h < 16) return mask;
    final block = math.max(6, (math.min(w, h) / 48).round());
    final gw = (w + block - 1) ~/ block;
    final gh = (h + block - 1) ~/ block;
    final grid = Uint8List(gw * gh);
    // Büyük blokta her piksele bakmak gereksiz: ikişer atlanır.
    final step = block >= 12 ? 2 : 1;
    var any = false;
    for (var by = 0; by < gh; by++) {
      for (var bx = 0; bx < gw; bx++) {
        final x0 = bx * block, y0 = by * block;
        final x1 = math.min(w, x0 + block), y1 = math.min(h, y0 + block);
        var count = 0, paperLike = 0, ink = 0;
        for (var y = y0; y < y1; y += step) {
          final row = y * w;
          for (var x = x0; x < x1; x += step) {
            final v = flat[row + x];
            count++;
            if (v >= 204) {
              paperLike++;
            } else if (v < 140) {
              ink++;
            }
          }
        }
        if (count == 0) continue;
        final mid = (count - paperLike - ink) / count;
        // Bloğun ortasındaki zemin (kanal başına).
        final cx = math.min(bg.gw - 1, ((x0 + x1) ~/ 2) ~/ bg.cell);
        final cy = math.min(bg.gh - 1, ((y0 + y1) ~/ 2) ~/ bg.cell);
        final at = cy * bg.gw + cx;
        var hi = 0.0, lo = double.infinity, lum = 0;
        for (var c = 0; c < 3; c++) {
          final v = bg.grids[c][at];
          final ratio = v / math.max(1, paper[c]);
          if (ratio > hi) hi = ratio;
          if (ratio < lo) lo = ratio;
          lum += v * (c == 0 ? 299 : (c == 1 ? 587 : 114));
        }
        lum ~/= 1000;
        final colored = hi / math.max(0.001, lo) > 1.6;
        final veryDark = lum < paperLevel * 0.25 && ink < count * 0.05;
        if ((mid > 0.40 && paperLike < count * 0.35) || colored || veryDark) {
          grid[by * gw + bx] = 1;
          any = true;
        }
      }
    }
    if (!any) return mask;

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

  /// **Yazı netleştirme** (2026-11-10, kullanıcı: *"taramada otomatik
  /// netleştirme yok ya da iyi değil"*). Eski tek geçişli maske (yarıçap 1,
  /// 0,8) 2480 px'e indirilmiş telefon çekiminde neredeyse görünmüyordu:
  /// kamera yumuşaklığı 2–3 piksele yayılıyor, 3×3 bulanık fark onu
  /// yakalamıyor. Şimdi:
  ///  1. **İki ölçek**: ince (yarıçap 1) + orta (yarıçap 2) fark birlikte
  ///     eklenir → hem harf kenarı hem harf gövdesi toparlanır.
  ///  2. **Gürültü eşiği**: küçük farklar (kâğıt dokusu, sensör gürültüsü,
  ///     JPEG kırıntısı) keskinleştirilmez → "kirli" sayfa olmaz.
  ///  3. **Hale sınırı**: sonuç 3×3 komşuluğun en küçük/en büyük değerinden
  ///     en çok [haloMargin] taşabilir → harf çevresinde beyaz/siyah çember
  ///     oluşmaz, güçlü miktar güvenle kullanılır.
  static Uint8List sharpenText(Uint8List gray, int w, int h,
      {bool adaptive = false}) {
    final b1 = DocEdges.boxBlur(gray, w, h, 1);
    final b2 = DocEdges.boxBlur(gray, w, h, 2);
    // Bulanıklık ölçüsü (0 = net, 1 = bulanık). 2026-11-12, kullanıcı:
    // *"bulanıklık giderme yok"*. Net bir kenarda ince fark (yarıçap 1) orta
    // farkın (yarıçap 2) ~%75'idir; kenar birkaç piksele yayıldıkça oran
    // düşer. Bulanık sayfada üçüncü, KABA ölçek (yarıçap 4) devreye girer ve
    // hale sınırı 5×5 komşuluğa genişler — yoksa sınır, yayılmış kenarın
    // dikleşmesine izin vermiyordu.
    var blurry = 0.0;
    if (adaptive) {
      var s1 = 0, s2 = 0, edges = 0;
      for (var i = 0; i < gray.length; i++) {
        final d2 = (gray[i] - b2[i]).abs();
        if (d2 > 12) {
          s1 += (gray[i] - b1[i]).abs();
          s2 += d2;
          edges++;
        }
      }
      if (edges > 50 && s2 > 0) {
        blurry = ((0.72 - s1 / s2) / 0.25).clamp(0.0, 1.0);
      }
    }
    final b4 = blurry > 0 ? DocEdges.boxBlur(gray, w, h, 4) : null;
    var lo = _minMax3(gray, w, h, min: true);
    var hi = _minMax3(gray, w, h, min: false);
    if (blurry >= 0.5) {
      lo = _minMax3(lo, w, h, min: true);
      hi = _minMax3(hi, w, h, min: false);
    }
    final margin = haloMargin + (14 * blurry).round();
    final coarse = coarseAmount * blurry;
    final out = Uint8List(gray.length);
    for (var i = 0; i < gray.length; i++) {
      final g = gray[i];
      var d1 = g - b1[i];
      var d2 = g - b2[i];
      if (d1.abs() < fineNoise) d1 = 0;
      if (d2.abs() < mediumNoise) d2 = 0;
      var sum = g + fineAmount * d1 + mediumAmount * d2;
      if (b4 != null) {
        final d4 = g - b4[i];
        if (d4.abs() >= coarseNoise) sum += coarse * d4;
      }
      var v = sum.round();
      final floor = lo[i] - margin, ceil = hi[i] + margin;
      if (v < floor) v = floor;
      if (v > ceil) v = ceil;
      out[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
    }
    return out;
  }

  static const fineAmount = 0.9;
  static const mediumAmount = 0.7;
  static const coarseAmount = 0.9;
  static const fineNoise = 3;
  static const mediumNoise = 4;
  static const coarseNoise = 6;
  static const haloMargin = 10;

  /// 3×3 komşuluk en küçüğü/en büyüğü (ayrılabilir: önce satır, sonra sütun).
  static Uint8List _minMax3(Uint8List g, int w, int h, {required bool min}) {
    final tmp = Uint8List(g.length);
    for (var y = 0; y < h; y++) {
      final row = y * w;
      for (var x = 0; x < w; x++) {
        var v = g[row + x];
        if (x > 0) {
          final o = g[row + x - 1];
          if (min ? o < v : o > v) v = o;
        }
        if (x < w - 1) {
          final o = g[row + x + 1];
          if (min ? o < v : o > v) v = o;
        }
        tmp[row + x] = v;
      }
    }
    final out = Uint8List(g.length);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        var v = tmp[i];
        if (y > 0) {
          final o = tmp[i - w];
          if (min ? o < v : o > v) v = o;
        }
        if (y < h - 1) {
          final o = tmp[i + w];
          if (min ? o < v : o > v) v = o;
        }
        out[i] = v;
      }
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

/// Kâğıt zemini kestirimi: küçük hücre ızgarası, kanal başına.
class _PaperBackground {
  final int cell, gw, gh;

  /// Üç kanal (gri girdide üçü de aynı liste).
  final List<Uint8List> grids;

  const _PaperBackground(this.cell, this.gw, this.gh, this.grids);

  /// [src] [stride] kanallı (1 = gri, 3 = RGB) görüntü.
  static _PaperBackground estimate(Uint8List src, int stride, int w, int h) {
    final shortEdge = math.min(w, h);
    final cell = math.max(2, (shortEdge / 200).round());
    // Kapama yarıçapı ≈ kısa kenarın %4'ü: harf ve satırdan büyük (mürekkep
    // zemine sızmaz), gölgeden küçük.
    final radius = math.max(2, (shortEdge * 0.04 / cell).round());
    final gw = (w + cell - 1) ~/ cell;
    final gh = (h + cell - 1) ~/ cell;
    final grids = <Uint8List>[];
    for (var c = 0; c < stride; c++) {
      var grid = _cellQuantile(src, stride, c, w, h, cell, gw, gh);
      grid = _morph(grid, gw, gh, radius, max: true);
      grid = _morph(grid, gw, gh, radius, max: false);
      grid = DocEdges.boxBlur(grid, gw, gh, 1);
      for (var i = 0; i < grid.length; i++) {
        // Zemin gerçekten siyahsa bölme patlamasın.
        if (grid[i] < 24) grid[i] = 24;
      }
      grids.add(grid);
    }
    while (grids.length < 3) {
      grids.add(grids.first);
    }
    return _PaperBackground(cell, gw, gh, grids);
  }

  /// Hücre başına %85'lik dilim: hücrenin kâğıt tonu (mürekkep dışarıda,
  /// tek bir parlama pikseli de sonucu belirlemez).
  static Uint8List _cellQuantile(Uint8List src, int stride, int offset, int w,
      int h, int cell, int gw, int gh) {
    final out = Uint8List(gw * gh);
    final hist = Int32List(256);
    for (var by = 0; by < gh; by++) {
      final y0 = by * cell, y1 = math.min(h, y0 + cell);
      for (var bx = 0; bx < gw; bx++) {
        final x0 = bx * cell, x1 = math.min(w, x0 + cell);
        hist.fillRange(0, 256, 0);
        var count = 0;
        for (var y = y0; y < y1; y++) {
          var i = (y * w + x0) * stride + offset;
          for (var x = x0; x < x1; x++, i += stride) {
            hist[src[i]]++;
            count++;
          }
        }
        final target = (count * 0.85).ceil();
        var seen = 0, value = 255;
        for (var v = 0; v < 256; v++) {
          seen += hist[v];
          if (seen >= target) {
            value = v;
            break;
          }
        }
        out[by * gw + bx] = value;
      }
    }
    return out;
  }

  /// Ayrılabilir en büyük/en küçük süzgeci (kenar dışı yok sayılır).
  static Uint8List _morph(Uint8List g, int gw, int gh, int r,
      {required bool max}) {
    final tmp = Uint8List(g.length);
    for (var y = 0; y < gh; y++) {
      final row = y * gw;
      for (var x = 0; x < gw; x++) {
        final a = x - r < 0 ? 0 : x - r;
        final b = x + r >= gw ? gw - 1 : x + r;
        var v = g[row + a];
        for (var k = a + 1; k <= b; k++) {
          final o = g[row + k];
          if (max ? o > v : o < v) v = o;
        }
        tmp[row + x] = v;
      }
    }
    final out = Uint8List(g.length);
    for (var x = 0; x < gw; x++) {
      for (var y = 0; y < gh; y++) {
        final a = y - r < 0 ? 0 : y - r;
        final b = y + r >= gh ? gh - 1 : y + r;
        var v = tmp[a * gw + x];
        for (var k = a + 1; k <= b; k++) {
          final o = tmp[k * gw + x];
          if (max ? o > v : o < v) v = o;
        }
        out[y * gw + x] = v;
      }
    }
    return out;
  }
}

/// Zemin ızgarasını piksele çift doğrusal büyütür (satır satır).
class _GridSampler {
  final _PaperBackground bg;
  final Int32List _x0, _x1, _fx;
  int _r0 = 0, _r1 = 0, _fy = 0;

  _GridSampler(this.bg, int w, int h)
      : _x0 = Int32List(w),
        _x1 = Int32List(w),
        _fx = Int32List(w) {
    for (var x = 0; x < w; x++) {
      final gx = (x + 0.5) / bg.cell - 0.5;
      final ix = gx.floor();
      _x0[x] = ix.clamp(0, bg.gw - 1);
      _x1[x] = (ix + 1).clamp(0, bg.gw - 1);
      _fx[x] = ((gx - ix) * 256).round();
    }
  }

  void row(int y) {
    final gy = (y + 0.5) / bg.cell - 0.5;
    final iy = gy.floor();
    _r0 = iy.clamp(0, bg.gh - 1) * bg.gw;
    _r1 = (iy + 1).clamp(0, bg.gh - 1) * bg.gw;
    _fy = ((gy - iy) * 256).round();
  }

  /// [x] sütunundaki üç kanalın zeminini [out]'a yazar (en az 24).
  void at(int x, List<int> out) {
    final x0 = _x0[x], x1 = _x1[x], fx = _fx[x];
    for (var c = 0; c < 3; c++) {
      final g = bg.grids[c];
      final top = g[_r0 + x0] * (256 - fx) + g[_r0 + x1] * fx;
      final bottom = g[_r1 + x0] * (256 - fx) + g[_r1 + x1] * fx;
      final v = (top * (256 - _fy) + bottom * _fy) >> 16;
      out[c] = v < 24 ? 24 : v;
    }
  }
}
