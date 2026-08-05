import 'pdf_font_map.dart';
import 'pdf_font_metrics.dart';
import 'pdf_syntax.dart';

/// Bir içerik akışında metin değiştirmenin sonucu.
class PdfContentReplacement {
  /// Yeni içerik akışı baytları.
  final List<int> content;

  /// Aranan metnin akışta kaç kez geçtiği. 1'den büyükse çağıran kullanıcıyı
  /// uyarmalı: hangisinin değiştirileceği belirsizdir.
  final int matchCount;

  /// Eşleşmenin bulunduğu kodlama (tanı/kayıt için).
  final String encoding;

  /// Satırın kalanı yeni metne göre **yeniden hizalandı mı**? (Word'deki gibi.)
  /// false ise ya genişlik farkı yoktu ya da hizalama güvenle yapılamadı.
  final bool reflowed;

  /// Hizalamadan sonra satır, sayfanın metin alanının dışına taşıyor mu?
  /// Çağıran kullanıcıyı KAYDETMEDEN önce uyarır.
  final bool overflows;

  const PdfContentReplacement({
    required this.content,
    required this.matchCount,
    required this.encoding,
    this.reflowed = false,
    this.overflows = false,
  });
}

/// Değiştirme neden yapılamadı?
enum PdfReplaceFailure {
  /// Metin bu akışta bulunamadı (fontun kodlaması çözülemiyor olabilir).
  notFound,

  /// Yeni metin özgün fontun kodlamasıyla yazılamıyor (glif yok).
  notEncodable,
}

class PdfReplaceException implements Exception {
  final PdfReplaceFailure failure;
  final String message;
  const PdfReplaceException(this.failure, this.message);
  @override
  String toString() => message;
}

