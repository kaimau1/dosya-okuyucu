/// PDF **içerik akışı** (content stream) sözdizimi: tarayıcı, metin
/// operatörleri, metin durumu/matrisi ve tek-baytlık font kodlamaları.
///
/// Bu katman saf: bayt alır, bayt verir. Dosya yapısıyla (nesne, xref) işi yok
/// — o `pdf_objects.dart`'ta. Böylece en kırılgan kısım (ayrıştırma) cihazsız
/// test edilebiliyor.
library;

/// Bir metin operatörü çalışırken geçerli olan **metin durumu**.
///
/// Bunları izlemek şart: bir dizenin sayfada kapladığı yatay yer yalnız glif
/// genişliklerine değil, karakter/kelime aralığına ve yatay ölçeğe de bağlı.
/// Yeniden hizalama (satırın kalanını kaydırma) bu ölçüyü kullanıyor.
class PdfTextState {
  /// `Tf` puntosu.
  final double fontSize;

  /// `Tc` — her glife eklenen aralık.
  final double charSpacing;

  /// `Tw` — tek baytlık 32 koduna eklenen aralık (iki yana yaslamada kullanılır).
  final double wordSpacing;

  /// `Tz`/100 — yatay ölçek çarpanı.
  final double horizScale;

  /// `TL` — satır aralığı (`T*` ve `'` bunu kullanır).
  final double leading;

  const PdfTextState({
    this.fontSize = 0,
    this.charSpacing = 0,
    this.wordSpacing = 0,
    this.horizScale = 1,
    this.leading = 0,
  });

  PdfTextState copyWith({
    double? fontSize,
    double? charSpacing,
    double? wordSpacing,
    double? horizScale,
    double? leading,
  }) =>
      PdfTextState(
        fontSize: fontSize ?? this.fontSize,
        charSpacing: charSpacing ?? this.charSpacing,
        wordSpacing: wordSpacing ?? this.wordSpacing,
        horizScale: horizScale ?? this.horizScale,
        leading: leading ?? this.leading,
      );
}

/// Bir dizenin ölçüsü: toplam glif genişliği (1/1000 em) ve sayımlar.
class PdfGlyphRun {
  final double width1000;
  final int glyphCount;

  /// Tek baytlık 32 kodu sayısı — `Tw` yalnız bunlara eklenir.
  final int spaceCount;

  const PdfGlyphRun({
    required this.width1000,
    required this.glyphCount,
    required this.spaceCount,
  });
}

/// Bir fontun baytlarını ölçen geri çağırım; ölçemiyorsa null döner.
typedef PdfMeasure = PdfGlyphRun? Function(String? fontName, List<int> bytes);

/// İçerik akışındaki bir operatör ve o an geçerli olan metin durumu.
class PdfContentEvent {
  /// Operatörün adı (`Tj`, `Tm`, `Td`, `BT`, `ET`, `Tf`, …).
  final String op;

  /// Operandların başlangıcı ve operatörün kendi başlangıcı/bitişi.
  final int operandStart;
  final int operatorStart;
  final int end;

  /// Sayısal operandlar ve her birinin bayt aralığı (`[başlangıç, bitiş)`).
  /// Aralıklar yeniden hizalamada ŞART: bir sayıyı yerinde değiştirmek için
  /// nerede olduğunu bilmek gerekiyor.
  final List<double> numbers;
  final List<List<int>> numberRanges;

  /// Operandlar içindeki dizeler (sırayla).
  final List<PdfStringToken> strings;

  /// O anda geçerli olan font kaynağının adı (`/F1 12 Tf` → `F1`).
  final String? fontName;

  /// Operatör çalışmadan ÖNCEki metin matrisi (`Tm`) ve satır matrisi (`Tlm`).
  /// `'` ve `"` için satır atlaması UYGULANMIŞ hâlleridir (metin oraya çizilir).
  final List<double> matrix;
  final List<double> lineMatrix;

  final PdfTextState state;

  /// Matrisin yatay bileşeni güvenilir mi? Ölçülemeyen bir fonttan sonra
  /// kalem konumu bilinmez olur; o noktadan sonra hizalama yapılmaz.
  final bool xKnown;

