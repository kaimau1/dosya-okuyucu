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

  /// ML Kit güven puanı (0–1); bulut/Arapça yolu vermez → null (işaretlenmez).
  final double? confidence;
  const OcrWordBox(this.text, this.box, {this.confidence});
}

/// Bu puanın altındaki sözcük düzeltme ekranında "emin değilim" işareti alır
/// (P19 m.4). ponytail: sabit eşik; cihazda fazla/az işaret çıkarsa ayarla.
const ocrLowConfidence = 0.6;

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
    this.lowRanges = const [],
  });

  /// Düşük güvenli sözcüklerin [fullText] içindeki `(başlangıç, bitiş)`
  /// aralıkları (bitiş hariç). Yalnız düzeltme ekranı okur.
  final List<(int, int)> lowRanges;
}

/// [frag] içindeki düşük güvenli sözcüklerin PDF kutuları (sözcük başına bir).
List<PdfRect> lowConfidenceRects(OcrPageText text, PdfPageTextFragment frag) {
  final end = frag.index + frag.length;
  return [
    for (final (s, e) in text.lowRanges)
      if (s >= frag.index && e <= end && e > s)
        frag.charRects.sublist(s - frag.index, e - frag.index).boundingRect(),
  ];
}

/// Parça = (metindeki başlangıç, karakter kutuları); metin uzunluğu kutu sayısı.
typedef OcrFrag = ({int index, List<PdfRect> rects});

