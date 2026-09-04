/// **APK'nın ikili kaynak biçimlerini okuyan çözümleyici** — `AndroidManifest
/// .xml` (ikili XML) ve `resources.arsc` (kaynak tablosu).
///
/// ## Niye yazıldı (kullanıcı 2026-09-03)
/// *"bizim uygulamanın simgesi görülmüyor dosyalarda, bazı uygulamaların
/// görülüyor bizimki görülmüyor, başka uygulamalarda da görünmeyenler var."*
///
/// Simge şimdiye kadar **dosya adına bakılarak** aranıyordu
/// (`res/mipmap-xxxhdpi/ic_launcher.png`). Kaynak küçültmesiyle
/// (`shrinkResources`) derlenmiş APK'larda AAPT2 kaynak yollarını KISALTIYOR:
/// bizim kendi APK'mızda simge `res/o-.png` adında duruyor ve ada bakan her
/// eşleme boşa çıkıyor. Ada bakmayan yedek arama ise "en büyük kare PNG"yi
/// seçtiği için uyarlanabilir simgenin **zemin katmanını** (düz degrade)
/// buluyordu — kullanıcının gördüğü boş turkuaz kare tam olarak buydu.
///
/// Doğrusu Android'in yaptığını yapmak: manifest'teki `application@icon`
/// **kaynak kimliğini** okuyup `resources.arsc`ten dosya yoluna çevirmek.
/// Ad kısaltması bu yolu etkilemiyor; tablo zaten kimlikle çalışıyor.
///
/// ## Kapsam — dürüstçe
/// Yalnız simge bulmak için gereken kadarı: dizgi havuzu, XML başlangıç
/// elemanları + öznitelikleri, tablodaki **basit** (karmaşık olmayan)
/// girdiler. Stil havuzları, çoğul/dizi kaynakları ve ikili XML'in metin
/// düğümleri okunmuyor — hiçbiri simgeye giden yolda değil.
library;

import 'dart:typed_data';

/// İkili XML özniteliği.
class AxmlAttribute {
  /// `Res_value` veri türü (1 = başka bir kaynağa gönderme, 3 = dizgi …).
  final int type;

  /// Ham değer: gönderme türünde kaynak kimliği, dizgi türünde havuz indisi.
  final int data;

  /// Değer bir dizgiyse çözülmüş hâli.
  final String? string;

  const AxmlAttribute(this.type, this.data, this.string);

  static const typeReference = 0x01;
  static const typeString = 0x03;
  static const typeFloat = 0x04;
  static const typeDimension = 0x05;
  static const typeFraction = 0x06;
  static const typeIntFirst = 0x10;
  static const typeIntLast = 0x1f;

  /// Bu öznitelik bir kaynağa gönderme mi (ve kimliği sıfırdan farklı mı)?
  bool get isReference => type == typeReference && data != 0;

  /// **Sayısal değeri** — kayan nokta, ölçü (dp/sp), oran, tam sayı ya da
  /// sayı yazan bir dizge. Sayı değilse null.
  ///
  /// Vektör çizimler için gerekli (`viewportWidth="24"`, `strokeWidth="1.5"`,
  /// `rotation="45"`): aynı alan bir APK'da float, ötekinde dizge geliyor.
  double? get asDouble {
    switch (type) {
      case typeFloat:
        final buffer = ByteData(4)..setUint32(0, data, Endian.little);
        return buffer.getFloat32(0, Endian.little);
      case typeDimension:
      case typeFraction:
        // `Res_value` karmaşık sayısı: üst 24 bit mantis, 4-5. bitler taban.
        const mantissa = 1.0 / (1 << 8);
        const radix = [
          mantissa,
          mantissa / (1 << 7),
          mantissa / (1 << 15),
          mantissa / (1 << 23),
        ];
        return (data & 0xFFFFFF00).toSigned(32) * radix[(data >> 4) & 3];
      case typeString:
        final text = string;
        if (text == null) return null;
        // "24dp" / "1.5sp" → sayı kısmı.
        final match = RegExp(r'^-?[0-9]*\.?[0-9]+').firstMatch(text.trim());
        return match == null ? null : double.tryParse(match.group(0)!);
      default:
        if (type >= typeIntFirst && type <= typeIntLast) return data.toDouble();
        return null;
    }
  }
}