  const PdfContentEvent({
    required this.op,
    required this.operandStart,
    required this.operatorStart,
    required this.end,
    required this.numbers,
    required this.numberRanges,
    required this.strings,
    required this.fontName,
    required this.matrix,
    required this.lineMatrix,
    required this.state,
    required this.xKnown,
  });

  bool get showsText => op == 'Tj' || op == 'TJ' || op == "'" || op == '"';

  bool get movesText => op == 'Td' || op == 'TD' || op == 'Tm' || op == 'T*';

  /// Matris döndürülmüş/eğilmiş mi? Böyle bir metinde yatay kaydırma
  /// "sağa" demek değildir — hizalama yapılmaz.
  bool get isRotated => matrix[1].abs() > 1e-6 || matrix[2].abs() > 1e-6;
}

/// Metin gösteren bir operatörün (`Tj` `TJ` `'` `"`) içerik akışındaki yeri.
///
/// [PdfContentEvent]'i sarar: eski çağrı yerleri (`op.strings`, `op.fontName` …)
/// olduğu gibi çalışsın diye.
class PdfTextOp {
  final PdfContentEvent event;

  /// Olayın tüm olaylar listesindeki sırası — hizalamada "bu operatörden
  /// SONRAKİ konumlandırmalar" bulunurken kullanılır.
  final int eventIndex;

  const PdfTextOp(this.event, this.eventIndex);

  String get op => event.op;
  int get operandStart => event.operandStart;
  int get operatorStart => event.operatorStart;
  int get end => event.end;
  List<PdfStringToken> get strings => event.strings;
  String? get fontName => event.fontName;
  List<double> get matrix => event.matrix;
  PdfTextState get state => event.state;
  bool get xKnown => event.xKnown;

  /// `TJ` dizisindeki kerning sayılarının toplamı (diğer operatörlerde 0).
  double get kern =>
      op == 'TJ' ? event.numbers.fold<double>(0, (a, b) => a + b) : 0;

  /// Operatörün tüm dizelerinin baytları, sırayla.
  List<int> get allBytes => [for (final s in strings) ...s.bytes];
}

/// Bir içerik akışının taranmış hâli.
class PdfContentScan {
  final List<PdfContentEvent> events;
  final List<PdfTextOp> textOps;
  const PdfContentScan(this.events, this.textOps);
}

/// İçerik akışındaki bir dize belirteci.
class PdfStringToken {
  /// Ham baytlardaki yeri (`(` ya da `<` dâhil, kapanış dâhil).
  final int start;
  final int end;

  /// Kaçış dizileri açılmış hâli.
  final List<int> bytes;

  /// Onaltılık biçimde mi yazılmıştı (`<0041>`)? Yeniden yazarken aynı biçim
  /// korunur — Identity-H metni belgelerde hep onaltılıktır ve biçimi
  /// değiştirmek gereksiz bir fark üretir.
  final bool isHex;

  const PdfStringToken(this.start, this.end, this.bytes, {this.isHex = false});
}

