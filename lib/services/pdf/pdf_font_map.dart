import 'dart:convert';

import 'pdf_dict.dart';
import 'pdf_glyph_names.dart';
import 'pdf_syntax.dart' show PdfSingleByteEncoding;

/// Bir PDF fontunun **kod ↔ karakter** eşlemesi (`/ToUnicode` CMap'inden).
///
/// **Niye şart oldu (2026-07-26, kullanıcı ekran görüntüsü):** gerçek bir
/// resmî belge (EBYS çıktısı) düzenlenmek istendiğinde yerinde düzenleme
/// "metni bulamadım" deyip yedek yola (üste yazma) düşüyordu; sonuç yazı tipi
/// bozuk ve satırı yarıda kesen çirkin bir çıktıydı. Sebep: o belgelerdeki
/// yazı tipleri **alt küme gömülü** ve kodlaması standart değil — çoğu zaman
/// Type0/Identity-H, yani harf başına 2 baytlık glif numarası. Tek baytlık
/// tahmin tabloları (WinAnsi/CP1254) böyle bir belgede hiçbir zaman tutmaz.
///
/// `/ToUnicode`, PDF'in kendi içinde taşıdığı "bu kod şu harftir" tablosudur ve
/// metni kopyalanabilen her belgede bulunur. Okuyup **ters çevirince** yeni
/// metni fontun kendi kodlarıyla yazabiliyoruz — yani belgenin özgün yazı tipi
/// korunuyor.
class PdfFontEncoding {
  /// Kod → karakter(ler).
  final Map<int, String> toUnicode;

  /// Karakter → kod (tersi). Yalnız tek karaktere eşlenen kodlar girer;
  /// ligatür gibi çok karakterli hedefler geri yazılamaz.
  final Map<String, int> fromUnicode;

  /// Bir kodun kaç bayt olduğu (1 = basit font, 2 = Type0/Identity-H).
  final int codeBytes;

  const PdfFontEncoding({
    required this.toUnicode,
    required this.fromUnicode,
    required this.codeBytes,
  });

  bool get isEmpty => toUnicode.isEmpty;

