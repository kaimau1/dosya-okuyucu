import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'scan_enhance.dart' show ScanEnhance;

/// **Metne bakarak** sayfa düzleştirme: eğimi (skew) ve kitap kıvrımını
/// (bombe) düzeltir.
///
/// ## Niye [ScanDeskew] yetmedi (2026-08-06 kullanıcı bulgusu)
/// Var olan düzeltme **kâğıdın kenarını** arıyor (`DocEdges` → dörtgen →
/// perspektif). Kullanıcının kendi kitabını çektiği sayfalarda kenar ya
/// kadrajın dışında ya da zeminle aynı renkte: dörtgen bulunamıyor, sayfa
/// eğik kalıyordu. Ekran görüntüsünde satırlar sağa doğru belirgin biçimde
/// iniyordu ve OCR bu yüzden zorlanıyordu ("metinleri tanımakta zorlanıyor").
/// Ayrıca kitap ciltten kalkık durduğu için satırlar **düz değil, kavisli**
/// çıkıyor — kenar tespiti bunu hiçbir zaman düzeltemez, çünkü sorun kâğıdın
/// kenarında değil yüzeyinde.
///
/// Bu modül kâğıda değil **yazının kendisine** bakar; kenar görünmese de
/// çalışır:
/// 1. Sayfa küçültülüp uyarlamalı eşiklemeyle mürekkep haritası çıkarılır.
/// 2. **Eğim**: sayfa denenen her açıyla eğilir ve satır izdüşüm profilinin
///    "sivriliği" (kareler toplamı) ölçülür. Satırlar yatayla hizalandığı anda
///    mürekkep birkaç satıra toplanır → profil sivrilir. En sivri açı eğimdir.
///    (Kaba ±12° tarama, sonra 0,1° çözünürlükle ince ayar.)
/// 3. **Bombe**: sayfa dikey şeritlere bölünür, komşu şeritlerin satır
///    profilleri çapraz ilinti ile hizalanır → her şeridin ne kadar aşağıda
///    kaldığı bulunur. Sütun başına dikey kaydırma alanı bundan kurulur ve
///    görüntü bu alanla yeniden örneklenir; kavisli satırlar düzleşir.
///
/// **İlke — emin değilsen dokunma.** Yanlış düzeltme, düzeltmemekten kötüdür
/// (DocEdges ilkesi). Mürekkep yoksa, satır bulunamazsa, ölçülen eğim
/// gürültü düzeyindeyse ya da kıvrım kayda değer değilse sayfa OLDUĞU GİBİ
/// kalır ve `null` dönülür.
abstract final class ScanDewarp {
  /// Ölçüm için küçültme hedefi (uzun kenar). Eğim/kıvrım kestirimi için
  /// 1000 px fazlasıyla yeter; tam çözünürlükte ölçmek yalnız yavaşlatır.
  static const measureLongEdge = 1000;

  /// Uygulanmaya değer en küçük eğim (derece). Altındaki açı ölçüm gürültüsü
  /// sayılır ve sayfa yeniden örneklenmez (her yeniden örnekleme bir tık
  /// yumuşama demek).
  static const minSkewDegrees = 0.25;

  /// Aranan en büyük eğim (derece). Daha fazlası artık "eğik tarama" değil,
  /// bilerek yan çevrilmiş sayfadır — ona karışmıyoruz.
  static const maxSkewDegrees = 12.0;

  /// Kıvrım ölçümünde sayfanın bölündüğü dikey şerit sayısı.
  static const bandCount = 12;

  /// Kıvrımın uygulanmaya değer sayılması için gereken en küçük tepe-tepe
  /// kayma — sayfa yüksekliğinin oranı olarak.
  static const minCurveRatio = 0.006;

  // ── izolat girişi ────────────────────────────────────────────────────────

  /// `compute` ile çağrılmak üzere tek argümanlı giriş: [request.sourcePath]
  /// düzleştirilebiliyorsa [request.targetPath]'e yazılır ve o yol döner;
  /// dokunmaya değmiyorsa **null** (kaynak dosya olduğu gibi kullanılır).
  static String? runRequest(ScanStraightenRequest request) {
    final bytes = File(request.sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final out = straighten(decoded);
    if (out == null) return null;
    File(request.targetPath)
        .writeAsBytesSync(img.encodeJpg(out, quality: ScanEnhance.jpegQuality),
            flush: true);
    return request.targetPath;
  }

  /// Sonuç için benzersiz geçici dosya yolu (aynı yola yazmak Flutter'ın
  /// görsel önbelleğini eski kareyle bırakır — `writeTempPng` ile aynı gerekçe).
  static Future<String> tempTarget(String sourcePath) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return p.join(dir.path,
        '${p.basenameWithoutExtension(sourcePath)}_duzlestirildi_$stamp.jpg');
  }