/// [content] içerik akışındaki [oldText] metnini [newText] ile **yerinde**
/// değiştirir: aynı font, aynı konum, aynı grafik durumu korunur.
///
/// Yaklaşım — ve niye böyle:
/// * Metin, `Tj/TJ/'/"` operatörlerinin dizeleri BİRLEŞTİRİLEREK aranır.
///   PDF üreticileri bir cümleyi kerning yüzünden onlarca parçaya böler;
///   tek operatöre bakmak gerçek belgelerde neredeyse hiç eşleşmez.
/// * Arama **boşluklar yok sayılarak** yapılır. pdfium'un çıkardığı metin
///   (kullanıcının seçtiği şey) ile akıştaki ham dizeler boşluklarda ayrışır:
///   PDF'te iki kelime arası çoğu zaman boşluk KARAKTERİ değil, kerning
///   sayısıdır. Boşluğa takılan bir arama "metni bulamadım" derdi.
/// * Yalnız **etkilenen dizeler** yeniden yazılır; operatörün kendisi, dizi
///   yapısı ve aradaki kerning sayıları bayt bayt korunur. (Eskiden bütün
///   `TJ` dizisi tek dizeye indirgeniyordu — metin doğruydu ama harf aralıkları
///   siliniyordu, yani "hiç dokunulmadı" sözü tam doğru değildi.)
/// * Yeni metin eskisinden geniş/darsa **satırın kalanı kaydırılır** — belgenin
///   kendi glif genişlikleriyle ölçülerek (bkz. [PdfFontMetrics]). Word'de
///   yazarken satırın akması budur; PDF'te kendiliğinden olmaz.
///
/// Hiçbir kodlamada eşleşme yoksa [PdfReplaceFailure.notFound], yeni metin o
/// kodlamada yazılamıyorsa [PdfReplaceFailure.notEncodable] atar.
/// [precedingText] verilirse (seçimden hemen önce gelen metin) önce
/// `öncesi + aranan` bütünü aranır. Niye: aynı kelime sayfada birkaç kez
/// geçebilir ve yalnız kelimeye bakan bir arama YANLIŞ yeri değiştirirdi.
/// Bağlamla bulunamazsa sade aramaya düşülür.
///
/// **Kademeli eşleşme (2026-08-05, "isabet" turu).** pdfium'un çıkardığı metin
/// (kullanıcının seçtiği şey) ile akışın `/ToUnicode` çözümü ayrışabilir:
/// ligatür (akışta U+FB01 "ﬁ", seçimde "fi"), tipografik tırnak/çizgi
/// (’ karşı ', – karşı -) ve **büyük/küçük harf** (küçük-büyük harf fontları
/// ya da tablo tutarsızlıkları; kullanıcı bulgusu 2026-08-05: *"büyük küçük
/// yazım... şu an yeterli değil"*). Birebir arama bu belgelerde "bulunamadı"
/// deyip kullanıcıyı üstü-kapatma yedeğine düşürüyordu. Şimdi üç geçiş var:
/// 1. birebir; 2. katlama (ligatür açılır, tırnak/çizgi türleri tekilleşir);
/// 3. katlama + Türkçe küçük harf (İ→i, I→ı — `toLowerCase` OLMAZ: Dart
/// 'İ'.toLowerCase() 'i̇' (i + birleşen nokta) üretir ve eşleşme yine kaçar).
/// Yazılan yeni metin kullanıcının yazdığıdır, dönüşüm YALNIZ aramada.
///
/// [nearX]/[nearY] verilirse (seçimin PDF-koordinat merkezi) ve aynı geçişte
/// birden çok eşleşme varsa **konuma en yakın olan** değiştirilir — aynı
/// kelime sayfada iki kez geçtiğinde kullanıcının DOKUNDUĞU değişir, ilk
/// bulunan değil. Bağlam öneki yine önceliklidir; konum, bağlamın da çözemediği
/// (ya da bağlamsız) durumların hakemidir.
/// [fontEncodings] sayfanın font kaynaklarının `/ToUnicode` eşlemeleridir
/// (kaynak adı → eşleme). **Öncelikli yol budur:** belgenin kendi tablosunu
/// kullandığımız için alt küme gömülü ve Type0/Identity-H fontlar da çalışır,
/// yani yeni metin belgenin ÖZGÜN yazı tipiyle yazılır. Eşleme yoksa ya da
/// metni bulamazsa tek baytlık tahmin tablolarına düşülür.
/// [fontMetrics] glif genişlikleridir; yoksa yeniden hizalama yapılmaz.
/// [mediaBox] verilirse taşma denetlenir.
PdfContentReplacement replaceTextInContent(
  List<int> content,
  String oldText,
  String newText, {
  String precedingText = '',
  Map<String, PdfFontEncoding> fontEncodings = const {},
  Map<String, PdfFontMetrics> fontMetrics = const {},
  List<double>? mediaBox,
  List<PdfSingleByteEncoding>? encodings,
  double? nearX,
  double? nearY,
}) {
  final measure = _measureFor(fontEncodings, fontMetrics);
  final scan = scanContent(content, measure: measure);
  final ops = scan.textOps;
  if (ops.isEmpty) {
    throw const PdfReplaceException(
        PdfReplaceFailure.notFound, 'Bu sayfada düzenlenebilir metin yok.');
  }

  // Dönüşüm kademeleri: birebir → katlama → katlama + Türkçe küçük harf.
  const transforms = <String Function(String)?>[null, _fold, _foldLower];

  // 1) Fontun kendi /ToUnicode tablosu.
  if (fontEncodings.isNotEmpty) {
    final pieces = [
      for (final op in ops)
        _decodePieces(
            op, (op) => fontEncodings[op.fontName]?.decode ?? _latin1Decode),
    ];
    final texts = [for (final p in pieces) p.join()];
    for (final transform in transforms) {
      final match = _findBest(texts, oldText,
          prefix: precedingText,
          transform: transform,
          ops: ops,
          nearX: nearX,
          nearY: nearY);
      if (match == null) continue;
      return _apply(
        content: content,
        scan: scan,
        pieces: pieces,
        texts: texts,
        match: match,
        newText: newText,
        encoderFor: (op) =>
            fontEncodings[op.fontName]?.encode ??
            PdfSingleByteEncoding.latin1.encode,
        measure: measure,
        mediaBox: mediaBox,
        encodingName: 'ToUnicode',
        matchCount: _countFlexible(texts, oldText, transform: transform),
      );
    }
  }

  // 2) Yedek: yaygın tek baytlık kodlamalar.
  for (final transform in transforms) {
    for (final enc in encodings ?? PdfSingleByteEncoding.candidates) {
      final pieces = [
        for (final op in ops) _decodePieces(op, (_) => enc.decode),
      ];
      final texts = [for (final p in pieces) p.join()];
      final match = _findBest(texts, oldText,
          prefix: precedingText,
          transform: transform,
          ops: ops,
          nearX: nearX,
          nearY: nearY);
      if (match == null) continue;
      return _apply(
        content: content,
        scan: scan,
        pieces: pieces,
        texts: texts,
        match: match,
        newText: newText,
        encoderFor: (_) => enc.encode,
        measure: measure,
        mediaBox: mediaBox,
        encodingName: enc.name,
        matchCount: _countFlexible(texts, oldText, transform: transform),
      );
    }
  }

  throw const PdfReplaceException(
    PdfReplaceFailure.notFound,
    'Bu metin belgenin içinde bulunamadı. Sayfa taranmış (resim) olabilir ya '
    'da yazı tipi metin eşlemesi taşımıyor olabilir.',
  );
}

