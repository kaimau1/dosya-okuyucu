/// **Artımlı kayıt kırpması** (PDF Pro Faz 54 / 0, PK1 koşulu 2).
///
/// KÖK NEDEN (Faz 52 ölçümü): PDFium'un `FPDF_INCREMENTAL` kaydı yalnız
/// değişen nesneleri değil, belleğe YÜKLENMİŞ her nesneyi (çizim sırasında
/// açılan font sözlükleri, gömülü FontFile2 akışları…) ekte yeniden yazıyor →
/// tek paragraf düzenlemesi +36 KB (p50). PDFium'un kaydını yeniden yazamayız
/// ama ekini okuyabiliriz: ekteki her nesne özgünüyle **anlamca** (sözlük
/// anahtar sırası, sayı/dize yazımı, akış filtresi farkı yok sayılarak)
/// karşılaştırılır; aynı olanlar atılır, sıkıştırılmamış akışlar Flate'lenir,
/// kalanlar Dart artımlı yazıcısıyla ([PdfFile.appendRawObjects]) yazılır.
///
/// Güvenli taraf: anlayamadığımız her durumda (şifreli belge, ekte nesne
/// akışı, özgünle başlamayan çıktı, ayrıştırma hatası) PDFium'un kendi kaydı
/// DEĞİŞMEDEN döner — kırpma yalnız boyutu küçültür, içeriği değiştirmez.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../pdf_objects.dart';

abstract final class PdfIncrementalTrim {
  /// [saved] = [original] + PDFium eki. Kırpılmış sürümü döndürür.
  static Uint8List trim(Uint8List original, Uint8List saved) {
    try {
      return _trim(original, saved) ?? saved;
    } catch (_) {
      return saved;
    }
  }

  static Uint8List? _trim(Uint8List original, Uint8List saved) {
    if (saved.length <= original.length) return null;
    for (var i = 0; i < original.length; i++) {
      if (saved[i] != original[i]) return null;
    }
    final base = PdfFile.parse(original);
    // Şifreli belge: PDFium eki kendi şifreleme sözlüğü/kimliğiyle yazıyor;
    // özgün trailer'la birleştirmek belgeyi bozdu (Faz 54 ölçümü) → dokunma.
    if (base.isEncrypted) return null;
    final tailBytes = Uint8List.sublistView(saved, original.length);
    final tail = PdfFile.parse(tailBytes);

    final kept = <({int number, int generation, List<int> body})>[];
    var dropped = 0;
    for (final o in tail.objects.values) {
      if (o.insideObjectStream) return null; // ekte ObjStm: anlamıyoruz
      final type = pdfName(o.dict, 'Type');
      if (type == 'XRef') continue;
      if (type == 'ObjStm') return null;
      final old = base.objects[o.number];
      if (old != null && _same(base, old, tail, o)) {
        dropped++;
        continue;
      }
      kept.add((
        number: o.number,
        generation: o.generation,
        body: _body(tail, o),
      ));
    }
    if (dropped == 0 && !_anyUncompressed(tail)) {
      return null; // kırpacak bir şey yok — PDFium'un kaydı aynen
    }
    return Uint8List.fromList(base.appendRawObjects(kept));
  }

  static bool _anyUncompressed(PdfFile f) => f.objects.values.any((o) =>
      o.isStream &&
      pdfName(o.dict, 'Type') != 'XRef' &&
      !RegExp(r'/Filter\b').hasMatch(o.dict));

  /// Nesnenin yazılacak gövdesi; sıkıştırılmamış akış Flate'lenir.
  static List<int> _body(PdfFile f, PdfObject o) {
    final head = latin1.encode('${o.number} ${o.generation} obj\n');
    if (!o.isStream) {
      return [...head, ...latin1.encode(o.dict.trim()), ...latin1.encode('\nendobj')];
    }
    final raw = o.rawData(f.bytes);
    if (!RegExp(r'/Filter\b').hasMatch(o.dict)) {
      final z = const ZLibEncoder().encode(raw);
      if (z.length < raw.length) {
        return [
          ...head,
          ...latin1.encode(PdfFile.rebuildStreamDict(o.dict, z.length)),
          ...latin1.encode('\nstream\n'),
          ...z,
          ...latin1.encode('\nendstream\nendobj'),
        ];
      }
    }
    return [
      ...head,
      ...latin1.encode(o.dict.trim()),
      ...latin1.encode('\nstream\n'),
      ...raw,
      ...latin1.encode('\nendstream\nendobj'),
    ];
  }

  static bool _same(PdfFile fa, PdfObject a, PdfFile fb, PdfObject b) {
    if (a.isStream != b.isStream) return false;
    final da = PdfValueParser.parse(a.dict);
    final db = PdfValueParser.parse(b.dict);
    if (!a.isStream) return pdfValueEquals(da, db);
    if (da is! Map || db is! Map) return false;
    const lenOnly = {'/Length'};
    const codec = {'/Length', '/Filter', '/DecodeParms'};
    if (pdfValueEquals(_without(da, lenOnly), _without(db, lenOnly)) &&
        _bytesEqual(a.rawData(fa.bytes), b.rawData(fb.bytes))) {
      return true;
    }
    if (!pdfValueEquals(_without(da, codec), _without(db, codec))) return false;
    try {
      return _bytesEqual(fa.decodeStream(a), fb.decodeStream(b));
    } catch (_) {
      return false; // çözülemeyen (şifreli/bilinmeyen filtre) → "farklı", kalır
    }
  }