  // ── ana boru hattı ───────────────────────────────────────────────────────

  /// [source]'u düzleştirir; dokunmaya değmiyorsa null.
  static img.Image? straighten(img.Image image) {
    // Çıktı boyutu filtre borusunun sınırına ([ScanEnhance.maxLongEdge])
    // baştan çekilir. Filtre zaten aynı yere küçültüyor; burada küçültmek
    // yeniden örnekleme işini (12 MP → 8,7 MP) belirgin kısaltıyor ve hiçbir
    // ayrıntı kaybettirmiyor.
    final source = _cap(image, ScanEnhance.maxLongEdge);
    final measure = _downscaleGray(source, measureLongEdge);
    final ink = inkMap(measure.gray, measure.width, measure.height);
    // Mürekkep oranı çok düşük (boş sayfa) ya da çok yüksek (fotoğraf/koyu
    // zemin) ise satır kavramı yok demektir.
    final ratio = _inkRatio(ink);
    if (ratio < 0.005 || ratio > 0.45) return null;

    final skew = estimateSkewDegrees(ink, measure.width, measure.height);
    var result = source;
    var changed = false;
    if (skew.abs() >= minSkewDegrees) {
      // Ölçülen eğim +4° ise sayfa 4° SAAT YÖNÜNDE dönmüş demektir; düzeltme
      // ters yöndedir. (Bu işaret bir kez ters yazıldı ve testte yakalandı:
      // kıvrım adımı kaymayı kesme (shear) ile örtüp sonucu "düzgün"
      // gösterdiği için gözle fark edilmiyordu.)
      result = rotateWhite(result, -skew);
      changed = true;
    }

    // Kıvrım, eğim düzeltildikten SONRA ölçülür: eğik sayfada şerit
    // profilleri zaten kaymış olur ve kıvrım varmış gibi görünür.
    final second = _downscaleGray(result, measureLongEdge);
    final ink2 = changed
        ? inkMap(second.gray, second.width, second.height)
        : ink;
    final shifts = columnShifts(ink2, second.width, second.height);
    if (shifts != null) {
      result = _applyShifts(result, shifts);
      changed = true;
    }
    return changed ? result : null;
  }

  // ── eğim ─────────────────────────────────────────────────────────────────

  /// [ink] (0 = mürekkep, 255 = kâğıt) haritasından sayfanın eğimini derece
  /// olarak kestirir. Pozitif = satırlar sağa doğru **iniyor**.
  ///
  /// Yöntem: her aday açı için satır izdüşüm profili kurulur ve profilin
  /// kareler toplamı ölçülür. Mürekkep miktarı açıdan bağımsız sabit olduğu
  /// için kareler toplamı ancak mürekkep AZ SAYIDA satıra toplandığında
  /// büyür — yani en büyük değeri veren açı, satırların yatay olduğu açıdır.
  /// (Klasik "projection profile" yöntemi; Hough'a göre hem daha ucuz hem de
  /// harf kenarlarındaki kısa çizgilere kanmıyor.)
  static double estimateSkewDegrees(Uint8List ink, int width, int height) {
    if (width < 16 || height < 16) return 0;
    // Mürekkep noktalarını bir kez topla: aday açı başına tüm görseli
    // dolaşmak yerine yalnız bu noktaları dolaşırız (10× hızlı).
    final xs = <int>[];
    final ys = <int>[];
    for (var y = 0; y < height; y++) {
      final row = y * width;
      for (var x = 0; x < width; x++) {
        if (ink[row + x] == 0) {
          xs.add(x);
          ys.add(y);
        }
      }
    }
    if (xs.length < 64) return 0;

    double scoreAt(double degrees) {
      final slope = math.tan(degrees * math.pi / 180);
      final cx = width / 2;
      final hist = Int32List(height);
      for (var i = 0; i < xs.length; i++) {
        final row = (ys[i] - (xs[i] - cx) * slope).round();
        if (row >= 0 && row < height) hist[row]++;
      }
      var sum = 0.0;
      for (final v in hist) {
        sum += v.toDouble() * v;
      }
      return sum;
    }

    var best = 0.0;
    var bestScore = scoreAt(0);
    for (var d = -maxSkewDegrees; d <= maxSkewDegrees + 1e-9; d += 1.0) {
      final s = scoreAt(d);
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    }
    for (var d = best - 1.0; d <= best + 1.0 + 1e-9; d += 0.1) {
      if (d.abs() > maxSkewDegrees) continue;
      final s = scoreAt(d);
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    }
    return double.parse(best.toStringAsFixed(2));
  }