String _latin1Decode(List<int> bytes) => PdfSingleByteEncoding.latin1
    .decode(bytes);

/// Operatörün her DİZESİNİN ayrı ayrı çözülmüş metni.
///
/// Dize dize tutmak şart: yeniden yazarken yalnız eşleşmenin dokunduğu dizeyi
/// değiştiriyoruz, ötekiler ve aradaki kerning sayıları baytı baytına kalıyor.
List<String> _decodePieces(
    PdfTextOp op, String Function(List<int>) Function(PdfTextOp) decoderFor) {
  final decode = decoderFor(op);
  return [for (final s in op.strings) decode(s.bytes)];
}

/// Baytları ölçen geri çağırım: kod uzunluğunu kodlamadan, genişlikleri
/// belgenin kendi tablosundan alır.
PdfMeasure _measureFor(Map<String, PdfFontEncoding> encodings,
    Map<String, PdfFontMetrics> metrics) {
  return (fontName, bytes) {
    final m = metrics[fontName];
    if (m == null) return null;
    final codeBytes = encodings[fontName]?.codeBytes ?? 1;
    if (codeBytes <= 0 || bytes.length % codeBytes != 0) return null;
    final codes = <int>[];
    var spaces = 0;
    for (var i = 0; i + codeBytes <= bytes.length; i += codeBytes) {
      var code = 0;
      for (var b = 0; b < codeBytes; b++) {
        code = (code << 8) | bytes[i + b];
      }
      codes.add(code);
      if (codeBytes == 1 && code == 32) spaces++;
    }
    final width = m.widthOfCodes(codes);
    if (width == null) return null;
    return PdfGlyphRun(
        width1000: width, glyphCount: codes.length, spaceCount: spaces);
  };
}

/// Eşleşmenin operatör/karakter koordinatları.
class _Match {
  final int firstOp;
  final int firstOffset; // firstOp metninde eşleşmenin başladığı karakter
  final int lastOp;
  final int lastOffset; // lastOp metninde eşleşmenin bittiği karakter (hariç)
  const _Match(this.firstOp, this.firstOffset, this.lastOp, this.lastOffset);
}

/// Bir bayt aralığının yerine yazılacak baytlar.
class _Splice {
  final int start;
  final int end;
  final List<int> bytes;
  const _Splice(this.start, this.end, this.bytes);
}

