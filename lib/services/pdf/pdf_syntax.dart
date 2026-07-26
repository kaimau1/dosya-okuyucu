/// PDF **içerik akışı** (content stream) sözdizimi: tarayıcı, metin
/// operatörleri ve tek-baytlık font kodlamaları.
///
/// Bu katman saf: bayt alır, bayt verir. Dosya yapısıyla (nesne, xref) işi yok
/// — o `pdf_objects.dart`'ta. Böylece en kırılgan kısım (ayrıştırma) cihazsız
/// test edilebiliyor.
library;

/// Metin gösteren bir operatörün (`Tj` `TJ` `'` `"`) içerik akışındaki yeri.
class PdfTextOp {
  /// Operatörün adı.
  final String op;

  /// Operandların başlangıcı (dizinin `[`'i ya da dizenin `(`'i).
  final int operandStart;

  /// Operatörün kendisinin başlangıcı (operandların bittiği yer).
  final int operatorStart;

  /// Operatörden sonraki ilk bayt.
  final int end;

  /// Operandlar içindeki dizeler (sırayla).
  final List<PdfStringToken> strings;

  /// O anda geçerli olan font kaynağının adı (`/F1 12 Tf` → `F1`).
  ///
  /// Baytları doğru karaktere çevirmek için ŞART: her fontun kendi kodlaması
  /// vardır ve aynı bayt farklı fontlarda farklı harf demektir.
  final String? fontName;

  const PdfTextOp({
    required this.op,
    required this.operandStart,
    required this.operatorStart,
    required this.end,
    required this.strings,
    this.fontName,
  });
}

/// İçerik akışındaki bir dize belirteci.
class PdfStringToken {
  /// Ham baytlardaki yeri (`(` ya da `<` dâhil, kapanış dâhil).
  final int start;
  final int end;

  /// Kaçış dizileri açılmış hâli.
  final List<int> bytes;

  const PdfStringToken(this.start, this.end, this.bytes);
}

/// İçerik akışını tarar ve metin gösteren operatörleri sırayla döndürür.
///
/// Satır içi görsellere (`BI … ID <ikili veri> EI`) dikkat edilir: ikili veri
/// ayrıştırılmaya çalışılırsa tarayıcı raydan çıkar ve rastgele "dize"ler
/// uydurur — belge bozulmasının kısa yolu budur.
List<PdfTextOp> scanTextOps(List<int> content) {
  final ops = <PdfTextOp>[];
  final strings = <PdfStringToken>[];
  final names = <String>[]; // son operatörden beri görülen /Ad'lar
  String? currentFont;
  var operandStart = -1;
  var i = 0;
  final n = content.length;

  bool isWhite(int c) =>
      c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 || c == 0x0C || c == 0x00;
  bool isDelim(int c) =>
      c == 0x28 || c == 0x29 || c == 0x3C || c == 0x3E || c == 0x5B ||
      c == 0x5D || c == 0x7B || c == 0x7D || c == 0x2F || c == 0x25;

  void resetOperands() {
    operandStart = -1;
    strings.clear();
    names.clear();
  }

  while (i < n) {
    final c = content[i];
    if (isWhite(c)) {
      i++;
      continue;
    }
    if (c == 0x25) {
      // % yorum — satır sonuna kadar.
      while (i < n && content[i] != 0x0A && content[i] != 0x0D) {
        i++;
      }
      continue;
    }
    if (operandStart < 0) operandStart = i;

    if (c == 0x28) {
      final tok = _readLiteralString(content, i);
      strings.add(tok);
      i = tok.end;
      continue;
    }
    if (c == 0x3C) {
      if (i + 1 < n && content[i + 1] == 0x3C) {
        i += 2; // sözlük başlangıcı — içeriği ayrıca taranır
        continue;
      }
      final tok = _readHexString(content, i);
      strings.add(tok);
      i = tok.end;
      continue;
    }
    if (c == 0x3E) {
      i += (i + 1 < n && content[i + 1] == 0x3E) ? 2 : 1;
      continue;
    }
    if (c == 0x2F) {
      // /Ad
      i++;
      final nameStart = i;
      while (i < n && !isWhite(content[i]) && !isDelim(content[i])) {
        i++;
      }
      names.add(String.fromCharCodes(content.sublist(nameStart, i)));
      continue;
    }
    if (c == 0x5B || c == 0x5D || c == 0x7B || c == 0x7D) {
      i++;
      continue;
    }

    // Sayı ya da operatör (anahtar sözcük).
    final start = i;
    while (i < n && !isWhite(content[i]) && !isDelim(content[i])) {
      i++;
    }
    final word = String.fromCharCodes(content.sublist(start, i));
    if (word.isEmpty) {
      i++;
      continue;
    }
    final isNumber = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$').hasMatch(word);
    if (isNumber) continue; // operand olarak biriksin

    // Operatör.
    if (word == 'BI') {
      i = _skipInlineImage(content, i);
      resetOperands();
      continue;
    }
    if (word == 'Tf' && names.isNotEmpty) {
      currentFont = names.last;
    }
    if (word == 'Tj' || word == 'TJ' || word == "'" || word == '"') {
      if (strings.isNotEmpty) {
        ops.add(PdfTextOp(
          op: word,
          operandStart: operandStart,
          operatorStart: start,
          end: i,
          strings: List.of(strings),
          fontName: currentFont,
        ));
      }
    }
    resetOperands();
  }
  return ops;
}