/// İçerik akışını tarar: metin operatörleri + metin matrisi/durumu.
///
/// [measure] verilirse gösterilen her dizenin ilerleyişi hesaplanır ve metin
/// matrisi buna göre ilerletilir; verilmezse (ya da bir fontu ölçemezse)
/// sonraki olayların [PdfContentEvent.xKnown] alanı false olur.
///
/// Satır içi görsellere (`BI … ID <ikili veri> EI`) dikkat edilir: ikili veri
/// ayrıştırılmaya çalışılırsa tarayıcı raydan çıkar ve rastgele "dize"ler
/// uydurur — belge bozulmasının kısa yolu budur.
PdfContentScan scanContent(List<int> content, {PdfMeasure? measure}) {
  final events = <PdfContentEvent>[];
  final textOps = <PdfTextOp>[];

  final strings = <PdfStringToken>[];
  final names = <String>[];
  final numbers = <double>[];
  final numberRanges = <List<int>>[];
  String? currentFont;
  var operandStart = -1;

  var tm = _identity();
  var tlm = _identity();
  var state = const PdfTextState();
  var xKnown = true;

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
    numbers.clear();
    numberRanges.clear();
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
    if (_numberPattern.hasMatch(word)) {
      numbers.add(double.tryParse(word) ?? 0);
      numberRanges.add([start, i]);
      continue; // operand olarak biriksin
    }

    // Operatör.
    if (word == 'BI') {
      i = _skipInlineImage(content, i);
      resetOperands();
      continue;
    }

    // Durum değişiklikleri: olay kaydedilmeden ÖNCE uygulanması gerekenler
    // (`'` ve `"` önce satır atlar, metni yeni satıra çizer).
    var eventState = state;
    if (word == 'Tf' && names.isNotEmpty) {
      currentFont = names.last;
      if (numbers.isNotEmpty) {
        state = state.copyWith(fontSize: numbers.last);
      }
      eventState = state;
    } else if (word == '"' && numbers.length >= 2) {
      state = state.copyWith(
          wordSpacing: numbers[numbers.length - 2],
          charSpacing: numbers[numbers.length - 1]);
      eventState = state;
    }
    if (word == "'" || word == '"') {
      tlm = _translate(0, -state.leading, tlm);
      tm = List.of(tlm);
      xKnown = true;
    }

    final event = PdfContentEvent(
      op: word,
      operandStart: operandStart < 0 ? start : operandStart,
      operatorStart: start,
      end: i,
      numbers: List.of(numbers),
      numberRanges: [for (final r in numberRanges) List.of(r)],
      strings: List.of(strings),
      fontName: currentFont,
      matrix: List.of(tm),
      lineMatrix: List.of(tlm),
      state: eventState,
      xKnown: xKnown,
    );
    events.add(event);

    switch (word) {
      case 'BT':
        tm = _identity();
        tlm = _identity();
        xKnown = true;
      case 'Tc':
        if (numbers.isNotEmpty) {
          state = state.copyWith(charSpacing: numbers.last);
        }
      case 'Tw':
        if (numbers.isNotEmpty) {
          state = state.copyWith(wordSpacing: numbers.last);
        }
      case 'Tz':
        if (numbers.isNotEmpty) {
          state = state.copyWith(horizScale: numbers.last / 100);
        }
      case 'TL':
        if (numbers.isNotEmpty) state = state.copyWith(leading: numbers.last);
      case 'Tm':
        if (numbers.length >= 6) {
          tm = numbers.sublist(numbers.length - 6);
          tlm = List.of(tm);
          xKnown = true;
        }
      case 'Td':
        if (numbers.length >= 2) {
          tlm = _translate(
              numbers[numbers.length - 2], numbers[numbers.length - 1], tlm);
          tm = List.of(tlm);
          xKnown = true;
        }
      case 'TD':
        if (numbers.length >= 2) {
          state = state.copyWith(leading: -numbers[numbers.length - 1]);
          tlm = _translate(
              numbers[numbers.length - 2], numbers[numbers.length - 1], tlm);
          tm = List.of(tlm);
          xKnown = true;
        }
      case 'T*':
        tlm = _translate(0, -state.leading, tlm);
        tm = List.of(tlm);
        xKnown = true;
    }

    if (event.showsText && strings.isNotEmpty) {
      final textOp = PdfTextOp(event, events.length - 1);
      textOps.add(textOp);
      final advance = advanceOf(textOp, textOp.allBytes, measure);
      if (advance == null) {
        xKnown = false;
      } else {
        tm = _translate(advance, 0, tm);
      }
    }

    resetOperands();
  }
  return PdfContentScan(events, textOps);
}

/// Yalnız metin gösteren operatörler (eski çağrı yerleri için kısayol).
List<PdfTextOp> scanTextOps(List<int> content, {PdfMeasure? measure}) =>
    scanContent(content, measure: measure).textOps;

/// İçerikte **görünmez metin** var mı? (`3 Tr` = hiç çizme, `7 Tr` = yalnız
/// kırpma yolu.)
///
/// Taranmış "aranabilir" PDF'in imzası budur: sayfa aslında bir GÖRÜNTÜ, OCR
/// metni onun üstüne görünmez yazılır ki arama/kopyalama çalışsın. Bizim
/// tarayıcımız da böyle üretiyor (`ConversionService.imagesToPdf`,
/// `PdfTextRenderingMode.invisible`).
bool hasInvisibleText(List<int> content) => scanContent(content).events.any(
      (e) =>
          e.op == 'Tr' &&
          e.numbers.isNotEmpty &&
          (e.numbers.last == 3 || e.numbers.last == 7),
    );