/// pdfrx 2.x'te parça sayfaya geri başvurur (`pageText`): önce sayfa boş
/// parça listesiyle kurulur, parçalar sonra eklenir. Sayfanın `charRects`'i
/// parçalarınkinin art arda dizilişi (metinle birebir aynı uzunlukta).
OcrPageText assembleOcrPageText(int pageNumber, String fullText, List<OcrFrag> frags,
    {List<(int, int)> lowRanges = const []}) {
  final page = OcrPageText._(
    pageNumber: pageNumber,
    fullText: fullText,
    charRects: [for (final f in frags) ...f.rects],
    fragments: <PdfPageTextFragment>[],
    lowRanges: lowRanges,
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
/// Satır sırası ML Kit'in blok/satır sırasıdır (kabaca okuma sırası) —
/// çok sütunlu YAZIDA salt y-sıralaması sütunları karıştırırdı. İSTİSNA
/// **tablo** ([orderOcrRows], 2026-11-15): ML Kit tabloyu sütun sütun okur
/// (önce tüm adlar, sonra tüm sayılar); seçim metin sırasında ilerlediği için
/// iki satır arasına sürüklemek öbür sütuna atlıyordu ("1 1 1 … 44"). Tablo
/// sayfasında aynı yükseklikteki hücreler TEK görsel satırda, soldan sağa,
/// sekmeyle ayrılarak birleşir (kopyalanınca tabloya da yapışır).
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
  final low = <(int, int)>[];

  for (final row in orderOcrRows(lines)) {
    // Hücre (segment) sınırı: bu sözcükten önce sekme yazılır.
    final cellStart = <int>{};
    final words = <OcrWordBox>[];
    for (final seg in row) {
      if (words.isNotEmpty) cellStart.add(words.length);
      words.addAll(seg);
    }
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
        lineText.write(cellStart.contains(wi) ? '\t' : ' ');
        charRects.add(toPdf(Rect.fromLTRB(
          left,
          prev.top < w.box.top ? prev.top : w.box.top,
          right,
          prev.bottom > w.box.bottom ? prev.bottom : w.box.bottom,
        )));
      }
      final c = w.confidence;
      if (c != null && c < ocrLowConfidence) {
        final s = lineStart + lineText.length;
        low.add((s, s + w.text.length));
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
  return assembleOcrPageText(pageNumber, buffer.toString(), fragments,
      lowRanges: low);
}

/// Satırları görsel satırlara dizer: satır → hücreler → sözcükler.
///
/// Varsayılan: her ML Kit satırı tek hücreli bir satır, sıra korunur.
/// Sayfa **tablo** görünüyorsa (aynı yükseklikte yan yana duran satırların
/// çoğunda dar bir hücre — sayı/kod sütunu — var) yan yana duranlar tek
/// satırda birleşir ve satırlar yukarıdan aşağı sıralanır. İki sütunlu düz
/// yazıda yan yana satırların ikisi de geniştir → dokunulmaz.
List<List<List<OcrWordBox>>> orderOcrRows(List<List<OcrWordBox>> lines) {
  final clean = <List<OcrWordBox>>[
    for (final line in lines)
      [
        for (final w in line)
          if (w.text.isNotEmpty && !w.box.isEmpty) w,
      ],
  ]..removeWhere((l) => l.isEmpty);
  final plain = [
    for (final l in clean) [l],
  ];
  if (clean.length < 4) return plain;

  Rect boxOf(List<OcrWordBox> l) =>
      l.skip(1).fold(l.first.box, (r, w) => r.expandToInclude(w.box));
  final boxes = [for (final l in clean) boxOf(l)];
  var minL = boxes.first.left, maxR = boxes.first.right;
  for (final b in boxes) {
    if (b.left < minL) minL = b.left;
    if (b.right > maxR) maxR = b.right;
  }
  final pageW = maxR - minL;
  if (pageW <= 0) return plain;

  // Yukarıdan aşağı; aynı satıra düşenler (dikey örtüşme ≥ küçük boyun
  // yarısı, yatayda örtüşmeyen) bir araya.
  final order = List.generate(clean.length, (i) => i)
    ..sort((a, b) => boxes[a].center.dy.compareTo(boxes[b].center.dy));
  final rows = <List<int>>[];
  final rowBox = <Rect>[];
  for (final i in order) {
    final b = boxes[i];
    var placed = false;
    for (var r = rows.length - 1; r >= 0 && r >= rows.length - 3; r--) {
      final rb = rowBox[r];
      final overlap = (b.bottom < rb.bottom ? b.bottom : rb.bottom) -
          (b.top > rb.top ? b.top : rb.top);
      final minH = b.height < rb.height ? b.height : rb.height;
      if (overlap < minH * 0.5) continue;
      final clash = rows[r].any((j) =>
          boxes[j].left < b.right && b.left < boxes[j].right);
      if (clash) continue;
      rows[r].add(i);
      rowBox[r] = rb.expandToInclude(b);
      placed = true;
      break;
    }
    if (!placed) {
      rows.add([i]);
      rowBox.add(b);
    }
  }

  final multi = rows.where((r) => r.length > 1).toList();
  if (multi.length < 3) return plain;
  final narrow = multi
      .where((r) => r.any((j) => boxes[j].width < pageW * 0.15))
      .length;
  // Tablo: yan yana satırların en az %60'ında dar hücre var ve sayfanın
  // önemli bir kısmı böyle satırlar.
  if (narrow < multi.length * 0.6 || multi.length < rows.length * 0.3) {
    return plain;
  }
  return [
    for (final r in rows)
      [
        for (final j in (r..sort((a, b) => boxes[a].left.compareTo(boxes[b].left))))
          clean[j],
      ],
  ];
}

/// [OcrPageText]'i JSON'a çevirir — **disk önbelleği** için (2026-08-05,
/// 4. tur: uygulama kapanıp açılınca taranmış sayfa yeniden OCR'lanmasın;
/// pil + "anında seçilebilir sayfa"). Saf fonksiyon, birim testli.
String encodeOcrPageText(OcrPageText text) => jsonEncode({
      // v2 (2026-11-15): tablo satır sırası — eski önbellek yeniden OCR'lanır.
      'v': 2,
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
      // P19 m.4: düşük güvenli sözcük aralıkları düz dizide (isteğe bağlı —
      // eski v2 girdisinde yok, işaretsiz okunur; yeniden OCR gerekmez).
      if (text.lowRanges.isNotEmpty)
        'low': [for (final (s, e) in text.lowRanges) ...[s, e]],
    });

/// [encodeOcrPageText] çıktısını geri çözer; biçim tanınmazsa/bozuksa null
/// (önbellek girdisi atılır, OCR yeniden koşar — asla hata fırlatmaz).
OcrPageText? decodeOcrPageText(String json) {
  try {
    final map = jsonDecode(json);
    if (map is! Map || map['v'] != 2) return null;
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
    final flatLow = ((map['low'] as List?) ?? const []).cast<int>();
    final low = <(int, int)>[
      for (var i = 0; i + 1 < flatLow.length; i += 2)
        if (flatLow[i] >= 0 &&
            flatLow[i] < flatLow[i + 1] &&
            flatLow[i + 1] <= fullText.length)
          (flatLow[i], flatLow[i + 1]),
    ];
    return assembleOcrPageText(map['page'] as int, fullText, fragments,
        lowRanges: low);
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
