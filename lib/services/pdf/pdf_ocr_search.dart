import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:pdfrx/pdfrx.dart';

import 'pdf_ocr_text.dart';
import 'selection_rects.dart';

/// Taranmış sayfadaki tek arama eşleşmesi.
class PdfOcrMatch {
  final int pageNumber;

  /// Satır başına bir kutu (PDF koordinatı) — seçim vurgusuyla aynı geometri.
  final List<PdfRect> rects;

  /// Eşleşmeyi kaplayan tek kutu (sayfaya kaydırma hedefi).
  final PdfRect bounds;

  const PdfOcrMatch(this.pageNumber, this.rects, this.bounds);
}

/// **Taranmış sayfalarda arama** — pdfrx'in `PdfTextSearcher`'ı yalnız pdfium
/// metin katmanını görür; taranmış PDF'te arama bu yüzden KÖRDÜ (seçim ve
/// kopyalama OCR ile çalışır olmuştu, arama geride kalmıştı — "taranmış veya
/// yazılmış fark etmez" sözünün son parçası).
///
/// Metin katmanı ince sayfalar (< 8 karakter, seçim katmanıyla aynı eşik)
/// [PdfOcrText] üzerinden OCR'lanır (bellek + disk önbellekli: ikinci arama
/// ve sonraki oturumlar anında) ve desen OCR metninde aranır. Eşleşme
/// kutuları `selectionPdfRects` ile üretilir — vurgu, seçim vurgusuyla
/// birebir aynı satır geometrisini kullanır.
///
/// Sayaç canlı ilerler: her sayfa bittiğinde dinleyiciler uyarılır
/// (kullanıcı ilk eşleşmeler gelirken gezinmeye başlayabilir).
class PdfOcrSearch extends ChangeNotifier {
  /// Bir aramada OCR'lanacak en çok sayfa — 300 sayfalık taranmış kitapta
  /// aramanın dakikalarca pil yakmasına set. Önbellekli sayfalar sınırı
  /// YEMEZ (zaten bedava); sınır yalnız yeni OCR işlerini sayar.
  static const maxFreshOcrPages = 40;

  /// Seçim katmanıyla aynı "taranmış sayfa" eşiği.
  static const thinTextThreshold = 8;

  List<PdfOcrMatch> _matches = const [];
  bool _searching = false;
  int _current = -1;
  int _generation = 0;

  /// Sınır yüzünden OCR'lanmadan atlanan sayfa sayısı (arayüz "ilk 40 taranmış
  /// sayfa arandı" diyebilsin; sessiz kesme yok).
  int _skippedPages = 0;

  List<PdfOcrMatch> get matches => _matches;
  bool get isSearching => _searching;
  int get currentIndex => _current;
  int get skippedPages => _skippedPages;

  set currentIndex(int value) {
    if (value == _current) return;
    _current = value;
    notifyListeners();
  }

  /// [pattern]'i [document]'ın taranmış sayfalarında arar. Yeni bir çağrı
  /// öncekini iptal eder (generation sayacı). [fromPage]: kullanıcının
  /// baktığı sayfa — arama oradan başlayıp sona, sonra baştan devam eder;
  /// ilk sonuçlar gözün önündeki sayfalardan gelir.
  Future<void> start(PdfDocument document, Pattern pattern,
      {int fromPage = 1}) async {
    final gen = ++_generation;
    _matches = const [];
    _current = -1;
    _skippedPages = 0;
    _searching = true;
    notifyListeners();

    final pages = document.pages;
    final ordered = [
      ...pages.where((p) => p.pageNumber >= fromPage),
      ...pages.where((p) => p.pageNumber < fromPage),
    ];
    final found = <PdfOcrMatch>[];
    var freshBudget = maxFreshOcrPages;
    for (final page in ordered) {
      if (gen != _generation) return; // yeni arama başladı: sessizce çekil
      PdfPageText? layer;
      try {
        layer = await page.loadText();
      } catch (_) {}
      if (gen != _generation) return;
      if ((layer?.fullText.trim().length ?? 0) >= thinTextThreshold) {
        continue; // metin katmanı var: o sayfa pdfrx arayıcısının işi
      }
      if (!PdfOcrText.isCached(page)) {
        if (freshBudget <= 0) {
          _skippedPages++;
          continue;
        }
        freshBudget--;
      }
      final ocr = await PdfOcrText.forPage(page);
      if (gen != _generation) return;
      if (ocr == null) continue;
      var pageHadMatch = false;
      for (final m in pattern.allMatches(ocr.fullText)) {
        if (m.start >= m.end) continue;
        final rects = selectionPdfRects(ocr, m.start, m.end - 1);
        if (rects.isEmpty) continue;
        found.add(PdfOcrMatch(page.pageNumber, rects, rects.boundingRect()));
        pageHadMatch = true;
      }
      if (pageHadMatch) {
        // Liste büyüyor: kopya üzerinden yayınla (dinleyici döngü ortasındaki
        // listeyi tutarsa şaşırmasın).
        _matches = List.unmodifiable(found);
        notifyListeners();
      }
    }
    if (gen != _generation) return;
    _matches = List.unmodifiable(found);
    _searching = false;
    notifyListeners();
  }

  /// Aramayı temizler (kutu kapandı ya da sorgu boşaldı).
  void reset() {
    _generation++;
    if (_matches.isEmpty && !_searching && _current == -1) return;
    _matches = const [];
    _searching = false;
    _current = -1;
    _skippedPages = 0;
    notifyListeners();
  }
}