/// `(` ile başlayan değişmez dizeyi okur; kaçışları açar.
PdfStringToken _readLiteralString(List<int> content, int start) {
  final bytes = <int>[];
  var depth = 0;
  var i = start;
  final n = content.length;
  while (i < n) {
    final c = content[i];
    if (c == 0x5C) {
      // ters bölü kaçışı
      i++;
      if (i >= n) break;
      final e = content[i];
      switch (e) {
        case 0x6E: // n
          bytes.add(0x0A);
          i++;
        case 0x72: // r
          bytes.add(0x0D);
          i++;
        case 0x74: // t
          bytes.add(0x09);
          i++;
        case 0x62: // b
          bytes.add(0x08);
          i++;
        case 0x66: // f
          bytes.add(0x0C);
          i++;
        case 0x0A: // satır devamı
          i++;
        case 0x0D:
          i++;
          if (i < n && content[i] == 0x0A) i++;
        default:
          if (e >= 0x30 && e <= 0x37) {
            // sekizlik, en çok 3 hane
            var value = 0;
            var count = 0;
            while (i < n && count < 3 && content[i] >= 0x30 && content[i] <= 0x37) {
              value = value * 8 + (content[i] - 0x30);
              i++;
              count++;
            }
            bytes.add(value & 0xFF);
          } else {
            bytes.add(e);
            i++;
          }
      }
      continue;
    }
    if (c == 0x28) {
      depth++;
      if (depth > 1) bytes.add(c);
      i++;
      continue;
    }
    if (c == 0x29) {
      depth--;
      if (depth == 0) {
        i++;
        return PdfStringToken(start, i, bytes);
      }
      bytes.add(c);
      i++;
      continue;
    }
    bytes.add(c);
    i++;
  }
  return PdfStringToken(start, i, bytes);
}

/// `<` ile başlayan onaltılık dizeyi okur.
PdfStringToken _readHexString(List<int> content, int start) {
  final bytes = <int>[];
  var i = start + 1;
  var high = -1;
  final n = content.length;
  while (i < n && content[i] != 0x3E) {
    final digit = _hexDigit(content[i]);
    if (digit >= 0) {
      if (high < 0) {
        high = digit;
      } else {
        bytes.add(high * 16 + digit);
        high = -1;
      }
    }
    i++;
  }
  if (high >= 0) bytes.add(high * 16); // tek hane → sonuna 0 eklenir
  if (i < n) i++; // kapanış '>'
  return PdfStringToken(start, i, bytes);
}

int _hexDigit(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  return -1;
}