/// İkili XML'de bir başlangıç elemanı.
class AxmlElement {
  final String name;

  /// Öznitelikler **kaynak kimliğine** göre (ör. `android:icon` = 0x01010002).
  /// Ad havuzu kısaltılmış APK'larda adlar boş kalabiliyor; kimlik kalmıyor.
  final Map<int, AxmlAttribute> byResId;

  /// Öznitelikler ada göre (ad havuzu okunabildiğinde).
  final Map<String, AxmlAttribute> byName;

  const AxmlElement(this.name, this.byResId, this.byName);
}

/// İkili XML ağacında bir düğüm: eleman + çocukları.
///
/// Vektör çizimler (`<vector><group><path/></group></vector>`) için gerekli;
/// düz eleman listesi grubun dönüşümünü hangi yolun taşıdığını kaybeder.
class AxmlNode {
  final AxmlElement element;
  final List<AxmlNode> children = [];

  AxmlNode(this.element);

  String get name => element.name;

  /// Adı [name] olan ilk çocuk (yoksa null).
  AxmlNode? child(String name) {
    for (final c in children) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// Ağacın tamamında adı [name] olan düğümler (kendisi dahil).
  Iterable<AxmlNode> descendants(String name) sync* {
    if (this.name == name) yield this;
    for (final c in children) {
      yield* c.descendants(name);
    }
  }
}

/// Android'in ikili XML biçimi (AXML).
abstract final class AndroidBinaryXml {
  static const _chunkStringPool = 0x0001;
  static const _chunkXml = 0x0003;
  static const _chunkResourceMap = 0x0180;
  static const _chunkStartElement = 0x0102;
  static const _chunkEndElement = 0x0103;

  /// Android çerçevesinin öznitelik kimlikleri (yalnız kullandıklarımız).
  static const attrIcon = 0x01010002;
  static const attrRoundIcon = 0x0101052c;
  static const attrDrawable = 0x01010199;

  /// Belgeyi **ağaç olarak** okur (iç içe elemanlar korunur).
  ///
  /// Niye gerekli (2026-09-03): vektör çizimlerde (`<vector>`) anlam iç içe
  /// duruyor — `<group>` altındaki `<path>` grubun dönüşümünü taşır ve düz
  /// bir liste bunu kaybeder. [parse] düz liste döndürmeye devam ediyor;
  /// simge arayan eski yollar onu kullanıyor.
  static List<AxmlNode> parseTree(Uint8List bytes) {
    try {
      return _parseTree(bytes);
    } catch (_) {
      return const [];
    }
  }

  /// Belgedeki başlangıç elemanlarını sırayla döndürür. Biçim tanınmazsa boş.
  static List<AxmlElement> parse(Uint8List bytes) {
    try {
      return _parse(bytes);
    } catch (_) {
      // Bozuk/tanınmayan APK: çağıran eski sezgisel yola düşer.
      return const [];
    }
  }

  static List<AxmlElement> _parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 8) return const [];
    if (data.getUint16(0, Endian.little) != _chunkXml) return const [];
    final headerSize = data.getUint16(2, Endian.little);
    final total = data.getUint32(4, Endian.little);
    final end = total < bytes.length ? total : bytes.length;

    List<String> strings = const [];
    List<int> resourceMap = const [];
    final out = <AxmlElement>[];

