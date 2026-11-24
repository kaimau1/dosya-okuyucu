import 'package:dosya_okuyucu/services/cloud_ocr.dart';
import 'package:dosya_okuyucu/services/ocr_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// AI ile metin tanıma (2026-11-18, ML Kit'te Arapça yok): yanıt çözme,
/// kutu dönüşümü, sözcük bölme, "zayıf sonuç" eşiği.
void main() {
  test('kutu 0–1000 → piksel; boş satır atlanır', () {
    final lines = CloudOcr.parse(
        '{"lines":[{"text":"مرحبا بالعالم","box":[100,200,150,800]},'
        '{"text":"  ","box":[0,0,1,1]}]}',
        2000,
        1000);
    expect(lines, hasLength(1));
    expect(lines.single.text, 'مرحبا بالعالم');
    expect(lines.single.box, const Rect.fromLTRB(400, 100, 1600, 150));
  });

  test('bozuk yanıt boş liste', () {
    expect(CloudOcr.parse('değil json', 10, 10), isEmpty);
    expect(CloudOcr.parse('{"x":1}', 10, 10), isEmpty);
  });

  test('Arapça satır sağdan sola sözcüklere bölünür', () {
    const line = OcrLine('ab cd', Rect.fromLTRB(0, 0, 50, 10));
    final ltr = CloudOcr.words(line);
    expect(ltr.first.box.left, 0);
    const ar = OcrLine('سلام عليكم', Rect.fromLTRB(0, 0, 100, 10));
    final rtl = CloudOcr.words(ar);
    expect(rtl.first.text, 'سلام');
    expect(rtl.first.box.right, 100);
    expect(rtl.last.box.left, closeTo(0, 0.001));
  });

  test('Latin modelin Arapça sayfadaki çıktısı zayıf sayılır', () {
    expect(CloudOcr.looksWeak(''), isTrue);
    expect(CloudOcr.looksWeak('J ! ll 1'), isTrue);
    expect(
        CloudOcr.looksWeak('Bu belge Türkçe yazılmış uzunca bir paragraftır.'),
        isFalse);
  });

  test('el yazısı tanıma çöpü bozuk sayılır, düzgün metin sayılmaz', () {
    expect(
        CloudOcr.looksGarbled(
            'deg er lend, Lmes yg olocoi te, Bi kt Sk rd ve'),
        isTrue);
    expect(
        CloudOcr.looksGarbled(
            'Yapılan son değerlendirmelere göre Ankara görülen sağanak '
            'yağışların bugün akşam saatlerinden itibaren etkisini arttırması'),
        isFalse);
    expect(CloudOcr.looksGarbled('kısa'), isFalse);
  });
}