  /// Ham baytları metne çevirir. Tanınmayan kod, eşleşmeyi bozmaması için
  /// yer tutucuyla (U+FFFD) temsil edilir.
  String decode(List<int> bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i + codeBytes <= bytes.length; i += codeBytes) {
      var code = 0;
      for (var b = 0; b < codeBytes; b++) {
        code = (code << 8) | bytes[i + b];
      }
      buffer.write(toUnicode[code] ?? '�');
    }
    return buffer.toString();
  }

  /// Metni fontun kodlarına çevirir; **tek karakter bile karşılanamıyorsa
  /// null** döner (yarım yazmak belgeyi bozar).
  List<int>? encode(String text) {
    final out = <int>[];
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final code = fromUnicode[ch];
      if (code == null) return null;
      for (var b = codeBytes - 1; b >= 0; b--) {
        out.add((code >> (b * 8)) & 0xFF);
      }
    }
    return out;
  }

  /// `/ToUnicode` akışının çözülmüş baytlarından eşlemeyi kurar.
  static PdfFontEncoding parseCMap(List<int> data) {
    final text = latin1.decode(data, allowInvalid: true);
    final map = <int, String>{};

    // Kod uzunluğu codespacerange'den: <0000> <FFFF> → 2 bayt, <00> <FF> → 1.
    var codeBytes = 1;
    final space = RegExp(
            r'begincodespacerange([\s\S]*?)endcodespacerange')
        .firstMatch(text);
    if (space != null) {
      final first = RegExp(r'<([0-9A-Fa-f]+)>').firstMatch(space.group(1)!);
      if (first != null) {
        codeBytes = (first.group(1)!.length / 2).ceil().clamp(1, 4);
      }
    }

    for (final block
        in RegExp(r'beginbfchar([\s\S]*?)endbfchar').allMatches(text)) {
      for (final m in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')
          .allMatches(block.group(1)!)) {
        final code = int.parse(m.group(1)!, radix: 16);
        map[code] = _utf16BeToString(m.group(2)!);
      }
    }

    for (final block
        in RegExp(r'beginbfrange([\s\S]*?)endbfrange').allMatches(text)) {
      final body = block.group(1)!;
      // <lo> <hi> [<d1> <d2> …]  — her koda ayrı hedef.
      for (final m in RegExp(
              r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*\[([^\]]*)\]')
          .allMatches(body)) {
        final lo = int.parse(m.group(1)!, radix: 16);
        final targets = RegExp(r'<([0-9A-Fa-f]+)>')
            .allMatches(m.group(3)!)
            .map((t) => _utf16BeToString(t.group(1)!))
            .toList();
        for (var i = 0; i < targets.length; i++) {
          map[lo + i] = targets[i];
        }
      }
      // <lo> <hi> <dstStart> — ardışık eşleme.
      final consumed = RegExp(
              r'<[0-9A-Fa-f]+>\s*<[0-9A-Fa-f]+>\s*\[[^\]]*\]')
          .allMatches(body)
          .map((m) => m.group(0)!)
          .toSet();
      var rest = body;
      for (final c in consumed) {
        rest = rest.replaceAll(c, ' ');
      }
      for (final m in RegExp(
              r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')
          .allMatches(rest)) {
        final lo = int.parse(m.group(1)!, radix: 16);
        final hi = int.parse(m.group(2)!, radix: 16);
        final dst = m.group(3)!;
        // Aralık çok büyükse bozuk CMap'tir; belleği şişirmeyelim.
        if (hi < lo || hi - lo > 65535) continue;
        final base = int.parse(dst, radix: 16);
        final width = dst.length;
        for (var code = lo; code <= hi; code++) {
          map[code] = _utf16BeToString(
              (base + (code - lo)).toRadixString(16).padLeft(width, '0'));
        }
      }
    }

    final reverse = <String, int>{};
    for (final entry in map.entries) {
      // Aynı karaktere birden çok kod düşerse İLKİ kalsın (deterministik).
      if (entry.value.isNotEmpty && !reverse.containsKey(entry.value)) {
        reverse[entry.value] = entry.key;
      }
    }

    return PdfFontEncoding(
      toUnicode: map,
      fromUnicode: reverse,
      codeBytes: codeBytes,
    );
  }

  /// **Basit (tek baytlık) fontun `/Encoding /Differences` tablosundan** eşleme
  /// kurar; kurulamıyorsa null.
  ///
  /// `/ToUnicode` YOKSA tek umut budur: `/Differences [ 208 /Gbreve 221
  /// /Idotaccent … ]` dizisi "bu kod şu harftir"i glif ADIYLA söyler ve
  /// Türkçe belgelerin çoğunda bulunur. Okumadan Latin-1 varsaydığımız için
  /// `İ` yerine `Ý`, `Ğ` yerine `Ð` görüyorduk (2026-08-06 kullanıcı bulgusu).
  ///
  /// Temel tablo **CP1254** (bkz. [PdfFontEncoding.fallback] gerekçesi); adı
  /// açıkça verilen kodlar dizideki glif adından gelir ve temeli EZER.
  ///
  /// Null dönen durumlar (hepsi bilinçli — yarım anlamaktansa yedeğe düşmek):
  /// * `/Subtype /Type0` — kodlar 2 baytlık, `/Differences` kavramı yok.
  /// * `/Differences` yok — temel tablo zaten yedekle aynı, nesne kurmayalım.
  /// * Temel tablo Mac tabanlı — o eşlemeyi taşımıyoruz, yanlış harf yazmayalım.
  static PdfFontEncoding? fromSimpleFont(
    String fontDict, {
    required String? Function(int ref) dictOf,
  }) {
    if (pdfName(fontDict, 'Subtype') == 'Type0') return null;

    final encodingRef = pdfRef(fontDict, 'Encoding');
    final encodingDict = encodingRef == null ? null : dictOf(encodingRef);
    final baseName =
        pdfName(fontDict, 'Encoding') ?? // /Encoding /WinAnsiEncoding
            (encodingDict == null ? null : pdfName(encodingDict, 'BaseEncoding'));
    if (baseName != null && baseName.startsWith('Mac')) return null;

    final differences =
        encodingDict == null ? null : pdfArray(encodingDict, 'Differences');
    if (differences == null || differences.trim().isEmpty) return null;

    final map = <int, String>{
      for (var b = 0; b < 256; b++) b: PdfSingleByteEncoding.turkish.decode([b]),
    };
    var applied = 0;
    var code = 0;
    for (final m
        in RegExp(r'(\d+)|/([^\s/\[\]<>()]+)').allMatches(differences)) {
      final number = m.group(1);
      if (number != null) {
        code = int.tryParse(number) ?? code;
        continue;
      }
      final rune = glyphNameToRune(m.group(2)!);
      if (rune != null && code >= 0 && code < 256) {
        map[code] = String.fromCharCode(rune);
        applied++;
      }
      code++;
    }
    if (applied == 0) return null;

    final reverse = <String, int>{};
    for (final entry in map.entries) {
      if (entry.value.isNotEmpty && !reverse.containsKey(entry.value)) {
        reverse[entry.value] = entry.key;
      }
    }
    return PdfFontEncoding(
        toUnicode: map, fromUnicode: reverse, codeBytes: 1);
  }

  /// Font hakkında **hiçbir** eşleme bilgisi bulunamadığında kullanılacak tek
  /// baytlık tablo.
  ///
  /// **Latin-1 DEĞİL, CP1254 — bilinçli karar (2026-08-06).** İkisi yalnız altı
  /// konumda ayrışır: 0xD0/0xDD/0xDE/0xF0/0xFD/0xFE. Latin-1 okuması bunları
  /// `Ð Ý Þ ð ý þ` (İzlandaca) yapar, CP1254 okuması `Ğ İ Ş ğ ı ş`. Bu
  /// uygulamanın açtığı belgelerde ilk küme neredeyse hiç geçmez, ikincisi
  /// neredeyse her Türkçe belgede geçer. Üstelik CP1254 0x80–0x9F bölgesini de
  /// doldurur: Latin-1 yedeğinde tırnak/tire (`’ “ –`) görünmez denetim
  /// karakterine düşüyordu. Gerçekten `Ð` demek isteyen üretici bunu
  /// `/Differences`ta ADIYLA söyler ve o yol bu tabloyu ezer.
  static PdfSingleByteEncoding get fallback => PdfSingleByteEncoding.turkish;

  /// UTF-16BE onaltılık dizesini metne çevirir (`00DC` → `Ü`).
  static String _utf16BeToString(String hex) {
    if (hex.length <= 2) {
      return String.fromCharCode(int.parse(hex, radix: 16));
    }
    final units = <int>[];
    for (var i = 0; i + 4 <= hex.length; i += 4) {
      units.add(int.parse(hex.substring(i, i + 4), radix: 16));
    }
    if (units.isEmpty) return '';
    return String.fromCharCodes(units);
  }
}
