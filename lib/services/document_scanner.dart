import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel, PlatformException, MissingPluginException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfPageFormat;

import 'conversion_service.dart';
import 'docs_home.dart';
import 'fm/file_ops.dart';
import 'fm/fs_events.dart';
import 'ocr_service.dart';

/// **Belge tarayıcı** — kamerayla çekilen sayfayı masaüstü tarayıcıdan çıkmış
/// gibi (kenar tespiti, perspektif düzeltme, kontrast/gri filtre) belgeye
/// çevirir, çok sayfayı tek PDF'te toplar.
///
/// Kenar bulma/kırpma/filtre işini **Google ML Kit `GmsDocumentScanner`** yapıyor
/// (Faz 35 / adım 0, 2026-11-05): `ci/DocScan.kt` köprüsü, kanal `dosya/docscan`,
/// SCANNER_MODE_FULL, sonuç JPEG (+PDF). `cunning_document_scanner` bırakıldı.
/// Play Hizmetleri yoksa/hata verirse (ya da `scan_engine_v2` bayrağı kapalıysa)
/// **yedek akış**: galeriden içe aktar; kırpma/döndürme stüdyoda (`scan_edit_screen`).
///
/// Bizim payımız: gelen sayfaları **tek PDF** yapmak, istenirse OCR ile
/// görünmez metin katmanı ekleyip belgeyi **aranabilir** kılmak ve Belgeler
/// dizinine yazmak.
class DocumentScanner {
  const DocumentScanner._();

  static const _chan = MethodChannel('dosya/docscan');

  /// Özellik bayrağı (geri alma = tek satır): kapalıysa doğrudan yedek akış.
  static const engineV2Key = 'scan_engine_v2';

  static Future<bool> _engineV2() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(engineV2Key) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Tarama arayüzünü açar; kullanıcı vazgeçerse `null`, aksi hâlde taranan
  /// sayfaların (JPEG) yolları döner. Kamera izni gerekmez (Play Hizmetleri).
  /// Tembel: köprü ilk kullanımda çağrılır, açılışta hiçbir şey kurulmaz.
  static Future<List<String>?> scanPages({int maxPages = 30}) async {
    if (await _engineV2()) {
      try {
        final res = await _chan.invokeMapMethod<String, dynamic>('start', {
          'maxPages': maxPages,
          'gallery': true,
          'mode': 'full',
        });
        if (res == null) return null; // vazgeçildi
        final pages = (res['pages'] as List?)?.cast<String>() ?? const [];
        return pages.isEmpty ? null : pages;
      } on PlatformException catch (e) {
        // `unavailable`: Play Hizmetleri yok / model inemedi → yedek akış.
        if (e.code != 'unavailable') rethrow;
      } on MissingPluginException {
        // Köprüsüz derleme → yedek akış.
      }
    }
    return importFromGallery(maxPages: maxPages);
  }

  /// **Yedek akış:** galeriden görsel seç (otomatik kenar yok; kırpma/döndürme
  /// tarama stüdyosunda). Vazgeçilirse `null`.
  static Future<List<String>?> importFromGallery({int maxPages = 30}) async {
    final r = await FilePicker.pickFiles(type: FileType.image);
    final paths = [
      for (final f in r)
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty) return null;
    return paths.length > maxPages ? paths.sublist(0, maxPages) : paths;
  }