/// Katlama: ligatürler açılır, tipografik tırnak/çizgi türleri tekilleşir.
/// pdfium ile /ToUnicode çoğu belgede bu karakterlerde ayrışır.
String _fold(String ch) => switch (ch) {
      'ﬀ' => 'ff',
      'ﬁ' => 'fi',
      'ﬂ' => 'fl',
      'ﬃ' => 'ffi',
      'ﬄ' => 'ffl',
      'ﬅ' => 'ft',
      'ﬆ' => 'st',
      '‘' || '’' || '‚' || '′' || 'ʼ' => "'",
      '“' || '”' || '„' || '″' => '"',
      '‐' || '‑' || '‒' || '–' || '—' || '−' =>
        '-',
      '…' => '...',
      _ => ch,
    };

/// Katlama + Türkçe küçük harf. `toLowerCase` KULLANILMAZ:
/// Dart'ta 'İ'.toLowerCase() 'i̇' (i + U+0307 birleşen nokta) üretir ve
/// pdfium'un düz 'i'siyle yine eşleşmez; I/İ elle eşlenir.
String _foldLower(String ch) {
  final folded = _fold(ch);
  final out = StringBuffer();
  for (var i = 0; i < folded.length; i++) {
    final c = folded[i];
    out.write(switch (c) {
      'İ' => 'i',
      'I' => 'ı',
      _ => c.toLowerCase(),
    });
  }
  return out.toString();
}

/// Boşlukları yok sayarak TÜM eşleşmeleri toplar, [nearX]/[nearY] verilmişse
/// konuma en yakınını döndürür.
///
/// Sıra: önce `prefix + needle` (bağlam) eşleşmeleri, boşsa sade eşleşmeler;
/// her iki kümede de konum hakemdir. [transform] arama-anı dönüşümüdür
/// (katlama/harf) — koordinat eşlemesi özgün karakterlere göre tutulur,
/// değiştirme özgün baytlara iner.
_Match? _findBest(
  List<String> texts,
  String needle, {
  String prefix = '',
  String Function(String)? transform,
  required List<PdfTextOp> ops,
  double? nearX,
  double? nearY,
}) {
  final withPrefix = prefix.isEmpty
      ? const <_Match>[]
      : _findAllFlexible(texts, needle, prefix: prefix, transform: transform);
  final candidates = withPrefix.isNotEmpty
      ? withPrefix
      : _findAllFlexible(texts, needle, transform: transform);
  if (candidates.isEmpty) return null;
  if (candidates.length == 1 || nearX == null || nearY == null) {
    return candidates.first;
  }
  _Match best = candidates.first;
  var bestScore = double.infinity;
  for (final m in candidates) {
    final op = ops[m.firstOp];
    if (!op.xKnown || op.event.isRotated) continue;
    // Dikey uzaklık ağır basar: kullanıcı satırı seçti, aynı satırın başka
    // sütunundaki eşleşme yataydan gelir.
    final score = (op.matrix[5] - nearY).abs() * 3 + (op.matrix[4] - nearX).abs();
    if (score < bestScore) {
      bestScore = score;
      best = m;
    }
  }
  return best;
}

/// [needle]'ın (istenirse `prefix+needle` bütününün) BÜTÜN eşleşmeleri.
///
/// [prefix] verilirse yalnız needle kısmının koordinatı döndürülür (bağlam
/// değiştirilmez, sadece yeri bulur).
List<_Match> _findAllFlexible(
  List<String> texts,
  String needle, {
  String prefix = '',
  String Function(String)? transform,
}) {
  final (hay, opIndex, charIndex) = _flatten(texts, transform: transform);
  final target = _stripSpaces(needle, transform: transform);
  if (target.isEmpty) return const [];
  final head = _stripSpaces(prefix, transform: transform);
  if (head.isEmpty && prefix.isNotEmpty) return const [];
  final whole = '$head$target';
  final out = <_Match>[];
  var from = 0;
  while (true) {
    final at0 = hay.indexOf(whole, from);
    if (at0 < 0) break;
    from = at0 + 1;
    final at = at0 + head.length;
    final endAt = at + target.length - 1;
    if (endAt >= opIndex.length) break;
    out.add(_Match(
      opIndex[at],
      charIndex[at],
      opIndex[endAt],
      charIndex[endAt] + 1,
    ));
  }
  return out;
}

