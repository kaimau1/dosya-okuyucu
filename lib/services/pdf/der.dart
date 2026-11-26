/// Küçük **DER (ASN.1) yazıcı** — Faz 39 dijital imza için öz-imzalı X.509
/// sertifikası kurmaya yeter (SEQUENCE/SET/INTEGER/OID/…).
///
/// Neden pointycastle'ın ASN1 sınıfları değil: her nesne `encodedBytes`
/// önbelleği tutuyor, BIT STRING/INTEGER işaret baytı kurallarını çağıranın
/// bilmesini bekliyor; burada her şey saf fonksiyon ve test edilebilir.
library;

import 'dart:convert';
import 'dart:typed_data';

abstract final class Der {
  static const tagInteger = 0x02;
  static const tagBitString = 0x03;
  static const tagOctetString = 0x04;
  static const tagNull = 0x05;
  static const tagOid = 0x06;
  static const tagUtf8 = 0x0c;
  static const tagUtcTime = 0x17;
  static const tagGeneralizedTime = 0x18;
  static const tagBoolean = 0x01;
  static const tagSequence = 0x30;
  static const tagSet = 0x31;

  /// Etiket + uzunluk + değer.
  static Uint8List tlv(int tag, List<int> value) {
    final out = BytesBuilder(copy: false)
      ..addByte(tag)
      ..add(length(value.length))
      ..add(value);
    return out.toBytes();
  }

  /// DER uzunluk kodu: <128 kısa biçim, üstü 0x80|n + büyük-endian baytlar.
  static List<int> length(int n) {
    if (n < 0x80) return [n];
    final bytes = <int>[];
    var v = n;
    while (v > 0) {
      bytes.insert(0, v & 0xff);
      v >>= 8;
    }
    return [0x80 | bytes.length, ...bytes];
  }

  static Uint8List sequence(List<List<int>> items) =>
      tlv(tagSequence, [for (final i in items) ...i]);

  /// SET OF — DER kuralı: öğeler kodlanmış baytlarına göre sıralı.
  static Uint8List set(List<List<int>> items) {
    final sorted = [...items]..sort(_compareBytes);
    return tlv(tagSet, [for (final i in sorted) ...i]);
  }

