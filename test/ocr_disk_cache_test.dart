import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:dosya_okuyucu/services/pdf/ocr_page_text.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_ocr_text.dart';
import 'support/temp_dir.dart';

/// OCR disk önbelleği: sayfa metni JSON'a gidip AYNEN geri gelmeli — kutu
/// koordinatlarında kayıp, uygulama yeniden açılınca seçimin kaymasıdır.
void main() {
  OcrPageText sample() => buildOcrPageText(
        pageNumber: 3,
        pageHeight: 200,
        imageScale: 2,
        lines: [
          [
            OcrWordBox('Merhaba', const Rect.fromLTRB(20, 40, 160, 60)),
            OcrWordBox('dünya', const Rect.fromLTRB(170, 40, 260, 60)),
          ],
          [OcrWordBox('ikinci', const Rect.fromLTRB(20, 80, 120, 100))],
        ],
      )!;

  group('encode/decode', () {
    test('gidiş-dönüş kayıpsız', () {
      final original = sample();
      final decoded = decodeOcrPageText(encodeOcrPageText(original))!;

      expect(decoded.pageNumber, original.pageNumber);
      expect(decoded.fullText, original.fullText);
      expect(decoded.fragments.length, original.fragments.length);
      for (var i = 0; i < original.fragments.length; i++) {
        final a = original.fragments[i];
        final b = decoded.fragments[i];
        expect(b.index, a.index);
        expect(b.text, a.text);
        expect(b.charRects, a.charRects,
            reason: 'kutular birebir dönmeli (seçim geometrisi)');
      }
    });

    test('bozuk/yabancı girdi null döner, fırlatmaz', () {
      expect(decodeOcrPageText('çöp'), isNull);
      expect(decodeOcrPageText('{"v":99}'), isNull);
      expect(decodeOcrPageText('{"v":1,"page":1,"text":"ab","frags":'
          '[{"i":0,"t":"ab","r":[1,2,3,4]}]}'), isNull,
          reason: 'kutu sayısı metin uzunluğunu tutmuyor: girdi atılmalı');
    });
  });

  group('fnv1a', () {
    test('kararlı ve negatifsiz', () {
      expect(fnv1a('a'), fnv1a('a'), reason: 'aynı girdi aynı özet');
      expect(fnv1a('a') == fnv1a('b'), isFalse);
      expect(fnv1a('/depo/hasta raporu.pdf|123|456').startsWith('-'), isFalse);
      expect(fnv1a(''), hasLength(16));
    });
  });

  group('PdfOcrText disk katmanı', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ocr_cache_test');
      PdfOcrText.debugReset();
      PdfOcrText.debugDiskDirOverride = tempDir.path;
    });

    tearDown(() {
      PdfOcrText.debugReset();
      try {
        removeTempDir(tempDir);
      } catch (_) {}
    });

    test('ikinci oturumda OCR koşmaz: sonuç diskten gelir', () async {
      final page = FakeOcrPage(pageNumber: 3);
      var ocrCalls = 0;
      PdfOcrText.debugOcrOverride = (_) async {
        ocrCalls++;
        return sample();
      };

      final first = await PdfOcrText.forPage(page);
      expect(first, isNotNull);
      expect(ocrCalls, 1);

      // "Uygulama yeniden açıldı": bellek önbelleği gitti, disk duruyor.
      PdfOcrText.debugReset();
      PdfOcrText.debugDiskDirOverride = tempDir.path;
      PdfOcrText.debugOcrOverride = (_) async {
        ocrCalls++;
        return null;
      };

      final second = await PdfOcrText.forPage(page);
      expect(second, isNotNull, reason: 'diskten çözülmeli');
      expect(second!.fullText, first!.fullText);
      expect(ocrCalls, 1, reason: 'OCR yeniden KOŞMAMALI');
      expect(PdfOcrText.isCached(page), isTrue);
    });

    test('"metin yok" da hatırlanır (boş sayfa her açılışta taranmasın)',
        () async {
      final page = FakeOcrPage(pageNumber: 7);
      var ocrCalls = 0;
      PdfOcrText.debugOcrOverride = (_) async {
        ocrCalls++;
        return null;
      };

      expect(await PdfOcrText.forPage(page), isNull);
      expect(ocrCalls, 1);

      PdfOcrText.debugReset();
      PdfOcrText.debugDiskDirOverride = tempDir.path;
      PdfOcrText.debugOcrOverride = (_) async {
        ocrCalls++;
        return sample();
      };

      expect(await PdfOcrText.forPage(page), isNull,
          reason: 'diskteki "yok" işareti geçerli olmalı');
      expect(ocrCalls, 1);
    });
  });
}

/// Test için sahte belge/sayfa (yalnız kullanılan üyeler; kalanı patlar).
class FakeOcrDoc implements PdfDocument {
  @override
  final String sourceName;
  final List<PdfPage> _pages = [];

  FakeOcrDoc([this.sourceName = 'sahte-belge.pdf']);

  @override
  List<PdfPage> get pages => _pages;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

class FakeOcrPage implements PdfPage {
  @override
  final int pageNumber;
  final PdfPageText? textLayer;

  @override
  final PdfDocument document;

  FakeOcrPage({required this.pageNumber, this.textLayer, FakeOcrDoc? doc})
      : document = doc ?? FakeOcrDoc() {
    (document as FakeOcrDoc)._pages.add(this);
  }

  @override
  double get width => 100;

  @override
  double get height => 200;

  @override
  PdfPageRotation get rotation => PdfPageRotation.none;

  @override
  bool get isLoaded => true;

  @override
  Future<PdfPageText> loadText() async =>
      textLayer ??
      OcrPageText(pageNumber: pageNumber, fullText: '', fragments: const []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}