    var offset = headerSize;
    while (offset + 8 <= end) {
      final type = data.getUint16(offset, Endian.little);
      final chunkHeader = data.getUint16(offset + 2, Endian.little);
      final size = data.getUint32(offset + 4, Endian.little);
      if (size < 8) break;
      switch (type) {
        case _chunkStringPool:
          strings = readStringPool(bytes, offset);
        case _chunkResourceMap:
          final count = (size - chunkHeader) ~/ 4;
          resourceMap = [
            for (var i = 0; i < count; i++)
              data.getUint32(offset + chunkHeader + 4 * i, Endian.little),
          ];
        case _chunkStartElement:
          final element =
              _readElement(data, offset, chunkHeader, strings, resourceMap);
          if (element != null) out.add(element);
      }
      offset += size;
    }
    return out;
  }

  static List<AxmlNode> _parseTree(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 8) return const [];
    if (data.getUint16(0, Endian.little) != _chunkXml) return const [];
    final headerSize = data.getUint16(2, Endian.little);
    final total = data.getUint32(4, Endian.little);
    final end = total < bytes.length ? total : bytes.length;

    List<String> strings = const [];
    List<int> resourceMap = const [];
    final roots = <AxmlNode>[];
    final stack = <AxmlNode>[];

    var offset = headerSize;
    while (offset + 8 <= end) {
      final type = data.getUint16(offset, Endian.little);
      final chunkHeader = data.getUint16(offset + 2, Endian.little);
      final size = data.getUint32(offset + 4, Endian.little);
      if (size < 8) break;
      switch (type) {
        case _chunkStringPool:
          strings = readStringPool(bytes, offset);
        case _chunkResourceMap:
          final count = (size - chunkHeader) ~/ 4;
          resourceMap = [
            for (var i = 0; i < count; i++)
              data.getUint32(offset + chunkHeader + 4 * i, Endian.little),
          ];
        case _chunkStartElement:
          final element =
              _readElement(data, offset, chunkHeader, strings, resourceMap);
          if (element != null) {
            final node = AxmlNode(element);
            if (stack.isEmpty) {
              roots.add(node);
            } else {
              stack.last.children.add(node);
            }
            stack.add(node);
          }
        case _chunkEndElement:
          if (stack.isNotEmpty) stack.removeLast();
      }
      offset += size;
    }
    return roots;
  }

  static AxmlElement? _readElement(
    ByteData data,
    int offset,
    int chunkHeader,
    List<String> strings,
    List<int> resourceMap,
  ) {
    // `ResXMLTree_attrExt`: ns(4) name(4) attributeStart(2) attributeSize(2)
    // attributeCount(2) idIndex(2) classIndex(2) styleIndex(2).
    // **`attributeStart` bu yapının başından ölçülür**, düğüm başlığından
    // değil — birini ötekiyle karıştırmak öznitelikleri çöp okutuyor.
    final ext = offset + chunkHeader;
    if (ext + 20 > data.lengthInBytes) return null;
    final nameIndex = data.getUint32(ext + 4, Endian.little);
    final attributeStart = data.getUint16(ext + 8, Endian.little);
    final attributeSize = data.getUint16(ext + 10, Endian.little);
    final attributeCount = data.getUint16(ext + 12, Endian.little);
    final byResId = <int, AxmlAttribute>{};
    final byName = <String, AxmlAttribute>{};
    for (var i = 0; i < attributeCount; i++) {
      final at = ext + attributeStart + i * attributeSize;
      if (at + 20 > data.lengthInBytes) break;
      final attrName = data.getUint32(at + 4, Endian.little);
      final rawValue = data.getUint32(at + 8, Endian.little);
      final valueType = data.getUint8(at + 15);
      final valueData = data.getUint32(at + 16, Endian.little);
      String? text;
      if (valueType == AxmlAttribute.typeString) {
        text = _at(strings, valueData);
      }
      text ??= _at(strings, rawValue);
      final attribute = AxmlAttribute(valueType, valueData, text);
      if (attrName < resourceMap.length) {
        byResId[resourceMap[attrName]] = attribute;
      }
      final label = _at(strings, attrName);
      if (label != null && label.isNotEmpty) byName[label] = attribute;
    }
    return AxmlElement(_at(strings, nameIndex) ?? '', byResId, byName);
  }

  static String? _at(List<String> strings, int index) =>
      index < strings.length && index >= 0 ? strings[index] : null;

  /// `ResStringPool` — hem ikili XML hem kaynak tablosu bunu kullanıyor.
  ///
  /// İki kodlama var ve bayrak biti (0x100) hangisi olduğunu söylüyor. Uzunluk
  /// alanları "yüksek bit varsa iki birim" kuralıyla yazılıyor (UTF-8'de bayt,
  /// UTF-16'da 16-bit); tek birim varsayan bir okuma uzun dizgilerde kayıyor.
  static List<String> readStringPool(Uint8List bytes, int offset) {
    final data = ByteData.sublistView(bytes);
    if (offset + 28 > bytes.length) return const [];
    final headerSize = data.getUint16(offset + 2, Endian.little);
    final count = data.getUint32(offset + 8, Endian.little);
    final flags = data.getUint32(offset + 16, Endian.little);
    final stringsStart = data.getUint32(offset + 20, Endian.little);
    final utf8Pool = (flags & 0x100) != 0;
    final out = <String>[];
    for (var i = 0; i < count; i++) {
      final indexAt = offset + headerSize + 4 * i;
      if (indexAt + 4 > bytes.length) break;
      var p = offset +
          stringsStart +
          data.getUint32(indexAt, Endian.little);
      if (p >= bytes.length) {
        out.add('');
        continue;
      }
      if (utf8Pool) {
        // Karakter sayısı (atlanır) + bayt sayısı.
        var chars = bytes[p++];
        if ((chars & 0x80) != 0 && p < bytes.length) {
          chars = ((chars & 0x7f) << 8) | bytes[p++];
        }
        var length = p < bytes.length ? bytes[p++] : 0;
        if ((length & 0x80) != 0 && p < bytes.length) {
          length = ((length & 0x7f) << 8) | bytes[p++];
        }
        final stop = p + length <= bytes.length ? p + length : bytes.length;
        out.add(_decodeUtf8(bytes, p, stop));
      } else {
        var length = data.getUint16(p, Endian.little);
        p += 2;
        if ((length & 0x8000) != 0 && p + 2 <= bytes.length) {
          length = ((length & 0x7fff) << 16) | data.getUint16(p, Endian.little);
          p += 2;
        }
        final buffer = StringBuffer();
        for (var c = 0; c < length && p + 2 <= bytes.length; c++, p += 2) {
          buffer.writeCharCode(data.getUint16(p, Endian.little));
        }
        out.add(buffer.toString());
      }
    }
    return out;
  }

  /// Küçük ve **hataya dayanıklı** UTF-8 çözücü: bozuk bayt dizini bütün
  /// havuzu düşürmesin (bir dosya adı okunamazsa yalnız o kayıp olmalı).
  static String _decodeUtf8(Uint8List bytes, int start, int stop) {
    final buffer = StringBuffer();
    var i = start;
    while (i < stop) {
      final b = bytes[i];
      if (b < 0x80) {
        buffer.writeCharCode(b);
        i++;
      } else if (b < 0xE0 && i + 1 < stop) {
        buffer.writeCharCode(((b & 0x1F) << 6) | (bytes[i + 1] & 0x3F));
        i += 2;
      } else if (b < 0xF0 && i + 2 < stop) {
        buffer.writeCharCode(((b & 0x0F) << 12) |
            ((bytes[i + 1] & 0x3F) << 6) |
            (bytes[i + 2] & 0x3F));
        i += 3;
      } else if (i + 3 < stop) {
        final code = ((b & 0x07) << 18) |
            ((bytes[i + 1] & 0x3F) << 12) |
            ((bytes[i + 2] & 0x3F) << 6) |
            (bytes[i + 3] & 0x3F);
        buffer.writeCharCode(code);
        i += 4;
      } else {
        i++;
      }
    }
    return buffer.toString();
  }
}

