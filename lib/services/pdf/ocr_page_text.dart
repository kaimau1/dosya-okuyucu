import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:ui' show Rect;

import 'package:pdfrx/pdfrx.dart';

/// OCR'ın tanıdığı TEK SÖZCÜK: metin + görüntü **piksel** koordinatında kutu
/// (sol-üst köşe orijinli, y aşağı doğru — ML Kit'in verdiği hâliyle).
///
/// Bilerek ML Kit tipi değil: bu dosya saf Dart kalsın diye (birim testleri
/// Linux'ta ML Kit olmadan koşar). `OcrService` ML Kit `TextElement`'larını
/// buna çevirir.
class OcrWordBox {
  final String text;
  final Rect box;
  const OcrWordBox(this.text, this.box);
}

/// Taranmış sayfanın OCR sonucu, pdfrx'in metin katmanıyla AYNI biçimde.
///
/// Niye `PdfPageText`in alt sınıfı: seçim katmanı (`PdfSelectLayer`) pdfium
/// metnini `fullText` + `fragments[].charRects` üzerinden işler. OCR sonucu da
/// aynı arayüzü giyince katman "yazılmış mı taranmış mı" hiç bilmeden çalışır —
/// iki ayrı seçim yolu (ve iki kat hata yüzeyi) yerine tek yol.
class OcrPageText extends PdfPageText {
  OcrPageText._({
    required super.pageNumber,
    required super.fullText,
    required super.charRects,
    required super.fragments,
  });
}

/// Parça = (metindeki başlangıç, karakter kutuları); metin uzunluğu kutu sayısı.
typedef OcrFrag = ({int index, List<PdfRect> rects});

/// pdfrx 2.x'te parça sayfaya geri başvurur (`pageText`): önce sayfa boş
/// parça listesiyle kurulur, parçalar sonra eklenir. Sayfanın `charRects`'i
/// parçalarınkinin art arda dizilişi (metinle birebir aynı uzunlukta).
OcrPageText assembleOcrPageText(int pageNumber, String fullText, List<OcrFrag> frags) {
  final page = OcrPageText._(
    pageNumber: pageNumber,
    fullText: fullText,
    charRects: [for (final f in frags) ...f.rects],
    fragments: <PdfPageTextFragment>[],
  );
  page.fragments.addAll([
    for (final f in frags)
      PdfPageTextFragment(
        pageText: page,
        index: f.index,
        length: f.rects.length,
        bounds: f.rects.boundingRect(),
        charRects: f.rects,
        direction: PdfTextDirection.ltr,
      ),
  ]);
  return page;
}

/// ML Kit sözcük satırlarından seçilebilir sayfa metni kurar; sözcük yoksa
/// null döner.
///
/// [lines]: satır başına sözcük listesi (görüntü piksel koordinatında).
/// [imageScale]: görüntü pikseli / PDF punto oranı (sayfa `scale` katıyla
/// çizildiyse aynı `scale`). [pageHeight] PDF puntosu — y ekseni ÇEVRİLİR:
/// PDF'te orijin sol-ALT köşedir ve `PdfRect.top > bottom` olmalıdır.
///
/// Yapı: satır başına BİR fragment. Fragment metni sözcüklerin tek boşlukla
/// birleşimi + satır sonunda '\n'. `charRects` metinle birebir aynı uzunlukta:
/// * sözcük karakterleri → sözcük kutusunun eşit dilimleri (OCR karakter
///   kutusu vermez; eşit bölme, seçim tutamaçlarının sözcük içinde makul
///   konumlanması için yeter — Chrome'un OCR katmanı da aynı kabulü yapar),
/// * sözcük arası boşluk → iki kutu ARASINDAKİ aralık (seçim vurgusu kesintisiz
///   görünsün; aralık negatifse sınırda sıfır genişlik),
/// * '\n' → satır sonunda sıfır genişlik kutu.
///
/// Satır sırası ML Kit'in blok/satır sırasıdır (kabaca okuma sırası).
/// BİLİNÇLİ olarak yeniden SIRALANMAZ: çok sütunlu sayfada salt y-koordinat
/// sıralaması sütunları birbirine karıştırır, ML Kit'in blok gruplaması ise
/// sütunu bütün tutar.
OcrPageText? buildOcrPageText({
  required int pageNumber,
  required double pageHeight,
  required double imageScale,
  required List<List<OcrWordBox>> lines,
}) {
  if (imageScale <= 0) return null;

  PdfRect toPdf(Rect px) => PdfRect(
        px.left / imageScale,
        pageHeight - px.top / imageScale,
        px.right / imageScale,
        pageHeight - px.bottom / imageScale,
      );

  final buffer = StringBuffer();
  final fragments = <OcrFrag>[];

  for (final line in lines) {
    final words = [
      for (final w in line)
        if (w.text.isNotEmpty && !w.box.isEmpty) w,
    ];
    if (words.isEmpty) continue;

    final lineStart = buffer.length;
    final lineText = StringBuffer();
    final charRects = <PdfRect>[];

    for (var wi = 0; wi < words.length; wi++) {
      final w = words[wi];
      if (wi > 0) {
        // Sözcük arası boşluk: önceki kutunun sağından bu kutunun soluna.
        final prev = words[wi - 1].box;
        final left = prev.right;
        final right = w.box.left > left ? w.box.left : left;
        lineText.write(' ');
        charRects.add(toPdf(Rect.fromLTRB(
          left,
          prev.top < w.box.top ? prev.top : w.box.top,
          right,
          prev.bottom > w.box.bottom ? prev.bottom : w.box.bottom,
        )));
      }
      lineText.write(w.text);
      final n = w.text.length;
      final sliceW = w.box.width / n;
      for (var ci = 0; ci < n; ci++) {
        charRects.add(toPdf(Rect.fromLTRB(
          w.box.left + sliceW * ci,
          w.box.top,
          ci == n - 1 ? w.box.right : w.box.left + sliceW * (ci + 1),
          w.box.bottom,
        )));
      }
    }

    // Satır sonu '\n': sıfır genişlik, satırın sağ ucunda.
    final last = words.last.box;
    lineText.write('\n');
    charRects.add(toPdf(Rect.fromLTRB(last.right, last.top, last.right, last.bottom)));

    final text = lineText.toString();
    buffer.write(text);
    fragments.add((index: lineStart, rects: charRects));
  }

  if (fragments.isEmpty) return null;
  return assembleOcrPageText(pageNumber, buffer.toString(), fragments);
}