  static int _compareBytes(List<int> a, List<int> b) {
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  /// İşaretli tamsayı (ikiye tümleyen, en kısa biçim).
  static Uint8List integer(BigInt value) => tlv(tagInteger, bigIntBytes(value));

  static Uint8List smallInt(int value) => integer(BigInt.from(value));

  /// Pozitif sayının baytları; en üst bit 1 ise başa 0x00 (negatif okunmasın).
  static List<int> bigIntBytes(BigInt value) {
    if (value == BigInt.zero) return [0];
    if (value.isNegative) {
      throw ArgumentError('Negatif tamsayı desteklenmiyor');
    }
    final bytes = <int>[];
    var v = value;
    final mask = BigInt.from(0xff);
    while (v > BigInt.zero) {
      bytes.insert(0, (v & mask).toInt());
      v >>= 8;
    }
    if (bytes.first & 0x80 != 0) bytes.insert(0, 0);
    return bytes;
  }

  /// Büyük-endian işaretsiz baytlar (imza/modül için, baştaki 0 yok).
  static Uint8List unsignedBytes(BigInt value, [int? width]) {
    final raw = bigIntBytes(value);
    final trimmed = raw.length > 1 && raw.first == 0 ? raw.sublist(1) : raw;
    if (width == null || trimmed.length >= width) {
      return Uint8List.fromList(trimmed);
    }
    return Uint8List(width)..setAll(width - trimmed.length, trimmed);
  }

  static Uint8List oid(String dotted) {
    final parts = dotted.split('.').map(int.parse).toList();
    if (parts.length < 2) throw ArgumentError('OID: $dotted');
    final body = <int>[parts[0] * 40 + parts[1]];
    for (final p in parts.skip(2)) {
      final chunk = <int>[p & 0x7f];
      var v = p >> 7;
      while (v > 0) {
        chunk.insert(0, 0x80 | (v & 0x7f));
        v >>= 7;
      }
      body.addAll(chunk);
    }
    return tlv(tagOid, body);
  }

  static Uint8List nullValue() => Uint8List.fromList([tagNull, 0]);

  static Uint8List boolean(bool v) => tlv(tagBoolean, [v ? 0xff : 0]);

  static Uint8List utf8String(String s) => tlv(tagUtf8, utf8.encode(s));

  static Uint8List octetString(List<int> v) => tlv(tagOctetString, v);

  /// BIT STRING (kullanılmayan bit sayısı + veri).
  static Uint8List bitString(List<int> v, {int unusedBits = 0}) =>
      tlv(tagBitString, [unusedBits, ...v]);

  /// 2050 öncesi UTCTime (YYMMDDHHMMSSZ), sonrası GeneralizedTime — RFC 5280.
  static Uint8List time(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final tail =
        '${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
    if (u.year < 2050) {
      return tlv(tagUtcTime, ascii.encode('${two(u.year % 100)}$tail'));
    }
    return tlv(tagGeneralizedTime, ascii.encode('${u.year}$tail'));
  }

  /// `[n]` açık (explicit) bağlam etiketi.
  static Uint8List explicit(int n, List<int> inner) => tlv(0xa0 | n, inner);

  /// BER/DER akışından tek bir düğüm okur (belirli ve belirsiz uzunluk destekli).
  static DerNode? parse(Uint8List buf, [int offset = 0]) {
    if (offset < 0 || offset + 2 > buf.length) return null;
    final tag = buf[offset];
    final lenByte = buf[offset + 1];
    if (lenByte == 0x80) {
      // Belirsiz uzunluk (BER): 0x00 0x00 bitiricisine kadar alt düğümleri tara.
      final valueStart = offset + 2;
      var pos = valueStart;
      while (pos + 1 < buf.length) {
        if (buf[pos] == 0 && buf[pos + 1] == 0) {
          return DerNode(tag, offset, valueStart, pos, pos + 2,
              indefinite: true);
        }
        final child = parse(buf, pos);
        if (child == null || child.end <= pos) return null;
        pos = child.end;
      }
      return null;
    }
    int len;
    int valueStart;
    if (lenByte < 0x80) {
      len = lenByte;
      valueStart = offset + 2;
    } else {
      final count = lenByte & 0x7f;
      if (count == 0 || count > 4 || offset + 2 + count > buf.length) {
        return null;
      }
      len = 0;
      for (var i = 0; i < count; i++) {
        len = (len << 8) | buf[offset + 2 + i];
      }
      valueStart = offset + 2 + count;
    }
    final valueEnd = valueStart + len;
    if (valueEnd > buf.length) return null;
    return DerNode(tag, offset, valueStart, valueEnd, valueEnd);
  }

  /// Düğümün içindeki tüm alt düğümleri okur.
  static List<DerNode> children(Uint8List buf, DerNode parent) {
    final out = <DerNode>[];
    var pos = parent.valueStart;
    while (pos < parent.valueEnd) {
      final child = parse(buf, pos);
      if (child == null || child.end <= pos || child.end > parent.valueEnd) {
        break;
      }
      out.add(child);
      pos = child.end;
    }
    return out;
  }

  /// OID düğümünü noktalı dizeye çevirir (`1.2.840.113549.1.1.11`).
  static String? decodeOid(Uint8List buf, DerNode node) {
    if (node.tag != tagOid || node.valueStart >= node.valueEnd) return null;
    final first = buf[node.valueStart];
    final parts = <int>[first ~/ 40, first % 40];
    var v = 0;
    for (var i = node.valueStart + 1; i < node.valueEnd; i++) {
      final b = buf[i];
      v = (v << 7) | (b & 0x7f);
      if ((b & 0x80) == 0) {
        parts.add(v);
        v = 0;
      }
    }
    return parts.join('.');
  }

  /// Pozitif INTEGER düğümünü [BigInt]'e çevirir.
  static BigInt decodeBigInt(Uint8List buf, DerNode node) {
    var v = BigInt.zero;
    for (var i = node.valueStart; i < node.valueEnd; i++) {
      v = (v << 8) | BigInt.from(buf[i]);
    }
    return v;
  }
}

/// Ayrıştırılmış tek bir BER/DER TLV düğümü.
class DerNode {
  const DerNode(
    this.tag,
    this.start,
    this.valueStart,
    this.valueEnd,
    this.end, {
    this.indefinite = false,
  });

  final int tag;
  final int start;
  final int valueStart;
  final int valueEnd;
  final int end;
  final bool indefinite;

  bool get constructed => (tag & 0x20) != 0;

  Uint8List valueBytes(Uint8List buf) => buf.sublist(valueStart, valueEnd);
  Uint8List rawBytes(Uint8List buf) => buf.sublist(start, end);
}