/// Kaynak tablosundaki tek bir değer (bir yapılandırma için).
class ArscValue {
  /// Yapılandırmanın yoğunluğu (dpi). 0 = herhangi, 65534 = "anydpi".
  final int density;

  /// Kaynak türü (`mipmap`, `drawable` …).
  final String type;

  /// Kaynak adı (`ic_launcher`). Dosya adı kısaltılsa da bu KALIYOR.
  final String name;

  /// `Res_value` veri türü.
  final int dataType;

  /// Ham değer (renk kaynaklarında ARGB, gönderme türünde kaynak kimliği).
  final int data;

  /// Değer dizgiyse çözülmüş hâli (dosya kaynaklarında `res/…` yolu).
  final String? string;

  const ArscValue({
    required this.density,
    required this.type,
    required this.name,
    required this.dataType,
    required this.data,
    this.string,
  });

  bool get isFile =>
      dataType == AxmlAttribute.typeString &&
      (string?.startsWith('res/') ?? false);
}

/// `resources.arsc` — APK'nın kaynak tablosu.
class ArscTable {
  /// Kaynak kimliği → yapılandırmalara göre değerler.
  final Map<int, List<ArscValue>> entries;

  const ArscTable(this.entries);

  static const _chunkTable = 0x0002;
  static const _chunkPackage = 0x0200;
  static const _chunkType = 0x0201;

