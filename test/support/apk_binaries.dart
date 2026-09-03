import 'dart:typed_data';

/// **Testler için ikili APK kaynak dosyaları üretir** (`AndroidManifest.xml`
/// ve `resources.arsc`).
///
/// Niye üreteç, niye gerçek bir APK fikstürü değil: gerçek bir APK'nın
/// `resources.arsc`i tek başına 400 KB ve depoya konması gereken her bayt
/// sonsuza kadar orada kalıyor. Üreteç hem küçük hem de biçimi BELGELİYOR:
/// çözümleyicinin okuduğu her alan burada elle yazılıyor, ikisi birbirini
/// denetliyor.
///
/// Kapsam, çözümleyicinin kapsamı kadar: UTF-8 dizgi havuzu, kaynak eşlemi,
/// tek bir başlangıç elemanı ve basit (karmaşık olmayan) tablo girdileri.
abstract final class ApkBinaries {
  /// `ResStringPool` yığını (UTF-8 kodlamalı).
  static Uint8List stringPool(List<String> strings) {
    final offsets = <int>[];
    final data = BytesBuilder();
    for (final s in strings) {
      offsets.add(data.length);
      final bytes = _utf8(s);
      data.addByte(s.length & 0x7F); // karakter sayısı
      data.addByte(bytes.length & 0x7F); // bayt sayısı
      data.add(bytes);
      data.addByte(0);
    }
    var payload = data.toBytes();
    // Yığınlar 4 baytın katına hizalanır.
    if (payload.length % 4 != 0) {
      payload = Uint8List.fromList(
          [...payload, ...List.filled(4 - payload.length % 4, 0)]);
    }
    const header = 28;
    final stringsStart = header + 4 * strings.length;
    final size = stringsStart + payload.length;
    final out = BytesBuilder()
      ..add(_u16(0x0001))
      ..add(_u16(header))
      ..add(_u32(size))
      ..add(_u32(strings.length))
      ..add(_u32(0)) // stil sayısı
      ..add(_u32(0x100)) // UTF-8 bayrağı
      ..add(_u32(stringsStart))
      ..add(_u32(0));
    for (final o in offsets) {
      out.add(_u32(o));
    }
    out.add(payload);
    return out.toBytes();
  }

  /// `application` elemanı olan minik bir ikili manifest.
  ///
  /// [iconResId] `android:icon` özniteliğinin gösterdiği kaynak kimliği.
  static Uint8List manifest({required int iconResId, int? roundIconResId}) {
    // Havuzun BAŞI öznitelik adlarıdır: kaynak eşlemi (resource map) o
    // indisleri kimliğe çeviriyor.
    final names = <String>['icon', if (roundIconResId != null) 'roundIcon'];
    final strings = [...names, 'manifest', 'application'];
    final pool = stringPool(strings);
    // Kaynak eşlemi ÖZNİTELİK kimliklerini taşır (android:icon = 0x01010002),
    // özniteliğin değerini değil — ikisini karıştırmak `byResId`i boş bırakır.
    final map = BytesBuilder()
      ..add(_u16(0x0180))
      ..add(_u16(8))
      ..add(_u32(8 + 4 * names.length))
      ..add(_u32(0x01010002));
    if (roundIconResId != null) map.add(_u32(0x0101052c));
    final resourceMap = map.toBytes();

    final attributes = BytesBuilder()
      ..add(_attribute(nameIndex: 0, dataType: 0x01, data: iconResId));
    if (roundIconResId != null) {
      attributes
          .add(_attribute(nameIndex: 1, dataType: 0x01, data: roundIconResId));
    }
    final attrBytes = attributes.toBytes();
    final attrCount = attrBytes.length ~/ 20;
    final element = BytesBuilder()
      ..add(_u16(0x0102))
      ..add(_u16(16))
      ..add(_u32(16 + 20 + attrBytes.length))
      ..add(_u32(1)) // satır numarası
      ..add(_u32(0xFFFFFFFF)) // yorum yok
      ..add(_u32(0xFFFFFFFF)) // ad alanı yok
      ..add(_u32(strings.indexOf('application')))
      ..add(_u16(20)) // öznitelikler attrExt'in 20. baytında başlar
      ..add(_u16(20)) // her öznitelik 20 bayt
      ..add(_u16(attrCount))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(attrBytes);
    final body = element.toBytes();

    final total = 8 + pool.length + resourceMap.length + body.length;
    return Uint8List.fromList([
      ..._u16(0x0003),
      ..._u16(8),
      ..._u32(total),
      ...pool,
      ...resourceMap,
      ...body,
    ]);
  }

  /// Uyarlanabilir simge XML'i: `<adaptive-icon>` altında zemin ve ön plan.
  static Uint8List adaptiveIcon({
    required int backgroundResId,
    required int foregroundResId,
  }) {
    const drawable = 0x01010199;
    final strings = ['drawable', 'adaptive-icon', 'background', 'foreground'];
    final pool = stringPool(strings);
    final resourceMap = Uint8List.fromList([
      ..._u16(0x0180),
      ..._u16(8),
      ..._u32(12),
      ..._u32(drawable),
    ]);

    Uint8List element(String name, int resId) {
      final attr = _attribute(nameIndex: 0, dataType: 0x01, data: resId);
      return Uint8List.fromList([
        ..._u16(0x0102),
        ..._u16(16),
        ..._u32(16 + 20 + attr.length),
        ..._u32(1),
        ..._u32(0xFFFFFFFF),
        ..._u32(0xFFFFFFFF),
        ..._u32(strings.indexOf(name)),
        ..._u16(20),
        ..._u16(20),
        ..._u16(1),
        ..._u16(0),
        ..._u16(0),
        ..._u16(0),
        ...attr,
      ]);
    }

    final background = element('background', backgroundResId);
    final foreground = element('foreground', foregroundResId);
    final total =
        8 + pool.length + resourceMap.length + background.length + foreground.length;
    return Uint8List.fromList([
      ..._u16(0x0003),
      ..._u16(8),
      ..._u32(total),
      ...pool,
      ...resourceMap,
      ...background,
      ...foreground,
    ]);
  }