int _countFlexible(List<String> texts, String needle,
    {String Function(String)? transform}) {
  final (hay, _, __) = _flatten(texts, transform: transform);
  final target = _stripSpaces(needle, transform: transform);
  if (target.isEmpty) return 0;
  var count = 0;
  var from = 0;
  while (true) {
    final at = hay.indexOf(target, from);
    if (at < 0) return count;
    count++;
    from = at + 1;
  }
}

/// Tüm operatör metinlerini boşluksuz tek dizeye indirger; her karakterin
/// hangi operatörün kaçıncı karakteri olduğunu tutar. [transform] bir kaynak
/// karakteri 1..n arama karakterine açabilir (ligatür); açılan her karakter
/// AYNI kaynak (operatör, karakter) çiftine eşlenir — böylece eşleşme sınırı
/// ligatürün ortasına düşse bile değiştirme bütün kaynak karakteri kapsar.
(String, List<int>, List<int>) _flatten(List<String> texts,
    {String Function(String)? transform}) {
  final buffer = StringBuffer();
  final opIndex = <int>[];
  final charIndex = <int>[];
  for (var o = 0; o < texts.length; o++) {
    final text = texts[o];
    for (var c = 0; c < text.length; c++) {
      if (_isSpace(text.codeUnitAt(c))) continue;
      final unit = transform?.call(text[c]) ?? text[c];
      for (var u = 0; u < unit.length; u++) {
        buffer.writeCharCode(unit.codeUnitAt(u));
        opIndex.add(o);
        charIndex.add(c);
      }
    }
  }
  return (buffer.toString(), opIndex, charIndex);
}

String _stripSpaces(String s, {String Function(String)? transform}) {
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (_isSpace(s.codeUnitAt(i))) continue;
    buffer.write(transform?.call(s[i]) ?? s[i]);
  }
  return buffer.toString();
}

bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0;

/// Eşleşmeyi yazar: önce dizeler, sonra (mümkünse) satırın kalanının kaydırması.
PdfContentReplacement _apply({
  required List<int> content,
  required PdfContentScan scan,
  required List<List<String>> pieces,
  required List<String> texts,
  required _Match match,
  required String newText,
  required List<int>? Function(String) Function(PdfTextOp) encoderFor,
  required PdfMeasure measure,
  required List<double>? mediaBox,
  required String encodingName,
  required int matchCount,
}) {
  final ops = scan.textOps;
  final splices = <_Splice>[];

  // Her etkilenen operatörde: hangi karakter aralığı silinecek, yerine ne gelecek.
  final newBytesOf = <int, List<int>>{};
  for (var o = match.firstOp; o <= match.lastOp; o++) {
    final from = o == match.firstOp ? match.firstOffset : 0;
    final to = o == match.lastOp ? match.lastOffset : texts[o].length;
    final insert = o == match.firstOp ? newText : '';
    final encode = encoderFor(ops[o]);
    final rewritten = <int>[];
    var used = false;

    var offset = 0;
    for (var s = 0; s < pieces[o].length; s++) {
      final piece = pieces[o][s];
      final token = ops[o].strings[s];
      final pieceEnd = offset + piece.length;
      final overlaps = from < pieceEnd && to > offset;
      if (overlaps) {
        final head = piece.substring(0, (from - offset).clamp(0, piece.length));
        final tail = piece.substring((to - offset).clamp(0, piece.length));
        final text = head + (used ? '' : insert) + tail;
        used = true;
        final bytes = encode(text);
        if (bytes == null) {
          throw const PdfReplaceException(
            PdfReplaceFailure.notEncodable,
            'Yazdığınız karakterlerden biri belgenin yazı tipinde yok. Bu yazı '
            'tipi belgeye yalnızca kullanılan harfleriyle gömülmüş; olmayan bir '
            'harfi eklemek yazıyı bozardı. Farklı bir sözcük deneyin.',
          );
        }
        splices.add(
            _Splice(token.start, token.end, writeStringLike(token, bytes)));
        rewritten.addAll(bytes);
      } else {
        rewritten.addAll(token.bytes);
      }
      offset = pieceEnd;
    }
    newBytesOf[o] = rewritten;
  }

  final reflow = _reflow(
    scan: scan,
    match: match,
    newBytesOf: newBytesOf,
    measure: measure,
    mediaBox: mediaBox,
  );
  splices.addAll(reflow.splices);

  // Baytları SONDAN başa değiştir: öndeki değişiklik sonraki uzaklıkları kaydırır.
  final out = List<int>.of(content);
  splices.sort((a, b) => b.start.compareTo(a.start));
  for (final s in splices) {
    out.replaceRange(s.start, s.end, s.bytes);
  }

  return PdfContentReplacement(
    content: out,
    matchCount: matchCount,
    encoding: encodingName,
    reflowed: reflow.shifted,
    overflows: reflow.overflows,
  );
}

