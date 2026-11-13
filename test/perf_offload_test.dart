import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_form.dart';

/// 2026-11-03 kasma turu: ana izlekten arka izleğe taşınan açılış işleri
/// aynı sonucu vermeli.
void main() {
  group('PdfFormFiller.scanForAcroFormSync', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('acro'));
    tearDown(() => dir.deleteSync(recursive: true));

    File write(List<int> bytes) =>
        File('${dir.path}/x.pdf')..writeAsBytesSync(bytes);

    List<int> filler(int n) => List.filled(n, 0x41); // 'A'

    test('anahtar yoksa false, varsa true', () {
      expect(PdfFormFiller.scanForAcroFormSync(write(filler(5000)).path),
          isFalse);
      final f = write([...filler(3000), ...'/AcroForm'.codeUnits, ...filler(9)]);
      expect(PdfFormFiller.scanForAcroFormSync(f.path), isTrue);
    });

    test('blok sınırında bölünmüş anahtar bulunur', () {
      const block = 64;
      final key = '/AcroForm'.codeUnits;
      // Sınırın her olası yarılmasını dene.
      for (var cut = 1; cut < key.length; cut++) {
        final f = write([...filler(block - cut), ...key, ...filler(50)]);
        expect(PdfFormFiller.scanForAcroFormSync(f.path, blockSize: block),
            isTrue,
            reason: 'kesim $cut');
      }
    });

    test('yarım anahtar (dosya sonu) false; yok dosya false', () {
      final f = write([...filler(10), ...'/AcroFor'.codeUnits]);
      expect(PdfFormFiller.scanForAcroFormSync(f.path, blockSize: 8), isFalse);
      expect(PdfFormFiller.scanForAcroFormSync('${dir.path}/yok.pdf'), isFalse);
    });

    test('büyük dosyada yalnız baş ve son taranır', () {
      final key = '/AcroForm'.codeUnits;
      const edge = 100;
      // Sonda (olağan katalog yeri) ve başta (doğrusallaştırılmış) bulunur.
      expect(
          PdfFormFiller.scanForAcroFormSync(
              write([...filler(1000), ...key, ...filler(20)]).path,
              blockSize: 32, edgeBytes: edge),
          isTrue);
      expect(
          PdfFormFiller.scanForAcroFormSync(
              write([...filler(20), ...key, ...filler(1000)]).path,
              blockSize: 32, edgeBytes: edge),
          isTrue);
      // Ortada kalan anahtar bilinçli olarak görülmez (dosyanın tamamı okunmaz).
      expect(
          PdfFormFiller.scanForAcroFormSync(
              write([...filler(500), ...key, ...filler(500)]).path,
              blockSize: 32, edgeBytes: edge),
          isFalse);
      // Uç sınırına tam oturan anahtar (son `edge` baytın başında).
      expect(
          PdfFormFiller.scanForAcroFormSync(
              write([...filler(500), ...key, ...filler(edge - key.length)])
                  .path,
              blockSize: 32, edgeBytes: edge),
          isTrue);
    });

    test('izolatlı looksLikeForm aynı cevabı verir', () async {
      final f = write([...filler(100), ...'/AcroForm'.codeUnits]);
      expect(await PdfFormFiller.looksLikeForm(f.path), isTrue);
    });
  });

  test('DocxEditor.openForView izolattan çalışan bir model döndürür',
      () async {
    final bytes = Uint8List.fromList(
        File('test/fixtures/office/madde_imleri.docx').readAsBytesSync());
    final sync = DocxEditor.parse(bytes);
    final syncView = sync.viewBytes();

    final opened = await DocxEditor.openForView(bytes);
    expect(DocxEditor.debugOpenedInIsolate, isTrue,
        reason: 'model izolattan gönderilebilmeli (yedek yola düşmemeli)');
    expect(opened.editor.paragraphs.length, sync.paragraphs.length);
    expect([for (final p in opened.editor.paragraphs) p.text],
        [for (final p in sync.paragraphs) p.text]);
    expect(opened.view.length, syncView.length);
    // Gelen model düzenlenip kaydedilebilmeli (izolattan sağ çıktı mı?).
    final saved = await opened.editor.saveAsync();
    expect(DocxEditor.parse(saved).paragraphs.length, sync.paragraphs.length);
  });
}
