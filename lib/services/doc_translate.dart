import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:pdfrx/pdfrx.dart';

import 'ocr_service.dart';
import 'translate_service.dart';

/// **Belge çevirisi** — "belgenin/PDF'in metnini tanıyıp tüm sayfayı çevir".
///
/// Kullanıcı isteği 2026-07-31: *"çeviri özelliğimiz var ama yeterli değil,
/// belgeleri pdfleri metnini tanıyıp tüm sayfa olarak çevirebilmek lazım tek
/// butonla"*. Eski durumun eksiği neydi:
/// - Çeviri **hazır metin** istiyordu. Taranmış PDF'te metin katmanı yok →
///   ekran "önce Metni tanı'yı çalıştırın" diyordu; yani tek düğme değil, iki
///   düğme ve arada kullanıcının bilmesi gereken bir kavram (OCR) vardı.
/// - OCR sayfa sınırı 25'ti ve metin tek dizede birleşiyordu; sayfa ayrımı
///   kayboluyor, "— Sayfa 3 —" başlığı bile çeviriye giriyordu.
///
/// Bu katman ikisini birleştirir: sayfa sayfa metni **nereden gelirse gelsin**
/// toplar (önce metin katmanı, o sayfa boşsa OCR) ve sayfa yapısını koruyarak
/// çevirir. Arayüzden bağımsızdır (`BuildContext` almaz) → akış widget'ı
/// (`widgets/translate_flow.dart`) yalnız ilerlemeyi çizer.
abstract final class DocTranslate {
  /// Çeviride taranacak en fazla sayfa. OCR sayfası başına ~1-2 sn: 300 sayfa
  /// üstü belgede kullanıcı zaten "Durdur"a basar, ama sınırsız bırakmak
  /// telefonu boşuna ısıtır.
  static const maxPages = 300;

  /// PDF'in sayfa metinlerini toplar.
  ///
  /// Önce **metin katmanı** okunur (hızlı, birebir doğru). Katmanı boş çıkan
  /// sayfalar taranmış demektir; yalnız onlar OCR'a gider — karma belgede
  /// (dijital sayfalar + arada taranmış imza sayfası) hem hızlı hem eksiksiz.
  ///
  /// [onLayer] metin katmanı okunurken (işlenen, toplam),
  /// [onOcr] OCR sırasında (işlenen, toplam) ile çağrılır.
  /// [cancelled] düzenli yoklanır; durdurulursa o ana kadarki sayfalar döner.
  static Future<List<OcrPage>> collectPdfPages(
    PdfDocument document, {
    void Function(int done, int total)? onLayer,
    void Function(int done, int total)? onOcr,
    bool Function()? cancelled,
    int pageLimit = maxPages,
  }) async {
    final pages = document.pages;
    final total = pages.length > pageLimit ? pageLimit : pages.length;
    final byNumber = <int, String>{};
    final needsOcr = <int>{};

    for (var i = 0; i < total; i++) {
      if (cancelled?.call() ?? false) return _sorted(byNumber);
      onLayer?.call(i, total);
      final page = pages[i];
      String text = '';
      try {
        // dynamic: `loadText` dönüşü pdfrx sürümleri arasında nullable/nonnull
        // değişti (bkz. viewer_screen._extractPdfText) — iki imzayla da derlensin.
        final dynamic layer = await page.loadText();
        text = layer == null ? '' : (layer.fullText as String? ?? '').trim();
      } catch (_) {
        text = '';
      }
      if (text.isEmpty) {
        needsOcr.add(page.pageNumber);
      } else {
        byNumber[page.pageNumber] = text;
      }
    }
    onLayer?.call(total, total);

    if (needsOcr.isNotEmpty && !(cancelled?.call() ?? false)) {
      final recognized = await OcrService.recognizePdfPages(
        document,
        maxPages: needsOcr.length,
        onlyPages: needsOcr,
        onProgress: onOcr,
        cancelled: cancelled,
      );
      for (final page in recognized) {
        byNumber[page.number] = page.text;
      }
    }
    return _sorted(byNumber);
  }

  static List<OcrPage> _sorted(Map<int, String> byNumber) {
    final numbers = byNumber.keys.toList()..sort();
    return [for (final n in numbers) OcrPage(n, byNumber[n]!)];
  }

  /// Sayfaları sırayla çevirir; **tek** çevirici açılır (bkz.
  /// [TranslateService.translateWith]).
  ///
  /// [onPage] her sayfa öncesi (işlenen, toplam) ile çağrılır. Durdurulursa
  /// çevrilmiş sayfalar döner — kullanıcı 40 sayfanın 12'sini görebilsin.
  static Future<List<OcrPage>> translatePages(
    List<OcrPage> pages, {
    required TranslateLanguage from,
    required TranslateLanguage to,
    void Function(int done, int total)? onPage,
    bool Function()? cancelled,
  }) async {
    final translator = TranslateService.translator(from: from, to: to);
    final out = <OcrPage>[];
    try {
      for (var i = 0; i < pages.length; i++) {
        if (cancelled?.call() ?? false) break;
        onPage?.call(i, pages.length);
        final text = await TranslateService.translateWith(
          translator,
          pages[i].text,
          cancelled: cancelled,
        );
        if (text.trim().isNotEmpty) out.add(OcrPage(pages[i].number, text));
      }
    } finally {
      await translator.close();
    }
    return out;
  }

  /// Sayfaların toplam karakter sayısı (ilerleme metninde "≈ 40 bin karakter").
  static int charCount(List<OcrPage> pages) =>
      pages.fold<int>(0, (sum, p) => sum + p.text.length);
}