  static Map<String, Object?> _without(Map m, Set<String> keys) => {
        for (final e in m.entries)
          if (!keys.contains(e.key)) e.key as String: e.value,
      };

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// PDF nesne sözdiziminin değer düzeyi okuyucusu — yalnız KARŞILAŞTIRMA için:
/// sözlük → `Map` (anahtar sırası önemsiz), dizi → `List`, sayı → `double`,
/// ad → `'/Ad'` (#xx çözülmüş), dize → `'s:'+latin1 bayt` (literal/onaltılık
/// aynı), başvuru → `'r:N G'`, anahtar sözcük → `'k:…'`. Tek değer okunur;
/// fazlası (sözlükten sonraki boşluk) yok sayılır.
abstract final class PdfValueParser {
  static Object? parse(String text) {
    final p = _P(text);
    final v = p.value();
    return v;
  }
}

bool pdfValueEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !pdfValueEquals(e.value, b[e.key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!pdfValueEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

class _P {
  _P(this.s);
  final String s;
  int i = 0;

  void _ws() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x25) {
        while (i < s.length && s[i] != '\n' && s[i] != '\r') {
          i++;
        }
      } else if (c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 ||
          c == 0x0C || c == 0x00) {
        i++;
      } else {
        return;
      }
    }
  }

  static bool _delim(int c) =>
      c <= 0x20 || '()<>[]{}/%'.codeUnits.contains(c);

  Object? value() {
    _ws();
    if (i >= s.length) return null;
    if (s.startsWith('<<', i)) {
      i += 2;
      final m = <String, Object?>{};
      while (true) {
        _ws();
        if (i >= s.length) return m;
        if (s.startsWith('>>', i)) {
          i += 2;
          return m;
        }
        final k = value();
        final v = value();
        if (k is String && k.startsWith('/')) m[k] = v;
      }
    }
    final c = s[i];
    if (c == '[') {
      i++;
      final l = <Object?>[];
      while (true) {
        _ws();
        if (i >= s.length) return l;
        if (s[i] == ']') {
          i++;
          return l;
        }
        l.add(value());
      }
    }
    if (c == '/') {
      final st = ++i;
      while (i < s.length && !_delim(s.codeUnitAt(i))) {
        i++;
      }
      return '/${s.substring(st, i).replaceAllMapped(RegExp(r'#([0-9A-Fa-f]{2})'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))}';
    }
    if (c == '(') return 's:${_literal()}';
    if (c == '<') {
      final end = s.indexOf('>', i);
      var hex = s.substring(i + 1, end < 0 ? s.length : end)
          .replaceAll(RegExp(r'\s'), '');
      i = end < 0 ? s.length : end + 1;
      if (hex.length.isOdd) hex += '0';
      final b = StringBuffer('s:');
      for (var k = 0; k + 1 < hex.length; k += 2) {
        b.writeCharCode(int.parse(hex.substring(k, k + 2), radix: 16));
      }
      return b.toString();
    }
    if (c == ']' || c == '>' || c == ')' || c == '{' || c == '}') {
      i++;
      return 'k:$c';
    }
    // Sayı ya da anahtar sözcük; "N G R" başvurusu tek değer.
    final st = i;
    while (i < s.length && !_delim(s.codeUnitAt(i))) {
      i++;
    }
    final tok = s.substring(st, i);
    final n = double.tryParse(tok);
    if (n == null) return 'k:$tok';
    final m = RegExp(r'\s+(\d+)\s+R(?![^\s()<>\[\]{}/%])').matchAsPrefix(s, i);
    if (m != null && RegExp(r'^\d+$').hasMatch(tok)) {
      i = m.end;
      return 'r:$tok ${m[1]}';
    }
    return n;
  }

  String _literal() {
    i++; // (
    final b = StringBuffer();
    var depth = 1;
    while (i < s.length) {
      final c = s[i++];
      if (c == '\\') {
        if (i >= s.length) break;
        final e = s[i++];
        switch (e) {
          case 'n':
            b.write('\n');
          case 'r':
            b.write('\r');
          case 't':
            b.write('\t');
          case 'b':
            b.write('\b');
          case 'f':
            b.write('\f');
          case '\r':
            if (i < s.length && s[i] == '\n') i++;
          case '\n':
            break;
          default:
            if (RegExp(r'[0-7]').hasMatch(e)) {
              var oct = e;
              while (oct.length < 3 && i < s.length &&
                  RegExp(r'[0-7]').hasMatch(s[i])) {
                oct += s[i++];
              }
              b.writeCharCode(int.parse(oct, radix: 8) & 0xFF);
            } else {
              b.write(e);
            }
        }
      } else if (c == '(') {
        depth++;
        b.write(c);
      } else if (c == ')') {
        if (--depth == 0) break;
        b.write(c);
      } else {
        b.write(c);
      }
    }
    return b.toString();
  }
}