/// [bytes] baytlarının [op]'un durumuyla ölçeklenmiş yatay ilerleyişi
/// (metin uzayı birimi). Ölçülemiyorsa null.
///
/// `TJ` dizisindeki kerning sayıları da düşülür — ama düzenlemede o sayılar
/// aynen korunduğu için eski/yeni farkı alınırken birbirini götürürler.
double? advanceOf(PdfTextOp op, List<int> bytes, PdfMeasure? measure) {
  final run = measure?.call(op.fontName, bytes);
  if (run == null) return null;
  final st = op.state;
  var tx = run.width1000 / 1000 * st.fontSize +
      run.glyphCount * st.charSpacing +
      run.spaceCount * st.wordSpacing;
  tx -= op.kern / 1000 * st.fontSize;
  return tx * st.horizScale;
}

final _numberPattern = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$');

/// `m × n` (PDF satır-vektör düzeni, 6 elemanlı afin matris).
List<double> multiplyMatrix(List<double> m, List<double> n) => [
      m[0] * n[0] + m[1] * n[2],
      m[0] * n[1] + m[1] * n[3],
      m[2] * n[0] + m[3] * n[2],
      m[2] * n[1] + m[3] * n[3],
      m[4] * n[0] + m[5] * n[2] + n[4],
      m[4] * n[1] + m[5] * n[3] + n[5],
    ];

/// Afin matrisin tersi; tekilse (ölçek 0) null.
List<double>? invertMatrix(List<double> m) {
  final det = m[0] * m[3] - m[1] * m[2];
  if (det.abs() < 1e-12) return null;
  return [
    m[3] / det,
    -m[1] / det,
    -m[2] / det,
    m[0] / det,
    (m[2] * m[5] - m[3] * m[4]) / det,
    (m[1] * m[4] - m[0] * m[5]) / det,
  ];
}

/// Afin matrisi bir noktaya uygular.
(double, double) applyMatrix(List<double> m, double x, double y) =>
    (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]);

List<double> _identity() => [1, 0, 0, 1, 0, 0];

/// `translate(tx, ty) × m` (PDF satır-vektör düzeni).
List<double> _translate(double tx, double ty, List<double> m) => [
      m[0],
      m[1],
      m[2],
      m[3],
      tx * m[0] + ty * m[2] + m[4],
      tx * m[1] + ty * m[3] + m[5],
    ];

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
  return PdfStringToken(start, i, bytes, isHex: true);
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

/// Metni onaltılık PDF dizesi olarak yazar (`<0041>`).
List<int> writeHexString(List<int> bytes) {
  const digits = '0123456789ABCDEF';
  final out = <int>[0x3C];
  for (final b in bytes) {
    out
      ..add(digits.codeUnitAt((b >> 4) & 0xF))
      ..add(digits.codeUnitAt(b & 0xF));
  }
  out.add(0x3E);
  return out;
}

/// Dizeyi ÖZGÜN biçiminde (onaltılık ya da değişmez) yazar.
List<int> writeStringLike(PdfStringToken original, List<int> bytes) =>
    original.isHex ? writeHexString(bytes) : writeLiteralString(bytes);

/// Sayıyı içerik akışına yazılabilir biçimde biçimlendirir.
///
/// Gereksiz ondalık basamak bırakmaz: `303.0` → `303`, `303.4560` → `303.456`.
String writePdfNumber(double value) {
  if (!value.isFinite) return '0';
  if ((value - value.roundToDouble()).abs() < 1e-6) {
    return value.round().toString();
  }
  var s = value.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
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

  /// Denenecek kodlamalar. **CP1254 önce** (2026-08-06): WinAnsi'den yalnız
  /// altı Türkçe harf konumunda ayrılır, o konumları içermeyen belgede ikisi
  /// birebir aynı sonucu verir — yani sıralamanın tek etkisi Türkçe belgede
  /// doğru harfi seçmek.
  static List<PdfSingleByteEncoding> get candidates => [
        turkish,
        winAnsi,
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