/// [OcrPageText]'i JSON'a çevirir — **disk önbelleği** için (2026-08-05,
/// 4. tur: uygulama kapanıp açılınca taranmış sayfa yeniden OCR'lanmasın;
/// pil + "anında seçilebilir sayfa"). Saf fonksiyon, birim testli.
String encodeOcrPageText(OcrPageText text) => jsonEncode({
      'v': 1,
      'page': text.pageNumber,
      'text': text.fullText,
      'frags': [
        for (final f in text.fragments)
          {
            'i': f.index,
            't': f.text,
            // Kutu başına 4 sayı düz dizide: JSON küçük kalsın (sayfa başına
            // yüzlerce karakter kutusu var).
            'r': [
              for (final r in f.charRects) ...[r.left, r.top, r.right, r.bottom],
            ],
          },
      ],
    });

/// [encodeOcrPageText] çıktısını geri çözer; biçim tanınmazsa/bozuksa null
/// (önbellek girdisi atılır, OCR yeniden koşar — asla hata fırlatmaz).
OcrPageText? decodeOcrPageText(String json) {
  try {
    final map = jsonDecode(json);
    if (map is! Map || map['v'] != 1) return null;
    final fullText = map['text'] as String;
    final fragments = <OcrFrag>[];
    for (final f in map['frags'] as List) {
      final text = f['t'] as String;
      final flat = (f['r'] as List).cast<num>();
      if (flat.length != text.length * 4) return null;
      final rects = <PdfRect>[
        for (var i = 0; i < flat.length; i += 4)
          PdfRect(flat[i].toDouble(), flat[i + 1].toDouble(),
              flat[i + 2].toDouble(), flat[i + 3].toDouble()),
      ];
      final index = f['i'] as int;
      // Parça metni tam metinle tutarlı olmalı (bozuk önbellek girdisi atılır).
      if (index + text.length > fullText.length ||
          fullText.substring(index, index + text.length) != text) {
        return null;
      }
      fragments.add((index: index, rects: rects));
    }
    if (fragments.isEmpty) return null;
    return assembleOcrPageText(map['page'] as int, fullText, fragments);
  } catch (_) {
    return null;
  }
}

/// Kararlı, bağımlılıksız 64-bit FNV-1a özeti — önbellek dosya adı için
/// (belge yolu + mtime + boyut → aynı belge aynı ada, değişen belge yeni ada).
/// `hashCode` KULLANILAMAZ: Dart onun oturumlar arası kararlılığını vaat etmez.
String fnv1a(String input) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = hash * 0x100000001b3; // Dart VM 64-bit sarmalı çarpım
  }
  // İşaret biti atılır: `toRadixString` negatif sayıya '-' koyar, dosya adında
  // istemeyiz. 63 bit önbellek anahtarı için fazlasıyla yeter.
  return (hash & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
}
