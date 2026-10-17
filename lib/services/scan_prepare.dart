import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'scan_dewarp.dart';
import 'scan_enhance.dart';

/// Taranan TEK sayfanın durumu: filtrenin uygulandığı kaynak, ekranda/PDF'te
/// görünen görsel ve seçili filtre.
///
/// İkisi ayrı tutulur çünkü filtre yıkıcı değildir: kullanıcı sonuç
/// ekranından "Sayfaları düzenle" ile filtreyi değiştirirse yeni filtre
/// [source]'a uygulanır — keskinleştirilmiş görseli yeniden keskinleştirmek
/// sayfayı gürültüye boğuyordu (bkz. `ScanReviewScreen`).
class ScanPage {
  /// Tarayıcı çıktısı ya da onun düzleştirilmiş/kırpılmış/döndürülmüş hâli.
  final String source;

  /// PDF'e giren görsel ([source] + [filter]).
  final String display;

  final ScanFilter filter;

  const ScanPage({
    required this.source,
    required this.display,
    this.filter = ScanFilter.original,
  });

  /// Hiç işlenmemiş sayfa (hazırlık başarısızsa da buna düşülür).
  const ScanPage.raw(String path)
      : source = path,
        display = path,
        filter = ScanFilter.original;

  ScanPage copyWith({String? source, String? display, ScanFilter? filter}) =>
      ScanPage(
        source: source ?? this.source,
        display: display ?? this.display,
        filter: filter ?? this.filter,
      );

  static List<String> displays(List<ScanPage> pages) =>
      [for (final page in pages) page.display];
}

/// İzolata geçen istek (tek argüman kuralı). Hedef yollar ana izlekte
/// hesaplanır: `path_provider` arka plan izolatında platform kanalı ister.
class ScanPrepareRequest {
  final String sourcePath;
  final String straightTarget;
  final String displayTarget;
  final ScanFilter filter;
  final bool straighten;

  const ScanPrepareRequest({
    required this.sourcePath,
    required this.straightTarget,
    required this.displayTarget,
    required this.filter,
    this.straighten = true,
  });
}

/// **Tarayıcıdan gelen sayfayı TEK geçişte hazırlama** (2026-10-17).
///
/// Kullanıcı: *"belge taramada kesme sorunu ve direk kaydetmesi gerekli,
/// baştan sona incelenmeli tüm akış"*. İki kök neden vardı:
///
/// 1. **Çifte kırpma.** ML Kit tarayıcısı (`SCANNER_MODE_FULL`) sayfayı
///    ZATEN kâğıdın kenarından kırpıp perspektifini açarak veriyor. Önizleme
///    ekranı açılırken bunun üstüne bir de kendi kenar bulucumuz
///    (`ScanDeskew` → `DocEdges`) koşuyordu. Kırpılmış sayfada kâğıt kenarı
///    artık görselin sınırı olduğu için bulunamıyor; bulucu onun yerine
///    sayfanın İÇİNDEKİ en güçlü dörtgeni — tablo çerçevesi, antet çizgisi,
///    kimlik kartının iç çerçevesi — "kâğıt" sanıyor ve alanı %45–98 arasında
///    olduğu için uyguluyordu. Çerçevenin dışında kalan yazı (başlık, imza,
///    sayfa altı) PDF'ten KESİLİYORDU. Kâğıt kenarına bakan otomatik
///    düzeltme bu yüzden tarayıcı çıktısında artık koşmaz; elle "Kenarları
///    kırp" yolu duruyor.
/// 2. **Gereksiz ara ekran.** Kullanıcı ML Kit'te "Kaydet"e bastıktan sonra
///    bir de önizleme ekranında "Devam"a basmak zorundaydı. Artık sayfalar
///    burada hazırlanıp doğrudan kaydediliyor; düzenleme sonuç ekranında
///    isteğe bağlı.
///
/// Kalan otomatik adımlar kırpmaz: yazıya bakan düzleştirme ([ScanDewarp],
/// tuvali BÜYÜTEREK döndürür ve kıvrımı açarken içeriği taşırmaz) ve
/// netleştirme ([ScanEnhance]). Görsel bir kez çözülür, bir kez (düzleşme
/// olduysa iki kez) kodlanır — eskiden her adım dosyayı yeniden okuyup
/// yeniden JPEG'e yazıyordu (sayfa başına üç çözme, iki kodlama).
abstract final class ScanPrepare {
  /// [request]'i uygular — `compute` ile izolatta çağrılır. Görsel
  /// çözülemezse sayfa OLDUĞU GİBİ döner (hazırlık süs, kayıp sebebi değil).
  static ScanPage runRequest(ScanPrepareRequest request) {
    final bytes = File(request.sourcePath).readAsBytesSync();
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      image = null; // bozuk dosyada `image` paketi hata da atabiliyor
    }
    if (image == null) return ScanPage.raw(request.sourcePath);
    // EXIF yönü piksele işlenir: aksi hâlde yeniden kodlanan (EXIF'siz)
    // çıktı yan dönmüş görünürdü.
    if (image.exif.imageIfd.hasOrientation &&
        image.exif.imageIfd.orientation != 1) {
      image = img.bakeOrientation(image);
    }

    var source = request.sourcePath;
    if (request.straighten) {
      final flat = ScanDewarp.straighten(image);
      if (flat != null) {
        image = flat;
        File(request.straightTarget).writeAsBytesSync(
            img.encodeJpg(flat, quality: ScanEnhance.jpegQuality),
            flush: true);
        source = request.straightTarget;
      }
    }
    if (request.filter == ScanFilter.original) {
      return ScanPage.raw(source);
    }
    final out = ScanEnhance.applyToImage(image, request.filter);
    File(request.displayTarget).writeAsBytesSync(
        img.encodeJpg(out, quality: ScanEnhance.jpegQuality),
        flush: true);
    return ScanPage(
        source: source, display: request.displayTarget, filter: request.filter);
  }

  /// Tek sayfayı izolatta hazırlar; hata olursa sayfa işlenmeden döner.
  static Future<ScanPage> page(
    String path, {
    ScanFilter filter = ScanFilter.auto,
    bool straighten = true,
  }) async {
    try {
      final dir = (await getTemporaryDirectory()).path;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final base = p.basenameWithoutExtension(path);
      return await compute(
        runRequest,
        ScanPrepareRequest(
          sourcePath: path,
          straightTarget: p.join(dir, '${base}_duzlestirildi_$stamp.jpg'),
          displayTarget: p.join(dir, '${base}_${filter.name}_$stamp.jpg'),
          filter: filter,
          straighten: straighten,
        ),
      );
    } catch (_) {
      return ScanPage.raw(path);
    }
  }

  /// Sayfaları SIRAYLA hazırlar (aynı anda tek 12 MP görsel bellekte —
  /// paralel izolatlar düşük bellekli telefonda süreci öldürtebilirdi).
  static Future<List<ScanPage>> pages(
    List<String> paths, {
    ScanFilter filter = ScanFilter.auto,
    void Function(int done, int total)? onProgress,
  }) async {
    final out = <ScanPage>[];
    for (var i = 0; i < paths.length; i++) {
      onProgress?.call(i, paths.length);
      out.add(await page(paths[i], filter: filter));
    }
    onProgress?.call(paths.length, paths.length);
    return out;
  }
}