  /// Taranan sayfalardan PDF üretip **Belgeler dizinine** yazar, yolunu döndürür.
  ///
  /// [searchable] ise her sayfa OCR'lanıp görünmez metin katmanı eklenir —
  /// belge hem aranabilir hem kopyalanabilir olur (görüntü değişmez).
  /// [onProgress] sayfa sayfa ilerlemeyi bildirir (OCR uzun sürebilir).
  @visibleForTesting
  static Future<String> buildPdf(
    List<String> imagePaths, {
    bool searchable = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final ocrLines = searchable
        ? await recognizePages(imagePaths, onProgress: onProgress)
        : const <List<OcrLine>>[];
    final bytes = await renderPdf(imagePaths, ocrLinesPerPage: ocrLines);
    return savePdf(bytes);
  }

  /// Sayfaları OCR'lar — satır **kutularıyla** birlikte.
  ///
  /// Ayrı bir adım olması gerekiyor: aynı sonuç iki yerde kullanılıyor —
  /// PDF'in görünmez metin katmanı **ve** tarama sonucu ekranındaki "Metin"
  /// sekmesi (kullanıcı isteği 2026-07-31: *"bir sayfada belge, bir sayfada
  /// yazılar düzgün formatta"*). İki kez taramak süreyi ikiye katlardı.
  static Future<List<List<OcrLine>>> recognizePages(
    List<String> imagePaths, {
    void Function(int done, int total)? onProgress,
  }) async {
    final out = <List<OcrLine>>[];
    for (var i = 0; i < imagePaths.length; i++) {
      onProgress?.call(i, imagePaths.length);
      out.add(await OcrService.recognizeImageLines(imagePaths[i]));
    }
    onProgress?.call(imagePaths.length, imagePaths.length);
    return out;
  }

  /// Sayfa görsellerinden PDF baytları üretir (diske yazmaz).
  ///
  /// Her sayfa A4: gerçek bir tarayıcı gibi tek boy kâğıt. Görsel oranı
  /// korunarak sayfaya tam oturtulur (kırpılmaz), yatay sayfa yatay basılır.
  ///
  /// [uniformA4] false ise (fiş, fotoğraf, kartvizit — Faz 35) her sayfa
  /// görselin kendi oranında: uzun fiş A4'e sığdırılıp küçülmez.
  static Future<Uint8List> renderPdf(
    List<String> imagePaths, {
    List<List<OcrLine>> ocrLinesPerPage = const [],
    bool uniformA4 = true,
  }) =>
      ConversionService().imagesToPdf(
        imagePaths,
        ocrLinesPerPage: ocrLinesPerPage,
        uniformPage: uniformA4 ? PdfPageFormat.a4 : null,
      );

  /// PDF'i diske yazar ve yolunu döner. [dir] verilmezse Belgeler dizini
  /// (kullanıcı sonuç ekranından başka bir klasör seçebiliyor).
  ///
  /// Ad çakışırsa üzerine YAZILMAZ: `rapor (1).pdf` üretilir. Akıllı
  /// adlandırma (bkz. `suggestScanTitle`) aynı belgeyi iki kez tarayana aynı
  /// adı önerir — sessizce ezmek ilk taramayı kaybettirirdi.
  static Future<String> savePdf(Uint8List bytes,
      {String? dir, String? fileName}) async {
    final target = dir ?? (await defaultDir()).path;
    await Directory(target).create(recursive: true);
    final path = FileOps.uniquePath(
        p.join(target, fileName ?? 'Tarama ${_stamp()}.pdf'));
    await File(path).writeAsBytes(bytes, flush: true);
    // Pano/gezgin ANINDA tazelensin (kullanıcı bulgusu 2026-08-06: *"benim
    // eklediğim taramalar hemen düşmüyor"*). Tarama sonucu süreç boyunca
    // önbellekli; kimse "değişti" demezse yeni PDF ancak aşağı çekince ya da
    // uygulama yeniden açılınca görünüyordu. Sinyal BURADA, çünkü her tarama
    // kaydı — akıştan da, sonuç ekranından da — bu tek noktadan geçiyor.
    FsEvents.changed();
    return path;
  }

  /// Taranan sayfaların düz metni — sayfa sayfa (boş sayfa listeye girmez).
  static List<OcrPage> textPages(List<List<OcrLine>> ocrLinesPerPage) {
    final out = <OcrPage>[];
    for (var i = 0; i < ocrLinesPerPage.length; i++) {
      final text = ocrLinesPerPage[i]
          .map((line) => line.text.trim())
          .where((line) => line.isNotEmpty)
          .join('\n');
      if (text.isNotEmpty) out.add(OcrPage(i + 1, text));
    }
    return out;
  }

  /// Taramaların alt klasörü (Faz 35 / madde 4): belgeler klasörü taramayla
  /// dolup taşmasın; "Son belgeler" ve gezgin yine bulur.
  static const scansFolder = 'Taramalar';

  /// Ana bellekte `Documents/Dosya Okuyucu/Taramalar` (bkz. [DocsHome]).
  /// Alt klasör kurulamazsa (izin) belgeler klasörünün kendisi.
  static Future<Directory> defaultDir() async {
    final home = await DocsHome.resolve();
    final dir = Directory(p.join(home.path, scansFolder));
    try {
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return home;
    }
  }

  static String _stamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }
}