  /// [source]'u [degrees] kadar döndürür (**pozitif = saat yönü**, ekran
  /// koordinatı: y aşağı) ve boşta kalan köşeleri BEYAZa boyar. Tuval,
  /// dönmüş sayfayı tam kapsayacak kadar büyür — köşe kırpılmaz.
  ///
  /// Eğim gidermek için `-eğim` verilir: pozitif eğim (satırlar sağa iniyor)
  /// sayfanın saat yönünde dönmüş olması demektir.
  ///
  /// `img.copyRotate` kullanılmadı: tuvali büyütürken boşluğu saydam/siyah
  /// bırakıyor — belge taramasında siyah köşe hem çirkin hem OCR'ı bozuyor.
  /// Ayrıca burada ters dönüşümle örnekleme yapıldığı için ara piksel
  /// (bilinear) hesabı bizde kalıyor.
  static img.Image rotateWhite(img.Image source, double degrees) {
    final radians = degrees * math.pi / 180;
    final cos = math.cos(radians).abs();
    final sin = math.sin(radians).abs();
    final w = source.width, h = source.height;
    final outW = (w * cos + h * sin).round();
    final outH = (w * sin + h * cos).round();
    final out = img.Image(width: outW, height: outH, numChannels: 3);

    final cxIn = w / 2, cyIn = h / 2;
    final cxOut = outW / 2, cyOut = outH / 2;
    // Ters dönüşüm: çıktı pikselinin kaynaktaki yeri. Eğim +degrees ise
    // düzeltme −degrees'tir; ters dönüşüm bu yüzden +degrees ile kurulur.
    final c = math.cos(radians), s = math.sin(radians);
    final src = source.getBytes(order: img.ChannelOrder.rgb);
    final dst = out.getBytes(order: img.ChannelOrder.rgb);

    for (var y = 0; y < outH; y++) {
      final dy = y - cyOut;
      for (var x = 0; x < outW; x++) {
        final dx = x - cxOut;
        final sx = c * dx + s * dy + cxIn;
        final sy = -s * dx + c * dy + cyIn;
        final o = (y * outW + x) * 3;
        if (sx < 0 || sy < 0 || sx > w - 1 || sy > h - 1) {
          dst[o] = dst[o + 1] = dst[o + 2] = 255; // kâğıt beyazı
          continue;
        }
        _sampleBilinear(src, w, sx, sy, dst, o);
      }
    }
    return out;
  }

  // ── bombe (kitap kıvrımı) ────────────────────────────────────────────────

