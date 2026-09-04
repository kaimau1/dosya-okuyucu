/// PDF akış **filtreleri** — `FlateDecode` dışındakiler.
///
/// Kullanıcı bulgusu 2026-09-04: bir belgede sayfa hem metinsiz hem görselsiz
/// görünüyordu. Kök neden `pdf_objects.dart`taki filtre okumasıydı ama
/// düzeltirken ortaya çıktı ki içerik akışlarında gerçekten karşılaşılan
/// birkaç filtre hiç desteklenmiyordu. Hepsi saf fonksiyon, hepsi testli:
/// bozuk girdide **eldeki kadarını** döner, asla fırlatmaz — çağıran
/// (`decodeStream`) zaten kendi kapısında reddediyor.
library;

/// `ASCIIHexDecode`: onaltılık çiftler, `>` ile biter.
List<int> pdfAsciiHexDecode(List<int> data) {
  final out = <int>[];
  var high = -1;
  for (final b in data) {
    if (b == 0x3E) break; // '>'
    final v = _hexValue(b);
    if (v < 0) continue; // boşluk ve tanınmayan bayt atlanır
    if (high < 0) {
      high = v;
    } else {
      out.add((high << 4) | v);
      high = -1;
    }
  }
  // Tek kalan yarım bayt: eksik basamak 0 sayılır (PDF 7.4.2).
  if (high >= 0) out.add(high << 4);
  return out;
}

int _hexValue(int b) {
  if (b >= 0x30 && b <= 0x39) return b - 0x30;
  if (b >= 0x41 && b <= 0x46) return b - 0x41 + 10;
  if (b >= 0x61 && b <= 0x66) return b - 0x61 + 10;
  return -1;
}

/// `ASCII85Decode`: beş harf → dört bayt, `z` → dört sıfır, `~>` ile biter.
List<int> pdfAscii85Decode(List<int> data) {
  final out = <int>[];
  final group = <int>[];
  for (var i = 0; i < data.length; i++) {
    final b = data[i];
    if (b == 0x7E) break; // '~' → '~>'
    if (b == 0x7A && group.isEmpty) {
      out.addAll(const [0, 0, 0, 0]); // 'z'
      continue;
    }
    if (b < 0x21 || b > 0x75) continue; // boşluk vb.
    group.add(b - 0x21);
    if (group.length == 5) {
      _emit85(group, out, 4);
      group.clear();
    }
  }
  if (group.length > 1) {
    final n = group.length - 1;
    while (group.length < 5) {
      group.add(84); // 'u' — eksik basamaklar en büyük değerle doldurulur
    }
    _emit85(group, out, n);
  }
  return out;
}

void _emit85(List<int> group, List<int> out, int take) {
  var value = 0;
  for (final g in group) {
    value = value * 85 + g;
  }
  final bytes = [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
  out.addAll(bytes.take(take));
}

/// `RunLengthDecode`: `0–127` → sonraki n+1 bayt olduğu gibi,
/// `129–255` → sonraki bayt 257−n kez, `128` → son.
List<int> pdfRunLengthDecode(List<int> data) {
  final out = <int>[];
  var i = 0;
  while (i < data.length) {
    final len = data[i];
    i++;
    if (len == 128) break;
    if (len < 128) {
      final take = len + 1;
      for (var k = 0; k < take && i < data.length; k++, i++) {
        out.add(data[i]);
      }
    } else {
      if (i >= data.length) break;
      final b = data[i];
      i++;
      for (var k = 0; k < 257 - len; k++) {
        out.add(b);
      }
    }
  }
  return out;
}

/// `LZWDecode` (PDF/TIFF değişkesi: 9–12 bit değişken kod, 256 = temizle,
/// 257 = son).
///
/// [early] 1 ise (varsayılan) kod genişliği bir kod ERKEN büyür — PDF'in
/// alışılmış davranışı; 0 yazan üreticiler de var, `/DecodeParms
/// /EarlyChange 0` onu söyler.
List<int> pdfLzwDecode(List<int> data, {int early = 1}) {
  const clearCode = 256;
  const eodCode = 257;
  final out = <int>[];
  var table = <List<int>>[];

  void resetTable() {
    table = [for (var i = 0; i < 256; i++) [i], const [], const []];
  }

  resetTable();
  var codeBits = 9;
  var buffer = 0;
  var bits = 0;
  List<int>? previous;

  for (final byte in data) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= codeBits) {
      final code = (buffer >> (bits - codeBits)) & ((1 << codeBits) - 1);
      bits -= codeBits;
      if (code == eodCode) return out;
      if (code == clearCode) {
        resetTable();
        codeBits = 9;
        previous = null;
        continue;
      }
      List<int> entry;
      if (code < table.length && (code < 256 || table[code].isNotEmpty)) {
        entry = table[code];
      } else if (previous != null) {
        entry = [...previous, previous[0]];
      } else {
        return out; // bozuk akış — eldeki kadarı
      }
      out.addAll(entry);
      if (previous != null) {
        table.add([...previous, entry[0]]);
      }
      previous = entry;
      final limit = table.length + early;
      if (limit >= 512 && codeBits == 9) {
        codeBits = 10;
      } else if (limit >= 1024 && codeBits == 10) {
        codeBits = 11;
      } else if (limit >= 2048 && codeBits == 11) {
        codeBits = 12;
      }
    }
  }
  return out;
}
