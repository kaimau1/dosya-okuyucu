import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:dosya_okuyucu/widgets/signature_pad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  List<int> blankPdf() {
    final doc = PdfDocument();
    doc.pages.add();
    final out = doc.saveSync();
    doc.dispose();
    return out;
  }

  Uint8List tinyPng() {
    final pic = img.Image(width: 24, height: 12);
    img.fill(pic, color: img.ColorRgb8(20, 40, 120));
    return Uint8List.fromList(img.encodePng(pic));
  }

  group('Signature modeli (çiz / yaz / görsel + kayıtlılar)', () {
    test('çizim, yazılı imza ve görsel JSON gidiş-dönüşünü korur', () {
      final drawn = Signature.fromRaw([
        [const Offset(0, 0), const Offset(100, 50)],
      ]);
      expect(drawn.kind, SignatureKind.draw);
      final drawnBack = Signature.fromJson(drawn.toJson())!;
      expect(drawnBack.kind, SignatureKind.draw);
      expect(drawnBack.strokes.single.length, 2);

      final typed = Signature.typed('Ayşe Yılmaz');
      expect(typed.kind, SignatureKind.type);
      final typedBack = Signature.fromJson(typed.toJson())!;
      expect(typedBack.kind, SignatureKind.type);
      expect(typedBack.text, 'Ayşe Yılmaz');

      final imageSig = Signature.image(tinyPng(), 2.0);
      expect(imageSig.kind, SignatureKind.image);
      final imageBack = Signature.fromJson(imageSig.toJson())!;
      expect(imageBack.kind, SignatureKind.image);
      expect(imageBack.imageBytes, imageSig.imageBytes);
      expect(imageBack.aspect, 2.0);
    });

    test('kayıtlı imza ve baş harf kitaplıkları ayrı saklanır ve silinebilir',
        () async {
      final s1 = Signature.typed('Ayşe Yılmaz');
      final s2 = Signature.typed('Ali Kaya');
      final i1 = Signature.typed('AY');

      await s1.save();
      await s2.save();
      await i1.save(initials: true);

      final saved = await Signature.loadSaved();
      expect(saved.map((e) => e.text), ['Ali Kaya', 'Ayşe Yılmaz']);
      expect((await Signature.load())?.text, 'Ali Kaya');

      final savedInit = await Signature.loadSaved(initials: true);
      expect(savedInit.map((e) => e.text), ['AY']);

      await Signature.removeSaved(0);
      final after = await Signature.loadSaved();
      expect(after.map((e) => e.text), ['Ayşe Yılmaz']);
      expect((await Signature.load())?.text, 'Ayşe Yılmaz');
    });

    test('fromImageBytes görseli küçültüp PNG imza üretir', () async {
      final big = img.Image(width: 800, height: 200);
      img.fill(big, color: img.ColorRgb8(0, 0, 0));
      final sig = await Signature.fromImageBytes(
          Uint8List.fromList(img.encodePng(big)));
      expect(sig, isNotNull);
      expect(sig!.kind, SignatureKind.image);
      expect(sig.aspect, closeTo(4.0, 0.05));
    });
  });

  group('PdfTools.stampText & stampImage', () {
    test('yazılı imza ve tarih damgası Türkçe harflerle PDF içine basılır',
        () async {
      final font = File('assets/fonts/Tinos-Italic.ttf').readAsBytesSync();
      final out = await PdfTools.stampText(
        blankPdf(),
        pageIndex: 0,
        text: 'Ayşe Şahin · 26.11.2026',
        rect: const Rect.fromLTWH(50, 700, 220, 40),
        fontBytes: font,
      );
      final doc = PdfDocument(inputBytes: out);
      final extracted = PdfTextExtractor(doc).extractText();
      doc.dispose();
      expect(extracted, contains('Ayşe'));
      expect(extracted, contains('26.11.2026'));
    });

    test('görsel imza PDF sayfasına gömülür ve yeniden açılır', () async {
      final out = await PdfTools.stampImage(
        blankPdf(),
        pageIndex: 0,
        imageBytes: tinyPng(),
        rect: const Rect.fromLTWH(100, 650, 120, 60),
      );
      final doc = PdfDocument(inputBytes: out);
      expect(doc.pages.count, 1);
      doc.dispose();
      expect(out.length, greaterThan(blankPdf().length));
    });
  });
}
