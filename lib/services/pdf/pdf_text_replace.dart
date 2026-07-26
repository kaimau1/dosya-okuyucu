import 'pdf_font_map.dart';
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

  const PdfContentReplacement({
    required this.content,
    required this.matchCount,
    required this.encoding,
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
/// * Eşleşen operatörlerin operandları değiştirilir, **operatörün kendisi
///   korunur** — `'` satır atlar, `"` kelime/karakter aralığı ayarlar; bunları
///   düşürmek sayfanın kalanını kaydırırdı.
///
/// Hiçbir kodlamada eşleşme yoksa [PdfReplaceFailure.notFound], yeni metin o
/// kodlamada yazılamıyorsa [PdfReplaceFailure.notEncodable] atar.
/// [precedingText] verilirse (seçimden hemen önce gelen metin) önce
/// `öncesi + aranan` bütünü aranır. Niye: aynı kelime sayfada birkaç kez
/// geçebilir ve yalnız kelimeye bakan bir arama YANLIŞ yeri değiştirirdi.
/// Bağlamla bulunamazsa sade aramaya düşülür.
/// [fontEncodings] sayfanın font kaynaklarının `/ToUnicode` eşlemeleridir
/// (kaynak adı → eşleme). **Öncelikli yol budur:** belgenin kendi tablosunu
/// kullandığımız için alt küme gömülü ve Type0/Identity-H fontlar da çalışır,
/// yani yeni metin belgenin ÖZGÜN yazı tipiyle yazılır. Eşleme yoksa ya da
/// metni bulamazsa tek baytlık tahmin tablolarına düşülür.
PdfContentReplacement replaceTextInContent(
  List<int> content,
  String oldText,
  String newText, {
  String precedingText = '',
  Map<String, PdfFontEncoding> fontEncodings = const {},
  List<PdfSingleByteEncoding>? encodings,
}) {
  final ops = scanTextOps(content);
  if (ops.isEmpty) {
    throw const PdfReplaceException(
        PdfReplaceFailure.notFound, 'Bu sayfada düzenlenebilir metin yok.');
  }

  // 1) Fontun kendi /ToUnicode tablosu.
  if (fontEncodings.isNotEmpty) {
    final texts = <String>[
      for (final op in ops)
        _decodeWithFont(op, fontEncodings) ??
            PdfSingleByteEncoding.latin1
                .decode([for (final s in op.strings) ...s.bytes]),
    ];
    final match = _findFlexible(texts, oldText, prefix: precedingText) ??
        _findFlexible(texts, oldText);
    if (match != null) {
      final replacement = _rewrite(
        content,
        ops,
        texts,
        match,
        newText,
        encoderFor: (op) => _encoderFor(op, fontEncodings),
      );
      return PdfContentReplacement(
        content: replacement,
        matchCount: _countFlexible(texts, oldText),
        encoding: 'ToUnicode',
      );
    }
  }

  // 2) Yedek: yaygın tek baytlık kodlamalar.
  for (final enc in encodings ?? PdfSingleByteEncoding.candidates) {
    final texts = <String>[
      for (final op in ops)
        enc.decode([for (final s in op.strings) ...s.bytes]),
    ];
    final match = _findFlexible(texts, oldText, prefix: precedingText) ??
        _findFlexible(texts, oldText);
    if (match == null) continue;

    final replacement = _rewrite(content, ops, texts, match, newText,
        encoderFor: (_) => enc.encode);
    return PdfContentReplacement(
      content: replacement,
      matchCount: _countFlexible(texts, oldText),
      encoding: enc.name,
    );
  }

  throw const PdfReplaceException(
    PdfReplaceFailure.notFound,
    'Bu metin belgenin içinde bulunamadı. Sayfa taranmış (resim) olabilir ya '
    'da yazı tipi metin eşlemesi taşımıyor olabilir.',
  );
}

/// Operatörün baytlarını kendi fontunun tablosuyla çözer (font yoksa null).
String? _decodeWithFont(
    PdfTextOp op, Map<String, PdfFontEncoding> fontEncodings) {
  final enc = fontEncodings[op.fontName];
  if (enc == null) return null;
  return enc.decode([for (final s in op.strings) ...s.bytes]);
}

/// Operatöre yazarken kullanılacak kodlayıcı.
List<int>? Function(String) _encoderFor(
    PdfTextOp op, Map<String, PdfFontEncoding> fontEncodings) {
  final enc = fontEncodings[op.fontName];
  if (enc != null) return enc.encode;
  return PdfSingleByteEncoding.latin1.encode;
}

/// Eşleşmenin operatör/karakter koordinatları.
class _Match {
  final int firstOp;
  final int firstOffset; // firstOp metninde eşleşmenin başladığı karakter
  final int lastOp;
  final int lastOffset; // lastOp metninde eşleşmenin bittiği karakter (hariç)
  const _Match(this.firstOp, this.firstOffset, this.lastOp, this.lastOffset);
}

/// Boşlukları yok sayarak arar; bulursa operatör/karakter koordinatı döner.
///
/// [prefix] verilirse `prefix + needle` bütünü aranır ama YALNIZ needle
/// kısmının koordinatı döndürülür (bağlam değiştirilmez, sadece yeri bulur).
_Match? _findFlexible(List<String> texts, String needle, {String prefix = ''}) {
  final (hay, opIndex, charIndex) = _flatten(texts);
  final target = _stripSpaces(needle);
  if (target.isEmpty) return null;
  final head = _stripSpaces(prefix);
  if (head.isEmpty && prefix.isNotEmpty) return null;
  final at0 = hay.indexOf('$head$target');
  if (at0 < 0) return null;
  final at = at0 + head.length;
  final endAt = at + target.length - 1;
  if (endAt >= opIndex.length) return null;
  return _Match(
    opIndex[at],
    charIndex[at],
    opIndex[endAt],
    charIndex[endAt] + 1,
  );
}

int _countFlexible(List<String> texts, String needle) {
  final (hay, _, __) = _flatten(texts);
  final target = _stripSpaces(needle);
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
/// hangi operatörün kaçıncı karakteri olduğunu tutar.
(String, List<int>, List<int>) _flatten(List<String> texts) {
  final buffer = StringBuffer();
  final opIndex = <int>[];
  final charIndex = <int>[];
  for (var o = 0; o < texts.length; o++) {
    final text = texts[o];
    for (var c = 0; c < text.length; c++) {
      if (_isSpace(text.codeUnitAt(c))) continue;
      buffer.writeCharCode(text.codeUnitAt(c));
      opIndex.add(o);
      charIndex.add(c);
    }
  }
  return (buffer.toString(), opIndex, charIndex);
}

String _stripSpaces(String s) {
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (!_isSpace(s.codeUnitAt(i))) buffer.writeCharCode(s.codeUnitAt(i));
  }
  return buffer.toString();
}

bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0;

/// Eşleşen operatörlerin operandlarını yeniden yazar.
List<int> _rewrite(
  List<int> content,
  List<PdfTextOp> ops,
  List<String> texts,
  _Match match,
  String newText, {
  required List<int>? Function(String) Function(PdfTextOp) encoderFor,
}) {
  // Eşleşmenin kapsadığı her operatöre düşen yeni metin.
  final replacements = <int, String>{};
  if (match.firstOp == match.lastOp) {
    final text = texts[match.firstOp];
    replacements[match.firstOp] = text.substring(0, match.firstOffset) +
        newText +
        text.substring(match.lastOffset);
  } else {
    replacements[match.firstOp] =
        texts[match.firstOp].substring(0, match.firstOffset) + newText;
    for (var o = match.firstOp + 1; o < match.lastOp; o++) {
      replacements[o] = '';
    }
    replacements[match.lastOp] = texts[match.lastOp].substring(match.lastOffset);
  }

  // Baytları SONDAN başa değiştir: öndeki değişiklik sonraki uzaklıkları kaydırır.
  final out = List<int>.of(content);
  final indexes = replacements.keys.toList()..sort();
  for (final o in indexes.reversed) {
    final op = ops[o];
    final bytes = encoderFor(op)(replacements[o]!);
    if (bytes == null) {
      throw const PdfReplaceException(
        PdfReplaceFailure.notEncodable,
        'Yazdığınız karakterlerden biri belgenin yazı tipinde yok. Bu yazı '
        'tipi belgeye yalnızca kullanılan harfleriyle gömülmüş; olmayan bir '
        'harfi eklemek yazıyı bozardı. Farklı bir sözcük deneyin.',
      );
    }
    out.replaceRange(
      op.operandStart,
      op.operatorStart,
      _operandBytes(content, op, bytes),
    );
  }
  return out;
}

/// Operatörün türüne göre yeni operand baytları.
///
/// `"` operatörünün önündeki iki sayı (kelime/karakter aralığı) KORUNUR;
/// atılırsa satırın kalanı kayar.
List<int> _operandBytes(List<int> content, PdfTextOp op, List<int> textBytes) {
  final literal = writeLiteralString(textBytes);
  final out = <int>[];
  if (op.op == 'TJ') {
    out
      ..add(0x5B) // [
      ..addAll(literal)
      ..add(0x5D); // ]
  } else if (op.op == '"') {
    // aw ac (str) " → sayılar aynen kalsın.
    out
      ..addAll(content.sublist(op.operandStart, op.strings.first.start))
      ..addAll(literal);
  } else {
    out.addAll(literal);
  }
  out.add(0x20); // operatörden önce ayraç
  return out;
}
