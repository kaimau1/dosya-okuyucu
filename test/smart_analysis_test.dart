import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/smart_analysis.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

FsEntry _f(String path, {int size = 1000, int ms = 0}) => FsEntry(
    path: path,
    name: path.split('/').last,
    isDir: false,
    sizeBytes: size,
    modifiedMs: ms);

void main() {
  test('selamlaşma metni tanınır (şapka/ı duyarsız)', () {
    expect(SmartAnalysis.isGreeting('HAYIRLI CUMALAR\ndostlarım'), isTrue);
    expect(SmartAnalysis.isGreeting('Günaydın 🌸'), isTrue);
    expect(SmartAnalysis.isGreeting('gunaydin'), isTrue);
    expect(SmartAnalysis.isGreeting('Fatura tutarı 1.250 TL'), isFalse);
  });

  test('sınıflandırma önceliği', () {
    expect(SmartAnalysis.classify(const ImageTraits('iyi geceler', 1e9, 128)),
        SmartKind.greeting);
    expect(
        SmartAnalysis.classify(
            ImageTraits('a' * 80, 1e9, 128)),
        SmartKind.textHeavy);
    expect(SmartAnalysis.classify(const ImageTraits('', 1e9, 5)), SmartKind.dark);
    expect(SmartAnalysis.classify(const ImageTraits('', 10, 128)),
        SmartKind.blurry);
    expect(SmartAnalysis.classify(const ImageTraits('', 1e9, 128)), isNull);
  });

  test('kopya adlı indirme: aslı aynı boyutta aynı klasörde olmalı', () {
    final docs = [
      _f('/d/Download/rapor.pdf', size: 500),
      _f('/d/Download/rapor (1).pdf', size: 500),
      _f('/d/Download/sunum (2).pptx', size: 900), // aslı yok
      _f('/d/Download/not.txt', size: 10),
      _f('/d/Download/not (1).txt', size: 11), // boyut farklı
    ];
    expect(SmartAnalysis.copyNamed(docs).map((e) => e.name), ['rapor (1).pdf']);
    expect(SmartAnalysis.copyBase('a - Kopya.docx'), 'a.docx');
  });

  test('ölçüm: düz gri bulanık, dama tahtası net; siyah karanlık', () {
    final flat = img.Image(width: 200, height: 200)
      ..clear(img.ColorRgb8(120, 120, 120));
    final chess = img.Image(width: 200, height: 200);
    for (var y = 0; y < 200; y++) {
      for (var x = 0; x < 200; x++) {
        final on = ((x ~/ 3) + (y ~/ 3)).isEven;
        chess.setPixelRgb(x, y, on ? 255 : 0, on ? 255 : 0, on ? 255 : 0);
      }
    }
    final black = img.Image(width: 100, height: 100)..clear(img.ColorRgb8(3, 3, 3));
    final m1 = SmartAnalysis.measure(img.encodePng(flat))!;
    final m2 = SmartAnalysis.measure(img.encodePng(chess))!;
    final m3 = SmartAnalysis.measure(img.encodePng(black))!;
    expect(m1.$1, lessThan(SmartAnalysis.blurThreshold));
    expect(m2.$1, greaterThan(SmartAnalysis.blurThreshold));
    expect(m3.$2, lessThan(SmartAnalysis.darkThreshold));
  });

  test('sohbet görselleri: OCR ile kova, önbellek ikinci turda OCR çağırmaz',
      () async {
    final dir = Directory.systemTemp.createTempSync('sa');
    addTearDown(() => dir.deleteSync(recursive: true));
    final wa = Directory('${dir.path}/WhatsApp/Media/WhatsApp Images')
      ..createSync(recursive: true);
    final greet = File('${wa.path}/IMG-1.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 50, height: 50)
        ..clear(img.ColorRgb8(200, 150, 100))));
    final shot = File('${wa.path}/Screenshot_1.jpg')
      ..writeAsBytesSync(greet.readAsBytesSync());
    final entries = [
      for (final f in [greet, shot])
        FsEntry(
            path: f.path,
            name: f.path.split('/').last,
            isDir: false,
            sizeBytes: f.lengthSync(),
            modifiedMs: 1),
    ];
    var ocrCalls = 0;
    Future<String> ocr(String path) async {
      ocrCalls++;
      return 'Hayırlı Cumalar';
    }

    final cache = File('${dir.path}/cache.json');
    final b = await SmartAnalysis.analyzeChatImages(entries,
        ocr: ocr, cacheFile: cache);
    final kinds = {for (final x in b) x.kind: x.files.length};
    expect(kinds[SmartKind.greeting], 1);
    expect(kinds[SmartKind.screenshot], 1);
    expect(ocrCalls, 1);
    await SmartAnalysis.analyzeChatImages(entries, ocr: ocr, cacheFile: cache);
    expect(ocrCalls, 1, reason: 'önbellekten');
  });
}