class _ReflowResult {
  final List<_Splice> splices;
  final bool shifted;
  final bool overflows;
  const _ReflowResult(this.splices, this.shifted, this.overflows);
  static const none = _ReflowResult([], false, false);
}

/// Yeni metnin genişlik farkı kadar **satırın kalanını kaydırır**.
///
/// Neyi neden yapmıyoruz:
/// * Döndürülmüş/eğik metin matrisinde "sağa kaydır" tanımsız → dokunulmaz.
/// * Eşleşme birden çok operatöre yayılmış ve aralarında konumlandırma varsa
///   (her parça ayrı yerleştirilmiş) fark tek bir kaymaya indirgenemez → yapılmaz.
/// * Bir font ölçülemiyorsa (genişlik tablosu yok) hiç kaydırılmaz — yanlış
///   ölçüp sayfayı bozmaktansa satırın kalanını yerinde bırakmak yeğdir.
///
/// Kaydırma kuralı: mutlak `Tm` her seferinde kaydırılır (kendi başına konum
/// belirler); göreli `Td/TD` yalnız BİR kez — sonrakiler zaten kaymış satır
/// matrisine göre çalışır, ikinci kez eklemek kaymayı ikiye katlardı.
_ReflowResult _reflow({
  required PdfContentScan scan,
  required _Match match,
  required Map<int, List<int>> newBytesOf,
  required PdfMeasure measure,
  required List<double>? mediaBox,
}) {
  final ops = scan.textOps;
  final last = ops[match.lastOp];
  if (last.event.isRotated || !last.xKnown) return _ReflowResult.none;

  // Eşleşmenin içinde konumlandırma operatörü var mı?
  final firstEvent = ops[match.firstOp].eventIndex;
  for (var e = firstEvent + 1; e < last.eventIndex; e++) {
    if (scan.events[e].movesText) return _ReflowResult.none;
  }

  // Genişlik farkı (metin uzayı birimi).
  var delta = 0.0;
  for (var o = match.firstOp; o <= match.lastOp; o++) {
    final before = advanceOf(ops[o], ops[o].allBytes, measure);
    final after = advanceOf(ops[o], newBytesOf[o]!, measure);
    if (before == null || after == null) return _ReflowResult.none;
    delta += after - before;
  }

  final scale = last.matrix[0];
  if (scale.abs() < 1e-9) return _ReflowResult.none;
  final deltaObj = delta * scale;

  final lineY = last.matrix[5];
  final lineX = last.matrix[4];
  final height = (last.state.fontSize * last.matrix[3]).abs();
  final tolerance = height > 0 ? height * 0.34 : 1.0;

  final splices = <_Splice>[];
  var shiftApplied = false;
  var shifted = false;

  for (var e = last.eventIndex + 1; e < scan.events.length; e++) {
    final event = scan.events[e];
    if (event.op == 'ET' || event.op == 'BT') break;
    if (!event.movesText) continue;

    final numbers = event.numbers;
    if (event.op == 'Tm') {
      if (numbers.length < 6) break;
      final x = numbers[numbers.length - 2];
      final y = numbers[numbers.length - 1];
      if (numbers[numbers.length - 5].abs() > 1e-6 ||
          numbers[numbers.length - 4].abs() > 1e-6) {
        break;
      }
      if ((y - lineY).abs() > tolerance) break;
      if (x < lineX - 0.01) break; // solda kalan metne dokunma
      if (deltaObj.abs() > 1e-4) {
        splices.add(
            _splice(event, event.numberRanges.length - 2, x + deltaObj));
        shifted = true;
      }
      shiftApplied = true;
    } else if (event.op == 'Td' || event.op == 'TD') {
      if (numbers.length < 2) break;
      final lm = event.lineMatrix;
      if (lm[1].abs() > 1e-6 || lm[2].abs() > 1e-6) break;
      final tx = numbers[numbers.length - 2];
      final ty = numbers[numbers.length - 1];
      final y = tx * lm[1] + ty * lm[3] + lm[5];
      final x = tx * lm[0] + ty * lm[2] + lm[4];
      if ((y - lineY).abs() > tolerance) break;
      if (x < lineX - 0.01) break;
      if (!shiftApplied) {
        if (lm[0].abs() < 1e-9) break;
        if (deltaObj.abs() > 1e-4) {
          splices.add(
              _splice(event, event.numberRanges.length - 2, tx + deltaObj / lm[0]));
          shifted = true;
        }
        shiftApplied = true;
      }
    } else if (event.op == 'T*') {
      final lm = event.lineMatrix;
      final y = lm[5] - event.state.leading * lm[3];
      if ((y - lineY).abs() > tolerance) break;
    }
  }

  return _ReflowResult(
    splices,
    shifted,
    _overflows(
      scan: scan,
      match: match,
      newBytesOf: newBytesOf,
      measure: measure,
      mediaBox: mediaBox,
      lineY: lineY,
      tolerance: tolerance,
      deltaObj: deltaObj,
    ),
  );
}