  /// Dikey şerit başına **kaydırma** miktarları (ölçüm ölçeğinde piksel);
  /// kıvrım kayda değer değilse null.
  ///
  /// Değerler şeridin içeriğinin referansa göre ne kadar AŞAĞIDA olduğunu
  /// söyler: `+3` = bu şerit 3 piksel aşağı kaymış, düzeltmek için yukarı
  /// çekilmeli.
  ///
  /// Şeritler komşularıyla **çapraz ilinti** ile hizalanır. Niye komşu komşu
  /// (hepsi birden ortadaki şeride değil): kıvrım kenara doğru birikir,
  /// uçtaki şeridin kayması ortadakinden büyük olabilir ve doğrudan
  /// karşılaştırma yanlış satıra kilitlenirdi. Arama penceresi de satır
  /// aralığının yarısından küçük tutuluyor — aksi hâlde bir satır aşağıyı
  /// "mükemmel hizalanma" sanmak işten değil.
  static List<double>? columnShifts(Uint8List ink, int width, int height,
      {int bands = bandCount}) {
    if (width < bands * 4 || height < 32) return null;
    final profiles = <Float64List>[];
    for (var b = 0; b < bands; b++) {
      final from = (width * b) ~/ bands;
      final to = (width * (b + 1)) ~/ bands;
      final profile = Float64List(height);
      for (var y = 0; y < height; y++) {
        final row = y * width;
        var count = 0;
        for (var x = from; x < to; x++) {
          if (ink[row + x] == 0) count++;
        }
        profile[y] = count.toDouble();
      }
      profiles.add(_smooth(profile));
    }

    final spacing = _lineSpacing(profiles[bands ~/ 2]);
    if (spacing == null) return null; // satır düzeni yok (fotoğraf/boş sayfa)
    final maxShift = math.max(2, math.min((spacing * 0.45).round(), height ~/ 12));

    final shifts = List<double>.filled(bands, 0);
    final mid = bands ~/ 2;
    for (var b = mid - 1; b >= 0; b--) {
      final d = _bestOffset(profiles[b], profiles[b + 1], maxShift);
      if (d == null) return null;
      shifts[b] = shifts[b + 1] + d;
    }
    for (var b = mid + 1; b < bands; b++) {
      final d = _bestOffset(profiles[b], profiles[b - 1], maxShift);
      if (d == null) return null;
      shifts[b] = shifts[b - 1] + d;
    }

    // Ortalamayı sıfırla: sayfa topluca kaymasın, yalnız kıvrım düzelsin.
    final mean = shifts.reduce((a, b) => a + b) / bands;
    for (var i = 0; i < bands; i++) {
      shifts[i] -= mean;
    }
    final peak = shifts.reduce(math.max) - shifts.reduce(math.min);
    if (peak < height * minCurveRatio) return null;
    return shifts;
  }

