import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'doc_edges.dart' show DocEdges;

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
    final radius = math.max(4, (math.min(w, h) * backgroundRadiusRatio).round());

    final rgb = source.getBytes(order: img.ChannelOrder.rgb);
    final gray = Uint8List(w * h);
    for (var i = 0, j = 0; i < gray.length; i++, j += 3) {
      gray[i] = (rgb[j] * 0.299 + rgb[j + 1] * 0.587 + rgb[j + 2] * 0.114)
          .round()
          .clamp(0, 255);
    }

    // 1-3: gri kanal üstünde tüm düzeltmeler.
    var corrected = flattenIllumination(gray, w, h, radius);
    corrected = stretchContrast(corrected);
    corrected = sharpen(corrected, w, h, sharpenAmount);

    if (filter == ScanFilter.blackWhite) {
      final bw = adaptiveThreshold(corrected, w, h,
          radius: math.max(6, (math.min(w, h) * 0.02).round()), bias: 10);
      return _grayToImage(bw, w, h);
    }
    if (filter == ScanFilter.gray) return _grayToImage(corrected, w, h);

    // Renkli mod: düzeltme **parlaklık** üzerinden uygulanıp renge geri
    // taşınır. Üç kanalı ayrı ayrı düzeltmek renkleri kaydırıyordu (mavi
    // kalemle atılan imza morarıyordu).
    final out = Uint8List(rgb.length);
    for (var i = 0, j = 0; i < gray.length; i++, j += 3) {
      final before = gray[i];
      final after = corrected[i];
      // Kaynak zaten siyahsa oran patlamasın diye +1'li bölme.
      final ratio = (after + 1) / (before + 1);
      out[j] = (rgb[j] * ratio).round().clamp(0, 255);
      out[j + 1] = (rgb[j + 1] * ratio).round().clamp(0, 255);
      out[j + 2] = (rgb[j + 2] * ratio).round().clamp(0, 255);
    }
    return img.Image.fromBytes(
        width: w, height: h, bytes: out.buffer, numChannels: 3);
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
  /// görsel önbelleğini eski kareyle bırakırdı — bkz. `writeTempPng`).
  static Future<String> tempTarget(String sourcePath, ScanFilter filter) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final name = '${p.basenameWithoutExtension(sourcePath)}'
        '_${filter.name}_$stamp.jpg';
    return p.join(dir.path, name);
  }
}