_Splice _splice(PdfContentEvent event, int index, double value) {
  final range = event.numberRanges[index];
  return _Splice(range[0], range[1], writePdfNumber(value).codeUnits);
}

/// Hizalamadan sonra satır sayfanın metin alanını aşıyor mu?
///
/// Metin alanının sağ sınırı ÖLÇÜLEREK tahmin edilir: sayfadaki en soldaki
/// metin kenar boşluğunu verir, sayfa simetrik kabul edilir. Tahmin olduğu
/// için sonucu yalnız UYARI olarak kullanıyoruz — işlem iptal edilmiyor.
bool _overflows({
  required PdfContentScan scan,
  required _Match match,
  required Map<int, List<int>> newBytesOf,
  required PdfMeasure measure,
  required List<double>? mediaBox,
  required double lineY,
  required double tolerance,
  required double deltaObj,
}) {
  if (mediaBox == null || mediaBox.length < 4) return false;
  final ops = scan.textOps;

  var leftMost = double.infinity;
  var lineRight = double.negativeInfinity;
  for (var o = 0; o < ops.length; o++) {
    final op = ops[o];
    if (op.event.isRotated || !op.xKnown) continue;
    final bytes = newBytesOf[o] ?? op.allBytes;
    final advance = advanceOf(op, bytes, measure);
    if (advance == null) continue;
    final onLine = (op.matrix[5] - lineY).abs() <= tolerance;
    final shift = (onLine && o > match.lastOp) ? deltaObj : 0.0;
    final left = op.matrix[4] + shift;
    if (left < leftMost) leftMost = left;
    if (onLine) {
      final right = left + advance * op.matrix[0];
      if (right > lineRight) lineRight = right;
    }
  }
  if (!leftMost.isFinite || !lineRight.isFinite) return false;

  final margin = leftMost - mediaBox[0];
  final limit = mediaBox[2] - (margin > 0 ? margin : 0);
  return lineRight > limit + 0.5;
}