  /// [profile]'ı [reference]'a hizalayan kayma (piksel); ilinti tepe yapmazsa
  /// null. Pozitif = profil referanstan o kadar AŞAĞIDA.
  static double? _bestOffset(
      Float64List profile, Float64List reference, int maxShift) {
    final n = profile.length;
    var bestScore = double.negativeInfinity;
    var best = 0;
    for (var d = -maxShift; d <= maxShift; d++) {
      var score = 0.0;
      for (var y = 0; y < n; y++) {
        final j = y + d;
        if (j < 0 || j >= n) continue;
        score += profile[j] * reference[y];
      }
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    if (bestScore <= 0) return null;
    return best.toDouble();
  }

  /// Satır aralığı (piksel) — profilin öz-ilintisindeki ilk belirgin tepe.
  /// Bulunamazsa null (düzenli satır yok demektir).
  static double? _lineSpacing(Float64List profile) {
    final n = profile.length;
    var mean = 0.0;
    for (final v in profile) {
      mean += v;
    }
    mean /= n;
    if (mean <= 0) return null;
    final centered = Float64List(n);
    for (var i = 0; i < n; i++) {
      centered[i] = profile[i] - mean;
    }
    final maxLag = math.min(n ~/ 3, 120);
    var bestLag = 0;
    var bestScore = 0.0;
    for (var lag = 6; lag <= maxLag; lag++) {
      var score = 0.0;
      for (var i = 0; i + lag < n; i++) {
        score += centered[i] * centered[i + lag];
      }
      if (score > bestScore) {
        bestScore = score;
        bestLag = lag;
      }
    }
    return bestLag == 0 ? null : bestLag.toDouble();
  }

  /// Şerit kaymalarını sütun başına yumuşak bir alana çevirip [source]'u
  /// yeniden örnekler (yalnız DİKEY kayma — yatay düzen bozulmaz).
  static img.Image _applyShifts(img.Image source, List<double> shifts) {
    final w = source.width, h = source.height;
    final bands = shifts.length;
    // Ölçüm küçültülmüş görselde yapıldı; kayma tam çözünürlüğe orantılanır.
    // Ölçüm yüksekliği ile gerçek yükseklik arasındaki oran, uzun kenar
    // sınırından gelir.
    final scale = h / _downscaledHeight(w, h, measureLongEdge);
    final perColumn = Float64List(w);
    for (var x = 0; x < w; x++) {
      // Şerit merkezleri arasında doğrusal geçiş — basamaklı kayma görünür
      // bir "merdiven" bırakırdı.
      final t = (x + 0.5) / w * bands - 0.5;
      final i = t.floor();
      final f = t - i;
      final a = shifts[i.clamp(0, bands - 1)];
      final b = shifts[(i + 1).clamp(0, bands - 1)];
      perColumn[x] = (a + (b - a) * f) * scale;
    }

    final out = img.Image(width: w, height: h, numChannels: 3);
    final src = source.getBytes(order: img.ChannelOrder.rgb);
    final dst = out.getBytes(order: img.ChannelOrder.rgb);
    for (var x = 0; x < w; x++) {
      final shift = perColumn[x];
      for (var y = 0; y < h; y++) {
        final sy = y + shift;
        final o = (y * w + x) * 3;
        if (sy < 0 || sy > h - 1) {
          dst[o] = dst[o + 1] = dst[o + 2] = 255;
          continue;
        }
        _sampleBilinear(src, w, x.toDouble(), sy, dst, o);
      }
    }
    return out;
  }

  // ── yardımcılar ──────────────────────────────────────────────────────────

  /// Uyarlamalı eşikleme ile mürekkep haritası (0 = mürekkep, 255 = kâğıt).
  /// Genel eşik kullanılmıyor: gölgeli köşe komple mürekkep sayılırdı.
  static Uint8List inkMap(Uint8List gray, int w, int h) =>
      ScanEnhance.adaptiveThreshold(
        ScanEnhance.flattenIllumination(
            gray, w, h, math.max(4, (math.min(w, h) * 0.06).round())),
        w,
        h,
        radius: math.max(4, (math.min(w, h) * 0.02).round()),
        bias: 12,
      );

  static double _inkRatio(Uint8List ink) {
    var count = 0;
    for (final v in ink) {
      if (v == 0) count++;
    }
    return count / ink.length;
  }

  /// Uzun kenarı [longEdge]'e indirir (zaten küçükse aynı görsel döner).
  static img.Image _cap(img.Image source, int longEdge) {
    final long = math.max(source.width, source.height);
    if (long <= longEdge) return source;
    final ratio = longEdge / long;
    return img.copyResize(
      source,
      width: (source.width * ratio).round(),
      height: (source.height * ratio).round(),
      interpolation: img.Interpolation.average,
    );
  }

  static ({Uint8List gray, int width, int height}) _downscaleGray(
      img.Image source, int longEdge) {
    final image = _cap(source, longEdge);
    final w = image.width, h = image.height;
    final rgb = image.getBytes(order: img.ChannelOrder.rgb);
    final gray = Uint8List(w * h);
    for (var i = 0, j = 0; i < gray.length; i++, j += 3) {
      gray[i] = (rgb[j] * 0.299 + rgb[j + 1] * 0.587 + rgb[j + 2] * 0.114)
          .round()
          .clamp(0, 255);
    }
    return (gray: gray, width: w, height: h);
  }

  /// [_downscaleGray]'in ürettiği yükseklik — kaymayı ölçekleyebilmek için.
  static double _downscaledHeight(int w, int h, int longEdge) {
    final long = math.max(w, h);
    if (long <= longEdge) return h.toDouble();
    return h * longEdge / long;
  }

  static Float64List _smooth(Float64List profile) {
    final n = profile.length;
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      final a = profile[i == 0 ? 0 : i - 1];
      final b = profile[i];
      final c = profile[i == n - 1 ? n - 1 : i + 1];
      out[i] = (a + 2 * b + c) / 4;
    }
    return out;
  }

  static void _sampleBilinear(
      Uint8List src, int w, double sx, double sy, Uint8List dst, int o) {
    final x0 = sx.floor(), y0 = sy.floor();
    final x1 = x0 + 1, y1 = y0 + 1;
    final fx = sx - x0, fy = sy - y0;
    final maxIndex = src.length ~/ 3 - 1;
    int at(int x, int y) {
      final index = y * w + x;
      return (index < 0 ? 0 : (index > maxIndex ? maxIndex : index)) * 3;
    }

    final p00 = at(x0, y0), p10 = at(x1, y0), p01 = at(x0, y1), p11 = at(x1, y1);
    for (var c = 0; c < 3; c++) {
      final top = src[p00 + c] + (src[p10 + c] - src[p00 + c]) * fx;
      final bottom = src[p01 + c] + (src[p11 + c] - src[p01 + c]) * fx;
      dst[o + c] = (top + (bottom - top) * fy).round().clamp(0, 255);
    }
  }
}

/// İzolata geçen istek (tek argüman kuralı — bkz. `ScanEnhanceRequest`).
class ScanStraightenRequest {
  final String sourcePath;
  final String targetPath;
  const ScanStraightenRequest(
      {required this.sourcePath, required this.targetPath});
}