  /// Tek paketli bir kaynak tablosu.
  ///
  /// [files] her kaynak için `kimlik → (yoğunluk, yol)` listesi verir; yollar
  /// tablonun genel dizgi havuzuna yazılır. [colors] renk kaynakları içindir
  /// (uyarlanabilir simgenin zemini sık sık düz renktir).
  static Uint8List table({
    required Map<int, List<(int, String)>> files,
    Map<int, int> colors = const {},
    List<String> typeNames = const ['mipmap', 'drawable', 'color'],
    String keyName = 'ic_launcher',
  }) {
    final values = <String>[];
    for (final entries in files.values) {
      for (final (_, path) in entries) {
        if (!values.contains(path)) values.add(path);
      }
    }
    final pool = stringPool(values);
    final types = stringPool(typeNames);
    final keys = stringPool([keyName]);

    // Kimlikler: (paket << 24) | (tür << 16) | girdi. Aynı türdeki girdiler
    // tek bir tür yığınında toplanır; her yapılandırma AYRI yığın.
    final byTypeAndDensity = <(int, int), Map<int, (int, int)>>{};
    void add(int resId, int density, int dataType, int data) {
      final typeId = (resId >> 16) & 0xFF;
      final index = resId & 0xFFFF;
      byTypeAndDensity
          .putIfAbsent((typeId, density), () => <int, (int, int)>{})[index] =
          (dataType, data);
    }

    files.forEach((resId, entries) {
      for (final (density, path) in entries) {
        add(resId, density, 0x03, values.indexOf(path));
      }
    });
    colors.forEach((resId, argb) => add(resId, 0, 0x1c, argb));

    final chunks = BytesBuilder();
    byTypeAndDensity.forEach((key, entries) {
      final (typeId, density) = key;
      final maxIndex =
          entries.keys.fold<int>(0, (a, b) => a > b ? a : b);
      final count = maxIndex + 1;
      const configSize = 64;
      const header = 20 + configSize;
      final offsets = BytesBuilder();
      final body = BytesBuilder();
      for (var i = 0; i < count; i++) {
        final entry = entries[i];
        if (entry == null) {
          offsets.add(_u32(0xFFFFFFFF));
          continue;
        }
        offsets.add(_u32(body.length));
        body
          ..add(_u16(8)) // girdi başlığı
          ..add(_u16(0)) // basit girdi
          ..add(_u32(0)) // anahtar dizgisi indisi
          ..add(_u16(8)) // Res_value boyutu
          ..addByte(0)
          ..addByte(entry.$1)
          ..add(_u32(entry.$2));
      }
      final offsetBytes = offsets.toBytes();
      final bodyBytes = body.toBytes();
      final config = Uint8List(configSize);
      ByteData.sublistView(config)
        ..setUint32(0, configSize, Endian.little)
        ..setUint16(14, density, Endian.little);
      chunks
        ..add(_u16(0x0201))
        ..add(_u16(header))
        ..add(_u32(header + offsetBytes.length + bodyBytes.length))
        ..addByte(typeId)
        ..addByte(0) // bayrak yok (seyrek değil, 16 bit ofset değil)
        ..add(_u16(0))
        ..add(_u32(count))
        ..add(_u32(header + offsetBytes.length))
        ..add(config)
        ..add(offsetBytes)
        ..add(bodyBytes);
    });
    final typeChunks = chunks.toBytes();

    const packageHeader = 284;
    const typeStringsOffset = packageHeader;
    final keyStringsOffset = typeStringsOffset + types.length;
    final packageSize =
        packageHeader + types.length + keys.length + typeChunks.length;
    final package = BytesBuilder()
      ..add(_u16(0x0200))
      ..add(_u16(packageHeader))
      ..add(_u32(packageSize))
      ..add(_u32(0x7F))
      ..add(Uint8List(256)) // paket adı (boş bırakılabilir)
      ..add(_u32(typeStringsOffset))
      ..add(_u32(0))
      ..add(_u32(keyStringsOffset))
      ..add(_u32(0))
      ..add(types)
      ..add(keys)
      ..add(typeChunks);
    final packageBytes = package.toBytes();

    final total = 12 + pool.length + packageBytes.length;
    return Uint8List.fromList([
      ..._u16(0x0002),
      ..._u16(12),
      ..._u32(total),
      ..._u32(1), // paket sayısı
      ...pool,
      ...packageBytes,
    ]);
  }

  static Uint8List _attribute({
    required int nameIndex,
    required int dataType,
    required int data,
  }) =>
      Uint8List.fromList([
        ..._u32(0xFFFFFFFF), // ad alanı
        ..._u32(nameIndex),
        ..._u32(0xFFFFFFFF), // ham değer yok
        ..._u16(8), // Res_value boyutu
        0, // res0
        dataType,
        ..._u32(data),
      ]);

  static List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];

  static List<int> _u32(int v) =>
      [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

  static List<int> _utf8(String s) => s.codeUnits;
}
