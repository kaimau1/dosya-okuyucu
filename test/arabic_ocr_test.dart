import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/arabic_ocr.dart';
import 'package:dosya_okuyucu/services/ocr_service.dart';
import 'package:dosya_okuyucu/services/voice/neural_engine.dart';
import 'package:dosya_okuyucu/services/voice/neural_voices.dart';
import 'package:flutter_test/flutter_test.dart';

/// B16: internetsiz Arapça OCR'ın saf parçaları (model çıkarımı cihazda).
void main() {
  test('sözlük: 0 = CTC boşluğu, satır i = sınıf i, son sınıf boşluk', () {
    final chars = ArabicOcr.dictChars('\n!\nا\nب\n');
    expect(chars, ['', '!', 'ا', 'ب', ' ']);
  });

  test('CTC: boşluk ve art arda yinelenen atılır', () {
    final chars = ['', 'a', 'b', ' '];
    // t=6, c=4: a a _ a b ' '
    final steps = [1, 1, 0, 1, 2, 3];
    final logits = Float32List(steps.length * 4);
    for (var i = 0; i < steps.length; i++) {
      logits[i * 4 + steps[i]] = 1;
    }
    expect(ArabicOcr.ctcDecode(logits, steps.length, 4, chars), 'aab ');
  });

  test('görsel sıra → okuma sırası; Latin/rakam öbeği korunur', () {
    // Model çıktısı (Python ölçümü): "ميحرلا نمحرلا هللا مسب"
    expect(
      ArabicOcr.visualToLogical('ميحرلا نمحرلا هللا مسب'),
      'بسم الله الرحمن الرحيم',
    );
    expect(ArabicOcr.visualToLogical('123 بتك'), 'كتب 123');
  });

  test('olasılık haritası → satır kutusu (zayıf ve ince bileşen atılır)', () {
    const w = 40, h = 20;
    final prob = Float32List(w * h);
    for (var y = 5; y < 10; y++) {
      for (var x = 4; x < 30; x++) {
        prob[y * w + x] = 0.9;
      }
    }
    for (var x = 0; x < 40; x++) {
      prob[15 * w + x] = 0.9; // 1 px kalınlık → atılır
    }
    for (var y = 12; y < 14; y++) {
      for (var x = 30; x < 38; x++) {
        prob[y * w + x] = 0.4; // ortalama < 0,6 → atılır
      }
    }
    final boxes = ArabicOcr.boxesFromProb(prob, w, h);
    expect(boxes, hasLength(1));
    final b = boxes.single;
    expect(b.left, lessThan(4));
    expect(b.right, greaterThan(30));
    expect(b.top, lessThan(5));
    expect(b.bottom, greaterThan(10));
  });

  test('Arapça metin eşiği (otomatik kipte yerel sonucu tutma)', () {
    expect(OcrService.hasArabicText('بسم الله الرحمن'), isTrue);
    expect(OcrService.hasArabicText('abc def ghi jkl'), isFalse);
  });

  test('tensör çözümü: int32 başlık + float32 veri', () {
    final head = Int32List.fromList([3, 1, 2, 2]).buffer.asUint8List();
    final data = Float32List.fromList([1, 2, 3, 4]).buffer.asUint8List();
    final (t, dims) = NeuralVoiceEngine.decodeTensor(
      Uint8List.fromList([...head, ...data]),
    );
    expect(dims, [1, 2, 2]);
    expect(t, [1, 2, 3, 4]);
  });

  test('modeller sabit sürüm + SHA-256 (APK\'ya gömülü değil)', () {
    for (final f in ArabicOcr.files) {
      expect(f.url, contains('/resolve/3cbb2688'), reason: f.path);
      expect(f.sha256, matches(RegExp(r'^[0-9a-f]{64}$')), reason: f.path);
    }
  });

  test('yerel sunucu: girdi bellekten bir kez verilir', () async {
    final root = Directory.systemTemp.createTempSync('ocr_srv');
    addTearDown(() => root.deleteSync(recursive: true));
    final server = await VoiceServer.start(root.path);
    addTearDown(server.close);
    final c = HttpClient();
    addTearDown(c.close);
    server.provide('j9', Uint8List.fromList([7, 8]));
    final res = await (await c.getUrl(Uri.parse('${server.base}in/j9')))
        .close();
    expect(res.statusCode, 200);
    expect(await res.fold<List<int>>([], (a, b) => a..addAll(b)), [7, 8]);
    final again = await (await c.getUrl(Uri.parse('${server.base}in/j9')))
        .close();
    expect(again.statusCode, 404);
    await again.drain<void>();
  });
}
