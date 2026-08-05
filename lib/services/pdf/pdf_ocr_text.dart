import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdfrx/pdfrx.dart';

import '../ocr_service.dart';
import 'ocr_page_text.dart';

/// Taranmış (metin katmanı olmayan) PDF sayfası için OCR'dan seçilebilir
/// metin üretir: sayfa bitmap'e çizilir → ML Kit sözcük kutuları →
/// [buildOcrPageText] ile sahte `PdfPageText`.
///
/// Seçim katmanı bunu pdfium metniyle birebir aynı arayüzden kullanır;
/// kullanıcı için yazılmış/taranmış farkı yoktur (Chrome'un yaptığı gibi).
///
/// KVKK notu: OCR tamamen cihaz içinde (ML Kit yerel model), tanınan metin
/// yalnız bellekte tutulur; diske sayfa görüntüsünden başka bir şey yazılmaz
/// ve o da iş biter bitmez silinir.
class PdfOcrText {
  PdfOcrText._();

  /// Test kancası: bütün boru hattının (çiz → ML Kit → kur) yerine geçer.
  /// Testler Linux'ta koşar; ML Kit de pdfium bitmap çizimi de orada yok.
  static Future<OcrPageText?> Function(PdfPage page)? debugOcrOverride;

  /// OCR bu platformda çalışır mı? (ML Kit modeli mobil APK ile gelir;
  /// masaüstünde taranmış sayfa seçimi — şimdilik — yok.)
  static bool get isSupported =>
      debugOcrOverride != null ||
      (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// Sayfa başına sonuç önbelleği (null = denendi, sayfada metin yok — yeniden
  /// denemek pil yakar). Anahtar dosya yolu + sayfa numarası: `PdfReload`
  /// belgeyi aynı yoldan tazelediği için önbellek yeniden yüklemeden etkilenmez.
  static final _cache = <String, OcrPageText?>{};
  static final _inFlight = <String, Future<OcrPageText?>>{};
  static const _cacheCap = 24;

  static String _key(PdfPage page) =>
      '${page.document.sourceName}#${page.pageNumber}';

  /// [page] için OCR metni. Aynı sayfa için eşzamanlı ikinci çağrı ilk işi
  /// bekler; sonuç (boş olsa da) önbelleğe girer.
  static Future<OcrPageText?> forPage(PdfPage page) {
    if (!isSupported) return Future.value(null);
    final key = _key(page);
    if (_cache.containsKey(key)) {
      // LRU tazele: sonda duran en taze olandır.
      final v = _cache.remove(key);
      _cache[key] = v;
      return Future.value(v);
    }
    return _inFlight[key] ??= _run(page, key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  static Future<OcrPageText?> _run(PdfPage page, String key) async {
    OcrPageText? result;
    try {
      final override = debugOcrOverride;
      if (override != null) {
        result = await override(page);
      } else {
        final rendered = await OcrService.renderPageToPng(page,
            tag: 'sel${page.pageNumber}');
        if (rendered != null) {
          try {
            final lines =
                await OcrService.recognizeImageWordLines(rendered.path);
            result = buildOcrPageText(
              pageNumber: page.pageNumber,
              pageHeight: page.height,
              imageScale: rendered.scale,
              lines: lines,
            );
          } finally {
            try {
              File(rendered.path).deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {
      // OCR başarısızlığı seçimi değil yalnız taranmış-sayfa desteğini düşürür;
      // sessizce "metin yok" say (önbelleğe de öyle yaz — tekrar deneme yok).
    }
    _cache[key] = result;
    if (_cache.length > _cacheCap) _cache.remove(_cache.keys.first);
    return result;
  }

  /// Testler arası sızıntı olmasın diye.
  static void debugReset() {
    _cache.clear();
    _inFlight.clear();
    debugOcrOverride = null;
  }
}