  /// "anydpi" yapılandırması: uyarlanabilir simgenin XML'i buraya düşer.
  static const anyDensity = 0xFFFE;

  static ArscTable? parse(Uint8List bytes) {
    try {
      return _parse(bytes);
    } catch (_) {
      return null;
    }
  }

  static ArscTable? _parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 12) return null;
    if (data.getUint16(0, Endian.little) != _chunkTable) return null;
    final headerSize = data.getUint16(2, Endian.little);
    final total = data.getUint32(4, Endian.little);
    final end = total < bytes.length ? total : bytes.length;

    // Tablonun genel dizgi havuzu: dosya yolları burada.
    final values = AndroidBinaryXml.readStringPool(bytes, headerSize);
    final entries = <int, List<ArscValue>>{};

    var offset = headerSize + data.getUint32(headerSize + 4, Endian.little);
    while (offset + 8 <= end) {
      final type = data.getUint16(offset, Endian.little);
      final chunkHeader = data.getUint16(offset + 2, Endian.little);
      final size = data.getUint32(offset + 4, Endian.little);
      if (size < 8) break;
      if (type == _chunkPackage) {
        _readPackage(bytes, data, offset, chunkHeader, size, values, entries);
      }
      offset += size;
    }
    if (entries.isEmpty) return null;
    return ArscTable(entries);
  }

  static void _readPackage(
    Uint8List bytes,
    ByteData data,
    int offset,
    int chunkHeader,
    int size,
    List<String> values,
    Map<int, List<ArscValue>> entries,
  ) {
    // `ResTable_package`: header(8) id(4) name(256 bayt) typeStrings(4)
    // lastPublicType(4) keyStrings(4) lastPublicKey(4).
    final packageId = data.getUint32(offset + 8, Endian.little);
    final typeStringsOffset = data.getUint32(offset + 268, Endian.little);
    final keyStringsOffset = data.getUint32(offset + 276, Endian.little);
    final types = typeStringsOffset == 0
        ? const <String>[]
        : AndroidBinaryXml.readStringPool(bytes, offset + typeStringsOffset);
    final keys = keyStringsOffset == 0
        ? const <String>[]
        : AndroidBinaryXml.readStringPool(bytes, offset + keyStringsOffset);

    var at = offset + chunkHeader;
    final end = offset + size;
    while (at + 8 <= end) {
      final chunkType = data.getUint16(at, Endian.little);
      final header = data.getUint16(at + 2, Endian.little);
      final chunkSize = data.getUint32(at + 4, Endian.little);
      if (chunkSize < 8) break;
      if (chunkType == _chunkType) {
        _readType(bytes, data, at, header, chunkSize, packageId, types, keys,
            values, entries);
      }
      at += chunkSize;
    }
  }

  static void _readType(
    Uint8List bytes,
    ByteData data,
    int at,
    int header,
    int size,
    int packageId,
    List<String> types,
    List<String> keys,
    List<String> values,
    Map<int, List<ArscValue>> entries,
  ) {
    // `ResTable_type`: header(8) id(1) flags(1) reserved(2) entryCount(4)
    // entriesStart(4) config(…).
    final typeId = data.getUint8(at + 8);
    final flags = data.getUint8(at + 9);
    final entryCount = data.getUint32(at + 12, Endian.little);
    final entriesStart = data.getUint32(at + 16, Endian.little);
    final configSize = data.getUint32(at + 20, Endian.little);
    // Yoğunluk `ResTable_config`in 14. baytında (size(4) imsi(4) locale(4)
    // orientation(1) touchscreen(1) → density(2)).
    final density =
        configSize >= 16 ? data.getUint16(at + 20 + 14, Endian.little) : 0;
    final sparse = (flags & 0x01) != 0;
    final offset16 = (flags & 0x02) != 0;
    final typeName = typeId - 1 < types.length && typeId >= 1
        ? types[typeId - 1]
        : '';

    for (var i = 0; i < entryCount; i++) {
      int entryIndex;
      int entryOffset;
      if (sparse) {
        final p = at + header + 4 * i;
        if (p + 4 > bytes.length) break;
        entryIndex = data.getUint16(p, Endian.little);
        entryOffset = data.getUint16(p + 2, Endian.little) * 4;
      } else if (offset16) {
        final p = at + header + 2 * i;
        if (p + 2 > bytes.length) break;
        final raw = data.getUint16(p, Endian.little);
        if (raw == 0xFFFF) continue;
        entryIndex = i;
        entryOffset = raw * 4;
      } else {
        final p = at + header + 4 * i;
        if (p + 4 > bytes.length) break;
        final raw = data.getUint32(p, Endian.little);
        if (raw == 0xFFFFFFFF) continue;
        entryIndex = i;
        entryOffset = raw;
      }
      final entry = at + entriesStart + entryOffset;
      if (entry + 8 > bytes.length) continue;
      final entrySize = data.getUint16(entry, Endian.little);
      final entryFlags = data.getUint16(entry + 2, Endian.little);
      final keyIndex = data.getUint32(entry + 4, Endian.little);
      // Karmaşık girdi (stil/dizi) — simge dosyası değil, atlanır.
      if ((entryFlags & 0x0001) != 0) continue;
      final valueAt = entry + (entrySize >= 8 ? entrySize : 8);
      if (valueAt + 8 > bytes.length) continue;
      final dataType = data.getUint8(valueAt + 3);
      final valueData = data.getUint32(valueAt + 4, Endian.little);
      final resId = (packageId << 24) | (typeId << 16) | entryIndex;
      entries.putIfAbsent(resId, () => <ArscValue>[]).add(ArscValue(
            density: density,
            type: typeName,
            name: keyIndex < keys.length ? keys[keyIndex] : '',
            dataType: dataType,
            data: valueData,
            string: dataType == AxmlAttribute.typeString &&
                    valueData < values.length
                ? values[valueData]
                : null,
          ));
    }
  }

  List<ArscValue> lookup(int resId) => entries[resId] ?? const [];

  /// [resId] kaynağının **en keskin** dosyası.
  ///
  /// Yoğunluk sıralaması bilinçli: `anydpi` (uyarlanabilir simgenin XML'i) en
  /// sona konur — çizilebilir bir raster varsa o yeğlenir, XML ancak başka
  /// hiçbir şey yoksa döner. [xml] `false` ise XML uzantılı adaylar hiç
  /// bakılmaz.
  String? bestFile(int resId, {bool xml = true}) {
    String? best;
    var bestScore = -1;
    for (final value in lookup(resId)) {
      final path = value.string;
      if (!value.isFile || path == null) continue;
      final isXml = path.toLowerCase().endsWith('.xml');
      if (isXml && !xml) continue;
      // anydpi/anydpi-v26 (0xFFFE) gerçek bir yoğunluk değil; en düşük puan.
      final density = value.density == anyDensity ? 0 : value.density;
      final score = (isXml ? 0 : 100000) + density;
      if (score <= bestScore) continue;
      bestScore = score;
      best = path;
    }
    return best;
  }
}
