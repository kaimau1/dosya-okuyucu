import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/pdf/ocr_page_text.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_ocr_search.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_ocr_text.dart';

import 'ocr_disk_cache_test.dart' show FakeOcrDoc, FakeOcrPage;

/// Taranmış sayfalarda arama: metin katmanlı sayfa pdfrx'in işi (atlanır),
/// ince sayfa OCR'lanıp desende aranır; sonuçlar kullanıcının baktığı
/// sayfadan başlar; OCR bütçesi aşılırsa sessiz kesme yerine sayaç tutulur.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ocr_search_test');
    PdfOcrText.debugReset();
    PdfOcrText.debugDiskDirOverride = tempDir.path;
  });

  tearDown(() {
    PdfOcrText.debugReset();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  OcrPageText line(int page, String text) => buildOcrPageText(
        pageNumber: page,
        pageHeight: 200,
        imageScale: 1,
        lines: [
          [
            for (var i = 0; i < text.split(' ').length; i++)
              OcrWordBox(text.split(' ')[i],
                  Rect.fromLTRB(10.0 + 80 * i, 20, 80.0 + 80 * i, 40)),
          ],
        ],
      )!;

  test('ince sayfalar OCR ile aranır, metin katmanlı sayfa atlanır', () async {
    final doc = FakeOcrDoc();
    FakeOcrPage(
        pageNumber: 1,
        doc: doc,
        textLayer: line(1, 'fatura kelimesi metin katmanında zaten var'));
    FakeOcrPage(pageNumber: 2, doc: doc);
    FakeOcrPage(pageNumber: 3, doc: doc);

    final ocrPages = <int>[];
    PdfOcrText.debugOcrOverride = (page) async {
      ocrPages.add(page.pageNumber);
      return page.pageNumber == 2 ? line(2, 'toplam fatura tutarı fatura') : null;
    };

    final search = PdfOcrSearch();
    await search.start(doc, RegExp('fatura'));

    expect(ocrPages, [2, 3], reason: '1. sayfanın metin katmanı var: OCR yok');
    expect(search.matches, hasLength(2));
    expect(search.matches.every((m) => m.pageNumber == 2), isTrue);
    expect(search.matches.first.rects, isNotEmpty);
    expect(search.isSearching, isFalse);
    expect(search.skippedPages, 0);
  });

  test('arama kullanıcının baktığı sayfadan başlar', () async {
    final doc = FakeOcrDoc();
    for (var i = 1; i <= 3; i++) {
      FakeOcrPage(pageNumber: i, doc: doc);
    }
    PdfOcrText.debugOcrOverride = (page) async => line(page.pageNumber, 'alfa');

    final search = PdfOcrSearch();
    await search.start(doc, RegExp('alfa'), fromPage: 3);

    expect(search.matches.map((m) => m.pageNumber).toList(), [3, 1, 2],
        reason: 'ilk sonuçlar gözün önündeki sayfadan gelmeli');
  });

  test('yeni arama eskisini iptal eder (generation)', () async {
    final doc = FakeOcrDoc();
    for (var i = 1; i <= 5; i++) {
      FakeOcrPage(pageNumber: i, doc: doc);
    }
    PdfOcrText.debugOcrOverride =
        (page) async => line(page.pageNumber, 'alfa');

    final search = PdfOcrSearch();
    final first = search.start(doc, RegExp('alfa'));
    final second = search.start(doc, RegExp('yok-boyle-kelime'));
    await Future.wait([first, second]);

    expect(search.matches, isEmpty,
        reason: 'ilk aramanın eşleşmeleri ikinciye SIZMAMALI');
    expect(search.isSearching, isFalse);
  });

  test('OCR bütçesi: sınır üstü sayfalar sayılır, sessiz kesme yok', () async {
    final doc = FakeOcrDoc();
    final total = PdfOcrSearch.maxFreshOcrPages + 2;
    for (var i = 1; i <= total; i++) {
      FakeOcrPage(pageNumber: i, doc: doc);
    }
    var ocrCalls = 0;
    PdfOcrText.debugOcrOverride = (_) async {
      ocrCalls++;
      return null;
    };

    final search = PdfOcrSearch();
    await search.start(doc, RegExp('x'));

    expect(ocrCalls, PdfOcrSearch.maxFreshOcrPages);
    expect(search.skippedPages, 2);
  });

  test('reset eşleşmeleri ve durumu temizler', () async {
    final doc = FakeOcrDoc();
    FakeOcrPage(pageNumber: 1, doc: doc);
    PdfOcrText.debugOcrOverride = (_) async => line(1, 'alfa');

    final search = PdfOcrSearch();
    await search.start(doc, RegExp('alfa'));
    expect(search.matches, isNotEmpty);

    search.reset();
    expect(search.matches, isEmpty);
    expect(search.currentIndex, -1);
    expect(search.isSearching, isFalse);
  });
}
