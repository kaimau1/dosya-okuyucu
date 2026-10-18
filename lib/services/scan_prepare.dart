import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'scan_dewarp.dart';
import 'scan_enhance.dart';
import 'scan_page_ops.dart' show ScanPageOps;

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

/// **Sayfa hazırlığı** — filtre ve (istenirse) düzleştirme, TEK geçişte.
///
/// ## 2026-10-18: tarayıcı çıktısı OLDUĞU GİBİ kaydedilir
/// Kullanıcı: *"belge tarandıktan ve onaylandıktan sonra arka planda yapılan
/// iyileştirmeler resmin patlamasına ve bozulmasına sebep oluyor"* ve
/// *"resimli sayfalarda yanlış kesiyor"*. Önceki turda tarayıcıdan dönen her
/// sayfa burada KENDİLİĞİNDEN düzleştirilip ([ScanDewarp]) netleştiriliyordu
/// ([ScanFilter.auto]). İkisi de yazılı kâğıt için tasarlanmıştı; sayfada bir
/// fotoğraf varsa netleştirme onu beyaz bir lekeye çeviriyor, düzleştirme de
/// fotoğrafın dokusunu "satır" sanıp sayfayı çeviriyor ya da fotoğrafı dikey
/// şeritlere bölüp kaydırıyordu. Kullanıcı ML Kit ekranında sayfanın son
/// hâlini görüp ONAYLIYOR; onaydan sonra sessizce değiştirmek, onayladığı
/// şeyi bozmaktı. Artık:
/// * [pages]/[page] varsayılanı hiçbir şey yapmamak: görsel yeniden
///   kodlanmaz, PDF'e tarayıcının verdiği JPEG girer.
/// * Filtre (Otomatik/Gri/S-B) ve düzleştirme yalnız kullanıcı tarama
///   ekranında seçerse uygulanır — ikisi de artık resim bölgelerini koruyor
///   (bkz. `ScanEnhance.pictureMask`).
///
/// (2026-10-17'nin dersi de geçerli: kâğıt kenarına bakan otomatik kırpma
/// tarayıcı çıktısında koşmaz — ML Kit sayfayı zaten kırptı.)
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
  /// Yapılacak bir şey yoksa (özgün + düzleştirme yok) izolat açılmaz.
  static Future<ScanPage> page(
    String path, {
    ScanFilter filter = ScanFilter.original,
    bool straighten = false,
  }) async {
    if (filter == ScanFilter.original && !straighten) {
      return ScanPage.raw(path);
    }
    try {
      final dir = (await getTemporaryDirectory()).path;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final base = ScanPageOps.shortBase(path);
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
    ScanFilter filter = ScanFilter.original,
    bool straighten = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final out = <ScanPage>[];
    for (var i = 0; i < paths.length; i++) {
      onProgress?.call(i, paths.length);
      out.add(await page(paths[i], filter: filter, straighten: straighten));
    }
    onProgress?.call(paths.length, paths.length);
    return out;
  }
}