/// `BI` sonrası satır içi görselin sonunu (`EI`) bulur.
int _skipInlineImage(List<int> content, int from) {
  final n = content.length;
  var i = from;
  // Önce ID'yi bul (sözlük kısmı normal sözdizimi).
  while (i + 1 < n) {
    if (content[i] == 0x49 && content[i + 1] == 0x44) {
      i += 2;
      if (i < n) i++; // ID'den sonra tek bir boşluk
      break;
    }
    i++;
  }
  // Sonra EI'yi ara: öncesinde boşluk, sonrasında ayraç/boşluk olmalı.
  while (i + 1 < n) {
    if (content[i] == 0x45 &&
        content[i + 1] == 0x49 &&
        (i == 0 || _isWhiteByte(content[i - 1])) &&
        (i + 2 >= n || _isWhiteByte(content[i + 2]))) {
      return i + 2;
    }
    i++;
  }
  return n;
}

bool _isWhiteByte(int c) =>
    c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 || c == 0x0C || c == 0x00;

/// Metni değişmez PDF dizesi olarak yazar (`(` … `)`), kaçışlarıyla.
List<int> writeLiteralString(List<int> bytes) {
  final out = <int>[0x28];
  for (final b in bytes) {
    switch (b) {
      case 0x28: // (
      case 0x29: // )
      case 0x5C: // \
        out
          ..add(0x5C)
          ..add(b);
      case 0x0D:
        out.addAll([0x5C, 0x72]); // \r
      case 0x0A:
        out.addAll([0x5C, 0x6E]); // \n
      default:
        out.add(b);
    }
  }
  out.add(0x29);
  return out;
}

/// PDF'te sık kullanılan **tek baytlık** font kodlamaları.
///
/// Niye tablo: yeni metni özgün fontun kodlamasıyla yazmak zorundayız, yoksa
/// harfler başka gliflere düşer. Hangi tablonun geçerli olduğunu tahmin
/// etmiyoruz — [PdfSingleByteEncoding.decode] ile çözüp kullanıcının seçtiği
/// metni bulabiliyor muyuz diye BAKIYORUZ (bkz. `pdf_content_editor`).
class PdfSingleByteEncoding {
  final String name;
  final Map<int, int> _toUnicode; // bayt → kod noktası (yalnız farklılıklar)
  late final Map<int, int> _fromUnicode = {
    for (final e in _toUnicode.entries) e.value: e.key,
  };

  PdfSingleByteEncoding(this.name, this._toUnicode);

  String decode(List<int> bytes) {
    final codes = <int>[
      for (final b in bytes) _toUnicode[b] ?? b,
    ];
    return String.fromCharCodes(codes);
  }

  /// [text]'i baytlara çevirir; **tek bir karakter bile karşılanamıyorsa null**
  /// döner. Yarım yazmaktansa hiç yazmamak: eksik glif belgeyi bozar.
  List<int>? encode(String text) {
    final out = <int>[];
    for (final rune in text.runes) {
      final mapped = _fromUnicode[rune];
      if (mapped != null) {
        out.add(mapped);
        continue;
      }
      // Tabloda farklılık yoksa bayt = kod noktası (Latin-1 bölgesi).
      if (rune < 0x100 && !_toUnicode.containsKey(rune)) {
        out.add(rune);
        continue;
      }
      return null;
    }
    return out;
  }

  /// Denenecek kodlamalar — en yaygından başlayarak.
  static List<PdfSingleByteEncoding> get candidates => [
        winAnsi,
        turkish,
        latin1,
      ];

  static final latin1 = PdfSingleByteEncoding('Latin-1', const {});

  /// WinAnsiEncoding (CP1252) — PDF'lerin çoğunun varsayılanı.
  static final winAnsi = PdfSingleByteEncoding('WinAnsi', const {
    0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026,
    0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160,
    0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019,
    0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
    0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153,
    0x9E: 0x017E, 0x9F: 0x0178,
  });

  /// CP1254 — Türkçe belgelerde kullanılan tek baytlık kodlama.
  static final turkish = PdfSingleByteEncoding('CP1254', const {
    0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026,
    0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160,
    0x8B: 0x2039, 0x8C: 0x0152, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
    0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02DC,
    0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153, 0x9F: 0x0178,
    0xD0: 0x011E, // Ğ
    0xDD: 0x0130, // İ
    0xDE: 0x015E, // Ş
    0xF0: 0x011F, // ğ
    0xFD: 0x0131, // ı
    0xFE: 0x015F, // ş
  });
}
